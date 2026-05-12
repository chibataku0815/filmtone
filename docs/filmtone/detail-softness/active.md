# Phase 5: Detail Softness Visual Tuning Matrix

Date opened: 2026-05-12 JST
Phase: 5 of 5 (see `strategy.md`; Phase 4-B archived at
`archive/2026-05-12-phase-4b-source-compensation-native-wiring.md`,
commit `52d38328`).

## Gating

All four renderers now read `detailSoftness` with a real render pass,
and native macOS + iOS feed a runtime `sourceDetailBias` resolved from
source metadata at the export / preview callsites:

- macOS native render pass — commit `e277e9f3`.
- iOS export render pass — commit `eac47d53`.
- WebGPU + WebGL render passes — commit `444db1e0`.
- macOS + iOS Advanced UI exposure — commit `27a856fa`.
- TS resolver `resolveSourceDetailCompensation` — commit `3036e5b9`.
- Native `sourceDetailBias` wiring + Swift resolver mirror — commit
  `52d38328`.

Nothing further is gated. This phase is judgment, not code.

## Goal

Run a visual A/B matrix across all four renderers (macOS native, iOS
export, WebGPU, WebGL) at three user `detailSoftness` settings
(`0.00`, `0.18`, `0.30`) over the agreed source classes. Confirm
stage identity when effective softness is zero, then judge product
output at `0.00` / `0.18` / `0.30` with each renderer's real
`sourceDetailBias` behavior. Only patch code if a real visual defect
is found.

The default lane disposition is **no new product code**. Phase 5 is a
QA / judgment pass, not a feature pass.

## Owner-confirmed constraints

- No new product code unless the visual matrix finds a concrete
  defect.
- If a defect is found, the patch is scoped to the single failing
  surface (source class + renderer + setting) and committed
  separately.
- `sourceDetailBias` stays runtime-only — no schema change,
  no Look identity, no UI surface.
- No `PHASE0_SCHEMA_VERSION` bump.
- No copy / release-note edits inside this phase. Release-note copy
  can travel in a follow-up lane once the matrix confirms results.

## Matrix Dimensions

### Renderers (4)

| Renderer | Entry point | Source-metadata channel |
|---|---|---|
| macOS native | `FilmtoneGradePipeline.apply(...)` → `applyDetailSoftnessStage` | `cameraOptics` + `colorClass` + `resolvedProfile?.id` |
| iOS export | `GradeRenderPipeline.applyDetailSoftnessStage(...)` | `request.sourceProbe` (nested `sourceVideoMetadata` preferred, top-level fallback) |
| WebGPU | `WebGPUBackend.detailSoftness(...)` (renderer pass) | None at backend boundary (`sourceDetailBias = 0`) |
| WebGL | `WebGLBackend.detailSoftness(...)` (renderer pass) | None at backend boundary (`sourceDetailBias = 0`) |

### `detailSoftness` settings (3)

- `0.00` — user-authored softness is zero. WebGPU / WebGL and
  metadata-missing native renders should be identity. Native renders
  with a non-zero `sourceDetailBias` should show only the intended
  automatic source compensation.
- `0.18` — mid-range user-authored softness.
- `0.30` — near `DETAIL_SOFTNESS_EFFECTIVE_MAX` (`0.34`); judges
  ceiling behavior and clamp interaction with non-zero
  `sourceDetailBias`.

### Source classes (7)

| Class | Expected `sourceDetailBias` (native) | Renderer notes |
|---|---|---|
| iPhone SDR / HEVC | `0.10` | Native classifies via `cameraMake == "Apple"` + Rec.709 path. Web stays at `0`. |
| iPhone Apple Log / ProRes | `0.06` | Apple-Log signals must override the iPhone Rec.709 path. |
| DJI / GoPro (Rec.709) | `0.08` | DJI / GoPro action cameras. |
| Sony / Canon / Panasonic Log | `0.02` | Cinema-Log class; conservative bias. |
| Low-light noisy clips | depends on camera class | Watch for noise-amplification artifacts at `0.30`. |
| Hair / foliage / brick / text | depends on camera class | Watch for waxy / smeared / illegible artifacts at `0.30`. |
| Strong practical lights | depends on camera class | Watch for halo / haze interaction with edge guard at `0.30`. |

