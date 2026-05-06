# Backlight Veiling Glare Implementation Plan (2026-05-03 JST)

## Purpose

添付参考の逆光・窓光の見え方を、Filmtone Desktop の optical finish として再現する。

これは既存 Bloom / Halation の強度追加ではなく、強い光源がレンズ内で散乱し、黒と中間調を侵食する `Veiling Glare / Backlight Mist` として実装する。

優先順位:

1. 画の再現品質
2. Preview / export の一致
3. 既存 UI への最小統合
4. iOS parity と外殻ドキュメント

## Target Look

### Reference A: outdoor sun silhouette

- 太陽または画面外太陽が左側から入り、フレーム全体の黒が持ち上がる。
- 主体はシルエットに近いが、黒潰れではなく薄い乳白色の膜が乗る。
- Bloom の輪郭だけでなく、低周波の広い haze が必要。
- 彩度は全体に落ち、光源側はわずかに warm / beige に寄る。

### Reference B: outdoor backlit cliff portrait

- 左上の空が広く低コントラスト化し、岩肌と人物にやわらかく被る。
- 白飛びの硬い境界よりも、光源側からの veil が主役。
- 被写体の顔や肌は残し、単純な全画面 fade にはしない。

### Reference C: indoor window backlight

- 大面積の白い窓が source になり、人物とカメラ周辺へ広い霧状の scatter が乗る。
- 窓の白はほぼクリップしてよいが、境界は硬すぎない。
- シャドウは一部深く残る。ただし純粋な黒ではなく、窓光に押されて局所的に持ち上がる。

## Current Implementation Facts

- Default soft finish is too weak for this look:
  - `FILMTONE_SOFT_FINISH_PATCH` in `packages/film-lab-core/src/presets.ts`
  - `bloomStrength: 0.22`
  - `diffusion: 0.08`
  - `halationIntensity: 0.10`
- Existing WebGPU composite already has a direct + scatter path:
  - `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
  - Params:
    - `opticalDirectTransmission`
    - `opticalBlackRetention`
    - `opticalScatterStrength`
    - `opticalHighlightReactivity`
    - `opticalWarmScatter`
    - `opticalSpectralTail`
- Existing WebGPU backend already has depth / ray-angle source shaping for Mist and Glow:
  - `bloom-depth-prefilter.frag.wgsl.ts`
  - `halation-depth-prefilter.frag.wgsl.ts`
  - `diffusion-depth-prefilter.frag.wgsl.ts`
- Desktop video export already prefers WebGPU:
  - `apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts`
  - `createOffscreenRenderSession({ prefer: "webgpu" })`
- WebGL path does not have equivalent direct + scatter behavior. This work should target WebGPU first.

## Product Decision

Create a new optical finish family/profile called `Backlight Veil`.

Do not position it as stronger Bloom. The user-facing behavior should be:

- Bloom: local highlight glow
- Halation: colored edge glow
- Mist: whole-image diffusion
- Backlight Veil: source-reactive low-frequency glare that reduces contrast

The first implementation should use the existing WebGPU direct + scatter model and existing depth/ray-angle prefilters. If it cannot reach the reference quality, add a dedicated `veiling-glare` renderer pass.

## Implementation Phases

## Phase 1: Profile Probe

Goal: establish whether existing WebGPU optical primitives can reach the reference.

Files:

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/optical-filter-profiles.test.ts`
- `packages/film-lab-core/src/optical-recommendation.ts`
- `packages/film-lab-core/src/optical-recommendation.test.ts`

Add profiles:

- `backlightVeil-1-8`
- `backlightVeil-1-4`
- `backlightVeil-1-2`
- Optional scene-specific aliases later:
  - `windowVeil`
  - `sunVeil`

Initial 1/4 parameter target:

```ts
{
  bloomThreshold: 0.62,
  bloomStrength: 0.34,
  bloomRadius: 0.76,
  bloomSoftKnee: 0.78,

  diffusion: 0.22,
  depthMistGain: 0.38,
  depthGlowGain: 0.30,
  depthMistRayAngleGain: 0.55,
  depthBloomRayAngleGain: 0.42,
  depthHalationRayAngleGain: 0.30,
  depthMistFieldPsfGain: 1.0,
  depthBloomFieldPsfGain: 1.0,
  depthHalationFieldPsfGain: 1.0,
  depthMistFieldPsfRadiusPx: 26,
  depthBloomFieldPsfRadiusPx: 14,
  depthHalationFieldPsfRadiusPx: 18,

  halationIntensity: 0.12,
  halationThreshold: 0.54,
  halationRadius: 0.62,
  halationHue: 22,
  halationSoftKnee: 0.56,

  lensSoftness: 0.09,
  rgbShift: 0.0008,

  opticalDirectTransmission: 0.84,
  opticalBlackRetention: 0.58,
  opticalScatterStrength: 0.72,
  opticalHighlightReactivity: 0.86,
  opticalWarmScatter: 0.20,
  opticalSpectralTail: 0.08,
}
```

Density scaling:

- `1/8`: keep shadows more stable.
  - `diffusion: 0.14`
  - `opticalDirectTransmission: 0.90`
  - `opticalBlackRetention: 0.72`
  - `opticalScatterStrength: 0.46`
- `1/2`: strong reference / music-video direction.
  - `diffusion: 0.30`
  - `opticalDirectTransmission: 0.76`
  - `opticalBlackRetention: 0.42`
  - `opticalScatterStrength: 0.88`

Acceptance gate:

- Outdoor sun silhouette:
  - subject darks become veiled without turning grey-flat.
  - light side visibly washes over the subject.
- Outdoor cliff:
  - left/top haze increases without destroying subject skin.
- Indoor window:
  - white window bleeds broadly and softly into the room.
- No obvious circular ring, cross streak, or Prism artifact.
- Preview and export use the same WebGPU output path.

If Phase 1 passes visually, stop at profile + UI polish. If it misses the reference, proceed to Phase 2.

## Phase 2: Dedicated Veiling Glare Pass

Goal: add the missing low-frequency glare component that Bloom / Halation / Diffusion cannot produce reliably.

New renderer concept:

1. Build a source mask from large bright areas and near-white highlights.
2. Blur the source with a very wide low-frequency pyramid.
3. Apply direct-light attenuation to the base image.
4. Add warm source-reactive scatter.
5. Optionally bias scatter direction from source centroid / user origin.

New params:

```ts
veilingGlareStrength: number;      // 0..1
veilingGlareThreshold: number;     // 0..1
veilingGlareRadius: number;        // 0..1, maps to wide mip spread
veilingGlareTransmission: number;  // 0..1 direct preservation
veilingGlareBlackLift: number;     // 0..1 shadow veil floor
veilingGlareWarmth: number;        // 0..1
veilingGlareSourceX: number;       // 0..1, default auto
veilingGlareSourceY: number;       // 0..1, default auto
```

Implementation files:

- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-core/src/presets.ts`
- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/veiling-glare-prefilter.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/veiling-glare-blend.frag.wgsl.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/index.ts`
- `packages/film-lab-renderer/src/webgpu/compositeUniforms.ts` only if blend stays in composite
- `packages/film-lab-renderer/dist/`

Preferred render graph:

```text
media
  -> filmlab grade
  -> bloom / halation / diffusion pyramids
  -> composite
  -> veiling glare post pass
  -> halo prism / cross / shafts if active
  -> motion blur
  -> present/readback
```

Reason:

- Veiling glare should affect final contrast after the core grade and glow family.
- It should happen before motion blur so temporal output accumulates the final optical state.
- It should not be hidden inside Bloom because it needs different masking and direct attenuation.

Source mask:

```wgsl
let luma = dot(source.rgb, LUMA_709);
let maxChannel = max(source.r, max(source.g, source.b));
let whiteArea = smoothstep(threshold, threshold + softKnee, luma);
let plateArea = smoothstep(0.78, 0.98, maxChannel) * smoothstep(0.20, 0.55, localLowContrast);
let source = max(whiteArea, plateArea) * source.rgb;
```

Important: the indoor window reference needs large white plates to trigger even when they have no specular point shape.

Blend model:

```wgsl
direct = scene * mix(1.0, transmission, strength);
scatter = wideVeil * warmBias * strength;
shadowFloor = blackLift * strength * sourceCoverage;
result = direct + scatter + shadowFloor * (1.0 - scene);
```

Avoid:

- pure screen blend only
- global fade only
- fixed white overlay
- hard clipping to `vec3(1.0)` before final present

## Phase 3: Desktop UI Integration

Goal: expose the effect without making the Finish Tools panel noisy.

Files:

- `apps/desktop-film-lab-batch/src/renderer/FilmLabControlPanelCore.tsx`
- `apps/desktop-film-lab-batch/src/renderer/messages.ts`
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
- `apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.ts`
- Tests beside the touched files.

UI plan:

- Add `Backlight Veil` as a Lens Filter family.
- Keep the existing compact Lens Filter selector.
- Do not add full advanced sliders in the first pass.
- If Phase 2 adds dedicated params, expose only density chips initially.
- Hidden params are allowed if the profile output is the product surface.

Metadata:

- Existing `look.opticalFilterProfile` should record the selected profile.
- If dedicated params are introduced, they remain normal `Params`.
- Do not create separate session metadata unless the user-facing profile identity cannot be reconstructed from params.

## Phase 4: Recommendation Integration

Goal: scene analysis should choose Backlight Veil when it sees big bright plates or backlight dominance.

Files:

- `packages/film-lab-core/src/optical-recommendation.ts`
- `packages/film-lab-core/src/optical-recommendation.test.ts`
- `apps/desktop-film-lab-batch/src/renderer/optical-scene-analysis.ts`

Descriptor triggers:

- high `highlightCoverage`
- high `dominantShotCoverage`
- moderate/high `portraitLikelihood`
- strong luma asymmetry from one side of the frame
- large bright area with low detail, not only point lights

Rule:

- Point lights / night city -> existing Glow / Cross remains appropriate.
- Large window / sun plate / backlight portrait -> Backlight Veil.
- Beauty close-up without strong backlight -> Pearl Glow / Mist remains appropriate.

## Phase 5: Verification

Primary commands:

```bash
bun test packages/film-lab-core/src/optical-filter-profiles.test.ts
bun test packages/film-lab-core/src/optical-recommendation.test.ts
bun run build:core
bun run build:renderer
bun test apps/desktop-film-lab-batch/src/renderer/export-metadata-session.test.ts apps/desktop-film-lab-batch/src/renderer/metadata-json-runtime.test.ts
bun run verify:desktop
git diff --check
```

Visual QA:

- Use three target scene families:
  - outdoor hard backlight portrait
  - outdoor hazy cliff / beach backlight
  - indoor large window backlight
- Capture preview and export frame for each.
- Confirm no preview/export orientation mismatch in bloom, diffusion, or new veil.
- Confirm no WebGPU-only pass is silently absent from export.

Visual acceptance:

- Blacks lift through light scatter, not a flat global fade.
- Highlight core can clip, but the boundary is not a hard digital plate.
- Subject edge remains readable.
- The effect remains plausible at 1/8 and intentionally strong at 1/2.
- No Prism ring, star streak, or colored fringe unless the user explicitly selects those families.

## Risks

### Existing profile path may be too weak

The current direct + scatter path depends on existing bloom / halation / diffusion energy. If the source is a very large clipped window, it may still lack the broad, directional veil in the references.

Mitigation: Phase 2 dedicated source mask and wide pyramid.

### WebGL parity

The WebGL composite path does not implement optical direct + scatter. Desktop preview/export should use WebGPU for this effect. If WebGL fallback matters later, add explicit degraded-state messaging rather than silently shipping a different look.

### iOS parity

iOS Phase0/Core Image does not yet have the Desktop WebGPU depth / ray-angle / dedicated veil path. Do not claim iOS parity until a native implementation exists.

### Over-lifting shadows

If `opticalBlackRetention` or future `veilingGlareBlackLift` is too aggressive, the result becomes a flat fade. Use source-reactive lift and preserve local contrast around faces.

### Resolution-dependent radius

Prior export investigations identified fixed-pixel optical radii as a possible preview/export mismatch source. Any new pass should use normalized radius or a fixed reference resolution scale.

## Recommended Next Step

Implement Phase 1 first on this branch:

```text
feature/optical-veiling-glare-research
```

Do not start with broad QA or UI redesign. Add the `Backlight Veil` profiles, run core/renderer verification, then visually tune on the three reference scene types. Move to Phase 2 only if the profile probe cannot reproduce the low-frequency veil.
