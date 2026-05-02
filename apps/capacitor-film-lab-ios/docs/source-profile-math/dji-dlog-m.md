# DJI D-Log M -> Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's DJI D-Log M decoding. The math
is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog-m/`
via `scripts/swift/test-source-profile-math.swift`.

This profile is **distinct** from `dji-dlog` (DJI D-Log original on
Zenmuse X9 / Inspire 3). Both the transfer curve and the gamut differ;
aliasing them would produce wrong color on real Mavic 3 Pro / Osmo
Pocket 3 / Osmo 360 footage shot in D-Log M.

## Coverage

DJI ships a byte-identical (SHA-256 `b18162854ab47702...`) D-Log M to
Rec.709 V1 cube for:

- DJI Mavic 3 Pro
- DJI Osmo Pocket 3
- DJI Osmo 360

A single `built-in:source-profile.dji-dlog-m` catalog entry covers all
three consumer bodies.

## Source material (synthesized fit)

DJI has not published a formal D-Log M transfer/gamut specification.
The constants in `FilmtoneSourceProfileMath.dlogMDecode` and
`dgamutMToRec709` are **fitted** from DJI's official
`D-Log M to Rec.709 V1.cube` (downloaded from
https://www.dji.com/downloads/softwares/osmo-pocket-3-dlog-to-rec709).
The cube file itself is **not redistributed** in this repo; only the
fitted coefficients are committed. License posture: derivative
coefficients are fair game; the original LUT is not.

The fit pre-compensates Filmtone's SDR shoulder so that
`filmtoneSdrShoulder(decode_M(V))` reproduces the cube's gray-axis
output, then jointly refines the matrix on a 9^3 voxel sub-grid in
Rec.709-encoded space. See
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog-m/encode-ramp.py`
for the full fit pipeline and `provenance.md` (in the same directory)
for the residual report against DJI's cube.

## Decoding (encoded D-Log M V -> linear scene-referred L)

Piecewise log of the same shape as DJI D-Log original. The 6 free
parameters (cut, offset, slope, a, b, c) are fitted; the 7th (`d`) is
derived from continuity at the breakpoint.

```
DLOGM_CUT             = 0.1113510236
DLOGM_LINEAR_OFFSET   = 0.0000000120
DLOGM_LINEAR_SLOPE    = 7.5547639793
DLOGM_LOG_A           = 1.5389476580
DLOGM_LOG_B           = -1.8459129538
DLOGM_LOG_C           = 0.0165823994
DLOGM_LOG_D           = 0.3103580873   # derived from continuity at CUT

if V <= DLOGM_CUT:
    L = (V - DLOGM_LINEAR_OFFSET) / DLOGM_LINEAR_SLOPE
else:
    L = (10^(DLOGM_LOG_A * V + DLOGM_LOG_B) - DLOGM_LOG_C) / DLOGM_LOG_D
```

Implemented in `FilmtoneSourceProfileMath.dlogMDecode(_:)`.

## D-Gamut M -> Rec.709 matrix

Both spaces are treated as D65, so no chromatic adaptation is applied.
The matrix is fitted under the row-sum = 1 (gray-axis preserving)
constraint:

```
[[+1.4312693292, -0.4338679939, +0.0025986647],
 [-0.0747311522, +1.1578502353, -0.0831190830],
 [-0.0570111279, -0.2731296886, +1.3301408164]]
```

Less aggressive negative coefficients than D-Gamut original — D-Log M
targets a slightly narrower gamut closer to Rec.709, consistent with
DJI's positioning of D-Log M as the consumer-camera log curve.

Implemented in `FilmtoneSourceProfileMath.dgamutMToRec709`.

## Pipeline order

```
encoded D-Log M (D-Gamut M)
    -> dlogMDecode
    -> dgamutMToRec709
    -> filmtoneSdrShoulder
    -> rec709Encode
    -> Rec.709 SDR code value
```

`filmtoneSdrShoulder` and `rec709Encode` are shared with every other
Source Profile so cross-source exports get one common Filmtone display
look.

## Accuracy budget (gate)

| Metric | Tolerance |
|---|---|
| Linearization (V -> L) | `max |delta| <= 1e-3` over 4096-point ramp |
| Macbeth dE2000 | `max <= 2.0, mean <= 1.0` |
| Full-frame Rec.709 SDR /255 | `max <= 2.0, mean <= 0.5` |

Regenerate locally with `bun run gen:fixtures:dlogm`. The fixture is
the hard gate -- drift beyond these budgets must fail the gate, not be
silently absorbed.

The accuracy gate compares Swift output to the Python-emitted fixture,
both running the same fitted coefficients. It does **not** compare to
DJI's official cube directly (see "DJI cube residual" below for why).

## DJI cube residual (informational, NOT gated)

Reconstructing the Filmtone forward pipeline with the fitted constants
and comparing voxel-by-voxel against the DJI cube produces structurally
non-zero residual because Filmtone substitutes its own SDR shoulder for
DJI's. This residual is intentional and recorded in `provenance.md`,
but it is **not** part of the accuracy gate. Every existing Filmtone
synthesized profile (D-Log original / C-Log / C-Log 3 + Cinema Gamut /
V-Log / S-Log3) shows the same Filmtone-shouldered behavior on
manufacturer reference charts; the cross-profile look unification is
the point.

## Out of scope (future profiles)

- DJI D-Log original (already shipped as `built-in:source-profile.dji-dlog`)
- DJI Cinema-color D-Log XL (Inspire 3 / Ronin 4D variant) — different
  curve and a wider gamut
