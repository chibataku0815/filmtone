# Active - M4 Combined Timing Smoke

Date: 2026-05-07 JST

## Milestone

M4 - Combined Timing Smoke

## Goal

Prove that, on the same single `AVCaptureSession` run on iPhone 17 Pro / iOS
26.4.2, video PTS (M2-B Path C: ProRes 422 HQ Apple Log 2 master via
`AVCaptureMovieFileOutput` + `AVCaptureVideoDataOutput` timing side-band) and
Core Motion raw gyro / accelerometer timestamps (M3 path) live in a clock
relationship that is concrete enough to begin `.gcsv` work in M5.

Specifically, on a single 30-second smoke run:

- A 30 second `.mov` master is produced.
- Motion samples cover the full video duration plus a small margin
  (gyro / accel `coverageSeconds >= 30.5`).
- First / last video VDO sample PTS (host-time seconds) are present in JSON.
- First / last MovieFile output recording timestamps are present in JSON.
- First / last gyro and accelerometer Core Motion `CMLogItem.timestamp`
  values are present in JSON.
- A `mach_absolute_time` anchor captured at `session.startRunning()` and
  the `mach_timebase_info` `numer` / `denom` are present in JSON, so M5
  can reproduce the host-time ↔ boot-uptime relationship without guessing.
- A computed offset between first VDO host-time PTS and first gyro
  boot-uptime is recorded (sanity: should be well under 1 second on a
  single session that owns both subsystems).

This M4 lane records the timing relationship; it does not generate `.gcsv`
or import into Gyroflow (M5).

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCombinedTimingSmoke.swift`
  (new) — single-class coordinator that owns `AVCaptureSession` (with
  `AVCaptureMovieFileOutput` master + `AVCaptureVideoDataOutput` side-band)
  and `CMMotionManager` (raw gyro + accel) for one 30-second run, captures
  one shared `mach_absolute_time` anchor at session start, and writes the
  combined diagnostics. **The implementation copies only the minimum logic
  needed from `FilmtoneCaptureWriter` (M2-B) and `FilmtoneMotionRecorder`
  (M3); it does not call their static `runSmoke` entry points side-by-side
  because that would give two sessions and lose the shared anchor.**
- `apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
  - Add `case "m4": runM4CombinedTimingSmokeOnLaunch()` to
    `runFilmtoneSmokeIfRequested()` (env-var dispatcher already in place
    from M3 — this is a 1-case extension, not a refactor).
  - Add `runM4CombinedTimingSmokeOnLaunch()` reachable only from the
    dispatcher. `[FilmtoneM4Smoke]` log prefix.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (add 4 entries for the new Swift file: `PBXBuildFile`, `PBXFileReference`,
  group children, sources phase — same shape as `FilmtoneMotionRecorder.swift`
  / `FilmtoneCaptureWriter.swift`)
- `docs/filmtone/ios/v2-capture-gyroflow/active.md` (this file, progress)
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (only for final result
  Completion Log entry on archive)

Out of edit scope on this lane:

- `Info.plist` — no new keys. `NSCameraUsageDescription` (M2-B) and
  `NSMotionUsageDescription` (M3) are already present.
