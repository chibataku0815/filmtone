import FilmLabSwiftCore
import Foundation

// M5-C.3b: Desktop catalog mirroring iOS canonical
// `FilmtoneStrengthSheetData.advancedParamGroups`. Field order, ranges,
// and digits track the iOS source so a Look saved on either platform
// reads sensibly. No recipes — direct slider editing only (recipes /
// help layer = M5-C.3c follow-up).
enum AdvancedAdjustCatalog {
    struct Control: Identifiable, Hashable {
        let key: String
        let label: String
        let range: ClosedRange<Double>
        let digits: Int
        var id: String { key }
    }

    struct Group: Identifiable, Hashable {
        let id: String
        let title: String
        let controls: [Control]
        let videoOnly: Bool
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
            videoOnly: false
        ),
        .init(
            id: "process",
            title: "Process",
            controls: [
                .init(key: "cyan",              label: "Cyan",     range: -1...1, digits: 2),
                .init(key: "magenta",           label: "Magenta",  range: -1...1, digits: 2),
                .init(key: "yellow",            label: "Yellow",   range: -1...1, digits: 2),
                .init(key: "printContrast",     label: "Print Contrast",     range: 0...1, digits: 2),
                .init(key: "compressionAmount", label: "Compression Amount", range: 0...1, digits: 2),
                .init(key: "compressionRange",  label: "Compression Range",  range: 0...1, digits: 2),
            ],
            videoOnly: false
        ),
        .init(
            id: "optics",
            title: "Optics",
            controls: [
                .init(key: "rgbShift",     label: "RGB Shift",     range: 0...FilmtonePhase0Generated.rgbShiftMax, digits: 3),
                .init(key: "lensSoftness", label: "Lens Softness", range: 0...1, digits: 2),
                .init(key: "vignette",     label: "Vignette",      range: 0...1, digits: 2),
            ],
            videoOnly: false
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
            videoOnly: false
        ),
        .init(
            id: "grain",
            title: "Grain",
            controls: [
                .init(key: "grainIntensity",  label: "Grain Intensity",  range: 0...FilmtonePhase0Generated.grainIntensityMax, digits: 3),
                .init(key: "grainSize",       label: "Grain Size",       range: 0...1, digits: 2),
                .init(key: "grainRadialMix",  label: "Grain Radial Mix", range: 0...1, digits: 2),
            ],
            videoOnly: false
        ),
        .init(
            id: "motion",
            title: "Motion",
            controls: [
                .init(key: "shutterAngle",   label: "Shutter Angle",   range: 0...720, digits: 0),
                .init(key: "trailIntensity", label: "Trail Intensity", range: 0...0.95, digits: 2),
            ],
            videoOnly: true
        ),
    ]

    static func groups(forVideo isVideo: Bool) -> [Group] {
        allGroups.filter { !$0.videoOnly || isVideo }
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
