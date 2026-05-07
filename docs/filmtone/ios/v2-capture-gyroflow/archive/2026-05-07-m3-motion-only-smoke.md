# Active - M3 Motion-Only Recorder Smoke

Date: 2026-05-07 JST

## Milestone

M3 - Motion-Only Recorder Smoke

## Goal

Prove Core Motion sample delivery on iPhone 17 Pro / iOS 26.4.2 is stable and
dense enough on its own — without any AVCaptureSession running — that M4 can
later combine it with the M2-B Path C ProRes Apple Log 2 video pipeline for
Gyroflow timing mapping.

Specifically:

- A 10 second motion-only diagnostic file is produced on a real device.
- Gyro and accelerometer samples cover the full requested duration.
- Median sample interval and max timestamp gap are visible in diagnostics.
- `NSMotionUsageDescription` is in `Info.plist` before any motion API is
  touched at runtime.
- **Raw** `startGyroUpdates` / `startAccelerometerUpdates` are used. Fused
  `startDeviceMotionUpdates` is not used for Gyroflow data.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionRecorder.swift` (new)
- `apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
  - Replace the unconditional DEBUG sequence
    (`runM1CapabilityProbeOnLaunch()` + `runM2BCoexistenceSmokeOnLaunch()`)
    with a single env-var dispatcher so smokes are mutually exclusive.
  - Selector: `ProcessInfo.processInfo.environment["FILMTONE_SMOKE_LANE"]`
    → `"m1"` | `"m2b"` | `"m3"` | unset/other ⇒ no smoke runs.
  - Add `runM3MotionOnlySmokeOnLaunch()` reachable only from the dispatcher.
  - This guarantees M3 evidence is **motion-only** on device — no AVCapture
    residue from M2-B. Past M1 / M2-B archives stay reproducible by setting
    the env var explicitly. `devicectl --environment-variables` requires a
    **JSON dictionary** (not `KEY=value`); fall-back form
    `DEVICECTL_CHILD_FILMTONE_SMOKE_LANE=m3 xcrun devicectl …` also works.
    See Verification for the exact invocation. Reference:
    `reference_devicectl_env_var_launch`.
- `apps/capacitor-film-lab-ios/ios/App/App/Info.plist`
  (add `NSMotionUsageDescription` only)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (add 4 entries for the new Swift file: `PBXBuildFile`, `PBXFileReference`,
  group children, sources phase — same shape as
  `FilmtoneCaptureCapabilityProbe.swift` / `FilmtoneCaptureWriter.swift`)
- `docs/filmtone/ios/v2-capture-gyroflow/active.md` (this file, progress)
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (only for final result)