`detailSoftness` × renderer × source class × content content = the
matrix. Not every cell needs an explicit screenshot; sweep at `0.00`
for identity and `0.30` for stress, and spot-check `0.18`.

## Identity test when effective softness is zero

For each renderer, capture or render the same source at:

- `detailSoftness = 0.00` with `sourceDetailBias = 0` (WebGPU /
  WebGL default, or native metadata-missing / explicitly neutral
  fixture).
- A reference output produced without the detail-softness stage in
  the pipeline (e.g. by stubbing `FilmtoneDetailSoftness.deriveUniforms`
  to return `effectiveDetailSoftness = 0`, or by reverting the
  detail-softness commits locally — owner picks the simpler ground
  truth).

Pass condition: byte-equivalent or pixel-equivalent within encoding
noise. The clamp + `effectiveDetailSoftness < 0.0001` early-return
should make this true by construction on every renderer.

If `effectiveDetailSoftness == 0` is **not** identity on any renderer,
document it and stop — that is a Phase-5-blocking defect, not a
tuning issue.

## Quality judgment at `detailSoftness = 0.18` / `0.30`

For each renderer × source class:

- Skin / face: no waxy plasticity.
- Hair / foliage: no smearing or loss of high-frequency texture
  beyond the intended softening.
- Brick / text: text remains legible; brick mortar lines remain
  resolvable.
- Strong practical lights: no over-bright halo blooming or unnatural
  edge guard collapse.
- Noise on low-light footage: not amplified into clumpy blotches.

Per-renderer divergence is a defect candidate even if no single
renderer looks bad in isolation — the four renderers should converge
in look at the same `detailSoftness` value (web has no bias; native +
iOS bias matches the resolver).

## Edit Targets (none by default)

This phase intentionally has no expected code edits. If a defect is
found, the next active.md (Phase 5-followup) is the place for the
patch — not this one.

Likely patch surfaces _if_ a defect is found:

- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts` — WGSL
  detail-softness pass (kernel radius, edge guard, chroma atten).
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts` — GLSL
  parity.
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`
  — shared uniform math, if every renderer drifts in the same
  direction.
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneSourceDetailCompensation.swift`
  — bias values, if a source class is consistently mis-classified or
  over/under-corrected.

Do not pre-patch any of these. Defect-first.

## Verification

This phase is QA, not code, so the gates are minimal:

```bash
bun run check:filmtone-context
git diff --check
```

If a defect-driven patch is taken, the touched-surface gates apply
(e.g. `bun run verify:macos`, `bun run verify:ios`, `swift test
--package-path packages/film-lab-swift-core`, `bun run build:renderer`)
plus a re-run of the matrix cell that failed.

Skip gates (justified):

- `bun run --cwd packages/film-lab-core test` — no TS source touched.
- `bun run build:core` — no TS source touched.
- `bun run verify:macos` / `bun run verify:ios` — no native source
  touched.

## Done Conditions

- Identity at `detailSoftness = 0.00` confirmed on all four renderers
  for at least one representative source class.
- `detailSoftness = 0.18` and `0.30` judged on each of the seven
  source classes across at least the two production renderers
  (macOS native + iOS export); WebGPU + WebGL spot-checked on the
  cells the web product surface actually serves.
- Cross-renderer convergence noted: where native + iOS bias produces
  a visibly different look from WebGPU / WebGL at the same
  `detailSoftness`, that's logged as expected behavior (web has no
  bias channel) rather than a defect.
- If any defect is found, it is documented (source class + renderer +
  `detailSoftness` setting + observed artifact) and either patched
  in a separate active.md or filed as a known-issue follow-up.
