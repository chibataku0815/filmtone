import Foundation

/// v1.3 Camera Profiles math primitives. SSOT for source-profile decoders,
/// gamut matrices, the shared Filmtone SDR display shoulder, and the
/// Rec.709 OETF.
///
/// These functions used to live in `FilmtoneExportSession` as private
/// `static` methods. They were extracted in v1.3 (Camera Profiles Phase
/// B-1) so that both the existing Apple Log path and the new (S) V-Log /
/// S-Log3 paths could share the identical Filmtone SDR display mapping
/// (`filmtoneSdrShoulder` + `rec709Encode`) without duplication.
///
/// The Phase B-1 migration is a no-behavior-change refactor: the constants,
/// the operator order, and the clamping rules are byte-identical to the
/// pre-extraction code. Verified via the existing Apple Log → Rec.709
/// snapshot fixtures — if any drift appears, revert and split the move
/// into a smaller commit (per plan §B-1 hard gate).
///
/// All functions stay deliberately deterministic: no Foundation date /
/// random / locale dependencies, so the standalone Phase 0 contract gate
/// can compile this file without dragging in the full media types graph.
enum FilmtoneSourceProfileMath {

    // MARK: - Filmtone shared SDR display mapping

    /// Filmtone identity SDR shoulder. Applied to linearized + gamut-mapped
    /// scene-referred RGB on its way out to Rec.709 SDR. Identical math
    /// across every Camera Profile (Apple Log, Apple Log 2, D-Log, C-Log,
    /// V-Log, S-Log3, Rec.709 passthrough) so cross-source exports share
    /// one display look.
    ///
    /// Anchors `0.18` linear ≈ middle gray and rolls highlights via a
    /// soft-knee Reinhard-style curve. Output is clamped to [0, 1].
    @inline(__always)
    static func filmtoneSdrShoulder(_ linear: Double) -> Double {
        let exposed = max(0, linear * 1.18)
        let shoulder = exposed / (1 + max(exposed - 0.18, 0) * 0.42)
        return clamp01(shoulder)
    }

    /// ITU-R BT.709 OETF (encode) with the standard 0.018 knee. Input
    /// must be linear-light scene-referred RGB in [0, 1]; output is the
    /// gamma-encoded code value also in [0, 1].
    @inline(__always)
    static func rec709Encode(_ linear: Double) -> Double {
        let value = clamp01(linear)
        if value < 0.018 {
            return value * 4.5
        }
        return 1.099 * pow(value, 0.45) - 0.099
    }

    // MARK: - Apple Log / Apple Log 2

    /// Apple Log → linear scene-referred decoder. Constants transcribed
    /// from Apple's reference implementation; Apple has not published a
    /// machine-readable spec, so these match the values that shipped in
    /// `FilmtoneExportSession` before Phase B-1.
    ///
    /// Apple Log 2 reuses this curve (D-CP6: Apple Log 2 is documented as
    /// sharing the EOTF, only the gamut differs — known limitation logged
    /// in `docs/source-profile-math/apple-log-2.md`).
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

    // MARK: - DJI D-Log

    /// D-Log → linear scene-referred decoder. Constants from DJI's
    /// *White Paper on D-Log and D-Gamut of DJI Cinema Color System*
    /// (Zenmuse X9 6K & 8K, Rev.1.0). This is the documented D-Log /
    /// D-Gamut curve, not D-Log M.
    @inline(__always)
    static func dlogDecode(_ encoded: Double) -> Double {
        if encoded <= 0.14 {
            return (encoded - 0.0929) / 6.025
        }
        return (pow(10.0, 3.89616 * encoded - 2.27752) - 0.0108) / 0.9892
    }

    /// D-Gamut → Rec.709 matrix from DJI's D-Gamut colorimetric section.
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

    /// End-to-end DJI D-Log → Rec.709 SDR pixel pipeline:
    /// linearize → D-Gamut→Rec.709 matrix → Filmtone shoulder → Rec.709 OETF.
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

    /// Build a 33³ DJI D-Log → Rec.709 cube for `CIColorCubeWithColorSpace`.
    static func makeDlogToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = dlogPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - DJI D-Log M

    /// D-Log M → linear scene-referred decoder. DJI has not published a
    /// formal D-Log M transfer specification. The 6 piecewise-log
    /// coefficients below are FITTED from the DJI consumer-camera
    /// `D-Log M to Rec.709 V1.cube` (SHA-256 b18162854ab47702...) which
    /// DJI ships byte-identically for Mavic 3 Pro, Osmo Pocket 3, and
    /// Osmo 360. The fit pre-compensates the Filmtone SDR shoulder so
    /// that `filmtoneSdrShoulder(decode_M(V))` reproduces the cube's
    /// gray-axis output. The 7th coefficient (`d`) is derived from
    /// continuity at the breakpoint.
    ///
    /// SSOT: `Tests/Fixtures/source-profile/dji-dlog-m/encode-ramp.py`.
    /// Re-running that script reproduces these literals; see
    /// `docs/source-profile-math/dji-dlog-m.md` for the full provenance.
    @inline(__always)
    static func dlogMDecode(_ encoded: Double) -> Double {
        let cut: Double           = 0.1113510236
        let linearOffset: Double  = 0.0000000120
        let linearSlope: Double   = 7.5547639793
        let logA: Double          = 1.5389476580
        let logB: Double          = -1.8459129538
        let logC: Double          = 0.0165823994
        let logD: Double          = 0.3103580873  // derived from continuity at cut
        if encoded <= cut {
            return (encoded - linearOffset) / linearSlope
        }
        return (pow(10.0, logA * encoded + logB) - logC) / logD
    }

