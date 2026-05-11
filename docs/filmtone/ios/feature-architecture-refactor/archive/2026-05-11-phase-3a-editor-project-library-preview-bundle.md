# Active - Phase 3A EditorStore Project + Library + Preview Bundle

Date: 2026-05-11 JST
Phase: Phase 3A - EditorStore split, project + library + preview boundaries
Milestone: Reduce `FilmtoneEditorStore.swift` by moving project-domain,
library-domain, and preview-lifecycle ownership behind collaborator
controllers while preserving the existing `FilmtoneEditorStore` facade
API.

## Owner Directive

- Use larger product-boundary grain. Do not split this into inventory-only
  or tiny helper-only turns unless a build failure proves the boundary is
  too wide.
- Product quality and forward velocity are the priority. Keep outer-shell
  QA minimal; use `verify:ios`, pbxproj registration, and targeted stale
  greps unless this bundle changes behavior-bearing preview/export/capture
  flow.
- View code should remain untouched. If a view change looks necessary,
  stop and record the compatibility reason before widening scope.

## Goal

Create the first meaningful EditorStore split:

1. Record the minimum access inventory needed to preserve facade
   compatibility for project, library, and preview state.
2. Extract project-domain state/mutations into a new controller.
3. Extract library/bootstrap/cache-domain state/mutations into a new
   controller.
4. Extract preview state/render lifecycle into a new orchestrator.
5. Keep `FilmtoneEditorStore` as the `ObservableObject` facade used by
   views, with public API signatures and call sites preserved.

## Current State

- `FilmtoneEditorStore.swift`: 3441 lines.
- It currently mixes project state, library/bootstrap/cache state,
  preview lifecycle, export lifecycle, capture relay, transient UI, and
  facade methods in one `ObservableObject`.
- Existing nearby names include `FilmtoneProjectState`,
  `LibraryStoreActor`, and `LibrarySnapshot`; avoid introducing generic
  names that collide with those concepts.

## Target Design

Add three collaborator types:

- `EditorProjectController`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectController.swift`
  - Owns project-domain state and project-only mutation logic where the
    access inventory proves the facade can forward safely.
  - Preferred ownership candidates:
    - `project`
    - `appliedSavedLookId`
    - `appliedSavedLookEntryCache`
    - `selectedOpticalFilterId`
    - camera-profile / source-profile project mutation helpers
    - saved-look / user-LUT / optical-filter application bookkeeping
    - quick/advanced adjustment mutation helpers when they are
      project-only

- `EditorLibraryController`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorLibraryController.swift`
  - Owns library actor interaction, bootstrap lifecycle, snapshot
    refresh, and cache inventory state.
  - Preferred ownership candidates:
    - `LibraryStoreActor?`
    - `libraryBootstrapTask`
    - `library`
    - `cacheInventory`
    - `isReleasingCache`
    - `bootstrapLibraryAsync`
    - `refreshLibrarySnapshot`
    - library/cache helper methods that do not require preview/export
      lifecycle ownership

