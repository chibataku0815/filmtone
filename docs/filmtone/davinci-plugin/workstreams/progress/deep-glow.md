# Progress: Deep Glow

Plan: planning source
`/Users/chibatakumi/.codex/worktrees/filmtone-davinci-optical-planning/docs/filmtone/davinci-plugin/workstreams/deep-glow.md`
Owner: `DEEP-GLOW`; master state is director-owned
Last synced: 2026-07-19 JST

## State

`Review — coordinator static/build/Resolve smoke review complete; owner visual verdict pending`

Sections below through "Copy / History Impact" describe the accepted V1
implementation and its first weight-shift correction. The V1 selected model is
superseded by the `2026-07-19 Quality Redesign` section at the end of this
file; V1 text is retained as design lineage only.

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

---

# 2026-07-19 Quality Redesign

## Redesign Assignment

- Worktree:
  `/Users/chibatakumi/.codex/worktrees/72be83d2-b4c9-499a-b7cd-12456a1552ad/filmtone`
- Base HEAD confirmed: `202907ea34b43d1e03e78c2db5125d4d7a722fef` on
  `feature/resolve-spatial-integration`.
- Start gate: the worktree already carried owner/Codex uncommitted changes
  (FilmBreath, GateWeave, TextureSoftness, Vignette, Integration, generated
  contracts, `resolve-spatial-contract.ts`) plus an untracked `build/`
  directory. None of those were reverted, staged, or claimed. The Deep Glow
  files themselves were dirty with the first weight-shift correction; that
  in-flight state is the redesign input and is superseded below.
- Start SHA-256 of assigned files at task start:
  - `DeepGlowMetalSource.h`
    `60e161f266530fc591ff52d153461525a55d3cc8168f454848c7cdcc299de8b7`
  - `DeepGlowProcessor.h`
    `5ce91260a824b39d52845be3e4ca627611fff72381eacc2d2b71a6a7616e1f12`
  - `DeepGlowProcessor.mm`
    `e1f269166f09d8b2d5e22f84cac7a82361b1a4f2544e34f6f18df92164929213`
  - `packages/film-lab-core/src/resolve-spatial-contract.ts`
    `e154559e5dd0bb816d75182784bc8fd1437cd8d01377b3b5cec3af69987b9875`
- Start diff of the Deep Glow files vs base (the first correction, now
  superseded): composite cache key v1→v2; `deepGlowPerceptualShoulderV1` and
  `deepGlowBaseHeadroomV1` added to the composite; two-lobe body/spread
  normalized weights; cubic Strength gain. 2 files, +73/−30.
- The dirty `resolve-spatial-contract.ts` hunks at start touch Texture
  Softness effective-max constants and the Vignette attenuation string only;
  Deep Glow rows were untouched at start, so this task's contract edits are
  cleanly separable.

## Why The V1/V1.1 Model Is Retired

1. `kMaximumReducedLevelCount = 5` fixed the pyramid depth; Radius only moved
   normalized weights across the same five mips and never changed the actual
   PSF spatial scale, mip depth, or iteration count.
2. Sum-to-one weight normalization made wide Radius dilute the glow into a
   thin low-frequency veil instead of extending a luminous tail.
3. Each retained mip was bilinear-sampled directly in one composite; without
   progressive coarse-to-fine reconstruction the dyadic scales read as
   separate soft plateaus at broad Radius.
4. `deepGlowPerceptualShoulderV1` and `deepGlowBaseHeadroomV1` ran
   unconditionally and re-suppressed the HDR glow energy the pipeline had
   just produced, which is the owner-observed "conservative, weaker than the
   Resolve stock glow" verdict.
5. Threshold was hard-capped at 1.0 by the generated facade, so a source
   above 1.0 could never be isolated as the only emitter.
6. No falloff law existed; the weight vector was an ad-hoc Gaussian mixture.

## External Quality Evidence (public claims only)

Primary developer source, fetched 2026-07-19:
`https://www.plugineverything.com/deep-glow` states, verbatim: "physically
accurate inverse square based falloff", "HDR thresholding", "Thresholding
Smoothness (reduces temporal flicker)", and "Gamma correction (linear results
even when working in non-linear colorspace)" as an explicit user control.
`https://aescripts.com/deep-glow/` returned HTTP 403 this session;
`https://flashbackj.com/product/deep-glow` is a reseller restatement of the
same product page and was not used as an independent source. No proprietary
implementation detail was observed or copied; these public claims fix the
quality principles only, and the realization below is Filmtone's own Spatial
ABI v1 design. No identity or parity with Deep Glow is claimed.

