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
    let codec: FilmtoneVideoCodec
    var sourceKind: FilmtoneSourceKind { .video }

    init(
        sourceURL: URL,
        outputURL: URL,
        presetName: String,
        codec: FilmtoneVideoCodec = .h264
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.presetName = presetName
        self.codec = codec
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

        let params = FilmtonePresetCatalog.params(for: request.presetName)
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

                    let graded = FilmtoneGradePipeline.apply(to: scaled, params: params)
                        .cropped(to: renderBounds)

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
                sourceInterpretation: contract.sourceInterpretationID
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
