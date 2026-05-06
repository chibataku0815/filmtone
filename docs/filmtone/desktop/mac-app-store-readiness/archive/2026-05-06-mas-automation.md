# Mac App Store Automation Task

Date: 2026-05-06

## Goal

Automate as much of the macOS App Store Connect release path as possible after
the app record and uploaded package existed.

## Changed

- Added a macOS fastlane harness under `apps/filmtone-desktop-macos/fastlane/`.
- Added lanes for metadata upload, package upload, combined release upload,
  guarded review submission, delivery status, and App Privacy boundary notes.
- Added env loading/status wrappers under `apps/filmtone-desktop-macos/scripts/`.
- Added localized `ja` / `en-US` Mac App Store metadata.
- Extended `bun run check:filmtone-copy` to validate macOS metadata alongside
  iOS metadata.
- Added root `release:macos-appstore:*` scripts.

## Executed

- `bun run release:macos-appstore:metadata` uploaded localized metadata and App
  Review information to App Store Connect.
- `DELIVERY_ID=759ae36e-be06-4251-8f6c-f48579c6dfbe bun run
  release:macos-appstore:status` confirmed the uploaded package remains
  `VALID` and App Store eligible.

## Verification

Passed:

- `bun run check:filmtone-copy`
- `bun run check:macos-appstore`
- `bash -n apps/filmtone-desktop-macos/scripts/load-release-env.sh`
- `bash -n apps/filmtone-desktop-macos/scripts/bundle.sh`
- `bash -n apps/filmtone-desktop-macos/scripts/release-env-status.sh`
- `ruby -c apps/filmtone-desktop-macos/fastlane/Fastfile`
- `FASTLANE_SKIP_UPDATE_CHECK=1 bash apps/filmtone-desktop-macos/scripts/bundle.sh exec fastlane lanes`
- `git diff --check`

## Remaining

- App Store screenshots still need to be staged or entered in App Store Connect.
- App Privacy remains outside the ASC API-key fastlane lane; use
  `apps/filmtone-desktop-macos/fastlane/app_privacy.md` as the answer draft.
- Review submission is gated by `SUBMIT_FOR_REVIEW=1` and
  `CONFIRM_METADATA_READY=1`.
