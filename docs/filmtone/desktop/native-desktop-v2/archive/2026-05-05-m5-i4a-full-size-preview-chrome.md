# M5-I.4a Full-Size Preview Chrome

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Remove the remaining macOS titlebar gap above loaded preview content. The
window should no longer show the `Filmtone` title, and preview content should
extend into the titlebar area QuickTime-style.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Configure the window as full-size content view.
- [x] Hide / clear the title robustly.
- [x] Adjust preview resize math so full-size chrome no longer adds top gap.
- [x] Keep Open / Export toolbar actions available.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- `Filmtone` title is not visible in the titlebar.
- Loaded preview starts behind / within the titlebar area instead of below a
  separate dark strip.
- Source preview remains no-crop and aspect-fit.
- No playback, compare, localization, export, or control-polish changes.

## Out Of Scope

- AVPlayer playback correctness.
- Compare bar.
- Localization parity.
- Full control polish.
