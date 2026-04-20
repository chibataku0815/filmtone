# Filmtone iOS Release Rail

This app-scoped release rail lives entirely under `apps/capacitor-film-lab-ios`. It keeps automatic signing in Xcode and does not use `match`.

## Install

From this app directory:

```sh
./scripts/bundle.sh install
```

## Required Environment

App Store Connect API key authentication is required for `archive`, `metadata`, `beta`, and `release`:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- Either `ASC_KEY_CONTENT` or `ASC_KEY_PATH`

`ASC_KEY_CONTENT` can be the raw `.p8` contents or the same text with `\n` escapes. `ASC_KEY_PATH` can be absolute or relative to this app directory.

The `archive` lane accepts the key env vars as optional: when present, they are forwarded to `xcodebuild` as `-authenticationKey*` flags so App Store distribution assets can be fetched via `-allowProvisioningUpdates` without a logged-in Xcode GUI. When absent, Xcode automatic signing still runs under `-allowProvisioningUpdates` using whatever Apple Developer account is already configured in Xcode Preferences.

Required for `metadata` and `release` lanes:

- `REVIEW_PHONE`

Required for `beta` and `release` lanes:

- `IPA_PATH` (example: `build/fastlane/Filmtone.ipa`)

Optional review overrides:

- `REVIEW_FIRST_NAME`
- `REVIEW_LAST_NAME`
- `REVIEW_EMAIL`
- `REVIEW_DEMO_USER`
- `REVIEW_DEMO_PASSWORD`
- `REVIEW_NOTES`

Optional team selection:

- `APPLE_DEVELOPER_TEAM_ID`
- `APPLE_DEVELOPER_TEAM_NAME`
- `APP_STORE_CONNECT_TEAM_ID`
- `APP_STORE_CONNECT_TEAM_NAME`
- `FASTLANE_USER`

Optional URL overrides for staged metadata:

- `FILMTONE_CANONICAL_BASE_URL`
- `FILMTONE_MARKETING_URL`
- `FILMTONE_SUPPORT_URL`
- `FILMTONE_PRIVACY_URL`
- Locale-specific overrides such as `FILMTONE_MARKETING_URL_JA` or `FILMTONE_MARKETING_URL_EN_US`

Optional screenshot-locale override:

- `SNAPSHOT_BASE_LOCALE` (defaults to `ja`)

## App-local Commands

```sh
bun run release:bundle:install
bun run release:archive
bun run release:screenshots
bun run release:metadata
bun run release:beta
bun run release:appstore
```

## Typical Local Flow

1. Build the web shell if needed:

```sh
bun run build
```

2. Archive the signed app-store build:

```sh
bun run release:archive
```

The archive lane writes `build/fastlane/Filmtone.ipa`. `beta` and `release` do not archive implicitly.

3. Capture screenshots with the shared `App` scheme. The lane targets one deterministic simulator (`iPhone 17 Pro Max` on iOS 26.2, UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`), runs the dedicated screenshot UI test once, and stages the resulting asset set into both `ja` and `en-US`. There is no device fallback and no runtime discovery:

```sh
bun run release:screenshots
```

4. Sync localized metadata and review info:

```sh
REVIEW_PHONE='+81-90-0000-0000' bun run release:metadata
```

5. Upload a TestFlight build. Pass the archived `.ipa` explicitly:

```sh
IPA_PATH=build/fastlane/Filmtone.ipa bun run release:beta
```

6. Upload the release candidate to App Store Connect. The `release` lane requires both an explicit `.ipa` path and staged screenshots under `fastlane/screenshots/{ja,en-US}`:

```sh
IPA_PATH=build/fastlane/Filmtone.ipa REVIEW_PHONE='+81-90-0000-0000' bun run release:appstore
```

To submit for review from the `release` lane, opt in explicitly:

```sh
IPA_PATH=build/fastlane/Filmtone.ipa SUBMIT_FOR_REVIEW=1 REVIEW_PHONE='+81-90-0000-0000' bun run release:appstore
```

To auto-release after approval:

```sh
IPA_PATH=build/fastlane/Filmtone.ipa AUTOMATIC_RELEASE=1 SUBMIT_FOR_REVIEW=1 REVIEW_PHONE='+81-90-0000-0000' bun run release:appstore
```

## Notes

- `archive` uses `ios/App/App.xcworkspace`, scheme `App`, `export_method: app-store`, and passes `-allowProvisioningUpdates` on both the build and export phases. The lane sets `signingStyle: automatic` and `teamID: C3G77H8NM6` in the export options so Xcode can resolve distribution signing assets without a manual selection step.
- When ASC API key env vars are present, the same key material is forwarded to `xcodebuild` via `-authenticationKeyID`, `-authenticationKeyIssuerID`, and `-authenticationKeyPath`, so provisioning assets can be fetched headlessly. If only `ASC_KEY_CONTENT` is set, the lane writes it to a temporary `.p8` file for the duration of the run and removes it on exit.
- `scripts/bundle.sh` prefers Homebrew Ruby (`brew --prefix ruby`) so `bundle exec fastlane ...` does not accidentally run against macOS system Ruby.
- `screenshots` is deterministic: it targets one simulator (`iPhone 17 Pro Max` / iOS 26.2 / UDID `D3011FE4-52CA-4B7F-B181-A55D9998E192`), runs the dedicated UI test once, and stages the resulting asset set into both `ja` and `en-US`. There is no simulator discovery, no runtime iteration, and no retry loop.
- `beta` and `release` are fail-fast: they require `IPA_PATH`, verify that the file exists, and will not re-run `archive` implicitly.
- `release` is also fail-fast on screenshots: each locale in `fastlane/screenshots/{ja,en-US}` must have 1-10 files, counts must match across locales, and filenames must line up. Missing screenshots are treated as an error, not as a skip path.
- Override the capture locale with `SNAPSHOT_BASE_LOCALE` (defaults to `ja`).
- Metadata is staged from `fastlane/metadata` into `fastlane/.generated/metadata` so URL values can be injected from env vars without mutating the checked-in copy.
- Support and privacy URLs default to the dedicated `/film-lab/support` and `/film-lab/privacy` pages on `www.chibatakumi.studio`.
- The checked-in metadata keeps Filmtone positioned as a local-first iPhone grading tool and deliberately avoids AI, subscription, or cloud-sync promises.
- `beta` requires ASC API key auth. Apple-ID + app-specific password fallback is no longer supported; TestFlight upload goes through the same API key material as `metadata` and `release`.
