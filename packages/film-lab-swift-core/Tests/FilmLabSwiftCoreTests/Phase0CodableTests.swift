import XCTest
import FilmLabSwiftCore

final class Phase0CodableTests: XCTestCase {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: FilmtoneQuickState

    func testQuickStateRoundTrip() throws {
        let original = FilmtoneQuickState(filmCharacter: 0.4, era: -0.2, dynamics: 0.85)
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FilmtoneQuickState.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    func testQuickStateClampedToAxisRange() {
        let outOfRange = FilmtoneQuickState(filmCharacter: 2.5, era: -3.0, dynamics: 0.5).clamped()
        XCTAssertEqual(outOfRange.filmCharacter, FilmtonePhase0Generated.quickAxisMax)
        XCTAssertEqual(outOfRange.era, FilmtonePhase0Generated.quickAxisMin)
        XCTAssertEqual(outOfRange.dynamics, 0.5)
    }

    func testQuickStateValueForAxis() {
        let q = FilmtoneQuickState(filmCharacter: 0.1, era: 0.2, dynamics: 0.3)
        XCTAssertEqual(q.value(forAxis: "filmCharacter"), 0.1)
        XCTAssertEqual(q.value(forAxis: "era"), 0.2)
        XCTAssertEqual(q.value(forAxis: "dynamics"), 0.3)
        XCTAssertEqual(q.value(forAxis: "unknown"), 0)
    }

    // MARK: Phase0OutputProfileDTO

    func testOutputProfileRoundTrip() throws {
        let original = Phase0OutputProfileDTO(
            longEdge: 3840,
            fps: 30,
            codec: "h264",
            container: "mp4",
            preserveAudio: false
        )
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Phase0OutputProfileDTO.self, from: data)
        XCTAssertEqual(decoded, original)
    }

    // MARK: FilmtonePhase0Params

    func testParamsRoundTrip() throws {
        let original = FilmtonePhase0Generated.resetParams
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FilmtonePhase0Params.self, from: data)
        XCTAssertEqual(decoded, original)
        // detailSoftness was added in Phase 1 of the detail-softness lane; it
        // must round-trip with its default 0 like every other listed key.
        XCTAssertEqual(decoded.detailSoftness, original.detailSoftness)
        XCTAssertEqual(decoded.filmBreathAmount, original.filmBreathAmount)
    }

    func testParamsValueAndSetByKey() {
        var p = FilmtonePhase0Generated.resetParams
        p.setValue(0.42, for: "exposure")
        XCTAssertEqual(p.value(for: "exposure"), 0.42)

        // Unknown key is a silent no-op (canonical iOS contract).
        p.setValue(999, for: "nonexistentKey")
        XCTAssertEqual(p.value(for: "nonexistentKey"), 0)
    }

    func testParamsApplyingPatchOverridesOnlyListedKeys() {
        let base = FilmtonePhase0Generated.resetParams
        let patch = FilmtonePhase0ParamsPatch(values: [
            "exposure": 0.25,
            "saturation": 1.4
        ])
        let applied = base.applyingPatch(patch)
        XCTAssertEqual(applied.exposure, 0.25)
        XCTAssertEqual(applied.saturation, 1.4)
        XCTAssertEqual(applied.contrast, base.contrast)
        XCTAssertEqual(applied.grainIntensity, base.grainIntensity)
    }

    func testParamsApplyingNilPatchIsIdentity() {
        let base = FilmtonePhase0Generated.resetParams
        let applied = base.applyingPatch(nil)
        XCTAssertEqual(applied, base)
    }

    // MARK: FilmtonePhase0ParamsPatch

    func testPatchRoundTripPreservesListedKeysOnly() throws {
        // Mix listed paramKeys ("exposure", "fade") with an unknown key
        // ("madeUpKey") — the iOS-canonical custom Codable filters by
        // FilmtonePhase0Generated.paramKeys on both encode and decode, so the
        // unknown key must NOT survive the round trip.
        let original = FilmtonePhase0ParamsPatch(values: [
            "exposure": 0.18,
            "fade": 0.3,
            "detailSoftness": 0.12,
            "filmBreathAmount": 0.28,
            "madeUpKey": 9.9
        ])

        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FilmtonePhase0ParamsPatch.self, from: data)

        XCTAssertEqual(decoded.values["exposure"], 0.18)
        XCTAssertEqual(decoded.values["fade"], 0.3)
        XCTAssertEqual(decoded.values["detailSoftness"], 0.12)
        XCTAssertEqual(decoded.values["filmBreathAmount"], 0.28)
        XCTAssertNil(decoded.values["madeUpKey"])
        XCTAssertEqual(decoded.values.count, 4)
    }

    func testEmptyPatchRoundTrip() throws {
        let original = FilmtonePhase0ParamsPatch.empty
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(FilmtonePhase0ParamsPatch.self, from: data)
        XCTAssertTrue(decoded.isEmpty)
        XCTAssertEqual(decoded, original)
    }

    func testPatchDensifyingOpticsGlowFillsMissingKeysFromBase() {
        let base = FilmtonePhase0Generated.resetParams
        let sparse = FilmtonePhase0ParamsPatch(values: [
            "exposure": 0.1,
            "rgbShift": 0.9
        ])

        let dense = sparse.densifyingOpticsGlow(from: base)

        // Existing entry preserved (NOT overwritten by base).
        XCTAssertEqual(dense.values["rgbShift"], 0.9)
        // Non-optics-glow entry preserved.
        XCTAssertEqual(dense.values["exposure"], 0.1)

        // Every optics-glow key is now present, filled from base.
        for key in FilmtonePhase0ParamsPatch.opticsGlowKeys {
            XCTAssertNotNil(dense.values[key], "expected optics/glow key '\(key)' in densified patch")
        }
        // bloomStrength was missing → filled from base.
        XCTAssertEqual(dense.values["bloomStrength"], base.bloomStrength)
    }

    func testPatchRemovingValueDropsKey() {
        let p = FilmtonePhase0ParamsPatch(values: ["exposure": 0.2, "fade": 0.5])
        let removed = p.removingValue(for: "exposure")
        XCTAssertNil(removed.values["exposure"])
        XCTAssertEqual(removed.values["fade"], 0.5)
    }
}
