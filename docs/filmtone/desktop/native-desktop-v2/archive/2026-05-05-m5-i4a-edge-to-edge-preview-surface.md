# M5-I.4a Edge-To-Edge Preview Surface

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Remove the remaining left / right / top dark strips around loaded preview. The
preview surface itself must ignore macOS safe area so media can occupy the full
window surface, while overlay controls remain in the existing layout.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Make only `PreviewSurface` edge-to-edge with safe-area ignored.
- [x] Remove `Filmtone` as the WindowGroup-supplied title.
- [x] Keep overlay controls, toolbar Open / Export, and `.scaledToFit()` unchanged.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- Loaded preview no longer has left / right / top strips caused by safe-area layout.
- Window title text is not visible.
- Preview remains no-crop / aspect-fit.
- No playback, compare, localization, export, or control-polish changes.

## Out Of Scope

- Cropping / `.scaledToFill()`.
- AVPlayer playback correctness.
- Compare bar.
- Localization parity.
- Full control polish.
