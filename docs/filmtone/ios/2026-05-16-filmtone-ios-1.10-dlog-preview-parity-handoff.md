# Filmtone iOS 1.10 D-Log Preview Parity Handoff

Date: 2026-05-16 JST

## Release Truth

- Public App Store version: `1.9` from `check-filmtone-ios-truth.sh`.
- Local candidate: `1.10` build `13`.
- TestFlight build: `1.10 (13)` was archived, uploaded, processed, and
  distributed to Internal testers on 2026-05-16 JST, superseding the prior
  internal `1.10 (11)` candidate.
- App Store review: `1.10 (13)` was submitted for review on 2026-05-16 JST
  using `APP_VERSION=1.10 BUILD_NUMBER=13 bun run release:submit-review`.
  `automatic_release` was `false`.

## What Changed

- Fixed iOS editor preview wiring so `project.cameraProfile` is passed into:
  - still preview rendering
  - graded video preview item creation
  - graded video preview composition refresh
  - compare preview frame rendering
- Result: manual Source Profile selections such as DJI D-Log / D-Log M now build the same input conversion LUT in preview that export already used.
- Aligned iOS export rasterization with the AVVideoComposition preview path: Core Image now renders export BGRA frames in sRGB while writer/composition metadata remains Rec.709. Reader output no longer forces Rec.709 color properties, so source attachments stay intact.
- After owner feedback that build `12` output looked correct but denser than preview, the AVVideoComposition preview now rasterizes its processed frame through the same BGRA/output-color-space boundary before returning it to AVPlayer.
- Updated live-preview diagnostics so explicit built-in Source Profiles report `inputLutWillApply` accurately.
- Bumped iOS Xcode version to `1.10` build `13`.
- Updated localized release notes for the 1.10 TestFlight candidate.

## Copy / History Impact

- Copy / History Impact: App Store / TestFlight release notes updated because the candidate changes release-visible behavior.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note, because the fix clarifies the split between Creative Look LUTs and Source Profile input conversion in iOS preview.

## Verification

- `bun run verify:ios` passed.
  - Includes D-Log and D-Log M source profile accuracy gates at `0.000` reported max deltas.
- `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` passed after adding sRGB raster-output and reader source-attachment assertions.
- Local range reproduction using `/Users/chibatakumi/Movies/DJI_20260514155502_0073_D-reset.mp4`:
  - source decoded center mean RGB: `88.58 / 105.61 / 80.98`
  - fixed sRGB export raster mean RGB: `95.24 / 115.02 / 88.01`
  - old itur_709 export raster mean RGB: `103.56 / 122.42 / 96.75`
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.
- Local signed device build succeeded without uploading:
  `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS' -configuration Debug -derivedDataPath apps/capacitor-film-lab-ios/build/local-device build`
- Build `13` was installed locally on `千葉工のiPhone (7)` via `xcrun devicectl device install app`.
- Build `13`: `bun run --cwd apps/capacitor-film-lab-ios release:archive` succeeded.
  - IPA: `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa`
  - dSYM: `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.app.dSYM.zip`
  - IPA Info.plist: `CFBundleIdentifier = com.chibatakumi.film.lab.ios`,
    `CFBundleShortVersionString = 1.10`, `CFBundleVersion = 13`
  - IPA SHA-256: `f08026ab8d8e96bfe76193e1931095fdc0ed3031dd7ed3f354e168ad061e760b`
- Build `13`: `IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta` succeeded.
  - App Store Connect processing completed for `1.10 (13)`.
  - Distributed to Internal testers.
- Build `13`: `APP_VERSION=1.10 BUILD_NUMBER=13 bun run release:submit-review` succeeded.
  - Metadata and review information synced.
  - Precheck passed.
  - Existing build `1.10 (13)` was selected.
  - App submitted for review.
- Historical build `11`: `bun run --cwd apps/capacitor-film-lab-ios release:archive` succeeded.
  - IPA: `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa`
  - IPA Info.plist: `CFBundleShortVersionString = 1.10`, `CFBundleVersion = 11`
  - IPA SHA-256: `b00e8b1345c75b8ed74e8b49fc3f59d583be95084d750a9505dd6dd2ffd9904e`
- Historical build `11`: `IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta` succeeded.
  - App Store Connect processing completed for `1.10 (11)`.
  - Distributed to Internal testers.

## Remaining Risk

- Build `13` is submitted for App Store review, but public App Store lookup
  still reports `1.9` until Apple review approval and release complete.
- Desktop and iOS source-profile D-Log math share the same constants by inspection. Desktop preview/export was reported correct on the same source, so the remaining visual sign-off should focus on the iOS preview/export split.
