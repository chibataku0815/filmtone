# Canon Log 3 + Cinema Gamut fixture provenance

Generated: 2026-05-02T05:21:34+00:00
Repo HEAD: 0fc51412bc7314096c69d893056b895d5fda697e
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- Canon, *White Paper Canon Log Gamma Curves*.
  https://www.usa.canon.com/content/dam/canon-assets/white-papers/pro/white-paper-canon-log-gamma-curves.pdf
- Colour Science Canon Log 3 v1.2 (Canon 2020) reference implementation:
  https://github.com/colour-science/colour/blob/develop/colour/models/rgb/transfer_functions/canon.py
- Antler Post Cinema Gamut colour space reference (RGB->XYZ matrix):
  https://antlerpost.com/colour-spaces/CinemaGamut.html
- ITU-R BT.709-6 (XYZ->Rec.709 matrix at D65).
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Combined matrix (Cinema Gamut -> Rec.709, D65 -> D65, no CAT)

```
[[ 1.92355517 -0.79863353 -0.12508072]
 [-0.20431556  1.49593305 -0.29159440]
 [-0.02369073 -0.42022784  1.44415855]]
```

Computed as `XYZ_TO_REC709 @ CINEMA_GAMUT_TO_XYZ`. Sanity:
`(1,1,1)_CinemaGamut -> (~1, ~1, ~1)_Rec709` because both share D65 white.

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift Canon Log 3 + Cinema Gamut
assertions (linearization 1e-3 max |Δ|, Macbeth ΔE2000 max 2.0 / mean 1.0,
full-frame max 2/255 / mean 0.5/255).

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
