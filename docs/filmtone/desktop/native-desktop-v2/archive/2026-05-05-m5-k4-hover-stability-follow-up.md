# M5-K4 Scrub Hover Stability Follow-up

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Goal

Fix the visual regression where hovering the video scrub bar makes the seek bar
shake while preserving hover/drag thumbnail previews.

## Result

- Replaced the SwiftUI hover path around the video scrub slider with a stable
  tracking path that does not perturb slider layout.
- Preserved click/drag seeking and hover/drag thumbnail refresh.
- Kept the thumbnail rendered as an overlay so hovering does not move the scrub
  bar vertically.
- The user visually confirmed the latest Debug app after this follow-up.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed before the M5-K
  integration commit (`86/86 passed`).
- `bun run verify:macos` passed before the M5-K integration commit.
- `git diff --check` was clean before the M5-K integration commit.
- Debug app was relaunched for visual smoke, and the user confirmed the hover
  behavior.

## Done Conditions

- [x] Hovering the video scrub bar no longer causes the seek bar to shake.
- [x] Hover and drag thumbnail preview still appear.
- [x] Verification was green before integration.
- [x] User visual smoke passed after the follow-up.

## Out Of Scope

- Thumbnail visual redesign.
- Thumbnail provider cache or grading pipeline changes.
- Compare bar, opening screen, sidebar, or Look control changes.

## Unexpected Blockers

- None.
