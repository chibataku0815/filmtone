# M5-I.3 Control Spacing And Slider Polish

Date opened: 2026-05-05 JST
Milestone: M5 Native Editing UI

## Goal

Fix the M5-I control polish issues surfaced by visual smoke: align panels and
controls to an 8px grid, remove card-in-card appearance from select controls,
and remove the unwanted lower line from sliders.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift`
- Existing right-rail UI call sites only if spacing or slider replacement requires it.

## Checklist

- [x] Make right-rail panel spacing/padding consistently 8px-grid based.
- [x] Remove large nested card backgrounds from Source / Look select controls.
- [x] Keep only the value chip as the clickable select affordance.
- [x] Replace native SwiftUI sliders on the right rail with a custom single-track slider that has no lower artifact line.
- [x] Run `bun run verify:macos`.
- [x] Relaunch the current Debug app after killing stale Filmtone processes.
- [x] Run `git diff --check`.

## Verification

- `bun run verify:macos` PASS. UI-change warnings clean; existing Core Image
  kernel deprecation warnings remain.
- Killed stale macOS Filmtone debug processes and relaunched:
  `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`.
- `git diff --check` PASS.

## Done Conditions

- Source / Look no longer look like cards inside cards.
- Panel and control spacing follows 8px increments.
- Quick / Strength sliders show one intentional track, not an extra line underneath.
- No color, export, sidecar, playback, or release behavior changes.
- `bun run verify:macos` and `git diff --check` pass.

## Stop Conditions

- Done conditions met.
- Three consecutive `bun run verify:macos` failures caused by this polish pass.

## Out Of Scope

- Color pipeline, export mechanics, playback, release cutover, and portfolio updates.

## Unexpected Blockers

- None yet.
