import Foundation

// M5-I.1: Desktop-side mirror of the user-facing label catalog from iOS
// `FilmtoneStrings.swift`, scoped to the AdvancedAdjustEditor surface
// (group titles, recipe chips, per-key param labels, and supporting
// affordance copy).
//
// iOS keeps every string behind `NSLocalizedString` against the bundle's
// `.lproj` translations and falls back to `defaultValue` when no row
// exists. Native Desktop v2 does not yet ship `.lproj` resources, so this
// struct holds the same default-value fallbacks iOS produces today and
// picks between English and Japanese off `Locale.preferredLanguages`,
// matching the iOS `prefersJapanese` selector. When Desktop grows real
// `Localizable.strings`, swap the static `english` / `japanese` builders
// for `NSLocalizedString` lookups; call sites and shape stay the same.
struct FilmtoneDesktopStrings: Sendable {
    let advancedTitle: String
    let advancedActiveBadgeFormat: @Sendable (_ active: Int, _ total: Int) -> String
    let advancedResetAllOverrides: String
    let advancedClose: String
    let advancedClearGroupHelp: @Sendable (_ groupTitle: String) -> String
    let advancedApplyRecipeHelp: @Sendable (_ recipeLabel: String, _ groupTitle: String) -> String
    let advancedResetParamHelp: @Sendable (_ paramLabel: String) -> String
    let groupBasic: String
    let groupTone: String
    let groupOptics: String
    let groupGlow: String
    let groupGrain: String
    let groupMotion: String
    let presetNone: String
    let presetDefault: String
    let presetStrong: String
    let grainFine: String
    let grainClassic: String
    let grainPush: String
    let toneStandard: String
    let toneAiry: String
    let toneSunset: String
    let toneDepth: String
    let paramLabels: [String: String]

    func paramLabel(for key: String) -> String {
        paramLabels[key] ?? key
    }

    static let english: FilmtoneDesktopStrings = .init(
        advancedTitle: "Advanced Adjust",
        advancedActiveBadgeFormat: { active, total in
            "\(active) / \(total) active"
        },
        advancedResetAllOverrides: "Reset All Overrides",
        advancedClose: "Close",
        advancedClearGroupHelp: { groupTitle in
            "Clear \(groupTitle) overrides"
        },
        advancedApplyRecipeHelp: { recipeLabel, groupTitle in
            "Apply \(recipeLabel) preset to \(groupTitle)"
        },
        advancedResetParamHelp: { paramLabel in
            "Reset \(paramLabel) to base value"
        },
        groupBasic: "Basic",
        groupTone: "Tone",
        groupOptics: "Optics",
        groupGlow: "Glow",
        groupGrain: "Grain",
        groupMotion: "Motion",
        presetNone: "None",
        presetDefault: "Default",
        presetStrong: "Strong",
        grainFine: "Fine",
        grainClassic: "Classic",
        grainPush: "Push",
        toneStandard: "Standard",
        toneAiry: "Airy",
        toneSunset: "Sunset",
        toneDepth: "Depth",
        paramLabels: englishParamLabels
    )

    // iOS canonical (`FilmtoneStrings.swift:894-1021`) only branches a
    // subset of labels on `prefersJapanese`. Mirror that subset exactly
    // so cross-platform copy parity is line-by-line traceable: groups
    // / presets / grain chips / tone chips / motion params translate;
    // everything else keeps the iOS default English even on JA hosts.
    static let japanese: FilmtoneDesktopStrings = .init(
        advancedTitle: "詳細調整",
        advancedActiveBadgeFormat: { active, total in
            "\(active) / \(total) active"
        },
        advancedResetAllOverrides: "すべてのオーバーライドをリセット",
        advancedClose: "閉じる",
        advancedClearGroupHelp: { groupTitle in
            "\(groupTitle) のオーバーライドをクリア"
        },
        advancedApplyRecipeHelp: { recipeLabel, groupTitle in
            "\(recipeLabel) プリセットを \(groupTitle) に適用"
        },
        advancedResetParamHelp: { paramLabel in
            "\(paramLabel) をベース値にリセット"
        },
        groupBasic: "Basic",
        groupTone: "階調",
        groupOptics: "Optics",
        groupGlow: "Glow",
        groupGrain: "Grain",
        groupMotion: "Motion",
        presetNone: "なし",
        presetDefault: "標準",
        presetStrong: "強め",
        grainFine: "微粒子",
        grainClassic: "標準粒子",
        grainPush: "粗粒子",
        toneStandard: "標準",
        toneAiry: "爽やか",
        toneSunset: "夕景",
        toneDepth: "深み",
        paramLabels: japaneseParamLabels
    )

