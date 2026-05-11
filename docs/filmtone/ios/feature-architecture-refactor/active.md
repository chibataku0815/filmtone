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

Before edits, record only the access patterns needed for mutation/export
compatibility:

| Surface | Access pattern | Decision |
|---|---|---|
| export progress/result/local availability | pending | facade storage or coordinator storage |
| save-to-Photos state | pending | move with export or defer |
| project mutation public methods | pending | move body or keep facade forward |
| cache inventory/release state | pending | move, defer, or optional coordinator |
| preview invalidation calls | pending | keep as facade delegate |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorProjectMutationCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorExportCoordinator.swift`
- optional: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCacheCoordinator.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [ ] Fill the minimum inventory table.
- [ ] Add `EditorProjectMutationCoordinator` as a real collaborator.
- [ ] Add `EditorExportCoordinator` as a real collaborator.
- [ ] Add `EditorCacheCoordinator` only if it materially reduces the
  store without widening scope.
- [ ] Keep all view-facing `FilmtoneEditorStore` API names intact.
- [ ] Keep SwiftUI view files unchanged, or document the exact exception.
- [ ] Register every new Swift file in the App target pbxproj.
- [ ] Run pbxproj 4-section grep for every new Swift file.
- [ ] Run `bun run verify:ios`.
- [ ] Run `git diff --check`.
- [ ] Record line/file deltas, gates, and facade compatibility notes.

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

Pending implementation.

## Gate Results

Pending implementation.

## Facade Compatibility Notes

Pending implementation.

## Unexpected / Follow-up

Pending implementation.
