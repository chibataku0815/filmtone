# Native Desktop v2 Replacement Readiness

Date: 2026-05-05 JST
Branch: `feature/native-desktop-plan`
Current HEAD at drafting time: `f0e81e71`
Post-rollback truth HEAD: `60809f84`
Final release code HEAD: `4f2e5eba`

## Purpose

Prepare and record the safe public cutover from legacy Electron Desktop to
Native Desktop v2. The original purpose was pre-release readiness; the final
section now records the clean 2026-05-05 v1.4 public switch after parent branch
correction and `origin/main` merge.

## Final Cutover Update

Public cutover completed on 2026-05-05 after the user-directed order was
honored: correct the parent branch, merge `main`, then release.

- Public update metadata reports `latestVersion: "1.4"`.
- Native Desktop DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.4.dmg`
- DMG sha256:
  `40d2b2fd745c648849d310856e2bcd5d0db0afd948b3842fd83800f68e705cb8`
- The fixed download path still starts at
  `https://www.chibatakumi.studio/film-lab/download` and routes into the
  Filmtone download surface.
- The public download complete page references `Filmtone-1.4.dmg`.
- Production Vercel deployment:
  `chibatakumi-portfolio-1bttmm5np-forestones-projects.vercel.app`, aliased to
  `https://www.chibatakumi.studio`.
- Release truth script reports public Desktop latest `1.4`.

The first public attempt earlier on 2026-05-05 was rolled back when the user
clarified the desired order. That rollback is preserved in the archive as
historical evidence; it is superseded by this final clean release.

## Final Truth

Truth scripts latest rechecked on 2026-05-06:

- Public Desktop latest: `1.4` from update metadata.
- Native Desktop release version: `1.4`.
- Local Native Desktop Bundle ID: `com.chibatakumi.film-lab-desktop`.
- Local Native Desktop product name: `Filmtone`.
- iOS public version at the original readiness check: `1.4`.
- iOS public version from the 2026-05-06 15:12 JST truth refresh: `1.5`.
- iOS local Xcode candidate: `1.5` build `4`.

The root `package.json` version belongs to the legacy Electron workspace and is
not the Native Desktop release version source. Native Desktop release version is
read from `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`.

## Replacement Direction

- Native Desktop v2 replaces the Electron Desktop product lane for macOS 26+
  users.
- Legacy Electron Desktop source remains frozen for pre-macOS-26 access and
  emergency rollback; it is not the current Desktop release version source.
- The fixed public download page stays
  `https://www.chibatakumi.studio/film-lab/download`.
- The fixed update metadata pathname stays
  `film-lab/desktop/update-meta.json`.
- The update metadata switch is the last public step because Electron 1.0.4
  clients poll it and will show the upgrade prompt once `latestVersion` becomes
  `1.4`.

## Product Gates For Public Cutover

Production `update-meta.json` was written only after these were true:

- Native Desktop visual smoke passes for opening, still preview, video
  playback, sidebar, Look/strength editing, compare, scrub thumbnail hover/drag,
  and export/share.
- Source profile auto-selection / conversion LUT behavior landed in M5-L1.
- Backlight Veil parity landed in M5-L3.
- iOS-style advanced recipe chips (`None` / `Default` / `Strong`, Japanese
  `なし` / `標準` / `強め`) landed in M5-L2.
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passes.
- `bun run verify:macos` passes.
- `git diff --check` is clean.

## Dry-Run / Preflight

Run this before any release run:

```bash
bun run release:cutover-preflight
```

The preflight is read-only. It checks:

- `MARKETING_VERSION = 1.4`
- `PRODUCT_NAME = Filmtone`
- `PRODUCT_BUNDLE_IDENTIFIER = com.chibatakumi.film-lab-desktop`
- `RELEASE_NOTES-v1.4.md` exists
- release scripts use the cutover identity
- upload scripts still require `--confirm-prod`
- public update metadata has not already moved unexpectedly

The preflight may warn that `Filmtone-1.4.dmg` does not exist before the release
artifact is built. That warning is expected during planning.

## Public Cutover Run Order

Completed run order:

```bash
export ASC_KEY_ID=TM2BK9269B
export ASC_ISSUER_ID=<App Store Connect issuer UUID>
export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8

bun run release:cutover-preflight
scripts/release-macos.sh
scripts/package-dmg.sh
bun run release:cutover-preflight
```

Manual inspection checkpoint:

```bash
open apps/filmtone-desktop-macos/build/release/1.4/Filmtone-1.4.dmg
```

Confirm:

- `Filmtone.app` installs over the old Desktop app identity.
- `spctl` / Gatekeeper accepts the app and DMG.
- The launched app reports Bundle ID `com.chibatakumi.film-lab-desktop`.
- The app opens stills and videos and can export.

Upload the DMG first:

```bash
bun run release:upload-dmg -- --confirm-prod --sync-vercel-env
```

Before switching update metadata, the fixed download page was verified to
resolve to the new DMG and still give users a valid installer.

Switch update metadata last:

```bash
bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env
```

Then rerun:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Actual after cutover:

- public update metadata `latestVersion` is `1.4`
- public download page points to the Native Desktop DMG
- Electron 1.0.4 clients see the v1.4 upgrade prompt

## Rollback Notes

Capture the current production values before upload:

- `FILM_LAB_DESKTOP_DOWNLOAD_URL`
- `FILM_LAB_DESKTOP_UPDATE_CHECK_URL`
- current public `update-meta.json`

If failure happens before `update-meta.json` is switched, users should not see a
new update prompt. Restore the download URL env if it was changed.

If failure happens after `update-meta.json` is switched, immediately upload a
rollback metadata body with the previous public Desktop latest version and the
previous download page / release notes values. For the M7 v1.5 lane, the
rollback target is currently `latestVersion: "1.4"`; for the original v1.4
cutover it was `latestVersion: "1.0.4"`. Then redeploy portfolio if env values
changed.

## Non-Goals

- Do not use readiness prep as permission to publish before product gates close
  or are explicitly deferred.
- Do not archive or delete `apps/desktop-film-lab-batch/` in this prep step.
- Do not change the public download URL shape.
- Do not add Sparkle or background auto-update for v1.4.
- Do not lower the macOS target below `26.0`.

## Remaining Release Risks

- The iOS parity issues that blocked readiness were closed before the clean
  release, but broader real-media population testing is still needed.
- The final update-meta write is public and affects Electron 1.0.4 users on
  their next update check.
- Portfolio production deployment was verified after env changes; source-level
  portfolio submodule permanence remains a post-release follow-up.