- `FilmtoneCaptureWriter.swift` — read-only reference, do not refactor.
- `FilmtoneMotionRecorder.swift` — read-only reference, do not refactor.
- `FilmtoneCaptureCapabilityProbe.swift`, capture UI, JS bridge,
  `packages/film-lab-*`.

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (M4 spec lines 108-127)
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m1-capability-probe.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m2-b-coexistence-smoke.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m3-motion-only-smoke.md`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureWriter.swift`
  (M2-B reference: session config, MovieFile + VDO attachment shape,
  `hardwareCost`, format / Apple Log 2 selection)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMotionRecorder.swift`
  (M3 reference: raw API call shape, serial OperationQueue handler,
  BlockOperation snapshot finalize, NSObject.finalize collision avoidance)
- `apps/capacitor-film-lab-ios/diagnostics/m2b-coexistence-smoke.json`
  (M2-B diagnostic schema)
- `apps/capacitor-film-lab-ios/diagnostics/m3-motion-only-smoke.json`
  (M3 diagnostic schema)

## Anchor Strategy (decision recorded — applies to implementation)

iOS clock domains, verified during M2-B / M3:

- `CMSampleBuffer.presentationTimeStamp` (VDO) is on the host-time clock
  (`CMClockGetHostTimeClock`), which on iOS derives from `mach_absolute_time`.
- `CMLogItem.timestamp` (Core Motion) is **system uptime in seconds**, which
  also derives from `mach_absolute_time`.

Therefore both timelines share the underlying `mach_absolute_time` source,
but expose different units (CMTime vs seconds). M4 makes this explicit by
recording, in one place:

- `anchor.machTimebaseNumer` / `anchor.machTimebaseDenom` — from
  `mach_timebase_info(&info)` once per process.
- `anchor.startMachAbsolute` — `mach_absolute_time()` snapshot taken
  immediately after the **synchronous** `session.startRunning()` returns
  on the session-config queue.
- `anchor.startBootUptimeSeconds` — `ProcessInfo.processInfo.systemUptime`
  snapshot taken on the same line as `startMachAbsolute`.

These three together let M5 (and any downstream consumer) convert any VDO
host-time PTS into a Core Motion boot-uptime, and vice versa, without
guessing.

M4 records the values; computing per-frame motion lookups is M5 / Gyroflow.

## Checklist

### Implementation (30-min granular)

- [x] Add 4 pbxproj entries for `FilmtoneCombinedTimingSmoke.swift`
  mirroring `FilmtoneMotionRecorder.swift` shape. New file IDs:
  `D20000010000000000000041` (build) /
  `C20000010000000000000041` (ref).
- [x] Create `FilmtoneCombinedTimingSmoke.swift` with one public entry:
  `static func runSmoke(duration: TimeInterval = 30.0,`
  `motionMargin: TimeInterval = 1.0,`
  `completion: @escaping (Result<SmokeResult, Error>) -> Void)`.
- [x] Define `SmokeResult { movURL, jsonURL, debugLogURL }` and
  `SmokeError` enum: `cameraUnavailable`, `motionUnavailable`,
  `formatSelectionFailed`, `writerStartFailed`, `noVideoSamples`,
  `noGyroSamples`, `noAccelSamples`, `recordingFinishFailed`.
- [x] Capture-side: copy the M2-B Path C config minimum from
  `FilmtoneCaptureWriter` — `BuiltInWideAngleCamera`. **Fix the format
  to the M2-B-validated `device.formats[56]`** (3840x2160 @ 30 fps,
  pixelFormat `x422`, Apple Log 2). No search, no fallback: if
  `device.formats.count <= 56`, or `formats[56].supportedColorSpaces`
  does not contain `.appleLog2`, or the dimensions / fps differ from
  the M2-B values, fail with `formatSelectionFailed`. Keeping the
  format identical to the M2-B PASS run is what makes the M4 combined
  evidence comparable. Apply via
  `device.activeFormat = device.formats[56]` and
  `device.activeColorSpace = .appleLog2` inside
  `lockForConfiguration`. ProRes 422 HQ on `AVCaptureMovieFileOutput`
  is configured via
  `movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.proRes422HQ],`
  `for: videoConnection)` after confirming the connection-less property
  `movieOutput.availableVideoCodecTypes` contains `.proRes422HQ` (same
  shape as M2-B; iPhoneOS 26.4 SDK exposes this as a property on
  `AVCaptureMovieFileOutput`, not a method taking a connection). Attach
  `AVCaptureVideoDataOutput` as the timing side-band via the same
  connection pattern as M2-B. `videoStabilizationMode = .off` when
  controllable (record observed value either way).
- [x] Motion-side: copy the M3 minimum from `FilmtoneMotionRecorder` —
  raw `startGyroUpdates` + `startAccelerometerUpdates` only, dedicated
  serial `OperationQueue` (`maxConcurrentOperationCount = 1`),
  append-only handlers, request interval `1.0 / 200.0`. Do NOT call
  `startDeviceMotionUpdates`. Use `finalizeAndComplete()` (avoid
  `NSObject.finalize` collision — same trap M2-B / M3 hit).
- [x] Anchor capture: immediately after `session.startRunning()` returns
  on the session-config queue, record `mach_absolute_time()`,
  `ProcessInfo.processInfo.systemUptime`, and (once per process)
  `mach_timebase_info`. Start motion updates **on the same line** so the
  motion-vs-video offset stays small and bounded.
- [x] Recording lifecycle: start `AVCaptureMovieFileOutput.startRecording`
  immediately after the anchor capture; stop after `duration` (30 s) via
  `stopRecording()`. Stop motion updates `motionMargin` seconds after
  `stopRecording` finalizes — motion must overlap the video on both ends
  (start-before / stop-after).
- [x] VDO side-band per-frame timing capture: in
  `captureOutput(_:didOutput:from:)`, append `(sampleIndex,
  presentationTimeStamp.seconds, hostTimeSeconds)` to a stream-local
  array. No filtering, no JSON serialisation in the callback.
- [x] MovieFile start anchor: implement
  `AVCaptureFileOutputRecordingDelegate
  .fileOutput(_:didStartRecordingTo:startPTS:from:)` (iOS 18.2+;
  available on the iOS 26.4.x target). Capture `startPTS` and convert
  to seconds via `startPTS.seconds`. `startPTS` is on
  `session.synchronizationClock`, which on iOS is host-time-clock
  derived — directly comparable to VDO `presentationTimeStamp.seconds`
  and (after `mach_absolute_time` ↔ `systemUptime` is the identity
  on iOS) to Core Motion `CMLogItem.timestamp`.
- [x] MovieFile finalize: `AVCaptureFileOutputRecordingDelegate
  .fileOutput(_:didFinishRecordingTo:from:error:)` returns the master
  `.mov` URL and any error — gate diagnostics write on this. Read
  `recordedDuration` once just before `stopRecording()` and persist as
  `movieFile.recordedDurationSeconds`. Do **not** use
  `recordedFileStartTime` (does not exist on `AVCaptureFileOutput`);
  the start anchor comes from the `startPTS` delegate above.
- [x] Compute video stats: `vdoSampleCount`, `vdoFirstPTSSeconds`,
  `vdoLastPTSSeconds`, `vdoCoverageSeconds`,
  `vdoEffectiveFps = sampleCount / coverageSeconds`,
  `vdoIntervals.medianSeconds` / `maxGapSeconds` / `p99Seconds` /
  `gapCountOver50ms` / `gapCountOver100ms` / `gapCountOver200ms`.
  Record MovieFile metadata: `movFileSizeBytes` (from `FileManager`
  attributes after finalize), `recordedDurationSeconds` (snapshot of
  `recordedDuration` taken just before `stopRecording`),
  `startPTSSeconds` (from the iOS 18.2+ `didStartRecordingTo:startPTS:
  from:` delegate above; same clock domain as VDO PTS).
- [x] Compute motion stats per stream: same shape as M3 — `firstTS`,
  `lastTS`, `coverageSeconds`, `sampleCount`, `effectiveHz`,
  `intervals.medianSeconds` / `maxGapSeconds` / `p99Seconds` /
  `gapCountOver50ms` / `gapCountOver100ms` / `gapCountOver200ms`.
- [x] Compute mapping offset section: `mapping.firstVdoPTSSeconds`,
  `mapping.firstGyroTSSeconds`, `mapping.firstAccelTSSeconds`,
  `mapping.vdoPTSMinusGyroTSSeconds = firstVdoPTSSeconds -
  firstGyroTSSeconds`, `mapping.vdoPTSMinusAccelTSSeconds`. Record but do
  not enforce a hard threshold here — Done conditions only require the
  numbers to exist; M5 will judge them.
- [x] Write diagnostics JSON to
  `Library/Caches/Filmtone/captures/m4-combined-timing-smoke.json`,
  master to `m4-master.mov`, trace log to `m4-debug.log`. (Mirrors M2-B
  layout.)
- [x] Add `case "m4": runM4CombinedTimingSmokeOnLaunch()` to
  `runFilmtoneSmokeIfRequested()` in `AppDelegate.swift`. Implement
  `runM4CombinedTimingSmokeOnLaunch()` calling
  `FilmtoneCombinedTimingSmoke.runSmoke(duration: 30.0)`. Use
  `[FilmtoneM4Smoke]` log prefix.

### JSON schema (planned, schemaVersion: 1)

```
{
  "lane": "v2-capture-gyroflow",
  "milestone": "M4",
  "schemaVersion": 1,
  "smokeLaneEnvVar": "m4",
  "duration": { "requestedSeconds": 30, "motionMarginSeconds": 1, "elapsedSeconds": ... },
  "device": { "model": ..., "systemVersion": ... },
  "anchor": {
    "machTimebaseNumer": ..., "machTimebaseDenom": ...,
    "startMachAbsolute": ...,
    "startBootUptimeSeconds": ...
  },
  "video": {
    "format": { "pixelFormat": "x422", "colorSpace": "AppleLog2",
                "dimensions": [3840, 2160], "fps": 30 },
    "writer": { "codec": "ProRes422HQ",
                "movFileSizeBytes": ..., "movDurationSeconds": ... },
    "movieFile": {
      "startPTSSeconds": ...,
      "recordedDurationSeconds": ...,
      "movFileSizeBytes": ...
    },
    "vdo": {
      "sampleCount": ...,
      "firstPTSSeconds": ..., "lastPTSSeconds": ...,
      "coverageSeconds": ...,
      "effectiveFps": ...,
      "intervals": {
        "medianSeconds": ..., "maxGapSeconds": ..., "p99Seconds": ...,
        "gapCountOver50ms": ..., "gapCountOver100ms": ...,
        "gapCountOver200ms": ...
      }
    },
    "stabilizationMode": "off" /* or observed value */
  },
  "motion": {
    "fusedDeviceMotionStarted": false,
    "requestedHz": 200,
    "gyro":  { /* same shape as M3 */ },
    "accel": { /* same shape as M3 */ }
  },
  "mapping": {
    "firstVdoPTSSeconds": ...,
    "firstGyroTSSeconds": ...,
    "firstAccelTSSeconds": ...,
    "vdoPTSMinusGyroTSSeconds": ...,
    "vdoPTSMinusAccelTSSeconds": ...
  },
  "smokeError": null
}
```

### Verification

`bun cap sync ios` is intentionally skipped — this lane only edits
Swift / pbxproj on the iOS native side. No Capacitor bridge or
`ios/App/App/public` web asset is touched.

- [x] pbxproj integration check:
  `grep -c FilmtoneCombinedTimingSmoke apps/capacitor-film-lab-ios/ios/App/`
  `App.xcodeproj/project.pbxproj` returns `4`.
- [x] Simulator build:
  `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug`
  `-sdk iphonesimulator -destination 'generic/platform=iOS Simulator'`
  `build CODE_SIGNING_ALLOWED=NO` → BUILD SUCCEEDED.
- [x] Real-device signed Debug build for iPhone 17 Pro
  (`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`) using
  `-derivedDataPath /tmp/filmtone-m4-derived -allowProvisioningUpdates`.
- [x] `xcrun devicectl device install app …App.app` succeeds.
- [x] Launch with the M4 selector env var (combined, single session).
  Primary form:
  `xcrun devicectl device process launch --device <udid>`
  `--environment-variables '{"FILMTONE_SMOKE_LANE":"m4"}'`
  `com.chibatakumi.film.lab.ios`.
  Fall-back:
  `DEVICECTL_CHILD_FILMTONE_SMOKE_LANE=m4 xcrun devicectl device process`
  `launch --device <udid> com.chibatakumi.film.lab.ios`.
  Confirm propagation via `[FilmtoneM4Smoke] starting` in m4-debug.log.
- [x] Pull diagnostics + master with
  `xcrun devicectl device copy from --device <udid>`
  `--source 'Library/Caches/Filmtone/captures/m4-combined-timing-smoke.json'`
  `--destination /tmp/filmtone-m4-pull/` (and `m4-debug.log`,
  `m4-master.mov`).
- [x] Copy small diagnostics (JSON + debug log only — **not** the .mov)
  into repo:
  `apps/capacitor-film-lab-ios/diagnostics/m4-combined-timing-smoke.json`
  `apps/capacitor-film-lab-ios/diagnostics/m4-debug.log`. The .mov stays
  in `/tmp/filmtone-m4-pull/` (size + binary).
- [x] Sanity check the env-var dispatcher worked: `m4-debug.log` contains
  `[FilmtoneM4Smoke] starting` with this launch's timestamp, and
  `m2b-debug.log` / `m3-debug.log` (if present from past launches) were
  **not** updated during this launch (compare mtime / last-line
  timestamp). Stale m2b/m3 artefact files in the container do not count
  as evidence of M2-B / M3 running this launch.
- [x] `git diff --check` clean.

### Done Conditions (from strategy.md)

- A 30 second `.mov` and combined diagnostics are produced.
- Motion samples cover the full video duration plus a small margin
  (gyro / accel `coverageSeconds >= 30.5`).
- First / last video PTS and first / last motion timestamps are present
  in the diagnostics JSON.
- Offset mapping is explicit enough to start `.gcsv` generation —
  i.e. `mapping.vdoPTSMinusGyroTSSeconds` and `vdoPTSMinusAccelTSSeconds`
  are present and finite.
- Diagnostics include the timestamp anchor needed to map video PTS and
  Core Motion timestamps — i.e. `anchor.machTimebaseNumer/Denom`,
  `anchor.startMachAbsolute`, `anchor.startBootUptimeSeconds` all
  present.

### Stop Conditions

- `AVCaptureMovieFileOutput` cannot start recording (e.g.
  `hardwareCost > 1.0` on this device — would contradict M2-B finding
  of `hardwareCost = 0.5`; escalate).
- VDO produces zero samples during the 30-second run (would contradict
  M2-B finding of 191 samples in 6 s; escalate).
- Either gyro or accel produces zero samples after `startGyroUpdates` /
  `startAccelerometerUpdates` (would contradict M3 finding of 1048
  samples in 10 s; escalate).
- `motion.gyro.intervals.maxGapSeconds > 0.5` or
  `motion.accel.intervals.maxGapSeconds > 0.5` while the AVCaptureSession
  is running — hard stop. M3 saw 0.0100s motion-only; gaps over 0.5s in
  combined mode would mean Core Motion is being starved by the capture
  pipeline and breaks Gyroflow mapping.
- 2 consecutive real-device verification failures.

Quality lines (not stop, but recorded in archive findings):

- Combined `motion.gyro.intervals.maxGapSeconds > 0.1` ⇒ note as
  "M5 mapping risk: moderate (capture-pipeline-induced motion gaps)".
- `vdo.intervals.maxGapSeconds > (2.0 / fps)` ⇒ note as "VDO frame
  drops observed during combined run; M5 should treat VDO PTS as
  side-band only and use MovieFile `startPTSSeconds` (from the iOS
  18.2+ `didStartRecordingTo:startPTS:from:` delegate) as the master
  timeline anchor".
- `abs(mapping.vdoPTSMinusGyroTSSeconds) > 1.0` ⇒ note as
  "host-time vs boot-uptime offset larger than expected; M5 must
  re-derive anchor before mapping".

### Out of Scope

- `.gcsv` generation (M5).
- Gyroflow import / sync proof (M5).
- Per-frame gyro lookup at capture time — M4 only records anchors and
  raw streams; M5 / Gyroflow does the per-frame mapping.
- Fused device-motion (`startDeviceMotionUpdates`) — explicitly not used
  for Gyroflow data per strategy.md M3 done condition.
- Capture preview UI / JS bridge surface / editor handoff (M6).
- Audio / `NSMicrophoneUsageDescription`.
- External SSD / security-scoped output.
- Device matrix beyond iPhone 17 Pro / iOS 26.4.x (owner device only;
  M7 covers broader trial).
- Refactoring `FilmtoneCaptureWriter` or `FilmtoneMotionRecorder` to
  share code — keeping M2-B / M3 archives reproducible matters more
  than DRY here. The duplicated minimum in
  `FilmtoneCombinedTimingSmoke.swift` is intentional.

## Verification Status

| Step | Status |
|---|---|
| `FilmtoneCombinedTimingSmoke.swift` written | ✅ done |
| pbxproj 4 entries added (grep -c == 4) | ✅ done |
| `AppDelegate.swift` `case "m4"` added to dispatcher | ✅ done |
| Simulator build | ✅ `BUILD SUCCEEDED` |
| Real-device signed Debug build | ✅ `BUILD SUCCEEDED` (iPhone 17 Pro UDID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`, derivedDataPath `/tmp/filmtone-m4-derived`) |
| Real-device run with `FILMTONE_SMOKE_LANE=m4` only | ✅ launched 2026-05-07 19:59:04 JST |
| Diagnostics + master pulled, JSON + log copied to repo | ✅ `apps/capacitor-film-lab-ios/diagnostics/m4-combined-timing-smoke.json` + `m4-debug.log` (m4-master.mov 2.48 GB held on device, NOT committed) |
| Sanity: m4 lane marker present + m2b/m3 logs not updated this launch | ✅ m4-debug.log mtime 19:59 / m2b-debug.log mtime 14:25 / m3-debug.log mtime 15:17 |
| `git diff --check` | ✅ clean |

