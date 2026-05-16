import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
import FilmLabSwiftCore
import Foundation

enum FilmtoneVideoCodec: String, Sendable {
    case h264
    // Phase 1c+ option per master handoff §13 #2 (ProRes is "option" — not
    // implemented in this slice; surfaced here so callers can opt into the
    // future path without churn).
}

struct FilmtoneVideoExportRequest: FilmtoneSidecarRequest {
    let sourceURL: URL
    let outputURL: URL
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let codec: FilmtoneVideoCodec
    let sourceProfileSelection: CameraProfileSelection
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let packageCreativeLut: PreparedCreativeLut?
    let importedGradeLook: FilmtoneImportedGradeLook?
    let importedGradeSidecarURL: URL?
    let gradeRecipe: FilmtoneGradeRecipe
    let capturePackageProvenance: FilmtoneCapturePackageProvenance?
    let highlightMarkers: FilmtoneHighlightMarkers?
    let opticalFilterProfileId: String?
    /// M5-M (CC-B): intensity scalar for the optical filter profile (0…1).
    let opticalFilterIntensity: Double
    /// Optional headless automation output cap. Nil preserves the app's
    /// current full-display-size export behavior.
    let outputLongEdgeLimit: Double?
    let videoTimingMode: FilmtoneVideoTimingMode
    var sourceKind: FilmtoneSourceKind { .video }

    init(
        sourceURL: URL,
        outputURL: URL,
        presetName: String,
        presetStrength: Double = FilmtonePresetCatalog.presetStrengthDefault,
        lookSlug: String? = nil,
        codec: FilmtoneVideoCodec = .h264,
        sourceProfileSelection: CameraProfileSelection = .auto,
        quickState: FilmtoneQuickState = .zero,
        paramOverrides: FilmtonePhase0ParamsPatch = .empty,
        packageCreativeLut: PreparedCreativeLut? = nil,
        importedGradeLook: FilmtoneImportedGradeLook? = nil,
        importedGradeSidecarURL: URL? = nil,
        gradeRecipe: FilmtoneGradeRecipe? = nil,
        capturePackageProvenance: FilmtoneCapturePackageProvenance? = nil,
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        opticalFilterProfileId: String? = nil,
        opticalFilterIntensity: Double = 1.0,
        outputLongEdgeLimit: Double? = nil,
        videoTimingMode: FilmtoneVideoTimingMode = .normal
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.presetName = presetName
        self.presetStrength = presetStrength
        self.lookSlug = lookSlug
        self.codec = codec
        self.sourceProfileSelection = sourceProfileSelection
        self.quickState = quickState
        self.paramOverrides = paramOverrides
        self.packageCreativeLut = packageCreativeLut
        self.importedGradeLook = importedGradeLook
        self.importedGradeSidecarURL = importedGradeSidecarURL
        if let gradeRecipe {
            self.gradeRecipe = gradeRecipe
        } else if let importedGradeLook {
            self.gradeRecipe = FilmtoneGradeRecipe(
                selection: .importedGrade(
                    look: importedGradeLook,
                    sidecarURL: importedGradeSidecarURL,
                    packageCreativeLut: packageCreativeLut
                ),
                quickState: quickState,
                paramOverrides: paramOverrides,
                opticalFilterProfileId: opticalFilterProfileId,
                opticalFilterIntensity: opticalFilterIntensity
            )
        } else {
            self.gradeRecipe = FilmtoneGradeRecipe(
                selection: .builtIn(
                    presetName: presetName,
                    presetStrength: presetStrength,
                    lookSlug: lookSlug,
                    packageCreativeLut: packageCreativeLut
                ),
                quickState: quickState,
                paramOverrides: paramOverrides,
                opticalFilterProfileId: opticalFilterProfileId,
                opticalFilterIntensity: opticalFilterIntensity
            )
        }
        self.capturePackageProvenance = capturePackageProvenance
        self.highlightMarkers = highlightMarkers
        self.opticalFilterProfileId = opticalFilterProfileId
        self.opticalFilterIntensity = max(0, min(1, opticalFilterIntensity))
        if let outputLongEdgeLimit,
           outputLongEdgeLimit.isFinite,
           outputLongEdgeLimit > 0 {
            self.outputLongEdgeLimit = outputLongEdgeLimit
        } else {
            self.outputLongEdgeLimit = nil
        }
        self.videoTimingMode = videoTimingMode
    }
}