- Active archived to
  `archive/2026-05-12-phase-5-visual-tuning-matrix.md` and a 1–3 line
  completion note appended to `strategy.md` (e.g. "Phase 5 closed —
  no defects" or "Phase 5 closed — N defects patched at commits ...").

## Stop Conditions

- A renderer fails identity at `detailSoftness = 0.00` → stop the
  matrix and treat it as a Phase-5-blocking bug; open a Phase 5
  follow-up active.md scoped to that renderer.
- A defect is found that cannot be scoped to a single failing
  surface (e.g. it requires reworking the shared uniform math, which
  would change behavior on all four renderers at once) → pause and
  escalate before patching, do not silently re-tune the shared math
  inside this phase.
- The matrix reveals that the Phase 4 resolver bias values are
  systemically wrong for a source class → open a Phase 4-C resolver
  re-tune active.md rather than patching inside Phase 5.

## Phase 5-A Diagnostic (2026-05-12 JST) — DO NOT SHIP

iOS on-device QA at `0.18` / `0.30` / `1.0` slider max came back too
subtle on real export. A shared-math tuning attempt
(`effectiveMax 0.45`, `kernelRadiusMax 2.0`, `edgeGuardHi 0.20`,
`chromaAttenScale 0.70`) was visually invisible on text-heavy
magazine footage. A further shared-math push (0.75 / 4.0 / 0.40)
was prepared but rolled back — pushing the shared constants harder
does not prove the slider value is actually reaching the export
kernel.

The right next step is plumbing diagnosis, not stronger shared
tuning. Two structural concerns:

1. `edgeGuard` is designed to protect high-contrast luma edges, so
   text-heavy footage is a worst case for visible delta — pushing
   shared constants may not be the right knob.
2. Even at slider max, paper noise / soft outlines should show a
   visible delta. They don't, so a plumbing bug between slider and
   export kernel is not ruled out.

### State of this commit

- Shared math (`packages/film-lab-core/src/detail-softness.ts` +
  `FilmtoneDetailSoftnessUniforms.swift`) is at the production-
  baseline values (`effectiveMax 0.45`, `kernelRadiusMax 2.0`,
  `edgeGuardHi 0.20`, `chromaAttenScale 0.70`). macOS native,
  WebGPU, and WebGL keep using these.
- The iOS export `GradeRenderPipeline.applyDetailSoftnessStage`
  **overrides the shared uniforms** with intentionally extreme
  values for diagnostic purposes only. Live preview and other
  renderers are unaffected.
- On its first non-zero call per pipeline instance, the iOS path
  emits one `NSLog` line with both the shared and diagnostic
  uniforms (see "Per-session diagnostic log" below).

| Constant            | Shared math (production baseline) | iOS-export diagnostic override |
|---------------------|-----------------------------------|--------------------------------|
| `effectiveMax`      | 0.45                              | **1.0**                        |
| `kernelRadiusMin`   | 0.62                              | 0.62                           |
| `kernelRadiusMax`   | 2.0                               | **6.0**                        |
| `chromaAttenScale`  | 0.70                              | **0.50**                       |
| `edgeGuardLo`       | 0.04                              | 0.04                           |
| `edgeGuardHi`       | 0.20                              | **1.0**                        |
| `highlightBias`     | 1.18                              | 1.18                           |

Identity short-circuit (`effectiveDetailSoftness < 0.0001`) and the
`sourceDetailBias` model are unchanged. With `edgeGuardHi = 1.0`,
edgeGuard hardly attenuates softening even on high-contrast text;
with `kernelRadiusMax = 6.0`, the 4-cardinal-tap localRef samples
±6 px so the detail signal is wider; with `effectiveMax = 1.0`,
slider `1.0` plus any positive `sourceDetailBias` yields full-effect
attenuation.

### Per-session diagnostic log

The iOS override emits one `NSLog` line per `GradeRenderPipeline`
instance on its first non-zero call:

```
[Filmtone][DetailSoftness][Diagnostic 5-A] input detailSoftness=… sourceDetailBias=… | shared effective=… radius=… edgeGuardHi=… chromaAttenScale=… | diagnostic effective=… radius=… edgeGuardHi=… chromaAttenScale=…
```

Confirms (a) the slider value arrives in `params.detailSoftness`,
(b) `sourceDetailBias` arrives non-zero where expected, (c) the
diagnostic uniforms used by the kernel match the override above.

### Plumbing-test pass / fail

- **Pass (max obviously softer than zero on iOS export, and log
  shows non-zero `detailSoftness`)** → plumbing confirmed
  end-to-end. Revert the iOS diagnostic override + this section,
  then re-tune **shared math** for production. The likely surgery
  is on `edgeGuardHi` (let softening reach text edges) more than
  on `effectiveMax` or `kernelRadiusMax`.
- **Fail, log shows non-zero `detailSoftness` but no visible
  effect** → kernel is running but not changing output enough,
  even at max effective. Check `OpticalKernels.detailSoftness`
  argument order, sampler colorspace, and whether a downstream
  stage (creative LUT, vignette, print stage) composites the
  softened output away.
- **Fail, log shows `detailSoftness = 0` even though slider is at
  `1.0`** → params not reaching the export call site. Check the
  Phase0 export request path: `FilmtoneExportSession` build of
  `Phase0ParamsDTO`, the slider → params binding in the iOS UI,
  and Look-vs-override resolution.
- **Fail, log line never appears** → `applyDetailSoftnessStage` is
  not being called on the export pipeline at all. Check
  `FilmtoneExportSession.applyGrade` and any build-flag gating.

Phase 5 closeout is **blocked** until max-vs-zero is distinguishable
on real export and the iOS diagnostic override is reverted.

## Copy / History Impact

Marker (required for `bun run check:filmtone-context`):

> `No copy/history impact: visual QA pass only. No UI string, App
> Store page, release note, fastlane lane, or messages/{en,ja}.json
> row is touched in this phase. Article / release-note copy travels
> in a follow-up lane once the matrix results are in.`

## Article / Change-History Opportunity

- **Article opportunity**: yes, once the matrix has been run.
  Detail Softness with automatic source bias on iPhone / DJI / GoPro
  footage is a release-note-worthy story, but the copy is deferred
  until the matrix confirms the bias is visible on real footage and
  not over-tuned.
- **Change-history opportunity**: yes, alongside the eventual Phase 5
  closeout. The five-phase arc (Contract → Render → UI → Source
  Compensation → Visual Tuning Matrix) is a coherent change-history
  entry.

## Checklist

- [x] Phase 4-B archived; `strategy.md` Phase 4-B row Complete with
      commit pointer `52d38328`; Phase 5 row opened In progress.
- [ ] Identity at `effectiveDetailSoftness == 0` confirmed on macOS
      native.
- [ ] Identity at `effectiveDetailSoftness == 0` confirmed on iOS
      export.
- [ ] Identity at `effectiveDetailSoftness == 0` confirmed on WebGPU.
- [ ] Identity at `effectiveDetailSoftness == 0` confirmed on WebGL.
- [ ] `detailSoftness = 0.18` / `0.30` judged on iPhone SDR / HEVC.
- [ ] `detailSoftness = 0.18` / `0.30` judged on iPhone Apple Log /
      ProRes.
- [ ] `detailSoftness = 0.18` / `0.30` judged on DJI / GoPro Rec.709.
- [ ] `detailSoftness = 0.18` / `0.30` judged on Sony / Canon /
      Panasonic Log.
- [ ] `detailSoftness = 0.18` / `0.30` judged on low-light noisy
      clips.
- [ ] `detailSoftness = 0.18` / `0.30` judged on hair / foliage /
      brick / text.
- [ ] `detailSoftness = 0.18` / `0.30` judged on strong practical
      lights.
- [ ] Cross-renderer convergence noted (or divergence logged as
      expected).
- [ ] Defects (if any) documented with source class + renderer +
      setting + artifact.
- [ ] Defects (if any) patched in scoped follow-up commits, not
      bundled into this active.
- [ ] `bun run check:filmtone-context` PASS.
- [ ] `git diff --check` clean.
- [ ] Archive `active.md` →
      `archive/2026-05-12-phase-5-visual-tuning-matrix.md` and append
      a 1–3 line completion note to `strategy.md`. (Owner-run after
      the matrix is complete.)

## Read-only references

- Phase 4-B archive:
  `archive/2026-05-12-phase-4b-source-compensation-native-wiring.md`.
- Phase 4-A archive:
  `archive/2026-05-12-phase-4-source-compensation-resolver.md`.
- Phase 3 archive: `archive/2026-05-12-phase-3-ui-exposure.md`.
- Phase 2 archive: `archive/2026-05-12-phase-2-renderer-parity.md`.
- TS resolver: `packages/film-lab-core/src/source-detail-compensation.ts`.
- Swift resolver mirror:
  `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneSourceDetailCompensation.swift`.
- Shared uniform math:
  `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`.
- macOS render entry point:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`.
- iOS render entry point:
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`.
- Web render entry points:
  `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`,
  `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`.
