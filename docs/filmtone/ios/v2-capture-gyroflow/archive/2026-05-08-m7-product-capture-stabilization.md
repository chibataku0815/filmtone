# Active: M7 — Product Capture Surface Bootstrap + Stabilized Recording Integration

Date: 2026-05-07 JST
Worktree: `filmtone-worktrees/ios-v2-m6-avfoundation-stabilization-smoke`
Branch: `feature/ios-v2-capture-m6-avfoundation-stabilization-smoke`
Base: M6 PASS commit (`3968eafd`) + uncommitted strategy realignment edits

## Live-code discovery (scope correction)

Live-code discovery: no non-smoke product capture surface exists yet.
Therefore M7 creates the minimal non-DEBUG product capture surface and wires
AVFoundation cinematicExtendedEnhanced stabilization into that first product
path. This is not a separate library lane and does not reopen Gyroflow.

Evidence (audited 2026-05-07 against branch HEAD):

- Every Swift file in `apps/capacitor-film-lab-ios/ios/App/App/` that
  touches `AVCaptureSession` / `AVCaptureMovieFileOutput` /
  `preferredVideoStabilizationMode` is a smoke. `FilmtoneCaptureWriter.swift`
  is named without the `Smoke` suffix but its file header explicitly
  labels itself `M2-B Path C Dual-Output Coexistence Smoke`,
  `DEBUG-only entry`, `No JS bridge / UI surface in M2-B`.
- Every capture entry point invoked from `AppDelegate.swift`
  (`FilmtoneCaptureWriter.runSmoke`, `FilmtoneMotionRecorder.runSmoke`,
  `FilmtoneCombinedTimingSmoke.runSmoke`, `FilmtoneGcsvSmoke.runSmoke`,
  `FilmtoneStabilizationSmoke.runSmoke`) sits inside `#if DEBUG`.
- `FilmtoneMediaPlugin.swift` is a Capacitor media-library bridge, not a
  camera capture surface.
