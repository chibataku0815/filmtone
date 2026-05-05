# Mac App Store Readiness Task

Date: 2026-05-05

## Goal

Create a Mac App Store-submittable, sandboxed macOS build lane for Filmtone
Desktop while preserving the existing Developer ID DMG release lane.

## Edit Targets

- `apps/filmtone-desktop-macos/ExportOptionsAppStore.plist`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/FilmtoneDesktopAppStore.entitlements`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `scripts/release-macos-app-store.sh`
- `scripts/check-macos-app-store-readiness.mjs`
- `package.json`

## Completed

- Created worktree
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-mac-app-store-readiness`
  on branch `feature/macos-app-store-readiness`.
- Added Mac App Store export options using `app-store-connect`.
- Added MAS entitlements with App Sandbox and user-selected read/write access.
- Added a separate MAS release script, leaving the existing Developer ID DMG
  scripts and export options unchanged.
- Added sandbox-scoped access around source and output URLs during still, video,
  and highlight reel export tasks.
- Added verification coverage for adjacent sidecar JSON writes beside a selected
  export output.
- Added a read-only MAS readiness guard script.

## Verification

Passed:

- `bun run check:macos-appstore`
- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:macos`
- `bash -n scripts/release-macos-app-store.sh`
- `git diff --check`
- MAS sandbox debug build with
  `CODE_SIGN_ENTITLEMENTS=FilmtoneDesktop/FilmtoneDesktopAppStore.entitlements`
- Entitlement inspection of the sandbox debug app
- `FILMTONE_MAS_ARCHIVE_ONLY=1 scripts/release-macos-app-store.sh`
- `scripts/release-macos-app-store.sh`
- `pkgutil --check-signature apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`

Local export artifact:

- `apps/filmtone-desktop-macos/build/app-store/1.4/export/Filmtone.pkg`

## Notes

The full export completed locally. Xcode emitted a warning about a missing
stored token for the `info@adoyosu.com` account, but the local package export was
not blocked.

App Store Connect record setup, metadata, screenshots, upload, review
submission, and public release switching remain outside this task.

Human GUI smoke on the installed/exported build remains the final pre-upload
check: still, landscape video, and portrait iPhone video open/export to a chosen
non-container folder with adjacent sidecar JSON present.