## Real-Device Findings

iPhone 17 Pro (iPhone18,1, iOS 26.4.2). 30 s smoke. Result: PASS. Source artifacts: `apps/capacitor-film-lab-ios/diagnostics/m4-combined-timing-smoke.json`, `m4-debug.log`.

### Format pin (M2-B-validated `formats[56]`)

| Field | Value | Note |
|---|---|---|
| `video.format.formatIndex` | 56 | required |
| `video.format.dimensions` | [3840, 2160] | sensor native |
| `video.format.fps` | 30 | min == max == 30 |
| `video.format.colorSpace` | AppleLog2 (rawValue 4) | required |
| `video.format.pixelFormat` | x422 | 10-bit 4:2:2 BiPlanar Video Range |

`formats[56].supportedColorSpaces (raw) = 0,2,3,4` — appleLog2 (4) confirmed present at runtime.

### MovieFile master (Path C)

| Field | Value | Note |
|---|---|---|
| `video.writer.availableVideoCodecTypes` | `apch, apcn, apcs, apco` | connection-less property; `apch` = ProRes 422 HQ |
| `video.writer.codec` | `apch` | applied via `setOutputSettings([AVVideoCodecKey: .proRes422HQ], for: connection)` |
| `video.movieFile.didStart` | true | from `didStartRecordingTo:startPTS:from:` (iOS 18.2+) |
| `video.movieFile.didFinish` | true | |
| `video.movieFile.finishError` | null | no recording fatality |
| `video.movieFile.recordedDurationSeconds` | 30.567 | |
| `video.movieFile.movFileSizeBytes` | 2,477,204,843 (≈ 2.48 GB) | ≈ 660 Mbps avg |
| `video.movieFile.startPTSSeconds` | **139121.811448625** | finite — startPTS gate satisfied |
| `video.movieRotation.appliedAngle` | 90 | portrait orientation |
| `video.movieStabilization.applied` | off | per spec |

