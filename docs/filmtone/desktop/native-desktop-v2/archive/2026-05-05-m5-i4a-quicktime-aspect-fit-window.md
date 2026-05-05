# M5-I.4a QuickTime-Style Aspect-Fit Window

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Reduce loaded-preview letterbox / pillarbox by resizing the macOS window toward
the opened media's display aspect ratio, QuickTime-style, instead of continuing
to polish visible matte areas.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Add window capture in `RootWindowView`.
- [x] Probe still / video display size on open.
- [x] Resize the window content area to the media aspect ratio within screen bounds.
- [x] Relax the loaded-state content minimum dynamically so portrait media can fit.
- [x] Keep remaining loaded matte as a fallback for manual resize and screen-bound cases.
- [x] Preserve `.scaledToFit()` preview content and source identity gate.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- Opening landscape or portrait source resizes the window toward source aspect
  ratio within the visible screen frame.
- Loaded preview normally shows little/no matte because the window matches media
  aspect.
- Manual resize or screen-bound cases may still expose the neutral matte fallback.
- No AVPlayer, compare, localization, export, or right-rail control changes.

## Out Of Scope

- Playback correctness.
- Compare bar.
- Localization parity.
- Full control polish.
