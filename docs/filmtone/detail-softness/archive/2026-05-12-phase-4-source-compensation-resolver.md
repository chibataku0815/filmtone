# Phase 4: Detail Softness Source Compensation

Date opened: 2026-05-12 JST
Phase: 4 of 5 (see `strategy.md`; Phase 3 archived at
`archive/2026-05-12-phase-3-ui-exposure.md`).

## Gating

Phase 3 UI exposure is committed on `feature/detail-softness-contract`
at `27a856fa`. Final visual A/B across native + web is rolled into
Phase 5 / final QA per owner direction and is **not** a Phase 4
precondition.

## Goal

Add a conservative metadata-driven source-detail compensation resolver
that produces a recommended `sourceDetailBias`, without baking that
automatic bias into saved Looks. Effective render softness remains:

```
clamp(user detailSoftness + sourceDetailBias, 0, DETAIL_SOFTNESS_EFFECTIVE_MAX)
```

User-authored `detailSoftness` stays the saved creative intent
(`FilmtonePhase0ParamsPatch.opticsGlowKeys`). The automatic
`sourceDetailBias` is **session/source-derived**, not patched into
saved Look identity, and not exposed as a user control.

## Scope decision

This slice ships the **resolver + unit tests in
`packages/film-lab-core/`** only. Render-site plumbing is a follow-up.

Rationale: callsite survey on `feature/detail-softness-contract`:

- macOS `FilmtoneGradePipeline.apply(...)` does not forward source
  profile / log transfer to `applyDetailSoftnessStage(to:params:)`.
  `FilmtoneVideoExporterRenderContext` holds `resolvedProfile:
  CameraProfileCatalogEntry?` and `cameraOptics: CameraOpticsDTO?`,
  but the stage signature only sees `params`.
- iOS `GradeRenderPipeline.applyDetailSoftnessStage(to:params:)` does
  not receive `Phase0ExportRequest.sourceProbe` either.
- Web `WebGPUBackend` / `WebGLBackend` consume `params.detailSoftness`
  directly from the uniform table with no source-metadata channel at
  the backend boundary.

Widening these signatures + building a Swift mirror of the resolver
to keep platform parity is broad metadata plumbing per the owner stop
condition. Phase 4 lands the resolver as the single source of truth
and opens a Phase 4-B follow-up for platform wiring once the resolver
is stable.

## Owner-confirmed constraints

- Range / clamp: `recommendedBias` ≥ 0 and ≤
  `DETAIL_SOFTNESS_EFFECTIVE_MAX` (`0.34`). `deriveDetailSoftnessUniforms`
  already enforces the combined clamp; the resolver returns a
  bias-only number so callers can log it independently.
- Saved-Look isolation: `sourceDetailBias` **must not** become a
  `FilmtonePhase0Params` field or join
  `FilmtonePhase0ParamsPatch.opticsGlowKeys`. It is a session-derived
  uniform input, not stored creative intent.
- No new UI controls for `sourceDetailBias`.
- No recipe changes from Phase 3 (existing optical recipes still do
  not auto-apply `detailSoftness`).
- Unknown metadata defaults to a small or zero bias (see Tuning).

## Tuning (initial conservative recommendations)

Resolver output `recommendedBias` per input class:

| Source class | Bias | Reason |
|---|---|---|
| iPhone SDR / HEVC (consumer) | `0.10` | modest positive; iPhone sensor-acutance + H.265 macroblock edges |
| Apple Log / Apple Log 2 / ProRes (iPhone Pro) | `0.06` | smaller positive; log preserves more roll, less hard sharpness |
| DJI / GoPro / action camera (Rec.709) | `0.08` | positive; high-MP small-sensor with strong in-camera sharpening |
| Sony S-Log3 / Canon C-Log{,3} / Panasonic V-Log | `0.02` | near-zero; cinema-class log curves already gentle on acutance |
| unknown Rec.709 | `0.02` | tiny; could be sensor-sharp consumer source but unsure |
| unknown log transfer | `0.00` | zero; log usually softer, do not bias when uncertain |
| missing metadata | `0.00` | fully conservative passthrough |

`confidence` reflects how directly metadata identified the class:
`high` = make + model + transfer matched; `medium` = transfer or
explicit source-profile-id matched; `low` = single weak signal;
`none` = nothing matched.

## Edit Targets (this slice)

### Core resolver — `packages/film-lab-core/src/`

