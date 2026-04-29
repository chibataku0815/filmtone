import Foundation

enum FilmtonePhase0Generated {
    static let schemaVersion = 2
    static let presetVersion = "v1"
    static let presetDefault = "reset"
    static let presetStrengthDefault = 1.0
    static let paramKeys: [String] = ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "lensSoftness", "grainRadialMix", "grainSize", "bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow", "fade", "vignette", "grainIntensity"]
    static let quickAxisIds: [String] = ["filmCharacter", "era", "dynamics"]
    static let quickAxisMin = -1.0
    static let quickAxisMax = 1.0
    static let quickAxisStep = 0.01
    static let defaultQuickState = FilmtoneQuickState(
        filmCharacter: 0.0,
        era: 0.0,
        dynamics: 0.0
    )
    static let outputProfile = Phase0OutputProfileDTO(
        longEdge: 1920,
        fps: 24,
        codec: "h264",
        container: "mp4",
        preserveAudio: true
    )
    static let rgbShiftMax = 0.005
    static let grainIntensityMax = 0.1
    static let sourceDurationCapSec = 300.0
    static let sourceLongEdgeCap = 4096
    static let sourceFileSizeCapBytes = 8589934592
    static let resetParams: FilmtonePhase0Params =
    .init(
            exposure: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            temperature: 0.0,
            tint: 0.0,
            rgbShift: 0.0,
            lensSoftness: 0.0,
            grainRadialMix: 1.0,
            grainSize: 0.3,
            bloomThreshold: 0.8,
            bloomStrength: 0.0,
            bloomRadius: 0.4,
            diffusion: 0.0,
            halationIntensity: 0.0,
            halationSpread: 15.0,
            halationHue: 0.0,
            halationThreshold: 0.6,
            halationRadius: 0.6,
            bloomSoftKnee: 0.5,
            halationSoftKnee: 0.3,
            compressionAmount: 0.0,
            compressionRange: 0.5,
            printContrast: 0.0,
            cyan: 0.0,
            magenta: 0.0,
            yellow: 0.0,
            fade: 0.0,
            vignette: 0.0,
            grainIntensity: 0.0
        )
    static let paramsByName: [String: FilmtonePhase0Params] = [
        "reset": .init(
            exposure: 0.0,
            contrast: 1.0,
            saturation: 1.0,
            temperature: 0.0,
            tint: 0.0,
            rgbShift: 0.0,
            lensSoftness: 0.0,
            grainRadialMix: 1.0,
            grainSize: 0.3,
            bloomThreshold: 0.72,
            bloomStrength: 0.22,
            bloomRadius: 0.52,
            diffusion: 0.08,
            halationIntensity: 0.1,
            halationSpread: 22.0,
            halationHue: 20.0,
            halationThreshold: 0.6,
            halationRadius: 0.44,
            bloomSoftKnee: 0.5,
            halationSoftKnee: 0.3,
            compressionAmount: 0.0,
            compressionRange: 0.5,
            printContrast: 0.0,
            cyan: 0.0,
            magenta: 0.0,
            yellow: 0.0,
            fade: 0.0,
            vignette: 0.0,
            grainIntensity: 0.0
        ),
        "iphone": .init(
            exposure: 0.04,
            contrast: 1.08,
            saturation: 0.94,
            temperature: 0.02,
            tint: 0.0,
            rgbShift: 0.0006,
            lensSoftness: 0.035,
            grainRadialMix: 1.0,
            grainSize: 0.26,
            bloomThreshold: 0.76,
            bloomStrength: 0.18,
            bloomRadius: 0.48,
            diffusion: 0.08,
            halationIntensity: 0.06,
            halationSpread: 18.0,
            halationHue: 22.0,
            halationThreshold: 0.6,
            halationRadius: 0.38,
            bloomSoftKnee: 0.5,
            halationSoftKnee: 0.3,
            compressionAmount: 0.18,
            compressionRange: 0.68,
            printContrast: 0.06,
            cyan: 0.0,
            magenta: 0.0,
            yellow: 0.0,
            fade: 0.02,
            vignette: 0.18,
            grainIntensity: 0.025
        ),
        "softBlue": .init(
            exposure: 0.16,
            contrast: 0.94,
            saturation: 1.08,
            temperature: -0.18,
            tint: -0.04,
            rgbShift: 0.0008,
            lensSoftness: 0.1,
            grainRadialMix: 1.0,
            grainSize: 0.34,
            bloomThreshold: 0.62,
            bloomStrength: 0.36,
            bloomRadius: 0.72,
            diffusion: 0.24,
            halationIntensity: 0.08,
            halationSpread: 24.0,
            halationHue: 18.0,
            halationThreshold: 0.54,
            halationRadius: 0.5,
            bloomSoftKnee: 0.72,
            halationSoftKnee: 0.42,
            compressionAmount: 0.32,
            compressionRange: 0.82,
            printContrast: 0.04,
            cyan: 0.05,
            magenta: -0.03,
            yellow: -0.06,
            fade: 0.1,
            vignette: 0.16,
            grainIntensity: 0.035
        ),
        "amberGlow": .init(
            exposure: 0.08,
            contrast: 1.12,
            saturation: 1.12,
            temperature: 0.26,
            tint: 0.02,
            rgbShift: 0.001,
            lensSoftness: 0.05,
            grainRadialMix: 1.0,
            grainSize: 0.32,
            bloomThreshold: 0.68,
            bloomStrength: 0.24,
            bloomRadius: 0.5,
            diffusion: 0.12,
            halationIntensity: 0.14,
            halationSpread: 22.0,
            halationHue: 30.0,
            halationThreshold: 0.52,
            halationRadius: 0.46,
            bloomSoftKnee: 0.62,
            halationSoftKnee: 0.44,
            compressionAmount: 0.14,
            compressionRange: 0.64,
            printContrast: 0.1,
            cyan: -0.08,
            magenta: 0.03,
            yellow: 0.12,
            fade: 0.04,
            vignette: 0.22,
            grainIntensity: 0.045
        )
    ]
    static let hiddenDefaults = FilmtonePhase0HiddenDefaults(
        depthMistGain: 0.0,
        depthGlowGain: 0.0,
        depthRayAngleGamma: 1.4,
        depthRayAngleInnerThreshold: 0.1,
        depthMistRayAngleGain: 0.35,
        depthBloomRayAngleGain: 0.25,
        depthHalationRayAngleGain: 0.18,
        depthMistFieldPsfGain: 1.0,
        depthBloomFieldPsfGain: 1.0,
        depthHalationFieldPsfGain: 1.0,
        depthMistFieldPsfRadiusPx: 18.0,
        depthBloomFieldPsfRadiusPx: 9.0,
        depthHalationFieldPsfRadiusPx: 12.0,
        crossFilterDepthGain: 0.25,
        crossFilterAngleGain: 0.35,
        crossFilterAngleGamma: 1.4,
        crossFilterAngleInnerThreshold: 0.1,
        crossFilterEdgeLengthGain: 0.45,
        crossFilterEdgeStrengthGain: 0.25
    )
    static let quickWeights: [String: [String: Double]] = [
        "filmCharacter": [
            "saturation": 0.24,
            "temperature": 0.16,
            "tint": -0.06,
            "grainIntensity": 0.1,
            "vignette": 0.12
        ],
        "era": [
            "fade": 0.18,
            "saturation": -0.14,
            "contrast": -0.08,
            "halationIntensity": 0.16,
            "halationSpread": 6.0
        ],
        "dynamics": [
            "exposure": 0.24,
            "contrast": 0.18,
            "bloomStrength": 0.16,
            "bloomThreshold": -0.06,
            "bloomRadius": 0.12
        ]
    ]
}
