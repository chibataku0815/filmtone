import CoreGraphics
import CoreImage
import FilmLabSwiftCore
import Foundation

/// Phase 2B-6A: non-optics color half of the export grade pipeline.
/// Owns prepared LUT state (input + creative) and dispatches the
/// kernel-based color stages (base grade, tone compression, print) plus
/// LUT application. The optics half lives in `OpticsCompositor`. Grain
/// stays on `FilmtoneExportSession` because it depends on per-session
/// `sourceSeed` and per-frame `timeSeconds`.
///
/// Stage order, kernel selection, kernel argument order, and
/// `presetVersion` dispatch are preserved exactly from the pre-extraction
/// `FilmtoneExportSession` bodies.
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
            abs(params.highlightTone) > epsilon
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

        // v1 kernel takes the original 7 args; v2 takes 11 (adds shadowTone /
        // highlightTone / shadowHue / highlightHue for density-dependent
        // split-tone).
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
            kernel = OpticalKernels.filmCompressionV2
        case "v1":
            kernel = OpticalKernels.filmCompression
        default:
            assertionFailure("Unknown presetVersion: \(presetVersion)")
            kernel = OpticalKernels.filmCompressionV2
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
}
