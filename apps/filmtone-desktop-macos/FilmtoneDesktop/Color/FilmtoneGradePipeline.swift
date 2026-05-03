import CoreImage
import Foundation

// Phase 1b primary grade chain: baseGradeV2 → filmCompressionV2 → printStage.
// Phase 2 C5a: vignette + grain inserted in iOS canonical order.
// Phase 2 C5c: RayAngleOptics integrated — vignette now computes real
// opticsPack + applyMask from camera optics metadata when available.
//
//   baseGradeV2 → filmCompressionV2 → vignette → grain → printStage
//
// Multi-pass blur (bloom/halation/diffusion) and CIKernel-based stages
// (radialRGBSplit / edgeSoftnessBlend) remain deferred until C5b.

enum FilmtoneGradePipeline {
    static func apply(
        to image: CIImage,
        params: FilmtonePhase0Params,
        frameTimeSeconds: Double = 0,
        sourceSeed: Double = 0,
        cameraOptics: CameraOpticsDTO? = nil
    ) -> CIImage {
        var current = image

        if shouldApplyBaseGrade(params) {
            current = applyBaseGradeV2(to: current, params: params)
        }
        if params.compressionAmount > 0.0001 {
            current = applyFilmCompressionV2(to: current, params: params)
        }
        if params.vignette > 0.0001 {
            current = applyVignette(to: current, params: params, cameraOptics: cameraOptics)
        }
        let clampedGrain = max(0, min(FilmtonePhase0Generated.grainIntensityMax, params.grainIntensity))
        if clampedGrain > 0.0001 {
            current = applyGrain(
                to: current,
                intensity: clampedGrain,
                params: params,
                timeSeconds: frameTimeSeconds,
                sourceSeed: sourceSeed
            )
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

    private static func applyVignette(
        to image: CIImage,
        params: FilmtonePhase0Params,
        cameraOptics: CameraOpticsDTO?
    ) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.vignette else { return image }
        let extent = image.extent
        let origin = CIVector(x: extent.origin.x, y: extent.origin.y)
        let size = CIVector(x: extent.size.width, y: extent.size.height)
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let inner = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold

        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: cameraOptics,
            imageWidth: Double(extent.width),
            imageHeight: Double(extent.height)
        )
        let opticsPack = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(extent.width),
            imageHeight: Double(extent.height)
        )
        let applyMask: Double = (cameraOptics?.source == "metadata") ? 1.0 : 0.0

        return kernel.apply(extent: extent, arguments: [
            image,
            params.vignette,
            origin,
            size,
            gamma,
            inner,
            opticsPack,
            applyMask,
        ]) ?? image
    }

    private static func applyGrain(
        to image: CIImage,
        intensity: Double,
        params: FilmtonePhase0Params,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.grain else { return image }
        let extent = image.extent
        let origin = CIVector(x: extent.origin.x, y: extent.origin.y)
        let size = CIVector(x: extent.size.width, y: extent.size.height)
        return kernel.apply(extent: extent, arguments: [
            image,
            intensity,
            params.grainRadialMix,
            params.grainSize,
            timeSeconds,
            sourceSeed,
            origin,
            size,
        ]) ?? image
    }
}
