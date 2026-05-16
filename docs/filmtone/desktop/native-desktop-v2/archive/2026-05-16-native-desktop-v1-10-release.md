# Active - Native Desktop v1.10 Release

Date opened: 2026-05-16 JST
Milestone: M12 Native Desktop v1.10 Release

## Goal

Publish Desktop v1.10 as a focused follow-up to v1.9, restoring the Adjust rail
default so parameter groups start collapsed while preserving the inline Adjust
surface and manual expansion behavior.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.10.md`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/AdvancedAdjustEditor.swift`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-16-adjust-inline-collapsed-default-follow-up.md`

## Read-Only References

- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.9.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-16-native-desktop-v1-9-release.md`

## Copy / Release Notes Brief

- Primary reader: an existing Mac user who installed or saw v1.9 and noticed
  the Adjust rail opening too much at once.
- Moment: reading a focused follow-up release note before replacing the app.
- Unresolved feeling: whether the new Adjust rail is still too dense by default.
- Next action: install the Mac update if the compact default matters.
- Not for: broad product positioning or iOS copy.
- Claim class: Candidate until DMG/upload/update-meta verification passes; then
  Public Now.
- Source evidence: local Desktop source, release verification, and release truth
  scripts.
- Reversibility buffer: notes describe only default expansion state and do not
  claim broader UI redesign or color pipeline changes.

## Checklist

- [x] Run release truth scripts before version/public-state claims.
- [x] Confirm no prior `active.md` is open.
- [x] Bump native Desktop marketing/build version to `1.10` / `7`.
- [x] Draft Desktop v1.10 release notes.
- [x] Run release/product verification gates.
- [x] Build, sign, notarize, and staple the macOS app.
- [x] Package and verify `Filmtone-1.10.dmg`.
- [x] Upload the DMG to the production Desktop rail.
- [x] Publish update metadata with `latestVersion: "1.10"`.
- [x] Verify public download/update metadata truth.
- [x] Commit, tag, and push the release source.
- [x] Record verification, archive this active task, and update `strategy.md`.

## Verification

- `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:cutover-preflight`
  passed before build; rerun after the DMG existed also passed.
- `bun run verify:desktop` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: `146/146`.
- `bun run build:core` passed.
- `bun run verify:filmtone-mcp` passed: `10 pass`, `0 fail`.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.
- `scripts/release-macos.sh` produced a signed, notarized, stapled
  `Filmtone.app`; `spctl --assess --type execute` accepted it as Notarized
  Developer ID.
- `scripts/package-dmg.sh` produced signed, notarized, stapled
  `apps/filmtone-desktop-macos/build/release/1.10/Filmtone-1.10.dmg`;
  `spctl --assess --type open --context context:primary-signature` accepted it.
- `hdiutil verify apps/filmtone-desktop-macos/build/release/1.10/Filmtone-1.10.dmg`
  passed.
- Mounted DMG app Info.plist reports version `1.10`, build `7`, bundle id
  `com.chibatakumi.film-lab-desktop`.
- DMG sha256:
  `009d82ed75e80458b4e027c1981031965337fec5dd32365f1bfd1e8aa7314f5a`.
- `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-dmg -- --confirm-prod --sync-vercel-env`
  uploaded the DMG and synced `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- `bunx vercel@50 deploy --prod --yes` completed production deploy
  `chibatakumi-portfolio-j5m43yzkw-forestones-projects.vercel.app`, aliased to
  `www.chibatakumi.studio`, after the download URL sync.
- Fixed download complete page contains `Filmtone-1.10.dmg` and the public DMG
  URL.
- `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
  uploaded update metadata with `latestVersion: "1.10"` and synced
  `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`.
- A second `bunx vercel@50 deploy --prod --yes` completed production deploy
  `chibatakumi-portfolio-8brtpn339-forestones-projects.vercel.app`, aliased to
  `www.chibatakumi.studio`, after update-check env sync.
- Public update metadata:
  `{"schemaVersion":1,"latestVersion":"1.10","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- Release truth script reports public Desktop latest `1.10`, native marketing
  version `1.10`, and native build `7`. Source-control commit/tag/push is
  completed after this archive file becomes part of the release source commit.
- iOS truth script reports public App Store version `1.9` and local Xcode
  candidate `1.10` build `10`; this is separate from Desktop release truth.

## Release Result

- Public update metadata:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
  reports `latestVersion: "1.10"`.
- Fixed download page:
  `https://www.chibatakumi.studio/film-lab/download` redirects to the current
  Filmtone download page; the download complete page returns
  `Filmtone-1.10.dmg`.
- Public DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.10.dmg`
- DMG sha256:
  `009d82ed75e80458b4e027c1981031965337fec5dd32365f1bfd1e8aa7314f5a`.
- Production deployment:
  `https://chibatakumi-portfolio-8brtpn339-forestones-projects.vercel.app`
  aliased to `https://www.chibatakumi.studio`.

## Copy / History Impact

- Public copy update required: v1.10 release notes, because this publishes a
  focused Desktop follow-up.
- Implementation history update required: none; this release does not change the
  runtime architecture or source-of-truth story.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Release-note only.

## Done Conditions

- Public update metadata reports Desktop `1.10`.
- Fixed Desktop download rail resolves to the notarized `Filmtone-1.10.dmg`.
- DMG is signed, notarized, stapled, Gatekeeper accepted, and checksum recorded.
- Release source is committed, tagged `desktop-v1.10`, and pushed without
  including unrelated iOS dirty files.
- `active.md` is archived with verification and no release task remains open.

## Stop Conditions

- Stop if signing/notarization credentials are unavailable.
- Stop if production upload or update metadata publication fails.
- Stop after 3 consecutive failures of the same verification step.
- Stop if unrelated iOS dirty files become necessary to stage or modify.

## Out Of Scope

- New editing UI features beyond restoring collapsed defaults.
- Legacy Electron Desktop changes.
- iOS release or App Store metadata changes.
- Portfolio implementation changes outside release upload/env synchronization.

## Unexpected

- Existing iOS files are dirty before this release task. They are unrelated user
  work and must remain out of the Desktop release commit.
