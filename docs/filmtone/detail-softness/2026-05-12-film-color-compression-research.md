# Film Color Compression Research — Detail Softness Follow-up

Date: 2026-05-12 JST
Status: research note for the next product task
Scope: no implementation in this document

## Goal

Use the Detail Softness work as the spatial foundation, then improve
Filmtone's color / density compression so the optical stack receives a less
digital source:

```text
base grade / tone shaping
→ film color + density compression
→ detailSoftness
→ edge optics / bloom / halation / diffusion
→ grain / print / LUT
```

The desired result is not lower saturation. It is a filmic rolloff of color
pressure: saturated highlights, digital color edges, skin / paper / sky
transitions, and practical-light colors should compress into a denser and more
cohesive image before glow and optics amplify them.

## Current Filmtone State

Filmtone already has `compressionAmount` and `compressionRange`, exposed as
`Highlight softness` and `Tone span` in the Advanced Tone group. The render
implementation is intentionally hue-preserving:

- macOS/iOS native `filmCompressionV2` computes Rec.709 luma, applies a sigmoid
  to luma, then scales RGB by one scalar.
- WebGL uses the same luma-scale shape with an output clamp.
- WebGPU uses the same luma-scale shape but leaves wider intermediate values
  alive for the later soft shaper.
- The color-only baker mirrors the same luma-based sigmoid for LUT export /
  sidecar consistency.

This is a good base because it avoids per-channel compression destroying hue.
The gap is that it only compresses luma. It does not yet model filmic chroma /
colorfulness rolloff, gamut healing, or highlight color density. Strong reds,
cyans, blue LEDs, skin highlights, and highly saturated phone footage can still
feel video-like even when luma is rounded.

## Research Findings

### 1. Filmic rendering separates tone from colorfulness

ACES 2's Output Transform is useful as a reference architecture, not something
to copy wholesale. It separates rendering into tone scale, chroma compression,
gamut compression, and display encoding. ACES specifically moves into a JMh
space so lightness (`J`), colorfulness (`M`), and hue (`h`) can be handled
separately. The key product lesson: tone mapping should not blindly compress
RGB channels, and color compression should preserve hue where possible.

