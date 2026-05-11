# Active — Phase 1B Commit Prep

Date: 2026-05-11 JST
Phase: Phase 1B — folder migration complete, commit pending
Milestone: Feature-based source layout

## Goal

Finalize the Phase 1B source-folder migration so the worktree can be
committed without leaving pbxproj, scripts, or current docs inconsistent.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `apps/capacitor-film-lab-ios/ios/App/App/**`
- `apps/capacitor-film-lab-ios/scripts/refactor/`
- `apps/capacitor-film-lab-ios/scripts/verify-phase0-contract.sh`
- `apps/capacitor-film-lab-ios/scripts/davinci/verify-highlight-marker-import.sh`
- `scripts/generate-filmtone-swift.ts`
- `scripts/check-ios-grain-catalog.mjs`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `apps/capacitor-film-lab-ios/docs/`
- `docs/filmtone/ios/README.md`
- `docs/filmtone/ios/capture-practicality/paused/`
- `bun.lock`

## Checklist

- [x] Create explicit mapping for the former flat App root: 108 `.swift`
  files + 1 `.metal` file into `Root/`, `Capture/`, `Editor/`, `Export/`,
  `Look/`, `Optics/`, `Source/`, `Services/`, `Smoke/`, and `Strings/`.
- [x] Move those 109 files with `git mv`; leave `FilmtoneExportActivity/`
  in place.
- [x] Rewrite Xcode groups with the Ruby `xcodeproj` migration script.
- [x] Repair active build/test scripts that referenced former flat paths.
- [x] Repair paused capture-practicality docs that are likely to resume.
- [x] Repair current iOS guide/docs that still pointed at former flat paths.
- [x] Refresh `bun.lock` after the React/Capacitor purge dependency removal.
- [x] Re-run verification after doc and path cleanup.

## Verification

- `apps/capacitor-film-lab-ios/scripts/refactor/migrate-pbxproj.rb --verify`
  — PASS, all 109 plans verified, App and ExportActivity source counts
  unchanged.
- `bun run verify:ios` — PASS: generated Swift drift check, xcodebuild,
  grain catalog, and Swift contract sub-tests all green.
- `git diff --find-renames --stat` — 109 renames detected as renames.
- `git diff --check` — clean.

Simulator launch smoke remains skipped for Phase 1B. The relocation is
covered by xcodebuild compiling the full App target with all file refs in
their new groups; real capture/export smoke is reserved for the later
Capture split phase.

## Done Conditions

- Former `ios/App/App/` root has no flat `.swift` or `.metal` files.
- Xcode project resolves all moved refs through feature folders.
- Build/test scripts and current docs no longer point at moved flat paths.
- Phase 1B can be committed as one coherent source-layout commit.

## Copy / History Impact

No public copy impact: this is an internal source-layout refactor with no
user-facing copy, version, App Store, privacy, codec/export, or release-claim
change.

Article Opportunity: Developer note.
Change-History Opportunity: Developer note, because this records the shift
from a flat native SwiftUI App source root to feature-based ownership before
the god-object splits.

## Unexpected / Follow-up

- Branch was renamed to the proposed `feature/ios-feature-architecture`
  before commit prep finished.
- Root `AGENTS.md` was updated to point at the generated Swift files that
  actually exist after Phase 1B.
