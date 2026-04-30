# Sony S-Log3 / S-Gamut3.Cine → Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's S-Log3 decoding and
S-Gamut3.Cine → Rec.709 conversion. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/sony-slog3/`
via `scripts/swift/test-source-profile-math.swift`.

## Spec citations

- **Primary**: Sony, *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
  https://pro.sony/s3/cms-static-content/uploadfile/06/1237494271406.pdf
- **Verified mirror** (constants reproduced verbatim):
  https://antlerpost.com/colour-spaces/SLog3.html

## Constants (S-Log3 decoder)

```
threshold = 171.2102946929 / 1023.0   ≈ 0.16739734...
```

## Decoding (encoded V → linear scene-referred L)

```
if V <  threshold:  L = ((V * 1023 - 95) * 0.01125) / (171.2102946929 - 95)
if V >= threshold:  L = 10^((V * 1023 - 420) / 261.5) * (0.18 + 0.01) - 0.01
```

`V` is the 0..1 normalized code value (10-bit reference). `0.18 + 0.01`
is Sony's mid-gray anchor with the S-Log3 black offset. Implemented in
`FilmtoneSourceProfileMath.slog3Decode(_:)`.

## S-Gamut3.Cine → XYZ matrix (D65)

```
[[ 0.5990839208,  0.2489255161,  0.1024464902],
 [ 0.2150758201,  0.8850685017, -0.1001443219],
 [-0.0320658495, -0.0276583907,  1.1487819910]]
```

## S-Gamut3.Cine → Rec.709 matrix (precomputed, D65 → D65)

```
[[ 1.6269, -0.5365, -0.0904],
 [-0.1078,  1.1628, -0.0550],
 [-0.0140, -0.0240,  1.0379]]
```

This matrix is the precomputed product of `XYZ → Rec.709` and `S-Gamut3.Cine →
XYZ`. It is implemented in
`FilmtoneSourceProfileMath.sgamut3CineToRec709(...)` and reproduced in
the Python fixture generator
(`Tests/Fixtures/source-profile/sony-slog3/encode-ramp.py`).

S-Gamut3 (non-Cine) is rarely used outside FX9/Venice cameras and is
deferred to v1.4.

## Pipeline order (`FilmtoneSourceProfileMath.slog3PixelToRec709`)

```
encoded S-Log3  →  slog3Decode (linearize)
                   ↓
                   sgamut3CineToRec709 (matrix in linear light)
                   ↓
                   filmtoneSdrShoulder (highlight roll-off, 0.18 anchor)
                   ↓
                   rec709Encode (BT.709 OETF)
                   ↓
                   Rec.709 SDR code value
```

The Filmtone SDR shoulder + Rec.709 OETF are shared with the Apple Log
and V-Log paths so cross-curve outputs render with one display look.

## Accuracy budget (D-CP5)

| Metric | Tolerance |
|---|---|
| Linearization (V → L) | `max |Δ| ≤ 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max ≤ 2/255, mean ≤ 0.5/255` |
| Macbeth ΔE2000 | `max ≤ 2.0, mean ≤ 1.0` |
| Edge cases (V<0.05 or V>0.95) | `max ≤ 4/255 (mean only)` |

The fixture under
`Tests/Fixtures/source-profile/sony-slog3/` is regenerated locally with
`bun run gen:fixtures:slog3` (which invokes the Python script via
`uv run --with colour-science --with numpy --with pillow`). Current
recorded budget run reports `max = 0.000` across all metrics.

If the budget ever drifts beyond the values above, the build MUST fail
(no silent fallback per CLAUDE.md `feedback_no_fallback_bug_hotbed`).

## v1.4 candidates

- S-Gamut3 (FX9 / Venice variant)
- ARRI LogC4 (license review pending)
- Nikon N-Log
- Canon Log 3
- BMD Film Gen 5
