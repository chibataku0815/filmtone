# Filmtone Optical Filter Profile Handoff - 2026-05-01 JST

## Purpose

This handoff preserves the discussion about raising the quality of Filmtone's
lens-filter simulation and turning it into a product-facing selection model.

The next chat should use this as the source context for creating a concrete
implementation plan. Do not restart with a broad audit. Route directly to:

- `packages/film-lab-core/` for shared profile schema and presets.
- `packages/film-lab-renderer/` for WebGPU optical rendering behavior.
- `apps/desktop-film-lab-batch/` only when planning Desktop UI integration.
- `apps/capacitor-film-lab-ios/CLAUDE.md` only when planning iOS parity.

## Worktree State At Handoff

Observed with `git status --short --branch` on 2026-05-01 JST:

- Branch: `main...origin/main [ahead 1]`
- Existing unrelated dirty worktree is concentrated in iOS Swift/UI files under
  `apps/capacitor-film-lab-ios/ios/App/App/`.
- Existing untracked iOS handoffs and Swift files were already present.
- This handoff adds only this document.

Important: do not revert or overwrite the existing iOS changes unless the user
explicitly asks.

## User Problem

The user is simulating lens filters but feels the result does not reach a
convincing quality level. They had already considered:

- Depth map coupling.
- Light incidence / ray-angle simulation.

They asked whether something important was missing, and then suggested a UX
direction: make filters selectable by categories based on commercially
available lens filters.

## Prior Claude Response That Triggered This Discussion

The user pasted a previous Claude answer that proposed, in priority order:

1. Process in linear light, not sRGB.
2. Use nonlinear highlight-dependent scattering.
3. Use non-Gaussian PSF shapes: tight core plus broad long tail, multi-ring,
   two-stage falloff, etc.
4. Preserve energy: redistribute light instead of only adding glow.
5. Add wavelength-dependent scattering / spectral separation.
6. Model directional veiling glare from strong light sources.
7. Modulate by aperture / f-number if EXIF is available.

The suggested priority there was `1 -> 2 -> 4 -> 3`.

## What Was Verified In The Repo

### Desktop WebGPU Is Already The Main Quality Path

Desktop defaults to WebGPU:

- `apps/desktop-film-lab-batch/vite.config.ts`
  - `import.meta.env.FILMTONE_BACKEND` is set to `"webgpu"`.
  - Comments say Desktop should not silently downgrade to WebGL.
- `apps/desktop-film-lab-batch/src/renderer/offscreen/create-offscreen-render-session.ts`
  - Offscreen export also defaults to `prefer = "webgpu"`.

Implication: for Desktop quality, focus first on WebGPU, not legacy WebGL.

### WebGPU Already Has Linear/HDR Foundations

Relevant files:

- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/filmlab.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`

Current WebGPU pipeline:

1. `filmlab -> rt.colorGraded (rgba16float)`
2. `bloomPrefilter -> bloom pyramid`
3. `halationPrefilter -> halation pyramid`
4. `diffusion -> full-image diffusion pyramid`
5. `composite -> rt.composited (rgba16float)`
6. final swap output is `rgba8unorm-srgb`, so hardware handles linear to sRGB.

The WebGPU shader comments explicitly state that the swap pass uses
`rgba8unorm-srgb` and avoids in-shader gamma math.

Conclusion: if the user is judging Desktop WebGPU, the missing quality is
probably not simply "sRGB blur". The stronger issue is model/order/profile.

### WebGPU Already Has Depth/Ray-Angle/Field-PSF For Glow Families

Relevant files:

- `packages/film-lab-renderer/src/webgpu/shaders/diffusion-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/bloom-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts`
- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/presets.ts`

Current shared params already include:

- `depthMistGain`
- `depthGlowGain`
- `depthRayAngleGamma`
- `depthRayAngleInnerThreshold`
- `depthMistRayAngleGain`
- `depthBloomRayAngleGain`
- `depthHalationRayAngleGain`
- `depthMistFieldPsfGain`
- `depthBloomFieldPsfGain`
- `depthHalationFieldPsfGain`
- `depthMistFieldPsfRadiusPx`
- `depthBloomFieldPsfRadiusPx`
- `depthHalationFieldPsfRadiusPx`

Current depth prefilter concept:

- Weight the source before the diffusion/bloom/halation pyramid.
- Avoid applying a sharp depth mask after the blur, because that creates
  double-image or ghost edges.
- Use ray-angle masks and optional field PSF widening.

Conclusion: the user already intuited a valuable direction, and the Desktop
WebGPU implementation has a significant part of it. The next step is not merely
"add depth"; it is to make optical behavior more coherent and productizable.

### Current Composite Still Looks Like Additive Post Glow

Relevant file:

- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`

Current composite behavior:

- Bloom and halation are sampled from accumulated pyramids.
- They are multiplied by strength.
- They are transformed by `glowShoulder`.
- They are screen-blended over `color.rgb`.
- Diffusion is also screen-blended after sampling the diffusion pyramid.

This is controlled and bounded, but it still behaves like a post effect:

```text
glow = shoulder(bloom + halation) * headroom
out = screen(base, glow)
diffusion = screen(out, diffusionOpacity)
```

Main suspected quality gap:

```text
direct = base * transmission
scatter = convolve(opticalSource * scatterMask)
out = direct + scatter
```

In other words, the model should redistribute light, not only add glow.

### Current Optical Source Is After The Main Grade

WebGPU currently builds glow from `rt.colorGraded`, after the `filmlab` pass.
The `filmlab` pass includes primary grade, LUTs, print CMY, and print contrast.

For a lens filter, this is probably too late. A physical lens filter scatters
light before the sensor/encoding/creative print stage. A better model is likely:

- Build the optical scatter source from a scene-linear or pre-print stage.
- Feed that source into bloom/halation/diffusion pyramids.
- Composite the resulting direct/scatter model before or around the final print
  stage, depending on desired artistic control.

This does not mean the whole renderer must be rewritten immediately. First
experiment only on WebGPU with a narrow Black Mist profile.

### WebGL Is Legacy And Less Relevant For New Optical Quality

Relevant files:

- `packages/film-lab-renderer/src/webgl/shaders/filmlab.frag.ts`
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`

WebGL still has more legacy behavior:

- Several color stages clamp to `[0, 1]`.
- It has bloom, halation, and diffusion pyramids.
- It does not have the same depth/ray-angle source prefilter path as WebGPU.

Conclusion: do not make WebGL the reference for new filter quality. Preserve
compatibility only after WebGPU proves the desired look.

### iOS Has A Known Parity Gap

Relevant doc:

- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/ios-v1.1-tasks/08-depth-coupling-native-pipeline.md`

The doc states:

- Desktop uses depth and ray-angle prefilters for bloom, halation, and
  diffusion.
- iOS has Core Image stages for bloom/halation/diffusion.
- iOS has no depth texture lifecycle or depth map import path in Phase0 native
  export.

Conclusion: if the user is judging iOS output, the gap is expected. The safest
sequence is:

1. Define and validate the optical profile model on Desktop WebGPU.
2. Then port the proven profile behavior to iOS native export.

## External Research Notes

The following sources were used to ground the product taxonomy and optical
model. The next chat may cite or revisit them if needed.

### Veiling Glare / GSF

Source:

- Stanford / Talvala et al., "Veiling Glare in High Dynamic Range Imaging"
  - https://graphics.stanford.edu/papers/glare_removal/glare_removal.pdf

Useful conclusions:

- Bright objects reduce contrast across the field of view.
- Veiling glare is a global light-transport effect in the camera body/lens.
- A point source contributes light to many other sensor pixels.
- The glare spread function is not always shift-invariant; it varies across
  the scene/field.
- Strong glare is mostly low frequency, but has edge-adjacent high-frequency
  components near bright regions.

Implication for Filmtone:

- A single uniform blur is not enough.
- Need field-varying low-frequency contrast floor / glare floor.
- Need source-reactive and possibly direction-aware response from strong
  practical lights.

### Polychromatic PSF / Spectral Dependency

Source:

- Font, Escalera, Yzuel, "Polychromatic point spread function: Calculation
  accuracy"
  - https://portalrecerca.uab.cat/en/publications/polychromatic-point-spread-function-calculation-accuracy/

Useful conclusion:

- A polychromatic PSF integrates monochromatic intensities over spectrum while
  accounting for source spectral emission and detector spectral response.
- More wavelength samples are needed when chromatic aberration is present.

Implication for Filmtone:

- RGB-only radius offsets are an approximation, but still useful.
- Better profiles should include wavelength bias:
  - warm/red long-tail halation for warm practicals,
  - restrained blue/green spread for cleaner filters,
  - chromatic ring/spectral edges for prism/halo profiles.

### Tiffen Diffusion Families

Sources:

- Tiffen Black Pro-Mist product page:
  - https://tiffen.com/products/black-pro-mist-filter
- Tiffen diffusion guide:
  - https://es.tiffen.com/pages/diffusion-guide

Relevant product facts:

- Black Pro-Mist is described around reducing highlights/lowering glare,
  taking the edge off digital cameras, soft light, pastel effect, and halation.
- Tiffen guide differentiates families such as Black Diffusion/FX,
  Warm Black Pro-Mist, Warm Pro-Mist, Digital Diffusion/FX, Black
  Glimmerglass, Black Soft/FX, and Black Pearlescent.
- The guide distinguishes effects that reduce fine sharp detail, reduce
  contrast, add warmth, preserve clarity, minimize halation, or keep image
  focused while softening.

Implication for Filmtone:

- Real-world filter categories are user-understandable.
- The categories map cleanly to internal optical profile parameters.

### Moment CineBloom

Source:

- https://www.shopmoment.com/products/moment-cinebloom-diffusion-filters

Relevant product facts:

- Available strengths include 5%, 10%, and 20%.
- Described as catching/blooming light, softening hard edges, smoothing skin,
  and escaping the clinical ultra-sharp digital look.

Implication for Filmtone:

- A "CineBloom" style profile should prioritize broad glow and dreamy haze over
  strict black retention.

### NiSi Black Mist

Source:

- https://nisiopticsusa.com/blackmist/

Relevant product facts:

- Strengths include 1/8, 1/4, 1/2.
- NiSi says 1/4 is popular for stills and 1/8 for video/cinematography.
- Each step in strength doubles the effect.
- Described as reducing highlights/lowering contrast, blooming bright light
  sources, soft portraits/skin tones, and maintaining resolution/clarity.

Implication for Filmtone:

- Use density labels like `1/8`, `1/4`, `1/2` because they are familiar.
- Strength should not be linear slider-only; density presets need tuned curves.

### Prism Lens FX Dream FX

Source:

- https://prismlensfx.com/products/dream-fx-filter

Relevant product facts:

- Dream FX strengths include 1/8, 1/4, 1/2.
- Described as dream-like cinematic softness, blooming highlights, and
  softening skin tones.

Implication for Filmtone:

- A "Dream" or "CineBloom" family can share broad haze mechanics but differ in
  bloom density, softness, and highlight reactivity.

## Integrated Product Conclusion

The right product move is to combine:

1. A commercially familiar filter-selection UX.
2. A technically coherent optical profile model.

Do not expose only raw parameters like `bloomStrength`, `diffusion`, and
`halationIntensity` as the main user model. Instead, create an
`Optical Filter Profile` layer that owns a bundle of optical behavior.

This should become a Filmtone signature feature:

```text
Lens Filter
  Type: Black Mist / CineBloom / Pearl / Warm Mist / Clean Soft / Streak / Prism
  Strength: Subtle / 1/8 / 1/4 / 1/2 / Heavy
  Advanced: Glow / Contrast Hold / Warmth / Highlight Reactivity / Depth Response
