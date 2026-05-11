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
| recording UI state/error | pending | move or facade storage |
| capture package refs | pending | move or facade storage |
| desktop handoff prompt | pending | move with relay or defer |
| source load/busy/error/notice | pending | optional transient UI controller or defer |
| capture package preview processor | pending | move or keep facade |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorCaptureRelay.swift`
- optional: `apps/capacitor-film-lab-ios/ios/App/App/Editor/Internal/EditorTransientUIController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [ ] Fill the minimum inventory table.
- [ ] Add `EditorCaptureRelay` as a real collaborator.
- [ ] Add `EditorTransientUIController` only if it materially reduces
  the store without broadening scope.
- [ ] Preserve all view-facing `FilmtoneEditorStore` API names.
- [ ] Keep SwiftUI view files unchanged, or document the exact exception.
- [ ] Register every new Swift file in the App target pbxproj.
- [ ] Run pbxproj 4-section grep for every new Swift file.
- [ ] Run `bun run verify:ios`.
- [ ] Run `git diff --check`.
- [ ] Record line/file deltas, gates, and facade compatibility notes.

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

Pending implementation.

## Gate Results

Pending implementation.

## Facade Compatibility Notes

Pending implementation.

## Unexpected / Follow-up

Pending implementation.
