# Active: Native Desktop And iPad Performance-Led Export Quality Reset

Date opened: 2026-07-07 JST
Milestone: M3 Native Color And Optics Parity / M5 Native Editing UI

## Goal

Make Film Damage and Highlight Reel feel production-ready on Native Desktop and
Native iPad before deciding what to carry to iPhone.

The product stance for this task is:

- Native Desktop and Native iPad lead performance-heavy editing/export work.
- iPad is the large-preview touch editor rail.
- Desktop is the long-session export and heavy-effect rail.
- iPhone receives only features that pass performance, thermal, screen-density,
  and export-wait filters.

## Loop Model

Run this task as short product-quality loops. Each loop must end with one of:

- a focused code/doc change inside this scope,
- a concrete product decision recorded below,
- or a stop-condition report.

Do not use loops for broad cleanup, release hygiene, portfolio work, or full QA.

Per-loop rhythm:

1. Observe the current surface: read only the files named by the next checklist
   item and the relevant dirty diff.
2. Decide the product issue: visual fidelity, export performance, touch
   ergonomics, or iPhone suitability.
3. Change the smallest product surface that resolves the issue.
4. Record the result in this file before moving to the next loop.
5. Defer wide verification unless the user explicitly asks for testing in the
   current task.

## Edit Targets

Primary product targets:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneExportSnapshot.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/ExportCoordinator.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/ExportInspectorPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadTouchControls.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadAdjustPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadLookPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadToolbar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadVideoTimelineBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Pad/FilmtonePadWorkspaceView.swift`
- `packages/film-lab-swift-core/Sources/FilmLabSwiftCore/FilmtoneHighlightMarkers.swift`

Documentation targets:

- `docs/filmtone/2026-07-07-native-desktop-ipad-restart-research.md`
- `docs/filmtone/desktop/native-desktop-v2/active.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md` only for a final
  1-3 line completion note or a required release-truth correction.

Existing verification files may be read as evidence, but do not add or modify
test files unless the user explicitly asks for test-file work in the current
task.

## Read-Only References

- `AGENTS.md`
- `README.md`
- `CLAUDE.md`
- `apps/filmtone-desktop-macos/README.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/desktop/README.md`
- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/2026-07-07-native-desktop-ipad-restart-research.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-06-film-damage-visibility-tuning.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-06-film-damage-render-speed-recovery.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-reel-duration-split-output.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-reel-split-output-hardening.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-02-highlight-split-finished-state-ux-polish.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-06-07-desktop-v1-16-ipad-v1-4-release.md`

## Checklist

- [x] Loop 0 - Intake: classify the existing dirty tree into keep / revise /
  defer / release-only buckets without reverting user changes.
- [x] Loop 1 - Film Damage product check: decide whether the current dark debris
  / hairline direction is the accepted Desktop+iPad visual target or needs
  focused adjustment.
- [x] Loop 2 - Film Damage performance check: identify whether current
  CoreImage work is good enough for FHD default and explicit 4K, or whether a
  Desktop/iPad-only Metal path should become the next task.
- [x] Loop 3 - Highlight Reel product check: confirm 1 / 3 / 5 / 10 second
  duration choices and combined/separate output are the desired Desktop+iPad
  behavior.
- [x] Loop 4 - Highlight Reel export-state check: make sure multi-file outputs
  are understandable in Desktop and iPad finished states.
- [x] Loop 5 - iPad touch check: finish the minimum touch-target and inspector
  polish needed for Look, Adjust, Timeline, and Export controls.
- [x] Loop 6 - iPhone filter: write an adoption table for each Desktop/iPad
  feature: `ship`, `ship reduced`, `hide`, or `defer`.
- [x] Loop 7 - Final decision: record the next implementation active task if
  this reset reveals a narrower follow-up.
- [x] Record Copy / History Impact, Article Opportunity, and
  Change-History Opportunity.
- [x] Archive this active task when Done conditions are met.

## Loop Log

Append concise entries here as loops complete.

