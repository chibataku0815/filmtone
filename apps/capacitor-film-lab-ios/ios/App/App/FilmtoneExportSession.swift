import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit

final class FilmtoneExportSession {
    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let cacheStore: CacheStore
    private let mezzanineService: MezzanineService?
    private let outputURL: URL
    private(set) var didUseMezzanineVariant: ProfileVariant?
    private let ciContext: CIContext
    private let preparedInputLut: PreparedLut?
    private let preparedCreativeLut: PreparedLut?
    private let sourceSeed: Double
    private let outputColorSpace: CGColorSpace
    private var degradedDecodePath = false
    private var cancelled = false
    private static let aberrationEdgeSoftenScale = 32.0
    private static let aberrationEdgeSoftenMax = 0.52
    private static let aberrationEdgeSoftenCurve = 1.55
    private static let aberrationBlurRadiusMin = 1.6
    private static let aberrationBlurRadiusMax = 6.2
    private static let aberrationBlurRadiusCap = 7.8
    private static let lensSoftnessBlurBoost = 1.85
    private static let glowBaseScale = 0.5
    private static let bloomSpreadBoost = 1.25
    private static let halationSpreadDivisor = 12.0
    private static let diffusionCompositeBase = 0.87
    private static let bloomMipLevels = 6
    private static let halationMipLevels = 6
    private static let diffusionMipLevels = 4
    private static let glowUpsampleBlurRadius = 1.0

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        cacheStore: CacheStore,
        mezzanineService: MezzanineService? = nil
    ) throws {
        self.request = request
        self.sourceURL = sourceURL
        self.cacheStore = cacheStore
        self.mezzanineService = mezzanineService
        self.outputURL = try cacheStore.temporaryExportURL(pathExtension: request.output.container)
        let workingColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        self.outputColorSpace = outputColorSpace
        self.ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false,
            .workingColorSpace: workingColorSpace,
            .workingFormat: NSNumber(value: CIFormat.RGBAh.rawValue),
            .outputColorSpace: outputColorSpace,
        ])
        self.preparedInputLut = Self.makePreparedLut(from: request.inputLut)
            ?? Self.makeAutomaticInputLut(for: request.sourceProbe?.inputTransformPolicy)
        let legacyCreativeLut = request.creativeLut ?? request.lut.map {
            SerializableLutDTO(size: $0.size, data: $0.data, intensity: $0.intensity)
        }
        self.preparedCreativeLut = Self.makePreparedLut(from: legacyCreativeLut)
        self.sourceSeed = Self.makeStableSourceSeed(from: sourceURL.absoluteString)
    }

    func cancel() {
        cancelled = true
    }

    func makeSharedGradeProcessor() -> FilmtoneSharedGradeProcessor {
        FilmtoneSharedGradeProcessor(session: self)
    }

    func renderPreviewFrame() throws -> Phase0PreviewRenderResultDTO {
        defer {
            ciContext.clearCaches()
        }

        switch request.sourceKind {
        case .image:
            return try renderStillPreview()
        case .video:
            return try renderVideoPreview()
        }
    }

    func run(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> Phase0ExportResultDTO {
        defer {
            ciContext.clearCaches()
        }

        let startedAt = Date()
        progress(.init(stage: .preflight, progress: 0.03, currentFrame: nil, totalFrames: nil, message: "Preparing export"))

        let result: CompletedExport
        switch request.sourceKind {
        case .video:
            result = try exportVideo(progress: progress)
        case .image:
            result = try exportStillImage(progress: progress)
        }

        let elapsedMs = Int(Date().timeIntervalSince(startedAt) * 1000.0)
        let fileSizeBytes = try outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
        let realtimeRatio: Double?
        if let duration = result.sourceDurationSec, duration > 0 {
            realtimeRatio = Double(elapsedMs) / (duration * 1000.0)
        } else {
            realtimeRatio = nil
        }

        progress(.init(stage: .completed, progress: 1.0, currentFrame: result.frameCount, totalFrames: result.frameCount, message: "Export complete"))

        // T2 (v1.1): write the filmtone-ios-export-session-v1 sidecar next to the
        // export output. Failure here must NOT fail the export itself — missing
        // sidecar just surfaces as `sidecarUri = nil` downstream.
        let sidecarUri = writeExportSidecar(
            outputSize: result.outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved
        )

        return Phase0ExportResultDTO(
            outputUri: outputURL.absoluteString,
            elapsedMs: elapsedMs,
            outputWidth: Int(result.outputSize.width.rounded()),
            outputHeight: Int(result.outputSize.height.rounded()),
            outputFps: request.output.fps,
            fileSizeBytes: fileSizeBytes,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            benchmarkRecord: nil,
            sidecarUri: sidecarUri
        )
    }

    /// Assemble and atomically write the filmtone-ios-export-session-v1 sidecar.
    /// Returns the sidecar absolute URL string on success, `nil` on any failure.
    private func writeExportSidecar(
        outputSize: CGSize,
        fileSizeBytes: Int?,
        elapsedMs: Int,
        realtimeRatio: Double?,
        audioPreserved: Bool?
    ) -> String? {
        let identity = SidecarDeviceIdentity(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            deviceModel: UIDevice.current.filmtoneModelIdentifier,
            iosVersion: UIDevice.current.systemVersion,
            exportedAtIso: ISO8601DateFormatter.filmtoneSidecar.string(from: Date())
        )

        let hdrPolicy = request.sourceProbe?.sourceVideoMetadata?.hdrPreparationPolicy

        let inputs = SidecarBuildInputs(
            request: request,
            sourceProbe: request.sourceProbe,
            hdrPolicy: hdrPolicy,
            degradedDecodePath: degradedDecodePath,
            outputURL: outputURL,
            outputSize: outputSize,
            fileSizeBytes: fileSizeBytes,
            elapsedMs: elapsedMs,
            realtimeRatio: realtimeRatio,
            audioPreserved: audioPreserved,
            identity: identity,
            // v1.2: render-mode + mezzanine variant + profile-version for sidecar truth.
            // Stream D owns the field declarations on SidecarBuildInputs; this call site
            // populates them per the cross-stream contract.
            renderMode: (request.renderMode ?? .quality).rawValue,
            mezzanineUsedVariant: didUseMezzanineVariant?.rawValue,
            mezzanineProfileVersion: didUseMezzanineVariant != nil ? MezzanineService.Profile.version : nil
        )

        let sidecarURL = FilmtoneExportSidecarBuilder.sidecarURL(for: outputURL)
        do {
            let payload = try FilmtoneExportSidecarBuilder.build(inputs)
            try payload.write(to: sidecarURL, options: [.atomic])
            return sidecarURL.absoluteString
        } catch {
            filmtonePreviewCompositionDebugLog(
                "sidecar write failed at \(sidecarURL.path): \(error.localizedDescription)"
            )
            return nil
        }
    }

    private func exportVideo(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> CompletedExport {
        let effectiveSourceURL = resolvedVideoSourceURL()
        // Re-probe the matched variant so downstream telemetry / sidecar can record
        // which mezzanine variant was actually used (HDR-preferred for Quality, any-
        // available for Speed). When mezzanine was bypassed the variant stays nil.
        if effectiveSourceURL == sourceURL {
            didUseMezzanineVariant = nil
        } else if let mezz = mezzanineService,
                  effectiveSourceURL == mezz.existingMezzanineURL(for: sourceURL, variant: .hdr) {
            didUseMezzanineVariant = .hdr
        } else if let mezz = mezzanineService,
                  effectiveSourceURL == mezz.existingMezzanineURL(for: sourceURL, variant: .sdr) {
            didUseMezzanineVariant = .sdr
        } else {
            // Unreachable in practice (resolvedVideoSourceURL only returns a mezzanine
            // URL or sourceURL), but keep nil to stay on the safe explicit path.
            didUseMezzanineVariant = nil
        }
        let asset = AVURLAsset(url: effectiveSourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let outputSize = Self.scaledSize(for: videoTrack, longEdge: request.output.longEdge)
        let writer = try makeWriter(outputSize: outputSize)
        let videoInput = makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Video writer input could not be added.")
        }
        writer.add(videoInput)

        let audioTrack = request.output.preserveAudio ? asset.tracks(withMediaType: .audio).first : nil
        let audioInput: AVAssetWriterInput?
        let audioOutput: AVAssetReaderTrackOutput?
        if let audioTrack {
            let pair = makeAudioPipeline(for: audioTrack)
            audioInput = pair.input
            audioOutput = pair.output
            if let audioInput, writer.canAdd(audioInput) {
                writer.add(audioInput)
            }
        } else {
            audioInput = nil
            audioOutput = nil
        }

        let reader = try AVAssetReader(asset: asset)
        let videoOutputSelection = makeVideoReaderOutput(
            for: videoTrack,
            reader: reader,
            codecFamily: request.sourceProbe?.codecFamily ?? request.sourceProbe?.sourceVideoMetadata?.codecFamily
        )
        guard let videoOutputSelection else {
            throw FilmtoneMediaError.exportFailed("Video reader output could not be added.")
        }
        let videoOutput = videoOutputSelection.output
        degradedDecodePath = videoOutputSelection.degradedDecodePath
        reader.add(videoOutput)

        if let audioOutput, reader.canAdd(audioOutput) {
            reader.add(audioOutput)
        }

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        guard reader.startReading() else {
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let estimatedFrameCount = max(
            1,
            Int(ceil((sourceDurationSec.isFinite ? sourceDurationSec : 0) * estimatedVideoFrameRate(for: videoTrack)))
        )
        var renderedFrames = 0
        let completionLock = NSLock()
        let failureLock = NSLock()
        let dispatchGroup = DispatchGroup()
        let videoQueue = DispatchQueue(label: "FilmtoneExportSession.video")
        let audioQueue = DispatchQueue(label: "FilmtoneExportSession.audio")
        var videoInputFinished = false
        var audioInputFinished = audioInput == nil
        var capturedError: Error?

        func finishVideoInput(markAsFinished: Bool) {
            completionLock.lock()
            defer { completionLock.unlock() }
            guard !videoInputFinished else {
                return
            }
            if markAsFinished {
                videoInput.markAsFinished()
            }
            videoInputFinished = true
            dispatchGroup.leave()
        }

        func finishAudioInput(markAsFinished: Bool) {
            guard let audioInput else {
                return
            }

            completionLock.lock()
            defer { completionLock.unlock() }
            guard !audioInputFinished else {
                return
            }
            if markAsFinished {
                audioInput.markAsFinished()
            }
            audioInputFinished = true
            dispatchGroup.leave()
        }

        func failExport(_ error: Error) {
            failureLock.lock()
            let shouldStore = capturedError == nil
            if shouldStore {
                capturedError = error
            }
            failureLock.unlock()

            guard shouldStore else {
                return
            }

            reader.cancelReading()
            writer.cancelWriting()
            finishVideoInput(markAsFinished: true)
            finishAudioInput(markAsFinished: true)
        }

        progress(.init(stage: .reading, progress: 0.08, currentFrame: 0, totalFrames: estimatedFrameCount, message: "Reading source"))

        dispatchGroup.enter()
        videoInput.requestMediaDataWhenReady(on: videoQueue) { [self] in
            while videoInput.isReadyForMoreMediaData {
                if capturedError != nil {
                    finishVideoInput(markAsFinished: true)
                    return
                }

                do {
                    try checkCancelled()
                    guard let sampleBuffer = videoOutput.copyNextSampleBuffer() else {
                        if reader.status == .failed {
                            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
                        }
                        finishVideoInput(markAsFinished: true)
                        return
                    }

                    let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let appendedFrame = try appendVideoSample(
                        sampleBuffer,
                        videoInput: videoInput,
                        writer: writer,
                        reader: reader,
                        adaptor: adaptor,
                        videoTrack: videoTrack,
                        outputSize: outputSize,
                        waitForReady: false
                    )
                    guard appendedFrame else {
                        continue
                    }

                    renderedFrames += 1
                    if renderedFrames == 1 || renderedFrames % 12 == 0 {
                        let normalizedProgress = renderingProgress(
                            presentationTime: presentationTime,
                            sourceDurationSec: sourceDurationSec
                        )
                        progress(.init(
                            stage: .rendering,
                            progress: min(0.9, normalizedProgress),
                            currentFrame: renderedFrames,
                            totalFrames: estimatedFrameCount,
                            message: "Rendering frames"
                        ))
                    }
                } catch {
                    failExport(error)
                    return
                }
            }
        }

        if let audioInput, let audioOutput {
            dispatchGroup.enter()
            audioInput.requestMediaDataWhenReady(on: audioQueue) { [self] in
                while audioInput.isReadyForMoreMediaData {
                    if capturedError != nil {
                        finishAudioInput(markAsFinished: true)
                        return
                    }

                    do {
                        try checkCancelled()
                        guard let sampleBuffer = audioOutput.copyNextSampleBuffer() else {
                            if reader.status == .failed {
                                throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Audio read failed.")
                            }
                            finishAudioInput(markAsFinished: true)
                            return
                        }

                        try appendAudioSample(
                            sampleBuffer,
                            audioInput: audioInput,
                            writer: writer,
                            reader: reader,
                            waitForReady: false
                        )
                    } catch {
                        failExport(error)
                        return
                    }
                }
            }
        }

        dispatchGroup.wait()

        if let capturedError {
            throw capturedError
        }

        if reader.status == .failed {
            throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "Video read failed.")
        }

        progress(.init(stage: .writing, progress: 0.92, currentFrame: renderedFrames, totalFrames: estimatedFrameCount, message: "Writing output"))
        try finish(writer: writer)

        return CompletedExport(
            outputSize: outputSize,
            frameCount: renderedFrames,
            sourceDurationSec: sourceDurationSec.isFinite ? sourceDurationSec : nil,
            audioPreserved: audioInput != nil
        )
    }

    private func exportStillImage(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> CompletedExport {
        guard let image = loadedSourceImage(at: sourceURL) else {
            throw FilmtoneMediaError.unsupportedSource("The selected image could not be loaded.")
        }

        let outputSize = Self.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
        let writer = try makeWriter(outputSize: outputSize)
        let videoInput = makeVideoInput(outputSize: outputSize)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: Int(outputSize.width.rounded()),
                kCVPixelBufferHeightKey as String: Int(outputSize.height.rounded()),
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw FilmtoneMediaError.exportFailed("Still-image writer input could not be added.")
        }
        writer.add(videoInput)

        guard writer.startWriting() else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed to start.")
        }
        writer.startSession(atSourceTime: .zero)

        let frameCount = max(request.output.fps * 3, 1)
        let filteredImage = renderableStillImage(image, outputSize: outputSize, timeSeconds: 0)
        guard let pixelBufferPool = adaptor.pixelBufferPool else {
            throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
        }

        for frameIndex in 0..<frameCount {
            try checkCancelled()
            try autoreleasepool {
                try waitUntilReadyForMoreMediaData(videoInput, writer: writer, label: "video")

                var renderedBuffer: CVPixelBuffer?
                let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
                guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                    throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
                }

                ciContext.render(
                    filteredImage,
                    to: renderedBuffer,
                    bounds: CGRect(origin: .zero, size: outputSize),
                    colorSpace: outputColorSpace
                )
                attachRec709Metadata(to: renderedBuffer)

                let presentationTime = CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(request.output.fps))
                if !adaptor.append(renderedBuffer, withPresentationTime: presentationTime) {
                    throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The still frame could not be appended.")
                }
            }

            if frameIndex == 0 || frameIndex % 12 == 0 {
                let normalizedProgress = 0.12 + (Double(frameIndex + 1) / Double(frameCount)) * 0.74
                progress(.init(
                    stage: .rendering,
                    progress: min(0.9, normalizedProgress),
                    currentFrame: frameIndex + 1,
                    totalFrames: frameCount,
                    message: "Rendering still image"
                ))
            }
        }

        videoInput.markAsFinished()
        progress(.init(stage: .writing, progress: 0.92, currentFrame: frameCount, totalFrames: frameCount, message: "Writing output"))
        try finish(writer: writer)

        return CompletedExport(
            outputSize: outputSize,
            frameCount: frameCount,
            sourceDurationSec: Double(frameCount) / Double(request.output.fps),
            audioPreserved: false
        )
    }

    private func renderStillPreview() throws -> Phase0PreviewRenderResultDTO {
        guard let image = loadedSourceImage(at: sourceURL) else {
            throw FilmtoneMediaError.unsupportedSource("The selected image could not be loaded.")
        }

        let outputSize = Self.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
        let original = scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(to: original, timeSeconds: 0).cropped(to: original.extent)

        let originalURL = try writePreviewImage(original, preferredName: "filmtone-preview-original")
        let gradedURL = try writePreviewImage(graded, preferredName: "filmtone-preview-graded")

        return Phase0PreviewRenderResultDTO(
            originalUri: originalURL.absoluteString,
            gradedUri: gradedURL.absoluteString,
            width: Int(outputSize.width.rounded()),
            height: Int(outputSize.height.rounded()),
            posterTimeSec: nil
        )
    }

    private func renderVideoPreview() throws -> Phase0PreviewRenderResultDTO {
        let asset = AVURLAsset(url: sourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let posterTimeSec = makePreviewPosterTime(sourceDurationSec: sourceDurationSec)
        let outputSize = Self.scaledSize(for: videoTrack, longEdge: request.output.longEdge)

        let posterTime = CMTime(seconds: posterTimeSec, preferredTimescale: 600)
        let cgImage = try copyPreviewCGImage(for: asset, at: posterTime)
        let posterImage = CIImage(cgImage: cgImage)
        let original = scaledStillSourceImage(posterImage, outputSize: outputSize)
        let graded = applyGrade(to: original, timeSeconds: posterTimeSec).cropped(to: original.extent)

        let originalURL = try writePreviewImage(original, preferredName: "filmtone-preview-original")
        let gradedURL = try writePreviewImage(graded, preferredName: "filmtone-preview-graded")

        return Phase0PreviewRenderResultDTO(
            originalUri: originalURL.absoluteString,
            gradedUri: gradedURL.absoluteString,
            width: Int(outputSize.width.rounded()),
            height: Int(outputSize.height.rounded()),
            posterTimeSec: posterTimeSec
        )
    }

    private func copyPreviewCGImage(for asset: AVAsset, at time: CMTime) throws -> CGImage {
        do {
            return try configuredPreviewGenerator(asset: asset, tolerance: .zero).copyCGImage(at: time, actualTime: nil)
        } catch {
            let fallbackTolerance = CMTime(seconds: 0.5, preferredTimescale: 600)
            return try configuredPreviewGenerator(asset: asset, tolerance: fallbackTolerance)
                .copyCGImage(at: time, actualTime: nil)
        }
    }

    private func configuredPreviewGenerator(asset: AVAsset, tolerance: CMTime) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return generator
    }

    private func makeWriter(outputSize: CGSize) throws -> AVAssetWriter {
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        writer.movieFragmentInterval = .invalid
        return writer
    }

    private func makeVideoInput(outputSize: CGSize) -> AVAssetWriterInput {
        let width = Int(outputSize.width.rounded())
        let height = Int(outputSize.height.rounded())
        let bitRate = max(width * height * 6, 3_000_000)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: bitRate,
                AVVideoExpectedSourceFrameRateKey: request.output.fps,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoAllowFrameReorderingKey: false,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = .identity
        return input
    }

    private func makeVideoReaderOutput(
        for track: AVAssetTrack,
        reader: AVAssetReader,
        codecFamily: SourceCodecFamilyDTO?
    ) -> (output: AVAssetReaderTrackOutput, degradedDecodePath: Bool)? {
        let candidates: [(pixelFormat: OSType, degraded: Bool)]
        if codecFamily == .prores422 {
            candidates = [
                (kCVPixelFormatType_422YpCbCr16, false),
                (kCVPixelFormatType_64RGBAHalf, true),
                (kCVPixelFormatType_32BGRA, true),
            ]
        } else {
            candidates = [
                (kCVPixelFormatType_32BGRA, false),
            ]
        }

        for candidate in candidates {
            let output = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(candidate.pixelFormat),
                    AVVideoAllowWideColorKey: true,
                ]
            )
            output.alwaysCopiesSampleData = false
            if reader.canAdd(output) {
                return (output, candidate.degraded)
            }
        }

        return nil
    }

    private func makeAudioPipeline(
        for track: AVAssetTrack
    ) -> (input: AVAssetWriterInput, output: AVAssetReaderTrackOutput) {
        let output = AVAssetReaderTrackOutput(
            track: track,
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
        return (input, output)
    }

    private func renderableImage(
        from imageBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        outputSize: CGSize,
        timeSeconds: Double
    ) -> CIImage {
        let base = scaledVideoSourceImage(
            sourceVideoImage(from: imageBuffer),
            transform: transform,
            outputSize: outputSize
        )
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func renderableStillImage(
        _ image: CIImage,
        outputSize: CGSize,
        timeSeconds: Double
    ) -> CIImage {
        let base = scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    fileprivate func renderablePreviewVideoImage(
        from image: CIImage,
        outputSize: CGSize,
        timeSeconds: Double
    ) throws -> CIImage {
        let base = scaledPreviewVideoSourceImage(
            sourcePreviewVideoImage(from: image),
            outputSize: outputSize
        )
        let graded = applyGrade(to: base, timeSeconds: timeSeconds)
        let cropped = graded.cropped(to: CGRect(origin: .zero, size: outputSize))
        try validatePreviewVideoImage(cropped, outputSize: outputSize)
        return cropped
    }

    private func scaledVideoFrameImage(
        from imageBuffer: CVPixelBuffer,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        scaledVideoSourceImage(
            sourceVideoImage(from: imageBuffer),
            transform: transform,
            outputSize: outputSize
        )
    }

    private func scaledVideoSourceImage(
        _ image: CIImage,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage {
        let oriented = image.transformed(by: Self.coreImageVideoTransform(
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

    private func scaledPreviewVideoSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        // AVVideoComposition's CI filtering request already respects track presentation.
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func scaledStillSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        return normalized
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func validatePreviewVideoImage(_ image: CIImage, outputSize: CGSize) throws {
        let extent = image.extent.standardized
        guard
            extent.origin.x.isFinite,
            extent.origin.y.isFinite,
            extent.size.width.isFinite,
            extent.size.height.isFinite,
            !extent.isNull,
            !extent.isInfinite,
            extent.size.width > 0.5,
            extent.size.height > 0.5
        else {
            throw FilmtoneMediaError.exportFailed(
                filmtoneLocalized(
                    "filmtone.preview.video.invalid_extent",
                    defaultValue: "The live video preview produced an invalid frame.",
                    comment: "Error shown when the live video preview frame is invalid."
                )
            )
        }

        let expected = CGRect(origin: .zero, size: outputSize).standardized
        guard
            abs(extent.origin.x - expected.origin.x) < 0.5,
            abs(extent.origin.y - expected.origin.y) < 0.5,
            abs(extent.size.width - expected.size.width) < 0.5,
            abs(extent.size.height - expected.size.height) < 0.5
        else {
            throw FilmtoneMediaError.exportFailed(
                filmtoneLocalized(
                    "filmtone.preview.video.unexpected_extent",
                    defaultValue: "The live video preview frame size was invalid.",
                    comment: "Error shown when the live video preview frame extent is unexpected."
                )
            )
        }
    }

    static func coreImageVideoTransform(
        for preferredTransform: CGAffineTransform,
        sourceExtent: CGRect
    ) -> CGAffineTransform {
        // AVAssetTrack.preferredTransform is expressed in the track's top-left
        // coordinate space. Convert it into Core Image's bottom-left space
        // before rasterizing decoded buffers or portrait clips land 180° off.
        let sourceRect = CGRect(origin: .zero, size: sourceExtent.size)
        let displayedRect = sourceRect.applying(preferredTransform).standardized
        let inputFlip = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -sourceRect.height)
        let outputFlip = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: -displayedRect.height)
        return inputFlip
            .concatenating(preferredTransform)
            .concatenating(outputFlip)
    }

    fileprivate func applyGrade(to image: CIImage, timeSeconds: Double) -> CIImage {
        let params = request.grade.params
        var current = image

        current = applyInputLutStage(to: current)
        current = applyBaseGradeStage(to: current, params: params)
        current = applyToneCompressionStage(to: current, params: params)
        current = applyEdgeOpticsStage(to: current, params: params)
        current = applyGlowFamilyStage(to: current, params: params)
        current = applyVignetteStage(to: current, params: params)
        current = applyGrainStage(to: current, params: params, timeSeconds: timeSeconds)
        current = applyCreativeLutStage(to: current)
        current = applyPrintStage(to: current, params: params)

        return current.cropped(to: image.extent)
    }

    fileprivate var outputFrameRate: Int {
        request.output.fps
    }

    private func applyInputLutStage(to image: CIImage) -> CIImage {
        guard let preparedInputLut else {
            return image
        }
        return applyLut(preparedInputLut, to: image)
    }

    private func applyBaseGradeStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let epsilon = 0.0001
        guard
            abs(params.exposure) > epsilon ||
            abs(params.contrast - 1.0) > epsilon ||
            abs(params.saturation - 1.0) > epsilon ||
            abs(params.temperature) > epsilon ||
            abs(params.tint) > epsilon ||
            abs(params.fade) > epsilon
        else {
            return image
        }

        guard let kernel = OpticalKernels.baseGrade else {
            return image
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.exposure,
            params.contrast,
            params.saturation,
            params.temperature,
            params.tint,
            params.fade,
        ]) ?? image
    }

    private func applyToneCompressionStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        guard params.compressionAmount > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.filmCompression else {
            return image
        }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.compressionAmount,
            params.compressionRange,
        ]) ?? image
    }

    private func applyEdgeOpticsStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        var current = image

        if params.rgbShift > 0.0001 {
            current = applyRadialRGBShift(params.rgbShift, to: current)
        }

        let rgbShiftNormalized = Self.clamp(
            params.rgbShift / max(FilmtonePhase0Generated.rgbShiftMax, 0.0001)
        )
        let aberrationSoften = Self.aberrationEdgeSoften(for: rgbShiftNormalized)
        if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
            current = applyEdgeSoftness(
                to: current,
                aberrationSoften: aberrationSoften,
                lensSoftness: params.lensSoftness
            )
        }

        return current
    }

    private func applyGlowFamilyStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let extent = image.extent
        let black = Self.blackImage(for: extent)

        let bloomImage: CIImage
        if params.bloomStrength > 0.0001 {
            let bloomPlate = extractHighlightPlate(
                from: image,
                threshold: params.bloomThreshold,
                knee: params.bloomSoftKnee,
                tintColor: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
            bloomImage = buildMipBlurComposite(
                from: bloomPlate,
                radius: params.bloomRadius,
                levelCount: Self.bloomMipLevels,
                spreadMultiplier: Self.bloomSpreadBoost,
                useTentResampling: true
            )
        } else {
            bloomImage = black
        }

        let halationImage: CIImage
        if params.halationIntensity > 0.0001 {
            let halationPlate = extractHighlightPlate(
                from: image,
                threshold: params.halationThreshold,
                knee: params.halationSoftKnee,
                tintColor: Self.halationColor(for: params.halationHue)
            )
            halationImage = buildMipBlurComposite(
                from: halationPlate,
                radius: params.halationRadius,
                levelCount: Self.halationMipLevels,
                spreadMultiplier: 1.0 + max(params.halationSpread, 0) / Self.halationSpreadDivisor,
                useTentResampling: true
            )
        } else {
            halationImage = black
        }

        let diffusionImage: CIImage
        if params.diffusion > 0.0001 {
            diffusionImage = buildMipBlurComposite(
                from: image,
                radius: 0.9,
                levelCount: Self.diffusionMipLevels,
                spreadMultiplier: 1.15,
                useTentResampling: true
            )
        } else {
            diffusionImage = black
        }

        guard
            params.bloomStrength > 0.0001 ||
            params.halationIntensity > 0.0001 ||
            params.diffusion > 0.0001
        else {
            return image
        }

        guard let kernel = OpticalKernels.glowComposite else {
            return image
        }

        return kernel.apply(extent: extent, arguments: [
            image,
            bloomImage,
            halationImage,
            diffusionImage,
            params.bloomStrength,
            params.halationIntensity,
            params.diffusion,
            Self.diffusionCompositeBase,
        ]) ?? image
    }

    private func applyVignetteStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        guard params.vignette > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.vignette else {
            return image
        }

        let optics = request.sourceProbe?.cameraOptics
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsPack = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        // Mask only activates on trustworthy lens metadata — `"assumed"` /
        // nil / `"fallback65"` sources keep vignette byte-identical with
        // pre-Stream-2 output. Gamma / inner come from the shared contract
        // defaults so the ray-angle math stays locked to SSOT rather than
        // Swift-side constants.
        let applyMask: Double = (optics?.source == "metadata") ? 1.0 : 0.0
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let innerThreshold = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.vignette,
            Self.extentOriginVector(for: image.extent),
            Self.extentSizeVector(for: image.extent),
            gamma,
            innerThreshold,
            opticsPack,
            applyMask,
        ]) ?? image
    }

    private func applyGrainStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        timeSeconds: Double
    ) -> CIImage {
        let grainIntensity = max(0, min(FilmtonePhase0Generated.grainIntensityMax, params.grainIntensity))
        guard grainIntensity > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.grain else {
            return image
        }
        let normalizedTime = timeSeconds.isFinite ? max(timeSeconds, 0) : 0
        return kernel.apply(extent: image.extent, arguments: [
            image,
            grainIntensity,
            params.grainRadialMix,
            params.grainSize,
            normalizedTime,
            sourceSeed,
            Self.extentOriginVector(for: image.extent),
            Self.extentSizeVector(for: image.extent),
        ]) ?? image
    }

    private func applyCreativeLutStage(to image: CIImage) -> CIImage {
        guard let preparedCreativeLut else {
            return image
        }
        return applyLut(preparedCreativeLut, to: image)
    }

    private func applyPrintStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let epsilon = 0.0001
        guard
            params.printContrast > epsilon ||
            abs(params.cyan) > epsilon ||
            abs(params.magenta) > epsilon ||
            abs(params.yellow) > epsilon
        else {
            return image
        }

        guard let kernel = OpticalKernels.printStage else {
            return image
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.printContrast,
            params.cyan,
            params.magenta,
            params.yellow,
        ]) ?? image
    }

    private func applyLut(_ lut: PreparedLut, to image: CIImage) -> CIImage {
        let lutImage = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": lut.size,
            "inputCubeData": lut.cubeData,
            "inputColorSpace": outputColorSpace,
        ])

        guard lut.intensity < 0.999 else {
            return lutImage
        }

        let alphaAdjusted = lutImage.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: lut.intensity),
        ])
        return alphaAdjusted
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)
    }

    private func extractHighlightPlate(
        from image: CIImage,
        threshold: Double,
        knee: Double,
        tintColor: CIColor
    ) -> CIImage {
        guard let kernel = OpticalKernels.softKneeHighlight else {
            return Self.blackImage(for: image.extent)
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            Self.clamp(threshold),
            Self.clamp(knee),
            tintColor,
        ]) ?? Self.blackImage(for: image.extent)
    }

    private func applyRadialRGBShift(_ amount: Double, to image: CIImage) -> CIImage {
        guard let kernel = OpticalKernels.radialRGBSplit else {
            return image
        }

        let padding = CGFloat(max(4.0, abs(amount) * max(image.extent.width, image.extent.height)))
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in
                rect.insetBy(dx: -padding, dy: -padding)
            },
            arguments: [
                image,
                amount,
                Self.extentOriginVector(for: image.extent),
                Self.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func applyEdgeSoftness(
        to image: CIImage,
        aberrationSoften: Double,
        lensSoftness: Double
    ) -> CIImage {
        let lensDrive = pow(Self.clamp(lensSoftness), 0.78)
        let aberrationDrive = pow(
            Self.clamp(aberrationSoften / Self.aberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = min(
            Self.lerp(
                Self.aberrationBlurRadiusMin,
                Self.aberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * Self.lensSoftnessBlurBoost),
            Self.aberrationBlurRadiusCap
        )
        guard blurRadius > 0.0001, let kernel = OpticalKernels.edgeSoftnessBlend else {
            return image
        }

        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurRadius,
            ])
            .cropped(to: image.extent)

        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect },
            arguments: [
                image,
                blurred,
                Self.clamp(aberrationSoften),
                Self.clamp(lensSoftness),
                Self.extentOriginVector(for: image.extent),
                Self.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func buildMipBlurComposite(
        from image: CIImage,
        radius: Double,
        levelCount: Int,
        spreadMultiplier: Double,
        useTentResampling: Bool = false
    ) -> CIImage {
        let extent = image.extent.integral
        guard levelCount > 0 else {
            return Self.blackImage(for: extent)
        }

        var mips = Self.buildMipPyramid(
            from: image,
            levelCount: levelCount,
            initialScale: Self.glowBaseScale / max(spreadMultiplier, 0.0001),
            useTentResampling: useTentResampling
        )
        guard !mips.isEmpty else {
            return Self.blackImage(for: extent)
        }

        let weights = Self.computeMipWeights(radius: Self.clamp(radius), levels: mips.count)
        if mips.count > 1 {
            for index in stride(from: mips.count - 2, through: 0, by: -1) {
                let lowRes = mips[index + 1]
                let highRes = mips[index]
                let restored = useTentResampling
                    ? Self.tentUpsampledImage(lowRes, to: highRes.extent)
                    : Self.upsampledImage(lowRes, to: highRes.extent)
                let weighted = Self.weightedImage(restored, weight: weights[index + 1])
                mips[index] = Self.addImages(weighted, highRes).cropped(to: highRes.extent)
            }
        }

        let output = useTentResampling
            ? Self.tentUpsampledImage(mips[0], to: extent)
            : Self.upsampledImage(mips[0], to: extent)
        return output.cropped(to: extent)
    }

    private static func buildMipPyramid(
        from image: CIImage,
        levelCount: Int,
        initialScale: Double,
        useTentResampling: Bool = false
    ) -> [CIImage] {
        guard levelCount > 0 else {
            return []
        }

        var mips: [CIImage] = []
        var current = useTentResampling
            ? tentDownsampledImage(image, scale: initialScale)
            : downsampledImage(image, scale: initialScale)
        mips.append(current)

        guard levelCount > 1 else {
            return mips
        }

        for _ in 1..<levelCount {
            current = useTentResampling
                ? tentDownsampledImage(current, scale: 0.5)
                : downsampledImage(current, scale: 0.5)
            mips.append(current)
        }

        return mips
    }

    private static func downsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let targetSize = CGSize(
            width: max(1.0, round(image.extent.width * safeScale)),
            height: max(1.0, round(image.extent.height * safeScale))
        )
        let scaled = scaledImage(image, scale: safeScale)
        return scaled.cropped(to: CGRect(origin: .zero, size: targetSize))
    }

    private static func upsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }

        let scale = extent.width / image.extent.width
        let upsampled = scaledImage(image, scale: scale).cropped(to: extent)
        guard scale > 1.0001, glowUpsampleBlurRadius > 0.0001 else {
            return upsampled
        }

        return upsampled
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: glowUpsampleBlurRadius,
            ])
            .cropped(to: extent)
    }

    private static func tentDownsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let sourceExtent = image.extent.integral
        let targetSize = CGSize(
            width: max(1.0, round(sourceExtent.width * safeScale)),
            height: max(1.0, round(sourceExtent.height * safeScale))
        )
        let targetExtent = CGRect(origin: .zero, size: targetSize)

        guard let kernel = OpticalKernels.tentDownsample else {
            return downsampledImage(image, scale: scale)
        }

        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        )?.cropped(to: targetExtent) ?? downsampledImage(image, scale: scale)
    }

    private static func tentUpsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }
        let sourceExtent = image.extent.integral
        let targetExtent = extent.integral

        guard let kernel = OpticalKernels.tentUpsample else {
            return upsampledImage(image, to: extent)
        }

        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        )?.cropped(to: targetExtent) ?? upsampledImage(image, to: extent)
    }

    private static func scaledImage(_ image: CIImage, scale: Double) -> CIImage {
        guard abs(scale - 1.0) > 0.0001 else {
            return image
        }
        return image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0,
        ])
    }

    private static func weightedImage(_ image: CIImage, weight: Double) -> CIImage {
        guard weight > 0 else {
            return blackImage(for: image.extent)
        }
        guard abs(weight - 1.0) > 0.0001 else {
            return image
        }
        let vector = CIVector(x: weight, y: 0, z: 0, w: 0)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": vector,
            "inputGVector": CIVector(x: 0, y: weight, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: weight, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": zero,
        ])
    }

    private static func addImages(_ foreground: CIImage, _ background: CIImage) -> CIImage {
        foreground
            .applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: background,
            ])
            .cropped(to: background.extent)
    }

    private static func blackImage(for extent: CGRect) -> CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
    }

    private static func extentOriginVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.origin.x, y: extent.origin.y)
    }

    private static func extentSizeVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.width, y: extent.height)
    }

    private static func computeMipWeights(radius: Double, levels: Int) -> [Double] {
        (0..<levels).map { index in
            let t = Double(index) / Double(max(levels - 1, 1))
            let base = exp(-3.0 * (1.0 - radius) * t)
            let wide = exp(-0.5 * radius * (1.0 - t))
            return (base * (1.0 - radius)) + (wide * radius)
        }
    }

    private static func halationColor(for hue: Double) -> CIColor {
        let t = clamp(hue / 100.0)
        let red = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
        let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
        let blue = (0x20 + ((0x10 - 0x20) * t)) / 255.0
        return CIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func aberrationEdgeSoften(for normalizedRgbShift: Double) -> Double {
        let normalized = clamp(normalizedRgbShift)
        guard normalized > 0.0001 else {
            return 0
        }

        let linear = normalized * (aberrationEdgeSoftenScale * FilmtonePhase0Generated.rgbShiftMax)
        let boosted = pow(normalized, aberrationEdgeSoftenCurve) * aberrationEdgeSoftenMax
        return min(aberrationEdgeSoftenMax, max(linear, boosted))
    }

    private static func makeStableSourceSeed(from string: String) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 8_192)
    }

    private static func clamp(_ value: Double, min minValue: Double = 0, max maxValue: Double = 1) -> Double {
        min(max(value, minValue), maxValue)
    }

    private static func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + ((end - start) * t)
    }

    private func appendVideoSample(
        _ sampleBuffer: CMSampleBuffer,
        videoInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoTrack: AVAssetTrack,
        outputSize: CGSize,
        waitForReady: Bool = true
    ) throws -> Bool {
        try autoreleasepool { () throws -> Bool in
            if waitForReady {
                try waitUntilReadyForMoreMediaData(videoInput, writer: writer, reader: reader, label: "video")
            }

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return false
            }
            guard let pixelBufferPool = adaptor.pixelBufferPool else {
                throw FilmtoneMediaError.exportFailed("Pixel buffer pool is unavailable.")
            }

            let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let presentationTimeSec = CMTimeGetSeconds(presentationTime)
            let frameImage = renderableImage(
                from: imageBuffer,
                transform: videoTrack.preferredTransform,
                outputSize: outputSize,
                timeSeconds: presentationTimeSec.isFinite ? presentationTimeSec : 0
            )

            var renderedBuffer: CVPixelBuffer?
            let creationStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &renderedBuffer)
            guard creationStatus == kCVReturnSuccess, let renderedBuffer else {
                throw FilmtoneMediaError.exportFailed("A render pixel buffer could not be created.")
            }

            ciContext.render(
                frameImage,
                to: renderedBuffer,
                bounds: CGRect(origin: .zero, size: outputSize),
                colorSpace: outputColorSpace
            )
            attachRec709Metadata(to: renderedBuffer)

            if !adaptor.append(renderedBuffer, withPresentationTime: presentationTime) {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The frame could not be appended.")
            }

            return true
        }
    }

    private func appendAudioSample(
        _ sampleBuffer: CMSampleBuffer,
        audioInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        waitForReady: Bool = true
    ) throws {
        try autoreleasepool {
            if waitForReady {
                try waitUntilReadyForMoreMediaData(audioInput, writer: writer, reader: reader, label: "audio")
            }

            if !audioInput.append(sampleBuffer) {
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "Audio samples could not be appended.")
            }
        }
    }

    private func finish(writer: AVAssetWriter) throws {
        try checkCancelled()

        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting {
            semaphore.signal()
        }
        let waitResult = semaphore.wait(timeout: .now() + 30)
        if waitResult == .timedOut {
            writer.cancelWriting()
            throw FilmtoneMediaError.exportFailed("The writer did not finish output within the expected time.")
        }

        try checkCancelled()

        guard writer.status == .completed else {
            throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The export did not complete.")
        }
    }

    private func estimatedVideoFrameRate(for track: AVAssetTrack) -> Double {
        if let frameRate = request.sourceProbe?.frameRate, frameRate.isFinite, frameRate > 0 {
            return frameRate
        }
        let nominalFrameRate = Double(track.nominalFrameRate)
        if nominalFrameRate.isFinite, nominalFrameRate > 0 {
            return nominalFrameRate
        }
        return Double(request.output.fps)
    }

    private func renderingProgress(
        presentationTime: CMTime,
        sourceDurationSec: Double
    ) -> Double {
        guard sourceDurationSec.isFinite, sourceDurationSec > 0 else {
            return 0.12
        }
        let presentationSec = CMTimeGetSeconds(presentationTime)
        guard presentationSec.isFinite else {
            return 0.12
        }
        let normalized = min(max(presentationSec / sourceDurationSec, 0), 1)
        return 0.12 + (normalized * 0.74)
    }

    private func makePreviewPosterTime(sourceDurationSec: Double) -> Double {
        guard sourceDurationSec.isFinite, sourceDurationSec > 0 else {
            return 0
        }
        let candidate = sourceDurationSec * 0.25
        return min(max(candidate, 0), sourceDurationSec)
    }

    private func waitUntilReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader? = nil,
        label: String
    ) throws {
        let startedWaitingAt = Date()
        while !input.isReadyForMoreMediaData {
            try checkCancelled()

            if let reader {
                switch reader.status {
                case .failed:
                    throw FilmtoneMediaError.exportFailed(reader.error?.localizedDescription ?? "The reader failed while waiting for media data.")
                case .cancelled:
                    throw FilmtoneMediaError.exportCancelled
                default:
                    break
                }
            }

            switch writer.status {
            case .failed:
                throw FilmtoneMediaError.exportFailed(writer.error?.localizedDescription ?? "The writer failed while waiting for media data.")
            case .cancelled:
                throw FilmtoneMediaError.exportCancelled
            case .completed:
                throw FilmtoneMediaError.exportFailed("The writer completed before all media data was appended.")
            default:
                break
            }

            if Date().timeIntervalSince(startedWaitingAt) >= 15 {
                throw FilmtoneMediaError.exportFailed("The \(label) writer input stopped accepting media data.")
            }

            Thread.sleep(forTimeInterval: 0.002)
        }
    }

    private func checkCancelled() throws {
        if cancelled {
            throw FilmtoneMediaError.exportCancelled
        }
    }

    private func writePreviewImage(_ image: CIImage, preferredName: String) throws -> URL {
        let url = try cacheStore.temporaryPreviewURL(preferredName: preferredName, pathExtension: "jpg")
        guard let data = ciContext.jpegRepresentation(
            of: image,
            colorSpace: outputColorSpace,
            options: [:]
        ) else {
            throw FilmtoneMediaError.exportFailed("Preview JPEG data could not be created.")
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func loadedSourceImage(at url: URL) -> CIImage? {
        CIImage(contentsOf: url, options: [
            .applyOrientationProperty: true,
            .toneMapHDRtoSDR: true,
        ])
    }

    private func sourceVideoImage(from imageBuffer: CVPixelBuffer) -> CIImage {
        let options: [CIImageOption: Any] = shouldToneMapHDRToSDR(imageBuffer)
            ? [.toneMapHDRtoSDR: true]
            : [:]
        return CIImage(cvPixelBuffer: imageBuffer, options: options)
    }

    private func sourcePreviewVideoImage(from image: CIImage) -> CIImage {
        // AVVideoComposition already provides this image in presentation
        // orientation. Rewrapping its backing pixel buffer drops that transform
        // and makes portrait clips preview as raw landscape frames.
        return image
    }

    private func shouldToneMapHDRToSDR(_ imageBuffer: CVPixelBuffer) -> Bool {
        guard let transferFunction = CVBufferGetAttachment(
            imageBuffer,
            kCVImageBufferTransferFunctionKey,
            nil
        )?.takeUnretainedValue() else {
            return false
        }

        return CFEqual(transferFunction, kCVImageBufferTransferFunction_ITU_R_2100_HLG) ||
            CFEqual(transferFunction, kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ)
    }

    private func attachRec709Metadata(to imageBuffer: CVPixelBuffer) {
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferColorPrimaries_ITU_R_709_2,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferTransferFunction_ITU_R_709_2,
            .shouldPropagate
        )
        CVBufferSetAttachment(
            imageBuffer,
            kCVImageBufferYCbCrMatrixKey,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2,
            .shouldPropagate
        )
    }

    private static func makePreparedLut(from lut: SerializableLutDTO?) -> PreparedLut? {
        guard let lut, lut.size > 1, !lut.data.isEmpty else {
            return nil
        }

        let floatData = rgbaCubeData(from: lut.data, size: lut.size)
        let cubeData = floatData.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }

        return PreparedLut(
            size: lut.size,
            intensity: lut.intensity,
            cubeData: cubeData
        )
    }

    private static func makeAutomaticInputLut(for policy: SourceInputTransformPolicyDTO?) -> PreparedLut? {
        switch policy?.strategy {
        case .appleLogToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        case .appleLog2ToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        default:
            return nil
        }
    }

    private static func rgbaCubeData(from data: [Double], size: Int) -> [Float] {
        let expectedRGBCount = size * size * size * 3
        let expectedRGBACount = size * size * size * 4
        if data.count == expectedRGBACount {
            return data.map(Float.init)
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(expectedRGBACount)
        let count = min(data.count, expectedRGBCount)
        var index = 0
        while index < count {
            rgba.append(Float(data[index]))
            rgba.append(Float(index + 1 < count ? data[index + 1] : 0))
            rgba.append(Float(index + 2 < count ? data[index + 2] : 0))
            rgba.append(1)
            index += 3
        }

        while rgba.count < expectedRGBACount {
            rgba.append(0)
            rgba.append(0)
            rgba.append(0)
            rgba.append(1)
        }
        return rgba
    }

    private static func makeAppleLogToRec709Lut(size: Int, rec2020GamutMap: Bool) -> PreparedLut? {
        guard size > 1 else {
            return nil
        }

        var values: [Float] = []
        values.reserveCapacity(size * size * size * 4)
        for blueIndex in 0..<size {
            let blue = Double(blueIndex) / Double(size - 1)
            for greenIndex in 0..<size {
                let green = Double(greenIndex) / Double(size - 1)
                for redIndex in 0..<size {
                    let red = Double(redIndex) / Double(size - 1)
                    let converted = appleLogPixelToRec709(
                        red: red,
                        green: green,
                        blue: blue,
                        rec2020GamutMap: rec2020GamutMap
                    )
                    values.append(Float(converted.red))
                    values.append(Float(converted.green))
                    values.append(Float(converted.blue))
                    values.append(1)
                }
            }
        }

        let cubeData = values.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }
        return PreparedLut(size: size, intensity: 1, cubeData: cubeData)
    }

    private static func appleLogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double,
        rec2020GamutMap: Bool
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = appleLogDecode(red)
        let linearGreen = appleLogDecode(green)
        let linearBlue = appleLogDecode(blue)

        let mapped: (red: Double, green: Double, blue: Double)
        if rec2020GamutMap {
            mapped = rec2020ToRec709(red: linearRed, green: linearGreen, blue: linearBlue)
        } else {
            mapped = (linearRed, linearGreen, linearBlue)
        }

        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    private static func appleLogDecode(_ encoded: Double) -> Double {
        let r0 = -0.05641088
        let rt = 0.01
        let sigma = 47.28711236
        let beta = 0.00964052
        let gamma = 0.08550479
        let delta = 0.69336945
        let pt = sigma * pow(rt - r0, 2)

        if encoded >= pt {
            return pow(2, (encoded - delta) / gamma) - beta
        }
        if encoded >= 0 {
            return sqrt(max(encoded / sigma, 0)) + r0
        }
        return r0
    }

    private static func rec2020ToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red: 1.6605 * red - 0.5876 * green - 0.0728 * blue,
            green: -0.1246 * red + 1.1329 * green - 0.0083 * blue,
            blue: -0.0182 * red - 0.1006 * green + 1.1187 * blue
        )
    }

    private static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        let exposed = max(0, linear * 1.18)
        let shoulder = exposed / (1 + max(exposed - 0.18, 0) * 0.42)
        return clamp(shoulder, min: 0, max: 1)
    }

    private static func rec709Encode(_ linear: Double) -> Double {
        let value = clamp(linear, min: 0, max: 1)
        if value < 0.018 {
            return value * 4.5
        }
        return 1.099 * pow(value, 0.45) - 0.099
    }

    private func resolvedVideoSourceURL() -> URL {
        // v1.2 HDR-aware mezzanine + Speed/Quality toggle (plan §6.3).
        //
        // - .quality (default): only HDR mezzanine is allowed as a faster path because it
        //   preserves wide-gamut color fidelity. SDR mezzanine is intentionally NOT a
        //   fallback — silent SDR substitution would degrade Quality output. SDR sources
        //   stay on source-direct read so the cinematic-100 path is byte-identical to v1.1.
        // - .speed: explicit user opt-in. Any cached mezzanine is acceptable; HDR is
        //   preferred when both exist.
        // - In all cases, when no acceptable mezzanine exists we fall back to the source
        //   URL as the single explicit alternative (no silent degradation).
        let mode = request.renderMode ?? .quality
        guard let mezz = mezzanineService else { return sourceURL }
        switch mode {
        case .quality:
            return mezz.existingMezzanineURL(for: sourceURL, variant: .hdr) ?? sourceURL
        case .speed:
            return mezz.existingMezzanineURL(for: sourceURL, variant: .hdr)
                ?? mezz.existingMezzanineURL(for: sourceURL, variant: .sdr)
                ?? sourceURL
        }
    }

    static func scaledSize(for track: AVAssetTrack, longEdge: Int) -> CGSize {
        let transformed = track.naturalSize.applying(track.preferredTransform)
        let sourceSize = CGSize(width: abs(transformed.width), height: abs(transformed.height))
        return scaledSize(for: sourceSize, longEdge: longEdge)
    }

    static func scaledSize(for sourceSize: CGSize, longEdge: Int) -> CGSize {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return CGSize(width: longEdge, height: longEdge)
        }

        let maxEdge = max(sourceSize.width, sourceSize.height)
        let scale = min(CGFloat(longEdge) / maxEdge, 1.0)
        let width = max(2, Int((sourceSize.width * scale).rounded()) / 2 * 2)
        let height = max(2, Int((sourceSize.height * scale).rounded()) / 2 * 2)
        return CGSize(width: width, height: height)
    }
}

