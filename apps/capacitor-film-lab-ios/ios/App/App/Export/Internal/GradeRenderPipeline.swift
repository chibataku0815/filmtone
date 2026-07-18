import CoreGraphics
import CoreImage
import FilmLabSwiftCore
import Foundation

/// Phase 2B-6A: non-optics color half of the export grade pipeline.
/// Owns prepared LUT state (input + creative) and dispatches the
/// kernel-based color stages (base grade, tone compression, print) plus
/// LUT application. The optics half lives in `OpticsCompositor`.
///
/// Stage order, kernel selection, kernel argument order, and
/// `presetVersion` dispatch are preserved exactly from the pre-extraction
/// `FilmtoneExportSession` bodies.
///
/// R3 (god-object regrowth pass): `applyGrade` (the per-frame stage
/// orchestrator), `applyVideoMotionStage`, `applyGrainStage`,
/// `applyFilmDamageStage`, `paramsApplyingFilmBreath`, and the
/// `sourceDetailBias` / `sourceSeed` derivation statics moved here from
/// `FilmtoneExportSession`. `opticsCompositor`, `loadedDepthMap`,
/// `sourceDetailBias`, and `sourceSeed` are threaded in as parameters
/// (mirroring the pre-existing `sourceDetailBias` parameter on
/// `applyDetailSoftnessStage`) rather than stored, since they are
/// session-owned / per-source state. `FilmtoneExportSession` still owns
/// `request`, the `opticsCompositor` instance, `loadedDepthMap`'s mutable
/// per-frame lifetime, and the render-stage profiling hook
/// (`profileRenderSubstage`, threaded in here as a closure).
final class GradeRenderPipeline {
    private let preparedInputLut: PreparedLut?
    private let preparedCreativeLut: PreparedLut?
    private let outputColorSpace: CGColorSpace

    init(
        preparedInputLut: PreparedLut?,
        preparedCreativeLut: PreparedLut?,
        outputColorSpace: CGColorSpace
    ) {
        self.preparedInputLut = preparedInputLut
        self.preparedCreativeLut = preparedCreativeLut
        self.outputColorSpace = outputColorSpace
    }

    func applyInputLutStage(to image: CIImage) -> CIImage {
        guard let preparedInputLut else {
            return image
        }
        return applyLut(preparedInputLut, to: image)
    }

    func applyBaseGradeStage(to image: CIImage, params: Phase0ParamsDTO, presetVersion: String) -> CIImage {
        let epsilon = 0.0001
        guard
            abs(params.exposure) > epsilon ||
            abs(params.contrast - 1.0) > epsilon ||
            abs(params.saturation - 1.0) > epsilon ||
            abs(params.temperature) > epsilon ||
            abs(params.tint) > epsilon ||
            abs(params.fade) > epsilon ||
            abs(params.shadowTone) > epsilon ||
            abs(params.highlightTone) > epsilon ||
            abs(params.blackPoint) > epsilon ||
            abs(params.toeContrast) > epsilon
        else {
            return image
        }

        let kernel: CIColorKernel?
        switch presetVersion {
        case "v2":
            kernel = OpticalKernels.baseGradeV2
        case "v1":
            kernel = OpticalKernels.baseGrade
        default:
            assertionFailure("Unknown presetVersion: \(presetVersion)")
            kernel = OpticalKernels.baseGradeV2
        }
        guard let kernel else {
            return image
        }

        // v1 kernel takes the original 7 args; v2 takes 13 (adds shadowTone /
        // highlightTone / shadowHue / highlightHue for density-dependent
        // split-tone, plus blackPoint / toeContrast for black floor & toe
        // hardness shaping). v1 saved Looks ignore the new fields — appearance
        // unchanged.
        let args: [Any]
        switch presetVersion {
        case "v1":
            args = [
                image,
                params.exposure,
                params.contrast,
                params.saturation,
                params.temperature,
                params.tint,
                params.fade,
            ]
        default:
            args = [
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
                params.blackPoint,
                params.toeContrast,
            ]
        }
        return kernel.apply(extent: image.extent, arguments: args) ?? image
    }

