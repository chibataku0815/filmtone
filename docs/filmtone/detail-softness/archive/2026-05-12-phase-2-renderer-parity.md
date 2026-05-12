# Phase 2-B/2-C/2-D: Renderer Detail Softness Parity

Date opened: 2026-05-12 JST
Phase: 2 of 5 (sub-stages 2-B/2-C/2-D; see `strategy.md` and
`archive/2026-05-12-phase-2a-research-charter.md`)

## Gating

**Phase 1 commit landed separately before Phase 2-B render source.**
`feature/detail-softness-contract` HEAD includes `033a335f`
(`feat(detail-softness): add neutral contract plumbing`), which commits the
Phase 1 contract plumbing and lane docs without render prototype code. Phase
2-B render changes may start from this commit and must land in a later commit.

This `active.md` now tracks the Phase 2 renderer-parity unit. The native
macOS pilot and iOS export port are already committed; the current remaining
core work is WebGPU + WebGL parity in one coherent implementation pass.

## Owner-confirmed decisions (2026-05-12)

- **Algorithm**: local-reference high-pass attenuation skeleton from the
  Phase 2-A archive §Algorithm decision. No bilateral / domain-transform
  spike unless the macOS pilot fails edge/skin quality at `0.18` or `0.30`.
- **Pilot renderer**: macOS native first (fastest CIKernel/Metal iter cycle,
  single-function pipeline, mechanical port target for iOS export in 2-C).
- **Branch posture**: Phase 1 commits separately before any Phase 2-B render
  source change.
- **`effectiveMax`**: hard-coded `0.34` for Phase 2 (revisit Phase 3 when UI
  control lands).
- **Working colorspace**: verify during prototype; failure adjusts luma
  weights, not the algorithm shape.
- **Intermediate visual A/B**: owner moved it to final QA. Do not block
  renderer progress on intermediate A/B checkpoints.
- **iOS granularity**: Phase 2-C is part of the native renderer pass, not a
  standalone iOS lane. Do not open a separate iOS active or hold Web parity
  on iOS-only QA unless new iOS source is touched.

## Goal

Implement the Detail Softness render pass across native macOS, iOS export,
WebGPU, and WebGL renderers. WebGPU + WebGL land together as Phase 2-D so the
web product surface does not sit in a half-parity state. Validate:

1. `effectiveDetailSoftness == 0` is bitwise neutral (identity-at-0).
2. `effectiveDetailSoftness ∈ {0.18, 0.30}` produces visible softening
   without obvious skin waxiness, smeared hair / foliage, or unreadable text
   in final visual QA.
3. The Phase 2-A skeleton is the right shape; if it fails edge / skin
   quality on the pilot still set, halt and reopen algorithm review per
   owner's "spike if pilot fails" clause.
4. Working colorspace at the insertion point uses Rec.709 luma weights as
   assumed in 2-A. Verify and document; adjust luma weights if not.

## Edit Targets

### Shared derivation helper — `packages/film-lab-core/`

- **New** `packages/film-lab-core/src/detail-softness.ts` exporting:
  - `DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34` constant.
  - `DetailSoftnessUniforms` type matching the WGSL/Metal layout proposed
    in Phase 2-A:
    `{ effectiveDetailSoftness, kernelRadiusPx, chromaAttenScale, edgeGuardLo, edgeGuardHi, highlightBias }`.
  - `deriveDetailSoftnessUniforms(detailSoftness: number, opts?: { sourceDetailBias?: number }): DetailSoftnessUniforms`
    — pure function consumed by every renderer in 2-B…2-D so derived units
    do not diverge.
- **New** `packages/film-lab-core/src/detail-softness.test.ts` covering:
  - `detailSoftness === 0` ⇒ `effectiveDetailSoftness === 0`.
  - Clamp to `[0, 0.34]` at both boundaries (`-0.1` → `0`, `0.5` → `0.34`).
  - `sourceDetailBias` defaults to `0` in Phase 2; when provided, sum is
    re-clamped to `[0, 0.34]`.
  - Derived `kernelRadiusPx` lies in `[0.55, 1.45]` and increases
    monotonically with `effectiveDetailSoftness`.
