import XCTest
import FilmLabSwiftCore

// Mirror of packages/film-lab-core/src/detail-softness.test.ts.
// Any drift in expected values is a Phase 5-B parity failure.

final class DetailSoftnessUniformsTests: XCTestCase {

    func testIdentityAtZero() {
        let u = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0)
        XCTAssertEqual(u.effectiveDetailSoftness, 0)
        XCTAssertGreaterThanOrEqual(u.kernelRadiusPx, 1.0)
        XCTAssertLessThanOrEqual(u.kernelRadiusPx, 2.5)
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
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.7).effectiveDetailSoftness,
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
                detailSoftness: 0.4,
                sourceDetailBias: 0.4
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
        let samples = [0.0, 0.05, 0.1, 0.18, 0.3, 0.45, 0.55, 0.65].map {
            FilmtoneDetailSoftness.deriveUniforms(detailSoftness: $0)
        }
        for index in 1..<samples.count {
            XCTAssertGreaterThanOrEqual(
                samples[index].kernelRadiusPx,
                samples[index - 1].kernelRadiusPx
            )
        }
        XCTAssertEqual(samples.first!.kernelRadiusPx, 1.0, accuracy: 1e-12)
        XCTAssertEqual(samples.last!.kernelRadiusPx, 2.5, accuracy: 1e-12)
    }

    func testParityConstants() {
        // Any change here is a Phase 5-B tuning concern and must update the TS
        // helper, the Swift mirror, and every shader port in lockstep.
        let u = FilmtoneDetailSoftness.deriveUniforms(detailSoftness: 0.18)
        XCTAssertEqual(u.rangeSigma, 0.07)
        XCTAssertEqual(u.detailAmplitudeLo, 0.0)
        XCTAssertEqual(u.detailAmplitudeHi, 0.05)
        XCTAssertEqual(u.chromaAttenScale, 0.7)
        XCTAssertEqual(u.highlightBias, 1.18)
    }
}
