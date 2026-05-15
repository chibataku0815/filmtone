# Active — 24fps Slow Mode (iOS + macOS)

Inserted 2026-05-15 as a cross-platform product interrupt.

## Milestone

M3 / M4 shared parity hardening and Native Desktop behavior parity.

## Goal

Add an explicit `24fps Slow` video timing mode for source videos above 24fps.
The mode interprets each source frame as one 24fps output frame, affects preview
and normal video export on iOS and macOS, and exports without audio. Normal
video behavior remains unchanged unless the user selects the mode.

## Detailed Handoff

Current implementation details, verification logs, known blocker, and the
recommended continuation prompt are recorded in:

```text
docs/filmtone/desktop/native-desktop-v2/2026-05-15-24fps-slow-mode-implementation-handoff.md
```

## Edit Targets

- Shared Swift timing/request contracts used by iOS and macOS.
- iOS native preview/export/export panel/sidecar surfaces.
- macOS native preview/export/export inspector/sidecar surfaces.
- Focused verification fixtures for timing math and export metadata.

## Read-only References

- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- The paused Twilight task at
  `paused/2026-05-15-twilight-bundled-look-paused.md`

## Checklist

- [x] Add shared slow-mode timing constants, eligibility, and time mapping.
- [x] Add export request timing mode without changing the fixed Phase0 output profile.
- [x] Wire iOS preview UI display time, playback rate, and export frame timing.
- [x] Wire macOS preview UI display time, playback rate, and export frame timing.
- [x] Add additive sidecar/result metadata for slow-mode exports.
- [x] Add focused tests or verification assertions for timing math and metadata.
- [x] Run the smallest relevant verification commands and record results.

## Verification

- `swift test` in `packages/film-lab-swift-core`: passed, 76 tests.
- `bun run build:core`: passed after `bun install` restored missing local deps.
- `bun run verify:desktop`: passed after fixing a Swift initialization compile
  issue in `FilmtoneDesktopVideoSession`.
- `bun run check:filmtone-copy`: passed.
- `bun run check:filmtone-context`: passed.
- `git diff --check`: passed.
- `bun run verify:ios`: passed after fixing
  `Phase0ExportRequestDTO.effectiveOutputFPS` to defer to `request.output.fps`
  in normal mode and only return `videoTimingPolicy.targetFPS` in slow24 mode
  (mirrored in `scripts/swift/phase0-contract-support.swift`). Industry-
  consistent with FCPXML `format/frameDuration` vs `conform-rate/srcFrameRate`
  separation between output container fps and source-conform fps.

## Done Conditions

- iOS and macOS expose an explicit slow option only for eligible video sources.
- Preview display duration/current time and playback speed reflect slow mode.
- Normal video exports remain unchanged.
- Slow-mode exports use 24fps output timing, preserve every decoded source
  frame once, and do not include audio.
- Sidecars/results include additive timing metadata.
- Verification either passes or the remaining failures are documented with the
  concrete blocker.

## Stop Conditions

- 3 consecutive verification failures on the same surface.
- Slow mode requires a schema bump or breaking sidecar reader change.
- Preview time mapping breaks existing marker/compare behavior beyond a local
  fix in this lane.
- Highlight export behavior is accidentally changed.

## Out of Scope

- Audio stretching, pitch correction, frame blending, optical flow, and 24fps
  same-speed conversion.
- Highlight export retiming.
- Legacy Electron Desktop.
- Portfolio submodule, App Store metadata, release notes, or public version
  claims.

## Copy / History Impact

Adds user-facing timing copy and additive sidecar/result metadata for explicit
24fps slow video export. No public release/version/App Store copy change is
required in this task.

## Article Opportunity

Release-note only.

## Change-History Opportunity

Developer note.
