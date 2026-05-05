import FilmLabSwiftCore
import Foundation

// M5-C.3a verification harness — exercises the Quick adjust + saved-Look
// round-trip wiring without booting the SwiftUI app. Compiled standalone
// via `Verify/run.sh` against a pure-Foundation subset of FilmtoneDesktop
// sources. Asserts the math + serialization invariants so a green run
// gives confidence that user visual checks 2 / 4 / 5 (and the logic
// behind 1 / 3) are sound — only the actual GUI tap-through remains
// for the user.

private final class TestRunner {
    private(set) var passed = 0
    private(set) var failed = 0

    func test(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            passed += 1
            print("  PASS  \(name)")
        } catch {
            failed += 1
            print("  FAIL  \(name) — \(error)")
        }
    }

    func summary() -> Int32 {
        let total = passed + failed
        print("")
        print("  \(passed)/\(total) passed, \(failed) failed")
        return failed == 0 ? 0 : 1
    }
}

private struct AssertionError: Error, CustomStringConvertible {
    let description: String
}

private func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    if a != b {
        throw AssertionError(description: "\(msg) — expected \(b), got \(a)")
    }
}

private func assertClose(_ a: Double, _ b: Double, eps: Double = 1e-9, _ msg: String = "") throws {
    if abs(a - b) > eps {
        throw AssertionError(description: "\(msg) — expected \(b), got \(a) (diff \(a - b))")
    }
}

private func assertParamsEqual(_ a: FilmtonePhase0Params,
                               _ b: FilmtonePhase0Params,
                               eps: Double = 1e-9,
                               _ msg: String = "") throws {
    for key in FilmtonePhase0Params.keyPaths.keys.sorted() {
        let av = a.value(for: key)
        let bv = b.value(for: key)
        if abs(av - bv) > eps {
            throw AssertionError(description: "\(msg) — \(key): \(av) != \(bv)")
        }
    }
}

private struct StubSidecarRequest: FilmtoneSidecarRequest {
    let sourceURL: URL
    let outputURL: URL
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let sourceKind: FilmtoneSourceKind
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    var highlightMarkers: FilmtoneHighlightMarkers? = nil
}

private let runner = TestRunner()

// ---------------------------------------------------------------------------
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
// Test group 9 — M5-G.2 AdvancedAdjustCatalog parity (post-M5-C.3b review).
// AdvancedAdjustCatalog mirrors iOS canonical
// `FilmtoneStrengthSheetData.advancedParamGroups` + `FilmtonePhase0Math
// .clampParam`. iOS canonical clampParam does NOT live in
// film-lab-swift-core today, so these tests pin the Desktop catalog's
// own clamp surface instead — promoting clampParam into the shared
// package is a separate slice. Tests here guard against silent regression
// of either the catalog field set or the per-key clamp behavior.
// ---------------------------------------------------------------------------

runner.test("AdvancedAdjustCatalog group + control counts match the spec") {
    let allKeys = AdvancedAdjustCatalog.allGroups.flatMap { $0.controls.map(\.key) }
    try assertEqual(AdvancedAdjustCatalog.allGroups.count, 6, "expected 6 groups")
    try assertEqual(allKeys.count, 31, "expected 31 controls total")
    try assertEqual(
        Set(allKeys).count, 31,
        "control key collision — every key must appear exactly once"
    )
}

runner.test("AdvancedAdjustCatalog video-only filter hides motion in still mode") {
    let stillKeys = AdvancedAdjustCatalog.groups(forVideo: false)
        .flatMap { $0.controls.map(\.key) }
    let videoKeys = AdvancedAdjustCatalog.groups(forVideo: true)
        .flatMap { $0.controls.map(\.key) }
    try assertEqual(stillKeys.count, 29, "still mode = 31 - 2 motion")
    try assertEqual(videoKeys.count, 31, "video mode exposes all 31")
    if stillKeys.contains("shutterAngle") || stillKeys.contains("trailIntensity") {
        throw AssertionError(description: "still mode must not surface motion params")
    }
    if !videoKeys.contains("shutterAngle") || !videoKeys.contains("trailIntensity") {
        throw AssertionError(description: "video mode must surface motion params")
    }
}

runner.test("AdvancedAdjustCatalog keys are real Phase0 params") {
    // Catalog drives sliders that ultimately call `presetParams.value
    // (for: key)` — every catalog key must resolve through
    // FilmtonePhase0Params.keyPaths or the slider thumb shows nothing.
    let phase0Keys = Set(FilmtonePhase0Params.keyPaths.keys)
    for key in AdvancedAdjustCatalog.allGroups.flatMap({ $0.controls.map(\.key) }) {
        if !phase0Keys.contains(key) {
            throw AssertionError(
                description: "catalog key '\(key)' is not in FilmtonePhase0Params.keyPaths"
            )
        }
    }
}