### VDO timing side-band

| Field | Value |
|---|---|
| `video.vdo.sampleCount` | 957 |
| `video.vdo.coverageSeconds` | 31.867 |
| `video.vdo.effectiveFps` | 29.999 |
| `video.vdo.firstPTSSeconds` | 139121.644778166 |
| `video.vdo.lastPTSSeconds` | 139153.51209087501 |
| `video.vdo.intervals.maxGapSeconds` | 0.0333 |
| `video.vdo.intervals.gapCountOver50ms / 100ms / 200ms` | 0 / 0 / 0 |
| `video.vdo.rotation.appliedAngle` | 90 |
| `video.vdo.stabilization.applied` | off |

### Core Motion (raw, fused DM never started)

| | Gyro | Accel |
|---|---|---|
| `requestedHz` | 200 | 200 |
| `effectiveHz` | 99.92 | 99.92 |
| `sampleCount` | 3183 | 3182 |
| `coverageSeconds` | 31.844 | 31.834 |
| `firstTS` | 139121.69283 | 139121.70284 |
| `lastTS` | 139153.5370 | 139153.5370 |
| `intervals.maxGapSeconds` | 0.0100 | 0.0100 |
| `intervals.gapCount > 50ms / 100ms / 200ms` | 0 / 0 / 0 | 0 / 0 / 0 |

