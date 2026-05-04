# M5-C iOS Feature Parity Audit

Date: 2026-05-04 JST

## Milestone

M5 Native Editing UI

## Goal

Identify the user-visible iOS functionality that the native macOS app has not
yet caught up to, then turn that gap into a prioritized Native Desktop v2
implementation queue. The outcome should make clear whether each gap belongs in
M3 color/optics parity, M5 editing UI, M6 release cutover, or post-cutover.

## Edit Targets

- This `active.md`
- `strategy.md` only for a short completion note if the audit closes

## Read-Only References

- `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/capacitor-film-lab-ios/CLAUDE.md`
- iOS app Swift / TypeScript product surfaces directly relevant to user-visible
  workflow
- Native Desktop v2 Swift product surfaces directly relevant to user-visible
  workflow
- Existing archived Native Desktop v2 task logs only when they explain current
  behavior

## Checklist

- [x] Confirm the current iOS product surface and verification route.
- [x] Confirm the current Native Desktop v2 product surface.
- [x] Build a parity gap table grouped by user workflow.
- [x] Classify gaps as M3 / M5 / M6 / post-cutover.
- [x] Pick the highest-leverage next implementation slice.
- [x] Record verification / non-verification.

## Confirmed Current Surfaces

### iOS

Primary references inspected:

- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `apps/capacitor-film-lab-ios/src/features/editor/MobilePhase0Editor.tsx`
- `apps/capacitor-film-lab-ios/src/features/export/ExportSheet.tsx`
- `apps/capacitor-film-lab-ios/src/lib/phase0-state.ts`
- `apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRootView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneFullscreenLutEditor.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileSheet.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportPanel.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneBuiltInCatalog.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`

iOS is not just a Phase 0 editor anymore. The current user-visible surface is a
fullscreen-first editor with source picking from Photos / Files, live preview,
compare, video playback controls, Look carousel, saved Look and LUT library,
Source sheet, Adjust sheet, Export sheet, save/share, cache persistence, and
iOS-native progress / notification support.

Verification route: `bun run verify:ios`; Swift build risk uses the
`xcodebuild -workspace ios/App/App.xcworkspace -scheme App ...` command in
`apps/capacitor-film-lab-ios/CLAUDE.md`.

### Native Desktop v2

