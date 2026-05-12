import XCTest
import FilmLabSwiftCore

// Mirror of packages/film-lab-core/src/detail-softness.test.ts.
// Any drift in expected values is a Phase 2 parity failure.

final class DetailSoftnessUniformsTests: XCTestCase {

    func testIdentityAtZero() {
        let u = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0)
        XCTAssertEqual(u.effectiveDetailSoftness, 0)
        XCTAssertGreaterThanOrEqual(u.kernelRadiusPx, 0.62)
        XCTAssertLessThanOrEqual(u.kernelRadiusPx, 2.0)
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: -0.1).effectiveDetailSoftness,
            0
        )
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: -1.0).effectiveDetailSoftness,
            0
        )
    }

    func testAboveMaxClampsToEffectiveMax() {
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.5).effectiveDetailSoftness,
            FilmtoneDetailSoftness.effectiveMax
        )
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 1.0).effectiveDetailSoftness,
            FilmtoneDetailSoftness.effectiveMax
        )
    }

    func testSourceDetailBiasDefaultsToZero() {
        let a = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.18)
        let b = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.18, sourceDetailBias: 0)
        XCTAssertEqual(a.effectiveDetailSoftness, b.effectiveDetailSoftness)
        XCTAssertEqual(a.effectiveDetailSoftness, 0.18, accuracy: 1e-12)
    }

    func testSourceDetailBiasSumsThenClamps() {
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(
                detailSoftness: 0.3,
                sourceDetailBias: 0.3
            ).effectiveDetailSoftness,
            FilmtoneDetailSoftness.effectiveMax
        )
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(
                detailSoftness: 0.1,
                sourceDetailBias: 0.1
            ).effectiveDetailSoftness,
            0.2,
            accuracy: 1e-12
        )
        XCTAssertEqual(
            FilmtoneDetailSoftness.deriveUniforms(
                detailSoftness: 0,
                sourceDetailBias: -0.5
            ).effectiveDetailSoftness,
            0
        )
    }

    func testKernelRadiusMonotonic() {
        let samples = [0.0, 0.05, 0.1, 0.18, 0.24, 0.3, 0.34, 0.45].map {
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: $0)
        }
        for index in 1..<samples.count {
            XCTAssertGreaterThanOrEqual(
                samples[index].kernelRadiusPx,
                samples[index - 1].kernelRadiusPx
            )
        }
        XCTAssertEqual(samples.first!.kernelRadiusPx, 0.62, accuracy: 1e-12)
        XCTAssertEqual(samples.last!.kernelRadiusPx, 2.0, accuracy: 1e-12)
    }

    func testParityConstants() {
        // Any change here is a Phase 5 tuning concern and must update the TS
        // helper, the Swift mirror, and every shader port in lockstep.
        let u = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.18)
        XCTAssertEqual(u.chromaAttenScale, 0.7)
        XCTAssertEqual(u.edgeGuardLo, 0.04)
        XCTAssertEqual(u.edgeGuardHi, 0.2)
        XCTAssertEqual(u.highlightBias, 1.18)
    }
}