struct FilmtoneVideoExportProgress: Sendable {
    let processedFrames: Int
    let estimatedTotalFrames: Int
    let normalized: Double
}

struct FilmtoneVideoExportResult: Sendable {
    let outputURL: URL
    let sidecarURL: URL?
    let processedFrames: Int
    let outputWidth: Int
    let outputHeight: Int
    let audioPreserved: Bool
    let videoTimingMode: FilmtoneVideoTimingMode
    let outputFrameRate: Int
}

enum FilmtoneVideoExportError: Error, LocalizedError {
    case sourceUnreadable(URL)
    case renderFailed(URL)
    case noHighlightMarkers
    case completedOutputMissingAudio(URL)

    var errorDescription: String? {
        switch self {
        case .sourceUnreadable(let url):
            return "Could not read video frames from \(url.lastPathComponent)"
        case .renderFailed(let url):
            return "Could not render video to \(url.lastPathComponent)"
        case .noHighlightMarkers:
            return "No highlight markers are available for this video"
        case .completedOutputMissingAudio(let url):
            return "Completed export does not contain audio: \(url.lastPathComponent)"
        }
    }
}

enum FilmtoneVideoExporter {
    static func exportHighlightReel(
        _ request: FilmtoneVideoExportRequest,
        progress: (@Sendable (FilmtoneVideoExportProgress) -> Void)? = nil
    ) async throws -> FilmtoneVideoExportResult {
        guard let segments = request.highlightMarkers?.highlightReelSegments(),
              !segments.isEmpty else {
            throw FilmtoneVideoExportError.noHighlightMarkers
        }

        let probe = try await FilmtoneSourceProber.probeVideo(sourceURL: request.sourceURL)
        let contract = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: probe.metadata,
            sourceColorClass: probe.colorClass
        )
        let resolvedProfile = FilmtoneSourceInputTransform.resolve(
            selection: request.sourceProfileSelection,
            probedColorClass: probe.colorClass
        )
        _ = FilmtoneSourceInputTransform.prepareCube(for: resolvedProfile?.curve)
        let reader = try FilmtoneVideoReader(probe: probe, contract: contract)

        let displaySize = reader.displaySize
        let outputSize = constrainedOutputSize(
            displaySize.width > 0 && displaySize.height > 0
                ? displaySize
                : reader.naturalSize,
            maxLongEdge: request.outputLongEdgeLimit
        )
        let frameRate = max(1, Int(Double(reader.nominalFrameRate).rounded()))
        let timeline = FilmtoneHighlightReelFrameTimeline(segments: segments, outputFps: frameRate)
        guard timeline.totalFrameCount > 0 else {
            throw FilmtoneVideoExportError.noHighlightMarkers
        }

        let writer = try FilmtoneVideoWriter(
            outputURL: request.outputURL,
            outputSize: outputSize,
            frameRate: frameRate,
            contract: contract
        )

        let renderContext = makeRenderContext(
            request: request,
            probe: probe,
            reader: reader,
            outputSize: outputSize,
            contract: contract,
            resolvedProfile: resolvedProfile
        )

        try writer.start()
        try reader.start()

        var previousFrame: TimedVideoFrame?
        var lookaheadFrame = try readNextTimedVideoFrame(from: reader)
        var processed = 0
        let estimatedTotal = max(1, timeline.totalFrameCount)

