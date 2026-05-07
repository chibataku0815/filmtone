# Active - M5-B Gyroflow Desktop Validation

Date: 2026-05-07 JST

## Milestone

M5 - Gyroflow `.gcsv` Proof (sub-step **M5-B**: desktop load / sync /
stabilization validation). M5-A is complete at `d0e847e1`; M5-C
rolling-shutter calibration remains deferred.

## Goal

Prove that the M5-A package is not only structurally valid, but usable
inside Gyroflow desktop:

- Gyroflow loads the ProRes Apple Log 2 master and `m5-motion.gcsv`.
- The M5-A run-local sync seed aligns the gyro track without a new
  manual guess per clip.
- Gyroflow can produce one basic stabilized result for the owner-style
  handheld pan without obvious phase error, axis inversion, or timing
  drift.

This is the first user-facing Gyroflow proof. It does not change the
iOS writer unless the desktop result exposes a concrete artifact defect.

## Inputs

Primary M5-A package:

```text
/tmp/filmtone-m5-pull2/m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f/
├── m5-master.mov              # 2.7 GB, ProRes 422 HQ Apple Log 2
├── m5-motion.gcsv             # 3188 rows, Strategy C
├── m5-combined-timing.json    # smokeError null
└── m5-debug.log
```

Repo-fixed evidence:

- `apps/capacitor-film-lab-ios/diagnostics/m5-combined-timing.json`
- `apps/capacitor-film-lab-ios/diagnostics/m5-motion.gcsv`
- `apps/capacitor-film-lab-ios/diagnostics/m5-debug.log`

Run-local sync seeds from M5-A Run #2:

- Primary: `runLocalMovieStartToGyroOffsetSeconds = +0.1418127913`
- Secondary: `runLocalMovieStartToAccelOffsetSeconds = +0.1368097913`
- VDO cross-check: `runLocalVdoFirstPtsToGyroOffsetSeconds = -0.0248580837`
- VDO cross-check: `runLocalVdoFirstPtsToAccelOffsetSeconds = -0.0298610837`

## Edit Targets

