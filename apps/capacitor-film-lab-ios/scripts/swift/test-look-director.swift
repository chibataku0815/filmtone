import FilmLabSwiftCore
import Foundation

struct LookDirectorCheckError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw LookDirectorCheckError(message: message)
    }
}

@main
struct TestLookDirector {
    static func main() throws {
        try runNightCase()
        try runHighKeyCase()
        try runLowSaturationCase()
        try runLogProfileCase()
        try runOrdinaryCase()
        try runLegacyDescriptorCase()
        print("Look Director resolver tests passed")
    }

    // MARK: - Cases

    /// Night / practical-light source — shadow heavy with bright warm
    /// highlights. Stone should keep LUT intensity high enough to bite,
    /// push glow optics, and add shadow latitude.
    static func runNightCase() throws {
        let descriptor = nightDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Stone night returned nil")
        }
        let values = resolved.paramOverrides.values
        // M1 fix: shadow latitude is the `fade` toe-lift, not the
        // density-dependent `shadowTone` color cast. Director must raise
        // fade on night/shadow-heavy material and must NOT write
        // shadowTone (that would tip shadow chroma direction, not
        // latitude).
        try expect(
            (values["fade"] ?? 0) > 0.02,
            "night Stone must raise fade for shadow latitude, got \(values["fade"] ?? -1)"
        )
        try expect(
            values["shadowTone"] == nil,
            "night Stone must not write shadowTone (split-tone color, not latitude)"
        )
        try expect(
            (values["bloomStrength"] ?? 0) > FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0],
            "night Stone must lift bloomStrength over catalog baseline"
        )
        try expect(
            (values["halationIntensity"] ?? 0) > FilmtoneCreativePack01Patches.stonePatch.values["halationIntensity", default: 0],
            "night Stone must lift halationIntensity over catalog baseline"
        )
        try expect(
            (values["diffusion"] ?? 0) > FilmtoneCreativePack01Patches.stonePatch.values["diffusion", default: 0],
            "night Stone must lift diffusion over catalog baseline"
        )
        try expect(
            resolved.intensity >= 0.8 && resolved.intensity <= 1.0,
            "night Stone intensity clamped to plausible range, got \(resolved.intensity)"
        )

        // Urban should follow same direction but with smaller delta than
        // Stone because its weights scale at 0.7x.
        guard let urban = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-urban",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Urban night returned nil")
        }
        let urbanBloom = (urban.paramOverrides.values["bloomStrength"] ?? 0)
            - FilmtoneCreativePack01Patches.urbanPatch.values["bloomStrength", default: 0]
        let stoneBloom = (values["bloomStrength"] ?? 0)
            - FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0]
        try expect(
            urbanBloom < stoneBloom + 1e-6,
            "Urban bloom delta must not exceed Stone (\(urbanBloom) vs \(stoneBloom))"
        )

        // Noir vignette must not be raised — catalog already deep.
        guard let noir = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-noir",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Noir night returned nil")
        }
        try expect(
            noir.paramOverrides.values["vignette"] == nil,
            "Noir must not emit vignette override on night material"
        )
    }

    /// High-key source — bright, sustained highlights, few shadows.
    /// Resolver should compress highlights and avoid lifting bloom.
    static func runHighKeyCase() throws {
        let descriptor = highKeyDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Stone high-key returned nil")
        }
        let values = resolved.paramOverrides.values
        try expect(
            (values["compressionAmount"] ?? 0) > 0.05,
            "high-key Stone must add compressionAmount"
        )
        try expect(
            values["fade"] == nil,
            "high-key Stone must not raise fade — shadow latitude only applies to shadow-heavy material"
        )
        try expect(
            values["shadowTone"] == nil,
            "high-key Stone must not write shadowTone (density-dependent color cast, not a latitude handle)"
        )
        // bloomStrength might still get a small lift from highlight
        // coverage, but never above the catalog + 0.05 ceiling.
        let baseBloom = FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0]
        let bloomDelta = (values["bloomStrength"] ?? baseBloom) - baseBloom
        try expect(
            bloomDelta < 0.05,
            "high-key Stone bloom delta stays small, got \(bloomDelta)"
        )
    }

    /// Low-saturation flat material that did not match a profile id.
    /// Director should bump LUT intensity and add compression. No glow.
    static func runLowSaturationCase() throws {
        let descriptor = lowSaturationDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Stone low-sat returned nil")
        }
        try expect(
            resolved.intensity >= 1.0 - 1e-9,
            "low-sat Stone intensity should reach 1.0, got \(resolved.intensity)"
        )
        let values = resolved.paramOverrides.values
        try expect(
            (values["compressionAmount"] ?? 0) > 0.05,
            "low-sat Stone must add compression to give the flat frame shape"
        )
        try expect(
            (values["bloomStrength"] ?? 0) <= FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0] + 1e-9,
            "low-sat Stone must not lift bloom — no practical lights in scene"
        )
    }

    /// Log / profile material — descriptor flags low-sat-flat too but
    /// explicit sourceProfileId promotes confidence. Director should
    /// hold off on detailSoftness because sourceDetailBias already adds
    /// it via the export pipeline.
    static func runLogProfileCase() throws {
        let descriptor = lowSaturationDescriptor(withDigitalHardness: 0.5)
        // sourceDetailBias 0.06 is the Apple Log bias.
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: "built-in:source-profile.apple-log",
            sourceDetailBias: 0.06
        ) else {
            throw LookDirectorCheckError(message: "Stone log returned nil")
        }
        let values = resolved.paramOverrides.values
        try expect(
            (values["compressionAmount"] ?? 0) > 0.05,
            "log Stone must add compression"
        )
        // detailSoftness should be smaller than non-log case for the
        // same digital hardness, because bias pulls it back.
        guard let nonLog = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "non-log baseline returned nil")
        }
        let logSoftness = values["detailSoftness"] ?? 0
        let nonLogSoftness = nonLog.paramOverrides.values["detailSoftness"] ?? 0
        try expect(
            logSoftness <= nonLogSoftness + 1e-9,
            "Log Stone detail softness (\(logSoftness)) must not exceed non-log (\(nonLogSoftness))"
        )
    }

    /// Ordinary mid-range material — moderate luma, modest saturation,
    /// no hardness. Director should make no aggressive moves; intensity
    /// stays near 1.0 and the overlay can be empty (nil resolution).
    static func runOrdinaryCase() throws {
        let descriptor = ordinaryDescriptor()
        let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        )
        // Either nil (no adaptation) or only tiny overlays are acceptable.
        if let resolved {
            let values = resolved.paramOverrides.values
            try expect(
                abs(resolved.intensity - 1.0) < 0.05,
                "ordinary Stone intensity stays near 1.0, got \(resolved.intensity)"
            )
            for (key, value) in values {
                if key == "compressionAmount" || key == "compressionRange" {
                    continue
                }
                let baseline = FilmtoneCreativePack01Patches.stonePatch.values[key, default: 0]
                try expect(
                    abs(value - baseline) < 0.05,
                    "ordinary Stone must not move \(key) far from baseline (got \(value), baseline \(baseline))"
                )
            }
        }
    }

    /// Legacy descriptor with no optional scores — resolver should
    /// gracefully treat scores as zero and return either nil or a tiny
    /// overlay.
    static func runLegacyDescriptorCase() throws {
        let descriptor = FilmtoneSourceToneDescriptor(
            lumaP05: 0.18,
            lumaP50: 0.4,
            lumaP95: 0.78,
            lumaRangeP05P95: 0.6,
            shadowCoverage: 0.10,
            highlightCoverage: 0.10,
            lowMidCoverage: 0.25,
            saturationMean: 0.4
        )
        _ = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        )
        // Acceptable for the legacy path: either nil or a small overlay
        // with no detailSoftness / bloom moves. We only assert it does
        // not crash and does not raise vignette wildly.
        if let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) {
            let baseline = FilmtoneCreativePack01Patches.stonePatch.values["vignette", default: 0]
            let v = resolved.paramOverrides.values["vignette"] ?? baseline
            try expect(
                v <= baseline + 0.05,
                "legacy descriptor must not raise vignette aggressively"
            )
        }
    }

    // MARK: - Descriptors

    static func nightDescriptor() -> FilmtoneSourceToneDescriptor {
        FilmtoneSourceToneDescriptor(
            lumaP05: 0.02,
            lumaP50: 0.12,
            lumaP95: 0.88,
            lumaRangeP05P95: 0.86,
            shadowCoverage: 0.60,
            highlightCoverage: 0.08,
            lowMidCoverage: 0.72,
            saturationMean: 0.42,
            nightPracticalScore: 0.85,
            highKeyScore: 0.05,
            lowSaturationFlatScore: 0.10,
            digitalHardnessScore: 0.35
        )
    }

    static func highKeyDescriptor() -> FilmtoneSourceToneDescriptor {
        FilmtoneSourceToneDescriptor(
            lumaP05: 0.30,
            lumaP50: 0.72,
            lumaP95: 0.96,
            lumaRangeP05P95: 0.66,
            shadowCoverage: 0.02,
            highlightCoverage: 0.42,
            lowMidCoverage: 0.04,
            saturationMean: 0.28,
            nightPracticalScore: 0.0,
            highKeyScore: 0.85,
            lowSaturationFlatScore: 0.10,
            digitalHardnessScore: 0.20
        )
    }

    static func lowSaturationDescriptor(withDigitalHardness hardness: Double = 0.20) -> FilmtoneSourceToneDescriptor {
        FilmtoneSourceToneDescriptor(
            lumaP05: 0.32,
            lumaP50: 0.48,
            lumaP95: 0.62,
            lumaRangeP05P95: 0.30,
            shadowCoverage: 0.06,
            highlightCoverage: 0.04,
            lowMidCoverage: 0.10,
            saturationMean: 0.10,
            nightPracticalScore: 0.0,
            highKeyScore: 0.10,
            lowSaturationFlatScore: 0.85,
            digitalHardnessScore: hardness
        )
    }

    static func ordinaryDescriptor() -> FilmtoneSourceToneDescriptor {
        FilmtoneSourceToneDescriptor(
            lumaP05: 0.20,
            lumaP50: 0.46,
            lumaP95: 0.78,
            lumaRangeP05P95: 0.58,
            shadowCoverage: 0.10,
            highlightCoverage: 0.10,
            lowMidCoverage: 0.18,
            saturationMean: 0.38,
            nightPracticalScore: 0.05,
            highKeyScore: 0.10,
            lowSaturationFlatScore: 0.10,
            digitalHardnessScore: 0.05
        )
    }
}