```

## Naming And Legal/Branding Guidance

Avoid implying official emulation of trademarked products.

Recommended UI names:

- `Black Mist`
- `Cine Bloom`
- `Pearl Glow`
- `Glimmer Soft`
- `Warm Mist`
- `Clean Soft`
- `Streak`
- `Prism Halo`

Avoid UI names like:

- `Tiffen Black Pro-Mist`
- `Moment CineBloom`
- `NiSi Black Mist`
- `Prism Lens FX Dream FX`

Those can be internal references or research notes, not product claims.

Suggested copy:

- "Inspired by common diffusion-filter families."
- "Filter-style optical profiles."
- "Not a manufacturer-certified emulation."

## Proposed Filter Families

| Family | User Expectation | Internal Behavior |
|---|---|---|
| Black Mist | Highlight bloom while preserving blacks | high black retention, nonlinear highlight scatter, medium long-tail diffusion |
| Cine Bloom | Dreamy broad glow and soft digital edge | wider diffusion, lower contrast hold, stronger glow floor |
| Pearl Glow | Beauty, polished skin, controlled halo | subtle diffusion, soft lens, low halation, clean highlights |
| Glimmer Soft | Clarity-preserving softening | microcontrast reduction, low bloom, minimal color shift |
| Warm Mist | Warm practical lights and night ambience | warm scatter, lower warm-highlight threshold, tasteful red/orange halation |
| Clean Soft | Less clinical sharpness without obvious filter | lens softness, minor diffusion, minimal bloom |
| Streak | Cross/star points from bright sources | existing cross-filter pipeline |
| Prism Halo | Ring/arc/rainbow specialty effects | existing halo-prism pipeline plus source reactivity |

## Proposed Shared Profile Schema

Create a new shared profile module, likely:

- `packages/film-lab-core/src/optical-filter-profiles.ts`

Possible TypeScript shape:

```ts
export type OpticalFilterFamily =
  | "blackMist"
  | "cineBloom"
  | "pearlGlow"
  | "glimmerSoft"
  | "warmMist"
  | "cleanSoft"
  | "streak"
  | "prismHalo";

export type OpticalFilterDensity =
  | "subtle"
  | "1/8"
  | "1/4"
  | "1/2"
  | "heavy";

export interface OpticalFilterProfile {
  id: string;
  family: OpticalFilterFamily;
  density: OpticalFilterDensity;
  displayName: string;
  params: Partial<Params>;
  optical: {
    blackRetention: number;
    directTransmission: number;
    scatterStrength: number;
    scatterCore: number;
    scatterTail: number;
    highlightReactivity: number;
    warmth: number;
    spectralBias: {
      redTail: number;
      greenTail: number;
      blueTail: number;
    };
    depthResponse: number;
    rayAngleResponse: number;
    fieldPsfScale: number;
  };
}
```

This does not have to be the final API. The important point is that the profile
must represent behavior, not only existing slider values.

## Existing Params To Reuse Before Adding New Ones

Start by mapping profiles onto existing params:

- `bloomThreshold`
- `bloomStrength`
- `bloomRadius`
- `bloomSoftKnee`
- `diffusion`
- `halationIntensity`
- `halationThreshold`
- `halationRadius`
- `halationHue`
- `halationSoftKnee`
- `lensSoftness`
- `rgbShift`
- `vignette`
- `depthMistGain`
- `depthGlowGain`
- `depthMistRayAngleGain`
- `depthBloomRayAngleGain`
- `depthHalationRayAngleGain`
- `depthMistFieldPsfGain`
- `depthBloomFieldPsfGain`
- `depthHalationFieldPsfGain`
- `crossFilter*`
- `haloPrism*`

Add new renderer params only when the direct/scatter experiment proves a need:

- `opticalDirectTransmission`
- `opticalBlackRetention`
- `opticalScatterStrength`
- `opticalHighlightReactivity`
- `opticalWarmScatter`
- `opticalSpectralTail`

## Technical Direction For Renderer

### Phase A - Profile Layer Without Renderer Rewrite

Goal: ship a better UX and baseline taste quickly.

Implement shared profile presets that map to existing params:

- Black Mist 1/8, 1/4, 1/2
- Cine Bloom 5%, 10%, 20% or Subtle/Medium/Heavy
- Pearl Glow Subtle/1/4
- Warm Mist 1/8, 1/4

Verification:

- `bun run build:core`
- `bun run build:renderer`
- Desktop smoke or focused UI verification if UI is touched.

### Phase B - Black Mist Direct/Scatter Experiment In WebGPU

Goal: solve the "added post glow" quality ceiling.

Current model:

```text
out = screen(base, shoulder(bloom + halation + diffusion))
```

Target experiment:

```text
opticalSource = prePrintOrSceneLinearColor
scatterMask = nonlinearHighlightAndMistResponse(opticalSource)
scatter = pyramidConvolve(opticalSource * scatterMask)
direct = base * transmissionCurve(base, blackRetention)
out = direct + scatter
```

Key requirements:

- Preserve black levels for Black Mist.
- Avoid white plates around hot lights.
- Keep skin from becoming waxy or grey.
- Let practical lights bloom without flattening the whole frame.
- Ensure missing depth preserves current output.

Possible implementation strategy:

1. Add one extra WebGPU render target for an optical source before final print,
   or split `filmlab` into pre-print and final-print stages.
2. Build scatter pyramids from this optical source.
3. Add a new composite mode path gated by profile/param.
4. Keep legacy screen-blend path as fallback during comparison.

### Phase C - Profile-Specific PSF Shapes

The current mip weighting is useful but generic. Add profile-specific PSF
behavior:

- Black Mist:
  - tight core,
  - broad but low-energy long tail,
  - high black retention,
  - restrained global haze.
- Cine Bloom:
  - wider tail,
  - lower contrast hold,
  - stronger broad glow floor.
- Pearl/Glimmer:
  - low halo,
  - more micro-softness than glow,
  - beauty-safe skin behavior.
- Warm Mist:
  - warm/red/orange long tail,
  - warm practical source reactivity.

### Phase D - iOS Parity

Only after Desktop WebGPU profile quality is proven:

1. Define native profile payload contract.
2. Map shared profile IDs to iOS native parameters.
3. Add depth coupling later as planned in
   `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/ios-v1.1-tasks/08-depth-coupling-native-pipeline.md`.
4. Use still-image depth first; do not start with video depth sequences.

## Product UX Direction

Recommended main control:

```text
Lens Filter
  [None] [Black Mist] [Cine Bloom] [Pearl Glow] [Warm Mist] [Clean Soft] [Streak] [Prism Halo]

