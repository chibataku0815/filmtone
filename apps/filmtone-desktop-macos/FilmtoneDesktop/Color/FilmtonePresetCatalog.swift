import Foundation

// Wraps the 4 built-in presets emitted by `bun run generate:swift` into
// FilmtonePhase0Generated.paramsByName. Stable ordering ("reset" first,
// then alphabetical) so the SwiftUI Picker shows a deterministic list.

enum FilmtonePresetCatalog {
    static let presetVersion = FilmtonePhase0Generated.presetVersion
    static let defaultName = FilmtonePhase0Generated.presetDefault
    static let presetStrengthDefault = FilmtonePhase0Generated.presetStrengthDefault

    static let orderedNames: [String] = {
        let all = FilmtonePhase0Generated.paramsByName.keys
        let sorted = all.sorted()
        if let resetIndex = sorted.firstIndex(of: defaultName), resetIndex != 0 {
            var reordered = sorted
            reordered.remove(at: resetIndex)
            reordered.insert(defaultName, at: 0)
            return reordered
        }
        return sorted
    }()

    static func params(for name: String) -> FilmtonePhase0Params {
        params(for: name, strength: presetStrengthDefault)
    }

    // Mirrors iOS `FilmtonePhase0Math.interpolatePresetParams` (canonical):
    // per-key linear interpolation from reset → target, then a single grade
    // pipeline runs with the interpolated params. The pipeline itself stays
    // unaware of strength.
    static func params(for name: String, strength: Double) -> FilmtonePhase0Params {
        let target = FilmtonePhase0Generated.paramsByName[name]
            ?? FilmtonePhase0Generated.paramsByName[defaultName]
            ?? FilmtonePhase0Generated.resetParams
        let t = clampStrength(strength)
        if t >= 1.0 {
            return target
        }
        let reset = FilmtonePhase0Generated.resetParams
        if t <= 0.0 {
            return reset
        }
        return lerp(reset: reset, target: target, t: t)
    }

    static func clampStrength(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    static func displayName(for name: String) -> String {
        switch name {
        case "reset": return "Reset"
        case "iphone": return "iPhone"
        case "softBlue": return "Soft Blue"
        case "amberGlow": return "Amber Glow"
        default: return name
        }
    }

    static func lookId(for name: String) -> String {
        // Look canonical id format mirrors film-lab-core `lookIdForBaseLook` —
        // `filmtone:base:<presetName>:<presetVersion>`. Matches Case B sidecar
        // contract in master handoff §10.
        "filmtone:base:\(name):\(presetVersion)"
    }

    private static func lerp(
        reset: FilmtonePhase0Params,
        target: FilmtonePhase0Params,
        t: Double
    ) -> FilmtonePhase0Params {
        FilmtonePhase0Params(
            exposure: mix(reset.exposure, target.exposure, t),
            contrast: mix(reset.contrast, target.contrast, t),
            saturation: mix(reset.saturation, target.saturation, t),
            temperature: mix(reset.temperature, target.temperature, t),
            tint: mix(reset.tint, target.tint, t),
            rgbShift: mix(reset.rgbShift, target.rgbShift, t),
            lensSoftness: mix(reset.lensSoftness, target.lensSoftness, t),
            grainRadialMix: mix(reset.grainRadialMix, target.grainRadialMix, t),
            grainSize: mix(reset.grainSize, target.grainSize, t),
            bloomThreshold: mix(reset.bloomThreshold, target.bloomThreshold, t),
            bloomStrength: mix(reset.bloomStrength, target.bloomStrength, t),
            bloomRadius: mix(reset.bloomRadius, target.bloomRadius, t),
            diffusion: mix(reset.diffusion, target.diffusion, t),
            halationIntensity: mix(reset.halationIntensity, target.halationIntensity, t),
            halationSpread: mix(reset.halationSpread, target.halationSpread, t),
            halationHue: mix(reset.halationHue, target.halationHue, t),
            halationThreshold: mix(reset.halationThreshold, target.halationThreshold, t),
            halationRadius: mix(reset.halationRadius, target.halationRadius, t),
            bloomSoftKnee: mix(reset.bloomSoftKnee, target.bloomSoftKnee, t),
            halationSoftKnee: mix(reset.halationSoftKnee, target.halationSoftKnee, t),
            compressionAmount: mix(reset.compressionAmount, target.compressionAmount, t),
            compressionRange: mix(reset.compressionRange, target.compressionRange, t),
            printContrast: mix(reset.printContrast, target.printContrast, t),
            cyan: mix(reset.cyan, target.cyan, t),
            magenta: mix(reset.magenta, target.magenta, t),
            yellow: mix(reset.yellow, target.yellow, t),
            shutterAngle: mix(reset.shutterAngle, target.shutterAngle, t),
            trailIntensity: mix(reset.trailIntensity, target.trailIntensity, t),
            fade: mix(reset.fade, target.fade, t),
            shadowTone: mix(reset.shadowTone, target.shadowTone, t),
            highlightTone: mix(reset.highlightTone, target.highlightTone, t),
            shadowHue: mix(reset.shadowHue, target.shadowHue, t),
            highlightHue: mix(reset.highlightHue, target.highlightHue, t),
            vignette: mix(reset.vignette, target.vignette, t),
            grainIntensity: mix(reset.grainIntensity, target.grainIntensity, t)
        )
    }

    private static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
