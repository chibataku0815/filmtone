# Native Desktop v2 Replacement Readiness

Date: 2026-05-05 JST
Branch: `feature/native-desktop-plan`
Current HEAD at drafting time: `f0e81e71`
Post-rollback truth HEAD: `60809f84`

## Purpose

Prepare the safe public cutover from legacy Electron Desktop to Native Desktop
v2. This is not the public release run. It defines what must be true before the
fixed Desktop download/update rail is pointed at the native v1.4 artifact.

## Cutover Attempt / Rollback Update

Public cutover was attempted on 2026-05-05, then rolled back after the user
clarified the desired order: correct the parent branch, merge `main`, then
release.

- Public update metadata is back to `latestVersion: "1.0.4"`.
- Native Desktop DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.4.dmg`
- DMG sha256:
  `a891ccfdba470cd68e39273130485e92d21a89f4f7879a0650baca57abff3e68`
- The fixed download path still starts at
  `https://www.chibatakumi.studio/film-lab/download` and routes into the
  Filmtone download surface.
- The public download complete page is back on the legacy Desktop DMG
  `filmtone-1.0.3-arm64.dmg`.
- The previously listed product parity gaps remain pre-release risks or
  explicit-defer candidates for the clean release run.

## Pre-Cutover Truth

Truth scripts run on 2026-05-05:

- Public Desktop latest: `1.0.4` from update metadata.
- Native Desktop release target: `1.4`.
- Local Native Desktop Bundle ID: `com.chibatakumi.film-lab-desktop`.
- Local Native Desktop product name: `Filmtone`.
- iOS public version: `1.4`.
- iOS local marketing version: `1.4`.

The root `package.json` version belongs to the legacy Electron workspace and is
not the Native Desktop release version source. Native Desktop release version is
read from `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`.

## Replacement Direction

- Native Desktop v2 replaces the Electron Desktop product lane for macOS 26+
  users.
- Electron Desktop `1.0.4` remains frozen legacy access for pre-macOS-26 users.
- The fixed public download page stays
  `https://www.chibatakumi.studio/film-lab/download`.
- The fixed update metadata pathname stays
  `film-lab/desktop/update-meta.json`.
- The update metadata switch is the last public step because Electron 1.0.4
  clients poll it and will show the upgrade prompt once `latestVersion` becomes
  `1.4`.

## Product Gates Before Public Cutover

Do not write production `update-meta.json` until these are true:

- Native Desktop visual smoke passes for opening, still preview, video
  playback, sidebar, Look/strength editing, compare, scrub thumbnail hover/drag,
  and export/share.
- Source profile auto-selection / conversion LUT behavior is either confirmed
  iOS-equivalent or explicitly deferred by the user.
- Backlight Veil parity is either implemented or explicitly deferred by the
  user.
- iOS-style advanced recipe chips (`None` / `Default` / `Strong`, Japanese
  `なし` / `標準` / `強め`) are either visible in the Desktop editing path or
  explicitly deferred by the user.
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

Only after the product gates are closed:

```bash
export ASC_KEY_ID=TM2BK9269B
export ASC_ISSUER_ID=<App Store Connect issuer UUID>
export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_TM2BK9269B.p8

bun run release:cutover-preflight
scripts/release-macos.sh
scripts/package-dmg.sh
bun run release:cutover-preflight
```

Then manually inspect the generated artifact:

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

Before switching update metadata, verify the fixed download page resolves to
the new DMG and still gives users a valid installer.

Switch update metadata last:

```bash
bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env
```

Then rerun:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
```

Expected after cutover:

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
rollback metadata body with `latestVersion: "1.0.4"` and the previous download
page / release notes values. Then redeploy portfolio if env values changed.

## Non-Goals

- Do not publish before the remaining product gates are closed or explicitly
  deferred.
- Do not archive or delete `apps/desktop-film-lab-batch/` in this prep step.
- Do not change the public download URL shape.
- Do not add Sparkle or background auto-update for v1.4.
- Do not lower the macOS target below `26.0`.

## Remaining Release Risks

- The attached iOS parity issues are real product confidence risks until closed
  or deferred.
- The final update-meta write is public and affects Electron 1.0.4 users on
  their next update check.
- Portfolio deployment must be verified after env changes; Blob upload alone is
  not the full public web update.