| Loop | Result | Product Decision | Follow-up |
|---|---|---|---|
| 0 | Dirty tree classified. Keep: Film Damage kernel changes, Highlight Reel duration/split output, iPad touch controls, shared highlight contract. Release-only: Fastfile screenshot upload, iPad metadata release notes, Desktop release notes, release archive logs. Read-only evidence: touched verification files. | Continue product reset from existing work; do not revert user changes or treat release-only files as the core product surface. | Use Loops 1-5 to decide whether kept product changes need focused revision. |
| 1 | Desktop and iPad/iOS kernels both carry the same dark debris, reduced sparkle, embedded scratch, and broad material-mask direction. Archived June 6 notes record visual probes where black debris/flecks appear on bright material. | Keep the current dark debris / hairline Film Damage direction as the Desktop+iPad target. Do not tune it down for iPhone first. | Real-footage owner review remains the taste gate; no code change in this loop. |
| 2 | Current Desktop posture already matches the product need: FHD default, 4K opt-in, visible 4K time-cost warning, RGBA8 export context, and Film Damage broad-phase exits. June 6 timing notes record strong 3840 probe improvement from about 21.0ms/frame to about 17.0ms/frame. | Keep CoreImage as the current product path for FHD default and explicit 4K. Do not start a Metal rewrite inside this loop. | Track Desktop/iPad-only Metal Film Damage as a future task only if real footage still feels too slow after FHD/4K UX is accepted. |
| 3 | Shared contract exposes 1 / 3 / 5 / 10 second durations, `.combined` merges overlaps, `.separate` preserves one clip per marker window, and Desktop/iPad UI surfaces both duration and output mode. | Adopt this as the Desktop+iPad Highlight product behavior. Keep 1s combined as default; longer durations and split clips are explicit power controls. | Loop 4 should focus on finished-state clarity, not changing the underlying segment model. |
| 4 | Desktop finished state reports `Files / N clips`, reveals and shares `effectiveShareURLs`; iPad finished state reports clip count, changes Save to Photos to `N本を保存` / `Save N Clips`, saves every package URI, shares the package URI list, and protects package files from cache cleanup. | Multi-file finished-state behavior is acceptable for Desktop+iPad. Do not change the export contract in this loop. | Keep ready-state labels terse for now; if owner finds `Reel` / `Clips` unclear, make that a small iPad/Desktop copy polish task. |
| 5 | Look, Adjust, Toolbar, and Timeline already use shared iPad touch metrics. ExportPanel Highlight duration/mode chips were still shorter, so this loop added a 44pt minimum option-button height and explicit hit shape for those controls. | Minimum iPad touch finish line is now: 48pt-class Pad rail controls, enlarged timeline/icon targets, and at least 44pt export option chips. | No broad UI redesign. Future copy polish may expand `Reel` / `Clips` labels if owner finds them unclear. |
| 6 | iPhone adoption table completed. | iPhone is a selective downstream rail, not a parity rail. | Do not implement iPhone changes until the local iPhone source/version story is aligned with public `1.13`. |
| 7 | Reset completed. Strategy now carries current Desktop `1.16`, iPad `1.4`, and split iPhone public/local truth. The active decisions are narrowed to product acceptance rather than broad parity. | Do not open a general iPhone parity task. The next implementation active should be one focused target: real-footage Film Damage acceptance, Highlight finished-state copy polish, or a measured iPhone reduced-feature pass after the iPhone rail is aligned. | Archive this task. Create a new `active.md` only when selecting one narrower target. |

## iPhone Adoption Table

Fill this during Loop 6.

| Desktop / iPad feature | iPhone decision | Reason | Required reduction |
|---|---|---|---|
| Film Damage default | Ship reduced | The visual direction is valuable, but iPhone has less thermal/export margin and the local iPhone rail is not aligned with public `1.13`. | Keep default/moderate damage only; do not use Desktop/iPad-heavy positioning or 4K-first copy. |
| Film Damage heavy / 4K combinations | Defer | Heavy damage plus 4K is exactly where Desktop/iPad have the advantage. | Keep Desktop/iPad-led until measured on current iPhone hardware and local release state is clean. |
| Highlight 1s combined | Ship | This preserves the original Highlight behavior and has the lowest export-wait risk. | Keep one-tap/simple UI; do not expose split output as part of the same first iPhone pass. |
| Highlight 3s / 5s / 10s combined | Ship reduced | Longer clips are useful but scale export time directly, especially with Film Damage. | Prefer 3s/5s first; keep 10s hidden or deferred until measured. |
| Highlight separate clips | Defer | Multi-file save/share and repeated render loops add wait time and UI complexity on a small screen. | Revisit only after Desktop/iPad split output is accepted and iPhone package sharing is explicitly designed. |
| iPad touch inspector controls | Hide | These controls are designed for large-preview tablet editing and should not be compressed into iPhone. | Keep iPhone on sheet/fullscreen patterns with fewer simultaneous controls. |

