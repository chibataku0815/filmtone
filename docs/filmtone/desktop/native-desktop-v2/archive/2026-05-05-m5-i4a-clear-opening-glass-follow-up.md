# M5-I.4a Follow-up Clear Opening Glass

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Adjust the first M5-I.4a implementation after user visual smoke: the opening
state must read as clear Apple Liquid Glass rather than a dark background with
an opaque gray card.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Replace opening dark gradient posture with clearer full-window glass field.
- [x] Remove the opaque empty-state card posture so it reads as clear glass.
- [x] Preserve loaded preview behavior and matte from the first M5-I.4a pass.
- [x] Run verification.
- [x] Archive this active task and update the strategy note.

## Verification

- `bun run verify:macos`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `git diff --check`

Result:

- `bun run verify:macos` PASS
- `apps/filmtone-desktop-macos/Verify/run.sh` PASS (56/56)
- `git diff --check` clean

## Done Conditions

- Opening background reads as clear Apple Liquid Glass.
- Empty-state logo / copy / CTA remain readable without a gray slab.
- No AVPlayer, compare, localization, export, or right-rail control changes.

## Out Of Scope

- Playback correctness.
- Compare bar.
- Loaded-preview QuickTime-style aspect resize or matte redesign.
- Full control polish.
- Localization parity.
