# Filmtone iOS Public Release Handoff

Last updated: 2026-04-20 02:15 JST

Historical note: this document remains the v1.0 release/procedural record from the `feature/filmtone-ios-phase0` rail. It is not the day-to-day canonical lane pointer.

This is a fresh, stand-alone handoff for continuing Filmtone iOS public release preparation in a brand-new chat. It is designed to be sufficient without any access to prior chat history and without any prior context about the Fastlane rail.

Supersedes:

- `docs/filmtone-ios-public-release-handoff-2026-04-20.md`
- `docs/filmtone-ios-public-release-handoff-2026-04-20-0148-jst.md`

Treat this document as the primary source of truth for the historical v1.0 release rail. Read it end-to-end before taking any action.

---

## 1. Executive Status

Both the screenshot blocker and the App Store export signing blocker are resolved. The remaining work is to run `metadata`, `release`, and (optionally) `beta` once ASC API credentials and `REVIEW_PHONE` are available in the shell.

Landed in the previous session (2026-04-20 01:48 JST handoff):

- Deterministic screenshot lane.
- Five required screenshots staged into both `ja` and `en-US`.

Landed in this session (2026-04-20 02:05 JST):

- Removed two legacy project-level `CODE_SIGN_IDENTITY = "iPhone Developer"` entries from the Xcode project. Those were forcing development-only signing at the project scope and preventing App Store distribution export even though the target-level signing was already automatic.
- Updated the `archive` lane to pass `-allowProvisioningUpdates` on both the build and export phases, set `signingStyle: automatic` + `teamID: C3G77H8NM6` in the export options, and forward the ASC API key to `xcodebuild` via `-authenticationKeyID`, `-authenticationKeyIssuerID`, and `-authenticationKeyPath` when those env vars are present.
- Removed the Apple-ID + app-specific-password fallback from the `beta` lane. `beta` now requires the same ASC API key material as `metadata` and `release`.
- Refreshed `RELEASE.md` to match the current rail (deterministic simulator target, new archive signing path, API-key-only `beta`, removed inactive overrides).
- Verified `./scripts/bundle.sh exec fastlane ios archive` end-to-end on this Mac and inspected the resulting IPA.

Pending (not blocked):

- `./scripts/bundle.sh exec fastlane ios metadata` — unverified. Needs ASC API key + `REVIEW_PHONE`.
- `./scripts/bundle.sh exec fastlane ios release` — unverified. Needs ASC API key + `REVIEW_PHONE`. Submission still gated by explicit `SUBMIT_FOR_REVIEW=1`.
- `./scripts/bundle.sh exec fastlane ios beta` — unverified, and TestFlight upload is not required for this milestone. Run only if TestFlight distribution is explicitly desired at execution time.

---

## 2. Objective

Prepare `Filmtone` (iPhone, iOS 17+) for its first public App Store release with `fastlane` as the only release rail.

The rail covers:

- `archive` (IPA export)
- `screenshots`
- `metadata`
- `beta` (TestFlight, optional)
- `release` (App Store upload, with opt-in submit-for-review)

---

## 3. Non-Negotiable Constraints

These came from the user and are policy until explicitly changed.

### 3.1 Product constraints

- Initial release is free.
- iPhone only. iOS 17+.
- Locales: Japanese (`ja`) and English (`en-US`).
- No login, no account, no IAP, no subscription.
- Supported codecs: `H.264`, `HEVC`, `ProRes`.
- `DNxHR` / `DNxHD` explicitly unsupported in v1. Metadata and review notes must not claim support.
- App is positioned as local-first. Metadata must not claim AI features, cloud sync, or subscription.

### 3.2 Release system constraints

- `fastlane` is mandatory.
- Keep Xcode automatic signing.
- Do not introduce `match`.
- App Store Connect authentication must use API key env vars:
  - `ASC_KEY_ID`
  - `ASC_ISSUER_ID`
  - `ASC_KEY_CONTENT` or `ASC_KEY_PATH`
- Apple-ID + app-specific-password fallback for `beta` is removed and must not be reintroduced.

### 3.3 Process constraints

- Use sequential thinking for nontrivial reasoning.
- Verify unknowns instead of guessing.
- Fallback-oriented design is a bug source and must be avoided. Do not reintroduce:
  - simulator runtime iteration
  - screenshot retry loops
  - fallback auth paths for upload
  - primary→secondary renderer/backend self-switching
- Do not revert unrelated dirty worktree changes.
- Agent Teams / subagents are fine when work is genuinely independent.
- The user performs all `git commit` / `git push`. Do not commit on their behalf.

### 3.4 Process interpretation

The user rejected fallback. Practical meaning for this work:

- prefer one explicit known-good execution path
- if something cannot be done with current machine state (e.g. a missing cert), the correct answer is to fix the machine state outside the repo, not to add repo-side fallback logic

---

## 4. Environment

### 4.1 Absolute paths

- Worktree root (where all work for this task happens):
  - `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0`
- iOS app root:
  - `apps/capacitor-film-lab-ios` (relative to worktree root)
- Original terminal cwd when the prior chat launched:
  - `/Volumes/SamsungPortableSSDX5001/documents/life`

Note: terminal cwd can be reset to the `life` repo between tool calls in this environment. Always qualify commands with absolute paths or `cd` the worktree root/app root explicitly.

### 4.2 Time context

- Current session date: `2026-04-20`
- Timezone: `Asia/Tokyo`
- This handoff timestamp: `2026-04-20 02:15 JST`

### 4.3 Git / worktree state

- Branch: `feature/filmtone-ios-phase0`
- Worktree HEAD at the time of this handoff: `bbf9f34a9a217f422475b7503a826356648ae5ce` (`fix(ios): stabilize process video preview refresh`)
- The worktree is dirty with many preexisting or in-progress changes outside the narrow release-prep slice. Treat it as shared state and do not do broad cleanup.

Changes introduced in this session that are not yet committed:

- Modified (tracked):
  - `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` — only the two legacy `CODE_SIGN_IDENTITY = "iPhone Developer"` lines were removed; the rest of the diff in that file is from prior sessions (PrivacyInfo, snapshot UI test targets).
- Untracked (were already untracked; this session edited them):
  - `apps/capacitor-film-lab-ios/fastlane/Fastfile`
  - `apps/capacitor-film-lab-ios/RELEASE.md`
  - `docs/filmtone-ios-public-release-handoff-2026-04-20-0148-jst.md`

### 4.4 Env var state in the current shell (at time of handoff)

