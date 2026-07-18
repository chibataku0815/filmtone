# Progress: Deep Glow

Plan: planning source
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/deep-glow.md`
Owner: `DEEP-GLOW`; master state is director-owned
Last synced: 2026-07-18 JST

## State

`Review — source implementation complete; build / Metal / Resolve proof not authorized`

## Assignment

- Task: `019f7596-56cf-7d72-94c8-dd3aa69ad962`.
- Worktree:
  `/Users/chibatakumi/.codex/worktrees/9e8cd883-a02c-444b-a983-379cfd04d516/filmtone`
- Assigned common feature base:
  `00711523fa09a6fc13d82374e31e94576b701a4a`.
- Start gate: clean detached worktree and exact assigned base confirmed before
  edits.
- Exclusive folder: `Sources/Effects/DeepGlow/`.
- Parallel peers: CHROMATIC-SHIFT, LENS-SOFTNESS, TEXTURE-SOFTNESS, VIGNETTE.
- Planning source remained read-only.

## Frozen Inputs Confirmed

- Filmtone Resolve spatial contract: version 1,
  `com.forestone.filmtone.resolve.spatial`.
- Spatial module ABI: version 1.
- Canonical artistic input: generated `DeepGlowParameterViewV1` only,
  containing the normalized `bloomStrength`, `bloomThreshold`, `bloomRadius`,
  and `bloomSoftKnee` facade result plus its generated active gate.
- Strength-zero / disabled identity is decided before resource planning by
  `SpatialMetalHost`; the feature requests no texture allocation or pass.
- Frozen resource boundary: two Host-owned RGBA32Float pyramids, maximum 64
  feature passes, coordinator-owned command buffer, explicit integer reads,
  and clamp-to-edge.
- Frozen ceiling is unchanged: 384 MiB spatial transient / 640 MiB integrated
  transient at UHD. This feature adds no allocation outside the shared pair.

## Primary / Authoritative Research Gate

- Jorge Jimenez, *Next Generation Post Processing in Call of Duty: Advanced
  Warfare*, SIGGRAPH 2014 author-hosted publication and slides:
  <https://www.iryoku.com/publications/> and
  <https://www.iryoku.com/downloads/Next-Generation-Post-Processing-in-Call-of-Duty-Advanced-Warfare-v18.pptx>.
  Used for the multi-resolution tent-filter lineage, not for product tuning.
- NVIDIA GPU Gems, Greg James and John O'Rorke, *Real-Time Glow*:
  <https://developer.nvidia.com/gpugems/gpugems/part-iv-image-processing/chapter-21-real-time-glow>.
  Used for normalized convolution, reduced-resolution broad glow, and additive
  reconstruction principles.
- Epic Games official Unreal Engine Bloom documentation:
  <https://dev.epicgames.com/documentation/en-us/unreal-engine/bloom-in-unreal-engine>.
  Used as authoritative evidence that multiple Gaussian-like scales improve
  bloom quality and that wide bands belong at lower resolutions.
- Unity official Bloom manual:
  <https://docs.unity3d.com/2017.4/Documentation/Manual/PostProcessing-Bloom.html>.
  Used for the threshold / gradual soft-knee / resolution-independent radius
  control model, not its implementation or tuning.
- Apple Metal Feature Set Tables and sampler addressing documentation:
  <https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf> and
  <https://developer.apple.com/documentation/metal/mtlsampleraddressmode>.
  Used to confirm RGBA32Float read/write fidelity and clamp-to-edge semantics.

Committed Filmtone evidence was inspected read-only at:

- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`

Those sources establish Filmtone's luminance-keyed, soft-knee, multi-level
Deep Glow intent. The Resolve code is an independent Spatial ABI v1 design: it
does not port the Swift/Core Image resource graph, mirror sampling, half
precision, halation, diffusion, or native composite shoulder.

## Selected Model

### Highlight extraction

- The glow plate uses positive RGB only; negative RGB remains untouched in the
  base result and is not spread as negative light energy.
- Selection luminance uses Filmtone's committed native evidence weights
  `(0.2126, 0.7152, 0.0722)` without applying a transfer function or input
  color conversion. Resolve remains responsible for the working encoding.
- `kneeWidth = threshold * softKnee`.
- The quadratic shoulder runs from `threshold - kneeWidth` through
  `threshold + kneeWidth`, meets the hard `max(luminance-threshold, 0)` branch
  continuously, and scales positive RGB by selected excess divided by source
  luminance. It neither caps HDR highlights nor globally clamps RGB.
- At restrained defaults, values below the knee start contribute exactly zero;
  black therefore has no haze floor.

### Multi-scale filtering and radius

- Normal frames use five reduced glow levels: 1/2, 1/4, 1/8, 1/16, and 1/32.
- Each reduction uses a unit-sum 13-tap tent with manual bilinear sampling.
- Each reduced result is copied into the retained source-plane mip because
  Spatial ABI v1 forbids reading both ping/pong planes and writing either one
  in the same pass. The final pass can then read all retained mips and write
  only the module output plane without aliasing.
