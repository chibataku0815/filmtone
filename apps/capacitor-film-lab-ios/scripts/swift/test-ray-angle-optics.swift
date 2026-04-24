import CoreImage
import Foundation

struct RayAngleCheckError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw RayAngleCheckError(message: message)
    }
}

func approx(_ a: Double, _ b: Double, _ eps: Double) -> Bool {
    abs(a - b) < eps
}

@main
struct TestRayAngleOptics {
    static func main() throws {
        try runReferenceConstantTest()
        try runResolveFallbackTest()
        try runResolveMetadataTest()
        try runResolveWideVsTeleTest()
        try runMaskCenterTest()
        try runMaskEdgeWideVsTeleTest()
        try runApplyMaskSemanticsTest()
        print("Ray-angle optics tests passed")
    }

    // MARK: - Fixture helpers

    static func optics(
        source: String = "metadata",
        fovXDeg: Double? = nil,
        fovYDeg: Double? = nil,
        fxPx: Double? = nil,
        fyPx: Double? = nil
    ) -> CameraOpticsDTO {
        CameraOpticsDTO(
            source: source,
            fxPx: fxPx,
            fyPx: fyPx,
            cxPx: nil,
            cyPx: nil,
            fovXDeg: fovXDeg,
            fovYDeg: fovYDeg,
            focalLength35mm: nil,
            lensModel: nil,
            cameraMake: nil,
            cameraModel: nil
        )
    }

    // MARK: - Tests

    static func runReferenceConstantTest() throws {
        let expected = tan(65.0 * .pi / 360.0)
        try expect(
            approx(FilmtoneRayAngleOptics.referenceTanHalfHfov, expected, 1e-9),
            "referenceTanHalfHfov should equal tan(65° / 2) to 1e-9"
        )
        // Sanity against plan-frozen decimal approximation.
        try expect(
            approx(FilmtoneRayAngleOptics.referenceTanHalfHfov, 0.6370702608, 1e-9),
            "referenceTanHalfHfov should be ≈ 0.6370702608 (plan §Ray-angle 定数)"
        )
        try expect(
            FilmtoneRayAngleOptics.fallbackHfovDeg == 65.0,
            "fallbackHfovDeg should be 65.0"
        )
        try expect(
            FilmtoneRayAngleOptics.fovMinDeg == 1.0,
            "fovMinDeg should be 1.0"
        )
        try expect(
            FilmtoneRayAngleOptics.fovMaxDeg == 178.0,
            "fovMaxDeg should be 178.0"
        )
        try expect(
            FilmtoneRayAngleOptics.defaultGamma == 1.4,
            "defaultGamma should mirror CONTRACT_DEFAULTS.depthRayAngleGamma (1.4)"
        )
        try expect(
            FilmtoneRayAngleOptics.defaultInnerThreshold == 0.1,
            "defaultInnerThreshold should mirror CONTRACT_DEFAULTS.depthRayAngleInnerThreshold (0.1)"
        )
    }

    static func runResolveFallbackTest() throws {
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: nil,
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            resolved.source == "fallback65",
            "nil optics should resolve to source=fallback65 (got \(resolved.source))"
        )
        try expect(
            approx(resolved.tanHalfFovX, FilmtoneRayAngleOptics.referenceTanHalfHfov, 1e-9),
            "fallback65 tanHalfFovX should equal referenceTanHalfHfov"
        )
        // Aspect 1080/1920 = 0.5625 → tanHalfFovY ≈ reference * 0.5625
        let expectedY = FilmtoneRayAngleOptics.referenceTanHalfHfov * (1080.0 / 1920.0)
        try expect(
            approx(resolved.tanHalfFovY, expectedY, 1e-9),
            "fallback65 tanHalfFovY should be reference * aspectY"
        )

