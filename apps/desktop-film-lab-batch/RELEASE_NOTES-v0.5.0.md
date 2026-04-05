# Filmtone Desktop v0.5.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> Film doesn't just look — it moves, ages, and breathes. Now Filmtone does too.

### Grain v3

The grain engine has been rebuilt from the ground up. Three iterations
converged on a per-pixel hash with organic clumping and separate
chroma/luma channels — red and blue grains drift independently while
green stays luminance-only, the way silver-halide crystals behave in
real film stock.

- **Grain Size** — a new parameter controls cluster density from
  ultra-fine (0) to coarse (1). Each of the 10 built-in presets now
  carries a tuned `grainSize` value matching its real-world stock.
- **Organic clumping** — grain no longer tiles uniformly. Clusters
  form and break naturally, eliminating the synthetic-noise look of
  earlier versions.
- **Temporal cadence** — grain refreshes at 3 fps, matching the
  perceptual rhythm of projected film.

### Diffusion (Pro-Mist filter)

A new `diffusion` parameter adds a full-image light haze comparable to
a Pro-Mist filter on the lens. Unlike bloom, which targets bright
spots, diffusion lifts the entire image through a 3-level mip pyramid
and screen blend — producing a subtle, even glow that softens contrast
without losing detail.

Five presets ship with diffusion values where a Pro-Mist character fits
the stock (Cinematic 0.06, Portra 0.05, Gold 200 0.04, B&W 0.04,
CineStill 800T 0.08).

### CineStill 800T halation removed

The CineStill 800T preset no longer applies halation by default
(`halationIntensity` 0.32 → 0). The halation slider remains available
for manual dialing.

### UI reorganization

- **Hidden low-quality effects** — Light Shafts, Dust, and Scratch
  controls are hidden from the UI while they mature. The renderer
  guards prevent stale saved values from activating these effects.
- **Pro panel rearranged** — LUT panel moved below presets, Log
  Conversion opens by default, Compare section collapses by default.
- **Cleaner labels** — LUT slider labels shortened for clarity,
  redundant export-tab copy removed, sidebar toggle made consistent
  across all tabs.

**Note:** Existing projects may look different when opened in v0.5.0
due to the new grain engine and per-preset grainSize/diffusion values.

## Lineage

- Grain rewritten from single-pass uniform noise to per-pixel hash
  with organic clumping and chroma/luma separation.
- Diffusion adds a 3-level mip pyramid (no prefilter) with screen
  blend, capped at 0.29 multiplier for tasteful maximum intensity.
- Post-composite render target chain now active — enables future
  per-frame temporal effects.
- Motion blur (Slow Shutter) is the only active post-composite effect
  in v0.5.0. Light Shafts and Dust/Scratches are implemented but
  UI-hidden and renderer-guarded for v0.6.
- All 10 presets recalibrated with individual grainSize and diffusion
  values.
- Includes all v0.4.5 features (Bloom/Halation rework) and prior
  Desktop improvements.

## Checksums

```
886c339873c34dbae1a8f0ebfbae114375c2c494e8a7ac57851a329de295f363  filmtone-0.5.0-arm64.dmg
```
