# Active — Film Breath Visible QA Fix

Inserted 2026-05-15 JST after visual QA reported no visible difference between
Film Breath amount `0` and `1` in the launched Desktop debug app.

## Milestone

Follow-up / unexpected blocker for the Film Breath cross-platform quality task.

## Goal

Make Film Breath visibly respond in Desktop video preview and export while
preserving still identity. First prove whether the failure is value propagation,
frame-time propagation, or amount tuning; then patch the smallest product
surface that makes amount `1` clearly observable without adding Gate Weave,
damage, or frame translation.

## Edit Targets

- `apps/filmtone-desktop-macos/`: preview/export state flow and grade pipeline
  wiring; focused verifier tests if the bug is testable outside UI.
- `packages/film-lab-swift-core/` and `packages/film-lab-core/`: only if the
  bounded modulation itself is too subtle after propagation is proven.
- `docs/filmtone/desktop/native-desktop-v2/active.md`: checklist and
  verification notes.

## Read-Only References

- `AGENTS.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-15-film-breath.md`
- Desktop preview/export call sites under `apps/filmtone-desktop-macos/`

## Checklist

- [x] Confirm Desktop Advanced value reaches resolved render params.
- [x] Confirm Desktop video preview passes positive frame time into the grade
  pipeline.
- [x] Confirm Desktop video export passes positive frame time into the grade
  pipeline.
- [x] Patch the no-op cause or retune amount response if propagation is correct
  but amount `1` is not visibly useful.
- [x] Rebuild/relaunch the Desktop debug app.
- [x] Record verification and remaining visual QA risk.

## Verification

- [ ] Focused Desktop verifier or unit-level check for the fixed path.
- [x] `bun run verify:desktop` — passed after the initial-time seek fix.
- [x] `git diff --check` — passed.

## Done Conditions

- User-visible Desktop video preview responds between amount `0` and `1`.
- Desktop video export uses the same Film Breath path as preview.
- Still image processing remains identity when `timeSeconds = 0`.

## Stop Conditions

- Stop after 3 consecutive failures of the same verification command.
- Stop if fixing visible response requires adding out-of-scope Gate Weave,
  scratches, dust, scan jitter, or image translation.
- Stop if value/frame-time propagation cannot be determined from local source.

## Out Of Scope

- iOS live capture monitor.
- Sidecar schema bump.
- Public release/version copy.

## Unexpected Blockers

- 2026-05-15: User reported Desktop visual QA shows no visible difference
  between Film Breath amount `0` and `1`.
- 2026-05-15: Source inspection found the preview/export grade paths pass real
  frame time, but the AVPlayer initial frame can remain at `0s`; Film Breath is
  exact identity at `timeSeconds = 0`, so opening a video and toggling the
  control before playback can look like a no-op. Patched video session setup and
  duration probing to seek the initial preview frame to the midpoint when
  paused.

## Current Visual QA Risk

- 2026-05-15: User provided two screenshots at `0` and max around `24.72s`;
  the midpoint seek fix was not enough. Retuned shared Film Breath limits from
  the original subtle caps (`±0.055EV`, `±2%` contrast, `±0.030` temperature,
  `±0.015` tint) to visible max caps (`±0.16EV`, `±5.5%` contrast,
  `±0.090` temperature, `±0.040` tint), while keeping `drive = amount^1.35`.
- Post-retune code/tests/build passed, but the debug app has not been relaunched
  and visually rechecked after the retune. The currently running Desktop process
  may still be the pre-retune binary.
