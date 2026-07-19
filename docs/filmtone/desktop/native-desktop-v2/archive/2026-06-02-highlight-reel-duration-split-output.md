# Active: Highlight Reel Duration And Split Output

Milestone: M5 Native Editing UI

Goal:

- Let Desktop and iPad users choose Highlight Reel clip duration instead of
  being locked to one second.
- Let users choose whether Highlight output is one combined reel or separate
  files per marker segment.
- Keep normal video export, still export, sidecar schema, and Slow 24 timing
  behavior unchanged.

Edit targets:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneHighlightMarkers.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift`
- Highlight export tests under the affected Desktop/iPad/shared surfaces.

Read-only references:

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-05-dhm-5-marker-highlight-reel.md`
- Existing iOS export architecture docs only when live source files leave an
  implementation question open.

Checklist:

- [x] Confirm current Desktop and iPad Highlight export flow and constraints.
- [x] Add shared options helpers for duration and separate/combined behavior.
- [x] Wire Desktop UI state, controls, and export coordinator.
- [x] Wire iPad UI state, controls, and export coordinator.
- [x] Add or update focused tests for duration and split behavior.
- [x] Run the smallest verification that proves the changed surfaces.
- [x] Record Copy / History Impact and archive this task.

Verification:

- `cd packages/film-lab-swift-core && swift test` passed.
- `bun run verify:desktop` passed.
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App-iPad -destination 'generic/platform=iOS Simulator'
  -configuration Debug build CODE_SIGNING_ALLOWED=NO` passed.
- `bun run verify:ios` passed.
- `bun run check:filmtone-copy` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

Completion notes:

- Desktop and iPad now expose Highlight duration choices for 1, 3, 5, and 10
  seconds.
- The default remains the existing one-second combined reel.
- Combined Highlight output merges overlapping selected-duration marker windows.
- Separate Highlight output writes one clip per marker window and shares all
  generated iPad files as a package list.

Copy / History Impact:

- No public copy/history impact: this change adds in-app Highlight controls and
  export behavior, but does not change release, platform, version, privacy,
  codec, or implementation-history claims.
- Article Opportunity: Release-note only.
- Change-History Opportunity: No story.

Done conditions:

- Desktop and iPad expose Highlight duration choices including 1, 3, 5, and 10
  seconds.
- Existing one-second combined Highlight behavior remains the default.
- Combined Highlight output uses the selected duration and retains overlap merge
  behavior.
- Separate Highlight output writes distinct outputs for individual marker
  segments with the selected duration.
- Verification has been run or a concrete blocker is recorded.

Stop conditions:

- Done conditions met.
- An unexpected product decision is needed for multi-file sharing on iPad.
- The same verification step fails 3 consecutive times.

Out of scope:

- DaVinci importer changes.
- Public release/version metadata changes.
- Sidecar schema bumps.
- Portfolio website updates.
- Legacy Electron Desktop changes.

Unexpected blockers:

- None yet.
