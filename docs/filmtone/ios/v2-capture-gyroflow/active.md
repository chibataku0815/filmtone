# Active - M2-B Path C Dual-Output Coexistence Smoke

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

- [ ] Configure session with `sessionPreset = .inputPriority`.
- [ ] Add Wide rear camera input.
- [ ] Set `activeFormat = formats[56]`.
- [ ] Set `activeColorSpace = .appleLog2`.
- [ ] Set 3840x2160 @ 30 fps.
- [ ] Add `AVCaptureMovieFileOutput`.
- [ ] Configure ProRes 422 HQ output settings.
- [ ] Add `AVCaptureVideoDataOutput` as timing side-band.
- [ ] Query VDO pixel formats only after output is connected.
- [ ] Force stabilization off when controllable and record applied value.
- [ ] Log `hardwareCost`.
- [ ] Record 5-7 second `.mov`.
- [ ] Pull `.mov` and diagnostics from device.
- [ ] Verify `.mov` with `ffprobe`.
- [ ] Compare Movie output timing with VDO sample PTS.
- [ ] Record pass/fail notes.

## Verification

| Step | Status |
|---|---|
| `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` | ✅ **BUILD SUCCEEDED** (iphonesimulator26.4) |
| `git diff --check` | ✅ clean |
| Real-device run on iPhone 17 Pro / iOS 26.4.2 | ⏸ pending (user device run) |
| `ffprobe` on generated `.mov` | ⏸ pending (post device run) |
| Pulled diagnostics JSON/log | ⏸ pending (post device run) |

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

This active is **not** M2-B complete. Real-device verification (Done
Conditions and Stop Conditions) has not run yet.

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
