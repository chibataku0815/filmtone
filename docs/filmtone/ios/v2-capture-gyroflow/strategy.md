# Filmtone iOS V2 Capture / Gyroflow Strategy

Date: 2026-05-07 JST

## Placement

This directory is the current source of truth for the Filmtone iOS V2
capture / Gyroflow lane:

```text
docs/filmtone/ios/v2-capture-gyroflow/
├── strategy.md
├── active.md
└── archive/
```

Archived feasibility evidence remains read-only:

```text
docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-v2-capture-gyroflow-realtime-preview-feasibility-2026-05-01-jst.md
```

## Final Goal

Make Filmtone useful enough for the owner to capture, grade, stabilize, finish,
and reuse in a real personal workflow.

This is not an App Store acquisition lane. Growth work is optional and
downstream. The core product work is capture truth, motion-data truth,
color-preview truth, and fast finishing.

## Measurable Done Conditions

V2 is done when the owner can repeatedly complete this loop:

1. Record a 30-60 second rear-camera clip inside Filmtone.
2. Use Apple Log or Apple Log 2 only when the device proves support for it.
3. Record gyro and accelerometer samples across the full clip duration.
4. Export `.mov`, `.gcsv`, and Filmtone sidecar files together.
5. Load `.mov + .gcsv` in Gyroflow and align sync without a new manual guess
   for every clip.
6. Open the same clip immediately in the existing Filmtone editor.
7. Apply Source Profile, Look, optical effects, quick adjustments, and export.
8. Confirm preview and export are close enough that preview decisions are not
   misleading.
9. Finish at least three owner clips that would otherwise have been shot
   outside Filmtone.

## Milestones

### M1 - Capability Probe

Goal:

Enumerate the owner device's real capture capabilities before building any
recording path.

Done:

- A capability JSON is produced from a real device.
- At least one rear-camera video mode is visible.
- Apple Log / Apple Log 2 support is shown only when runtime-reported.
- Unsupported modes are absent or disabled, not inferred.
- The probe does not start recording and does not add privacy keys unless the
  runtime path proves permission is required.

### M2 - Video-Only Writer Smoke

Goal:

Prove Filmtone can write one short video in the selected mode before motion or
Gyroflow work exists.

Done:

- A 5-10 second `.mov` opens normally.
- Video diagnostics include first / last PTS, frame count, dropped-frame count,
  selected format, selected color space, fps, dimensions, and writer status.
- `NSCameraUsageDescription` exists before any capture session is started.
- The selected codec follows the codec policy in Known Constraints.
- Rotation/orientation is pinned and recorded in diagnostics.
- Video stabilization is forced off when controllable and recorded when not.

Dependency:

- M1.

### M3 - Motion-Only Recorder Smoke

Goal:

Prove Core Motion sample delivery is stable enough before combining it with
video recording.

Done:

- A 10 second motion diagnostic file is produced.
- Gyro and accelerometer samples cover the requested duration.
- Median interval and max timestamp gap are visible.
- `NSMotionUsageDescription` exists before motion recording is requested.
- Raw gyro and raw accelerometer APIs are used; fused device-motion samples are
  not used for Gyroflow data.

Dependency:

- M1.

### M4 - Combined Timing Smoke

Goal:

Collect video PTS and Core Motion timestamps in the same recording session with
enough metadata to attempt mapping.

Done:

- A 30 second `.mov` and combined diagnostics are produced.
- Motion samples cover the full video duration plus a small margin.
- First / last video PTS and first / last motion timestamps are present.
- Offset mapping is explicit enough to start `.gcsv` generation.
- Diagnostics include the timestamp anchor needed to map video PTS and Core
  Motion timestamps.

Dependencies:

- M2.
- M3.

### M5 - Gyroflow `.gcsv` Proof

Goal:

Prove captured motion data can become a Gyroflow-readable sidecar.

Done:

- Package folder contains `.mov`, `.gcsv`, and diagnostics.
- Gyroflow loads the video and sidecar.
- A basic sync / optical-flow check can align the clip.
- One simple handheld pan stabilizes without obvious phase error.
- Rolling-shutter coefficient is recorded as device-once package metadata once
  it is dialed in.

Dependency:

- M4.

### M6 - Editor Handoff And Honest Preview

Goal:

Make captured clips useful inside Filmtone, then make capture-time preview good
enough for shooting decisions.

Done:

- A captured clip opens in the existing editor.
- Matching Source Profile is preselected or attached.
- Export sidecar references capture package metadata.
- Capture preview is close enough for exposure, framing, and Look choice.
- Any omitted preview effect classes are explicitly labeled during development.
- Capture preview reuses the existing Filmtone grade graph through a
  `AVCaptureVideoDataOutput` -> `CIImage` -> `CIContext` -> `MTKView` style
  path unless a later active task records why that is not viable.

Dependency:

- M4 for editor handoff.
- M5 before public Gyroflow-facing claims.

### M7 - Owner Clip Trial

Goal:

Decide whether this actually replaces the stock camera for the target personal
use case.

Done:

- Three real owner clips complete capture -> edit -> export or capture ->
  Gyroflow handoff.
- Any fallback to the stock camera is recorded with a concrete reason.

Dependency:

- M6.

## Known Constraints

- No implementation starts without `active.md`.
- Only one current `active.md` may exist for this lane.
- No silent capture fallback. Apple Log / Apple Log 2, ProRes, HEVC, lens, fps,
  stabilization, and storage choices must be explicit.
- No fake preview. Preview may be partial, but it must not claim more than it
  shows.
- Video capture defaults to ProRes 422 or 422 HQ when runtime writer support is
  available. HEVC 10-bit is an explicit fallback. HEVC 8-bit plus Log is not an
  acceptable capture mode.
- Capture diagnostics must record orientation, stabilization state, OIS/EIS
  limits, codec, color space, fps, dimensions, and timestamp anchors.
- M1-M4 use internal sandbox output only. External SSD / security-scoped output
  is deferred until owner workflow polish unless an active task explicitly
  expands scope.
- M1-M4 produce silent video. Audio capture and `NSMicrophoneUsageDescription`
  are deferred until owner workflow polish.
- The first device target is the owner device.
- Broad device coverage, App Store copy, screenshots, and marketing wait until
  the owner workflow works.
- "Gyro recorded" is not the same as "Gyroflow-quality stabilization."

## Open Questions

- Which rear-camera format should be the first real recording mode on the owner
  device?
- Does the owner device runtime-report Apple Log 2 for the desired mode?
- Can `AVCaptureVideoDataOutput + AVAssetWriter` produce stable PTS for this
  use case?
- Does Core Motion sampling remain stable while the selected video mode records?
- Can Core Motion boot-time timestamps and video PTS be mapped cleanly enough
  for Gyroflow?
- Which stabilization / lens path makes gyro data agree with the image path?
- Does capture-time preview need Metal earlier than expected?

## Completion Log

- 2026-05-07: Created iOS V2 capture / Gyroflow 2-layer operating structure and
  scoped the first active task to M1 Capability Probe.
