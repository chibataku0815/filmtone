import Foundation

// Swift mirror of packages/film-lab-core/src/detail-softness.ts.
// Constants and derivation must match the TS helper byte-for-byte so
// macOS native (FilmtoneGradePipeline), iOS export (GradeRenderPipeline),
// and the WebGL / WebGPU shader paths share the same effective values.
//
// Algorithm shape: amplitude-gated bilateral detail-layer attenuation.
// See detail-softness.ts for the algorithm narrative.

public struct FilmtoneDetailSoftnessUniforms: Equatable, Sendable {
    public var effectiveDetailSoftness: Double
    public var kernelRadiusPx: Double
    public var rangeSigma: Double
    public var detailAmplitudeLo: Double
    public var detailAmplitudeHi: Double
    public var chromaAttenScale: Double
    public var highlightBias: Double

    public init(
        effectiveDetailSoftness: Double,
        kernelRadiusPx: Double,
        rangeSigma: Double,
        detailAmplitudeLo: Double,
        detailAmplitudeHi: Double,
        chromaAttenScale: Double,
        highlightBias: Double
    ) {
        self.effectiveDetailSoftness = effectiveDetailSoftness
        self.kernelRadiusPx = kernelRadiusPx
        self.rangeSigma = rangeSigma
        self.detailAmplitudeLo = detailAmplitudeLo
        self.detailAmplitudeHi = detailAmplitudeHi
        self.chromaAttenScale = chromaAttenScale
        self.highlightBias = highlightBias
    }
}

public enum FilmtoneDetailSoftness {
    public static let effectiveMax: Double = 0.65

    static let kernelRadiusMin: Double = 1.0
    static let kernelRadiusMax: Double = 2.5
    static let rangeSigma: Double = 0.07
    static let detailAmplitudeLo: Double = 0.0
    static let detailAmplitudeHi: Double = 0.05
    static let chromaAttenScale: Double = 0.7
    static let highlightBias: Double = 1.18

    public static func deriveUniforms(
        detailSoftness: Double,
        sourceDetailBias: Double = 0
    ) -> FilmtoneDetailSoftnessUniforms {
        let combined = detailSoftness + sourceDetailBias
        let effective = max(0, min(effectiveMax, combined))
        let t = effective / effectiveMax
        let radius = kernelRadiusMin + t * (kernelRadiusMax - kernelRadiusMin)
        return FilmtoneDetailSoftnessUniforms(
            effectiveDetailSoftness: effective,
            kernelRadiusPx: radius,
            rangeSigma: rangeSigma,
            detailAmplitudeLo: detailAmplitudeLo,
            detailAmplitudeHi: detailAmplitudeHi,
            chromaAttenScale: chromaAttenScale,
            highlightBias: highlightBias
        )
    }
}