        do {
            for outputFrameIndex in 0..<timeline.totalFrameCount {
                try Task.checkCancellation()
                guard let sourceLookupTime = timeline.sourceTimeSec(forOutputFrameIndex: outputFrameIndex) else {
                    continue
                }

                while let lookahead = lookaheadFrame,
                      lookahead.seconds < sourceLookupTime {
                    previousFrame = lookahead
                    lookaheadFrame = try readNextTimedVideoFrame(from: reader)
                }

                let selectedFrame = nearestFrame(
                    targetSeconds: sourceLookupTime,
                    previous: previousFrame,
                    lookahead: lookaheadFrame
                )
                guard let selectedFrame else {
                    throw FilmtoneVideoExportError.sourceUnreadable(request.sourceURL)
                }

                let outputTime = CMTime(
                    value: CMTimeValue(outputFrameIndex),
                    timescale: CMTimeScale(frameRate)
                )
                let outputBuffer = try renderPixelBuffer(
                    from: selectedFrame,
                    frameTimeSeconds: sourceLookupTime,
                    writer: writer,
                    renderContext: renderContext
                )
                try await writer.append(buffer: outputBuffer, presentationTime: outputTime)
                processed += 1

                if processed == 1 || processed % 12 == 0 {
                    progress?(FilmtoneVideoExportProgress(
                        processedFrames: processed,
                        estimatedTotalFrames: estimatedTotal,
                        normalized: min(1.0, Double(processed) / Double(estimatedTotal))
                    ))
                }
            }

            try await writer.finish()
        } catch {
            reader.cancel()
            writer.cancel()
            throw error
        }

        progress?(FilmtoneVideoExportProgress(
            processedFrames: processed,
            estimatedTotalFrames: max(processed, estimatedTotal),
            normalized: 1.0
        ))

