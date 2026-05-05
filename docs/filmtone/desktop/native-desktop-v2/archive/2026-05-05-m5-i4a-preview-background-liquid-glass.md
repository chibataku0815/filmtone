# M5-I.4a Preview Background / Liquid Glass Treatment

Date: 2026-05-05 JST

## Milestone

M5 Native Editing UI

## Goal

Replace the stark pure-black opening / letterbox posture with a product-grade
preview background treatment: branded Liquid Glass for the empty state and a
neutral dark frosted matte for loaded media, without applying full Liquid Glass
behind preview content.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Checklist

- [x] Add reusable preview backdrop / neutral frosted matte.
- [x] Convert empty state into branded Liquid Glass surface with real Open CTA.
- [x] Pass `presentOpenPanel` into `PreviewSurface`.
- [x] Preserve loaded media `.scaledToFit()` and stale-frame identity gate.
- [x] Run verification.
- [x] Archive this active task and append a short strategy note.

## Verification

- `bun run verify:macos` — PASS (`BUILD SUCCEEDED`)
- `apps/filmtone-desktop-macos/Verify/run.sh` — PASS (`56/56 passed`)
- `git diff --check` — clean

## Done Conditions

- Empty opening state reads as branded Liquid Glass, not flat black.
- Loaded preview letterbox / pillarbox is neutral dark frosted matte, not pure black.
- Preview content remains no-crop and color-trustworthy.
- No AVPlayer, compare bar, localization, or broader control polish work is included.

## Stop Conditions

- Verification fails 3 consecutive times for the same root cause.
- The design requires changing playback, compare, localization, or export behavior.

## Out Of Scope

- AVPlayer playback correctness.
- Compare bar.
- Localization parity.
- Full control system polish.
- Export behavior.
