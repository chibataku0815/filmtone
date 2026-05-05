# M5-I.4a Titlebar Brand Cleanup

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Remove redundant titlebar branding surfaced by user visual smoke: the left
titlebar app icon and visible `Filmtone` title are unnecessary because the
opening surface already carries the product brand.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Hide the AppKit titlebar title.
- [x] Remove the custom navigation toolbar app icon.
- [x] Preserve right-side Open / Export toolbar actions.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- The top-left titlebar no longer shows the redundant app icon + `Filmtone`
  wordmark.
- Traffic-light controls and right-side toolbar actions remain available.
- Opening transparency / preview behavior remains unchanged.

## Out Of Scope

- Toolbar button visual redesign.
- Loaded preview playback correctness.
- Compare bar.