Out of edit scope on this lane: `FilmtoneCaptureWriter.swift`,
`FilmtoneCaptureCapabilityProbe.swift`, capture UI, JS bridge,
`packages/film-lab-*`.

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (M3 spec lines 88-106)
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m1-capability-probe.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m2-b-coexistence-smoke.md`
- `apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`
- `apps/capacitor-film-lab-ios/diagnostics/m2b-coexistence-smoke.json`
  (for diagnostic schema / file-IO conventions to mirror)

## Checklist

### Implementation (30-min granular)

- [x] Add `NSMotionUsageDescription` string to `Info.plist`.
- [x] Create `FilmtoneMotionRecorder.swift` with one public entry point
  `static func runSmoke(duration: TimeInterval = 10.0,`
  `completion: @escaping (Result<SmokeResult, Error>) -> Void)`.
- [x] Define `SmokeResult { jsonURL, debugLogURL }` and
  `SmokeError` enum: `coreMotionUnavailable`, `gyroUnavailable`,
  `accelerometerUnavailable`, `noGyroSamples`, `noAccelSamples`.
- [x] Use `CMMotionManager` with raw APIs only:
  `startGyroUpdates(to: handlerQueue) { [weak self] data, err in ... }` and
  `startAccelerometerUpdates(to: handlerQueue) { ... }`.
  Do NOT call `startDeviceMotionUpdates`.
- [x] Set `gyroUpdateInterval` and `accelerometerUpdateInterval` to
  `1.0 / 200.0` (200 Hz request — Apple hardware-caps the update interval
  per SDK headers; the **observed** interval is what counts).
  Record both `requestedSeconds = 0.005` and the observed
  `effectiveHz = 1.0 / medianIntervalSeconds` per stream in JSON.
- [x] Use a dedicated serial `OperationQueue` (`maxConcurrentOperationCount = 1`)
  for sample handlers (one queue, both handlers). Handler body must be
  **minimal** — append `(timestamp, x, y, z)` to a stream-local array and
  return. No filtering, no JSON serialisation, no Swift `defer` blocks
  inside handlers. Rationale: CoreMotion SDK headers state that
  `stopGyroUpdates` / `stopAccelerometerUpdates` cancel pending operations
  on the queue; minimising per-handler work minimises the post-stop loss
  window.
- [x] Drive timing from `CMLogItem.timestamp` (boot-uptime seconds, same
  reference as M2-B Movie/VDO timestamps so M4 mapping is straightforward).
- [x] Finalize sequence (post-stop wait is **best-effort**, not the source
  of truth):
  1. After `duration` elapses, dispatch a `BlockOperation` onto the same
     handler queue that calls `stopGyroUpdates()` and
     `stopAccelerometerUpdates()` and snapshots the gyro/accel sample
     arrays into local `let` copies. Running the snapshot on the same
     serial queue serialises it after any handler operations already
     enqueued; pending-but-not-yet-started handler operations may be
     cancelled per SDK header — that loss is bounded and acceptable.
  2. After the snapshot operation completes, compute stats and write JSON.
  3. `waitUntilAllOperationsAreFinished()` is *only* used to block the
     completion callback until step 2 is done, not as a sample-completeness
     guarantee.
  4. Record `gyro.sampleCount` / `accel.sampleCount` and
     `coverageSeconds = lastTS - firstTS` directly from the snapshot — Done
     conditions are evaluated against the snapshot, not against any
     "samples observed during stop".

  Implementation notes:
  - **Never call `waitUntilAllOperationsAreFinished()` from the handler queue
    itself** (deadlock). It must be called from an outside thread (the
    duration-elapsed dispatch source / completion-waiter), purely to block
    the completion callback until the BlockOperation in step 1+2 finishes.
  - The "no `m2b-*` artefacts produced this launch" sanity check is **not**
    a stale-file existence check (the app container can carry past M2-B
    artefacts indefinitely). Instead verify: (a) `m3-debug.log` contains the
    `[FilmtoneM3Smoke] starting` lane marker with this launch's timestamp,
    and (b) `m2b-debug.log` mtime / last line is **older** than this M3
    launch — i.e. it was not written this launch.
- [x] Compute per-stream stats: `firstTS`, `lastTS`, `coverageSeconds`,
  `sampleCount`, `effectiveHz`, `intervals.medianSeconds`,
  `intervals.maxGapSeconds`, `intervals.p99Seconds`,
  `intervals.gapCountOver50ms`, `intervals.gapCountOver100ms`,
  `intervals.gapCountOver200ms`. Do not store raw sample arrays in JSON
  (keep file small; Gyroflow `.gcsv` is M5).
- [x] Write diagnostics JSON to
  `Library/Caches/Filmtone/captures/m3-motion-only-smoke.json`
  and trace log to `m3-debug.log` (mirrors M2-B layout).
- [x] Refactor the `#if DEBUG` block in `AppDelegate.swift` so smokes are
  mutually exclusive: replace the unconditional sequence with one
  dispatch on `FILMTONE_SMOKE_LANE` env var. Add
  `runM3MotionOnlySmokeOnLaunch()` only as a `case "m3"` branch; do not
  call it side-by-side with M1 or M2-B. Use `[FilmtoneM3Smoke]` log
  prefix. Default (env var unset) ⇒ no smoke runs, so day-to-day Xcode
  Debug launches stay clean.
- [x] Add 4 pbxproj entries for `FilmtoneMotionRecorder.swift` mirroring
  `FilmtoneCaptureWriter.swift` shape. New file IDs:
  `D20000010000000000000031` (build) /
  `C20000010000000000000031` (ref).

### JSON schema (planned, schemaVersion: 1)

```
{
  "lane": "v2-capture-gyroflow",
  "milestone": "M3",
  "schemaVersion": 1,
  "smokeLaneEnvVar": "m3",
  "duration": { "requestedSeconds": 10, "elapsedSeconds": ... },
  "device": { "model": ..., "systemVersion": ... },
  "coreMotion": {
    "isGyroAvailable": true,
    "isAccelerometerAvailable": true,
    "isDeviceMotionAvailable": true,   // read-only flag; fused not started
    "requestedGyroIntervalSeconds": 0.005,
    "requestedAccelIntervalSeconds": 0.005
  },
  "gyro": {
    "sampleCount": ..., "firstTS": ..., "lastTS": ...,
    "coverageSeconds": ...,
    "effectiveHz": ...,
    "intervals": {
      "medianSeconds": ...,
      "maxGapSeconds": ...,
      "p99Seconds": ...,
      "gapCountOver50ms": ...,
      "gapCountOver100ms": ...,
      "gapCountOver200ms": ...
    }
  },
  "accel": { /* same fields */ },
  "smokeError": null
}
```

