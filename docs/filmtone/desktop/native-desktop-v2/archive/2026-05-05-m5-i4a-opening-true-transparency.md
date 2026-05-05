# M5-I.4a Opening True Transparency Follow-up

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Answer the user visual-smoke question "透明にはできないのでしょうか？" by making
the opening state transparent at the AppKit window level, not only a
transparent-looking SwiftUI surface over an opaque window.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Make the hosting `NSWindow` non-opaque with a clear backing color.
- [x] Keep the loaded preview matte / image path as the color-judgment fallback.
- [x] Reduce the empty backdrop fill so the clear window can actually show through.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- Opening transparency can reveal content behind the Filmtone window.
- Opening state still reads as Apple Liquid Glass, not a flat invisible window.
- Loaded preview behavior remains unchanged from the QuickTime aspect-fit slice.

## Out Of Scope

- AVPlayer playback correctness.
- Compare bar.
- Localization parity.
- Full control polish.
- Further loaded-preview matte redesign.
