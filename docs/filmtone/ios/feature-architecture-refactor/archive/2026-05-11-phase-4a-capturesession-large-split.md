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

| Surface | Access pattern | Decision |
|---|---|---|
| `sessionQueue` / `AVCaptureSession` / `movieOutput` / `recordingDelegate` | facade-only owns AVFoundation graph; collaborators receive scoped operations | **facade** (single owner per Queue / Ownership Rule) |
| device/lens/format/EV/focus/WB/manual exposure controls | view reads `exposureMode` / `manualISO` / `manualShutterSeconds` / `exposureBiasEV` / `isoRange` / `shutterDurationRange` / `exposureBiasRange` / `whiteBalanceMode` / `canLockWhiteBalance`; view calls `setManualISO` / `setManualShutter` / `setExposureBias` / `enterManualExposure` / `exitManualExposure` / `lockWhiteBalance` / `unlockWhiteBalance` / `applyTapToFocusAndMeter` | **`CaptureDeviceManager`** owns device + 14 `@Published` device-side fields + setters + `configure(lens:into:)` device-side prepare body |
| recording state machine / elapsed / storage policy / storage pressure / requested stabilization | view reads `state` / `storagePolicy` / `storagePressure` / `requestedStabilization` / `elapsedSeconds`; view calls `currentDurationLimit()` / `setRequestedStabilization` | **`RecordingStateController`** owns state enum, elapsed timer, auto-stop, storage pressure monitor, captureId, URLs, recordedDurationSnapshot, pendingFailure, recordingCaptureRotation, duration cap constants |
| package assembly / persistence | facade-internal `handleMovieFinished` body; not view-visible | **`CapturePackageAssembler`** owns package paths factory, codec subtype reader, post-record invariant gates (color space / stabilization / rotation / codec FourCC), `FilmtoneCapturePackage` construction, persistence write handoff, proxy export orchestration |
| live preview VDO / preview layer / rotation coordinator | view reads `hasLivePreview` / `previewFrameSink` / `previewLayer` / `livePreviewTelemetry` / `orientationState` | **facade** (tightly coupled to `AVCaptureSession` + `movieOutput.connection` for capture rotation; split would require cross-queue closure plumbing that violates "no second queue / no cross-queue dispatch" rule for marginal benefit this bundle) |
| `pendingSelectedLook` / `pendingCustomLut` | view calls `setSelectedLook` / `setCustomLut`; consumed only at package build | **facade** (small, single-write/single-read, no benefit to relocating) |
| public CaptureSession API used by views | 50+ read accessors + 14 setter/lifecycle methods (`prepare(lens:)`, `start`, `stop`, `rearm`, `teardown`, `useExternalFolder`, `setRequestedStabilization`, ...) | **facade** preserves all via computed forwards + typealiases for `SessionState` / `WhiteBalanceMode` / `ExposureMode` (referenced by `FilmtoneCaptureCockpitTopBar` and `FilmtoneCaptureView`) |
| `FilmtoneCaptureSession.WhiteBalanceMode` / `ExposureMode` qualified type references | `FilmtoneCaptureCockpitTopBar.swift:84,88`, `FilmtoneCaptureView.swift:682,805` | enum primary owner = `CaptureDeviceManager`; **typealias on facade** preserves qualified path with zero view edits |

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureDeviceManager.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/RecordingStateController.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Checklist

- [x] Fill the minimum inventory table.
- [x] Add `Capture/Internal/` if it does not already exist.
- [x] Add `CaptureDeviceManager` as a real collaborator.
- [x] Add `RecordingStateController` as a real collaborator.
- [x] Add `CapturePackageAssembler` as a real collaborator.
- [x] Preserve all view-facing `FilmtoneCaptureSession` API names.
- [x] Keep SwiftUI view files unchanged, or record the exact exception.
- [x] Register every new Swift file in the App target pbxproj.
- [x] Run pbxproj 4-section grep for every new Swift file.
- [x] Run `bun run verify:ios`.
- [x] Run `git diff --check`.
- [x] Record line/file deltas, gates, and facade compatibility notes.

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

