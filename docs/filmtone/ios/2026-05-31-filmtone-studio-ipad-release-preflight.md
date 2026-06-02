# Filmtone Studio iPad Release Preflight

Date: 2026-05-31 JST

## Summary

- Prepared and uploaded the separate Filmtone Studio App Store asset lane for `com.chibatakumi.film.lab.ipad`.
- This does not change the iPhone/iOS app lane for `com.chibatakumi.film.lab.ios`.
- No submission, binary archive, build upload, or build-number change is included.

## Assets

- Metadata source: `apps/capacitor-film-lab-ios/fastlane/metadata-ipad/`
- Screenshot source: `apps/capacitor-film-lab-ios/fastlane/screenshots-ipad/`
- Validation lane: `bundle exec fastlane ios ipad_preflight`
- Upload lane: `IPAD_APP_VERSION=1.1 bundle exec fastlane ios ipad_upload_assets`

## Upload Result

- 2026-06-01 JST: Created or updated App Store Connect version `1.1` for `com.chibatakumi.film.lab.ipad`.
- Uploaded metadata and 15 screenshots through `ipad_upload_assets`.
- App Store Connect reports `1.1` as `PREPARE_FOR_SUBMISSION` with 5 screenshots per locale for `ja`, `en-US`, and `en-GB`.
- Fastlane precheck passed. No binary was uploaded and no App Review submission was performed.
- Public iTunes lookup still reports live version `1.0` and no public iPad screenshot URLs immediately after upload.

## Release Submission

- 2026-06-01 JST: Exported an iPad-only `1.1 (3)` IPA from the approved `1.0 (2)` iPad archive, changing only the App Store version/build metadata.
- Uploaded `1.1 (3)` with `ipad_release`; metadata, screenshots, review information, and binary upload succeeded.
- The first submit attempt stopped after build selection because App Store Connect required `whatsNew` for all three localizations.
- Added `ipad_submit_review`, synced `ja`, `en-US`, and `en-GB` release notes, then submitted the already uploaded `1.1 (3)` build.
- App Store Connect now reports version `1.1` as `WAITING_FOR_REVIEW`, build `1.1 (3)` as `VALID`, and `releaseType=AFTER_APPROVAL`.

## Copy / History Impact

Public copy update required: Filmtone Studio now has a tracked iPad-specific App Store metadata and screenshot asset source. The product copy remains scoped to large-preview editing, Look selection, comparison, and save/share/file export.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note, because this separates the iPad App Store asset lane from the existing iPhone/iOS release rail.
