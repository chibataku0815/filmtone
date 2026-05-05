# Mac App Store Readiness

This lane tracks the first Mac App Store-ready Filmtone Desktop build. It is
separate from Native Desktop v2 M5-M work and uses:

- Worktree:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-mac-app-store-readiness`
- Branch: `feature/macos-app-store-readiness`
- Bundle ID: `com.chibatakumi.film-lab-desktop`

## Scope

Done in this lane:

- Add a Mac App Store archive/export lane without changing the existing
  Developer ID DMG lane.
- Add Mac App Store sandbox entitlements.
- Preserve user-selected read/write access for open/export flows.
- Keep sidecar JSON output adjacent to the selected export file.
- Add checks that protect the Developer ID lane from accidental MAS changes.

Not included:

- App Store Connect app record creation.
- Metadata, screenshots, privacy answers, upload, review submission, or public
  release switch.
- Universal Purchase with the existing iOS app.
- Human GUI smoke of the installed/exported build with real still, landscape
  video, and portrait iPhone video sources.

## Current State

The active readiness task is complete and archived at:

- `archive/2026-05-05-mas-readiness.md`

The local Mac App Store export proof produced:

- `apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`

The export completed locally. Xcode also reported a missing stored Xcode account
token for `info@adoyosu.com`, but this did not block local package export.

Before App Store Connect upload, run one final human GUI smoke on the exported or
installed MAS-style build: open one still, one landscape video, and one portrait
iPhone video, then export each to a chosen non-container folder and confirm media
plus sidecar JSON are present.