- Re-export from `packages/film-lab-core/src/index.ts`.

### macOS native pipeline — `apps/filmtone-desktop-macos/`

- `FilmtoneDesktop/Color/FilmtoneGradeKernels.swift` — add
  `detailSoftnessKernel` following whichever pattern the surrounding optical
  kernels use (CIKernel string vs Metal-backed `CIColorKernel`). Implements
  the Phase 2-A skeleton: local-reference 3x3..5x5 sample, edge guard via
  local `|∇L|`, separated luma vs chroma attenuation, highlight bias.
  Identity short-circuit when `effectiveDetailSoftness == 0`.
- `FilmtoneDesktop/Color/FilmtoneGradePipeline.swift` — add
  `applyDetailSoftnessStage(to:params:)` and insert between
  `filmCompressionV2` (current L66) and `edgeOptics` (current L68) in the
  `apply(...)` orchestrator. Uniforms derived from a Swift mirror of
  `deriveDetailSoftnessUniforms` to keep TS / Swift in lockstep.
- Swift mirror lives in `FilmtonePhase0Math.swift` alongside `clampParam(...)`
  so the iOS export port in 2-C reuses it. Constants (`effectiveMax`, kernel
  radius range, edge-guard thresholds, highlight bias) must match
  `detail-softness.ts` byte-for-byte.

### iOS export granularity — `apps/capacitor-film-lab-ios/`

- Phase 2-C iOS export implementation is treated as complete within the
  native renderer unit. The pass is in the export pipeline after tone
  compression and before edge optics.
- For the current Web renderer work, do not create a separate iOS task,
  commit, or manual A/B checkpoint. iOS participates in final visual QA with
  the other renderers after parity is wired.
- If a follow-up touches iOS source again, prove that surface with
  `bun run verify:ios` plus `git diff --check`; do not expand into screenshot
  capture, App Store, release, or device-export QA unless the touched product
  surface requires it.
- Future iOS-only Detail Softness work should split by product surface:
  export render pass, editor/preview UI exposure, capture/source metadata,
  or release/copy. Do not split by tiny file mechanics such as pbxproj,
  fixtures, or helper placement unless that is the whole failure.

### Working colorspace verification (read-only check)

- Read `FilmtoneGradePipeline.swift` upstream of the insertion point to
  confirm the working colorspace at that point. Expected: linearised
  Rec.709 primaries (`(0.2126, 0.7152, 0.0722)` luma weights). If Display P3
  or BT.2020 primaries are in play, adjust luma weights and document under
  Completion Log.

### Web renderer parity — `packages/film-lab-renderer/`

- WebGPU and WebGL are in scope for this active task as Phase 2-D.
- Insert the pass after graded / tone-compressed color and before the
  bloom / halation / diffusion / optics source reads.
- Use `deriveDetailSoftnessUniforms(...)` from `film-lab-core`; do not fork
  the constants or range math into renderer-local values.
- Keep `detailSoftness == 0` structurally neutral by short-circuiting the
  extra pass before shader dispatch / draw whenever possible.
- Land WebGPU + WebGL together with tracked
  `packages/film-lab-renderer/dist/` rebuild output.

### Out of scope until final QA / later phases

- Final curated still-set A/B. It runs after all renderers are wired.
- Cross-renderer visual tuning matrix.
- Phase 4 source-bias resolver, Phase 3 UI exposure, Phase 5 tuning.
- `AdvancedAdjustCatalog.swift` Veil intensity max-merge decision (deferred
  from Phase 1; revisit when iOS port lands or when UI exposure starts).

## Verification

During the Web renderer implementation unit, run only the gates that prove the
changed surface:

```bash
bun run build:renderer
git diff --check
```

