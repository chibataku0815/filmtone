# Active: Highlight Reel Split Output Hardening

Milestone: M5 Native Editing UI

Goal:

- Harden the new Highlight Reel duration and split-output workflow for Desktop
  and iPad before it becomes release-facing behavior.
- Make multi-file output predictable, understandable, and resilient across
  repeated exports, cancel paths, and sharing.
- Keep the existing default of one-second combined Highlight output unchanged.

Edit targets:

- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneHighlightMarkers.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- Focused tests under affected shared, Desktop, and iPad surfaces.

Read-only references:

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-reel-duration-split-output.md`
- Existing export/share code around the affected Desktop and iPad surfaces.

Checklist:

- [x] Inspect current split-output implementation for product and failure-mode
  gaps.
- [x] Tighten deterministic naming, duplicate handling, and result reporting
  where needed.
- [x] Add focused test coverage for the highest-risk multi-file behavior.
- [x] Run the smallest verification that proves the hardened surfaces.
- [x] Record Copy / History Impact and archive this task.

Verification:

- Targeted `CacheStore` script compile/run passed.
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App-iPad -destination 'generic/platform=iOS Simulator'
  -configuration Debug build CODE_SIGNING_ALLOWED=NO` passed.
- `bun run verify:ios` passed.
- `cd packages/film-lab-swift-core && swift test` passed.
- `bun run verify:desktop` passed.
- `bun run check:filmtone-context` passed.
- `git diff --check` passed.

Completion notes:

- iPad Highlight exports now pass a readable preferred output name into the
  export cache. Combined output uses `source-highlight-{duration}` and split
  output uses `source-highlight-{duration}-{index}` before the cache's unique
  suffix.
- `CacheStore.temporaryExportURL` now supports sanitized preferred export names
  while preserving the existing `filmtone-export` default for normal exports.
- iPad split Highlight results now save every generated clip to Photos instead
  of saving only the first output. Connect package saves are still protected
  from non-media companion files by keeping package multi-save limited to the
  no-sidecar Highlight split result shape.

Copy / History Impact:

- No public copy/history impact: this hardens file naming and multi-file save
  behavior for the in-app Highlight export path without changing release,
  version, platform, privacy, codec, or implementation-history claims.
- Article Opportunity: Release-note only, covered by the Highlight duration /
  split-output feature note.
- Change-History Opportunity: No story.

Done conditions:

- Separate Highlight output behaves predictably when run repeatedly into the
  same destination.
- Desktop and iPad result/share surfaces correctly represent multi-file output.
- Edge cases found during inspection are either fixed or explicitly recorded as
  remaining product risks.
- Verification has passed or a concrete blocker is recorded.

Stop conditions:

- Done conditions met.
- A product decision is needed for an output behavior that cannot be inferred
  from existing export conventions.
- The same verification step fails 3 consecutive times.

Out of scope:

- New Highlight detection algorithms.
- DaVinci importer changes.
- Public release/version metadata changes.
- Portfolio website updates.
- Legacy Electron Desktop changes.

Unexpected blockers:

- None yet.
