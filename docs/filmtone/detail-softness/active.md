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

## Phase 5-B Algorithm Replacement (2026-05-12 JST)

The Phase 5-A diagnostic (iOS-export-only `effectiveMax 1.0`,
`kernelRadiusMax 6.0`, `edgeGuardHi 1.0`) confirmed end-to-end
plumbing on real device export: slider → `params.detailSoftness` →
`applyDetailSoftnessStage` → `OpticalKernels.detailSoftness` is
intact. The bug is in the algorithm, not the wiring.

The original 4-cardinal-tap local-mean attenuation behaved as a
low-pass blur at high effective values: text edges softened, the
overall image lost acutance, and the `edgeGuard` smoothstep on a
2-tap luma gradient was both fragile and conservative — so on
text-heavy footage softening was visually invisible, while at
diagnostic values it produced a generic blur look.

Detail Softness is supposed to be **digital acutance relief**
(reduce micro-contrast / sharpening hardness / sensor-noise edges)
rather than defocus. Replaced with an amplitude-gated bilateral
detail-layer:

1. Sample a ring of 8 neighbours (4 cardinal + 4 diagonal) on a
   circle of radius `kernelRadiusPx`. Same-radius diagonals
   ensure isotropic sampling without aspect bias.
2. Weight each tap with a Gaussian over **luma distance**
   (`rangeSigma = 0.07`). Taps on the other side of a step edge
   collapse to ~0 weight, so the local reference stays near the
   center on edges rather than averaging across them.
3. `detail = center − bilateral reference`. The detail layer
   carries micro-contrast / noise / digital sharpening halos —
   the large step itself was excluded by the bilateral weights.
4. **Amplitude gate**: any residual high-amplitude detail (text
   transitions, contour lines, small print) is released and
   passes through unattenuated:
   `gate = 1 − smoothstep(detailAmplitudeLo, detailAmplitudeHi,
   |detailLuma|)`. This is structural edge protection on the
   actual detail signal, not on a 2-tap gradient approximation.
5. Split detail into luma + chroma and apply
   `effective × gate × highlightWeight` (plus `chromaAttenScale`
   on chroma).

### State after this commit

| Constant            | Old (Phase 2-A baseline) | New (Phase 5-B) |
|---------------------|--------------------------|-----------------|
| `effectiveMax`      | 0.34→0.45                | **0.65**        |
| `kernelRadiusMin`   | 0.62                     | **1.0**         |
| `kernelRadiusMax`   | 2.0                      | **2.5**         |
| `rangeSigma`        | n/a                      | **0.07** (new)  |
| `detailAmplitudeLo` | `edgeGuardLo` 0.04       | **0.0** (replaces edge guard) |
| `detailAmplitudeHi` | `edgeGuardHi` 0.2        | **0.05** (replaces edge guard) |
| `chromaAttenScale`  | 0.7                      | 0.7             |
| `highlightBias`     | 1.18                     | 1.18            |

The diagnostic override on `GradeRenderPipeline` is reverted; iOS
export now reads the shared math like the other three renderers.
Identity short-circuit at `effectiveDetailSoftness < 0.0001` is
preserved by both the caller and the kernel.

### Files touched

- `packages/film-lab-core/src/detail-softness.ts` — new uniforms
  (`rangeSigma`, `detailAmplitudeLo/Hi` replacing `edgeGuardLo/Hi`),
  new effective-max / radius range.
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`
  — Swift mirror.
- `packages/film-lab-core/src/detail-softness.test.ts` — parity
  constant assertions, kernel radius endpoints, clamp inputs.
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/DetailSoftnessUniformsTests.swift`
  — Swift mirror of the TS test.
- `packages/film-lab-core/src/detail-softness-frame.test.ts` — **new**.
  Pure-JS port of the kernel applied to a 64×32 synthetic frame.
  Asserts (a) identity at slider 0, (b) noise / micro-detail
  softens at slider max, (c) step-edge amplitude preserved within
  3% — the **non-blur metric**.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  — new CIKernel body (9-sample bilateral + amplitude gate).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  — diagnostic override reverted; new 8-arg kernel call.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
  — new CIKernel body.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
  — new 8-arg kernel call.
- `packages/film-lab-renderer/src/webgl/shaders/detail-softness.frag.ts`
  — new GLSL fragment body.
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts` — new
  uniform names + init / per-frame binding.
- `packages/film-lab-renderer/src/webgpu/shaders/detail-softness.frag.wgsl.ts`
  — new WGSL fragment body, 3 × vec4f uniform layout.
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts` —
  `DETAIL_SOFTNESS_PARAMS_BYTES` 32 → 48, scratch layout rewritten.

### Diagnostic for future tuning

`detail-softness-frame.test.ts` is the on-CI proxy for visual QA: it
holds the "softens noise / preserves step edges" contract as a
numeric assertion. If a tuning pass weakens edge preservation
(blur-like behavior), the step-edge test fails and the pass is
rejected before it ships.

### Re-tuning protocol

Re-run on-device QA at slider `0.0`, `0.18`, `0.3`, `1.0` after
reinstall:

- Slider 0 must remain identity (already enforced).
- Slider 0.18 should be just visible on fine texture (paper, skin).
- Slider 1.0 should be clearly softer in micro-contrast while
  preserving text legibility, hair contour, and brick mortar lines.
- Cross-renderer convergence: macOS + iOS + Web should agree at the
  same slider value (modulo `sourceDetailBias` on native paths).

If 1.0 is *still* too subtle after this rewrite, the next knob is
`detailAmplitudeHi` (raise it to let larger detail through the
gate), then `effectiveMax`. Do not raise `kernelRadiusMax` past ~3.0
without also revisiting `rangeSigma` — wider rings need a slightly
larger sigma to keep the bilateral effective on gentle gradients.

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
