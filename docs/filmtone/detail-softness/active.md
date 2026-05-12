# Phase 4-B: Detail Softness Source Compensation — Native Wiring

Date opened: 2026-05-12 JST
Phase: 4-B of 5 (see `strategy.md`; Phase 4-A archived at
`archive/2026-05-12-phase-4-source-compensation-resolver.md`).

## Gating

Phase 4-A TS resolver is committed on `feature/detail-softness-contract`
at `3036e5b9`. The resolver's bias output is the contract; this slice
wires it into native render/export paths that already see source
metadata at the callsite.

## Goal

Wire the `sourceDetailBias` produced by
`resolveSourceDetailCompensation` into the native macOS preview /
export and iOS export render passes so the existing
`FilmtoneDetailSoftness.deriveUniforms(detailSoftness:sourceDetailBias:)`
parameter is fed at runtime. `sourceDetailBias` stays a runtime-only
input — not a `FilmtonePhase0Params` field, not in
`FilmtonePhase0ParamsPatch.opticsGlowKeys`, not in any persisted
project / Look / export JSON.

Effective render softness remains:

```
clamp(user detailSoftness + sourceDetailBias, 0, DETAIL_SOFTNESS_EFFECTIVE_MAX)
```

## Scope decision

Native wiring only.

- **macOS native + export**: `FilmtoneGradePipeline.apply(...)` already
  takes `cameraOptics: CameraOpticsDTO?`. Add an optional
  `sourceDetailBias: Double = 0` parameter, threaded into
  `applyDetailSoftnessStage` and `FilmtoneDetailSoftness.deriveUniforms`.
  Resolve the bias once per export at `FilmtoneVideoExporter`
  (`VideoFrameRenderContext` build) from `cameraOptics` +
  `resolvedProfile?.id`. Preview / still callsites pass `0` for now
  unless they already have probe metadata.
- **iOS export**: `GradeRenderPipeline.applyDetailSoftnessStage(...)`
  gains an optional `sourceDetailBias: Double = 0` parameter; the
  export session resolves the bias once from `request.sourceProbe`
  (which carries `cameraOptics`, `codecFamily`,
  `logTransferFunction`, `inputTransformPolicy`,
  `sourceVideoMetadata.colorClass`) and passes the value into the
  stage.
- **Web (WebGPU / WebGL) deferred**: the renderer-side `Backend`
  protocol consumes `params.detailSoftness` from the uniform table
  with no source-metadata channel at the backend boundary; widening
  it would be the broad-renderer-redesign stop condition. Skipped
  this slice.

## Owner-confirmed constraints

- `sourceDetailBias` is **runtime-only**.
- No `PHASE0_SCHEMA_VERSION` bump.
- No new persisted project / Look / export JSON fields.
- No UI surface.
- No recipe changes.
- Stage clamp remains `DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34`,
  inherited from the existing
  `FilmtoneDetailSoftness.deriveUniforms` shared math.

## Edit Targets (this slice)

### Swift mirror — `packages/film-lab-swift-core/`

- **New**:
  `Sources/FilmLabSwiftCore/FilmtoneSourceDetailCompensation.swift` —
  exports `FilmtoneSourceDetailCompensation.resolve(...)` that mirrors
  the TS resolver. String-based inputs (`cameraMake`, `cameraModel`,
  `logTransferFunction`, `inputTransformStrategy`, `codecFamily`,
  `colorClass`, `sourceProfileId`) so it can be fed from either iOS
  or macOS DTOs without dragging app-specific types into
  `FilmLabSwiftCore`.
- **New**:
  `Tests/FilmLabSwiftCoreTests/FilmtoneSourceDetailCompensationParityTests.swift`
  — parity with the TS tuning table:
  - iPhone SDR / HEVC → `0.10`
  - Apple Log / ProRes → `0.06` (and Apple-Log signal overrides
    iPhone Rec.709 path when both present)
  - DJI / GoPro → `0.08`
  - Sony / Canon / Panasonic Log → `0.02`
  - unknown Rec.709 → `0.02`
  - unknown Log / `inputTransformStrategy == "core-image-tone-map-sdr"`
    only → `0.00`
  - missing metadata → `0.00`
  - case-insensitive `cameraMake`
  - clamp at `FilmtoneDetailSoftness.effectiveMax`
  - `inputTransformStrategy == "none"` does not trigger
    `log-unknown`

### macOS — `apps/filmtone-desktop-macos/FilmtoneDesktop/`

- **Edit**: `Color/FilmtoneGradePipeline.swift` — add optional
  `sourceDetailBias: Double = 0` to `FilmtoneGradePipeline.apply(...)`
  and `applyDetailSoftnessStage(to:params:sourceDetailBias:)`; thread
  into `FilmtoneDetailSoftness.deriveUniforms`. Default `0` keeps
  existing callers byte-identical.
- **Edit**: `Export/FilmtoneVideoExporter.swift` — resolve the bias
  once when building `VideoFrameRenderContext` (using `cameraOptics`
  + `resolvedProfile?.id`); add `sourceDetailBias: Double` to the
  context struct; forward into `FilmtoneGradePipeline.apply`. Other
  exporter / preview callsites that do not have probe metadata pass
  the `apply(...)` default `0`.

