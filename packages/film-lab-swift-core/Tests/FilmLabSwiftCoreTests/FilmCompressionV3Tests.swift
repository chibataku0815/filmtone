import XCTest
import FilmLabSwiftCore

final class FilmCompressionV3Tests: XCTestCase {

    func testIdentityAtZero() {
        let sample = FilmtoneFilmCompressionRgb(r: 0.95, g: 0.72, b: 0.36)
        let out = FilmtoneFilmCompressionV3.apply(rgb: sample, amount: 0, range: 0.5)
        XCTAssertEqual(out, sample)
    }

    func testNeutralGrayRemainsNeutral() {
        for value in [0.0, 0.08, 0.18, 0.5, 0.82, 1.0] {
            let out = FilmtoneFilmCompressionV3.apply(
                rgb: FilmtoneFilmCompressionRgb(r: value, g: value, b: value),
                amount: 0.8,
                range: 0.62,
                clampOutput: true
            )
            XCTAssertEqual(out.r, out.g, accuracy: 1e-12)
            XCTAssertEqual(out.g, out.b, accuracy: 1e-12)
        }
    }

    func testSwiftMirrorMatchesTsReferenceSamples() {
        let samples: [(FilmtoneFilmCompressionRgb, Double, Double, FilmtoneFilmCompressionRgb)] = [
            (
                FilmtoneFilmCompressionRgb(r: 0.92, g: 0.63, b: 0.48),
                0.9,
                0.55,
                FilmtoneFilmCompressionRgb(
                    r: 0.8856961209774066,
                    g: 0.6241051081623576,
                    b: 0.48879941187871173
                )
            ),
            (
                FilmtoneFilmCompressionRgb(r: 0.18, g: 1.0, b: 1.0),
                0.85,
                0.6,
                FilmtoneFilmCompressionRgb(
                    r: 0.4599138921821231,
                    g: 0.8680290715974506,
                    b: 0.8680290715974506
                )
            ),
            (
                // Shadow sample: one-sided shoulder leaves deep blacks
                // identical so chroma stays at 100% and luma is not lifted.
                FilmtoneFilmCompressionRgb(r: 0.05, g: 0.1, b: 0.15),
                0.9,
                0.65,
                FilmtoneFilmCompressionRgb(
                    r: 0.05,
                    g: 0.1,
                    b: 0.15
                )
            ),
            (
                FilmtoneFilmCompressionRgb(r: 1.0, g: 0.05, b: 0.04),
                0.95,
                0.58,
                FilmtoneFilmCompressionRgb(
                    r: 0.8869029151895078,
                    g: 0.08039799843465117,
                    b: 0.07190847299512637
                )
            ),
        ]

        for (rgb, amount, range, expected) in samples {
            let out = FilmtoneFilmCompressionV3.apply(
                rgb: rgb,
                amount: amount,
                range: range,
                clampOutput: true
            )
            XCTAssertEqual(out.r, expected.r, accuracy: 1e-12)
            XCTAssertEqual(out.g, expected.g, accuracy: 1e-12)
            XCTAssertEqual(out.b, expected.b, accuracy: 1e-12)
        }
    }

    func testConstantsMatchTsMirror() {
        XCTAssertEqual(FilmtoneFilmCompressionV3.chromaCompressionMax, 0.42)
        XCTAssertEqual(FilmtoneFilmCompressionV3.problemColorGuardMax, 0.22)
        XCTAssertEqual(FilmtoneFilmCompressionV3.warmProtectStrength, 0.35)
        XCTAssertEqual(FilmtoneFilmCompressionV3.shadowReleaseStart, 0.14)
        XCTAssertEqual(FilmtoneFilmCompressionV3.shadowReleaseEnd, 0.30)
        XCTAssertEqual(FilmtoneFilmCompressionV3.highlightDensityLandingStart, 0.78)
        XCTAssertEqual(FilmtoneFilmCompressionV3.highlightDensityLandingStrength, 0.88)
    }
}
