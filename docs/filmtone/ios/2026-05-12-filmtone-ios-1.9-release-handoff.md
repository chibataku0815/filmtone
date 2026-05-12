# Filmtone iOS 1.9 Release Handoff

Date: 2026-05-12 JST

## Scope

- Prepare iOS `MARKETING_VERSION=1.9` / `CURRENT_PROJECT_VERSION=8`.
- Update only localized App Store "What's New" copy for `ja`, `en-US`, and
  `en-GB`.
- Keep title, subtitle, screenshots, descriptions, support URL, marketing URL,
  privacy URL, and portfolio submodule untouched.

## Change Review

- Audio preservation: iOS capture now records microphone audio for app-captured
  clips, normal video export preserves source audio from original source assets,
  and completed output files are validated for audio tracks before success is
  reported. Highlight-reel exports remain source-audio disabled.
- Texture softness: Advanced controls expose `detailSoftness` as `Texture
  softness`, distinct from lens/periphery softness. The render pass uses an
  amplitude-gated bilateral detail layer rather than a plain blur, and native
  export applies conservative runtime-only source detail bias from source
  metadata.
- Architecture: the native SwiftUI / AVFoundation iOS app is now organized by
  capture, editor, export, look, optics, source, services, smoke, strings, and
  root surfaces. This is release support, not the public headline.

## Copy / History Impact

- Public copy update required: App Store release notes now mention audio
  preservation, Texture softness, and export/package diagnostics for 1.9.
- Implementation history update required: no change to
  `filmtone-implementation-history.md`; this release follows the existing
  shared-color-truth + native-runtime framing.
- Release/App Store claim: run the iOS truth script before saying 1.9 is
  public. At prep time, public App Store remains 1.8 while local candidate is
  1.9 build 8.
- Article Opportunity: Full article candidate — 1.9 combines output reliability
  and a visible image-quality control. Publish only after App Store public truth
  reports 1.9.
- Change-History Opportunity: Context paragraph — mention that React +
  Capacitor was a rational WebGPU/WebGL reuse path and that the current native
  path keeps shared color truth while improving capture/export runtime quality.

## Verification

- Release truth:
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh`
    reports public App Store `1.8` and local Xcode candidate `1.9` build `8`.
  - App Store Connect has iOS version `1.9`, selected build `8`, state
    `WAITING_FOR_REVIEW`.
  - Automatic release remains disabled; do not describe 1.9 as public until
    the truth script reports public `1.9`.
- Build and package checks passed:
  - `bun run build:core`
  - `bun run build:renderer`
  - `bun run build:smart-look`
  - `bun run verify:ios`
  - `swift test --package-path packages/film-lab-swift-core` (64 tests)
  - targeted core detail/schema tests (106 tests)
- Copy/context checks passed:
  - Japanese product-copy mechanical check for release notes + article draft
  - `bun run check:filmtone-copy`
  - `bun run check:filmtone-context`
  - `git diff --check`
- Release commands completed:
  - `bun run release:env:check`
  - `bun run release:archive`
  - IPA plist check confirmed `CFBundleShortVersionString=1.9`,
    `CFBundleVersion=8`, and bundle id `com.chibatakumi.film.lab.ios`.
  - `bun run release:appstore-binary`
  - `bun run release:release-notes`
  - `bun run release:submit-review-notes`
- Release submission note: the first review-notes submission attempt failed
  because ASC build processing had not surfaced build `8` yet. Retried after
  processing delay; build `1.9 (8)` was selected and submitted successfully.

## Known Remaining Product Risks

- Detail Softness broad cross-renderer/material visual matrix remains a final
  QA item, not a blocker for the iOS 1.9 candidate because the iOS real-device
  QA and frame-level edge-preservation tests passed. Do not overclaim it in
  release copy.
