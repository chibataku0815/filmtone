# Active - Adjust Inline Collapsed Default Follow-Up

Date opened: 2026-05-16 JST
Milestone: M5 Native Editing UI follow-up

## Goal

Restore the Adjust rail default so parameter groups are collapsed on first
open, matching the original Advanced Adjust behavior.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift`
- `docs/filmtone/desktop/native-desktop-v2/active.md`

## Checklist

- [x] Remove inline auto-expansion from initial state and lifecycle hooks.
- [x] Verify the Desktop build surface.
- [x] Archive this follow-up.

## Verification

- `bun run verify:desktop` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: `146/146`.
- `git diff --check` passed.

## Copy / History Impact

- No copy/history impact: this only restores the existing collapsed default for
  inline Adjust groups.
- Article Opportunity: No story.
  Change-History Opportunity: Release-note only if this is published as a patch
  release.

## Done Conditions

- Inline Adjust groups start collapsed.
- Users can still expand groups manually.
- Desktop verification passes.

## Stop Conditions

- Stop after 3 consecutive verification failures.
- Stop if the fix needs release/version changes beyond this UI behavior.

## Out Of Scope

- New release publication.
- iOS changes.
- Legacy Electron changes.

## Unexpected

- Existing iOS dirty files remain unrelated and must not be touched.