Verified unset when the last verification ran:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_CONTENT`
- `ASC_KEY_PATH`
- `REVIEW_PHONE`

`archive` still succeeded because `-allowProvisioningUpdates` reached the Apple Developer account already logged into Xcode on this Mac.

`APP_STORE_CONNECT_APPLE_ID` and `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD` are no longer read by any lane.

### 4.5 Apple Developer / ASC facts

- Team ID (hardcoded in `Fastfile` as `DEVELOPMENT_TEAM_ID`, and set as `DEVELOPMENT_TEAM` in every relevant Xcode target build config): `C3G77H8NM6`
- App bundle id: `com.chibatakumi.film.lab.ios`
- UI test target bundle id: `com.chibatakumi.film.lab.iosUITests`
- Export profile observed after a successful run: `iOS Team Store Provisioning Profile: com.chibatakumi.film.lab.ios`

### 4.6 Tooling

- Ruby / Bundler / Fastlane are installed via Homebrew Ruby.
- `apps/capacitor-film-lab-ios/scripts/bundle.sh` is the only supported way to invoke Fastlane. It puts Homebrew Ruby's `bin` at the front of `PATH`, then `exec bundle "$@"`. Use:
  - `./scripts/bundle.sh install` to install Gemfile deps
  - `./scripts/bundle.sh exec fastlane <lane>` to run lanes
- Fastlane is pinned to `2.233.0` (see `Gemfile.lock`).
- `.ruby-version` pins a specific Ruby version aligned with Homebrew Ruby.

---

## 5. What Has Been Implemented

### 5.1 iOS project packaging fixes (prior sessions)

- `Info.plist` aligned for release.
- `PrivacyInfo.xcprivacy` present.
- Missing localization keys completed in `Localizable.xcstrings`.
- Encryption export compliance flag set to `false` in Fastfile submission info.

### 5.2 Fastlane release rail (prior sessions, refined this session)

Files:

- `apps/capacitor-film-lab-ios/Gemfile`
- `apps/capacitor-film-lab-ios/Gemfile.lock`
- `apps/capacitor-film-lab-ios/.ruby-version`
- `apps/capacitor-film-lab-ios/scripts/bundle.sh`
- `apps/capacitor-film-lab-ios/fastlane/Appfile`
- `apps/capacitor-film-lab-ios/fastlane/Fastfile`
- `apps/capacitor-film-lab-ios/fastlane/Deliverfile`
- `apps/capacitor-film-lab-ios/fastlane/Snapfile`
- `apps/capacitor-film-lab-ios/fastlane/metadata/...` (copyright, primary_category, and per-locale description / keywords / name / promotional_text / release_notes / subtitle)
- `apps/capacitor-film-lab-ios/fastlane/screenshots/{ja,en-US}/iPhone 17 Pro Max-*.png`
- `apps/capacitor-film-lab-ios/RELEASE.md`
- `apps/capacitor-film-lab-ios/package.json`

Lanes: `archive`, `screenshots`, `metadata`, `beta`, `release`.

### 5.3 Screenshot UI test foundation (prior sessions)

Files:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSnapshotSupport.swift`
- `apps/capacitor-film-lab-ios/ios/App/AppDelegate.swift` (snapshot launch-args plumbing)
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/SnapshotHelper.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/xcshareddata/xcschemes/App.xcscheme`

Five deterministic scenes (hero / presets / quick / camera / export) drive five screenshots per run:

- `iPhone 17 Pro Max-01_source_loaded_preview.png`
- `iPhone 17 Pro Max-02_preset_row.png`
- `iPhone 17 Pro Max-03_strength_quick_controls.png`
- `iPhone 17 Pro Max-04_camera_profile_route.png`
- `iPhone 17 Pro Max-05_export_save_share.png`

### 5.4 Web / legal surface (prior sessions)

- `apps/web/src/app/[locale]/film-lab/support/page.tsx`
- `apps/web/src/app/[locale]/film-lab/privacy/page.tsx`
- `apps/web/src/features/interactive/film-lab/ios-release-info.ts`
- `apps/web/messages/en.json`, `apps/web/messages/ja.json`

### 5.5 Signing and auth cleanup (this session)

1. `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`

   Removed two project-level legacy entries:

   ```text
   CODE_SIGN_IDENTITY = "iPhone Developer";
   ```

   These lived in the project's Debug and Release `XCBuildConfiguration` sections (not the target-level ones) and were overriding the target-level automatic-signing decision for distribution export. Target-level settings are unchanged:

   - `CODE_SIGN_STYLE = Automatic`
   - `DEVELOPMENT_TEAM = C3G77H8NM6`
   - `PRODUCT_BUNDLE_IDENTIFIER = com.chibatakumi.film.lab.ios`
   - no `PROVISIONING_PROFILE_SPECIFIER`
   - no `PROVISIONING_PROFILE`

2. `apps/capacitor-film-lab-ios/fastlane/Fastfile`

   - Added `DEVELOPMENT_TEAM_ID = "C3G77H8NM6"` constant.
   - Added `resolve_asc_key_file_path!` helper: if `ASC_KEY_CONTENT` is set, writes a mode-0600 temp `.p8` file for the run and returns its path; otherwise resolves `ASC_KEY_PATH` relative to the app root.
   - Rewrote `archive` to:
     - build `xcargs` that always contains `-allowProvisioningUpdates`
     - when ASC API key env vars are set, also append `-authenticationKeyIssuerID`, `-authenticationKeyID`, `-authenticationKeyPath`
     - pass the same string as `xcargs` and `export_xcargs`
     - set `export_options` `{ method: "app-store", signingStyle: "automatic", teamID: DEVELOPMENT_TEAM_ID }`
     - wrap the `build_app` call in `begin … ensure FileUtils.rm_f(temp_key_path) if temp_key_path end` so the temp `.p8` never leaks
   - Removed `beta_upload_fallback?` helper.
   - Rewrote `beta` to require ASC API key auth unconditionally:
     ```ruby
     upload_options = {
       api_key: load_asc_api_key!,
       ipa: ipa_path,
       app_platform: "ios",
       skip_waiting_for_build_processing: truthy_env?("SKIP_WAITING_FOR_BUILD_PROCESSING"),
       distribute_external: false,
       notify_external_testers: false,
     }
     upload_options[:localized_build_info] = localized_release_notes unless localized_release_notes.empty?
     ```
   - `metadata`, `release`, `screenshots` are unchanged in this session.

3. `apps/capacitor-film-lab-ios/RELEASE.md`

   - Screenshot section rewritten: deterministic simulator (`iPhone 17 Pro Max`, iOS 26.2, UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`), no fallback language.
   - Archive section documents `-allowProvisioningUpdates`, `signingStyle: automatic`, teamID, and ASC API key → xcodebuild auth forwarding.
   - Removed: `FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD`, `APP_STORE_CONNECT_APPLE_ID`, `SNAPSHOT_IPHONE_DEVICE`, `SNAPSHOT_IOS_VERSION` (no longer honored by any lane).
   - Added: explicit `beta` API-key requirement note, `SNAPSHOT_BASE_LOCALE` as the only active screenshot override.

---

## 6. Current Fastlane Behavior

### 6.1 `screenshots`

From `apps/capacitor-film-lab-ios/fastlane/Fastfile`:

- `SCREENSHOT_SIMULATOR_DEVICE = "iPhone 17 Pro Max"`
- `SCREENSHOT_SIMULATOR_UDID   = "D3011FE4-52CA-4B7F-B181-A55D9998E192"`
- Writes fastlane snapshot cache files for one base locale (defaulting to `ja`; override with `SNAPSHOT_BASE_LOCALE`).
- Runs one direct `xcodebuild test` on `App` scheme with that destination id and `CODE_SIGNING_ALLOWED=NO`.
- Stages the captured asset set into both `ja` and `en-US` under `apps/capacitor-film-lab-ios/fastlane/screenshots/`.

No longer does: simulator discovery, `-showdestinations` parsing, runtime sorting, retry, fallback orchestration, or status-bar override.

Screenshot cache on disk:

- `~/Library/Caches/tools.fastlane/screenshots`

### 6.2 `archive`

From `Fastfile`:

- `build_app` with:
  - `workspace: ios/App/App.xcworkspace`
  - `scheme: App`
  - `clean: true`
  - `export_method: "app-store"`
  - `output_directory: apps/capacitor-film-lab-ios/build/fastlane`
  - `output_name: "Filmtone"`
  - `build_path: apps/capacitor-film-lab-ios/build/fastlane`
  - `xcargs` / `export_xcargs`: `-allowProvisioningUpdates` plus (when ASC env is set) `-authenticationKeyIssuerID <id> -authenticationKeyID <id> -authenticationKeyPath <path>`
  - `export_options: { method: "app-store", signingStyle: "automatic", teamID: "C3G77H8NM6" }`
- Emits:
  - timestamped `<output_dir>/Filmtone YYYY-MM-DD HH.MM.SS.xcarchive/`
  - `<output_dir>/Filmtone.ipa`
  - `<output_dir>/Filmtone.app.dSYM.zip`

When running on a CI-like machine with no GUI-logged-in Xcode account, supplying the ASC API key env vars lets `-allowProvisioningUpdates` fetch distribution signing assets headlessly.

### 6.3 `metadata`

- Requires ASC API key env vars and `REVIEW_PHONE`.
- Calls `stage_metadata!` which copies `fastlane/metadata/*` into `fastlane/.generated/metadata/*` and injects localized URL values (`marketing_url.txt`, `support_url.txt`, `privacy_url.txt`) from env vars / defaults without mutating the checked-in templates.
- Calls `upload_to_app_store` with:
  - `skip_binary_upload: true`
  - `skip_screenshots: true`
  - `force: true`
  - `app_review_information` from `app_review_information!`
  - `submission_information: { export_compliance_uses_encryption: false }`

### 6.4 `beta`

- Requires ASC API key env vars.
- If no existing IPA path passed, calls `archive` first.
- Calls `upload_to_testflight` with API key auth, `distribute_external: false`, `notify_external_testers: false`, optional `localized_build_info` from release notes, optional `skip_waiting_for_build_processing` via `SKIP_WAITING_FOR_BUILD_PROCESSING=1`.

### 6.5 `release`

- Requires ASC API key env vars and `REVIEW_PHONE`.
- If no existing IPA path passed, calls `archive` first.
- Calls `upload_to_app_store` with:
  - `api_key`
  - `ipa`
  - staged `metadata_path`
  - `skip_binary_upload: false`
  - `skip_metadata: false`
  - `submit_for_review: truthy_env?("SUBMIT_FOR_REVIEW")`
  - `automatic_release: truthy_env?("AUTOMATIC_RELEASE")`
  - `force: true`
  - `app_review_information`
  - `submission_information: { export_compliance_uses_encryption: false }`
- If screenshots are staged on disk: `screenshots_path: SCREENSHOTS_PATH`, `overwrite_screenshots: truthy_env?("OVERWRITE_SCREENSHOTS")`.
- Otherwise: `skip_screenshots: true`.

### 6.6 `Appfile`

```ruby
app_identifier "com.chibatakumi.film.lab.ios"
apple_id  ENV["FASTLANE_USER"]               if ENV["FASTLANE_USER"]
team_id   ENV["APPLE_DEVELOPER_TEAM_ID"]     if ENV["APPLE_DEVELOPER_TEAM_ID"]
team_name ENV["APPLE_DEVELOPER_TEAM_NAME"]   if ENV["APPLE_DEVELOPER_TEAM_NAME"]
itc_team_id   ENV["APP_STORE_CONNECT_TEAM_ID"]   if ENV["APP_STORE_CONNECT_TEAM_ID"]
itc_team_name ENV["APP_STORE_CONNECT_TEAM_NAME"] if ENV["APP_STORE_CONNECT_TEAM_NAME"]
```

