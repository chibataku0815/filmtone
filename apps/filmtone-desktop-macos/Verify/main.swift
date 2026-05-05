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
// Test group 6 — Resolution order (M5-C.3a invariant).
// iOS canonical: interpolate → applyingPatch(paramOverrides) → applyQuickState.
// paramOverrides MUST land before quickState; if a key appears in both,
// the final value should be (overrideValue + axisValue * weight).
// ---------------------------------------------------------------------------

runner.test("paramOverrides then quickState — ordering matches iOS canonical") {
    // Find a (axis, key) pair with a non-zero weight to test ordering on.
    var pickedAxis: String? = nil
    var pickedKey: String? = nil
    var pickedWeight: Double = 0
    outer: for axis in FilmtonePhase0Generated.quickAxisIds {
        guard let weights = FilmtonePhase0Generated.quickWeights[axis] else { continue }
        for (key, weight) in weights where weight != 0 {
            pickedAxis = axis
            pickedKey = key
            pickedWeight = weight
            break outer
        }
    }
    guard let axis = pickedAxis, let key = pickedKey else {
        throw AssertionError(description: "no non-zero quickWeight to test")
    }
    let absoluteValue = 0.123
    var qs = FilmtoneQuickState.zero
    switch axis {
    case "filmCharacter": qs.filmCharacter = 0.5
    case "era": qs.era = 0.5
    case "dynamics": qs.dynamics = 0.5
    default: throw AssertionError(description: "unknown axis")
    }
    let patch = FilmtonePhase0ParamsPatch(values: [key: absoluteValue])
    let result = FilmtonePresetCatalog.resolved(
        presetName: "reset",
        strength: 1.0,
        lookSlug: nil,
        quickState: qs,
        paramOverrides: patch
    )
    let expected = absoluteValue + 0.5 * pickedWeight
    try assertClose(
        result.value(for: key),
        expected,
        "axis=\(axis) key=\(key) override=\(absoluteValue) +0.5*\(pickedWeight)"
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

exit(runner.summary())