If iOS source changes again during this active, use the iOS proof gate only:

```bash
bun run verify:ios
git diff --check
```

Before archiving the full Phase 2 renderer-parity active task, run the closure
gates below unless no affected surface changed since the last recorded pass:

```bash
bun run build:core
bun run --cwd packages/film-lab-core test    # new detail-softness.test.ts passes; baseline-waived ios-swift-payload failures unchanged
bun run build:smart-look                     # .d.ts re-export check
bun run verify:macos                         # macOS pipeline compiles
bun run verify:ios                           # iOS export pipeline compiles
swift test --package-path packages/film-lab-swift-core   # contract tests still green
bun run check:filmtone-context               # this active.md declares Copy / History Impact below
git diff --check
```

### Visual A/B (manual, recorded in Completion Log)

Use the standard A/B still set listed in plan §Visual Tuning Reference:

- 1 skin close-up (Rec.709 / iPhone SDR).
- 1 hair / foliage edge.
- 1 text / signage.
- 1 highlight rim (sun edge, lamp practical).

| `detailSoftness` | Expectation |
|---|---|
| `0.00` | Bitwise identical to current build. Screenshot diff against pre-Phase-2-B baseline is 0. |
| `0.18` | Visible softening on skin + foliage. Text readable. Highlight rims preserved. |
| `0.30` | Stronger softening. Still no waxy skin / unreadable text. |
| `> 0.34` | Clipped to `0.34` (effectiveMax). |

## Done Conditions

- Shared `deriveDetailSoftnessUniforms` helper exists in `film-lab-core`,
  is unit-tested, and is re-exported from the package entrypoint.
- Swift mirror of the derivation lives in `FilmtonePhase0Math.swift`;
  constants byte-match the TS helper.
- macOS native pipeline carries `applyDetailSoftnessStage` between
  `filmCompressionV2` and `edgeOptics`.
- Native macOS + iOS export pipelines carry the pass after tone compression
  and before edge optics / glow.
- WebGPU + WebGL carry the pass after graded / tone-compressed color and
  before bloom / halation / diffusion / optics source reads.
- Final visual QA still checks identity at `0` and visible softening at
  `0.18` / `0.30` without obvious skin waxiness, smeared hair, or unreadable
  text.
- Working colorspace verified at insertion point; luma weights confirmed or
  adjusted with the change documented under Completion Log.
- Web implementation-unit gates pass: `bun run build:renderer` and
  `git diff --check`.
- Closure gates pass before archive; baseline-waived
  `ios-swift-payload.test.ts` failures remain unchanged.
- Completion Log lists the algorithm-shape verdict (skeleton holds, or
  needs spike) and the colorspace verdict.

## Copy / History Impact

No copy / history impact: Phase 2-B/2-C/2-D is an internal render pass + a
shared derivation helper. No user-visible label, help text, App Store
metadata, or implementation-history claim changes — UI exposure lands in
Phase 3.
`bun run check:filmtone-context` must pass on this declaration.

## Stop Conditions

- Phase 2 render source is about to start from a HEAD before `033a335f`.
  Halt and rebase / switch to the committed Phase 1 base first.
- Identity short-circuit is removed or bypassed in any renderer.
- Final visual QA shows macroscopic skin waxiness or smeared hair at `0.18`.
  Reopen algorithm review per owner's "spike if pilot fails" clause.
- Working colorspace at insertion point is not Rec.709 (Display P3 or
  BT.2020). Pause to adjust luma weights; document under Completion Log.
- A renderer requires broad architecture changes outside the local detail
  softness insertion path. Pause and bring back the narrowest refactor option
  before continuing.

## Checklist

- [x] **(Precondition)** Phase 1 commit landed on
      `feature/detail-softness-contract` at `033a335f`.
- [x] `packages/film-lab-core/src/detail-softness.ts` added with helper +
      `DetailSoftnessUniforms` type + `DETAIL_SOFTNESS_EFFECTIVE_MAX`
      constant.
