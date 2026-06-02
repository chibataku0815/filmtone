# ARRI LogC3 + AWG3 -> Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's ARRI LogC3 decoding and ARRI Wide
Gamut 3 -> Rec.709 conversion. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/arri-logc3/`
via `scripts/swift/test-source-profile-math.swift`.

This is a Filmtone normalization transform, not an ARRI Classic 709 / K1S1
look emulation and not a bundled ARRI display LUT.

## Spec citations

- **Primary**: ARRI, *ALEXA Log C Curve - Usage in VFX*, March 2017.
  https://www.arri.com/resource/blob/31918/66f56e6abb6e5b6553929edf9aa7483e/2017-03-alexa-logc-curve-in-vfx-data.pdf
- **ARRI Log C overview**:
  https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/log-c
- **ARRI LUT Generator**:
  https://www.arri.com/en/learn-help/learn-help-camera-system/tools/lut-generator
- **Panasonic S1II ARRI LogC3 support note**:
  https://www.panasonic.com/uk/consumer/cameras-camcorders/lumix-s-mirrorless-full-frame-cameras-learn/article/s1ii-videography.html

## Constants (LogC3 EI 800 exposure-value decoder)

```
cut = 0.010591
a   = 5.555556
b   = 0.052272
c   = 0.247190
d   = 0.385537
e   = 5.367655
f   = 0.092809
```

## Decoding (encoded LogC3 V -> linear exposure value L)

```
threshold = e * cut + f

if V > threshold:
    L = (10^((V - d) / c) - b) / a
else:
    L = (V - f) / e
```

Implemented in `FilmtoneSourceProfileMath.arriLogC3Decode(_:)`.

## AWG3 -> Rec.709 matrix

```
[[ 1.617523 -0.537287 -0.080237]
 [-0.070573  1.334613 -0.264040]
 [-0.021102 -0.226954  1.248056]]
```

Implemented in `FilmtoneSourceProfileMath.arriWideGamut3ToRec709(...)`.

## Pipeline order

```
encoded ARRI LogC3 (AWG3)
    -> arriLogC3Decode
    -> arriWideGamut3ToRec709
    -> filmtoneSdrShoulder
    -> rec709Encode
    -> Rec.709 SDR code value
```

`filmtoneSdrShoulder` and `rec709Encode` are shared with every other Source
Profile so cross-source exports get one common display look.

## Accuracy budget

| Metric | Tolerance |
|---|---|
| Linearization (V -> L) | `max |delta| <= 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max <= 2/255, mean <= 0.5/255` |
| Macbeth DeltaE2000 | `max <= 2.0, mean <= 1.0` |

Regenerate locally with `bun run gen:fixtures:arri-logc3`. The fixture is the
hard gate; drift beyond these budgets must fail the gate, not be silently
absorbed.

## Out of scope

- ARRI Classic 709 / K1S1 look LUT bundling.
- ARRI LogC4.
- Auto-detection without reliable probe-visible ARRI LogC3 metadata.
