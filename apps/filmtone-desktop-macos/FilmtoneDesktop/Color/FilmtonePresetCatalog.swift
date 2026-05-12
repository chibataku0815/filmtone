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
    ///
    /// M5-M follow-up (Look × Veil energy max-merge): when both a Look and
    /// a Backlight Veil profile are engaged, Veil's `paramPatch` is layered
    /// AFTER `applyQuickState` and BEFORE `userOverrides`, with split
    /// semantics — energy keys (`FilmtoneOpticalFilterCatalog.energyScaledKeys`)
    /// max-merge against the post-Quick base so Veil never *reduces* the
    /// Look's existing optical character (Veil profile values were authored
    /// against a reset baseline, so an absolute overwrite would knock down
    /// `lensSoftness` 0.095→0.08 and `rgbShift` 0.0032→0.0007 under Stone).
    /// Structural keys (thresholds / radii / hue / soft-knee) keep absolute
    /// overwrite so Veil's spatial shape still wins. User-facing
    /// `paramOverrides` (advanced panel edits) always land last as an
    /// absolute set — they win over both Look and Veil.
    static func resolved(
        presetName: String,
        strength: Double,
        lookSlug: String?,
        quickState: FilmtoneQuickState = .zero,
        opticalFilterProfileId: String? = nil,
        opticalFilterIntensity: Double = 1.0,
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
        let withVeil = applyVeilPatch(
            to: withQuick,
            profileId: opticalFilterProfileId,
            intensity: opticalFilterIntensity
        )
        // Drop overrides that already match the post-Veil base so a
        // saved Look that round-trips through Adjust without changing
        // anything does not pin redundant values into `paramOverrides`.
        // Mirrors iOS `paramOverrides.normalized(over: base+Quick)`; the
        // normalization base also includes the Veil layer so a
        // Veil-supplied value isn't redundantly pinned by an unmodified
        // paramOverrides patch when it round-trips through save/load.
        let normalized = paramOverrides.normalized(over: withVeil)
        return normalized.isEmpty
            ? withVeil
            : withVeil.applyingPatch(normalized)
    }

    /// Layer the Backlight Veil profile patch on top of a base set of
    /// resolved params (post-Quick). Energy keys max-merge against the
    /// base — `max(base[key], veil[key] * intensity)` — so a Look that
    /// already raised them above the Veil's authored value is preserved.
    /// Structural keys (`!energyScaledKeys`) keep absolute overwrite so
    /// the Veil's spatial shape (thresholds / radii / hue / softKnee)
    /// still defines how the bloom / halation / scatter resolves.
    /// Returns `base` unchanged when intensity ≤ 0 or the profile is nil.
    private static func applyVeilPatch(
        to base: FilmtonePhase0Params,
        profileId: String?,
        intensity: Double
    ) -> FilmtonePhase0Params {
        let clamped = clampStrength(intensity)
        guard clamped > 0,
              let profile = FilmtoneOpticalFilterCatalog.profile(for: profileId) else {
            return base
        }
        var next = base
        for (key, veilValue) in profile.paramPatch.values {
            if FilmtoneOpticalFilterCatalog.energyScaledKeys.contains(key) {
                let scaled = veilValue * clamped
                if scaled > next.value(for: key) {
                    next.setValue(scaled, for: key)
                }
            } else {
                next.setValue(veilValue, for: key)
            }
        }
        return next
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
            detailSoftness: mix(reset.detailSoftness, target.detailSoftness, t),
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
            shadowLatitude: mix(reset.shadowLatitude, target.shadowLatitude, t),
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