`coreMotion.fusedDeviceMotionStarted = false` (raw streams only). `requestedHz = 200` but iOS 26.4 caps the rear-mounted IMU delivery rate at ~100 Hz; the cap is hardware-/OS-level, not a code defect — flagged for M5 to surface in `.gcsv` metadata.

### Anchor + clock unification

| Field | Value |
|---|---|
| `anchor.machTimebaseNumer/Denom` | 125 / 3 (≈ 41.67 ns / tick) |
| `anchor.startMachAbsolute` | 3338920485861 |
| `anchor.startBootUptimeSeconds` | 139121.68691195833 |
| `session.synchronizationClock` | `FigClock[HostTimeClock]: … current time: 139121.523607 seconds` |

`session.synchronizationClock` is `HostTimeClock` — same `mach_absolute_time` domain as `ProcessInfo.processInfo.systemUptime` and `CMLogItem.timestamp`. The triple-anchor (mach_absolute / systemUptime / mach_timebase) captured immediately after `session.startRunning()` returned matches the synchronizationClock current time within 164 ms of session start, consistent with `startRunning` returning before sample-flow stabilises. M5 can convert any of `vdo.firstPTSSeconds`, `movieFile.startPTSSeconds`, gyro `firstTS`, accel `firstTS` into the same axis without guessing.

