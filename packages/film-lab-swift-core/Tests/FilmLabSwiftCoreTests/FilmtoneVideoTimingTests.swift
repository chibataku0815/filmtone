import XCTest
@testable import FilmLabSwiftCore

final class FilmtoneVideoTimingTests: XCTestCase {
    func testSlow24EligibilityAndSpeedMath() {
        let sixty = FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: 60)
        XCTAssertEqual(sixty.resolvedMode, .slow24)
        XCTAssertEqual(sixty.targetFPS, 24)
        XCTAssertEqual(sixty.speedMultiplier, 0.4, accuracy: 1e-12)
        XCTAssertEqual(sixty.displayDuration(sourceDuration: 1) ?? .nan, 2.5, accuracy: 1e-12)
        XCTAssertEqual(sixty.sourceTime(forDisplayTime: 1.25), 0.5, accuracy: 1e-12)
        XCTAssertEqual(sixty.displayTime(forSourceTime: 0.5), 1.25, accuracy: 1e-12)

        let thirty = FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: 30)
        XCTAssertEqual(thirty.resolvedMode, .slow24)
        XCTAssertEqual(thirty.speedMultiplier, 0.8, accuracy: 1e-12)
    }

    func testSlow24FallsBackFor24fpsAndUnknownSources() {
        XCTAssertEqual(
            FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: 24).resolvedMode,
            .normal
        )
        XCTAssertEqual(
            FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: 23.976).resolvedMode,
            .normal
        )
        XCTAssertEqual(
            FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: nil).resolvedMode,
            .normal
        )
    }

    func testSlow24MetadataMarksSilentOutput() {
        let policy = FilmtoneVideoTimingPolicy(mode: .slow24, sourceFPS: 60)
        let metadata = FilmtoneVideoTimingMetadataDTO.make(
            policy: policy,
            sourceDurationSec: 1,
            sourceFrameCount: 60
        )
        XCTAssertEqual(metadata.videoTimingMode, "slow24")
        XCTAssertEqual(metadata.sourceFps, 60)
        XCTAssertEqual(metadata.targetFps, 24)
        XCTAssertEqual(metadata.outputDurationSec, 2.5)
        XCTAssertEqual(metadata.audioPolicy, "none")
    }
}
