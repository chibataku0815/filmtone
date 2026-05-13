import FilmLabSwiftCore
import Foundation

/// M1 Max Quality Look Director — turns Creative Pack 01 built-in Looks
/// into source-aware adaptations. The director is biased toward stronger,
/// visible image moves, but the M1C pivot fixes a product regression from
/// M1A/M1B: on owner-side review, night/practical material went gray and
/// milky because the director was lifting `fade`, lowering `bloomThreshold`,
/// and adding broad diffusion on night. Those handles read as global haze,
/// not film signature. M1C removes them and instead drives night quality
/// through display-domain cube color, controlled contrast, color separation, and
/// localized practical-light glow that is gated against high-key scenes so
/// it never washes a daylight sky.
///
/// The director does not own descriptor extraction — `SourceProbeService`
/// fills the optional score fields. Missing scores fall through to
/// neutral, no-adaptation behavior.
enum FilmtoneLookDirector {

    /// Per-Look weighting profile. Stone is the flagship and gets the
    /// fullest range. Urban keeps its cooler palette but still receives
    /// a visible practical-light optical response. Noir keeps optics
    /// light because the bundled cube already carries toned print
    /// structure.
    struct LookWeights {
        let scale: Double
        let nightOpticsScale: Double
        let highKeyCompressionGain: Double
        let logFlatCompression: Double
        let highKeyPrintGain: Double
        let logFlatPrintGain: Double
        let contrastGain: Double
        let saturationGain: Double
        let digitalSoftnessGain: Double
        let practicalBloomGain: Double
        let practicalHalationGain: Double
        let practicalRgbShiftGain: Double
        let vignetteGain: Double
    }

    // M2 tuning pass: Stone reads as a flagship Look on first frame and
    // night/practical material gets visible (not just measurable) bloom /
    // halation / chromatic spread without lifting the toe or washing
    // daylight skies. Anti-haze invariants from M1C still hold.
    private static let stoneWeights = LookWeights(
        scale: 1.0,
        nightOpticsScale: 1.0,
        highKeyCompressionGain: 0.48,
        logFlatCompression: 0.44,
        highKeyPrintGain: 0.28,
        logFlatPrintGain: 0.36,
        contrastGain: 0.17,
        saturationGain: 0.23,
        digitalSoftnessGain: 0.30,
        practicalBloomGain: 1.05,
        practicalHalationGain: 0.92,
        practicalRgbShiftGain: 0.036,
        vignetteGain: 0.11
    )

    // M2 tuning pass: Urban's cooler character carries more density and
    // sat-restore weight, and the practical-light optical response is
    // raised. Effective delta stays below Stone because the global 0.7x
    // scale plus a slightly reduced nightOpticsScale clamp the magnitude.
    private static let urbanWeights = LookWeights(
        scale: 0.7,
        nightOpticsScale: 0.85,
        highKeyCompressionGain: 0.34,
        logFlatCompression: 0.32,
        highKeyPrintGain: 0.20,
        logFlatPrintGain: 0.26,
        contrastGain: 0.13,
        saturationGain: 0.17,
        digitalSoftnessGain: 0.24,
        practicalBloomGain: 1.00,
        practicalHalationGain: 0.86,
        practicalRgbShiftGain: 0.038,
        vignetteGain: 0.09
    )

    private static let noirWeights = LookWeights(
        scale: 0.55,
        nightOpticsScale: 0.45,
        highKeyCompressionGain: 0.22,
        logFlatCompression: 0.20,
        highKeyPrintGain: 0.13,
        logFlatPrintGain: 0.16,
        contrastGain: 0.06,
        saturationGain: 0.0,
        digitalSoftnessGain: 0.14,
        practicalBloomGain: 0.18,
        practicalHalationGain: 0.14,
        practicalRgbShiftGain: 0.0,
        vignetteGain: 0.0
    )

