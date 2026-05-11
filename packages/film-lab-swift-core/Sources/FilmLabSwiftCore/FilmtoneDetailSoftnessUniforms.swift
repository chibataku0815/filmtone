import Foundation

// Swift mirror of packages/film-lab-core/src/detail-softness.ts.
// Constants and derivation must match the TS helper byte-for-byte so the
// macOS native pilot (Phase 2-B) and the iOS export port (Phase 2-C) share
// the same effective values as the WebGL / WebGPU renderers (Phase 2-D).
//
// Algorithm shape: local-reference high-pass attenuation with edge guard
// and luma-vs-chroma separation. See
// `docs/filmtone/detail-softness/archive/2026-05-12-phase-2a-research-charter.md`
// §Algorithm decision.

public struct FilmtoneDetailSoftnessUniforms: Equatable, Sendable {
    public var effectiveDetailSoftness: Double
    public var kernelRadiusPx: Double
    public var chromaAttenScale: Double
    public var edgeGuardLo: Double
    public var edgeGuardHi: Double
    public var highlightBias: Double

    public init(
        effectiveDetailSoftness: Double,
        kernelRadiusPx: Double,
        chromaAttenScale: Double,
        edgeGuardLo: Double,
        edgeGuardHi: Double,
        highlightBias: Double
    ) {
        self.effectiveDetailSoftness = effectiveDetailSoftness
        self.kernelRadiusPx = kernelRadiusPx
        self.chromaAttenScale = chromaAttenScale
        self.edgeGuardLo = edgeGuardLo
        self.edgeGuardHi = edgeGuardHi
        self.highlightBias = highlightBias
    }
}

public enum FilmtoneDetailSoftness {
    public static let effectiveMax: Double = 0.34

    static let kernelRadiusMin: Double = 0.55
    static let kernelRadiusMax: Double = 1.45
    static let chromaAttenScale: Double = 0.85
    static let edgeGuardLo: Double = 0.04
    static let edgeGuardHi: Double = 0.2
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
            chromaAttenScale: chromaAttenScale,
            edgeGuardLo: edgeGuardLo,
            edgeGuardHi: edgeGuardHi,
            highlightBias: highlightBias
        )
    }
}
