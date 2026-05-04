import Foundation

// Minimal type stubs so SharedGenerated/FilmtonePhase0Generated.swift
// compile-links inside the macOS target. Field shapes mirror the iOS
// definitions in apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
// and FilmtoneMediaTypes.swift. Phase 2 (SPM packages/film-lab-swift-core)
// absorbs both copies; this file is deleted at that point.

struct FilmtoneQuickState: Codable, Equatable, Hashable, Sendable {
    var filmCharacter: Double
    var era: Double
    var dynamics: Double

    static let zero = FilmtoneQuickState(
        filmCharacter: 0,
        era: 0,
        dynamics: 0
    )

    func clamped() -> FilmtoneQuickState {
        .init(
            filmCharacter: Self.clampAxis(filmCharacter),
            era: Self.clampAxis(era),
            dynamics: Self.clampAxis(dynamics)
        )
    }

    func value(forAxis axis: String) -> Double {
        switch axis {
        case "filmCharacter":
            return filmCharacter
        case "era":
            return era
        case "dynamics":
            return dynamics
        default:
            return 0
        }
    }

    static func clampAxis(_ value: Double) -> Double {
        max(
            FilmtonePhase0Generated.quickAxisMin,
            min(FilmtonePhase0Generated.quickAxisMax, value)
        )
    }
}

struct FilmtonePhase0Params {
    var exposure: Double
    var contrast: Double
    var saturation: Double
    var temperature: Double
    var tint: Double
    var rgbShift: Double
    var lensSoftness: Double
    var grainRadialMix: Double
    var grainSize: Double
    var bloomThreshold: Double
    var bloomStrength: Double
    var bloomRadius: Double
    var diffusion: Double
    var halationIntensity: Double
    var halationSpread: Double
    var halationHue: Double
    var halationThreshold: Double
    var halationRadius: Double
    var bloomSoftKnee: Double
    var halationSoftKnee: Double
    var compressionAmount: Double
    var compressionRange: Double
    var printContrast: Double
    var cyan: Double
    var magenta: Double
    var yellow: Double
    var shutterAngle: Double
    var trailIntensity: Double
    var fade: Double
    var shadowTone: Double
    var highlightTone: Double
    var shadowHue: Double
    var highlightHue: Double
    var vignette: Double
    var grainIntensity: Double
}

struct Phase0OutputProfileDTO {
    var longEdge: Int
    var fps: Int
    var codec: String
    var container: String
    var preserveAudio: Bool
}

struct FilmtonePhase0HiddenDefaults {
    var depthMistGain: Double
    var depthGlowGain: Double
    var depthRayAngleGamma: Double
    var depthRayAngleInnerThreshold: Double
    var depthMistRayAngleGain: Double
    var depthBloomRayAngleGain: Double
    var depthHalationRayAngleGain: Double
    var depthMistFieldPsfGain: Double
    var depthBloomFieldPsfGain: Double
    var depthHalationFieldPsfGain: Double
    var depthMistFieldPsfRadiusPx: Double
    var depthBloomFieldPsfRadiusPx: Double
    var depthHalationFieldPsfRadiusPx: Double
    var crossFilterDepthGain: Double
    var crossFilterAngleGain: Double
    var crossFilterAngleGamma: Double
    var crossFilterAngleInnerThreshold: Double
    var crossFilterEdgeLengthGain: Double
    var crossFilterEdgeStrengthGain: Double
}