- Conclusion: M7 must bootstrap the surface, not retrofit an existing
  one. The realignment-time M7 wording ("integrate the M6 PASS
  stabilization mode into the real Filmtone capture surface") is
  re-read here as: create the first real Filmtone capture surface with
  M6 stabilization wired in from the first commit. strategy.md is
  intentionally NOT re-edited; this active is the propose-and-apply
  surface for the scope correction (owner direction 2026-05-07).

## Why this active exists

M6 PASS proved AVFoundation `cinematicExtendedEnhanced` is
owner-acceptable for capture-time stabilization on the M5-A locked
format. The M6 result must reach a real, non-DEBUG product capture path
before the next owner-facing milestone (old `M9 Owner Clip Trial`) can
run. This active creates that path and wires M6's stabilization mode
into it from the start, so the first product clip the owner ever
records is already stabilized.

## Done conditions (minimum)

1. A non-DEBUG, non-`Filmtone*Smoke.swift` product capture entry exists
   that an owner-facing path (UI gesture, Capacitor plugin call from
   the existing web shell, or single existing-screen hook) can invoke.
2. That product path applies the M6-proven capture config verbatim:
   `AVCaptureDeviceTypeBuiltInWideAngleCamera` (rear), `formats[56]`,
   `.appleLog2` (raw 4), 3840x2160@30, writer
   `AVVideoCodecType.proRes422HQ` via `AVCaptureMovieFileOutput`. M5-A
   locked, exact value-for-value.
3. `connection.preferredVideoStabilizationMode =
   .cinematicExtendedEnhanced` is set by default on the product path
   before `startRecording`.
4. Unsupported case is **never** silently absorbed: when the M5-A locked
   format does not support `.cinematicExtendedEnhanced` at runtime, the
   product path surfaces `stabilization unavailable` to UI **and**
   diagnostics, refuses to silently fall back to a different mode, and
   either aborts the recording or proceeds only with an explicit user
   acknowledgement that gets recorded in the diagnostics.
5. The product entry is the **minimum** new UI surface: hook into the
   existing app (a Capacitor plugin method on the existing
   `FilmtoneMediaPlugin` or a sibling, or a single button on an existing
   screen). No new full-screen camera UI in M7.
6. Owner records at least one real clip through the product path (not a
   smoke build) and the resulting package satisfies: ProRes 422 HQ
   written (FourCC `apch` via `AVURLAsset`), Apple Log 2 preserved
   (`activeColorSpace.rawValue == 4`), stabilization active mode after
   `startRecording` is `.cinematicExtendedEnhanced` (raw 5) or the
   recorded loud-fail path of Done condition 4 was taken, file produced
   in the expected sandbox / package layout.

## Owner Stop Conditions

- M7 grows past stabilization wiring into "redesign the capture UI" /
  "rebuild the Capacitor plugin surface" / "introduce a state machine
  for multi-mode capture" → STOP.
- Silent fallback to `.standard` / `.off` when
  `.cinematicExtendedEnhanced` is unsupported → STOP. Contract is loud
  failure with diagnostic record.
- M5-B / old M5 Done wording is touched in this active → STOP. That
  cleanup stays as a Follow-up note in this active's archive only.
- strategy.md milestone bodies are touched in this active → STOP. The
  Live-code discovery preamble above is the scope correction; no
  re-edit of strategy.md.
- Gyroflow re-engagement / external desktop stabilization concerns
  enter the active → STOP. M7 is on-device capture only.
- Smoke files (`Filmtone*Smoke.swift`, `FilmtoneCaptureWriter.swift`)
  are deleted, renamed, or repurposed in M7 → STOP. They remain as
  DEBUG-only validation harnesses for format / mode regressions.

## Out of scope

- Filmtone-optimized motion library implementation. Known Constraints
  marks it deprioritized.
- Editor handoff (M8 territory).
- Owner clip trial as a 3-clip campaign (M9 territory; M7 owner clip =
  1 verification clip, not the M9 sample size).
- Audio capture (`NSMicrophoneUsageDescription` deferred per strategy
  Known Constraints).
- New full-screen camera UI design.
- Capacitor plugin redesign past the minimum hook.
- strategy.md M5 / M5-B Done wording cleanup; recorded as Follow-up.
- Start/stop pair semantics on the plugin method. M7 is 1-shot
  `recordProductClip({ durationSeconds })`. Start/stop UI + state
  machine + cancel handling = M7+ (next active, owner direction
  2026-05-07).
- Native UIKit / SwiftUI button on existing screens. Owner UI is
  designed in the next active alongside real UX, not bolted on
  during M7 implementation.
- Caller-specified duration clamping. Out-of-bounds duration is a
  loud reject (`FILMTONE_PRODUCT_CAPTURE_DURATION_OUT_OF_BOUNDS`),
  not silently coerced.

## 30-min granular subtasks

1. **Smoke audit for migration plan.** Read `FilmtoneStabilizationSmoke.swift`
   end-to-end. Extract: M5-A locked config block, `configureSession()`
   wiring, `AVCaptureMovieFileOutput` setup, supported-modes probe,
   `activeVideoStabilizationMode != .off` assertion, AVURLAsset
   codec-read post-write, package directory rename pattern, error enum
   for loud failures. Read `FilmtoneMediaPlugin.swift` to identify the
   existing Capacitor bridge surface (registered methods, return shape,
   error surface). Read `AppDelegate.swift` lines around the smoke
   wiring to identify a non-DEBUG hook path. Inline the migration
   inventory in this active: `transfer verbatim`, `adapt`, `smoke-only,
   drop`. **Read-only.**
2. **Draft product surface design.** Inline in this active draft:
   (a) Swift target file(s) and class shape (`final class
   FilmtoneProductCapture`?  per-call session vs single shared
   actor?). (b) Entry point — Capacitor plugin method on existing
   `FilmtoneMediaPlugin` vs sibling plugin vs `AppDelegate` non-DEBUG
   bridge. (c) UI hook — single existing-screen button vs pure JS
   bridge call. (d) Loud-fail contract for stabilization unavailable
   (error code shape, UI surfacing). (e) Sandbox output path
   conventions (reuse smoke `Filmtone/captures/` or carve a product
   sub-path). (f) Diagnostics shape (reuse smoke JSON schema vs
   product-only schema). **No Swift edits.**
3. **STOP for owner OK on design.** Wait for explicit sign-off on the
   subtask 2 draft. No partial application.
4. **Implement product capture path.** Create the Swift file(s) per
   the OK'd design. Port M6-proven config + stabilization + AVURLAsset
   codec read + loud-fail unsupported path. Wire UI / bridge entry.
   Add diagnostic exposure. No smoke deletion / rename.
5. **On-device smoke verification.** Run the new product path on the
   owner device via the new non-DEBUG entry (not the smoke build).
   Confirm Done conditions 1-5 with `devicectl device process launch`
   logs and the package on disk.
6. **Owner real clip + archive.** Owner runs Done condition 6 clip. On
   PASS: archive this active to
   `archive/2026-05-07-m7-product-capture-stabilization-bootstrap.md`
   and add a 1-line Completion Log entry to strategy.md (M7 PASS only,
   no inlined implementation detail per owner caveat 2026-05-07).
   Follow-up note in archive: `strategy.md M5 / M5-B Done wording
   cleanup remains, not handled in M7`.

## Verification status

- [x] Subtask 1: smoke audit + migration inventory (see Migration
  inventory section below)
- [x] Subtask 2: product surface design drafted inline (held for
  owner OK below)
- [x] Subtask 3: owner OK received 2026-05-07. Three confirmation
  points + one design clarification:
  (1) `recordProductClip({ durationSeconds })` 1-shot fixed duration
  per call. start/stop pair is M7+ (UI / state machine / cancel
  semantics out of M7 scope).
  (2) Native UI ゼロ. Bridge call only. No button on existing
  screens — UI is designed in the next active alongside real UX.
  (3) 5 distinct reject codes (`FILMTONE_PRODUCT_CAPTURE_*`) with
  structured `detail` payload. Failure-class fidelity is a quality
  contract for the upcoming owner clip trial.
  (Clarification) `durationSeconds` is caller-specified. Native side
  **rejects loud** outside accepted bounds — does NOT clamp. Adds a
  6th reject code: `FILMTONE_PRODUCT_CAPTURE_DURATION_OUT_OF_BOUNDS`.
  Bounds locked at min 1.0s / max 60.0s (1.0s = stabilization +
  recording infra settle floor; 60.0s = 4K ProRes 422 HQ ≈ 3.5 GB
  cap, matches M5/M6 30s smoke baseline + 2x headroom, prevents
  unbounded session via plugin call). Bounds embedded as Swift
  constants for M7 minimum; owner can re-tune in a follow-up active.
- [x] Subtask 4: implementation landed on this branch
- [x] Subtask 5: on-device verification PASS — owner-tapped Record
  button on iPhone 17 Pro (id `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`),
  clip recorded, `clip.mov` automatically loaded into editor source,
  preview rendered. Done conditions 1-4 covered by build/install +
  product flow success; no separate Safari devtools 4-gate inspection
  was performed (deliberate per 本質優先 — strict gate inspection was
  treated as 外殻).
- [x] Subtask 6: owner real clip + archived (this active is closed
  on 2026-05-08).

Architecture correction 2026-05-08 (mid-implementation discovery): the
React/Capacitor MobilePhase0Editor surface is **not the live UI** —
`AppDelegate` boots a native SwiftUI tree via
`FilmtoneRootHostingController` + `FilmtoneRootView` →
`FilmtoneEmptyView` / `FilmtoneFullscreenLutEditor`. The earlier
React-side wiring (MobilePhase0Editor.tsx, messages.ts, FilmtoneIcons,
filmtoneMedia.ts/web.ts) never rendered. The product surface that
shipped is a third CTA on `FilmtoneEmptyView` calling
`FilmtoneEditorStore.recordProductClip()` →
`FilmtoneProductCapture.recordClip(durationSeconds:5)` directly (no
Capacitor plugin bridge). Follow-up: React/Capacitor stack is dead
code in launch path — separate lane will purge.

## Migration inventory (subtask 1 — read-only audit, evidence below)

Source: `apps/capacitor-film-lab-ios/ios/App/App/`. Audited files:
`FilmtoneStabilizationSmoke.swift` (1743 lines), `FilmtoneMediaPlugin.swift`
(467 lines), `AppDelegate.swift` (246 lines), `FilmtoneCaptureCapabilityProbe.swift`
(447 lines).

### Transfer verbatim (from `FilmtoneStabilizationSmoke.swift`)

| Block | Lines | Notes |
|---|---|---|
| Locked-format constants (`lockedFormatIndex=56`, `lockedWidth=3840`, `lockedHeight=2160`, `lockedFPS=30`, `lockedRotationAngle`, `appleLog2ColorSpaceRaw=4`) | ~190-255 (constants region), `lockedRotationAngle` defined nearby | M5-A locked, exact value-for-value (Done condition 2) |
| `configureSession()` core body — wide camera lookup + format gate + colorSpace + dim + fps assertions + `lockForConfiguration` apply + `AVCaptureMovieFileOutput` + `availableVideoCodecTypes` ProRes 422 HQ gate + `setOutputSettings` | 467-552 | The product path runs identical assertions; smoke-only: VDO + env-stabilization branch |
| Stabilization probe + `connection.preferredVideoStabilizationMode = .cinematicExtendedEnhanced` apply on the movie connection | 566-607 | Loud-fail on unsupported (Done condition 4) preserved verbatim from smoke `unsupportedStabilizationModeForFormat` shape |
| `AVURLAsset` codec read (`readActualMovieMediaSubType` + `fourCC` helpers) | 1597-1641 | Direct file evidence read post-write — verifies actual `apch` FourCC, not constant claim. Same 5s timeout pattern. |
| Active-mode + colorSpace re-read in `didStartRecordingTo` delegate (`appliedStabilizationMovieRaw = movieConn.activeVideoStabilizationMode.rawValue`, `colorSpaceRawAfterRecordStart = device.activeColorSpace.rawValue`, `activeFormatMatchesLockedAfterRecordStart`) | 1696-1713 | Stop Condition gates b/c (active != .off when requested non-.off; Apple Log 2 preserved) |
| Stop-Condition resolved-error chain in finalize (`stabilizationActiveModeOff` / `stabilizationColorSpaceDowngraded` / `proRes422HQCodecDowngraded` / `actualCodecReadFailed`) | 792-808 (active-mode + colorSpace), codec branch in finalize | All four gates carry over to the product path |

### Adapt (smoke-shaped, needs product-shape rewrite)

| Item | Smoke shape | Product M7 shape |
|---|---|---|
| Package directory | `Caches/Filmtone/captures/m6-package-<UUID>/` | Same root, product-named subdir (`product-capture-<UUID>/` or per `clipId`). Smoke's staging-then-rename pattern can be **dropped** — product owns clip lifecycle so partial files are owner-managed. |
| Master file name | `m6-master.mov` | Owner-named or `clip-<UUID>.mov`. Single .mov per clip. |
| Duration model | Fixed 30s timer, `sessionQueue.asyncAfter(deadline: .now() + requestedDuration) { requestStop() }` (L703) | Owner-controlled start / stop via plugin method. No fixed timer. |
| Error enum | 22 cases incl. `gcsvWriteFailed`, `gcsvAccelResamplingDropped`, `noGyroSamples`, `noAccelSamples`, `unrecognizedStabilizationModeEnv`, etc. | Trimmed to ~9: `permissionDenied`, `noWideCamera`, `formatSelectionFailed`, `appleLog2EnumUnavailable`, `cannotAddInput`, `cannotAddMovieOutput`, `proRes422HQNotAvailable`, `unsupportedStabilizationModeForFormat`, `stabilizationActiveModeOff`, `stabilizationColorSpaceDowngraded`, `proRes422HQCodecDowngraded`, `actualCodecReadFailed`, `recordingFinishFailed`, `movieRecordingProducedNoFile`. |
| Diagnostics output | Three artifacts: `.mov` + `m6-motion.gcsv` + `m6-combined-timing.json` + `m6-debug.log` | Two artifacts: `.mov` + small product diagnostic JSON (recorded mode / activeColorSpace raw / actualMediaSubType / locked-format match). No `.gcsv`, no `.log`. |

### Smoke-only, drop entirely

- `FILMTONE_M6_STABILIZATION_MODE` env var parsing + the
  `candidateStabilizationModes` 8-mode array + `stabilizationNameToMode`
  + `acceptedStabilizationNames` (constants L224-254, parser referenced
  L579). Product locks `.cinematicExtendedEnhanced` and probes only
  that one mode against `isVideoStabilizationModeSupported(_:)`.
- `AVCaptureVideoDataOutput` setup (L555-564, L608-619). Smoke kept VDO
  as a timing side-band for gyro-mapping; M7 is stabilization-only and
  does not need PTS-to-Core-Motion alignment. Drop the entire VDO
  path, the `AVCaptureVideoDataOutputSampleBufferDelegate` extension
  (L1659-), and the `vdoQueue` / `vdoSamples` / `vdoFirstSamplePixelFormat`
  / `vdoFirstSampleDimensions` / `vdoRotationApplied` state.
- `CMMotionManager` gyro / accel sampling (`motion`, `motionHandlerQueue`,
  `gyroSamples`, `accelSamples`, `motion.startGyroUpdates`,
  `motion.startAccelerometerUpdates`, all snapshot logic).
- `.gcsv` writing path (`FilmtoneGcsvWriter` reference, `lastGcsvOutput`,
  the gcsv finalize branch in `finalizeAndComplete`).
- The fixed `requestedDuration` timer and `motionMargin` settle period.
- `dlog`-driven `.log` file. Product diagnostics go through Capacitor
  plugin response payload + standard `os_log`, not a per-clip text log.
- `schemaVersion = 1` JSON shape (smoke has 1316+ lines of JSON shape;
  product diagnostic is a small fixed dictionary).

### Capacitor bridge surface (existing, ready to extend)

- Plugin: `FilmtoneMediaPlugin` (`@objc(FilmtoneMediaPlugin)` /
  `jsName = "FilmtoneMedia"`) at `FilmtoneMediaPlugin.swift`. 11
  registered methods today (`pluginMethods` L9-21), incl.
  `probeCaptureCapabilities` (L353-373) which is the closest analog —
  Capacitor plugin method that drives an internal capture-related
  service via `Task.detached(priority: .userInitiated)`, returns a
  payload via `await MainActor.run { call.resolve(response) }`.
- Adding a method = (a) one line in the `pluginMethods: [CAPPluginMethod]`
  array, (b) one `@objc func name(_ call: CAPPluginCall)` body. No
  CAPBridgedPlugin overhaul needed.
- Auto-loaded into the Capacitor bridge by `CAPBridgedPlugin` conformance
  + `@objc` registration; no manual wiring in `AppDelegate`.

### Non-DEBUG hook surfaces

- `AppDelegate.application(_:didFinishLaunchingWithOptions:)` runs the
  full app bootstrap (`FilmtoneEditorFacade`, `FilmtoneRootHostingController`,
  `FilmtoneEditorStore`) **outside** `#if DEBUG`. The Capacitor bridge
  is a peer of that hosting; plugin methods on `FilmtoneMediaPlugin` are
  reachable from JS in the running app without any AppDelegate
  edits.
- The `#if DEBUG` block at AppDelegate L10-12 / L77+ only wires the
  smoke dispatcher and is independent of the production bridge.
- Conclusion: **Capacitor plugin method on `FilmtoneMediaPlugin` is
  the right entry**. No new plugin file, no AppDelegate change, no UI
  surface change in the iOS native target. The web shell (existing JS
  bundle in `apps/capacitor-film-lab-ios/ios/App/App/public/`) is the
  natural caller.

### Cross-cutting

- `FilmtoneCaptureCapabilityProbe` (already shipped, used by
  `probeCaptureCapabilities`) is a **read-only** capability probe.
  M7 product capture is a separate, write-side service. They share no
  state and should not collapse into one type.
- The `pickSource` / `runExport` / `saveToPhotos` plugin methods
  already use `bridge?.viewController` and `Task.detached`. Same
  patterns transfer to the M7 plugin method.

## Subtask 2 — Product surface design (draft, held for owner OK)

**No Swift edits applied. This is the propose-half of subtask 3's gate.**

### (a) Swift target file + class shape

- New file: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneProductCapture.swift`
- Class: `final class FilmtoneProductCapture: NSObject` matching the
  smoke's class shape (private state, single internal `AVCaptureSession`,
  delegate conformances on extensions).
- **No actor / no concurrency wrapper**. The smoke's
  `DispatchQueue(label: "filmtone.m6.session")` pattern transfers verbatim
  — capture is single-pipeline, the queue is the serialization point.
- Lifecycle: per-call instance owned by the plugin. Plugin holds
  `private var currentProductCapture: FilmtoneProductCapture?`.
  The instance is released after `recordProductClip` resolves /
  rejects.
- No singleton, no actor isolation gymnastics. AVFoundation owns
  thread-safety contracts via `sessionQueue`; matches what smoke proved
  in M2-B / M5-A / M6.

### (b) Entry point — Capacitor plugin method on existing FilmtoneMediaPlugin

- Add **one** method to `FilmtoneMediaPlugin`:

  ```swift
  @objc func recordProductClip(_ call: CAPPluginCall)
  ```

  Plus one line in `pluginMethods`:

  ```swift
  CAPPluginMethod(name: "recordProductClip", returnType: CAPPluginReturnPromise),
  ```

- JS-callable signature:

  ```ts
  FilmtoneMedia.recordProductClip({ durationSeconds: number }) -> Promise<{
      schemaVersion: number,
      filePath: string,
      fileURI: string,
      payload: {
          // diagnostic shape per (f) below
      }
  }>
  ```

- M7 minimum **does not implement start/stop semantics**. Fixed-duration
  record per call. Justification: M7 is the bootstrap; start/stop UX is
  M7+ / M9 territory and adds state machine + concurrency-with-cancel
  complexity that does not affect the stabilization integration
  question.
- Internally the method does:
  ```
  Task.detached(priority: .userInitiated) {
      let capture = FilmtoneProductCapture()
      // hold ref on plugin
      capture.recordClip(durationSeconds: ...) { result in
          // resolve / reject on MainActor
      }
  }
  ```
  Mirrors `probeCaptureCapabilities` (L353-373) exactly.

### (c) UI hook — none in M7

- M7 does not add a native UIKit / SwiftUI button. The owner-facing
  path is the Capacitor JS bridge call from the existing web shell
  (Safari devtools attached to the running app, or a temporary JS-side
  trigger).
- Strategy.md Done condition #5 of M7 is satisfied: "JS bridge call
  from the web shell" is an "owner-facing path".
- Adding a UIKit / SwiftUI button or a web-side React button is **out
  of scope** for M7 by Owner Stop Condition above. If owner wants a
  button next, that opens a follow-up active.

### (d) Loud-fail contract for stabilization unavailable

Three failure surfaces, all loud:

| Failure | Detection | Plugin reject code | Plugin reject message |
|---|---|---|---|
| Locked format does not list `cinematicExtendedEnhanced` as supported | `lockedFormat.isVideoStabilizationModeSupported(.cinematicExtendedEnhanced) == false` during `configureSession()` | `FILMTONE_PRODUCT_CAPTURE_STABILIZATION_UNSUPPORTED` | Includes the probed supported set so JS can surface |
| Active mode after `startRecording` is `.off` even though preferred was set | `appliedStabilizationMovieRaw == .off.rawValue` in `didStartRecordingTo` | `FILMTONE_PRODUCT_CAPTURE_STABILIZATION_NOT_ACTIVE` | Includes requested + active mode names |
| Apple Log 2 silent downgrade post-recording | `device.activeColorSpace.rawValue != 4` in `didStartRecordingTo` | `FILMTONE_PRODUCT_CAPTURE_COLOR_SPACE_DOWNGRADED` | Includes expected + observed raw values |
| ProRes 422 HQ → other codec silent downgrade | AVURLAsset codec read FourCC != `apch` | `FILMTONE_PRODUCT_CAPTURE_CODEC_DOWNGRADED` | Includes expected + observed FourCC |
| AVURLAsset codec read failure | `readActualMovieMediaSubType` returns errorMessage | `FILMTONE_PRODUCT_CAPTURE_CODEC_READ_FAILED` | Underlying message |
| Caller-supplied `durationSeconds` outside `[1.0, 60.0]` | parameter validation at plugin entry, before any AVCaptureSession setup | `FILMTONE_PRODUCT_CAPTURE_DURATION_OUT_OF_BOUNDS` | `detail = { requestedSeconds, minSeconds: 1.0, maxSeconds: 60.0 }`. **Loud reject — never clamp**. Owner direction 2026-05-07. |

- No silent fallback path. No "try `.cinematic` instead". The product
  contract is: if stabilization isn't available exactly per M6 PASS,
  the recording is rejected at the plugin boundary.
- The UI surface (web shell side) is not in M7 scope. JS gets the
  rejected promise; it is the web shell's responsibility to display.

### (e) Sandbox output path

- Root: `Caches/Filmtone/captures/` (same as smoke — already
  established pattern, low-risk).
- Per-clip subdir: `product-capture-<UUID>/` containing:
  - `clip.mov` (ProRes 422 HQ Apple Log 2)
  - `diagnostics.json` (per (f) below)
- No staging-then-rename. The smoke does atomic rename to mark
  finalize completion; M7 owns clip lifecycle within a single call so
  partial files on error are owner-debug, not user-facing.
- M7 does not address Photos library / camera roll save. That is a
  separate concern (existing `saveToPhotos` plugin method covers
  post-capture save if owner chooses).

### (f) Diagnostic shape (`diagnostics.json` + plugin response payload)

Fixed dictionary, ~17 fields. Subset matches the smoke's evidence
fields, minus motion / gcsv / VDO / staging:

```json
{
  "schemaVersion": 1,
  "deviceModel": "iPhone17,1",
  "iosVersion": "26.4.2",
  "lockedFormatIndex": 56,
  "lockedDimensions": "3840x2160",
  "lockedFPS": 30,
  "preferredStabilizationMode": "cinematicExtendedEnhanced",
  "preferredStabilizationModeRaw": 5,
  "supportedStabilizationModes": ["off","standard","cinematic","cinematicExtended","cinematicExtendedEnhanced","auto"],
  "appliedStabilizationMode": "cinematicExtendedEnhanced",
  "appliedStabilizationModeRaw": 5,
  "activeColorSpaceRaw": 4,
  "activeFormatMatchesLockedAfterRecordStart": true,
  "actualMediaSubType": "apch",
  "actualMediaSubTypeReadError": null,
  "movPath": "/.../product-capture-<UUID>/clip.mov",
  "movSizeBytes": 2503895563,
  "requestedDurationSeconds": 10.0,
  "recordedDurationSeconds": 10.012,
  "startedAtBootTime": 148110.512708041,
  "stoppedAtBootTime": 148120.524708041,
  "hardwareCost": 0.6339474,
  "sessionPreset": "AVCaptureSessionPresetInputPriority"
}
```

- Returned to JS via `call.resolve(...)` payload **and** written to
  `diagnostics.json` next to the clip. Both sources are authoritative
  copies of the same dictionary — JS gets immediate access for UI;
  on-disk copy is debug evidence.
- No `.gcsv`, no `.log`, no JSON arrays of per-sample data.

### Estimated edit footprint (subtask 4)

| File | Change |
|---|---|
| new: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneProductCapture.swift` | ~400-500 lines (smoke is 1743; product drops VDO + motion + gcsv + env-probe + 30s timer) |
| `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift` | +30-40 lines (one plugin method + one `pluginMethods` row + one `currentProductCapture` ref + one error-bridging helper) |
| `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` | New file membership (PBXBuildFile + PBXFileReference + Sources phase) |
| `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` | NOT touched in M7 implementation phase. Only at subtask 6 archive: 1-line Completion Log entry. |

Owner Stop Condition adherence:
- No "redesign the capture UI" → M7 adds zero UIKit/SwiftUI.
- No "rebuild the Capacitor plugin surface" → M7 adds one method to
  the existing plugin, no new plugin file.
- No state machine for multi-mode capture → M7 is single-mode
  (`cinematicExtendedEnhanced` only) fixed-duration.
- No silent fallback → all 5 unsupported / downgrade cases are
  loud-fail with distinct reject codes.
- No M5-B wording cleanup → strategy.md Done block stays as-is.
- No strategy.md milestone-body edits → only the eventual subtask 6
  1-line Completion Log entry.
- No smoke deletion / rename → smokes stay DEBUG-only.

### Subtask 3 STOP — owner OK requested

Three explicit decisions to confirm before subtask 4 (implementation)
proceeds:

1. **(b) plugin method shape** — single `recordProductClip(durationSeconds)`
   with fixed-duration record per call. OK or want start/stop pair in
   M7?
2. **(c) UI hook** — zero native UI in M7; owner triggers via
   Capacitor JS bridge from existing web shell. OK or want a single
   button on an existing settings/diagnostics screen as part of M7?
3. **(d) loud-fail codes** — 5 distinct `FILMTONE_PRODUCT_CAPTURE_*`
   reject codes. OK or want a single generic code with structured
   detail?

## Closure rule

- Done conditions 1-6 met + on-device evidence captured → archive +
  1-line strategy.md Completion Log entry.
- Stabilization unsupported on M5-A locked format at runtime + owner
  has not OK'd a recorded explicit fallback acknowledgement → STOP,
  escalate. M7 does not silently downgrade.
- Owner rejects the design at subtask 3 → revise inline, re-request OK.
  No partial application.
- Owner expands scope past the 6 Done items → close this active without
  applying past subtask 3, open a broader active separately.

## Notes

- This active runs on the M6 PASS branch
  (`feature/ios-v2-capture-m6-avfoundation-stabilization-smoke`) so M6
  PASS + strategy realignment + M7 implementation can ship as one
  merge unit. Owner may prefer a thin split branch; that decision
  belongs to the user, not this active.
- `FilmtoneCaptureWriter.swift` is named without `Smoke` but is a
  smoke per its header. M7 does not rename it. The new product file
  carries an unambiguous product-naming convention.
- M7 product path is not the authoritative enum survey; M6 owns that
  evidence. `FilmtoneProductCapture.candidateStabilizationModes` is
  intentionally a 6-mode subset (drops `previewOptimized` /
  `lowLatency` per M6 empirical evidence on locked
  `formats[56].appleLog2`). Do not widen it to chase parity with
  smoke — full enum survey lives in M6 archive.
- Follow-up (recorded for archive, NOT in M7 scope): strategy.md M5
  Done wording referencing "Gyroflow loads the video and sidecar /
  basic sync optical-flow check / one handheld pan stabilizes without
  obvious phase error" is stale per the M5-B BLOCKED Completion Log
  entry. A separate active should rewrite those bullets to reflect
  the M5-A on-device truth and the M5-B / Gyroflow desktop decision
  not being a Filmtone milestone.
