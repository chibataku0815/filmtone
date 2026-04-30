# Sony S-Log3 / S-Gamut3.Cine fixture provenance

Generated: 2026-04-30T03:47:20+00:00
Repo HEAD: 7bbddc8cebb0079c2abc4c9f280ae3c546a24913
Generator: encode-ramp.py (this directory)
Color science: colour-science (BSD-3-Clause), numpy, pillow

## Spec citations

- Sony, *Technical Summary for S-Gamut3.Cine/S-Log3 and S-Gamut3/S-Log3*.
  https://pro.sony/s3/cms-static-content/uploadfile/06/1237494271406.pdf
- Verified mirror (constants match): https://antlerpost.com/colour-spaces/SLog3.html
- ColorChecker reference patches: X-Rite 1976 chart constants
  (https://en.wikipedia.org/wiki/ColorChecker — public-domain math
  reference, not the X-Rite product image).

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift S-Log3 assertions. Drift
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
