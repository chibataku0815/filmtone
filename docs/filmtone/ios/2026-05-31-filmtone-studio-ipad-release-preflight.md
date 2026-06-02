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
- After submission, App Store Connect reported version `1.1` as `WAITING_FOR_REVIEW`, build `1.1 (3)` as `VALID`, and `releaseType=AFTER_APPROVAL`.

## TestFlight 1.2

- 2026-06-02 JST: Public lookup and ASC confirmed `com.chibatakumi.film.lab.ipad` version `1.1` is already released, so the next TestFlight candidate is `1.2`.
- Updated the iPad release rail default from `1.1` to `1.2` and added `ipad_beta` for Filmtone Studio TestFlight uploads.
- Exported an iPad-only `1.2 (4)` IPA from the `1.1 (3)` iPad archive, changing only App Store version/build metadata.
- Uploaded `1.2 (4)` with `ipad_beta`; App Store Connect processed it as `VALID` and distributed it to the internal `in-house` TestFlight group.
- Follow-up report from TestFlight showed the iPad build still surfaced the iPhone-side display name, the 1.2 screenshots did not show the latest Film Damage control, and Film Damage was buried inside Advanced controls.
- Added an explicit `ipad_archive` lane for fresh iPad archives with `com.chibatakumi.film.lab.ipad`, a separate export activity extension id, iPad-only device family, `Filmtone Studio` display name, and App Store/iPad orientation requirements.
- Moved Film Damage to its own top-level adjustment sheet section while keeping Dust and Scratches in the existing parameter model.
- Updated screenshot 04 for `ja`, `en-US`, and `en-GB` to include Film Damage, then uploaded the refreshed 1.2 metadata/screenshots with `ipad_upload_assets`.
- `1.2 (5)` was built with the new display name but failed App Store Connect upload validation because the first archive-lane draft also applied the app bundle id to the extension and lacked the iPad-specific orientation key.
- `1.2 (6)` was later identified as an invalid iPad candidate: the lane archived the iPhone `App` scheme with iPad identity overrides. The resulting IPA contained `Payload/App.app` and `FilmtoneExportActivity.appex`, so it was not the native `App-iPad` build. App Store Connect build `1.2 (6)` was expired on 2026-06-02 JST.
- Restored the native `App-iPad` scheme/target and iPad workspace sources, then changed `ipad_archive` to archive `scheme: "App-iPad"` without overriding the app/extension bundle identifiers or device family at archive time.
- Added Film Damage to the iPad Advanced Adjust catalog as a top-level group and wired the iPad workspace route through `FilmtonePadWorkspaceView`.
- Verified the corrected local route with `check-pad-route` and an `App-iPad` Debug build.
- Archived `1.2 (8)` from the native `App-iPad` target. IPA inspection confirmed `Payload/App-iPad.app`, executable `App-iPad`, bundle id `com.chibatakumi.film.lab.ipad`, `UIDeviceFamily = [2]`, and `PlugIns/FilmtoneExportActivityIPad.appex`.
- Uploaded `1.2 (8)` with `ipad_beta`; App Store Connect processed it as `VALID` and distributed it to internal TestFlight testers on 2026-06-02 JST. App Store Connect now shows `1.2 (8)` as `IN_BETA_TESTING` and `1.2 (6)` as `EXPIRED`.

Copy / History Impact: Public iPad screenshot asset update; screenshot 04 now names and shows Film Damage. App Store metadata text is unchanged.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note, because the iPad rail must archive the native `App-iPad` target. Identity overrides on the iPhone `App` target are an invalid release path.

## Copy / History Impact

Public copy update required: Filmtone Studio now has a tracked iPad-specific App Store metadata and screenshot asset source. The product copy remains scoped to large-preview editing, Look selection, comparison, and save/share/file export.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note, because this separates the iPad App Store asset lane from the existing iPhone/iOS release rail.
