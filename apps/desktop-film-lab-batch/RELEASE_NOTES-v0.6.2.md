# Filmtone Desktop v0.6.2

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> This patch makes the Cross Filter surface match the product decision that is already in source: harder defaults, fewer ambiguous controls, and clearer streak choices.

### Cross Filter now ships as Hard-only at the product surface

Soft mode is frozen for now. The current Soft result is too weak to present as
a reliable user-facing choice, so Filmtone now treats Cross Filter as Hard-only
through the product surface.

- The Soft implementation remains in the codebase as internal reference work.
- Restored and shared state is normalized back to Hard-only behavior.
- The product UI no longer asks you to switch between Soft and Hard.

### Spikes is now a discrete 4 / 6 / 8 selection

Cross Filter spikes behave like a character choice, not a continuous quantity.
The old slider suggested a precision that the effect does not really provide, so
it has been replaced with a direct discrete selection.

- Choose from `4`, `6`, or `8` spikes explicitly.
- Shared and restored state now maps cleanly onto the supported values.
- The control surface is simpler to read when dialing in streak texture.

## Recent lineage

What changed from previous versions, in plain terms:

- **v0.6.1 → v0.6.2**: Publicly ships the Cross Filter product-surface cleanup: Soft mode is frozen at the product surface, restored/shared state normalizes to Hard, and Spikes now uses a discrete `4 / 6 / 8` selection.
- **v0.6.0 → v0.6.1**: Fixed preview recovery after export, restored the launch-time update banner, retuned glow for black-mist night scenes, and corrected hard cross-filter spacing.
- **v0.5.1 → v0.6.0**: Added the new Cross Filter optical effect. Improved compare and playback controls, made slider reset easier to discover, picked more representative first thumbnails, aligned loading typography, and added a persistent local proxy cache with automatic pruning and manual purge.
- **v0.5.0 → v0.5.1**: Instant preview for heavy footage (ProRes, 4K HEVC). Motion blur rebuilt with eight-frame ring buffer and real shutter-angle control. Portrait video displayed in full frame with frosted-glass letterbox. Before / After split fixed so motion blur only appears on the graded side.
- **v0.5.0**: Grain completely rebuilt — now unique per stock with natural clumping and independent color grain. New Diffusion effect added. CineStill 800T halation turned off by default. All 10 presets recalibrated with individual grain and diffusion values. UI simplified.
- **v0.4.5**: Bloom and halation effects redesigned for smoother, more natural glow. All presets retuned.
- **v0.4.0 and earlier**: Foundation — 10 film stock presets, LUT support, batch export, signed and notarized macOS app.

## Checksums

```text
f5757cca4adc113348b3588f6c22cc6e11ddd2b8e7ebc5f3c7f4f0eab62a5077  filmtone-0.6.2-arm64.dmg
```