`team_id` defaults come from target-level `DEVELOPMENT_TEAM = C3G77H8NM6` in the Xcode project, so `APPLE_DEVELOPER_TEAM_ID` is optional.

### 6.7 Metadata content invariants

These are already checked into `fastlane/metadata/` and must not be edited casually:

- `primary_category.txt`: `PHOTO_AND_VIDEO`
- `en-US/release_notes.txt`: `Initial release with presets, Quick controls, dual LUT slots, export, and save/share to Photos.`
- `ja/release_notes.txt`: `最初の公開版です。プリセット、Quick 3 軸、Camera Profile / Film Look の dual LUT、書き出し、写真への保存 / 共有を利用できます。`

Do not introduce AI, subscription, cloud-sync, or `DNxHR` / `DNxHD` claims in any metadata string.

---

## 7. Verification History

### 7.1 Project integrity (earlier)

- `xcodebuild -list -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace` — OK
- `plutil -lint apps/capacitor-film-lab-ios/ios/App/App/Info.plist` — OK
- `plutil -lint apps/capacitor-film-lab-ios/ios/App/App/PrivacyInfo.xcprivacy` — OK

### 7.2 Build-for-testing (earlier)

```sh
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build-for-testing
```

Result: `** TEST BUILD SUCCEEDED **`.

### 7.3 Direct screenshot UI test (earlier)

```sh
rm -rf "$HOME/Library/Caches/tools.fastlane/screenshots"
xcodebuild \
  -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App \
  -destination 'id=D3011FE4-52CA-4B7F-B181-A55D9998E192' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests/testCaptureAppStoreScreenshots \
  test
```

Result: `** TEST SUCCEEDED **`. This evidence justified the simplified lane.

### 7.4 Fastlane runtime normalization (earlier)

- `./scripts/bundle.sh install` — OK
- `./scripts/bundle.sh exec fastlane lanes` — OK

### 7.5 Screenshot lane (earlier, still valid)

```sh
./scripts/bundle.sh exec fastlane ios screenshots
```

Result: fastlane finished successfully; one simulator destination; one `xcodebuild test` invocation; five screenshots staged into both `ja` and `en-US`. Staged files on disk:

- `apps/capacitor-film-lab-ios/fastlane/screenshots/ja/iPhone 17 Pro Max-0{1..5}_*.png`
- `apps/capacitor-film-lab-ios/fastlane/screenshots/en-US/iPhone 17 Pro Max-0{1..5}_*.png`

### 7.6 Archive lane (this session)

```sh
./scripts/bundle.sh exec fastlane ios archive
```

Result:

- Archive path: `apps/capacitor-film-lab-ios/build/fastlane/Filmtone 2026-04-20 02.03.28.xcarchive`
- Exported plist observed:
  ```
  { "method": "app-store", "signingStyle": "automatic", "teamID": "C3G77H8NM6" }
  ```
- xcodebuild export was invoked with `-allowProvisioningUpdates -allowProvisioningUpdates` (both from `xcargs` and `export_xcargs`), which is benign.
- IPA emitted at `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa` (~71 MB).
- dSYM zipped to `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.app.dSYM.zip`.
- `build_app` total time: 38 s.

Post-run IPA inspection (via `codesign -dvvv` on `Payload/App.app` and `security cms -D -i embedded.mobileprovision | PlistBuddy`):

- `Authority = Apple Distribution: takumi chiba (C3G77H8NM6)`
- Other authorities: `Apple Worldwide Developer Relations Certification Authority`, `Apple Root CA`
- `TeamIdentifier = C3G77H8NM6`
- Embedded profile `Name = iOS Team Store Provisioning Profile: com.chibatakumi.film.lab.ios`
- Embedded profile `Entitlements.get-task-allow = false`
- Embedded profile has no `ProvisionedDevices` key (consistent with an App Store distribution profile, not ad-hoc / development)

### 7.7 Fastlane parse (this session)

```sh
./scripts/bundle.sh exec fastlane lanes
```

Result: fastlane lists `archive`, `screenshots`, `metadata`, `beta`, `release` without parsing errors after the auth cleanup.

### 7.8 Known environmental noise

During xcodebuild runs, Xcode emits repeated messages like:

- `Failed to start remote service "com.apple.mobile.notification_proxy" on device.`
- `The device is passcode protected.`

These come from a connected physical iPhone and did not prevent archive or screenshot success. Treat as environmental noise unless a future run proves otherwise.

---

## 8. Remaining Tasks For The Next Chat

Execute in order. Do not skip verification.

### 8.1 Prerequisites

