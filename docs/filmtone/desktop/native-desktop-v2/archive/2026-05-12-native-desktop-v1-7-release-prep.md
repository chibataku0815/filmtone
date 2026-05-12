# Active - Native Desktop v1.7 Release Prep

Date opened: 2026-05-12 JST
Milestone: `M9 Native Desktop v1.7 Release Prep`

## Goal

Prepare the next Native Desktop release after public Desktop v1.6. The release
candidate should carry the post-v1.6 product changes that matter on Desktop:
completed-output audio preservation for normal video export, and Texture
Softness / source detail compensation for reducing hard digital fine detail.

Primary exit for this task: local release candidate state is coherent
(`MARKETING_VERSION=1.7`, build `4`, release notes and article draft prepared,
focused verification green, signed/notarized/stapled DMG produced). Public DMG
upload and update metadata mutation are explicitly out of scope until the owner
confirms that public cutover step.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.7.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/2026-05-12-filmtone-desktop-v1-7-article-jp.md`

## Read-Only References

- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.6.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-10-native-desktop-v1-6-release.md`
- `docs/filmtone/export-audio/archive/2026-05-12-export-audio-restoration-a.md`
- `docs/filmtone/detail-softness/strategy.md`
- `docs/filmtone/detail-softness/archive/2026-05-12-phase-5-detail-softness-visual-tuning.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/filmtone-implementation-history.md`

## Checklist

- [x] Run Desktop/iOS truth scripts and confirm public Desktop latest is v1.6.
- [x] Review post-v1.6 Desktop-impacting commits.
- [x] Bump Native Desktop marketing version to `1.7` and build number to `4`.
- [x] Add v1.7 release notes.
- [x] Draft the Japanese release article with candidate/public-state guardrails.
- [x] Run focused product/release verification.
- [x] Build/sign/notarize/staple `Filmtone.app`.
- [x] Package/sign/notarize/staple `Filmtone-1.7.dmg`.
- [x] Verify DMG checksum and mounted app metadata.
- [x] Record verification results and known remaining risks.
- [x] Stop before public DMG upload/update metadata mutation.

## Verification

2026-05-12 JST:

- Release truth reports local Native Desktop `1.7` build `4`, release notes
  present, and public Desktop latest still `1.6`.
- `bun run build:core` passed.
- `bun run build:renderer` passed.
- `swift test --package-path packages/film-lab-swift-core` passed
  (`64/64`).
- Targeted core Detail Softness / Source Detail Compensation tests passed
  (`33/33`).
- `bash apps/filmtone-desktop-macos/Verify/run.sh` passed (`124/124`).
- `bun run verify:macos` passed (`** BUILD SUCCEEDED **`).
- `bun run release:cutover-preflight` passed before packaging with the expected
  "DMG not built yet" warning, then passed after packaging with the v1.7 DMG
  present.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- Japanese product-copy mechanical check passed for the article draft.
- `git diff --check` passed.
- `scripts/release-macos.sh` passed; `Filmtone.app` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `scripts/package-dmg.sh` passed; `Filmtone-1.7.dmg` is signed, notarized,
  stapled, and Gatekeeper accepted as Notarized Developer ID.
- `Filmtone-1.7.dmg` sha256:
  `cb23f1f0b1f37c17f4eaf547975a88bc48d6ae28b720256950ffcf821ede2045`.
- Mounted DMG check passed: `Filmtone.app` exists, Applications symlink exists,
  Bundle ID is `com.chibatakumi.film-lab-desktop`, short version is `1.7`,
  build version is `4`, and the mounted app is Gatekeeper accepted.

Public upload/update metadata mutation was not run.

## Done Conditions

- Native Desktop local release truth reports `1.7` build `4`.
- v1.7 release notes describe only behavior included in the Desktop release
  candidate.
- Article draft is marked as candidate copy until public update metadata reports
  v1.7.
- Focused verification passes.
- The local `Filmtone-1.7.dmg` is signed, notarized, stapled, and Gatekeeper
  accepted.

## Stop Conditions

- Stop before production DMG upload or update metadata switch unless the owner
  explicitly confirms public mutation.
- Stop after 3 consecutive failures on the same verification step.
- Stop if verification shows `detailSoftness: 0` changes existing output,
  normal video export can silently drop audio from an audio-bearing source, or
  the article claim would require public state that is not yet true.
- Stop if unrelated dirty iOS working-tree changes become necessary to modify
  for Desktop release prep.

## Out Of Scope

- iOS 1.9 release submission or App Store metadata.
- Portfolio submodule bump or public web source edits.
- Public Desktop DMG upload/update metadata mutation.
- Mac App Store review submission.
- Broad visual matrix expansion beyond release-critical checks.

## Change Review

- Audio preservation: Native Desktop normal video export now reads an audio
  track when the source has one, writes AAC audio into the MP4, and validates
  the completed output file before reporting preserved audio. Highlight-reel
  export remains source-audio disabled.
- Texture Softness: `detailSoftness` is now a shared user param, exposed on
  Desktop as `Texture softness`, with an amplitude-gated bilateral detail-layer
  render pass rather than plain blur.
- Source Detail Compensation: Native Desktop preview/still export/video
  export resolve a conservative runtime-only `sourceDetailBias` from source
  metadata and feed it into the Detail Softness stage without storing it in
  saved Looks.

## Copy / History Impact

- Public copy update required: v1.7 release notes and the release article draft
  should cover audio preservation and Texture Softness.
- Implementation history update required: no change to
  `filmtone-implementation-history.md`; the release follows the existing
  shared-color-truth + native-runtime framing.
- Release claim: Desktop truth script must report public v1.7 before the
  article or public copy says v1.7 is available.
- Article Opportunity: Full article candidate — this combines visible image
  quality and export reliability, but publish-language stays gated until the
  public release truth reports v1.7.
- Change-History Opportunity: Context paragraph — explain that Native Desktop
  has moved from a video-only AVFoundation writer to completed-file-validated
  audio preservation, and from lens/periphery softness only to a source-aware
  texture softness model.

## Unexpected / Blockers

None yet.

## Known Remaining Product Risks

- Public Desktop update metadata still reports `1.6`; v1.7 is not public until
  the DMG upload and update-meta switch are explicitly run.
- Texture Softness has frame-level non-blur tests and iOS real-device QA in the
  source lane, but the broad Desktop real-media visual matrix remains a
  post-release tuning watch item. Do not overclaim universal camera behavior in
  public copy.
- Source detail compensation is metadata-heuristic and conservative, not a
  manufacturer-certified transform.
