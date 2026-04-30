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
    /// across every Camera Profile (Apple Log, Apple Log 2, V-Log, S-Log3,
    /// Rec.709 passthrough) so cross-source exports share one display look.
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
