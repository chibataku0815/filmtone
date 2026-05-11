# Canon Log 3 + Cinema Gamut -> Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's Canon Log 3 + Cinema Gamut
decoding. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/canon-log3-cinema-gamut/`
via `scripts/swift/test-source-profile-math.swift`.

This profile is **distinct** from `canon-clog` (original Canon Log + BT.709
gamut). Both the transfer curve and the gamut differ — aliasing them would
produce wrong color on real Cinema EOS / R5 / R5C / R6 / R7 footage shot in
this combination.

## Spec citations

- **Primary**: Canon, *White Paper Canon Log Gamma Curves*.
  https://www.usa.canon.com/content/dam/canon-assets/white-papers/pro/white-paper-canon-log-gamma-curves.pdf
- **Implementation reference**: Colour Science Canon Log 3 v1.2 (Canon
  2020) reference implementation, byte-for-byte source for the 8 piecewise
  coefficients used below.
  https://github.com/colour-science/colour/blob/develop/colour/models/rgb/transfer_functions/canon.py
- **Cinema Gamut primaries / RGB->XYZ matrix**: Antler Post Cinema Gamut.
  https://antlerpost.com/colour-spaces/CinemaGamut.html
- **Rec.709 / BT.709 OETF and XYZ matrix**: ITU-R BT.709-6 Annex 1.
- **Residual reference (optional)**: Canon official LUT
  `CinemaGamut_CanonLog3-to-BT709_WideDR_65_FF_Ver.2.0.cube`
  (https://th.canon/en/support/0200422502).

## Decoding (encoded Canon Log 3 V -> linear scene-referred L, reflection)

Canon Log 3 v1.2 (Canon 2020) is a piecewise function with two log tails
and a linear midsection. Break points at encoded `V = 0.097465473` and
`V = 0.15277891` correspond to scene-linear `±0.014` (×0.9 reflection
scale equals the published `±0.0126` reference value):

```
if V < 0.097465473:
    L = -(10^((0.12783901 - V) / 0.36726845) - 1) / 14.98325 * 0.9
elif V <= 0.15277891:
    L = (V - 0.12512219) / 1.9754798 * 0.9
else:
    L = (10^((V - 0.12240537) / 0.36726845) - 1) / 14.98325 * 0.9
```

Spec test: `V = 34.338937 / 100` decodes to exactly `L = 0.18` (18% gray).

Implemented in `FilmtoneSourceProfileMath.canonLog3Decode(_:)`.

## Cinema Gamut -> Rec.709 matrix

Both spaces share D65 white, so no chromatic adaptation is required.
The combined matrix is the precomputed product of:

- **Cinema Gamut RGB -> CIE XYZ** (Antler Post, D65):
  ```
  [[ 0.71604965  0.12968348  0.10472280]
   [ 0.26126136  0.86964215 -0.13090350]
   [-0.00967635 -0.23648164  1.33521573]]
  ```
- **CIE XYZ -> Rec.709** (ITU-R BT.709-6, D65, Bruce Lindbloom).

Result, used in `FilmtoneSourceProfileMath.cineGamutToRec709`:

```
[[ 1.92355517 -0.79863353 -0.12508072]
 [-0.20431556  1.49593305 -0.29159440]
 [-0.02369073 -0.42022784  1.44415855]]
```

Sanity: `(1, 1, 1)_CinemaGamut -> (~1, ~1, ~1)_Rec709` because both spaces
share D65 white.

## Pipeline order

```
encoded Canon Log 3 (Cinema Gamut)
    -> canonLog3Decode
    -> cineGamutToRec709
    -> filmtoneSdrShoulder
    -> rec709Encode
    -> Rec.709 SDR code value
```

`filmtoneSdrShoulder` and `rec709Encode` are shared with every other
Source Profile so cross-source exports get one common display look.

## Accuracy budget

| Metric | Tolerance |
|---|---|
| Linearization (V -> L) | `max |delta| <= 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max <= 2/255, mean <= 0.5/255` |
| Macbeth DeltaE2000 | `max <= 2.0, mean <= 1.0` |

Regenerate locally with `bun run gen:fixtures:clog3`. The fixture is the
hard gate — drift beyond these budgets must fail the gate, not be silently
absorbed.

## Out of scope (future profiles)

- Canon Log 2 + Cinema Gamut (different curve, same gamut).
- Canon Log 3 + BT.709 (same curve, BT.709 gamut — Cinema EOS users can
  shoot in this combination on some bodies).
- Canon Log 3 + Cinema Gamut + Wide DR LUT shoulder variant (the Canon
  shipped LUT `Ver.2.0` includes a custom display shoulder; Filmtone
  applies its own `filmtoneSdrShoulder` instead).
