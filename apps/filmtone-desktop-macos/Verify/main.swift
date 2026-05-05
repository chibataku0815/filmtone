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
    var byKey: [String: String] = [:]
    for group in AdvancedAdjustCatalog.allGroups {
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
    let titles = AdvancedAdjustCatalog.allGroups.map(\.title)
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

let storeSemaphore = DispatchSemaphore(value: 0)
Task {
    await runStoreTests()
    storeSemaphore.signal()
}
storeSemaphore.wait()

exit(runner.summary())