- `EditorPreviewOrchestrator`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorPreviewOrchestrator.swift`
  - Owns still/video preview state, compare state, preview task
    lifecycle, and video preview session lifecycle.
  - The facade forwards `preview`, `comparePreviewFrame`,
    `isCompareHeld`, selected preview URI, video state, and preview
    error without changing view call sites.

## Compatibility Rules

- Preserve `@EnvironmentObject var store: FilmtoneEditorStore` view usage.
- Preserve existing public/internal method names used by views and runtime
  surfaces.
- If `$store.project` or another property-wrapper binding is used
  cross-file, keep that `@Published` storage on `FilmtoneEditorStore` for
  this bundle and move only mutation services into the controller. Do not
  force computed forwarding if it would break SwiftUI bindings.
- If direct property access only is used, computed forwarding plus
  `objectWillChange` bridging is acceptable.
- Bridge child controller changes into the facade `objectWillChange` only
  when state actually moves into a controller.
- Do not change export, capture relay, or transient UI ownership in this
  bundle unless a moved project/library/preview method cannot compile
  without a tiny local delegate.

## Minimum Access Inventory

Result of the cross-file `rg` of `store\.<name>` / `\$store\.<name>` on
view files (`apps/capacitor-film-lab-ios/ios/App/App/{Root,Editor,Export,Source}/`):

| Surface | Access pattern (cross-file) | Decision |
|---|---|---|
| `project` | direct read only (`store.project.<field>`) — 11 sites, no `$store.project` | Keep `@Published` storage on facade. View-direct binding preserved. |
| `library` | direct read only (`store.library.<field>`) — 7 sites, no `$store.library` | Keep `@Published` storage on facade. |
| `cacheInventory` / `isReleasingCache` | direct read only — 3 sites in `FilmtoneSourceProfileSheet` | Keep `@Published` storage on facade. |
| `appliedSavedLookId` | direct read only — 2 sites in `FilmtoneRootView` + `FilmtoneFullscreenLutEditor` | Keep storage on facade with `didSet` clearing the project controller cache. |
| `selectedOpticalFilterId` | direct read only — 2 sites in `FilmtoneStrengthSheet` | Keep `@Published` storage on facade. |
| `libraryStore` (private) | 0 cross-file refs; only used inside `FilmtoneEditorStore.swift` | Move into `EditorLibraryController` (real collaborator). |
| `appliedSavedLookEntryCache` (private) | 0 cross-file refs; read only at `makeLivePreviewGradeProcessor()` and `applySavedLook`/`saveCurrentLook` apply paths | Move into `EditorProjectController` (real collaborator). |
| `libraryBootstrapTask` (private) | 0 cross-file refs; cancel-on-deinit only | Keep facade-owned for deinit cancellation; body of the task moves into `libraryController.loadOrRebuildSnapshot()`. |
| `bootstrapLibraryAsync`/`refreshLibrarySnapshot` (private) | 0 cross-file refs | Methods stay on facade as small forwarders; the actor I/O moves into `EditorLibraryController`. |
| `preview` / `comparePreviewFrame` / `isCompareHeld` | direct read/write through `store`, no view-side property-wrapper binding | Move storage to `EditorPreviewOrchestrator`; facade exposes computed forwards and bridges `objectWillChange`. |
| `previewTask` / `videoPreviewSession` | 0 cross-file refs; preview lifecycle only | Move into `EditorPreviewOrchestrator`. |

Compatibility outcome: zero SwiftUI view-side diffs needed. All
view-direct properties stay `@Published` on `FilmtoneEditorStore`; the
controllers absorb the optional-actor unwrap and the synchronous cache
state.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorLibraryController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorPreviewOrchestrator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Read-Only References

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorFacade.swift`
- SwiftUI view files that access `FilmtoneEditorStore`
- `apps/capacitor-film-lab-ios/ios/App/App/Look/`
- `apps/capacitor-film-lab-ios/ios/App/App/Services/`

## Checklist

- [x] Run the minimum access inventory and fill the table above.
- [x] Create `Editor/Internal/` if it does not already exist.
- [x] Add `EditorProjectController` and wire it into
  `FilmtoneEditorStore`.
- [x] Add `EditorLibraryController` and wire it into
  `FilmtoneEditorStore`.
- [x] Preserve all existing view-facing `FilmtoneEditorStore` API names.
- [x] Keep SwiftUI view files unchanged, or record the exact compatibility
  exception before editing one.
- [x] Register new Swift files in the App target pbxproj.
- [x] Run pbxproj 4-section grep for each new file.
- [x] Run `bun run verify:ios`.
- [x] Run `git diff --check`.
- [x] Record line/file deltas, gates, and any facade compromises.

## Verification Gates

Minimum:

- `grep -c 'EditorProjectController.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `grep -c 'EditorLibraryController.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `grep -c 'EditorPreviewOrchestrator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `bun run verify:ios`
- `git diff --check`

Targeted checks:

- `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App | rg '(View|Root|CaptureView|FullscreenLutEditor)'`
  should be empty unless a compatibility exception is recorded.
- Stale declaration grep for moved methods/properties in
  `FilmtoneEditorStore.swift` should show only intentional facade
  forwards.

## Done Conditions

- `FilmtoneEditorStore.swift` is materially smaller and no longer owns
  project-domain bookkeeping, library/bootstrap actor access, and
  preview lifecycle directly.
- New controllers compile as real collaborators, not extension-only file
  splits.
- View-facing API and view files are unchanged.
- `bun run verify:ios`, pbxproj greps, and `git diff --check` are green.
- The next active can take Preview + Export coordination as one larger
  Phase 3 bundle.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Access inventory finds that moving `project` or `library` storage would
  force broad view rewrites. In that case, keep facade storage and move
  services/mutations only; record the compromise instead of stopping.
