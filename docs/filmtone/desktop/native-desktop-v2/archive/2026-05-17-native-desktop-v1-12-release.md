# Native Desktop v1.12 Release

Date opened: 2026-05-17 JST
Milestone: M13 / Native Desktop v1.12 Release

## Goal

Publish the user-confirmed Native Desktop build with Rec.709-safe Built-in Look
color variants as Desktop v1.12, without changing the legacy Electron rail or
iOS release state.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.12.md`
- This `active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only after public
  verification succeeds

## Read-Only References

- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `scripts/release-macos.sh`
- `scripts/package-dmg.sh`
- `scripts/upload-dmg-to-vercel-blob.mjs`
- `scripts/upload-update-meta-to-vercel-blob.mjs`

## Checklist

- [x] Confirm Desktop release truth before mutation.
- [x] Bump Native Desktop marketing/build version to `1.12` / `9`.
- [x] Add scoped v1.12 release notes.
- [x] Run Desktop verification and release preflight.
- [x] Build, sign, notarize, staple, and package `Filmtone-1.12.dmg`.
- [x] Upload DMG to Vercel Blob.
- [x] Upload update metadata as the final public switch.
- [x] Verify public update metadata and download URL.
- [x] Record verification, archive this task, and update strategy.

## Verification

- 2026-05-17: `check-filmtone-release-truth.sh` reports local Native Desktop
  `1.12` build `9`, public update metadata still `1.11`, latest tag
  `desktop-v1.11`.
- 2026-05-17: `bun run verify:desktop` passed.
- 2026-05-17: `apps/filmtone-desktop-macos/Verify/run.sh` passed
  `154/154`.
- 2026-05-17: `bun run release:cutover-preflight` passed with the expected
  pre-DMG warning only.
- 2026-05-17: `git diff --check` passed.
- 2026-05-17: `bun run check:filmtone-copy` passed.
- 2026-05-17: `bun run check:filmtone-context` passed.
- 2026-05-17: `scripts/release-macos.sh 1.12` passed; app is notarized,
  stapled, and `spctl --assess --type execute` accepted it as Notarized
  Developer ID.
- 2026-05-17: `scripts/package-dmg.sh 1.12` passed; DMG is notarized,
  stapled, and `spctl --assess --type open` accepted it as Notarized
  Developer ID.
- 2026-05-17: `hdiutil verify` passed for `Filmtone-1.12.dmg`.
- 2026-05-17: `codesign --verify --deep --strict --verbose=4` passed for the
  release app.
- 2026-05-17: `Filmtone-1.12.dmg` sha256:
  `bafaed774a08f2679f44cdb21ebcbfe3b8339592b0534f4822fe81f9877c00b7`.
- 2026-05-17: `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-dmg -- --confirm-prod --sync-vercel-env`
  uploaded `Filmtone-1.12.dmg` and synced
  `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- 2026-05-17: Vercel redeploy
  `dpl_B17mr4PJweKeEcJ5GLa2LyrjjDA3` refreshed the fixed download page after
  the download URL sync.
- 2026-05-17: Fixed download page contains `Filmtone-1.12.dmg`; direct Blob
  URL returns `content-disposition: attachment; filename="Filmtone-1.12.dmg"`
  and `content-length: 22756263`.
- 2026-05-17: `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
  uploaded update metadata with `latestVersion: "1.12"` and synced
  `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`.
- 2026-05-17: Vercel redeploy
  `dpl_FntjkRcd1mKWAMQBmQ233aJ8zmEP` completed production deployment
  `https://chibatakumi-portfolio-deub3aj0j-forestones-projects.vercel.app`
  and aliased it to `https://www.chibatakumi.studio`.
- 2026-05-17: Public update metadata:
  `{"schemaVersion":1,"latestVersion":"1.12","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- 2026-05-17: Release truth script reports public Desktop latest `1.12`,
  native marketing version `1.12`, and native build `9`.

## Release Result

- Public update metadata:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
  reports `latestVersion: "1.12"`.
- Fixed download page:
  `https://www.chibatakumi.studio/film-lab/download` redirects to the current
  Filmtone download page, and the download complete page returns
  `Filmtone-1.12.dmg`.
- Public DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.12.dmg`
- DMG sha256:
  `bafaed774a08f2679f44cdb21ebcbfe3b8339592b0534f4822fe81f9877c00b7`.
- Production deployment:
  `https://chibatakumi-portfolio-deub3aj0j-forestones-projects.vercel.app`
  aliased to `https://www.chibatakumi.studio`.
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh`
- `bun run verify:desktop`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run release:cutover-preflight`
- `git diff --check`
- `bun run check:filmtone-copy`
- `bun run check:filmtone-context`

## Done Conditions

- Public update metadata reports `latestVersion: "1.12"`.
- Fixed Desktop download rail points to `Filmtone-1.12.dmg`.
- The DMG is signed, notarized, stapled, and Gatekeeper accepted.
- Release notes include the final DMG checksum.

## Stop Conditions

- Done conditions met.
- Unexpected release-script, notarization, or upload failure that cannot be
  resolved without changing signing/distribution assumptions.
- Three consecutive failures in the same verification or upload step.

## Out Of Scope

- iOS release/upload.
- Legacy Electron Desktop.
- Public landing-page copy beyond the existing fixed Desktop download rail.
- User-imported LUT behavior changes.

## Unexpected Blockers

- None yet.

## Copy / History Impact

- Release-note only. The release changes product behavior for Desktop Built-in
  Looks, but does not require public LP or implementation-history wording before
  the core release.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note later if the full iOS/Desktop
  source-aware Look approach needs to be explained publicly.