## Selected Redesign Model

### Highlight extraction (unchanged family, retuned boundary)

- Positive-RGB, luminance-keyed selection with the committed Filmtone
  weights `(0.2126, 0.7152, 0.0722)`, colour-ratio preservation
  (`selected / luminance` scaling), and the existing premultiplied coverage
  path are retained.
- The continuous quadratic knee is retained and is now presented as
  `Threshold Smooth`: `kneeWidth = threshold * smooth`, the quadratic
  shoulder meets the hard `max(luminance − threshold, 0)` branch
  continuously, and per-tap extraction before tent averaging keeps the
  boundary temporally quiet on video.
- Extraction stays fused into the first reduction tap loop, so selection
  happens per source sample before any averaging.
- Strength is applied only at composite time, after selection; changing
  Strength never changes which pixels qualify as emitters.
- Threshold validation now accepts `0 ... kDeepGlowThresholdMaximum = 4.0`,
  matching the widened contract range below, so above-1.0 HDR-only selection
  becomes expressible once the facade is regenerated.

### Radius → physical PSF scale

- `bloomRadius` keeps its persistent ID and 0...1 storage and becomes a
  logarithmic radius control:
  `pixelRadius = min(frame.width, frame.height) * 0.003 * (0.5 / 0.003)^radius`
  (named constants `kDeepGlowMinRadiusFraction = 0.003`,
  `kDeepGlowMaxRadiusFraction = 0.5`). Radius 0 is a tight core
  (≈6.5 px at UHD), Radius 1 reaches half the render short axis
  (≈1080 px at UHD).
- Effective diffusion depth is derived from that pixel radius:
  `levelsReal = max(1, 1 + log2(pixelRadius / kDeepGlowLevelOneRadiusPixels))`
  with `kDeepGlowLevelOneRadiusPixels = 2.0`, clamped to the frame's
  representable reduction count and `kDeepGlowMaxReducedLevelCount = 11`.
  `reducedLevelCount = ceil(levelsReal)`; the deepest level fades in with the
  fractional part (`deepestLevelFade ∈ (0,1]`), so sweeping Radius changes
  depth continuously with no pop, step, or ring at level transitions.
- Because the fraction is taken from the render-frame short axis, proxy and
  full-resolution renders keep the same apparent glow footprint
  (contract `renderScaleRule` semantics preserved). Pixel-space isotropy is
  retained per the frozen `isotropic-pixel-filtering-no-axis-stretch` aspect
  rule; PAR-anamorphic roundness remains recorded verification debt.

### Progressive diffusion (downsample chain + coarse-to-fine reconstruction)

- Downsample: `n = reducedLevelCount` passes of the existing unit-sum 13-tap
  tent with fused extraction on pass 1. Passes alternate ping-pong planes
  (`D_k` lands on the output plane for odd `k`, the source plane for even
  `k`), which removes every V1 retain-copy pass while honouring the ABI rule
  that one pass may not read and write the same plane.
- Turnaround at the deepest level: one 9-tap 3×3 tent blur at level `n`
  converts `D_n` to the unassociated running accumulation `U_n`, applies
  `deepestLevelFade`, and smooths the PSF truncation scale.
- Upsample: `n − 1` combine passes. Each reads the coarser accumulation
  `U_{k+1}` through a 9-tap 3×3 tent over manual bilinear taps (the
  Jimenez/CoD tent lineage already cited in the V1 research gate) plus the
  same-plane `D_k`, and writes
  `U_k = unassociate(D_k) + kDeepGlowOctavePersistence * upsample(U_{k+1})`
  to the opposite plane. Plane algebra: `plane(U_k) = ¬plane(D_k)` holds for
  every level, and `U_1` lands on the source plane so the final composite
  reads base and `U_1` from one plane and writes the module output plane.