    /// Slug must match a Creative Pack 01 built-in. Returns nil for
    /// unknown slugs so the catalog keeps the static patch unmodified.
    static func resolveCreativePack01(
        slug: String,
        descriptor: FilmtoneSourceToneDescriptor?,
        sourceProfileId: String?,
        sourceDetailBias: Double?
    ) -> FilmtoneCreativePack01Adaptation.Resolved? {
        let weights: LookWeights
        switch slug {
        case "filmtone-creative-pack-01-stone":
            weights = stoneWeights
        case "filmtone-creative-pack-01-urban":
            weights = urbanWeights
        case "filmtone-creative-pack-01-noir":
            weights = noirWeights
        default:
            return nil
        }

        let descriptor = descriptor
        let night = clamp01(descriptor?.nightPracticalScore ?? 0)
        let highKey = clamp01(descriptor?.highKeyScore ?? 0)
        var lowSatFlat = clamp01(descriptor?.lowSaturationFlatScore ?? 0)
        let digitalHardness = clamp01(descriptor?.digitalHardnessScore ?? 0)
        let shadowCoverage = clamp01(descriptor?.shadowCoverage ?? 0)
        let highlightCoverage = clamp01(descriptor?.highlightCoverage ?? 0)
        let saturationMean = clamp01(descriptor?.saturationMean ?? 0)

        // Treat explicit Log / profile catalog ids as low-saturation-flat
        // confirmation. The descriptor heuristic alone can miss flat
        // material when a tone-mapping path already brightened the frame.
        let isLogProfile: Bool = {
            guard let id = sourceProfileId else { return false }
            return id.hasPrefix("built-in:source-profile.") &&
                id != "built-in:source-profile.rec709"
        }()
        if isLogProfile {
            lowSatFlat = max(lowSatFlat, 0.6)
        }

        // Intensity — the bundled cube already ships at the schema maximum
        // (1.0), so stronger high-key / Log moves come from post-cube
        // tone handles below. Pull intensity down on night material so
        // saturated practical lights do not clip the cube.
        var intensity = 1.0
        if slug != "filmtone-creative-pack-01-noir" {
            intensity = max(0.82, intensity - 0.10 * night)
        } else {
            intensity = max(0.9, 1.0 - 0.08 * night)
        }

        // Build the overlay patch — only keys we actually touch are
        // emitted. The bundled catalog patches stay unchanged for keys
        // we do not override.
        var values: [String: Double] = [:]

        // Compression — main highlight-rolloff handle. Night material gets
        // the floor only (its shadow-dominated tone curve does not need a
        // forced compression rate); high-key and Log/flat get the bigger
        // moves. The unconditional floor is intentional so ordinary clips
        // still read as a Look on the cube.
        let compressionAdd =
            weights.highKeyCompressionGain * highKey +
            weights.logFlatCompression * lowSatFlat +
            0.105 * weights.scale
        if compressionAdd > 0.005 {
            values["compressionAmount"] = clamp(0.0, 0.68, compressionAdd)
            // Pull the compression knee earlier on flat / high-key material
            // so compression reaches mid tones, not just highlights. Night
            // intentionally leaves the knee at default so the natural
            // shadow→highlight ramp keeps its contour.
            let kneeShift = -0.28 * lowSatFlat - 0.16 * highKey
            values["compressionRange"] = clamp(0.20, 0.6, 0.5 + kneeShift)
        }

        // Print curve — useful on high-key / Log material, but not a night
        // black-floor lever. The print-stage sigmoid lifts the deepest
        // shadows, so M2 removes the old night print boost that caused
        // Stone to drift gray even after `fade` was removed.
        let nightPrintGuard = 1.0 - 0.85 * night
        let printAdd =
            (
                weights.highKeyPrintGain * highKey +
                weights.logFlatPrintGain * lowSatFlat
            ) * nightPrintGuard +
            0.014 * weights.scale
        if printAdd > 0.005 {
            values["printContrast"] = clamp(0.0, 0.42,
                catalogValue(slug: slug, key: "printContrast") + printAdd
            )
        }

        // Contrast — keep the punch on flat or high-key material; on night,
        // a small contrast bump preserves shape without lifting the toe.
        let contrastAdd = weights.contrastGain * max(
            highKey * 0.8,
            lowSatFlat * 0.65,
            night * 0.5
        )
        if contrastAdd > 0.005 {
            values["contrast"] = clamp(1.0, 1.22,
                catalogValue(slug: slug, key: "contrast") + contrastAdd
            )
        }

        // Saturation — color separation. Low-sat flat gets the biggest
        // restore. Night needs a moderate lift so colored practicals
        // (sodium, neon, tungsten) keep their hue instead of smearing
        // toward the cube's neutral. Noir's saturationGain is zero by
        // design.
        let saturationAdd = weights.saturationGain * max(
            lowSatFlat,
            highKey * 0.35,
            night * 0.5
        )
        if saturationAdd > 0.005 {
            values["saturation"] = clamp(1.0, 1.24,
                catalogValue(slug: slug, key: "saturation") + saturationAdd
            )
        }

        // M1C: `fade` is intentionally NOT written by the resolver. The
        // baseGradeV2 kernel uses `fade` as a shadow-only toe-lift mask
        // (`shadowFadeMask * fade * (1 - color) * 0.6`). On owner-side
        // review the M1A-strong nightFadeBoost made shadows gray and the
        // overall image milky on night/practical material — the failure
        // mode of "lift the toe to give film latitude headroom." M1C
        // replaces that with contrast / saturation / localized glow. The
        // print curve is deliberately guarded above because it can lift the
        // deepest shadows. `shadowCoverage` is therefore unused in the
        // night path except for vignette below.
        _ = shadowCoverage

        // Detail softness — protect against digital hardness. Independent
        // of the export-pipeline `sourceDetailBias` (those add together
        // at the stage). On Log/flat material we hold off because the
        // profile bias is already doing the work.
        let bias = sourceDetailBias ?? 0
        let softnessAdd = weights.digitalSoftnessGain * digitalHardness *
            (lowSatFlat > 0.5 ? 0.5 : 1.0)
        let softnessAfterBias = max(0.0, softnessAdd - 0.4 * bias)
        if softnessAfterBias > 0.005 {
            values["detailSoftness"] = clamp(0.0, 0.25, softnessAfterBias)
        }

        // Glow family — bloom / halation. M1C rule: glow is a LOCAL
        // practical-light effect, not a night-wide diffuser. Drive bloom
        // and halation from `highlightCoverage` (the actual measured area
        // of bright pixels), then gate against `highKey` so a daylight sky
        // cannot blow into the bloom band. `bloomThreshold` is never
        // lowered: lowering it pulled midtones into the bloom kernel and
        // read as milky veil on the M1A/M1B owner-side review.
        let opticsScale = weights.nightOpticsScale * weights.scale
        // 0 at highKey ≥ 0.7, 1.0 at highKey ≤ 0.3, smooth linear in between.
        let practicalGlowGate = clamp01(1.0 - (highKey - 0.3) / 0.4)
        // M4: require measured highlight coverage, but let night/practical
        // confidence decide how much of that highlight area is allowed into
        // the optics path. This keeps ordinary highlights restrained and
        // makes lantern/neon sources visibly better without lowering the
        // bloom threshold or adding broad diffusion.
        let practicalAffinity = 0.25 + 0.75 * night
        let practicalGlowEnergy = highlightCoverage * practicalGlowGate * practicalAffinity
        let bloomAdd = weights.practicalBloomGain * practicalGlowEnergy * opticsScale
        let halationAdd = weights.practicalHalationGain * practicalGlowEnergy * opticsScale
        let rgbShiftAdd = weights.practicalRgbShiftGain * practicalGlowEnergy * opticsScale
        if bloomAdd > 0.005 {
            values["bloomStrength"] = clamp(0.0, 0.55,
                catalogValue(slug: slug, key: "bloomStrength") + bloomAdd
            )
        }
        if halationAdd > 0.005 {
            values["halationIntensity"] = clamp(0.0, 0.22,
                catalogValue(slug: slug, key: "halationIntensity") + halationAdd
            )
        }
        if rgbShiftAdd > 0.0004 {
            values["rgbShift"] = clamp(0.0, 0.0045,
                catalogValue(slug: slug, key: "rgbShift") + rgbShiftAdd
            )
        }

        // Diffusion — adapt only on Log/flat material so a milky-flat clip
        // gets a little surface texture beyond the catalog baseline. Night
        // intentionally does NOT add diffusion: a broad diffuser on a
        // shadow-heavy frame reads as fog, the exact M1A/M1B failure mode
        // M1C corrects.
        let diffusionAdd = 0.030 * lowSatFlat * opticsScale
        if diffusionAdd > 0.005 {
            values["diffusion"] = clamp(0.0, 0.28,
                catalogValue(slug: slug, key: "diffusion") + diffusionAdd
            )
        }

        // Vignette — only deepen on night frames with strong shadow
        // coverage. Vignette darkens corners, so it works WITH the
        // black-floor-first direction.
        let vignetteAdd = weights.vignetteGain *
            min(1.0, night * 0.7 + shadowCoverage * 0.3) *
            (saturationMean < 0.55 ? 1.0 : 0.6)
        if vignetteAdd > 0.005 && slug != "filmtone-creative-pack-01-noir" {
            values["vignette"] = clamp(0.0, 0.20,
                catalogValue(slug: slug, key: "vignette") + vignetteAdd
            )
        }

        if values.isEmpty && abs(intensity - 1.0) < 0.005 {
            return nil
        }

        return FilmtoneCreativePack01Adaptation.Resolved(
            intensity: intensity,
            paramOverrides: FilmtonePhase0ParamsPatch(values: values)
        )
    }

    // MARK: - Helpers

    private static func clamp(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        return max(lower, min(upper, value))
    }

    private static func clamp01(_ value: Double) -> Double {
        return max(0, min(1, value))
    }

    private static func catalogValue(slug: String, key: String) -> Double {
        let patch: FilmtonePhase0ParamsPatch
        switch slug {
        case "filmtone-creative-pack-01-stone":
            patch = FilmtoneCreativePack01Patches.stonePatch
        case "filmtone-creative-pack-01-urban":
            patch = FilmtoneCreativePack01Patches.urbanPatch
        case "filmtone-creative-pack-01-noir":
            patch = FilmtoneCreativePack01Patches.noirPatch
        default:
            return 0
        }
        return patch.values[key] ?? 0
    }
}
