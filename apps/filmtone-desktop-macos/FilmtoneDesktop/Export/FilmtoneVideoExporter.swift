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
    let highlightMarkers: FilmtoneHighlightMarkers?
    let opticalFilterProfileId: String?
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
        highlightMarkers: FilmtoneHighlightMarkers? = nil,
        opticalFilterProfileId: String? = nil
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
        self.highlightMarkers = highlightMarkers
        self.opticalFilterProfileId = opticalFilterProfileId
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
}

enum FilmtoneVideoExportError: Error, LocalizedError {
    case sourceUnreadable(URL)
    case renderFailed(URL)
    case noHighlightMarkers

    var errorDescription: String? {
        switch self {
        case .sourceUnreadable(let url):
            return "Could not read video frames from \(url.lastPathComponent)"
        case .renderFailed(let url):
            return "Could not render video to \(url.lastPathComponent)"
        case .noHighlightMarkers:
            return "No highlight markers are available for this video"
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
        let outputSize = displaySize.width > 0 && displaySize.height > 0
            ? displaySize
            : reader.naturalSize
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
            outputHeight: Int(outputSize.height.rounded())
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
        let reader = try FilmtoneVideoReader(probe: probe, contract: contract)

        // Display orientation (portrait capture etc. swaps width/height).
        let displaySize = reader.displaySize
        let outputSize = displaySize.width > 0 && displaySize.height > 0
            ? displaySize
            : reader.naturalSize
        let frameRate = max(1, Int(Double(reader.nominalFrameRate).rounded()))
        let estimatedTotal = max(1, reader.estimatedFrameCount)

        let writer = try FilmtoneVideoWriter(
            outputURL: request.outputURL,
            outputSize: outputSize,
            frameRate: frameRate,
            contract: contract
        )

        try writer.start()
        try reader.start()

        let params = FilmtonePresetCatalog.resolved(
            presetName: request.presetName,
            strength: request.presetStrength,
            lookSlug: request.lookSlug,
            quickState: request.quickState,
            paramOverrides: FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: request.opticalFilterProfileId,
                userOverrides: request.paramOverrides
            )
        )
        let sourceSeed = FilmtoneGradePipeline.makeStableSourceSeed(
            from: request.sourceURL.absoluteString
        )
        // M5-A.2: resolve the cube ONCE outside the frame loop. The NSCache
        // hit guarantees a parsed cube survives this entire export. nil
        // when no Look is selected or strength gate is closed (D4-ii).
        let creativeLut: PreparedCreativeLut?
        if let lookSlug = request.lookSlug,
           request.presetStrength > 0,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) {
            creativeLut = FilmtoneCreativeLutLoader.load(look: look)
        } else {
            creativeLut = nil
        }
        let context = FilmtoneCIContext.shared
        let outputColorSpace = contract.destinationColorSpace
        let renderBounds = CGRect(origin: .zero, size: outputSize)
        let preferredTransform = reader.preferredTransform
        let renderContext = VideoFrameRenderContext(
            contract: contract,
            resolvedProfile: resolvedProfile,
            params: params,
            sourceSeed: sourceSeed,
            cameraOptics: probe.cameraOptics,
            creativeLut: creativeLut,
            ciContext: context,
            outputColorSpace: outputColorSpace,
            renderBounds: renderBounds,
            preferredTransform: preferredTransform,
            outputSize: outputSize
        )

        var processed = 0
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

                try await writer.append(buffer: outputBuffer, presentationTime: validTime)
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

            try await writer.finish()
        } catch {
            reader.cancel()
            writer.cancel()
            throw error
        }

        var sidecarURL: URL? = nil
        if writeSidecar {
            sidecarURL = try FilmtoneSidecarWriter.writeSidecar(
                for: request,
                sourceInterpretation: contract.sourceInterpretationID,
                resolvedSourceProfile: resolvedProfile
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
            outputHeight: Int(outputSize.height.rounded())
        )
    }

    private static func makeRenderContext(
        request: FilmtoneVideoExportRequest,
        probe: FilmtoneVideoTrackProbe,
        reader: FilmtoneVideoReader,
        outputSize: CGSize,
        contract: FilmtoneColorPipelineContract,
        resolvedProfile: CameraProfileCatalogEntry?
    ) -> VideoFrameRenderContext {
        let params = FilmtonePresetCatalog.resolved(
            presetName: request.presetName,
            strength: request.presetStrength,
            lookSlug: request.lookSlug,
            quickState: request.quickState,
            paramOverrides: FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: request.opticalFilterProfileId,
                userOverrides: request.paramOverrides
            )
        )
        let creativeLut: PreparedCreativeLut?
        if let lookSlug = request.lookSlug,
           request.presetStrength > 0,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) {
            creativeLut = FilmtoneCreativeLutLoader.load(look: look)
        } else {
            creativeLut = nil
        }
        return VideoFrameRenderContext(
            contract: contract,
            resolvedProfile: resolvedProfile,
            params: params,
            sourceSeed: FilmtoneGradePipeline.makeStableSourceSeed(
                from: request.sourceURL.absoluteString
            ),
            cameraOptics: probe.cameraOptics,
            creativeLut: creativeLut,
            ciContext: FilmtoneCIContext.shared,
            outputColorSpace: contract.destinationColorSpace,
            renderBounds: CGRect(origin: .zero, size: outputSize),
            preferredTransform: reader.preferredTransform,
            outputSize: outputSize
        )
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
                creativeLut: renderContext.creativeLut
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
