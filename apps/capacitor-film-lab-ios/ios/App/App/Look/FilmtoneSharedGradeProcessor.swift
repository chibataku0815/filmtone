import AVFoundation
import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

/// Live capture preview / in-app composition grade processor extracted
/// from `FilmtoneExportSession` during the v1.x feature-architecture
/// refactor (Phase 2B-4). Owns `applyForLivePreview(_:mode:)` (the VDO
/// sample entrypoint the capture surface invokes on every frame) and
/// `makeVideoComposition(...)` (the in-app video preview composer
/// factory). The implementation delegates back to
/// `FilmtoneExportSession` so the live preview render path stays
/// byte-parity compatible with the master export when the same input
/// pixels are fed.
final class FilmtoneSharedGradeProcessor {
    private let session: FilmtoneExportSession
    private lazy var motionBlurAccumulator = session.makeMotionBlurAccumulator()

    init(session: FilmtoneExportSession) {
        self.session = session
    }

    /// Live capture preview entrypoint (M10 / S8-F F3).
    ///
    /// Apply the request's current grade chain (Look + adjustments) to a
    /// single CIImage, without motion blur.  The capture surface uses
    /// this on every VDO sample so the live preview shows the same
    /// color direction the editor will apply when the captured master
    /// is adopted.  Motion blur is intentionally skipped here because:
    ///
    /// - shutter-angle blur is a master-frame-rate effect, not a live-
    ///   monitoring effect (Filmtone's blur ring assumes 24 fps frame
    ///   spacing — a real-time camera feed has its own integration
    ///   time that bears no relation to the user's selected angle), and
    /// - the live preview cadence is the camera's, not the export
    ///   timeline's, so feeding `motionBlurAccumulator.apply(...)` would
    ///   contaminate state that the export pipeline depends on.
    ///
    /// `ciContext` is reused from the underlying session so the live
    /// preview render path is byte-parity compatible with the master
    /// export when the same input pixels are fed.
    func applyForLivePreview(
        _ image: CIImage,
        mode: FilmtoneLivePreviewRenderMode = .fullPreview
    ) -> CIImage {
        session.applyLivePreviewGrade(to: image, timeSeconds: 0, mode: mode)
    }

    /// Reuse the session's CIContext for the live preview renderer so
    /// CIFilter intermediates compiled by `applyForLivePreview` aren't
    /// re-built on every frame in a separate context.
    var ciContext: CIContext { session.ciContext }

    func makeVideoComposition(
        asset: AVAsset,
        videoTrack _: AVAssetTrack,
        outputSize: CGSize
    ) -> AVMutableVideoComposition {
        let previewRasterizer = FilmtoneCompositionPreviewRasterizer(
            ciContext: session.ciContext,
            colorPipeline: session.colorPipeline,
            outputSize: outputSize
        )
        let composition = AVMutableVideoComposition(
            asset: asset,
            applyingCIFiltersWithHandler: { [session] request in
                do {
                    let timeSeconds = CMTimeGetSeconds(request.compositionTime)
                    let processed = try session.renderablePreviewVideoImage(
                        from: request.sourceImage,
                        outputSize: outputSize,
                        timeSeconds: timeSeconds.isFinite ? timeSeconds : 0,
                        motionAccumulator: self.motionBlurAccumulator
                    )
                    let rasterized = try previewRasterizer.rasterizedImage(from: processed)
                    request.finish(with: rasterized, context: session.ciContext)
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
        session.colorPipeline.applyOutputMetadata(to: composition)
        return composition
    }
}

private final class FilmtoneCompositionPreviewRasterizer {
    private let ciContext: CIContext
    private let colorPipeline: FilmtoneColorPipelineContract
    private let outputColorSpace: CGColorSpace
    private let outputSize: CGSize
    private let pixelBufferPool: CVPixelBufferPool?

    init(
        ciContext: CIContext,
        colorPipeline: FilmtoneColorPipelineContract,
        outputSize: CGSize
    ) {
        self.ciContext = ciContext
        self.colorPipeline = colorPipeline
        self.outputColorSpace = colorPipeline.destinationColorSpace
        self.outputSize = outputSize

        var pool: CVPixelBufferPool?
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: max(2, Int(outputSize.width.rounded())),
            kCVPixelBufferHeightKey as String: max(2, Int(outputSize.height.rounded())),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
        ]
        CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &pool)
        self.pixelBufferPool = pool
    }

    func rasterizedImage(from image: CIImage) throws -> CIImage {
        guard let pixelBufferPool else {
            throw FilmtoneMediaError.exportFailed("The video preview raster buffer pool could not be created.")
        }
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pixelBufferPool, &pixelBuffer)
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw FilmtoneMediaError.exportFailed("The video preview raster buffer could not be created.")
        }

        let bounds = CGRect(origin: .zero, size: outputSize)
        ciContext.render(
            image,
            to: pixelBuffer,
            bounds: bounds,
            colorSpace: outputColorSpace
        )
        colorPipeline.applyOutputMetadata(to: pixelBuffer)

        return CIImage(
            cvPixelBuffer: pixelBuffer,
            options: [.colorSpace: outputColorSpace]
        )
        .cropped(to: bounds)
    }
}
