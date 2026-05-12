# Filmtone Detail Softness Strategy

Date opened: 2026-05-12 JST
Last updated: 2026-05-12 JST (Phase 4-A resolver landed at `3036e5b9`; Phase 4-B native wiring opened)

This file is the compact source of truth for the Detail Softness lane.
Implementation logs, chat handoffs, and detailed verification records belong in
`archive/`.

## Goal

Add a filmic softness system, `detailSoftness`, that reduces hard digital fine
detail and local acutance without making footage look simply blurred, distinct
from `lensSoftness` (which is lens / periphery softness). Build it in five
phases, contract first, render later, then UI, then source-aware automatic
compensation, then a visual tuning matrix.

Primary planning document:
`docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md`

The current branch and worktree for this lane is
`feature/detail-softness-contract` at
`/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-detail-softness`,
branched from `main @ 95f1be03` so it never collides with the in-flight
`feature/export-audio-preservation` lane.

## Measurable Done Conditions

- `detailSoftness` exists end-to-end as a shared param with range `0…1` and
  default `0`.
- A `detailSoftness` of `0` is render-path neutral by construction: no
  renderer, shader, uniform table, or visual pass reads the key in Phase 1.
- Existing projects, presets, Looks, and saved patches load and round-trip
  unchanged. No `PHASE0_SCHEMA_VERSION` bump.
- User-authored `detailSoftness` rides along with saved Look identity
  (`FilmtonePhase0ParamsPatch.opticsGlowKeys`); future automatic
  `sourceDetailBias` is kept out of saved Looks.
- A real render pass exists, placed after base grade / tone compression and
  before edge optics / glow / grain, and rejects plain Gaussian blur.
- A user-facing Advanced control exists with copy that survives
  `bun run check:filmtone-copy`.
- Source Detail Compensation provides conservative metadata-driven bias that
  is logged but not baked into saved Looks.
- A visual tuning matrix has been run across the listed source classes
  without obvious blur, waxy skin, smeared hair / foliage, or unreadable text.

## Phases

| ID | Phase | Status | Done Condition |
|---|---|---|---|
| Phase 1 | Contract & Neutral Plumbing | Complete (2026-05-12 JST) | `detailSoftness` plumbed in every contract layer with default `0`; in-scope verify commands green; 2 pre-existing `ios-swift-payload.test.ts` failures explicitly waived as baseline drift unrelated to `detailSoftness`; no render code changes. |
| Phase 2 | Real Render Pass | Complete (2026-05-12 JST) | Local-reference / high-frequency detail reduction with edge guard and luma-vs-chroma weighting, committed across macOS native (`e277e9f3`), iOS export (`eac47d53`), WebGPU + WebGL (`444db1e0`). Final visual A/B deferred to final QA. |
| Phase 3 | UI Exposure & Recipe Decision | Complete (2026-05-12 JST) | iOS + macOS Advanced sliders shipped at commit `27a856fa`; existing recipes left untouched; final visual A/B rolled into Phase 5 / final QA. |
| Phase 4-A | Source Detail Compensation Resolver | Complete (2026-05-12 JST) | TS resolver `resolveSourceDetailCompensation` + 21 unit tests landed at commit `3036e5b9`. Bias never patched into saved Looks; surface stays diagnostic. |
| Phase 4-B | Source Detail Compensation Native Wiring | In progress | Swift resolver mirror + parity tests; macOS `FilmtoneGradePipeline.apply` + iOS `GradeRenderPipeline.applyDetailSoftnessStage` forward a session-derived `sourceDetailBias` into `FilmtoneDetailSoftness.deriveUniforms`. Web renderer wiring deferred until metadata channel exists. |
| Phase 5 | Visual Tuning Matrix | Not started | iPhone SDR HEVC, iPhone Apple Log / ProRes, DJI / action camera Rec.709, Sony / Canon / Panasonic Log, low-light noisy clips, hair / foliage / brick / text, strong practical lights all judged. |

## Current Strategic State

- Phase 1 closed 2026-05-12 JST on `feature/detail-softness-contract` in the
  `filmtone-detail-softness` worktree. `detailSoftness` exists end-to-end as a
  neutral param with default `0`, `PHASE0_SCHEMA_VERSION` unchanged at `2`,
  `paramKeys` widened to 36, `opticsGlowKeys` includes the new key, and the
  stale `apps/capacitor-film-lab-ios/.../FilmtonePhase0Generated.swift` test
  path was repointed to the canonical Swift package emit. Closeout artifact:
  `archive/2026-05-12-phase-1-contract-neutral-plumbing.md`. Phase 2 (real
  render pass) is in progress.
- `feature/export-audio-preservation` runs in a sibling worktree. Phase 1
  must not touch the in-flight export-audio files there.
