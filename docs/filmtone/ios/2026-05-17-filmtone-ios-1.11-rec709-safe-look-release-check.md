# Filmtone iOS 1.11 Rec.709 Safe Look Release Check

Date: 2026-05-17 JST

## Scope

Prepare Filmtone iOS `1.11 (14)` as a new TestFlight release candidate for
the Rec.709-safe Built-in Look application work.

This candidate covers Built-in Creative Pack 01 Stone / Urban / Noir source
aware behavior. It does not submit App Review yet.

Post-upload update on 2026-05-17 JST: the current source tree now includes the
follow-up Rec.709-safe color cube variants for Stone / Urban / Noir. Those
changes are not in the already uploaded `1.11 (14)` binary, so `1.11 (14)` must
remain an Internal TestFlight reference build only. The next release candidate
must bump `CURRENT_PROJECT_VERSION` to `15` or later before archive/upload.

## Changed

- Xcode candidate bumped to `MARKETING_VERSION = 1.11` and
  `CURRENT_PROJECT_VERSION = 14`.
- App Store release notes were updated for `ja`, `en-US`, and `en-GB`.
- Snapshot UI smoke tests were refreshed to the current full-screen editor,
  source profile sheet, and export sheet surfaces.
- Follow-up source changes after the `1.11 (14)` upload added Rec.709-safe cube
  variants and source-aware full/safe selection. Re-archive is required.

## Verification

- `bun run verify:ios` passed.
- Selected iOS UI smoke passed on simulator:
  - `testFullscreenBuiltInLookCarouselDisplaysCreativePack01Looks`
  - `testBuiltInLookChipSelectionKeepsFullscreenControlsReady`
  - `testCameraProfileShowsInputAndCreativeLutControls`
  - `testExportSaveCtaVisibleWithoutScrolling`
- Direct simulator launch with `-filmtoneSnapshot presets` showed the
  full-screen editor with Stone / Urban / Noir available.
- Debug build installed and launched on the connected iPhone.
- `bun run --cwd apps/capacitor-film-lab-ios release:env:check` passed for
  archive, metadata, beta, and App Store readiness.
- `bun run --cwd apps/capacitor-film-lab-ios release:archive` produced a signed
  IPA and dSYM.
- Exported IPA plist confirmed:
  - `CFBundleIdentifier = com.chibatakumi.film.lab.ios`
  - `CFBundleShortVersionString = 1.11`
  - `CFBundleVersion = 14`
- IPA SHA-256:
  `24dccf0f8792d4bcae13660cdd5c686f1679a9cb3cbe97537417cdd641d95826`
- `IPA_PATH=build/fastlane/Filmtone.ipa bun run --cwd apps/capacitor-film-lab-ios release:beta`
  uploaded `1.11 (14)`, App Store Connect processing completed, and the build
  was distributed to Internal testers.

## Release Gate

App Review submission remains blocked until owner visual QA accepts real
material behavior for at least:

- Rec.709 high-key footage
- Rec.709 saturated footage
- Rec.709 low-saturation flat footage
- D-Log M or Apple Log profile footage

Automated and install checks have run. Subjective image-quality QA on real
clips is still the remaining release risk.

Because the source tree changed after the `1.11 (14)` TestFlight upload, the
release path is now: visual QA on current source -> bump iOS build number ->
archive -> upload a new TestFlight build -> submit only after that build is
accepted.

## Copy / History Impact

Copy / History Impact: App Store release notes changed for the 1.11 candidate.

Article Opportunity: Release-note only.

Change-History Opportunity: Developer note later only if the source-aware
Built-in Look direction becomes part of a broader implementation-history story.
