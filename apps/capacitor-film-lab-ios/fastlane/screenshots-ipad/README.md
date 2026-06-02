# Filmtone Studio App Store Screenshots

Staged App Store screenshots for the separate Filmtone Studio tablet app.

## Current Set

- Five localized screenshots per locale.
- Locales: `ja`, `en-US`, `en-GB`.
- Size: `2732x2048` landscape.
- `en-GB` intentionally reuses the `en-US` image set.
- Source campaign: `/Volumes/SamsungPortableSSDX5001/documents/life/docs/artifacts/2026-05-22-filmtone-ipad-app-store-screenshots/final/en-US/`.
- 2026-06-02 JST: screenshot 04 was updated to include the current Film Damage control.

## QA Notes

- Visible product mark is `Filmtone Studio`.
- The generated vertical simulator captures under `fastlane/.generated/screenshots-ipad*` are not the release set.
- Run `bun run release:ipad-preflight` from `apps/capacitor-film-lab-ios/` before any App Store Connect upload.
- Run `IPAD_APP_VERSION=1.2 bun run release:ipad-assets` from `apps/capacitor-film-lab-ios/` to upload only metadata and screenshots. This lane does not upload a binary or submit for review.
