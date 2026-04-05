# Filmtone Desktop v0.4.5

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

### Bloom & Halation rework

The bloom and halation effects have been completely redesigned for smoother,
more natural results.

- **Smoother bloom spread** — glow transitions are now seamless, eliminating
  hard edges and ring artifacts that could appear around bright areas.
- **Precise halation** — the warm color bleed now targets only point light
  sources and blown highlights, so skin tones and shadows stay clean.
- **Graceful at any setting** — even extreme slider positions produce tasteful,
  film-like results instead of visual breakdowns.
- **Recalibrated presets** — all 10 built-in film stocks have been retuned
  for more accurate and natural bloom and halation behavior.

**Note:** Existing projects may look slightly different when opened in v0.4.5
due to the improved rendering pipeline.

## Lineage

- Replaces the single-scale Gaussian blur with a multi-resolution pyramid for
  both bloom (5 levels) and halation (6 levels).
- Composite blending changed from additive to screen blend, preserving highlight
  detail instead of clipping.
- All 10 preset bloom/halation values recalibrated based on reference film stocks.

## Checksums

```
f26c61d20b785c2379de0f5e5b17a7b01da65c21d511819b0e37b2b308b84857  filmtone-0.4.5-arm64.dmg
```