Strength
  [Subtle] [1/8] [1/4] [1/2] [Heavy]
```

Recommended advanced controls:

```text
Glow
Contrast Hold
Warmth
Highlight Reactivity
Depth Response
Field Edge Response
```

UX principle:

- Main UI should answer "which glass did I put in front of the lens?"
- Advanced UI should answer "how much should Filmtone adapt it to this shot?"

Do not make the first screen a dense engineering panel.

## Recommended MVP

Do not start with every filter family.

MVP:

1. `Black Mist 1/8`
2. `Black Mist 1/4`
3. `Black Mist 1/2`

Why:

- Black Mist is the clearest commercial mental model.
- It tests the most important quality constraint: bloom highlights while
  keeping blacks alive.
- It surfaces whether the current screen-blend model is the real bottleneck.

Acceptance criteria:

- Practical lights bloom but do not become white plates.
- Black clothing/hair/night shadows remain black enough.
- Skin gets softer but not waxy.
- A daylight shot does not become uniformly foggy.
- A night shot with practicals shows obvious but tasteful filter character.
- Strength steps feel like density changes, not a linear opacity slider.

## Risks And Open Questions

1. **Optical source split may require renderer restructuring.**  
   If `filmlab` currently combines too many stages, pre-print scatter may need a
   new intermediate target or a split pass.

2. **Energy preservation can darken images unexpectedly.**  
   Direct attenuation must be profile-specific and exposure-aware. Black Mist
   should preserve blacks; Cine Bloom can reduce contrast more.

3. **Trademark/marketing risk.**  
   Use generic product names in UI. Keep commercial product names in internal
   research only.

4. **iOS parity will lag.**  
   iOS native currently lacks Desktop's full depth/ray-angle glow coupling.
   Do not promise exact parity until implemented.

5. **Filter profile should not fight LUT identity.**  
   Creative LUT packs and lens-filter profiles should be composable. A profile
   should not silently rewrite the look identity unless the user selected it.

6. **Video performance.**  
   Extra pyramids or additional render targets may be costly. WebGPU Desktop is
   the right first proving ground.

## Verification Guidance For Future Implementation

Smallest relevant checks:

- Shared profile/schema changes:
  - `bun run build:core`
  - relevant `film-lab-core` tests.
- WebGPU renderer changes:
  - `bun run build:renderer`
  - focused renderer tests if added.
  - Desktop visual smoke if UI/preview is affected.
- Desktop behavior/export changes:
  - `bun run verify:desktop`
- iOS native/export changes:
  - `bun run verify:ios`
  - use the `xcodebuild` command documented in
    `apps/capacitor-film-lab-ios/CLAUDE.md` if Swift build risk is material.
- Copy/UI wording:
  - `bun run check:filmtone-copy`
- Always:
  - `git diff --check`

## Suggested Plan Document Structure For The Next Chat

The next chat should produce a plan with these sections:

1. Product goal
2. Current renderer facts
3. UX model
4. Shared profile schema
5. MVP profile table
6. WebGPU direct/scatter experiment
7. Desktop UI integration
8. iOS parity plan
9. Verification plan
10. Rollout and risk controls

## Highest-Precision Handoff Prompt For The Next Chat

Copy this prompt into a new chat:

```text
You are working in:

/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone

Follow AGENTS.md. This is the standalone source of truth for Filmtone Desktop,
iOS, and shared packages. Do not begin with broad file discovery. Run
`git status --short --branch`, then route directly to the relevant files.

Task:
Create a detailed implementation plan for Filmtone's new Optical Filter Profile
system.

Context:
Read this handoff first:

docs/filmtone/archive/cross-cutting-legacy-2026-04-26-to-2026-05-01/filmtone-optical-filter-profile-handoff-2026-05-01-jst.md

The user wants Filmtone's lens-filter simulation to reach higher quality and
also become easier to use by selecting filter categories inspired by
commercial lens filters. The design must integrate both:

1. Product UX: a lens-filter rack with categories such as Black Mist,
   Cine Bloom, Pearl Glow, Warm Mist, Clean Soft, Streak, and Prism Halo, plus
   density/strength choices such as Subtle, 1/8, 1/4, 1/2, Heavy.
2. Rendering quality: move beyond generic additive post glow toward optical
   profiles that control direct transmission, black retention, nonlinear
   highlight scatter, PSF shape, depth response, ray-angle response, and
   spectral/warm scatter behavior.

Important current facts:

- Desktop defaults to WebGPU.
- WebGPU already uses `rgba16float` intermediates and final
  `rgba8unorm-srgb`, so the Desktop quality gap is probably not simply "sRGB
  blur".
- WebGPU already has depth/ray-angle/field-PSF prefilters for diffusion,
  bloom, and halation.
- Current composite still screen-blends bloom/halation/diffusion over the
  final color, so it can read like added post glow rather than light
  redistributed by glass.
- Current glow source is `rt.colorGraded`, after much of the grade/print stack.
  A better optical model may need a pre-print or scene-linear source.
- iOS native has a known parity gap: Core Image bloom/halation/diffusion exist,
  but depth texture lifecycle/import and full Desktop-style depth coupling are
  not yet implemented.
- Existing iOS worktree changes are unrelated; do not revert them.

Plan requirements:

- Do not implement code yet unless explicitly asked. Produce a plan document.
- Prefer a staged plan:
  1. shared profile schema in `packages/film-lab-core`,
  2. MVP Black Mist 1/8, 1/4, 1/2 profiles mapped to existing params,
  3. Desktop UI filter-rack integration,
  4. WebGPU direct/scatter experiment for Black Mist,
  5. expansion to Cine Bloom / Pearl / Warm / Clean Soft,
  6. iOS parity after Desktop quality is proven.
- Include technical file targets and verification commands.
- Include trademark-safe naming guidance: use generic names in UI, commercial
  products only as internal references.
- Include acceptance criteria for the Black Mist MVP:
  practical lights bloom, blacks remain alive, skin does not become waxy,
  daylight does not turn uniformly foggy, night practicals show tasteful filter
  character, density steps feel like filter strengths rather than opacity.
- Include risks and open questions, especially renderer pass order,
  energy-preserving direct/scatter composition, iOS parity, and performance.

Primary files to inspect:

- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/presets.ts`
- `packages/film-lab-core/src/optical-recommendation.ts`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/filmlab.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/diffusion-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/bloom-depth-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/halation-depth-prefilter.frag.wgsl.ts`
- `apps/desktop-film-lab-batch/src/renderer/` only for UI integration targets.
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/ios-v1.1-tasks/08-depth-coupling-native-pipeline.md` for iOS
  parity context.

Output:
Write a detailed plan document under `docs/filmtone/` with a concise filename
including `optical-filter-profile-plan` and `2026-05-01-jst`.
Do not stage, commit, push, or edit the portfolio repo.
```

