# Filmtone Desktop v0.4.4

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### ProRes MOV Support

ProRes MOV files — including LOG footage from sources like Artlist and Artgrid —
can now be previewed and exported. All ProRes profiles are supported (HQ, 4444,
LT, etc.). On import, ProRes sources are automatically converted to an optimized
intermediate format (the same mezzanine pipeline introduced in v0.4.3 for HEVC).

DCI 4K (4096×2160) and other above-UHD resolutions are now accepted as video
input. The mezzanine step downscales to FHD internally, so even 6K or 8K
sources can be graded and exported.

## Lineage

- Builds on v0.4.3 mezzanine pipeline (HEVC/VP9/AV1 auto-optimization).
- Extends mezzanine conversion to the preview loading path, not just export.
- Adds colorspace normalization for ProRes 4444 (yuv444p12le) sources.

## Checksums

```
14aa0ab27d6d056e4a7ce599977e219955c7d7fd29e6e691db1d5e6fdb0db9f9  filmtone-0.4.4-arm64.dmg
```
