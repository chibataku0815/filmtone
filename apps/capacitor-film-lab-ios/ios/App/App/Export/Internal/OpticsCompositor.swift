import CoreGraphics
import CoreImage
import FilmLabSwiftCore
import Foundation

/// Stateful optics orchestrator lifted out of `FilmtoneExportSession`
/// during Phase 2B-5B. Owns the Metal optics gate / renderer lifecycle,
/// the per-frame and once-per-export telemetry flags, the Backlight Veil
/// profile resolution and spatial-key max-merge, and the edge optics /
/// glow family / vignette CI fallback paths.
///
/// 5A already moved the stateless resampling math into `OpticsResampling`.
/// 5B keeps the Metal vs. CI gate predicate, the CI fallback ordering,
/// kernel argument order, and Backlight Veil composite path byte-identical
/// to the pre-move pipeline.
///
/// `loadedDepthMap` ownership stays on `FilmtoneExportSession` because its
/// lifetime belongs to the still/video decode paths; the compositor
/// receives the current value per `applyGlowFamilyStage` call.
final class OpticsCompositor {
    private let request: Phase0ExportRequestDTO
    private let disableGlowFamilyForExport: Bool
    private let useMetalOpticsForExport: Bool
    private let ciContext: CIContext
    private let colorPipeline: FilmtoneColorPipelineContract

    private lazy var metalOpticsRenderer: FilmtoneMetalOpticsRenderer? =
        FilmtoneMetalOpticsRenderer(
            workingColorSpace: colorPipeline.workingColorSpace,
            ciContext: ciContext
        )

    private(set) var metalOpticsActiveOnce = false
    private(set) var metalVignetteActiveOnce = false
    private var metalVignetteAppliedThisFrame = false
    private(set) var depthPrefilterMs: Double?

    init(
        request: Phase0ExportRequestDTO,
        disableGlowFamilyForExport: Bool,
        useMetalOpticsForExport: Bool,
        ciContext: CIContext,
        colorPipeline: FilmtoneColorPipelineContract
    ) {
        self.request = request
        self.disableGlowFamilyForExport = disableGlowFamilyForExport
        self.useMetalOpticsForExport = useMetalOpticsForExport
        self.ciContext = ciContext
        self.colorPipeline = colorPipeline
    }

    var disabledRenderStages: [String] {
        disableGlowFamilyForExport
            ? [FilmtoneExportRenderSubstage.glowFamily.rawValue]
            : []
    }

    var acceleratedRenderStages: [String] {
        var stages: [String] = []
        if metalOpticsActiveOnce {
            stages.append(FilmtoneExportRenderSubstage.glowFamily.rawValue + "/metal")
        }
        if metalVignetteActiveOnce {
            stages.append(FilmtoneExportRenderSubstage.vignette.rawValue + "/metal")
        }
        return stages
    }

    /// Phase 2 段階 1: clear the per-frame Metal vignette flag before any
    /// stage runs. `applyGlowFamilyStage` sets it true when the Metal
    /// optics chain absorbs the vignette pass; `applyVignetteStage`
    /// consumes it to skip the CI path.
    func resetFrameState() {
        metalVignetteAppliedThisFrame = false
    }

    /// Backlight Veil Phase 1c — if a Backlight Veil family is active,
    /// its 12 spatial keys override the user's optical signature so the
    /// scatter math has the canonical plate inputs. Color-grade params
    /// stay untouched, so the user's Look color is preserved and the
    /// Veil layers on top as a lens veil.
    func paramsApplyingBacklightVeil(to baseParams: Phase0ParamsDTO) -> Phase0ParamsDTO {
        guard let veilSpatial = currentBacklightVeilProfile()?.spatial else {
            return baseParams
        }
        return applyBacklightVeilSpatialOverrides(baseParams, spatial: veilSpatial)
    }

    func applyEdgeOpticsStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        var current = image

        if params.rgbShift > 0.0001 {
            current = applyRadialRGBShift(params.rgbShift, to: current)
        }

        let rgbShiftNormalized = Self.clamp(
            params.rgbShift / max(FilmtonePhase0Generated.rgbShiftMax, 0.0001)
        )
        let aberrationSoften = OpticsResampling.aberrationEdgeSoften(for: rgbShiftNormalized)
        if aberrationSoften > 0.0001 || params.lensSoftness > 0.0001 {
            current = applyEdgeSoftness(
                to: current,
                aberrationSoften: aberrationSoften,
                lensSoftness: params.lensSoftness
            )
        }