- The feature fails closed before resource access unless source/output have
  nonzero matching execution tokens, both are full-resolution mip zero, both
  match the frame dimensions, and their ping/pong planes are distinct.
- Radius moves a smooth Gaussian-like focus across normalized mip positions;
  an 18% exponentially decaying core component retains highlight structure at
  broad settings. All active weights are normalized to sum to one.
- There is no discrete radius-dependent mip-count switch. Rebuilding the same
  normalized 1/2...1/32 pyramid for the current render dimensions keeps the
  apparent radius stable across render scale.
- Frames too small for all five levels use every representable reduced level;
  a 1x1 frame uses inline extraction in the composite pass.

### Passes, resources, precision, and energy

- Normal-frame feature pass count: **11** — five reduce/extract passes, five
  retain-copy passes, and one full-resolution composite.
- Small-frame pass count: `2 * representableReducedLevels + 1`.
- Declared mip count: **6 total** at normal sizes (full resolution plus five
  reduced levels).
- Scratch/mip use: only the frozen pair of shared Host pyramids; no feature
  heap, buffer, texture, command buffer, wait, readback, or hidden allocation.
- Precision: RGBA32Float textures and MSL `float` math throughout; fast math is
  explicitly disabled in all three pipeline requests.
- Energy normalization: every tent kernel sums to 1 and every radius weight
  vector sums to 1. `bloomStrength` is the sole linear glow-energy multiplier,
  so radius distribution does not silently amplify the effect.
- Edge policy: every manual interpolation tap clamps its integer coordinates
  to the corresponding mip edge. No zero, transparent, repeat, or mirror
  sample can create a border halo.

### Alpha and range

- Composite alpha is copied directly from the full-resolution source read.
- In premultiplied mode, scratch alpha temporarily carries filtered coverage:
  selection is evaluated in unassociated RGB, selected energy is associated
  before filtering, each reconstructed band is divided by its filtered
  coverage, and the final glow is associated by destination alpha. This avoids
  both transparent-color contribution and a second unintended alpha gain.
- For a constant partial-alpha region with straight selected energy `E` and
  alpha `A`, extraction stores `(E*A, A)`, filtering preserves that constant,
  reconstruction yields `(E*A)/A = E`, and composite writes glow `E*A` exactly
  once. Output alpha remains the original `A`; an output pixel with zero alpha
  receives zero glow.
- Integration must explicitly pass OFX alpha association as feature-local Host
  metadata; opaque/unassociated input bypasses the coverage path.
- Source RGB is always added back without a global clamp. Negative base values
  and values above one therefore survive; positive HDR bloom energy may remain
  above one.

## Files

- `apps/filmtone-resolve-ofx/Sources/Effects/DeepGlow/DeepGlowProcessor.h`
- `apps/filmtone-resolve-ofx/Sources/Effects/DeepGlow/DeepGlowProcessor.mm`
- `apps/filmtone-resolve-ofx/Sources/Effects/DeepGlow/DeepGlowMetalSource.h`
- `docs/filmtone/davinci-plugin/workstreams/progress/deep-glow.md`

No contract, generated facade, shared Host, integration, factory, Parameters,
Makefile, plist, existing effect, or sibling feature was changed.

## Checklist

- [x] Confirm clean/base, frozen facade, spatial ABI, and exclusive scope.
- [x] Record primary research and canonical Filmtone evidence.
- [x] Implement exact identity, resource plan, and Metal passes.
- [x] Inspect source design for clamps, alpha, edges, pass/resource ownership,
      and exclusive-file compliance.
- [x] Apply director static-review corrections for invocation capability
      boundaries and single-association premultiplied alpha math.
- [x] Complete progress evidence and prepare the delegation handoff.

## Approximations And Verification Debt

- The normalized five-band tent reconstruction is a controlled real-time point-
  spread approximation, not a measured physical lens PSF.
- Fixed Filmtone luminance weights intentionally do not infer Resolve gamut or
  transfer. Wide-gamut working spaces need visual evaluation; changing input
  color management is out of scope.
- Non-square-pixel, odd-size, proxy/full render-scale, transparent-edge,
  negative-RGB, and very-high-HDR frames are covered by static design only.
- Integration must map the OFX clip premultiplication state to
  `DeepGlowAlphaAssociationV1` and construct the processor from the generated
  parameter view. That is integration work, not a frozen ABI change.
- Actual shader compilation, Objective-C++ compilation, bundle build, pass
  reporting, memory reporting, Resolve loading, identity pixel comparison,
  visual haze/ring/radius review, and performance measurement remain unproved.

## Verification

- Performed: read-only start gate, full planning/foundation review, primary /
  authoritative research, and read-only source/status inspection.
- Not performed by explicit task prohibition: tests, test files, build,
  shader compilation, Resolve, install, Git staging/commit/merge/rebase/push.

## Copy / History Impact

- No public copy/history impact yet: feature-local source is not integrated,
  built, visually accepted, packaged, or released.
- Article Opportunity: **Developer note**, only after integration and visual
  acceptance make the implementation claim true.
- Change-History Opportunity: **Yes** — if accepted, this records the first
  Resolve spatial feature built on the bounded Spatial ABI v1 pyramid model.