        // Optics DTO with all fov / focal nil also takes the fallback path.
        let naked = optics(source: "assumed")
        let resolvedNaked = FilmtoneRayAngleOptics.resolve(
            optics: naked,
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            resolvedNaked.source == "fallback65",
            "DTO with all null fov / focal should fall back to fallback65"
        )
    }

    static func runResolveMetadataTest() throws {
        let metadata = optics(source: "metadata", fovXDeg: 65.0, fovYDeg: 38.0)
        let resolved = FilmtoneRayAngleOptics.resolve(
            optics: metadata,
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            resolved.source == "metadata",
            "metadata source marker should be preserved"
        )
        try expect(
            approx(resolved.tanHalfFovX, 0.6370702608, 1e-6),
            "fovXDeg=65 → tanHalfFovX ≈ 0.6370702608 (got \(resolved.tanHalfFovX))"
        )
        let expectedY = tan(38.0 * .pi / 360.0)  // ≈ 0.3443276
        try expect(
            approx(resolved.tanHalfFovY, expectedY, 1e-6),
            "fovYDeg=38 → tanHalfFovY ≈ 0.3443276 (got \(resolved.tanHalfFovY))"
        )
        try expect(
            approx(expectedY, 0.3443276, 1e-6),
            "sanity: tan(38° / 2) ≈ 0.3443276"
        )
    }

    static func runResolveWideVsTeleTest() throws {
        let wide = FilmtoneRayAngleOptics.resolve(
            optics: optics(source: "metadata", fovXDeg: 100.0),
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            wide.tanHalfFovX > FilmtoneRayAngleOptics.referenceTanHalfHfov,
            "100deg wide lens should have tanHalfFovX > reference (got \(wide.tanHalfFovX))"
        )

        let tele = FilmtoneRayAngleOptics.resolve(
            optics: optics(source: "metadata", fovXDeg: 40.0),
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            tele.tanHalfFovX < FilmtoneRayAngleOptics.referenceTanHalfHfov,
            "40deg tele lens should have tanHalfFovX < reference (got \(tele.tanHalfFovX))"
        )
    }

    static func runMaskCenterTest() throws {
        let centerMask = FilmtoneRayAngleOptics.mask(
            uvX: 0.5,
            uvY: 0.5,
            imageWidth: 1920,
            imageHeight: 1080,
            optics: optics(source: "metadata", fovXDeg: 65.0, fovYDeg: 38.0)
        )
        try expect(
            centerMask < 0.001,
            "mask at center (uvX=0.5, uvY=0.5) should be ≈ 0 (got \(centerMask))"
        )
    }

    static func runMaskEdgeWideVsTeleTest() throws {
        let wide = FilmtoneRayAngleOptics.mask(
            uvX: 0.95,
            uvY: 0.5,
            imageWidth: 1920,
            imageHeight: 1080,
            optics: optics(source: "metadata", fovXDeg: 100.0)
        )
        let tele = FilmtoneRayAngleOptics.mask(
            uvX: 0.95,
            uvY: 0.5,
            imageWidth: 1920,
            imageHeight: 1080,
            optics: optics(source: "metadata", fovXDeg: 40.0)
        )
        try expect(
            wide > tele,
            "at uvX=0.95, 100deg wide mask (\(wide)) should exceed 40deg tele mask (\(tele))"
        )
    }

    static func runApplyMaskSemanticsTest() throws {
        // This test asserts that `resolve()` reports "assumed" / "metadata"
        // correctly so the caller can set `applyMask = (source == "metadata")`.
        let assumed = FilmtoneRayAngleOptics.resolve(
            optics: optics(source: "assumed", fovXDeg: 65.0),
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            assumed.source == "assumed",
            "source=assumed should survive the resolve path (got \(assumed.source))"
        )

        let metadata = FilmtoneRayAngleOptics.resolve(
            optics: optics(source: "metadata", fovXDeg: 65.0),
            imageWidth: 1920,
            imageHeight: 1080
        )
        try expect(
            metadata.source == "metadata",
            "source=metadata should survive the resolve path"
        )
    }
}
