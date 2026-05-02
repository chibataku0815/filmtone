# Canon C-Log fixture provenance

Generated: 2026-05-02T04:44:27+00:00
Repo HEAD: 72c7c5e0bf24fcdca349fb3e1947fd15fa274828
Generator: encode-ramp.py (this directory)
Color science: numpy, pillow

## Spec citations

- Canon, *Canon-Log Transfer Characteristic*, June 20, 2012.
  https://downloads.canon.com/CDLC/Canon-Log_Transfer_Characteristic_6-20-2012.pdf
- Colour Science Canon Log transfer function reference:
  https://colour.readthedocs.io/en/v0.3.12/_modules/colour/models/rgb/transfer_functions/canon_log.html
- ColorChecker reference patches: X-Rite 1976 chart constants.

## Hard gate

This fixture is the ground truth for
scripts/swift/test-source-profile-math.swift C-Log assertions.

Generated artifacts (4):
- linearization-ramp.json
- macbeth-patches.json
- source-encoded.png
- expected-rec709.png
