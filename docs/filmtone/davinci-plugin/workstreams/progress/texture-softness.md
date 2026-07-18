# Progress: Texture Softness

Plan: planning source
Owner: `TEXTURE-SOFTNESS`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — feature source complete; authorized integration/build/visual proof remains`

## Assignment

- Task: `019f7596-86c6-7751-8440-c76023a0f475`
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/6ddbb877-a231-4b0a-a762-ca57c335bf22/filmtone`
- Base: `00711523fa09a6fc13d82374e31e94576b701a4a`
- Exclusive folder: `Sources/Effects/TextureSoftness/`
- Planning source was read-only:
  `/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning`

## Checklist

- [x] Confirm clean/base, current detail contract, Spatial ABI v1, and scope.
- [x] Record primary research and distinction from Lens Softness.
- [x] Implement exact identity, resource plan, and Metal detail attenuation.
- [x] Inspect source and diff for halos, highlights, alpha, scale, and isolation.
- [x] Complete progress evidence for coordinator review.

## Research Gate

Primary/authoritative sources consulted:

- Tomasi and Manduchi, *Bilateral Filtering for Gray and Color Images*,
  ICCV 1998, DOI `10.1109/ICCV.1998.710815`. The normalized positive
  spatial/range weighting is the edge-preserving basis used here:
  <https://doi.org/10.1109/ICCV.1998.710815>
- Farbman, Fattal, Lischinski, and Szeliski, *Edge-Preserving Decompositions
  for Multi-Scale Tone and Detail Manipulation*, SIGGRAPH 2008. Its analysis
  of bilateral base/detail limits and halo risk rules out broad multi-scale
  detail manipulation for this feature:
  <https://www.microsoft.com/en-us/research/publication/edge-preserving-decompositions-for-multi-scale-tone-and-detail-manipulation/>
- Paris and Durand, *A Fast Approximation of the Bilateral Filter using a
  Signal Processing Approach*, MIT-CSAIL-TR-2006-073. Its accuracy/cost
  discussion supports direct evaluation for this fixed small neighborhood
  instead of introducing a large-kernel approximation:
  <https://people.csail.mit.edu/sparis/publi/2006/tr/Paris_06_Fast_Bilateral_Filter_MIT_TR.pdf>

Selected model: one center-inclusive, single-scale bilateral reference over
the generated eight-tap ring. The residual `center - reference` is attenuated
only after a detail-amplitude release gate. This stays within the canonical
Filmtone detail-softness model and avoids the multi-scale/detail-boosting
regime that the research identifies as prone to halos.

## Fixed Implementation Decisions

### Decomposition and range protection

- The generated `TextureSoftnessParameterViewV1` is the only parameter input.
  Its `effectiveAmount`, full-resolution kernel radius, `rangeSigma`, detail
  thresholds, chroma attenuation, and highlight bias are passed without
  feature-local retuning or parameter clamps.
- The base reference is the center RGB sample with weight `1` plus eight
  bilinearly sampled neighbors on one circular ring. Each neighbor receives
  a positive luma-range Gaussian weight; the normalized sum cannot have a
  zero denominator.
- Large luma steps receive negligible cross-edge weight. Residual detail is
  additionally released by
  `1 - smoothstep(detailAmplitudeLow, detailAmplitudeHigh, abs(detailLuma))`,
  so major edges, text, contours, and focus cues are not attenuated.
- Luma and chroma residuals follow the canonical Filmtone split. Chroma uses
  the generated lower attenuation scale, limiting color smearing and the
  waxy/beauty-retouch character.
- The native/WebGPU highlight transition (`smoothstep(0.6, 0.9, centerLuma)`)
  is retained as implementation-parity evidence; the strength comes only
  from generated `highlightBias`. Range weights prevent bright neighboring
  pixels from contaminating a darker center. RGB itself is never clipped.

### Halo, ringing, banding, and skin safeguards