- `FilmtonePhase0Params` Codable is synthesized; full-param JSON missing
  `detailSoftness` would fail direct decode. Current storage surfaces use
  `FilmtonePhase0ParamsPatch` (dynamic-key, missing-tolerant) and
  project-level custom decoders, so this is acceptable for Phase 1. Revisit
  if a direct full-params decode surface appears later.
- Phase 2 sub-stage 2-A (algorithm + insertion-point + uniform contract)
  closed 2026-05-12 JST as research-only with no source changes. Owner
  confirmed the local-reference high-pass attenuation skeleton, macOS
  native as pilot renderer, separate Phase 1 commit before Phase 2-B
  render source touches, `effectiveMax = 0.34` hard-coded for Phase 2,
  and a working-colorspace verification step during the macOS prototype.
  Native macOS + iOS export passes are committed. `active.md` now tracks the
  renderer-parity unit through Phase 2-D, with WebGPU + WebGL landing
  together and final visual A/B deferred until all renderers are wired.

## Interrupt / Decision Log

- 2026-05-12 JST: Lane opened. Worktree split from `feature/export-audio-preservation`
  to keep the two product surfaces separate and to branch from a clean
  `main @ 95f1be03`.
- 2026-05-12 JST: Owner-confirmed three decisions for Phase 1.
  `detailSoftness` is added to `FilmtonePhase0ParamsPatch.opticsGlowKeys`
  from day one as user-authored optical creative intent. Desktop
  `AdvancedAdjustCatalog.energyScaledKeys` is **not** touched in Phase 1;
  the Veil intensity max-merge decision is deferred to Phase 2 when render
  exists. The `git worktree add` command is owner-run, not Claude-run.
- 2026-05-12 JST: Owner-confirmed `FilmtonePhase0Params` does not need a
  custom `init(from:)` in Phase 1. Direct full-params JSON decode is not a
  current storage surface; will revisit if one appears.
- 2026-05-12 JST: Implementation discovery — `Phase0ParamsDTO`
  (`apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaTypes.swift`)
  uses synthesized `Codable` and is decoded by `Phase0ExportRequestDTO`. Old
  saved project state is safe because `FilmtoneProjectState.init(from:)`
  decodes `params` as `FilmtonePhase0ParamsPatch` (dynamic-key,
  missing-tolerant). Export-request JSON is constructed at runtime, not
  persisted, so widening the DTO is backward-safe. Phase 1 updates the four
  static fixtures
  (`apps/capacitor-film-lab-ios/scripts/fixtures/phase0-contract/*-export-request.json`)
  to carry `detailSoftness: 0`; `legacy-project-state.json` stays sparse and
  decodes through the patch-based path unchanged.
- 2026-05-12 JST: Phase 1 closed. In-scope verify gates pass
  (`swift test --package-path packages/film-lab-swift-core` 37 / 37,
  `bun run verify:ios`, `bun run verify:macos`,
  `bun run check:filmtone-context`, `git diff --check`).
  `bun run --cwd packages/film-lab-core test` shows
  **199 pass / 2 fail (baseline-waived)**: both failures are in
  `packages/film-lab-core/src/ios-swift-payload.test.ts`
  (`hiddenDefaults` length expected `19` got `33`; `CONTRACT_DEFAULT_KEY_ORDER`
  missing 14 `haloPrism*` / `optical*` keys vs `CONTRACT_DEFAULTS`) and are
  confirmed pre-existing on `main @ 95f1be03` by inspecting
  `git show main:packages/film-lab-core/src/{ios-swift-payload,presets}.ts`.
  `detailSoftness` is in neither array and does not affect the drift. Out-of-
  scope follow-up: extend `CONTRACT_DEFAULT_KEY_ORDER` to include the 14
  drifted keys in their declaration order.
- 2026-05-12 JST: Phase 1 TS contract tests added in a follow-up commit at
  Owner request after closeout review flagged the gap. Added in
  `packages/film-lab-core/src/schema.test.ts`: `detailSoftness` missing → 0
  default, 0/1 boundary acceptance, out-of-range (`-0.1` / `1.1`) rejection.
  Added in `packages/film-lab-core/src/phase0-schema.test.ts`:
  `pickPhase0Params(PRESETS.cinematic).detailSoftness` round-trips, sparse
  patch missing the key defaults to `0`, boundary acceptance and out-of-range
  rejection at the phase0 layer, and `mergePhase0Params(...)` preserves
  `detailSoftness` while still stripping unknown sibling keys. All 6 new
  tests pass; baseline-waived failures unchanged.
