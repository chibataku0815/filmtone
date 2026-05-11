import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum FilmtoneVideoWriterError: Error {
    case writerSetupFailed(URL, underlying: Error?)
    case inputCannotBeAdded(URL)
    case audioInputCannotBeAdded(URL)
    case writerStartFailed(URL, underlying: Error?)
    case appendFailed(URL, underlying: Error?)
    case audioAppendFailed(URL, underlying: Error?)
    case waitForReadyTimedOut(URL)
    case finishIncomplete(URL, status: AVAssetWriter.Status, underlying: Error?)
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
    private let audioInput: AVAssetWriterInput?
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor

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

        let audioInput: AVAssetWriterInput?
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
            audioInput = input
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
        try await waitForReadyForMoreMediaData(audioInput)
        if !audioInput.append(sampleBuffer) {
            throw FilmtoneVideoWriterError.audioAppendFailed(outputURL, underlying: writer.error)
        }
    }

    func finish() async throws {
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.scheduleFinishWriting(continuation: continuation)
        }
    }

    private func scheduleFinishWriting(continuation: CheckedContinuation<Void, Error>) {
        let outURL = outputURL
        writer.finishWriting { [self] in
            if writer.status == .completed {
                continuation.resume()
            } else {
                continuation.resume(throwing: FilmtoneVideoWriterError.finishIncomplete(
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

    private func waitForReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        timeoutSeconds: Double = 15
    ) async throws {
        let startedAt = Date()
        while !input.isReadyForMoreMediaData {
            try Task.checkCancellation()
            if Date().timeIntervalSince(startedAt) >= timeoutSeconds {
                throw FilmtoneVideoWriterError.waitForReadyTimedOut(outputURL)
            }
            try await Task.sleep(nanoseconds: 2_000_000)
        }
    }
}