Primary references inspected:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GradeControls.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtonePresetCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneCreativePackCatalog.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneSourceProber.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`

Native Desktop currently covers the vertical slice: open still/video from file,
preview the graded still or selected video frame, select None / Stone / Urban,
adjust one Look strength slider, scrub video frame preview, export PNG/JPEG/MP4,
write sidecar, show progress, and cancel export.

## Parity Gap Map

| Workflow | iOS current surface | Native Desktop current surface | Owner | Priority | Notes |
|---|---|---|---|---|---|
| Source intake | Photo Library and Files routes, import progress, persisted source/probe, cache protection. | `NSOpenPanel` file open only; no source load progress beyond immediate state. | M5 | P1 | Mac does not need Photos parity literally, but it does need a product-grade source state, recent/reopen posture, and progress/error treatment. |
| Source profile / input transform | Auto plus built-in profiles: Apple Log, Apple Log 2, DJI D-Log, DJI D-Log M, Canon C-Log, Canon Log 3 / Cinema Gamut, V-Log, S-Log3, Rec.709. Custom input LUT import and intensity. | Metadata classification exists, but no user-facing camera/source profile picker and no custom input LUT path. | M3 + M5 | P0 | This is the highest product-risk gap: supported iOS source footage can grade/export differently or become unusable on Desktop. |
| Source caps / HDR policy | Source cap violations, HDR policy notice, source metadata chips, camera optics label. | Probe metadata exists, but no comparable source sheet, policy notice, or source-cap user gate. | M3 + M5 | P0 | Needed before native Desktop can be trusted as the primary editor for varied camera footage. |
| Preview navigation | Fullscreen editor, still compare press, video original/graded compare, AVPlayer playback, play/pause, scrubber, 2x press/lock gesture, hide chrome. | Graded preview plus static video frame scrub. No live playback, original/graded compare, play/pause, or hide-chrome mode. | M5 | P1 | Scrub landed, but iOS preview UX is still much richer. |
| Look selection | Built-in Looks are library entries, with Stone / Urban bundled creative LUTs, saved Looks, favorite/rename/delete, apply with provenance. | Picker with None / Stone / Urban only. No saved Look library, no favorite/rename/delete, no applied Look provenance beyond built-in slug. | M5 | P0 | Desktop has the built-in Look result but not the iOS reuse loop. |
| Custom creative LUTs | Import Look LUT, persist in LUT library, apply as creative LUT, set intensity, save into Looks. | No user-imported creative LUT path; bundled Pack 01 only. | M5 + M3 | P1 | Important for pro Desktop expectations, but can follow source profile if release scope is tight. |
| Adjustments | Strength, quick adjustments, advanced parameter overrides, recipe chips, reset, help sheets. | Look strength only. No quick/advanced parameter overrides, recipes, reset posture, or help. | M5 | P0 | Native is currently not an editor in the iOS sense; it is mostly a Look preview/export tool. |
| Optical filters / depth | Optical filter selection store, depth source services, depth realism toggle, still/video depth paths. | RayAngleOptics and optical stages exist, but no user surface for optical filter selection or depth realism. | M3 + M5 | P1 | Depth may remain gated if hidden defaults are not product-approved, but the gap should be explicit. |
| Export options | Export panel with source blocks, progress stages, metrics, save to Photos, share package, local export availability, Master/Postcard render mode, depth toggle. | `NSSavePanel`, PNG/JPEG or MP4, sidecar, progress/cancel, summary string. No export inspector, render mode, share/reveal, or result metrics UI. | M5 + M6 | P0 | Finder integration is already in M5 Done Conditions and should include reveal/share after export. |
| Persistence / library | Project/source/probe persistence, cache store, saved LUT/Look library actor, retained exports until save/share. | In-memory editor state only; no project restore, no recent source/library/cache equivalent. | M5 | P1 | Needed for desktop product feel and for matching iOS continuity. |
| Onboarding / empty state | Onboarding, empty view with source choices and saved Look entry points. | Empty window relies on toolbar Open. | M5 | P2 | Useful after core parity, but not a blocker for primary editing quality. |
| iOS-specific system affordances | Save to Photos, Share Sheet, Live Activity, notification, app intents. | Not applicable literally on Mac. | M6 / post-cutover | P2 | Translate only where Mac has a product equivalent: Finder reveal, Share menu, notification for background export. |

## Classification

### P0 Before Native Release Candidate

- Source Profile / input transform parity: bring the iOS camera profile catalog
  and user-visible selection model to macOS, including Auto and at least the
  built-in profiles. This is both M3 and M5 because it affects output truth and
  user control.
- Source-cap / HDR policy surfacing: if Desktop cannot handle a source the same
  way iOS can, it must say so before export rather than relying on late failure.
- Look library parity: built-in Looks should live in a real selection surface,
  and user-saved Looks need an owning persistence model.
- Adjustment parity: the native app needs quick and advanced parameter editing,
  not just Look strength.
- Export panel parity: export should become a Mac-native panel/inspector with
  result metrics, reveal/share affordances, progress, cancel, and any render
  mode/depth gates that remain product-approved.

### P1 Soon After P0 Or During Same M5 Run

- Video playback preview and original/graded compare.
- Custom creative LUT import plus intensity.
- Input LUT library persistence and recent/saved LUT strip equivalent.
- Optical filter / depth controls once the underlying product switch is
  approved.
- Project/session persistence and recent-source restoration.

### P2 / Post-Cutover Translation

- Literal iOS onboarding structure.
- Literal iOS Live Activity / notification equivalents unless long-running Mac
  exports become a release-blocking workflow.
- App Store screenshot/snapshot-only affordances.

## Recommended Next Active Slice

Open **M5-C.1 Native Source Profile And Source Gate Parity** next.

Reason:

- It closes the biggest correctness gap first: the same footage that iOS can
  normalize through Auto / Apple Log / Apple Log 2 / DJI / Canon / Panasonic /
  Sony / Rec.709 needs an explicit Desktop path before native Desktop can be
  considered a release candidate.
- It is narrow enough to implement without swallowing the whole iOS UI: source
  profile catalog, state, source sheet / inspector control, export threading,
  sidecar/source metadata behavior, and verification.
- It creates the foundation for later Input LUT and Saved Look work, because
  source-side normalization must stay separate from creative Look state.

Suggested M5-C.1 Done Conditions:

- Native Desktop has a Source control surface with Auto and built-in source
  profiles matching iOS catalog names.
- Selected source profile affects preview, still export, and video export.
- Auto remains the default and preserves current behavior for ordinary Rec.709 /
  iPhone sources.
- Unsupported or policy-relevant sources show a user-visible gate before export.
- Sidecar remains V1-compatible and records additive source-profile intent only
  if the current sidecar contract has a safe field for it.
- `bun run verify:macos` passes.

## Verification

- 2026-05-04 JST: Documentation-only audit completed by reading current iOS
  and Native Desktop v2 product surfaces listed above.
- Product build not run for the audit because no implementation slice was
  opened as part of this task.
- `git diff --check` passed for the current worktree; note that the worktree
  also contains unrelated M5-B Pass 4 diagnostic code edits.

## Audit Completion State

Audit is complete, but this `active.md` should not be archived yet while the
Unexpected / Blockers section contains the separate M5-B Pass 4 diagnostic
change. Once that readability slice is either completed or moved back out, the
audit can be archived and `strategy.md` can receive a short completion note.

## Done Conditions

- `active.md` contains a concrete iOS-to-native gap map.
- Each P0/P1 gap has an owning milestone.
- The next implementation slice is specific enough to become the next
  `active.md`.

## Out Of Scope

- Implementing the missing features in this audit slice.
- Changing iOS behavior.
- Changing Electron Desktop behavior.
- Portfolio / public website updates.

## Unexpected / Blockers

- 2026-05-04 13:16 JST — user-flagged readability issue on `GradeControls`
  panel after Pass 3 `.clear` posture (CleanShot screenshot). Dark default
  text + invisible Slider track over bright preview content. Treated as
  M5-B Pass 4 軽微修正 sub-slice within this active per CLAUDE.md §4.5.
  Diagnostic build applied: `Glass.clear.tint(.black.opacity(0.45))` on
  `GradeControls` panel (RootWindowView), `.foregroundStyle(.white)` on
  labels + `.foregroundStyle(.white.opacity(0.7))` on the percent + `.tint
  (.white)` on the Slider (GradeControls.swift). Production target after
  diagnostic confirms wiring: tint opacity 0.30. Capsule / scrub bar / chrome
  unchanged (Pass 3 closure preserved). M5-C audit checklist itself
  untouched.