- **New**: `source-detail-compensation.ts` — exports
  `SourceDetailCompensationInput`,
  `SourceDetailProfile`, and `resolveSourceDetailCompensation(input)`.
  Re-uses existing core types: `SourceLogTransferFunction`,
  `SourceCodecFamily`, `SourceColorClass`, and
  `SourceProfileId` so callsites can plug in metadata that is
  already on the wire.
- **New**: `source-detail-compensation.test.ts` — coverage for every
  row of the Tuning table plus:
  - clamp at `DETAIL_SOFTNESS_EFFECTIVE_MAX` (no row produces
    `recommendedBias > 0.34`);
  - missing-metadata returns `{ recommendedBias: 0, confidence:
    "none" }`;
  - explicit `sourceProfileId === "built-in:source-profile.rec709"`
    behaves like unknown Rec.709 not unknown Log;
  - case-insensitive camera-make matching;
  - `inputTransformPolicy.strategy ∈ { "apple-log-to-rec709",
    "apple-log2-to-rec709" }` is honored even if `cameraMake` is
    nil.
- **Index re-export**: `packages/film-lab-core/src/index.ts` adds
  `resolveSourceDetailCompensation`, `type
  SourceDetailCompensationInput`, `type SourceDetailProfile`,
  `type SourceDetailConfidence`, `type SourceDetailTransferClass`.

### Tracked core dist

If the rebuilt `packages/film-lab-core/dist/index.{js,d.ts}` diff
shows the new symbols, commit the diff alongside source per
project `CLAUDE.md` §6. No `renderer` / `smart-look` dist rebuild
expected — neither package consumes the resolver yet.

