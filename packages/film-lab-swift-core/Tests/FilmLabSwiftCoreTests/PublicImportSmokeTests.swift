import XCTest
import FilmLabSwiftCore

/// Pins the public API surface that Desktop / iOS will reach via plain
/// `import FilmLabSwiftCore` in M4-B Phase 2 / Phase 3.
///
/// This file deliberately uses the non-`@testable` import: every symbol it
/// touches must be accessible at module-public access, not internal. If a
/// symbol drops to internal in a future refactor, this file fails to compile
/// and the cross-module wiring planned for Phase 2 is caught before it
/// silently breaks.
final class PublicImportSmokeTests: XCTestCase {
    func testQuickStateZeroIsReachableFromPublicAPI() {
        let zero = FilmtoneQuickState.zero
        XCTAssertEqual(zero.filmCharacter, 0)
        XCTAssertEqual(zero.era, 0)
        XCTAssertEqual(zero.dynamics, 0)
    }

    func testGeneratedResetParamsIsReachableFromPublicAPI() {
        let reset = FilmtonePhase0Generated.resetParams
        // Spot-check one stored property so the field is reachable too —
        // not just the static let.
        XCTAssertEqual(reset.exposure, 0.0)
    }

    func testPatchEmptyIsReachableFromPublicAPI() {
        let empty = FilmtonePhase0ParamsPatch.empty
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(empty.values.count, 0)
    }

    func testOutputProfileMemberwiseInitIsPublic() {
        // Calls the explicit public init(...) on the package's
        // Phase0OutputProfileDTO — auto-synthesized memberwise inits are
        // internal even when stored properties are public, so this would
        // fail to compile without the explicit `public init(...)`.
        let profile = Phase0OutputProfileDTO(
            longEdge: 1080,
            fps: 30,
            codec: "h264",
            container: "mp4",
            preserveAudio: false
        )
        XCTAssertEqual(profile.longEdge, 1080)
        XCTAssertEqual(profile.fps, 30)
        XCTAssertEqual(profile.codec, "h264")
        XCTAssertEqual(profile.container, "mp4")
        XCTAssertFalse(profile.preserveAudio)
    }

    func testHiddenDefaultsFieldIsReachableFromPublicAPI() {
        // hiddenDefaults landmark is one of the iOS canonical CD-gated
        // values (per apps/capacitor-film-lab-ios/CLAUDE.md §4 invariants).
        // If FilmtonePhase0HiddenDefaults' fields drop to internal, this
        // line fails to compile.
        XCTAssertEqual(FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma, 1.4)
    }
}
