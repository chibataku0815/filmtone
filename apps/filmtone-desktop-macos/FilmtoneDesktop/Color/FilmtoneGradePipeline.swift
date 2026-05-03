import CoreImage
import Foundation

// Phase 1b primary grade chain: input → baseGradeV2 → filmCompressionV2 →
// printStage → output. Optics (bloom / halation / diffusion / vignette /
// grain / motion blur) and rgbShift / lensSoftness are intentionally
// deferred to Phase 1c (video) / Phase 2 (Native Color/Export Backbone)
// per master handoff §7 / §8.
//
// All three kernels are CIColorKernel (per-pixel) and operate in the
// CIContext's working color space. Callers must configure the context with
// `workingColorSpace = linear sRGB` so the math sees linear values.

enum FilmtoneGradePipeline {
    static func apply(
        to image: CIImage,
        params: FilmtonePhase0Params
    ) -> CIImage {
        var current = image

        if shouldApplyBaseGrade(params) {
            current = applyBaseGradeV2(to: current, params: params)
        }
        if params.compressionAmount > 0.0001 {
            current = applyFilmCompressionV2(to: current, params: params)
        }
        if shouldApplyPrintStage(params) {
            current = applyPrintStage(to: current, params: params)
        }

        return current
    }

    private static func shouldApplyBaseGrade(_ p: FilmtonePhase0Params) -> Bool {
        let epsilon = 1e-4
        return abs(p.exposure) > epsilon
            || abs(p.contrast - 1.0) > epsilon
            || abs(p.saturation - 1.0) > epsilon
            || abs(p.temperature) > epsilon
            || abs(p.tint) > epsilon
            || abs(p.fade) > epsilon
            || abs(p.shadowTone) > epsilon
            || abs(p.highlightTone) > epsilon
    }

    private static func shouldApplyPrintStage(_ p: FilmtonePhase0Params) -> Bool {
        let epsilon = 1e-4
        return abs(p.printContrast) > epsilon
            || abs(p.cyan) > epsilon
            || abs(p.magenta) > epsilon
            || abs(p.yellow) > epsilon
    }

    private static func applyBaseGradeV2(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.baseGradeV2 else { return image }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.exposure,
            params.contrast,
            params.saturation,
            params.temperature,
            params.tint,
            params.fade,
            params.shadowTone,
            params.highlightTone,
            params.shadowHue,
            params.highlightHue,
        ]) ?? image
    }

    private static func applyFilmCompressionV2(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.filmCompressionV2 else { return image }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.compressionAmount,
            params.compressionRange,
        ]) ?? image
    }

    private static func applyPrintStage(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.printStage else { return image }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.printContrast,
            params.cyan,
            params.magenta,
            params.yellow,
        ]) ?? image
    }
}
