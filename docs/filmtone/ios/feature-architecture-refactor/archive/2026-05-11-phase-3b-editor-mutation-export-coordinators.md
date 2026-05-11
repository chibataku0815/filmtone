# Active - Phase 3B EditorStore Mutation + Export Coordination Bundle

Date: 2026-05-11 JST
Phase: Phase 3B - EditorStore split, mutation + export/cache boundaries
Milestone: Push `FilmtoneEditorStore` from a large facade toward a thin
orchestrator by extracting project mutation orchestration and export/cache
lifecycle coordination behind real collaborators.

## Owner Directive

- Keep the larger-grain pace. Do not stop at pass-through wrappers or a
  sub-200-line reduction.
- Product quality and facade compatibility are the priority. View code
  should remain unchanged.
- Outer-shell QA stays minimal: `verify:ios`, pbxproj 4-section greps,
  view-diff gate, stale greps, and `git diff --check`.

## Goal

Continue the Phase 3 split from the post-3A state:

- Current `FilmtoneEditorStore.swift`: 2794 lines.
- Target after this bundle: roughly 1900-2200 lines.
- Extract enough real behavior that the store no longer directly owns the
  project mutation + export/cache coordination layer.

## Target Design

Add two primary collaborators, and a third only if it falls out cleanly:

- `EditorProjectMutationCoordinator`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectMutationCoordinator.swift`
  - Owns project mutation orchestration that currently sprawls across
    saved looks, LUT import/apply, optical filter selection, and
    `applyLutMutation`-style update wrappers.
  - Preferred move candidates:
    - `applyLutMutation` and related project mutation helpers
    - `currentCreativeLutBinding`
    - `saveCurrentLook`
    - `applySavedLook`
    - `importInputLut`, `importCreativeLut`, `importCaptureUserLut`
    - `loadCaptureUserLut`, `applyLibraryLut`, `applyCaptureCustomLut`
    - optical filter / selected look bookkeeping when it is project-only

- `EditorExportCoordinator`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift`
  - Owns export lifecycle state and calls into `FilmtoneEditorFacade` /
    `FilmtoneExportSession`.
  - Preferred move candidates:
    - `exportProgress`, `exportResult`, `exportLocalAvailability`
    - export start/cancel/result handling
    - save-to-Photos state if it naturally follows export result
    - mezzanine/export validation helpers that do not belong to preview

- Optional `EditorCacheCoordinator`
  - Add only if it directly reduces coupling in this bundle.
  - Candidate ownership:
    - `cacheInventory`
    - `isReleasingCache`
    - `loadCacheInventory`
    - `releaseCache`
    - protected URI collection if it can depend on existing facade
      forwards without view changes

## Compatibility Rules

- Preserve `@EnvironmentObject var store: FilmtoneEditorStore` and all
  view-facing method/property names.
- Keep SwiftUI view files at 0 diff unless a compatibility exception is
  recorded before editing.
- If a `@Published` property is read directly by views, either keep the
  facade storage or bridge the collaborator's `objectWillChange` exactly
  as Phase 3A did for preview.
- Do not modify `EditorPreviewOrchestrator` behavior except for minimal
  delegate calls needed after project/export mutations.
- Do not touch `FilmtoneExportSession` in this bundle unless the export
  coordinator requires a pure call-site namespace update.

## Minimum Inventory

