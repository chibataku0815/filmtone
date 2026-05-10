import FilmLabSwiftCore
import SwiftUI

extension FilmtoneStrengthSheet {
    func makeHelpTopic(
        id: String,
        copy: FilmtoneAdjustmentHelpCopy,
        comparisonStyle: FilmtoneAdjustmentComparisonStyle
    ) -> FilmtoneAdjustmentHelpTopic {
        FilmtoneAdjustmentHelpTopic(id: id, copy: copy, comparisonStyle: comparisonStyle)
    }

    func comparisonStyleForGroup(_ id: String) -> FilmtoneAdjustmentComparisonStyle {
        switch id {
        case "basic":
            return .exposure
        case "process":
            return .tone
        case "optics":
            return .optics
        case "glow":
            return .glow
        case "grain":
            return .grain
        case "motion":
            return .motion
        default:
            return .advanced
        }
    }

    func comparisonStyleForParam(_ key: String) -> FilmtoneAdjustmentComparisonStyle {
        switch key {
        case "exposure":
            return .exposure
        case "contrast":
            return .contrast
        case "saturation":
            return .saturation
        case "temperature", "tint", "fade":
            return .tone
        case "cyan", "magenta", "yellow":
            return .colorBalance
        case "printContrast":
            return .contrast
        case "compressionAmount", "compressionRange":
            return .highlight
        case "rgbShift":
            return .colorFringe
        case "lensSoftness":
            return .softness
        case "vignette":
            return .vignette
        case "bloomThreshold", "bloomStrength", "bloomRadius", "bloomSoftKnee":
            return .bloom
        case "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "halationSoftKnee":
            return .halation
        case "diffusion":
            return .diffusion
        case "grainIntensity", "grainSize", "grainRadialMix":
            return .grain
        case "shutterAngle", "trailIntensity":
            return .motion
        default:
            return .advanced
        }
    }
    var advancedParamGroups: [FilmtoneAdvancedParamGroup] {
        var groups: [FilmtoneAdvancedParamGroup] = [
            .init(
                id: "basic",
                title: store.strings.advancedBasicLabel,
                recipes: [],
                controls: [
                    control("exposure", range: -2...2),
                    control("contrast", range: 0...2),
                    control("saturation", range: 0...2),
                    control("temperature", range: -1...1),
                    control("tint", range: -1...1),
                    control("fade", range: 0...1),
                ]
            ),
            .init(
                id: "process",
                title: store.strings.advancedProcessLabel,
                recipes: toneAdvancedRecipes,
                controls: [
                    control("cyan", range: -1...1),
                    control("magenta", range: -1...1),
                    control("yellow", range: -1...1),
                    control("printContrast", range: 0...1),
                    control("compressionAmount", range: 0...1),
                    control("compressionRange", range: 0...1),
                ]
            ),
            .init(
                id: "optics",
                title: store.strings.advancedOpticsLabel,
                recipes: standardAdvancedRecipes(
                    defaultValues: { base in
                        [
                            "rgbShift": max(base.rgbShift, 0.0038),
                            "lensSoftness": max(base.lensSoftness, 0.30),
                            "vignette": max(base.vignette, 0.46),
                        ]
                    },
                    strongValues: { base in
                        [
                            "rgbShift": max(base.rgbShift, FilmtonePhase0Math.rgbShiftMax),
                            "lensSoftness": max(base.lensSoftness, 0.44),
                            "vignette": max(base.vignette, 0.62),
                        ]
                    }
                ),
                controls: [
                    control("rgbShift", range: 0...FilmtonePhase0Math.rgbShiftMax, digits: 3),
                    control("lensSoftness", range: 0...1),
                    control("vignette", range: 0...1),
                ]
            ),
            .init(
                id: "glow",
                title: store.strings.advancedGlowLabel,
                recipes: standardAdvancedRecipes(
                    defaultValues: { base in
                        [
                            "bloomThreshold": min(base.bloomThreshold, 0.64),
                            "bloomStrength": max(base.bloomStrength, 0.24),
                            "bloomRadius": max(base.bloomRadius, 0.68),
                            "bloomSoftKnee": max(base.bloomSoftKnee, 0.76),
                            "halationIntensity": max(base.halationIntensity, 0.06),
                            "halationSpread": max(base.halationSpread, 34),
                            "halationHue": abs(base.halationHue) < FilmtonePhase0Math.paramEqualityTolerance ? 22 : base.halationHue,
                            "halationThreshold": min(base.halationThreshold, 0.56),
                            "halationRadius": max(base.halationRadius, 0.66),
                            "halationSoftKnee": max(base.halationSoftKnee, 0.58),
                            "diffusion": max(base.diffusion, 0.09),
                        ]
                    },
                    strongValues: { base in
                        [
                            "bloomThreshold": min(base.bloomThreshold, 0.58),
                            "bloomStrength": max(base.bloomStrength, 0.34),
                            "bloomRadius": max(base.bloomRadius, 0.78),
                            "bloomSoftKnee": max(base.bloomSoftKnee, 0.86),
                            "halationIntensity": max(base.halationIntensity, 0.10),
                            "halationSpread": max(base.halationSpread, 38),
                            "halationHue": abs(base.halationHue) < FilmtonePhase0Math.paramEqualityTolerance ? 22 : base.halationHue,
                            "halationThreshold": min(base.halationThreshold, 0.50),
                            "halationRadius": max(base.halationRadius, 0.80),
                            "halationSoftKnee": max(base.halationSoftKnee, 0.70),
                            "diffusion": max(base.diffusion, 0.14),
                        ]
                    }
                ),
                controls: [
                    control("bloomThreshold", range: 0...1),
                    control("bloomStrength", range: 0...1),
                    control("bloomRadius", range: 0...1),
                    control("bloomSoftKnee", range: 0...1),
                    control("halationIntensity", range: 0...1),
                    control("halationSpread", range: 0...40, digits: 0),
                    control("halationHue", range: 0...100, digits: 0),
                    control("halationThreshold", range: 0...1),
                    control("halationRadius", range: 0...1),
                    control("halationSoftKnee", range: 0...1),
                    control("diffusion", range: 0...1),
                ]
            ),
            .init(
                id: "grain",
                title: store.strings.advancedGrainLabel,
                recipes: grainAdvancedRecipes,
                controls: [
                    control("grainIntensity", range: 0...FilmtonePhase0Generated.grainIntensityMax),
                    control("grainSize", range: 0...1),
                    control("grainRadialMix", range: 0...1),
                ]
            ),
        ]

        if store.source?.kind == .video {
            groups.append(
                .init(
                    id: "motion",
                    title: store.strings.advancedMotionLabel,
                    recipes: standardAdvancedRecipes(
                        defaultValues: { _ in
                            [
                                "shutterAngle": 360,
                                "trailIntensity": 0,
                            ]
                        },
                        strongValues: { _ in
                            [
                                "shutterAngle": 720,
                                "trailIntensity": 0.35,
                            ]
                        }
                    ),
                    controls: [
                        control("shutterAngle", range: 0...720, digits: 0),
                        control("trailIntensity", range: 0...0.95),
                    ]
                )
            )
        }

        return groups
    }

