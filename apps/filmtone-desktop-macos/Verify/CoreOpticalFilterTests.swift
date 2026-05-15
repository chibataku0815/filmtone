import FilmLabSwiftCore
import Foundation

func registerCoreOpticalFilterTests() {
    // Test group 15 — M5-K3 FilmtoneCompareSplitMath. Pins the boundary
    // behavior of the shared split-fraction helper so EditorState.didSet,
    // FilmtoneCompareCompose.makeSplit, and the AVPlayer composition handler
    // never silently drift on what counts as a valid compare position.
    // ---------------------------------------------------------------------------

    runner.test("FilmtoneCompareSplitMath default is 0.5") {
        try assertClose(FilmtoneCompareSplitMath.default, 0.5)
    }

    runner.test("FilmtoneCompareSplitMath range is 0...1 inclusive") {
        try assertClose(FilmtoneCompareSplitMath.range.lowerBound, 0.0)
        try assertClose(FilmtoneCompareSplitMath.range.upperBound, 1.0)
    }

    runner.test("FilmtoneCompareSplitMath.clamp identity inside range") {
        try assertClose(FilmtoneCompareSplitMath.clamp(0.0), 0.0)
        try assertClose(FilmtoneCompareSplitMath.clamp(0.25), 0.25)
        try assertClose(FilmtoneCompareSplitMath.clamp(0.5), 0.5)
        try assertClose(FilmtoneCompareSplitMath.clamp(0.75), 0.75)
        try assertClose(FilmtoneCompareSplitMath.clamp(1.0), 1.0)
    }

    runner.test("FilmtoneCompareSplitMath.clamp pulls out-of-range to bounds") {
        try assertClose(FilmtoneCompareSplitMath.clamp(-0.25), 0.0)
        try assertClose(FilmtoneCompareSplitMath.clamp(-1_000), 0.0)
        try assertClose(FilmtoneCompareSplitMath.clamp(1.25), 1.0)
        try assertClose(FilmtoneCompareSplitMath.clamp(1_000_000), 1.0)
    }

    runner.test("FilmtoneCompareSplitMath.clamp collapses non-finite to default") {
        try assertClose(FilmtoneCompareSplitMath.clamp(.nan), FilmtoneCompareSplitMath.default)
        try assertClose(FilmtoneCompareSplitMath.clamp(.infinity), FilmtoneCompareSplitMath.default)
        try assertClose(FilmtoneCompareSplitMath.clamp(-.infinity), FilmtoneCompareSplitMath.default)
    }

    // ---------------------------------------------------------------------------
    // Test group 16 — M5-M (CC-B) intensity cursor regression.
    // intensity == 1.0 must reproduce the M5-L3 chip-only patch byte-for-byte.
    // intensity == 0.0 must produce an empty patch contribution from the profile
    // (user overrides are unaffected). Monotonicity: increasing intensity from
    // 0 toward 1 must monotonically increase each profile key's magnitude.
    // ---------------------------------------------------------------------------

    runner.test("intensity 1.0 is byte-equivalent to M5-L3 chip-only patch") {
        for profile in FilmtoneOpticalFilterCatalog.profiles {
            // Chip-only path (M5-L3 backward-compat overload, intensity=1.0).
            let legacy = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                userOverrides: .empty
            )
            // New intensity-aware path at 1.0.
            let withIntensity = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                intensity: 1.0,
                userOverrides: .empty
            )
            for (key, legacyVal) in legacy.values {
                let intensityVal = withIntensity.values[key] ?? .nan
                try assertClose(
                    intensityVal, legacyVal,
                    "profile=\(profile.id) key=\(key): intensity=1.0 must equal chip-only"
                )
            }
            // No extra keys should appear at intensity=1.0.
            for key in withIntensity.values.keys {
                if legacy.values[key] == nil {
                    throw AssertionError(
                        description: "profile=\(profile.id): unexpected key '\(key)' at intensity=1.0"
                    )
                }
            }
        }
    }

    runner.test("intensity 0.0 produces empty profile contribution (no extra keys)") {
        for profile in FilmtoneOpticalFilterCatalog.profiles {
            let patch = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                intensity: 0.0,
                userOverrides: .empty
            )
            // All profile keys should be 0 (or absent) — user overrides are
            // empty, so no key from the catalog should survive at non-zero.
            for (key, val) in patch.values {
                // Profile patch keys multiplied by 0 → should all be 0.
                try assertClose(
                    val, 0.0,
                    "profile=\(profile.id) key=\(key): intensity=0.0 must zero profile contribution"
                )
            }
        }
    }

    runner.test("intensity userOverrides are not attenuated by intensity scalar") {
        // User overrides (advanced panel edits) must survive intensity=0.0
        // unchanged — they represent direct per-key edits, not Backlight Veil.
        let userOverrides = FilmtonePhase0ParamsPatch(values: [
            "exposure": 0.42,
            "bloomStrength": 0.75,
        ])
        let patch = FilmtoneOpticalFilterCatalog.renderParamOverrides(
            profileId: "backlightVeil-1-4",
            intensity: 0.0,
            userOverrides: userOverrides
        )
        try assertClose(patch.values["exposure"] ?? .nan, 0.42, "exposure override survives intensity=0")
        try assertClose(patch.values["bloomStrength"] ?? .nan, 0.75, "bloomStrength override survives intensity=0")
    }

    runner.test("intensity scales energy keys linearly; structural keys pass through verbatim") {
        // Energy keys are "how much" the effect emits — bloom / halation /
        // diffusion strengths, lensSoftness, rgbShift. These attenuate
        // linearly with intensity so 0.5 = half the energy.
        //
        // Structural keys are "where / what shape" — bloomThreshold,
        // bloomRadius, bloomSoftKnee, halationThreshold, halationRadius,
        // halationHue, halationSoftKnee. These pass through verbatim while
        // the profile is engaged (intensity > 0). Scaling them by intensity
        // would lower the bloom threshold at half intensity, making the veil
        // engage on darker pixels — i.e. *more* aggressive at 0.5 than 1.0.
        // The earlier `mapValues { $0 * intensity }` had that bug.
        let energyKeys: Set<String> = [
            "bloomStrength",
            "halationIntensity",
            "diffusion",
            "lensSoftness",
            "rgbShift",
        ]
        let structuralKeys: Set<String> = [
            "bloomThreshold",
            "bloomRadius",
            "bloomSoftKnee",
            "halationThreshold",
            "halationRadius",
            "halationHue",
            "halationSoftKnee",
        ]
        for profile in FilmtoneOpticalFilterCatalog.profiles {
            let at1 = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                intensity: 1.0,
                userOverrides: .empty
            )
            let at05 = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                intensity: 0.5,
                userOverrides: .empty
            )
            let at01 = FilmtoneOpticalFilterCatalog.renderParamOverrides(
                profileId: profile.id,
                intensity: 0.1,
                userOverrides: .empty
            )
            for (key, val1) in at1.values {
                let val05 = at05.values[key] ?? .nan
                let val01 = at01.values[key] ?? .nan
                if energyKeys.contains(key) {
                    try assertClose(
                        val05, val1 * 0.5,
                        "energy key \(key) on \(profile.id): expected 0.5*full at intensity=0.5"
                    )
                    try assertClose(
                        val01, val1 * 0.1,
                        "energy key \(key) on \(profile.id): expected 0.1*full at intensity=0.1"
                    )
                } else if structuralKeys.contains(key) {
                    try assertClose(
                        val05, val1,
                        "structural key \(key) on \(profile.id): must NOT scale with intensity (got \(val05) at 0.5, expected \(val1))"
                    )
                    try assertClose(
                        val01, val1,
                        "structural key \(key) on \(profile.id): must NOT scale with intensity (got \(val01) at 0.1, expected \(val1))"
                    )
                } else {
                    throw AssertionError(
                        description: "Unknown profile key \(key) — classify it in energyKeys or structuralKeys"
                    )
                }
            }
        }
    }

    runner.test("intensity does not pre-load thresholds (anti-regression for mapValues bug)") {
        // The pre-fix `mapValues { $0 * intensity }` made `bloomThreshold`
        // 0.28 at intensity=0.5 for the 1/4 profile (catalog 0.56). Lower
        // threshold means the veil engages on darker pixels — i.e. *more*
        // aggressive at half intensity than at full. This guard locks the
        // fix so the bug cannot come back through a future refactor.
        let half = FilmtoneOpticalFilterCatalog.renderParamOverrides(
            profileId: "backlightVeil-1-4",
            intensity: 0.5,
            userOverrides: .empty
        )
        guard let bloomThresholdHalf = half.values["bloomThreshold"] else {
            throw AssertionError(
                description: "bloomThreshold must be present in the patch at intensity=0.5"
            )
        }
        try assertClose(
            bloomThresholdHalf, 0.56,
            "bloomThreshold must pass through profile value 0.56 at intensity=0.5"
        )
        if abs(bloomThresholdHalf - 0.28) < 1e-6 {
            throw AssertionError(
                description: "bloomThreshold==0.28 at intensity=0.5 indicates the legacy `mapValues * intensity` bug regressed"
            )
        }
    }

    runner.test("intensityScaledScatter returns nil at intensity 0 (legacy glow fallback)") {
        // GradePipeline routes through the Backlight Veil CIKernel only when
        // `intensityScaledScatter` returns non-nil. At intensity == 0 the
        // user has zeroed the Backlight contribution: the pipeline must fall
        // back to the legacy `glowComposite` (no Backlight-specific direct
        // loss / scatter math). Identical to selecting None.
        for profile in FilmtoneOpticalFilterCatalog.profiles {
            let scatter = FilmtoneOpticalFilterCatalog.intensityScaledScatter(
                for: profile.id,
                intensity: 0.0
            )
            if scatter != nil {
                throw AssertionError(
                    description: "\(profile.id) at intensity=0 must yield nil scatter so GradePipeline falls back to legacy glow composite"
                )
            }
        }
        // A tiny but non-zero intensity still produces scaled scatter so the
        // user sees a faint Backlight effect even at low strength.
        if FilmtoneOpticalFilterCatalog.intensityScaledScatter(
            for: "backlightVeil-1-4",
            intensity: 0.1
        ) == nil {
            throw AssertionError(
                description: "intensity=0.1 must still produce scaled scatter (engaged at low strength)"
            )
        }
        // Negative or NaN-like extreme values clamp to nil too.
        if FilmtoneOpticalFilterCatalog.intensityScaledScatter(
            for: "backlightVeil-1-4",
            intensity: -0.5
        ) != nil {
            throw AssertionError(
                description: "intensity<0 must clamp to nil scatter"
            )
        }
    }

    runner.test("intensityScaledScatter at 1.0 equals catalog scatter byte-for-byte") {
        for profile in FilmtoneOpticalFilterCatalog.profiles {
            guard let scaled = FilmtoneOpticalFilterCatalog.intensityScaledScatter(
                for: profile.id,
                intensity: 1.0
            ), let raw = FilmtoneOpticalFilterCatalog.opticalScatter(for: profile.id) else {
                throw AssertionError(
                    description: "\(profile.id) scatter resolution failed at intensity=1.0"
                )
            }
            try assertClose(scaled.directTransmission, raw.directTransmission)
            try assertClose(scaled.blackRetention, raw.blackRetention)
            try assertClose(scaled.scatterStrength, raw.scatterStrength)
            try assertClose(scaled.highlightReactivity, raw.highlightReactivity)
            try assertClose(scaled.warmScatter, raw.warmScatter)
            try assertClose(scaled.spectralTail, raw.spectralTail)
        }
    }

    runner.test("intensityScaledScatter at 0.5 blends toward neutral-no-effect coefficients") {
        // Neutral targets: directTransmission → 1.0 (no direct loss),
        // all other coefficients → 0 (no scatter / shadow protect /
        // highlight reactivity / warm bias / spectral tail). At 0.5 the
        // values sit halfway between catalog and neutral.
        guard let raw = FilmtoneOpticalFilterCatalog.opticalScatter(for: "backlightVeil-1-4"),
              let scaled = FilmtoneOpticalFilterCatalog.intensityScaledScatter(
                for: "backlightVeil-1-4",
                intensity: 0.5
              ) else {
            throw AssertionError(description: "1/4 scatter resolution failed at intensity=0.5")
        }
        // dT: mix(1.0, raw.dT, 0.5) = 1.0 - 0.5 * (1.0 - raw.dT)
        let expectedDT = 1.0 - 0.5 * (1.0 - raw.directTransmission)
        try assertClose(scaled.directTransmission, expectedDT)
        try assertClose(scaled.blackRetention, raw.blackRetention * 0.5)
        try assertClose(scaled.scatterStrength, raw.scatterStrength * 0.5)
        try assertClose(scaled.highlightReactivity, raw.highlightReactivity * 0.5)
        try assertClose(scaled.warmScatter, raw.warmScatter * 0.5)
        try assertClose(scaled.spectralTail, raw.spectralTail * 0.5)
    }

    runner.test("intensity sidecar omits opticalFilterIntensity when 1.0") {
        struct IntensitySidecarRequest: FilmtoneSidecarRequest {
            let sourceURL = URL(fileURLWithPath: "/tmp/in.png")
            let outputURL = URL(fileURLWithPath: "/tmp/out.png")
            let presetName = "reset"
            let presetStrength = 1.0
            let lookSlug: String? = nil
            let sourceKind: FilmtoneSourceKind = .still
            let quickState = FilmtoneQuickState.zero
            let paramOverrides = FilmtonePhase0ParamsPatch.empty
            let opticalFilterProfileId: String? = "backlightVeil-1-4"
            let opticalFilterIntensity: Double
        }
        // At 1.0, opticalFilterIntensity should be absent from the sidecar block.
        let payload1 = FilmtoneSidecarWriter.sidecarPayload(
            for: IntensitySidecarRequest(opticalFilterIntensity: 1.0)
        )
        if let block = payload1["opticalFilterProfile"] as? [String: Any] {
            if block["opticalFilterIntensity"] != nil {
                throw AssertionError(
                    description: "opticalFilterIntensity must be omitted from sidecar when 1.0"
                )
            }
        }
        // At 0.5, opticalFilterIntensity should be present.
        let payload05 = FilmtoneSidecarWriter.sidecarPayload(
            for: IntensitySidecarRequest(opticalFilterIntensity: 0.5)
        )
        guard let block05 = payload05["opticalFilterProfile"] as? [String: Any] else {
            throw AssertionError(description: "opticalFilterProfile block missing at intensity=0.5")
        }
        let storedIntensity = block05["opticalFilterIntensity"] as? Double
        try assertClose(storedIntensity ?? .nan, 0.5, "opticalFilterIntensity should be 0.5 in sidecar")
    }

    // ---------------------------------------------------------------------------
    // Test group 17 — M5-M follow-up (Look × Veil energy max-merge).
    // FilmtonePresetCatalog.resolved() now layers Veil's paramPatch with split
    // semantics: energy keys (bloomStrength / halationIntensity / diffusion /
    // lensSoftness / rgbShift) max-merge against the post-Quick base so a Look
    // that already raised them isn't knocked back down by Veil's reset-baseline
    // authored values. Structural keys (thresholds / radii / hue / softKnee)
    // keep absolute overwrite. User paramOverrides always win last.
    // Regression context: under Stone, Veil 1/4's lensSoftness=0.08 was
    // overwriting Stone's lensSoftness=0.095, and Veil's rgbShift=0.0007 was
    // overwriting Stone's 0.0032 — Veil read as "weaker" instead of "stronger".
    // ---------------------------------------------------------------------------

    let stoneSlug = "filmtone-creative-pack-01-stone"

    runner.test("Stone+Veil1/4: lensSoftness max-merges (Stone 0.095 preserved over Veil 0.08)") {
        let stoneOnly = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug
        )
        let stoneVeil = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-4",
            opticalFilterIntensity: 1.0
        )
        if stoneVeil.lensSoftness < stoneOnly.lensSoftness {
            throw AssertionError(
                description: "Veil reduced Stone's lensSoftness: stone=\(stoneOnly.lensSoftness) stoneVeil=\(stoneVeil.lensSoftness)"
            )
        }
        try assertClose(stoneVeil.lensSoftness, stoneOnly.lensSoftness, "Stone 0.095 > Veil 1/4 0.08, max wins")
    }

    runner.test("Stone+Veil1/4: rgbShift max-merges (Stone 0.0032 preserved over Veil 0.0007)") {
        let stoneOnly = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug
        )
        let stoneVeil = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-4",
            opticalFilterIntensity: 1.0
        )
        if stoneVeil.rgbShift < stoneOnly.rgbShift {
            throw AssertionError(
                description: "Veil reduced Stone's rgbShift: stone=\(stoneOnly.rgbShift) stoneVeil=\(stoneVeil.rgbShift)"
            )
        }
        try assertClose(stoneVeil.rgbShift, stoneOnly.rgbShift, "Stone 0.0032 > Veil 1/4 0.0007, max wins")
    }

    runner.test("Stone+Veil1/4: bloomStrength rises above Stone (Veil 0.38 > Stone 0.20)") {
        let stoneVeil = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-4",
            opticalFilterIntensity: 1.0
        )
        try assertClose(stoneVeil.bloomStrength, 0.38, "Veil 0.38 wins via max-merge")
    }

    runner.test("Stone+Veil1/4: structural bloomThreshold takes Veil's value (0.56, not Stone's 0.64)") {
        let stoneVeil = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-4",
            opticalFilterIntensity: 1.0
        )
        // bloomThreshold is structural — Veil overwrites regardless of base value
        try assertClose(stoneVeil.bloomThreshold, 0.56)
        try assertClose(stoneVeil.bloomRadius, 0.80)
        try assertClose(stoneVeil.halationHue, 22)
    }

    runner.test("Stone+Veil1/4 at intensity=0: byte-identical to Stone-only") {
        let stoneOnly = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug
        )
        let stoneVeilZero = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-4",
            opticalFilterIntensity: 0.0
        )
        try assertParamsEqual(stoneVeilZero, stoneOnly, "intensity=0 must skip Veil layer entirely")
    }

    runner.test("user paramOverride bloomStrength=0.05 wins over Stone+Veil1/2") {
        let patch = FilmtonePhase0ParamsPatch(values: ["bloomStrength": 0.05])
        let result = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-2",
            opticalFilterIntensity: 1.0,
            paramOverrides: patch
        )
        try assertClose(result.bloomStrength, 0.05, "user override is final-stage absolute overwrite")
    }

    runner.test("Veil energy max-merge: intensity 1 ≥ intensity 0.5 ≥ intensity 0 (monotonic)") {
        // Stone supplies a definitively non-zero base for every energy key
        // (lensSoftness 0.095, rgbShift 0.0032, bloomStrength 0.20, etc.) so
        // the max-merge envelope is exercised on a non-trivial baseline.
        let intensity1 = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-2",
            opticalFilterIntensity: 1.0
        )
        let intensity05 = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-2",
            opticalFilterIntensity: 0.5
        )
        let intensity0 = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug,
            opticalFilterProfileId: "backlightVeil-1-2",
            opticalFilterIntensity: 0.0
        )
        // For each Veil energy key: max-merge produces a monotonic envelope
        // intensity1 ≥ intensity05 ≥ intensity0 — never *reduces* below base
        // as intensity attenuates.
        for key in ["bloomStrength", "halationIntensity", "diffusion", "lensSoftness", "rgbShift"] {
            let v1 = intensity1.value(for: key)
            let v05 = intensity05.value(for: key)
            let v0 = intensity0.value(for: key)
            if v1 + 1e-12 < v05 {
                throw AssertionError(description: "\(key): intensity1=\(v1) < intensity05=\(v05) — monotonicity broken")
            }
            if v05 + 1e-12 < v0 {
                throw AssertionError(description: "\(key): intensity05=\(v05) < intensity0=\(v0) — Veil reduced base")
            }
        }
        // intensity0 must equal Stone-only baseline byte-for-byte.
        let stoneOnly = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: stoneSlug
        )
        try assertParamsEqual(intensity0, stoneOnly, "intensity=0 must skip Veil layer")
    }

    runner.test("Veil-only (no Look) matches legacy renderParamOverrides flat-patch result") {
        // Regression guard: lookSlug=nil + Veil through new resolved path must
        // produce the same final params as the legacy
        // `renderParamOverrides → applyingPatch` indirection used elsewhere.
        let veilProfileId = "backlightVeil-1-4"
        let veilIntensity = 0.7
        let userOverrides = FilmtonePhase0ParamsPatch.empty

        let newPath = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            opticalFilterProfileId: veilProfileId,
            opticalFilterIntensity: veilIntensity,
            paramOverrides: userOverrides
        )

        let legacyFlat = FilmtoneOpticalFilterCatalog.renderParamOverrides(
            profileId: veilProfileId,
            intensity: veilIntensity,
            userOverrides: userOverrides
        )
        let legacyPath = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            paramOverrides: legacyFlat
        )

        // With reset baseline, base[key] == 0 for energy keys, so max(0, scaled) == scaled
        // and the new max-merge path produces identical params to legacy applyingPatch.
        try assertParamsEqual(
            newPath, legacyPath,
            "lookSlug=nil + Veil through new path must match legacy flat-patch result"
        )
    }

    // ---------------------------------------------------------------------------
}