Provide the following env vars in the shell (sourced from 1Password / the user's secrets store):

Required:

- `ASC_KEY_ID` — 10-char key id from App Store Connect → Users and Access → Keys
- `ASC_ISSUER_ID` — UUID issuer id from the same page
- One of:
  - `ASC_KEY_CONTENT` — raw `.p8` content, or the same content with `\n` escapes for single-line shell use
  - `ASC_KEY_PATH` — path to the `.p8` file (absolute or relative to `apps/capacitor-film-lab-ios`)
- `REVIEW_PHONE` — contact phone for App Review (E.164 format), e.g. `+81-90-xxxx-xxxx`

Optional (only set if the defaults don't fit):

- `REVIEW_FIRST_NAME`, `REVIEW_LAST_NAME`, `REVIEW_EMAIL`, `REVIEW_DEMO_USER`, `REVIEW_DEMO_PASSWORD`, `REVIEW_NOTES`
- `APPLE_DEVELOPER_TEAM_ID`, `APPLE_DEVELOPER_TEAM_NAME`, `APP_STORE_CONNECT_TEAM_ID`, `APP_STORE_CONNECT_TEAM_NAME`, `FASTLANE_USER`
- `FILMTONE_CANONICAL_BASE_URL`, `FILMTONE_MARKETING_URL{,_JA,_EN_US}`, `FILMTONE_SUPPORT_URL{,_JA,_EN_US}`, `FILMTONE_PRIVACY_URL{,_JA,_EN_US}`
- `SUBMIT_FOR_REVIEW=1` — only set when the release is ready for actual review submission
- `AUTOMATIC_RELEASE=1` — only set when the user wants auto-release after review approval
- `SKIP_WAITING_FOR_BUILD_PROCESSING=1` — optional for `beta`
- `OVERWRITE_SCREENSHOTS=1` — optional for `release` when updating screenshots

Defaults baked into the Fastfile:

- `REVIEW_FIRST_NAME = "Takumi"`
- `REVIEW_LAST_NAME = "Chiba"`
- `REVIEW_EMAIL = "chiba@fores-tone.co.jp"`
- `REVIEW_NOTES = "Filmtone is local-first. Review the flow by importing a photo or video, choosing a preset, adjusting Quick controls, optionally applying Camera Profile and Film Look LUTs, then exporting and saving to Photos. No login, subscription, AI generation, or cloud sync is required."`
- URL bases default to `https://www.chibatakumi.studio/{film-lab, en/film-lab, film-lab/support, en/film-lab/support, film-lab/privacy, en/film-lab/privacy}`.

### 8.2 Confirm rail is still green before running anything new

```sh
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0/apps/capacitor-film-lab-ios
./scripts/bundle.sh exec fastlane lanes
```

Expected: 5 lanes listed without parse errors.

If `Filmtone.ipa` is missing (e.g. new worktree checkout), re-run:

```sh
./scripts/bundle.sh exec fastlane ios archive
```

Expected: `Successfully exported and signed the ipa file: …/Filmtone.ipa`, and `codesign -dvvv` of `Payload/App.app` shows `Authority=Apple Distribution: takumi chiba (C3G77H8NM6)`.

### 8.3 Metadata sync

```sh
./scripts/bundle.sh exec fastlane ios metadata
```

Expected:

- Fastlane stages `fastlane/metadata/*` into `fastlane/.generated/metadata/*` with URL `.txt` files injected.
- `upload_to_app_store` succeeds with `skip_binary_upload: true`, updating App Store Connect metadata (no binary, no screenshots).
- App Review info is synced.
- Export compliance says no encryption.

On failure, the likely causes are:

- missing `REVIEW_PHONE`
- ASC API key env vars not actually loaded by the shell
- App Store Connect team ambiguity (supply `APP_STORE_CONNECT_TEAM_ID` explicitly)

### 8.4 Release (App Store upload)

The user has to decide whether to submit for review in the same run or upload-only first.

Upload-only first (recommended for the first public release):

```sh
./scripts/bundle.sh exec fastlane ios release
```

Upload + submit for review:

```sh
SUBMIT_FOR_REVIEW=1 ./scripts/bundle.sh exec fastlane ios release
```

Upload + submit + auto-release after approval:

```sh
AUTOMATIC_RELEASE=1 SUBMIT_FOR_REVIEW=1 ./scripts/bundle.sh exec fastlane ios release
```

Expected: `upload_to_app_store` uploads the IPA, synced metadata, and staged screenshots. Review info and submission flags applied per env.

If screenshots are missing on disk when `release` runs, the lane will log a warning and skip screenshot upload. The five per-locale screenshots are currently staged under `apps/capacitor-film-lab-ios/fastlane/screenshots/{ja,en-US}/`, so this is expected to be fine as long as those files are still present.

### 8.5 TestFlight (optional, only if explicitly desired)

```sh
./scripts/bundle.sh exec fastlane ios beta
```

Or, skip wait for processing:

```sh
SKIP_WAITING_FOR_BUILD_PROCESSING=1 ./scripts/bundle.sh exec fastlane ios beta
```

The lane uses the existing `Filmtone.ipa` if present, otherwise re-archives. Uploads to TestFlight, does not distribute externally, does not notify external testers.

### 8.6 Post-run verification checklist

After each lane runs, confirm:

- exit code 0
- no `[!]` error lines in fastlane output
- App Store Connect web UI reflects the expected change (metadata strings, IPA build number, screenshots, review info)
- for `release` with `SUBMIT_FOR_REVIEW=1`: App Store Connect shows the build in "Waiting for Review" or similar

### 8.7 Commits and push

The user performs all commits and pushes. Do not commit on their behalf. After verification, recommend a commit set scoped to:

- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` (the legacy `CODE_SIGN_IDENTITY` removal)
- `apps/capacitor-film-lab-ios/fastlane/Fastfile`
- `apps/capacitor-film-lab-ios/RELEASE.md`
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md` (this handoff)
- any metadata deltas the user wants retained

Do not include build artifacts (`apps/capacitor-film-lab-ios/build/**`), `node_modules`, or `dist/` in the commit.

---

## 9. Risks and Gotchas

1. **Passcode-protected-device noise.** Tolerable but noisy. Unlock or disconnect the physical iPhone to silence it if desired.
2. **Xcode account session expiry.** `-allowProvisioningUpdates` relies on a logged-in Apple ID in Xcode. If the session expired between runs, the next `archive` can fail. Fix by re-authing in Xcode > Settings > Accounts, or by supplying the ASC API key env vars so `xcodebuild -authenticationKey*` can fetch assets headlessly.
3. **ASC API key `.p8` leakage.** `resolve_asc_key_file_path!` writes `ASC_KEY_CONTENT` to a mode-0600 temp file in `Dir.tmpdir` and deletes it in the `ensure` block. Do not change that ordering. Do not log the file path. Do not cat it.
4. **Multi-line `ASC_KEY_CONTENT` gotcha.** The loader replaces `\n` (literal two characters) with newlines, so you can pass the `.p8` as a single-line env var. If you paste a truly multi-line value, that also works.
5. **Temporary xcarchive buildup.** Each `archive` run creates a timestamped `.xcarchive` under `apps/capacitor-film-lab-ios/build/fastlane/`. They are not automatically cleaned and are not in git. Safe to delete stale ones, but leave `Filmtone.ipa` and `Filmtone.app.dSYM.zip` intact until the release is accepted.
6. **`TARGETED_DEVICE_FAMILY = 1`.** Enforced in project settings. iPhone only. Do not relax this.
7. **`IPHONEOS_DEPLOYMENT_TARGET = 17.0`.** Same.
8. **No `match`, ever.** Even if a future error suggests “consider using match,” do not take that path.
9. **Do not re-run `screenshots` unless there is evidence of a regression.** The lane is deterministic and the staged files are known good.
10. **Fallback is forbidden.** If any lane asks for a silent fallback, reject it and surface a clear error instead.
11. **Review notes must stay honest.** Filmtone is local-first. Do not add AI, subscription, or cloud sync claims in any metadata or review text. Keep `DNxHR` / `DNxHD` explicitly unsupported.

---

## 10. Important Files To Read First In The Next Chat

Start here before taking any action:

- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md` (this doc)
- `apps/capacitor-film-lab-ios/fastlane/Fastfile`
- `apps/capacitor-film-lab-ios/fastlane/Appfile`
- `apps/capacitor-film-lab-ios/fastlane/metadata/**/*.txt`
- `apps/capacitor-film-lab-ios/RELEASE.md`
- `apps/capacitor-film-lab-ios/Gemfile` / `Gemfile.lock` / `.ruby-version`
- `apps/capacitor-film-lab-ios/scripts/bundle.sh`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `apps/capacitor-film-lab-ios/build/fastlane/Filmtone.ipa` (sanity-check existence)

For screenshot debugging only if needed:

- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/FilmtoneSnapshotsUITests.swift`
- `apps/capacitor-film-lab-ios/ios/App/FilmtoneSnapshotsUITests/SnapshotHelper.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSnapshotSupport.swift`

---

## 11. Dirty Worktree / Safety Notes

The worktree has preexisting dirty content outside the narrow release-prep slice. Do not do broad cleanup.

Examples from `git status --short` at handoff time:

- multiple modified native iOS app Swift files (`FilmtoneMediaTypes.swift`, `FilmtonePhase0*`, `FilmtoneStrings.swift`, `Info.plist`, `Localizable.xcstrings`)
- modified `apps/web/messages/{en,ja}.json`
- modified `packages/film-lab-core/**` (tests + dist + `ios-*` payload)
- untracked directories: `apps/capacitor-film-lab-ios/build/`, `apps/capacitor-film-lab-ios/dist/`, `apps/capacitor-film-lab-ios/node_modules/`
- untracked release-rail files: `apps/capacitor-film-lab-ios/{Gemfile,Gemfile.lock,.ruby-version,RELEASE.md}`, `apps/capacitor-film-lab-ios/fastlane/**`, `apps/capacitor-film-lab-ios/scripts/**`

Rules:

- Do not run `git checkout -- .`, `git reset --hard`, `git clean -fdx`, or anything equivalent.
- Do not revert unrelated files.
- Read before editing any already-dirty file.
- When in doubt about whether a change is yours, `git diff <file>` first.

---

## 12. Cold-Start Prompt For The Next Chat

Paste this into a fresh chat verbatim:

```text
You are taking over a partially completed App Store release task for the Filmtone iOS app.

The source of truth is this repository state plus the handoff document at:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0/docs/filmtone-ios-public-release-handoff-2026-04-20-0215-jst.md

Read that document first, end-to-end, and treat it as authoritative. Do not assume access to earlier chat history.

Worktree root:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-ios-phase0

Branch: feature/filmtone-ios-phase0

Non-negotiable constraints that remain in force:
- fastlane is the release rail.
- Keep Xcode automatic signing.
- Do not introduce match.
- iPhone only, iOS 17+, JA/EN, no login/account/IAP/subscription.
- Supported codecs: H.264, HEVC, ProRes. DNxHR/DNxHD explicitly unsupported in v1 metadata.
- No fallback-oriented design (no screenshot fallback, no upload auth fallback, no silent backend switching).
- Do not revert unrelated dirty worktree changes.
- The user performs all git commits and pushes. Do not commit on their behalf.

Current verified status:
- `./scripts/bundle.sh exec fastlane ios screenshots` passes deterministically. 5 screenshots are staged under fastlane/screenshots/{ja,en-US}/.
- `./scripts/bundle.sh exec fastlane ios archive` passes end-to-end and produces build/fastlane/Filmtone.ipa, distribution-signed with Apple Distribution: takumi chiba (C3G77H8NM6), profile "iOS Team Store Provisioning Profile: com.chibatakumi.film.lab.ios", get-task-allow=false, no ProvisionedDevices.
- `./scripts/bundle.sh exec fastlane lanes` parses cleanly.
- metadata, beta, release have NOT been run yet because ASC_KEY_ID / ASC_ISSUER_ID / (ASC_KEY_CONTENT or ASC_KEY_PATH) / REVIEW_PHONE were unset in the previous shell.

Your immediate objective:
1. Read the handoff doc.
2. Confirm the env vars in section 8.1 are available in the current shell. If not, ask the user to provide them (do not attempt to pull secrets yourself).
3. Run `./scripts/bundle.sh exec fastlane lanes` as a sanity check.
4. Run `./scripts/bundle.sh exec fastlane ios metadata` and verify success.
5. Run `./scripts/bundle.sh exec fastlane ios release` (upload-only first). If the user explicitly asks to submit for review, re-run with `SUBMIT_FOR_REVIEW=1`. If the user asks for auto-release after approval, add `AUTOMATIC_RELEASE=1`.
6. `./scripts/bundle.sh exec fastlane ios beta` is optional. Run it only if TestFlight upload is explicitly desired.
7. After each lane, confirm exit code 0, no [!] lines, and that App Store Connect reflects the change.
8. After all verifications, propose a narrowly scoped commit set to the user (do not commit yourself).

Important technical guidance:
- Prefer the simplest known-good path over clever recovery.
- archive is already solved; treat it as done unless new evidence proves otherwise.
- If a lane fails due to ASC auth, surface the precise error instead of falling back.
- Before making any substantial reasoning step, use sequential thinking.
- When you need cross-cutting exploration, Agent Teams / subagents are fine for genuinely independent work.

Start by reading the handoff doc and producing a 3-line plan.
```

---

## 13. Change Log For This Handoff

- 2026-04-20 01:48 JST — screenshot rail finalized; archive still blocked on distribution cert.
- 2026-04-20 02:05 JST — signing fix landed; archive verified producing distribution-signed IPA; `beta` auth simplified to ASC API key only; `RELEASE.md` refreshed.
- 2026-04-20 02:15 JST — this handoff written as the cold-start doc for the next chat. Supersedes 01:48 and 2026-04-20.md.
