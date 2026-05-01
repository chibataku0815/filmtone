# Filmtone V2 Capture / Gyroflow / Realtime Preview Feasibility

Date: 2026-05-01 JST

## Conclusion

Filmtone V2 can realistically target a large capture-focused upgrade:

- Apple Log / Apple Log 2 capture inside Filmtone
- Filmtone Look / Source Profile preview during capture
- Gyroflow-compatible motion-data export
- realtime preview of the major Filmtone effects during editing

The product-quality path is not to build every outer shell feature first. The core proof should be a single real capture lane:

1. Record a short Apple Log clip inside Filmtone.
2. Record gyro / accelerometer samples during that same capture.
3. Export `.mov + .gcsv + Filmtone sidecar`.
4. Confirm Gyroflow can load and synchronize the motion data.
5. Confirm Filmtone can preview the active Source Profile / Look without lying about final color.

The riskiest claim is not "can iOS read gyro while recording?" It can. The real risk is whether the timestamp quality, IMU orientation, lens profile, rolling-shutter metadata, and stabilization settings are good enough for Gyroflow-quality output.

## Current Filmtone Baseline

Filmtone iOS is currently a finishing/import app, not a capture camera. The App Store description explicitly says:

- `apps/capacitor-film-lab-ios/fastlane/metadata/en-US/description.txt`
- line 14: "Filmtone is not a capture camera."

Existing useful foundations:

- Apple Log / Apple Log 2 already exist as Source Profile entries:
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- Apple Log / Apple Log 2 decoding math already exists:
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
- video preview already uses `AVMutableVideoComposition` with Core Image filtering:
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
  - `FilmtoneSharedGradeProcessor.makeVideoComposition(...)`
