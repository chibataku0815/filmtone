# Canon C-Log -> Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's Canon Log original (C-Log)
decoding. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/canon-clog/`
via `scripts/swift/test-source-profile-math.swift`.

This profile assumes original Canon Log in BT.709 gamut. Canon Log 2/3 and
Cinema Gamut are materially different transforms and should be added as
separate source profiles.

## Spec citations

- **Primary**: Canon, *Canon-Log Transfer Characteristic*, June 20, 2012.
  https://downloads.canon.com/CDLC/Canon-Log_Transfer_Characteristic_6-20-2012.pdf
- **Implementation reference**: Colour Science `canon_log` transfer function,
  citing Canon's 2012 white paper.
  https://colour.readthedocs.io/en/v0.3.12/_modules/colour/models/rgb/transfer_functions/canon_log.html

## Decoding (encoded Canon Log V -> linear scene-referred L)

The profile uses full-range normalized Canon Log values.

```
pivot = 0.0730597
scale = 0.529136
gain  = 10.1596

if V <  pivot: L = -((10^((pivot - V) / scale) - 1) / gain) * 0.9
if V >= pivot: L =  ((10^((V - pivot) / scale) - 1) / gain) * 0.9
```

Implemented in `FilmtoneSourceProfileMath.canonLogDecode(_:)`.

## Pipeline order

```
encoded Canon C-Log -> canonLogDecode
                    -> filmtoneSdrShoulder
                    -> rec709Encode
                    -> Rec.709 SDR code value
```

No gamut matrix is applied for this original C-Log profile because it is
treated as BT.709 gamut.

## Accuracy budget

| Metric | Tolerance |
|---|---|
| Linearization (V -> L) | `max |delta| <= 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max <= 2/255, mean <= 0.5/255` |
| Macbeth DeltaE2000 | `max <= 2.0, mean <= 1.0` |

Regenerate locally with `bun run gen:fixtures:clog`.
