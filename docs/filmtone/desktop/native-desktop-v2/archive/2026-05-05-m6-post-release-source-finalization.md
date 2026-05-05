# M6 Post-Release Source Finalization

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`
Starting HEAD: `0ae2138c`

## Milestone

M6 Release Cutover

## Goal

Make the completed Native Desktop v1.4 public cutover durable in source control:
push the release branch, land it on `main`, tag it, bump the portfolio submodule,
and record post-release QA / Electron frozen-legacy follow-ups.

## Edit Targets

- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-m6-post-release-source-finalization.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/desktop/release-cutover/cutover-architecture.md`
- `apps/desktop-film-lab-batch/README.md`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/vendor/filmtone`

## Read-Only References

- public update metadata
- public download page
- release truth scripts
- current `feature/native-desktop-plan`
- `origin/main`
- portfolio dirty worktree state

## Checklist

- [x] Confirm release branch state and public release truth.
- [x] Record Electron frozen-legacy / post-release QA state in release docs.
- [x] Commit the source-finalization record on `feature/native-desktop-plan`.
- [x] Push `feature/native-desktop-plan`.
- [x] Merge the release branch to `main`.
- [x] Push `main`.
- [x] Create and push `desktop-v1.4` tag.
- [x] Bump portfolio `vendor/filmtone` to the released source commit.
- [x] Commit the portfolio submodule bump without touching unrelated dirty files.
- [x] Archive this active and leave no current `active.md`.

## Verification

- `bun run release:cutover-preflight` passed; it warned only that public
  update metadata already points to `1.4`, which is expected after cutover.
- `git diff --check` passed.
- release truth script reports public Desktop latest `1.4`.
- public download complete page references `Filmtone-1.4.dmg`.
- main-merge worktree verification passed:
  - `bash apps/filmtone-desktop-macos/Verify/run.sh` (`99/99`)
  - `bun run verify:macos` (`** BUILD SUCCEEDED **`)
- Remote `feature/native-desktop-plan` pushed at `a21ae73e`.
- Remote `main` pushed at merge commit `3ce0f1b0`.
- Remote tag `desktop-v1.4` pushed at `3ce0f1b0`.
- Portfolio source permanence commit pushed:
  `c766b7c9` (`chore(filmtone): bump submodule to desktop v1.4`), with
  `vendor/filmtone` at `3ce0f1b0`.

## Done Conditions

- `feature/native-desktop-plan`, `main`, and `desktop-v1.4` exist on remote at
  the released source state.
- Portfolio has a committed `vendor/filmtone` bump to the released source state,
  or a concrete blocker is recorded.
- Public release truth still reports Desktop `1.4`.
- No Native Desktop v2 `active.md` remains open.

## Stop Conditions

- Done met.
- Unexpected blocker.
- 3 consecutive verification failures.

## Out Of Scope

- Changing Native Desktop product behavior.
- Rebuilding/notarizing a new artifact.
- Reverting or cleaning unrelated untracked handoff/evidence files.
- Reverting or cleaning unrelated dirty portfolio files.

## Unexpected Blockers

- Local `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` `main`
  had unrelated dirty iOS / agent files, so `main` was merged in a temporary
  worktree from `origin/main` instead of touching that worktree.
- Local portfolio `main` had unrelated dirty files and was behind remote, so
  the submodule bump was committed in a temporary portfolio worktree from
  `origin/main`.