### Mapping (M5 deliverable input)

| Field | Value (s) |
|---|---|
| `mapping.firstVdoPTSSeconds` | 139121.644778 |
| `mapping.firstGyroTSSeconds` | 139121.692833 |
| `mapping.firstAccelTSSeconds` | 139121.702840 |
| `mapping.vdoPTSMinusGyroTSSeconds` | **−0.04805** (VDO 48 ms ahead of gyro) |
| `mapping.vdoPTSMinusAccelTSSeconds` | **−0.05806** (VDO 58 ms ahead of accel) |
| `video.movieFile.startPTSSeconds` | 139121.811449 (+124 ms after anchor) |

All timestamps are on the same `HostTimeClock` / `mach_absolute_time` axis. The 48 / 58 ms offset is the VDO sample-flow lead over Core Motion (delegate plumbing + first IMU integration window) and is itself an M5 calibration constant, not noise. M5 can use either:

- `video.vdo.firstPTSSeconds` (frame-grain) — preferred for per-frame motion lookup, or
- `video.movieFile.startPTSSeconds` (ProRes I-frame anchor) — preferred for `.gcsv` master timeline anchor since this is what the .mov header records.

### Stop Conditions check

| Condition | Result |
|---|---|
| `smokeError` non-null → fail | `smokeError: null` ✅ |
| `video.format.formatIndex != 56` | 56 ✅ |
| `video.writer.codec != "apch"` | `apch` ✅ |
| `video.movieFile.didStart != true` or `didFinish != true` | both true ✅ |
| `video.movieFile.startPTSSeconds` non-finite | finite (139121.811449) ✅ |
| `video.vdo.sampleCount == 0` | 957 ✅ |
| `motion.gyro.sampleCount == 0` | 3183 ✅ |
| `motion.accel.sampleCount == 0` | 3182 ✅ |
| `coreMotion.fusedDeviceMotionStarted == true` | false ✅ |
| any of `gapCountOver100ms` non-zero | all 0 ✅ |
| `mapping.vdoPTSMinusGyroTSSeconds` non-finite | −0.04805 (finite) ✅ |

All Stop Conditions cleared. M4 PASS.

### Notes for follow-ups (not blocking M4)

- 200 Hz IMU not delivered (iOS 26.4 caps at ~100 Hz). M5 must record both `requestedHz` and `effectiveHz` in `.gcsv` metadata so downstream Gyroflow stabilisation knows the actual rate.
- VDO samples have rotation applied at the connection layer (`vdoFirstSampleDimensions = 2160 × 3840` in JSON; sensor native is 3840 × 2160 with `appliedAngle = 90`). M5 / `.gcsv` axis convention must be defined relative to the rotated buffer to match the .mov stream rather than sensor native.
- `hardwareCostAfterCommit = 0.5` confirms the dual-output session has comfortable headroom on iPhone 17 Pro for the M4 boundary; M5 staging on iPhone 15 Pro / 16 Pro should re-measure since those have lower budgets.
