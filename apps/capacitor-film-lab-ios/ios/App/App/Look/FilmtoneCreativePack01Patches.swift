import FilmLabSwiftCore
import Foundation

/// Creative Pack 01 baseline Phase 0 patches — the optical / restraint
/// baselines that ship with each Look's bundled `.cube`. Pulled into a
/// dedicated file so the Look Director resolver tests can link them
/// without compiling the whole `FilmtoneBuiltInCatalog` graph.
enum FilmtoneCreativePack01Patches {

    /// Color neutralization values shared by every Pack 01 patch. The
    /// cube is SSOT for color, so the runtime kernel must produce
    /// identity in these fields before the cube is sampled.
    static let colorOpNeutralEntries: [String: Double] = [
        "exposure": 0,
        "contrast": 1,
        "saturation": 1,
        "temperature": 0,
        "tint": 0,
        "fade": 0,
        "compressionAmount": 0,
        "compressionRange": 0.5,
        "printContrast": 0,
        "cyan": 0,
        "magenta": 0,
        "yellow": 0,
        "shadowTone": 0,
        "highlightTone": 0,
    ]

    /// Stone — generated 65³ cube plus a restrained optical baseline.
    static let stonePatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0.0032
        values["bloomThreshold"] = 0.64
        values["bloomStrength"] = 0.20
        values["bloomRadius"] = 0.62
        values["halationIntensity"] = 0.07
        values["halationHue"] = 24
        values["diffusion"] = 0.06
        values["lensSoftness"] = 0.095
        values["grainIntensity"] = 0.0045
        values["grainSize"] = 0.13
        values["vignette"] = 0.055
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    /// Urban — generated 65³ cube plus a restrained optical baseline.
    static let urbanPatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0.0028
        values["bloomThreshold"] = 0.66
        values["bloomStrength"] = 0.18
        values["bloomRadius"] = 0.58
        values["halationIntensity"] = 0.055
        values["halationHue"] = 20
        values["diffusion"] = 0.065
        values["lensSoftness"] = 0.095
        values["grainIntensity"] = 0.0045
        values["grainSize"] = 0.13
        values["vignette"] = 0.06
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    /// Noir — generated 65³ toned print monochrome cube plus a denser
    /// optical baseline.
    static let noirPatch: FilmtonePhase0ParamsPatch = {
        var values = colorOpNeutralEntries
        values["rgbShift"] = 0
        values["bloomThreshold"] = 0.56
        values["bloomStrength"] = 0.2
        values["bloomRadius"] = 0.64
        values["halationIntensity"] = 0.028
        values["halationHue"] = 36
        values["diffusion"] = 0.13
        values["lensSoftness"] = 0.16
        values["grainRadialMix"] = 0.9
        values["grainIntensity"] = 0.075
        values["grainSize"] = 0.48
        values["vignette"] = 0.16
        return FilmtonePhase0ParamsPatch(values: values)
    }()

    /// Catalog baseline lookup keyed by Creative Pack 01 slug. Used by
    /// the re-resolver to restore non-adapted keys to the bundled baseline
    /// when source/profile changes drop a previously-active overlay key.
    static func baselinePatch(for slug: String) -> FilmtonePhase0ParamsPatch? {
        switch slug {
        case "filmtone-creative-pack-01-stone":
            return stonePatch
        case "filmtone-creative-pack-01-urban":
            return urbanPatch
        case "filmtone-creative-pack-01-noir":
            return noirPatch
        default:
            return nil
        }
    }

    /// Keys the Look Director may write into the adaptation overlay. When
    /// source/profile changes drop a key, the re-resolver restores it from
    /// the catalog baseline so a previous source's overlay value does not
    /// linger.
    static let adaptationOverlayKeys: Set<String> = [
        "compressionAmount",
        "compressionRange",
        "fade",
        "detailSoftness",
        "bloomStrength",
        "bloomThreshold",
        "halationIntensity",
        "diffusion",
        "vignette",
    ]
}
