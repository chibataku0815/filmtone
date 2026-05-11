import CoreImage
import FilmLabSwiftCore
import Foundation

// Phase 1b primary grade chain: baseGradeV2 → filmCompressionV2 → printStage.
// Phase 2 C5a: vignette + grain inserted in iOS canonical order.
// Phase 2 C5c: RayAngleOptics integrated — vignette computes opticsPack + applyMask.
// Phase 2 C5b A.1: glowFamily inserted before vignette (iOS canonical order).
// Phase 2 C5b A.2: halation + diffusion plates activated (bloom + halation + diffusion all live).
// Phase 2 C5b A.3: edgeOptics (radialRGBSplit + edgeSoftnessBlend) inserted between
//   filmCompressionV2 and glowFamily (iOS canonical order, FilmtoneExportSession L1565).
// M5-A.2: creativeLut inserted between grain and printStage (iOS canonical
//   FilmtoneExportSession L1561). Caller passes nil for the legacy
//   "no Look" path; the stage is a no-op then.
// M5-M follow-up: the creative LUT stage now alpha-blends by the caller's
//   `lutIntensity`. iOS canonical pins `lut.intensity = 1.0` per Pack 01
//   recipe and lets `presetStrength` drive a preset-lerp; on macOS we
//   instead resolve the Look path to its full target params and route the
//   user-facing Strength slider into this stage's alpha. strength=1.0 is
//   byte-identical to the prior simple path; intermediate strengths are
//   the documented platform divergence (continuous LUT alpha vs preset
//   lerp).
//
// Phase 2-B Detail Softness: local-reference high-pass attenuation
//   inserted between filmCompressionV2 and edgeOptics, per
//   docs/filmtone/detail-softness/archive/2026-05-12-phase-2a-research-charter.md
//   §Stage insertion points → macOS native. Identity at
//   `effectiveDetailSoftness == 0` (caller short-circuit + kernel guard).
//
//   baseGradeV2 → filmCompressionV2 → detailSoftness → edgeOptics → glowFamily → vignette → grain → creativeLut → printStage

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

    // MARK: — Edge optics constants (verbatim from iOS FilmtoneExportSession L128-134)
    private static let aberrationEdgeSoftenScale = 32.0
    private static let aberrationEdgeSoftenMax = 0.52
    private static let aberrationEdgeSoftenCurve = 1.55
    private static let aberrationBlurRadiusMin = 1.6
    private static let aberrationBlurRadiusMax = 6.2
    private static let aberrationBlurRadiusCap = 7.8
    private static let lensSoftnessBlurBoost = 1.85

    // MARK: — Primary pipeline

    static func apply(
        to image: CIImage,
        params: FilmtonePhase0Params,
        frameTimeSeconds: Double = 0,
        sourceSeed: Double = 0,
        cameraOptics: CameraOpticsDTO? = nil,
        creativeLut: PreparedCreativeLut? = nil,
        lutIntensity: Double = 1.0,
        opticalFilterProfileId: String? = nil,
        opticalFilterIntensity: Double = 1.0
    ) -> CIImage {
        var current = image

        if shouldApplyBaseGrade(params) {
            current = applyBaseGradeV2(to: current, params: params)
        }
        if params.compressionAmount > 0.0001 {
            current = applyFilmCompressionV2(to: current, params: params)
        }
        current = applyDetailSoftnessStage(to: current, params: params)
        current = applyEdgeOpticsStage(to: current, params: params)
        // M5-M (CC-B): Backlight Veil profiles route through a CIKernel
        // composite that uses the six iOS-canonical optical scatter
        // coefficients (direct loss, black retention, scatter strength,
        // highlight reactivity, warm bias, spectral tail). Other profile
        // selections (or `nil`), or intensity ≤ 0, fall through to the
        // legacy glowComposite path so non-veil renders stay bytewise
        // identical and intensity=0 leaves only explicit user overrides
        // visible (no Backlight-specific direct-loss/scatter math).
        let opticalScatter = FilmtoneOpticalFilterCatalog.intensityScaledScatter(
            for: opticalFilterProfileId,
            intensity: opticalFilterIntensity
        )
        current = applyGlowFamilyStage(
            to: current,
            params: params,
            opticalScatter: opticalScatter
        )
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
        if let creativeLut {
            current = applyCreativeLutStage(
                to: current,
                lut: creativeLut,
                intensity: lutIntensity
            )
        }
        if shouldApplyPrintStage(params) {
            current = applyPrintStage(to: current, params: params)
        }

        return current
    }

    // MARK: — Creative LUT (M5-A.2 — iOS canonical FilmtoneExportSession L2077)

    private static func applyCreativeLutStage(
        to image: CIImage,
        lut: PreparedCreativeLut,
        intensity: Double
    ) -> CIImage {
        // M5-M follow-up: alpha-blend mirroring iOS `applyLut`
        // (FilmtoneExportSession L2292-2311). `intensity` is the user-facing
        // Look Strength on macOS; iOS pins it to `lut.intensity` (Pack 01 =
        // 1.0) and drives the slider through preset-lerp. strength=1.0
        // collapses to the same `CIColorCubeWithColorSpace`-only path as
        // the previous implementation (byte-identical).
        let cubed = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": lut.size,
            "inputCubeData": lut.cubeData,
            "inputColorSpace": FilmtoneCIContext.outputColorSpace,
        ])
        let alpha = clampValue(intensity)
        if alpha >= 0.999 { return cubed }
        if alpha <= 0.001 { return image }
        let attenuated = cubed.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: alpha),
        ])
        return attenuated
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)
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
        return p.printContrast > epsilon
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

    // MARK: — Detail softness (Phase 2-B macOS native pilot)

    // Local-reference high-pass attenuation. Identity at
    // `effectiveDetailSoftness == 0` — short-circuits before any CIImage
    // construction, so non-`detailSoftness` renders stay bit-identical to
    // the pre-Phase-2 pipeline. Inserted between `filmCompressionV2` and
    // `edgeOptics` per Phase 2-A insertion-point survey.
    private static func applyDetailSoftnessStage(
        to image: CIImage,
        params: FilmtonePhase0Params
    ) -> CIImage {
        let uniforms = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: params.detailSoftness)
        if uniforms.effectiveDetailSoftness < 0.0001 {
            return image
        }
        guard let kernel = FilmtoneGradeKernels.detailSoftness else { return image }

        let padding = CGFloat(ceil(uniforms.kernelRadiusPx) + 1.0)
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect.insetBy(dx: -padding, dy: -padding) },
            arguments: [
                image.clampedToExtent(),
                uniforms.effectiveDetailSoftness,
                uniforms.kernelRadiusPx,
                uniforms.chromaAttenScale,
                uniforms.edgeGuardLo,
                uniforms.edgeGuardHi,
                uniforms.highlightBias,
            ]
        )?.cropped(to: image.extent) ?? image
    }

    // MARK: — Edge optics (C5b A.3 — radialRGBSplit + edgeSoftnessBlend)

    private static func applyEdgeOpticsStage(to image: CIImage, params: FilmtonePhase0Params) -> CIImage {
        var current = image

        if params.rgbShift > 0.0001 {
            current = applyRadialRGBShift(params.rgbShift, to: current)
        }

        let rgbShiftNormalized = clampValue(
            params.rgbShift / Swift.max(FilmtonePhase0Generated.rgbShiftMax, 0.0001)
        )
        let aberrationSoften = aberrationEdgeSoften(for: rgbShiftNormalized)
        if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
            current = applyEdgeSoftness(
                to: current,
                aberrationSoften: aberrationSoften,
                lensSoftness: params.lensSoftness
            )
        }

        return current
    }

    private static func applyRadialRGBShift(_ amount: Double, to image: CIImage) -> CIImage {
        guard let kernel = FilmtoneGradeKernels.radialRGBSplit else {
            return image
        }

        let padding = CGFloat(Swift.max(4.0, abs(amount) * Swift.max(image.extent.width, image.extent.height)))
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in
                rect.insetBy(dx: -padding, dy: -padding)
            },
            arguments: [
                image,
                amount,
                extentOriginVector(for: image.extent),
                extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private static func applyEdgeSoftness(
        to image: CIImage,
        aberrationSoften: Double,
        lensSoftness: Double
    ) -> CIImage {
        let lensDrive = pow(clampValue(lensSoftness), 0.78)
        let aberrationDrive = pow(
            clampValue(aberrationSoften / aberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = Swift.min(
            lerp(
                aberrationBlurRadiusMin,
                aberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * lensSoftnessBlurBoost),
            aberrationBlurRadiusCap
        )
        guard blurRadius > 0.0001, let kernel = FilmtoneGradeKernels.edgeSoftnessBlend else {
            return image
        }

        let blurred = image
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurRadius,
            ])
            .cropped(to: image.extent)

        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect },
            arguments: [
                image,
                blurred,
                clampValue(aberrationSoften),
                clampValue(lensSoftness),
                extentOriginVector(for: image.extent),
                extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private static func aberrationEdgeSoften(for normalizedRgbShift: Double) -> Double {
        let normalized = clampValue(normalizedRgbShift)
        guard normalized > 0.0001 else {
            return 0
        }

        let linear = normalized * (aberrationEdgeSoftenScale * FilmtonePhase0Generated.rgbShiftMax)
        let boosted = pow(normalized, aberrationEdgeSoftenCurve) * aberrationEdgeSoftenMax
        return Swift.min(aberrationEdgeSoftenMax, Swift.max(linear, boosted))
    }

    private static func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + (end - start) * t
    }

    // MARK: — Glow family (C5b A.2 — bloom + halation + diffusion plates all active)

    private static func applyGlowFamilyStage(
        to image: CIImage,
        params: FilmtonePhase0Params,
        opticalScatter: FilmtoneOpticalScatterParams? = nil
    ) -> CIImage {
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

        let halationImage: CIImage
        if params.halationIntensity > 0.0001 {
            let halationPlate = extractHighlightPlate(
                from: image,
                threshold: params.halationThreshold,
                knee: params.halationSoftKnee,
                tintColor: halationColor(for: params.halationHue)
            )
            halationImage = buildMipBlurComposite(
                from: halationPlate,
                radius: params.halationRadius,
                levelCount: halationMipLevels,
                spreadMultiplier: 1.0 + Swift.max(params.halationSpread, 0) / halationSpreadDivisor,
                useTentResampling: true
            )
        } else {
            halationImage = black
        }

        let diffusionImage: CIImage
        if params.diffusion > 0.0001 {
            diffusionImage = buildMipBlurComposite(
                from: image,
                radius: 0.9,
                levelCount: diffusionMipLevels,
                spreadMultiplier: 1.15,
                useTentResampling: true
            )
        } else {
            diffusionImage = black
        }

        if let opticalScatter,
           let veilKernel = FilmtoneGradeKernels.glowCompositeBacklightVeil {
            return veilKernel.apply(extent: extent, arguments: [
                image,
                bloomImage,
                halationImage,
                diffusionImage,
                params.bloomStrength,
                params.halationIntensity,
                params.diffusion,
                opticalScatter.directTransmission,
                opticalScatter.blackRetention,
                opticalScatter.scatterStrength,
                opticalScatter.highlightReactivity,
                opticalScatter.warmScatter,
                opticalScatter.spectralTail,
            ]) ?? image
        }

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

    private static func halationColor(for hue: Double) -> CIColor {
        let t = clampValue(hue / 100.0)
        let red   = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
        let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
        let blue  = (0x20 + ((0x10 - 0x20) * t)) / 255.0
        return CIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func clampValue(_ value: Double, min minVal: Double = 0, max maxVal: Double = 1) -> Double {
        Swift.min(Swift.max(value, minVal), maxVal)
    }

    // MARK: — Per-source grain seed (verbatim from iOS FilmtoneExportSession L2411-2418)

    /// Stable per-source salt for the grain kernel. Verbatim FNV-1a-style
    /// hash mod 8192. iOS computes this from `sourceURL.absoluteString`; the
    /// macOS exporters / preview pass through the same string so a given
    /// source produces the same grain pattern across both platforms (and
    /// across preview ↔ export on macOS).
    static func makeStableSourceSeed(from string: String) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 8_192)
    }
}