        return FilmtoneVideoExportResult(
            outputURL: request.outputURL,
            sidecarURL: nil,
            processedFrames: processed,
            outputWidth: Int(outputSize.width.rounded()),
            outputHeight: Int(outputSize.height.rounded()),
            audioPreserved: false,
            videoTimingMode: .normal,
            outputFrameRate: frameRate
        )
    }

    static func export(
        _ request: FilmtoneVideoExportRequest,
        writeSidecar: Bool = true,
        progress: (@Sendable (FilmtoneVideoExportProgress) -> Void)? = nil
    ) async throws -> FilmtoneVideoExportResult {
        // Phase 2 C1: probe source for color metadata, classify, then build
        // the canonical contract via FilmtoneColorPipeline.defaultOutputContract.
        // The probe also pre-loads track properties (naturalSize / preferredTransform
        // / nominalFrameRate / duration) used by the reader so we no longer hit
        // the deprecated synchronous `asset.tracks` / `track.naturalSize` path.
        let probe = try await FilmtoneSourceProber.probeVideo(sourceURL: request.sourceURL)
        let contract = FilmtoneColorPipeline.defaultOutputContract(
            sourceMetadata: probe.metadata,
            sourceColorClass: probe.colorClass
        )
        // M5-C.1: resolve catalog entry once for the entire export. Pre-warm
        // the cube cache so the per-frame loop reuses the parsed cube blob
        // (NSLock + dictionary in FilmtoneSourceInputTransform).
        let resolvedProfile = FilmtoneSourceInputTransform.resolve(
            selection: request.sourceProfileSelection,
            probedColorClass: probe.colorClass
        )
        _ = FilmtoneSourceInputTransform.prepareCube(for: resolvedProfile?.curve)
        let timingPolicy = FilmtoneVideoTimingPolicy(
            mode: request.videoTimingMode,
            sourceFPS: Double(probe.nominalFrameRate)
        )
        let reader = try FilmtoneVideoReader(
            probe: probe,
            contract: contract,
            preserveAudio: !timingPolicy.isSlow24
        )

        // Display orientation (portrait capture etc. swaps width/height).
        let displaySize = reader.displaySize
        let outputSize = constrainedOutputSize(
            displaySize.width > 0 && displaySize.height > 0
                ? displaySize
                : reader.naturalSize,
            maxLongEdge: request.outputLongEdgeLimit
        )
        let frameRate = timingPolicy.isSlow24
            ? timingPolicy.targetFPS
            : max(1, Int(Double(reader.nominalFrameRate).rounded()))
        let estimatedTotal = max(1, reader.estimatedFrameCount)

        let writer = try FilmtoneVideoWriter(
            outputURL: request.outputURL,
            outputSize: outputSize,
            frameRate: frameRate,
            contract: contract,
            preserveAudio: reader.hasAudioOutput && !timingPolicy.isSlow24
        )

        try writer.start()
        try reader.start()

        let resolvedGrade = FilmtoneGradeResolution.resolve(recipe: request.gradeRecipe)
            .applyingSourcePolicy(
                resolvedProfile: resolvedProfile,
                probedColorClass: probe.colorClass
            )
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: request.sourceURL.absoluteString
        )
        let context = FilmtoneCIContext.shared
        let outputColorSpace = contract.destinationColorSpace
        let renderBounds = CGRect(origin: .zero, size: outputSize)
        let preferredTransform = reader.preferredTransform
        let renderContext = VideoFrameRenderContext(
            contract: contract,
            resolvedProfile: resolvedProfile,
            params: resolvedGrade.params,
            sourceSeed: sourceSeed,
            cameraOptics: probe.cameraOptics,
            creativeLut: resolvedGrade.creativeLut,
            lutIntensity: resolvedGrade.lutIntensity,
            opticalFilterProfileId: request.gradeRecipe.opticalFilterProfileId,
            opticalFilterIntensity: request.gradeRecipe.opticalFilterIntensity,
            sourceDetailBias: resolveSourceDetailBias(
                cameraOptics: probe.cameraOptics,
                colorClass: probe.colorClass,
                resolvedProfile: resolvedProfile
            ),
            ciContext: context,
            outputColorSpace: outputColorSpace,
            renderBounds: renderBounds,
            preferredTransform: preferredTransform,
            outputSize: outputSize
        )

        var processed = 0
        let audioTask = reader.hasAudioOutput && !timingPolicy.isSlow24
            ? Task.detached(priority: .userInitiated) {
                try await appendAudioSamples(from: reader, to: writer)
            }
            : nil
        do {
            while let pair = try reader.nextSampleBuffer() {
                try Task.checkCancellation()

                let presentationTime = CMSampleBufferGetPresentationTimeStamp(pair.sampleBuffer)
                let validTime: CMTime = (presentationTime.isValid && presentationTime.isNumeric)
                    ? presentationTime
                    : .zero

                let frame = TimedVideoFrame(pixelBuffer: pair.pixelBuffer, seconds: CMTimeGetSeconds(validTime))
                let frameTimeSeconds = frame.seconds.isFinite ? max(frame.seconds, 0) : 0
                let outputBuffer = try renderPixelBuffer(
                    from: frame,
                    frameTimeSeconds: frameTimeSeconds,
                    writer: writer,
                    renderContext: renderContext
                )

                let outputTime = timingPolicy.isSlow24
                    ? CMTime(value: CMTimeValue(processed), timescale: CMTimeScale(max(1, frameRate)))
                    : validTime
                try await writer.append(buffer: outputBuffer, presentationTime: outputTime)
                processed += 1

                if processed == 1 || processed % 12 == 0 {
                    let normalized = min(1.0, Double(processed) / Double(estimatedTotal))
                    progress?(FilmtoneVideoExportProgress(
                        processedFrames: processed,
                        estimatedTotalFrames: estimatedTotal,
                        normalized: normalized
                    ))
                }
            }

            if let audioTask {
                try await audioTask.value
            }
            try await writer.finish()
        } catch {
            audioTask?.cancel()
            reader.cancel()
            writer.cancel()
            throw error
        }

        let audioPreserved = timingPolicy.isSlow24
            ? false
            : try await validateCompletedAudioPreservation(
                sourceHasAudio: probe.audioTrack != nil,
                outputURL: request.outputURL
            )

        var sidecarURL: URL? = nil
        if writeSidecar {
            let timingMetadata = FilmtoneVideoTimingMetadataDTO.make(
                policy: timingPolicy,
                sourceDurationSec: reader.durationSeconds,
                sourceFrameCount: processed
            )
            sidecarURL = try FilmtoneSidecarWriter.writeSidecar(
                for: request,
                sourceInterpretation: contract.sourceInterpretationID,
                resolvedSourceProfile: resolvedProfile,
                videoTimingMetadata: timingMetadata
            )
        }

        progress?(FilmtoneVideoExportProgress(
            processedFrames: processed,
            estimatedTotalFrames: max(processed, estimatedTotal),
            normalized: 1.0
        ))

        return FilmtoneVideoExportResult(
            outputURL: request.outputURL,
            sidecarURL: sidecarURL,
            processedFrames: processed,
            outputWidth: Int(outputSize.width.rounded()),
            outputHeight: Int(outputSize.height.rounded()),
            audioPreserved: audioPreserved,
            videoTimingMode: timingPolicy.resolvedMode,
            outputFrameRate: frameRate
        )
    }

    private static func appendAudioSamples(
        from reader: FilmtoneVideoReader,
        to writer: FilmtoneVideoWriter
    ) async throws {
        while let sampleBuffer = try reader.nextAudioSampleBuffer() {
            try Task.checkCancellation()
            try await writer.appendAudio(sampleBuffer: sampleBuffer)
        }
    }

    private static func constrainedOutputSize(
        _ size: CGSize,
        maxLongEdge: Double?
    ) -> CGSize {
        let width = max(2, size.width)
        let height = max(2, size.height)
        guard let maxLongEdge,
              maxLongEdge.isFinite,
              maxLongEdge > 0 else {
            return evenSize(width: width, height: height)
        }
        let longEdge = max(width, height)
        guard longEdge > maxLongEdge else {
            return evenSize(width: width, height: height)
        }
        let scale = maxLongEdge / longEdge
        return evenSize(width: width * scale, height: height * scale)
    }

    private static func evenSize(width: Double, height: Double) -> CGSize {
        CGSize(
            width: evenDimension(width),
            height: evenDimension(height)
        )
    }

    private static func evenDimension(_ value: Double) -> Int {
        let rounded = max(2, Int(value.rounded()))
        return rounded % 2 == 0 ? rounded : max(2, rounded - 1)
    }

    private static func validateCompletedAudioPreservation(
        sourceHasAudio: Bool,
        outputURL: URL
    ) async throws -> Bool {
        guard sourceHasAudio else {
            return false
        }
        let outputAsset = AVURLAsset(url: outputURL)
        guard !(try await outputAsset.loadTracks(withMediaType: .audio)).isEmpty else {
            throw FilmtoneVideoExportError.completedOutputMissingAudio(outputURL)
        }
        return true
    }

    private static func makeRenderContext(
        request: FilmtoneVideoExportRequest,
        probe: FilmtoneVideoTrackProbe,
        reader: FilmtoneVideoReader,
        outputSize: CGSize,
        contract: FilmtoneColorPipelineContract,
        resolvedProfile: CameraProfileCatalogEntry?
    ) -> VideoFrameRenderContext {
        let resolvedGrade = FilmtoneGradeResolution.resolve(recipe: request.gradeRecipe)
            .applyingSourcePolicy(
                resolvedProfile: resolvedProfile,
                probedColorClass: probe.colorClass
            )
        return VideoFrameRenderContext(
            contract: contract,
            resolvedProfile: resolvedProfile,
            params: resolvedGrade.params,
            sourceSeed: FilmtoneGradePipeline.makeStableSourceSeed(
                from: request.sourceURL.absoluteString
            ),
            cameraOptics: probe.cameraOptics,
            creativeLut: resolvedGrade.creativeLut,
            lutIntensity: resolvedGrade.lutIntensity,
            opticalFilterProfileId: request.gradeRecipe.opticalFilterProfileId,
            opticalFilterIntensity: request.gradeRecipe.opticalFilterIntensity,
            sourceDetailBias: resolveSourceDetailBias(
                cameraOptics: probe.cameraOptics,
                colorClass: probe.colorClass,
                resolvedProfile: resolvedProfile
            ),
            ciContext: FilmtoneCIContext.shared,
            outputColorSpace: contract.destinationColorSpace,
            renderBounds: CGRect(origin: .zero, size: outputSize),
            preferredTransform: reader.preferredTransform,
            outputSize: outputSize
        )
    }

    private static func bundledCreativeLut(
        lookSlug: String?,
        strength: Double
    ) -> PreparedCreativeLut? {
        guard let lookSlug,
              strength > 0,
              let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) else {
            return nil
        }
        return FilmtoneCreativeLutLoader.load(look: look)
    }

    private static func clampLutIntensity(_ intensity: Double) -> Double {
        max(0, min(1, intensity.isFinite ? intensity : 1))
    }

    private static func renderPixelBuffer(
        from frame: TimedVideoFrame,
        frameTimeSeconds: Double,
        writer: FilmtoneVideoWriter,
        renderContext: VideoFrameRenderContext
    ) throws -> CVPixelBuffer {
        guard let pool = writer.pixelBufferPool else {
            throw FilmtoneVideoExportError.renderFailed(writer.outputURL)
        }
        var renderedBuffer: CVPixelBuffer?
        let createStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &renderedBuffer)
        guard createStatus == kCVReturnSuccess, let outputBuffer = renderedBuffer else {
            throw FilmtoneVideoExportError.renderFailed(writer.outputURL)
        }

        autoreleasepool {
            let sourceImage = CIImage(
                cvImageBuffer: frame.pixelBuffer,
                options: renderContext.contract.sourceImageOptions(
                    for: frame.pixelBuffer,
                    toneMapHDRToSDR: true
                )
            )

            let oriented = sourceImage.transformed(by: renderContext.preferredTransform)
            let normalized = oriented.transformed(by: CGAffineTransform(
                translationX: -oriented.extent.origin.x,
                y: -oriented.extent.origin.y
            ))
            let scaleX = renderContext.outputSize.width / max(normalized.extent.width, 1)
            let scaleY = renderContext.outputSize.height / max(normalized.extent.height, 1)
            let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            let normalized709 = FilmtoneSourceInputTransform.apply(
                to: scaled,
                entry: renderContext.resolvedProfile
            )
            let graded = FilmtoneGradePipeline.apply(
                to: normalized709,
                params: renderContext.params,
                frameTimeSeconds: max(frameTimeSeconds, 0),
                sourceSeed: renderContext.sourceSeed,
                cameraOptics: renderContext.cameraOptics,
                creativeLut: renderContext.creativeLut,
                lutIntensity: renderContext.lutIntensity,
                opticalFilterProfileId: renderContext.opticalFilterProfileId,
                opticalFilterIntensity: renderContext.opticalFilterIntensity,
                sourceDetailBias: renderContext.sourceDetailBias
            ).cropped(to: renderContext.renderBounds)

            renderContext.ciContext.render(
                graded,
                to: outputBuffer,
                bounds: renderContext.renderBounds,
                colorSpace: renderContext.outputColorSpace
            )
            renderContext.contract.applyOutputMetadata(to: outputBuffer)
        }

        return outputBuffer
    }

    private static func readNextTimedVideoFrame(
        from reader: FilmtoneVideoReader
    ) throws -> TimedVideoFrame? {
        guard let pair = try reader.nextSampleBuffer() else {
            return nil
        }
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(pair.sampleBuffer)
        let validTime: CMTime = (presentationTime.isValid && presentationTime.isNumeric)
            ? presentationTime
            : .zero
        let seconds = CMTimeGetSeconds(validTime)
        return TimedVideoFrame(
            pixelBuffer: pair.pixelBuffer,
            seconds: seconds.isFinite ? max(seconds, 0) : 0
        )
    }

    private static func nearestFrame(
        targetSeconds: Double,
        previous: TimedVideoFrame?,
        lookahead: TimedVideoFrame?
    ) -> TimedVideoFrame? {
        switch (previous, lookahead) {
        case (let previous?, let lookahead?):
            let previousDistance = abs(previous.seconds - targetSeconds)
            let lookaheadDistance = abs(lookahead.seconds - targetSeconds)
            return previousDistance <= lookaheadDistance ? previous : lookahead
        case (let previous?, nil):
            return previous
        case (nil, let lookahead?):
            return lookahead
        case (nil, nil):
            return nil
        }
    }
}

