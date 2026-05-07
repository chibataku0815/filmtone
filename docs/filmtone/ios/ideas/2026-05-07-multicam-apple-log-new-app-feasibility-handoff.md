# MultiCam Apple Log New-App Feasibility Handoff

Date: 2026-05-07 JST

## Purpose

This document hands off a separate new-app idea for a future chat:

> Build a new native iOS app that tests whether front and rear iPhone cameras
> can capture Apple Log simultaneously through AVFoundation MultiCam.

This is intentionally separate from the Filmtone iOS V2 capture / Gyroflow
lane. Do not merge this into the current Filmtone `active.md` unless the user
explicitly changes direction.

Current Filmtone V2 source of truth:

```text
docs/filmtone/ios/v2-capture-gyroflow/
├── strategy.md
├── active.md
└── archive/
```

This handoff is an idea / feasibility record only.

## Conversation Context

The user first considered growing the iOS app audience. Advertising did not
increase access meaningfully, so the direction shifted toward making Filmtone a
product the owner personally wants to use.

That produced an owner-first Filmtone iOS V2 capture / Gyroflow plan:

- capture in Filmtone;
- record raw gyro and accelerometer samples;
- export `.mov + .gcsv + Filmtone sidecar`;
- hand off to Gyroflow when stabilization matters;
- finish color inside Filmtone;
- use small verification stages instead of building a polished camera UI first.

The current Filmtone V2 plan is single-camera-first. The first active task is a
capability probe for one rear-camera recording path, not a MultiCam experiment.

The user then introduced a separate idea:

> Capture front and rear cameras simultaneously in Apple Log, then stabilize
> with Gyroflow.

After discussion, the scope was narrowed to the capture feasibility itself:

> Investigate MultiCam Apple Log capture as a separate new-app premise.

This means the next chat should treat it as a clean native iOS prototype /
research app, not as a feature inside the current Filmtone app.

## Current Conclusion

MultiCam Apple Log is not disproven by the API, but it is not proven by public
documentation either.

Feasibility tiers:

- Front + rear simultaneous capture: likely feasible on supported devices.
- Rear Apple Log + front Rec.709 / HLG companion stream: plausible and worth
  testing.
- Front + rear both Apple Log at modest resolution / fps: unknown until real
  device probing.
- Front + rear both Apple Log in ProRes / high resolution / high fps: likely
  difficult because of MultiCam hardware, bandwidth, encoder, and thermal
  costs.

The key unknown is the runtime intersection:

```text
front format:
  isMultiCamSupported == true
  supportedColorSpaces contains appleLog or appleLog2

rear format:
  isMultiCamSupported == true
  supportedColorSpaces contains appleLog or appleLog2

session:
  AVCaptureMultiCamSession.isMultiCamSupported == true
  front and rear devices are in supportedMultiCamDeviceSets
  hardwareCost < 1.0
  systemPressureCost is sustainable
```

If that intersection is empty, the idea should pivot to rear Apple Log plus
front non-Log companion capture.

## Evidence Already Checked

### Apple MultiCam

Apple's WWDC19 camera capture session explains that AVFoundation added
MultiCam support on iOS 13 and that front and rear camera streams can be routed
to separate `AVCaptureVideoDataOutput` instances. It also explains that
MultiCam has hardware, thermal, and bandwidth constraints.

Sources:

- Apple WWDC19:
  `https://developer.apple.com/videos/play/wwdc2019/225/`
- Apple sample:
  `https://developer.apple.com/documentation/AVFoundation/avmulticampip-capturing-from-multiple-cameras`

The local Xcode iPhoneOS 26.4 SDK confirms:

- `AVCaptureMultiCamSession` exists.
- `AVCaptureMultiCamSession.isMultiCamSupported` exists.
- `AVCaptureMultiCamSession.sessionPreset` is always input-priority.
- Each input's `device.activeFormat` must be set manually.
- `AVCaptureDevice.Format.isMultiCamSupported` exists.
- `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets` exists.
- `AVCaptureMultiCamSession.hardwareCost` and `systemPressureCost` exist.
- A session with cost above the budget cannot run or cannot run sustainably.

Relevant local SDK files:

```text
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.4.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureSession.h
/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS26.4.sdk/System/Library/Frameworks/AVFoundation.framework/Headers/AVCaptureDevice.h
```

### Apple Log / Apple Log 2

The local Xcode iPhoneOS 26.4 SDK confirms:

- `AVCaptureColorSpace_AppleLog` exists and is available from iOS 17.
- `AVCaptureColorSpace_AppleLog2` exists and is available from iOS 26.
- `AVCaptureDevice.Format.supportedColorSpaces` exists.
- `AVCaptureDevice.activeColorSpace` can be set manually.
- To prevent AVFoundation from undoing manual color-space selection, the
  session must set `automaticallyConfiguresCaptureDeviceForWideColor = false`.
- Changing active color space while a session is running is disruptive.
- Apple Log / Apple Log 2 disables photo capture outputs connected to that
  device, so the new app should not include photo output in the first spike.

Important: this proves the API surface exists. It does not prove that any
front-camera MultiCam-supported format runtime-reports Apple Log.

### Encoder / Writer Constraints

The local SDK notes:

- ProRes encoders can preserve high bit-depth sources.
- For high bit-depth ProRes writing, recommended YUV pixel formats include
  16-bit / 10-bit 4:2:2 formats.
- Scaling and color matching are not supported with those high bit-depth
  AVAssetWriter paths, so writer dimensions should match sample-buffer
  dimensions.

Implication:

- For an Apple Log proof, avoid scaling in the writer path.
- Prefer two separate writers or two separate movie files for the first proof.
- Do not begin with PiP compositing if the goal is proving Apple Log capture.

### Gyroflow Context

Gyroflow `.gcsv` sidecar is text-based and can describe raw gyro /
accelerometer samples plus camera metadata.

Source:

- `https://docs.gyroflow.xyz/app/technical-details/gcsv-format`

For this new-app idea, Gyroflow should be considered later. First prove
MultiCam Apple Log capture. Stabilization adds lens profile, orientation,
rolling shutter, front/rear mirroring, and axis-mapping complexity.

## Product / Prototype Framing

Treat this as a new native iOS prototype app, not a Filmtone feature.

Recommended prototype name:

```text
MultiCamLogProbe
```

Recommended starting stack:

- Native Swift / SwiftUI app.
- AVFoundation only for capture.
- No Capacitor.
- No Filmtone editor UI.
- No LUT / color grade UI.
- No App Store metadata.
- No public positioning.

The prototype should answer one question:

> Can one iPhone runtime-report and run front + rear MultiCam streams where
> both selected formats support Apple Log or Apple Log 2?

## Non-Goals For The First Chat

- Do not build a polished camera app.
- Do not build Gyroflow stabilization yet.
- Do not build Filmtone grading.
- Do not build PiP output first.
- Do not build a library, account system, or sharing flow.
- Do not use `AVCaptureMovieFileOutput` first if sample-level timing or
  two-stream control matters.
- Do not infer support from device marketing names; probe runtime values.

## Recommended Validation Ladder

### S0 - Static API Confirmation

Goal:

Confirm the local SDK has the required symbols.

Check:

- `AVCaptureMultiCamSession`
- `AVCaptureMultiCamSession.isMultiCamSupported`
- `AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets`
- `AVCaptureDevice.Format.isMultiCamSupported`
- `AVCaptureDevice.Format.supportedColorSpaces`
- `AVCaptureDevice.activeColorSpace`
- `AVCaptureColorSpace.appleLog`
- `AVCaptureColorSpace.appleLog2`
- `AVCaptureSession.automaticallyConfiguresCaptureDeviceForWideColor`
- `AVCaptureSession.hardwareCost`
- `AVCaptureMultiCamSession.systemPressureCost`

Pass:

- All required symbols exist in the local SDK.

### S1 - Device Capability Enumeration

Goal:

Collect a real-device JSON before any recording.

Implementation:

- Create a tiny native iOS app or command surface.
- Query `AVCaptureMultiCamSession.isMultiCamSupported`.
- Use `AVCaptureDevice.DiscoverySession` for front and rear cameras.
- Record `supportedMultiCamDeviceSets`.
- For each candidate front / rear device, enumerate all formats.

JSON fields:

```json
{
  "deviceModel": "...",
  "osVersion": "...",
  "multiCamSupported": true,
  "supportedMultiCamDeviceSets": [],
  "devices": [
    {
      "uniqueID": "...",
      "localizedName": "...",
      "position": "front|back",
      "deviceType": "...",
      "formats": [
        {
          "formatIndex": 0,
          "dimensions": "1920x1080",
          "fpsRanges": [],
          "isMultiCamSupported": true,
          "supportedColorSpaces": ["sRGB", "P3_D65", "appleLog"],
          "isBinnedOrCroppedHint": "...",
          "fieldOfView": 0,
          "videoStabilizationModes": [],
          "pixelFormat": "..."
        }
      ]
    }
  ]
}
```

