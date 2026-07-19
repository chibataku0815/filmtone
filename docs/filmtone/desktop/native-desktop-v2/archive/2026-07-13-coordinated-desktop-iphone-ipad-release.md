# Active: Coordinated Desktop, iPhone, And iPad Release

Date opened: 2026-07-13 JST
Milestone: Release coordination

## Goal

Release the current native Filmtone product state on all three public rails
without mixing platform identities:

- Desktop direct download: candidate `1.17`, build `13`.
- iPhone App Store: candidate `1.14`, build `21`, bundle
  `com.chibatakumi.film.lab.ios`, scheme `App`.
- iPad App Store: candidate `1.5`, build `17`, bundle
  `com.chibatakumi.film.lab.ipad`, scheme `App-iPad`.

The release includes the Filmtone-owned Deep Glow optical finish. Visible copy
must use `Deep Glow`; the compatibility ids remain internal only.

## Source State

- Release work starts from `main` at `168419e`, two commits ahead of
  `origin/main`.
- The working tree already contains owner-authored native Desktop, iPhone,
  iPad, shared optical-filter, export, and release-rail changes. Preserve and
  release those changes as the current product candidate; do not revert or
  publish unrelated source-control operations.
- No commit, push, tag, or portfolio submodule update is in scope without a
  separate explicit request.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.17.md`
- `apps/capacitor-film-lab-ios/fastlane/Fastfile`
- `apps/capacitor-film-lab-ios/fastlane/metadata/*/release_notes.txt`
- `apps/capacitor-film-lab-ios/fastlane/metadata-ipad/*/release_notes.txt`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` only when
  the iPhone candidate version/build source requires alignment
- This file, its archive copy, and a short strategy completion note

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/desktop/release-cutover/README.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- Existing user-authored product and test changes outside the edit targets

## Checklist

- [x] Run Desktop and iOS/iPad release truth gates.
- [x] Confirm both upload lanes mechanically reject wrong-rail IPA identities.
- [x] Confirm unused iPhone and iPad App Store Connect build numbers.
- [x] Make the iPhone archive lane apply explicit candidate version/build values.
- [x] Update Desktop candidate version/build and three-rail release notes.
- [x] Build, sign, notarize, staple, and package the Desktop candidate.
- [x] Publish the Desktop DMG and update public update metadata.
- [x] Archive iPhone with scheme `App` and verify the actual IPA identity.
- [x] Upload iPhone binary/metadata and submit the processed build for review.
- [x] Archive iPad with scheme `App-iPad` and verify the actual IPA identity.
- [x] Upload iPad binary/metadata and submit the processed build for review.
- [x] Rerun public truth gates and record the resulting states.
- [x] Archive this task and append a short strategy completion note.

## Required Release Checks

These are packaging, signing, identity, notarization, upload, and public-state
checks required to perform the release. They are not product test suites:

- Inspect each generated IPA payload and app/extension `Info.plist` identity.
- Inspect Desktop signature, notarization, stapling, Gatekeeper result, DMG
  checksum, public object, and update metadata.
- Inspect App Store Connect upload processing and review-submission state for
  each distinct mobile rail.
- Rerun the life Desktop and iOS truth scripts after publication/submission.

Product tests, test suites, test-like verification commands, and test-file
changes are explicitly skipped because the global task rule forbids them unless
the user asks for testing in the current task.

## Done Conditions

- Desktop public update metadata reports `latestVersion: "1.17"`, and the fixed
  download rail serves the signed, notarized, stapled `Filmtone-1.17.dmg`.
- iPhone App Store Connect has an uploaded candidate for `1.14` whose IPA is
  `Payload/App.app`, bundle `com.chibatakumi.film.lab.ios`, device family `[1]`,
  and extension `FilmtoneExportActivity.appex`; review is submitted or an
  explicit App Store Connect processing blocker is recorded.
- iPad App Store Connect has an uploaded candidate for `1.5` whose IPA is
  `Payload/App-iPad.app`, bundle `com.chibatakumi.film.lab.ipad`, device family
  `[2]`, and extension `FilmtoneExportActivityIPad.appex`; review is submitted
  or an explicit App Store Connect processing blocker is recorded.
- No wrong-rail archive or upload is accepted.

## Stop Conditions

- Stop immediately if any IPA has the wrong bundle, payload, executable,
  extension, or device-family identity.
- Stop after 3 consecutive failures of the same signing, notarization, upload,
  processing, or review-submission action.
- Stop if the release path would require reverting owner-authored work or
  performing an unrequested commit, push, tag, or submodule update.
