import XCTest
import FilmLabSwiftCore

final class ShadowLatitudeTests: XCTestCase {

    func testIdentityAtZero() {
        let sample = FilmtoneShadowLatitudeRgb(r: 0.08, g: 0.12, b: 0.16)
        let out = FilmtoneShadowLatitude.apply(rgb: sample, amount: 0)
        XCTAssertEqual(out, sample)
    }

    func testDeepBlackAnchor() {
        let samples = [
            FilmtoneShadowLatitudeRgb(r: 0, g: 0, b: 0),
            FilmtoneShadowLatitudeRgb(r: 0.025, g: 0.025, b: 0.025),
            FilmtoneShadowLatitudeRgb(r: 0.04, g: 0.02, b: 0.01),
        ]
        for sample in samples {
            XCTAssertLessThanOrEqual(FilmtoneShadowLatitude.luma(sample), 0.025)
            let out = FilmtoneShadowLatitude.apply(rgb: sample, amount: 1, clampOutput: true)
            XCTAssertLessThanOrEqual(maxDelta(sample, out), 0.002)
        }
    }

    func testLowMidShadowGainsSeparationAndMidtonesRelease() {
        for value in [0.06, 0.10, 0.18] {
            let sample = FilmtoneShadowLatitudeRgb(r: value, g: value, b: value)
            let out = FilmtoneShadowLatitude.apply(rgb: sample, amount: 1, clampOutput: true)
            XCTAssertGreaterThan(FilmtoneShadowLatitude.luma(out), FilmtoneShadowLatitude.luma(sample))
        }

        for value in [0.30, 0.42, 0.70] {
            let sample = FilmtoneShadowLatitudeRgb(r: value, g: value, b: value)
            let out = FilmtoneShadowLatitude.apply(rgb: sample, amount: 1, clampOutput: true)
            XCTAssertLessThanOrEqual(maxDelta(sample, out), 0.003)
        }
    }

    func testSwiftMirrorMatchesTsReferenceSamples() {
        let samples: [(FilmtoneShadowLatitudeRgb, FilmtoneShadowLatitudeRgb)] = [
            (
                FilmtoneShadowLatitudeRgb(r: 0.035, g: 0.12, b: 0.045),
                FilmtoneShadowLatitudeRgb(r: 0.04448099505626667, g: 0.13628099505626667, b: 0.05528099505626666)
            ),
            (
                FilmtoneShadowLatitudeRgb(r: 0.055, g: 0.085, b: 0.15),
                FilmtoneShadowLatitudeRgb(r: 0.06597374790166667, g: 0.09837374790166668, b: 0.16857374790166668)
            ),
            (
                FilmtoneShadowLatitudeRgb(r: 0.16, g: 0.095, b: 0.055),
                FilmtoneShadowLatitudeRgb(r: 0.17940133037526668, g: 0.10920133037526666, b: 0.06600133037526665)
            ),
            (
                FilmtoneShadowLatitudeRgb(r: 0.1, g: 0.1, b: 0.1),
                FilmtoneShadowLatitudeRgb(r: 0.11466666666666667, g: 0.11466666666666667, b: 0.11466666666666667)
            ),
        ]

        for (rgb, expected) in samples {
            let out = FilmtoneShadowLatitude.apply(rgb: rgb, amount: 1, clampOutput: true)
            XCTAssertEqual(out.r, expected.r, accuracy: 1e-12)
            XCTAssertEqual(out.g, expected.g, accuracy: 1e-12)
            XCTAssertEqual(out.b, expected.b, accuracy: 1e-12)
        }
    }

    func testConstantsMatchTsMirror() {
        XCTAssertEqual(FilmtoneShadowLatitude.blackAnchor, 0.025)
        XCTAssertEqual(FilmtoneShadowLatitude.mainBandStart, 0.055)
        XCTAssertEqual(FilmtoneShadowLatitude.mainBandEnd, 0.18)
        XCTAssertEqual(FilmtoneShadowLatitude.releaseEnd, 0.30)
        XCTAssertEqual(FilmtoneShadowLatitude.lumaGainMax, 0.22)
        XCTAssertEqual(FilmtoneShadowLatitude.chromaRetentionMax, 0.08)
    }

    private func maxDelta(_ a: FilmtoneShadowLatitudeRgb, _ b: FilmtoneShadowLatitudeRgb) -> Double {
        max(abs(a.r - b.r), max(abs(a.g - b.g), abs(a.b - b.b)))
    }
}