- [x] `packages/film-lab-core/src/detail-softness.test.ts` added covering
      identity, clamps, monotonicity, bias.
- [x] `packages/film-lab-core/src/index.ts` re-exports the helper, type,
      and constant.
- [x] Swift mirror in `FilmLabSwiftCore` matches the TS derivation; constants
      in lockstep.
- [x] `FilmtoneGradeKernels.swift` `detailSoftnessKernel` added with
      identity short-circuit at `effectiveDetailSoftness == 0`.
- [x] `FilmtoneGradePipeline.swift` `applyDetailSoftnessStage` inserted
      between `filmCompressionV2` and `edgeOptics`.
- [x] iOS export `GradeRenderPipeline` + `OpticalKernels` carry the same
      detail softness pass after tone compression and before edge optics.
- [x] Working colorspace at insertion point verified; luma weights
      confirmed (or adjusted with rationale).
- [x] WebGPU detail softness pass inserted after graded / tone-compressed
      color and before bloom / halation / diffusion / optics reads.
- [x] WebGL detail softness pass inserted at the same semantic point as
      WebGPU.
- [x] `packages/film-lab-renderer/dist/` rebuilt and included with the Web
      renderer source changes.
- [ ] Final visual QA confirms identity-at-0 and visible softening at
      `0.18` / `0.30` without quality regressions.
- [x] Web implementation-unit gates green (`bun run build:renderer`,
      `git diff --check`).
- [ ] Closure verify commands green before archive (build:core /
      film-lab-core test / build:smart-look / verify:macos / verify:ios /
      swift test / check:filmtone-context / git diff --check).
- [ ] `active.md` archived to
      `archive/2026-05-12-phase-2-renderer-parity.md`;
      `strategy.md` gets a 1–3 line completion note.

## Read-only references

- Phase 2-A archive: `archive/2026-05-12-phase-2a-research-charter.md`
  (algorithm skeleton, insertion-point survey, uniform contract).
- Plan: `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`.
- Phase 1 archive: `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`.
- `strategy.md` (this lane).

## Implementation Log

### 2026-05-12 JST — macOS implementation landed

Source landed on `feature/detail-softness-contract` after the Phase 1
commit `033a335f`.

**Files added / changed**

- `packages/film-lab-core/src/detail-softness.ts` — shared derivation
  helper, uniforms type, `DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34` constant.
- `packages/film-lab-core/src/detail-softness.test.ts` — 8 tests covering
  identity, clamps, default bias, summed bias re-clamp, monotonic kernel
  radius, parity constants.
- `packages/film-lab-core/src/index.ts` — re-exports helper, type,
  constant.
