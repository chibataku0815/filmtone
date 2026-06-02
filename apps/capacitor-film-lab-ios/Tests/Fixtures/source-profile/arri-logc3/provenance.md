# ARRI LogC3 + AWG3 fixture provenance

Generated: 2026-05-31T13:52:14+00:00
Repo HEAD: 0672de8c42d81c3c6bae83edf965dcb9d47148be
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- ARRI, *ALEXA Log C Curve - Usage in VFX*, exposure-value LogC3 EI 800 parameters.
  https://www.arri.com/resource/blob/31918/66f56e6abb6e5b6553929edf9aa7483e/2017-03-alexa-logc-curve-in-vfx-data.pdf
- ARRI Log C learning docs.
  https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/log-c
- ARRI LUT Generator.
  https://www.arri.com/en/learn-help/learn-help-camera-system/tools/lut-generator
- Panasonic LUMIX S1II ARRI LogC3 product note.
  https://www.panasonic.com/uk/consumer/cameras-camcorders/lumix-s-mirrorless-full-frame-cameras-learn/article/s1ii-videography.html
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Transform

Filmtone normalizes ARRI LogC3 / ARRI Wide Gamut 3 into Rec.709 SDR:

1. Decode LogC3 with EI 800 exposure-value parameters.
2. Convert linear AWG3 to Rec.709 with ARRI's matrix.
3. Apply Filmtone SDR shoulder.
4. Apply the Rec.709 OETF.

This fixture does not emulate or bundle ARRI Classic 709 / K1S1 looks.

## Combined matrix (AWG3 -> Rec.709)

```
[[ 1.617523 -0.537287 -0.080237]
 [-0.070573  1.334613 -0.264040]
 [-0.021102 -0.226954  1.248056]]
```

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift ARRI LogC3 + AWG3 assertions
(linearization 1e-3 max |Δ|, Macbeth ΔE2000 max 2.0 / mean 1.0,
full-frame max 2/255 / mean 0.5/255).

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
