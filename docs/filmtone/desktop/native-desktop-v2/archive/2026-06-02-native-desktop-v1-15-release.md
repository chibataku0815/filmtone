# Native Desktop v2 Active Task: Desktop v1.15 Film Damage Export UX Release

Milestone: Native Desktop v1.15 Release

Goal: Ship a Desktop Developer ID DMG release from current `main` that includes
the June 2 Film Damage export fidelity, export-speed, and FHD/4K export-choice
work, while preserving monotonic public update metadata after Desktop v1.14.

Edit targets:
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.15.md`
- Desktop release docs under `docs/filmtone/desktop/native-desktop-v2/`
- Release artifacts and public update metadata if verification passes

Read-only references:
- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-desktop-scratch-export-integration-60fps-speed.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-desktop-fhd-4k-export-choice.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-desktop-4k-export-warning-ux.md`
- Truth scripts in `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/`

Checklist:
- [x] Confirm Desktop public/local version truth and choose the target version.
- [x] Bump native Desktop marketing/build version for the release candidate.
- [x] Add release notes focused on shipped Film Damage export UX behavior.
- [x] Run Desktop/core/release verification gates.
- [x] Build, sign, notarize, staple, and package the Developer ID DMG.
- [x] Upload the DMG and update public Desktop metadata if artifact verification passes.
- [x] Rerun truth checks and record final release state.
- [x] Archive this active task and append a short strategy note.

Release copy brief:
- Primary reader: a Mac user exporting graded 4K/60 footage with Film Damage or
  choosing between normal FHD and 4K output before export.
- Moment: reading the release notes or update prompt before replacing the app.
- Unresolved feeling: wants scratches to feel embedded in the result and wants
  the export action to be clearer before committing to a slower 4K render.
- Next action: download v1.15 and use the explicit FHD/4K export choice.
- Not for: Mac App Store review copy, broad product positioning, or iOS release
  claims.
- Claim class: Candidate until public update metadata reports `1.15`.
- Source evidence: Desktop truth script, current source, June 2 archived Desktop
  task logs, and final release artifact checks.
- Reversibility buffer: describe 4K as taking longer and the measured speed
  improvement as one real test clip, not a guarantee for all files.

Verification:
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
  reports public Desktop `1.14`, local candidate `1.14`/`10` before bump.
- `bun run verify:desktop` passed before bump.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed before bump: `163/163`.
- `bun run release:cutover-preflight` passed before bump with expected warning
  that public update-meta already points to `1.14`.
- `bun run check:filmtone-context` passed before bump.
- `git diff --check` passed before bump.
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
  after bump reports public Desktop `1.14`, local candidate `1.15`/`11`.
- `bun run verify:desktop` passed after bump.
- `apps/filmtone-desktop-macos/Verify/run.sh` passed after bump: `163/163`.
- `bun run release:cutover-preflight` passed after bump with expected pre-DMG
  warning; after packaging it passed with `Filmtone-1.15.dmg` present.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` initially required this task's
  `Copy / History Impact` marker, then passed after the marker was added.
- `git diff --check` passed after bump.
- `scripts/release-macos.sh 1.15` passed: app notarized, stapled, and
  `spctl --assess --type execute` accepted.
- `scripts/package-dmg.sh 1.15` passed: DMG notarized, stapled, and
  `spctl --assess --type open --context context:primary-signature` accepted.
- `shasum -a 256 apps/filmtone-desktop-macos/build/release/1.15/Filmtone-1.15.dmg`
  = `0e7fc9d31484d319759d21044d572e1d9fc48eabdcbea1b93082ac9d32e14d29`.
- `hdiutil verify apps/filmtone-desktop-macos/build/release/1.15/Filmtone-1.15.dmg`
  passed.
- `codesign --verify --deep --strict --verbose=4` passed for both
  `Filmtone.app` and `Filmtone-1.15.dmg`.
- `xcrun stapler validate` passed for both `Filmtone.app` and
  `Filmtone-1.15.dmg`.
- `bun run release:upload-dmg -- --confirm-prod --sync-vercel-env` uploaded
  `Filmtone-1.15.dmg` to
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.15.dmg`
  and synced `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- Vercel remote redeploy refreshed the fixed download page to production URL
  `https://chibatakumi-portfolio-8t8idhvq6-forestones-projects.vercel.app`.
- `curl -L -s https://www.chibatakumi.studio/film-lab/download` contains
  `Filmtone-1.15.dmg`.
- Public DMG `HEAD` returned `200`, `content-disposition:
  attachment; filename="Filmtone-1.15.dmg"`, and `content-length: 22837689`.
- `bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
  uploaded update metadata with `latestVersion: "1.15"` and synced
  `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`.
- Vercel remote redeploy refreshed the production deployment after
  update-check env sync to production URL
  `https://chibatakumi-portfolio-edvob0vpa-forestones-projects.vercel.app`.
- Public update metadata:
  `{"schemaVersion":1,"latestVersion":"1.15","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- Final `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`
  reports public Desktop latest `1.15`, native marketing version `1.15`, and
  native build `11`.
- Final iOS truth check reports public App Store version `1.13`; local Xcode
  candidate remains `1.11` build `15`. No local iOS ahead commit applies.

## Release Result

- Desktop v1.15 is public through the fixed download page and update metadata.
- Official artifact: `apps/filmtone-desktop-macos/build/release/1.15/Filmtone-1.15.dmg`.
- SHA-256: `0e7fc9d31484d319759d21044d572e1d9fc48eabdcbea1b93082ac9d32e14d29`.
- Public update metadata reports `latestVersion: "1.15"`.
- The release includes the June 2 Desktop Film Damage export integration,
  SDR RGBA8 export context speed improvement, FHD default video export, and
  explicit 4K export choice/warning.

## Copy / History Impact

- Copy / History Impact: Desktop release notes were added for v1.15, and the
  release copy is limited to shipped Desktop export behavior. No App Store or
  public article copy is changed in this task.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note; this release documents why normal
  Desktop video export now defaults to FHD while 4K is kept as an explicit
  slower path.

Done conditions:
- Desktop v1.15 local source version and release notes are coherent with public
  Desktop v1.14.
- The release artifact is signed, notarized, stapled, Gatekeeper accepted, and
  uploaded.
- Public Desktop update metadata reports `latestVersion: "1.15"`.
- Truth script confirms the public Desktop release state after upload.

Stop conditions:
- Done conditions met.
- Notarization, signing, or public upload credentials are unavailable after
  normal project env lookup.
- 3 consecutive verification failures on the same unresolved root cause.

Out of scope:
- Mac App Store submission.
- Portfolio submodule bump unless explicitly requested.
- New Film Damage kernel work beyond the current HEAD.
- Git staging, commit, push, or tag creation unless explicitly requested.

Unexpected blockers:
- 1Password MCP authentication timed out after 120s, so notarization used the
  existing local developer env file without printing secret values.
- The local portfolio worktree was dirty, so both portfolio refreshes used
  Vercel remote redeploy of existing production deployments instead of a local
  `vercel deploy`.
