import AVFoundation
import CoreImage
import CryptoKit
import Foundation

final class MezzanineService {
    struct Profile {
        static let version = 2
        static let codec = "h264"
        static let longEdge = 1920
        static let bitrate = 12_000_000
    }

    struct Limits {
        static let maxBytes: Int64 = 1_073_741_824  // 1 GB
        static let maxEntries: Int = 10
    }

    enum GenerationError: Error {
        case unsupportedSource(String)
        case writerFailed(String)
        case readerFailed(String)
        case cancelled
    }

    private let cacheStore: CacheStore
    private let fileManager: FileManager
    private let ciContext: CIContext
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private let inFlightQueue = DispatchQueue(label: "MezzanineService.inflight")
    private var inFlight: [String: Task<URL, Error>] = [:]

    init(
        cacheStore: CacheStore,
        fileManager: FileManager = .default
    ) {
        self.cacheStore = cacheStore
        self.fileManager = fileManager
        self.ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: true,
        ])
        // Lazy cold-start prune: any files left past caps from a prior session
        // or an unclean shutdown get evicted before we start writing new ones.
        try? cacheStore.pruneMezzanine(
            maxBytes: Limits.maxBytes,
            maxEntries: Limits.maxEntries
        )
    }

    // MARK: - Signature

    func signature(for sourceURL: URL) throws -> String {
        let attrs = try fileManager.attributesOfItem(atPath: sourceURL.path)
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mtimeMs: Int64 = {
            guard let date = attrs[.modificationDate] as? Date else { return 0 }
            return Int64(date.timeIntervalSince1970 * 1000)
        }()
        let durationSec = Int(CMTimeGetSeconds(AVURLAsset(url: sourceURL).duration).rounded())

        let payload: [String: Any] = [
            "path": sourceURL.path,
            "sizeBytes": size,
            "mtimeMs": mtimeMs,
            "trackDurationRoundedSec": durationSec,
            "profile": [
                "version": Profile.version,
                "codec": Profile.codec,
                "longEdge": Profile.longEdge,
                "bitrate": Profile.bitrate,
            ],
        ]

        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.sortedKeys]
        )
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Public API

    /// Returns mezzanine URL if a valid cache file already exists for `sourceURL`.
    /// Touches contentAccessDate for LRU recency. Does not trigger generation.
    func existingMezzanineURL(for sourceURL: URL) -> URL? {
        guard let sig = try? signature(for: sourceURL),
              let url = try? cacheStore.mezzanineFileURL(signature: sig),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        // Touch access date; ignore failure.
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        return url
    }

    /// Ensures a mezzanine file for `sourceURL` exists, generating if missing.
    /// Multiple concurrent calls for the same source coalesce to a single task.
    /// Generation is atomic: writes to a `.partial` sibling and renames on success
    /// so a crash mid-transcode never leaves a readable-but-corrupt `.mp4` behind.
    @discardableResult
    func ensureMezzanine(sourceURL: URL) async throws -> URL {
        let sig = try signature(for: sourceURL)
        let destURL = try cacheStore.mezzanineFileURL(signature: sig)

        if fileManager.fileExists(atPath: destURL.path) {
            return destURL
        }

        let task: Task<URL, Error> = inFlightQueue.sync {
            if let existing = inFlight[sig] { return existing }
            let tempURL = destURL.appendingPathExtension("partial")
            let newTask = Task<URL, Error> { [weak self] in
                guard let self else { throw GenerationError.cancelled }
                defer {
                    self.inFlightQueue.sync { self.inFlight[sig] = nil }
                }
                // Clean any stale partial from a prior crashed run.
                try? self.fileManager.removeItem(at: tempURL)
                try Task.checkCancellation()
                try await self.generate(sourceURL: sourceURL, destinationURL: tempURL)
                try Task.checkCancellation()
                // Atomic promote so existingMezzanineURL only ever sees complete files.
                if self.fileManager.fileExists(atPath: destURL.path) {
                    try? self.fileManager.removeItem(at: destURL)
                }
                try self.fileManager.moveItem(at: tempURL, to: destURL)
                try? self.cacheStore.pruneMezzanine(
                    maxBytes: Limits.maxBytes,
                    maxEntries: Limits.maxEntries
                )
                return destURL
            }
            inFlight[sig] = newTask
            return newTask
        }

        return try await task.value
    }

    // MARK: - Generation

    private func generate(sourceURL: URL, destinationURL: URL) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async { [self] in
                do {
                    try self.generateSync(sourceURL: sourceURL, destinationURL: destinationURL)
                    continuation.resume(returning: ())
                } catch {
                    // Clean partial output on failure so a future ensure retries.
                    try? self.fileManager.removeItem(at: destinationURL)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func generateSync(sourceURL: URL, destinationURL: URL) throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw GenerationError.unsupportedSource("No video track found.")
        }

        let outputSize = FilmtoneExportSession.scaledSize(
            for: videoTrack,
            longEdge: Profile.longEdge
        )

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let writer = try AVAssetWriter(outputURL: destinationURL, fileType: .mp4)
        writer.movieFragmentInterval = .invalid

        let width = Int(outputSize.width.rounded())
        let height = Int(outputSize.height.rounded())
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: Profile.bitrate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ],
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        videoInput.transform = .identity

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw GenerationError.writerFailed("Video input could not be added.")
        }
        writer.add(videoInput)

        let audioTrack = asset.tracks(withMediaType: .audio).first
        let audioOutput: AVAssetReaderTrackOutput?
        let audioInput: AVAssetWriterInput?
        if let audioTrack {
            let output = AVAssetReaderTrackOutput(
                track: audioTrack,
                outputSettings: [
                    AVFormatIDKey: kAudioFormatLinearPCM,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsBigEndianKey: false,
                    AVLinearPCMIsNonInterleaved: false,
                ]
            )
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
            audioOutput = output
            audioInput = input
            if writer.canAdd(input) { writer.add(input) }
        } else {
            audioOutput = nil
            audioInput = nil
        }

        let reader = try AVAssetReader(asset: asset)
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw GenerationError.readerFailed("Video output could not be added.")
        }
        reader.add(videoOutput)

        if let audioOutput, reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }

        guard writer.startWriting() else {
            throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "Writer failed to start.")
        }
        guard reader.startReading() else {
            throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "Reader failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let group = DispatchGroup()
        let videoQueue = DispatchQueue(label: "MezzanineService.video")
        let audioQueue = DispatchQueue(label: "MezzanineService.audio")
        let failureLock = NSLock()
        let completionLock = NSLock()
        var videoFinished = false
        var audioFinished = audioInput == nil
        var capturedError: Error?

        let preferredTransform = videoTrack.preferredTransform

        func finishVideo(markAsFinished: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !videoFinished else { return }
            if markAsFinished { videoInput.markAsFinished() }
            videoFinished = true
            group.leave()
        }

        func finishAudio(markAsFinished: Bool) {
            guard let audioInput else { return }
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !audioFinished else { return }
            if markAsFinished { audioInput.markAsFinished() }
            audioFinished = true
            group.leave()
        }

        func fail(_ error: Error) {
            failureLock.lock()
            let shouldStore = capturedError == nil
            if shouldStore { capturedError = error }
            failureLock.unlock()
            guard shouldStore else { return }
            reader.cancelReading()
            writer.cancelWriting()
            finishVideo(markAsFinished: true)
            finishAudio(markAsFinished: true)
        }

        group.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) {
            while videoInput.isReadyForMoreMediaData {
                if capturedError != nil {
                    finishVideo(markAsFinished: true)
                    return
                }
                autoreleasepool {
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            fail(GenerationError.readerFailed(reader.error?.localizedDescription ?? "Video read failed."))
                        } else {
                            finishVideo(markAsFinished: true)
                        }
                        return
                    }

                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                        return
                    }
                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let sourceImage = self.orientAndScale(
                        CIImage(cvPixelBuffer: pixelBuffer),
                        transform: preferredTransform,
                        outputSize: outputSize
                    )

                    guard let pool = adaptor.pixelBufferPool else {
                        fail(GenerationError.writerFailed("Pixel buffer pool unavailable."))
                        return
                    }
                    var rendered: CVPixelBuffer?
                    let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &rendered)
                    guard status == kCVReturnSuccess, let rendered else {
                        fail(GenerationError.writerFailed("Could not create output pixel buffer."))
                        return
                    }

                    self.ciContext.render(
                        sourceImage,
                        to: rendered,
                        bounds: CGRect(origin: .zero, size: outputSize),
                        colorSpace: self.colorSpace
                    )

                    if !adaptor.append(rendered, withPresentationTime: presentationTime) {
                        fail(GenerationError.writerFailed(writer.error?.localizedDescription ?? "Append failed."))
                        return
                    }
                }
            }
        }

        if let audioInput, let audioOutput {
            group.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) {
                while audioInput.isReadyForMoreMediaData {
                    if capturedError != nil {
                        finishAudio(markAsFinished: true)
                        return
                    }
                    guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            fail(GenerationError.readerFailed(reader.error?.localizedDescription ?? "Audio read failed."))
                        } else {
                            finishAudio(markAsFinished: true)
                        }
                        return
                    }
                    if !audioInput.append(sampleBuffer) {
                        fail(GenerationError.writerFailed(writer.error?.localizedDescription ?? "Audio append failed."))
                        return
                    }
                }
            }
        }

        group.wait()

        if let capturedError {
            throw capturedError
        }

        if reader.status == .failed {
            throw GenerationError.readerFailed(reader.error?.localizedDescription ?? "Reader failed.")
        }

        let finishGroup = DispatchGroup()
        finishGroup.enter()
        writer.finishWriting {
            finishGroup.leave()
        }
        finishGroup.wait()

        if writer.status != .completed {
            throw GenerationError.writerFailed(writer.error?.localizedDescription ?? "Writer did not complete.")
        }
    }

    private func orientAndScale(
        _ image: CIImage,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        let oriented = image.transformed(by: FilmtoneExportSession.coreImageVideoTransform(
            for: transform,
            sourceExtent: image.extent
        ))
        let normalized = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }
}
