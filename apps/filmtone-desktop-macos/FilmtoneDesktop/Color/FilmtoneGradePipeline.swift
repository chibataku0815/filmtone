import CoreImage
import Foundation

// Phase 1b primary grade chain: baseGradeV2 → filmCompressionV2 → printStage.
// Phase 2 C5a: vignette + grain inserted in iOS canonical order.
// Phase 2 C5c: RayAngleOptics integrated — vignette computes opticsPack + applyMask.
// Phase 2 C5b A.1: glowFamily inserted before vignette (iOS canonical order).
//   bloom path active; halation + diffusion plates deferred to C5b A.2 (black).
//
//   baseGradeV2 → filmCompressionV2 → glowFamily → vignette → grain → printStage
//
// CIKernel-based stages (radialRGBSplit / edgeSoftnessBlend) deferred to C5b A.3.

enum FilmtoneGradePipeline {

    // MARK: — Glow pyramid constants (verbatim from iOS FilmtoneExportSession)
    private static let glowBaseScale = 0.5
    private static let bloomSpreadBoost = 1.25
    private static let halationSpreadDivisor = 12.0
    private static let diffusionCompositeBase = 0.87
    private static let bloomMipLevels = 6
    private static let halationMipLevels = 6
    private static let diffusionMipLevels = 4
    private static let glowUpsampleBlurRadius = 1.0

    // MARK: — Primary pipeline

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
        current = applyGlowFamilyStage(to: current, params: params)
        if params.vignette > 0.0001 {
            current = applyVignette(to: current, params: params, cameraOptics: cameraOptics)
        }
        let clampedGrain = Swift.max(0, Swift.min(FilmtonePhase0Generated.grainIntensityMax, params.grainIntensity))
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

    // MARK: — Grade stages

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

    // MARK: — Glow family (C5b A.1 — bloom active; halation + diffusion plates deferred to A.2)