        return current
    }

    /// Backlight Veil Phase 1c — resolves the request-selected profile
    /// (6 optical + 12 spatial keys) from `Phase0ExportRequestDTO`. Returns
    /// nil when OFF, in which case the legacy composite path runs unchanged.
    private func currentBacklightVeilProfile()
        -> FilmtoneOpticalFiltersGenerated.Profile? {
        guard
            let filterId = request.opticalFilterProfileId,
            let profile = FilmtoneOpticalFiltersGenerated.backlightVeilProfiles
                .first(where: { $0.id == filterId })
        else {
            return nil
        }
        return profile
    }

    /// Backlight Veil Phase 1c (energy max-merge port from macOS, 2026-05-06)
    /// — produces a `Phase0ParamsDTO` that layers the active Backlight Veil
    /// profile's spatial keys onto the existing `params`. Color-grade params
    /// (exposure / contrast / saturation / LUT etc.) remain untouched.
    ///
    /// Two merge regimes for the 12 spatial keys:
    ///   * **Energy keys** (`bloomStrength` / `halationIntensity` / `diffusion`
    ///     / `lensSoftness` / `rgbShift`): `max(params[k], veil[k])`. Veil
    ///     profiles are authored against the reset baseline; absolute overwrite
    ///     would let a Look (Stone `lensSoftness=0.095`, `rgbShift=0.0032`)
    ///     get clobbered by Veil's lower defaults (Veil 1/4 `lensSoftness=0.08`,
    ///     `rgbShift=0.0007`), perceptually weakening the veil.
    ///   * **Structural keys** (`bloomThreshold` / `bloomRadius` /
    ///     `bloomSoftKnee` / `halationThreshold` / `halationRadius` /
    ///     `halationHue` / `halationSoftKnee`): absolute overwrite — Veil's
    ///     spatial shape wins so the scatter math has stable plate inputs.
    ///
    /// Mirrors macOS `FilmtonePresetCatalog.applyVeilPatch`
    /// (`apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`).
    /// Note: iOS `state.paramOverrides` mixes Look-derived patch and
    /// user-manual edits in one map, so user-manual overrides do not get
    /// last-write-wins precedence over Veil energy keys here (macOS does,
    /// because it threads `paramOverrides` separately). Tracked as known
    /// iOS divergence.
    private func applyBacklightVeilSpatialOverrides(
        _ params: Phase0ParamsDTO,
        spatial s: FilmtoneOpticalFiltersGenerated.SpatialKeys
    ) -> Phase0ParamsDTO {
        Phase0ParamsDTO(
            exposure: params.exposure,
            contrast: params.contrast,
            saturation: params.saturation,
            temperature: params.temperature,
            tint: params.tint,
            rgbShift: max(params.rgbShift, s.rgbShift),
            lensSoftness: max(params.lensSoftness, s.lensSoftness),
            detailSoftness: params.detailSoftness,
            grainRadialMix: params.grainRadialMix,
            grainSize: params.grainSize,
            bloomThreshold: s.bloomThreshold,
            bloomStrength: max(params.bloomStrength, s.bloomStrength),
            bloomRadius: s.bloomRadius,
            diffusion: max(params.diffusion, s.diffusion),
            halationIntensity: max(params.halationIntensity, s.halationIntensity),
            halationSpread: params.halationSpread,
            halationHue: s.halationHue,
            halationThreshold: s.halationThreshold,
            halationRadius: s.halationRadius,
            bloomSoftKnee: s.bloomSoftKnee,
            halationSoftKnee: s.halationSoftKnee,
            compressionAmount: params.compressionAmount,
            compressionRange: params.compressionRange,
            printContrast: params.printContrast,
            cyan: params.cyan,
            magenta: params.magenta,
            yellow: params.yellow,
            shutterAngle: params.shutterAngle,
            trailIntensity: params.trailIntensity,
            filmBreathAmount: params.filmBreathAmount,
            dustAmount: params.dustAmount,
            scratchAmount: params.scratchAmount,
            fade: params.fade,
            shadowTone: params.shadowTone,
            shadowLatitude: params.shadowLatitude,
            blackPoint: params.blackPoint,
            toeContrast: params.toeContrast,
            highlightTone: params.highlightTone,
            shadowHue: params.shadowHue,
            highlightHue: params.highlightHue,
            vignette: params.vignette,
            grainIntensity: params.grainIntensity
        )
    }

    func applyGlowFamilyStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        loadedDepthMap: FilmtoneDepthMap?
    ) -> CIImage {
        let backlightVeilOptical = currentBacklightVeilProfile()?.optical

        // v1.5 Metal optics prototype gate. Quality video exports without
        // depth payload may route the entire glow family chain to the custom
        // MTLComputePipeline path. The renderer falls back internally on any
        // allocation/encoding failure, but we also gate on call-site safety
        // (depth requires the CI prefilter, still images use loadedDepthMap).
        if useMetalOpticsForExport,
           !disableGlowFamilyForExport,
           request.sourceKind == .video,
           (request.renderMode ?? .quality) == .quality,
           loadedDepthMap == nil,
           let renderer = metalOpticsRenderer
        {
            let opticalScatterParams: FilmtoneMetalOpticsRenderer.OpticalScatterParams? =
                backlightVeilOptical.map { keys in
                    FilmtoneMetalOpticsRenderer.OpticalScatterParams(
                        directTransmission: keys.directTransmission,
                        blackRetention: keys.blackRetention,
                        scatterStrength: keys.scatterStrength,
                        highlightReactivity: keys.highlightReactivity,
                        warmScatter: keys.warmScatter,
                        spectralTail: keys.spectralTail
                    )
                }
            let glowParams = FilmtoneMetalOpticsRenderer.GlowFrameParams(
                bloomStrength: params.bloomStrength,
                bloomThreshold: params.bloomThreshold,
                bloomSoftKnee: params.bloomSoftKnee,
                bloomRadius: params.bloomRadius,
                bloomMipLevels: OpticsResampling.bloomMipLevels,
                bloomSpreadBoost: OpticsResampling.bloomSpreadBoost,
                halationIntensity: params.halationIntensity,
                halationThreshold: params.halationThreshold,
                halationSoftKnee: params.halationSoftKnee,
                halationRadius: params.halationRadius,
                halationHue: params.halationHue,
                halationMipLevels: OpticsResampling.halationMipLevels,
                halationSpread: params.halationSpread,
                halationSpreadDivisor: OpticsResampling.halationSpreadDivisor,
                diffusion: params.diffusion,
                diffusionMipLevels: OpticsResampling.diffusionMipLevels,
                diffusionCompositeBase: OpticsResampling.diffusionCompositeBase,
                glowBaseScale: OpticsResampling.glowBaseScale,
                opticalScatter: opticalScatterParams
            )
            // Phase 2 段階 1: fold the vignette stage into the same Metal
            // pass when the params justify it. Vignette is only chained when
            // intensity > epsilon; otherwise the chain runs glow-only and
            // applyVignetteStage stays a no-op (CI path also no-ops).
            let vignetteParams = vignetteFrameParams(image: image, params: params)
            let chainParams = FilmtoneMetalOpticsRenderer.OpticsChainParams(
                glow: glowParams,
                vignette: vignetteParams
            )
            if let metalResult = renderer.renderOpticsChain(
                input: image,
                outputExtent: image.extent,
                params: chainParams
            ) {
                metalOpticsActiveOnce = true
                if vignetteParams != nil {
                    metalVignetteActiveOnce = true
                    metalVignetteAppliedThisFrame = true
                }
                return metalResult
            }
        }

        guard !disableGlowFamilyForExport else {
            return image
        }

        let extent = image.extent
        let black = OpticsResampling.blackImage(for: extent)

        // v1.3 (D3.2): depth × ray-angle prefilter on the glow trio.
        // Gated on `loadedDepthMap != nil`, which is only set in
        // `exportStillImage` when (depthEnabled && HEIC && hasDepth). With the
        // current contract `hiddenDefaults.depthMistGain == depthGlowGain == 0`
        // and the per-variant rayAngleGain/gamma/innerThreshold defaults, the
        // FilmtoneDepthPrefilter.apply short-circuits to `image` unchanged
        // (its first guard returns input when both gains are 0). UI inject of
        // non-zero gains is deferred to Stream 4 (a later wave); Phase A
        // landing is byte-identical to v1.2 unless a future call-site supplies
        // non-zero gains.
        let depthCI: CIImage? = loadedDepthMap?.ciImage
        let cameraOpticsDTO = request.sourceProbe?.cameraOptics
        let hidden = FilmtonePhase0Generated.hiddenDefaults
        let depthStart = (depthCI != nil) ? Date() : nil

        let bloomImage: CIImage
        if params.bloomStrength > 0.0001 {
            let bloomInput: CIImage
            if let depthCI {
                bloomInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .bloom,
                        depthGain: hidden.depthGlowGain,
                        rayAngleGain: hidden.depthBloomRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                bloomInput = image
            }
            let bloomPlate = extractHighlightPlate(
                from: bloomInput,
                threshold: params.bloomThreshold,
                knee: params.bloomSoftKnee,
                tintColor: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
            )
            bloomImage = buildMipBlurComposite(
                from: bloomPlate,
                radius: params.bloomRadius,
                levelCount: OpticsResampling.bloomMipLevels,
                spreadMultiplier: OpticsResampling.bloomSpreadBoost,
                useTentResampling: true,
                normalizedBandEnergy: backlightVeilOptical != nil
            )
        } else {
            bloomImage = black
        }

        let halationImage: CIImage
        if params.halationIntensity > 0.0001 {
            let halationInput: CIImage
            if let depthCI {
                halationInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .halation,
                        depthGain: hidden.depthGlowGain,
                        rayAngleGain: hidden.depthHalationRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                halationInput = image
            }
            let halationPlate = extractHighlightPlate(
                from: halationInput,
                threshold: params.halationThreshold,
                knee: params.halationSoftKnee,
                tintColor: OpticsResampling.halationColor(for: params.halationHue)
            )
            halationImage = buildMipBlurComposite(
                from: halationPlate,
                radius: params.halationRadius,
                levelCount: OpticsResampling.halationMipLevels,
                spreadMultiplier: 1.0 + max(params.halationSpread, 0) / OpticsResampling.halationSpreadDivisor,
                useTentResampling: true
            )
        } else {
            halationImage = black
        }

        let diffusionImage: CIImage
        if params.diffusion > 0.0001 {
            let diffusionInput: CIImage
            if let depthCI {
                diffusionInput = FilmtoneDepthPrefilter.apply(
                    to: image,
                    depth: depthCI,
                    imageExtent: extent,
                    optics: cameraOpticsDTO,
                    params: .init(
                        variant: .mist,
                        depthGain: hidden.depthMistGain,
                        rayAngleGain: hidden.depthMistRayAngleGain,
                        rayAngleGamma: hidden.depthRayAngleGamma,
                        rayAngleInnerThreshold: hidden.depthRayAngleInnerThreshold
                    )
                )
            } else {
                diffusionInput = image
            }
            diffusionImage = buildMipBlurComposite(
                from: diffusionInput,
                radius: 0.9,
                levelCount: OpticsResampling.diffusionMipLevels,
                spreadMultiplier: 1.15,
                useTentResampling: true
            )
        } else {
            diffusionImage = black
        }

        if let depthStart {
            let elapsed = Date().timeIntervalSince(depthStart) * 1000.0
            depthPrefilterMs = (depthPrefilterMs ?? 0) + elapsed
        }

        guard
            params.bloomStrength > 0.0001 ||
            params.halationIntensity > 0.0001 ||
            params.diffusion > 0.0001
        else {
            return image
        }

        if let backlightVeilOptical {
            // Deep Glow compatibility CI fallback. The main radiance field
            // uses normalized bands and an exposure response; the retained
            // scatter coefficients preserve the established optical finish.
            // 9 args (3 spatial floats + 6 optical floats); diffusionBase
            // drops out because the new kernel multiplies diffused by the
            // hardcoded 0.24 from WGSL.
            guard let kernel = OpticalKernels.glowCompositeBacklightVeil else {
                return image
            }
            return kernel.apply(extent: extent, arguments: [
                image,
                bloomImage,
                halationImage,
                diffusionImage,
                OpticsResampling.radianceExposureGain(params.bloomStrength),
                params.halationIntensity,
                params.diffusion,
                backlightVeilOptical.directTransmission,
                backlightVeilOptical.blackRetention,
                backlightVeilOptical.scatterStrength,
                backlightVeilOptical.highlightReactivity,
                backlightVeilOptical.warmScatter,
                backlightVeilOptical.spectralTail,
            ]) ?? image
        }

        guard let kernel = OpticalKernels.glowComposite else {
            return image
        }

        return kernel.apply(extent: extent, arguments: [
            image,
            bloomImage,
            halationImage,
            diffusionImage,
            params.bloomStrength,
            params.halationIntensity,
            params.diffusion,
            OpticsResampling.diffusionCompositeBase,
        ]) ?? image
    }

    /// Build the Metal vignette parameter struct from the same inputs
    /// `applyVignetteStage` would consume. Returns nil when the CI path
    /// would also no-op (intensity below threshold), so caller can decide
    /// whether to chain the vignette pass at all.
    private func vignetteFrameParams(
        image: CIImage,
        params: Phase0ParamsDTO
    ) -> FilmtoneMetalOpticsRenderer.VignetteFrameParams? {
        guard params.vignette > 0.0001 else {
            return nil
        }
        let optics = request.sourceProbe?.cameraOptics
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsCIVector = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsPack = SIMD3<Float>(
            Float(opticsCIVector.x),
            Float(opticsCIVector.y),
            Float(opticsCIVector.z)
        )
        let applyMask: Float = (optics?.source == "metadata") ? 1.0 : 0.0
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let innerThreshold = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold
        return FilmtoneMetalOpticsRenderer.VignetteFrameParams(
            intensity: params.vignette,
            opticsPack: opticsPack,
            applyMask: applyMask,
            gamma: gamma,
            innerThreshold: innerThreshold
        )
    }

    func applyVignetteStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        // Phase 2 段階 1: when the Metal optics chain absorbed the vignette
        // pass for this frame, the CI vignette is already represented in
        // `image` and re-applying would double the falloff.
        if metalVignetteAppliedThisFrame {
            return image
        }
        guard params.vignette > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.vignette else {
            return image
        }

        let optics = request.sourceProbe?.cameraOptics
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: optics,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        let opticsPack = FilmtoneRayAngleOptics.kernelArgs(
            resolved: resolved,
            imageWidth: Double(image.extent.width),
            imageHeight: Double(image.extent.height)
        )
        // Mask only activates on trustworthy lens metadata — `"assumed"` /
        // nil / `"fallback65"` sources keep vignette byte-identical with
        // pre-Stream-2 output. Gamma / inner come from the shared contract
        // defaults so the ray-angle math stays locked to SSOT rather than
        // Swift-side constants.
        let applyMask: Double = (optics?.source == "metadata") ? 1.0 : 0.0
        let gamma = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma
        let innerThreshold = FilmtonePhase0Generated.hiddenDefaults.depthRayAngleInnerThreshold

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.vignette,
            OpticsResampling.extentOriginVector(for: image.extent),
            OpticsResampling.extentSizeVector(for: image.extent),
            gamma,
            innerThreshold,
            opticsPack,
            applyMask,
        ]) ?? image
    }

    private func extractHighlightPlate(
        from image: CIImage,
        threshold: Double,
        knee: Double,
        tintColor: CIColor
    ) -> CIImage {
        guard let kernel = OpticalKernels.softKneeHighlight else {
            return OpticsResampling.blackImage(for: image.extent)
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            Self.clamp(threshold),
            Self.clamp(knee),
            tintColor,
        ]) ?? OpticsResampling.blackImage(for: image.extent)
    }

    private func applyRadialRGBShift(_ amount: Double, to image: CIImage) -> CIImage {
        guard let kernel = OpticalKernels.radialRGBSplit else {
            return image
        }

        let padding = CGFloat(max(4.0, abs(amount) * max(image.extent.width, image.extent.height)))
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in
                rect.insetBy(dx: -padding, dy: -padding)
            },
            arguments: [
                image,
                amount,
                OpticsResampling.extentOriginVector(for: image.extent),
                OpticsResampling.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func applyEdgeSoftness(
        to image: CIImage,
        aberrationSoften: Double,
        lensSoftness: Double
    ) -> CIImage {
        let lensDrive = pow(Self.clamp(lensSoftness), 0.78)
        let aberrationDrive = pow(
            Self.clamp(aberrationSoften / OpticsResampling.aberrationEdgeSoftenMax),
            0.82
        )
        let blurRadius = min(
            Self.lerp(
                OpticsResampling.aberrationBlurRadiusMin,
                OpticsResampling.aberrationBlurRadiusMax,
                aberrationDrive
            ) + (lensDrive * OpticsResampling.lensSoftnessBlurBoost),
            OpticsResampling.aberrationBlurRadiusCap
        )
        guard blurRadius > 0.0001, let kernel = OpticalKernels.edgeSoftnessBlend else {
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
                Self.clamp(aberrationSoften),
                Self.clamp(lensSoftness),
                OpticsResampling.extentOriginVector(for: image.extent),
                OpticsResampling.extentSizeVector(for: image.extent),
            ]
        ) ?? image
    }

    private func buildMipBlurComposite(
        from image: CIImage,
        radius: Double,
        levelCount: Int,
        spreadMultiplier: Double,
        useTentResampling: Bool = false,
        normalizedBandEnergy: Bool = false
    ) -> CIImage {
        let extent = image.extent.integral
        guard levelCount > 0 else {
            return OpticsResampling.blackImage(for: extent)
        }

        var mips = OpticsResampling.buildMipPyramid(
            from: image,
            levelCount: levelCount,
            initialScale: OpticsResampling.glowBaseScale / max(spreadMultiplier, 0.0001),
            useTentResampling: useTentResampling
        )
        guard !mips.isEmpty else {
            return OpticsResampling.blackImage(for: extent)
        }

        if normalizedBandEnergy {
            let weights = OpticsResampling.normalizedGlowBandWeights(
                radius: Self.clamp(radius),
                levels: mips.count
            )
            let deepestIndex = mips.count - 1
            mips[deepestIndex] = OpticsResampling.weightedImage(
                mips[deepestIndex],
                weight: weights[deepestIndex]
            )
            if mips.count > 1 {
                for index in stride(from: mips.count - 2, through: 0, by: -1) {
                    let lowRes = mips[index + 1]
                    let highRes = mips[index]
                    let restored = useTentResampling
                        ? OpticsResampling.tentUpsampledImage(lowRes, to: highRes.extent)
                        : OpticsResampling.upsampledImage(lowRes, to: highRes.extent)
                    let weightedHighRes = OpticsResampling.weightedImage(
                        highRes,
                        weight: weights[index]
                    )
                    mips[index] = OpticsResampling.addImages(
                        restored,
                        weightedHighRes
                    ).cropped(to: highRes.extent)
                }
            }
        } else if mips.count > 1 {
            let weights = OpticsResampling.computeMipWeights(
                radius: Self.clamp(radius),
                levels: mips.count
            )
            for index in stride(from: mips.count - 2, through: 0, by: -1) {
                let lowRes = mips[index + 1]
                let highRes = mips[index]
                let restored = useTentResampling
                    ? OpticsResampling.tentUpsampledImage(lowRes, to: highRes.extent)
                    : OpticsResampling.upsampledImage(lowRes, to: highRes.extent)
                let weightedLowRes = OpticsResampling.weightedImage(
                    restored,
                    weight: weights[index + 1]
                )
                mips[index] = OpticsResampling.addImages(
                    weightedLowRes,
                    highRes
                ).cropped(to: highRes.extent)
            }
        }

        let output = useTentResampling
            ? OpticsResampling.tentUpsampledImage(mips[0], to: extent)
            : OpticsResampling.upsampledImage(mips[0], to: extent)
        return output.cropped(to: extent)
    }

    /// 2-arg fallback clamp; kept private to this compositor so 5B stays
    /// self-contained. Body identical to `FilmtoneExportSession.clamp`,
    /// which still serves the 30+ non-optics call sites on ExportSession.
    private static func clamp(
        _ value: Double,
        min minValue: Double = 0,
        max maxValue: Double = 1
    ) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }

    /// Linear interpolation; kept private to this compositor.
    /// Body identical to `FilmtoneExportSession.lerp`.
    private static func lerp(_ start: Double, _ end: Double, _ t: Double) -> Double {
        start + ((end - start) * t)
    }
}