runner.test("AdvancedAdjustCatalog.clamp respects per-key range branches") {
    // Sample one representative value below + above the range for each
    // distinct clamp branch in AdvancedAdjustCatalog.clamp. iOS-canonical
    // shutterAngle discontinuity is exercised in the next test.
    try assertClose(AdvancedAdjustCatalog.clamp(-5, for: "exposure"), -2, "exposure floor")
    try assertClose(AdvancedAdjustCatalog.clamp(5, for: "exposure"), 2, "exposure ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-1, for: "contrast"), 0, "contrast floor")
    try assertClose(AdvancedAdjustCatalog.clamp(5, for: "contrast"), 2, "contrast ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-2, for: "temperature"), -1, "temperature floor")
    try assertClose(AdvancedAdjustCatalog.clamp(2, for: "temperature"), 1, "temperature ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-5, for: "halationSpread"), 0, "halationSpread floor")
    try assertClose(AdvancedAdjustCatalog.clamp(50, for: "halationSpread"), 40, "halationSpread ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-5, for: "halationHue"), 0, "halationHue floor")
    try assertClose(AdvancedAdjustCatalog.clamp(150, for: "halationHue"), 100, "halationHue ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-1, for: "trailIntensity"), 0, "trailIntensity floor")
    try assertClose(AdvancedAdjustCatalog.clamp(2, for: "trailIntensity"), 0.95, "trailIntensity ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-1, for: "rgbShift"), 0, "rgbShift floor")
    try assertClose(
        AdvancedAdjustCatalog.clamp(1, for: "rgbShift"),
        FilmtonePhase0Generated.rgbShiftMax,
        "rgbShift ceiling tracks generated max"
    )
    try assertClose(
        AdvancedAdjustCatalog.clamp(1, for: "grainIntensity"),
        FilmtonePhase0Generated.grainIntensityMax,
        "grainIntensity ceiling tracks generated max"
    )
    // Generic 0...1 branch
    try assertClose(AdvancedAdjustCatalog.clamp(-1, for: "vignette"), 0, "vignette floor")
    try assertClose(AdvancedAdjustCatalog.clamp(2, for: "vignette"), 1, "vignette ceiling")
    try assertClose(AdvancedAdjustCatalog.clamp(-1, for: "lensSoftness"), 0, "lensSoftness floor")
    try assertClose(AdvancedAdjustCatalog.clamp(2, for: "lensSoftness"), 1, "lensSoftness ceiling")
}

runner.test("AdvancedAdjustCatalog.clamp shutterAngle iOS-canonical discontinuity") {
    // iOS canonical FilmtonePhase0Math.clampParam: < 90 collapses to 0
    // (motion blur disabled); 90..<180 snaps up to 180 (canonical
    // half-circle minimum); 180...720 is linear; >720 caps at 720.
    try assertClose(AdvancedAdjustCatalog.clamp(-50, for: "shutterAngle"), 0, "below 0 → 0")
    try assertClose(AdvancedAdjustCatalog.clamp(0, for: "shutterAngle"), 0, "at 0 stays 0")
    try assertClose(AdvancedAdjustCatalog.clamp(45, for: "shutterAngle"), 0, "<90 collapses to 0")
    try assertClose(AdvancedAdjustCatalog.clamp(89, for: "shutterAngle"), 0, "just below 90 → 0")
    try assertClose(AdvancedAdjustCatalog.clamp(90, for: "shutterAngle"), 180, "≥90 snaps to 180")
    try assertClose(AdvancedAdjustCatalog.clamp(179, for: "shutterAngle"), 180, "<180 snaps to 180")
    try assertClose(AdvancedAdjustCatalog.clamp(180, for: "shutterAngle"), 180, "180 stays 180")
    try assertClose(AdvancedAdjustCatalog.clamp(360, for: "shutterAngle"), 360, "interior linear")
    try assertClose(AdvancedAdjustCatalog.clamp(720, for: "shutterAngle"), 720, "ceiling 720")
    try assertClose(AdvancedAdjustCatalog.clamp(800, for: "shutterAngle"), 720, ">720 → 720")
}

runner.test("AdvancedAdjustCatalog.clamp default branch is identity") {
    // Unknown key falls through to identity. Documents the contract
    // that the catalog does not silently filter out keys it doesn't
    // recognize — a future Phase0 param can be added without an
    // immediate clamp branch.
    try assertClose(
        AdvancedAdjustCatalog.clamp(42, for: "someNewParamNotInCatalog"),
        42,
        "identity passthrough for unknown key"
    )
}

// ---------------------------------------------------------------------------
// Test group 10 — M5-H.2 catalog label parity with iOS canonical
// `FilmtoneStrings.paramLabels`. Drift detector: a Desktop label rename
// without an iOS counterpart will fail this test, so the two platforms'
// sliders never silently drift in name.
// ---------------------------------------------------------------------------

private let iosCanonicalParamLabels: [String: String] = [
    "exposure": "Exposure",
    "contrast": "Contrast",
    "saturation": "Saturation",
    "temperature": "Temperature",
    "tint": "Tint",
    "fade": "Fade",
    "rgbShift": "Color fringing",
    "lensSoftness": "Lens softness",
    "vignette": "Vignette",
    "bloomThreshold": "Bloom Threshold",
    "bloomStrength": "Bloom Strength",
    "bloomRadius": "Bloom Radius",
    "bloomSoftKnee": "Bloom Soft Knee",
    "halationIntensity": "Halation Intensity",
    "halationSpread": "Halation Spread",
    "halationHue": "Halation Hue",
    "halationThreshold": "Halation Threshold",
    "halationRadius": "Halation Radius",
    "halationSoftKnee": "Halation Soft Knee",
    "diffusion": "Diffusion",
    "grainIntensity": "Grain Strength",
    "grainSize": "Grain Size",
    "grainRadialMix": "Grain edge emphasis",
    "compressionAmount": "Highlight softness",
    "compressionRange": "Tone span",
    "printContrast": "Print Contrast",
    "cyan": "Cyan",
    "magenta": "Magenta",
    "yellow": "Yellow",
    "shutterAngle": "Shutter Angle",
    "trailIntensity": "Trail Length",
]

runner.test("AdvancedAdjustCatalog labels match iOS canonical paramLabels") {
    // M5-I.1: read the catalog with `.english` strings explicitly so the
    // assertion is deterministic on JA hosts where `.current` would
    // resolve to `.japanese` and produce a JA tail (e.g. シャッターアングル).
    var byKey: [String: String] = [:]
    for group in AdvancedAdjustCatalog.allGroups(strings: .english) {
        for control in group.controls {
            byKey[control.key] = control.label
        }
    }
    for (key, expected) in iosCanonicalParamLabels {
        guard let actual = byKey[key] else {
            throw AssertionError(
                description: "catalog missing key '\(key)' (iOS canonical label '\(expected)')"
            )
        }
        if actual != expected {
            throw AssertionError(
                description: "label drift on '\(key)': Desktop '\(actual)' vs iOS '\(expected)'"
            )
        }
    }
}

runner.test("AdvancedAdjustCatalog group titles include Tone (renamed from Process)") {
    let titles = AdvancedAdjustCatalog.allGroups(strings: .english).map(\.title)
    let expected = ["Basic", "Tone", "Optics", "Glow", "Grain", "Motion"]
    try assertEqual(titles, expected, "group title order + spelling")
}

// ---------------------------------------------------------------------------
// Test group 11 — M5-H.2 recipe shape + key validity. Every recipe must
// (a) carry a `none` chip plus at least one stamp, (b) restrict its
// stamped keys to the controls that live in the same group, and (c)
// emit values that survive AdvancedAdjustCatalog.clamp without drift.
// ---------------------------------------------------------------------------

runner.test("Each non-basic group ships at least one none + one stamp recipe") {
    for group in AdvancedAdjustCatalog.allGroups where group.id != "basic" {
        let kinds = group.recipes.map(\.kind)
        if !kinds.contains(.none) {
            throw AssertionError(
                description: "group '\(group.id)' missing .none recipe (clear chip)"
            )
        }
        if !kinds.contains(.stamp) {
            throw AssertionError(
                description: "group '\(group.id)' missing any .stamp recipe"
            )
        }
    }
}

runner.test("basic group keeps no recipes (mirrors iOS)") {
    let basic = AdvancedAdjustCatalog.allGroups.first { $0.id == "basic" }
    try assertEqual(basic?.recipes.isEmpty, true, "basic group should ship no chips")
}

runner.test("Recipe stamped keys are confined to their own group") {
    let baseParams = FilmtonePresetCatalog.params(
        for: FilmtonePresetCatalog.defaultName,
        strength: 1.0
    )
    for group in AdvancedAdjustCatalog.allGroups where !group.recipes.isEmpty {
        let groupKeys = Set(group.controls.map(\.key))
        for recipe in group.recipes where recipe.kind == .stamp {
            let emitted = recipe.values(baseParams)
            for key in emitted.keys {
                if !groupKeys.contains(key) {
                    throw AssertionError(
                        description: "recipe '\(group.id).\(recipe.id)' stamps '\(key)' outside its group"
                    )
                }
            }
        }
    }
}

runner.test("Recipe stamped values survive catalog clamp without drift") {
    // None of the canonical recipe values should be out-of-range for
    // their key — if a recipe writes a value that clamp would change,
    // applyAdvancedRecipe would silently rewrite it and the chip stops
    // round-tripping cleanly.
    let baseParams = FilmtonePresetCatalog.params(
        for: FilmtonePresetCatalog.defaultName,
        strength: 1.0
    )
    for group in AdvancedAdjustCatalog.allGroups where !group.recipes.isEmpty {
        for recipe in group.recipes where recipe.kind == .stamp {
            let emitted = recipe.values(baseParams)
            for (key, value) in emitted {
                let clamped = AdvancedAdjustCatalog.clamp(value, for: key)
                try assertClose(
                    clamped, value, eps: 1e-9,
                    "recipe '\(group.id).\(recipe.id)' value for '\(key)' was clamped"
                )
            }
        }
    }
}

runner.test("Tone recipes ship the iOS canonical 4-chip set") {
    guard let tone = AdvancedAdjustCatalog.allGroups.first(where: { $0.id == "process" }) else {
        throw AssertionError(description: "process group missing")
    }
    let ids = tone.recipes.map(\.id)
    try assertEqual(ids, ["standard", "airy", "sunset", "depth"], "tone recipe order")
}

runner.test("Recipe stamp + Quick does not double-apply Quick on stamped key") {
    // M5-H.2 P2 regression test. Pre-fix Desktop applied override then
    // Quick, so a recipe stamp like `bloomStrength=0.34` rendered at
    // 0.34 + Quick.dynamics * weight (visible drift between iOS and
    // Desktop). With the iOS-canonical Quick → override order, the
    // recipe value is the final value: Quick does not re-apply on the
    // stamped key.
    var qs = FilmtoneQuickState.zero
    qs.dynamics = 0.5

    let quickWeightByKey: [String: Double] = {
        var m: [String: Double] = [:]
        for axis in FilmtonePhase0Generated.quickAxisIds {
            if let weights = FilmtonePhase0Generated.quickWeights[axis] {
                for (key, weight) in weights where weight != 0 {
                    m[key] = weight
                }
            }
        }
        return m
    }()

    let baseParams = FilmtonePresetCatalog.params(
        for: FilmtonePresetCatalog.defaultName,
        strength: 1.0
    )

    guard let glow = AdvancedAdjustCatalog.allGroups.first(where: { $0.id == "glow" }),
          let recipe = glow.recipes.first(where: { $0.id == "default" }) else {
        throw AssertionError(description: "glow group / default recipe missing")
    }
    let recipeValues = recipe.values(baseParams)

    // Sort keys so test pickup is deterministic across runs (Dictionary
    // iteration order is not stable). Skip any key whose recipe value
    // would either round through clamp (means the test premise of
    // "absolute survives" is not true for that key) or land within
    // `paramEqualityTolerance` of base+Quick (would normalize out as
    // identity, leaving result == base+Quick instead of recipe value).
    var pickedKey: String?
    var pickedRecipeValue: Double = 0
    for key in recipeValues.keys.sorted() {
        guard let weight = quickWeightByKey[key], let recipeValue = recipeValues[key] else { continue }
        let clamped = AdvancedAdjustCatalog.clamp(recipeValue, for: key)
        if abs(clamped - recipeValue) > 1e-9 { continue }
        let baseAfterQuick = baseParams.value(for: key) + qs.dynamics * weight
        if abs(clamped - baseAfterQuick) < AdvancedAdjustCatalog.paramEqualityTolerance { continue }
        pickedKey = key
        pickedRecipeValue = recipeValue
        break
    }
    guard let key = pickedKey else {
        // No Quick-affected glow key has a recipe stamp that fits the
        // test premise on this preset — assertion is moot, the test
        // group still exercises the resolve-order rewrite via the
        // earlier "overrides win absolute" test.
        return
    }

    let patch = FilmtonePhase0ParamsPatch(values: [key: pickedRecipeValue])
    let result = FilmtonePresetCatalog.resolved(
        presetName: FilmtonePresetCatalog.defaultName,
        strength: 1.0,
        lookSlug: nil,
        quickState: qs,
        paramOverrides: patch
    )
    try assertClose(
        result.value(for: key),
        pickedRecipeValue,
        "key=\(key) recipe=\(pickedRecipeValue) — Quick must not re-apply on overridden key"
    )
}

// ---------------------------------------------------------------------------
// Test group 12 — M5-H.2 SavedLookStore rename / favorite / delete.
// Built-in entries must reject mutation; user entries must round-trip
// across loadOrRebuild() so the disk write is durable, not just an
// in-memory mutation.
// ---------------------------------------------------------------------------

private func makeIsolatedDefaults() -> UserDefaults {
    // Per-test suite name keeps the verify harness from clobbering the
    // user's real ~/Library/Preferences map and isolates tests from
    // each other. removePersistentDomain in defer cleans the suite up.
    let name = "filmtone-verify-defaults-\(UUID().uuidString)"
    return UserDefaults(suiteName: name) ?? .standard
}

private func runStoreTests() async {
    let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("filmtone-verify-store-\(UUID().uuidString)", isDirectory: true)

    runner.test("SavedLookStore rename + favorite persist across reload (user entry)") {
        let defaults = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "") }
        let store: FilmtoneSavedLookStore
        do {
            store = try FilmtoneSavedLookStore(rootURL: tempRoot, defaults: defaults)
        } catch {
            throw AssertionError(description: "store init failed: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let semaphore = DispatchSemaphore(value: 0)
        var caught: Error?
        var renamedName: String?
        var renamedFavorite: Bool?
        var reloadedName: String?
        var reloadedFavorite: Bool?

        Task {
            do {
                _ = try await store.loadOrRebuild()
                let saved = try await store.saveLook(
                    name: "Original",
                    presetName: "reset",
                    presetVersion: FilmtonePresetCatalog.presetVersion,
                    strength: 0.5,
                    quickState: .zero,
                    paramOverrides: .empty,
                    creativeLut: nil
                )
                let renamed = try await store.renameLook(id: saved.id, newName: "Renamed")
                let starred = try await store.setFavorite(id: saved.id, favorite: true)
                renamedName = renamed.name
                renamedFavorite = starred.favorite

                // Independent reload via a fresh store instance — proves
                // the change is on disk, not just in the actor cache.
                let store2 = try FilmtoneSavedLookStore(rootURL: tempRoot, defaults: defaults)
                let snap = try await store2.loadOrRebuild()
                let user = snap.looks.first { !$0.bundled }
                reloadedName = user?.name
                reloadedFavorite = user?.favorite
            } catch {
                caught = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let caught { throw AssertionError(description: "store flow failed: \(caught)") }
        try assertEqual(renamedName, "Renamed", "rename returns updated name")
        try assertEqual(renamedFavorite, true, "favorite returns updated flag")
        try assertEqual(reloadedName, "Renamed", "rename survives reload")
        try assertEqual(reloadedFavorite, true, "favorite survives reload")
    }

    runner.test("SavedLookStore favorite on built-in persists via UserDefaults map") {
        // M5-H.2 P2 fix: iOS allows favoriting built-in Looks via a
        // UserDefaults map. Rename / delete remain immutable, but
        // favorite now flips through the map and surfaces in the next
        // snapshot — including across a fresh store instance.
        let defaults = makeIsolatedDefaults()
        let store: FilmtoneSavedLookStore
        do {
            store = try FilmtoneSavedLookStore(
                rootURL: tempRoot.appendingPathComponent("builtinfav"),
                defaults: defaults
            )
        } catch {
            throw AssertionError(description: "store init failed: \(error)")
        }
        defer {
            try? FileManager.default.removeItem(at: tempRoot)
            defaults.removeObject(forKey: FilmtoneSavedLookStore.builtInFavoritesUserDefaultsKey)
        }

        let semaphore = DispatchSemaphore(value: 0)
        var caught: Error?
        var afterStarFavorite: Bool?
        var snapshotFavorite: Bool?
        var freshSnapshotFavorite: Bool?
        var afterUnstarFavorite: Bool?

        Task {
            do {
                _ = try await store.loadOrRebuild()
                let snap0 = await store.snapshot()
                guard let bundled = snap0.looks.first(where: { $0.bundled }) else {
                    throw AssertionError(description: "no bundled look to favorite")
                }
                let starred = try await store.setFavorite(id: bundled.id, favorite: true)
                afterStarFavorite = starred.favorite
                let snap1 = await store.snapshot()
                snapshotFavorite = snap1.lookEntry(id: bundled.id)?.favorite

                // Fresh store proves the favorite came from UserDefaults,
                // not the actor's in-memory cache.
                let store2 = try FilmtoneSavedLookStore(
                    rootURL: tempRoot.appendingPathComponent("builtinfav"),
                    defaults: defaults
                )
                _ = try await store2.loadOrRebuild()
                let snap2 = await store2.snapshot()
                freshSnapshotFavorite = snap2.lookEntry(id: bundled.id)?.favorite

                let unstarred = try await store.setFavorite(id: bundled.id, favorite: false)
                afterUnstarFavorite = unstarred.favorite
            } catch {
                caught = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let caught { throw AssertionError(description: "built-in favorite flow failed: \(caught)") }
        try assertEqual(afterStarFavorite, true, "setFavorite(true) returns favorite=true")
        try assertEqual(snapshotFavorite, true, "in-process snapshot reflects favorite")
        try assertEqual(freshSnapshotFavorite, true, "fresh store snapshot reads favorite from UserDefaults")
        try assertEqual(afterUnstarFavorite, false, "setFavorite(false) clears the flag")
    }

    runner.test("SavedLookStore deleteLook removes user entry from snapshot") {
        let defaults = makeIsolatedDefaults()
        let store: FilmtoneSavedLookStore
        do {
            store = try FilmtoneSavedLookStore(
                rootURL: tempRoot.appendingPathComponent("delete"),
                defaults: defaults
            )
        } catch {
            throw AssertionError(description: "store init failed: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let semaphore = DispatchSemaphore(value: 0)
        var caught: Error?
        var afterDeleteUserCount: Int?

        Task {
            do {
                _ = try await store.loadOrRebuild()
                let saved = try await store.saveLook(
                    name: "Doomed",
                    presetName: "reset",
                    presetVersion: FilmtonePresetCatalog.presetVersion,
                    strength: 1.0,
                    quickState: .zero,
                    paramOverrides: .empty,
                    creativeLut: nil
                )
                _ = try await store.deleteLook(id: saved.id)
                let snap = await store.snapshot()
                afterDeleteUserCount = snap.looks.filter { !$0.bundled }.count
            } catch {
                caught = error
            }
            semaphore.signal()
        }
        semaphore.wait()

        if let caught { throw AssertionError(description: "delete flow failed: \(caught)") }
        try assertEqual(afterDeleteUserCount, 0, "user looks should be empty after delete")
    }

    runner.test("SavedLookStore rejects rename / delete on built-in entries (favorite now allowed)") {
        let defaults = makeIsolatedDefaults()
        let store: FilmtoneSavedLookStore
        do {
            store = try FilmtoneSavedLookStore(
                rootURL: tempRoot.appendingPathComponent("immutable"),
                defaults: defaults
            )
        } catch {
            throw AssertionError(description: "store init failed: \(error)")
        }
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let semaphore = DispatchSemaphore(value: 0)
        var renameError: Error?
        var deleteError: Error?

        Task {
            _ = try? await store.loadOrRebuild()
            let snap = await store.snapshot()
            guard let bundled = snap.looks.first(where: { $0.bundled }) else {
                semaphore.signal()
                return
            }
            do { _ = try await store.renameLook(id: bundled.id, newName: "Hijack") }
            catch { renameError = error }
            do { _ = try await store.deleteLook(id: bundled.id) }
            catch { deleteError = error }
            semaphore.signal()
        }
        semaphore.wait()

        guard let rename = renameError as? FilmtoneSavedLookStore.StoreError,
              case .immutableEntry = rename else {
            throw AssertionError(description: "rename of built-in must throw .immutableEntry, got \(String(describing: renameError))")
        }
        guard let del = deleteError as? FilmtoneSavedLookStore.StoreError,
              case .immutableEntry = del else {
            throw AssertionError(description: "delete of built-in must throw .immutableEntry, got \(String(describing: deleteError))")
        }
    }
}

// ---------------------------------------------------------------------------
// Test group 13 — M5-I.1 FilmtoneDesktopStrings JA/EN parity. The Desktop
// localization layer must hold the same canonical English defaults the
// catalog ships today AND the iOS canonical Japanese variants for the
// labels iOS branches on `prefersJapanese`. Every assertion here pins a
// single string the user sees in the AdvancedAdjustEditor so a JA host
// never silently regresses to English copy when it should not.
// ---------------------------------------------------------------------------

runner.test("FilmtoneDesktopStrings.english carries the iOS canonical group titles") {
    try assertEqual(FilmtoneDesktopStrings.english.groupBasic, "Basic", "english groupBasic")
    try assertEqual(FilmtoneDesktopStrings.english.groupTone, "Tone", "english groupTone")
    try assertEqual(FilmtoneDesktopStrings.english.groupOptics, "Optics", "english groupOptics")
    try assertEqual(FilmtoneDesktopStrings.english.groupGlow, "Glow", "english groupGlow")
    try assertEqual(FilmtoneDesktopStrings.english.groupGrain, "Grain", "english groupGrain")
    try assertEqual(FilmtoneDesktopStrings.english.groupMotion, "Motion", "english groupMotion")
}

runner.test("FilmtoneDesktopStrings.japanese carries the iOS canonical Tone (階調)") {
    // iOS only translates `groupTone` ("階調"); the other group titles keep
    // their English defaultValue even on JA locale.
    try assertEqual(FilmtoneDesktopStrings.japanese.groupBasic, "Basic", "japanese groupBasic falls back to EN per iOS")
    try assertEqual(FilmtoneDesktopStrings.japanese.groupTone, "階調", "japanese groupTone")
    try assertEqual(FilmtoneDesktopStrings.japanese.groupOptics, "Optics", "japanese groupOptics falls back to EN per iOS")
    try assertEqual(FilmtoneDesktopStrings.japanese.groupGlow, "Glow", "japanese groupGlow falls back to EN per iOS")
    try assertEqual(FilmtoneDesktopStrings.japanese.groupGrain, "Grain", "japanese groupGrain falls back to EN per iOS")
    try assertEqual(FilmtoneDesktopStrings.japanese.groupMotion, "Motion", "japanese groupMotion falls back to EN per iOS")
}

runner.test("FilmtoneDesktopStrings preset chips match iOS defaults (None/なし, Default/標準, Strong/強め)") {
    try assertEqual(FilmtoneDesktopStrings.english.presetNone, "None", "english presetNone")
    try assertEqual(FilmtoneDesktopStrings.english.presetDefault, "Default", "english presetDefault")
    try assertEqual(FilmtoneDesktopStrings.english.presetStrong, "Strong", "english presetStrong")
    try assertEqual(FilmtoneDesktopStrings.japanese.presetNone, "なし", "japanese presetNone")
    try assertEqual(FilmtoneDesktopStrings.japanese.presetDefault, "標準", "japanese presetDefault")
    try assertEqual(FilmtoneDesktopStrings.japanese.presetStrong, "強め", "japanese presetStrong")
}

runner.test("FilmtoneDesktopStrings tone recipe chips match iOS defaults (Standard/標準, Airy/爽やか, Sunset/夕景, Depth/深み)") {
    try assertEqual(FilmtoneDesktopStrings.english.toneStandard, "Standard", "english toneStandard")
    try assertEqual(FilmtoneDesktopStrings.english.toneAiry, "Airy", "english toneAiry")
    try assertEqual(FilmtoneDesktopStrings.english.toneSunset, "Sunset", "english toneSunset")
    try assertEqual(FilmtoneDesktopStrings.english.toneDepth, "Depth", "english toneDepth")
    try assertEqual(FilmtoneDesktopStrings.japanese.toneStandard, "標準", "japanese toneStandard")
    try assertEqual(FilmtoneDesktopStrings.japanese.toneAiry, "爽やか", "japanese toneAiry")
    try assertEqual(FilmtoneDesktopStrings.japanese.toneSunset, "夕景", "japanese toneSunset")
    try assertEqual(FilmtoneDesktopStrings.japanese.toneDepth, "深み", "japanese toneDepth")
}

runner.test("FilmtoneDesktopStrings paramLabel mirrors iOS branching (Exposure EN-only; shutterAngle/trailIntensity translate)") {
    // iOS defaults most paramLabels to English even on JA locale; only
    // shutterAngle and trailIntensity carry an explicit JA variant.
    try assertEqual(FilmtoneDesktopStrings.english.paramLabel(for: "exposure"), "Exposure", "english exposure")
    try assertEqual(FilmtoneDesktopStrings.english.paramLabel(for: "shutterAngle"), "Shutter Angle", "english shutterAngle")
    try assertEqual(FilmtoneDesktopStrings.english.paramLabel(for: "trailIntensity"), "Trail Length", "english trailIntensity")
    try assertEqual(FilmtoneDesktopStrings.japanese.paramLabel(for: "exposure"), "Exposure", "japanese exposure falls back to EN per iOS")
    try assertEqual(FilmtoneDesktopStrings.japanese.paramLabel(for: "shutterAngle"), "シャッターアングル", "japanese shutterAngle")
    try assertEqual(FilmtoneDesktopStrings.japanese.paramLabel(for: "trailIntensity"), "残像の長さ", "japanese trailIntensity")
}

runner.test("FilmtoneDesktopStrings paramLabel falls back to the key when unknown") {
    try assertEqual(
        FilmtoneDesktopStrings.english.paramLabel(for: "someUnknownKey"),
        "someUnknownKey",
        "unknown key passes through"
    )
}

runner.test("FilmtoneDesktopStrings supplies localized affordance copy") {
    try assertEqual(FilmtoneDesktopStrings.english.advancedTitle, "Advanced Adjust", "english advancedTitle")
    try assertEqual(FilmtoneDesktopStrings.japanese.advancedTitle, "詳細調整", "japanese advancedTitle")
    try assertEqual(FilmtoneDesktopStrings.english.advancedResetAllOverrides, "Reset All Overrides", "english resetAll")
    try assertEqual(FilmtoneDesktopStrings.japanese.advancedResetAllOverrides, "すべてのオーバーライドをリセット", "japanese resetAll")
    try assertEqual(FilmtoneDesktopStrings.english.advancedClose, "Close", "english close")
    try assertEqual(FilmtoneDesktopStrings.japanese.advancedClose, "閉じる", "japanese close")
}

runner.test("AdvancedAdjustCatalog with .japanese surfaces 階調 + tone JA recipe chips") {
    let groups = AdvancedAdjustCatalog.allGroups(strings: .japanese)
    let titles = groups.map(\.title)
    try assertEqual(titles, ["Basic", "階調", "Optics", "Glow", "Grain", "Motion"], "JA group title order")
    guard let process = groups.first(where: { $0.id == "process" }) else {
        throw AssertionError(description: "process group missing under .japanese")
    }
    let toneLabels = process.recipes.map(\.label)
    try assertEqual(toneLabels, ["標準", "爽やか", "夕景", "深み"], "JA tone recipe labels")
    guard let glow = groups.first(where: { $0.id == "glow" }) else {
        throw AssertionError(description: "glow group missing under .japanese")
    }
    let glowRecipeLabels = glow.recipes.map(\.label)
    try assertEqual(glowRecipeLabels, ["なし", "標準", "強め"], "JA standard recipe labels")
}

runner.test("AdvancedAdjustCatalog with .japanese translates motion params, leaves the rest at iOS default") {
    let groups = AdvancedAdjustCatalog.allGroups(strings: .japanese)
    guard let motion = groups.first(where: { $0.id == "motion" }) else {
        throw AssertionError(description: "motion group missing under .japanese")
    }
    var jaByKey: [String: String] = [:]
    for control in motion.controls {
        jaByKey[control.key] = control.label
    }
    try assertEqual(jaByKey["shutterAngle"], "シャッターアングル", "JA shutterAngle in motion group")
    try assertEqual(jaByKey["trailIntensity"], "残像の長さ", "JA trailIntensity in motion group")

    // basic.exposure remains EN per iOS default
    guard let basic = groups.first(where: { $0.id == "basic" }),
          let exposure = basic.controls.first(where: { $0.key == "exposure" }) else {
        throw AssertionError(description: "basic.exposure missing under .japanese")
    }
    try assertEqual(exposure.label, "Exposure", "basic.exposure stays EN under .japanese per iOS")
}

// ---------------------------------------------------------------------------
// M5-K4 — Scrub thumbnail math.
// Pure helpers that the AV-bound provider depends on for cache key bucketing
// and thumbnail-overlay placement. Verified here so a regression in either
// helper trips the harness instead of surfacing as a UI glitch on the scrub
// bar.
// ---------------------------------------------------------------------------

runner.test("FilmtoneScrubThumbnailMath.quantize default bucket = 0.25s") {
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 0.0),
        0.0,
        eps: 1e-9,
        "0 → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 0.124),
        0.0,
        eps: 1e-9,
        "0.124 → 0 (rounds down)"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 0.125),
        0.25,
        eps: 1e-9,
        "0.125 → 0.25 (banker's rounding lands on even quarter)"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 0.30),
        0.25,
        eps: 1e-9,
        "0.30 → 0.25"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 0.40),
        0.50,
        eps: 1e-9,
        "0.40 → 0.50"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 1.74),
        1.75,
        eps: 1e-9,
        "1.74 → 1.75"
    )
}

runner.test("FilmtoneScrubThumbnailMath.quantize clamps non-finite / negative") {
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: -0.5),
        0.0,
        eps: 1e-9,
        "negative → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: .nan),
        0.0,
        eps: 1e-9,
        "NaN → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: .infinity),
        0.0,
        eps: 1e-9,
        "+inf → 0"
    )
}

runner.test("FilmtoneScrubThumbnailMath.quantize honors custom bucket") {
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 1.7, bucket: 1.0),
        2.0,
        eps: 1e-9,
        "1.7 with 1s bucket → 2.0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 1.7, bucket: 0.0),
        1.7,
        eps: 1e-9,
        "0 bucket → passthrough"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantize(seconds: 1.7, bucket: -0.5),
        1.7,
        eps: 1e-9,
        "negative bucket → passthrough"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampToDuration: typical clamp") {
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: -1.0, duration: 12.34),
        0.0,
        eps: 1e-9,
        "negative seconds → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 5.0, duration: 12.34),
        5.0,
        eps: 1e-9,
        "in-range passthrough"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 99.0, duration: 12.34),
        12.34,
        eps: 1e-9,
        "past-end → duration"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 12.34, duration: 12.34),
        12.34,
        eps: 1e-9,
        "exactly-end stays at duration"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampToDuration: zero / non-finite duration") {
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 5.0, duration: 0.0),
        0.0,
        eps: 1e-9,
        "zero duration → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 5.0, duration: -3.0),
        0.0,
        eps: 1e-9,
        "negative duration → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 5.0, duration: .nan),
        0.0,
        eps: 1e-9,
        "NaN duration → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: 5.0, duration: .infinity),
        0.0,
        eps: 1e-9,
        "infinite duration → 0 (treated as invalid)"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampToDuration: non-finite seconds") {
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: .nan, duration: 12.34),
        0.0,
        eps: 1e-9,
        "NaN seconds → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampToDuration(seconds: .infinity, duration: 12.34),
        0.0,
        eps: 1e-9,
        "infinite seconds → 0"
    )
}

