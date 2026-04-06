# Filmtone Desktop v0.5.1

- Download URL: `https://www.chibatakumi.studio/film-lab/download`
- Platform: macOS only
- Minimum macOS: `11.0+`
- Architecture: Apple Silicon (`arm64`)
- Official artifact: signed + notarized `DMG`
- Updates: in-app notification + manual download replacement
- Support: `chiba@fores-tone.co.jp`

## What changed

> Heavy footage used to mean waiting. Now it means instant preview.

### Instant preview for heavy footage

ProRes, 4K HEVC, and other demanding formats no longer stall the
interface while Filmtone prepares them. The moment you open a file,
a native-decoded preview appears so you can start grading immediately.
In the background, Filmtone converts the footage into an optimised
intermediate using hardware-accelerated VideoToolbox. When the
conversion finishes, the player switches seamlessly to the higher-quality
stream — no restart, no interruption.

The same intermediate is reused at export time, so you never convert the
same file twice. A small quality badge in the corner tells you which
stage the player is in.

### Shutter-angle motion blur

Motion blur has been completely rebuilt. Instead of a simple one-frame
blend, Filmtone now accumulates up to eight frames in a ring buffer and
blends them with a weighted curve — the same principle behind a real
camera's rotary shutter.

- **Shutter Angle** (0 -- 720 degrees) — controls how many frames
  contribute to the blur. 180 degrees gives a natural cinema look,
  360 degrees doubles the trail, and 720 degrees uses all eight frames
  for a dreamy, drawn-out streak.
- **Trail Intensity** (0 -- 0.95) — adds a feedback loop that extends
  the motion trail beyond the buffer, useful for stylised or
  experimental looks.

The weight curve shifts automatically: a triangle distribution up to
360 degrees for natural fall-off, flattening to a box curve above that
for even, extended trails.

### Portrait video support

Vertical (9:16) footage now displays in full-frame **contain** mode
instead of being cropped to landscape. The letterbox areas on either
side are filled with a frosted-glass version of the video itself,
giving portrait clips a polished, finished look without any manual
setup.

### Before / After comparison — fixed

A bug caused the motion blur effect to appear on both sides of the
Before / After split view. The original side is now rendered clean —
exactly as your footage looks without any grading — while the graded
side shows the full effect chain including motion blur. Switching
between single and split view also resets the blur buffer so no
ghost frames leak across modes.

## Lineage

What changed from previous versions, in plain terms:

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

```
22be00fa8160006d408f46d3d3e0234306e57ea4bec3e9d71f919053585bc692  filmtone-0.5.1-arm64.dmg
```
