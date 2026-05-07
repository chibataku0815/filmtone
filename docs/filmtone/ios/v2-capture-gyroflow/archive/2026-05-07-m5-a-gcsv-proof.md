# Active - M5-A `.gcsv` Writer + Package Emission

Date: 2026-05-07 JST

## Milestone

M5 - Gyroflow `.gcsv` Proof (sub-step **M5-A**: on-device writer +
package emission). M5-B / M5-C are deferred — see "Out of scope".

## Goal

Produce a Gyroflow-spec-conformant `.gcsv` sidecar from a real-device
combined-timing run on iPhone 17 Pro / iOS 26.4.x, packaged with the
ProRes 422 HQ Apple Log 2 master and combined-timing diagnostics, so
that M5-B (Gyroflow desktop validation) can begin from a concrete
artifact pulled off the device.

Specifically, on one 30-second smoke run:

- A `m5-master.mov` ProRes 422 HQ Apple Log 2 file is produced (M2-B /
  M4 path; same writer shape).
- Per-sample raw gyro and raw accelerometer arrays are captured —
  **timestamp + x/y/z per sample**, not just the aggregate counts /
  median / max-gap that M4 records.
- A `m5-motion.gcsv` file is written that conforms to the Gyroflow
  `.gcsv` v1.x format (header + rows). Header records the explicit
  decisions made about axis convention, timestamp basis, and units.
- A `m5-combined-timing.json` is written next to the `.gcsv` and
  records: gcsv path, gcsv row count, header bytes, row construction
  strategy (Phase 0.b), axis convention (Phase 0.c), timestamp basis
  (always motion-relative for M5-A), run-local sync offsets computed
  from this run's `movieFile.startPTSSeconds` / first VDO PTS / first
  gyro / first accel (NOT M4 offsets — those serve only as a
  baseline expected range), IMU effective Hz vs requested Hz (M4
  evidence: iOS 26.4 caps the 200 Hz request near 99.92 Hz on
  iPhone 17 Pro), and the M4 mapping offsets retained as
  `baselineExpectedRange` for cross-reference only.
- All three files live inside one package directory:
  `Library/Caches/Filmtone/captures/m5-package-<UUID>/{m5-master.mov,
  m5-motion.gcsv, m5-combined-timing.json}` — no scattered files.
- Offline gates pass: gcsv row count == per-sample array count, header
  parses, no NaN / Inf in any sample, timestamps strictly monotonic,
  master `startPTSSeconds` is finite (M4 gate, not regressed).

This M5-A lane writes the sidecar and proves it is structurally valid
on the device side. It does **not** prove Gyroflow desktop accepts it.

## Why split M5 (M5-A vs M5-B vs M5-C)

M5 strategy "Done" mixes two irreducibly different verification kinds:

1. **On-device writer truth (M5-A)**: gcsv format, per-sample arrays,
   timestamp basis, axis convention, package layout. Verifiable by
   Swift code + offline parser checks.
2. **Desktop tool integration (M5-B)**: "Gyroflow loads the video and
   sidecar", "basic sync / optical-flow check can align the clip",
   "one simple handheld pan stabilizes without obvious phase error".
   These require manual Gyroflow desktop interaction and visual
   judgment — not closeable by a Swift smoke run.
3. **Calibration (M5-C)**: rolling-shutter coefficient device-once
   metadata. Requires Gyroflow's RS calibration flow on a structured
   target — separate scope.

Splitting lets M5-A land as one 本質 deliverable (writer + format
conformance) without blocking on desktop tool wiring or RS calibration.
M5-B then begins from a concrete `.gcsv` artifact pulled off the
device, not from speculation about format. This matches CLAUDE.md §3
"本質優先 / 外殻最小".

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneGcsvSmoke.swift`
  (new) — single-class coordinator. **Forks from M4's
  `FilmtoneCombinedTimingSmoke.swift` rather than refactoring it**:
  M4 archive evidence (`f8e7db15`) is frozen; touching M4 risks
  invalidating the truth-script-checked PASS state. M5-A copies the
  M4 session / movie-file / VDO / motion-manager scaffolding, adds
  per-sample array capture, and adds the `.gcsv` writer + package
  finalize. Sole public entry: `static func runSmoke(duration:
  TimeInterval = 30.0, motionMargin: TimeInterval = 1.0, completion:
  @escaping (Result<SmokeResult, Error>) -> Void)`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneGcsvWriter.swift`
  (new, optional split) — pure function whose exact input/output
  signature **depends on the row construction policy decided in
  Phase 0** (see Phase 0 Step 0.b). Two stream arrays are not
  blindly fed in — the writer's input is what Phase 0 selects:
  either gyro-only rows, two separate gcsv files, or a single
  combined-on-gyro-timeline row set with explicit accel resampling
  metadata. No `AVFoundation` / `CoreMotion` imports — Foundation
  only — so it can be unit-tested via `scripts/swift/` standalone
  Swift later if needed.