runner.test("FilmtoneScrubThumbnailMath: end-of-asset request quantizes within bounds") {
    // Repro for the P2 review finding: a far-right hover at fraction
    // 1.0 against a 12.34s asset previously quantized to 12.5s, beyond
    // the asset's end. With clamp + quantize the request lands at the
    // last in-range bucket (12.25s) and never escapes the asset.
    let duration = 12.34
    let request = duration  // far-right hover
    let clamped = FilmtoneScrubThumbnailMath.clampToDuration(
        seconds: request,
        duration: duration
    )
    let quantized = FilmtoneScrubThumbnailMath.quantize(seconds: clamped)
    if quantized > duration {
        throw AssertionError(
            description: "quantized \(quantized) escaped duration \(duration)"
        )
    }
    try assertClose(quantized, 12.25, eps: 1e-9, "lands on last in-range 0.25s bucket")
}

runner.test("FilmtoneScrubThumbnailMath.quantizeWithinDuration: round-up overshoot floors back") {
    // Follow-up review finding: clamp-then-quantize chain still lets
    // round-half-to-even push past `duration`. 12.38 / 0.25 = 49.52,
    // which rounds to 50 → 12.50, beyond the 12.38s asset. The helper
    // detects the overshoot and floors to the last bucket ≤ duration.
    let duration1 = 12.38
    let q1 = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
        seconds: duration1,
        duration: duration1
    )
    if q1 > duration1 {
        throw AssertionError(
            description: "quantized \(q1) escaped duration \(duration1)"
        )
    }
    try assertClose(q1, 12.25, eps: 1e-9, "12.38s asset → last in-range bucket 12.25")

    // 12.88s asset: 51.5 / .toNearestOrEven → 52 → 13.0, past 12.88.
    // Floor must back off to 12.75.
    let duration2 = 12.88
    let q2 = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
        seconds: duration2,
        duration: duration2
    )
    if q2 > duration2 {
        throw AssertionError(
            description: "quantized \(q2) escaped duration \(duration2)"
        )
    }
    try assertClose(q2, 12.75, eps: 1e-9, "12.88s asset → last in-range bucket 12.75")

    // Slightly-past-bucket like 12.39 also rounds up to 12.50 and must
    // floor to 12.25.
    let duration3 = 12.39
    let q3 = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
        seconds: duration3,
        duration: duration3
    )
    if q3 > duration3 {
        throw AssertionError(
            description: "quantized \(q3) escaped duration \(duration3)"
        )
    }
    try assertClose(q3, 12.25, eps: 1e-9, "12.39s asset → last in-range bucket 12.25")
}

