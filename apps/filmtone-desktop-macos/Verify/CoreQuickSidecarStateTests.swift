import FilmLabSwiftCore
import Foundation

func registerCoreQuickSidecarStateTests() {
    // Test group 1 — Quick=.zero / overrides=.empty parity (visual check #5).
    // resolved(...) with both new args defaulted must equal the legacy
    // params(for:strength:) path field-by-field, for every preset / strength.
    // ---------------------------------------------------------------------------

    for preset in FilmtonePresetCatalog.orderedNames {
        for strength in [0.0, 0.25, 0.6, 1.0] {
            runner.test("parity preset=\(preset) strength=\(strength)") {
                let legacy = FilmtonePresetCatalog.params(for: preset, strength: strength)
                let resolved = FilmtonePresetCatalog.resolved(
                    presetName: preset,
                    strength: strength,
                    lookSlug: nil
                )
                try assertParamsEqual(resolved, legacy, "Quick=.zero must equal legacy")
            }
        }
    }

    // ---------------------------------------------------------------------------
    // Test group 2 — Quick math correctness (visual check #1 logic).
    // applyQuickState with a single axis at +0.5 must shift each affected
    // param by exactly 0.5 * weight from the base.
    // ---------------------------------------------------------------------------

    for axis in FilmtonePhase0Generated.quickAxisIds {
        runner.test("quick axis=\(axis) @+0.5 shifts by 0.5*weight") {
            let base = FilmtonePresetCatalog.params(
                for: FilmtonePresetCatalog.defaultName,
                strength: 1.0
            )
            var qs = FilmtoneQuickState.zero
            switch axis {
            case "filmCharacter": qs.filmCharacter = 0.5
            case "era": qs.era = 0.5
            case "dynamics": qs.dynamics = 0.5
            default: throw AssertionError(description: "unknown axis \(axis)")
            }
            let result = FilmtonePresetCatalog.applyQuickState(to: base, quickState: qs)
            guard let weights = FilmtonePhase0Generated.quickWeights[axis] else {
                throw AssertionError(description: "no weights for axis \(axis)")
            }
            for (key, weight) in weights {
                let expected = base.value(for: key) + 0.5 * weight
                let actual = result.value(for: key)
                try assertClose(actual, expected, "axis=\(axis) key=\(key) weight=\(weight)")
            }
        }
    }

    // Negative axis sign — symmetric around zero.
    runner.test("quick axis filmCharacter @-0.5 mirrors @+0.5") {
        let base = FilmtonePresetCatalog.params(
            for: FilmtonePresetCatalog.defaultName,
            strength: 1.0
        )
        var pos = FilmtoneQuickState.zero
        pos.filmCharacter = 0.5
        var neg = FilmtoneQuickState.zero
        neg.filmCharacter = -0.5
        let resultPos = FilmtonePresetCatalog.applyQuickState(to: base, quickState: pos)
        let resultNeg = FilmtonePresetCatalog.applyQuickState(to: base, quickState: neg)
        guard let weights = FilmtonePhase0Generated.quickWeights["filmCharacter"] else {
            throw AssertionError(description: "no weights")
        }
        for (key, _) in weights {
            let baseV = base.value(for: key)
            let posV = resultPos.value(for: key)
            let negV = resultNeg.value(for: key)
            let posDelta = posV - baseV
            let negDelta = negV - baseV
            try assertClose(posDelta, -negDelta, "key=\(key) sign symmetry")
        }
    }

    // ---------------------------------------------------------------------------
    // Test group 3 — Sidecar quickState block (visual check #4).
    // Live request quickState must be emitted into the sidecar payload,
    // not the previously-hard-coded [0, 0, 0] block.
    // ---------------------------------------------------------------------------

    runner.test("sidecar quickState block emits live values") {
        let qs = FilmtoneQuickState(
            filmCharacter: 0.4,
            era: -0.2,
            dynamics: 0.7
        )
        let req = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/in.png"),
            outputURL: URL(fileURLWithPath: "/tmp/out.png"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .still,
            quickState: qs,
            paramOverrides: .empty
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard let block = payload["quickState"] as? [String: Double] else {
            throw AssertionError(description: "quickState block missing or wrong type")
        }
        try assertClose(block["filmCharacter"] ?? -999, 0.4, "filmCharacter")
        try assertClose(block["era"] ?? -999, -0.2, "era")
        try assertClose(block["dynamics"] ?? -999, 0.7, "dynamics")
    }

    runner.test("sidecar quickState clamps out-of-range values") {
        let qs = FilmtoneQuickState(
            filmCharacter: 5.0,    // -> clamps to +1
            era: -5.0,             // -> clamps to -1
            dynamics: 0.3
        )
        let req = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/in.png"),
            outputURL: URL(fileURLWithPath: "/tmp/out.png"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .still,
            quickState: qs,
            paramOverrides: .empty
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard let block = payload["quickState"] as? [String: Double] else {
            throw AssertionError(description: "quickState block missing")
        }
        try assertClose(block["filmCharacter"] ?? -999, FilmtonePhase0Generated.quickAxisMax)
        try assertClose(block["era"] ?? -999, FilmtonePhase0Generated.quickAxisMin)
        try assertClose(block["dynamics"] ?? -999, 0.3)
    }

    runner.test("sidecar gradeParams reflect Quick + paramOverrides applied") {
        var qs = FilmtoneQuickState.zero
        qs.filmCharacter = 0.5
        let patch = FilmtonePhase0ParamsPatch(values: ["exposure": 0.2])
        let req = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/in.png"),
            outputURL: URL(fileURLWithPath: "/tmp/out.png"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .still,
            quickState: qs,
            paramOverrides: patch
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard let grade = payload["gradeParams"] as? [String: Double] else {
            throw AssertionError(description: "gradeParams missing")
        }
        let expectedDirect = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            quickState: qs,
            paramOverrides: patch
        )
        for key in FilmtonePhase0Params.keyPaths.keys.sorted() {
            let payloadV = grade[key] ?? .nan
            let expectedV = expectedDirect.value(for: key)
            try assertClose(payloadV, expectedV, "gradeParams.\(key)")
        }
    }

    runner.test("sidecar emits highlightMarkers block with stable id") {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "clip.mov",
                durationSec: 20,
                fps: 24,
                fileSizeBytes: 1024
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "filmtone-marker-desktop-test",
                    sourceTimeSec: 5,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                )
            ]
        )
        let req = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/clip.mov"),
            outputURL: URL(fileURLWithPath: "/tmp/out.mp4"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .video,
            quickState: .zero,
            paramOverrides: .empty,
            highlightMarkers: markers
        )
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: req)
        guard
            let block = payload["highlightMarkers"] as? [String: Any],
            let markerList = block["markers"] as? [[String: Any]],
            let first = markerList.first
        else {
            throw AssertionError(description: "highlightMarkers block missing")
        }
        try assertEqual(block["schema"] as? String, Optional(FilmtoneHighlightMarkers.schemaID))
        try assertEqual(first["id"] as? String, Optional("filmtone-marker-desktop-test"))
        try assertEqual(first["createdOnPlatform"] as? String, Optional("macos"))
        try assertEqual(first["sourceFrame"] as? Int, Optional(120))
    }

    runner.test("sidecar reader loads iOS highlightMarkers by source filename") {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-marker-read-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("clip.mov")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())
        let sidecarURL = tempDir.appendingPathComponent("rendered.mp4.filmtone-ios-export-session-v1.json")
        let json = """
        {
          "package": { "sourceMediaFilename": "clip.mov" },
          "highlightMarkers": {
            "schema": "filmtone-highlight-markers-v1",
            "sourceIdentity": {
              "filename": "clip.mov",
              "durationSec": 20,
              "fps": 24,
              "fileSizeBytes": 1024
            },
            "defaults": { "preRollSec": 2, "postRollSec": 3 },
            "markers": [{
              "id": "filmtone-marker-ios-test",
              "sourceTimeSec": 5,
              "sourceFrame": 120,
              "sourceFps": 24,
              "preRollSec": 2,
              "postRollSec": 3,
              "color": "Blue",
              "name": "Highlight",
              "note": "",
              "createdOnPlatform": "ios",
              "createdAtIso": "2026-05-05T00:00:00.000Z"
            }]
          }
        }
        """
        try Data(json.utf8).write(to: sidecarURL)

        let markers = FilmtoneSidecarWriter.readHighlightMarkers(matchingSourceURL: sourceURL)
        try assertEqual(markers?.markers.first?.id, Optional("filmtone-marker-ios-test"))
        try assertEqual(markers?.markers.first?.createdOnPlatform, Optional("ios"))
    }

    runner.test("sidecar writer creates adjacent JSON beside selected export") {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("filmtone-sandbox-sidecar-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let sourceURL = tempDir.appendingPathComponent("source.mov")
        let outputURL = tempDir.appendingPathComponent("selected-export.mp4")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())

        let req = StubSidecarRequest(
            sourceURL: sourceURL,
            outputURL: outputURL,
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .video,
            quickState: .zero,
            paramOverrides: .empty,
            highlightMarkers: nil
        )

        let sidecarURL = try FilmtoneSidecarWriter.writeSidecar(for: req)
        try assertEqual(
            sidecarURL.deletingLastPathComponent(),
            outputURL.deletingLastPathComponent(),
            "sidecar directory"
        )
        try assertEqual(sidecarURL.lastPathComponent, "selected-export.filmtone.json", "sidecar filename")
        guard FileManager.default.fileExists(atPath: sidecarURL.path) else {
            throw AssertionError(description: "sidecar was not written next to export")
        }
    }

    runner.test("highlight reel export route uses centered merged marker segments") {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "clip.mov",
                durationSec: 8,
                fps: 24,
                fileSizeBytes: 2048
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "marker-a",
                    sourceTimeSec: 1.0,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "marker-b",
                    sourceTimeSec: 1.7,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "marker-tail",
                    sourceTimeSec: 7.9,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-05-05T00:00:00.000Z"
                ),
            ]
        )
        let request = StubSidecarRequest(
            sourceURL: URL(fileURLWithPath: "/tmp/clip.mov"),
            outputURL: URL(fileURLWithPath: "/tmp/highlight-reel.mp4"),
            presetName: "reset",
            presetStrength: 1.0,
            lookSlug: nil,
            sourceKind: .video,
            quickState: .zero,
            paramOverrides: .empty,
            highlightMarkers: markers
        )

        let segments = request.highlightMarkers?.highlightReelSegments() ?? []
        try assertEqual(segments.count, 2)
        try assertEqual(segments[0].markerIds, ["marker-a", "marker-b"])
        try assertClose(segments[0].sourceStartSec, 0.5)
        try assertClose(segments[0].sourceEndSec, 2.2)
        try assertEqual(segments[1].markerIds, ["marker-tail"])
        try assertClose(segments[1].sourceStartSec, 7.0)
        try assertClose(segments[1].sourceEndSec, 8.0)
    }

    runner.test("highlight reel selected options can produce separate longer clips") {
        let markers = FilmtoneHighlightMarkers(
            sourceIdentity: FilmtoneMarkerSourceIdentity(
                filename: "clip.mov",
                durationSec: 12,
                fps: 24,
                fileSizeBytes: 2048
            ),
            markers: [
                FilmtoneHighlightMarker(
                    id: "marker-a",
                    sourceTimeSec: 4.0,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-06-02T00:00:00.000Z"
                ),
                FilmtoneHighlightMarker(
                    id: "marker-b",
                    sourceTimeSec: 5.0,
                    sourceFps: 24,
                    createdOnPlatform: "macos",
                    createdAtIso: "2026-06-02T00:00:01.000Z"
                )
            ]
        )

        let segments = markers.highlightReelSegments(
            options: FilmtoneHighlightReelOptions(
                clipDurationSec: 5.0,
                outputMode: .separate
            )
        )

        try assertEqual(segments.count, 2)
        try assertEqual(segments[0].markerIds, ["marker-a"])
        try assertClose(segments[0].sourceStartSec, 1.5)
        try assertClose(segments[0].sourceEndSec, 6.5)
        try assertEqual(segments[1].markerIds, ["marker-b"])
        try assertClose(segments[1].sourceStartSec, 2.5)
        try assertClose(segments[1].sourceEndSec, 7.5)
    }

    runner.test("Backlight Veil catalog exposes shared profile ids + supported values") {
        try assertEqual(
            FilmtoneOpticalFilterCatalog.profiles.map(\.id),
            ["backlightVeil-1-8", "backlightVeil-1-4", "backlightVeil-1-2"],
            "Native should expose the product-facing Backlight Veil densities"
        )
        guard let profile = FilmtoneOpticalFilterCatalog.profile(for: "backlightVeil-1-4") else {
            throw AssertionError(description: "Backlight Veil 1/4 profile missing")
        }
        try assertEqual(profile.family, "backlightVeil")
        try assertEqual(profile.density, "1/4")
        try assertClose(profile.paramPatch.values["bloomThreshold"] ?? -1, 0.56)
        try assertClose(profile.paramPatch.values["bloomStrength"] ?? -1, 0.38)
        try assertClose(profile.paramPatch.values["diffusion"] ?? -1, 0.24)
        try assertClose(profile.paramPatch.values["halationIntensity"] ?? -1, 0.14)
        try assertClose(profile.paramPatch.values["lensSoftness"] ?? -1, 0.08)
    }

    runner.test("Backlight Veil render patch preserves manual advanced override priority") {
        let merged = FilmtoneOpticalFilterCatalog.renderParamOverrides(
            profileId: "backlightVeil-1-4",
            userOverrides: FilmtonePhase0ParamsPatch(values: [
                "bloomStrength": 0.91,
                "exposure": 0.25,
            ])
        )
        try assertClose(merged.values["bloomThreshold"] ?? -1, 0.56)
        try assertClose(merged.values["bloomStrength"] ?? -1, 0.91)
        try assertClose(merged.values["exposure"] ?? -1, 0.25)
    }

    runner.test("Backlight Veil profiles carry six optical scatter coefficients with monotonic progression") {
        let densities = ["backlightVeil-1-8", "backlightVeil-1-4", "backlightVeil-1-2"]
        var resolved: [FilmtoneOpticalScatterParams] = []
        for id in densities {
            guard let scatter = FilmtoneOpticalFilterCatalog.opticalScatter(for: id) else {
                throw AssertionError(
                    description: "\(id) missing optical scatter; M5-M expects every Backlight Veil density to expose iOS-canonical coefficients"
                )
            }
            resolved.append(scatter)
        }
        // None must collapse to nil so the legacy glow composite stays the
        // default render path.
        if FilmtoneOpticalFilterCatalog.opticalScatter(for: "none") != nil {
            throw AssertionError(description: "'none' must not carry optical scatter coefficients")
        }
        if FilmtoneOpticalFilterCatalog.opticalScatter(for: nil) != nil {
            throw AssertionError(description: "nil profile id must not carry optical scatter")
        }
        let strengths = resolved.map(\.scatterStrength)
        let directLosses = resolved.map { 1.0 - $0.directTransmission }
        let highlightDrives = resolved.map(\.highlightReactivity)
        let blackHolds = resolved.map(\.blackRetention)
        for index in 1..<strengths.count {
            if !(strengths[index] > strengths[index - 1]) {
                throw AssertionError(
                    description: "scatterStrength must increase 1/8 < 1/4 < 1/2 (got \(strengths))"
                )
            }
            if !(directLosses[index] > directLosses[index - 1]) {
                throw AssertionError(
                    description: "(1 - directTransmission) must increase 1/8 < 1/4 < 1/2 (got \(directLosses))"
                )
            }
            if !(highlightDrives[index] > highlightDrives[index - 1]) {
                throw AssertionError(
                    description: "highlightReactivity must increase 1/8 < 1/4 < 1/2 (got \(highlightDrives))"
                )
            }
            if !(blackHolds[index] < blackHolds[index - 1]) {
                throw AssertionError(
                    description: "blackRetention must decrease 1/8 > 1/4 > 1/2 (got \(blackHolds))"
                )
            }
        }
        // Spot-check the canonical 1/4 values against `optical-filter-profiles.ts`.
        try assertClose(resolved[1].directTransmission, 0.81)
        try assertClose(resolved[1].blackRetention, 0.56)
        try assertClose(resolved[1].scatterStrength, 0.66)
        try assertClose(resolved[1].highlightReactivity, 0.78)
        try assertClose(resolved[1].warmScatter, 0.17)
        try assertClose(resolved[1].spectralTail, 0.07)
    }

    runner.test("Backlight Veil composite delta progresses None < 1/8 < 1/4 < 1/2 on a synthetic bright frame") {
        // The Backlight Veil scenario is a shadow subject silhouetted
        // against a bright source. Sample that with a deep-shadow base
        // pixel and bright bloom + halation + diffusion plates: the veil
        // adds scatter into the shadow at progressively higher densities,
        // so absolute output delta from the unprocessed base must rise
        // monotonically with density. (At very bright base pixels direct
        // loss can dominate scatter and the delta is non-monotonic — use
        // shadow base here, matching the user-perceived Backlight scenario.)
        let basePixel = (0.05, 0.04, 0.03)
        let plate = (0.5, 0.5, 0.5)
        let bloomStrength = 0.4
        let halationIntensity = 0.18
        let diffusionAmount = 0.25

        func deltaFor(_ id: String?) -> Double {
            let scatter = FilmtoneOpticalFilterCatalog.opticalScatter(for: id)
            let composed: (Double, Double, Double)
            if let scatter {
                composed = FilmtoneOpticalScatterMath.composite(
                    base: basePixel,
                    bloom: plate,
                    halation: plate,
                    diffusion: plate,
                    bloomStrength: bloomStrength,
                    halationIntensity: halationIntensity,
                    diffusionAmount: diffusionAmount,
                    optical: scatter
                )
            } else {
                composed = basePixel
            }
            let dr = composed.0 - basePixel.0
            let dg = composed.1 - basePixel.1
            let db = composed.2 - basePixel.2
            return abs(dr) + abs(dg) + abs(db)
        }

        let deltas: [Double] = [
            deltaFor(nil),
            deltaFor("backlightVeil-1-8"),
            deltaFor("backlightVeil-1-4"),
            deltaFor("backlightVeil-1-2"),
        ]
        if !(deltas[0] < 1e-9) {
            throw AssertionError(description: "None must produce zero delta against base (got \(deltas[0]))")
        }
        for index in 1..<deltas.count {
            if !(deltas[index] > deltas[index - 1] + 0.005) {
                throw AssertionError(
                    description: "composite delta must increase materially with density (got \(deltas))"
                )
            }
        }
    }

    runner.test("Backlight Veil composite preserves shadow ordering and warm-biases scatter") {
        let scatter = FilmtoneOpticalFilterCatalog.opticalScatter(for: "backlightVeil-1-2")!
        let plate = (0.4, 0.4, 0.4)
        // Bright base falls back closer to base after direct loss; shadow
        // base picks up scatter. Both should still keep the highlight luma
        // above the shadow luma with the veil applied.
        let highlight = FilmtoneOpticalScatterMath.composite(
            base: (0.95, 0.85, 0.60),
            bloom: plate,
            halation: plate,
            diffusion: plate,
            bloomStrength: 0.4,
            halationIntensity: 0.18,
            diffusionAmount: 0.25,
            optical: scatter
        )
        let shadow = FilmtoneOpticalScatterMath.composite(
            base: (0.06, 0.05, 0.04),
            bloom: plate,
            halation: plate,
            diffusion: plate,
            bloomStrength: 0.4,
            halationIntensity: 0.18,
            diffusionAmount: 0.25,
            optical: scatter
        )
        let highlightLuma = FilmtoneOpticalScatterMath.luma(highlight)
        let shadowLuma = FilmtoneOpticalScatterMath.luma(shadow)
        if !(highlightLuma > shadowLuma + 0.3) {
            throw AssertionError(
                description: "Backlight Veil 1/2 must keep shadows below highlights (got shadow=\(shadowLuma) highlight=\(highlightLuma))"
            )
        }
        // Warm bias acts on the scatter contribution. At a neutral gray
        // base the direct-loss is symmetric across channels, so the
        // composed result must skew warm (R > B) under the 1/2 veil.
        let neutral = FilmtoneOpticalScatterMath.composite(
            base: (0.45, 0.45, 0.45),
            bloom: plate,
            halation: plate,
            diffusion: plate,
            bloomStrength: 0.4,
            halationIntensity: 0.18,
            diffusionAmount: 0.25,
            optical: scatter
        )
        if !(neutral.0 > neutral.2 + 0.005) {
            throw AssertionError(
                description: "Backlight Veil 1/2 must warm-bias a neutral mid pixel (R > B), got neutral=\(neutral)"
            )
        }
    }

    runner.test("sidecar records Backlight Veil identity and resolves gradeParams") {
        struct OpticalSidecarRequest: FilmtoneSidecarRequest {
            let sourceURL = URL(fileURLWithPath: "/tmp/in.mov")
            let outputURL = URL(fileURLWithPath: "/tmp/out.mp4")
            let presetName = "reset"
            let presetStrength = 1.0
            let lookSlug: String? = nil
            let sourceKind: FilmtoneSourceKind = .video
            let quickState = FilmtoneQuickState.zero
            let paramOverrides = FilmtonePhase0ParamsPatch(values: [
                "diffusion": 0.31,
            ])
            let opticalFilterProfileId: String? = "backlightVeil-1-4"
        }
        let payload = FilmtoneSidecarWriter.sidecarPayload(for: OpticalSidecarRequest())
        guard let optical = payload["opticalFilterProfile"] as? [String: String] else {
            throw AssertionError(description: "opticalFilterProfile block missing")
        }
        try assertEqual(optical["id"], "backlightVeil-1-4")
        try assertEqual(optical["family"], "backlightVeil")
        try assertEqual(optical["density"], "1/4")
        guard let grade = payload["gradeParams"] as? [String: Double] else {
            throw AssertionError(description: "gradeParams missing")
        }
        try assertClose(grade["bloomStrength"] ?? -1, 0.38)
        try assertClose(grade["diffusion"] ?? -1, 0.31)
        try assertClose(grade["halationIntensity"] ?? -1, 0.14)
    }

    // ---------------------------------------------------------------------------
    // Test group 4 — SavedLookEntry round-trip (visual check #2).
    // JSON-encoding + decoding a Look entry must preserve quickState +
    // paramOverrides byte-for-byte. The runtime save/load (FilmtoneSavedLookStore)
    // is a thin disk wrapper around this Codable, so a green Codable test
    // guarantees the in-app round-trip works.
    // ---------------------------------------------------------------------------

    runner.test("SavedLookEntry round-trip preserves quickState + paramOverrides") {
        let qs = FilmtoneQuickState(
            filmCharacter: 0.3,
            era: -0.1,
            dynamics: 0.6
        )
        let patch = FilmtonePhase0ParamsPatch(values: [
            "exposure": 0.25,
            "halationIntensity": 0.42,
            "shadowTone": -0.15,
        ])
        let original = SavedLookEntry(
            schemaVersion: FilmtoneLibraryConstants.entrySchemaVersion,
            id: UUID(),
            name: "Stone Era",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001),
            presetName: "reset",
            presetVersion: FilmtonePresetCatalog.presetVersion,
            strength: 0.6,
            quickState: qs,
            paramOverrides: patch,
            creativeLut: nil,
            favorite: false,
            thumbnailRef: nil,
            bundled: false,
            immutable: false,
            bundledSlug: nil
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(SavedLookEntry.self, from: data)
        try assertEqual(decoded.quickState, original.quickState, "quickState")
        try assertEqual(decoded.paramOverrides, original.paramOverrides, "paramOverrides")
        try assertEqual(decoded, original, "full SavedLookEntry")
    }

    // ---------------------------------------------------------------------------
    // Test group 5 — Reset Quick logic (visual check #3 logic).
    // FilmtoneQuickState.zero is the literal 0/0/0; EditorState.resetQuickState()
    // just assigns this to state.quickState.
    // ---------------------------------------------------------------------------

    runner.test("FilmtoneQuickState.zero is 0/0/0") {
        try assertClose(FilmtoneQuickState.zero.filmCharacter, 0)
        try assertClose(FilmtoneQuickState.zero.era, 0)
        try assertClose(FilmtoneQuickState.zero.dynamics, 0)
    }

    // ---------------------------------------------------------------------------
    // Test group 6 — Resolution order (M5-H.2 corrected to iOS canonical).
    // iOS canonical (`FilmtonePhase0Math.resolveParams`): interpolate →
    // applyQuickState → applyingPatch(paramOverrides). paramOverrides land
    // LAST and absolutely set the value — Quick is overwritten on any key
    // the user has explicitly overridden.
    //
    // Earlier (M5-C.3a) Desktop swapped the order so an override key
    // inherited a Quick delta on top. That broke recipe parity with iOS
    // (recipes' max(base, target) values landed at +Quick*weight after
    // render) and made the Adjust panel slider show one value while the
    // preview rendered another. M5-H.2 commit fixed both directions.
    // ---------------------------------------------------------------------------

    runner.test("resolved order: Quick then paramOverrides — overrides win absolute") {
        // Find a (axis, key) pair such that:
        //  - the key has a non-zero Quick weight (so Quick would visibly
        //    move the key absent an override),
        //  - the chosen `absoluteValue` survives `AdvancedAdjustCatalog.clamp`
        //    unchanged for the key (so `expected == absoluteValue`),
        //  - the clamped value differs from base+Quick by more than the
        //    `paramEqualityTolerance`, so `normalized(over:)` keeps the
        //    override instead of dropping it as identity.
        // Iterate sorted axes / keys so the test picks the same pair on
        // every host (Dictionary iteration order is not stable across runs
        // — picking a clamp-tight key like `grainIntensity` would silently
        // round 0.123 to 0.1 and break the equality assertion).
        let absoluteValue: Double = 0.5
        let baseParams = FilmtonePresetCatalog.params(for: "reset", strength: 1.0)

        var pickedAxis: String?
        var pickedKey: String?
        var pickedQuickContribution: Double = 0

        outer: for axis in FilmtonePhase0Generated.quickAxisIds.sorted() {
            guard let weights = FilmtonePhase0Generated.quickWeights[axis] else { continue }
            for (key, weight) in weights.sorted(by: { $0.key < $1.key }) where weight != 0 {
                let clamped = AdvancedAdjustCatalog.clamp(absoluteValue, for: key)
                // Reject keys whose range would clamp our chosen value.
                if abs(clamped - absoluteValue) > 1e-9 { continue }
                // Reject keys where the override would equal base+Quick
                // within tolerance (would get normalized out as identity).
                let baseAfterQuick = baseParams.value(for: key) + 0.5 * weight
                if abs(clamped - baseAfterQuick) < AdvancedAdjustCatalog.paramEqualityTolerance { continue }
                pickedAxis = axis
                pickedKey = key
                pickedQuickContribution = 0.5 * weight
                break outer
            }
        }

        guard let axis = pickedAxis, let key = pickedKey else {
            throw AssertionError(description: "no Quick-affected key fits the absolute=\(absoluteValue) test premise")
        }

        var qs = FilmtoneQuickState.zero
        switch axis {
        case "filmCharacter": qs.filmCharacter = 0.5
        case "era": qs.era = 0.5
        case "dynamics": qs.dynamics = 0.5
        default: throw AssertionError(description: "unknown axis \(axis)")
        }
        let patch = FilmtonePhase0ParamsPatch(values: [key: absoluteValue])
        let result = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            quickState: qs,
            paramOverrides: patch
        )
        // iOS canonical: override is the final value. Quick is overwritten
        // on this key. Pre-fix Desktop returned absoluteValue + Quick.
        try assertClose(
            result.value(for: key),
            absoluteValue,
            "axis=\(axis) key=\(key) override should win absolute over Quick=\(pickedQuickContribution)"
        )
    }

    runner.test("resolved order: Quick still affects keys that have no override") {
        // Sanity check that swapping the order didn't disable Quick entirely
        // — only override KEYS lose their Quick contribution.
        var pickedKey: String? = nil
        var pickedWeight: Double = 0
        if let weights = FilmtonePhase0Generated.quickWeights["filmCharacter"] {
            for (key, weight) in weights where weight != 0 {
                pickedKey = key
                pickedWeight = weight
                break
            }
        }
        guard let key = pickedKey else {
            throw AssertionError(description: "no non-zero filmCharacter weight")
        }
        let baseParams = FilmtonePresetCatalog.params(for: "reset", strength: 1.0)
        var qs = FilmtoneQuickState.zero
        qs.filmCharacter = 0.5
        let result = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            quickState: qs,
            paramOverrides: .empty
        )
        let expected = baseParams.value(for: key) + 0.5 * pickedWeight
        try assertClose(
            result.value(for: key),
            expected,
            "key=\(key) without override should reflect Quick"
        )
    }

    runner.test("paramOverrides applies absolute (set), not delta") {
        let patch = FilmtonePhase0ParamsPatch(values: ["exposure": 0.42])
        let result = FilmtonePresetCatalog.resolved(
            presetName: "reset",
            strength: 1.0,
            lookSlug: nil,
            quickState: .zero,
            paramOverrides: patch
        )
        try assertClose(result.exposure, 0.42, "exposure should be set, not added")
    }

    runner.test("normalized(over:) drops overrides that match resolved base") {
        // Recipe stamps that happen to match the post-Quick base shouldn't
        // pin redundant entries in paramOverrides — `normalized(over:)`
        // strips them, mirroring iOS behavior.
        let baseParams = FilmtonePresetCatalog.params(for: "reset", strength: 1.0)
        let exposureBase = baseParams.exposure
        let patch = FilmtonePhase0ParamsPatch(values: [
            "exposure": exposureBase, // matches base → drop
            "contrast": 1.5,           // differs from base 1.0 → keep
        ])
        let normalized = patch.normalized(over: baseParams)
        if normalized.values["exposure"] != nil {
            throw AssertionError(description: "exposure=\(exposureBase) should be dropped (matches base)")
        }
        guard let contrast = normalized.values["contrast"] else {
            throw AssertionError(description: "contrast=1.5 should be kept (differs from base)")
        }
        try assertClose(contrast, 1.5, "contrast preserved through normalize")
    }

    // ---------------------------------------------------------------------------
    // Test group 7 — Quick state Hashable usability (PreviewRenderKey gate).
    // The PreviewSurface task(id:) re-fires when Hashable identity changes.
    // Distinct quickState values must hash distinctly (or at least compare
    // non-equal so SwiftUI re-evaluates).
    // ---------------------------------------------------------------------------

    runner.test("FilmtoneQuickState distinct values compare non-equal") {
        let a = FilmtoneQuickState(filmCharacter: 0.1, era: 0, dynamics: 0)
        let b = FilmtoneQuickState(filmCharacter: 0.2, era: 0, dynamics: 0)
        if a == b {
            throw AssertionError(description: "expected non-equal quick states")
        }
    }

    runner.test("FilmtonePhase0ParamsPatch distinct patches compare non-equal") {
        let a = FilmtonePhase0ParamsPatch(values: ["exposure": 0.1])
        let b = FilmtonePhase0ParamsPatch(values: ["exposure": 0.2])
        if a == b {
            throw AssertionError(description: "expected non-equal patches")
        }
    }

    // ---------------------------------------------------------------------------
    // Test group 8 — M5-C.4 Export Inspector formatters + clamps.
    // FilmtoneFormatters is a Foundation-only helper used by the inspector to
    // surface elapsed time / file size / clamped JPEG quality. Tested here so a
    // regression in the displayed copy or clamp range is caught before the user
    // hits it visually.
    // ---------------------------------------------------------------------------

    runner.test("formattedFileSize boundaries (B / KB / MB / GB)") {
        try assertEqual(FilmtoneFormatters.formattedFileSize(0), "0 B")
        try assertEqual(FilmtoneFormatters.formattedFileSize(999), "999 B")
        try assertEqual(FilmtoneFormatters.formattedFileSize(1024), "1.0 KB")
        try assertEqual(FilmtoneFormatters.formattedFileSize(1536 * 1024), "1.5 MB")
        try assertEqual(FilmtoneFormatters.formattedFileSize(2_899_102_924), "2.7 GB")
    }

    runner.test("formattedFileSize negative input clamps to 0 B") {
        try assertEqual(FilmtoneFormatters.formattedFileSize(-100), "0 B")
    }

    runner.test("formattedElapsed sub-minute uses one-decimal seconds") {
        try assertEqual(FilmtoneFormatters.formattedElapsed(0.0), "0.0s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(0.5), "0.5s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(12.4), "12.4s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(59.9), "59.9s")
    }

    runner.test("formattedElapsed minutes uses Mm SSs") {
        try assertEqual(FilmtoneFormatters.formattedElapsed(60), "1m 00s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(90), "1m 30s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(599), "9m 59s")
    }

    runner.test("formattedElapsed hours uses Hh MMm SSs") {
        try assertEqual(FilmtoneFormatters.formattedElapsed(3600), "1h 00m 00s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(3661), "1h 01m 01s")
        try assertEqual(FilmtoneFormatters.formattedElapsed(7325), "2h 02m 05s")
    }

    runner.test("formattedElapsed handles non-finite + negative") {
        try assertEqual(FilmtoneFormatters.formattedElapsed(.nan), "—")
        try assertEqual(FilmtoneFormatters.formattedElapsed(-1), "—")
    }

    runner.test("clampedJpegQuality enforces 0.5...1.0 range") {
        try assertClose(FilmtoneFormatters.clampedJpegQuality(0.95), 0.95)
        try assertClose(FilmtoneFormatters.clampedJpegQuality(0.5), 0.5)
        try assertClose(FilmtoneFormatters.clampedJpegQuality(1.0), 1.0)
        try assertClose(FilmtoneFormatters.clampedJpegQuality(0.0), 0.5)
        try assertClose(FilmtoneFormatters.clampedJpegQuality(1.5), 1.0)
        try assertClose(FilmtoneFormatters.clampedJpegQuality(-1.0), 0.5)
    }

    // ---------------------------------------------------------------------------
}
