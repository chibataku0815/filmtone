import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

final class FilmtoneExportSession {
    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let outputURL: URL
    private let ciContext: CIContext
    private let preparedInputLut: PreparedLut?
    private let preparedCreativeLut: PreparedLut?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()
    private var cancelled = false

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        cacheStore: CacheStore
    ) throws {
        self.request = request
        self.sourceURL = sourceURL
        self.outputURL = try cacheStore.temporaryExportURL(pathExtension: request.output.container)
        self.ciContext = CIContext(options: [
            .cacheIntermediates: false,
            .priorityRequestLow: false,
        ])
        self.preparedInputLut = Self.makePreparedLut(from: request.inputLut)
        let legacyCreativeLut = request.creativeLut ?? request.lut.map {
            SerializableLutDTO(size: $0.size, data: $0.data, intensity: $0.intensity)
        }
        self.preparedCreativeLut = Self.makePreparedLut(from: legacyCreativeLut)
    }

    func cancel() {
        cancelled = true
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

        return Phase0ExportResultDTO(
            outputUri: outputURL.absoluteString,
            elapsedMs: elapsedMs,
            outputWidth: Int(result.outputSize.width.rounded()),
            outputHeight: Int(result.outputSize.height.rounded()),
            outputFps: request.output.fps,
            fileSizeBytes: fileSizeBytes,
            realtimeRatio: realtimeRatio,
            audioPreserved: result.audioPreserved,
            benchmarkRecord: nil
        )
    }

    private func exportVideo(
        progress: @escaping (Phase0ExportProgressDTO) -> Void
    ) throws -> CompletedExport {
        let asset = AVURLAsset(url: sourceURL)
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
        let videoOutput = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            ]
        )
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw FilmtoneMediaError.exportFailed("Video reader output could not be added.")
        }
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
        guard let image = CIImage(contentsOf: sourceURL, options: [.applyOrientationProperty: true]) else {
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
        let filteredImage = renderableStillImage(image, outputSize: outputSize)
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
                    colorSpace: colorSpace
                )

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
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        input.transform = .identity
        return input
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
        outputSize: CGSize
    ) -> CIImage {
        let image = CIImage(cvPixelBuffer: imageBuffer)
        let oriented = image.transformed(by: transform)
        let normalized = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))

        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let graded = applyGrade(to: scaled.cropped(to: CGRect(origin: .zero, size: outputSize)))
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func renderableStillImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
        let normalized = image.transformed(by: CGAffineTransform(
            translationX: -image.extent.origin.x,
            y: -image.extent.origin.y
        ))
        let scaleX = outputSize.width / normalized.extent.width
        let scaleY = outputSize.height / normalized.extent.height
        let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let graded = applyGrade(to: scaled.cropped(to: CGRect(origin: .zero, size: outputSize)))
        return graded.cropped(to: CGRect(origin: .zero, size: outputSize))
    }

    private func applyGrade(to image: CIImage) -> CIImage {
        var current = image
        let params = request.grade.params

        // Stage 1: input LUT (e.g. log-to-display normalization). Skip if nil.
        if let preparedInputLut {
            current = applyLut(preparedInputLut, to: current)
        }

        // Stage 2: Quick params (exposure / contrast / saturation / temp / tint / fade / vignette / grain).
        if abs(params.exposure) > 0.0001 {
            current = current.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: params.exposure,
            ])
        }

        if abs(params.saturation - 1.0) > 0.0001 || abs(params.contrast - 1.0) > 0.0001 {
            current = current.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: params.saturation,
                kCIInputContrastKey: params.contrast,
            ])
        }

        if abs(params.temperature) > 0.0001 || abs(params.tint) > 0.0001 {
            current = current.applyingFilter("CITemperatureAndTint", parameters: [
                "inputNeutral": CIVector(x: 6500, y: 0),
                "inputTargetNeutral": CIVector(
                    x: 6500 + (params.temperature * 1800),
                    y: params.tint * 150
                ),
            ])
        }

        if params.fade > 0.0001 {
            current = applyFade(params.fade, to: current)
        }

        if params.vignette > 0.0001 {
            current = current.applyingFilter("CIVignette", parameters: [
                kCIInputIntensityKey: params.vignette * 1.2,
                kCIInputRadiusKey: min(current.extent.width, current.extent.height) * 0.55,
            ])
        }

        if params.grainIntensity > 0.0001 {
            current = applyGrain(params.grainIntensity, to: current)
        }

        // Stage 3: creative LUT (signature look). Skip if nil.
        if let preparedCreativeLut {
            current = applyLut(preparedCreativeLut, to: current)
        }

        return current
    }

    private func applyLut(_ lut: PreparedLut, to image: CIImage) -> CIImage {
        let lutImage = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": lut.size,
            "inputCubeData": lut.cubeData,
            "inputColorSpace": colorSpace,
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

    private func applyFade(_ fade: Double, to image: CIImage) -> CIImage {
        let overlay = CIImage(color: CIColor(
            red: 0.95,
            green: 0.93,
            blue: 0.9,
            alpha: CGFloat(min(max(fade * 0.12, 0), 0.2))
        ))
        .cropped(to: image.extent)

        let softened = overlay
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)

        return softened.applyingFilter("CIColorControls", parameters: [
            kCIInputBrightnessKey: fade * 0.02,
            kCIInputContrastKey: max(0.78, 1 - (fade * 0.18)),
        ])
    }

    private func applyGrain(_ intensity: Double, to image: CIImage) -> CIImage {
        guard let noise = CIFilter(name: "CIRandomGenerator")?.outputImage else {
            return image
        }

        let monochrome = noise
            .cropped(to: image.extent)
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0,
            ])

        let alphaAdjusted = monochrome.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: intensity * 0.08),
        ])

        return alphaAdjusted
            .applyingFilter("CISoftLightBlendMode", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)
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
            let frameImage = renderableImage(
                from: imageBuffer,
                transform: videoTrack.preferredTransform,
                outputSize: outputSize
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
                colorSpace: colorSpace
            )

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

    private static func makePreparedLut(from lut: SerializableLutDTO?) -> PreparedLut? {
        guard let lut, lut.size > 1, !lut.data.isEmpty else {
            return nil
        }

        let floatData = lut.data.map(Float.init)
        let cubeData = floatData.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }

        return PreparedLut(
            size: lut.size,
            intensity: lut.intensity,
            cubeData: cubeData
        )
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

private struct PreparedLut {
    let size: Int
    let intensity: Double
    let cubeData: Data
}
