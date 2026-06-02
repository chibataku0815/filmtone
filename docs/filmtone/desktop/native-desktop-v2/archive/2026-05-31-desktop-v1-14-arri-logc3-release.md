# Native Desktop v2 Active Task: Desktop v1.14 ARRI LogC3 Release

Milestone: Native Desktop v1.14 Release

Goal: Ship a Desktop Developer ID DMG release that includes the ARRI LogC3 Source Profile work, preserving public update monotonicity after public metadata already reports `1.13`.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.14.md`
- Desktop release docs under `docs/filmtone/desktop/native-desktop-v2/`
- Release artifacts and public update metadata if verification passes

Read-only references:
- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-31-arri-logc3-source-profile.md`
- Truth scripts in `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/`

Checklist:
- [x] Confirm Desktop public/local version truth and choose the target version.
- [x] Bump native Desktop marketing/build version for the release candidate.
- [x] Add release notes focused on the ARRI LogC3 Source Profile product change.
- [x] Run Desktop/core/release verification gates.
- [x] Build, sign, notarize, staple, and package the Developer ID DMG.
- [x] Upload the DMG and update public Desktop metadata if artifact verification passes.
- [x] Rerun truth checks and record final release state.
- [x] Archive this active task and append a short strategy note.

Verification:
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh` (public `1.13`, local candidate `1.14`/`10` after bump)
- `bun test packages/film-lab-core/src/source-profile-conversion.test.ts` (27/27)
- `bun run build:core` (passed)
- `bun run verify:desktop` (passed)
- `apps/filmtone-desktop-macos/Verify/run.sh` (156/156)
- `bun run release:cutover-preflight` (passed; expected pre-DMG warning only)
- `git diff --check` (passed)
- `scripts/release-macos.sh 1.14` (app notarized, stapled, `spctl` accepted)
- `scripts/package-dmg.sh 1.14` (DMG notarized, stapled, `spctl --assess --type open` accepted)
- `shasum -a 256 apps/filmtone-desktop-macos/build/release/1.14/Filmtone-1.14.dmg` = `025e61cfe8947b9086e2e90b8449d377960db6f7fec594bbf6220852cac20340`
- `bun run release:upload-dmg -- --confirm-prod --sync-vercel-env` uploaded `Filmtone-1.14.dmg` to `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.14.dmg` and synced `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- Vercel remote redeploy `dpl_B8ub1KJrNyUwEhVTVVYGG6jPsAQj` refreshed the fixed download page without using the dirty local portfolio worktree.
- `curl -L -s https://www.chibatakumi.studio/film-lab/download` contains `Filmtone-1.14.dmg`.
- Public DMG `HEAD` returned `200`, `content-disposition: attachment; filename="Filmtone-1.14.dmg"`, and `content-length: 22758643`.
- `bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env` uploaded update metadata with `latestVersion: "1.14"` and synced `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`.
- Vercel remote redeploy `dpl_DyZRYvm3R6297FHkyinE23VmM2pS` refreshed the production deployment after update-check env sync.
- Public update metadata: `{"schemaVersion":1,"latestVersion":"1.14","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- Final `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` reports public Desktop latest `1.14`, native marketing version `1.14`, and native build `10`.
- `hdiutil verify apps/filmtone-desktop-macos/build/release/1.14/Filmtone-1.14.dmg` passed.
- `codesign --verify --deep --strict --verbose=4 apps/filmtone-desktop-macos/build/release/1.14/Filmtone.app` passed.

## Release Result

- Desktop v1.14 is public through the fixed download page and update metadata.
- Official artifact: `apps/filmtone-desktop-macos/build/release/1.14/Filmtone-1.14.dmg`.
- SHA-256: `025e61cfe8947b9086e2e90b8449d377960db6f7fec594bbf6220852cac20340`.
- Public update metadata reports `latestVersion: "1.14"`.
- The release includes ARRI LogC3 as a manual/sticky Source Profile; no ARRI Classic 709 / K1S1 look LUT and no ARRI auto-detection were added.

## Copy / History Impact

- Copy / History Impact: Desktop release notes were added for v1.14; no App Store or public article copy was drafted in this task.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note; this release documents the Source Profile system expanding to ARRI LogC3/AWG3 rather than bundling a one-off conversion LUT.

Done conditions:
- Desktop v1.14 local source version and release notes are coherent with public `1.13` being already ahead of the repo tag.
- The release artifact is signed, notarized, stapled, Gatekeeper accepted, and uploaded.
- Public Desktop update metadata reports `latestVersion: "1.14"`.
- Truth script confirms the public Desktop release state after upload.

Stop conditions:
- Done conditions met.
- Notarization, signing, or public upload credentials are unavailable after normal project env lookup.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Mac App Store submission.
- Portfolio submodule bump unless explicitly requested.
- New ARRI auto-detection or official ARRI 709 look LUT bundling.

Unexpected blockers:
- The local portfolio worktree was dirty, so both portfolio refreshes used
  Vercel remote redeploy of the current production deployment instead of a
  local `vercel deploy`.
- A user-directed Film Damage interrupt moved this release task into
  `paused/`; the release was resumed from that paused file and completed
  without replacing the current Film Damage `active.md`.
