# DJI D-Log fixture provenance

Generated: 2026-05-02T04:44:14+00:00
Repo HEAD: 72c7c5e0bf24fcdca349fb3e1947fd15fa274828
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- DJI, *White Paper on D-Log and D-Gamut of DJI Cinema Color System, DJI
  Zenmuse X9 6K & 8K*, Rev.1.0, 2022.02.
  https://dl.djicdn.com/downloads/DJI_Ronin_4D/X9_D_Log_D_Gamut_Whitepaper_I.pdf
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift D-Log assertions.

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
