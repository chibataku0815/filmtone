# Detail Softness / Source Detail Compensation Plan

Date: 2026-05-11 JST
Status: planning only. No implementation has started.
Scope: Filmtone Desktop, Filmtone iOS, shared `film-lab-*` packages.

## Goal

Add a filmic softness system that reduces hard digital detail without making
footage look simply blurred.

This plan separates two concerns:

- `detailSoftness`: user creative intent. A visible control for reducing hard
  micro-detail and digital acutance.
- Source Detail Compensation: source adaptation. A conservative automatic bias
  based on capture device / manufacturer / profile, especially for iPhone and
  other heavily processed consumer video.

The goal is not to create a 1-inch-only recipe. The feature should help any
source that arrives too sharp, too locally contrasty, or too edge-enhanced.

## Product Premise

Filmtone already has several filmic ingredients:

- `lensSoftness` for lens/periphery softness.
- Bloom, halation, diffusion, and optical scatter for light behavior.
- Film compression and print controls for tonal response.
- Grain with luma-aware behavior in native pipelines.

What is missing is a center-inclusive detail treatment that softens the hard
microcontrast common in modern digital capture. Existing `lensSoftness` is not
the right semantic home because it is currently implemented as edge/periphery
softening, coupled to lens feel and chromatic aberration.

## Definitions

### Detail Softness

User-facing creative control.

Recommended contract:

- Key: `detailSoftness`
- Range: `0...1`
- Default: `0`
- Useful working range:
  - `0.06-0.10`: subtle digital edge relief
  - `0.12-0.18`: visible filmic softening
  - `0.20-0.28`: strong soft finish
- Values above `0.30` should remain usable but protected against obvious blur.

### Source Detail Compensation

Source-aware render bias.

Recommended shape:

- Internal profile result: `sourceDetailProfile`
- Mode: `off | auto | manual` eventually, but start with internal `auto`
  plumbing and conservative defaults.
- Output: an additive bias or multiplier applied to the effective detail
  softness at render time.
- Do not save the automatic source bias into user Looks by default.

Rationale: a Look should stay portable across footage. If an iPhone auto-bias is
baked into a saved Look, the same Look can become too soft on camera-native Log
or already-soft lens footage.

## High-Level Render Model

Effective value:

```text
effectiveDetailSoftness =
  clamp(detailSoftness + sourceDetailBias, 0, effectiveMax)
```

Recommended initial clamps:

- `effectiveMax`: `0.34`
- unknown source bias: `0.00-0.03`
- known strong-sharpening consumer source: cap auto contribution around `0.14`

The automatic bias should be transparent and conservative. It is a starting
point, not a manufacturer-certified transform.

## Algorithm Direction

Do not implement `Detail Softness` as a plain Gaussian blur.

Target behavior:

1. Build a small-radius local reference from the graded image.
2. Compute high-frequency detail: source minus local reference.
3. Reduce high-frequency contrast according to `effectiveDetailSoftness`.
4. Protect major edges and readable boundaries with a gradient guard.
5. Reduce luma detail more than chroma detail.
6. Let hard highlight edges soften slightly more than midtone texture.
7. Preserve grain stage behavior by applying detail softness before grain.

Recommended initial kernel behavior:

- Small radius: roughly `0.55-1.45 px` depending on strength and output scale.
- Optional wider support only at stronger values.
- Luma detail attenuation stronger than chroma attenuation.
- Edge guard based on local luma gradient, not only radial distance.
- Highlight-edge bias using luma and local contrast.

Failure to avoid:

- all-over blur
- waxy skin
- unreadable text
- smeared hair / foliage
- halo doubling before bloom
- preview/export mismatch
- temporal shimmer on video

## Pipeline Placement

Preferred placement:

```text
input LUT
-> base grade
-> tone compression
-> Detail Softness
-> edge optics / lensSoftness / rgbShift
-> glow family: bloom, halation, diffusion, optical scatter
-> vignette
-> grain
-> creative LUT
-> print stage
```

Reasoning:

- After base grade and compression, the softness sees the intended tonal shape.
- Before glow, hard digital edges do not over-feed bloom / halation.
- Before grain, generated grain remains crisp and film-like instead of being
  blurred afterward.
- Before creative LUT / print, the color pipeline remains stable.

Composite-only MVP is possible but lower quality because bloom / halation would
still be generated from the hard source. Use it only as a temporary spike, not
as the target architecture.

## Source Detail Profiles

Initial profiles should be heuristic and conservative.

Suggested profile groups:

| Source group | Bias intent | Notes |
|---|---:|---|
| Apple iPhone SDR / HEVC / non-Log | `+0.08...+0.14` | Highest priority. Often needs edge/acutance relief. |
| Apple Log / Apple Log 2 | `+0.04...+0.08` | Still Apple pipeline, but treat less aggressively than SDR. |
| DJI Osmo / action-style consumer video | `+0.06...+0.12` | Strong local detail and small-sensor crispness are common. |
| GoPro / action camera | `+0.08...+0.15` | Similar to DJI, possibly stronger. |
| Sony / Canon / Panasonic Log camera | `+0.00...+0.04` | Avoid making cinema-camera or mirrorless Log footage too soft. |
| Unknown Rec.709 | `+0.00...+0.03` | Very conservative. |
| Unknown Log | `0.00` | Do not assume sharpening. |

These are starting points for A/B testing, not final tuning.

## Metadata Strategy

Existing useful fields:

- `cameraOptics.cameraMake`
- `cameraOptics.cameraModel`
- `cameraOptics.lensModel`
- `sourceVideoMetadata.logTransferFunction`
- `sourceVideoMetadata.inputTransformPolicy`
- source codec family where available

Near-term detection:

1. Use `cameraOptics.cameraMake` / `cameraModel` when metadata source is
   reliable.
2. Combine with log transfer state. Apple Log should not be treated the same as
   Apple SDR.
3. Use codec / transfer metadata as a weak signal only.
4. If metadata is missing, stay conservative and let the user slider do the
   work.

Future-friendly contract:

```text
SourceDetailProfile {
  id: string
  confidence: low | medium | high
  manufacturer?: string
  modelFamily?: string
  transferClass?: rec709 | hdr | log | unknown
  recommendedBias: number
  effectiveMax: number
  reason: string
}
```

Do not claim exact manufacturer emulation. This is capture adaptation, not a
certified Apple / DJI / GoPro profile.

## Contract And Storage

Add `detailSoftness` to the shared parameter contract.

Expected core targets:

- `packages/film-lab-core/src/params.ts`
- `packages/film-lab-core/src/schema.ts`
- `packages/film-lab-core/src/phase0-schema.ts`
- `packages/film-lab-core/src/quick-semantics.ts`
- `packages/film-lab-core/src/ios-swift-payload.ts`
- generated Swift via `bun run generate:ios-swift`