Pass:

- At least one front camera and one rear camera are allowed together.
- At least one format per side is `isMultiCamSupported`.
- Apple Log or Apple Log 2 appears in `supportedColorSpaces` for both sides.

Fail / pivot:

- If only rear supports Apple Log, pivot to rear Apple Log + front non-Log
  companion stream.

### S2 - Candidate Pair Cost Probe

Goal:

Find whether candidate front/rear Log formats fit within MultiCam budget.

Implementation:

- Create an `AVCaptureMultiCamSession`.
- Set `automaticallyConfiguresCaptureDeviceForWideColor = false`.
- Add front and rear inputs with no connections.
- Add one `AVCaptureVideoDataOutput` per camera with no connections.
- Manually create one connection per camera.
- Set active format and active color space per device before starting.
- Do not record.
- Read `hardwareCost` and `systemPressureCost`.

Pass:

- `hardwareCost < 1.0`.
- `systemPressureCost <= 1.0` or clearly sustainable.
- Both connections become active.

Fail / pivot:

- Lower resolution.
- Lower fps.
- Use cropped or binned formats.
- Try rear Apple Log + front Rec.709 / P3 / HLG.

### S3 - Dual Preview Smoke

Goal:

Prove both streams deliver sample buffers.

Implementation:

- Use two `AVCaptureVideoDataOutput` delegates.
- Count sample buffers for each stream for 10 seconds.
- Do not write movie files yet.
- Do not apply color transforms.

Diagnostics:

- first / last PTS per stream;
- frame count per stream;
- dropped frames per stream;
- observed fps per stream;
- active color space per stream;
- active format per stream;
- hardware and pressure cost.

Pass:

- Both streams deliver frames for 10 seconds without interruption.
- Both active color spaces remain Apple Log or Apple Log 2 if selected.

### S4 - Dual Writer Smoke

Goal:

Write actual files without compositing.

Recommended output:

```text
front.mov
rear.mov
multicam-log-diagnostics.json
```

Implementation:

- Use two `AVAssetWriter` instances first.
- Match writer dimensions to sample-buffer dimensions.
- Prefer ProRes if runtime-supported and sustainable.
- If ProRes is too costly, use explicit HEVC 10-bit fallback.
- Do not use HEVC 8-bit for Log.

Pass:

- Both files open.
- Both files preserve expected color metadata or are clearly tagged in
  diagnostics.
- No dropped-frame burst invalidates the test.

### S5 - Longer Thermal / Pressure Trial

Goal:

Determine whether the configuration is usable beyond a demo clip.

Run:

- 30 seconds.
- 2 minutes.
- 5 minutes if the previous runs pass.

Diagnostics:

- session interruptions;
- `systemPressureState`;
- hardware / pressure cost;
- writer status;
- dropped frames;
- storage throughput;
- file sizes.

Pass:

- 2-minute run completes without thermal shutdown, writer failure, or severe
  frame loss.

### S6 - Optional Gyroflow Axis Study

Only start this after MultiCam Apple Log is proven.

Question:

Can one raw IMU stream be mapped correctly to both front and rear camera image
paths?

Notes:

- Use raw gyro and raw accelerometer samples.
- Do not use fused `DeviceMotion` for Gyroflow data.
- Treat front and rear clips as separate camera profiles.
- Front camera likely needs separate orientation and mirroring metadata.
- Stabilize separate clips before compositing; do not start with a PiP
  composite.

## Recommended Technical Architecture

### Capture Graph

```text
AVCaptureMultiCamSession
  front AVCaptureDeviceInput
    -> front AVCaptureVideoDataOutput
    -> front AVAssetWriter

  rear AVCaptureDeviceInput
    -> rear AVCaptureVideoDataOutput
    -> rear AVAssetWriter
```

Do not connect two cameras to one `AVCaptureVideoDataOutput`. Apple explicitly
describes MultiCam as separate inputs, outputs, and connections. If compositing
is desired later, do it after the raw two-stream proof.

### Session Setup Rules

- Use `AVCaptureMultiCamSession`.
- Use no-connections APIs and manual `AVCaptureConnection` wiring.
- Set each device's `activeFormat` manually.
- Set `session.automaticallyConfiguresCaptureDeviceForWideColor = false`.
- Lock each device before setting `activeColorSpace`.
- Set `activeColorSpace` before `startRunning`.
- Do not change active color space while recording.
- Do not add photo output to the first Log proof.
- Keep video stabilization off during proof unless explicitly testing it.