private struct TimedVideoFrame {
    let pixelBuffer: CVPixelBuffer
    let seconds: Double
}

private struct VideoFrameRenderContext {
    let contract: FilmtoneColorPipelineContract
    let resolvedProfile: CameraProfileCatalogEntry?
    let params: FilmtonePhase0Params
    let sourceSeed: Double
    let cameraOptics: CameraOpticsDTO?
    let creativeLut: PreparedCreativeLut?
    let lutIntensity: Double
    let opticalFilterProfileId: String?
    let opticalFilterIntensity: Double
    let sourceDetailBias: Double
    let ciContext: CIContext
    let outputColorSpace: CGColorSpace
    let renderBounds: CGRect
    let preferredTransform: CGAffineTransform
    let outputSize: CGSize
}

private struct FilmtoneHighlightReelFrameTimeline {
    let entries: [Entry]
    let outputFps: Double
    let totalFrameCount: Int

    init(segments: [FilmtoneHighlightClipSegment], outputFps: Int) {
        let validFps = max(1, outputFps)
        var nextOutputFrameIndex = 0
        var nextEntries: [Entry] = []
        for (segmentIndex, segment) in segments.enumerated() where segment.durationSec > 0 {
            let frameCount = max(1, Int((segment.durationSec * Double(validFps) + 0.000001).rounded(.down)))
            nextEntries.append(Entry(
                segmentIndex: segmentIndex,
                outputStartFrameIndex: nextOutputFrameIndex,
                frameCount: frameCount,
                sourceStartSec: segment.sourceStartSec,
                sourceEndSec: segment.sourceEndSec
            ))
            nextOutputFrameIndex += frameCount
        }
        self.entries = nextEntries
        self.outputFps = Double(validFps)
        self.totalFrameCount = nextOutputFrameIndex
    }

