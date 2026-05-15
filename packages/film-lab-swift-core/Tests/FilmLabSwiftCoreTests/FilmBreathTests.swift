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
            XCTAssertLessThanOrEqual(abs(offsets.exposure), 0.16)
            XCTAssertLessThanOrEqual(abs(offsets.contrast), 0.055)
            XCTAssertLessThanOrEqual(abs(offsets.temperature), 0.09)
            XCTAssertLessThanOrEqual(abs(offsets.tint), 0.04)
        }
    }

    func testMaximumAmountIsVisuallyInspectableOnRepresentativeFrames() {
        let offsets = FilmtoneFilmBreath.deriveOffsets(
            amount: 1,
            timeSeconds: 24.72,
            sourceSeed: 7331
        )
        let visibleEnergy = abs(offsets.exposure) +
            abs(offsets.contrast) +
            abs(offsets.temperature) +
            abs(offsets.tint)

        XCTAssertGreaterThan(visibleEnergy, 0.08)
    }

    func testAdjacentFramesStaySmooth() {
        var previous = FilmtoneFilmBreath.deriveOffsets(amount: 1, timeSeconds: 1.0 / 24.0, sourceSeed: 99)
        for frame in 2..<(24 * 30) {
            let current = FilmtoneFilmBreath.deriveOffsets(
                amount: 1,
                timeSeconds: Double(frame) / 24.0,
                sourceSeed: 99
            )
            XCTAssertLessThan(abs(current.exposure - previous.exposure), 0.011)
            XCTAssertLessThan(abs(current.contrast - previous.contrast), 0.0042)
            XCTAssertLessThan(abs(current.temperature - previous.temperature), 0.006)
            XCTAssertLessThan(abs(current.tint - previous.tint), 0.003)
            previous = current
        }
    }
}
