# Mac App Store Readiness

This lane tracks the first Mac App Store-ready Filmtone Desktop build. It is
separate from Native Desktop v2 M5-M work and uses:

- Worktree:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-mac-app-store-readiness`
- Branch: `feature/macos-app-store-readiness`
- Bundle ID: `com.chibatakumi.film-lab-desktop`

## Scope

Done in this lane:

- Add a Mac App Store archive/export lane without changing the existing
  Developer ID DMG lane.
- Add Mac App Store sandbox entitlements.
- Preserve user-selected read/write access for open/export flows.
- Keep sidecar JSON output adjacent to the selected export file.
- Add checks that protect the Developer ID lane from accidental MAS changes.

Still not included:

- Screenshots, unless staged under
  `apps/filmtone-desktop-macos/fastlane/screenshots/` and uploaded with
  `UPLOAD_SCREENSHOTS=1`.
- Final App Privacy submission in App Store Connect.
- Review submission or public release switch.
- Universal Purchase with the existing iOS app.
- Human GUI smoke of the installed/exported build with real still, landscape
  video, and portrait iPhone video sources.

## Current State

The active readiness task is complete and archived at:

- `archive/2026-05-05-mas-readiness.md`

The local Mac App Store export proof produced:

- `apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`

The export completed locally. Xcode also reported a missing stored Xcode account
token for `info@adoyosu.com`, but this did not block local package export.

Before App Store Connect upload, run one final human GUI smoke on the exported or
installed MAS-style build: open one still, one landscape video, and one portrait
iPhone video, then export each to a chosen non-container folder and confirm media
plus sidecar JSON are present.

## Release Attempt Log

2026-05-05:

- Rebuilt the MAS package from `main`:
  `apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`
- Confirmed Developer Portal Bundle ID exists:
  `com.chibatakumi.film-lab-desktop`
- App Store Connect validation is blocked because no macOS app record currently
  resolves for `com.chibatakumi.film-lab-desktop` / `MAC_OS`.
- Exact validation error:
  `Cannot determine the Apple ID from Bundle ID 'com.chibatakumi.film-lab-desktop' and platform 'MAC_OS'.`

2026-05-06:

- Confirmed the macOS App Store Connect app record exists:
  Apple ID `6766605429`, Bundle ID `com.chibatakumi.film-lab-desktop`, SKU
  `filmtone-macos`.
- `altool --validate-app` passed for
  `apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`.
- `altool --upload-package --wait` passed.
- Delivery UUID: `759ae36e-be06-4251-8f6c-f48579c6dfbe`
- ASC processing status: `VALID`
- Uploaded build: `CFBundleShortVersionString=1.4`, `CFBundleVersion=1`,
  App Store eligible.
- Added fastlane automation for the macOS App Store lane:
  metadata upload, pkg upload, combined release upload, delivery status, guarded
  review submission, and App Privacy boundary reporting.
- Uploaded localized `ja` / `en-US` metadata and App Review information through
  `bun run release:macos-appstore:metadata`.
- Confirmed delivery status through
  `DELIVERY_ID=759ae36e-be06-4251-8f6c-f48579c6dfbe bun run release:macos-appstore:status`;
  processing remained `VALID` and App Store eligible.

Remaining before review submission:

- Add Mac App Store screenshots in App Store Connect or stage them under
  `apps/filmtone-desktop-macos/fastlane/screenshots/` and run with
  `UPLOAD_SCREENSHOTS=1`.
- Set App Privacy answers. The current local-first answer draft is
  `apps/filmtone-desktop-macos/fastlane/app_privacy.md`.
- Submit with `SUBMIT_FOR_REVIEW=1 CONFIRM_METADATA_READY=1 bun run
  release:macos-appstore:submit-review` after screenshots and privacy are set.
