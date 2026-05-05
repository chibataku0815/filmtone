# Active — M5-K2 Look + Strength Grouping

Date: 2026-05-05 JST
Milestone: M5 Native Editing UI
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-k2-look-strength`
Branch: `feature/native-desktop-m5-k2-look-strength`
Base: `0b79861f`

## Goal

Make the Look picker and the Look strength slider read as one conceptual
control group. Today the Look picker lives in `LookLibraryControls` (a
sidebar panel) while the strength slider lives in a separate `GradeControls`
panel further down the sidebar, with `QuickAdjustControls` between them; the
mental link between "what Look am I using?" and "how strong is it?" is
broken.

The fix moves the strength UI inside `LookLibraryControls` so the slider sits
immediately under the Look menu trigger, with disabled posture preserved when
no Look is selected. The now-empty `GradeControls` panel and file are
removed.

## Scope

- Move strength UI (label, percent readout, `FilmtoneGlassSlider`) into
  `LookLibraryControls`, immediately under the Look menu trigger.
- Remove the standalone `GradeControls` panel from the sidebar.
- Delete `GradeControls.swift` and its 4 pbxproj references because the file
  becomes empty.
- Preserve all Saved Look actions: favorite, rename, delete, save current
  Look.
- Preserve disabled posture for strength when `state.lookSlug == nil`.
- Preserve the 4px / 8px spacing discipline. Inner Look-and-strength block
  uses 8pt spacing; outer panel rhythm stays at 16pt. No nested cards inside
  the panel.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/LookLibraryControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift` (delete)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
  (remove 4 GradeControls.swift references)

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
  (panel rhythm reference)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneGlassControls.swift`
  (`FilmtoneGlassSlider`, `FilmtoneGlassMenuTrigger` shapes)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
  (`presetStrength`, `lookSlug`)
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-native-desktop-v2-post-j-visual-handoff.md`

## Checklist

- [x] Read AGENTS.md, strategy.md, post-J visual handoff.
- [x] Inspect current `LookLibraryControls`, `GradeControls`, `EditorSidebar`.
- [x] Move strength UI inside `LookLibraryControls`.
- [x] Remove `GradeControls(state:)` from `EditorSidebar`.
- [x] Delete `GradeControls.swift`.
- [x] Remove 4 GradeControls.swift entries from pbxproj.
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh`.
- [x] `bun run verify:macos`.
- [x] `git diff --check`.
- [x] Launch Debug app for visual smoke availability.
- [x] Archive this active.md.

## Verification

Required commands, run in order:

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
pkill -x Filmtone 2>/dev/null || true
open -n apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app
```

Expected:

- Verify still passes (UI-only change; no Verify SOURCES touched).
- `xcodebuild` Debug builds clean under Swift 6 strict concurrency.
- `git diff --check` is clean.
- Launched app shows: Source Profile → Look (with menu + strength slider
  inside the same panel, plus library action row + Save Current Look) →
  Quick → Export Inspector. No empty Grade panel.

## Done Conditions

- Strength sits immediately under the Look picker inside one panel.
- No-Look posture greys out the strength row but keeps it visible so the
  user understands the relationship.
- Saved Look actions still work: favorite, rename, delete, save current.
- `GradeControls.swift` removed; pbxproj clean.
- All required verifications pass.

## Stop Conditions

- Done conditions met → archive.
- N=3 consecutive verification failures on the same step (Verify/xcodebuild)
  → stop and report.
- Unexpected breakage outside scope (compare, scrub, playback, export) → stop
  and record under "Unexpected".

## Out Of Scope

- Toolbar flicker on sidebar toggle (M5-K1).
- Opening screen readability (M5-K1).
- Draggable compare bar (M5-K3).
- Scrub thumbnail preview (M5-K4).
- Any change to export, sidecar, color pipeline, AVPlayer route.
- Renaming `selectedSavedLookId` / `presetStrength` / `lookSlug`.
- Promoting AdvancedAdjustEditor or QuickAdjust into the Look panel.

## Unexpected / Blockers

- None encountered.

## Verification Result

```
bash apps/filmtone-desktop-macos/Verify/run.sh
=> 65/65 passed, 0 failed

bun run verify:macos
=> ** BUILD SUCCEEDED ** (xcodebuild Debug)

git diff --check
=> clean

pkill + open -n
=> Debug Filmtone.app launched for user visual smoke
```

## Changes Summary

- `LookLibraryControls.swift`: strength label + percent readout + slider
  inserted directly under the Look menu trigger inside an inner
  `VStack(spacing: 8)` so picker and slider read as one block; disabled
  posture (`opacity 0.5`) preserved when `state.lookSlug == nil`.
- `EditorSidebar.swift`: removed the `GradeControls(state: state)` panel
  call (the file is now strength-empty).
- `GradeControls.swift`: file deleted.
- `FilmtoneDesktop.xcodeproj/project.pbxproj`: 4 GradeControls.swift entries
  removed (PBXBuildFile, PBXFileReference, group child, Sources phase).

## Remaining Product Risks

- Visual smoke deferred to user: confirm the new combined panel reads as one
  conceptual control on the dark Liquid Glass right rail.
- Disabled-state contrast: strength row drops to `opacity(0.5)` — verify the
  user can still read the "Strength" label and percent at no-Look state.
- M5-K1 toolbar flicker / opening readability and M5-K3 / M5-K4 work remain
  open; this slice did not touch them.