private struct CompletedExport {
    let outputSize: CGSize
    let frameCount: Int
    let sourceDurationSec: Double?
    let audioPreserved: Bool
}

final class FilmtoneSharedGradeProcessor {
    private let session: FilmtoneExportSession

    init(session: FilmtoneExportSession) {
        self.session = session
    }

    func makeVideoComposition(
        asset: AVAsset,
        videoTrack _: AVAssetTrack,
        outputSize: CGSize
    ) -> AVMutableVideoComposition {
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { [session] request in
                do {
                    let timeSeconds = CMTimeGetSeconds(request.compositionTime)
                    let processed = try session.renderablePreviewVideoImage(
                        from: request.sourceImage,
                        outputSize: outputSize,
                        timeSeconds: timeSeconds.isFinite ? timeSeconds : 0
                    )
                    request.finish(with: processed, context: nil)
                } catch {
                    filmtonePreviewCompositionDebugLog(
                        "live composition frame failed at \(CMTimeGetSeconds(request.compositionTime))s: \(error.localizedDescription)"
                    )
                    request.finish(with: error)
                }
            }
        )
        composition.renderSize = outputSize
        composition.frameDuration = CMTime(
            value: 1,
            timescale: CMTimeScale(max(1, session.outputFrameRate))
        )
        return composition
    }
}

private func filmtonePreviewCompositionDebugLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[FilmtonePreview][Composition] \(message())")
    #endif
}

extension ISO8601DateFormatter {
    /// Shared formatter used by the export sidecar writer. Configured to emit
    /// millisecond-precision UTC stamps (e.g. `2026-04-24T12:00:00.000Z`).
    static let filmtoneSidecar: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct PreparedLut {
    let size: Int
    let intensity: Double
    let cubeData: Data
}

private enum OpticalKernels {
    static let baseGrade = CIColorKernel(source: """
kernel vec4 baseGrade(__sample image, float exposure, float contrast, float saturation, float temperature, float tint, float fade) {
    vec4 color = image;
    color.rgb *= pow(2.0, exposure);
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    color.rgb = mix(vec3(luma), color.rgb, saturation);
    color.r += temperature * 0.1;
    color.b -= temperature * 0.1;
    color.r += tint * 0.05;
    color.g -= tint * 0.08;
    color.b += tint * 0.05;
    color.rgb = color.rgb + fade * (1.0 - color.rgb);
    return color;
}
""")

    static let filmCompression = CIColorKernel(source: """
kernel vec4 filmCompression(__sample image, float amount, float range) {
    vec4 color = image;
    if (amount < 0.001) {
        return color;
    }
    float r = clamp(range, 0.0, 1.0);
    float k = mix(5.15, 2.85, r);
    float rangeSoft = smoothstep(0.82, 1.0, r);
    float amt = amount * (1.0 - 0.18 * rangeSoft);
    float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
    float x = clamp(k * (luma - 0.5), -5.5, 5.5);
    float s = 1.0 / (1.0 + exp(-x));
    float scale = luma > 0.001 ? mix(luma, s, amt) / luma : 1.0;
    color.rgb = clamp(color.rgb * scale, 0.0, 1.0);
    return color;
}
""")