| Surface | Access pattern | Decision |
|---|---|---|
| `exportProgress` / `exportResult` / `exportLocalAvailability` | View read-only (`FilmtoneExportPanel`); internal write at `applyProbe`, `applySnapshotScene`, `invalidateRenderedOutputState`, `export()` / `exportAndSave()` / `exportHighlightReel()` flow | `@Published` storage moves to `EditorExportCoordinator`. Combine `objectWillChange.sink` bridge (Phase 3A preview pattern). Facade keeps computed forwards (`var exportProgress: ... { exportCoordinator.exportProgress }`). |
| `saveToPhotosState` / `isSavingToPhotos` | View read-only (`FilmtoneExportPanel`, `FilmtoneSourceProfileSheet`, `FilmtoneSnapshotSupport`). View calls `store.saveToPhotos()`. Internal write at `applyProbe`, `applySnapshotScene`, `saveExportResultToPhotos`. | Move @Published + `saveToPhotos()` + private `saveExportResultToPhotos()` to coordinator. Facade keeps `saveToPhotos()` as 1-line forward. |
| Project mutation methods (`importInputLut`, `importCreativeLut`, `importCaptureUserLut`, `loadCaptureUserLut`, `applyLibraryLut`, `applyCaptureCustomLut`, `saveCurrentLook`, `applySavedLook`, `clearInputLut`, `clearCreativeLut`, `setInputLutIntensity`, `setCreativeLutIntensity`) | View calls `store.X(...)` (`FilmtoneSourceProfileSheet`, `FilmtoneRootView`, `FilmtoneCaptureView` via adoptCaptureResult). Internal `applyLutMutation` helper, `persistImportedLutToLibrary` helper, `currentCreativeLutBinding` helper. | Move bodies to `EditorProjectMutationCoordinator` with weak store back-ref. Facade keeps method names as 1-line forwards. `applyLutMutation` / `persistImportedLutToLibrary` / `currentCreativeLutBinding` become private to coordinator. |
| `cacheInventory` / `isReleasingCache` + `loadCacheInventory()` / `releaseCache()` / `reclaimCacheForBackground()` / `reclaimCacheForCurrentState()` | View read `store.cacheInventory` / `store.isReleasingCache` and call `store.loadCacheInventory()` / `store.releaseCache()` (`FilmtoneSourceProfileSheet`). `reclaimCacheForCurrentState()` called from init + `applyProbe` + `pickSource` + `recordProductClip` + `adoptCaptureResult` + `export()` + `exportAndSave()`. | Cache state co-lives with export under `EditorExportCoordinator` because `protectedCacheURIs` straddles both (uses `exportResult`, `source`, `preview`, `comparePreviewFrame`). Facade keeps `reclaimCacheForCurrentState()` as a 1-line forward to remain callable from non-coordinator paths. |
| Preview invalidation calls from mutation/export | `invalidateRenderedOutputState()` calls `previewOrchestrator.invalidateForProjectChange()`. `applySnapshotScene` calls `previewOrchestrator.applyFixture`. `applyProbe` calls `previewOrchestrator.reset()`. | `invalidateRenderedOutputState()` widens to internal so the mutation coordinator can re-enter through the store; preview ownership unchanged. |
| Access widening (private → internal) | `refreshLibrarySnapshot()`, `invalidateRenderedOutputState()`, `persist()`, `recomputeProjectParamsPreservingOpticsGlow()`, `invalidateExportPackageState()` private on store. `appliedSavedLookId` had `private(set)`. | All 5 helpers widen to internal so coordinators can re-enter. `appliedSavedLookId` drops `private(set)` (views read only; verified by grep). `didSet` retained so projectController cache stays in sync. |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectMutationCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift`
- optional: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCacheCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [x] Fill the minimum inventory table.
- [x] Add `EditorProjectMutationCoordinator` as a real collaborator.
- [x] Add `EditorExportCoordinator` as a real collaborator.
- [x] `EditorCacheCoordinator` not added — cache state co-lives in
  `EditorExportCoordinator` because `protectedCacheURIs` already crosses
  source + export + preview; an extra coordinator would only re-introduce
  the boundary between cache and export.
- [x] Keep all view-facing `FilmtoneEditorStore` API names intact.
- [x] Keep SwiftUI view files unchanged.
- [x] Register every new Swift file in the App target pbxproj.
- [x] Run pbxproj 4-section grep for every new Swift file.
- [x] Run `bun run verify:ios`.
- [x] Run `git diff --check`.
- [x] Record line/file deltas, gates, and facade compatibility notes.

## Verification Gates

Minimum:

- `grep -c 'EditorProjectMutationCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `grep -c 'EditorExportCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- optional cache coordinator grep if added
- `bun run verify:ios`
- `git diff --check`

Targeted:

- `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App | rg '(View|Root|CaptureView|FullscreenLutEditor)'`
  should be empty unless a compatibility exception is recorded.
- Stale greps for moved method declarations in `FilmtoneEditorStore.swift`
  should show only facade forwards.

## Done Conditions

- `FilmtoneEditorStore.swift` is reduced into the 1900-2200 line range,
  or the active records a concrete blocker for any overshoot.