- `apps/capacitor-film-lab-ios/ios/App/AppDelegate.swift`
  - Add `case "m5": runM5GcsvSmokeOnLaunch()` to
    `runFilmtoneSmokeIfRequested()` (1-case extension, not a refactor).
  - Add `runM5GcsvSmokeOnLaunch()` reachable only from the dispatcher.
    `[FilmtoneM5Smoke]` log prefix.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - Add 4 pbxproj entries per new Swift file: `PBXBuildFile`,
    `PBXFileReference`, group children, sources phase. Build IDs:
    `D20000010000000000000051` / ref `C20000010000000000000051`
    (FilmtoneGcsvSmoke), `D20000010000000000000052` / ref
    `C20000010000000000000052` (FilmtoneGcsvWriter). Same shape as
    M4 build ID `...0041` slot (M3 used `...0031`, M2-B `...0021`).
- `docs/filmtone/ios/v2-capture-gyroflow/active.md` (this file,
  progress).
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (only for the
  final M5-A Completion Log entry on archive — not edited until PASS).

Out of edit scope on this lane:

- `Info.plist` — no new keys (`NSCameraUsageDescription` and
  `NSMotionUsageDescription` already present from M2-B / M3).
- `FilmtoneCombinedTimingSmoke.swift` — read-only reference. Do not
  refactor; M4 archive truth depends on it.
- `FilmtoneCaptureWriter.swift`, `FilmtoneMotionRecorder.swift`,
  `FilmtoneCaptureCapabilityProbe.swift` — read-only reference.
- Capture UI, JS bridge, `packages/film-lab-*`.

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (M5 spec lines
  129-146; M4 Completion Log lines 272-281 for clock-axis evidence).
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m4-combined-timing-smoke.md`
  (M4 archive — full Real-Device Findings, anchor scheme, mapping
  offsets, IMU 99.92 Hz cap).
- `apps/capacitor-film-lab-ios/diagnostics/m4-combined-timing-smoke.json`
  (M4 evidence — to cross-reference per-sample arrays produced by
  M5-A against M4 aggregates).
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCombinedTimingSmoke.swift`
  (M4 implementation — fork base for M5-A scaffolding).
- Gyroflow `.gcsv` format reference (Phase 0 task: research and pin
  exact spec — see Implementation Outline Phase 0 below).

## Phase 0 Format Pin / Decisions

Status: completed 2026-05-07 JST. Implementation is still not started.

Primary sources pinned:

- Gyroflow app HEAD:
  `gyroflow/gyroflow@2f7a22a2ac593cbe750504b7adef6fb54c5b27fe`
  - `src/core/gyro_source/mod.rs`
  - `Cargo.lock`
- Gyroflow parser dependency from that lockfile:
  `AdrianEddy/telemetry-parser@2f4218ba2b85e0e3c6e009932cdbdd6c2ee2e382`
  - `src/gyroflow/gcsv.rs`
  - `src/util.rs`
- Official format docs:
  `gyroflow/docs.gyroflow.xyz@e24243308d5a160a6c5abf3b55c3d015c5778b9d`
  - `technical-details/gcsv-format.md`

Source findings:

- Gyroflow itself delegates `.gcsv` parsing through
  `telemetry-parser`; the locked Gyroflow `Cargo.lock` pins
  `telemetry-parser` to commit `2f4218b...`.
- `telemetry-parser/src/gyroflow/gcsv.rs` detects either
  `GYROFLOW IMU LOG` or `CAMERA IMU LOG`, parses comma-separated
  header rows until the `t` / `time` data header, accepts flexible CSV
  rows, and reads `tscale`, `gscale`, `ascale`, `orientation`,
  optional `lensprofile`, and rolling-shutter metadata.
- The official docs define `.gcsv` version `1.3`; required data
  headers are one of `t,gx,gy,gz`, `t,gx,gy,gz,ax,ay,az`, or
  `t,gx,gy,gz,ax,ay,az,mx,my,mz`. Gyro is minimum; accel is required
  for horizon lock.
- `t * tscale` is seconds. `gx/gy/gz * gscale` is rad/s.
  `ax/ay/az * ascale` is g. Floating-point sample values are valid.
- `telemetry-parser/src/util.rs` builds normalized IMU rows on the
  gyro timestamp set and interpolates accel/mag at each gyro
  timestamp. That matches Strategy C.

M5-A locked decisions:

- Header:
  - first line: `GYROFLOW IMU LOG`
  - `version,1.3`
  - `id,filmtone_ios_m5`
  - `vendor,filmtone`
  - `videofilename,m5-master.mov`
  - `tscale,0.000001`
  - `gscale,1.0`
  - `ascale,1.0`
  - data header: `t,gx,gy,gz,ax,ay,az`
- Data rows:
  - `t` is an integer microsecond timestamp relative to first gyro
    sample: `round((gyro.timestamp - firstGyro.timestamp) * 1_000_000)`.
  - gyro values are written as floating-point rad/s directly from
    `CMGyroData.rotationRate` (`gscale = 1.0`).
  - accel values are written as floating-point g directly from
    `CMAccelerometerData.acceleration` after interpolation onto the
    gyro timeline (`ascale = 1.0`).
- Row construction strategy: **Strategy C, combined on gyro timeline**.
  A single `m5-motion.gcsv` preserves accel for horizon-lock-quality
  downstream stabilization while matching the parser's gyro-timestamp
  interpolation model.