- Stop if App Store Connect reports a version-state conflict that cannot be
  resolved without changing the agreed release versions.

## Out Of Scope

- Legacy Electron Desktop.
- New product features beyond the current candidate and narrowly required
  release-rail corrections.
- Test changes or product verification suites.
- Git publication and portfolio submodule updates.

## Unexpected Blockers

- Desktop release archive attempt 1 compiled both `arm64` and `x86_64` and
  reached final app signing, then stopped with `errSecInternalComponent`.
  `security show-keychain-info` confirmed the user's login keychain is locked.
  The Developer ID identity is present, but its private key cannot be used
  until the owner unlocks the login keychain. No notarization or publication
  occurred. This is failure 1 of the 3-attempt signing stop condition.
- The first iPad asset upload created App Store version `1.5` and uploaded its
  metadata, but Apple had not exposed 2 of the 5 first screenshot checksums when
  the lane performed its immediate readback. The lane stopped before ordering
  the set. Screenshot readback now polls the processing state and removes stale
  or duplicate entries before ordering. This is failure 1 of the 3-attempt
  asset-upload stop condition.
- The Desktop signing failure was resolved using the Developer ID certificate
  bundle stored in 1Password and an isolated release keychain. The login
  keychain was subsequently unlocked, the temporary keychain was removed after
  all signing work, and the login keychain was restored as the sole default and
  search keychain.
- iPhone archive attempt 1 stopped while signing the export extension because
  the login keychain was locked. Attempt 2 passed signing but stopped because
  Xcode's Metal Toolchain component was missing. After installing Metal
  Toolchain `17F109`, attempt 3 produced the correct signed IPA. Neither failure
  uploaded a binary or crossed rail identities.
- The first post-submission readback found iPhone release type `MANUAL` even
  though the metadata-free submission lane received `AUTOMATIC_RELEASE=1`.
  App Store Connect was corrected to `AFTER_APPROVAL`, and both metadata-free
  submission lanes now update `releaseType` explicitly before submitting.

## Release Results

- Desktop: `1.17` build `13`, bundle `com.chibatakumi.film-lab-desktop`.
  `Filmtone-1.17.dmg` is Developer ID signed, notarized, stapled, accepted by
  Gatekeeper, and published at the fixed production download URL. SHA-256:
  `27a5a2670c5173a9e71964347ebacb2a0eabdabcecb8f0a177fc18ec68ebc6e8`.
  Public update metadata reports `latestVersion: "1.17"`.
- iPhone: `1.14` build `21`, `Payload/App.app`, bundle
  `com.chibatakumi.film.lab.ios`, device family `[1]`, extension
  `FilmtoneExportActivity.appex`. The build processed as `VALID` and the App
  Store version is `WAITING_FOR_REVIEW / AFTER_APPROVAL`.
- iPad: `1.5` build `17`, `Payload/App-iPad.app`, bundle
  `com.chibatakumi.film.lab.ipad`, device family `[2]`, extension
  `FilmtoneExportActivityIPad.appex`. The build processed as `VALID`; all 30
  localized 12.9-inch/11-inch screenshots were checksum/order verified, and
  the App Store version is `WAITING_FOR_REVIEW / AFTER_APPROVAL`.
- The public iPhone App Store lookup remains `1.13` and the public iPad release
  remains `1.4` until App Review approval. These public states are intentionally
  reported separately from the submitted candidates.

## Release Checks Performed

- Desktop archive/sign/notarize/staple, app and DMG Gatekeeper assessment,
  checksum, production object upload, update metadata publication, and
  production portfolio deployment.
- Independent IPA `Info.plist` inspection for both app payloads and both export
  extensions, followed by the Fastlane upload guard on each upload.
- App Store Connect build-processing readback (`VALID`), exact build selection,
  review submission, release-type readback, and screenshot checksum/order
  readback for the iPad rail.
- Final Desktop and iOS life truth scripts. Desktop public truth is `1.17`;
  mobile public truth remains iPhone `1.13` while the new candidates await
  review.
- Product tests, test suites, test-like verification commands, and test-file
  changes were not run or made because the current task did not explicitly ask
  for testing.

## Copy / History Impact

- Copy / History Impact: release notes must describe Deep Glow as a Filmtone
  optical finish and avoid the retired visible name `Backlight Veil`.
- Article Opportunity: Release-note only.
- Change-History Opportunity: Developer note; this release preserves separate
  iPhone and iPad archive identities and makes iPhone version/build injection
  explicit at archive time.
