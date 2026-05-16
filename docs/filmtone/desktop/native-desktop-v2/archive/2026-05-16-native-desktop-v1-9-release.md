# Active - Native Desktop v1.9 Release

Date opened: 2026-05-16 JST
Milestone: M11 Native Desktop v1.9 Release

## Goal

Publish Desktop v1.9 with the right editing rail changed from Quick axes to
inline Adjust parameters, and with bundled Look application no longer masking
direct parameter edits through duplicated user overrides.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.9.md`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/**`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/active.md`

## Read-Only References

- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-16-native-desktop-v1-8-release.md`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.8.md`

## Copy / Release Notes Brief

- Primary reader: an existing Mac user who noticed the right rail controls and
  wants to know what changed before replacing the app.
- Moment: reading the DMG release notes or update context before installing.
- Unresolved feeling: whether the old Quick sliders were unreliable, and
  whether the new rail still gives direct access to common adjustments.
- Next action: download/replace the Mac app if the denser Adjust rail is useful.
- Not for: App Store acquisition copy or broad Filmtone positioning.
- Claim class: Candidate until DMG/upload/update-meta verification passes; then
  Public Now.
- Source evidence: local Desktop source, v1.9 release verification, and release
  truth scripts.
- Reversibility buffer: notes describe the scoped rail behavior and override fix
  without claiming broader color parity or Resolve compatibility.

## Checklist

- [x] Run release truth scripts before version/public-state claims.
- [x] Confirm no prior `active.md` is open.
- [x] Bump native Desktop marketing/build version to `1.9` / `6`.
- [x] Draft Desktop v1.9 release notes.
- [x] Run release/product verification gates.
- [x] Build, sign, notarize, and staple the macOS app.
- [x] Package and verify `Filmtone-1.9.dmg`.
- [x] Upload the DMG to the production Desktop rail.
- [x] Publish update metadata with `latestVersion: "1.9"`.
- [x] Verify public download/update metadata truth.
- [x] Commit, tag, and push the release source.
- [x] Record verification, archive this active task, and update `strategy.md`.

## Verification

- `bun run release:cutover-preflight` passed before build; rerun with
  `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio`
  passed after the DMG existed.
- `bun run verify:desktop` passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed: `146/146`.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.
- `bun install` restored missing JS build dependencies in this worktree; its
  postinstall built core, renderer, and smart-look packages.
- `bun run build:core` passed after dependency install.
- `bun run verify:filmtone-mcp` passed: `10 pass`, `0 fail`.
- `scripts/release-macos.sh` produced a signed, notarized, stapled
  `Filmtone.app`; `spctl --assess --type execute` accepted it as Notarized
  Developer ID.
- `scripts/package-dmg.sh` produced signed, notarized, stapled
  `apps/filmtone-desktop-macos/build/release/1.9/Filmtone-1.9.dmg`;
  `spctl --assess --type open --context context:primary-signature` accepted it.
- `hdiutil verify apps/filmtone-desktop-macos/build/release/1.9/Filmtone-1.9.dmg`
  passed.
- Mounted DMG app Info.plist reports version `1.9`, build `6`, bundle id
  `com.chibatakumi.film-lab-desktop`.
- DMG sha256:
  `d3efb71b4d30e21f2935df4c35e616ca4286c9999b46d222b579b3fb56a8bf08`.
- `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-dmg -- --confirm-prod --sync-vercel-env`
  uploaded the DMG and synced `FILM_LAB_DESKTOP_DOWNLOAD_URL`.
- `bunx vercel@50 deploy --prod --yes` completed production deploy
  `chibatakumi-portfolio-hehwpwwcd-forestones-projects.vercel.app`, aliased to
  `www.chibatakumi.studio`, after the download URL sync.
- Fixed download complete page contains `Filmtone-1.9.dmg` and the public DMG
  URL.
- `PORTFOLIO_ROOT=/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
  uploaded update metadata with `latestVersion: "1.9"` and synced
  `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`.
- A second `bunx vercel@50 deploy --prod --yes` completed production deploy
  `chibatakumi-portfolio-bxfxgbe2j-forestones-projects.vercel.app`, aliased to
  `www.chibatakumi.studio`, after update-check env sync.
- Public update metadata:
  `{"schemaVersion":1,"latestVersion":"1.9","downloadPageUrl":"https://www.chibatakumi.studio/film-lab/download"}`.
- Release truth script reports public Desktop latest `1.9`, native marketing
  version `1.9`, and native build `6`. Source-control commit/tag/push is
  completed after this archive file becomes part of the release source commit.
- iOS truth script reports public App Store version `1.9` and local Xcode
  candidate `1.10` build `10`; this is separate from Desktop release truth.

## Release Result

- Public update metadata:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
  reports `latestVersion: "1.9"`.
- Fixed download page:
  `https://www.chibatakumi.studio/film-lab/download` redirects to the current
  Filmtone download page; the download complete page returns `Filmtone-1.9.dmg`.
- Public DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.9.dmg`
- DMG sha256:
  `d3efb71b4d30e21f2935df4c35e616ca4286c9999b46d222b579b3fb56a8bf08`.
- Production deployment:
  `https://chibatakumi-portfolio-bxfxgbe2j-forestones-projects.vercel.app`
  aliased to `https://www.chibatakumi.studio`.

## Copy / History Impact

- Public copy update required: v1.9 release notes, because this publishes the
  Quick-to-Adjust rail and bundled Look override fix.
- Implementation history update required: none; this release does not change the
  runtime architecture or source-of-truth story.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note, if documenting why the old Quick
  layer was retired in favor of direct parameter ownership.

## Done Conditions

- Public update metadata reports Desktop `1.9`.
- Fixed Desktop download rail resolves to the notarized `Filmtone-1.9.dmg`.
- DMG is signed, notarized, stapled, Gatekeeper accepted, and checksum recorded.
- Release source is committed, tagged `desktop-v1.9`, and pushed without
  including unrelated iOS dirty files.
- `active.md` is archived with verification and no release task remains open.

## Stop Conditions

- Stop if signing/notarization credentials are unavailable.
- Stop if production upload or update metadata publication fails.
- Stop after 3 consecutive failures of the same verification step.
- Stop if unrelated iOS dirty files become necessary to stage or modify.

## Out Of Scope

- Legacy Electron Desktop changes.
- iOS release or App Store metadata changes.
- Portfolio implementation changes outside release upload/env synchronization.
- New editing UI features beyond the already implemented rail change.

## Unexpected

- Existing iOS files are dirty before this release task. They are treated as
  unrelated user work and must remain out of the Desktop release commit.
- `bun install` regenerated `packages/film-lab-smart-look/dist/index.d.ts` to
  include current schema fields (`blackPoint`, `toeContrast`,
  `filmBreathAmount`). The dist file is tracked release source and is included
  with the Desktop release source, but it is not an iOS product change.
