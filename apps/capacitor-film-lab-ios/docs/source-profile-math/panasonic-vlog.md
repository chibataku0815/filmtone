# Panasonic V-Log → Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's V-Log decoding and V-Gamut →
Rec.709 conversion. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/panasonic-vlog/`
via `scripts/swift/test-source-profile-math.swift`.

## Spec citations

- **Primary**: Panasonic, *V-Log/V-Gamut REFERENCE MANUAL*, November 28, 2014.
  https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf
- **Verified mirror** (constants reproduced verbatim):
  https://antlerpost.com/colour-spaces/VGamut.html

## Constants (V-Log decoder)

```
cut2 = 0.181
b    = 0.00873
c    = 0.241514
d    = 0.598206
```

## Decoding (encoded V → linear scene-referred L)

```
if V <  cut2:  L = (V - 0.125) / 5.6
if V >= cut2:  L = 10^((V - d) / c) - b
```

Implemented in `FilmtoneSourceProfileMath.vlogDecode(_:)`.

## V-Gamut → XYZ matrix (D65)

```
[[ 0.679644,  0.152211,  0.118600],
 [ 0.260686,  0.774894, -0.035580],
 [-0.009310, -0.004612,  1.102980]]
```

## V-Gamut → Rec.709 matrix (precomputed, D65 → D65, no chromatic adaptation)

```
[[ 1.7398, -0.6727, -0.0671],
 [-0.1956,  1.2473, -0.0518],
 [-0.0114, -0.0440,  1.0554]]
```

This matrix is the product of `XYZ → Rec.709` (standard) and `V-Gamut →
XYZ`. It is implemented in `FilmtoneSourceProfileMath.vgamutToRec709(...)`
and reproduced in the Python fixture generator
(`Tests/Fixtures/source-profile/panasonic-vlog/encode-ramp.py`) so the
two sides cross-verify each other.

## Pipeline order (`FilmtoneSourceProfileMath.vlogPixelToRec709`)

```
encoded V-Log  →  vlogDecode (linearize)
                  ↓
                  vgamutToRec709 (matrix in linear light)
                  ↓
                  filmtoneSdrShoulder (highlight roll-off, 0.18 anchor)
                  ↓
                  rec709Encode (BT.709 OETF)
                  ↓
                  Rec.709 SDR code value
```

The Filmtone SDR shoulder + Rec.709 OETF live in
`FilmtoneSourceProfileMath` as well — they are shared verbatim with the
existing Apple Log path so cross-curve outputs render with one display
look.

## Accuracy budget (D-CP5)

| Metric | Tolerance |
|---|---|
| Linearization (V → L) | `max |Δ| ≤ 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max ≤ 2/255, mean ≤ 0.5/255` |
| Macbeth ΔE2000 | `max ≤ 2.0, mean ≤ 1.0` |
| Edge cases (V<0.05 or V>0.95) | `max ≤ 4/255 (mean only)` |

The fixture under
`Tests/Fixtures/source-profile/panasonic-vlog/` is regenerated locally
with `bun run gen:fixtures:vlog` (which invokes the Python script via
`uv run --with colour-science --with numpy --with pillow`). The current
recorded budget run reports `max = 0.000` across all three metrics —
expected, because Python and Swift transcribe the same constants in the
same operator order.

If the budget ever drifts beyond the values above, the build MUST fail
(no silent fallback per CLAUDE.md `feedback_no_fallback_bug_hotbed`).
Investigate first; only regenerate the fixture if the upstream spec or
Filmtone shoulder definition changed deliberately.

## v1.4 candidates

- ARRI LogC4 (license review pending)
- Nikon N-Log
- Canon Log 3
- BMD Film Gen 5

Each (S) curve must ship with math doc + fixture + accuracy test in the
SAME PR.
