# Filmtone Desktop v0.6.0

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> Filmtone now reaches beyond film stock and into the optics in front of the lens.

### Cross Filter

Filmtone now includes a new **Cross Filter** effect for bright point
lights, inspired by classic star and snow-cross lens filters. It adds
fine diffraction-style streaks that react to the image instead of sitting
on top as a generic glow.

- **Strength** controls how strongly the effect appears.
- **Points** sets the number of star directions.
- **Angle** rotates the filter just like a physical rotating frame.
- **Length** stretches or tightens the streaks.
- **Threshold** keeps the effect focused on the brightest highlights.
- **Chromatic** adds a subtle color split toward the streak tips.

The current renderer also includes the later quality passes developed
during the v0.6.0 cycle, so the streaks stay narrow, avoid spreading
across large highlight areas, and feel closer to a real optical filter.

### Video preview and compare UX

Several small but important video controls have been cleaned up.

- Compare mode now has a visible way to exit without relying on canvas
  clicks.
- Playback speed now supports faster review, including 2x playback.
- Slider reset actions are easier to discover instead of being hidden
  behind label-only gestures.

These changes make quick A/B judgment and repeat preview work feel more
deliberate and less fragile.

### Better thumbnail and loading polish

Thumbnail generation no longer blindly trusts the first near-zero frame.
For the leading thumbnail, Filmtone now probes several early candidate
frames and skips ones that are effectively black, so videos that fade in
or start on black are more likely to show a representative image.

Loading overlays have also been aligned with the rest of the app's font
stack so the transition from loading state to editor feels visually
consistent across Web and Desktop.

### Persistent proxy cache for repeat opens

Progressive preview proxies can now persist locally between launches
instead of being thrown away immediately.

- Cache location is fixed under the macOS cache directory.
- Reopening the same source can reuse an existing proxy.
- Automatic pruning keeps the cache bounded by entry count, total size,
  and age.
- A manual purge action is available from the Desktop UI.

This makes repeated work on the same heavy footage much faster while
still keeping storage growth under control.

## Lineage

What changed from previous versions, in plain terms:

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
e65df2854b7d87d191a81039642a9a9a74b92c059bd7ad7ebaa9a1f55a57af1f  filmtone-0.6.0-arm64.dmg
```
