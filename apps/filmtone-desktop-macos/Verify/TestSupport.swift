import FilmLabSwiftCore
import Foundation

// M5-C.3a verification harness — exercises the Quick adjust + saved-Look
// round-trip wiring without booting the SwiftUI app. Compiled standalone
// via `Verify/run.sh` against a pure-Foundation subset of FilmtoneDesktop
// sources. Asserts the math + serialization invariants so a green run
// gives confidence that user visual checks 2 / 4 / 5 (and the logic
// behind 1 / 3) are sound — only the actual GUI tap-through remains
// for the user.

final class TestRunner {
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

struct AssertionError: Error, CustomStringConvertible {
    let description: String
}

func assertEqual<T: Equatable>(_ a: T, _ b: T, _ msg: String = "") throws {
    if a != b {
        throw AssertionError(description: "\(msg) — expected \(b), got \(a)")
    }
}

func assertClose(_ a: Double, _ b: Double, eps: Double = 1e-9, _ msg: String = "") throws {
    if abs(a - b) > eps {
        throw AssertionError(description: "\(msg) — expected \(b), got \(a) (diff \(a - b))")
    }
}

func assertParamsEqual(_ a: FilmtonePhase0Params,
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

struct StubSidecarRequest: FilmtoneSidecarRequest {
    let sourceURL: URL
    let outputURL: URL
    let presetName: String
    let presetStrength: Double
    let lookSlug: String?
    let sourceKind: FilmtoneSourceKind
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    var highlightMarkers: FilmtoneHighlightMarkers? = nil
    let opticalFilterProfileId: String? = nil
}

let runner = TestRunner()

