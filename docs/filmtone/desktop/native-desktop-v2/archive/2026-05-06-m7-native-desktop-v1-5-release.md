# Active — M7 Native Desktop v1.5 Release

Date opened: 2026-05-06 JST
Milestone: `M7 Native Desktop v1.5 Release`

## Goal

Ship the next public Native Desktop release after Desktop v1.4. The release is
version `1.5` because public Desktop is currently `1.4`, `desktop-v1.4` is the
latest Desktop tag, and the post-tag changes include user-visible product fixes
and release automation.

Primary public exit: signed, notarized, stapled Developer ID DMG uploaded to
the fixed Desktop download rail, with update metadata reporting `1.5`.

Secondary exit: keep the Mac App Store lane ready, but do not block the public
DMG release on App Store screenshots, App Privacy, or review submission.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.5.md`
- `scripts/release-cutover-preflight.mjs`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- this `active.md`

## Read-only References

- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/desktop/mac-app-store-readiness/README.md`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.4.md`

## Checklist

- [x] Confirm release truth scripts and current git state.
- [x] Bump Native Desktop marketing version to `1.5` and build number to `2`.
- [x] Add v1.5 release notes covering portrait layout, Backlight Veil, Look
  Strength, Highlight Reel, and Mac App Store readiness.
- [x] Make cutover preflight usable for the current project release version
  instead of being hard-coded to v1.4.
- [x] Run local product/release verification:
  `bash apps/filmtone-desktop-macos/Verify/run.sh`,
  `bun run verify:macos`, `bun run release:cutover-preflight`,
  `git diff --check`.
- [x] Build/sign/notarize/staple `Filmtone.app` with `scripts/release-macos.sh`.
- [x] Package/sign/notarize/staple `Filmtone-1.5.dmg` with
  `scripts/package-dmg.sh`.
- [x] Upload DMG to Vercel Blob and sync the fixed download URL.
- [x] Upload update metadata with `latestVersion: "1.5"` after the DMG is
  available.
- [x] Verify public download/update truth and checksum.
- [x] Archive this task and append a short completion note to `strategy.md`.

## Verification

2026-05-06 JST:

- `bun run release:cutover-preflight` passed before packaging; expected warning
  only that `Filmtone-1.5.dmg` was not built yet.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`121/121`).
- `bun run verify:macos` passed (`** BUILD SUCCEEDED **`).
- `git diff --check` passed.
- `scripts/release-macos.sh` passed; `Filmtone.app` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `scripts/package-dmg.sh` passed; `Filmtone-1.5.dmg` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `Filmtone-1.5.dmg` sha256:
  `3d233125df33d8efe73f291f3122ade5babd28411cd4a9d3a6e3901a5a50257e`.
- `bun run release:cutover-preflight` passed again after the DMG existed.
- `bun run release:upload-dmg -- --confirm-prod --sync-vercel-env` uploaded
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.5.dmg`
  and synced `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- Vercel production deploy `dpl_23pPBFELGLrqyvuTfvmBJDvpGEy4` refreshed the
  fixed download page so it returned `Filmtone-1.5.dmg`.
- `bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
  uploaded `film-lab/desktop/update-meta.json` with `latestVersion: "1.5"`.
- Vercel production deploy `dpl_9dUbRukQbfmrknVYPSC69MfG5yF4` refreshed the
  update-check env.
- Release truth reports local Native Desktop `1.5` build `2`, public Desktop
  latest `1.5`, latest Desktop tag `desktop-v1.4`, and v1.5 release notes
  present.
- Public update metadata body:
  `{"schemaVersion":1,"latestVersion":"1.5","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- Public download page contains `Filmtone-1.5.dmg`.
- Public DMG HEAD returns `200`, `filename="Filmtone-1.5.dmg"`, and
  `content-length: 9320042`.

## Done Conditions

- Native Desktop release truth reports public Desktop latest `1.5`.
- The fixed public download rail resolves to `Filmtone-1.5.dmg`.
- The release artifact is signed, notarized, stapled, and Gatekeeper accepted.
- Local release notes and strategy record the release outcome.

## Stop Conditions

- Done conditions are met.
- Stop on an unexpected blocker requiring secrets, Apple account state, Vercel
  project access, schema changes, or release-scope product fixes.
- Stop after 3 consecutive verification failures on the same step.

## Out Of Scope

- Mac App Store review submission.
- Portfolio submodule bump, staging, commit, push, or source-level web content
  edits. Production deploy was in scope only to refresh Vercel env for the
  fixed Desktop download/update rails.
- New product features beyond release correctness fixes.

## Unexpected / Blockers

None.
