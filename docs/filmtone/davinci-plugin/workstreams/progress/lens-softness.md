# Progress: Lens Softness

Plan: read-only planning source
Owner: `LENS-SOFTNESS`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — feature-local source complete; build, Resolve, and visual proof remain unauthorized`

## Assignment

- Task: `019f7596-6e00-7151-b0df-6831d8644e32`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/6794aa03-a64d-460e-a1ca-ee1a32aa192e/filmtone`
- Base: `00711523fa09a6fc13d82374e31e94576b701a4a`
- Exclusive implementation folder: `Sources/Effects/LensSoftness/`
- Exclusive progress record: this file

## Checklist

- [x] Confirm clean/base, frozen spatial contract, ABI, and scope.
- [x] Record research and distinction from Texture Softness.
- [x] Implement exact identity, resource plan, and Metal pass.
- [x] Inspect source for bounds, edges, alpha, scale, and sibling isolation.
- [x] Complete progress evidence and prepare the delegation handoff.

## Research Gate

Only primary or authoritative sources were used:

- OpenFX coordinate-system specification:
  <https://openfx.readthedocs.io/en/latest/Reference/ofxCoordSystem.html>.
  Pixel/canonical conversion explicitly depends on independent X/Y render
  scale and pixel aspect ratio. The implementation consumes the frozen Host
  canonical-unit fields and multiplies its full-resolution radius by the Host
  render scale independently on each axis.
- Apple Metal clamp-to-edge address semantics:
  <https://developer.apple.com/documentation/metal/mtlsampleraddressmode/clamptoedge>.
  Spatial ABI v1 exposes integer reads rather than a sampler, so the feature
  implements the equivalent coordinate clamp before manual bilinear reads.
- Nikon's authoritative MTF explanation:
  <https://imaging.nikon.com/imaging/lineup/lens/mtf_chart/>. Lens contrast is
  described at low and high spatial frequencies as a function of distance
  from image center, supporting a continuous image-height response rather
  than a uniform full-frame softener.
- Tony Lindeberg, “Scale-Space Theory: A Basic Tool for Analysing Structures
  at Different Scales,” author/institutional record and paper:
  <https://kth.diva-portal.org/smash/record.jsf?pid=diva2%3A457189>.
  Gradual low-pass scale suppresses finer structure without requiring an
  edge-aware detail model.
- P. J. Burt and E. H. Adelson, “The Laplacian Pyramid as a Compact Image
  Code,” IEEE Transactions on Communications, DOI
  <https://doi.org/10.1109/TCOM.1983.1095851>. The normalized low-pass and
  pyramid alternative was evaluated; it was not adopted because this feature's
  accepted radius is compact and a pyramid would add avoidable passes/mips and
  a stronger defocus character.
- Committed Filmtone native evidence:
  `FilmtoneGradePipeline.swift`, `FilmtoneGradeKernels.swift`,
  `OpticsResampling.swift`, `OpticsCompositor.swift`, and
  `OpticalKernels.swift`. This fixes the half-diagonal response and the current
  Lens Softness radius character; the Resolve implementation does not copy
  Core Image code.

## Fixed Model And Approximation

- Parameter ownership: the processor accepts
  `FilmtoneSpatialParametersV1` and derives only
  `makeLensSoftnessParameterViewV1`; no default/range is duplicated.
- Optical field: the source-bounds center and Host display-aspect-correct
  canonical units form a half-diagonal radius. The frozen response is retained:
  `smoothstep(0.25, 1, radius)`, `radius^1.52`, `amount^0.78`, and maximum
  spatial mix `0.72`.
- Kernel: one compact 17-tap, rotationally staggered, two-ring optical PSF
  approximation. Center/inner/outer weights are `1/4`, `1/16`, and `1/32`
  per tap, summing exactly to one. This is deliberately not a uniform Gaussian
  plate.
- Radius: `1.6 + 1.85 * amount^0.78` full-resolution pixels, or
  `1.6...3.45` pixels for active `amount > 0`. X/Y render radii are that value
  multiplied by `renderScaleX` and `renderScaleY` respectively.
- Edge policy: every bilinear footprint is explicitly clamped to the nearest
  valid texel; there is no transparent/black border sample.
- Energy/range behavior: the positive normalized PSF has unity DC gain, and
  the sharp/soft result is a convex mix. RGB is never globally clamped, so
  negative and greater-than-one values remain representable. The exact center
  source alpha is written unchanged.
- Texture Softness separation: no range guide, edge-aware weighting, detail
  residual, chroma attenuation, or micro-contrast model is used. Lens Softness
  is a field-weighted low/medium-frequency optical PSF only.
- Approximation debt: this is a restrained circular PSF approximation, not a
  measured lens MTF/PSF and not a model of sagittal/meridional astigmatism,
  aperture shape, focus breathing, or depth-dependent defocus.

## Pass And Resource Use

- One full-resolution compute pass: module source mip 0 -> module output mip 0.
- Resource plan: `passCount = 1`, `mipLevelCount = 1`, RGBA32F,
  `clampToEdge`, full-frame, extended-range and alpha preservation declared.
- No feature-local texture/buffer, mip, command buffer, commit, wait, readback,
  or sibling implementation dependency.
- When amount is zero or the feature is disabled, the generated view is
  inactive. `isIdentity` returns before Host planning, so the spatial Host
  performs no Lens Softness pass or allocation and output is exact identity.
- For active work, the feature uses only the Host's bounded level-zero
  RGBA32F ping/pong pair; it does not increase the frozen 384 MiB ceiling.

## Files

- `apps/filmtone-resolve-ofx/Sources/Effects/LensSoftness/LensSoftnessProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/LensSoftness/LensSoftnessProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/lens-softness.md`

No contract, generated facade, shared Host, sibling feature, Integration,
Factory, Parameters, Makefile, plist, existing film module, or planning-source
file was changed.

## Verification

Performed:

- Start gate: clean worktree and exact assigned base confirmed before edits.
- Full read of required planning documents and frozen foundation source.
- Read-only source/status/diff inspection for exclusive-file compliance,
  facade use, identity scheduling, edge clamp, alpha path, extended-range RGB,
  render-scale math, pass count, and resource-plan consistency.

Not performed by task prohibition:

- Tests or test-like verification.
- Build or Metal shader compilation.
- Resolve launch, plugin install, image render, performance measurement, or
  visual acceptance.
- Stage, commit, merge, rebase, or push.

Verification debt is therefore authoritative compilation plus Resolve visual
checks at proxy/full resolution, landscape/portrait and non-square-pixel
formats, extended-range RGB, supplied alpha, border stress, and center-to-corner
continuity.

## Copy / History Impact

- No public copy changed. Public display name `Filmtone`, compatibility plugin
  ID, Node Role behavior, and CinePrint35 placement remain coordinator-owned.
- Article Opportunity: `Release-note only` after integration and owner visual
  acceptance.
- Change-History Opportunity: `Yes` — record that Resolve Lens Softness chose a
  field-weighted normalized optical PSF rather than Texture Softness or a
  uniform full-frame Gaussian blur.
