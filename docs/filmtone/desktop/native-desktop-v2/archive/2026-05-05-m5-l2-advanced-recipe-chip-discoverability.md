# M5-L2 Advanced Recipe Chip Discoverability

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-l2-advanced-chips`
Branch: `feature/native-desktop-m5-l2-advanced-chips`

## Milestone

M5 / Native Editing UI parity thin fix.

## Goal

Make the iOS-style advanced recipe chips visible and discoverable in Native
Desktop: Tone chips (`Standard` / `Airy` / `Sunset` / `Depth`) and Optics /
Glow / Grain / Motion chips (`None` / `Default` / `Strong`) should be visible
near their group titles before individual sliders.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Read-Only References

- `/Users/chibatakumi/Downloads/スクリーンショット 0008-05-05 19.52.12.png`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m5-l1-source-auto-conversion-lut-parity.md`

## Checklist

- [x] Inspect current Desktop advanced editor and iOS sheet shape.
- [x] Make recipe chips visible on first opening of the Desktop advanced surface.
- [x] Preserve existing apply/reset behavior and per-group slider editing.
- [x] Add focused Verify coverage for default expanded recipe-chip visibility.
- [x] Run required verification.
- [x] Relaunch the Debug app for visual smoke.
- [x] Record completion and archive this active task.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` => 94/94 passed.
- `bun run verify:macos` => xcodebuild Debug succeeded.
- `git diff --check` => clean.
- Relaunch Debug app:
  `pkill -x Filmtone 2>/dev/null || true`
  `open -n /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-l2-advanced-chips/apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`
  Confirmed `Filmtone` process is running.

## Done Conditions

- Opening the Desktop advanced adjustment surface immediately shows the iOS-style
  recipe chips for Tone and optics/glow/grain groups without requiring users to
  hunt through collapsed sections.
- Basic remains chip-free; Motion remains video-only.
- Recipe application, reset, Quick state, preview/export/sidecar behavior stay
  on existing state/catalog paths.
- Verification is green.

## Stop Conditions

- Done met.
- Unexpected blocker.
- 3 consecutive verification failures.

## Out Of Scope

- M5-L3 Backlight Veil.
- Source Auto / Conversion LUT changes beyond the M5-L1 base.
- New advanced parameter schema.
- Portfolio, release artifact, notarization, staging, commit, push.

## Unexpected Blockers

- None yet.
