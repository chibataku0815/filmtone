# M6 Main Merge Conflict Resolution

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
Merged: `origin/main`

## Goal

Resolve conflicts from merging `origin/main` into the parent Native Desktop v2
branch before the clean release run.

## Result

- Resolved `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  by preserving the Native v2 shared Swift package migration: the iOS app does
  not re-add `FilmtonePhase0Generated.swift` as an app-local source. The
  optical filter generated/store files remain in the iOS app target.
- Resolved `scripts/generate-filmtone-ios-swift.ts` as the legacy shim to the
  canonical `scripts/generate-filmtone-swift.ts`; the canonical generator
  already emits the shared Swift package payload and the iOS optical filters
  payload.

## Checklist

- [x] Inspect both conflicted files.
- [x] Resolve conflicts preserving main and branch intent.
- [x] Run conflict-marker / diff checks.
- [x] Commit the merge.
- [x] Archive this active.

## Verification

- `rg -n '<<<<<<<|=======|>>>>>>>'` over conflicted files: no matches.
- `git diff --check` passed.
- `bun run generate:swift -- --check` passed.

## Done Conditions

- [x] Merge is committed.
- [x] No conflict markers remain.
- [x] Parent branch is ready for release verification.

## Out Of Scope

- Public release.
- Unrelated cleanup of untracked handoff/evidence files.

## Unexpected Blockers

- None.