## Verification

Do not run tests, test suites, test commands, or test-like verification unless
the user explicitly asks for testing in the current task.

Results for this loop work:

- Desktop release truth script run on 2026-07-07 JST: native marketing version
  `1.16`, build `12`; public update metadata latest version `1.16`; latest
  Desktop tag still `desktop-v1.12` with `11` commits after tag.
- iOS truth script run on 2026-07-07 JST: iPhone public App Store version
  `1.13`; local Xcode candidate `1.11` build `15`.
- Live Apple lookup for `com.chibatakumi.film.lab.ipad` run on 2026-07-07 JST:
  iPad public App Store version `1.4`, released
  `2026-06-07T15:50:15Z`.
- Test suites, builds, `xcodebuild`, `swift test`, and formatting verification
  were skipped because the current user request did not explicitly ask for
  testing.

When testing is explicitly requested, use the smallest proof for the changed
surface:

- Film Damage Desktop surface:
  - focused visual/export probe if available,
  - `bash apps/filmtone-desktop-macos/Verify/run.sh`,
  - `bun run verify:desktop`.
- iPad export/editor surface:
  - `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App-iPad -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`,
  - `bun run verify:ios`.
- Shared Swift highlight contract:
  - `cd packages/film-lab-swift-core && swift test`.
- Release/version claims:
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`,
  - `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone`,
  - live Apple lookup for `com.chibatakumi.film.lab.ipad` when iPad public
    state is mentioned.
- Formatting:
  - `git diff --check`.

Skipped at task creation: all test and verification commands, because the
current user request only asks for a plan document.

## Done Conditions

- The existing dirty Desktop/iPad Film Damage and Highlight work is classified
  into keep / revise / defer / release-only.
- Desktop/iPad Film Damage has an explicit product decision for visual target
  and performance posture.
- Desktop/iPad Highlight Reel has an explicit product decision for duration,
  combined output, split output, and finished-state behavior.
- iPad touch ergonomics have a minimum finish line for the current editor
  surface.
- iPhone has a feature adoption table based on performance and UI constraints,
  not blanket parity.
- No release/version claim in this active task relies on stale Desktop `1.15`
  or iPad `1.3` text.
- Copy / History Impact and opportunity classifications are recorded.

## Stop Conditions

- Done conditions are met.
- Owner visual judgment is needed for Film Damage real-footage taste and cannot
  be inferred from source or existing references.
- Existing dirty changes overlap the target files in a way that makes ownership
  unclear.
- The task requires a long-term milestone restructure rather than a scoped
  Desktop/iPad quality reset.
- The same explicitly requested verification command fails 3 consecutive times.

## Out Of Scope

- Legacy Electron Desktop.
- Portfolio submodule bump or public web edits.
- Broad release packaging, notarization, App Store submission, or metadata
  upload unless the user explicitly switches to release work.
- iPhone full parity.
- New settings pages, decorative banners, or broad UI redesign outside the
  active editing/export surface.
- Creating or modifying test files unless explicitly requested.
- Staging, committing, pushing, or tagging.

## Unexpected Blockers

- None yet.

## Copy / History Impact

No public copy/history impact: this loop changed internal planning/strategy
truth and one iPad export touch-target implementation detail. It did not edit
App Store metadata, public web copy, release notes, product positioning copy, or
implementation-history prose.

Article Opportunity: No story.

Change-History Opportunity: Developer note. The durable product-direction point
is that Native Desktop and native iPad lead performance-heavy export/editor
work, while iPhone receives only measured reduced features rather than blanket
parity.
