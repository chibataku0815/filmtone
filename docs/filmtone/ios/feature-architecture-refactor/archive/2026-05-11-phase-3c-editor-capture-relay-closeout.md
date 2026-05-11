# Active - Phase 3C EditorStore Capture Relay + Facade Closeout

Date: 2026-05-11 JST
Phase: Phase 3C - EditorStore split, capture relay and facade cleanup
Milestone: Close the EditorStore split enough to move into CaptureSession
refactor without leaving capture/package state trapped in the editor
facade.

## Owner Directive

- Keep the larger-grain pace. This is the EditorStore closeout bundle,
  not a helper-by-helper cleanup pass.
- Product velocity and facade compatibility are the priority. SwiftUI
  view files should remain unchanged.
- Minimal outer shell: `verify:ios`, pbxproj greps, view-diff gate,
  targeted stale greps, and `git diff --check`.

## Goal

Start from the post-3B state:

- Current `FilmtoneEditorStore.swift`: 1927 lines.
- Target after this bundle: roughly 1200-1500 lines.
- Extract capture relay/package adoption state and remaining facade-only
  transient state so `FilmtoneEditorStore` becomes a coordinator shell
  over the internal collaborators.

## Target Design

Add one primary collaborator and one optional collaborator:

- `EditorCaptureRelay`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCaptureRelay.swift`
  - Owns capture UI state, package references, package rehydration, and
    capture result adoption glue.
  - Preferred move candidates:
    - `recordingState`
    - `recordingError`
    - `lastCapturePackage`
    - `currentCapturePackageRef`
    - `desktopHandoffPromptPresented` if it naturally follows source
      picking/capture handoff
    - `recordProductClip(durationSeconds:)`
    - `adoptCaptureResult(_:)`
    - package rehydration from persisted snapshot
    - `makeCapturePackagePreviewGradeProcessor(_:)` if it can move
      without pulling live preview internals back into the facade

- Optional `EditorTransientUIController`
  - Add only if it materially reduces the store and does not create a
    new pass-through shell.
  - Candidate ownership:
    - `sourceLoadState`
    - `isBusy`
    - `notice`
    - `error`
    - `toast`
    - `presentToast` / `dismissToast`

## Compatibility Rules

- Preserve all existing `FilmtoneEditorStore` method/property names used
  by views and runtime surfaces.
- Keep SwiftUI view files unchanged unless an exception is recorded
  before editing.
- If a moved `@Published` property is view-read, bridge collaborator
  `objectWillChange` into the store exactly as Phase 3A/3B did.
- Keep source/project/preview/export collaborator boundaries intact.
  Do not move code back into the facade to make capture extraction easier.
- Do not modify `FilmtoneCaptureSession` in this phase. That is Phase 4.

## Minimum Inventory

Before editing, record only the access patterns needed for capture relay
compatibility:

| Surface | Access pattern | Decision |
|---|---|---|
| `recordingState` | view read-only (`store.recordingState`) via `FilmtoneRootView` overlay; internal writes from `recordProductClip`/`adoptCaptureResult` | **Move to relay**; facade exposes computed get-only forward |
| `recordingError` | view read+write (`store.recordingError = nil`/`...`) via `.alert` in `FilmtoneRootView`; internal writes from capture flows | **Move to relay**; facade exposes computed get/set forward |
| `lastCapturePackage` | internal: persisted, read by `EditorExportCoordinator` (`store.lastCapturePackage`); no view binding | **Move to relay**; facade exposes computed get-only forward so export coordinator and `applyProbe` keep current surface |
| `currentCapturePackageRef` | internal: persisted, written from `init`/`adoptCaptureResult`/`applyProbe`; read by `persist()` | **Move to relay**; facade `persist()` reads via relay; computed forward optional |
| `desktopHandoffPromptPresented` | view projected binding (`$store.desktopHandoffPromptPresented` for `.sheet`) + `.onChange(of: store.desktopHandoffPromptPresented)` | **Keep on facade** — `$store.x` requires real `@Published` on the facade; only `pickSource` writes it, `pickSource` stays on facade (writes other facade state too). Moving would force a view-side change |
| `recordProductClip(durationSeconds:)` | view call site only (`FilmtoneEmptyView` button → `store.recordProductClip(...)` indirectly through callback) | **Move to relay**; facade keeps method name, 1-line forward |
| `adoptCaptureResult(_:)` | view call site (`FilmtoneRootView` capture cover callback `await store.adoptCaptureResult(package)`) | **Move to relay**; facade keeps method name, 1-line forward |
| `makeCapturePackagePreviewGradeProcessor(_:)` | view call site (`FilmtoneRootView` capture surface) | **Move to relay**; facade keeps method name, 1-line forward |
| `sourceLoadState` / `isBusy` / `notice` / `error` / `toast` / `presentToast` / `dismissToast` | heavily cross-cut: written from `pickSource`, `applyProbe`, `applySnapshotScene`, `EditorExportCoordinator`, `EditorProjectMutationCoordinator`; views read all | **Defer optional transient controller**: a controller would be pass-through across already-moved coordinators (export/mutation re-enter via `store.error`/`store.presentToast`). Stop condition #3 in active.md applies |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCaptureRelay.swift`
- optional: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorTransientUIController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [x] Fill the minimum inventory table.
- [x] Add `EditorCaptureRelay` as a real collaborator.
- [x] Add `EditorTransientUIController` only if it materially reduces
  the store without broadening scope. (Deferred — see inventory table:
  every transient surface re-enters from already-moved coordinators, so
  a controller would be pass-through. Stop condition #3 fired.)
- [x] Preserve all view-facing `FilmtoneEditorStore` API names.
- [x] Keep SwiftUI view files unchanged, or document the exact exception.
  (No exception required — 0 view diff.)
- [x] Register every new Swift file in the App target pbxproj.
- [x] Run pbxproj 4-section grep for every new Swift file.
- [x] Run `bun run verify:ios`.
- [x] Run `git diff --check`.
- [x] Record line/file deltas, gates, and facade compatibility notes.

## Verification Gates

Minimum:

- `grep -c 'EditorCaptureRelay.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- optional transient UI controller grep if added
- `bun run verify:ios`
- `git diff --check`

Targeted:

- `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App | rg '(View|Root|CaptureView|FullscreenLutEditor)'`
  should be empty unless a compatibility exception is recorded.
- Stale greps for moved capture/package declarations in
  `FilmtoneEditorStore.swift` should show only facade forwards.

## Done Conditions

- `FilmtoneEditorStore.swift` is reduced into the 1200-1500 line range,
  or the active records a concrete blocker for overshoot.
- Capture relay/package state is no longer primarily owned by the
  facade.
- New files are real collaborators, not extension-only splits.
- View-facing API and view files are unchanged.
- `bun run verify:ios`, pbxproj greps, and `git diff --check` are green.
- The next active can start Phase 4 CaptureSession split.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving capture relay requires changing `FilmtoneCaptureSession`.
  Stop and leave that for Phase 4.
- Transient UI extraction becomes a pass-through-only wrapper. Defer it
  and keep the Phase 3C focus on capture relay.

## Out Of Scope

- CaptureSession refactor.
- ExportSession changes.
- SwiftUI view body decomposition.
- Formal XCTest, simulator smoke, PSNR, or full UI QA matrix.

## Line / File Deltas

| File | Before | After | Delta |
|---|---:|---:|---:|
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift` | 1927 | **1723** | **−204** |
| `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCaptureRelay.swift` (new) | — | **353** | **+353** |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | — | — | +4 lines (4-section × 1 new file) |

`FilmtoneEditorStore.swift` landed at **1723** — overshoot of **+223** vs the 1500 upper bound. **Concrete blocker for overshoot:** the remaining ~358 lines of facade live-preview helpers (`makeLivePreviewGradeProcessor()` x3 variants + `liveCaptureSyntheticSource()` static fixture + `makeLivePreviewDiagnostics()`) are explicitly excluded by the active's `makeCapturePackagePreviewGradeProcessor(_:) if it can move without pulling live preview internals back into the facade` caveat. Moving them would either pull editor / preview internals (`appliedSavedLookId`, `projectController.appliedSavedLookEntryCache`, `lookProfileLabel`, `cameraProfileLabel`) into the relay or create a new live-preview collaborator beyond Phase 3C scope. Recorded for a follow-up bundle.

Aggregate trajectory through Phase 3 (`FilmtoneEditorStore.swift`):
3441 → 1927 (Phase 3B) → **1723** (Phase 3C) = **−1718 total** (50.0% reduction).

## Gate Results

| Gate | Command | Result |
|---|---|---|
| pbxproj 4-section | `grep -c 'EditorCaptureRelay.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | **4** ✓ |
| iOS verify pipeline | `bun run verify:ios` | **exit 0** (BUILD ok + grain catalog + Swift contract + motion blur + cube parser + capture transform LUT classifier + CacheStore + source-color-classifier + ray-angle optics + D-Log/D-Log M/C-Log/C-Log 3/V-Log/S-Log3 accuracy gates all at max \|Δ\|=0.000000 + look×veil energy merge + sidecar builder all pass) |
| Whitespace | `git diff --check` | **PASS** (exit 0) |
| View-side diff | `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App \| rg '(View\|Root\|CaptureView\|FullscreenLutEditor)'` | **empty** (0 view files touched) |
| Stale @Published storage in store | `grep -cE '@Published var (recordingState\|recordingError\|lastCapturePackage\|currentCapturePackageRef)'` on `FilmtoneEditorStore.swift` | **0** ✓ (all migrated) |
| Stale direct capture imports in store | `grep -cE 'FilmtoneProductCapture\(\)\|FilmtoneCapturePackagePersistence\.(read\|write)'` on store | **0** ✓ (relay owns) |

## Facade Compatibility Notes

1. `FilmtoneEditorStore.recordingState` — view-readable get-only computed forward to `captureRelay.recordingState`. No write sites outside the relay flows survived; capture overlays in `FilmtoneRootView` (`store.recordingState != nil`, `if let state = store.recordingState`) keep working.
2. `FilmtoneEditorStore.recordingError` — get/set computed forward. View writes (`store.recordingError = nil`, `store.recordingError = failure.displayMessage`) and reads (`.alert` Binding(get:set:) over `recordingError != nil`) keep their existing surface.
3. `FilmtoneEditorStore.lastCapturePackage` (iOS) — get-only computed forward. Internal call sites (`EditorExportCoordinator` references `store.lastCapturePackage` on lines 142/368/434) keep working unchanged.
4. `FilmtoneEditorStore.currentCapturePackageRef` (iOS) — get-only computed forward. `persist()` reads via the forward (`captureRef = currentCapturePackageRef`); the value is owned by the relay and persisted to disk through the existing `FilmtonePersistence.save` path.
5. `FilmtoneEditorStore.desktopHandoffPromptPresented` — **kept on facade**. `$store.desktopHandoffPromptPresented` (projected binding on `.sheet`) requires `@Published` storage on the facade itself; the single write site (`pickSource`) lives on the facade. Moving it would force a SwiftUI view edit or a write-through `@Published` mirror with risk of recursive update.
6. `recordProductClip(durationSeconds:)` — facade keeps method name and async signature; body is now a 1-line `await captureRelay.recordProductClip(...)`. View call sites unchanged.
7. `adoptCaptureResult(_:)` (iOS) — 1-line forward; preserves both the view callback path (`Task { await store.adoptCaptureResult(package) }`) and the post-adopt `await applySavedLook` / `await applyCaptureCustomLut` re-apply sequence (S11-E live-preview→editor chain handoff). Relay invokes the facade's mutation forwards.
8. `makeCapturePackagePreviewGradeProcessor(_:)` (iOS) — 1-line forward. Relay reuses the static `FilmtoneEditorStore.loadBundledCreativeLut` and the `ParsedCubeLutDTO.withIntensity` helper (both internal access in the same module). Take-picker preview behavior unchanged.
9. `applyProbe(source:probe:)` — widened from `private` to internal so the relay can re-enter the editor's source/probe pipeline. View invariant unchanged (still only callable from the same module).
10. `schedulePreviewRender()` — widened from `private` to internal for the same reason.
11. Combine bridge: `captureRelayCancellable = captureRelay.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }` mirrors the Phase 3A preview / Phase 3B export bridges. Relay-owned @Published mutations propagate through facade `objectWillChange` so SwiftUI redraws via `@ObservedObject var store: FilmtoneEditorStore` are equivalent.
12. Init rehydration delegation: `captureRelay.rehydrate(currentCapturePackageRef: snapshotCaptureRef)` replaces the inline init-time `FilmtoneCapturePackagePersistence.read` / clear-on-missing flow. `captureRelay.clearLinkage()` replaces the inline package-clear on a missing persisted source. `captureRelay.dropLinkageIfNotProxy(of:)` replaces the inline guard in `applyProbe`. Behavior is bytewise equivalent — same persist call, same store snapshot field.

## Unexpected / Follow-up

1. **Overshoot vs target band (1500 upper bound → landed 1723)**. The active's `makeCapturePackagePreviewGradeProcessor(_:) if it can move without pulling live preview internals back into the facade` caveat is the explicit blocker. Live-preview helpers (`makeLivePreviewGradeProcessor` x3 variants + `liveCaptureSyntheticSource` + `makeLivePreviewDiagnostics`) consume ~358 lines on the facade and were intentionally not moved. A future bundle could extract an `EditorLivePreviewProcessorFactory` (or expand `EditorPreviewOrchestrator`), but it would touch read-paths that span `appliedSavedLookId`, `projectController.appliedSavedLookEntryCache`, `lookProfileLabel`, and `cameraProfileLabel` — out of the Phase 3C capture-relay scope.
2. **`desktopHandoffPromptPresented` stayed on facade**. The active listed it as "if it naturally follows source picking/capture handoff". Routing it through the relay would require either (a) a `@Published` mirror on the facade with bidirectional sink (recursive-update risk), or (b) a view edit `$store.desktopHandoffPromptPresented` → `$store.captureRelay.desktopHandoffPromptPresented` (violates "Keep SwiftUI view files unchanged"). The single write site is `pickSource` which itself stays on the facade for this phase, so keeping the flag on the facade has zero cross-collaborator coupling.
3. **`EditorTransientUIController` was deferred (not added)**. Per inventory, every transient surface (`sourceLoadState`, `isBusy`, `notice`, `error`, `toast`, `presentToast`, `dismissToast`) is written from at least two of: `pickSource`, `applyProbe`, `applySnapshotScene`, `EditorExportCoordinator`, `EditorProjectMutationCoordinator`, `EditorCaptureRelay`. A controller would be a pass-through wrapper, hitting active's Stop Condition #3 ("Transient UI extraction becomes a pass-through-only wrapper").
4. **Phase 4 unblocked**. The capture relay now isolates M10 package adoption from `FilmtoneCaptureSession` internals; the relay only touches `FilmtoneCapturePackage` / `FilmtoneCapturePackagePersistence` / `FilmtoneProductCapture` (none of which are Phase 4's split targets). Phase 4 can split `FilmtoneCaptureSession` without re-routing through the facade.

## Phase 3 Aggregate (Cross-Stream Visibility)

`FilmtoneEditorStore.swift` line trajectory: 3441 (pre-3A) → 2794 (post-3A preview) → 1927 (post-3B mutation/export) → **1723 (post-3C capture relay)**.

Collaborators landed under `Editor/Internal/`:

| File | Lines | Phase |
|---|---:|---|
| `EditorProjectController.swift` | 45 | 3A |
| `EditorLibraryController.swift` | 118 | 3A |
| `EditorPreviewOrchestrator.swift` | 765 | 3A |
| `EditorProjectMutationCoordinator.swift` | 503 | 3B |
| `EditorExportCoordinator.swift` | 706 | 3B |
| `EditorCaptureRelay.swift` | 353 | 3C |
| **Total internal collaborators** | **2490** | |

Combined editor surface = 1723 (facade) + 2490 (internal collaborators) = **4213** lines, vs the pre-refactor 3441 single-file god class. The +772 net headroom is forwarding + collaborator init + Combine bridges + per-collaborator imports — explicit boundaries traded for trace bloat, the canonical refactor cost.
