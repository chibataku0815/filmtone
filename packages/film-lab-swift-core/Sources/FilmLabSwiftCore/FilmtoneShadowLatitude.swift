import Foundation

public struct FilmtoneShadowLatitudeRgb: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

// Swift mirror of packages/film-lab-core/src/shadow-latitude.ts.
// Keep constants and scalar behavior aligned with the TS helper, CIKernel,
// WebGL, and WebGPU ports.
public enum FilmtoneShadowLatitude {
    public static let blackAnchor: Double = 0.025
    public static let mainBandStart: Double = 0.055
    public static let mainBandEnd: Double = 0.18
    public static let releaseEnd: Double = 0.30
    public static let lumaGainMax: Double = 0.22
    public static let chromaRetentionMax: Double = 0.08

    public static func luma(_ rgb: FilmtoneShadowLatitudeRgb) -> Double {
        0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    }

    public static func apply(
        rgb: FilmtoneShadowLatitudeRgb,
        amount: Double,
        clampOutput: Bool = false
    ) -> FilmtoneShadowLatitudeRgb {
        let amt = clamp01(amount)
        if amt < 0.001 {
            return rgb
        }

        let y = luma(rgb)
        let blackProtect = smoothstep(edge0: blackAnchor, edge1: mainBandStart, x: y)
        let release = 1.0 - smoothstep(edge0: mainBandEnd, edge1: releaseEnd, x: y)
        let band = blackProtect * release

        if band <= 0.000001 {
            if clampOutput {
                return FilmtoneShadowLatitudeRgb(
                    r: clamp01(rgb.r),
                    g: clamp01(rgb.g),
                    b: clamp01(rgb.b)
                )
            }
            return rgb
        }

        let toeShape = Swift.max(0, 1.0 - y / releaseEnd)
        let lumaLift = y * toeShape * lumaGainMax * amt * band
        let outY = y + lumaLift
        let chromaScale = 1.0 + chromaRetentionMax * amt * band
        var out = FilmtoneShadowLatitudeRgb(
            r: outY + (rgb.r - y) * chromaScale,
            g: outY + (rgb.g - y) * chromaScale,
            b: outY + (rgb.b - y) * chromaScale
        )

        if clampOutput {
            out.r = clamp01(out.r)
            out.g = clamp01(out.g)
            out.b = clamp01(out.b)
        }
        return out
    }

    private static func clamp01(_ x: Double) -> Double {
        if x < 0 { return 0 }
        if x > 1 { return 1 }
        return x
    }

    private static func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3.0 - 2.0 * t)
    }
}
