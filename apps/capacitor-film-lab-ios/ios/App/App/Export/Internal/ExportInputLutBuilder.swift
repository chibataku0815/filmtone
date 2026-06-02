import Foundation

/// Builds prepared LUT cubes for the export pipeline.
///
/// These helpers moved out of `FilmtoneExportSession` during the v1.x
/// feature-architecture refactor (Phase 2B-2). Public surface is
/// unchanged — `FilmtoneExportSession` calls `makePreparedLut(from:)`
/// and `makeActiveInputLut(for:probe:)` through this namespace instead
/// of `Self.<helper>`. The cube data, intensity, and Apple Log math are
/// byte-identical to the pre-refactor implementation.
enum ExportInputLutBuilder {

    static func makePreparedLut(from lut: SerializableLutDTO?) -> PreparedLut? {
        guard let lut, lut.size > 1, !lut.data.isEmpty else {
            return nil
        }

        let floatData = rgbaCubeData(from: lut.data, size: lut.size)
        let cubeData = floatData.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }

        return PreparedLut(
            size: lut.size,
            intensity: lut.intensity,
            cubeData: cubeData
        )
    }

    private static func makeAutomaticInputLut(for policy: SourceInputTransformPolicyDTO?) -> PreparedLut? {
        switch policy?.strategy {
        case .appleLogToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        case .appleLog2ToRec709:
            return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
        default:
            return nil
        }
    }

    // v1.3 Camera Profiles Phase E: synthesized 33³ cubes are recomputed
    // once per app run and reused across exports. Keyed by a curve identity
    // string so the cache survives multiple exports of the same source
    // profile without rebuilding ~575 KB of cube data.
    private static let synthesizedInputLutCache = NSCache<NSString, NSData>()

    /// v1.3 Camera Profiles Phase E entry point. When `selection` is nil
    /// (legacy callers) or `.auto`, falls back to the existing
    /// `makeAutomaticInputLut` detection path. Otherwise dispatches
    /// through `FilmtoneSourceProfileCatalog`.
    static func makeActiveInputLut(
        for selection: CameraProfileSelection?,
        probe: SourceProbeDTO?
    ) -> PreparedLut? {
        switch selection ?? .auto {
        case .auto:
            return makeAutomaticInputLut(for: probe?.inputTransformPolicy)
        case .builtIn(let catalogId):
            guard let entry = FilmtoneSourceProfileCatalog.entry(forCatalogId: catalogId) else {
                return nil
            }
            return makeInputLut(forImpl: entry.impl)
        case .userImport:
            // v1.3: a user-imported `.cube` is carried by `request.inputLut`
            // and is consumed by the caller's `makePreparedLut(from:)` path
            // ahead of `makeActiveInputLut`. The `.userImport` selection
            // therefore short-circuits to nil here so the export pipeline
            // does not double-apply.
            return nil
        }
    }

    private static func makeInputLut(forImpl impl: SourceProfileImpl) -> PreparedLut? {
        switch impl {
        case .nilProfile:
            return nil
        case .nativePolicy(let strategy):
            switch strategy {
            case .appleLogToRec709, .appleLog2ToRec709:
                return makeAppleLogToRec709Lut(size: 33, rec2020GamutMap: true)
            default:
                return nil
            }
        case .synthesized(let curve):
            return makeSynthesizedInputLut(curve: curve)
        case .bundledCube:
            // Reserved for v1.4 (e.g. ARRI LogC4 once licensed). v1.3
            // catalog never selects this case; if it ever shows up in v1.3
            // we explicitly fall through to nil rather than silently
            // returning the wrong cube.
            return nil
        }
    }

    private static func makeSynthesizedInputLut(curve: SourceProfileCurve) -> PreparedLut? {
        let cubeSize = 33
        let cacheKey = "synthesized.\(curve.rawValue).\(cubeSize)" as NSString
        if let cached = synthesizedInputLutCache.object(forKey: cacheKey) {
            return PreparedLut(size: cubeSize, intensity: 1, cubeData: cached as Data)
        }
        let rgb: [Float]
        switch curve {
        case .arriLogC3:
            rgb = FilmtoneSourceProfileMath.makeArriLogC3ToRec709Cube(size: cubeSize)
        case .djiDLog:
            rgb = FilmtoneSourceProfileMath.makeDlogToRec709Cube(size: cubeSize)
        case .djiDLogM:
            rgb = FilmtoneSourceProfileMath.makeDlogMToRec709Cube(size: cubeSize)
        case .canonCLog:
            rgb = FilmtoneSourceProfileMath.makeCanonClogToRec709Cube(size: cubeSize)
        case .canonLog3CinemaGamut:
            rgb = FilmtoneSourceProfileMath.makeCanonLog3CineGamutToRec709Cube(size: cubeSize)
        case .panasonicVLog:
            rgb = FilmtoneSourceProfileMath.makeVlogToRec709Cube(size: cubeSize)
        case .sonySLog3:
            rgb = FilmtoneSourceProfileMath.makeSlog3ToRec709Cube(size: cubeSize)
        case .appleLog, .appleLog2:
            // Apple Log curves ride the native path, not synthesized —
            // FilmtoneSourceProfileCatalog ensures `.appleLog*` always
            // arrives here through `nativePolicy`. If the catalog ever
            // mismatches (test fixture mistake), fall through to the
            // existing Apple Log Lut so the pipeline degrades safely.
            return makeAppleLogToRec709Lut(size: cubeSize, rec2020GamutMap: true)
        }
        let cubeData = packRgbToRgbaCubeData(rgb: rgb, size: cubeSize)
        synthesizedInputLutCache.setObject(cubeData as NSData, forKey: cacheKey)
        return PreparedLut(size: cubeSize, intensity: 1, cubeData: cubeData)
    }

    private static func packRgbToRgbaCubeData(rgb: [Float], size: Int) -> Data {
        let count = size * size * size
        precondition(rgb.count == count * 3, "RGB cube data is malformed")
        var rgba = [Float](repeating: 0, count: count * 4)
        for i in 0..<count {
            rgba[i * 4 + 0] = rgb[i * 3 + 0]
            rgba[i * 4 + 1] = rgb[i * 3 + 1]
            rgba[i * 4 + 2] = rgb[i * 3 + 2]
            rgba[i * 4 + 3] = 1
        }
        return rgba.withUnsafeBufferPointer { Data(buffer: $0) }
    }

    private static func rgbaCubeData(from data: [Double], size: Int) -> [Float] {
        let expectedRGBCount = size * size * size * 3
        let expectedRGBACount = size * size * size * 4
        if data.count == expectedRGBACount {
            return data.map(Float.init)
        }

        var rgba: [Float] = []
        rgba.reserveCapacity(expectedRGBACount)
        let count = min(data.count, expectedRGBCount)
        var index = 0
        while index < count {
            rgba.append(Float(data[index]))
            rgba.append(Float(index + 1 < count ? data[index + 1] : 0))
            rgba.append(Float(index + 2 < count ? data[index + 2] : 0))
            rgba.append(1)
            index += 3
        }

        while rgba.count < expectedRGBACount {
            rgba.append(0)
            rgba.append(0)
            rgba.append(0)
            rgba.append(1)
        }
        return rgba
    }

    private static func makeAppleLogToRec709Lut(size: Int, rec2020GamutMap: Bool) -> PreparedLut? {
        guard size > 1 else {
            return nil
        }

        var values: [Float] = []
        values.reserveCapacity(size * size * size * 4)
        for blueIndex in 0..<size {
            let blue = Double(blueIndex) / Double(size - 1)
            for greenIndex in 0..<size {
                let green = Double(greenIndex) / Double(size - 1)
                for redIndex in 0..<size {
                    let red = Double(redIndex) / Double(size - 1)
                    let converted = appleLogPixelToRec709(
                        red: red,
                        green: green,
                        blue: blue,
                        rec2020GamutMap: rec2020GamutMap
                    )
                    values.append(Float(converted.red))
                    values.append(Float(converted.green))
                    values.append(Float(converted.blue))
                    values.append(1)
                }
            }
        }

        let cubeData = values.withUnsafeBufferPointer { pointer in
            Data(buffer: pointer)
        }
        return PreparedLut(size: size, intensity: 1, cubeData: cubeData)
    }

    private static func appleLogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double,
        rec2020GamutMap: Bool
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = appleLogDecode(red)
        let linearGreen = appleLogDecode(green)
        let linearBlue = appleLogDecode(blue)

        let mapped: (red: Double, green: Double, blue: Double)
        if rec2020GamutMap {
            mapped = rec2020ToRec709(red: linearRed, green: linearGreen, blue: linearBlue)
        } else {
            mapped = (linearRed, linearGreen, linearBlue)
        }

        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    // v1.3 Camera Profiles Phase B-1: the four primitives below moved to
    // `FilmtoneSourceProfileMath` so V-Log / S-Log3 (and any future curve)
    // share the identical Filmtone SDR shoulder + Rec.709 encode pair.
    // The thin wrappers here keep call sites (e.g. `appleLogPixelToRec709`)
    // source-stable; the math is byte-identical to the pre-Phase-B-1
    // implementation.

    @inline(__always)
    private static func appleLogDecode(_ encoded: Double) -> Double {
        FilmtoneSourceProfileMath.appleLogDecode(encoded)
    }

    @inline(__always)
    private static func rec2020ToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        FilmtoneSourceProfileMath.rec2020ToRec709(red: red, green: green, blue: blue)
    }

    @inline(__always)
    private static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        FilmtoneSourceProfileMath.filmtoneSdrShoulder(linear)
    }

    @inline(__always)
    private static func rec709Encode(_ linear: Double) -> Double {
        FilmtoneSourceProfileMath.rec709Encode(linear)
    }
}