- realtime-ish graded playback already has a native path:
  - `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
  - `makeGradedPreviewItem(...)`
  - `makeGradedPreviewComposition(...)`

This means V2 is not starting from zero for color or preview. It is starting from zero for capture, capture-time UI, and motion sidecar generation.

## Apple Log Capture Feasibility

Apple Log capture is feasible through AVFoundation.

Confirmed facts:

- Apple documents ProRes recording on supported iPhone models, including Log encoding.
- Apple Log is exposed as `AVCaptureColorSpace.appleLog`.
- Apple Log 2 is exposed as `AVCaptureColorSpace.appleLog2` in the local iPhoneOS 26.4 SDK.
- `AVCaptureDevice.Format.supportedColorSpaces` lets the app inspect which formats support which color spaces.
- `AVCaptureDevice.activeColorSpace` can be set while holding the device configuration lock.
- `AVCaptureVideoDataOutput` can provide sample buffers for custom processing / writing through `AVAssetWriter`.
- `AVCaptureMovieFileOutput` is simpler for direct recording, but `AVCaptureVideoDataOutput + AVAssetWriter` gives more control for timestamps, metadata, and preview processing.

Important constraints:

- Apple Log 2 is iOS 26.0+ in the local SDK.
- Apple Log / Log 2 support must be runtime-detected per device and capture format.
- Changing active color space while the session is running is disruptive.
- Photo capture is not supported when Apple Log / Apple Log 2 is selected as the capture color space.
- ProRes resolution / fps depends on model, storage capacity, and external SSD capability.
- 4K60 / 4K120 ProRes workflows can require fast USB-C external storage.

Product implication:

Filmtone should expose only modes that the current device/session can actually record. Do not imply Apple Log 2 support on devices or OS versions where `supportedColorSpaces` does not prove it.

## Gyro During Capture

It is credible to record gyro data while Filmtone is recording video, if the capture happens inside Filmtone.

Supported path:

- Start `AVCaptureSession`.
- Start `CMMotionManager` gyro / device-motion updates on a dedicated queue.
- Record `CMGyroData.timestamp` or `CMDeviceMotion.timestamp` plus rotation values.
- Record video frame PTS from `CMSampleBufferGetPresentationTimeStamp(...)` when using `AVCaptureVideoDataOutput`.
- Write a `.gcsv` sidecar after capture using the observed motion samples and video timing.

What is confirmed:

- Core Motion exposes raw gyro and processed device-motion data.
- `gyroUpdateInterval` and `deviceMotionUpdateInterval` can be requested.
- Apple says the actual delivered interval must be validated using each motion sample's timestamp.
- `CMLogItem.timestamp` is the time at which the motion item is valid.
- Apple documentation states that the timestamp is seconds since device boot.
- `AVCaptureVideoDataOutput` vends video sample buffers through a delegate queue.

What is not yet proven:

- Whether the observed gyro sample rate remains stable enough while ProRes / Log capture is writing.
- Whether external SSD writes affect motion-sample regularity.
- Whether video PTS and Core Motion timestamps can be aligned with low enough drift for Gyroflow.
- Which iPhone lens / stabilization settings produce motion data that matches the image path.
- Whether optical stabilization / electronic stabilization must be disabled for clean Gyroflow use.

Product implication:

"Gyro is recorded" and "Gyroflow stabilization is production-quality" are separate claims. V2 should not market the second until a real device spike proves it.

## Gyroflow Integration Shape

Best V2 target:

- export a Gyroflow-compatible `.gcsv` sidecar
- optionally package `.mov + .gcsv + Filmtone JSON`
- on Desktop, optionally call Gyroflow CLI if installed
- on iOS, share/export the package for Gyroflow or Desktop processing

Do not make app-internal Gyroflow stabilization the first V2 milestone.

Reasoning:

- Gyroflow supports `.gcsv` as a sidecar format.
- Gyroflow Core exists as a library, but its public API documentation is thin.
- Gyroflow Core integration would require Rust/Swift FFI, Metal texture or pixel-buffer handoff, lens profile handling, rolling shutter correction, and export-pipeline ownership.
- Gyroflow live feed stabilization is explicitly not a ready built-in path in Gyroflow documentation.

Quality-critical `.gcsv` fields:

- `GYROFLOW IMU LOG`
- `version,1.3`
- `id`
- `orientation`
- `videofilename`
- `lensprofile` if known
- `lens_info`
- `frame_readout_time`
- `frame_readout_direction`
- `tscale`
- `gscale`
- `ascale`
- `t,gx,gy,gz,ax,ay,az`

The hard part is not writing this file. The hard part is proving the values are aligned to the captured image.

## Gimbal / Gyroflow Coexistence

Smartphone gimbals and Gyroflow are compatible, but they should not be treated as doing the same job.

Best product framing:

- the gimbal physically stabilizes large movement, walking shake, and composition
- Gyroflow cleans up residual rotation, horizon drift, rolling-shutter wobble, and micro-jitter
- Gyroflow should usually be lighter on gimbal footage than on handheld footage

This can be a strong Filmtone workflow if the app exposes it honestly:

- `Handheld / Gyroflow`: prioritize gyro quality, faster shutter, minimal internal stabilization where controllable, and stronger post stabilization.
- `Gimbal / Gyroflow Light`: use the gimbal as the primary stabilizer and use Gyroflow as a residual cleanup / horizon tool.
- `Gimbal / No Gyroflow`: preserve natural physical camera movement and allow more cinematic shutter choices when post stabilization is not planned.

Main risk:

Avoid stacking too many stabilization systems without knowing which one owns the image path. A problematic stack is:

1. physical gimbal stabilization
2. phone-side electronic stabilization / action-mode style processing
3. strong Gyroflow stabilization in post

This can make the recorded motion data disagree with the image path, increase crop, and create warping or motion-blur mismatch. Optical stabilization may not always be controllable on iPhone, so Filmtone should treat it as something to characterize rather than something it can always disable.

Quality implication:

The V2 capture spike should not require a gimbal. After the handheld proof works, add a second capture matrix:

- handheld / no internal stabilization if controllable
- gimbal / no internal stabilization if controllable
- gimbal / default phone stabilization

Each case should be judged by Gyroflow sync accuracy, crop amount, rolling-shutter correction, motion-blur artifacts, and whether the result looks better than the original gimbal footage.

## Realtime Preview Feasibility

There are two different preview problems.

### Editing Preview

Feasible with the current architecture.

Current path:

- `AVPlayerItem.videoComposition`
- `AVMutableVideoComposition(asset:applyingCIFiltersWithHandler:)`
- `renderablePreviewVideoImage(...)`
- shared grade processor

This can become the main "all effects realtime preview" path, with careful work on:

- parameter update latency
- effect cache invalidation
- motion accumulator reset
- frame extent validation
- thermal behavior on long clips
- parity against export

### Capture-Time Preview

Feasible, but it needs a new native rendering surface.

`AVCaptureVideoPreviewLayer` is not enough for Filmtone effects. It can show camera preview, but not the full Filmtone grade/effect pipeline.

The likely path:

- `AVCaptureVideoDataOutput`
- keep sample buffers / pixel buffers in native high-bit-depth form
- apply display transform / Source Profile / Look through Core Image or Metal
- render to `MTKView`, `CIContext`, or `AVSampleBufferDisplayLayer`

Avoid:

- converting Log/HDR capture frames to `UIImage` / `CGImage` for preview
- forcing 8-bit intermediate buffers for color-critical preview
- applying a display LUT that differs from export without labeling it clearly

## Cinematic Depth / Cinematic Capture

Priority: low for the first V2 capture spike, but valuable as a later product-quality lane.

The important distinction:

- Filmtone's current depth-aware effects are built around `AVDepthData` / `AVDepthDataTrack`.
- Cinematic videos expose a different set of assets through Apple's Cinematic framework:
  - `cinematicVideoTrack`
  - `cinematicDisparityTrack`
  - `cinematicMetadataTrack`
- `CNRenderingSession` can render Cinematic shallow-depth-of-field output from the video and disparity tracks.

Feasible V2-adjacent path:

1. Detect imported Cinematic videos with `CNAssetInfo.checkIfCinematic(...)`.
2. Load the asset's `cinematicDisparityTrack`.
3. Convert the disparity frame data into a Filmtone depth-map representation.
4. Reuse that map for depth-aware halation, glow, diffusion, and possible focus/depth tools.

This is likely the best first Cinematic experiment because it does not block Apple Log capture, gyro recording, or Gyroflow sidecar proof work.

Cinematic capture inside Filmtone is also a real API surface in the local iPhoneOS 26.4 SDK:

- `AVCaptureDeviceInput.cinematicVideoCaptureSupported`
- `AVCaptureDeviceInput.cinematicVideoCaptureEnabled`
- `AVCaptureDeviceInput.simulatedAperture`
- Cinematic focus APIs on `AVCaptureDevice`

However, this should not be treated as part of the first V2 core. The SDK states that `AVCaptureDepthDataOutput` is not supported when Cinematic video capture is enabled. Running both in the same capture session can throw an exception. That means:

- Cinematic capture and raw `AVCaptureDepthDataOutput` streaming are separate capture modes.
- Filmtone should not assume it can capture Cinematic video and raw depth maps at the same time.
- Apple Log / ProRes / gyro / Cinematic coexistence must be proven by runtime format enumeration and real-device tests before being positioned as a product feature.

Product implication:

Cinematic depth is worth tracking, but it should be framed as a later "Cinematic import depth" or "Cinematic tools" lane, not a dependency for the V2 capture/gyro/realtime-preview proof.

## Recommended V2 Scope

V2 should be framed as:

"Capture in Filmtone, finish in Filmtone, hand off motion data cleanly when stabilization matters."

Core V2:

1. Native capture screen.
2. Runtime camera-format capability scanner.
3. Apple Log / Apple Log 2 capture when supported.
4. HEVC fallback only when explicitly labeled as non-ProRes.
5. capture-time Filmtone preview LUT.
6. Core Motion recorder.
7. `.gcsv` sidecar writer.
8. post-capture import into existing editor.
9. realtime editing preview refinement.

Defer:

- app-internal Gyroflow Core stabilization
- live Gyroflow stabilization
- polished gimbal-specific capture presets before the base gyro proof passes
- Cinematic depth / Cinematic capture support
- cloud/account workflows
- advanced clip library
- broad camera/lens profile database
- excessive QA matrix before the capture/motion proof works

## First Spike

Build one hidden/debug capture surface, not a polished camera UI.

Target clip:

- 30 seconds
- fixed rear lens
- fixed resolution/fps
- Apple Log if supported
- ProRes or HEVC depending on device capability
- no lens switching
- no cinematic/slo-mo/timelapse
- no decorative UI

Record:

- video file
- per-frame video PTS summary
- gyro samples
- accelerometer samples
- observed sample-rate stats
- dropped-frame count if using `AVCaptureVideoDataOutput`
- generated `.gcsv`

Pass conditions:

- motion samples cover the full video duration
- median gyro interval is close to requested interval
- max timestamp gap is explainable and acceptable
- first/last video PTS align with motion timeline after offset mapping
- Gyroflow loads `.gcsv` next to the video
- Gyroflow sync/optical-flow view can align motion and image
- simple handheld pan stabilizes without obvious phase error

Fail conditions:

- motion sampling collapses during ProRes writes
- PTS and motion timestamps drift unpredictably
- Gyroflow cannot align without manual guesswork every time
- iPhone stabilization / lens processing makes the gyro path disagree with the image path

## Open Questions

- Which capture path should be the first spike: `AVCaptureMovieFileOutput` plus parallel `AVCaptureVideoDataOutput`, or full `AVCaptureVideoDataOutput + AVAssetWriter`?
- What is the highest stable Core Motion sample rate during Log/ProRes capture on the target device?
- Can Filmtone force or detect the capture stabilization mode needed for Gyroflow compatibility?
- What lens profile can be trusted for iPhone wide / main / tele lenses?
- Can rolling-shutter readout be sourced from metadata, measured once, or must it be user/profile-provided?
- How accurate is the current Apple Log 2 Rec.2020 approximation against real Apple Log 2 footage?
- Which phone-side stabilization settings can Filmtone detect or control, and how do they affect Gyroflow sync?
- What are the best default Gyroflow settings for gimbal footage where post stabilization is only residual cleanup?
- Can `cinematicDisparityTrack` be converted cleanly into Filmtone's existing `FilmtoneDepthMap` path?
- Which devices/formats allow Cinematic capture, Apple Log / ProRes capture, and gyro recording in the combinations Filmtone would actually expose?

## Source Links

- Apple ProRes on iPhone:
  - https://support.apple.com/en-us/109041
- `AVCaptureColorSpace`:
  - https://developer.apple.com/documentation/avfoundation/avcapturecolorspace
- Recording video in Apple ProRes:
  - https://developer.apple.com/documentation/technotes/tn3104-recording-video-in-apple-prores
- `AVCaptureVideoDataOutput`:
  - https://developer.apple.com/documentation/avfoundation/avcapturevideodataoutput
- Cinematic framework:
  - https://developer.apple.com/documentation/cinematic
- `CNAssetInfo`:
  - https://developer.apple.com/documentation/cinematic/cnassetinfo
- `CNRenderingSession`:
  - https://developer.apple.com/documentation/cinematic/cnrenderingsession
- `AVCaptureDepthDataOutput`:
  - https://developer.apple.com/documentation/avfoundation/avcapturedepthdataoutput
- Capture cinematic video in your app:
  - https://developer.apple.com/videos/play/wwdc2025/319/
- Core Motion:
  - https://developer.apple.com/documentation/coremotion/
- `CMMotionManager.gyroUpdateInterval`:
  - https://developer.apple.com/documentation/coremotion/cmmotionmanager/gyroupdateinterval
- `CMLogItem.timestamp`:
  - https://developer.apple.com/documentation/coremotion/cmlogitem/timestamp
- Gyroflow GCSV format:
  - https://docs.gyroflow.xyz/app/technical-details/gcsv-format
- Gyroflow Core:
  - https://docs.gyroflow.xyz/app/technical-details/gyroflow-core
- Gyroflow live feed stabilization:
  - https://docs.gyroflow.xyz/app/advanced-usage/live-feed-stabilization
- Gyroflow basic usage:
  - https://docs.gyroflow.xyz/app/getting-started/basic-usage
- Gyroflow stabilization controls:
  - https://docs.gyroflow.xyz/app/getting-started/basic-usage/stabilization
- Gyroflow common filming tips:
  - https://docs.gyroflow.xyz/app/getting-started/common-filming-tips-and-issues

## Next Action

Do not start with a full camera product UI.

Start with a debug-only capture spike that proves:

- capture works
- motion samples are recorded during capture
- timestamps can be aligned
- Gyroflow can consume the sidecar
- Filmtone preview can show the active look without color-path dishonesty

If that spike passes, V2 is feasible as a serious product upgrade. If it fails, keep Apple Log capture and realtime preview, but reposition Gyroflow as experimental/export-only until the sync layer is solved.
