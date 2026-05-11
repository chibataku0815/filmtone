import AVFoundation
import CoreGraphics
import CoreImage
import CoreMedia
import FilmLabSwiftCore
import Foundation

/// Phase 2B-9C: still / video preview rendering + reference-after JPEG
/// artifact collaborator lifted out of `FilmtoneExportSession`. Owns the
/// preview-image generation path (still source load → scale → grade →
/// preview JPEG pair; video poster-time → frame copy → scale → grade →
/// preview JPEG pair), the zero-tolerance image generator with 0.5s
/// fallback, the 25%-clamped poster time computation, and the JPEG write
/// site that uses the session's CI context + output color space.
///
/// `FilmtoneExportSession` keeps `applyGrade(...)`,
/// `renderableStillImage(...)`, and `renderablePreviewVideoImage(...)`
/// so the grade / optics / grain stage order stays
/// session-owned in this sub-stage. The session passes an `applyGrade`
/// closure into `renderPreviewFrame(applyGrade:)` and the renderer calls
/// it at the same points the in-place helpers did, preserving the
/// `cropped(to: original.extent)` semantics.
final class ExportPreviewRenderer {
    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let outputURL: URL
    private let cacheStore: CacheStore
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let sourceImageNormalizer: ExportSourceImageNormalizer
    private let mezzanineRouter: ExportMezzanineRouter

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        outputURL: URL,
        cacheStore: CacheStore,
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        sourceImageNormalizer: ExportSourceImageNormalizer,
        mezzanineRouter: ExportMezzanineRouter
    ) {
        self.request = request
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.cacheStore = cacheStore
        self.ciContext = ciContext
        self.outputColorSpace = outputColorSpace
        self.sourceImageNormalizer = sourceImageNormalizer
        self.mezzanineRouter = mezzanineRouter
    }

    func renderPreviewFrame(
        applyGrade: (CIImage, Double) -> CIImage
    ) throws -> Phase0PreviewRenderResultDTO {
        switch request.sourceKind {
        case .image:
            return try renderStillPreview(applyGrade: applyGrade)
        case .video:
            return try renderVideoPreview(applyGrade: applyGrade)
        }
    }

    func writeReferenceAfterImage(
        to url: URL,
        sourceDurationSec: Double?
    ) throws -> Double {
        let asset = AVURLAsset(url: outputURL)
        let assetDuration = CMTimeGetSeconds(asset.duration)
        let duration = assetDuration.isFinite && assetDuration > 0
            ? assetDuration
            : (sourceDurationSec ?? 0)
        let posterTimeSec = makePreviewPosterTime(sourceDurationSec: duration)
        let posterTime = CMTime(
            seconds: posterTimeSec,
            preferredTimescale: 600
        )
        let cgImage = try copyPreviewCGImage(for: asset, at: posterTime)
        try writeJPEGImage(CIImage(cgImage: cgImage), to: url)
        return posterTimeSec
    }

    private func renderStillPreview(
        applyGrade: (CIImage, Double) -> CIImage
    ) throws -> Phase0PreviewRenderResultDTO {
        guard let image = sourceImageNormalizer.loadedSourceImage(at: sourceURL) else {
            throw FilmtoneMediaError.unsupportedSource("The selected image could not be loaded.")
        }

        let outputSize = ExportGeometry.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)
        let original = sourceImageNormalizer.scaledStillSourceImage(image, outputSize: outputSize)
        let graded = applyGrade(original, 0).cropped(to: original.extent)

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

    private func renderVideoPreview(
        applyGrade: (CIImage, Double) -> CIImage
    ) throws -> Phase0PreviewRenderResultDTO {
        // v1.4: read from the same effective URL the export will consume so
        // preview ↔ export bytes stay symmetric within each renderMode. When
        // the relevant mezzanine variant is missing (still being generated, or
        // policy declined), this transparently falls back to source.
        let effectiveSourceURL = mezzanineRouter.resolvedPreviewSourceURL()
        let asset = AVURLAsset(url: effectiveSourceURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            throw FilmtoneMediaError.unsupportedSource("No video track was found in the selected source.")
        }

        let sourceDurationSec = CMTimeGetSeconds(asset.duration)
        let posterTimeSec = makePreviewPosterTime(sourceDurationSec: sourceDurationSec)
        let outputSize = ExportGeometry.scaledSize(for: videoTrack, longEdge: request.output.longEdge)

        let posterTime = CMTime(seconds: posterTimeSec, preferredTimescale: 600)
        let cgImage = try copyPreviewCGImage(for: asset, at: posterTime)
        let posterImage = CIImage(cgImage: cgImage)
        let original = sourceImageNormalizer.scaledStillSourceImage(posterImage, outputSize: outputSize)
        let graded = applyGrade(original, posterTimeSec).cropped(to: original.extent)

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

    private func makePreviewPosterTime(sourceDurationSec: Double) -> Double {
        guard sourceDurationSec.isFinite, sourceDurationSec > 0 else {
            return 0
        }
        let candidate = sourceDurationSec * 0.25
        return min(max(candidate, 0), sourceDurationSec)
    }

    private func writePreviewImage(_ image: CIImage, preferredName: String) throws -> URL {
        let url = try cacheStore.temporaryPreviewURL(preferredName: preferredName, pathExtension: "jpg")
        try writeJPEGImage(image, to: url)
        return url
    }

    private func writeJPEGImage(_ image: CIImage, to url: URL) throws {
        guard let data = ciContext.jpegRepresentation(
            of: image,
            colorSpace: outputColorSpace,
            options: [:]
        ) else {
            throw FilmtoneMediaError.exportFailed("JPEG data could not be created.")
        }
        try data.write(to: url, options: .atomic)
    }
}