    static let printStage = CIColorKernel(source: """
vec3 applyPrintContrast(vec3 rgb, float amount) {
    if (amount < 0.001) {
        return rgb;
    }
    float k = mix(1.0, 5.0, amount);
    vec3 s = 1.0 / (1.0 + exp(-k * (rgb - 0.5)));
    return clamp(mix(rgb, s, amount), 0.0, 1.0);
}

kernel vec4 printStage(__sample image, float printContrast, float cyan, float magenta, float yellow) {
    vec4 color = image;
    float cmyScale = 0.15;
    color.r -= cyan * cmyScale;
    color.g -= magenta * cmyScale;
    color.b -= yellow * cmyScale;
    color.rgb = applyPrintContrast(color.rgb, printContrast);
    return vec4(clamp(color.rgb, 0.0, 1.0), image.a);
}
""")

    static let softKneeHighlight = CIColorKernel(source: """
kernel vec4 softKneeHighlight(__sample image, float threshold, float knee, __color tintColor) {
    float luma = dot(image.rgb, vec3(0.2126, 0.7152, 0.0722));
    float safeThreshold = max(threshold, 1e-4);
    float safeKnee = max(knee * safeThreshold, 1e-4);
    float t = clamp((luma - threshold + safeKnee) / (2.0 * safeKnee), 0.0, 1.0);
    float contribution = t * t * mix(safeKnee, 1.0, t);
    contribution = max(contribution, max(0.0, luma - threshold));
    return vec4(image.rgb * contribution * tintColor.rgb, image.a);
}
""")

