# Filmtone iOS 1.8 Release Handoff

Date: 2026-05-10 JST

Status note: this handoff records the pre-public submission state from
2026-05-10. A 2026-05-12 truth refresh reports public App Store version `1.8`;
use `docs/filmtone/ios/README.md` and the iOS truth script for current state.

## What Changed

- Prepared iOS `MARKETING_VERSION=1.8` / `CURRENT_PROJECT_VERSION=7`.
- Updated only App Store "What's New" copy for `ja`, `en-US`, and `en-GB`.
- Added narrow Fastlane release lanes for binary-only upload, release-notes-only
  sync, and review submission without re-uploading title, subtitle, screenshots,
  descriptions, or URLs.

## Release Truth

- Public App Store version remains `1.7` until Apple approves/releases 1.8.
- App Store Connect version `1.8` is `PENDING_DEVELOPER_RELEASE`.
- Selected App Store build: `1.8` build `7`.
- Automatic release was not enabled for submission.

## Verification

- `git diff --check`
- `ruby -c apps/capacitor-film-lab-ios/fastlane/Fastfile`
- `bun run verify:ios`
- `bun run release:archive`
- IPA check: `CFBundleShortVersionString=1.8`,
  `CFBundleVersion=7`, bundle id `com.chibatakumi.film.lab.ios`.
- `bun run release:appstore-binary`
- `bun run release:release-notes`
- `bun run release:submit-review-notes`
- Post-submission docs/copy cleanup: `bun run check:filmtone-copy`,
  `git diff --check`, then `bun run release:release-notes` to resync the
  adjusted Japanese "What's New" text.

## Remaining Risk

- Apple review has passed; manual developer release is pending.
- Public iTunes lookup still reports `1.7` until manual release completes.

## Plan Compliance

- Release scope stayed limited to the iOS `1.8` binary, build-number bump,
  "What's New" copy, and release-lane tooling needed to avoid metadata or
  screenshot churn.
- Title, subtitle, screenshots, descriptions, marketing URLs, support URLs,
  and privacy URLs were not re-uploaded by the release-specific lanes.

## Cross-Stream Visibility

- Capture-practicality completion state is recorded in
  `capture-practicality/strategy.md`.
- Completed active work moved to
  `capture-practicality/archive/2026-05-10-s5-recording-preview-performance.md`.
- Public state remains separate from local/ASC state: public `1.7`, ASC
  `1.8` `PENDING_DEVELOPER_RELEASE`.

## Scope Diff

- In scope: version/build bump, release notes, binary-only upload,
  release-notes-only sync, review submission, and short documentation cleanup.
- Out of scope: title/subtitle/screenshot changes, broad QA matrix, portfolio
  updates, App Store screenshot refresh, and product-code changes after the
  release candidate was built.

## Remaining Tasks

- Watch Apple review outcome.
- Decide whether to manually release immediately or hold.
- If rejected, use the ASC rejection reason as the next single `active.md`
  scope before making changes.