- Impulse-response claim (design, not measurement): the composite PSF is
  `Σ_{k=1..n} p^{k−1} · K_k` where each `K_k` is a positive, centered,
  unit-DC tent-chain kernel of footprint ≈ `2^{k−1}` × the finest footprint,
  and `p = kDeepGlowOctavePersistence = 1.0`. With `p = 1` every dyadic
  octave carries equal annular energy, giving an amplitude envelope
  ∝ `1/r²` between the finest and deepest footprints — a finite-core
  approximation of `1 / (1 + (r/s)²)` — with a bright core from the finest
  kernel and a smooth Gaussian-tailed truncation at the deepest. All terms
  are positive and unimodal, so the response decays monotonically with no
  negative lobes and no ringing. This is documented as an annular-energy
  inverse-square approximation; it is not labeled exponential and it is not
  an arbitrary Gaussian mixture: the per-octave weights are fixed by the
  constant-annular-energy property.
- Per-level weights are intentionally **not** normalized to sum to one. Core
  amplitude stays constant as Radius grows and the tail adds energy, which is
  the physical behaviour of an inverse-square PSF (total gathered energy
  grows with the logarithm of extent). Radius therefore extends light instead
  of diluting it.

### HDR composite (scene-referred, additive)

- `deepGlowPerceptualShoulderV1` and `deepGlowBaseHeadroomV1` are removed
  from the core path entirely. No tonemap, shoulder, headroom, or clamp runs
  on glow energy; if a creative tonemap is ever wanted it must be a separate
  explicit stage, which this cycle does not add.
- Composite is `output.rgb = base.rgb + strengthGain(strength) * glow.rgb`
  with `strengthGain(s) = s * (0.30 + 1.20 * s²)` (named constants; max gain
  1.5): fine control below ≈0.3, clearly strong at the top, no compensating
  shoulder. Bright HDR input glows proportionally brighter; energy is never
  re-compressed by the glow stage.
- Negative source RGB passes through in the base and never becomes negative
  light (extraction floors at zero, all filters are positive). Output alpha
  is the unmodified source alpha; the premultiplied path unassociates per
  level during reconstruction and multiplies the final glow by destination
  alpha exactly once, preserving the V1 constant-partial-alpha invariant.
- Strength 0 or Disabled remains exact identity: `isIdentity` is unchanged,
  no plan, no allocation, no pass.

### Working-domain decision (investigated 2026-07-19)

- Official surface: the installed Resolve 21.0.2 SDK ships `ofxColour.h`
  (OpenFX 1.5 colour-management extension: `None/Basic/Core/Full/OCIO`
  styles, negotiated via `kOfxImageEffectPropColourManagementStyle` at
  describe time with `kOfxImageClipPropColourspace` on clips).
- Current Host truth: `grep` over `apps/filmtone-resolve-ofx/Sources/`
  finds zero colour-management property reads or declarations; the plugin
  never opts in, and Resolve's host-side runtime support is unverified here
  (Resolve launch is prohibited in this task).
- Decision: **no automatic linearization** — there is no trusted input
  transfer signal available to this module today — and **no silent gamma 2.2
  / Rec.709 assumption**. Deep Glow operates on the host float working
  encoding exactly as delivered, unchanged from the accepted V1 contract and
  from `strategy.md`'s "Resolve owns input color management" boundary.
  Threshold and selection luminance are therefore working-domain quantities,
  and no claim is made that behaviour is automatically correct in every
  Resolve working space.
