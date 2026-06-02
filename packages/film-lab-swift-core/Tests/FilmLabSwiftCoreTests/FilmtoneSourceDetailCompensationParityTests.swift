import XCTest
import FilmLabSwiftCore

// Parity tests against the TS resolver in
// packages/film-lab-core/src/source-detail-compensation.test.ts.
// Bias values, ids, transfer classes, and cascade behavior must match
// row-for-row so macOS native + iOS export resolve a metadata bundle
// the same way the TS resolver does.

final class FilmtoneSourceDetailCompensationParityTests: XCTestCase {

    // MARK: - Tuning table parity

    func testIPhoneSdrHevcModestPositive() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Apple",
                cameraModel: "iPhone 17 Pro",
                codecFamily: "hevc",
                colorClass: "sdr-bt709"
            )
        )
        XCTAssertEqual(profile.id, .iphoneSdrHevc)
        XCTAssertEqual(profile.transferClass, .rec709Consumer)
        XCTAssertEqual(profile.confidence, .high)
        XCTAssertEqual(profile.recommendedBias, 0.10, accuracy: 1e-12)
    }

    func testIPhoneViaCameraModelOnly() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraModel: "iPhone 15",
                codecFamily: "hevc"
            )
        )
        XCTAssertEqual(profile.id, .iphoneSdrHevc)
        XCTAssertEqual(profile.recommendedBias, 0.10, accuracy: 1e-12)
    }

    func testAppleLogViaLogTransferFunction() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Apple",
                cameraModel: "iPhone 17 Pro",
                logTransferFunction: "apple-log",
                codecFamily: "prores-422",
                colorClass: "apple-log"
            )
        )
        XCTAssertEqual(profile.id, .appleLog)
        XCTAssertEqual(profile.transferClass, .logConsumer)
        XCTAssertEqual(profile.confidence, .high)
        XCTAssertEqual(profile.recommendedBias, 0.06, accuracy: 1e-12)
    }

    func testAppleLogViaInputTransformStrategyAlone() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                inputTransformStrategy: "apple-log-to-rec709"
            )
        )
        XCTAssertEqual(profile.id, .appleLog)
        XCTAssertEqual(profile.recommendedBias, 0.06, accuracy: 1e-12)
    }

    func testAppleLog2ViaSourceProfileId() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                sourceProfileId: "built-in:source-profile.apple-log-2"
            )
        )
        XCTAssertEqual(profile.id, .appleLog)
        XCTAssertEqual(profile.recommendedBias, 0.06, accuracy: 1e-12)
    }

    func testArriLogC3ViaSourceProfileId() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Panasonic",
                cameraModel: "LUMIX S1II",
                sourceProfileId: "built-in:source-profile.arri-logc3"
            )
        )
        XCTAssertEqual(profile.id, .arriLogC3)
        XCTAssertEqual(profile.transferClass, .logCinema)
        XCTAssertEqual(profile.confidence, .high)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testDjiViaCameraMake() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "DJI",
                cameraModel: "Osmo Action 4",
                codecFamily: "h264"
            )
        )
        XCTAssertEqual(profile.id, .djiAction)
        XCTAssertEqual(profile.transferClass, .rec709Consumer)
        XCTAssertEqual(profile.recommendedBias, 0.08, accuracy: 1e-12)
    }

    func testDjiViaSourceProfileId() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                sourceProfileId: "built-in:source-profile.dji-dlog"
            )
        )
        XCTAssertEqual(profile.id, .djiAction)
        XCTAssertEqual(profile.confidence, .high)
        XCTAssertEqual(profile.recommendedBias, 0.08, accuracy: 1e-12)
    }

    func testGoProMetadata() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "GoPro",
                cameraModel: "HERO12 Black",
                codecFamily: "hevc"
            )
        )
        XCTAssertEqual(profile.id, .goproAction)
        XCTAssertEqual(profile.recommendedBias, 0.08, accuracy: 1e-12)
    }

    func testSonySLog3NearZero() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Sony",
                cameraModel: "ILCE-7SM3",
                sourceProfileId: "built-in:source-profile.sony-slog3"
            )
        )
        XCTAssertEqual(profile.id, .sonySLog3)
        XCTAssertEqual(profile.transferClass, .logCinema)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testCanonCLogViaSourceProfileId() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                sourceProfileId: "built-in:source-profile.canon-log3-cinema-gamut"
            )
        )
        XCTAssertEqual(profile.id, .canonCLog)
        XCTAssertEqual(profile.transferClass, .logCinema)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testPanasonicVLogViaCameraMake() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Panasonic"
            )
        )
        XCTAssertEqual(profile.id, .panasonicVLog)
        XCTAssertEqual(profile.transferClass, .logCinema)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testUnknownRec709TinyPositive() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                codecFamily: "h264"
            )
        )
        XCTAssertEqual(profile.id, .rec709Unknown)
        XCTAssertEqual(profile.transferClass, .rec709Consumer)
        XCTAssertEqual(profile.confidence, .low)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testExplicitRec709SourceProfileId() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                sourceProfileId: "built-in:source-profile.rec709"
            )
        )
        XCTAssertEqual(profile.id, .rec709Unknown)
        XCTAssertEqual(profile.recommendedBias, 0.02, accuracy: 1e-12)
    }

    func testUnknownLogTransferZeroBias() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                inputTransformStrategy: "core-image-tone-map-sdr"
            )
        )
        XCTAssertEqual(profile.id, .logUnknown)
        XCTAssertEqual(profile.transferClass, .unknown)
        XCTAssertEqual(profile.recommendedBias, 0)
    }

    func testMissingMetadataZeroBias() {
        let profile = FilmtoneSourceDetailCompensation.resolve()
        XCTAssertEqual(profile.id, .metadataMissing)
        XCTAssertEqual(profile.confidence, .none)
        XCTAssertEqual(profile.recommendedBias, 0)
    }

    // MARK: - Invariants

    func testBiasAlwaysWithinClamp() {
        let cases: [FilmtoneSourceDetailCompensationInput] = [
            FilmtoneSourceDetailCompensationInput(cameraMake: "Apple", codecFamily: "hevc"),
            FilmtoneSourceDetailCompensationInput(sourceProfileId: "built-in:source-profile.arri-logc3"),
            FilmtoneSourceDetailCompensationInput(cameraMake: "DJI"),
            FilmtoneSourceDetailCompensationInput(cameraMake: "GoPro"),
            FilmtoneSourceDetailCompensationInput(cameraMake: "Sony"),
            FilmtoneSourceDetailCompensationInput(cameraMake: "Canon"),
            FilmtoneSourceDetailCompensationInput(cameraMake: "Panasonic"),
            FilmtoneSourceDetailCompensationInput(codecFamily: "h264"),
            FilmtoneSourceDetailCompensationInput(logTransferFunction: "apple-log"),
            FilmtoneSourceDetailCompensationInput(),
        ]
        for input in cases {
            let profile = FilmtoneSourceDetailCompensation.resolve(input)
            XCTAssertGreaterThanOrEqual(profile.recommendedBias, 0)
            XCTAssertLessThanOrEqual(profile.recommendedBias, FilmtoneDetailSoftness.effectiveMax)
        }
    }

    func testEffectiveMaxMirrorsRendererConstant() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(cameraMake: "Apple")
        )
        XCTAssertEqual(profile.effectiveMax, FilmtoneDetailSoftness.effectiveMax)
    }

    func testCameraMakeIsCaseInsensitiveAndWhitespaceTolerant() {
        let upper = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(cameraMake: "  SONY  ")
        )
        XCTAssertEqual(upper.id, .sonySLog3)
        let mixed = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(cameraMake: "Apple")
        )
        XCTAssertEqual(mixed.id, .iphoneSdrHevc)
    }

    func testAppleLogSignalOverridesIPhoneRec709Path() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                cameraMake: "Apple",
                cameraModel: "iPhone 17 Pro",
                logTransferFunction: "apple-log2"
            )
        )
        XCTAssertEqual(profile.id, .appleLog)
        XCTAssertEqual(profile.recommendedBias, 0.06, accuracy: 1e-12)
    }

    func testInputTransformStrategyNoneDoesNotTriggerLogUnknown() {
        let profile = FilmtoneSourceDetailCompensation.resolve(
            FilmtoneSourceDetailCompensationInput(
                inputTransformStrategy: "none"
            )
        )
        XCTAssertEqual(profile.id, .metadataMissing)
        XCTAssertEqual(profile.recommendedBias, 0)
    }
}
