# Archived - M2-B Path C Dual-Output Coexistence Smoke

Date: 2026-05-07 JST

## Milestone

M2 - Video-Only Writer Smoke

## Goal

Verify Path C on iPhone 17 Pro / iOS 26.4.2:

- `AVCaptureMovieFileOutput` writes the ProRes Apple Log 2 master.
- `AVCaptureVideoDataOutput` runs side-by-side only for timing / diagnostics.
- Both outputs can coexist in one `AVCaptureSession` without exceeding hardware limits.
- Movie PTS and VDO sample PTS can be related well enough for M3/M4 timing work.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureWriter.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
- `docs/filmtone/ios/v2-capture-gyroflow/active.md`
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` only for final result
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` only if a new Swift file is added

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m2-a-writer-smoke-blocked.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m2-writer-path-decision.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m1-capability-probe.md`
- `apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`

## Checklist

- [x] Configure session with `sessionPreset = .inputPriority`.
- [x] Add Wide rear camera input.
- [x] Set `activeFormat = formats[56]`.
- [x] Set `activeColorSpace = .appleLog2`.
- [x] Set 3840x2160 @ 30 fps.
- [x] Add `AVCaptureMovieFileOutput`.
- [x] Configure ProRes 422 HQ output settings.
- [x] Add `AVCaptureVideoDataOutput` as timing side-band.
- [x] Query VDO pixel formats only after output is connected.
- [x] Force stabilization off when controllable and record applied value.
- [x] Log `hardwareCost`.
- [x] Record 5-7 second `.mov`.
- [x] Pull `.mov` and diagnostics from device.
- [x] Verify `.mov` with `ffprobe`.
- [x] Compare Movie output timing with VDO sample PTS.
- [x] Record pass/fail notes.

## Verification

| Step | Status |
|---|---|
| `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` | ✅ **BUILD SUCCEEDED** (iphonesimulator26.4) |
| `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -destination 'id=3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9' -derivedDataPath /tmp/filmtone-m2b-derived -allowProvisioningUpdates build` | ✅ **BUILD SUCCEEDED** (iPhone 17 Pro / iOS 26.4.2, signed Debug build) |
| `xcrun devicectl device install app --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 /tmp/filmtone-m2b-derived/Build/Products/Debug-iphoneos/App.app` | ✅ installed bundle `com.chibatakumi.film.lab.ios` |
| Real-device run on iPhone 17 Pro / iOS 26.4.2 | ✅ pass |
| Pulled `.mov`, diagnostics JSON, and debug log | ✅ `/tmp/filmtone-m2b-coexistence-smoke/` |
| `ffprobe -hide_banner -v error -show_streams -show_format -of json /tmp/filmtone-m2b-coexistence-smoke/m2b-master.mov` | ✅ valid QuickTime/MOV, ProRes 422 HQ (`apch`), 3840x2160, 30 fps, 6.166667s, 185 frames |
| `git diff --check` | ✅ clean |

Compilation issues caught during this lane (recorded so the next lane does
not repeat them):

1. `private func finalize()` collides with `NSObject.finalize()` on a
   class that inherits from `NSObject`. Renamed to `finalizeAndComplete()`.
2. `AVError.Code.recordingSuccessfullyFinished` is not an SDK enum case.
   `AVCaptureFileOutputRecordingDelegate` graceful-stop is signalled via
   `userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == true`.
3. The diagnostics payload as one large nested dict literal trips
   "compiler is unable to type-check this expression in reasonable time".
   Split into intermediate `let` sub-dicts.
4. VDO sample callbacks run on `vdoQueue` and write
   `vdoFirstPTS / vdoLastPTS / vdoFrameCount / vdoFirstSampleDimensions`,
   which are then read on `sessionQueue` from `finalizeAndComplete()`.
   `CMVideoDimensions` is a 2-word struct, so torn reads are possible.
   Resolved by inserting `vdoQueue.sync { }` after `session.stopRunning()`
   and before any VDO state read.

## Real-Device Findings

Run on iPhone 17 Pro (`3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`), iOS 26.4.2,
Debug build of branch `feature/ios-v2-capture-m2-b-coexistence-smoke`.

Pulled artifacts:

- `/tmp/filmtone-m2b-coexistence-smoke/m2b-master.mov` (464 MiB)
- `/tmp/filmtone-m2b-coexistence-smoke/m2b-coexistence-smoke.json`
- `/tmp/filmtone-m2b-coexistence-smoke/m2b-debug.log`

Small diagnostics evidence was also copied into the repo:

- `apps/capacitor-film-lab-ios/diagnostics/m2b-coexistence-smoke.json`
- `apps/capacitor-film-lab-ios/diagnostics/m2b-debug.log`

The large `.mov` was intentionally left in `/tmp` only.

Session / output evidence:

- `AVCaptureSessionPresetInputPriority` remained applied after commit.
- `hardwareCostAfterCommit = 0.5`.
- `AVCaptureMovieFileOutput.availableVideoCodecTypes = [apch, apcn, apcs, apco]`.
- Movie selected codec `apch` and wrote a 486,823,385-byte `.mov`.
- `AVCaptureVideoDataOutput.availableVideoPixelFormatTypes` was queried after
  `addOutput` and returned `[x422, x420, &xv2, -xv2, &xv0, -xv0]`.
- First VDO sample pixel format was `x422`; VDO captured 191 frames with 0
  dropped frames.
- Movie and VDO connections both applied 90-degree rotation and stabilization
  `off`.

`ffprobe` evidence for `m2b-master.mov`:

- Container: QuickTime / MOV, `probe_score = 100`.
- Video stream: `codec_name = prores`, `profile = HQ`,
  `codec_tag_string = apch`, `pix_fmt = yuv422p10le`.
- Dimensions / timing: 3840x2160, 30 fps, 6.166667 seconds, 185 frames.
- Color metadata visible to `ffprobe`: `color_range = tv`,
  `color_space = bt2020nc`. Apple Log 2 selection is confirmed in the runtime
  diagnostics through `activeColorSpace = .appleLog2`.
- Side data: display matrix rotation `-90` for the portrait-pinned recording.

Movie / VDO timing relationship:

- Movie `didStartSyncClockTime.seconds = 125314.8470415`.
- Movie `stopRequestedSyncClockTime.seconds = 125320.942454291`.
- VDO first sample PTS seconds `125314.648812375`.
- VDO last sample PTS seconds `125320.982291416`.
- VDO started about 0.198 seconds before MovieFileOutput's start callback and
  ended about 0.040 seconds after the stop request. Both are on the host-time
  synchronization clock, which is enough evidence for M3/M4 timing mapping.

## Done Conditions

- MovieFileOutput and VDO can both attach to the same session.
- `hardwareCost <= 1.0`.
- A ProRes 422 HQ Apple Log 2 `.mov` is produced.
- VDO sample PTS is captured during the same recording.
- Diagnostics include enough timing evidence to decide whether M3 can proceed.

## Stop Conditions

- `canAddOutput` fails for either MovieFileOutput or VDO.
- `hardwareCost > 1.0`.
- Movie output cannot produce ProRes 422 HQ Apple Log 2.
- VDO PTS cannot be related to the movie timeline.
- 2 consecutive real-device verification failures.

## Out Of Scope

- Motion recording.
- `.gcsv` generation.
- Editor handoff.
- Capture preview UI.
- JS bridge surface.
- Audio capture.
- External SSD output.