- Resampling policy for Strategy C (revised 2026-05-07 after first
  real-device run):
  - **Common IMU coverage window first**: gcsv emits rows only for
    gyro samples whose timestamps fall inside `[accel.first.t,
    accel.last.t]`. Gyro samples outside this window are tracked as
    boundary trim — `accelOutOfRangeStartCount` (gyro before accel
    starts) / `accelOutOfRangeEndCount` (gyro after accel ends) /
    `accelOutOfRangeTotalCount` — and are NOT counted as drops.
    This handles the structural fact that gyro and accel are two
    independent CoreMotion streams that do not start or stop at the
    same nanosecond. The first M5-A device run produced a 5.004ms
    `accel.last.t` vs `gyro.last.t` gap; the prior policy mis-classified
    that single gyro tail sample as a drop and failed an otherwise
    healthy run.
  - **Inside the common window**: linearly interpolate accel at each
    gyro timestamp when the gyro timestamp is bracketed by accel
    samples; if the nearest accel sample is more than the tolerance
    away, count as `accelDroppedRowCount` (in-range drop).
  - tolerance: `accelResamplingToleranceSeconds = 0.010`.
  - record `accelToGyroMaxDeltaSeconds`,
    `accelToGyroMedianDeltaSeconds`, `accelDroppedRowCount`,
    `accelInterpolatedRowCount`, `accelExactRowCount`,
    `accelOutOfRangeStartCount`, `accelOutOfRangeEndCount`,
    `accelOutOfRangeTotalCount`, `gyroAccelTrimDurationStartSeconds`,
    `gyroAccelTrimDurationEndSeconds`,
    `gyroAccelTrimDurationTotalSeconds`,
    `gyroAccelTrimDurationLimitSeconds`,
    `gyroAccelTrimDurationWithinLimit`, and
    `gyroMedianIntervalSeconds`.
  - **Stop Conditions** (Strategy C):
    - `accelDroppedRowCount` must be `0` for PASS.
    - `gyroAccelTrimDurationTotalSeconds` must be `<=
      gyroAccelTrimDurationLimitSeconds` (= `max(1.5 *
      gyroMedianIntervalSeconds, 0.020)`). A larger trim indicates a
      stream-start or stream-stop race significantly worse than a
      single sample interval and is fatal.
  - **Reconciliation under PASS**: `gcsv.rowCount ==
    gyroSampleCount - accelOutOfRangeTotalCount`. General form:
    `gcsv.rowCount == gyroSampleCount - accelOutOfRangeTotalCount -
    accelDroppedRowCount`.
- Axis convention: `.gcsv` emits Core Motion raw sensor-frame values
  with a required `orientation` header. Phase 0 confirms `.gcsv` uses
  orientation metadata rather than requiring image-frame pre-rotation.
  M5-A will write the sensor-native sidecar and preserve the raw
  sensor arrays in JSON. M5-B validates the exact visual axis
  agreement in Gyroflow and may adjust the orientation string/remap if
  desktop evidence proves it wrong.
- Comment syntax: do not emit comment rows. The parser accepts metadata
  key/value rows and skips one-field rows, but the docs do not define a
  comment convention; keep the file plain CSV.

## Implementation Outline (high-level — no code yet)

**Phase 0 — Format research + decision lock (gate before any code)**:

0.a. Pin the Gyroflow `.gcsv` v1.x format spec from
   `https://github.com/gyroflow/gyroflow` source (`src/core/gyro_source.rs`
   gcsv parser) or official docs. Capture: header field set, separator,
   timestamp unit (s vs ms vs μs), axis order, units (rad/s vs deg/s for
   gyro; m/s² vs g for accel), required vs optional fields, comment
   syntax. Record the pinned spec citation (commit SHA + file path)
   in this active.md before any other Phase 0 step. **Do not paraphrase
   from memory** (CLAUDE.md §3 — `feedback_no_guessing_davinci_plugins`
   / `feedback_verify_before_documenting` analog).

0.b. **Row construction policy** — gyro and accel are two streams from
   `CMMotionManager` running on different sensors. M4 evidence shows
   they are not 1:1 row-aligned: M4 produced 3183 gyro samples vs 3182
   accel samples (off by one even on a single 30s run on iPhone 17 Pro
   / iOS 26.4.2; 99.92 Hz effective on both, but rate-decoupled on
   their own clocks). One gcsv "row" has one timestamp — Phase 0 must
   pick **how** that row is constructed. Three candidate strategies
   to evaluate against the Phase 0.a spec:
   - **Strategy A (gyro-only)** — write only gyro samples; accel goes
     into `m5-combined-timing.json` as a parallel per-sample array
     but is not part of the `.gcsv`. Acceptable if Gyroflow accepts
     gyro-only sidecars (likely yes — that is the historic GCSV use).
   - **Strategy B (two files)** — emit `m5-motion-gyro.gcsv` and
     `m5-motion-accel.gcsv` as separate sidecars. Acceptable if
     Gyroflow accepts split files; doubles the package surface.
   - **Strategy C (combined on gyro timeline)** — gyro timestamps
     define rows; for each gyro row, accel x/y/z is resolved by
     nearest-neighbor or linear-interpolation from the accel array.
     Required if Gyroflow's combined sidecar expects co-timed rows.
   Phase 0 picks one strategy based on the Gyroflow spec and records
   the choice + rationale in this active.md. If Strategy C is chosen,
   the resampler must also record `accelToGyroMaxDeltaSeconds`,
   `accelToGyroMedianDeltaSeconds`, `accelDroppedRowCount` (gyro rows
   that had no accel sample within tolerance), and
   `accelInterpolatedRowCount` in `m5-combined-timing.json`, so M5-B
   can judge resampling quality. Default tolerance: ±10 ms (one
   nominal IMU sample at 100 Hz) — confirmed or adjusted based on
   Phase 0 spec.