    static let glowComposite = CIColorKernel(source: """
vec3 glowShoulder(vec3 energy) {
    return 1.0 - exp(-max(energy, vec3(0.0)));
}

float glowHeadroom(vec3 baseRgb, float floorValue) {
    float luma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));
    return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));
}

kernel vec4 glowComposite(__sample base, __sample bloom, __sample halation, __sample diffusionImage, float bloomStrength, float halationIntensity, float diffusionAmount, float diffusionBase) {
    vec3 baseRgb = base.rgb;
    vec3 result = baseRgb;
    vec3 glowEnergy = bloom.rgb * bloomStrength + halation.rgb * halationIntensity;
    vec3 glow = glowShoulder(glowEnergy) * glowHeadroom(baseRgb, 0.82);
    result = result + min(glow, max(vec3(0.0), vec3(1.0) - result));

    if (diffusionAmount > 0.0) {
        vec3 diffOpacity = glowShoulder(diffusionImage.rgb * diffusionAmount * diffusionBase) * glowHeadroom(baseRgb, 0.88);
        result = result + min(diffOpacity, max(vec3(0.0), vec3(1.0) - result));
    }

    return vec4(clamp(result, 0.0, 1.0), base.a);
}
""")

    // Vignette kernel with optional ray-angle field mask (T3, Stream 2, v1.1).
    //
    // `opticsPack` = vec3(tanHalfFovX, tanHalfFovY, referenceIncidence).
    // `applyMask` is 1.0 only when `cameraOptics.source == "metadata"`;
    // for `"assumed"` / nil / fallback65 sources it stays 0.0.
    //
    // Math note: the mask must modulate the *darkening amount*, not the final
    // pixel multiplier. At the center `mask = 0` (no edge falloff); applying
    // that as a final multiplier would drive the center to black. Instead we
    // fold the mask into `intensity * dist^2` so the center always stays
    // untouched (`vig = 1.0`) and only the edge falloff is scaled by
    // optics-aware weight. When `applyMask = 0`, `effectiveMask = 1.0` and
    // the formula collapses to the original `1 - intensity * dist^2`,
    // byte-identical with pre-Stream-2 output.
    static let vignette = CIColorKernel(source: """
kernel vec4 vignette(__sample image, float intensity, vec2 extentOrigin, vec2 extentSize, float rayAngleGamma, float rayAngleInner, vec3 opticsPack, float applyMask) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    float dist = length(uv - vec2(0.5, 0.5)) * 1.414;

    vec2 sensor = (uv - vec2(0.5, 0.5)) * 2.0;
    float rayX = sensor.x * opticsPack.x;
    float rayY = sensor.y * opticsPack.y;
    float viewZ = 1.0 / sqrt(rayX * rayX + rayY * rayY + 1.0);
    float incidence = 1.0 - viewZ;
    float refIncidence = max(opticsPack.z, 1.0e-5);
    float normalized = clamp(incidence / refIncidence, 0.0, 1.0);
    float gammaSafe = max(rayAngleGamma, 0.001);
    float innerSafe = clamp(rayAngleInner, 0.0, 0.8);
    float shaped = pow(normalized, gammaSafe);
    float t = clamp((shaped - innerSafe) / max(1.0 - innerSafe, 1.0e-6), 0.0, 1.0);
    float mask = t * t * (3.0 - 2.0 * t);
    float effectiveMask = mix(1.0, mask, clamp(applyMask, 0.0, 1.0));

    float vig = 1.0 - intensity * dist * dist * effectiveMask;
    color.rgb *= clamp(vig, 0.0, 1.0);
    return color;
}
""")