`isDeviceMotionAvailable` is a flag read only — `startDeviceMotionUpdates`
is **not called** on M3 (strategy.md M3 done condition: fused device-motion
samples are not used for Gyroflow data).

### Verification

`bun cap sync ios` is intentionally skipped — this lane only edits
Swift / `Info.plist` / pbxproj on the iOS native side. No Capacitor
bridge or `ios/App/App/public` web asset is touched, so `cap sync`
would only risk overwriting unrelated state.

- [x] pbxproj integration check:
  `grep -c FilmtoneMotionRecorder apps/capacitor-film-lab-ios/ios/App/`
  `App.xcodeproj/project.pbxproj` returns `4`
  (PBXBuildFile + PBXFileReference + group children + sources phase).
- [x] Simulator build:
  `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug`
  `-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'`
  `build CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED.
- [x] Real-device build (signed Debug) for iPhone 17 Pro
  (`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`) using
  `-derivedDataPath /tmp/filmtone-m3-derived -allowProvisioningUpdates`.
- [x] `xcrun devicectl device install app …App.app` succeeds.
- [x] Launch with the M3 selector env var (motion-only, no AVCapture).
  `devicectl --environment-variables` expects a **JSON dictionary**, not
  `KEY=value`. Primary form:
  `xcrun devicectl device process launch --device <udid>`
  `--environment-variables '{"FILMTONE_SMOKE_LANE":"m3"}'`
  `com.chibatakumi.film.lab.ios`.
  Fall-back if the JSON form fails to propagate:
  `DEVICECTL_CHILD_FILMTONE_SMOKE_LANE=m3 xcrun devicectl device process`
  `launch --device <udid> com.chibatakumi.film.lab.ios`.
  Confirm propagation by grepping the m3 debug log for
  `[FilmtoneM3Smoke] starting`. (Permission prompt for
  `NSMotionUsageDescription` may or may not appear depending on prior
  authorization state — that is *not* a Done condition; see below.)
- [x] Pull diagnostics with
  `xcrun devicectl device copy from --device <udid>`
  `--source 'Library/Caches/Filmtone/captures/m3-motion-only-smoke.json'`
  `--destination /tmp/filmtone-m3-motion-only-smoke/` (and `m3-debug.log`).
- [x] Copy small diagnostics into repo:
  `apps/capacitor-film-lab-ios/diagnostics/m3-motion-only-smoke.json`
  `apps/capacitor-film-lab-ios/diagnostics/m3-debug.log`.
- [x] Sanity check the env-var dispatcher worked: `m3-debug.log` contains
  `[FilmtoneM3Smoke] starting` with this launch's timestamp, and
  `m2b-debug.log` (if present from past launches) was **not** updated
  during this launch (compare mtime / last-line timestamp). Stale m2b
  artefact files in the container do not count as evidence of M2-B
  running this launch.
- [x] `git diff --check` clean.

### Done Conditions (from strategy.md)

- A 10 second motion diagnostic file is produced.
- Gyro and accelerometer samples cover the requested duration
  (`coverageSeconds >= 9.5` for both).
- Median interval and max timestamp gap are visible in diagnostics.
- `NSMotionUsageDescription` is present in `Info.plist` (string check —
  whether the OS prompts the user this launch is OS-state dependent and
  is *not* a Done condition).
- Raw gyro and raw accelerometer APIs are used; fused device-motion samples
  are not used for Gyroflow data.

### Stop Conditions

- `CMMotionManager.isGyroAvailable` or `.isAccelerometerAvailable`
  returns `false` on iPhone 17 Pro (would be unexpected — escalate).
- Permission denied for `NSMotionUsageDescription` despite plist entry.
- Either stream produces zero samples after start.
- `intervals.maxGapSeconds > 0.5` — hard stop (M4 video↔motion mapping
  becomes unreliable).
- 2 consecutive real-device verification failures.

Quality lines (not stop, but recorded for M4 risk read):

- `intervals.maxGapSeconds > 0.2` ⇒ note as "M4 mapping risk: high".
- `intervals.maxGapSeconds > 0.1` ⇒ note as "M4 mapping risk: moderate".
- `gapCountOver100ms > 0` ⇒ note in archive findings.

### Out of Scope

- Video capture (M2-B already PASS on its own branch).
- Combined video + motion timing (that is M4).
- `.gcsv` generation (M5).
- Fused device-motion (`startDeviceMotionUpdates`) — explicitly not used
  for Gyroflow data per strategy.md M3 done condition.
- Capture preview UI / JS bridge surface / editor handoff.
- Audio.
- External SSD output.

## Verification Status

| Step | Status |
|---|---|
| `Info.plist` `NSMotionUsageDescription` added | ✅ added |
| `FilmtoneMotionRecorder.swift` written | ✅ added (raw gyro + accel, append-only handlers, BlockOperation snapshot) |
| pbxproj 4 entries added (grep -c == 4) | ✅ `grep -c FilmtoneMotionRecorder ... project.pbxproj` returns `4` |
| `AppDelegate.swift` env-var dispatcher refactor | ✅ `FILMTONE_SMOKE_LANE` selector wired (m1 \| m2b \| m3 \| unset) |
| Simulator build | ✅ **BUILD SUCCEEDED** (iphonesimulator26.4) |
| Real-device signed Debug build | ✅ **BUILD SUCCEEDED** (iPhone 17 Pro / iOS 26.4.2, `/tmp/filmtone-m3-derived`) |
| Real-device run with `FILMTONE_SMOKE_LANE=m3` only | ✅ launched via JSON-dictionary form `--environment-variables '{"FILMTONE_SMOKE_LANE":"m3"}'` |
| Diagnostics pulled + copied to repo | ✅ `apps/capacitor-film-lab-ios/diagnostics/m3-motion-only-smoke.json` + `m3-debug.log` |
| Sanity: m3 lane marker present + m2b log not updated this launch | ✅ m3 first dlog `[1778134609.638834]`, m2b last dlog `[1778131511.890116]` (~52 min stale) |
| `git diff --check` | ✅ clean |

## Real-Device Findings

Run on iPhone 17 Pro (`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`), iOS 26.4.2,
Debug build of branch `feature/ios-v2-capture-m3-motion-recorder-smoke`.

Pulled artifacts:

- `/tmp/filmtone-m3-pull/m3-motion-only-smoke.json`
- `/tmp/filmtone-m3-pull/m3-debug.log`

Small diagnostics evidence copied into the repo:

- `apps/capacitor-film-lab-ios/diagnostics/m3-motion-only-smoke.json`
- `apps/capacitor-film-lab-ios/diagnostics/m3-debug.log`

Per-stream evidence (10-second smoke, requestedHz=200 / requestedInterval=0.005s):

| Stream | sampleCount | coverageSeconds | effectiveHz | medianInterval | maxGap | gapCountOver50ms / 100ms / 200ms |
|---|---:|---:|---:|---:|---:|---:|
| gyro  | 1048 | 10.479 | 99.92 | 0.01001s | 0.01001s | 0 / 0 / 0 |
| accel | 1048 | 10.479 | 99.92 | 0.01001s | 0.01001s | 0 / 0 / 0 |

`smokeError = null`. `fusedDeviceMotionStarted = false`.
`isDeviceMotionAvailable = true` (read-only flag, fused not started).

Notes:

- requested 200 Hz vs observed ~100 Hz — Apple hardware-caps the raw gyro
  / accelerometer update interval at the OS default; the observed
  effectiveHz is canonical, requested is recorded for traceability. Done
  Conditions are `coverageSeconds >= 9.5` and "median interval and max
  timestamp gap visible" — both PASS.
- maxGapSeconds 0.0100s sits 50× below the hard-stop line (0.5s) and 10×
  below the "moderate" quality line (0.1s). M4 video↔motion mapping has
  generous timing headroom on this hardware.

Compilation issue caught during this lane (recorded so the next lane does
not repeat it):

1. `private func finalize()` collides with `NSObject.finalize()` on a
   class that inherits from `NSObject` — same trap M2-B hit. Renamed to
   `finalizeAndComplete()` in `FilmtoneMotionRecorder`.

Bootstrap note (worktree-only, not a lane edit):

- Capacitor web bootstrap files (`ios/App/App/public`, `config.xml`,
  `capacitor.config.json`) are gitignored and absent in fresh worktrees.
  Copied them from the M2-B worktree once so the build had something to
  embed. `bun cap sync ios` was not used — this lane never edits or
  regenerates the web bridge.
