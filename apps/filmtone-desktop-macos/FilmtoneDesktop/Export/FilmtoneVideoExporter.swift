import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo
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
        paramOverrides: FilmtonePhase0ParamsPatch = .empty
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

enum FilmtoneVideoExportError: Error {
    case sourceUnreadable(URL)
    case renderFailed(URL)
}

enum FilmtoneVideoExporter {
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
            paramOverrides: request.paramOverrides
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

        var processed = 0
        do {
            while let pair = try reader.nextSampleBuffer() {
                try Task.checkCancellation()

                let presentationTime = CMSampleBufferGetPresentationTimeStamp(pair.sampleBuffer)
                let validTime: CMTime = (presentationTime.isValid && presentationTime.isNumeric)
                    ? presentationTime
                    : .zero

                guard let pool = writer.pixelBufferPool else {
                    throw FilmtoneVideoExportError.renderFailed(request.outputURL)
                }
                var renderedBuffer: CVPixelBuffer?
                let createStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &renderedBuffer)
                guard createStatus == kCVReturnSuccess, let outputBuffer = renderedBuffer else {
                    throw FilmtoneVideoExportError.renderFailed(request.outputURL)
                }

                autoreleasepool {
                    let sourceImage = CIImage(
                        cvImageBuffer: pair.pixelBuffer,
                        options: contract.sourceImageOptions(
                            for: pair.pixelBuffer,
                            toneMapHDRToSDR: true
                        )
                    )

                    // Apply track preferred transform and normalize origin so the
                    // grade pipeline operates on a non-negative-origin extent
                    // matching `outputSize`.
                    let oriented = sourceImage.transformed(by: preferredTransform)
                    let normalized = oriented.transformed(by: CGAffineTransform(
                        translationX: -oriented.extent.origin.x,
                        y: -oriented.extent.origin.y
                    ))
                    let scaleX = outputSize.width / max(normalized.extent.width, 1)
                    let scaleY = outputSize.height / max(normalized.extent.height, 1)
                    let scaled = normalized.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                    // M5-C.1: apply the source profile cube before grade.
                    // For Auto on Rec.709 / unknown sources (no entry / nil
                    // curve) this is identity, preserving pre-M5-C.1 output
                    // bytewise.
                    let normalized709 = FilmtoneSourceInputTransform.apply(
                        to: scaled,
                        entry: resolvedProfile
                    )

                    // Phase 2 C5a: forward CMTime presentation seconds to the
                    // grain kernel so each frame draws a fresh grain pattern
                    // (kernel does floor(t*3) → 3 refresh per source-second).
                    let secondsRaw = CMTimeGetSeconds(validTime)
                    let frameTimeSeconds = secondsRaw.isFinite ? max(secondsRaw, 0) : 0
                    let graded = FilmtoneGradePipeline.apply(
                        to: normalized709,
                        params: params,
                        frameTimeSeconds: frameTimeSeconds,
                        sourceSeed: sourceSeed,
                        cameraOptics: probe.cameraOptics,
                        creativeLut: creativeLut
                    ).cropped(to: renderBounds)

                    context.render(
                        graded,
                        to: outputBuffer,
                        bounds: renderBounds,
                        colorSpace: outputColorSpace
                    )
                    contract.applyOutputMetadata(to: outputBuffer)
                }

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
}