    static let grain = CIColorKernel(source: """
float grainPixelHash(vec2 p, float seed) {
    return fract(sin(dot(p + vec2(seed, seed * 0.73), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

float grainClumpHash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float grainClumpNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = grainClumpHash(i);
    float b = grainClumpHash(i + vec2(1.0, 0.0));
    float c = grainClumpHash(i + vec2(0.0, 1.0));
    float d = grainClumpHash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

kernel vec4 grain(__sample image, float intensity, float radialMix, float grainSize, float timeSeconds, float sourceSeed, vec2 extentOrigin, vec2 extentSize) {
    vec4 color = image;
    vec2 uv = (destCoord() - extentOrigin) / extentSize;
    vec2 grainDelta = uv - vec2(0.5, 0.5);
    grainDelta.x *= extentSize.x / max(extentSize.y, 1.0);
    float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
    float grainRadialWeight = pow(grainRadial, 1.65);
    float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(radialMix, 0.0, 1.0));

    float grainFrame = floor(max(timeSeconds, 0.0) * 3.0);
    vec2 pixelCoord = uv * extentSize;
    float lumaGrain = grainPixelHash(pixelCoord, grainFrame * 1.7 + sourceSeed * 13.0);
    float chromaR = grainPixelHash(pixelCoord, grainFrame * 2.3 + 500.0 + sourceSeed * 7.0) * 0.3;
    float chromaB = grainPixelHash(pixelCoord, grainFrame * 3.1 + 1000.0 + sourceSeed * 5.0) * 0.3;

    float clumpScale = mix(80.0, 20.0, clamp(grainSize, 0.0, 1.0));
    float clump = grainClumpNoise((uv * extentSize / clumpScale) + vec2(grainFrame * 0.5 + sourceSeed * 0.1, sourceSeed * 0.07));
    float densityMod = mix(1.0, 0.3 + clump * 1.4, clamp(grainSize, 0.0, 1.0) * 0.7);

    float weight = intensity * 0.5 * grainRadialEffective;
    color.r += (lumaGrain + chromaR) * weight * densityMod;
    color.g += lumaGrain * weight * densityMod;
    color.b += (lumaGrain + chromaB) * weight * densityMod;
    color.rgb = clamp(color.rgb, 0.0, 1.0);
    return color;
}
""")

