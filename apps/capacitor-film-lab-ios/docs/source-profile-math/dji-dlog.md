# DJI D-Log / D-Gamut -> Rec.709 (Filmtone Source Profile)

This document is the SSOT for Filmtone's DJI D-Log decoding and D-Gamut ->
Rec.709 conversion. The math is implemented in
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
and verified against the calibrated fixture under
`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/dji-dlog/`
via `scripts/swift/test-source-profile-math.swift`.

This profile targets documented DJI D-Log / D-Gamut, not D-Log M.

## Spec citations

- **Primary**: DJI, *White Paper on D-Log and D-Gamut of DJI Cinema Color
  System, DJI Zenmuse X9 6K & 8K*, Rev.1.0, 2022.02.
  https://dl.djicdn.com/downloads/DJI_Ronin_4D/X9_D_Log_D_Gamut_Whitepaper_I.pdf

## Decoding (encoded D-Log V -> linear scene-referred L)

```
if V <= 0.14: L = (V - 0.0929) / 6.025
if V >  0.14: L = (10^(3.89616 * V - 2.27752) - 0.0108) / 0.9892
```

Implemented in `FilmtoneSourceProfileMath.dlogDecode(_:)`.

## D-Gamut -> Rec.709 matrix

```
[[ 1.6746, -0.5797, -0.0949],
 [-0.0981,  1.3340, -0.2359],
 [-0.0410, -0.2430,  1.2840]]
```

Implemented in `FilmtoneSourceProfileMath.dgamutToRec709(...)`.

## Pipeline order

```
encoded DJI D-Log -> dlogDecode
                  -> dgamutToRec709
                  -> filmtoneSdrShoulder
                  -> rec709Encode
                  -> Rec.709 SDR code value
```

## Accuracy budget

| Metric | Tolerance |
|---|---|
| Linearization (V -> L) | `max |delta| <= 1e-3` over 4096-point ramp |
| Full-frame Rec.709 SDR | `max <= 2/255, mean <= 0.5/255` |
| Macbeth DeltaE2000 | `max <= 2.0, mean <= 1.0` |

Regenerate locally with `bun run gen:fixtures:dlog`.
