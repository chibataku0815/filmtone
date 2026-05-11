# Active - Phase 4A CaptureSession Large Split

Date: 2026-05-11 JST
Phase: Phase 4A - CaptureSession split, device + recording + package
Milestone: Break `FilmtoneCaptureSession` into real collaborators so
Gyroflow / V2 capture work can extend device, state, and package behavior
without threading through one AVCapture monolith.

## Owner Directive

- Keep the larger-grain pace. This phase should not become a sequence of
  tiny helper extractions.
- Product quality gates stay strict for capture truth: ProRes 422 HQ,
  Apple Log 2, 4K24, requested stabilization, rotation, package
  persistence, and VDO live-preview handshake must remain fail-loud and
  unchanged.
- Outer-shell QA stays minimal: `verify:ios`, pbxproj 4-section greps,
  view-diff gate, stale greps, and `git diff --check`. Real-device smoke
  is Phase 4B unless this bundle changes a behavior-bearing surface that
  cannot be trusted by build alone.

## Goal

Start from the current capture state:

- `FilmtoneCaptureSession.swift`: 1849 lines.
- Target after this bundle: roughly 600-900 lines.
- Extract the three core responsibilities in one implementation bundle:
  device/format/lens ownership, recording state/timers/storage policy,
  and capture package assembly.

## Target Design

Add three primary collaborators:

- `CaptureDeviceManager`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureDeviceManager.swift`
  - Owns device/lens/format setup and device-facing controls.
  - Preferred move candidates:
    - `device`
    - `activeLens`
    - `previewVideoDataOutput`
    - `previewSampleDelegate`
    - rotation coordinator + observations
    - preview/capture rotation apply helpers
    - `prepare(lens:)` device/format work, or the device/format subset
      if `AVCaptureSession` stays on the facade
    - exposure bias, tap-to-focus/meter, white balance, manual exposure
      setters and their published ranges/states
    - live preview VDO setup / telemetry if it remains device-coupled

- `RecordingStateController`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/RecordingStateController.swift`
  - Owns recording lifecycle state, timers, storage policy, pressure
    monitoring, and requested stabilization state.
  - Preferred move candidates:
    - `state`
    - `elapsedSeconds`
    - `storagePolicy`
    - `storagePressure`
    - `requestedStabilization`
    - `captureId`, package/master/proxy URLs, started time, duration
      snapshot, pending failure
    - elapsed timer, auto-stop task, storage pressure task
    - `start()`, `stop()`, `rearm()` body ownership when it can be
      delegated without changing public API
    - `currentDurationLimit`, storage write-rate / pressure helpers

- `CapturePackageAssembler`
  - New file: `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift`
  - Owns completion-time file/package construction and persistence.
  - Preferred move candidates:
    - `handleMovieFinished(failure:)` package assembly body, or the
      pure assembly section if state controller still owns transition
    - codec subtype read
    - package paths creation
    - `FilmtoneCapturePackagePersistence.write` handoff
    - final `FilmtoneCapturePackage` construction from recording
      context

## Queue / Ownership Rule

`sessionQueue` must have a single owner after this bundle.

Preferred first implementation:

- Keep `AVCaptureSession` and `sessionQueue` on `FilmtoneCaptureSession`
  as the facade-owned AVFoundation boundary.
- Pass narrowly scoped closures/context objects into collaborators for
  operations that must run on that queue.
- Move `sessionQueue` only if one collaborator can own the whole
  AVFoundation mutation surface without creating cross-queue calls.

Do not create a second capture session queue and do not dispatch from one
queue into another for session mutation.

## Compatibility Rules

- Preserve `FilmtoneCaptureSession` public API and view-facing property
  names.
- Keep SwiftUI view files unchanged.
- If moved `@Published` state is read by `FilmtoneCaptureView`, expose a
  facade computed forward and bridge collaborator `objectWillChange`
  into the session.
- Keep `previewFrameSink` stable for the session lifetime.
- Keep VDO preview handshake unchanged: `hasLivePreview`,
  `livePreviewTelemetry`, and `FilmtoneCaptureLivePreview` behavior must
  remain equivalent.
- Do not modify `EditorCaptureRelay` or `FilmtoneEditorStore` in this
  phase unless a pure namespace update is required.

## Minimum Inventory

Before editing, record only the ownership facts needed to cut the bundle:

| Surface | Access pattern | Decision |
|---|---|---|
| `sessionQueue` / `AVCaptureSession` | pending | facade or device manager |
| device/lens/format controls | pending | move target |
| recording state/timers/storage pressure | pending | move target |
| package assembly / persistence | pending | move target |
| live preview VDO / rotation | pending | move target |
| public CaptureSession API used by views | pending | facade forward shape |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureDeviceManager.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/RecordingStateController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [ ] Fill the minimum inventory table.
- [ ] Add `Capture/Internal/` if it does not already exist.
- [ ] Add `CaptureDeviceManager` as a real collaborator.
- [ ] Add `RecordingStateController` as a real collaborator.
- [ ] Add `CapturePackageAssembler` as a real collaborator.
- [ ] Preserve all view-facing `FilmtoneCaptureSession` API names.
- [ ] Keep SwiftUI view files unchanged, or record the exact exception.
- [ ] Register every new Swift file in the App target pbxproj.
- [ ] Run pbxproj 4-section grep for every new Swift file.
- [ ] Run `bun run verify:ios`.
- [ ] Run `git diff --check`.
- [ ] Record line/file deltas, gates, and facade compatibility notes.

## Verification Gates

Minimum:

- `grep -c 'CaptureDeviceManager.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `grep -c 'RecordingStateController.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `grep -c 'CapturePackageAssembler.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` equals `4`
- `bun run verify:ios`
- `git diff --check`

Targeted:

- `git diff --name-only -- apps/capacitor-film-lab-ios/ios/App/App | rg '(View|Root|CaptureView|FullscreenLutEditor)'`
  should be empty unless a compatibility exception is recorded.
- Stale greps for moved methods/properties in
  `FilmtoneCaptureSession.swift` should show only facade forwards.

## Done Conditions

- `FilmtoneCaptureSession.swift` is reduced into the 600-900 line range,
  or the active records a concrete blocker for overshoot.
- Device/format/lens behavior, recording state/timers/storage pressure,
  and package assembly are no longer primarily owned by the facade.
- `sessionQueue` ownership is explicitly documented and singular.
- New files are real collaborators, not extension-only splits.
- View-facing API and view files are unchanged.
- `bun run verify:ios`, pbxproj greps, and `git diff --check` are green.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Splitting device manager would require changing capture view API. Keep
  facade forwards and record the compromise instead.
- Queue ownership cannot be kept singular with the planned split. Stop
  and record the smallest safe sub-boundary rather than adding a second
  queue.

## Out Of Scope

- EditorStore changes beyond pure namespace fallout.
- ExportSession changes.
- SwiftUI view body decomposition.
- Formal XCTest, simulator smoke, PSNR, or full QA matrix.

## Line / File Deltas

Pending implementation.

## Gate Results

Pending implementation.

## Facade Compatibility Notes

Pending implementation.

## Unexpected / Follow-up

Pending implementation.