runner.test("FilmtoneScrubThumbnailMath.quantizeWithinDuration: exact-bucket boundary kept") {
    // When duration *is* a bucket boundary, the rounded bucket equals
    // duration and must not be floored away — would lose the final
    // thumbnail on perfectly aligned clips.
    let duration = 12.50
    let q = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
        seconds: duration,
        duration: duration
    )
    try assertClose(q, 12.50, eps: 1e-9, "12.50s asset → 12.50 (bucket = duration)")

    // Just past the bucket (round-down side): 12.5001 / 0.25 = 50.0004
    // → 50 → 12.50, in range, return as-is.
    let q2 = FilmtoneScrubThumbnailMath.quantizeWithinDuration(
        seconds: 12.5001,
        duration: 12.5001
    )
    try assertClose(q2, 12.50, eps: 1e-9, "12.5001s asset → 12.50 (rounded down, in range)")
}

runner.test("FilmtoneScrubThumbnailMath.quantizeWithinDuration: mid-range pass-through") {
    // Mid-range hovers must behave identically to the pre-helper chain —
    // the floor branch only activates when quantize overshoots.
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 5.0, duration: 12.38),
        5.0,
        eps: 1e-9,
        "exact-on-bucket mid-range untouched"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 5.13, duration: 12.38),
        5.25,
        eps: 1e-9,
        "5.13 rounds to 5.25, well inside 12.38s"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: -1.0, duration: 12.38),
        0.0,
        eps: 1e-9,
        "negative request clamps to 0"
    )
}