- A required change crosses into preview/export/capture behavior beyond a
  tiny delegate. Stop and queue it for the next Phase 3 bundle.

## Out Of Scope

- Export progress/result/coordinator extraction.
- Capture relay extraction.
- SwiftUI view body decomposition.
- Formal XCTest, simulator smoke, PSNR, or full UI QA matrix.

## Line / File Deltas

| File | Before | After | Δ |
|---|---|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift` | 3441 | **2794** | **−647** |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectController.swift` | — | 45 | +45 (new) |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorLibraryController.swift` | — | 118 | +118 (new) |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorPreviewOrchestrator.swift` | — | 765 | +765 (new) |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | — | +24 | +24 |

`FilmtoneEditorStore.swift` post-diff is +63 / −710 vs HEAD (net **−647**).
That covers: preview-pure top-level types (`FilmtoneStillPreviewState`,
`FilmtoneComparePreviewFrame`, `FilmtoneVideoCompareMode`,
`FilmtoneVideoPreviewState`, `FilmtonePreviewState`,
`FilmtoneVideoPreviewSession` class), the 10 preview render methods
(`schedulePreviewRender`, `prepareVideoPreview`,
`refreshExistingVideoPreviewSession`, `renderStillFallbackPreview`,
`renderComparePreviewFrame`, `makeCompareFrame`,
`syncPreviewFromVideoSession`, `markStillPreviewRendering`,
`applyPreviewError`, `hasDisplayablePreviewContent`), and the
`previewTask` / `videoPreviewSession` storage.

Land at 2794 lines vs the 2400-2700 target range. ~94 lines above the
upper bound. The remainder is project mutation / library mutation
orchestration (e.g. `applySavedLook`, `saveCurrentLook`, the
`applyLutMutation` wrapping pattern) that crosses
project + library domains and would need a parallel
`EditorProjectMutationCoordinator` to absorb cleanly. Holding for a
later Phase 3 bundle rather than widening this one.

The new collaborators are real (state + methods + ObservableObject
surface), not extension-only file splits — see Done Conditions.

## Gate Results