    func sourceTimeSec(forOutputFrameIndex outputFrameIndex: Int) -> Double? {
        guard let entry = entries.first(where: {
            outputFrameIndex >= $0.outputStartFrameIndex &&
            outputFrameIndex < $0.outputStartFrameIndex + $0.frameCount
        }) else {
            return nil
        }
        let frameOffset = outputFrameIndex - entry.outputStartFrameIndex
        let sourceTime = entry.sourceStartSec + Double(frameOffset) / outputFps
        return min(max(sourceTime, entry.sourceStartSec), entry.sourceEndSec)
    }

    struct Entry {
        let segmentIndex: Int
        let outputStartFrameIndex: Int
        let frameCount: Int
        let sourceStartSec: Double
        let sourceEndSec: Double
    }
}

// Phase 4-B Detail Softness: resolve a session-derived `sourceDetailBias`
// from the metadata that is already in scope when the export render
// context is built. Output is fed straight into
// `FilmtoneDetailSoftness.deriveUniforms(detailSoftness:sourceDetailBias:)`
// at the detail-softness stage. Never persisted; not in any saved Look.
private func resolveSourceDetailBias(
    cameraOptics: CameraOpticsDTO?,
    colorClass: SourceColorClassDTO?,
    resolvedProfile: CameraProfileCatalogEntry?
) -> Double {
    let input = FilmtoneSourceDetailCompensationInput(
        cameraMake: cameraOptics?.cameraMake,
        cameraModel: cameraOptics?.cameraModel,
        logTransferFunction: nil,
        inputTransformStrategy: nil,
        codecFamily: nil,
        colorClass: colorClass?.rawValue,
        sourceProfileId: resolvedProfile?.id
    )
    return FilmtoneSourceDetailCompensation.resolve(input).recommendedBias
}