    private static func applyGlowFamilyStage(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
        guard
            params.bloomStrength > 0.0001 ||
            params.halationIntensity > 0.0001 ||
            params.diffusion > 0.0001
        else {
            return image
        }

        let extent = image.extent
        let black = blackImage(for: extent)

        let bloomImage: CIImage
        if params.bloomStrength > 0.0001 {
            let bloomPlate = extractHighlightPlate(
                from: image,
                threshold: params.bloomThreshold,
                knee: params.bloomSoftKnee,
                tintColor: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
            bloomImage = buildMipBlurComposite(
                from: bloomPlate,
                radius: params.bloomRadius,
                levelCount: bloomMipLevels,
                spreadMultiplier: bloomSpreadBoost,
                useTentResampling: true
            )
        } else {
            bloomImage = black
        }

        // C5b A.2: halation + diffusion plates (currently black)
        let halationImage: CIImage = black
        let diffusionImage: CIImage = black

        guard let kernel = FilmtoneGradeKernels.glowComposite else { return image }
        return kernel.apply(extent: extent, arguments: [
            image,
            bloomImage,
            halationImage,
            diffusionImage,
            params.bloomStrength,
            params.halationIntensity,
            params.diffusion,
            diffusionCompositeBase,
        ]) ?? image
    }

    // MARK: — Glow pyramid helpers (verbatim from iOS FilmtoneExportSession)

    private static func extractHighlightPlate(
        from image: CIImage,
        threshold: Double,
        knee: Double,
        tintColor: CIColor
    ) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.softKneeHighlight else {
            return blackImage(for: image.extent)
        }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            clampValue(threshold),
            clampValue(knee),
            tintColor,
        ]) ?? blackImage(for: image.extent)
    }

    private static func buildMipBlurComposite(
        from image: CIImage,
        radius: Double,
        levelCount: Int,
        spreadMultiplier: Double,
        useTentResampling: Bool = false
    ) -> CIImage {
        let extent = image.extent.integral
        guard levelCount > 0 else { return blackImage(for: extent) }

        var mips = buildMipPyramid(
            from: image,
            levelCount: levelCount,
            initialScale: glowBaseScale / Swift.max(spreadMultiplier, 0.0001),
            useTentResampling: useTentResampling
        )
        guard !mips.isEmpty else { return blackImage(for: extent) }

        let weights = computeMipWeights(radius: clampValue(radius), levels: mips.count)
        if mips.count > 1 {
            for index in stride(from: mips.count - 2, through: 0, by: -1) {
                let lowRes = mips[index + 1]
                let highRes = mips[index]
                let restored = useTentResampling
                    ? tentUpsampledImage(lowRes, to: highRes.extent)
                    : upsampledImage(lowRes, to: highRes.extent)
                let weighted = weightedImage(restored, weight: weights[index + 1])
                mips[index] = addImages(weighted, highRes).cropped(to: highRes.extent)
            }
        }

        let output = useTentResampling
            ? tentUpsampledImage(mips[0], to: extent)
            : upsampledImage(mips[0], to: extent)
        return output.cropped(to: extent)
    }

    private static func buildMipPyramid(
        from image: CIImage,
        levelCount: Int,
        initialScale: Double,
        useTentResampling: Bool = false
    ) -> [CIImage] {
        guard levelCount > 0 else { return [] }
        var mips: [CIImage] = []
        var current = useTentResampling
            ? tentDownsampledImage(image, scale: initialScale)
            : downsampledImage(image, scale: initialScale)
        mips.append(current)
        guard levelCount > 1 else { return mips }
        for _ in 1..<levelCount {
            current = useTentResampling
                ? tentDownsampledImage(current, scale: 0.5)
                : downsampledImage(current, scale: 0.5)
            mips.append(current)
        }
        return mips
    }

    private static func tentDownsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = Swift.min(1.0, Swift.max(scale, 0.0001))
        let sourceExtent = image.extent.integral
        let targetSize = CGSize(
            width: Swift.max(1.0, (sourceExtent.width * safeScale).rounded()),
            height: Swift.max(1.0, (sourceExtent.height * safeScale).rounded())
        )
        let targetExtent = CGRect(origin: .zero, size: targetSize)
        guard let kernel = FilmtoneGradeKernels.tentDownsample else {
            return downsampledImage(image, scale: scale)
        }
        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / Swift.max(targetExtent.width, 1.0),
                    y: sourceExtent.height / Swift.max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? downsampledImage(image, scale: scale)
    }

    private static func tentUpsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }
        let sourceExtent = image.extent.integral
        let targetExtent = extent.integral
        guard let kernel = FilmtoneGradeKernels.tentUpsample else {
            return upsampledImage(image, to: extent)
        }
        return kernel.apply(
            extent: targetExtent,
            roiCallback: { _, _ in sourceExtent },
            arguments: [
                image,
                extentOriginVector(for: sourceExtent),
                extentSizeVector(for: sourceExtent),
                extentOriginVector(for: targetExtent),
                CIVector(
                    x: sourceExtent.width / Swift.max(targetExtent.width, 1.0),
                    y: sourceExtent.height / Swift.max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? upsampledImage(image, to: extent)
    }

    private static func downsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = Swift.min(1.0, Swift.max(scale, 0.0001))
        let targetSize = CGSize(
            width: Swift.max(1.0, (image.extent.width * safeScale).rounded()),
            height: Swift.max(1.0, (image.extent.height * safeScale).rounded())
        )
        return scaledImage(image, scale: safeScale).cropped(to: CGRect(origin: .zero, size: targetSize))
    }

    private static func upsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }
        let scale = extent.width / image.extent.width
        let upsampled = scaledImage(image, scale: scale).cropped(to: extent)
        guard scale > 1.0001, glowUpsampleBlurRadius > 0.0001 else { return upsampled }
        return upsampled
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: glowUpsampleBlurRadius])
            .cropped(to: extent)
    }

    private static func scaledImage(_ image: CIImage, scale: Double) -> CIImage {
        guard abs(scale - 1.0) > 0.0001 else { return image }
        return image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0,
        ])
    }

    private static func weightedImage(_ image: CIImage, weight: Double) -> CIImage {
        guard weight > 0 else { return blackImage(for: image.extent) }
        guard abs(weight - 1.0) > 0.0001 else { return image }
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: weight, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: weight, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: weight, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": zero,
        ])
    }

    private static func addImages(_ foreground: CIImage, _ background: CIImage) -> CIImage {
        foreground
            .applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: background,
            ])
            .cropped(to: background.extent)
    }

    private static func blackImage(for extent: CGRect) -> CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
    }

    private static func extentOriginVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.origin.x, y: extent.origin.y)
    }

    private static func extentSizeVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.width, y: extent.height)
    }

    private static func computeMipWeights(radius: Double, levels: Int) -> [Double] {
        (0..<levels).map { index in
            let t = Double(index) / Double(Swift.max(levels - 1, 1))
            let base = exp(-3.0 * (1.0 - radius) * t)
            let wide = exp(-0.5 * radius * (1.0 - t))
            return (base * (1.0 - radius)) + (wide * radius)
        }
    }

    private static func clampValue(_ value: Double, min minVal: Double = 0, max maxVal: Double = 1) -> Double {
        Swift.min(Swift.max(value, minVal), maxVal)
    }
}
