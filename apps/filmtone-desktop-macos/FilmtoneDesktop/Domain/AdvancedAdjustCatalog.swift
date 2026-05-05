import FilmLabSwiftCore
import Foundation

// M5-C.3b + M5-H.2: Desktop catalog mirroring iOS canonical
// `FilmtoneStrengthSheetData.advancedParamGroups`.
//
// M5-H.2 brought labels in line with iOS `FilmtoneStrings.paramLabels`
// (the user-facing name a slider should carry on either platform) and
// added per-group `Recipe` chips matching the iOS
// `standardAdvancedRecipes` shape — so a Look saved on either platform
// reads sensibly and a user can apply the canonical Default / Strong
// preset stamps without dragging each slider individually.
enum AdvancedAdjustCatalog {
    struct Control: Identifiable, Hashable {
        let key: String
        let label: String
        let range: ClosedRange<Double>
        let digits: Int
        var id: String { key }
    }

    /// One chip below a group title. Apply by reading `values(base)`
    /// against the resolved-without-overrides params, then writing each
    /// returned key into `paramOverrides` (clamped). The `none` recipe
    /// returns `[:]` and signals that every key in the group should be
    /// cleared back to base — see `EditorState.applyAdvancedRecipe`.
    struct Recipe: Identifiable, Hashable {
        enum Kind: Hashable {
            /// "なし" / "None" / tone "Standard" — clear group overrides.
            case none
            /// "標準" / "Default" or any non-clearing canonical stamp.
            case stamp
        }

        let id: String
        let label: String
        let kind: Kind
        /// Computed from base params at apply time. The closure is held
        /// as a function value (Hashable conformance ignores it).
        let values: @Sendable (FilmtonePhase0Params) -> [String: Double]

        static func == (lhs: Recipe, rhs: Recipe) -> Bool {
            lhs.id == rhs.id && lhs.label == rhs.label && lhs.kind == rhs.kind
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
            hasher.combine(label)
            hasher.combine(kind)
        }
    }

    struct Group: Identifiable, Hashable {
        let id: String
        let title: String
        let controls: [Control]
        let videoOnly: Bool
        let recipes: [Recipe]
    }

