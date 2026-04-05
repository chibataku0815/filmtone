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

### Grain — completely reimagined

Film grain is no longer a simple noise overlay. Each stock now has its own
grain character that behaves the way real silver-halide crystals do — fine
and tight for Ektar, coarse and clumpy for CineStill, gentle and even for
Portra. Color grains drift independently from luminance grains, just like
on actual film.

- **Grain Size slider** — a new control lets you dial the coarseness from
  ultra-fine to heavily textured. Each of the 10 built-in presets starts
  at a value matched to its real-world stock, so it looks right out of
  the box.
- **Natural clumping** — grain clusters form and break organically instead
  of repeating in a uniform pattern. The "digital noise" look is gone.
- **Gentle refresh** — grain evolves slowly and naturally, the way
  projected film feels in motion.

### Diffusion — like a Pro-Mist on your lens

A brand-new Diffusion effect adds a soft, even glow across the entire
image — the same quality you get from a Pro-Mist filter on the lens.
It lifts shadows gently, softens contrast, and gives skin a beautiful
luminosity without losing detail in the rest of the frame.

Five presets ship with diffusion values tailored to their character:
CineStill 800T gets the strongest glow, Cinematic and Portra sit in the
middle, and Gold 200 and B&W receive a lighter touch.

### CineStill 800T — halation off by default

The red glow around lights (halation) is now turned off by default in the
CineStill 800T preset. If you want that signature look, the halation
slider is still there — just turn it up.

### Simpler, cleaner interface

- **Focused controls** — effects that are still being refined (Light
  Shafts, Dust, Scratches) are hidden until they meet our quality bar.
  They won't accidentally activate on existing projects either.
- **Better layout** — the LUT panel now sits below presets where it
  belongs, Log Conversion opens by default for a faster start, and the
  Compare panel stays collapsed until you need it.
- **Tidier labels** — slider names are shorter, redundant text is removed,
  and the sidebar toggle is consistent everywhere.

**Note:** Existing projects may look different when opened in v0.5.0.
Each preset now carries its own grain and diffusion settings, so your
images will pick up the new film character automatically. If you prefer
the previous look, set Grain Size and Diffusion to 0 manually.

## Lineage

What changed from previous versions, in plain terms:

- **v0.4.5 → v0.5.0**: Grain completely rebuilt — now unique per stock
  with natural clumping and independent color grain. New Diffusion effect
  added. CineStill 800T halation turned off by default. All 10 presets
  recalibrated with individual grain and diffusion values. UI simplified.
- **v0.4.5**: Bloom and halation effects redesigned for smoother, more
  natural glow. All presets retuned.
- **v0.4.0 and earlier**: Foundation — 10 film stock presets, LUT
  support, batch export, signed and notarized macOS app.

## Checksums

```
886c339873c34dbae1a8f0ebfbae114375c2c494e8a7ac57851a329de295f363  filmtone-0.5.0-arm64.dmg
```
