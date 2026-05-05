# M5-I.2 Glass Control Visual Correction

Date opened: 2026-05-05 JST
Milestone: M5 Native Editing UI

## Goal

Correct the M5-I.1 visual direction: do not use the reference images as a black
theme. Preserve Filmtone's existing Liquid Glass surface, and use the references
only for button/control shine, inner highlight, and clickable affordance quality.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift`
- Existing M5-I.1 call sites only if required.

## Checklist

- [x] Remove black-as-design-language from the shared glass helper controls.
- [x] Make Source / Look triggers read as custom premium controls, not default select boxes.
- [x] Keep lower-hierarchy controls quiet but visibly intentional.
- [x] Run `bun run verify:macos`.
- [x] Relaunch the current Debug app after killing stale Filmtone processes.
- [x] Run `git diff --check`.

## Verification

- `bun run verify:macos` PASS.
- Killed stale macOS Filmtone debug processes and relaunched:
  `apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`.
- `git diff --check` PASS.

## Done Conditions

- Source / Look menu triggers have a distinct custom capsule/value-chip surface.
- Primary action shine references the supplied images without making the UI black-based.
- No preview/content/color pipeline behavior changes.
- `bun run verify:macos` and `git diff --check` pass.

## Stop Conditions

- Done conditions met.
- Three consecutive `bun run verify:macos` failures caused by this visual correction.

## Out Of Scope

- Color pipeline, export mechanics, playback, release cutover, and portfolio updates.

## Unexpected Blockers

- M5-I.1 visual smoke was polluted by multiple running Filmtone builds with the same product name / Bundle ID; relaunch must kill stale macOS Filmtone processes first.
