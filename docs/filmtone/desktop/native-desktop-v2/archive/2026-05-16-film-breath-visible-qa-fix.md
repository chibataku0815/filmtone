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

## 2026-05-16 Second Retune — Amplitude Calibration + Fast Breath Band

The first retune (`±0.16EV` peak) still produced sub-visible exposure shifts at
typical timestamps because the noise composition's typical magnitude collapses
toward zero by central-limit averaging (`E|Σw·U| ≈ 0.25` for prior weights).
At `t=24.72s, seed=7331, amount=1.0` the actual exposure offset was
`-0.064 EV` — below the human-visible floor on typical SDR displays through
creative LUT shoulder compression.

Worked on isolated worktree `../filmtone-film-breath-retune` (branch
`feature/film-breath-visible-qa-retune` off `feature/film-breath @ 7dc8325f`).

Changes (TS and Swift helpers stay byte-aligned):

- LIMITS raised to Dehancer-max benchmark amplitudes (not Dehancer-compatible):
  - exposure `0.16 → 0.50 EV`
  - contrast `0.055 → 0.15`
  - temperature `0.09 → 0.22`
  - tint `0.04 → 0.12`
- Noise composition replaced (3 bands → 4 bands) with medium-dominant weights:
  - fast `1.8s × 0.15` (sub-second flutter — period stretched from initial
    `1.5s` and weight pulled down from initial `0.20` after first user QA
    reported the fast component felt "nervous")
  - medium `4.8s × 0.55` (projector-breath fundamental, lifted to absorb the
    weight freed from `fast`)
  - slow `8.6s × 0.20`
  - long `15.5s × 0.10`
- `breathNoise` output multiplied by `2.5×` calibration then clamped to `±1`
  so typical magnitudes reach the visible band while rare in-phase peaks are
  flat-topped at the LIMIT.
- Tests replaced weak `visibleEnergy > 0.08` assert with:
  - explicit `|exposure_offset| > 0.15` at `t=24.72s, seed=7331, amount=1.0`;
  - per-channel timestamp sweep across `{2,5,10,15,20,24.72,30,45,60,90}s`,
    requiring `|exposure| > 0.15 EV` and `|temperature| > 0.05` in ≥6/10 samples;
  - 24fps adjacent-frame smoothness thresholds relaxed
    (`exposure < 0.05 EV` per frame etc) to absorb the fast 1.5s band.
- Drive `amount^1.35` and envelope `smoothstep(t/1.25)` unchanged.
- Strong recipe stays at `0.28` — `drive ≈ 0.169` yields typical
  `|exposure_offset| ≈ 0.042 EV` which preserves subtle character.
- Sidecar V1 schema unchanged. UI label unchanged. iOS+Desktop parity preserved
  via shared Swift core.

Copy / History Impact: No copy/history impact — user-facing copy
(`Film Breath` / `フィルムブレス`), advanced row label, recipe defaults
(Default 0 / Strong 0.28), and sidecar schema (`gradeParams.filmBreathAmount`)
are unchanged. Article foundation
`docs/filmtone/articles/2026-05-15-film-breath/README.md` was not edited;
publish-ready copy is gated by visual QA and is out of scope here.

### Verification (this retune, in worktree)

- [x] `bun test packages/film-lab-core/src/film-breath.test.ts` — 6/6 pass.
- [x] `bun test` related core suites — 105/105 pass.
- [x] `bun run build:core` — pass.
- [x] `swift test --package-path packages/film-lab-swift-core` — 78/78 pass.
- [x] `bun run verify:desktop` — `** BUILD SUCCEEDED **`.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh` — 143/143 pass.
- [x] `bun run verify:ios` — pass (after `pod install` in worktree).
- [x] `bun run check:filmtone-context` — pass after Copy/History Impact note.
- [x] `bun run check:filmtone-copy` — pass.
- [x] `git diff --check` — pass.
- [x] Relaunch Desktop debug app from worktree-local build (initial 1.5s/0.20
      fast band; user reported "max is visible but nervous").
- [x] Fast band softened: weight `0.20 → 0.15`, period `1.5s → 1.8s`,
      medium weight `0.50 → 0.55` to absorb the released energy. Empirically
      this still gives 6/10 visible exposure timestamps, max 24fps adjacent
      frame delta `0.0139 EV` (≪ smoothness gate `0.05 EV`), and
      `|exposure_offset| = 0.500 EV` (LIMIT-clamped) at `t=24.72s, seed=7331`.
- [x] User visual QA at `5s / 24.72s / 60s`: accepted as the product-quality
      finish line. Strong (`0.28`) stays subtle (`drive ≈ 0.169` →
      typical `|exposure_offset| ≈ 0.06 EV`).