    static let radialRGBSplit = CIKernel(source: """
kernel vec4 radialRGBSplit(sampler image, float amount, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 delta = uv - vec2(0.5, 0.5);
    delta.x *= extentSize.x / max(extentSize.y, 1.0);
    float radial = clamp(length(delta) * 2.0, 0.0, 1.0);
    float weight = pow(radial, 1.65);
    float amt = amount * weight;
    vec2 dir = normalize(delta + vec2(1e-5, 1e-5));
    vec2 offset = vec2(dir.x * amt * extentSize.x, dir.y * amt * extentSize.y);
    vec4 center = sample(image, samplerTransform(image, coord));
    float r = sample(image, samplerTransform(image, coord + offset)).r;
    float b = sample(image, samplerTransform(image, coord - offset)).b;
    return vec4(r, center.g, b, center.a);
}
""")

    static let tentDownsample = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentDownsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 a = sampleMirror(image, sourceCoord + vec2(-2.0,  2.0), sourceOrigin, sourceSize);
    vec4 b = sampleMirror(image, sourceCoord + vec2( 0.0,  2.0), sourceOrigin, sourceSize);
    vec4 c = sampleMirror(image, sourceCoord + vec2( 2.0,  2.0), sourceOrigin, sourceSize);

    vec4 dd = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 e  = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);