0.c. **Axis convention research + final lock** — Phase 0 must read
   Gyroflow's orientation / camera-profile semantics from the same
   source pin as 0.a and final-lock which axis frame the `.gcsv`
   ships in. Two possible outcomes:
   - **(i) Gyroflow expects sensor-frame gcsv** (sensor-native) and
     applies the camera profile separately. M5-A `.gcsv` emits raw
     `CMGyroData.rotationRate` / `CMAccelerometerData.acceleration`
     unchanged. The remap matrix from sensor frame to the `.mov`'s
     movieRotation-90° portrait frame is recorded in the diagnostics
     JSON for cross-reference but not applied to gcsv rows.
   - **(ii) Gyroflow expects image-frame gcsv** (already rotated to
     match the `.mov`'s portrait orientation). M5-A `.gcsv` MUST
     apply the rotation-90° axis remap to every row before writing,
     because Goal requires "Gyroflow-spec-conformant `.gcsv`" — an
     unremapped sidecar in case (ii) would be a knowingly-wrong
     artifact and M5-B would be validating against a broken input.
     Raw sensor-native samples are still preserved in the
     diagnostics JSON (`motion.rawSensorFrame.gyro` /
     `motion.rawSensorFrame.accel`) for traceability and for any
     future need to re-derive the gcsv with a different remap; the
     applied remap matrix is recorded under `gcsv.appliedRemapMatrix`.
   The Phase 0 source pin tells us which case applies. M5-A picks
   exactly one and ships only that convention in the `.gcsv`.
   Working hypothesis (case (i), sensor-native) is **not authoritative**
   — Phase 0 evidence overrides it. The choice and rationale are
   pinned in this active.md before Phase 1.

**Phase 1 — Per-sample capture in `FilmtoneGcsvSmoke.swift`**:

3. Fork M4's session config, anchor capture, and motion-manager startup.
4. Replace M4's aggregate-only motion snapshot with:
   `struct MotionSample { let timestampSeconds: TimeInterval; let x:
   Double; let y: Double; let z: Double }` arrays for both streams.
5. Preserve M4's `AVCaptureMovieFileOutput` + VDO timing side-band
   wiring unchanged.
6. Preserve M4's startPTS gate and the two-phase `resolvedError`
   logic (recordingFatalError vs stream / anchor checks) — these were
   the P1 / P2 fixes from M4 review and must not regress in M5.

**Phase 2 — `.gcsv` writer + package finalize**:

7. Implement `FilmtoneGcsvWriter` as a pure-Foundation function (no
   `AVFoundation` / `CoreMotion` imports) so the writer is testable
   in isolation.
8. Apply the Phase 0 decisions and **document them inline in the
   gcsv header AND mirror them in the diagnostics JSON** (so M5-B
   can verify or adjust if Gyroflow desktop disagrees):
   - **gcsv internal time axis — motion-relative**: row timestamps
     start at zero. For Strategy A (gyro-only) or Strategy C
     (combined-on-gyro-timeline), the basis is
     `t_gcsv = gyro_cmlog_ts - first_gyro_cmlog_ts`. For Strategy B
     (two files), each file uses its own first-sample as zero. This
     is **motion-relative**, not PTS-relative — gcsv internal time
     does not encode the offset to `.mov` PTS. The PTS↔motion sync
     is communicated via a separate run-local offset (Step 9 below).
   - **Axis convention**: applied per Phase 0 Step 0.c decision
     (sensor-native by working hypothesis, but Phase 0 final-locks).
   - **Units**: applied per Phase 0 Step 0.a decision.
9. Compute and store **run-local sync offsets** in
   `m5-combined-timing.json` — these are the seeds M5-B feeds into
   Gyroflow's sync slider. **All four are computed from this M5 run's
   own anchor; M4 offsets must NOT be used as seeds.** M4 numbers
   serve only as a baseline expected range for sanity (Step 11).
   - `runLocalMovieStartToGyroOffsetSeconds = movieFile.startPTSSeconds
     - first_gyro_cmlog_ts` (primary Gyroflow sync seed — aligns the
     `.mov` recording start to the gyro time axis used inside gcsv).
   - `runLocalMovieStartToAccelOffsetSeconds = movieFile.startPTSSeconds
     - first_accel_cmlog_ts`.
   - `runLocalVdoFirstPtsToGyroOffsetSeconds = first_vdo_pts -
     first_gyro_cmlog_ts` (preserved for M4-cross-reference; this is
     the M4-style metric).
   - `runLocalVdoFirstPtsToAccelOffsetSeconds = first_vdo_pts -
     first_accel_cmlog_ts`.
   `firstVdoPTSSeconds`, `firstGyroCmLogTimestampSeconds`,
   `firstAccelCmLogTimestampSeconds`, and `movieStartPTSSeconds` are
   all stored alongside the offsets so M5-B can re-derive without
   trusting the offset arithmetic.
10. Emit package directory atomically: write to a temp folder, then
    rename into final `m5-package-<UUID>/` once all three files exist.
11. **M4 offsets — baseline range only, not seeds**. M4 measured
    `vdoPTSMinusGyroTSSeconds = -48.05ms` and
    `vdoPTSMinusAccelTSSeconds = -58.06ms` on iPhone 17 Pro / iOS
    26.4.2. M5-A records these in
    `m5-combined-timing.json.baselineExpectedRange` (clearly tagged
    "M4 reference, not this run") so the offline gate in Phase 4 can
    flag this run's `runLocalVdoFirstPtsToGyroOffsetSeconds` if it
    drifts outside `±200ms` (M4 gate transfer — see Stop Conditions).
    The seeds passed to M5-B are always this run's run-local values.

**Phase 3 — Diagnostics**:

12. `m5-combined-timing.json` extends the M4 schema with (in addition
    to the run-local sync offsets from Step 9 and the
    `baselineExpectedRange` from Step 11):
    - `gcsv.path`, `gcsv.rowCount`, `gcsv.headerBytes`,
      `gcsv.rowConstructionStrategy` (A / B / C from Phase 0 Step 0.b),
      `gcsv.axisConvention`, `gcsv.timestampBasis` (always
      `"motion-relative"` for M5-A), `gcsv.gyroUnit`, `gcsv.accelUnit`,
      `gcsv.imuRequestedHz`, `gcsv.imuEffectiveHz`.
    - For Strategy C only: `gcsv.accelToGyroMaxDeltaSeconds`,
      `gcsv.accelToGyroMedianDeltaSeconds`, `gcsv.accelDroppedRowCount`
      (in-range only), `gcsv.accelInterpolatedRowCount`,
      `gcsv.accelExactRowCount`,
      `gcsv.accelOutOfRangeStartCount`,
      `gcsv.accelOutOfRangeEndCount`,
      `gcsv.accelOutOfRangeTotalCount`,
      `gcsv.gyroAccelTrimDurationStartSeconds`,
      `gcsv.gyroAccelTrimDurationEndSeconds`,
      `gcsv.gyroAccelTrimDurationTotalSeconds`,
      `gcsv.gyroAccelTrimDurationLimitSeconds`,
      `gcsv.gyroAccelTrimDurationWithinLimit`,
      `gcsv.gyroMedianIntervalSeconds`,
      `gcsv.accelResamplingToleranceSeconds`.
    - `package.directoryPath`, `package.movFileSizeBytes`,
      `package.gcsvFileSizeBytes` (or `package.gcsvFiles` array if
      Strategy B).
    - All M4 fields preserved unchanged for cross-check.

**Phase 4 — Real-device run + offline gates**:

13. **Build path matches M4** (no Capacitor sync — this lane only
    edits Swift / pbxproj; `bun cap sync ios` is intentionally
    skipped, same as M4 archive notes). Two-stage `xcodebuild`:
    - Simulator gate first:
      `xcodebuild -workspace App.xcworkspace -scheme App -configuration
      Debug -sdk iphonesimulator -destination 'generic/platform=iOS
      Simulator' build CODE_SIGNING_ALLOWED=NO` → must succeed before
      device build.
    - Real-device signed build:
      `xcodebuild -workspace App.xcworkspace -scheme App -configuration
      Debug -sdk iphoneos -destination 'generic/platform=iOS' build
      -derivedDataPath /tmp/filmtone-m5-derived
      -allowProvisioningUpdates`.
14. Install + launch via `devicectl` (M4 pattern, exclusive env-var
    dispatcher):
    - `xcrun devicectl device install app --device <udid>
      …App.app`.
    - Primary launch:
      `xcrun devicectl device process launch --device <udid>
      --environment-variables '{"FILMTONE_SMOKE_LANE":"m5"}'
      com.chibatakumi.film.lab.ios`.
    - Fall-back form (if env-var JSON gets stripped):
      `DEVICECTL_CHILD_FILMTONE_SMOKE_LANE=m5 xcrun devicectl device
      process launch --device <udid> com.chibatakumi.film.lab.ios`.
    - Confirm propagation by tailing `[FilmtoneM5Smoke]` lines in the
      device-side debug log.
15. Wait the run duration, pull the package directory via
    `xcrun devicectl device copy from --device <udid>
    --source 'Library/Caches/Filmtone/captures/m5-package-<UUID>/'
    --destination /tmp/filmtone-m5-pull/ --domain-type
    appDataContainer`.
16. Run offline gate script (Swift standalone in `scripts/swift/` if
    needed) that parses the `.gcsv` and checks:
    - rowCount in `m5-combined-timing.json` matches actual gcsv
      data row count (per file if Strategy B).
    - Header parses; required Gyroflow fields per Phase 0.a present.
    - All x/y/z values are finite.
    - Timestamps strictly monotonic, no duplicates.
    - First timestamp == 0 (motion-relative basis), last timestamp ≈
      gyro `coverageSeconds`.
    - Master `startPTSSeconds` finite (M4 gate not regressed).
    - This run's `runLocalVdoFirstPtsToGyroOffsetSeconds` within
      `±200ms` of M4 baseline (`-48.05ms`); same for accel against
      `-58.06ms`. Drift outside this means the anchor scheme regressed.
    - For Strategy C: `gcsv.accelToGyroMaxDeltaSeconds <=
      accelResamplingToleranceSeconds` (otherwise resampling failed
      and the row policy must be re-evaluated).

**Phase 5 — Lane-internal review + archive proposal**:

17. Stop and post Real-Device Findings here. **Do not auto-archive**
    — wait for user review (the M4 lane proved this gate matters; P1
    / P2 / P3 were caught at this step).

## Stop Conditions (smoke must fail)

- Per-sample gyro array empty when M4-aggregate equivalent count > 0.
- Per-sample accel array empty when M4-aggregate equivalent count > 0.
- `.gcsv` data row count ≠ count expected from row construction
  policy: for Strategy A, must equal gyro per-sample count; for
  Strategy B, each file must equal its respective stream's count;
  for Strategy C (post-2026-05-07 revision), `gcsv.rowCount ==
  gyroSampleCount - accelOutOfRangeTotalCount - accelDroppedRowCount`,
  and the per-row classification must reconcile (`gyroSampleCount ==
  accelExactRowCount + accelInterpolatedRowCount +
  accelDroppedRowCount + accelOutOfRangeTotalCount`).
- `.gcsv` header missing any required Gyroflow field (Phase 0.a
  spec) or row construction strategy not recorded in header/JSON.
- Any sample x / y / z is NaN or Inf.
- Sample timestamps non-monotonic (i.e., `t[i+1] <= t[i]` for any i).
- For Strategy C: `accelDroppedRowCount > 0` (any in-range gyro row
  whose nearest accel sample exceeded `accelResamplingToleranceSeconds`).
  Boundary `accelOutOfRange*Count` rows do **not** trigger this — they
  are tracked separately and gated by the trim-duration limit.
- For Strategy C: `gyroAccelTrimDurationWithinLimit == false`, i.e.,
  `gyroAccelTrimDurationTotalSeconds > max(1.5 *
  gyroMedianIntervalSeconds, 0.020)`. Indicates a gyro/accel stream
  start-or-stop race significantly worse than a single sample
  interval — anchor scheme or motion-handler queue likely regressed.
- `m5-master.mov` `startPTSSeconds` missing or non-finite — M4 gate
  must not regress.
- This run's `runLocalVdoFirstPtsToGyroOffsetSeconds` /
  `runLocalVdoFirstPtsToAccelOffsetSeconds` (Step 9, computed from
  THIS run, not M4) drift outside `±200ms` of the M4 baseline range
  (M4 saw -48ms / -58ms; an order-of-magnitude worse number on
  this run means the anchor scheme regressed). Note: M4 numbers are
  the **acceptance range**, not the seed — the seed for M5-B is
  always this run's run-local value.
- Package directory is missing any of the three files (or file set
  per row strategy) at finalize time.
- Axis convention, timestamp basis, or row construction strategy
  not recorded in either gcsv header or diagnostics JSON.
- Run-local sync offsets (Step 9) missing or any of the four
  underlying first-* anchor values not stored alongside.

## Out of scope (deferred)

**M5-B — Gyroflow desktop validation** (separate active after M5-A
PASS):

- Gyroflow loads `m5-master.mov + m5-motion.gcsv`.
- Sync / optical-flow alignment seeded from M5-A's run-local sync
  offsets (Step 9) — M4 offsets are baseline range only, not seeds.
- Single handheld pan stabilizes without obvious phase error.
- Verify axis convention assumption from M5-A (or correct it).

**M5-C — Rolling-shutter coefficient** (separate active after M5-B):

- Capture structured target.
- Run Gyroflow's RS calibration flow.
- Record RS coefficient as device-once package metadata.

**Post-M5 deferred entirely**:

- IMU bias / temperature drift compensation.
- Owner clip workflow polish (M6).
- Editor handoff (M6).
- Multi-device coverage (M7).

## Verification Status

- [x] Phase 0.a — Gyroflow `.gcsv` format spec pinned (commit SHA
      + file path citation, header field set, units, separator).
- [x] Phase 0.b — Row construction strategy decided (A / B / C),
      rationale recorded, resampling tolerance set if Strategy C.
- [x] Phase 0.c — Axis convention final-locked against pinned
      Gyroflow orientation / camera-profile semantics.
- [x] Phase 1 — `FilmtoneGcsvSmoke.swift` per-sample capture
      compiles; M4 startPTS gate + two-phase resolvedError logic
      preserved verbatim.
- [x] Phase 2 — `FilmtoneGcsvWriter` writes valid gcsv per Phase 0
      decisions; run-local sync offsets stored in diagnostics JSON
      (Step 9); M4 baseline range stored separately (Step 11).
- [x] Phase 3 — Extended diagnostics JSON schema written
      (run-local offsets, baselineExpectedRange, Strategy-C resampling
      metrics if applicable).
- [x] Phase 4 — Two-stage `xcodebuild` (simulator gate + device
      signed) succeeds; `bun cap sync ios` correctly skipped per M4
      pattern. Both stages PASS (2026-05-07 JST). `public/`,
      `config.xml`, `capacitor.config.json` were copied verbatim from
      the M4 worktree (one-time setup; not produced by `cap sync` in
      this lane).
- [x] Phase 4 — Real-device run on iPhone 17 Pro / iOS 26.4.x
      produces `m5-package-<UUID>/{mov, gcsv, json}` (Run #2,
      `m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f/`).
- [x] Phase 4 — Offline gates pass: rowCount (3188 = 3189 − 1 − 0),
      monotonicity, finite, header parse (166 B), M4 startPTS gate
      not regressed (`startPTSSeconds = 143361.71016770799`), run-local
      VDO↔gyro/accel offsets within ±200ms of M4 baseline (Δ=23.2ms /
      28.2ms), Strategy C resampling: `accelDroppedRowCount = 0` and
      `gyroAccelTrimDurationWithinLimit = true` (5.003ms ≤ 20ms).
- [x] Phase 5 — Real-Device Findings posted here for user review.

## Real-Device Findings

### Run #1 (2026-05-07 21:01 JST) — pre-trim writer, FAIL by Stop
### Condition (1 boundary drop / 3191 rows)

iPhone 17 Pro / iOS 26.4.2, package
`m5-package-d769a4c8-d8e5-4541-8c1d-27e4958a9f9f/`.

Substantive gates PASSed:

- ProRes 422 HQ Apple Log 2 master 30.567s / 2.6 GB / `apch` / x422 /
  3840x2160 / 30 fps.
- `movieFile.startPTSSeconds = 142858.661408541` (finite — M4 P1 gate
  not regressed).
- VDO 959 samples / 29.999 fps / 0 gaps over 50 / 100 / 200ms.
- gyro 3191 / accel 3191 / both 99.93 Hz / 0 gaps over 50 / 100 / 200ms.
- gcsv structurally valid: header 166 B / 3190 rows / monotonic /
  finite / written.
- M4 baseline drift gate (±200ms): `vdoFirstPtsToGyroOffsetSeconds =
  -37.58ms` vs M4 -48.05ms (Δ=10.5ms) — within tolerance;
  `vdoFirstPtsToAccelOffsetSeconds = -37.58ms` vs M4 -58.06ms
  (Δ=20.5ms) — within tolerance.

FAILed by the pre-revision Stop Condition:

- `accelDroppedRowCount = 1` of 3191 (0.03%). Root cause:
  `gyro.last.t - accel.last.t = +5.004ms`. The single tail gyro
  sample fell outside the accel range and was classified as a drop.
  In-range `accelToGyroMaxDeltaSeconds = 5.003ms` — well within
  the 10ms tolerance. The drop was a **boundary effect**, not a
  resampling tolerance failure.

This produced the 2026-05-07 writer revision: separate boundary trim
(`accelOutOfRange*Count` / `gyroAccelTrimDuration*`) from in-range
drops (`accelDroppedRowCount`). Run #2 verifies the revised writer.

### Run #2 (2026-05-07 21:09 JST) — boundary-trim writer revision, PASS

iPhone 17 Pro / iOS 26.4.2, package
`m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f/`. `smokeError: null`.

Stop Conditions PASSed:

- `accelDroppedRowCount = 0` (in-range tolerance gate satisfied).
- `gyroAccelTrimDurationTotalSeconds = 5.003ms ≤ 20ms = limit
  (max(1.5 × 10.007ms, 20ms))` → `gyroAccelTrimDurationWithinLimit:
  true`.
- Reconciliation: `exactRow 3170 + interpRow 18 + droppedRow 0 +
  outOfRangeTotal 1 = 3189 = gyroSampleCount`. `gcsv.rowCount = 3188
  = gyroSampleCount - outOfRangeTotal - droppedRow`.

Substantive gates PASSed:

- ProRes 422 HQ Apple Log 2 master 30.567s / 2.7 GB / `apch` / x422 /
  3840x2160 / 30 fps. `movieFile.startPTSSeconds = 143361.71016770799`
  (finite — M4 P1 gate not regressed).
- VDO 958 samples / 29.999 fps / 0 gaps over 50 / 100 / 200ms.
- gyro 3189 / accel 3189 / both 99.93 Hz / 0 gaps over 50 / 100 / 200ms.
- gcsv structurally valid: header 166 B / 3188 rows / monotonic /
  finite / written.
- M4 baseline drift gate (±200ms): `runLocalVdoFirstPtsToGyroOffsetSeconds
  = -24.86ms` vs M4 -48.05ms (Δ=23.2ms) — within;
  `runLocalVdoFirstPtsToAccelOffsetSeconds = -29.86ms` vs M4 -58.06ms
  (Δ=28.2ms) — within.

Run-local sync seeds for M5-B:

- `runLocalMovieStartToGyroOffsetSeconds = +141.81ms` (PRIMARY M5-B
  Gyroflow sync seed — `movieFile.startPTSSeconds - first_gyro_cmlog_ts`).
- `runLocalMovieStartToAccelOffsetSeconds = +136.81ms`.
- `runLocalVdoFirstPtsToGyroOffsetSeconds = -24.86ms` (M4-style
  cross-reference).
- `runLocalVdoFirstPtsToAccelOffsetSeconds = -29.86ms`.

Strategy C resampling quality observations:

- `accelExactRowCount / inRangeCount = 3170 / 3188 = 99.4%` — gyro and
  accel CoreMotion timestamps coincide on the same handler scheduling
  cadence, so the vast majority of rows match exactly (delta = 0).
- `accelToGyroMaxDeltaSeconds = 5.003ms` (well within 10ms tolerance).
  `accelToGyroMedianDeltaSeconds = 0` reflects the exact-match cadence.
- `gyroMedianIntervalSeconds = 10.007ms`; `imuEffectiveHz = 99.93Hz`
  vs `imuRequestedHz = 200Hz` — iOS 26.4 IMU cap reproduced from M4.
- Boundary trim (5.003ms) is the start trim — gyro started ~5ms before
  accel. Same magnitude as Run #1's end trim, confirming the
  start/stop race is symmetric and well within the 20ms gate.

## Notes / Follow-ups

- **M4 mapping offset signs**: M4 measured `vdoPTSMinusGyroTSSeconds
  = -48.05ms` / `vdoPTSMinusAccelTSSeconds = -58.06ms`. Both are
  negative, meaning VDO first PTS is *before* first motion sample.
  **M4 offsets are baseline expected range only — they are NOT the
  M5-B seed**. The M5-B sync seed is always THIS M5 run's
  `runLocalMovieStartToGyroOffsetSeconds` (primary) /
  `runLocalMovieStartToAccelOffsetSeconds` /
  `runLocalVdoFirstPtsToGyroOffsetSeconds` /
  `runLocalVdoFirstPtsToAccelOffsetSeconds` from Phase 2 Step 9,
  computed against this run's own `movieFile.startPTSSeconds` /
  `first_vdo_pts` / `first_gyro_cmlog_ts` / `first_accel_cmlog_ts`.
  M4 offsets only feed the `±200ms` drift gate in the offline check
  (Phase 4 Step 16, Stop Conditions).
- **IMU 99.92 Hz cap**: 200 Hz request silently capped at ~100 Hz on
  iOS 26.4 / iPhone 17 Pro (M4 evidence). M5-A's gcsv must record
  both `requestedHz` (200) and `effectiveHz` (computed from sample
  count / coverage) so M5-B / Gyroflow can use the actual rate, not
  the requested one. Header field name pinned in Phase 0.a.
- **Rotation convention**: M4 `vdoFirstSampleDimensions = 2160x3840`
  (width x height) vs format `dimensions = 3840x2160` confirms
  rotation 90° applied at the connection layer. Phase 0 pinned
  Gyroflow `.gcsv` as an IMU log with explicit `orientation`
  metadata, not an image-frame pre-rotated stream. M5-A therefore
  emits Core Motion sensor-frame values in `.gcsv` and records the
  sensor-to-portrait remap matrix in JSON for traceability / M5-B
  visual validation.
- **Branching**: this lane is `feature/ios-v2-capture-m5-gcsv-proof`
  off M4 tip `f8e7db15`. Lives in worktree
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-worktrees/ios-v2-m5-gcsv-proof/`.

## Implementation Status

Phase 0 is complete and recorded above. Implementation can proceed
inside this active scope in this order: `FilmtoneGcsvWriter.swift` →
`FilmtoneGcsvSmoke.swift` fork from M4 → pbxproj entries →
`AppDelegate.swift` dispatcher case → simulator/device verification.

**2026-05-07 JST update**: Phase 1 / 2 / 3 / 4 / 5 all landed inside
this worktree (`feature/ios-v2-capture-m5-gcsv-proof`), uncommitted.
Files added: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneGcsvWriter.swift`
(pure Foundation Strategy C resampler + boundary-trim writer),
`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneGcsvSmoke.swift`
(M4 fork + `m5-package-<UUID>/` staging→rename + run-local offsets),
`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
(4 entries × 2 files at IDs `…0051` / `…0052`),
`apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
(`case "m5"` + `runM5GcsvSmokeOnLaunch()`). Real-device Run #1
(pre-revision) FAIL by Stop Condition produced the boundary-trim
writer revision; Run #2 (post-revision) PASS — see Real-Device
Findings. Run #2 small artifacts copied to
`apps/capacitor-film-lab-ios/diagnostics/m5-combined-timing.json /
m5-motion.gcsv / m5-debug.log` (the 2.7 GB `.mov` master is
intentionally excluded — same evidence-fixing convention as M1-M4).

Next: user review of Run #2 PASS findings → archive this active.md
into `archive/2026-05-07-m5-a-gcsv-proof.md` → strategy.md
Completion Log entry → commit on
`feature/ios-v2-capture-m5-gcsv-proof`. M5-B (Gyroflow desktop
validation) and M5-C (RS calibration) are deferred to separate
active.md scopes.
