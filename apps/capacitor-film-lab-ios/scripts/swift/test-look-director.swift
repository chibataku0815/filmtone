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
        try runUnknownDisplaySourceCase()
        try runLegacyDescriptorCase()
        try runPersistedRefreshCase()
        print("Look Director resolver tests passed")
    }

    // MARK: - Cases

    /// Night / practical-light source — shadow heavy with bright warm
    /// highlights. M1C rule: black-floor first. The director must NOT
    /// lift `fade`, must NOT lower `bloomThreshold`, must NOT add broad
    /// diffusion on night. Quality comes from the display-domain Stone cube,
    /// controlled contrast, color separation, and small localized
    /// bloom/halation tied to actual highlight coverage.
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

        // M1C anti-haze invariants: the resolver must not write the three
        // handles that produced milky veil on owner-side review.
        try expect(
            values["fade"] == nil,
            "night Stone must NOT emit fade (M2: no toe lift behind the Stone cube)"
        )
        try expect(
            values["bloomThreshold"] == nil,
            "night Stone must NOT lower bloomThreshold (catalog threshold stays)"
        )
        try expect(
            values["shadowTone"] == nil,
            "night Stone must not write shadowTone (split-tone color, not latitude)"
        )

        // M2 night invariant: printContrast is NOT the black-floor lever.
        // It uses a sigmoid that can lift the deepest shadows, so night only
        // gets a tiny guarded print floor.
        let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
        try expect(
            (values["printContrast"] ?? 0) < stonePrintBase + 0.05,
            "night Stone print curve must stay black-floor-safe, got \(values["printContrast"] ?? -1)"
        )
        // M2 floor: ordinary + night descriptors should already push
        // compression past the M1 floor (0.075 * scale) onto the new 0.105
        // * scale baseline.
        try expect(
            (values["compressionAmount"] ?? 0) > 0.10,
            "M2 night Stone must add a visible compression floor, got \(values["compressionAmount"] ?? -1)"
        )
        try expect(
            (values["contrast"] ?? 1.0) > 1.06,
            "M2 night Stone must lock the print shape with contrast, got \(values["contrast"] ?? -1)"
        )
        try expect(
            (values["saturation"] ?? 1.0) > 1.07,
            "M2 night Stone must restore color separation for practicals, got \(values["saturation"] ?? -1)"
        )

        // M2 glow: practical-light bloom / halation / chromatic spread must
        // visibly read against the bundled cube without lifting the toe or
        // washing daylight skies. The deltas are still gated on
        // highlightCoverage * practical confidence, so they remain LOCAL.
        let bloomBase = FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0]
        let bloomDelta = (values["bloomStrength"] ?? bloomBase) - bloomBase
        try expect(
            bloomDelta > 0.045 && bloomDelta < 0.085,
            "M2 night Stone bloom delta must be visible but localized, got \(bloomDelta)"
        )
        let halationBase = FilmtoneCreativePack01Patches.stonePatch.values["halationIntensity", default: 0]
        let halationDelta = (values["halationIntensity"] ?? halationBase) - halationBase
        try expect(
            halationDelta > 0.040 && halationDelta < 0.075,
            "M2 night Stone halation delta must be visible but localized, got \(halationDelta)"
        )
        let rgbShiftBase = FilmtoneCreativePack01Patches.stonePatch.values["rgbShift", default: 0]
        let rgbShiftDelta = (values["rgbShift"] ?? rgbShiftBase) - rgbShiftBase
        try expect(
            rgbShiftDelta > 0.0014 && rgbShiftDelta < 0.0028,
            "M2 night Stone rgbShift delta must add restrained optical edge color, got \(rgbShiftDelta)"
        )

        // Strongest anti-haze invariant: no broad diffusion adapter on
        // night material.
        let diffusionBase = FilmtoneCreativePack01Patches.stonePatch.values["diffusion", default: 0]
        let diffusionDelta = (values["diffusion"] ?? diffusionBase) - diffusionBase
        try expect(
            diffusionDelta < 0.005,
            "night Stone diffusion delta must stay at baseline (no broad night diffuser), got \(diffusionDelta)"
        )

        try expect(
            resolved.intensity >= 0.8 && resolved.intensity <= 1.0,
            "night Stone intensity clamped to plausible range, got \(resolved.intensity)"
        )

        // Urban should follow the same practical-light direction with a
        // visible optical response, while remaining below Stone's flagship
        // delta because its global Look scale stays at 0.7x.
        guard let urban = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-urban",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        ) else {
            throw LookDirectorCheckError(message: "Urban night returned nil")
        }
        try expect(
            urban.paramOverrides.values["fade"] == nil,
            "Urban night must NOT emit fade either"
        )
        try expect(
            urban.paramOverrides.values["bloomThreshold"] == nil,
            "Urban night must NOT lower bloomThreshold either"
        )
        let urbanBloomBase = FilmtoneCreativePack01Patches.urbanPatch.values["bloomStrength", default: 0]
        let urbanBloom = (urban.paramOverrides.values["bloomStrength"] ?? urbanBloomBase) - urbanBloomBase
        try expect(
            urbanBloom > 0.030 && urbanBloom < bloomDelta,
            "M2 Urban bloom delta must be visible but below Stone (\(urbanBloom) vs \(bloomDelta))"
        )
        let urbanHalationBase = FilmtoneCreativePack01Patches.urbanPatch.values["halationIntensity", default: 0]
        let urbanHalation = (urban.paramOverrides.values["halationIntensity"] ?? urbanHalationBase) - urbanHalationBase
        try expect(
            urbanHalation > 0.025 && urbanHalation < halationDelta,
            "M2 Urban halation delta must be visible but below Stone (\(urbanHalation) vs \(halationDelta))"
        )
        let urbanRgbShiftBase = FilmtoneCreativePack01Patches.urbanPatch.values["rgbShift", default: 0]
        let urbanRgbShift = (urban.paramOverrides.values["rgbShift"] ?? urbanRgbShiftBase) - urbanRgbShiftBase
        try expect(
            urbanRgbShift > 0.0010 && urbanRgbShift < rgbShiftDelta,
            "M2 Urban rgbShift delta must be visible but below Stone (\(urbanRgbShift) vs \(rgbShiftDelta))"
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
        try expect(
            noir.paramOverrides.values["fade"] == nil,
            "Noir night must NOT emit fade"
        )
    }

    /// High-key source — bright, sustained highlights, few shadows.
    /// Rec.709-safe resolver should still compress highlights, but hold the
    /// knee and print density below the Log/profile branch.
    static func runHighKeyCase() throws {
        let descriptor = highKeyDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0,
            sourceColorClassRaw: "sdr-bt709"
        ) else {
            throw LookDirectorCheckError(message: "Stone high-key returned nil")
        }
        let values = resolved.paramOverrides.values
        try expect(
            (values["compressionAmount"] ?? 0) <= 0.30,
            "Rec.709 high-key Stone compression must stay capped, got \(values["compressionAmount"] ?? -1)"
        )
        try expect(
            (values["compressionRange"] ?? 0) >= 0.36,
            "Rec.709 high-key Stone must not pull the knee below 0.36, got \(values["compressionRange"] ?? -1)"
        )
        let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
        try expect(
            (values["printContrast"] ?? 0) <= stonePrintBase + 0.12 + 1e-9,
            "Rec.709 high-key Stone print density must stay capped, got \(values["printContrast"] ?? -1)"
        )
        try expect(
            (values["contrast"] ?? 1.0) <= 1.10,
            "Rec.709 high-key Stone contrast must stay capped, got \(values["contrast"] ?? -1)"
        )
        try expect(
            values["fade"] == nil,
            "high-key Stone must not raise fade — shadow latitude only applies to shadow-heavy material"
        )
        try expect(
            values["shadowTone"] == nil,
            "high-key Stone must not write shadowTone (density-dependent color cast, not a latitude handle)"
        )
        // M1C: the practical-glow gate must zero bloom and halation on
        // strongly high-key material so a daylight sky cannot blow into
        // the bloom band.
        try expect(
            values["bloomStrength"] == nil,
            "high-key Stone must NOT lift bloom (sky-wash guard), got \(values["bloomStrength"] ?? -1)"
        )
        try expect(
            values["halationIntensity"] == nil,
            "high-key Stone must NOT lift halation either, got \(values["halationIntensity"] ?? -1)"
        )
        try expect(
            values["rgbShift"] == nil,
            "high-key Stone must NOT lift rgbShift either, got \(values["rgbShift"] ?? -1)"
        )
    }

    /// Rec.709 low-saturation flat material — do not treat display-referred
    /// flatness as Log latitude. Keep tone/color additions inside safe caps.
    static func runLowSaturationCase() throws {
        let descriptor = lowSaturationDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0,
            sourceColorClassRaw: "sdr-bt709"
        ) else {
            throw LookDirectorCheckError(message: "Stone low-sat returned nil")
        }
        try expect(
            resolved.intensity <= FilmtoneLookDirector.rec709SafeIntensityCeiling(slug: "filmtone-creative-pack-01-stone") + 1e-9,
            "Rec.709 low-sat Stone intensity must use the safe ceiling, got \(resolved.intensity)"
        )
        let values = resolved.paramOverrides.values
        try expect(
            (values["compressionAmount"] ?? 0) <= 0.22,
            "Rec.709 low-sat Stone compression must stay capped, got \(values["compressionAmount"] ?? -1)"
        )
        let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
        try expect(
            (values["printContrast"] ?? 0) <= stonePrintBase + 0.12 + 1e-9,
            "Rec.709 low-sat Stone print density must stay capped, got \(values["printContrast"] ?? -1)"
        )
        try expect(
            (values["saturation"] ?? 1.0) <= 1.08,
            "Rec.709 low-sat Stone saturation restore must stay capped, got \(values["saturation"] ?? -1)"
        )
        try expect(
            (values["contrast"] ?? 1.0) <= 1.10,
            "Rec.709 low-sat Stone contrast must stay capped, got \(values["contrast"] ?? -1)"
        )
        let diffusionBase = FilmtoneCreativePack01Patches.stonePatch.values["diffusion", default: 0]
        let diffusionDelta = (values["diffusion"] ?? diffusionBase) - diffusionBase
        try expect(
            diffusionDelta <= 0.012 + 1e-9,
            "Rec.709 low-sat Stone diffusion delta must stay capped, got \(diffusionDelta)"
        )
        let bloomBase = FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0]
        let bloomDelta = (values["bloomStrength"] ?? bloomBase) - bloomBase
        try expect(
            bloomDelta < 0.015,
            "low-sat Stone bloom must stay tiny — no practical lights in scene, got \(bloomDelta)"
        )
        try expect(
            values["fade"] == nil,
            "low-sat Stone must not write fade either"
        )
    }

    /// Log / profile material — descriptor flags low-sat-flat too but
    /// explicit sourceProfileId promotes confidence. Director should
    /// hold off on detailSoftness because sourceDetailBias already adds
    /// it via the export pipeline.
    static func runLogProfileCase() throws {
        let descriptor = lowSaturationDescriptor(withDigitalHardness: 0.5)
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
            (values["compressionAmount"] ?? 0) > 0.36,
            "M2 log Stone must add strong compression, got \(values["compressionAmount"] ?? -1)"
        )
        let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
        try expect(
            (values["printContrast"] ?? 0) > stonePrintBase + 0.28,
            "M2 log Stone must add visible print density, got \(values["printContrast"] ?? -1)"
        )
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
    /// no hardness. Director has a small visible floor so the built-in
    /// Look never feels unchanged, but it must stay far below the three
    /// representative source-specific moves.
    static func runOrdinaryCase() throws {
        let descriptor = ordinaryDescriptor()
        let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0,
            sourceColorClassRaw: "sdr-bt709"
        )
        if let resolved {
            let values = resolved.paramOverrides.values
            try expect(
                abs(resolved.intensity - FilmtoneLookDirector.rec709SafeIntensityCeiling(slug: "filmtone-creative-pack-01-stone")) < 1e-9,
                "ordinary Rec.709 Stone intensity uses the safe ceiling, got \(resolved.intensity)"
            )
            // M2: ordinary now hits the new 0.105 * scale floor plus tiny
            // descriptor terms. Stay clearly below the high-key / low-sat /
            // log bands (> 0.36) so the Look still tells those scenes apart.
            try expect(
                (values["compressionAmount"] ?? 0) < 0.22,
                "ordinary Stone compression floor must stay below source-specific band, got \(values["compressionAmount"] ?? -1)"
            )
            let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
            try expect(
                (values["printContrast"] ?? stonePrintBase) < stonePrintBase + 0.12,
                "ordinary Stone print floor must stay below source-specific band, got \(values["printContrast"] ?? -1)"
            )
        let stoneBloomBase = FilmtoneCreativePack01Patches.stonePatch.values["bloomStrength", default: 0]
        try expect(
                (values["bloomStrength"] ?? stoneBloomBase) < stoneBloomBase + 0.035,
                "ordinary Stone bloom floor must stay restrained, got \(values["bloomStrength"] ?? -1)"
        )
            try expect(
                values["fade"] == nil,
                "ordinary Stone must not emit fade either"
            )
        }
    }

    /// Unknown / display-referred sources should be conservative. Display P3 SDR
    /// and missing metadata arrive through the same non-Log fallback.
    static func runUnknownDisplaySourceCase() throws {
        let descriptor = lowSaturationDescriptor()
        guard let resolved = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0,
            sourceColorClassRaw: "unknown"
        ) else {
            throw LookDirectorCheckError(message: "Stone unknown display source returned nil")
        }
        let values = resolved.paramOverrides.values
        try expect(
            abs(resolved.intensity - FilmtoneLookDirector.rec709SafeIntensityCeiling(slug: "filmtone-creative-pack-01-stone")) < 1e-9,
            "unknown display Stone intensity must use the Rec.709-safe ceiling, got \(resolved.intensity)"
        )
        try expect(
            (values["compressionAmount"] ?? 0) <= 0.22,
            "unknown display Stone compression must stay in the safe branch, got \(values["compressionAmount"] ?? -1)"
        )
        try expect(
            (values["compressionRange"] ?? 0) >= 0.36,
            "unknown display Stone compression range must stay in the safe branch, got \(values["compressionRange"] ?? -1)"
        )
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
            try expect(
                resolved.paramOverrides.values["fade"] == nil,
                "legacy descriptor must not write fade"
            )
        }
    }

    /// M1C persisted refresh case — simulates a project saved from an
    /// earlier (M1A-strong) install whose paramOverrides carry strong
    /// overlay values AND stale non-overlay baseline values. The merged
    /// result must reset everything Pack 01 to the current catalog +
    /// adaptation, while passing through unrelated keys.
    static func runPersistedRefreshCase() throws {
        let descriptor = nightDescriptor()
        let adaptation = FilmtoneLookDirector.resolveCreativePack01(
            slug: "filmtone-creative-pack-01-stone",
            descriptor: descriptor,
            sourceProfileId: nil,
            sourceDetailBias: 0
        )
        let staleM1AStrong: [String: Double] = [
            // Old overlay values that M1C night adaptation does NOT emit.
            "fade": 0.09,
            "diffusion": 0.12,
            "bloomThreshold": 0.55,
            // Old overlay-but-M1C-emits values — adaptation must overwrite,
            // not the stale persisted value.
            "bloomStrength": 0.45,
            "halationIntensity": 0.21,
            "printContrast": 0.075,
            "rgbShift": 0.0048,
            // Old non-overlay baseline values (no overlay key for these,
            // so the M1A-strong → M1B install never refreshed them).
            "grainIntensity": 0.019,
            "lensSoftness": 0.15,
            // Junk that should survive the merge untouched.
            "customUnknownKey": 0.7,
        ]
        guard let merged = FilmtoneCreativePack01Patches.refreshedParamOverrides(
            existing: staleM1AStrong,
            slug: "filmtone-creative-pack-01-stone",
            adaptation: adaptation
        ) else {
            throw LookDirectorCheckError(message: "refreshedParamOverrides returned nil for stone slug")
        }

        let stoneBaseline = FilmtoneCreativePack01Patches.stonePatch.values

        // Non-overlay baseline keys: must reset to the current Stone catalog.
        try expect(
            abs((merged["grainIntensity"] ?? -1) - stoneBaseline["grainIntensity", default: -2]) < 1e-9,
            "persisted refresh must reset grainIntensity to Stone baseline, got \(merged["grainIntensity"] ?? -1)"
        )
        try expect(
            abs((merged["lensSoftness"] ?? -1) - stoneBaseline["lensSoftness", default: -2]) < 1e-9,
            "persisted refresh must reset lensSoftness to Stone baseline, got \(merged["lensSoftness"] ?? -1)"
        )

        // Overlay keys that night adaptation does NOT emit must revert to baseline.
        try expect(
            abs(merged["fade"] ?? -1) < 1e-9,
            "persisted refresh must clear stale fade overlay, got \(merged["fade"] ?? -1)"
        )
        try expect(
            abs((merged["diffusion"] ?? -1) - stoneBaseline["diffusion", default: -2]) < 1e-9,
            "persisted refresh must reset diffusion to baseline (no broad night diffuser), got \(merged["diffusion"] ?? -1)"
        )
        try expect(
            abs((merged["bloomThreshold"] ?? -1) - stoneBaseline["bloomThreshold", default: -2]) < 1e-9,
            "persisted refresh must reset bloomThreshold to baseline (catalog never lowers it), got \(merged["bloomThreshold"] ?? -1)"
        )

        // Overlay keys night DOES emit must reflect the resolver value,
        // not the stale persisted value.
        let stonePrintBase = FilmtoneCreativePack01Patches.stonePatch.values["printContrast", default: 0]
        try expect(
            (merged["printContrast"] ?? 0) < stonePrintBase + 0.04,
            "persisted refresh must apply guarded M2 night print curve, got \(merged["printContrast"] ?? -1)"
        )
        try expect(
            (merged["bloomStrength"] ?? 0) < 0.25,
            "persisted refresh must wipe stale strong bloom overlay, got \(merged["bloomStrength"] ?? -1)"
        )
        try expect(
            (merged["halationIntensity"] ?? 0) < 0.15,
            "persisted refresh must wipe stale strong halation overlay, got \(merged["halationIntensity"] ?? -1)"
        )
        let rgbShiftBase = FilmtoneCreativePack01Patches.stonePatch.values["rgbShift", default: 0]
        try expect(
            (merged["rgbShift"] ?? 0) > rgbShiftBase &&
                (merged["rgbShift"] ?? 0) < rgbShiftBase + 0.0028,
            "persisted refresh must apply restrained M2 rgbShift overlay, got \(merged["rgbShift"] ?? -1)"
        )

        // Unrelated keys must pass through untouched.
        try expect(
            merged["customUnknownKey"] == 0.7,
            "persisted refresh must not drop unrelated values"
        )
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
