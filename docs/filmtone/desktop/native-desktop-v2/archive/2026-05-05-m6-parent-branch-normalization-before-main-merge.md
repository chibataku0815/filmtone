# M6 Parent Branch Normalization Before Main Merge

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

## Goal

Bring the parent branch back into a coherent pre-release state before merging
`main`, then prepare for a clean release run after that merge.

## Result

- Rolled production update metadata back to `latestVersion: "1.0.4"`.
- Restored `FILM_LAB_DESKTOP_DOWNLOAD_URL` to the legacy Desktop DMG and
  redeployed the current production Vercel deployment remotely.
- Verified the public download complete page is back on
  `filmtone-1.0.3-arm64.dmg`.
- Corrected release-cutover docs and strategy so they no longer claim public
  Desktop `1.4` is active.
- Preserved the generated Native `Filmtone-1.4.dmg` artifact and release
  preflight tooling for the later clean release run.
- Recorded the first release attempt as an attempted cutover followed by
  rollback.

## Checklist

- [x] Correct release docs so they no longer claim public v1.4 is active.
- [x] Record the attempted cutover and rollback accurately.
- [x] Keep release readiness/preflight artifacts available for the later clean
      release run.
- [x] Confirm public truth is back to Desktop `1.0.4`.
- [x] Run scoped `git diff --check`.

## Verification

- Public update metadata:
  `{"schemaVersion":1,"latestVersion":"1.0.4","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`
- Release truth script reports `public_latestVersion: 1.0.4`.
- Public download complete page references `filmtone-1.0.3-arm64.dmg`.
- `git diff --check` passed.

## Done Conditions

- [x] Parent branch docs and active state match the actual public state.
- [x] No `active.md` remains open after archiving this task.
- [x] The branch is ready for the next operation: merge `main`.

## Out Of Scope

- Merging `main`.
- Releasing again.
- Deleting unrelated untracked handoff/evidence files.
- Resolving unrelated user changes in the portfolio repo.

## Unexpected Blockers

- None.
