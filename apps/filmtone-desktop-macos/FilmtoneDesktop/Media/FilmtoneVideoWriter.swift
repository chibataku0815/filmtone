import AVFoundation
import CoreMedia
import CoreVideo
import Dispatch
import Foundation

enum FilmtoneVideoWriterError: Error, LocalizedError {
    case writerSetupFailed(URL, underlying: Error?)
    case inputCannotBeAdded(URL)
    case audioInputCannotBeAdded(URL)
    case writerStartFailed(URL, underlying: Error?)
    case appendFailed(URL, underlying: Error?)
    case audioAppendFailed(URL, underlying: Error?)
    case waitForReadyTimedOut(URL)
    case finishTimedOut(URL, timeoutSeconds: Double)
    case finishIncomplete(URL, status: AVAssetWriter.Status, underlying: Error?)

    var errorDescription: String? {
        switch self {
        case .writerSetupFailed(let url, let underlying):
            return "Could not set up video writer for \(url.lastPathComponent)\(Self.underlyingMessage(underlying))"
        case .inputCannotBeAdded(let url):
            return "Could not add video input for \(url.lastPathComponent)"
        case .audioInputCannotBeAdded(let url):
            return "Could not add audio input for \(url.lastPathComponent)"
        case .writerStartFailed(let url, let underlying):
            return "Could not start video writer for \(url.lastPathComponent)\(Self.underlyingMessage(underlying))"
        case .appendFailed(let url, let underlying):
            return "Could not append a rendered frame to \(url.lastPathComponent)\(Self.underlyingMessage(underlying))"
        case .audioAppendFailed(let url, let underlying):
            return "Could not append audio to \(url.lastPathComponent)\(Self.underlyingMessage(underlying))"
        case .waitForReadyTimedOut(let url):
            return "The video writer stopped accepting frames for \(url.lastPathComponent)"
        case .finishTimedOut(let url, let timeoutSeconds):
            return "The video writer did not finish \(url.lastPathComponent) within \(Int(timeoutSeconds)) seconds"
        case .finishIncomplete(let url, let status, let underlying):
            return "The video writer did not complete \(url.lastPathComponent) (status: \(status))\(Self.underlyingMessage(underlying))"
        }
    }

    private static func underlyingMessage(_ error: Error?) -> String {
        guard let error else { return "" }
        return ": \(error.localizedDescription)"
    }
}

// AVAssetWriter wrapper for H.264 mp4 output. Lifted from iOS
// `FilmtoneExportSession.makeWriter(...)` / `makeVideoInput(...)`
// (lines 1272-1298). Configured for Rec.709 SDR per Phase 1c default contract.
//
// `@unchecked Sendable` because AVAssetWriter / AVAssetWriterInput /
// AVAssetWriterInputPixelBufferAdaptor are not declared Sendable but are used
// here from a single Task (FilmtoneVideoExporter.export) with no concurrent
// reentry. Phase 2 will revisit when the pipeline moves to actor-isolated
// queues / IOSurface-backed Metal compute.
final class FilmtoneVideoWriter: @unchecked Sendable {
    let outputURL: URL
    let outputSize: CGSize
    let frameRate: Int
    let contract: FilmtoneColorPipelineContract

    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: FilmtoneAudioWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let inputFinishLock = NSLock()
    private var videoInputFinished = false
    private var audioInputFinished: Bool

    init(
        outputURL: URL,
        outputSize: CGSize,
        frameRate: Int,
        contract: FilmtoneColorPipelineContract,
        preserveAudio: Bool = false
    ) throws {
        // AVAssetWriter refuses to write if the output URL already exists.
        try? FileManager.default.removeItem(at: outputURL)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let writer: AVAssetWriter
        do {
            writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        } catch {
            throw FilmtoneVideoWriterError.writerSetupFailed(outputURL, underlying: error)
        }
        writer.movieFragmentInterval = .invalid

        let width = max(2, Int(outputSize.width.rounded()))
        let height = max(2, Int(outputSize.height.rounded()))
        let bitRate = max(width * height * 6, 3_000_000)

        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: frameRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ],
            AVVideoColorPropertiesKey: contract.writerColorProperties,
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = .identity

        guard writer.canAdd(videoInput) else {
            throw FilmtoneVideoWriterError.inputCannotBeAdded(outputURL)
        }
        writer.add(videoInput)