    static let allGroups: [Group] = [
        .init(
            id: "basic",
            title: "Basic",
            controls: [
                .init(key: "exposure",    label: "Exposure",    range: -2...2, digits: 2),
                .init(key: "contrast",    label: "Contrast",    range: 0...2,  digits: 2),
                .init(key: "saturation",  label: "Saturation",  range: 0...2,  digits: 2),
                .init(key: "temperature", label: "Temperature", range: -1...1, digits: 2),
                .init(key: "tint",        label: "Tint",        range: -1...1, digits: 2),
                .init(key: "fade",        label: "Fade",        range: 0...1,  digits: 2),
            ],
            videoOnly: false,
            // iOS canonical: basic group ships with no recipe chips.
            recipes: []
        ),
        .init(
            id: "process",
            title: "Tone",
            controls: [
                .init(key: "cyan",              label: "Cyan",     range: -1...1, digits: 2),
                .init(key: "magenta",           label: "Magenta",  range: -1...1, digits: 2),
                .init(key: "yellow",            label: "Yellow",   range: -1...1, digits: 2),
                .init(key: "printContrast",     label: "Print Contrast", range: 0...1, digits: 2),
                .init(key: "compressionAmount", label: "Highlight softness", range: 0...1, digits: 2),
                .init(key: "compressionRange",  label: "Tone span", range: 0...1, digits: 2),
            ],
            videoOnly: false,
            // iOS canonical tone-specific 4-recipe variant. "Standard"
            // is the clear-group chip (paramOverrides for these 6 keys
            // drop, falling back to preset baseline).
            recipes: [
                .init(id: "standard", label: "Standard", kind: .none) { _ in [:] },
                .init(id: "airy", label: "Airy", kind: .stamp) { _ in
                    [
                        "cyan": 0.018,
                        "magenta": -0.025,
                        "yellow": -0.030,
                        "printContrast": 0.04,
                        "compressionAmount": 0.04,
                        "compressionRange": 0.54,
                    ]
                },
                .init(id: "sunset", label: "Sunset", kind: .stamp) { _ in
                    [
                        "cyan": -0.026,
                        "magenta": 0.028,
                        "yellow": 0.045,
                        "printContrast": 0.04,
                        "compressionAmount": 0.05,
                        "compressionRange": 0.56,
                    ]
                },
                .init(id: "depth", label: "Depth", kind: .stamp) { _ in
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
        ),
        .init(
            id: "optics",
            title: "Optics",
            controls: [
                .init(key: "rgbShift",     label: "Color fringing", range: 0...FilmtonePhase0Generated.rgbShiftMax, digits: 3),
                .init(key: "lensSoftness", label: "Lens softness", range: 0...1, digits: 2),
                .init(key: "vignette",     label: "Vignette",      range: 0...1, digits: 2),
            ],
            videoOnly: false,
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
                        "rgbShift": max(base.rgbShift, FilmtonePhase0Generated.rgbShiftMax),
                        "lensSoftness": max(base.lensSoftness, 0.44),
                        "vignette": max(base.vignette, 0.62),
                    ]
                }
            )
        ),
        .init(
            id: "glow",
            title: "Glow",
            controls: [
                .init(key: "bloomThreshold",    label: "Bloom Threshold",    range: 0...1, digits: 2),
                .init(key: "bloomStrength",     label: "Bloom Strength",     range: 0...1, digits: 2),
                .init(key: "bloomRadius",       label: "Bloom Radius",       range: 0...1, digits: 2),
                .init(key: "bloomSoftKnee",     label: "Bloom Soft Knee",    range: 0...1, digits: 2),
                .init(key: "halationIntensity", label: "Halation Intensity", range: 0...1, digits: 2),
                .init(key: "halationSpread",    label: "Halation Spread",    range: 0...40, digits: 0),
                .init(key: "halationHue",       label: "Halation Hue",       range: 0...100, digits: 0),
                .init(key: "halationThreshold", label: "Halation Threshold", range: 0...1, digits: 2),
                .init(key: "halationRadius",    label: "Halation Radius",    range: 0...1, digits: 2),
                .init(key: "halationSoftKnee",  label: "Halation Soft Knee", range: 0...1, digits: 2),
                .init(key: "diffusion",         label: "Diffusion",          range: 0...1, digits: 2),
            ],
            videoOnly: false,
            recipes: standardAdvancedRecipes(
                defaultValues: { base in
                    [
                        "bloomThreshold": min(base.bloomThreshold, 0.64),
                        "bloomStrength": max(base.bloomStrength, 0.24),
                        "bloomRadius": max(base.bloomRadius, 0.68),
                        "bloomSoftKnee": max(base.bloomSoftKnee, 0.76),
                        "halationIntensity": max(base.halationIntensity, 0.06),
                        "halationSpread": max(base.halationSpread, 34),
                        "halationHue": abs(base.halationHue) < 1e-6 ? 22 : base.halationHue,
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
                        "halationHue": abs(base.halationHue) < 1e-6 ? 22 : base.halationHue,
                        "halationThreshold": min(base.halationThreshold, 0.50),
                        "halationRadius": max(base.halationRadius, 0.80),
                        "halationSoftKnee": max(base.halationSoftKnee, 0.70),
                        "diffusion": max(base.diffusion, 0.14),
                    ]
                }
            )
        ),
        .init(
            id: "grain",
            title: "Grain",
            controls: [
                .init(key: "grainIntensity",  label: "Grain Strength",      range: 0...FilmtonePhase0Generated.grainIntensityMax, digits: 3),
                .init(key: "grainSize",       label: "Grain Size",          range: 0...1, digits: 2),
                .init(key: "grainRadialMix",  label: "Grain edge emphasis", range: 0...1, digits: 2),
            ],
            videoOnly: false,
            recipes: standardAdvancedRecipes(
                defaultValues: { base in
                    [
                        "grainIntensity": max(base.grainIntensity, 0.025),
                        "grainSize": max(base.grainSize, 0.30),
                        "grainRadialMix": 1.0,
                    ]
                },
                strongValues: { base in
                    [
                        "grainIntensity": max(base.grainIntensity, 0.045),
                        "grainSize": max(base.grainSize, 0.38),
                        "grainRadialMix": 1.0,
                    ]
                }
            )
        ),
        .init(
            id: "motion",
            title: "Motion",
            controls: [
                .init(key: "shutterAngle",   label: "Shutter Angle", range: 0...720, digits: 0),
                .init(key: "trailIntensity", label: "Trail Length",  range: 0...0.95, digits: 2),
            ],
            videoOnly: true,
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
            )
        ),
    ]

    static func groups(forVideo isVideo: Bool) -> [Group] {
        allGroups.filter { !$0.videoOnly || isVideo }
    }

    static func group(forId id: String) -> Group? {
        allGroups.first { $0.id == id }
    }

    /// Mirror of iOS `standardAdvancedRecipes(defaultValues:strongValues:)` —
    /// the 3-chip pattern (`なし` / `標準` / `強め`) reused by every non-
    /// basic group except `process`.
    private static func standardAdvancedRecipes(
        defaultValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double],
        strongValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double]
    ) -> [Recipe] {
        [
            .init(id: "none", label: "None", kind: .none) { _ in [:] },
            .init(id: "default", label: "Default", kind: .stamp, values: defaultValues),
            .init(id: "strong", label: "Strong", kind: .stamp, values: strongValues),
        ]
    }

    /// Mirror of iOS `FilmtonePhase0Math.clampParam` — applied at write
    /// time so persisted overrides stay within the canonical range. The
    /// shutterAngle case keeps iOS's discontinuous snap (below 90 → 0,
    /// 90..<180 → 180) so motion-blur disable is reachable from the slider.
    static func clamp(_ value: Double, for key: String) -> Double {
        switch key {
        case "exposure":
            return max(-2, min(2, value))
        case "contrast", "saturation":
            return max(0, min(2, value))
        case "temperature", "tint", "cyan", "magenta", "yellow":
            return max(-1, min(1, value))
        case "halationSpread":
            return max(0, min(40, value))
        case "halationHue":
            return max(0, min(100, value))
        case "shutterAngle":
            let clamped = max(0, min(720, value))
            return clamped < 90 ? 0 : max(180, clamped)
        case "trailIntensity":
            return max(0, min(0.95, value))
        case "rgbShift":
            return max(0, min(FilmtonePhase0Generated.rgbShiftMax, value))
        case "grainIntensity":
            return max(0, min(FilmtonePhase0Generated.grainIntensityMax, value))
        case "lensSoftness",
             "grainRadialMix",
             "grainSize",
             "bloomThreshold",
             "bloomStrength",
             "bloomRadius",
             "diffusion",
             "halationIntensity",
             "halationThreshold",
             "halationRadius",
             "bloomSoftKnee",
             "halationSoftKnee",
             "compressionAmount",
             "compressionRange",
             "printContrast",
             "fade",
             "vignette":
            return max(0, min(1, value))
        default:
            return value
        }
    }

    static func formatValue(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", value)
    }
}