- Recorded follow-up (not implemented; requires contract generation and
  Integration wiring outside this task's authorization): an explicit
  backward-compatible Advanced `Working Domain / Gamma` control with a
  pass-through neutral default — the same explicit-user-control approach the
  public Deep Glow page documents — plus a separate Host/Integration
  investigation of opting into the OFX colour-management negotiation.

### Contract source-of-truth edits (generation pending)

Edited in `packages/film-lab-core/src/resolve-spatial-contract.ts` only; the
generated `filmtone_resolve_spatial.hpp` is **not** hand-edited and was not
regenerated because generation is not authorized in this task:

- `bloomThreshold.maxValue`: `1 → RESOLVE_DEEP_GLOW_THRESHOLD_MAX (4)`;
  `unit` becomes `working-domain-input-luminance`. Persistent ID, default
  0.8, identity 0.8, and normalization rule are unchanged, so every stored
  old-project value loads identically; the UI simply gains headroom after
  regeneration.
- `bloomSoftKnee.label`: `Soft Knee → Threshold Smooth`. Label only; the
  persistent ID `com.forestone.filmtone.finish.deepGlow.softKnee`, default
  0.5, and range are unchanged, and OFX persists by ID, so old projects are
  unaffected.
- `bloomRadius.unit`: `normalized-mip-distribution → normalized-log-psf-radius`,
  and the deepGlow feature `renderScaleRule` string now names the
  log-PSF-fraction mechanism. Descriptive metadata only.
- Until regeneration runs, the shipped facade still clamps threshold to 1.0
  and shows the old labels; the new processor accepts both the old and the
  widened range, so there is no behavioural cliff in either direction.

### Resource / pass / mip math (UHD worst case)

- Pass count: `n` reduces + 1 turnaround + `(n − 1)` combines + 1 composite
  = `2n + 1`; `n ∈ [1, 11]` → 3...23 passes ≤ ABI limit 64. A 1×1 frame uses
  the 1-pass inline-extraction composite (`n = 0`).
- Declared mips: `n + 1 ≤ 12`, always ≤ the frame's complete chain; the Host
  allocates the shared pair once at the max requested depth.
- Memory: zero feature-owned allocation; only the two coordinator-owned
  RGBA32F pyramids are used. UHD 12-level complete pair = 353,889,760 tight
  bytes (337.50 MiB) ≤ 384 MiB spatial ceiling; plus the documented
  253.125 MiB following-queue reservation = 590.62 MiB ≤ 640 MiB integrated
  ceiling. The V1 6-level request was already within 0.35% of the complete
  pair, so the deeper chain does not move the frozen memory contract.
- Texture reuse: strict two-plane ping-pong; the alternating-plane
  downsample removes V1's five retain-copy passes, and every combine writes
  into a level slot whose plane is provably free by the alternation
  invariant.
- Pipeline cache: the shared Metal library string changed, and the Host cache
  keys pipelines by `(device, cacheKey)` alone, so every Deep Glow kernel and
  cache key moved to a `v3` family
  (`reduce/turnaround/upsample-combine/composite`), eliminating stale-key
  collisions inside a running session. Fast math stays disabled in all four
  pipeline requests.

### Compatibility

- Unchanged: plugin ID `com.chibatakumi.filmtone.finish`, public display
  name, all Deep Glow persistent parameter IDs/defaults/neutrals,
  `DeepGlowProcessor` public interface and alpha-association enum, Node Role
  behaviour, graph order, Rec.709 selection weights, 13-tap reduce tent,
  clamp-to-edge manual bilinear, fail-closed invocation validation, and the
  Spatial ABI v1 boundary. Integration source required no edit; it already
  constructs the processor from the generated view and explicit alpha
  association.
- Behaviour intentionally changed (product decision, not drift): Radius now
  changes real diffusion scale and depth; wide glow is luminous instead of
  normalized-thin; HDR glow energy is no longer shoulder-compressed. Old
  projects keep their stored values; the rendered glow character changes with
  this quality cycle by design.

### Verification Split

- Performed (read-only): start gate with dirty-state separation and start
  hashes; complete plan/progress/ABI/Host/Integration/generated-contract
  review; OFX SDK colour-extension inspection; generator-assertion review
  proving the widened threshold range regenerates cleanly; public evidence
  fetch; static plane-algebra and pass-count consistency check between
  `makeResourcePlan` and `encodeSpatialMetal`.
- Not performed by explicit task prohibition: tests, test files, build,
  shader or C++ compilation, contract generation, Resolve launch, install,
  runtime pass/memory reports, identity/HDR/alpha pixel proof, visual or
  performance acceptance, and all Git write operations. Source completion is
  explicitly not runtime or visual acceptance.

### Changed Files (this redesign)

- `apps/filmtone-resolve-ofx/Sources/Effects/DeepGlow/DeepGlowMetalSource.h`
  — v3 kernel family: reduce (fused extraction), turnaround, upsample-combine,
  additive composite; shoulder/headroom/copy kernels removed.
- `apps/filmtone-resolve-ofx/Sources/Effects/DeepGlow/DeepGlowProcessor.mm`
  — radius→depth shape, alternating-plane pass graph, widened threshold
  validation, strength gain; weight-shift model removed.
- `packages/film-lab-core/src/resolve-spatial-contract.ts` — Deep Glow rows
  only (threshold max/unit, radius unit, Threshold Smooth label, deepGlow
  renderScaleRule); regeneration pending and not run here.
- `docs/filmtone/davinci-plugin/workstreams/progress/deep-glow.md` — this
  record.
- `DeepGlowProcessor.h` is intentionally unchanged; the processor's public
  interface, constructor, and alpha-association enum are stable, so no
  Integration edit was required or made.
- Observed mid-task in the shared worktree and left untouched: a new
  untracked owner/peer file
  `apps/filmtone-resolve-ofx/Sources/Integration/FilmtoneResolveFactoryDefaults.h`
  plus the pre-existing dirty FilmBreath/GateWeave/TextureSoftness/Vignette/
  Integration/generated-contract files and `build/`.

### Copy / History Impact (this redesign)

- No public copy/history impact yet: the redesigned source is unbuilt,
  unverified in Resolve, and not visually accepted; no release, parity, or
  availability claim may be made from this state.
- Future user-facing copy after acceptance: `Threshold Smooth` label,
  HDR threshold headroom, and "Radius extends real diffusion distance" are
  the honest claim surface; never claim Deep Glow identity or parity.
- Article Opportunity: **Developer note** after owner visual acceptance (the
  inverse-square annular-energy reconstruction inside a bounded two-pyramid
  ABI is the durable story). Change-History Opportunity: **Yes** — records
  the shift from normalized weight-shift glow to physical-scale progressive
  reconstruction.

## Coordinator Review — 2026-07-19 JST

- Static acceptance passed after one coordinator correction: the
  upsample-combine path now applies the same unit-sum 3x3 tent to `D_k` that
  the turnaround path applies when that level is deepest. This removes the
  filter-shape discontinuity when Radius crosses a mip-count boundary without
  changing the frozen two-plane ABI or resource ceiling.
- Confirmed alternating-plane algebra, `2n + 1` pass accounting including the
  1x1 `n = 0` case, Host-side identity filtering before planning/allocation,
  unclamped base RGB/HDR/negative preservation, single alpha reassociation,
  clamp-to-edge sampling, zero references to removed v2 shoulder/headroom/
  copy/weight-shift symbols, generator compatibility, and no parity claim.
- Regenerated contracts with the frozen artifact-bearing root
  `/Users/chibatakumi/.codex/worktrees/visual-effect-core-unified`. The new
  spatial source hash is
  `1b5f08c7a898e484fe8321ad033bd12efd8bc6f2cd968c2d566f8c89246b4e1b`;
  the generated facade exposes Threshold `0...4`, `Threshold Smooth`, and the
  log-PSF Radius metadata. Existing Texture Softness/Vignette source changes
  were necessarily baked into the shared generated artifact and remain owned
  by their streams.
- `make -C apps/filmtone-resolve-ofx` completed successfully. The built and
  installed arm64 binary hashes both equal
  `e136474275d7003ac498b2b049f6e12f3ee8c0560ed7161585386ec5c158f6c3`.
  The prior install is recoverable from
  `apps/filmtone-resolve-ofx/build/install-backups/pre-deep-glow-redesign-01ed9dfc/FilmtoneFinish.ofx.bundle`.
- Resolve Studio 21 was restarted and is currently mapping the installed
  `/Library/OFX/Plugins/FilmtoneFinish.ofx.bundle` binary. Runtime smoke review
  confirmed the new controls load, Threshold accepts a value above 1.0,
  Radius reaches tight and wide endpoints without an obvious ring/pop in the
  available candle shot, and Strength 0 visually matches Disabled. Controls
  were left enabled at Strength 1.000 / Threshold 0.775 / Radius 1.000 /
  Threshold Smooth 0.500 for owner review.
- State remains **Review** until the owner supplies the final visual verdict;
  master acceptance is intentionally not advanced yet. No tests, test files,
  staging, commit, or push were performed.
- Remaining debt carried forward: PAR-anisotropic PSF circularity,
  owner-guided real-footage tuning of strength/radius constants, and the
  separate Advanced Working Domain/Gamma contract + Integration workstream.
