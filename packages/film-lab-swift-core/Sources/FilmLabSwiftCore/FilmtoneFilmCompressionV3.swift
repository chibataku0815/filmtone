import Foundation

public struct FilmtoneFilmCompressionRgb: Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

// Swift mirror of packages/film-lab-core/src/film-compression-v3.ts.
// Keep constants and scalar behavior aligned with the TS helper and shader
// ports. Public params remain compressionAmount / compressionRange.
public enum FilmtoneFilmCompressionV3 {
    public static let lumaKMin: Double = 2.85
    public static let lumaKMax: Double = 5.15
    public static let rangeSoftStart: Double = 0.82
    public static let rangeSoftEnd: Double = 1.0
    public static let rangeAmountTrim: Double = 0.18
    public static let chromaCompressionMax: Double = 0.42
    public static let problemColorGuardMax: Double = 0.22
    public static let shadowReleaseStart: Double = 0.14
    public static let shadowReleaseEnd: Double = 0.30
    public static let highlightKneeStartLowRange: Double = 0.62
    public static let highlightKneeStartHighRange: Double = 0.42
    public static let highlightKneeEndLowRange: Double = 0.96
    public static let highlightKneeEndHighRange: Double = 0.78
    public static let chromaStressStart: Double = 0.16
    public static let chromaStressEnd: Double = 0.70
    public static let gamutStressStart: Double = 0.82
    public static let gamutStressEnd: Double = 1.08
    public static let warmProtectStrength: Double = 0.35
    public static let highlightDensityLandingStart: Double = 0.78
    public static let highlightDensityLandingStrength: Double = 0.88
    public static let highlightDensityLandingChromaStart: Double = 0.18
    public static let highlightDensityLandingChromaEnd: Double = 0.62
    public static let highlightDensityLandingWarmProtect: Double = 0.35

    public static func luma(_ rgb: FilmtoneFilmCompressionRgb) -> Double {
        0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b
    }

    public static func chromaMagnitude(_ rgb: FilmtoneFilmCompressionRgb) -> Double {
        let y = luma(rgb)
        let cr = rgb.r - y
        let cg = rgb.g - y
        let cb = rgb.b - y
        return sqrt(cr * cr + cg * cg + cb * cb)
    }

