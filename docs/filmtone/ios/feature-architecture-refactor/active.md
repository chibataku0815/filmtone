# Active - Phase 2B-11 / 2C ExportSession Finalization

Date: 2026-05-11 JST
Phase: Phase 2B-11 / 2C - ExportSession final orchestrator pass
Milestone: Close the ExportSession split and decide whether Phase 2 is
ready to hand off to EditorStore.

## Owner Directive

- Keep product-boundary grain. This is a finalization pass, not another
  helper-chipping sequence.
- Essence first: confirm `FilmtoneExportSession` is now a thin enough
  orchestrator for Gyroflow / V2 capture lanes to work around it.
- Do not force extra extraction just to hit an exact line number. At 1078
  lines after 10D, Phase 2 is near the ~1000-line target; move only
  low-risk leftovers if they clearly reduce responsibility without
  widening behavior-bearing render or sidecar seams.
- Outer shell minimal: use existing build/math/sidecar gates unless this
  pass changes render, sidecar, writer, or queue behavior.

## Goal

Complete Phase 2 by doing a final ExportSession surface pass:

1. Inventory the remaining `FilmtoneExportSession` responsibilities and
   classify each as:
   - orchestrator surface to keep
   - already-delegated collaborator wiring to keep
   - low-risk cleanup to move or delete now
   - defer to later Phase 2C/QA only if behavior parity needs a fixture
2. Apply only low-risk cleanup that does not change render math, sidecar
   schema, writer/reader behavior, queue behavior, or public API.
3. Run the minimal Phase 2 closeout gates and record whether Phase 3 can
   start.

## Current State

- `FilmtoneExportSession.swift`: 1078 lines after 10D.
- Major collaborators now exist for:
  - source/profile LUT
  - depth payload + depth matcher
  - optics resampling + optics compositor
  - grade render pipeline
  - media writer + frame appender
  - source image normalization
  - connect package assembly
  - sidecar writing
  - still image writing
  - mezzanine routing
  - preview rendering
  - video timeline
  - video completion coordinator
  - video frame/audio pumps
  - video IO builder
  - export geometry

Remaining session-owned methods are expected to be mostly facade /
orchestration plus grade/motion glue required by `FilmtoneSharedGradeProcessor`
and preview/live monitor call sites.

## Preferred Work

- Produce a concise remaining-responsibility table in this active file.
- If obvious zero-risk cleanup exists, implement it in this same bundle.
  Examples:
  - stale comments that say a responsibility still lives on the session
    when it no longer does.
  - zero-caller private helpers after 10D.
  - import cleanup if build proves it safe.
- If a cleanup would move render math, sidecar assembly, queue behavior,
  or public API, leave it and record "defer by design".
- Do not add formal XCTest, simulator smoke, PSNR, or PNG fixtures unless
  this pass changes behavior-bearing logic.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - optional low-risk cleanup only
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - remaining responsibility table, gate results, Phase 3 readiness
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - final Phase 2 completion log after commit/archive

## Checklist

- [ ] Record remaining `FilmtoneExportSession` responsibility table.
- [ ] Confirm no zero-caller private helpers remain after 10D, or delete
  any that are clearly dead.
- [ ] Confirm stale ExportSession comments are gone or update them.
- [ ] Confirm public API surface used by views/runtime is unchanged.
- [ ] Confirm `FilmtoneExportSidecarBuilder.swift` is untouched in this
  pass unless explicitly justified.
- [ ] Run `bun run verify:ios`.
- [ ] Run `git diff --check`.
- [ ] Record Phase 3 readiness decision.

## Verification Gates

Minimum gates:

- `bun run verify:ios`
- `git diff --check`
- targeted stale-comment / zero-caller grep if cleanup is applied

Optional only if behavior changes:

- sidecar canonical fixture or still PNG/export smoke. Do not add these
  just because Phase 2 is ending; use them only if this final pass touches
  sidecar or render behavior.

## Done Conditions

- Phase 2 remaining responsibilities are documented.
- Any applied cleanup is low-risk and verified.
- `FilmtoneExportSession` is accepted as thin enough to move to Phase 3
  without blocking Gyroflow / V2 capture work.
- `bun run verify:ios` and `git diff --check` are green.
- Next active can start Phase 3 EditorStore at larger bundle grain.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Final cleanup reveals a required behavior-bearing extraction. Stop and
  record the blocker instead of silently widening scope.

## Out Of Scope

- New export behavior.
- Sidecar schema changes.
- Render math changes.
- Writer/reader/queue behavior changes.
- EditorStore or CaptureSession code changes.
- Formal QA matrix, simulator smoke, PSNR, PNG fixtures unless triggered
  by a behavior-bearing cleanup.

## Line / File Deltas

Pending implementation.

## Gate Results

Pending implementation.

## Phase 3 Readiness

Pending implementation.

## Unexpected / Follow-up

Pending implementation.
