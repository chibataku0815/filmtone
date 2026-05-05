# M5-I.4a Preview-Area Aspect Fit

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Fix the remaining loaded-preview margin after QuickTime-style resize. The
window resize must account for the toolbar / safe-area height so the actual
preview body, not the whole content rect, matches the source aspect ratio.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Measure or infer the top chrome / safe-area height.
- [x] Fit the preview body to source aspect and add chrome height back to the window content size.
- [x] Keep `.scaledToFit()` and matte fallback unchanged.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- Previously observed landscape video no longer leaves visible side matte after open.
- Portrait / landscape sources still stay no-crop.
- Manual resize may expose matte fallback.
- No playback, compare, localization, export, or control-polish changes.

## Out Of Scope

- AVPlayer playback correctness.
- Compare bar.
- Localization parity.
- Full control polish.
