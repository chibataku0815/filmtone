import FilmLabSwiftCore
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

    static func lookId(forSlug slug: String) -> String {
        // M5-A.2: built-in Creative LUT Pack 01 slugs (Stone / Urban) get a
        // dedicated namespace. Distinct from `filmtone:base:<preset>:<v>` so
        // a sidecar consumer can route by `:builtin:` vs `:base:` without
        // splitting on slug content.
        "filmtone:builtin:\(slug):\(presetVersion)"
    }

    /// M5-A.2 — preset-blend (D3-α) resolution that combines a Look's
    /// `paramOverrides` with a strength slider. When `lookSlug` is nil this
    /// delegates to the existing preset path so the legacy 4-preset UI is
    /// byte-identical.
    ///
    /// M5-M follow-up: when a Look is engaged the Look path resolves to the
    /// Look's full target params (`reset + paramOverridesPatch`) regardless
    /// of strength. The user-facing Strength slider is delegated to the
    /// creative LUT alpha (driven via
    /// `FilmtoneGradePipeline.apply(lutIntensity:)`). Resolving here to the
    /// full target avoids `preset_lerp(t) × lut_alpha(t) ≈ t²` double
    /// attenuation that collapsed the visible response into a near-binary
    /// curve. strength=1.0 stays byte-identical to the prior
    /// implementation; intermediate strengths now lerp the LUT color cast
    /// over the Look's full optical signature (bloom / vignette / grain /
    /// halation / etc. resolved to target). Deviation from iOS canonical:
    /// iOS's `presetStrength` drives a preset-lerp instead, with
    /// `lut.intensity` pinned to the Pack 01 default 1.0.
    ///
    /// M5-C.3a + M5-H.2 fix: after the preset/strength/look resolve, run
    /// `applyQuickState` for the 3-axis Quick offsets, then layer the
    /// `paramOverrides` patch on top. Order mirrors iOS canonical
    /// (`FilmtonePhase0Math.resolveParams`) so a Look saved on iOS produces
    /// identical params on macOS — and crucially, an explicit override
    /// value lands as an absolute set (Quick does not re-apply on top of
    /// it), which matches what the user sees in `AdvancedAdjustEditor`
    /// sliders.
    ///
    /// Earlier (M5-C.3a) the order was preset → override → Quick. That
    /// caused a double-Quick on any key the user touched in the Adjust
    /// panel, and made the iOS-canonical recipe stamps (`max(base.X, …)`)
    /// land at `recipe + Quick*weight` instead of the iOS-rendered
    /// `recipe`. The order swap brings byte parity back.
    static func resolved(
        presetName: String,
        strength: Double,
        lookSlug: String?,
        quickState: FilmtoneQuickState = .zero,
        paramOverrides: FilmtonePhase0ParamsPatch = .empty
    ) -> FilmtonePhase0Params {
        let base: FilmtonePhase0Params
        if let lookSlug,
           let look = FilmtoneCreativePackCatalog.find(slug: lookSlug) {
            // Strength is owned by the LUT alpha stage; resolve to target.
            base = FilmtonePhase0Generated.resetParams
                .applyingPatch(look.paramOverridesPatch)
        } else {
            base = params(for: presetName, strength: strength)
        }

        let withQuick = applyQuickState(to: base, quickState: quickState)
        // Drop overrides that already match the post-Quick base so a
        // saved Look that round-trips through Adjust without changing
        // anything does not pin redundant values into `paramOverrides`.
        // Mirrors iOS `paramOverrides.normalized(over: base+Quick)`.
        let normalized = paramOverrides.normalized(over: withQuick)
        return normalized.isEmpty
            ? withQuick
            : withQuick.applyingPatch(normalized)
    }

    /// M5-C.3a — verbatim port of iOS `FilmtonePhase0Math.applyQuickState`.
    /// Each Quick axis (`filmCharacter` / `era` / `dynamics`) carries an
    /// additive weighted offset over a fixed subset of param keys, summed
    /// into the running params object. Per-key clamps live on the params
    /// setter (already enforced by `setValue(_:for:)` for keys with
    /// generator-level bounds; the rest are unbounded by design).
    static func applyQuickState(
        to base: FilmtonePhase0Params,
        quickState: FilmtoneQuickState
    ) -> FilmtonePhase0Params {
        let clamped = quickState.clamped()
        var next = base
        for axis in FilmtonePhase0Generated.quickAxisIds {
            let axisValue = clamped.value(forAxis: axis)
            guard axisValue != 0,
                  let weights = FilmtonePhase0Generated.quickWeights[axis] else {
                continue
            }
            for (key, weight) in weights {
                let updated = next.value(for: key) + axisValue * weight
                next.setValue(updated, for: key)
            }
        }
        return next
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