Expected Swift targets:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtonePhase0Params.swift`
- generated `FilmtonePhase0Generated.swift`
- `FilmtonePhase0ParamsPatch.opticsGlowKeys` decision:
  - Include `detailSoftness` if it becomes part of a Look's optical identity.
  - Do not include automatic `sourceDetailBias`.

Storage rule:

- Save user `detailSoftness` in params / project / Look as normal.
- Keep automatic source compensation as source/session metadata or resolved
  render state.
- Sidecars may report resolved source profile for auditability, but should keep
  user param and auto bias distinguishable.

## UI Plan

Initial UI:

- Add `Detail Softness` to Advanced > Optics or a renamed Optics / Texture
  group.
- Keep `Lens Softness` but adjust copy later so it reads as lens/periphery
  softness, not general detail softness.
- Do not expose many technical sub-controls.

Possible later UI:

- `Auto source compensation` toggle.
- Read-only source chip such as `iPhone detail compensation` only if the app can
  explain it without clutter.
- Manual profile override only if real footage shows metadata misses are common.

Recommended copy direction:

- `Detail Softness`: "Softens hard fine detail without adding glow."
- `Lens Softness`: "Adds lens-like edge softness."
- Source compensation: "Balances capture sharpening from the source."

Copy must go through the copy quality harness before implementation copy lands.

## Implementation Phases

### Phase 1: Contract And Neutral Plumbing

Goal: add `detailSoftness` everywhere with default `0`, no visual change when
unset.

Tasks:

- Add param to TypeScript contract and schemas.
- Add Swift core field and generated payload.
- Add decoding / encoding / patch handling.
- Add sidecar field if sidecar emits all grade params.
- Add tests for schema, patch round-trip, generated Swift check.

Done:

- Existing projects and Looks load unchanged.
- `detailSoftness: 0` is bit-neutral.
- Core and Swift contract checks pass.

### Phase 2: Detail Softness Render Pass

Goal: implement the real visual effect before glow and grain.

Tasks:

- WebGL: add a full-resolution pre-glow pass after `rtColorGraded`, feeding
  bloom / halation / diffusion / composite from the softened source when active.
- WebGPU: add matching pass and bind layout / pipeline, preserving orientation
  parity.
- macOS native: add Core Image / Metal kernel after tone compression and before
  edge optics.
- iOS export / preview: mirror macOS ordering.

Done:

- Preview and export match visually.
- Detail softness affects bloom/halation inputs correctly.
- Strong values avoid obvious blur on text, hair, foliage, and faces.

### Phase 3: UI Exposure And Recipes

Goal: expose the control without disrupting existing Looks.

Tasks:

- Add Advanced control.
- Add help copy and localized labels.
- Decide whether existing optical recipes should include `detailSoftness`.
- Keep default reset at `0`.
- Tune recipes conservatively.

Suggested first recipe values:

- default optical recipe: `max(base.detailSoftness, 0.10)`
- strong optical recipe: `max(base.detailSoftness, 0.18)`

Done:

- Users can intentionally soften digital detail.
- Existing `lensSoftness` behavior remains compatible.

### Phase 4: Source Detail Compensation

Goal: add source-aware bias without baking it into Looks.

Tasks:

- Add source profile resolver in shared core.
- Use available `cameraOptics` and source metadata.
- Add platform-specific metadata collection only where missing.
- Apply source bias at render time.
- Keep resolved user value and auto bias distinguishable in debug / sidecar.

Done:

- iPhone footage starts closer to a natural filmic baseline.
- Unknown or cinema-camera Log footage is not over-softened.
- User can still override by lowering or raising `detailSoftness`.

### Phase 5: Visual Tuning Matrix

Goal: tune by footage class, not by assumption.

Minimum A/B footage matrix:

- iPhone SDR HEVC, bright daylight, high local detail
- iPhone Apple Log / ProRes, skin and practical highlights
- DJI Osmo / action-camera style Rec.709
- Sony / Canon / Panasonic Log mirrorless footage
- low-light noisy clip
- hair / foliage / brick / text
- strong practical light or window highlight

Checks:

- Does the hard digital edge reduce?
- Does the image remain readable?
- Does glow become more natural?
- Does grain still sit on top?
- Does motion avoid shimmer?
- Does export match preview?

## Verification Plan

Minimum per phase:

- Contract: `bun run build:core`
- Renderer: `bun run build:renderer`
- Swift payload: `bun run generate:ios-swift -- --check` if supported, or run
  generator then inspect generated diff.
- Desktop native: `bun run verify:macos`
- iOS: `bun run verify:ios`
- Diff hygiene: `git diff --check`

Broader verification after visual implementation:

- Preview/export parity screenshots or still frame exports.
- Before/after sample set.
- Performance check on 4K video.
- Regression check with `detailSoftness: 0`.

## Risks

- Over-softening faces and small texture.
- Blurring UI/text if applied to source overlays by accident.
- WebGL/WebGPU/native orientation mismatch in the new pass.
- Bloom/halation parity drift if some pipelines use softened source and others
  use hard source.
- Metadata false positives, especially generic `Apple` / `iPhone` strings on
  edited exports.
- Saved Look portability if source compensation is accidentally baked into
  param overrides.
- Performance cost from an extra full-resolution pass.

## Stop Conditions

Stop and review if any of these happen:

- `detailSoftness: 0` changes existing output.
- Preview/export parity fails after two fix attempts.
- Manufacturer profile logic requires claims that cannot be validated from
  local metadata.
- Strong values cannot preserve readable detail without new algorithm work.
- Source auto compensation starts changing saved Look identity.

## Out Of Scope

- A 1-inch-camera-only recipe.
- Manufacturer-certified camera emulation.
- New Log profile work unrelated to detail softness.
- Broad preset retuning before the core effect is visually proven.
- Public marketing copy before implementation and sample validation.

## Copy / History Impact

Current plan only: no public copy/history impact yet.

Future implementation likely affects:

- Advanced control labels and help copy.
- Release notes.
- Product explanation around source-aware detail handling.

Article Opportunity: Developer note after implementation and A/B samples exist.
Not ready for public article from this plan alone.

Change-History Opportunity: Yes. If implemented, document that Filmtone moved
from lens/periphery softness only to a separate source-aware detail softness
model.

## Open Questions

1. Should `detailSoftness` be part of saved Look optical identity from day one?
2. Should `Auto source compensation` be visible in the first UI release, or
   internal until enough footage is tested?
3. Should iPhone Apple Log and iPhone SDR use separate defaults immediately?
4. Should the first implementation tune Desktop/macOS native first, or shared
   renderer first?
5. What sample footage set becomes the visual acceptance baseline?