- `packages/film-lab-core/dist/*` — rebuilt.
- `packages/film-lab-smart-look/dist/*` — rebuilt (its `.d.ts` re-exports
  the widened core surface).
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`
  — Swift mirror lives in the **shared** Swift package (`FilmLabSwiftCore`)
  rather than the iOS-app-only `FilmtonePhase0Math.swift` proposed in the
  Edit Targets section: only the shared package is reachable from both
  the macOS pilot (this sub-stage) and the iOS export port (Phase 2-C).
- `packages/film-lab-swift-core/Tests/FilmLabSwiftCoreTests/DetailSoftnessUniformsTests.swift`
  — 7 tests mirroring the TS suite, locking parity constants.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
  — `detailSoftness` CIKernel (CI Kernel Language, working color space =
  linear sRGB / Rec.709). Identity short-circuit at
  `effectiveDetailSoftness < 1e-4`.
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
  — `applyDetailSoftnessStage` inserted between `filmCompressionV2` and
  `applyEdgeOpticsStage` in `apply(...)`. Caller short-circuit before
  kernel apply means non-`detailSoftness` renders never construct the
  CIImage for the new stage.

**Working colorspace verdict**

`FilmtoneCIContext.swift` pins working color space to
`CGColorSpace.linearSRGB` (linear sRGB = Rec.709 primaries). Rec.709 luma
weights `(0.2126, 0.7152, 0.0722)` used in the Phase 2-A skeleton apply
directly at the insertion point. **No luma-weight adjustment needed.**

**Verification gates run**

| Gate | Result |
|---|---|
| `bun run --cwd packages/film-lab-core test` | 207 pass / 2 fail. **The 2 failures are the same baseline-waived `ios-swift-payload.test.ts` failures from Phase 1, unchanged.** All 8 new `detail-softness.test.ts` tests pass. |
| `bun run build:core` | OK. |
| `bun run build:smart-look` | OK; `.d.ts` widened to re-export the helper / type / constant. |
| `swift test --package-path packages/film-lab-swift-core` | 44 / 44 pass (37 baseline + 7 new `DetailSoftnessUniformsTests`). |
| `bun run verify:macos` | **BUILD SUCCEEDED**. |
| `bun run verify:ios` | PASS after iOS export port. |
| `bun run check:filmtone-context` | PASS — this Implementation Log carries the Copy / History Impact marker for the new source files. |
| `git diff --check` | Clean. |

### 2026-05-12 JST — owner moved visual A/B to final QA; iOS port continued

Owner direction: do not block core renderer progress on the intermediate
macOS-only A/B gate. The final visual QA pass still checks identity at
`0.00` and visible softening at `0.18` / `0.30`, but native iOS export port
continues now.

**iOS export port**

- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  — added the same `detailSoftness` CIKernel skeleton as macOS.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  — added `applyDetailSoftnessStage(to:params:)`, deriving uniforms from
  `FilmLabSwiftCore.FilmtoneDetailSoftness`.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  — inserted the pass after `applyToneCompressionStage` and before
  `OpticsCompositor.applyEdgeOpticsStage`.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMetrics.swift`
  — added a `DetailSoftness` render substage so export profiling keeps the
  new native pass visible.

**Final owner action — visual A/B**

The Visual A/B procedure in §Verification is deferred to final QA because it
requires curated still exports through the native apps. Owner runs the
4-image set at `detailSoftness ∈ {0.00, 0.18, 0.30}` and reports back:

- Identity at `0.00` — screenshot diff vs pre-Phase-2-B baseline must be 0.
- Visible softening at `0.18` / `0.30` without obvious skin waxiness,
  smeared hair / foliage, or unreadable text on the standard still set.

If the algorithm shape holds, this renderer-parity task archives after
automated gates and final QA.
If final quality fails, reopen algorithm review per Phase 2-A's
"spike if pilot fails" clause.

### 2026-05-12 JST — web renderer port (Phase 2-D)

Owner direction: continue core product progress; ship the WebGL + WebGPU
detail-softness pass without intermediate visual A/B. Final QA covers both
native and web paths together.

**Files added / changed**

- `packages/film-lab-renderer/src/webgl/shaders/detail-softness.frag.ts` —
  GLSL3 fragment shader mirroring the macOS / iOS CIKernel. Shader-side
  short-circuit at `uEffectiveDetailSoftness < 0.0001` (`return center;`).
  Luma weights `(0.2126, 0.7152, 0.0722)` confirmed for the WebGL working
  space at this insertion point (post tone compression, pre optical inputs).
- `packages/film-lab-renderer/src/webgpu/shaders/detail-softness.frag.wgsl.ts`
  — WGSL counterpart with the same algorithm, packed uniform layout
  `(p0 = (effective, kernelRadiusPx, chromaAttenScale, edgeGuardLo),
   p1 = (edgeGuardHi, highlightBias, 1/width, 1/height))`. Same identity
  short-circuit at `effective < 0.0001`.
- `packages/film-lab-renderer/src/webgpu/shaders/index.ts` — re-export
  `detailSoftnessFragmentWgsl`.
- `packages/film-lab-renderer/src/index.ts` — re-export
  `detailSoftnessFragmentShader` (WebGL).