- Project mutation orchestration and export/cache coordination are no
  longer primarily owned by the facade.
- New files are real collaborators, not extension-only splits.
- View-facing API and view files are unchanged.
- `bun run verify:ios`, pbxproj greps, and `git diff --check` are green.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Export/cache extraction forces broad view rewrites. Keep facade storage
  and move behavior, then record the compromise.
- A required change crosses into CaptureSession behavior. Stop and queue
  it for Phase 3C or Phase 4.

## Out Of Scope

- Capture relay extraction unless it is a tiny delegate needed by export.
- CaptureSession refactor.
- SwiftUI view body decomposition.
- Formal XCTest, simulator smoke, PSNR, or full UI QA matrix.

## Line / File Deltas

| File | Pre | Post | Δ |
|---|---|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift` | 2794 | **1927** | **−867** |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectMutationCoordinator.swift` | — | **503** | +503 (new) |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift` | — | **706** | +706 (new) |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | (baseline) | +24 | +24 (4-section × 2) |

Existing Internal files unchanged: `EditorProjectController.swift` (45),
`EditorLibraryController.swift` (118), `EditorPreviewOrchestrator.swift`
(765). Target was 1900-2200 — landed at **1927**, inside the band.

## Gate Results

| Gate | Result |
|---|---|
| `grep -c 'EditorProjectMutationCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** |
| `grep -c 'EditorExportCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** |
| `bun run verify:ios` | **exit 0** — BUILD SUCCEEDED + all source-profile accuracy gates max \|Δ\| = 0.000000 |
| `git diff --check` | **PASS** |
| View-side diff (`View\|Root\|CaptureView\|FullscreenLutEditor`) | **empty** (0 diff) |
| Stale `applyLutMutation` / `currentCreativeLutBinding` / `persistImportedLutToLibrary` on store | **0 hits** (only `FilmtoneEditorStore.loadBundledCreativeLut(...)` static remains, which is still called from `makeLivePreviewGradeProcessor`) |
| Stale `export()` / `exportAndSave` / `saveExportResultToPhotos` / `resolveExportSource` / `toastForDecision` / `sidecarCaptureProvenance` / `discardLocalExportFiles` / `localExportURIs` / `uniqueURIs` body on store | **0 hits** (all moved to `EditorExportCoordinator`; `discardLocalExportFiles` dropped as dead code) |
| Stale `cacheInventory` / `isReleasingCache` / `loadCacheInventory` / `releaseCache` / `protectedCacheURIs` storage on store | **0 hits** (all delegate-forward to coordinator) |

## Facade Compatibility Notes

1. **Combine bridge** — both `previewCancellable` (from Phase 3A) and
   `exportCancellable` (new) re-emit the coordinator's `objectWillChange`
   into the store's `objectWillChange`. SwiftUI `@ObservedObject var
   store: FilmtoneEditorStore` continues to redraw on export-state /
   cache-state / preview-state changes without view-side change.
2. **`@Published` storage migration** — `exportProgress`, `exportResult`,
   `exportLocalAvailability`, `saveToPhotosState`, `isSavingToPhotos`,
   `cacheInventory`, `isReleasingCache` moved to
   `EditorExportCoordinator`. Facade keeps computed `var` forwards
   (read/write for the first five, read-only for the last two — matching
   the original `private(set)` semantics) so `store.exportProgress`,
   `$store.X` projected bindings (none exist for these — verified by
   grep), and `store.exportProgress = nil` all still compile and behave
   the same.
3. **`appliedSavedLookId` access widening** — was `private(set) var`,
   now `var` so the mutation coordinator can write it. `didSet` retained
   so `projectController.clearAppliedSavedLookEntry()` still fires on
   `nil` assignments. Views still read-only (verified — no view-side
   writes via grep).
4. **Mutation method forwards** — `importInputLut` / `importCreativeLut`
   / `importCaptureUserLut` / `loadCaptureUserLut` / `applyLibraryLut` /
   `saveCurrentLook` / `applySavedLook` / `applyCaptureCustomLut` /
   `clearInputLut` / `clearCreativeLut` / `setInputLutIntensity` /
   `setCreativeLutIntensity` are now 1-line forwards. `@discardableResult`
   preserved on `saveCurrentLook`. View call sites unchanged.
5. **Export method forwards** — `export()` / `exportAndSave()` /
   `saveToPhotos()` / `shareOutput()` / `exportHighlightReel()` /
   `loadCacheInventory()` / `releaseCache()` / `reclaimCacheForBackground()` /
   `reclaimCacheForCurrentState()` / `protectedCacheURIs` are now 1-line
   forwards. View call sites unchanged.
6. **`applyProbe` / `applySnapshotScene` reset paths** — collapsed from
   per-field inline writes to `exportCoordinator.resetForSourceChange()`
   and `exportCoordinator.applyFixture(exportResult:saveToPhotosState:)`.
   Same write-set, same order on the underlying `@Published` storage.
7. **`invalidateRenderedOutputState` / `invalidateExportPackageState`** —
   the former widened from `private` to internal (so the mutation
   coordinator can re-enter through `store.invalidateRenderedOutputState()`).
   Both now delegate to `exportCoordinator.invalidateForProjectChange()`
   / `invalidateExportPackageState()` respectively; preview side
   continues to call `previewOrchestrator.invalidateForProjectChange()`
   from the store wrapper.
8. **Static `loadBundledCreativeLut`** — left on `FilmtoneEditorStore`
   because `makeLivePreviewGradeProcessor` (two overloads) still call
   `FilmtoneEditorStore.loadBundledCreativeLut(...)` for v1.4 Creative
   LUT Pack 01 resolution. The mutation coordinator's `applySavedLook`
   calls the same static — pure function, no state to migrate.
9. **`ExportSourceDecision` / `ResolvedExportSource`** — moved as nested
   types into `EditorExportCoordinator`. No external references existed
   (private to the export flow), so this is a self-contained rename.
10. **`discardLocalExportFiles` removed** — dead code. Grep verified no
    callers anywhere in the iOS target.
11. **Access widening summary** — `refreshLibrarySnapshot()`,
    `invalidateRenderedOutputState()`, `persist()`,
    `recomputeProjectParamsPreservingOpticsGlow()`,
    `exportHighlightMarkers` widened `private` → internal so the
    coordinators can re-enter. `private extension ParsedCubeLutDTO` →
    `extension ParsedCubeLutDTO` so the mutation coordinator can use
    `lut.withIntensity(...)`. All other private helpers stayed private.

## Unexpected / Follow-up

1. **awk strip accidentally captured `presentToast` / `dismissToast`** —
   the original `FilmtoneEditorStore` placed these toast helpers in the
   middle of the export/cache section (between `exportHighlightReel` and
   `reclaimCacheForBackground`), not adjacent to other toast UI code.
   The awk delete-range from M14-A doc comment through `uniqueURIs`
   closing brace inadvertently included them. They were restored
   verbatim after the strip — verified by grep that both definitions are
   present, all call sites resolve, and the build succeeds. **Follow-up**:
   none required — the restore is functionally identical. Note for
   future bundles: when slicing by line range, also grep the captured
   range for unrelated public methods before executing.
2. **Target line band lower edge** — landed at 1927 vs 1900-2200 range.
   Inside the band, slightly above the lower bound. Remaining
   ~100-line headroom toward 2200 includes view-side computed helpers
   (`sourceLabel`, `activePresetLabel`, `previewMetaLabel`,
   `quickSummaryText`, `advancedSummaryText`, `adjustmentSummaryText`,
   `cameraProfileLabel`, `lookProfileLabel`, etc.) which are pure
   formatting and out of scope for this collaborator bundle.
3. **`recomputeProjectParams` stayed on store** — used by `selectPreset`,
   `setStrength`, `setQuickValue`, `setOpticalFilterId`, `setParamOverride`,
   `clearParamOverrides`, `applyParamPreset`, `restoreActivePresetDefaults`.
   Moving it would require another mutation coordinator pass; out of
   scope for this bundle and the next natural seam is a "preset / strength /
   quick state" coordinator covering all 7 callers.
4. **SourceKit pre-pbxproj noise** — same chronic "No such module
   'FilmLabSwiftCore'" diagnostic as Phase 3A. Resolves after the file
   is registered in `project.pbxproj` and `xcodebuild` actually builds.
   Harmless.
