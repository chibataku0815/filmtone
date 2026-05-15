import XCTest
import FilmLabSwiftCore

final class FilmBreathTests: XCTestCase {
    func testIdentityWhenAmountOrTimeIsZero() {
        XCTAssertEqual(
            FilmtoneFilmBreath.deriveOffsets(amount: 0, timeSeconds: 12.5, sourceSeed: 42),
            .zero
        )
        XCTAssertEqual(
            FilmtoneFilmBreath.deriveOffsets(amount: 0.7, timeSeconds: 0, sourceSeed: 42),
            .zero
        )
        var params = FilmtonePhase0Generated.resetParams
        params.filmBreathAmount = 0.7
        XCTAssertEqual(
            FilmtoneFilmBreath.applying(to: params, timeSeconds: 0, sourceSeed: 42),
            params
        )
    }

    func testDeterministicAndBounded() {
        let first = FilmtoneFilmBreath.deriveOffsets(amount: 1, timeSeconds: 8.25, sourceSeed: 1234)
        let second = FilmtoneFilmBreath.deriveOffsets(amount: 1, timeSeconds: 8.25, sourceSeed: 1234)
        XCTAssertEqual(first, second)

        for frame in stride(from: 1, to: 24 * 90, by: 7) {
            let offsets = FilmtoneFilmBreath.deriveOffsets(
                amount: 1,
                timeSeconds: Double(frame) / 24.0,
                sourceSeed: 7331
            )
            XCTAssertLessThanOrEqual(abs(offsets.exposure), 0.5)
            XCTAssertLessThanOrEqual(abs(offsets.contrast), 0.15)
            XCTAssertLessThanOrEqual(abs(offsets.temperature), 0.22)
            XCTAssertLessThanOrEqual(abs(offsets.tint), 0.12)
        }
    }

    func testMaximumAmountIsVisiblyModulatingExposureAtTheRegressionFrame() {
        let offsets = FilmtoneFilmBreath.deriveOffsets(
            amount: 1,
            timeSeconds: 24.72,
            sourceSeed: 7331
        )
        XCTAssertGreaterThan(abs(offsets.exposure), 0.15)
    }

    func testMaximumAmountStaysAboveVisibleFloorAcrossPlaybackWindow() {
        let timestamps: [Double] = [2, 5, 10, 15, 20, 24.72, 30, 45, 60, 90]
        var exposureHits = 0
        var temperatureHits = 0
        for t in timestamps {
            let offsets = FilmtoneFilmBreath.deriveOffsets(amount: 1, timeSeconds: t, sourceSeed: 7331)
            if abs(offsets.exposure) > 0.15 { exposureHits += 1 }
            if abs(offsets.temperature) > 0.05 { temperatureHits += 1 }
        }
        XCTAssertGreaterThanOrEqual(exposureHits, 6)
        XCTAssertGreaterThanOrEqual(temperatureHits, 6)
    }

    func testAdjacentFramesStaySmooth() {
        var previous = FilmtoneFilmBreath.deriveOffsets(amount: 1, timeSeconds: 1.0 / 24.0, sourceSeed: 99)
        for frame in 2..<(24 * 30) {
            let current = FilmtoneFilmBreath.deriveOffsets(
                amount: 1,
                timeSeconds: Double(frame) / 24.0,
                sourceSeed: 99
            )
            XCTAssertLessThan(abs(current.exposure - previous.exposure), 0.05)
            XCTAssertLessThan(abs(current.contrast - previous.contrast), 0.018)
            XCTAssertLessThan(abs(current.temperature - previous.temperature), 0.022)
            XCTAssertLessThan(abs(current.tint - previous.tint), 0.012)
            previous = current
        }
    }
}