- `docs/filmtone/ios/v2-capture-gyroflow/active.md` (this file,
  progress / findings).
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` (final
  Completion Log only after PASS).

No Swift / pbxproj edits are expected for a PASS path. If Gyroflow
reveals a concrete M5-A artifact defect, stop and record the defect
before deciding whether to open an M5-A follow-up active.

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m5-a-gcsv-proof.md`
- `apps/capacitor-film-lab-ios/diagnostics/m5-combined-timing.json`
- `apps/capacitor-film-lab-ios/diagnostics/m5-motion.gcsv`
- `apps/capacitor-film-lab-ios/diagnostics/m5-debug.log`
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md`

## Checklist

- [ ] Confirm the M5-A package still exists at `/tmp/filmtone-m5-pull2/...`;
      if the `.mov` is missing, restore it from device or rerun M5-A
      before continuing.
- [ ] Open Gyroflow desktop and load `m5-master.mov`.
- [ ] Load or auto-detect `m5-motion.gcsv`.
- [ ] Confirm Gyroflow recognizes IMU data: sample count/rate is plausible
      against M5-A (`3188 rows`, about `99.93 Hz`).
- [ ] Apply the primary sync seed `+141.81 ms` or the equivalent UI value
      needed by Gyroflow's sign convention; record the exact sign / field.
- [ ] Run Gyroflow's sync / optical-flow alignment on the clip.
- [ ] Check whether the suggested sync stays near the M5-A seed. Record
      the delta in ms.
- [ ] Stabilize one simple handheld pan segment.
- [ ] Inspect for obvious phase error, axis inversion, horizon drift, or
      overcorrection.
- [ ] Export a short stabilized proof clip or capture screenshots only if
      needed to preserve evidence; do not turn this into broad QA.
- [ ] Record Real-Device/Desktop Findings in this active.

## Done Conditions

- Gyroflow loads `m5-master.mov + m5-motion.gcsv`.
- IMU row count / rate visible in Gyroflow is consistent with M5-A
  diagnostics.
- Sync can be aligned starting from `+141.81 ms` without a new manual
  guess.
- The final sync offset is close enough to the M5-A seed to show the
  run-local offset is useful. Target: within `±100 ms`; record exact
  value either way.
- One simple pan stabilizes without obvious phase error or axis inversion.

## Stop Conditions

- `m5-master.mov` is unavailable and cannot be restored quickly.
- Gyroflow cannot load `m5-motion.gcsv`.
- Gyroflow loads the file but sees zero/implausible IMU samples.
- Sync requires an offset more than `±300 ms` away from the M5-A primary
  seed, suggesting the timestamp basis or sign is wrong.
- Stabilization shows obvious axis inversion or phase error after sync.
- Any issue points to a concrete M5-A writer defect; stop and define the
  smallest writer follow-up instead of hand-tuning around it.

## Out of Scope

- Rolling-shutter coefficient calibration (M5-C).
- iOS writer refactor unless M5-B exposes a concrete artifact defect.
- New capture run unless the existing `.mov` is missing or corrupt.
- Filmtone editor handoff / M6.
- Multi-device coverage.

## Verification Status

- [x] Gyroflow load completed.
- [x] Sync seed tested (Rough gyro offset clamped to 0.1s precision in
      Gyroflow v1.6.3; entered `0.1` — within ±100ms of M5-A seed
      `+0.14181`).
- [x] Stabilized proof checked (preview rendered, **axis inversion
      observed visually** — see Findings).
- [x] Findings recorded.

## Findings

### What worked

- Gyroflow v1.6.3 (macOS) loaded `m5-master.mov` and `m5-motion.gcsv`
  without error.
- `.gcsv` was recognized as `filmtone filmtone ios m5` (camera ID from
  M5-A writer's `vendor` / `model` header lines).
- IMU samples loaded; gyro X/Y/Z waveforms render finite and continuous
  across the full 30s timeline (visual confirmation of the `3188`-row
  `.gcsv`).
- Stabilization preview pipeline became active (left-panel
  `Max rotation: Pitch 4.8° / Yaw 4.9° / Roll 2.6°`, `Max zoom: 130.2%`
  on `Default` smoothness 48%) — Gyroflow integrated the gyro stream and
  began rendering compensated frames. Preview path:
  `Processing 1920x1080 using Qt RHI took 1.83ms`,
  `Device for video processing: [OpenCL] Apple M4 Max: 1.2`.
- Detected video metadata: `3840x2160`, `30 fps`, `PRORES 668.20 Mbps`,
  `YUV422 10 bit`, `Rotation: 270°` (matches M5-A
  `movieRotation.appliedAngle = 90` in inverse representation),
  `Duration: 30.63 s`, `Contains gyro: No` (expected — `.gcsv` is
  external sidecar, not embedded in `.mov`).

### What did not work

- **`Auto sync` did not produce any sync points.** No timeline markers,
  no progress / error banner. Probable causes:
  - The M5-A clip is gentle handheld over bright laptop screen content
    (low optical-flow feature density, low gyro signal — Max rotation
    only ~5°). `OpenCV (DIS)` + `findEssentialMat` + `rs-sync` need
    stronger motion + textured scene to converge.
  - This clip was designed as a structural / timing proof for M5-A, not
    an optical-sync test asset; suitability for Gyroflow auto-sync is
    incidental.
- **`Rough gyro offset` field is clamped to 0.1s precision** in Gyroflow
  v1.6.3 GUI. Cannot input `0.1418` (true M5-A seed); only `0.0` /
  `0.1` / `0.2` accepted. Entered `0.1`. Gap to true seed = 41.8ms
  (within Done condition tolerance ±100ms, so not a blocker).
- **Axis inversion observed visually** when stabilization preview was
  toggled on: gyro-driven correction moves the image in the wrong
  direction relative to camera motion. Qualitative — owner observed
  "基本的に反転している / 補正は正しくない".

### Root cause hypothesis

Gyroflow (stock, v1.6.3) is not optimized for iPhone IMU coordinate
conventions. `.mov` carries `Rotation 270° / appliedAngle 90°`
(sensor → display frame); `.gcsv` carries Core Motion raw rotationRate
and acceleration in **sensor frame** with `axisConvention.mode =
sensor-native` and `orientation = XYZ`. Gyroflow's IMU orientation
field defaulted to `XYZ` (identity), so the sensor-frame data is fed
into a pipeline that expects image-frame, producing the inversion.

This was an explicitly anticipated outcome — M5-A's archived
`axisConvention.rawSensorFrameNote` reads:

> "M5-B verifies against rotated .mov; orientation may be overridden
> if desktop evidence requires image-frame remap."

The desktop evidence here says: image-frame remap **is** required for
Gyroflow to interpret this stream correctly. But the chosen path is
**not** to remap inside the M5-A writer.

### Decision

1. **M5-A writer stays sensor-native** as designed. Raw Core Motion
   data is the honest representation; remapping at write time would
   bake a downstream consumer's coordinate convention into Filmtone's
   capture truth.
2. **Gyroflow is not the long-term motion consumer for Filmtone.**
   Filmtone will build its own iPhone-optimized stabilization /
   motion-data library separately. The Gyroflow desktop path is a
   diagnostic / interop reference, not a product workflow.
3. **M5-B closes as BLOCKED**, not PASS, not FAIL. Done conditions
   "Sync can be aligned starting from +141.81ms without a new manual
   guess" and "One simple pan stabilizes without obvious phase error"
   are not met inside stock Gyroflow, but the cause is on the
   Gyroflow consumer side, not in M5-A's writer.
4. Strategy `M5` Done conditions referencing Gyroflow stabilization
   quality may need rewording when the Filmtone-optimized motion
   library lane is opened. **No strategy edits beyond Completion Log
   in this active.**

### Out of scope (deferred to future actives)

- Defining the Filmtone-optimized stabilization library lane.
- Diagnosing the exact axis remap empirically (would only matter if a
  Gyroflow-side preset / IMU orientation override path were chosen,
  which it is not).
- M5-C rolling-shutter calibration.
- Any change to `FilmtoneGcsvWriter.swift` /
  `FilmtoneGcsvSmoke.swift` — M5-A code stays at `d0e847e1`.

### Evidence references

- M5-A package (read-only): `/tmp/filmtone-m5-pull2/m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f/`
- Repo-fixed: `apps/capacitor-film-lab-ios/diagnostics/m5-combined-timing.json`
- Repo-fixed: `apps/capacitor-film-lab-ios/diagnostics/m5-motion.gcsv`
- Repo-fixed: `apps/capacitor-film-lab-ios/diagnostics/m5-debug.log`
- Gyroflow build under test: v1.6.3 (macOS), `/Applications/Gyroflow.app`
