# M8 Opening Open Panel Foreground

Milestone: M5 Native Editing UI follow-up
Date opened: 2026-05-06 JST

## Goal

Make the empty-state `素材を開く` action visibly open the macOS media picker in
front of the Filmtone window, so the user is never left with an apparent no-op.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Confirm current open action path from empty state to `NSOpenPanel`.
- [x] Present the open panel as a window-attached sheet or otherwise force it
  in front of the active Filmtone window.
- [x] Avoid duplicate open panels from repeated clicks / shortcuts.
- [x] Run the smallest Native Desktop verification that proves the change.
- [x] Archive this task and append a compact strategy note.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` -> 121/121 passed.
- `bun run verify:macos` -> BUILD SUCCEEDED.
- `git diff --check` -> clean.

## Done Conditions

- Empty-state `素材を開く` and toolbar Open both present a visible frontmost
  media picker.
- Verification passes.

## Stop Conditions

- Done conditions met.
- Unexpected AppKit/SwiftUI modal behavior requires a larger window-management
  design change.
- 3 consecutive verification failures.

## Out Of Scope

- Changing supported media types.
- Reworking the empty-state visual design.
- Release packaging or public metadata updates.

## Unexpected Blockers

None yet.