| File | Before | After | Δ |
|---|---:|---:|---:|
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift` | 1849 | **880** | **−969** (52.4%) |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CaptureDeviceManager.swift` | (new) | 444 | +444 |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/RecordingStateController.swift` | (new) | 402 | +402 |
| `apps/capacitor-film-lab-ios/ios/App/App/Capture/Internal/CapturePackageAssembler.swift` | (new) | 365 | +365 |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | — | +21 lines (4-section × 3 + Internal group) | — |

Net: facade landed in the **600–900 target band** (880 / 880-floor 600 / 880-ceiling 900). All 3 new collaborators are real types — none is an extension-only split.

## Gate Results

| Gate | Result |
|---|---|
| `grep -c 'CaptureDeviceManager.swift' …pbxproj` | **4** |
| `grep -c 'RecordingStateController.swift' …pbxproj` | **4** |
| `grep -c 'CapturePackageAssembler.swift' …pbxproj` | **4** |
| `bun run verify:ios` | **exit 0** (BUILD ok + grain catalog + Swift contract + motion blur + cube parser + capture transform LUT classifier + CacheStore + source-color-classifier + ray-angle optics + D-Log/D-Log M/C-Log/C-Log 3/V-Log/S-Log3 accuracy gates all at max \|Δ\|=0.000000 + look×veil energy merge + sidecar builder all pass) |
| `git diff --check` | **PASS** (exit 0, no whitespace defects) |
| View-side diff (`rg '(View\|Root\|CaptureView\|FullscreenLutEditor)'`) | **empty** — no view files touched |
| Stale `@Published private(set) var <moved-key>` on facade | **0** for all 17 relocated keys (`state` / `elapsedSeconds` / `storagePolicy` / `storagePressure` / `requestedStabilization` / 12 device-side fields) |
| Stale `elapsedTimer` / `autoStopTask` / `storagePressureTask` / `captureId` storage / direct `makePackagePaths` / `readVideoMediaSubtype` / `estimatedMasterWriteRate` body on facade | **0** (only legitimate `recordingState.startAutoStop` / `recordingState.startStoragePressureMonitor` / `CapturePackageAssembler.makePackagePaths` forward calls remain) |

## Facade Compatibility Notes

1. **`SessionState` / `WhiteBalanceMode` / `ExposureMode` typealiases on facade** — the enums moved to their primary owners (`RecordingStateController` / `CaptureDeviceManager`), but `FilmtoneCaptureCockpitTopBar.swift:84,88` and `FilmtoneCaptureView.swift:682,805` use the qualified form `FilmtoneCaptureSession.WhiteBalanceMode` / `FilmtoneCaptureSession.ExposureMode`. Three typealiases on the facade preserve the qualified path with **zero view edits**. `FilmtoneCaptureSession.SessionState` similarly preserved.
2. **`FilmtoneCaptureSession.internalDurationCapSeconds` / `externalDurationCapSeconds`** — the constants moved to `RecordingStateController`. The facade re-exports them as `static let` forwards to keep any external caller's qualified path stable (no current external callers, but the back-compat shim is one line).
3. **`previewFrameSink` / `previewLayer` / `hasLivePreview` / `livePreviewTelemetry`** — stay on the facade per the Queue / Ownership Rule. Splitting them would require closure-plumbing the `AVCaptureMovieFileOutput` connection access into the device manager, which would either need a second queue or a cross-queue dispatch — both forbidden by active.md.
4. **`orientationState` stays on facade** — the rotation apply path touches `previewLayer.connection` (facade-owned) and `movieOutput.connection` (facade-owned). The pre-existing `pinOrientationToPortrait()` semantics (always-portrait) are preserved unchanged.
5. **Collaborator `objectWillChange` bridging** — same pattern as Phase 3A / 3B / 3C: `recordingState.objectWillChange.sink → self.objectWillChange.send()` + the same for `deviceManager`. A single `@StateObject var session` declaration in `FilmtoneCaptureView` repaints on any collaborator-side mutation.
6. **`setRequestedStabilization(_:)` stays composite on facade** — the storage moved to `RecordingStateController`, but the AV apply path (`session.beginConfiguration` + `connection.preferredVideoStabilizationMode` write + `commitConfiguration`) plus the format-support gate stay on the facade because they touch facade-owned `movieOutput` and the gate consults `deviceManager.device.activeFormat`. The controller's `setRequestedStabilization` is a raw `@Published` setter only.
7. **`start()` orchestration** — facade calls `recordingState.prepareForStart(makePaths: CapturePackageAssembler.makePackagePaths)` to get the per-run paths + captureId + durationLimit in one structured tuple, then constructs the `MovieDelegate` (owning the `[weak self]` callback to `handleMovieFinished`), applies movie rotation, calls `recordingState.beginRecording(at: Date())`, then `recordingState.startAutoStop(after:onAutoStop:)` and `recordingState.startStoragePressureMonitor`. The auto-stop closure is `[weak self] in self?.stop()` — the controller doesn't reach back into AV.
8. **`stop()` reads `movieOutput.recordedDuration`** — facade samples `CMTimeGetSeconds(movieOutput.recordedDuration)` and passes it to `recordingState.markStopping(recordedDuration:)`, which transitions state + cancels timers + cancels storage pressure in one call.
9. **`rearm()` delegates to `recordingState.resetForRearm()`** — the controller owns the scratch-state reset (URLs, durations, pressure, recordingCaptureRotation, state→.ready); the facade only drops `recordingDelegate` and calls `pinOrientationToPortrait()`.
10. **`teardown()`** — facade calls `recordingState.resetForTeardown()` first (which only flips state from `.ready` → `.idle`; preserves `.failed` etc.), stops `AVCaptureSession`, clears preview + VDO + rotation coordinator + frame sink, then calls `deviceManager.resetForTeardown()` to drop device handle + EV / WB / manual exposure flags.
11. **`handleMovieFinished(failure:)` delegates entirely to assembler** — facade builds `ExposureSnapshot` + `WhiteBalanceSnapshot` from `deviceManager` reads, gathers `lensRecord = deviceManager.activeLens?.toRecord()`, and passes the package-build inputs plus `pendingSelectedLook` / `pendingCustomLut` plus the AV `movieOutput.connection(with: .video)` plus an `onCleanup` closure to `packageAssembler.handleMovieFinished(...)`. The assembler performs all 4 post-record gates (color space / stabilization / rotation / codec FourCC), constructs the `FilmtoneCapturePackage`, writes JSON via persistence, and flips controller state.
12. **`PreviewSampleDelegate` references** — `FilmtoneCaptureSession.fourccString` / `.stabilizationDescription` are gone from the facade. The inner `PreviewSampleDelegate` now calls `CapturePackageAssembler.fourccString` / `.stabilizationDescription` (both `nonisolated static`).
13. **`pendingSelectedLook` / `pendingCustomLut` stay on facade** — single-write (`setSelectedLook` / `setCustomLut`) / single-read (at `handleMovieFinished` time). Moving them to a 4th collaborator is over-decomposition.
14. **`deviceManager` and `recordingState` are `let` (non-private)** — same access shape as Phase 3 (`let captureRelay: EditorCaptureRelay`). The view never accesses them via `session.deviceManager.x` — the facade's computed forwards are the only consumed surface. `packageAssembler` is `private(set) lazy var` because it carries a `weak` ref to `recordingState` that must be set after `recordingState` is itself initialized.

## Unexpected / Follow-up

1. **Pre-existing dead rotation observer code removed** — `installRotationCoordinator(device:previewLayer:)` + `receivePreviewRotation(_:)` + `receiveCaptureRotation(_:)` + `applyLatestRotationIfUnlocked()` were defined as `private` methods on the original `FilmtoneCaptureSession` but **never called from anywhere in the codebase** (`grep -rn 'installRotationCoordinator\|receivePreviewRotation\|receiveCaptureRotation\|applyLatestRotationIfUnlocked' apps/capacitor-film-lab-ios/` returns nothing). The runtime behaviour was always-portrait via `pinOrientationToPortrait()`. The dead `rotationCoordinator: AVCaptureDevice.RotationCoordinator?` and `rotationObservations` stored properties + `clearRotationCoordinator(resetState:)` (the only one with live callers) stay on the facade because `clearRotationCoordinator` is invoked from `teardown()` and `pinOrientationToPortrait()` — keeping them quiet ensures S6-era rotation wiring can be re-enabled later without re-scaffolding the storage. Verification: `bun run verify:ios` exit 0 with no regression after removal.
2. **`livePreviewTelemetry` mutation still goes through facade** — `CaptureDeviceManager` could in principle own this `@Published` (it tracks VDO-side metadata), but the mutation happens inside `PreviewSampleDelegate.reportTelemetryIfNeeded`, which already lives on the facade (since the delegate is a facade nested class wired to facade-owned `previewVideoDataOutput`). Forwarding to device manager would require another callback hop with no architectural benefit. Left on facade for this bundle.
3. **`pendingSelectedLook` / `pendingCustomLut` consumed at assembly time via facade reads** — these stay on the facade and the package assembler reads them via parameters passed in by `handleMovieFinished(failure:)`. Could optionally move to a 4th collaborator (CaptureLookRelay) in a future micro-bundle if a Look picker controller emerges, but the active.md explicitly directed against extension-only / pass-through splits — current shape is the right granularity.
4. **Phase 4B (real-device smoke) not run in this bundle per `RELEASE.md` policy** — simulator builds + verify:ios accuracy gates are green; real-device behaviour (ProRes 422 HQ encoder under thermal, S1 stabilization swap mid-take, S3 rearm cycle, S8-B lens swap, storage pressure on external SSD) is **untested in this bundle** because owner-directive scope reads "real-device smoke is Phase 4B unless this bundle changes a behavior-bearing surface that cannot be trusted by build alone." The refactor is mechanical / pass-through (no semantic change), so build trust is sufficient. Owner should run a manual capture smoke before unlocking Phase 5 lanes that depend on the new collaborator boundary.

## Phase 4 Aggregate (Cross-Stream Visibility)

`FilmtoneCaptureSession.swift`: 1849 → **880** = **−969 (52.4%)** in a single bundle.

Collaborators under `Capture/Internal/`: **3 files / 1211 lines combined** (`CaptureDeviceManager` 444 + `RecordingStateController` 402 + `CapturePackageAssembler` 365).

Phase 3 + Phase 4 aggregate `Editor/Internal/` + `Capture/Internal/`: **9 files / 3701 lines** across two god-object splits (Phase 3: 6 files / 2490 lines for `FilmtoneEditorStore.swift` 3441 → 1723; Phase 4A: 3 files / 1211 lines for `FilmtoneCaptureSession.swift` 1849 → 880).
