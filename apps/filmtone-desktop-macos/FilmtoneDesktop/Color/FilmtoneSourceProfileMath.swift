import Foundation

// M5-C.1: Source-profile math primitives, lifted verbatim from iOS canonical
// `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`.
// Pure-Foundation, deterministic, no platform dependencies.
//
// Adds two Apple Log cube builders that on iOS live in
// `FilmtoneExportSession.makeAppleLogToRec709Lut` (Desktop has no equivalent
// host class, so the cube builder lives here next to the decoder for
// symmetry with V-Log / S-Log3 / D-Log / C-Log).
enum FilmtoneSourceProfileMath {

    // MARK: - Filmtone shared SDR display mapping

    @inline(__always)
    static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        let exposed = max(0, linear * 1.18)
        let shoulder = exposed / (1 + max(exposed - 0.18, 0) * 0.42)
        return clamp01(shoulder)
    }

    @inline(__always)
    static func rec709Encode(_ linear: Double) -> Double {
        let value = clamp01(linear)
        if value < 0.018 {
            return value * 4.5
        }
        return 1.099 * pow(value, 0.45) - 0.099
    }

    // MARK: - Apple Log / Apple Log 2

    @inline(__always)
    static func appleLogDecode(_ encoded: Double) -> Double {
        let r0 = -0.05641088
        let rt = 0.01
        let sigma = 47.28711236
        let beta = 0.00964052
        let gamma = 0.08550479
        let delta = 0.69336945
        let pt = sigma * pow(rt - r0, 2)

        if encoded >= pt {
            return pow(2, (encoded - delta) / gamma) - beta
        }
        if encoded >= 0 {
            return sqrt(max(encoded / sigma, 0)) + r0
        }
        return r0
    }

    /// End-to-end Apple Log → Rec.709 SDR pixel pipeline. Apple Log carries a
    /// Rec.2020 gamut by default (D-CP6); pass `rec2020GamutMap: true` to
    /// apply the standard matrix on the way to Rec.709. Apple Log 2 v1.3
    /// shares the same EOTF (known limitation).
    @inline(__always)
    static func appleLogPixelToRec709(
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

    /// Build a cube of `size³` voxels packed as RGB Float32 (sample-major,
    /// R fastest, then G, then B). Mirrors V-Log / S-Log3 cube builders so
    /// the FilmtoneSourceInputTransform RGBA-packing wrapper handles every
    /// curve uniformly.
    static func makeAppleLogToRec709Cube(size: Int = 33, rec2020GamutMap: Bool = true) -> [Float] {
        precondition(size >= 2, "cube size must be ≥ 2")
        let denom = Double(size - 1)
        var cube = [Float](repeating: 0, count: size * size * size * 3)
        var index = 0
        for b in 0..<size {
            let blueIn = Double(b) / denom
            for g in 0..<size {
                let greenIn = Double(g) / denom
                for r in 0..<size {
                    let redIn = Double(r) / denom
                    let converted = appleLogPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn,
                        rec2020GamutMap: rec2020GamutMap
                    )
                    cube[index]     = Float(converted.red)
                    cube[index + 1] = Float(converted.green)
                    cube[index + 2] = Float(converted.blue)
                    index += 3
                }
            }
        }
        return cube
    }

    // MARK: - DJI D-Log

    @inline(__always)
    static func dlogDecode(_ encoded: Double) -> Double {
        if encoded <= 0.14 {
            return (encoded - 0.0929) / 6.025
        }
        return (pow(10.0, 3.89616 * encoded - 2.27752) - 0.0108) / 0.9892
    }

    @inline(__always)
    static func dgamutToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.6746 * red - 0.5797 * green - 0.0949 * blue,
            green: -0.0981 * red + 1.3340 * green - 0.2359 * blue,
            blue:  -0.0410 * red - 0.2430 * green + 1.2840 * blue
        )
    }

    @inline(__always)
    static func dlogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = dlogDecode(red)
        let linearGreen = dlogDecode(green)
        let linearBlue = dlogDecode(blue)
        let mapped = dgamutToRec709(
            red: linearRed,
            green: linearGreen,
            blue: linearBlue
        )
        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    static func makeDlogToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            dlogPixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - DJI D-Log M

    @inline(__always)
    static func dlogMDecode(_ encoded: Double) -> Double {
        let cut: Double           = 0.1113510236
        let linearOffset: Double  = 0.0000000120
        let linearSlope: Double   = 7.5547639793
        let logA: Double          = 1.5389476580
        let logB: Double          = -1.8459129538
        let logC: Double          = 0.0165823994
        let logD: Double          = 0.3103580873
        if encoded <= cut {
            return (encoded - linearOffset) / linearSlope
        }
        return (pow(10.0, logA * encoded + logB) - logC) / logD
    }

    @inline(__always)
    static func dgamutMToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.4312693292 * red - 0.4338679939 * green + 0.0025986647 * blue,
            green: -0.0747311522 * red + 1.1578502353 * green - 0.0831190830 * blue,
            blue:  -0.0570111279 * red - 0.2731296886 * green + 1.3301408164 * blue
        )
    }

    @inline(__always)
    static func dlogMPixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = dlogMDecode(red)
        let linearGreen = dlogMDecode(green)
        let linearBlue = dlogMDecode(blue)
        let mapped = dgamutMToRec709(
            red: linearRed,
            green: linearGreen,
            blue: linearBlue
        )
        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    static func makeDlogMToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            dlogMPixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - Canon C-Log

    @inline(__always)
    static func canonLogDecode(_ encoded: Double) -> Double {
        let pivot = 0.0730597
        let scale = 0.529136
        let gain = 10.1596
        let linear: Double
        if encoded < pivot {
            linear = -(pow(10.0, (pivot - encoded) / scale) - 1.0) / gain
        } else {
            linear = (pow(10.0, (encoded - pivot) / scale) - 1.0) / gain
        }
        return linear * 0.9
    }

    @inline(__always)
    static func canonClogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = canonLogDecode(red)
        let linearGreen = canonLogDecode(green)
        let linearBlue = canonLogDecode(blue)
        return (
            rec709Encode(filmtoneSdrShoulder(linearRed)),
            rec709Encode(filmtoneSdrShoulder(linearGreen)),
            rec709Encode(filmtoneSdrShoulder(linearBlue))
        )
    }

    static func makeCanonClogToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            canonClogPixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - Canon Log 3 + Cinema Gamut

    @inline(__always)
    static func canonLog3Decode(_ encoded: Double) -> Double {
        let lowBreak = 0.097465473
        let highBreak = 0.15277891
        let logScale = 0.36726845
        let logGain = 14.98325
        let linearSlope = 1.9754798
        let linearOffset = 0.12512219
        let lowOffset = 0.12783901
        let highOffset = 0.12240537
        let scene: Double
        if encoded < lowBreak {
            scene = -(pow(10.0, (lowOffset - encoded) / logScale) - 1.0) / logGain
        } else if encoded <= highBreak {
            scene = (encoded - linearOffset) / linearSlope
        } else {
            scene = (pow(10.0, (encoded - highOffset) / logScale) - 1.0) / logGain
        }
        return scene * 0.9
    }

    @inline(__always)
    static func cineGamutToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.92355517 * red - 0.79863353 * green - 0.12508072 * blue,
            green: -0.20431556 * red + 1.49593305 * green - 0.29159440 * blue,
            blue:  -0.02369073 * red - 0.42022784 * green + 1.44415855 * blue
        )
    }

    @inline(__always)
    static func canonLog3CineGamutPixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = canonLog3Decode(red)
        let linearGreen = canonLog3Decode(green)
        let linearBlue = canonLog3Decode(blue)
        let mapped = cineGamutToRec709(
            red: linearRed,
            green: linearGreen,
            blue: linearBlue
        )
        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    static func makeCanonLog3CineGamutToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            canonLog3CineGamutPixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - Panasonic V-Log

    @inline(__always)
    static func vlogDecode(_ encoded: Double) -> Double {
        let cut2 = 0.181
        let b = 0.00873
        let c = 0.241514
        let d = 0.598206

        if encoded < cut2 {
            return (encoded - 0.125) / 5.6
        }
        return pow(10.0, (encoded - d) / c) - b
    }

    @inline(__always)
    static func vgamutToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.7398 * red - 0.6727 * green - 0.0671 * blue,
            green: -0.1956 * red + 1.2473 * green - 0.0518 * blue,
            blue:  -0.0114 * red - 0.0440 * green + 1.0554 * blue
        )
    }

    @inline(__always)
    static func vlogPixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = vlogDecode(red)
        let linearGreen = vlogDecode(green)
        let linearBlue = vlogDecode(blue)
        let mapped = vgamutToRec709(
            red: linearRed,
            green: linearGreen,
            blue: linearBlue
        )
        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    static func makeVlogToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            vlogPixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - Sony S-Log3

    @inline(__always)
    static func slog3Decode(_ encoded: Double) -> Double {
        let threshold = 171.2102946929 / 1023.0
        if encoded < threshold {
            return ((encoded * 1023.0 - 95.0) * 0.01125) / (171.2102946929 - 95.0)
        }
        return pow(10.0, (encoded * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01
    }

    @inline(__always)
    static func sgamut3CineToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.6269 * red - 0.5365 * green - 0.0904 * blue,
            green: -0.1078 * red + 1.1628 * green - 0.0550 * blue,
            blue:  -0.0140 * red - 0.0240 * green + 1.0379 * blue
        )
    }

    @inline(__always)
    static func slog3PixelToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        let linearRed = slog3Decode(red)
        let linearGreen = slog3Decode(green)
        let linearBlue = slog3Decode(blue)
        let mapped = sgamut3CineToRec709(
            red: linearRed,
            green: linearGreen,
            blue: linearBlue
        )
        return (
            rec709Encode(filmtoneSdrShoulder(mapped.red)),
            rec709Encode(filmtoneSdrShoulder(mapped.green)),
            rec709Encode(filmtoneSdrShoulder(mapped.blue))
        )
    }

    static func makeSlog3ToRec709Cube(size: Int = 33) -> [Float] {
        return makeRGBCube(size: size) { r, g, b in
            slog3PixelToRec709(red: r, green: g, blue: b)
        }
    }

    // MARK: - Gamut matrices

    @inline(__always)
    static func rec2020ToRec709(
        red: Double,
        green: Double,
        blue: Double
    ) -> (red: Double, green: Double, blue: Double) {
        (
            red:    1.6605 * red - 0.5876 * green - 0.0728 * blue,
            green: -0.1246 * red + 1.1329 * green - 0.0083 * blue,
            blue:  -0.0182 * red - 0.1006 * green + 1.1187 * blue
        )
    }

    // MARK: - Internal helpers

    @inline(__always)
    private static func clamp01(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    /// RGB-packed cube builder shared by every (S) curve. Sample-major:
    /// R fastest, then G, then B. Output is `size³ * 3` Float32.
    @inline(__always)
    private static func makeRGBCube(
        size: Int,
        pixel: (Double, Double, Double) -> (red: Double, green: Double, blue: Double)
    ) -> [Float] {
        precondition(size >= 2, "cube size must be ≥ 2")
        let denom = Double(size - 1)
        var cube = [Float](repeating: 0, count: size * size * size * 3)
        var index = 0
        for b in 0..<size {
            let blueIn = Double(b) / denom
            for g in 0..<size {
                let greenIn = Double(g) / denom
                for r in 0..<size {
                    let redIn = Double(r) / denom
                    let converted = pixel(redIn, greenIn, blueIn)
                    cube[index]     = Float(converted.red)
                    cube[index + 1] = Float(converted.green)
                    cube[index + 2] = Float(converted.blue)
                    index += 3
                }
            }
        }
        return cube
    }
}
