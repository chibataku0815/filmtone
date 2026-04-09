# Filmtone Desktop v0.6.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> This patch focuses on the moments where trust matters most: launch, export, and low-light finishing.

### Preview now recovers after export

Some exports could leave the live preview black or unresponsive after the
render pipeline released its WebGL resources. Filmtone now treats export
cleanup more defensively and, when needed, reloads the current source into
a fresh preview runtime automatically.

- The export renderer now forces its own context to close instead of
  lingering and contaminating the interactive preview.
- The app detects preview context loss after export.
- If the current source was user media, Filmtone reloads it for you
  instead of leaving you in a broken preview state.

### Launch-time update banner works again

The update check is now triggered as soon as the renderer is ready,
instead of depending on the old delayed path alone. In practice, that
means builds with an embedded update URL can surface a newer release on
launch again, while still keeping the delayed fallback for abnormal cases.

### Better glow for black-mist night scenes

The glow stack has been retuned for darker night footage where bloom and
halation can easily collapse into flat white plates.

- Glow energy now rolls off with a softer shoulder, so highlight cores
  stay controlled while the outer glow can remain broad.
- Downsample and upsample passes now mirror at the edges, which avoids
  harsher cutoff behaviour near the frame boundary.
- The built-in **Cinematic** and **CineStill 800T** presets have been
  adjusted to land in a better starting range for this look.

### Hard cross-filter spacing behaves more predictably

The stricter cross-filter mode now does a better job separating nearby
highlight sources before streak generation, instead of producing spacing
behaviour that could feel inconsistent or overly dense.

### Cross Filter soft mode is frozen for now

The current Soft mode is too weak to ship as a reliable product surface,
so Filmtone now runs Cross Filter in Hard mode only.

- The Soft implementation remains in the codebase as a future reference.
- The product UI no longer asks you to choose between Soft and Hard.
- **Spikes** is now a discrete selection instead of a misleading slider.

### Effects panel is easier to steer

The former finish controls have been regrouped into a clearer **Effects**
section with families such as Glow, Cross, Texture, Lens, and Motion.
Quick Start states make it faster to get to a light or stronger look
before opening advanced controls.

This keeps the panel closer to how you actually judge a finish: proof the
direction first, then open the deeper sliders only when needed.

## Lineage

What changed from previous versions, in plain terms:

- **v0.6.0 → v0.6.1**: Fixed preview recovery after export, restored the
  launch-time update banner, retuned glow for black-mist night scenes,
  corrected hard cross-filter spacing, froze product use of Soft mode,
  and reorganized the finish controls into a clearer Effects panel with
  quicker starting points.
- **v0.5.1 → v0.6.0**: Added the new Cross Filter optical effect. Improved
  compare and playback controls, made slider reset easier to discover,
  picked more representative first thumbnails, aligned loading typography,
  and added a persistent local proxy cache with automatic pruning and
  manual purge.
- **v0.5.0 → v0.5.1**: Instant preview for heavy footage (ProRes, 4K
  HEVC). Motion blur rebuilt with eight-frame ring buffer and real
  shutter-angle control. Portrait video displayed in full frame with
  frosted-glass letterbox. Before / After split fixed so motion blur
  only appears on the graded side.
- **v0.5.0**: Grain completely rebuilt — now unique per stock with
  natural clumping and independent color grain. New Diffusion effect
  added. CineStill 800T halation turned off by default. All 10 presets
  recalibrated with individual grain and diffusion values. UI simplified.
- **v0.4.5**: Bloom and halation effects redesigned for smoother, more
  natural glow. All presets retuned.
- **v0.4.0 and earlier**: Foundation — 10 film stock presets, LUT
  support, batch export, signed and notarized macOS app.

## Checksums

```text
0bba08263ef3e2853a108e9e341121335e24107a1effa2c6fbdc6ebdbfd237cd  filmtone-0.6.1-arm64.dmg
```