    var toneAdvancedRecipes: [FilmtoneAdvancedParamRecipe] {
        [
            recipe("standard", store.strings.advancedToneStandardLabel) { _ in
                [:]
            },
            recipe("airy", store.strings.advancedToneAiryLabel) { _ in
                [
                    "cyan": 0.018,
                    "magenta": -0.025,
                    "yellow": -0.030,
                    "printContrast": 0.04,
                    "compressionAmount": 0.04,
                    "compressionRange": 0.54,
                ]
            },
            recipe("sunset", store.strings.advancedToneSunsetLabel) { _ in
                [
                    "cyan": -0.026,
                    "magenta": 0.028,
                    "yellow": 0.045,
                    "printContrast": 0.04,
                    "compressionAmount": 0.05,
                    "compressionRange": 0.56,
                ]
            },
            recipe("depth", store.strings.advancedToneDepthLabel) { _ in
                [
                    "cyan": 0,
                    "magenta": 0,
                    "yellow": 0.010,
                    "printContrast": 0.09,
                    "compressionAmount": 0.08,
                    "compressionRange": 0.58,
                ]
            },
        ]
    }

    var grainAdvancedRecipes: [FilmtoneAdvancedParamRecipe] {
        [
            recipe("none", store.strings.advancedPresetNoneLabel) { _ in
                [:]
            },
            recipe("fine", store.strings.advancedGrainFineLabel) { _ in
                [
                    "grainIntensity": 0.018,
                    "grainSize": 0.12,
                    "grainRadialMix": 0.65,
                ]
            },
            recipe("classic", store.strings.advancedGrainClassicLabel) { _ in
                [
                    "grainIntensity": 0.035,
                    "grainSize": 0.32,
                    "grainRadialMix": 0.90,
                ]
            },
            recipe("push", store.strings.advancedGrainPushLabel) { _ in
                [
                    "grainIntensity": 0.060,
                    "grainSize": 0.58,
                    "grainRadialMix": 1.00,
                ]
            },
        ]
    }

    func standardAdvancedRecipes(
        defaultValues: @escaping (FilmtonePhase0Params) -> [String: Double],
        strongValues: @escaping (FilmtonePhase0Params) -> [String: Double]
    ) -> [FilmtoneAdvancedParamRecipe] {
        [
            recipe("none", store.strings.advancedPresetNoneLabel) { _ in
                [:]
            },
            recipe("default", store.strings.advancedPresetDefaultLabel, values: defaultValues),
            recipe("strong", store.strings.advancedPresetStrongLabel, values: strongValues),
        ]
    }

    func recipe(
        _ id: String,
        _ label: String,
        values: @escaping (FilmtonePhase0Params) -> [String: Double]
    ) -> FilmtoneAdvancedParamRecipe {
        .init(id: id, label: label, values: values)
    }

    func control(
        _ key: String,
        range: ClosedRange<Double>,
        digits: Int = 2
    ) -> FilmtoneAdvancedParamControl {
        .init(
            key: key,
            label: store.strings.paramLabel(for: key),
            range: range,
            format: { value in
                Self.decimalLabel(value, digits: digits)
            }
        )
    }

    static func percentLabel(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    static func signedPercentLabel(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(Int((value * 100).rounded()))%"
    }

    static func decimalLabel(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}
