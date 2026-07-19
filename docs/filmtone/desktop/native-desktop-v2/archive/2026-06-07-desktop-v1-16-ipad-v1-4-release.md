# Active: Desktop v1.16 And iPad v1.4 Release

Date opened: 2026-06-07 JST
Milestone: Release coordination

## Goal

Ship the current Filmtone Desktop direct-download release and the separate
Filmtone Studio iPad App Store rail without mixing iPhone and iPad identities.

## Release Targets

- Desktop direct-download rail: next candidate `1.16`, build `12`.
- iPad App Store rail: next candidate `1.4`, build `16`, bundle
  `com.chibatakumi.film.lab.ipad`, scheme `App-iPad`, payload
  `Payload/App-iPad.app`.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.16.md`
- `apps/capacitor-film-lab-ios/fastlane/metadata-ipad/*/release_notes.txt`
- Release docs only as needed for the final log.

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `docs/filmtone/filmtone-release-version-sources.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `apps/capacitor-film-lab-ios/RELEASE.md`
- `apps/capacitor-film-lab-ios/fastlane/Fastfile`

## Checklist

- [x] Confirm public/current release truth for Desktop and iPad.
- [x] Bump Desktop candidate version/build and write release notes.
- [x] Update iPad What's New for the candidate release.
- [x] Verify Desktop and iPad candidate builds.
- [x] Archive/sign/notarize/package Desktop DMG.
- [x] Upload Desktop DMG and update public update metadata.
- [x] Archive iPad IPA with `App-iPad` identity and verify payload.
- [x] Upload iPad binary/assets and submit review after processing when allowed.
- [x] Rerun truth checks and record final state.
- [x] Archive this active task.

## Verification

- Truth scripts:
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh`
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh`
- Desktop:
  - `bun run verify:desktop`
  - `bash apps/filmtone-desktop-macos/Verify/run.sh`
  - `bun run verify:macos`
  - `bun run release:cutover-preflight`
  - `scripts/release-macos.sh`
  - `scripts/package-dmg.sh`
  - `bun run release:upload-dmg -- --confirm-prod --sync-vercel-env`
  - `bun run release:upload-update-meta -- --confirm-prod --sync-vercel-env`
- iPad:
  - `bun run verify:ios`
  - `xcodebuild -quiet -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App-iPad -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`
  - `bun run --cwd apps/capacitor-film-lab-ios release:ipad-preflight`
  - `IPAD_APP_VERSION=1.4 IPAD_BUILD_NUMBER=16 bun run --cwd apps/capacitor-film-lab-ios release:ipad-archive`
  - `IPAD_APP_VERSION=1.4 IPAD_BUILD_NUMBER=16 IPAD_IPA_PATH=... bun run --cwd apps/capacitor-film-lab-ios release:ipad-release`
  - `IPAD_APP_VERSION=1.4 IPAD_BUILD_NUMBER=16 bun run --cwd apps/capacitor-film-lab-ios release:ipad-submit-review`
- Shared:
  - `bun run check:filmtone-copy`
  - `bun run check:filmtone-context`
  - `git diff --check`

## Done Conditions

- Desktop public update metadata reports `latestVersion: "1.16"` and the fixed
  download rail serves the notarized `Filmtone-1.16.dmg`.
- iPad App Store Connect has the correct `App-iPad` build uploaded for version
  `1.4` build `16`, and review submission is completed or explicitly blocked
  by App Store Connect processing state.
- No iPhone rail upload is performed.
- Verification failures are resolved or documented as blockers.

## Stop Conditions

- Wrong-rail identity is detected for any IPA.
- Notarization, signing, Vercel upload, App Store Connect auth, or App Store
  review submission fails 3 consecutive times on the same command.
- The release would require publishing unrelated or unverified dirty-tree work.

## Out Of Scope

- iPhone App Store release.
- Legacy Electron Desktop release.
- Portfolio submodule bump unless explicitly requested.
- New product features beyond release notes/version metadata.

## Unexpected Blockers

- iPad `ipad_submit_review` immediately after binary upload failed once with
  `Build number: 16 does not exist`, because App Store Connect had not finished
  processing the uploaded build. After a 3-minute wait, the same lane selected
  build `1.4 (16)` and submitted successfully.

## Verification Results

- `bun run check:filmtone-copy`: passed.
- `bun run check:filmtone-context`: passed.
- `git diff --check`: passed before and after release work.
- `bun run verify:desktop`: passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh`: `165/165` passed.
- `bun run verify:macos`: passed.
- `bun run release:cutover-preflight`: passed with the v1.16 DMG present.
- Desktop app notarization/staple/Gatekeeper: passed.
- Desktop DMG notarization/staple/Gatekeeper: passed.
- `bun run verify:ios`: passed.
- `xcodebuild -quiet ... -scheme App-iPad ... CODE_SIGNING_ALLOWED=NO`: passed.
- `bun run --cwd apps/capacitor-film-lab-ios release:ipad-preflight`: passed.
- iPad IPA identity:
  - Payload: `Payload/App-iPad.app`
  - Bundle ID: `com.chibatakumi.film.lab.ipad`
  - Version/build: `1.4` / `16`
  - UIDeviceFamily: `[2]`
  - Executable: `App-iPad`
  - Extension bundle: `com.chibatakumi.film.lab.ipad.exportactivity`
- iPad upload:
  - Binary upload to App Store Connect: passed.
  - App Store metadata upload: passed.
  - Screenshot upload + ASC checksum/order verification: passed for `ja`,
    `en-US`, and `en-GB` on 12.9-inch and 11-inch iPad display sets.
  - Review submission: passed with `AUTOMATIC_RELEASE=1`.
- Truth checks after release:
  - Desktop public update metadata reports `latestVersion: "1.16"`.
  - Desktop public download page contains `Filmtone-1.16.dmg` and no longer
    contains `Filmtone-1.15.dmg`.
  - Public iPad App Store lookup remains `1.3` until App Review approves v1.4.

## Final State

- Desktop v1.16 build 12 is public on the direct-download rail.
- Desktop DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.16.dmg`
- Desktop update metadata:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
- Desktop DMG SHA-256:
  `9df8b1d51350fe40d7338aa8f3527f815b1097301db878886dc2d5d2e91dc1d9`
- Portfolio production deploy completed:
  `dpl_GaJLbYqMDZdxkrdn6suxViWRvFB4`, aliased to
  `https://www.chibatakumi.studio`.
- iPad v1.4 build 16 was submitted to App Review for
  `com.chibatakumi.film.lab.ipad` with automatic release enabled.

## Copy / History Impact

- Copy / History Impact: Release notes were updated for Desktop v1.16 and iPad
  v1.4 to describe Film Damage texture and render overhead improvements.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note; the release preserves the separate
  Desktop direct-download and iPad App Store rails, including the iPad-only
  `App-iPad` identity guard.