- All reference weights are non-negative and there are no negative-lobe,
  sharpen, deconvolution, or feedback passes. The one-pass attenuation cannot
  create a ringing kernel.
- The bilateral range rejection and high-amplitude release gate are separate
  protections against halos and gradient reversal around major edges.
- `effectiveAmount * max(1, highlightBias)` must stay at or below `1`, so the
  feature attenuates rather than inverts the selected residual.
- RGBA32Float is retained through the pass, `fastMathEnabled` is false, and no
  intermediate quantization is introduced; this avoids a feature-local
  gradient-banding source.
- The method has no skin detector, denoiser, temporal averaging, or broad
  low-frequency blur. It is bounded to the 1.0–2.5 full-resolution-pixel
  canonical detail scale and keeps high-amplitude facial/focus structure.

### Scale and edge semantics

- The generated full-resolution radius is multiplied independently by Host
  `renderScaleX` and `renderScaleY`. Proxy and full-resolution renders therefore
  address the same full-resolution-pixel neighborhood.
- Diagonal offsets use `sqrt(1/2)` per axis, preserving the circular ring in
  full-resolution pixel coordinates. No optical-center coordinate, radial
  falloff, pixel-aspect peripheral field, or Lens Softness mask is used.
- Fractional taps use explicit bilinear reads with coordinate-only
  clamp-to-edge, as required by Spatial ABI v1. Black/transparent edge samples
  are never introduced.

### Alpha and extended range

- Range weights and detail math consume unclamped float RGB. Negative and
  greater-than-one values remain representable throughout the pass.
- The output alpha is copied exactly from the unsplit center source sample;
  neighbor alpha is never filtered.
- A generated inactive view or exactly zero `effectiveAmount` returns identity
  from `isIdentity`. The Spatial Host therefore performs no allocation,
  pipeline lookup, or encode for zero amount.

### Pass and resource use

- Resource plan: one full-frame compute pass, one mip level, Host-owned
  RGBA32F ping/pong level zero only. No feature-local texture, buffer, mip,
  command buffer, commit, wait, or readback is created.
- Per output pixel, the direct implementation performs one center read and
  eight manual bilinear taps (up to 33 integer texture reads total), plus eight
  range exponentials. This fixed cost avoids approximation/pyramid resources
  and does not grow with radius or another feature's activity.

## Approximations And Debt

- The canonical eight-sample ring is a sparse bilateral neighborhood, not a
  dense Gaussian spatial window, WLS solve, or perceptual-Lab bilateral.
- Range distance is Rec.709 luma difference, matching committed Filmtone
  implementations; working-space colorimetry remains Resolve-owned.
- The fixed native highlight transition is not separately exposed by the v1
  generated facade. Changing it requires a future contract-owner decision;
  this worker did not modify the frozen contract.
- Build/Metal compilation, integration construction, UHD/proxy parity,
  supplied-host alpha, extended-range image probes, performance, Resolve, and
  owner visual checks remain unperformed and must be completed by authorized
  integration/quality work.

## Files

- `apps/filmtone-resolve-ofx/Sources/Effects/TextureSoftness/TextureSoftnessProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/TextureSoftness/TextureSoftnessProcessor.mm`
- `docs/filmtone/davinci-plugin/workstreams/progress/texture-softness.md`

## Verification

- Performed: clean/base start gate; full read-only contract/ABI review;
  primary-source Research Gate; manual source and scoped-diff inspection.
- Not performed: tests, test files, build, Metal compilation, Resolve,
  installation, performance/visual checks, or Git writes. They are explicitly
  prohibited in this feature task.

## Copy / History Impact

- No copy/history impact: this feature-local implementation does not change
  the director-fixed public name, parameter surface, compatibility ID, or
  existing film-module history.
- Article Opportunity: `Developer note`, only after integration and visual
  acceptance make the behavior claim true.
- Change-History Opportunity: `No`; the frozen source-of-truth and graph
  direction are unchanged.