    public static func apply(
        rgb: FilmtoneFilmCompressionRgb,
        amount: Double,
        range: Double,
        clampOutput: Bool = false
    ) -> FilmtoneFilmCompressionRgb {
        if amount < 0.001 {
            return rgb
        }

        let r = clamp01(range)
        let k = mix(lumaKMax, lumaKMin, r)
        let rangeSoft = smoothstep(edge0: rangeSoftStart, edge1: rangeSoftEnd, x: r)
        let amt = amount * (1.0 - rangeAmountTrim * rangeSoft)

        let y = luma(rgb)
        let x = clamp(k * (y - 0.5), min: -5.5, max: 5.5)
        let sigmoid = 1.0 / (1.0 + exp(-x))
        // One-sided shoulder: only roll highlights down, never lift shadows.
        // A symmetric sigmoid centered at 0.5 would pull shadows toward 0.5
        // and boost their chroma; the filmic target is shadow density, not
        // shadow lift.
        let shoulderY = Swift.min(y, mix(y, sigmoid, amt))
        let lumaScale = y > 0.001 ? shoulderY / y : 1.0

        let lr = rgb.r * lumaScale
        let lg = rgb.g * lumaScale
        let lb = rgb.b * lumaScale

        let cr = lr - shoulderY
        let cg = lg - shoulderY
        let cb = lb - shoulderY
        let chromaMag = sqrt(cr * cr + cg * cg + cb * cb)

        let shadowRelease = smoothstep(edge0: shadowReleaseStart, edge1: shadowReleaseEnd, x: shoulderY)
        let kneeStart = mix(highlightKneeStartLowRange, highlightKneeStartHighRange, r)
        let kneeEnd = mix(highlightKneeEndLowRange, highlightKneeEndHighRange, r)
        let highlightMask = smoothstep(edge0: kneeStart, edge1: kneeEnd, x: shoulderY)
        let chromaStress = smoothstep(edge0: chromaStressStart, edge1: chromaStressEnd, x: chromaMag)
        let maxChannel = Swift.max(lr, Swift.max(lg, lb))
        let minChannel = Swift.min(lr, Swift.min(lg, lb))
        let highEdgeStress = smoothstep(edge0: gamutStressStart, edge1: gamutStressEnd, x: maxChannel)
        let lowEdgeStress = smoothstep(edge0: gamutStressStart, edge1: gamutStressEnd, x: -minChannel)
        let gamutStress = Swift.max(highEdgeStress, lowEdgeStress)
            * chromaStress
            * smoothstep(edge0: 0.08, edge1: 0.24, x: shoulderY)
        let warmProtect = warmHueProtect(cr: cr, cg: cg, cb: cb, magnitude: chromaMag)

        let highlightCompression = chromaCompressionMax
            * highlightMask
            * shadowRelease
            * mix(0.55, 1.0, chromaStress)
        let guardCompression = problemColorGuardMax * gamutStress * shadowRelease
        let protectedCompression = (highlightCompression + guardCompression)
            * (1.0 - warmProtectStrength * warmProtect)
        let chromaScale = clamp01(1.0 - amt * protectedCompression)

        let landedCr = cr * chromaScale
        let landedCg = cg * chromaScale
        let landedCb = cb * chromaScale
        var out = FilmtoneFilmCompressionRgb(
            r: shoulderY + landedCr,
            g: shoulderY + landedCg,
            b: shoulderY + landedCb
        )
        let outMax = Swift.max(out.r, Swift.max(out.g, out.b))
        let landingChroma = smoothstep(
            edge0: highlightDensityLandingChromaStart,
            edge1: highlightDensityLandingChromaEnd,
            x: chromaMag
        )
        let landingMask = smoothstep(edge0: highlightDensityLandingStart, edge1: 0.98, x: outMax)
            * landingChroma
            * shadowRelease
            * (1.0 - highlightDensityLandingWarmProtect * warmProtect)

        if outMax > highlightDensityLandingStart && outMax > shoulderY + 0.000001 {
            let over = outMax - highlightDensityLandingStart
            let headroom = 1.0 - highlightDensityLandingStart
            let softMax = highlightDensityLandingStart + (headroom * over) / (over + headroom)
            let landingScale = clamp01((softMax - shoulderY) / (outMax - shoulderY))
            let landingBlend = clamp01(amt * highlightDensityLandingStrength * landingMask)
            let finalScale = mix(1.0, landingScale, landingBlend)
            out.r = shoulderY + landedCr * finalScale
            out.g = shoulderY + landedCg * finalScale
            out.b = shoulderY + landedCb * finalScale
        }

        if clampOutput {
            return FilmtoneFilmCompressionRgb(
                r: clamp01(out.r),
                g: clamp01(out.g),
                b: clamp01(out.b)
            )
        }

        return out
    }

    private static func clamp01(_ x: Double) -> Double {
        if x < 0 { return 0 }
        if x > 1 { return 1 }
        return x
    }

    private static func clamp(_ x: Double, min lo: Double, max hi: Double) -> Double {
        if x < lo { return lo }
        if x > hi { return hi }
        return x
    }

    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func smoothstep(edge0: Double, edge1: Double, x: Double) -> Double {
        let t = clamp01((x - edge0) / (edge1 - edge0))
        return t * t * (3.0 - 2.0 * t)
    }

    private static func warmHueProtect(cr: Double, cg: Double, cb: Double, magnitude: Double) -> Double {
        if magnitude <= 0.000001 {
            return 0
        }
        let dr = cr / magnitude
        let dg = cg / magnitude
        let db = cb / magnitude
        let redWarm = smoothstep(edge0: 0.32, edge1: 0.72, x: dr)
        let blueOpposed = 1.0 - smoothstep(edge0: -0.58, edge1: -0.20, x: db)
        let greenModerate = 1.0 - smoothstep(edge0: 0.18, edge1: 0.58, x: abs(dg))
        return clamp01(redWarm * blueOpposed * greenModerate)
    }
}