Source: [ACES Output Transforms](https://docs.acescentral.com/system-components/output-transforms/)

### 2. Chroma compression is the missing Filmtone layer

ACES Chroma Compression is described as hue-preserving photographic color
rendering. It keeps lightness and hue constant while compressing colorfulness.
The compression depends on both lightness and colorfulness: highlights compress
more than shadows, and the highlight rolloff affects skin rendering strongly.

Source: [ACES Chroma Compression](https://docs.acescentral.com/system-components/output-transforms/technical-details/chroma-compression/)

Filmtone does not need full Hellwig/JMh. A lightweight local model is enough for
the next product pass:

```text
Y = Rec.709 luma or current pipeline luma
N = neutral color at Y
C = rgb - N
M = length(C)
h = direction(C)
M' = compress(M, Y, amount, range, hue family)
rgb' = N + h * M'
```

This keeps the current hue-preserving intent while adding density-aware
colorfulness control.

### 3. Gamut compression should be technical healing, not the creative look

ACES Reference Gamut Compression was created to heal problematic saturated
out-of-gamut colors such as bright LEDs and police / stop lights. It deliberately
does not try to determine the "correct" color for such pixels; it produces less
problematic values for subsequent compositing and grading.

Source: [ACES Reference Gamut Compression](https://docs.acescentral.com/rgc/overview/)

For Filmtone, that implies two layers:

- Creative chroma density compression: always part of filmCompressionV3.
- Problem-color healing: only engages near high saturation / high luminance /
  gamut-edge stress, especially LEDs, neon, strong blue/cyan/red practicals.

Do not make the whole image dull to fix a few problem colors.

### 4. Log / film-scan references support the density direction

ARRI describes Log C as a wide-gamut log encoding whose grayscale
characteristic is similar to a scan from negative film, then notes that display
output requires tone mapping and a target color-space transform. The relevant
lesson for Filmtone is that "filmic" is not just a curve; it is a controlled
rendering from captured scene data into display color, with highlight handling
and color transform decisions.

Source: [ARRI Log C](https://www.arri.com/en/learn-help/learn-help-camera-system/image-science/log-c)

Kodak process-control documentation grounds the density idea through control
steps and full characteristic curves: film response is tracked as density,
contrast, and color balance across low-, mid-, and high-density regions. For
Filmtone, this supports treating color compression as a density / rolloff
problem, not as a global saturation slider.

Source: [Kodak Motion Picture Films Processing Module 1](https://www.kodak.com/content/products-brochures/Film/Processing-KODAK-Motion-Picture-Films-Module-1.pdf)

## Fit With Detail Softness

`detailSoftness` removes spatial hardness: micro-contrast, digital sharpening,
sensor-acutance bite, and small harsh detail.

Film color compression should remove color hardness:

- saturated highlights sticking to the display boundary
- hard chroma separation around bright edges
- skin highlights turning chalky or orange
- skies / walls showing brittle digital saturation
- practical lights keeping a synthetic color core under bloom / halation

The two effects should reinforce each other:

| Stage | Removes | Protects |
|---|---|---|
| Film color compression | color pressure, chroma clipping, highlight saturation hardness | hue family, skin direction, color identity |
| Detail Softness | spatial micro-hardness, sharpening bite, fine sensor harshness | text legibility, face contour, large edges |
| Glow / optics | adds light transport, scatter, halation, lens feel | black retention, direct transmission, shape |

If color compression is weak, glow rides on top of digital colors. If Detail
Softness is weak, glow rides on top of digital edges. If both are right, the
image feels captured and optically rendered instead of filtered.

## Proposed Next Task: Film Compression V3

### Product Objective

Replace the current luma-only `filmCompressionV2` with a filmic color/density
compression stage that:

- preserves hue better than per-channel RGB curves
- compresses highlight colorfulness before clipping
- keeps skin, paper, sky, and foliage natural
- makes bloom / halation / diffusion feel less pasted on
- remains neutral when `compressionAmount == 0`
- shares one parameter contract across macOS native, iOS export, WebGPU,
  WebGL, and color-only baking

### Algorithm Direction

Keep the current luma shoulder as the base, then add a second chroma-density
step:

1. Compute luma `Y` using the existing Rec.709 weights.
2. Apply the current or refined luma sigmoid shoulder to get `Y'` and
   `lumaScale`.
3. Build a neutral axis color at `Y'`.
4. Compute chroma vector from the neutral axis.
5. Compress chroma magnitude using a lightness-dependent curve:
   - little / no compression in shadows
   - mild expansion or preservation in midtones
   - stronger compression in highlights
   - extra guard for near-gamut problem colors
6. Recompose RGB from `Y' + compressed chroma`.
7. Apply a final soft gamut guard, not a hard clamp, before downstream optics.

### Initial Controls

Do not add UI in the first implementation slice. Drive V3 from the existing
controls:

- `compressionAmount`: total density / color compression strength.
- `compressionRange`: how far from highlights into midtones the luma + chroma
  rolloff reaches.

Internal constants can cover:

- `chromaCompressionMax`
- `highlightChromaKnee`
- `midtoneColorPreserve`
- `skinHueProtect`
- `problemColorGuard`

If V3 proves valuable, expose more refined controls later. The first product
pass should improve the default look, not add UI complexity.

### Placement

Keep this before `detailSoftness` and before the optical stack:

```text
baseGradeV2 → filmCompressionV3 → detailSoftness → edgeOptics / glowFamily
```

Reason: glow and halation should receive already-compressed color. Applying
color compression after glow would suppress the very optical energy the glow
stage created.

### Test / QA Matrix

Minimum automated tests:

- `compressionAmount == 0` is identity.
- luma-only neutral gray stays neutral.
- hue angle drift stays below a small threshold for skin-orange, sky-blue,
  foliage-green, saturated red, saturated cyan.
- bright saturated samples reduce chroma more than midtone samples.
- shadows do not collapse into gray.
- web/native constants and output examples match within tolerance.

Visual cells:

- iPhone SDR HEVC with bright text / paper.
- iPhone Apple Log / ProRes skin and window highlights.
- saturated practical lights: red, blue, cyan, neon.
- sky / wall gradients.
- foliage / hair after Detail Softness.
- existing Stone / Urban / Noir Creative LUT Pack outputs.

## Implementation Prompt

```text
Implement Film Compression V3 as the next Detail Softness follow-up.

Context:
- Detail Softness now handles spatial digital hardness.
- Current filmCompressionV2 is luma-only: it preserves hue by scaling RGB from
  a luma sigmoid, but it does not compress chroma/colorfulness.
- Goal: reduce digital color pressure and saturated-highlight hardness before
  detailSoftness and before glow/halation/diffusion.

Requirements:
- Keep `compressionAmount == 0` identity.
- Keep existing `compressionAmount` / `compressionRange` UI contract for the
  first slice. Do not add new public params unless implementation proves the
  existing contract cannot express the look.
- Replace or extend filmCompressionV2 in parity across:
  - macOS CIKernel
  - iOS CIKernel
  - WebGPU shader
  - WebGL shader
  - color-only baker
- Use a hue-preserving luma/chroma model:
  Y = Rec.709 luma, C = rgb - neutral(Y), M = length(C), h = direction(C).
  Compress M as a function of Y and M, then reconstruct.
- Add a problem-color guard for high-luma/high-chroma practical lights without
  globally dulling the image.
- Preserve skin hue and avoid gray shadows.
- Keep stage placement before `detailSoftness` and before glow/optics.

Verification:
- Unit tests for identity, hue drift, highlight chroma compression, shadow
  preservation, and parity constants.
- Existing native/web build gates for touched surfaces.
- Visual QA against iPhone SDR, Apple Log, saturated practicals, sky/wall
  gradients, skin, foliage/hair, and Creative LUT Pack outputs.

Do not close Phase 5 visual tuning until Film Compression V3 has been judged
with Detail Softness and glow together.
```

## Stop Conditions

- Per-channel RGB compression reappears and hue visibly rotates under strong
  contrast.
- Shadows lose color life or flatten to gray.
- Skin highlights become chalky, orange, or plastic.
- Glow / halation loses energy because compression was applied after the
  optical stack.
- V3 cannot be made visually consistent across native, WebGPU, WebGL, and
  color-only baking without widening the contract; pause before adding params.

## Copy / History Impact

No copy/history impact: research note only. No UI string, App Store copy,
release note, public page, fastlane metadata, or implementation-history source
was changed.

Article Opportunity: Developer note later, if V3 lands and the Detail Softness
+ film compression stack becomes a visible release story.

Change-History Opportunity: Yes. If implemented, this is the natural follow-up
to the Detail Softness lane: spatial softness first, then color/density
compression so the optical stack receives a more filmic source.

