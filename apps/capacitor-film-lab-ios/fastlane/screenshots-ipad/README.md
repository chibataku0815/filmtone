# Filmtone Studio App Store Screenshots

Staged App Store screenshots for the separate Filmtone Studio tablet app.

## Current Set

- Five localized screenshots per locale.
- Locales: `ja`, `en-US`, `en-GB`.
- Size: `2732x2048` landscape.
- `en-GB` intentionally reuses the `en-US` image set.
- Source campaign: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/artifacts/2026-05-22-filmtone-ipad-app-store-screenshots/final/en-US/`.

## QA Notes

- Visible product mark is `Filmtone Studio`.
- The generated vertical simulator captures under `fastlane/.generated/screenshots-ipad*` are not the release set.
- Run `bundle exec fastlane ios ipad_preflight` from this directory before any App Store Connect upload.
- Run `IPAD_APP_VERSION=1.1 bundle exec fastlane ios ipad_upload_assets` to upload only metadata and screenshots. This lane does not upload a binary or submit for review.
