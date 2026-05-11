import CoreGraphics
import CoreImage
import CoreVideo
import FilmLabSwiftCore
import Foundation

/// Phase 2B-8A: source image normalization collaborator lifted out of
/// `FilmtoneExportSession`. Owns still-source loading, video pixel-buffer
/// wrapping with HDR-to-SDR tone-map detection, AVAssetTrack→Core Image
/// orientation transform, still/video/preview scale-crop normalization, and
/// preview extent validation.
///
/// `renderableImage`, `renderableStillImage`, `renderablePreviewVideoImage`,
/// `applyGrade`, `applyVideoMotionStage`, `exportVideo`, and
/// `exportStillImage` remain on `FilmtoneExportSession` so grade / motion /
/// depth stage order stays session-owned. The session delegates only source
/// loading, image wrapping, orientation transform, scale/crop, and preview
/// extent validation. `coreImageVideoTransform` is exposed as a `static`
/// helper because `Services/MezzanineService` shares the same orientation
/// math when prewarming mezzanine variants.
final class ExportSourceImageNormalizer {
    private let colorPipeline: FilmtoneColorPipelineContract

    init(colorPipeline: FilmtoneColorPipelineContract) {
        self.colorPipeline = colorPipeline
    }

    func loadedSourceImage(at url: URL) -> CIImage? {
        CIImage(contentsOf: url, options: colorPipeline.stillImageOptions())
    }

    func sourceVideoImage(from imageBuffer: CVPixelBuffer) -> CIImage {
        let options = colorPipeline.sourceImageOptions(
            for: imageBuffer,
            toneMapHDRToSDR: shouldToneMapHDRToSDR(imageBuffer)
        )
        return CIImage(cvPixelBuffer: imageBuffer, options: options)
    }

    func sourcePreviewVideoImage(from image: CIImage) -> CIImage {
        // AVVideoComposition already provides this image in presentation
        // orientation. Rewrapping its backing pixel buffer drops that transform
        // and makes portrait clips preview as raw landscape frames.
        return image
    }

    func scaledVideoSourceImage(
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

    func scaledPreviewVideoSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
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

    func scaledStillSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage {
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

    func validatePreviewVideoImage(_ image: CIImage, outputSize: CGSize) throws {
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
}