    func applyToneCompressionStage(to image: CIImage, params: Phase0ParamsDTO, presetVersion: String) -> CIImage {
        guard params.compressionAmount > 0.0001 else {
            return image
        }
        let kernel: CIColorKernel?
        switch presetVersion {
        case "v2":
            kernel = OpticalKernels.filmCompressionV3
        case "v1":
            kernel = OpticalKernels.filmCompression
        default:
            assertionFailure("Unknown presetVersion: \(presetVersion)")
            kernel = OpticalKernels.filmCompressionV3
        }
        guard let kernel else {
            return image
        }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.compressionAmount,
            params.compressionRange,
        ]) ?? image
    }

    func applyShadowLatitudeStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        guard params.shadowLatitude > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.toeSeparation else {
            return image
        }
        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.shadowLatitude,
        ]) ?? image
    }

    func applyDetailSoftnessStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        sourceDetailBias: Double = 0
    ) -> CIImage {
        let uniforms = FilmtoneDetailSoftness.deriveUniforms(
            detailSoftness: params.detailSoftness,
            sourceDetailBias: sourceDetailBias
        )
        if uniforms.effectiveDetailSoftness < 0.0001 {
            return image
        }
        guard let kernel = OpticalKernels.detailSoftness else {
            return image
        }

        let padding = CGFloat(ceil(uniforms.kernelRadiusPx) + 1.0)
        return kernel.apply(
            extent: image.extent,
            roiCallback: { _, rect in rect.insetBy(dx: -padding, dy: -padding) },
            arguments: [
                image.clampedToExtent(),
                uniforms.effectiveDetailSoftness,
                uniforms.kernelRadiusPx,
                uniforms.rangeSigma,
                uniforms.detailAmplitudeLo,
                uniforms.detailAmplitudeHi,
                uniforms.chromaAttenScale,
                uniforms.highlightBias,
            ]
        )?.cropped(to: image.extent) ?? image
    }

    func applyCreativeLutStage(to image: CIImage) -> CIImage {
        guard let preparedCreativeLut else {
            return image
        }
        return applyLut(preparedCreativeLut, to: image)
    }

    func applyPrintStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage {
        let epsilon = 0.0001
        guard
            params.printContrast > epsilon ||
            abs(params.cyan) > epsilon ||
            abs(params.magenta) > epsilon ||
            abs(params.yellow) > epsilon
        else {
            return image
        }

        guard let kernel = OpticalKernels.printStage else {
            return image
        }

        return kernel.apply(extent: image.extent, arguments: [
            image,
            params.printContrast,
            params.cyan,
            params.magenta,
            params.yellow,
        ]) ?? image
    }

    private func applyLut(_ lut: PreparedLut, to image: CIImage) -> CIImage {
        let lutImage = image.applyingFilter("CIColorCubeWithColorSpace", parameters: [
            "inputCubeDimension": lut.size,
            "inputCubeData": lut.cubeData,
            "inputColorSpace": outputColorSpace,
        ])

        guard lut.intensity < 0.999 else {
            return lutImage
        }

        let alphaAdjusted = lutImage.applyingFilter("CIColorMatrix", parameters: [
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: lut.intensity),
        ])
        return alphaAdjusted
            .applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: image,
            ])
            .cropped(to: image.extent)
    }

    // MARK: - R3: per-frame orchestration + grain / film damage / film breath
    //
    // Moved verbatim from `FilmtoneExportSession` (see class doc above).
    // `opticsCompositor` is a `final class`, so calling its stage methods
    // here mutates the exact same instance the session owns — passing it
    // as a parameter instead of storing it does not change identity or
    // behavior. `profileSubstage` reproduces the session's
    // `profileRenderSubstage(_:image:outputSize:)` call at each of the
    // same 12 points, in the same order, with the same stage enum values.

    func applyGrade(
        to image: CIImage,
        timeSeconds: Double,
        rawParams: Phase0ParamsDTO,
        presetVersion: String,
        sourceDetailBias: Double,
        sourceSeed: Double,
        opticsCompositor: OpticsCompositor,
        loadedDepthMap: FilmtoneDepthMap?,
        profileSubstage: (FilmtoneExportRenderSubstage, CIImage) -> Void
    ) -> CIImage {
        // Backlight Veil Phase 1c — when a Backlight Veil family is active,
        // its 12 spatial keys (bloom / halation / diffusion / lensSoftness /
        // rgbShift) override the user's optical signature so the scatter
        // math has the canonical plate inputs. Color-grade params (exposure
        // / contrast / LUT etc.) stay untouched, so the user's Look color
        // is preserved and the Veil layers on top as a lens veil.
        let params = paramsApplyingFilmBreath(
            to: opticsCompositor.paramsApplyingBacklightVeil(to: rawParams),
            timeSeconds: timeSeconds,
            sourceSeed: sourceSeed
        )
        var current = image

        // Phase 2 段階 1: clear the per-frame Metal vignette flag before any
        // stage runs. `applyGlowFamilyStage` sets it true when the Metal
        // optics chain absorbs the vignette pass; `applyVignetteStage`
        // consumes it to skip the CI path.
        opticsCompositor.resetFrameState()

        current = applyInputLutStage(to: current)
        profileSubstage(.inputLut, current)
        current = applyBaseGradeStage(to: current, params: params, presetVersion: presetVersion)
        profileSubstage(.baseGrade, current)
        current = applyToneCompressionStage(to: current, params: params, presetVersion: presetVersion)
        profileSubstage(.toneCompression, current)
        current = applyShadowLatitudeStage(to: current, params: params)
        profileSubstage(.shadowLatitude, current)
        current = applyDetailSoftnessStage(
            to: current,
            params: params,
            sourceDetailBias: sourceDetailBias
        )
        profileSubstage(.detailSoftness, current)
        current = opticsCompositor.applyEdgeOpticsStage(to: current, params: params)
        profileSubstage(.edgeOptics, current)
        current = opticsCompositor.applyGlowFamilyStage(
            to: current,
            params: params,
            loadedDepthMap: loadedDepthMap
        )
        profileSubstage(.glowFamily, current)
        current = opticsCompositor.applyVignetteStage(to: current, params: params)
        profileSubstage(.vignette, current)
        current = applyGrainStage(to: current, params: params, timeSeconds: timeSeconds, sourceSeed: sourceSeed)
        profileSubstage(.grain, current)
        current = applyCreativeLutStage(to: current)
        profileSubstage(.creativeLut, current)
        current = applyPrintStage(to: current, params: params)
        profileSubstage(.printStage, current)
        current = applyFilmDamageStage(to: current, params: params, timeSeconds: timeSeconds, sourceSeed: sourceSeed)
        profileSubstage(.filmDamage, current)

        return current.cropped(to: image.extent)
    }

    func applyVideoMotionStage(
        to image: CIImage,
        timeSeconds: Double,
        outputSize: CGSize,
        accumulator: FilmtoneMotionBlurAccumulator?,
        params: Phase0ParamsDTO
    ) -> CIImage {
        guard let accumulator else {
            return image
        }
        return accumulator.apply(
            to: image,
            params: params,
            timeSeconds: timeSeconds,
            outputSize: outputSize
        )
    }

    func applyGrainStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> CIImage {
        let grainIntensity = max(0, min(FilmtonePhase0Generated.grainIntensityMax, params.grainIntensity))
        guard grainIntensity > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.grain else {
            return image
        }
        let normalizedTime = timeSeconds.isFinite ? max(timeSeconds, 0) : 0
        return kernel.apply(extent: image.extent, arguments: [
            image,
            grainIntensity,
            params.grainRadialMix,
            params.grainSize,
            normalizedTime,
            sourceSeed,
            OpticsResampling.extentOriginVector(for: image.extent),
            OpticsResampling.extentSizeVector(for: image.extent),
        ]) ?? image
    }

    func applyFilmDamageStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> CIImage {
        let dustAmount = max(0, min(1, params.dustAmount))
        let scratchAmount = max(0, min(1, params.scratchAmount))
        guard dustAmount > 0.0001 || scratchAmount > 0.0001 else {
            return image
        }
        guard let kernel = OpticalKernels.filmDamage else {
            return image
        }
        let normalizedTime = timeSeconds.isFinite ? max(timeSeconds, 0) : 0
        return kernel.apply(extent: image.extent, arguments: [
            image,
            dustAmount,
            scratchAmount,
            normalizedTime,
            sourceSeed,
            OpticsResampling.extentOriginVector(for: image.extent),
            OpticsResampling.extentSizeVector(for: image.extent),
        ]) ?? image
    }

    func paramsApplyingFilmBreath(
        to params: Phase0ParamsDTO,
        timeSeconds: Double,
        sourceSeed: Double
    ) -> Phase0ParamsDTO {
        let offsets = FilmtoneFilmBreath.deriveOffsets(
            amount: params.filmBreathAmount,
            timeSeconds: timeSeconds,
            sourceSeed: sourceSeed
        )
        guard !offsets.isIdentity else {
            return params
        }
        return Phase0ParamsDTO(
            exposure: max(-2, min(2, params.exposure + offsets.exposure)),
            contrast: max(0, min(2, params.contrast + offsets.contrast)),
            saturation: params.saturation,
            temperature: max(-1, min(1, params.temperature + offsets.temperature)),
            tint: max(-1, min(1, params.tint + offsets.tint)),
            rgbShift: params.rgbShift,
            lensSoftness: params.lensSoftness,
            detailSoftness: params.detailSoftness,
            grainRadialMix: params.grainRadialMix,
            grainSize: params.grainSize,
            bloomThreshold: params.bloomThreshold,
            bloomStrength: params.bloomStrength,
            bloomRadius: params.bloomRadius,
            diffusion: params.diffusion,
            halationIntensity: params.halationIntensity,
            halationSpread: params.halationSpread,
            halationHue: params.halationHue,
            halationThreshold: params.halationThreshold,
            halationRadius: params.halationRadius,
            bloomSoftKnee: params.bloomSoftKnee,
            halationSoftKnee: params.halationSoftKnee,
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
            highlightTone: params.highlightTone,
            shadowHue: params.shadowHue,
            highlightHue: params.highlightHue,
            vignette: params.vignette,
            grainIntensity: params.grainIntensity
        )
    }

    static func resolveSourceDetailBias(
        from probe: SourceProbeDTO?,
        cameraProfile: CameraProfileSelection?
    ) -> Double {
        guard let probe else { return 0 }
        let video = probe.sourceVideoMetadata
        let logTransfer = video?.logTransferFunction ?? probe.logTransferFunction
        let transformStrategy = (video?.inputTransformPolicy ?? probe.inputTransformPolicy)?.strategy
        let codec = video?.codecFamily ?? probe.codecFamily
        let resolvedProfileId: String? = {
            switch cameraProfile {
            case .some(.builtIn(let catalogId)):
                return catalogId
            case .some(.auto), .some(.userImport), nil:
                return nil
            }
        }()
        let input = FilmtoneSourceDetailCompensationInput(
            cameraMake: probe.cameraOptics?.cameraMake,
            cameraModel: probe.cameraOptics?.cameraModel,
            logTransferFunction: logTransfer?.rawValue,
            inputTransformStrategy: transformStrategy?.rawValue,
            codecFamily: codec?.rawValue,
            colorClass: video?.colorClass.rawValue,
            sourceProfileId: resolvedProfileId
        )
        return FilmtoneSourceDetailCompensation.resolve(input).recommendedBias
    }

    static func makeStableSourceSeed(from string: String) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Double(hash % 8_192)
    }
}
