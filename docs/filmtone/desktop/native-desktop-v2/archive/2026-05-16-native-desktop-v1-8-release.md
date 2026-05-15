# Active - Native Desktop v1.8 Release

Milestone: `M10 Native Desktop v1.8 Release`

Goal: Publish the current Native Desktop main state as a new Desktop release
instead of re-uploading a different binary under the already-public v1.7
version.

Edit targets:

- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
- `apps/filmtone-desktop-macos/RELEASE_NOTES-v1.8.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- Current untracked design memos that must be either tracked or removed before
  release.

Read-only references:

- `apps/filmtone-desktop-macos/README.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/filmtone-release-version-sources.md`
- `docs/filmtone/filmtone-copy-quality-harness.md`
- `docs/filmtone/filmtone-copy-context-sync.md`

Checklist:

- [x] Confirm current public Desktop truth before changing release state.
- [x] Bump Native Desktop marketing version to `1.8` and build number to `5`.
- [x] Add v1.8 release notes from shipped current-main behavior only.
- [x] Clean the working tree by tracking the two untracked design memos.
- [x] Run Desktop, shared-core, MCP, copy/context, and diff checks.
- [x] Build, sign, notarize, staple, and package `Filmtone-1.8.dmg`.
- [x] Upload the v1.8 DMG, verify the public download rail, then update
  update metadata to v1.8.
- [x] Tag and push the release source.
- [x] Re-run release truth and record final verification.

Verification:

- [x] `bun run release:cutover-preflight`
- [x] `bun run verify:desktop`
- [x] `bash apps/filmtone-desktop-macos/Verify/run.sh`
- [x] `bun run build:core`
- [x] `bun run verify:filmtone-mcp`
- [x] `bun run check:filmtone-copy`
- [x] `bun run check:filmtone-context`
- [x] `git diff --check`
- [x] `scripts/release-macos.sh`
- [x] `scripts/package-dmg.sh`
- [x] `hdiutil verify apps/filmtone-desktop-macos/build/release/1.8/Filmtone-1.8.dmg`
- [x] `spctl --assess --type open --context context:primary-signature .../Filmtone-1.8.dmg`
- [x] mounted app version / build / bundle id check: `1.8` / `5` /
  `com.chibatakumi.film-lab-desktop`
- [x] mounted app Gatekeeper check: accepted, source `Notarized Developer ID`
- [x] public DMG HEAD check: `Filmtone-1.8.dmg` HTTP 200
- [x] fixed download page check: returns `Filmtone-1.8.dmg`
- [x] public update metadata check: `latestVersion: "1.8"`
- [x] release truth script after publication: public Desktop latest `1.8`

Done conditions:

- Public update metadata reports Desktop `1.8`.
- The fixed Desktop download rail returns `Filmtone-1.8.dmg`.
- The v1.8 DMG is signed, notarized, stapled, Gatekeeper accepted, and has its
  checksum recorded in release notes.
- The release source is committed, tagged as `desktop-v1.8`, and pushed.

Stop conditions:

- Done conditions met.
- Apple signing/notarization/upload credentials are unavailable.
- Unexpected release truth conflict.
- 3 consecutive failures on the same verification, signing, packaging, or
  upload command.

Out of scope:

- Mac App Store submission.
- Portfolio source/submodule bump.
- New product work beyond release correctness and already-landed current-main
  behavior.

Unexpected:

- Unrelated iOS candidate dirty state appeared during the Desktop release work.
  It was parked in named `pre-desktop-v1.8-unrelated-ios-*` stashes so the
  Desktop release commit does not silently carry iOS release-candidate changes.

## Release Result

- Public update metadata:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/film-lab/desktop/update-meta.json`
  reports `latestVersion: "1.8"`.
- Fixed download page:
  `https://www.chibatakumi.studio/film-lab/download` redirects to the current
  Filmtone download page, which returns `Filmtone-1.8.dmg`.
- Public DMG:
  `https://ehi6m41cp33jiopb.public.blob.vercel-storage.com/filmtone/desktop/Filmtone-1.8.dmg`
- DMG sha256:
  `8a7a398bff773ac6d9cd939ceea87ccc835b453a5aaff22696e7e156b5a82820`.
- Production deployment:
  `https://chibatakumi-portfolio-tyno7o0s9-forestones-projects.vercel.app`
  aliased to `https://www.chibatakumi.studio`.

## Copy / History Impact

- Public copy update required: v1.8 release notes, because this publishes
  post-v1.7 Desktop behavior.
- Implementation history update required: none; this release does not change
  the WebGPU / WebGL -> React + Capacitor -> native SwiftUI / AVFoundation
  history.
- Release claim: release truth after publication reports public Desktop `1.8`.
- Article Opportunity: Release-note only — the release has visible workflow
  changes, but the immediate task was release correctness.
- Change-History Opportunity: Context paragraph — v1.8 was cut because public
  v1.7 was already live, so the post-v1.7 main state needed a new version rather
  than a replacement artifact.
