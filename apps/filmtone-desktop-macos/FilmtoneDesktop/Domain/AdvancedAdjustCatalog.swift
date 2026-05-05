import FilmLabSwiftCore
import Foundation

// M5-C.3b + M5-H.2 + M5-I.1: Desktop catalog mirroring iOS canonical
// `FilmtoneStrengthSheetData.advancedParamGroups`.
//
// M5-H.2 brought labels in line with iOS `FilmtoneStrings.paramLabels`
// (the user-facing name a slider should carry on either platform) and
// added per-group `Recipe` chips matching the iOS
// `standardAdvancedRecipes` shape — so a Look saved on either platform
// reads sensibly and a user can apply the canonical Default / Strong
// preset stamps without dragging each slider individually.
//
// M5-I.1 lifted every user-facing string out of this file into the
// `FilmtoneDesktopStrings` layer so JA/EN copy resolves the same way iOS
// does and call sites can pass an explicit strings instance for tests.
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

    // M5-I.1: every user-facing label resolved through `strings`. Tests
    // pass `.english` for deterministic comparisons against iOS canonical
    // copy regardless of host locale; production callers pass `.current`.
    static func allGroups(strings: FilmtoneDesktopStrings) -> [Group] {
        [
            .init(
                id: "basic",
                title: strings.groupBasic,
                controls: [
                    .init(key: "exposure",    label: strings.paramLabel(for: "exposure"),    range: -2...2, digits: 2),
                    .init(key: "contrast",    label: strings.paramLabel(for: "contrast"),    range: 0...2,  digits: 2),
                    .init(key: "saturation",  label: strings.paramLabel(for: "saturation"),  range: 0...2,  digits: 2),
                    .init(key: "temperature", label: strings.paramLabel(for: "temperature"), range: -1...1, digits: 2),
                    .init(key: "tint",        label: strings.paramLabel(for: "tint"),        range: -1...1, digits: 2),
                    .init(key: "fade",        label: strings.paramLabel(for: "fade"),        range: 0...1,  digits: 2),
                ],
                videoOnly: false,
                // iOS canonical: basic group ships with no recipe chips.
                recipes: []
            ),
            .init(
                id: "process",
                title: strings.groupTone,
                controls: [
                    .init(key: "cyan",              label: strings.paramLabel(for: "cyan"),              range: -1...1, digits: 2),
                    .init(key: "magenta",           label: strings.paramLabel(for: "magenta"),           range: -1...1, digits: 2),
                    .init(key: "yellow",            label: strings.paramLabel(for: "yellow"),            range: -1...1, digits: 2),
                    .init(key: "printContrast",     label: strings.paramLabel(for: "printContrast"),     range: 0...1, digits: 2),
                    .init(key: "compressionAmount", label: strings.paramLabel(for: "compressionAmount"), range: 0...1, digits: 2),
                    .init(key: "compressionRange",  label: strings.paramLabel(for: "compressionRange"),  range: 0...1, digits: 2),
                ],
                videoOnly: false,
                // iOS canonical tone-specific 4-recipe variant. "Standard"
                // is the clear-group chip (paramOverrides for these 6 keys
                // drop, falling back to preset baseline).
                recipes: [
                    .init(id: "standard", label: strings.toneStandard, kind: .none) { _ in [:] },
                    .init(id: "airy", label: strings.toneAiry, kind: .stamp) { _ in
                        [
                            "cyan": 0.018,
                            "magenta": -0.025,
                            "yellow": -0.030,
                            "printContrast": 0.04,
                            "compressionAmount": 0.04,
                            "compressionRange": 0.54,
                        ]
                    },
                    .init(id: "sunset", label: strings.toneSunset, kind: .stamp) { _ in
                        [
                            "cyan": -0.026,
                            "magenta": 0.028,
                            "yellow": 0.045,
                            "printContrast": 0.04,
                            "compressionAmount": 0.05,
                            "compressionRange": 0.56,
                        ]
                    },
                    .init(id: "depth", label: strings.toneDepth, kind: .stamp) { _ in
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
                title: strings.groupOptics,
                controls: [
                    .init(key: "rgbShift",     label: strings.paramLabel(for: "rgbShift"),     range: 0...FilmtonePhase0Generated.rgbShiftMax, digits: 3),
                    .init(key: "lensSoftness", label: strings.paramLabel(for: "lensSoftness"), range: 0...1, digits: 2),
                    .init(key: "vignette",     label: strings.paramLabel(for: "vignette"),     range: 0...1, digits: 2),
                ],
                videoOnly: false,
                recipes: standardAdvancedRecipes(
                    strings: strings,
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
                title: strings.groupGlow,
                controls: [
                    .init(key: "bloomThreshold",    label: strings.paramLabel(for: "bloomThreshold"),    range: 0...1, digits: 2),
                    .init(key: "bloomStrength",     label: strings.paramLabel(for: "bloomStrength"),     range: 0...1, digits: 2),
                    .init(key: "bloomRadius",       label: strings.paramLabel(for: "bloomRadius"),       range: 0...1, digits: 2),
                    .init(key: "bloomSoftKnee",     label: strings.paramLabel(for: "bloomSoftKnee"),     range: 0...1, digits: 2),
                    .init(key: "halationIntensity", label: strings.paramLabel(for: "halationIntensity"), range: 0...1, digits: 2),
                    .init(key: "halationSpread",    label: strings.paramLabel(for: "halationSpread"),    range: 0...40, digits: 0),
                    .init(key: "halationHue",       label: strings.paramLabel(for: "halationHue"),       range: 0...100, digits: 0),
                    .init(key: "halationThreshold", label: strings.paramLabel(for: "halationThreshold"), range: 0...1, digits: 2),
                    .init(key: "halationRadius",    label: strings.paramLabel(for: "halationRadius"),    range: 0...1, digits: 2),
                    .init(key: "halationSoftKnee",  label: strings.paramLabel(for: "halationSoftKnee"),  range: 0...1, digits: 2),
                    .init(key: "diffusion",         label: strings.paramLabel(for: "diffusion"),         range: 0...1, digits: 2),
                ],
                videoOnly: false,
                recipes: standardAdvancedRecipes(
                    strings: strings,
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
                title: strings.groupGrain,
                controls: [
                    .init(key: "grainIntensity",  label: strings.paramLabel(for: "grainIntensity"),  range: 0...FilmtonePhase0Generated.grainIntensityMax, digits: 3),
                    .init(key: "grainSize",       label: strings.paramLabel(for: "grainSize"),       range: 0...1, digits: 2),
                    .init(key: "grainRadialMix",  label: strings.paramLabel(for: "grainRadialMix"),  range: 0...1, digits: 2),
                ],
                videoOnly: false,
                recipes: standardAdvancedRecipes(
                    strings: strings,
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
                title: strings.groupMotion,
                controls: [
                    .init(key: "shutterAngle",   label: strings.paramLabel(for: "shutterAngle"),   range: 0...720, digits: 0),
                    .init(key: "trailIntensity", label: strings.paramLabel(for: "trailIntensity"), range: 0...0.95, digits: 2),
                ],
                videoOnly: true,
                recipes: standardAdvancedRecipes(
                    strings: strings,
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
    }

    /// Convenience accessor that resolves strings off the current host
    /// locale. Production SwiftUI surface uses this; tests prefer the
    /// explicit `allGroups(strings:)` form for determinism.
    static var allGroups: [Group] {
        allGroups(strings: .current)
    }

    static func groups(forVideo isVideo: Bool,
                       strings: FilmtoneDesktopStrings = .current) -> [Group] {
        allGroups(strings: strings).filter { !$0.videoOnly || isVideo }
    }

    static func visibleRecipeChipGroupIds(forVideo isVideo: Bool) -> [String] {
        groups(forVideo: isVideo, strings: .english)
            .filter { !$0.recipes.isEmpty }
            .map(\.id)
    }

    static func group(forId id: String,
                      strings: FilmtoneDesktopStrings = .current) -> Group? {
        allGroups(strings: strings).first { $0.id == id }
    }

    /// Mirror of iOS `standardAdvancedRecipes(defaultValues:strongValues:)` —
    /// the 3-chip pattern (`なし` / `標準` / `強め`) reused by every non-
    /// basic group except `process`.
    private static func standardAdvancedRecipes(
        strings: FilmtoneDesktopStrings,
        defaultValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double],
        strongValues: @escaping @Sendable (FilmtonePhase0Params) -> [String: Double]
    ) -> [Recipe] {
        [
            .init(id: "none", label: strings.presetNone, kind: .none) { _ in [:] },
            .init(id: "default", label: strings.presetDefault, kind: .stamp, values: defaultValues),
            .init(id: "strong", label: strings.presetStrong, kind: .stamp, values: strongValues),
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

    /// Mirror of iOS `FilmtonePhase0Math.paramEqualityTolerance`. Used by
    /// `FilmtonePhase0ParamsPatch.normalized(over:)` so an override that
    /// equals the resolved baseline drops out before it gets pinned into
    /// the patch — keeps saved-Look JSON tight and prevents recipe stamps
    /// from materializing redundant identity entries.
    static let paramEqualityTolerance: Double = 0.0001
}

enum FilmtoneOpticalFilterCatalog {
    struct Profile: Identifiable, Hashable, Sendable {
        let id: String
        let family: String
        let density: String
        let displayName: String
        let shortLabel: String
        let paramPatch: FilmtonePhase0ParamsPatch
    }

    static let noneIdentifier = "none"

    static let profiles: [Profile] = [
        .init(
            id: "backlightVeil-1-8",
            family: "backlightVeil",
            density: "1/8",
            displayName: "Backlight Veil 1/8",
            shortLabel: "1/8",
            paramPatch: supportedBacklightVeilPatch([
                "bloomThreshold": 0.66,
                "bloomStrength": 0.20,
                "bloomRadius": 0.70,
                "bloomSoftKnee": 0.70,
                "diffusion": 0.12,
                "halationIntensity": 0.07,
                "halationThreshold": 0.58,
                "halationRadius": 0.52,
                "halationHue": 22,
                "halationSoftKnee": 0.48,
                "lensSoftness": 0.06,
                "rgbShift": 0.0005,
            ])
        ),
        .init(
            id: "backlightVeil-1-4",
            family: "backlightVeil",
            density: "1/4",
            displayName: "Backlight Veil 1/4",
            shortLabel: "1/4",
            paramPatch: supportedBacklightVeilPatch([
                "bloomThreshold": 0.56,
                "bloomStrength": 0.38,
                "bloomRadius": 0.80,
                "bloomSoftKnee": 0.76,
                "diffusion": 0.24,
                "halationIntensity": 0.14,
                "halationThreshold": 0.52,
                "halationRadius": 0.62,
                "halationHue": 22,
                "halationSoftKnee": 0.56,
                "lensSoftness": 0.08,
                "rgbShift": 0.0007,
            ])
        ),
        .init(
            id: "backlightVeil-1-2",
            family: "backlightVeil",
            density: "1/2",
            displayName: "Backlight Veil 1/2",
            shortLabel: "1/2",
            paramPatch: supportedBacklightVeilPatch([
                "bloomThreshold": 0.50,
                "bloomStrength": 0.60,
                "bloomRadius": 0.88,
                "bloomSoftKnee": 0.82,
                "diffusion": 0.38,
                "halationIntensity": 0.22,
                "halationThreshold": 0.46,
                "halationRadius": 0.74,
                "halationHue": 22,
                "halationSoftKnee": 0.64,
                "lensSoftness": 0.10,
                "rgbShift": 0.0009,
            ])
        ),
    ]

    static func profile(for id: String?) -> Profile? {
        guard let id, id != noneIdentifier else { return nil }
        return profiles.first { $0.id == id }
    }

    static func renderParamOverrides(
        profileId: String?,
        userOverrides: FilmtonePhase0ParamsPatch
    ) -> FilmtonePhase0ParamsPatch {
        var values = profile(for: profileId)?.paramPatch.values ?? [:]
        for (key, value) in userOverrides.values {
            values[key] = value
        }
        return FilmtonePhase0ParamsPatch(values: values)
    }

    static func sidecarPayload(for id: String?) -> [String: Any]? {
        guard let profile = profile(for: id) else { return nil }
        return [
            "id": profile.id,
            "family": profile.family,
            "density": profile.density,
            "displayName": profile.displayName,
        ]
    }

    private static func supportedBacklightVeilPatch(_ values: [String: Double]) -> FilmtonePhase0ParamsPatch {
        let clamped = values.reduce(into: [String: Double]()) { result, element in
            result[element.key] = AdvancedAdjustCatalog.clamp(element.value, for: element.key)
        }
        return FilmtonePhase0ParamsPatch(values: clamped)
    }
}

extension FilmtonePhase0ParamsPatch {
    /// Drop every override whose clamped value matches the resolved base
    /// within `paramEqualityTolerance`. Mirrors iOS
    /// `FilmtonePhase0ParamsPatch.normalized(over:)` so the post-Quick
    /// resolve produces an identical patch shape on both platforms.
    func normalized(over base: FilmtonePhase0Params) -> FilmtonePhase0ParamsPatch {
        var next: [String: Double] = [:]
        for (key, value) in values {
            let clamped = AdvancedAdjustCatalog.clamp(value, for: key)
            if abs(clamped - base.value(for: key)) >= AdvancedAdjustCatalog.paramEqualityTolerance {
                next[key] = clamped
            }
        }
        return FilmtonePhase0ParamsPatch(values: next)
    }
}
