import CoreGraphics
import CoreImage
import FilmLabSwiftCore
import Foundation

/// Stateless optics resampling math lifted out of `FilmtoneExportSession`
/// during Phase 2B-5A. Owns the physical constants and pure helpers used
/// by the glow / halation / diffusion mip chain, the radial RGB shift /
/// edge softness blur radii, and the tent up/down resamplers that feed
/// `OpticalKernels.tentDownsample` / `OpticalKernels.tentUpsample`.
///
/// The compositor that consumes these helpers (Metal vs. CI fall-through,
/// vignette and glow stage orchestration) is deferred to Phase 2B-5B.
enum OpticsResampling {
    static let aberrationEdgeSoftenScale = 32.0
    static let aberrationEdgeSoftenMax = 0.52
    static let aberrationEdgeSoftenCurve = 1.55
    static let aberrationBlurRadiusMin = 1.6
    static let aberrationBlurRadiusMax = 6.2
    static let aberrationBlurRadiusCap = 7.8
    static let lensSoftnessBlurBoost = 1.85
    static let glowBaseScale = 0.5
    static let bloomSpreadBoost = 1.25
    static let halationSpreadDivisor = 12.0
    static let diffusionCompositeBase = 0.87
    static let bloomMipLevels = 6
    static let halationMipLevels = 6
    static let diffusionMipLevels = 4
    static let glowUpsampleBlurRadius = 1.0

    static func buildMipPyramid(
        from image: CIImage,
        levelCount: Int,
        initialScale: Double,
        useTentResampling: Bool = false
    ) -> [CIImage] {
        guard levelCount > 0 else {
            return []
        }

        var mips: [CIImage] = []
        var current = useTentResampling
            ? tentDownsampledImage(image, scale: initialScale)
            : downsampledImage(image, scale: initialScale)
        mips.append(current)

        guard levelCount > 1 else {
            return mips
        }

        for _ in 1..<levelCount {
            current = useTentResampling
                ? tentDownsampledImage(current, scale: 0.5)
                : downsampledImage(current, scale: 0.5)
            mips.append(current)
        }

        return mips
    }

    static func downsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let targetSize = CGSize(
            width: max(1.0, round(image.extent.width * safeScale)),
            height: max(1.0, round(image.extent.height * safeScale))
        )
        let scaled = scaledImage(image, scale: safeScale)
        return scaled.cropped(to: CGRect(origin: .zero, size: targetSize))
    }

    static func upsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }

        let scale = extent.width / image.extent.width
        let upsampled = scaledImage(image, scale: scale).cropped(to: extent)
        guard scale > 1.0001, glowUpsampleBlurRadius > 0.0001 else {
            return upsampled
        }

        return upsampled
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: glowUpsampleBlurRadius,
            ])
            .cropped(to: extent)
    }

    static func tentDownsampledImage(_ image: CIImage, scale: Double) -> CIImage {
        let safeScale = min(1.0, max(scale, 0.0001))
        let sourceExtent = image.extent.integral
        let targetSize = CGSize(
            width: max(1.0, round(sourceExtent.width * safeScale)),
            height: max(1.0, round(sourceExtent.height * safeScale))
        )
        let targetExtent = CGRect(origin: .zero, size: targetSize)

        guard let kernel = OpticalKernels.tentDownsample else {
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
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? downsampledImage(image, scale: scale)
    }

    static func tentUpsampledImage(_ image: CIImage, to extent: CGRect) -> CIImage {
        guard image.extent.width > 0.0001, image.extent.height > 0.0001 else {
            return blackImage(for: extent)
        }
        let sourceExtent = image.extent.integral
        let targetExtent = extent.integral

        guard let kernel = OpticalKernels.tentUpsample else {
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
                    x: sourceExtent.width / max(targetExtent.width, 1.0),
                    y: sourceExtent.height / max(targetExtent.height, 1.0)
                ),
            ]
        ) ?? upsampledImage(image, to: extent)
    }

    static func scaledImage(_ image: CIImage, scale: Double) -> CIImage {
        guard abs(scale - 1.0) > 0.0001 else {
            return image
        }
        return image.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: scale,
            kCIInputAspectRatioKey: 1.0,
        ])
    }

    static func weightedImage(_ image: CIImage, weight: Double) -> CIImage {
        guard weight > 0 else {
            return blackImage(for: image.extent)
        }
        guard abs(weight - 1.0) > 0.0001 else {
            return image
        }
        let vector = CIVector(x: weight, y: 0, z: 0, w: 0)
        let zero = CIVector(x: 0, y: 0, z: 0, w: 0)
        return image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": vector,
            "inputGVector": CIVector(x: 0, y: weight, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: weight, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBiasVector": zero,
        ])
    }

    static func addImages(_ foreground: CIImage, _ background: CIImage) -> CIImage {
        foreground
            .applyingFilter("CIAdditionCompositing", parameters: [
                kCIInputBackgroundImageKey: background,
            ])
            .cropped(to: background.extent)
    }

    static func blackImage(for extent: CGRect) -> CIImage {
        CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 1)).cropped(to: extent)
    }

    static func extentOriginVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.origin.x, y: extent.origin.y)
    }

    static func extentSizeVector(for extent: CGRect) -> CIVector {
        CIVector(x: extent.width, y: extent.height)
    }

    static func computeMipWeights(radius: Double, levels: Int) -> [Double] {
        (0..<levels).map { index in
            let t = Double(index) / Double(max(levels - 1, 1))
            let base = exp(-3.0 * (1.0 - radius) * t)
            let wide = exp(-0.5 * radius * (1.0 - t))
            return (base * (1.0 - radius)) + (wide * radius)
        }
    }

    static func halationColor(for hue: Double) -> CIColor {
        let t = clamp(hue / 100.0)
        let red = (0xe8 + ((0xc8 - 0xe8) * t)) / 255.0
        let green = (0x10 + ((0x60 - 0x10) * t)) / 255.0
        let blue = (0x20 + ((0x10 - 0x20) * t)) / 255.0
        return CIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    static func aberrationEdgeSoften(for normalizedRgbShift: Double) -> Double {
        let normalized = clamp(normalizedRgbShift)
        guard normalized > 0.0001 else {
            return 0
        }

        let linear = normalized * (aberrationEdgeSoftenScale * FilmtonePhase0Generated.rgbShiftMax)
        let boosted = pow(normalized, aberrationEdgeSoftenCurve) * aberrationEdgeSoftenMax
        return min(aberrationEdgeSoftenMax, max(linear, boosted))
    }

    /// 2-arg fallback clamp; kept private to this namespace so the 5A
    /// move stays self-contained. Identical body to
    /// `FilmtoneExportSession.clamp`; deduplication into a shared math
    /// namespace is intentionally out of scope (clamp has 30+ non-optics
    /// call sites on `FilmtoneExportSession`).
    private static func clamp(
        _ value: Double,
        min minValue: Double = 0,
        max maxValue: Double = 1
    ) -> Double {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
