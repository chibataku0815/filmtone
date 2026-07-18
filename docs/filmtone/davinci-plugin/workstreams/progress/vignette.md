# Progress: Vignette

Plan: planning-source `workstreams/vignette.md` (read-only)
Owner: `VIGNETTE`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — isolated source complete; authorized build/Resolve proof remains`

## Assignment

- Task: `/root/vignette_feature`
- Worktree: `/Users/chibatakumi/.codex/worktrees/filmtone-spatial-vignette`
- Base: `00711523fa09a6fc13d82374e31e94576b701a4a`
- Exclusive folder: `apps/filmtone-resolve-ofx/Sources/Effects/Vignette/`
- Dedicated record: this file

## Checklist

- [x] Confirm clean/base, frozen coordinates/semantics, ABI, and scope.
- [x] Record primary research and canonical Filmtone evidence.
- [x] Implement exact identity and Metal attenuation.
- [x] Inspect source for bounds, alpha, extended range, and isolation.
- [x] Complete progress evidence and return `delegation.md` handoff.

## Research Gate

- The Academy Software Foundation's authoritative
  [OpenFX coordinate-system specification](https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html)
  maps pixel coordinates into canonical/display coordinates as
  `X * pixelAspectRatio / renderScaleX` and `Y / renderScaleY`. The installed
  Resolve OpenFX 1.4 header independently defines clip/image PAR and requires
  render scale to be applied to spatial calculations.
- Gardner's primary NBS study,
  [Validity of the cosine-fourth-power law of illumination](https://nvlpubs.nist.gov/nistpubs/jres/39/jresv39n3p213_A1b.pdf),
  and Aggarwal, Hua, and Ahuja's primary IEEE study,
  [On cosine-fourth and vignetting effects in real lenses](https://doi.org/10.1109/ICCV.2001.937554),
  establish smooth off-axis illumination falloff while also showing that a
  single physical `cos^4` law is not universal for real lenses. No alternate
  physical curve is introduced here because the accepted Filmtone facade
  freezes the simpler quadratic radius model.
- Apple's authoritative
  [`MTLPixelFormatRGBA32Float` documentation](https://developer.apple.com/documentation/metal/mtlpixelformat/rgba32float)
  specifies four 32-bit floating-point RGBA components. Spatial ABI v1 fixes
  this format and rejects fast math, so the implementation keeps the radial
  field and multiplication in float rather than quantizing a mask to integer
  or half precision.
- Committed iOS/macOS Filmtone evidence derives its baseline Vignette from
  actual pixel distance divided by half-diagonal, then applies
  `1 - intensity * distance^2`. Its optional camera-metadata ray-angle mask is
  intentionally not copied: the frozen Resolve contract owns only `amount`
  and explicitly fixes the unmasked quadratic attenuation.

## Decisions Fixed

### Coordinates

For a texture-local rendered pixel center `(x + 0.5, y + 0.5)`:

```text
dxDisplay = (x + 0.5 - width / 2)  * pixelAspectRatio / renderScaleX
dyDisplay = (y + 0.5 - height / 2) / renderScaleY
halfDiagonal = hypot(logicalDisplayWidth, logicalDisplayHeight) / 2
radiusSquared = (dxDisplay^2 + dyDisplay^2) / halfDiagonal^2
```

This is full-resolution display-pixel distance: PAR corrects horizontal pixel
shape, each render-scale axis reconstructs full-resolution geometry, and the
display half-diagonal makes landscape, portrait, and square frames share the
same corner-normalized optical field. The optical center is the center of the
full source/output bounds, not the current render tile.

### Attenuation And Precision

- Exact frozen equation: `rgb * clamp(1 - amount * radiusSquared, 0, 1)`.
- A scalar factor applies equally to RGB, so no color transform or hue rotation
  is introduced. Negative and greater-than-one inputs are not globally
  clamped; only the non-negative attenuation factor is bounded.
- Source alpha is copied unchanged.
- The quadratic field is evaluated directly in RGBA32Float. It has no hard
  threshold, ring, lookup texture, or quantized mask that could introduce
  banding.
- The generated `VignetteParameterViewV1` remains the sole amount/identity
  facade; the processor does not duplicate defaults or normalize parameters.

### Pass And Resource Use

- `disabled` or `amount == 0` resolves to `active == false`; the spatial host
  removes the module before texture-pool allocation, so neutral state is exact
  identity and allocation-free.
- Active state declares exactly one full-frame compute pass and one mip level.
- The pass reads the host-provided base source view and writes the host-provided
  base output view. It requests no scratch image, mip, sampler, readback, wait,
  command buffer, or sibling resource.
- Spatial ABI v1 retains command-buffer ownership and uses its fixed
  `clampToEdge` policy; this coordinate-only pass performs no sampling outside
  the source pixel at `gid`.

## Files

- `apps/filmtone-resolve-ofx/Sources/Effects/Vignette/VignetteProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/Vignette/VignetteProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/vignette.md`

## Verification

Performed read-only source review of the generated facade, Spatial ABI v1,
coordinate derivation, pass/resource declaration, source-alpha copy,
extended-range multiplication, and changed-file ownership.

Not performed: tests, test files, build, Metal compilation, Resolve launch,
installation, visual comparison, stage/commit/merge/rebase/push. These actions
were not authorized for this worker.

## Remaining Debt

- Integration must register/build the two feature files and construct the
  processor from `makeVignetteParameterViewV1`; this is outside this feature's
  exclusive area.
- A later authorized gate must compile the embedded Metal source and inspect
  identity, alpha, HDR/negative RGB, landscape/portrait/square, non-square PAR,
  proxy/render-scale, and banding behavior in Resolve.

## Copy / History Impact

- No copy/history impact in this isolated source handoff; public label,
  parameter exposure, and claims are integration-owned.
- Article Opportunity: **Release-note only**, after integrated behavior and
  visual acceptance are true.
- Change-History Opportunity: **No** — the worker implements the already
  frozen contract without changing ownership or product direction.