        let audioInput: FilmtoneAudioWriterInput?
        if preserveAudio {
            let input = AVAssetWriterInput(
                mediaType: .audio,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVEncoderBitRateKey: 128_000,
                    AVNumberOfChannelsKey: 2,
                    AVSampleRateKey: 44_100,
                ]
            )
            input.expectsMediaDataInRealTime = false
            guard writer.canAdd(input) else {
                throw FilmtoneVideoWriterError.audioInputCannotBeAdded(outputURL)
            }
            writer.add(input)
            audioInput = FilmtoneAudioWriterInput(input)
        } else {
            audioInput = nil
        }

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        self.outputURL = outputURL
        self.outputSize = CGSize(width: width, height: height)
        self.frameRate = frameRate
        self.contract = contract
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = audioInput
        self.adaptor = adaptor
        self.audioInputFinished = audioInput == nil
    }

    func start(atSourceTime startTime: CMTime = .zero) throws {
        guard writer.startWriting() else {
            throw FilmtoneVideoWriterError.writerStartFailed(
                outputURL,
                underlying: writer.error
            )
        }
        writer.startSession(atSourceTime: startTime)
    }

    var pixelBufferPool: CVPixelBufferPool? {
        adaptor.pixelBufferPool
    }

    func waitForVideoInputReady() async throws {
        try await waitForReadyForMoreMediaData(videoInput)
    }

    func append(buffer: CVPixelBuffer, presentationTime: CMTime) async throws {
        try await waitForReadyForMoreMediaData(videoInput)
        if !adaptor.append(buffer, withPresentationTime: presentationTime) {
            throw FilmtoneVideoWriterError.appendFailed(outputURL, underlying: writer.error)
        }
    }

    func appendAudio(sampleBuffer: CMSampleBuffer) async throws {
        guard let audioInput else {
            throw FilmtoneVideoWriterError.audioInputCannotBeAdded(outputURL)
        }
        try await waitForReadyForMoreMediaData(audioInput.rawInput)
        if !audioInput.append(sampleBuffer) {
            throw FilmtoneVideoWriterError.audioAppendFailed(outputURL, underlying: writer.error)
        }
    }

    func appendAudioSamples(from reader: FilmtoneAudioReader) async throws {
        guard let audioInput else {
            throw FilmtoneVideoWriterError.audioInputCannotBeAdded(outputURL)
        }
        let queue = DispatchQueue(label: "com.filmtone.desktop.export.audio-writer", qos: .userInitiated)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let state = FilmtoneVideoWriterFinishState(continuation: continuation)
            audioInput.requestMediaDataWhenReady(on: queue) { [self, reader, audioInput] in
                while audioInput.isReadyForMoreMediaData {
                    if state.isResolved {
                        return
                    }
                    do {
                        switch writer.status {
                        case .failed, .cancelled:
                            throw FilmtoneVideoWriterError.finishIncomplete(
                                outputURL,
                                status: writer.status,
                                underlying: writer.error
                            )
                        default:
                            break
                        }
                        guard let sampleBuffer = try reader.nextSampleBuffer() else {
                            markAudioInputFinished()
                            _ = state.resume()
                            return
                        }
                        if !audioInput.append(sampleBuffer) {
                            throw FilmtoneVideoWriterError.audioAppendFailed(
                                outputURL,
                                underlying: writer.error
                            )
                        }
                    } catch {
                        reader.cancel()
                        _ = state.resume(throwing: error)
                        return
                    }
                }
            }
        }
    }

    func finish(timeoutSeconds: Double = 180) async throws {
        markVideoInputFinished()
        markAudioInputFinished()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let state = FilmtoneVideoWriterFinishState(continuation: continuation)
            self.scheduleFinishWriting(state: state)
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeoutSeconds) { [self] in
                if state.resume(throwing: FilmtoneVideoWriterError.finishTimedOut(
                    outputURL,
                    timeoutSeconds: timeoutSeconds
                )) {
                    writer.cancelWriting()
                }
            }
        }
    }

    private func scheduleFinishWriting(state: FilmtoneVideoWriterFinishState) {
        let outURL = outputURL
        writer.finishWriting { [self] in
            if writer.status == .completed {
                _ = state.resume()
            } else {
                _ = state.resume(throwing: FilmtoneVideoWriterError.finishIncomplete(
                    outURL,
                    status: writer.status,
                    underlying: writer.error
                ))
            }
        }
    }

    func cancel() {
        writer.cancelWriting()
    }

    private func markVideoInputFinished() {
        inputFinishLock.lock()
        defer { inputFinishLock.unlock() }
        guard !videoInputFinished else {
            return
        }
        videoInput.markAsFinished()
        videoInputFinished = true
    }

    private func markAudioInputFinished() {
        guard let audioInput else {
            return
        }
        inputFinishLock.lock()
        defer { inputFinishLock.unlock() }
        guard !audioInputFinished else {
            return
        }
        audioInput.markAsFinished()
        audioInputFinished = true
    }

    private func waitForReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        timeoutSeconds: Double = 120
    ) async throws {
        let startedAt = Date()
        while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()
            switch writer.status {
            case .failed, .cancelled, .completed:
                throw FilmtoneVideoWriterError.finishIncomplete(
                    outputURL,
                    status: writer.status,
                    underlying: writer.error
                )
            default:
                break
            }
            if Date().timeIntervalSince(startedAt) >= timeoutSeconds {
                throw FilmtoneVideoWriterError.waitForReadyTimedOut(outputURL)
            }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}

private final class FilmtoneAudioWriterInput: @unchecked Sendable {
    let rawInput: AVAssetWriterInput

    init(_ input: AVAssetWriterInput) {
        self.rawInput = input
    }

    var isReadyForMoreMediaData: Bool {
        rawInput.isReadyForMoreMediaData
    }

    func requestMediaDataWhenReady(
        on queue: DispatchQueue,
        using block: @escaping @Sendable () -> Void
    ) {
        rawInput.requestMediaDataWhenReady(on: queue, using: block)
    }

    func append(_ sampleBuffer: CMSampleBuffer) -> Bool {
        rawInput.append(sampleBuffer)
    }

    func markAsFinished() {
        rawInput.markAsFinished()
    }
}

private final class FilmtoneVideoWriterFinishState: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func resume() -> Bool {
        resume(with: .success(()))
    }

    func resume(throwing error: Error) -> Bool {
        resume(with: .failure(error))
    }

    var isResolved: Bool {
        lock.lock()
        defer { lock.unlock() }
        return continuation == nil
    }

    private func resume(with result: Result<Void, Error>) -> Bool {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return false
        }
        self.continuation = nil
        lock.unlock()

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
        return true
    }
}