### Output Strategy

Start with two separate files:

```text
rear.mov
front.mov
multicam-diagnostics.json
```

Avoid single composite output until after both streams are proven. A single
PiP/composite file makes it harder to prove:

- whether both inputs are really Apple Log;
- whether each camera's color metadata is preserved;
- which stream caused dropped frames;
- how front mirroring / orientation is represented;
- how each stream should later map to Gyroflow metadata.

## Main Feasibility Risks

### R1 - Front Camera May Not Support Apple Log

The API does not guarantee that a front camera format supports Apple Log.
Runtime `supportedColorSpaces` is the source of truth.

### R2 - MultiCam Formats May Exclude Apple Log

A camera might support Apple Log in single-camera mode but not expose Apple Log
on any `isMultiCamSupported` format.

### R3 - Hardware Cost May Exceed Budget

Two Log streams, high resolution, high fps, high bit-depth buffers, and
recording can push `hardwareCost` or `systemPressureCost` over the usable
threshold.

### R4 - ProRes May Be Too Heavy

ProRes is desirable for Log quality, but two simultaneous ProRes streams may be
too heavy for the device, storage, or thermal budget. HEVC 10-bit fallback must
be explicitly labeled if used.

### R5 - Color Metadata May Not Survive The Writer Path

It is not enough for the capture device to report Apple Log. The resulting
files must preserve or explicitly describe color metadata well enough for
downstream tools.

### R6 - Orientation And Mirroring Are Different Per Stream

Front camera rotation and mirroring are separate from rear camera behavior.
Diagnostics must record this per stream.

### R7 - Gyroflow Is A Later Risk

Gyroflow is not the first feasibility question. Stabilization needs separate
camera profiles, orientation, rolling shutter, lens profile, and front/rear
axis mapping.

## Decision Matrix

### Best Case

Both front and rear have MultiCam-supported formats with Apple Log or Apple Log
2. Hardware and pressure cost stay under budget. Dual files can be written for
at least 30 seconds.

Next step:

- Extend to 2-minute thermal trial.
- Then evaluate color metadata and optional Gyroflow axis mapping.

### Practical Case

Rear supports Apple Log in MultiCam, front does not.

Next step:

- Build rear Apple Log + front Rec.709 / P3 / HLG companion capture.
- Treat this as the likely usable product direction.

### Constraint Case

Both sides expose Apple Log, but hardware or pressure cost is too high.

Next step:

- Reduce resolution.
- Reduce fps.
- Prefer cropped / binned formats.
- Try HEVC 10-bit fallback.
- If still too high, return to single-camera Apple Log or rear-Log + front
  non-Log.

### Fail Case

No front/rear MultiCam pair exposes Apple Log on both sides, and rear-Log plus
front companion is not useful enough.

Next step:

- Do not build a MultiCam Apple Log app.
- Keep the idea archived as device-constrained.

## Suggested New-Chat First Task

Create a new, separate prototype plan for `MultiCamLogProbe`.

First active task:

> Build a read-only capability probe that produces JSON for front/rear
> MultiCam-supported formats and Apple Log / Apple Log 2 color-space support.

Do not record video in the first task.

Minimum output:

```text
multicam-apple-log-capabilities.json
```

Minimum pass/fail:

- Does the device support `AVCaptureMultiCamSession`?
- Are front and rear cameras allowed together?
- Does any front format have both `isMultiCamSupported` and Apple Log /
  Apple Log 2?
- Does any rear format have both `isMultiCamSupported` and Apple Log /
  Apple Log 2?
- Are there any candidate front/rear pairs worth cost-probing?

## Known Repository State At Handoff

Repository:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
```

Important note:

- The repo has many unrelated dirty files from other Filmtone work.
- Do not revert unrelated changes.
- This MultiCam idea is not implemented in the repo.
- This document is only a handoff for a separate new-app feasibility chat.

Relevant current docs:

```text
docs/filmtone/ios/v2-capture-gyroflow/strategy.md
docs/filmtone/ios/v2-capture-gyroflow/active.md
apps/capacitor-film-lab-ios/CLAUDE.md
```

The current Filmtone V2 active task is `M1 - Capability Probe` for a
single-camera owner workflow. It should not be expanded to MultiCam unless the
user explicitly says so.

## English Handoff Prompt For The Next Chat

```text
You are helping evaluate a separate new native iOS app idea, not a feature in
the current Filmtone iOS app.