    vec4 f = sampleMirror(image, sourceCoord + vec2(-2.0, 0.0), sourceOrigin, sourceSize);
    vec4 g = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 h = sampleMirror(image, sourceCoord + vec2( 2.0, 0.0), sourceOrigin, sourceSize);

    vec4 ii = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 j  = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 k = sampleMirror(image, sourceCoord + vec2(-2.0, -2.0), sourceOrigin, sourceSize);
    vec4 l = sampleMirror(image, sourceCoord + vec2( 0.0, -2.0), sourceOrigin, sourceSize);
    vec4 m = sampleMirror(image, sourceCoord + vec2( 2.0, -2.0), sourceOrigin, sourceSize);

    return ((dd + e + ii + j) * 0.125)
         + (g * 0.125)
         + ((a + c + k + m) * 0.03125)
         + ((b + f + h + l) * 0.0625);
}
""")

    static let tentUpsample = CIKernel(source: """
vec2 mirrorCoord(vec2 coord, vec2 origin, vec2 size) {
    vec2 safeSize = max(size, vec2(1.0, 1.0));
    vec2 uv = (coord - origin) / safeSize;
    vec2 tiled = mod(uv, 2.0);
    vec2 mirroredUv = 1.0 - abs(tiled - 1.0);
    return origin + (mirroredUv * safeSize);
}

vec4 sampleMirror(sampler image, vec2 coord, vec2 origin, vec2 size) {
    return sample(image, samplerTransform(image, mirrorCoord(coord, origin, size)));
}

kernel vec4 tentUpsample(sampler image, vec2 sourceOrigin, vec2 sourceSize, vec2 targetOrigin, vec2 sourceStep) {
    vec2 coord = destCoord();
    vec2 sourceCoord = sourceOrigin + ((coord - targetOrigin) * sourceStep);

    vec4 s  = sampleMirror(image, sourceCoord, sourceOrigin, sourceSize);
    vec4 s0 = sampleMirror(image, sourceCoord + vec2(-1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s1 = sampleMirror(image, sourceCoord + vec2( 0.0,  1.0), sourceOrigin, sourceSize);
    vec4 s2 = sampleMirror(image, sourceCoord + vec2( 1.0,  1.0), sourceOrigin, sourceSize);
    vec4 s3 = sampleMirror(image, sourceCoord + vec2(-1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s4 = sampleMirror(image, sourceCoord + vec2( 1.0,  0.0), sourceOrigin, sourceSize);
    vec4 s5 = sampleMirror(image, sourceCoord + vec2(-1.0, -1.0), sourceOrigin, sourceSize);
    vec4 s6 = sampleMirror(image, sourceCoord + vec2( 0.0, -1.0), sourceOrigin, sourceSize);
    vec4 s7 = sampleMirror(image, sourceCoord + vec2( 1.0, -1.0), sourceOrigin, sourceSize);

    vec4 upsampled = (s * 4.0)
                   + ((s1 + s3 + s4 + s6) * 2.0)
                   + (s0 + s2 + s5 + s7);
    return upsampled / 16.0;
}
""")

    static let edgeSoftnessBlend = CIKernel(source: """
kernel vec4 edgeSoftnessBlend(sampler sharp, sampler blurred, float aberrationSoften, float lensSoftness, vec2 extentOrigin, vec2 extentSize) {
    vec2 coord = destCoord();
    vec2 uv = (coord - extentOrigin) / extentSize;
    vec2 edgeDelta = uv - vec2(0.5, 0.5);
    edgeDelta.x *= extentSize.x / max(extentSize.y, 1.0);
    float edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);
    float edgeMask = smoothstep(0.25, 1.0, edgeR);
    float lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);
    float lensW = pow(lensR, 1.52);
    float lensDrive = pow(clamp(lensSoftness, 0.0, 1.0), 0.78);
    float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
    float lensMix = lensWeight * 0.72;
    float softenAmt = clamp((aberrationSoften * edgeMask) + (lensMix * edgeMask), 0.0, 1.0);
    vec4 sharpSample = sample(sharp, samplerTransform(sharp, coord));
    vec4 blurSample = sample(blurred, samplerTransform(blurred, coord));
    return mix(sharpSample, blurSample, softenAmt);
}
""")
}
