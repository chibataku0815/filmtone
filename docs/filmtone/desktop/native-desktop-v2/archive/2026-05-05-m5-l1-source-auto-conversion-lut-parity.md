# M5-L1 Source Auto / Conversion LUT Parity

Date: 2026-05-05 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-m5-l1-source-auto`
Branch: `feature/native-desktop-m5-l1-source-auto`

## Milestone

M5 / Native Editing UI parity thin fix, supporting M3 color parity.

## Goal

Make Native Desktop source Auto behavior product-equivalent to iOS for supported
detectable source profiles, especially Apple Log / Apple Log 2, while keeping
preview, export, and sidecar source-profile resolution consistent.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneSourceProber.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneSourceProfileCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/SourceProfileControls.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`

## Read-Only References

- `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- `docs/filmtone/desktop/native-desktop-v2/2026-05-05-native-desktop-v2-ios-parity-next-handoff.md`

## Checklist

- [x] Port iOS first-sample log-transfer fallback into Desktop video probing.
- [x] Add iOS-style source-change retention/reset policy for Desktop source profiles.
- [x] Surface Auto detection in the Source control using iOS-style labels.
- [x] Add focused Verify coverage for detection, source-change policy, and Auto labels.
- [x] Run required verification.
- [x] Relaunch the Debug app for visual smoke.
- [x] Record completion and archive this active task.

## Verification

- `bash apps/filmtone-desktop-macos/Verify/run.sh`
- `bun run verify:macos`
- `git diff --check`
- Relaunch Debug app:
  `pkill -x Filmtone 2>/dev/null || true`
  `open -n apps/filmtone-desktop-macos/build/Build/Products/Debug/Filmtone.app`

## Done Conditions

- Auto resolves Apple Log / Apple Log 2 when the signal is only present on the
  first decoded sample.
- Detectable manual profile selections reset to Auto on source mismatch;
  non-detectable manual profiles stay sticky.
- The Source control visibly communicates Auto detection while preserving
  source-cap warning priority.
- Preview/export/sidecar source-profile resolution remains on the existing
  shared Desktop path.
- Verification is green.

## Stop Conditions

- Done met.
- Unexpected blocker.
- 3 consecutive verification failures.

## Out Of Scope

- M5-L2 advanced recipe chip discoverability.
- M5-L3 Backlight Veil.
- New sidecar schema version or public API change.
- Shortcut changes.
- Portfolio, DHM, release artifact, notarization, staging, commit, push.

## Unexpected Blockers

- None yet.

## Completion Log

- Added Desktop first-sample Apple Log / Apple Log 2 log-transfer fallback,
  iOS-style source-profile source-change policy, and visible Auto detection
  labels.
- Verification:
  - `bash apps/filmtone-desktop-macos/Verify/run.sh` — 93/93 passed.
  - `bun run verify:macos` — Debug build succeeded.
  - `git diff --check` — clean.
  - Debug app launched from this worktree and `Filmtone` process was running.
- User confirmed real-device / real-media visual smoke after handoff.
- Remaining product risk: media with no detectable Apple Log / Apple Log 2
  metadata still requires manual Source profile selection.