Project idea:
Build a clean native Swift/SwiftUI prototype app named MultiCamLogProbe that
tests whether an iPhone can capture front and rear cameras simultaneously in
Apple Log or Apple Log 2 using AVFoundation MultiCam.

Important context:
- This is separate from the existing Filmtone iOS V2 capture/Gyroflow lane.
- Do not edit the existing Filmtone app unless explicitly asked.
- Treat the current task as feasibility research and prototype planning.
- The first proof must be a capability probe, not a polished camera UI.
- Do not start with Gyroflow stabilization.
- Do not start with PiP compositing.
- Do not infer support from marketing device names. Runtime probes are the
  source of truth.

Known API facts to verify and use:
- AVCaptureMultiCamSession supports simultaneous capture from multiple camera
  inputs on supported devices.
- AVCaptureMultiCamSession.isMultiCamSupported must be checked.
- AVCaptureDevice.DiscoverySession.supportedMultiCamDeviceSets identifies
  device sets allowed in one MultiCam session.
- AVCaptureDevice.Format.isMultiCamSupported must be true for any format used
  in MultiCam.
- AVCaptureDevice.Format.supportedColorSpaces must contain .appleLog or
  .appleLog2 for that exact format.
- .appleLog is available in the local iPhoneOS 26.4 SDK and is iOS 17+.
- .appleLog2 is available in the local iPhoneOS 26.4 SDK and is iOS 26+.
- To manually set activeColorSpace, set
  session.automaticallyConfiguresCaptureDeviceForWideColor = false.
- activeColorSpace must be set while holding the device configuration lock and
  before capture starts. Changing it while running is disruptive.
- MultiCam hardwareCost and systemPressureCost must be measured.
- If hardwareCost is >= 1.0, the desired configuration cannot run.
- If systemPressureCost is > 1.0, the configuration may not run sustainably.

Main feasibility question:
Does the actual owner device expose at least one front camera format and one
rear camera format where:
1. both formats are isMultiCamSupported,
2. both formats include .appleLog or .appleLog2 in supportedColorSpaces,
3. the front and rear devices are allowed together by supportedMultiCamDeviceSets,
4. the configured AVCaptureMultiCamSession has hardwareCost < 1.0,
5. systemPressureCost is sustainable?

First task:
Design and, if asked, implement only a read-only capability probe. It should not
record video. It should create a JSON artifact named:
multicam-apple-log-capabilities.json

The JSON should include:
- device model and OS version
- AVCaptureMultiCamSession.isMultiCamSupported
- supportedMultiCamDeviceSets
- all front and rear candidate devices
- each device's formats
- each format's dimensions, fps ranges, isMultiCamSupported,
  supportedColorSpaces, pixel format hints, field of view, stabilization support
  if available, and any binned/cropped hints available from the API
- candidate front/rear pairs where both sides are MultiCam-supported and where
  Apple Log or Apple Log 2 is present

Second task only after the probe:
Build a cost probe using AVCaptureMultiCamSession with no recording:
- add front and rear inputs with no automatic connections
- add one AVCaptureVideoDataOutput per camera
- create explicit AVCaptureConnections
- set activeFormat and activeColorSpace manually before starting
- read hardwareCost and systemPressureCost
- report whether any candidate pair can run

Preferred recording proof after cost probe:
- write two separate files first: rear.mov and front.mov
- do not composite first
- prefer ProRes only if runtime-supported and sustainable
- use HEVC 10-bit only as an explicit fallback
- do not use HEVC 8-bit for Log
- preserve sample-buffer dimensions; avoid scaling in the writer path

Likely outcomes:
- Best case: both front and rear support MultiCam Apple Log/Apple Log2 and the
  session cost is sustainable.
- Practical case: rear supports Apple Log, front only supports Rec.709/P3/HLG.
  This is still a viable product direction.
- Constraint case: both expose Log, but cost is too high; reduce resolution,
  fps, or use cropped/binned formats before giving up.
- Fail case: no useful MultiCam Apple Log pair exists; archive the idea as
  device-constrained.

Be strict:
- Keep this separate from Filmtone V2.
- Do not implement UI before proving runtime capability.
- Do not make public product claims.
- Do not claim front+rear Apple Log is possible until a real-device probe proves
  the exact formats and session costs.
- Prefer primary Apple/AVFoundation documentation and local SDK headers over
  memory or blog posts.
```

