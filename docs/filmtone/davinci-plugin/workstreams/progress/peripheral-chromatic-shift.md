# Progress: Peripheral Chromatic Shift

Plan: planning source `docs/filmtone/davinci-plugin/workstreams/peripheral-chromatic-shift.md`
Owner: `CHROMATIC-SHIFT`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — static acceptance correction applied; build, Metal compilation, Resolve, and visual verification remain unauthorized debt`

## Assignment

- Task: `019f7596-3fd0-7e13-bf54-b44596be9db0`
- Worktree: `/Users/chibatakumi/.codex/worktrees/8f9701bf-400b-4276-b074-fcb4e46721fd/filmtone`
- Assigned/common feature base: `00711523fa09a6fc13d82374e31e94576b701a4a`
- Start gate: clean detached worktree at the exact assigned base.
- Exclusive implementation folder:
  `apps/filmtone-resolve-ofx/Sources/Effects/PeripheralChromaticShift/`
- Planning source was read-only and was not modified.

## Checklist

- [x] Confirm clean/base, frozen units/falloff, Spatial ABI, and scope.
- [x] Record primary research and canonical Filmtone evidence.
- [x] Implement exact identity and Metal radial source sampling.
- [x] Inspect source and status for edge, alpha, bounds, clamps, and sibling isolation.
- [x] Complete progress evidence for director review.

## Research Gate

Primary or authoritative sources only:

- Mallon and Whelan, *Calibration and Removal of Lateral Chromatic
  Aberration in Images*:
  <https://doras.dcu.ie/4661/1/JM_elsevier_2006.pdf>. The paper models
  lateral chromatic aberration as radially dependent colour-plane
  misregistration, corrects it by image warping, and uses green as the
  reference plane. Adopted: per-channel source-coordinate warping with green
  centered. Not adopted: its calibrated lens-specific model, because the
  frozen Filmtone contract already owns the product response.
- OpenCV official geometric-transform documentation:
  <https://docs.opencv.org/4.x/da/d54/group__imgproc__transform.html>.
  It defines destination-to-source inverse remapping, fractional-coordinate
  interpolation, bilinear `INTER_LINEAR`, and explicit border extrapolation.
  Adopted: inverse source sampling, bilinear reconstruction, and edge
  replication rather than a zero/transparent border.
- Apple Metal Shading Language Specification, linked from the official Metal
  resources page:
  <https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf>.
  Adopted: `texture2d<float, access::read>` integer reads and explicit manual
  interpolation, matching Spatial ABI v1's no-sampler RGBA32Float contract.

Canonical local evidence:

- `packages/film-lab-core/src/resolve-spatial-contract.ts` and generated
  `filmtone_resolve_spatial.hpp` freeze `rgbShift` as an unscaled
  `0...0.005` per-axis frame fraction, exponent `1.65`, red outward, green
  centered, blue inward, centered optics, source alpha, and extended-range
  RGB preservation.
- Committed native `radialRGBSplit` in iOS `OpticalKernels.swift` and Desktop
  `FilmtoneGradeKernels.swift` is read-only product evidence for opposite
  red/blue radial source sampling and centered green/alpha.

## Decisions Fixed

- The processor accepts the generated `FilmtoneSpatialParametersV1` and uses
  `makePeripheralChromaticShiftParameterViewV1`; it does not duplicate the
  range or introduce `chromaticFringing`, a generic mapping, or an `x200`
  conversion.
- The optical center and radial direction use the Spatial ABI's
  display-aspect-correct `canonicalUnitsPerPixelX/Y`. Radius is clamped to
  `0...1`, then raised to the frozen `1.65` exponent.
- Red samples `sourcePosition + offset`, green samples the centered texel, and
  blue samples `sourcePosition - offset`. Alpha always comes from the centered
  source texel and is never split or attenuated.
- Subpixel reconstruction is manual bilinear interpolation over four integer
  RGBA32Float reads. The floating coordinate is clamped before neighbor
  selection and the upper integer neighbor is clamped again, so every sample
  is a valid edge texel; no black, transparent, repeat, or mirrored border is
  introduced.
- Bilinear mixing does not clamp RGB, so negative and greater-than-one values
  remain representable. Fast math is disabled through the pipeline request.
- After all Metal uniform values are derived and narrowed to `float`, the
  processor fail-closes before pipeline lookup or command encoding if any
  float is non-finite, or if amount, radial exponent, canonical units, or
  maximum per-axis offsets are non-positive. This supplements the double-
  precision frame check without changing valid-frame math.

## Render Scale Semantics

- Canonical direction comes from host-provided per-axis canonical units, which
  already account for independent render scale and pixel aspect ratio.
- Maximum rendered offset is `rgbShift * frame.width` on X and
  `rgbShift * frame.height` on Y. Since render bounds scale with the host render
  scale, this is the frozen full-resolution per-axis frame fraction expressed
  in current render pixels; proxy rendering therefore keeps normalized
  separation rather than a fixed pixel offset.

## Pass And Resource Use

- Resource plan: Spatial ABI v1, one compute pass, one mip level, full-frame,
  `clampToEdge`, extended-range and alpha preservation declared.
- The pass reads the coordinator-provided source mip-zero view and writes the
  coordinator-provided output mip-zero view. It requests no feature-local
  scratch, mip chain, sampler, command buffer, queue, wait, readback, or CPU/GPU
  resource allocation.
- Disabled or zero `rgbShift` resolves to an inactive generated view;
  `isIdentity` therefore prevents feature planning/encoding and the Spatial
  host performs no texture-pool allocation or copy for an all-identity graph.

## Approximations And Limitations

- Bilinear reconstruction is an explicit deterministic approximation for the
  native Core Image sampler. It avoids cubic ringing/overshoot, but Metal
  compilation and owner visual acceptance are still required to confirm the
  preferred sharpness at high-contrast edges.
- The exponent, centered optical axis, and symmetric red/blue directions are
  Filmtone product semantics, not a calibrated physical model for a specific
  lens. Lens-specific decentering, tangential LCA, animation, distortion, and
  color management remain out of scope.
- Edge replication prevents contamination and gaps but necessarily holds the
  outermost source texel when a shifted coordinate leaves the frame.

## Changed Files

- `apps/filmtone-resolve-ofx/Sources/Effects/PeripheralChromaticShift/PeripheralChromaticShiftProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/PeripheralChromaticShift/PeripheralChromaticShiftProcessor.mm`
- `apps/filmtone-resolve-ofx/Sources/Effects/PeripheralChromaticShift/PeripheralChromaticShiftMetalSource.h`
- `docs/filmtone/davinci-plugin/workstreams/progress/peripheral-chromatic-shift.md`

No sibling feature, shared Host, generated contract, integration, parameter,
factory, Makefile, plist, or planning-source file was changed.

## Verification

Performed:

- Read-only source inspection of the complete frozen contract, generated
  facade, and Spatial Host ABI/implementation.
- Read-only inspection of the feature source and `git status` for exclusive
  scope, center/edge coordinate math, alpha source, RGB clamps, pass count,
  mip count, post-cast Metal uniform validation, and forbidden sibling/shared
  edits.

Not performed by assignment prohibition:

- Tests or test-file work.
- Build, compiler/type checks, Metal shader compilation, or bundle generation.
- Resolve launch, install, render, performance measurement, visual acceptance,
  render-scale/format matrix, or supplied-host alpha proof.
- Stage, commit, merge, rebase, or push.

## Remaining Verification Debt

- Integration owner must add the feature to shared sources/parameters/pass
  order without changing this feature's frozen math.
- Authorized verification must compile Objective-C++ and embedded Metal,
  prove zero/default identity, inspect center and perimeter registration,
  exercise landscape/portrait/non-square-PAR/proxy renders, confirm no edge or
  alpha fringe, and obtain owner visual acceptance at restrained values.

## Copy / History Impact

- No copy/history impact: feature-local source only; public naming, parameter
  copy, and release claims are integration/release-owner work.
- Article Opportunity: `No story` at unverified source-handoff stage.
- Change-History Opportunity: `No` — frozen ownership and product direction
  did not change.