### iOS — `apps/capacitor-film-lab-ios/ios/App/App/Export/`

- **Edit**: `Internal/GradeRenderPipeline.swift` — change
  `applyDetailSoftnessStage(to:params:)` to
  `applyDetailSoftnessStage(to:params:sourceDetailBias:)` with
  default `0`; thread into
  `FilmtoneDetailSoftness.deriveUniforms`.
- **Edit**: `FilmtoneExportSession.swift` — resolve the bias once
  from `request.sourceProbe` at the same place where the export
  session already inspects probe metadata; pass into the detail
  softness stage call.

### Not touched (this slice)

- `FilmtonePhase0Params` / `FilmtonePhase0ParamsPatch` (no schema
  change — bias is not a stored param).
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts` /
  `WebGLBackend.ts` (deferred; metadata channel absent).
- Optical recipes / UI / copy / fastlane lanes / release notes.

## Verification

Smallest gates that prove the touched surfaces:

```bash
swift test --package-path packages/film-lab-swift-core
bun run verify:macos
bun run verify:ios
bun run check:filmtone-context
git diff --check
```

Skip gates (justified above):

- `bun run --cwd packages/film-lab-core test` — TS resolver
  unchanged from `3036e5b9`.
- `bun run build:core` — no TS source touched.
- `bun run build:renderer` — web wiring deferred.
- `bun run check:filmtone-copy` — no user-visible copy change in
  this slice.

## Done Conditions

- `FilmtoneSourceDetailCompensation.resolve(...)` exists in
  `FilmLabSwiftCore` and the parity tests pass.
- macOS `FilmtoneVideoExporter` resolves `sourceDetailBias` from
  `cameraOptics` + `resolvedProfile?.id` and forwards it through
  `FilmtoneGradePipeline.apply` into the detail-softness stage.
- iOS `FilmtoneExportSession` resolves `sourceDetailBias` from
  `request.sourceProbe` and forwards it into
  `gradeRenderPipeline.applyDetailSoftnessStage(...)`.
- `swift test --package-path packages/film-lab-swift-core` green.
- `bun run verify:macos` green.
- `bun run verify:ios` green.
- `bun run check:filmtone-context` PASS.
- `git diff --check` clean.
- Active archived to
  `archive/2026-05-12-phase-4b-source-compensation-native-wiring.md`
  and a 1–3 line completion note appended to `strategy.md`.

## Stop Conditions

- Wiring requires `FilmtonePhase0Params` to gain a `sourceDetailBias`
  field, or a new persisted JSON field anywhere in
  project / Look / export-request payloads.
- Wiring requires a broad renderer signature redesign across all
  platforms (e.g. forcing every shader `Backend.detailSoftness(...)`
  callsite to take a metadata blob).
- Metadata reachable at a callsite is too weak to classify reliably
  — accept the resolver's conservative-zero default and document it,
  do not invent fallback bias values.

## Copy / History Impact

No user-visible copy change in this slice. Render output may change
where source metadata identifies a class with non-zero bias, but the
existing UI strings (`Detail softness`, advanced control help) and
release notes are unchanged. Article / change-history treatment can
travel with the Phase 5 visual matrix landing.

Marker (required for `bun run check:filmtone-context`):

> `No copy/history impact: native wiring forwards an existing
> session-derived bias and does not change any UI string, App Store
> page, release note, fastlane lane, or messages/{en,ja}.json row.`

## Article / Change-History Opportunity

- **Article opportunity**: release-note candidate once the visual
  matrix (Phase 5) confirms the bias is visible on iPhone / DJI /
  GoPro footage. Defer until Phase 5.
- **Change-history opportunity**: yes, alongside Phase 4-A. The
  separation of user creative intent (`detailSoftness`) from
  automatic source adaptation (`sourceDetailBias`) is now expressed
  in real native render paths.

## Checklist

- [x] Phase 4-A active archived; `strategy.md` Phase 4-A row set to
      Complete with commit pointer `3036e5b9`; Phase 4-B row opened
      In progress.
- [x] `FilmtoneSourceDetailCompensation.swift` resolver mirror.
- [x] `FilmtoneSourceDetailCompensationParityTests.swift` covering
      the tuning table + invariants (21 tests).
- [x] `FilmtoneGradePipeline.apply(...)` accepts `sourceDetailBias`;
      `applyDetailSoftnessStage` threads it into
      `deriveUniforms(detailSoftness:sourceDetailBias:)`.
- [x] `FilmtoneVideoExporter` resolves the bias once and forwards
      it through the render context (both `export(...)` and
      `exportHighlightReel(...)` paths); macOS still exporter +
      preview surface + AVVideoComposition preview resolve the bias
      at their own callsites where probe metadata is already in
      scope.
- [x] `GradeRenderPipeline.applyDetailSoftnessStage(...)` accepts
      `sourceDetailBias`.
- [x] `FilmtoneExportSession` resolves the bias once from
      `request.sourceProbe` (stored as `sourceDetailBias`) and
      forwards it into the stage call.
- [x] `swift test --package-path packages/film-lab-swift-core`
      green (64 / 64, including 21 new parity tests).
- [x] `bun run verify:macos` green (`** BUILD SUCCEEDED **`).
- [x] `bun run verify:ios` green (EXIT=0).
- [x] `bun run check:filmtone-context` PASS (impact marker present
      in this active.md).
- [x] `git diff --check` clean.
- [ ] Archive `active.md` →
      `archive/2026-05-12-phase-4b-source-compensation-native-wiring.md`
      after commit lands; append 1–3 line completion note to
      `strategy.md`. (Owner-run after commit
      `feat(detail-softness): wire source detail bias into native
      render` lands.)

## Implementation Log

### 2026-05-12 JST — Native wiring landed

- Added Swift resolver mirror
  `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneSourceDetailCompensation.swift`.
  Inputs are string-typed (`cameraMake`, `cameraModel`,
  `logTransferFunction`, `inputTransformStrategy`, `codecFamily`,
  `colorClass`, `sourceProfileId`) so iOS / macOS DTOs feed in via
  their `rawValue`. Cascade order, bias values, transfer classes,
  and clamp behavior all mirror the TS resolver byte-for-byte.
- Added 21 parity unit tests in
  `Tests/FilmLabSwiftCoreTests/FilmtoneSourceDetailCompensationParityTests.swift`
  covering each Tuning row plus invariants (clamp, case-insensitive
  cameraMake, Apple-Log signal precedence over iPhone-Rec.709,
  `inputTransformStrategy == "none"` not triggering `log-unknown`,
  missing-metadata → zero).
- macOS native pipeline wiring:
  - `FilmtoneGradePipeline.apply(...)` gains optional
    `sourceDetailBias: Double = 0` (default keeps existing callers
    byte-identical); threaded into `applyDetailSoftnessStage` and
    `FilmtoneDetailSoftness.deriveUniforms(detailSoftness:sourceDetailBias:)`.
  - `FilmtoneVideoExporter` adds `sourceDetailBias` to
    `VideoFrameRenderContext`, resolved once per export via a new
    private `resolveSourceDetailBias(cameraOptics:colorClass:resolvedProfile:)`
    helper (consumes `probe.cameraOptics` + `probe.colorClass` +
    `resolvedProfile?.id`).
  - `FilmtoneStillExporter`, `PreviewSurface.renderFrames`, and
    `FilmtoneDesktopVideoComposition.makeComposition` each resolve
    the bias at their own callsites using the metadata already in
    scope.
- iOS export pipeline wiring:
  - `GradeRenderPipeline.applyDetailSoftnessStage(to:params:sourceDetailBias:)`
    gains optional bias arg (default `0`); threads into
    `FilmtoneDetailSoftness.deriveUniforms`.
  - `FilmtoneExportSession` stores `sourceDetailBias` (resolved
    once from `request.sourceProbe`, preferring
    `sourceVideoMetadata.logTransferFunction` /
    `inputTransformPolicy` / `codecFamily` / `colorClass` when the
    nested struct is present, falling back to the top-level probe
    fields) and forwards it on every `applyDetailSoftnessStage`
    call in `applyGrade`.
- No persisted contract change. `FilmtonePhase0Params` /
  `FilmtonePhase0ParamsPatch` / `Phase0ParamsDTO` /
  `Phase0ExportPayload` untouched; `PHASE0_SCHEMA_VERSION` still
  `2`.

**Verification gates run**

| Gate | Result |
|---|---|
| `swift test --package-path packages/film-lab-swift-core` | 64 / 64 pass (21 new parity tests + 43 pre-existing). |
| `bun run verify:macos` | `** BUILD SUCCEEDED **`. |
| `bun run verify:ios` | EXIT=0; generated-Swift drift check, Phase0 contract fixtures, all 12 sub-gates green. |
| `bun run check:filmtone-context` | PASS — impact marker in this active.md + Phase 4-A archive. |
| `git diff --check` | Clean. |

Skip gates (justified above): `bun run --cwd packages/film-lab-core test`,
`bun run build:core`, `bun run build:renderer`,
`bun run check:filmtone-copy`.

## Read-only references

- Phase 4-A archive:
  `archive/2026-05-12-phase-4-source-compensation-resolver.md`.
- TS resolver: `packages/film-lab-core/src/source-detail-compensation.ts`.
- Existing Swift uniforms helper (already accepts
  `sourceDetailBias`):
  `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneDetailSoftnessUniforms.swift`.
- macOS render entry point:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`.
- iOS render entry point:
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`.
- Source-metadata DTOs reused at wiring callsites:
  - macOS: `Color/FilmtoneSourceProfileCatalog.swift`
    (`CameraProfileCatalogEntry.id`), `Domain/CameraOpticsDTO.swift`.
  - iOS: `Source/FilmtoneMediaTypes.swift` (`SourceProbeDTO`,
    `SourceVideoMetadataDTO`, `CameraOpticsDTO`).
