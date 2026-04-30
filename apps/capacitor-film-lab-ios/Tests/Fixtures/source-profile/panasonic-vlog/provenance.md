# Panasonic V-Log fixture provenance

Generated: 2026-04-30T03:43:45+00:00
Repo HEAD: 7382e3bdcfcaaff1509d84023644d9c68b00ed84
Generator: encode-ramp.py (this directory)
Color science: colour-science (BSD-3-Clause), numpy, pillow

## Spec citations

- Panasonic, *V-Log/V-Gamut REFERENCE MANUAL*, November 28, 2014.
  https://pro-av.panasonic.net/en/cinema_camera_varicam_eva/support/pdf/VARICAM_V-Log_V-Gamut.pdf
- Verified mirror (constants match): https://antlerpost.com/colour-spaces/VGamut.html
- ColorChecker reference patches (X-Rite 1976 chart, transcribed at
  https://en.wikipedia.org/wiki/ColorChecker — public-domain mathematical
  reference, not the X-Rite product image).

## Hard gate

This fixture is the ground truth the Swift accuracy test
(scripts/swift/test-source-profile-math.swift) compares against. Drift
beyond the D-CP5 budget MUST fail the build:

- linearization: max |Δ| ≤ 1e-3 over 4096-point ramp
- Macbeth ΔE2000: max ≤ 2.0, mean ≤ 1.0
- full-frame: max ≤ 2/255, mean ≤ 0.5/255
- edge cases (V<0.05 or V>0.95): max ≤ 4/255 (mean only)

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
