import XCTest
import FilmLabSwiftCore

/// Landmark assertions on `FilmtonePhase0Generated`. These exist to catch
/// accidental regressions in the generator output (`scripts/generate-filmtone-swift.ts`)
/// or accidental hand-edits of the generated Swift artifact.
final class GeneratedLandmarkTests: XCTestCase {
    func testParamKeysCountAndOrder() {
        XCTAssertEqual(FilmtonePhase0Generated.paramKeys.count, 38)
        XCTAssertEqual(FilmtonePhase0Generated.paramKeys.first, "exposure")
        XCTAssertEqual(FilmtonePhase0Generated.paramKeys.last, "grainIntensity")

        // Spot-check optics/glow group is present in the listing (these
        // sit in the middle of the list — order changes here would
        // silently break ParamsPatch encode/decode and Look identity).
        XCTAssertTrue(FilmtonePhase0Generated.paramKeys.contains("rgbShift"))
        XCTAssertTrue(FilmtonePhase0Generated.paramKeys.contains("bloomStrength"))
        XCTAssertTrue(FilmtonePhase0Generated.paramKeys.contains("halationIntensity"))
        XCTAssertTrue(FilmtonePhase0Generated.paramKeys.contains("shadowLatitude"))
        XCTAssertTrue(FilmtonePhase0Generated.paramKeys.contains("vignette"))

        // detailSoftness lands immediately after lensSoftness in the canonical
        // ordering so user-authored optical creative intent rides with the
        // existing optics group through Look identity round-trip.
        let lensIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "lensSoftness")
        let detailIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "detailSoftness")
        XCTAssertNotNil(lensIndex)
        XCTAssertNotNil(detailIndex)
        if let lensIndex, let detailIndex {
            XCTAssertEqual(detailIndex, lensIndex + 1)
        }

        let shadowToneIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "shadowTone")
        let shadowLatitudeIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "shadowLatitude")
        XCTAssertNotNil(shadowToneIndex)
        XCTAssertNotNil(shadowLatitudeIndex)
        if let shadowToneIndex, let shadowLatitudeIndex {
            XCTAssertEqual(shadowLatitudeIndex, shadowToneIndex + 1)
        }

        let trailIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "trailIntensity")
        let breathIndex = FilmtonePhase0Generated.paramKeys.firstIndex(of: "filmBreathAmount")
        XCTAssertNotNil(trailIndex)
        XCTAssertNotNil(breathIndex)
        if let trailIndex, let breathIndex {
            XCTAssertEqual(breathIndex, trailIndex + 1)
        }
    }

    func testQuickAxisLandmarks() {
        XCTAssertEqual(FilmtonePhase0Generated.quickAxisIds, ["filmCharacter", "era", "dynamics"])
        XCTAssertEqual(FilmtonePhase0Generated.quickAxisMin, -1.0)
        XCTAssertEqual(FilmtonePhase0Generated.quickAxisMax, 1.0)
        XCTAssertEqual(FilmtonePhase0Generated.quickAxisStep, 0.01)
    }

    func testSchemaAndPresetLandmarks() {
        XCTAssertEqual(FilmtonePhase0Generated.schemaVersion, 2)
        XCTAssertEqual(FilmtonePhase0Generated.presetVersion, "v2")
        XCTAssertEqual(FilmtonePhase0Generated.presetDefault, "reset")
        XCTAssertEqual(FilmtonePhase0Generated.presetStrengthDefault, 1.0)
    }

    func testSourceCapLandmarks() {
        XCTAssertEqual(FilmtonePhase0Generated.sourceDurationCapSec, 300.0)
        XCTAssertEqual(FilmtonePhase0Generated.sourceLongEdgeCap, 4096)
        XCTAssertEqual(FilmtonePhase0Generated.sourceFileSizeCapBytes, 8589934592)
    }

    func testKernelClampLandmarks() {
        XCTAssertEqual(FilmtonePhase0Generated.rgbShiftMax, 0.005)
        XCTAssertEqual(FilmtonePhase0Generated.grainIntensityMax, 0.1)
    }

    func testHiddenDefaultsLandmarks() {
        // Per /apps/capacitor-film-lab-ios/CLAUDE.md §4 invariants —
        // these constants are CD-gated and must not drift silently.
        let h = FilmtonePhase0Generated.hiddenDefaults
        XCTAssertEqual(h.depthRayAngleGamma, 1.4)
        XCTAssertEqual(h.depthRayAngleInnerThreshold, 0.1)
        XCTAssertEqual(h.crossFilterAngleGamma, 1.4)
        XCTAssertEqual(h.crossFilterAngleInnerThreshold, 0.1)
        XCTAssertEqual(h.depthMistFieldPsfRadiusPx, 18.0)
        XCTAssertEqual(h.depthBloomFieldPsfRadiusPx, 9.0)
        XCTAssertEqual(h.depthHalationFieldPsfRadiusPx, 12.0)
    }

    func testResetParamsLandmarks() {
        let r = FilmtonePhase0Generated.resetParams
        XCTAssertEqual(r.exposure, 0.0)
        XCTAssertEqual(r.contrast, 1.0)
        XCTAssertEqual(r.saturation, 1.0)
        XCTAssertEqual(r.grainIntensity, 0.0)
        XCTAssertEqual(r.filmBreathAmount, 0.0)
        XCTAssertEqual(r.shadowHue, 180.0)
        XCTAssertEqual(r.highlightHue, 60.0)
    }

    func testParamsByNameRequiredEntries() {
        // The four canonical preset entries must always be present.
        XCTAssertNotNil(FilmtonePhase0Generated.paramsByName["reset"])
        XCTAssertNotNil(FilmtonePhase0Generated.paramsByName["iphone"])
        XCTAssertNotNil(FilmtonePhase0Generated.paramsByName["softBlue"])
        XCTAssertNotNil(FilmtonePhase0Generated.paramsByName["amberGlow"])
    }

    func testQuickWeightsRequiredAxes() {
        // QuickState axis weights must exist for all three axes.
        XCTAssertNotNil(FilmtonePhase0Generated.quickWeights["filmCharacter"])
        XCTAssertNotNil(FilmtonePhase0Generated.quickWeights["era"])
        XCTAssertNotNil(FilmtonePhase0Generated.quickWeights["dynamics"])
    }

    func testDefaultOutputProfileLandmarks() {
        let o = FilmtonePhase0Generated.outputProfile
        XCTAssertEqual(o.longEdge, 1920)
        XCTAssertEqual(o.fps, 24)
        XCTAssertEqual(o.codec, "h264")
        XCTAssertEqual(o.container, "mp4")
        XCTAssertTrue(o.preserveAudio)
    }
}