- 2026-05-12 JST: Phase 2-A research charter closed. Owner-confirmed
  Phase 2-B decisions: (a) adopt local-reference high-pass attenuation
  skeleton without a bilateral / domain-transform spike unless the macOS
  pilot fails edge/skin quality, (b) macOS native pilot renderer first,
  (c) Phase 1 commits separately before any Phase 2-B render source touch
  — do not bundle Phase 1 contract plumbing with render prototype work,
  (d) `effectiveMax = 0.34` hard-coded for Phase 2 with Phase 3 revisit,
  (e) verify the working colorspace at the insertion point during the
  macOS prototype and adjust luma weights if not Rec.709. Phase 2-A
  artifact archived to
  `archive/2026-05-12-phase-2a-research-charter.md`. Phase 2-B charter was
  drafted in `active.md`; render source touches were gated until the
  Phase 1 commit landed.
- 2026-05-12 JST: Owner changed Phase 2 execution posture after native
  passes landed: prioritize core renderer progress, defer intermediate
  visual A/B to final QA, and treat WebGPU + WebGL as one Phase 2-D
  renderer-parity unit rather than separate planning checkpoints.
- 2026-05-12 JST: iOS planning granularity adjusted. Phase 2-C iOS export
  stays inside the native renderer unit and is not reopened as a separate
  iOS active while Web parity is in flight. Future iOS-only Detail Softness
  work splits by product surface (export, editor/preview UI,
  capture/source metadata, release/copy), not by file mechanics.
- 2026-05-12 JST: Phase 2 closed. WebGPU + WebGL parity committed at
  `444db1e0` after macOS pilot (`e277e9f3`) and iOS export port
  (`eac47d53`). Renderer-parity active archived to
  `archive/2026-05-12-phase-2-renderer-parity.md`. Final visual A/B
  remains owner-run and is rolled into final QA — Phase 3 (UI exposure)
  starts now per owner direction.
- 2026-05-12 JST: Phase 4-A closed at commit `3036e5b9`. TS resolver
  `resolveSourceDetailCompensation(input)` and the
  `SourceDetailProfile` / `SourceDetailCompensationInput` types now
  live in `packages/film-lab-core/src/source-detail-compensation.ts`,
  with 21 unit tests covering the Tuning table plus invariants.
  Active archived to
  `archive/2026-05-12-phase-4-source-compensation-resolver.md`.
  Phase 4-B (native wiring on macOS + iOS where source metadata is
  already at the callsite) opens now. Web renderer wiring stays
  deferred — no source-metadata channel reaches the WebGPU / WebGL
  backends without broad API churn.
- 2026-05-12 JST: Phase 3 closed at commit `27a856fa`. `detailSoftness`
  is now a user-facing Advanced control in the Optics group on both iOS
  SwiftUI (`FilmtoneStrengthSheetData` + `FilmtoneStrings`) and macOS
  native (`AdvancedAdjustCatalog` + `FilmtoneDesktopStrings`), with the
  drift detector treating `Detail softness` as canonical. Existing
  optical recipes (Optics default/strong, Backlight Veil profiles, Stone
  / Urban Looks) deliberately do not auto-apply `detailSoftness` —
  recorded as the Phase 3 recipe decision so future authoring decisions
  can revisit with product feedback. Active archived to
  `archive/2026-05-12-phase-3-ui-exposure.md`. Final visual A/B is rolled
  into Phase 5 / final QA and is **not** a Phase 4 blocker per owner
  direction. Phase 4 (Source Detail Compensation) starts now.

## Constraints

- No render, shader, uniform, UI label, help string, copy, optical filter
  profile value, or source-compensation logic changes in Phase 1.
- `PHASE0_SCHEMA_VERSION` stays `2`. The change is additive and
  default-neutral; missing `detailSoftness` → `0` everywhere.
- `FilmtonePhase0Generated.swift` is regenerated, not hand-edited.
- Existing Zod object behavior on unknown keys is preserved; do not switch
  to strict-mode rejection.
- `packages/film-lab-core/dist/`, `packages/film-lab-smart-look/dist/`, and
  `packages/film-lab-renderer/dist/` are intentionally tracked. Rebuild via
  `bun run build:core` etc. and commit the diff alongside source.
- Git commits, pushes, portfolio submodule bumps, and worktree creation are
  owner-run.

## Operating Rules

- `active.md` exists only while a phase task is in progress. Move it to
  `archive/YYYY-MM-DD-phase-N-<slug>.md` on completion and append a 1–3 line
  note to this `strategy.md`.
- Half-day or longer interrupts: append `Paused` to the current `active.md`,
  move it to `paused/`, and open a new `active.md` for the interrupt. Reverse
  the move when the interrupt closes.
- Architecture-changing interrupts: log under `Interrupt / Decision Log`
  before opening the new `active.md`.

## Evidence Index

- `docs/filmtone/2026-05-11-detail-softness-source-compensation-plan.md` —
  algorithm spec and Phase 0/1/2 breakdown.
- `docs/filmtone/2026-05-12-detail-softness-dedicated-prompt.md` — dedicated
  chat routing for this lane (lives on the export-audio worktree, will be
  merged in via `main` once that lane lands).
- Phase 1 archive: created on Phase 1 close.
