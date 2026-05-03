# DJI D-Log M fixture provenance

Generated: 2026-05-02T07:19:18+00:00
Repo HEAD: 739d94b8c6e71a5c3d7294131485ad61e1130b2f
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow, scipy

## Source material

The fitted coefficients in this fixture (and in
`FilmtoneSourceProfileMath.dlogMDecode` / `dgamutMToRec709`) are derived
from the DJI consumer-camera D-Log M to Rec.709 cube:

- Path used for fit: `/Users/chibatakumi/Downloads/DJI OSMO Pocket 3 D-Log M to Rec.709 V1.cube`
- Cube SHA-256: `b18162854ab47702068410c33afa98a8cb6eef159fc5a04ce0e65fad0fd8947e`
- Cube header: `# Mavic 3 Pro, D-Log M, 2023-03-24`
- DJI download: https://www.dji.com/downloads/softwares/osmo-pocket-3-dlog-to-rec709
- Coverage: DJI ships a byte-identical cube for Mavic 3 Pro, Osmo
  Pocket 3, and Osmo 360, so a single fitted profile serves all three
  consumer bodies.

The cube file itself is **not redistributed in this repo** -- only the
fitted coefficients below are committed (license posture per
`docs/filmtone/ios/2026-05-02-...handoff` §3.2).

## Fitted decode_M (D-Log M -> linear scene-referred)

Piecewise log of the same shape as DJI D-Log original. The 6 free
parameters are fitted by `scipy.optimize.least_squares` against the
grayscale axis of the cube restricted to V <= 0.45 (where
DJI's display shoulder is approximately identity). The 7th coefficient
`d` is derived from continuity at `cut`.

```
DLOGM_CUT             = 0.1113510236
DLOGM_LINEAR_OFFSET   = 0.0000000120
DLOGM_LINEAR_SLOPE    = 7.5547639793
DLOGM_LOG_A           = 1.5389476580
DLOGM_LOG_B           = -1.8459129538
DLOGM_LOG_C           = 0.0165823994
DLOGM_LOG_D           = 0.3103580873     # derived from continuity at CUT
```

Decode formula:

```
decode_M(V) = (V - DLOGM_LINEAR_OFFSET) / DLOGM_LINEAR_SLOPE                    if V <= DLOGM_CUT
              (10^(DLOGM_LOG_A * V + DLOGM_LOG_B) - DLOGM_LOG_C) / DLOGM_LOG_D  if V >  DLOGM_CUT
```

Fit residual on the low-mid grayscale samples used for the fit:
`max |delta| = 1.111389e-01`.

## Fitted DGAMUT_M -> Rec.709 matrix

Linear regression on primary and mixed-axis samples at V in {0.30, 0.40, 0.45}
under the row-sum = 1 constraint (preserves the grayscale axis):

```
[[+1.43126933, -0.43386799, +0.00259866],
 [-0.07473115, +1.15785024, -0.08311908],
 [-0.05701113, -0.27312969, +1.33014082]]
```

Row sums: 1.000000, 1.000000, 1.000000 (target 1.000000).

## Pipeline order (Filmtone forward)

```
encoded V_dlog_m -> dlogMDecode -> dgamutMToRec709 -> filmtoneSdrShoulder -> rec709Encode
```

Filmtone substitutes its own SDR shoulder for DJI's so that cross-source
exports share one common display look.

## DJI cube residual (informational, NOT part of the accuracy gate)

Reconstructing the Filmtone forward pipeline with the fitted constants
and comparing voxel-by-voxel against the DJI cube (33^3 = 35,937 voxels)
gives the residual below. This is structurally non-zero because Filmtone
applies its own shoulder; the shoulder swap residual is intentional and
the accuracy gate (linearization 1e-3 / Macbeth dE2000 2.0/1.0 /
full-frame 2/255 0.5/255) does **not** include this metric.

```
Low-mid voxels (max V <= 0.45, n=3,375):
  dE2000 max  = 11.7660
  dE2000 mean = 2.6518

High-luminance voxels (max V > 0.45, n=32,562):
  dE2000 max  = 15.4286
  dE2000 mean = 2.0500

Full cube (all 35,937 voxels), code-value drift /255:
  max  = 55.7600
  mean = 5.9596
```

If `high_max_de > 4.0` or `low_max_de > 1.0`, the parametric form / fit
strategy needs to be reconsidered. The script halts before emitting
fixture artifacts in that case; surface to the user (do not silently
relax the budget).

## Hard gate (accuracy fixture)

This fixture is the ground truth for
`scripts/swift/test-source-profile-math.swift` D-Log M assertions.
Budgets:

- Linearization V->L: max |delta| <= 1e-3 over 4096 samples
- Macbeth dE2000: max <= 2.0, mean <= 1.0
- Full-frame /255: max <= 2.0, mean <= 0.5

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