    /// D-Gamut M → Rec.709 matrix, fitted from the DJI cube via joint
    /// refinement under the row-sum = 1 (gray-axis preserving) constraint.
    /// Less aggressive negative coefficients than D-Gamut original — D-Log M
    /// targets a slightly narrower gamut closer to Rec.709, which matches
    /// DJI's positioning of D-Log M as the consumer-camera log curve.
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

    /// End-to-end DJI D-Log M → Rec.709 SDR pixel pipeline:
    /// linearize → D-Gamut M→Rec.709 matrix → Filmtone shoulder → Rec.709 OETF.
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

    /// Build a 33³ DJI D-Log M → Rec.709 cube for `CIColorCubeWithColorSpace`.
    static func makeDlogMToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = dlogMPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - Canon C-Log

    /// Canon Log original → linear scene-referred decoder. Constants follow
    /// Canon's 2012 Canon-Log transfer characteristic via the Colour Science
    /// implementation. This profile assumes original Canon Log in BT.709
    /// gamut; Canon Log 2/3 + Cinema Gamut should be separate profiles.
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

    /// End-to-end Canon C-Log → Rec.709 SDR pixel pipeline. Original C-Log
    /// is treated as BT.709 gamut, so no chromaticity matrix is applied.
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

    /// Build a 33³ Canon C-Log → Rec.709 cube for `CIColorCubeWithColorSpace`.
    static func makeCanonClogToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = canonClogPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - Canon Log 3 + Cinema Gamut

    /// Canon Log 3 → linear scene-referred decoder. Constants from Canon
    /// (2020) Canon Log 3 v1.2 spec via the Colour Science library
    /// (`colour.models.log_decoding_CanonLog3`, v1.2 method). Reflection
    /// scale `* 0.9` matches the spec's reference convention so 18% gray
    /// maps to encoded ≈ 0.343389 and decodes back to 0.18 linear.
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

    /// Cinema Gamut → Rec.709 matrix. Precomputed product of (Cinema Gamut
    /// RGB → CIE XYZ, D65) from the Antler Post Cinema Gamut reference and
    /// the standard ITU-R BT.709-6 (XYZ → Rec.709, D65). No chromatic
    /// adaptation is needed because both spaces share D65 white. See
    /// `docs/source-profile-math/canon-log3-cinema-gamut.md` for the full
    /// derivation.
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

    /// End-to-end Canon Log 3 + Cinema Gamut → Rec.709 SDR pixel pipeline:
    /// linearize → Cinema Gamut→Rec.709 matrix → Filmtone shoulder → Rec.709 OETF.
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

    /// Build a 33³ Canon Log 3 + Cinema Gamut → Rec.709 cube for
    /// `CIColorCubeWithColorSpace`.
    static func makeCanonLog3CineGamutToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = canonLog3CineGamutPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - Panasonic V-Log

    /// V-Log → linear scene-referred decoder. Constants from Panasonic
    /// *V-Log/V-Gamut REFERENCE MANUAL* (2014-11-28). Verified mirror:
    /// https://antlerpost.com/colour-spaces/VGamut.html
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

    /// V-Gamut → Rec.709 (D65 → D65, no chromatic adaptation). The matrix
    /// is the precomputed product of (V-Gamut → XYZ) · (XYZ → Rec.709).
    /// Values reproduced from the V-Log/V-Gamut Reference Manual via the
    /// Antler Post mirror; see `docs/source-profile-math/panasonic-vlog.md`.
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

    /// End-to-end V-Log → Rec.709 SDR pixel pipeline:
    /// linearize → V-Gamut→Rec.709 matrix → Filmtone shoulder → Rec.709 OETF.
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

    /// Build a 33³ V-Log → Rec.709 cube, sample-major (R fastest, then G,
    /// then B), packed RGB Float32 for `CIColorCubeWithColorSpace`. Mirrors
    /// `FilmtoneExportSession.makeAppleLogToRec709Lut` so callers can
    /// substitute curves without changing their cube-consumption side.
    static func makeVlogToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = vlogPixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - Sony S-Log3

    /// S-Log3 → linear scene-referred decoder. Constants from Sony's
    /// *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
    /// Verified mirror: https://antlerpost.com/colour-spaces/SLog3.html
    /// The threshold `171.2102946929 / 1023.0` is the breakpoint between
    /// the linear-tail toe and the log-curve body.
    @inline(__always)
    static func slog3Decode(_ encoded: Double) -> Double {
        let threshold = 171.2102946929 / 1023.0
        if encoded < threshold {
            return ((encoded * 1023.0 - 95.0) * 0.01125) / (171.2102946929 - 95.0)
        }
        return pow(10.0, (encoded * 1023.0 - 420.0) / 261.5) * (0.18 + 0.01) - 0.01
    }

    /// S-Gamut3.Cine → Rec.709 matrix (precomputed, D65 → D65, no
    /// chromatic adaptation). Values reproduced from Sony's technical
    /// summary; see `docs/source-profile-math/sony-slog3.md`.
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

    /// End-to-end S-Log3 → Rec.709 SDR pixel pipeline. Mirrors the V-Log
    /// path so cross-curve consistency stays trivial to audit.
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

    /// Build a 33³ S-Log3 → Rec.709 cube for `CIColorCubeWithColorSpace`.
    static func makeSlog3ToRec709Cube(size: Int = 33) -> [Float] {
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
                    let converted = slog3PixelToRec709(
                        red: redIn,
                        green: greenIn,
                        blue: blueIn
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

    // MARK: - Gamut matrices

    /// Rec.2020 → Rec.709 conversion matrix (D65 → D65, no chromatic
    /// adaptation). Used by Apple Log / Apple Log 2 source profiles.
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
}