### Not touched (this slice, follow-up Phase 4-B)

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneDetailSoftness.swift`
  (Swift mirror would land here)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
- `packages/film-lab-renderer/src/webgpu/WebGPUBackend.ts`
- `packages/film-lab-renderer/src/webgl/WebGLBackend.ts`
- `FilmtonePhase0Params` / `FilmtonePhase0ParamsPatch` (no schema
  change — bias is not a stored param)

## Verification

Smallest gates that prove the touched surfaces:

```bash
bun run build:core
bun run --cwd packages/film-lab-core test
bun run check:filmtone-context
git diff --check
```

Skip gates (this slice):

- `bun run verify:ios` — no iOS source change.
- `bun run verify:macos` — no macOS source change.
- `bun run build:renderer` — no renderer source change.
- `bun run check:filmtone-copy` — no user-visible copy change in
  this slice (resolver output is diagnostic; UI exposure is
  Phase 3-shipped).

## Done Conditions

- `packages/film-lab-core/src/source-detail-compensation.ts` exports
  the resolver and types.
- `source-detail-compensation.test.ts` covers every Tuning row plus
  the four edge cases above; tests pass.
- `bun run --cwd packages/film-lab-core test` passes (baseline-waived
  `ios-swift-payload.test.ts` failures remain, see
  `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`).
- `bun run build:core` emits the new symbols into
  `packages/film-lab-core/dist/index.{js,d.ts}`.
- `bun run check:filmtone-context` passes against the
  `No copy/history impact: resolver shipped without user-visible
  copy change` declaration below.
- `git diff --check` clean.
- Active archived to
  `archive/2026-05-12-phase-4-source-compensation-resolver.md` and a
  1–3 line completion note appended to `strategy.md`.

## Stop Conditions

- The resolver requires `FilmtonePhase0Params` to gain a
  `sourceDetailBias` field. Halt — that would put automatic bias
  into saved Looks (constraint violation).
- A test or generator requires `PHASE0_SCHEMA_VERSION` bump. Halt —
  resolver is non-contract.
- Wiring the resolver into a render callsite requires changing the
  public `Phase0ExportRequest` shape or any persisted JSON
  fixture. Halt and re-evaluate the slice boundary.
- A reasonable signal (camera-make match, transfer match) is missed
  by the resolver — extend tests + tune, do not relax the
  unknown-default-zero rule for log sources.

## Copy / History Impact

No user-visible copy change in this slice. Resolver output is a
diagnostic / future render-bias input; it does not surface in any UI
string, App Store / LP page, release notes, fastlane lane, or
`messages/{en,ja}.json` row. **No history claim moves.**

Marker (required for `bun run check:filmtone-context`):

> `No copy/history impact: resolver shipped without user-visible
> copy change.`

## Article / Change-History Opportunity

- **Article opportunity**: developer-note only (no user-visible
  behaviour change in this slice). A release-note treatment is
  reserved for Phase 4-B when the resolver is wired to a render
  surface and changes pixels for users.
- **Change-history opportunity**: yes. The resolver separates
  user creative intent (`detailSoftness`) from automatic source
  adaptation (`sourceDetailBias`). That separation is worth
  recording in `docs/filmtone/` change history alongside the
  Phase 4-B wiring once it lands.

## Checklist

- [x] Phase 3 active archived; `strategy.md` Phase 3 status set to
      Complete with commit pointer `27a856fa`.
- [x] `source-detail-compensation.ts` resolver + types.
- [x] `source-detail-compensation.test.ts` covering Tuning table +
      edge cases (21 tests).
- [x] `packages/film-lab-core/src/index.ts` re-exports.
- [x] `bun run --cwd packages/film-lab-core test` PASS — 228 pass /
      2 fail; the two failures are the baseline-waived
      `ios-swift-payload.test.ts` rows from Phase 1
      (`hiddenDefaults` length and `CONTRACT_DEFAULT_KEY_ORDER`
      drift). Unchanged by this slice.
- [x] `bun run build:core` rebuilds `dist/` with new symbols
      (`resolveSourceDetailCompensation` + type group present in
      `dist/index.{js,d.ts}`).
- [x] `bun run check:filmtone-context` PASS — impact marker present
      in this active.md.
- [x] `git diff --check` clean.
- [x] Archived to
      `archive/2026-05-12-phase-4-source-compensation-resolver.md`
      after commit `3036e5b9 feat(detail-softness): add source
      compensation resolver` landed. `strategy.md` Phase 4 row
      flipped to Complete with the commit pointer; Phase 4-B
      (native wiring) opened in a new `active.md`.

## Implementation Log

### 2026-05-12 JST — Resolver landed

- Added `packages/film-lab-core/src/source-detail-compensation.ts`
  with `resolveSourceDetailCompensation(input)` + the
  `SourceDetailProfile` / `SourceDetailCompensationInput` /
  `SourceDetailConfidence` / `SourceDetailTransferClass` types.
  Bias values match the Phase 4 Tuning table; clamp is shared with
  `DETAIL_SOFTNESS_EFFECTIVE_MAX`.
- Added 21 unit tests in
  `packages/film-lab-core/src/source-detail-compensation.test.ts`
  covering each Tuning row plus invariants (clamp, case-insensitive
  cameraMake, Apple-Log signal precedence over iPhone-Rec.709,
  `inputTransformPolicy.strategy === "none"` not triggering
  `log-unknown`, missing-metadata → zero).
- Re-exported the resolver and types from
  `packages/film-lab-core/src/index.ts`.
- Rebuilt `packages/film-lab-core/dist/` (additive ESM + d.ts).
- `packages/film-lab-smart-look/dist/` and
  `packages/film-lab-renderer/dist/` were inspected and contain
  no references to the new symbols, so they are not rebuilt
  this slice.

**Verification gates run**

| Gate | Result |
|---|---|
| `bun run --cwd packages/film-lab-core test` | 228 pass / 2 baseline-waived fail (Phase 1 known drift). |
| `bun test packages/film-lab-core/src/source-detail-compensation.test.ts` | 21 / 21 pass. |
| `bun run build:core` | ESM + DTS rebuilt; resolver + types present in `dist/index.{js,d.ts}`. |
| `bun run check:filmtone-context` | PASS (impact marker in this active.md). |
| `git diff --check` | Clean. |

Skip gates (justified above): `bun run verify:ios`,
`bun run verify:macos`, `bun run build:renderer`,
`bun run check:filmtone-copy`.

## Read-only references

- Phase 1 archive:
  `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`.
- Phase 2 archive: `archive/2026-05-12-phase-2-renderer-parity.md`.
- Phase 3 archive: `archive/2026-05-12-phase-3-ui-exposure.md`.
- Source plan:
  `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`.
- Existing core types reused as resolver inputs:
  - `SourceLogTransferFunction`, `SourceCodecFamily`,
    `SourceColorClass`, `SourceInputTransformPolicy` —
    `packages/film-lab-core/src/native-bridge.ts`.
  - `SourceProfileId`, `SOURCE_PROFILE_CATALOG` —
    `packages/film-lab-core/src/source-profile-conversion.ts`.
- Render integration target (Phase 4-B, not this slice):
  `packages/film-lab-core/src/detail-softness.ts`
  `deriveDetailSoftnessUniforms(..., { sourceDetailBias })`.