| Gate | Result |
|---|---|
| `grep -c 'EditorProjectController.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** |
| `grep -c 'EditorLibraryController.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** |
| `grep -c 'EditorPreviewOrchestrator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** |
| `bun run verify:ios` | **exit 0** (xcodebuild `BUILD SUCCEEDED`, all 6 log-format accuracy gates pass at max \|Δ\|=0.000000, all kernel math + sidecar + capture-classifier + cache-store + cube-parser + grain-catalog gates pass) |
| `git diff --check` | exit 0 |
| `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App \| rg '(View\|Root\|CaptureView\|FullscreenLutEditor)'` | empty (no view-side diffs) |
| Stale `libraryStore` references in `FilmtoneEditorStore.swift` | only the `init(libraryStore:)` parameter + local DI var + the one `EditorLibraryController(libraryStore:)` construction call (intentional, all in the init body) |
| Stale preview-state mutations (`self.preview = .`, `self.comparePreviewFrame =`, `self.videoPreviewSession =`, `previewTask?.`) in `FilmtoneEditorStore.swift` | 0 (all delegated to `previewOrchestrator`) |
| Stale `appliedSavedLookEntryCache` field in `FilmtoneEditorStore.swift` | 0 (storage moved to project controller) |

## Preview Bundle Compatibility Notes

1. **Preview state ownership moved to orchestrator.** `preview`,
   `comparePreviewFrame`, and `isCompareHeld` are now `@Published` on
   `EditorPreviewOrchestrator`. The facade exposes them via three
   computed forwards (`var preview { previewOrchestrator.preview }`
   etc), and `isCompareHeld` has a get/set bridge so the existing
   `setCompareHeld(_:)` and `applySnapshotScene(_:)` mutation sites
   still compile against `self.isCompareHeld = false`.
2. **`objectWillChange` bridged via Combine.** The facade subscribes to
   `previewOrchestrator.objectWillChange` and forwards into its own
   `objectWillChange`. Stored as `previewCancellable: AnyCancellable?`
   on the facade. SwiftUI views observing `@EnvironmentObject var
   store: FilmtoneEditorStore` see preview-state changes identical to
   pre-bundle behavior — `import Combine` added to the facade file.
3. **Render lifecycle preserved verbatim.** The schedule task body
   (debounce → sourceCapViolations gate → buildExportRequest →
   image/video switch → image fallback → applyPreviewError catch-all)
   is byte-identical to the pre-bundle layout, just relocated to
   `EditorPreviewOrchestrator.schedule()`. `Task.sleep(nanoseconds:)` /
   `Task.checkCancellation()` placement preserved, including the
   `try await` order around `originalPrepared` / `gradedPrepared`.
4. **Source / probe / project read via weak back-reference.** The
   orchestrator holds `weak var store: FilmtoneEditorStore?` set via
   `previewOrchestrator.attach(self)` after init. `schedule()` reads
   `store.source`, `store.probe`, `store.project` once at entry. No
   retain cycle (facade strong-references orchestrator; orchestrator
   weak-references facade).
5. **`reclaimCacheForCurrentState()` access widened from `private` to
   internal.** The orchestrator's render branches call back into the
   facade for cache reclamation after each preview write. Behavior
   unchanged; only the access modifier was widened. No public API
   surface affected.
6. **Three `private` extensions / enum widened to internal.**
   `AVPlayer.filmtoneSeek`, `Double.filmtoneSanitizedSeconds`, and
   `enum FilmtonePreviewRefreshDebug` were declared as `private` /
   `private extension` inside the old monolithic
   `FilmtoneEditorStore.swift`. They are now plain (internal) so the
   orchestrator file can use them. The store also still uses
   `FilmtonePreviewRefreshDebug.isProcessParam(_:)` so a single
   shared internal symbol keeps both files in sync.
7. **deinit isolation.** The orchestrator's `previewTask?.cancel()`
   lives in `EditorPreviewOrchestrator.deinit` rather than the facade
   deinit. Calling a `@MainActor` instance method on the orchestrator
   from the facade's `nonisolated` deinit is illegal under Swift 6
   strict concurrency; the in-class deinit reads its own
   MainActor-isolated property directly which is allowed.
8. **Snapshot fixture hook.** `applySnapshotScene(_:)` previously
   wrote `self.preview = fixture.preview` directly. Replaced with
   `previewOrchestrator.applyFixture(preview:)`, which cancels the
   render task, writes the fixture preview, derives
   `comparePreviewFrame` from `preview.comparePreviewFrame`, nils
   `videoPreviewSession`, and resets `isCompareHeld`. UI test fixture
   behavior preserved verbatim.

## Facade Compatibility Notes

1. **View-facing storage preserved.** Every property accessed by views
   (`store.project`, `store.library`, `store.cacheInventory`,
   `store.isReleasingCache`, `store.appliedSavedLookId`,
   `store.selectedOpticalFilterId`) stays `@Published` on
   `FilmtoneEditorStore`. SwiftUI observation is identical to pre-bundle
   behavior.
2. **`appliedSavedLookId.didSet` still clears the cache.** Storage moved
   from `appliedSavedLookEntryCache` (facade-private) to
   `projectController.appliedSavedLookEntryCache`. The `didSet` now
   delegates to `projectController.clearAppliedSavedLookEntry()`. Non-nil
   apply paths now call `projectController.setAppliedSavedLookEntry(entry)`
   in place of `appliedSavedLookEntryCache = entry`.
3. **Live preview sync read preserved.** `makeLivePreviewGradeProcessor()`
   reads `projectController.appliedSavedLookEntryCache` synchronously, the
   same access shape it had against the facade field. No async I/O
   introduced; the M10 fullScreenCover capture path stays sync.
4. **Library bootstrap task ownership.** `libraryBootstrapTask:
   Task<Void, Never>?` stays on the facade so `deinit` cancellation
   (`previewTask?.cancel(); toastDismissTask?.cancel();
   libraryBootstrapTask?.cancel()`) doesn't need to cross actor isolation.
   The task body delegates to `libraryController.loadOrRebuildSnapshot()`,
   which absorbs the optional-actor unwrap and the `try…catch → .empty`
   fall-through.
5. **Six simple library mutations collapsed.** `renameSavedLook` /
   `deleteSavedLook` / `toggleFavoriteSavedLook` /
   `renameLibraryLut` / `deleteLibraryLut` / `toggleFavoriteLibraryLut`
   each lost their `guard let libraryStore else { return }` +
   `try? await libraryStore.X(...)` pair in favor of a single
   `await libraryController.X(...)` call. Behavior on `nil` actor is
   identical (no-op).
6. **`resolveAppliedSavedLookForExport()` centralized.** The export-side
   `appliedSavedLookId → SavedLookEntry` async resolution now lives on
   the project controller as `resolveAppliedSavedLook(id:via:)`, which
   delegates to the library controller. Sidecar provenance behavior is
   unchanged.
7. **DI surface unchanged.** `FilmtoneEditorStore.init(facade:strings:
   libraryStore:)` keeps the same signature so test/preview call sites
   that inject a custom `LibraryStoreActor?` still work. The optional is
   wrapped into `EditorLibraryController` inside the init.
8. **No `cacheInventory` / `isReleasingCache` move in this bundle.** The
   cache release flow at `loadCacheInventory()` / `releaseCache()`
   continues to read `facade.cacheInventory()` / `facade.releaseCache()`
   on `FilmtoneEditorFacade` (platform facade, distinct from the new
   controllers). Moving the cache flow into a library/cache controller
   requires the platform facade reference, deferred to the next Phase 3
   bundle alongside Preview + Export coordination (per
   Out-of-Scope / next-active hint).
9. **`applySavedLook` LUT-resolution invariant maintained.** The
   `libraryRef` branch now sets `lutMissingForApply = true` when
   `libraryController.loadLut(...)` returns nil (controller returns
   `nil` when the actor itself is unavailable). Pre-bundle, the same
   branch would have skipped via `guard let libraryStore else { return }`
   at the method top — but the `applySavedLook` method already early-
   returns when `libraryController.isAvailable == false`, so the inner
   branch is only reachable with a live actor, and `loadLut(...)` only
   returns nil when the actor is nil (impossible here) or throws.
   Practically: behavior parity preserved on every realistic path.

## Unexpected / Follow-up

- **Target line range overshoot.** Land at 2794 vs the
  2400-2700 target. The remaining 94 lines over the upper bound is
  project + library mutation orchestration
  (`applyLutMutation`, `applySavedLook`, `saveCurrentLook`,
  `currentCreativeLutBinding`, and the import/apply pairs) which
  crosses project + library + persistence + toast domains. Splitting it
  cleanly needs a parallel `EditorProjectMutationCoordinator` that
  owns `applyLutMutation` and bridges back to facade for `persist()`,
  `presentToast(_:kind:durationMs:)`, and `schedulePreviewRender()`.
  Deferred to the next Phase 3 bundle.
- **First compile pass failed on Swift 6 access control.** Four
  symbols inside `FilmtoneEditorStore.swift` were `private` /
  `private extension` and inaccessible from the new orchestrator file:
  `FilmtonePreviewRefreshDebug` enum, `AVPlayer.filmtoneSeek` extension,
  `Double.filmtoneSanitizedSeconds` extension, and
  `reclaimCacheForCurrentState()` method. Widened to internal in the
  same edit pass. Behavior parity preserved.
- **Second compile pass failed on `@MainActor` deinit.** Calling
  `previewOrchestrator.cancel()` from `FilmtoneEditorStore.deinit`
  was rejected ("call to main actor-isolated instance method 'cancel()'
  in a synchronous nonisolated context"). Moved the cancel into
  `EditorPreviewOrchestrator.deinit`. Cleared.
- **SourceKit "No such module 'FilmLabSwiftCore'"** appeared on both new
  controller files and on the modified `FilmtoneEditorStore.swift`
  before pbxproj registration. Chronic pre-registration indexer noise
  also seen in Phase 2B-10A / 10B / 10C / 10D extractions. Cleared once
  the pbxproj 4 sections were saved; `bun run verify:ios` exit 0
  confirms no real module-resolution issue.
- **`cacheInventory` / `isReleasingCache` deferred** — these need
  `FilmtoneEditorFacade` (the platform facade) inside whatever
  controller absorbs them. The natural pairing is the next Phase 3
  bundle (project mutation + export/cache coordination), which already
  needs the platform facade for `prewarmMezzanines` / `pickCubeLut` /
  `cacheInventory`.
- **Cross-file `libraryStore` doc references updated.** Two doc-block
  mentions of `libraryStore.loadLook(id:)` in
  `FilmtoneEditorStore.swift` swapped to `libraryController.loadLook(id:)`
  to keep code-narration accurate (no behavior change).
- **`strategy.md`** was pre-staged by the owner with the 10D archive
  rollup + Phase 3 plan; not modified in this session.