    static var current: FilmtoneDesktopStrings {
        prefersJapanese() ? .japanese : .english
    }

    // Mirrors the iOS `FilmtoneStrings.swift` `prefersJapanese`
    // computation: read the host's preferred language ordering and treat
    // any "ja*" tag (ja, ja-JP, ja-Hira) as Japanese.
    static func prefersJapanese() -> Bool {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.lowercased().hasPrefix("ja")
    }
}

// iOS canonical defaults from `FilmtoneStrings.swift:989-1021`. Most
// rows fall back to English even on JA locale because iOS keeps the
// English defaultValue for them; only `shutterAngle` / `trailIntensity`
// branch on `prefersJapanese`. Match that exactly to avoid drift.
private let englishParamLabels: [String: String] = [
    "exposure": "Exposure",
    "contrast": "Contrast",
    "saturation": "Saturation",
    "temperature": "Temperature",
    "tint": "Tint",
    "fade": "Fade",
    "rgbShift": "Color fringing",
    "lensSoftness": "Lens softness",
    "vignette": "Vignette",
    "bloomThreshold": "Bloom Threshold",
    "bloomStrength": "Bloom Strength",
    "bloomRadius": "Bloom Radius",
    "bloomSoftKnee": "Bloom Soft Knee",
    "halationIntensity": "Halation Intensity",
    "halationSpread": "Halation Spread",
    "halationHue": "Halation Hue",
    "halationThreshold": "Halation Threshold",
    "halationRadius": "Halation Radius",
    "halationSoftKnee": "Halation Soft Knee",
    "diffusion": "Diffusion",
    "grainIntensity": "Grain Strength",
    "grainSize": "Grain Size",
    "grainRadialMix": "Grain edge emphasis",
    "compressionAmount": "Highlight softness",
    "compressionRange": "Tone span",
    "printContrast": "Print Contrast",
    "cyan": "Cyan",
    "magenta": "Magenta",
    "yellow": "Yellow",
    "shutterAngle": "Shutter Angle",
    "trailIntensity": "Trail Length",
]

private let japaneseParamLabels: [String: String] = [
    "exposure": "Exposure",
    "contrast": "Contrast",
    "saturation": "Saturation",
    "temperature": "Temperature",
    "tint": "Tint",
    "fade": "Fade",
    "rgbShift": "Color fringing",
    "lensSoftness": "Lens softness",
    "vignette": "Vignette",
    "bloomThreshold": "Bloom Threshold",
    "bloomStrength": "Bloom Strength",
    "bloomRadius": "Bloom Radius",
    "bloomSoftKnee": "Bloom Soft Knee",
    "halationIntensity": "Halation Intensity",
    "halationSpread": "Halation Spread",
    "halationHue": "Halation Hue",
    "halationThreshold": "Halation Threshold",
    "halationRadius": "Halation Radius",
    "halationSoftKnee": "Halation Soft Knee",
    "diffusion": "Diffusion",
    "grainIntensity": "Grain Strength",
    "grainSize": "Grain Size",
    "grainRadialMix": "Grain edge emphasis",
    "compressionAmount": "Highlight softness",
    "compressionRange": "Tone span",
    "printContrast": "Print Contrast",
    "cyan": "Cyan",
    "magenta": "Magenta",
    "yellow": "Yellow",
    "shutterAngle": "シャッターアングル",
    "trailIntensity": "残像の長さ",
]
