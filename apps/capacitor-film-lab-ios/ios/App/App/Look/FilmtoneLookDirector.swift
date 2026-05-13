import FilmLabSwiftCore
import Foundation

/// M1 Max Quality Look Director — turns Creative Pack 01 built-in Looks
/// into source-aware adaptations so that night / high-key / Log / digital
/// material each receive a tuned LUT intensity plus optical and tonal
/// adjustments. The director is intentionally biased toward stronger,
/// visible image moves. Performance cost is visible through the export
/// sidecar profiler; preview uses the existing scale/proxy path.
///
/// The director does not own descriptor extraction — `SourceProbeService`
/// fills the optional score fields. Missing scores fall through to
/// neutral, no-adaptation behavior.
enum FilmtoneLookDirector {

    /// Per-Look weighting profile. Stone is the flagship and gets the
    /// fullest range. Urban runs at ~0.7x to keep its cooler palette
    /// clean. Noir keeps optics light because the bundled cube already
    /// carries toned print structure.
    struct LookWeights {
        let scale: Double
        let nightOpticsScale: Double
        let nightFadeBoost: Double
        let highKeyCompressionGain: Double
        let logFlatLutGain: Double
        let logFlatCompression: Double
        let digitalSoftnessGain: Double
        let vignetteGain: Double
    }

    private static let stoneWeights = LookWeights(
        scale: 1.0,
        nightOpticsScale: 1.0,
        nightFadeBoost: 0.09,
        highKeyCompressionGain: 0.16,
        logFlatLutGain: 0.10,
        logFlatCompression: 0.18,
        digitalSoftnessGain: 0.16,
        vignetteGain: 0.05
    )

    private static let urbanWeights = LookWeights(
        scale: 0.7,
        nightOpticsScale: 0.7,
        nightFadeBoost: 0.07,
        highKeyCompressionGain: 0.12,
        logFlatLutGain: 0.08,
        logFlatCompression: 0.14,
        digitalSoftnessGain: 0.13,
        vignetteGain: 0.04
    )

    private static let noirWeights = LookWeights(
        scale: 0.55,
        nightOpticsScale: 0.45,
        nightFadeBoost: 0.04,
        highKeyCompressionGain: 0.10,
        logFlatLutGain: 0.0,
        logFlatCompression: 0.10,
        digitalSoftnessGain: 0.08,
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

        // Intensity — start at base of the bundled cube (1.0) and lean
        // toward higher intensity on neutral / log material that needs
        // the LUT to do real grading work. Night material keeps the
        // headline intensity at base so practical highlights are not
        // over-saturated.
        var intensity = 1.0
        if slug != "filmtone-creative-pack-01-noir" {
            // Lift LUT intensity on flat material so the Look actually
            // bites. Capped so we never clip the bundled cube domain.
            intensity = min(1.0, 1.0 + weights.logFlatLutGain * lowSatFlat)
            // Slightly bias up on bright high-key shots where a small
            // intensity bump strengthens the print response without
            // crushing highlights — the cube already has a soft shoulder.
            intensity = min(1.0, intensity + 0.04 * highKey)
            // Pull intensity back when night practical lights dominate
            // so the warm signage retains color richness rather than
            // racing toward saturated clip.
            intensity = max(0.82, intensity - 0.10 * night)
        } else {
            // Noir intensity stays mostly at 1.0 — the toned print cube
            // is the Look. Pull back slightly on night so high contrast
            // signage does not lose halation transition.
            intensity = max(0.9, 1.0 - 0.08 * night)
        }

        // Build the overlay patch — only keys we actually touch are
        // emitted. The bundled catalog patches stay unchanged for keys
        // we do not override.
        var values: [String: Double] = [:]

        // Compression / shadow latitude — main tonal handles.
        let compressionAdd =
            weights.highKeyCompressionGain * highKey +
            weights.logFlatCompression * lowSatFlat
        if compressionAdd > 0.005 {
            values["compressionAmount"] = clamp(0.0, 0.55, compressionAdd)
            // Pull the compression knee earlier when material is flat so
            // the compression effect reaches mid tones instead of only
            // highlights. Range default is 0.5; smaller value lowers the
            // knee.
            let kneeShift = -0.18 * lowSatFlat - 0.06 * highKey
            values["compressionRange"] = clamp(0.25, 0.6, 0.5 + kneeShift)
        }

        // Shadow latitude — raise the curve toe on shadow-heavy material so
        // detail breathes without lifting highlight punch. `fade` is the
        // density-curve handle here: its baseGradeV2 kernel applies
        // `shadowFadeMask * fade * (1 - color) * 0.6`, a shadow-only mask
        // that decays smoothly above 0.4 luma. shadowTone is intentionally
        // not touched — that key is the density-dependent split-tone color
        // cast (shadowChroma direction from shadowHue), not a latitude
        // handle, and using it for "open shadows on night material" would
        // tip the shadow chroma direction instead of giving the toe
        // headroom. Capped at 0.10 so it never reads as a matte/wash.
        let fadeAdd =
            weights.nightFadeBoost * max(night, shadowCoverage * 0.6)
        if fadeAdd > 0.005 {
            let baselineFade = catalogValue(slug: slug, key: "fade")
            values["fade"] = clamp(0.0, 0.10, baselineFade + fadeAdd)
        }

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

        // Glow family — bloom / halation / diffusion. Push these for
        // night practical-light material; mild on high-key to avoid
        // halation washout on pale skies.
        let opticsScale = weights.nightOpticsScale * weights.scale
        let bloomAdd = 0.10 * night * opticsScale + 0.03 * highlightCoverage * opticsScale
        let halationAdd = 0.04 * night * opticsScale
        let diffusionAdd = 0.05 * night * opticsScale + 0.02 * lowSatFlat * opticsScale
        if bloomAdd > 0.005 {
            // Build on top of the catalog values rather than overwriting
            // them — return the overlay only. Editor / capture relay
            // merge by replacing the key, so we must read the catalog
            // baseline.
            values["bloomStrength"] = clamp(0.0, 0.55,
                catalogValue(slug: slug, key: "bloomStrength") + bloomAdd
            )
            // Lower threshold slightly so practical highlights sit
            // inside the bloom band.
            values["bloomThreshold"] = clamp(0.4, 0.85,
                catalogValue(slug: slug, key: "bloomThreshold") - 0.04 * night
            )
        }
        if halationAdd > 0.005 {
            values["halationIntensity"] = clamp(0.0, 0.22,
                catalogValue(slug: slug, key: "halationIntensity") + halationAdd
            )
        }
        if diffusionAdd > 0.005 {
            values["diffusion"] = clamp(0.0, 0.30,
                catalogValue(slug: slug, key: "diffusion") + diffusionAdd
            )
        }

        // Vignette — only deepen on night frames with strong shadow
        // coverage. Skip on Noir (catalog already at 0.16) and Urban /
        // Stone keep the catalog default unless night is dominant.
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