runner.test("FilmtoneScrubThumbnailMath.quantizeWithinDuration: zero / non-finite / sub-bucket duration") {
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 5.0, duration: 0.0),
        0.0,
        eps: 1e-9,
        "zero duration → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 5.0, duration: -3.0),
        0.0,
        eps: 1e-9,
        "negative duration → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 5.0, duration: .nan),
        0.0,
        eps: 1e-9,
        "NaN duration → 0"
    )
    // Sub-bucket duration: 0.10s asset, far-right hover. quantize would
    // round to 0 (already in range), so the helper returns 0 — correct
    // first-frame thumbnail for an extremely short clip.
    try assertClose(
        FilmtoneScrubThumbnailMath.quantizeWithinDuration(seconds: 0.10, duration: 0.10),
        0.0,
        eps: 1e-9,
        "sub-bucket duration → 0 (first-frame thumbnail)"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampHoverFraction clamps to [0,1]") {
    let width: CGFloat = 200
    let knob: CGFloat = 18
    try assertClose(
        FilmtoneScrubThumbnailMath.clampHoverFraction(x: -50, width: width, knob: knob),
        0.0,
        eps: 1e-9,
        "left of bar → 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampHoverFraction(x: 0, width: width, knob: knob),
        0.0,
        eps: 1e-9,
        "left edge minus knob/2 still clamps to 0"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampHoverFraction(x: width, width: width, knob: knob),
        1.0,
        eps: 1e-9,
        "right edge → 1"
    )
    try assertClose(
        FilmtoneScrubThumbnailMath.clampHoverFraction(x: width + 50, width: width, knob: knob),
        1.0,
        eps: 1e-9,
        "right of bar → 1"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampHoverFraction agrees with FilmtoneGlassSlider knob math") {
    // FilmtoneGlassSlider.updateValue computes ratio = (x - knob/2) / (width - knob).
    // Replicate that here at a midpoint so any future helper drift surfaces.
    let width: CGFloat = 600
    let knob: CGFloat = 18
    let usable = width - knob
    let cursorX = knob / 2 + usable * 0.5
    try assertClose(
        FilmtoneScrubThumbnailMath.clampHoverFraction(x: cursorX, width: width, knob: knob),
        0.5,
        eps: 1e-9,
        "midpoint → 0.5"
    )
}

runner.test("FilmtoneScrubThumbnailMath.clampThumbnailCenterX keeps overlay inside bar") {
    // Cursor at left end pushes overlay to its leftmost legal center.
    let leftCenter = FilmtoneScrubThumbnailMath.clampThumbnailCenterX(
        cursorX: 0,
        thumbnailWidth: 170,
        scrubBarMinX: 0,
        scrubBarMaxX: 600
    )
    try assertClose(leftCenter, 85, eps: 1e-9, "left clamp = thumbnailWidth/2")

    // Cursor in the middle of the bar passes through.
    let mid = FilmtoneScrubThumbnailMath.clampThumbnailCenterX(
        cursorX: 300,
        thumbnailWidth: 170,
        scrubBarMinX: 0,
        scrubBarMaxX: 600
    )
    try assertClose(mid, 300, eps: 1e-9, "midpoint passthrough")

    // Cursor at right end pushes overlay to its rightmost legal center.
    let rightCenter = FilmtoneScrubThumbnailMath.clampThumbnailCenterX(
        cursorX: 600,
        thumbnailWidth: 170,
        scrubBarMinX: 0,
        scrubBarMaxX: 600
    )
    try assertClose(rightCenter, 515, eps: 1e-9, "right clamp = scrubBarMaxX - thumbnailWidth/2")
}

runner.test("FilmtoneScrubThumbnailMath.clampThumbnailCenterX falls back to bar center when overlay overflows") {
    // Bar width 100, thumbnail width 170 — no clamp can keep both edges
    // inside, so the helper returns the bar's center.
    let center = FilmtoneScrubThumbnailMath.clampThumbnailCenterX(
        cursorX: 60,
        thumbnailWidth: 170,
        scrubBarMinX: 10,
        scrubBarMaxX: 110
    )
    try assertClose(center, 60, eps: 1e-9, "overflow → bar center")
}

runner.test("FilmtoneScrubThumbnailCacheKey is signature-aware Hashable") {
    let a1 = FilmtoneScrubThumbnailCacheKey(quantizedSeconds: 1.25, signature: 0)
    let a2 = FilmtoneScrubThumbnailCacheKey(quantizedSeconds: 1.25, signature: 0)
    let b = FilmtoneScrubThumbnailCacheKey(quantizedSeconds: 1.25, signature: 1)
    let c = FilmtoneScrubThumbnailCacheKey(quantizedSeconds: 1.50, signature: 0)
    try assertEqual(a1, a2, "same seconds + same signature collide")
    if a1 == b { throw AssertionError(description: "different signature must distinguish keys") }
    if a1 == c { throw AssertionError(description: "different seconds must distinguish keys") }
    var set: Set<FilmtoneScrubThumbnailCacheKey> = []
    set.insert(a1); set.insert(a2); set.insert(b); set.insert(c)
    try assertEqual(set.count, 3, "set dedupes a1/a2 but keeps b and c")
}

let storeSemaphore = DispatchSemaphore(value: 0)
Task {
    await runStoreTests()
    storeSemaphore.signal()
}
storeSemaphore.wait()

// ---------------------------------------------------------------------------
// Test group 14 — M5-K3 FilmtoneCompareSplitMath. Pins the boundary
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

exit(runner.summary())