- `packages/film-lab-renderer/src/webgpu.ts` — re-export
  `detailSoftnessFragmentWgsl` from the WebGPU sub-entry so the WebGL-only
  `apps/web` bundle still tree-shakes it out.
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts` — added
  `rtDetailSoftened` render target + `detailSoftnessMaterial`, plus a new
  `renderDetailSoftness` step that runs once per frame after the color-graded
  pass and only when `effectiveDetailSoftness > 0.0001` (caller short-circuit
  on top of the shader guard). All downstream optical inputs
  (`compositeMaterial.uSource`, bloom prefilter, halation prefilter, mist /
  diffusion downsample) now read from a shared `opticalSourceTexture()`
  helper that picks `rtDetailSoftened.texture` when active and falls back to
  `rtColorGraded.texture` otherwise — guaranteeing identity at `0`.
  `setParams` widens to accept `params.detailSoftness`, dispose path now
  releases the new RT + material.
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts` — added a
  pooled `rt.detailSoftened` target, a 32-byte `detailSoftnessBuffer`
  uniform, a `detailSoftness` pipeline (shares `pyramidPipelineLayout` /
  group-0 `offscreenFlagsBindGroup` with other full-res passes), and a
  one-pass render block guarded by `effectiveDetailSoftness > 0.0001`. The
  resulting `opticalSourceView` replaces every prior `colorGradedView`
  reference feeding bloom / halation / mist depth prefilters and the
  composite pass, so the depth-glow and non-depth-glow branches share the
  detail-softened source. `detailSoftness` flows through the existing
  dynamic `frameState.params` map — no extra setter wiring needed.
- `packages/film-lab-renderer/dist/*` — rebuilt (`bun run build:renderer`).

**Working colorspace verdict — web**

Both backends consume the working color-graded RT (`rgba16float` on WebGPU,
shared `RT_OPTIONS` color RT on WebGL) which is the same linear /
Rec.709-primaries surface fed to bloom / halation prefilters. The same
`(0.2126, 0.7152, 0.0722)` luma weights used for native therefore apply
unchanged. **No luma-weight adjustment needed.**

**Identity-at-0 guarantee**

Three independent short-circuits:

1. `deriveDetailSoftnessUniforms` clamps `detailSoftness` to `[0, 0.34]`.
2. Backend callers (WebGL `renderDetailSoftness`, WebGPU branch in
   `renderFrame`) skip the entire pass when
   `effectiveDetailSoftness < 0.0001`. The downstream optical inputs
   continue reading from `rtColorGraded` unchanged.
3. The shader guards the same threshold and returns the center sample
   bitwise-unchanged, in case a host bypasses the caller guard.

**Verification gates run**

| Gate | Result |
|---|---|
| `bun run build:core` | OK. |
| `bun run --cwd packages/film-lab-core test` | 207 pass / 2 fail. The 2 failures are the same baseline-waived `ios-swift-payload.test.ts::CONTRACT_DEFAULT_KEY_ORDER` failures from `main @ 95f1be03` (14 missing `haloPrism*` / `optical*` keys), unchanged by this lane. |
| `bun run build:smart-look` | OK. |
| `bun run build:renderer` | OK. |
| `bunx tsc -p packages/film-lab-renderer/tsconfig.json --noEmit` | Clean for renderer source. Two unrelated `bun:test` resolution errors on `motionBlurMath.test.ts` / `rayAngleOptics.test.ts` are pre-existing (Bun-only test files compiled by tsc). |
| `bun run check:filmtone-context` | PASS — impact marker found in `docs/filmtone/detail-softness/active.md`. |
| `git diff --check` | Clean. |

## Copy / History Impact (restated for Implementation Log)

No copy / history impact: Phases 2-B / 2-C / 2-D are internal render passes
plus a shared derivation helper. No user-visible label, help text, App
Store metadata, or implementation-history claim changes — UI exposure
lands in Phase 3.
`bun run check:filmtone-context` must pass on this declaration.
