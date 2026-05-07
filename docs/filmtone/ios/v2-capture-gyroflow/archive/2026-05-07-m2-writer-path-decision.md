# Active - M2 Writer Path Decision

Date: 2026-05-07 JST
Status: **DECIDED 2026-05-07 JST. Path C (Quality-first dual-output) selected.**

## Milestone

M2 - Video-Only Writer Smoke

## Goal

Decide whether Filmtone can keep `AVCaptureVideoDataOutput + AVAssetWriter` as
the product writer path, or must pivot to a quality-first master path after the
M2-A blocker showed that the M1 candidate format does not deliver `x422` /
`x420` through VDO.

This active is a design decision and minimal evidence-gathering task. Do not
build the next product writer in this active.

## Edit Targets

- `docs/filmtone/ios/v2-capture-gyroflow/active.md`
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md` only for the final
  selected path / open-question update
- Optional, only if a real-device format sweep is needed:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureWriter.swift`
- Optional, only if a separate sweep helper is cleaner:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureFormatSweep.swift`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` only if a
  new Swift file is added

## Read-Only References

- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m1-capability-probe.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m2-a-writer-smoke-blocked.md`
- `apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureCapabilityProbe.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureWriter.swift`
- iPhoneOS 26.4 SDK `CoreVideo.framework/Headers/CVPixelBuffer.h`
- iPhoneOS 26.4 SDK `AVFoundation.framework/Headers/AVAssetWriterInput.h`
- iPhoneOS 26.4 SDK `AVFoundation.framework/Headers/AVCaptureVideoDataOutput.h`
- Apple TN3121 "Selecting a pixel format for an AVCaptureVideoDataOutput"
- Apple AVCaptureSession `.inputPriority` preset documentation

## Candidate Paths

- **Format search**: sweep rear Wide Apple Log 2 formats to see whether any
  `AVCaptureVideoDataOutput` configuration can deliver a real 10-bit pixel
  format. If found, keep VDO product writer path.
- **Quality-first dual output**: use `AVCaptureMovieFileOutput` for the
  ProRes Apple Log 2 master and VDO only for timing / diagnostics / preview.
  This becomes the default if no 10-bit VDO-deliverable format exists.
- **Timing-first diagnostic**: use VDO 8-bit / BGRA only as a labeled timing
  harness, never as the product capture path.

## Decision (2026-05-07 JST)

**Selected: Path C — Quality-first dual-output.**

`AVCaptureMovieFileOutput` writes the ProRes Apple Log 2 master.
`AVCaptureVideoDataOutput` runs side-by-side purely for per-frame PTS /
diagnostics / dropped-frame counts that M3 (motion-only) and M4 (combined
timing) require for Gyroflow `.gcsv` mapping.

Rationale (in order of weight):

1. **Color / container correctness.** `AVCaptureMovieFileOutput` is Apple's
   blessed path for ProRes + Apple Log capture. ProRes 422 HQ + Apple Log 2
   master metadata (NCLC color tags, codec config, fps anchor) is
   auto-handled. The VDO + `AVAssetWriter` route requires hand-rolling
   color tags and is fragile under codec / colorspace evolution.
2. **VDO 10-bit availability is uncertain, not the deciding factor.** Even
   if the M2-A ordering issue (see below) is fixed and VDO 10-bit becomes
   deliverable on `formats[56]`, MovieFileOutput is still the safer master.
   Resolving the VDO ordering question therefore does not change the
   recommendation. A focused sweep is omitted for that reason.
3. **M3+ PTS still satisfied.** VDO side-band keeps real-time
   `CMSampleBuffer.presentationTimeStamp`, dropped-frame counts, and
   per-frame diagnostics — exactly what M3 and M4 strategy.md Done
   Conditions require for `.gcsv` mapping.
4. **Path B kept as labeled fallback only.** Reused only if Path C
   verification (hardwareCost / coexistence / PTS alignment) fails on
   iPhone 17 Pro / iOS 26.4.

## VDO viability statement

VDO **as the sole product master writer path is rejected** for M2 product
capture (ProRes Apple Log 2 4K@30 on iPhone 17 Pro / iOS 26.4). VDO
remains in the design as a side-band output for timing / diagnostics under
Path C.

## Evidence Reviewed

### Apple authoritative documentation

- **Apple TN3121 "Selecting a pixel format for an AVCaptureVideoDataOutput".**
  Confirms `availableVideoPixelFormatTypes` is "dynamic, and depends on the
  activeFormat of the capture device that the AVCaptureVideoDataOutput is
  **connected to**." iPhone 13 Pro example lists 13 deliverable formats
  including 10-bit `x422`, `x420`, and the lossless / lossy 10-bit variants
  `&xv2`, `-xv2`, `&xv0`, `-xv0`. Apple Log capability did not exist on
  iPhone 13 Pro, so the example is a "good case" baseline for 10-bit
  deliverability — not a proof that Apple Log 2 + VDO 10-bit works on
  iPhone 17 Pro.
- **AVCaptureSession `.inputPriority` documentation.** Confirms "When you
  change the device's format, the session preset automatically changes to
  [.inputPriority]." Implied: device must be in the session for the
  auto-change to fire.
- **Apple Developer Forums thread "How to save 4K60 ProRes Log Video"**
  (2026 thread, 0 replies). The asker uses
  `AVCaptureSession + AVCaptureMovieFileOutput` with
  `sessionPreset = .inputPriority` for 4K60 ProRes Log capture — the
  forum-asker pattern matches Path C's master half.

### Apple sample code citation found unverifiable

The "Capturing Apple Log video" Apple sample URL cited in an external
research summary
(`developer.apple.com/documentation/avfoundation/capture_setup/capturing_apple_log_video`)
returns HTTP 404 from both `developer.apple.com` and the
`docs.developer.apple.com` markdown endpoint. Not used as evidence for the
decision.

### M2-A FourCC decoding (iPhoneOS 26.4 SDK CVPixelBuffer.h)

All 9 deliverable pixel formats reported by the M2-A run are 8-bit:

| FourCC | SDK constant | Bits | Compression |
|---|---|---|---|
| `420v` | `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange` | 8 | none |
| `420f` | `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` | 8 | none |
| `BGRA` | `kCVPixelFormatType_32BGRA` | 8 | none |
| `&8v0` | `kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarVideoRange` | 8 | lossless |
| `-8v0` | `kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange` | 8 | lossy |
| `&8f0` | `kCVPixelFormatType_Lossless_420YpCbCr8BiPlanarFullRange` | 8 | lossless |
| `-8f0` | `kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange` | 8 | lossy |
| `&BGA` | `kCVPixelFormatType_Lossless_32BGRA` | 8 | lossless |
| `-BGA` | `kCVPixelFormatType_Lossy_32BGRA` | 8 | lossy |

The SDK *does* define 10-bit `x422` / `x420` and their 10-bit lossless / lossy
variants `&xv2`, `-xv2`, `&xv0`, `-xv0`, `&xf0`. None appeared in the M2-A
deliverable list at the time of the failing query.

### Apple Log 2 candidate format inventory (Wide rear, M1 JSON)

The M1 capability JSON shows 11 Wide rear formats that runtime-report
`appleLog2`. 8 are `x422` (the format-level mediaSubType is 10-bit 4:2:2);
3 are Bayer raw (`btp2`).

| idx | mediaSubType | dim | maxFPS |
|---|---|---|---|
| **56** (M1 candidate) | x422 | 3840×2160 | 30 |
| 60 | x422 | 3840×2160 | 60 |
| 64 | x422 | 3840×2160 | 120 |
| 29 | x422 | 1920×1080 | 30 |
| 33 | x422 | 1920×1080 | 60 |
| 39 | x422 | 1920×1080 | 120 |
| 42 | x422 | 1920×1440 | 30 |
| 46 | x422 | 1920×1440 | 60 |
| 65 | btp2 | 4224×2240 | 60 |
| 66 | btp2 | 4224×2240 | 120 |
| 69 | btp2 | 4224×3024 | 60 |

Format-level mediaSubType (`x422`) is the device's *internal* capture
format. It is **distinct from** the VDO deliverable format set, which
M2-A measured at 8-bit only for `formats[56]`.

### M2-A FilmtoneCaptureWriter.swift order analysis

The M2-A configuration sequence (FilmtoneCaptureWriter.swift lines
~210–266) does not follow the order implied by Apple TN3121 +
`.inputPriority` documentation. Two ordering issues were identified:

1. **`device.activeFormat` / `device.activeColorSpace` are set before
   `addInput(_:)`.** The `.inputPriority` doc says "when you change the
   device's format, the session preset automatically changes to
   `.inputPriority`." That auto-change fires when the device is part of a
   session. M2-A sets activeFormat on a device that is not yet in the
   session.
2. **`videoOutput.availableVideoPixelFormatTypes` is queried before
   `addOutput(videoOutput)`.** TN3121 explicitly states the available list
   "depends on the activeFormat of the capture device that the
   AVCaptureVideoDataOutput is **connected to**." Pre-`addOutput`, the
   VDO is not connected.

The blocker reported in the M2-A archive (`pixelFormatNotAvailable`) is
therefore consistent with two non-exclusive root causes:

- **Cause A**: Apple Log 2 + VDO 10-bit is genuinely not deliverable on
  iPhone 17 Pro / iOS 26.4 for `formats[56]`.
- **Cause B**: The M2-A query timing was wrong (VDO not connected) and
  the actual deliverable list was not observed.

This active does not run a sweep to disambiguate Cause A vs Cause B.
Path C is selected regardless of which one is true (see Rationale §2).
Cause B is a fallback verification need only if Path C verification
fails — see "Next Active Proposal".

## Checklist

- [x] Review archived M2-A finding and confirm the blocker is correctly
  understood. (Done; ordering subtleties added as a separate observation.)
- [x] Decode every M2-A deliverable FourCC against the iPhoneOS 26.4 SDK; record
  which are 8-bit compressed variants and which, if any, are 10-bit candidates.
  (All 9 confirmed 8-bit; no 10-bit deliverable for the M2-A query state.)
- [x] Decide whether a real-device format sweep is required before choosing the
  path. (Decided: not required. Even a positive sweep would not change the
  Path C recommendation; sweep deferred to Path C fallback verification.)
- [ ] If required, sweep rear Wide formats that runtime-report Apple Log 2 and
  record `availableVideoPixelFormatTypes` per format. (Skipped per decision.)
- [x] Determine whether any VDO-deliverable 10-bit format exists for Apple Log 2.
  (Outcome: indeterminate from M2-A evidence alone due to ordering bug; Path C
  selected without resolving this.)
- [x] If 10-bit VDO exists, identify the exact device format, color space,
  pixel format, dimensions, fps, and writer codec for the next active.
  (N/A — Path C selected.)
- [x] If 10-bit VDO does not exist, reject VDO as the product writer path.
  (Done — VDO rejected as *sole* product writer; retained as side-band only.)
- [x] Choose exactly one next implementation path. (Path C — dual-output.)
- [x] Update `strategy.md` open questions with the decision only.
- [x] Record verification / evidence in this file.

## Verification

- Docs-only decision verified by:
  - Apple TN3121 (CVPixelBuffer pixel format guidance, `availableVideoPixelFormatTypes` semantics).
  - Apple `.inputPriority` preset documentation (auto-switch on activeFormat change).
  - Apple Developer Forum thread "How to save 4K60 ProRes Log Video"
    (https://developer.apple.com/forums/thread/769888) — asker pattern matches
    Path C master half.
  - iPhoneOS 26.4 SDK `CVPixelBuffer.h` FourCC table.
  - M1 capability JSON (`apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`).
  - M2-A archive `m2a-debug.log` evidence.
- `git diff --check` clean (no whitespace errors).

## Done Conditions

- [x] The lane has one explicit writer-path decision. **Path C**.
- [x] The decision says whether VDO remains viable as the product writer path.
  **VDO rejected as sole product master writer; retained as Path C timing
  side-band.**
- [x] If VDO remains viable, the next active has a concrete 10-bit deliverable
  input. (N/A — VDO rejected.)
- [x] If VDO is rejected, the next active is scoped around quality-first dual
  output. (See Next Active Proposal.)
- [x] `strategy.md` no longer leaves the M2 writer path as an open-ended
  question. (Open Questions updated; Path C recorded in Completion Log.)

## Stop Conditions

- 2 consecutive device verification failures.
- The SDK / runtime evidence is inconclusive after one focused sweep.
- The decision would change M2/M3/M4 milestone structure rather than only the
  writer implementation path.

## Out Of Scope

- Producing a final `.mov`.
- BGRA or 8-bit VDO as product capture.
- `AVCaptureMovieFileOutput` implementation.
- Motion recording.
- `.gcsv` generation.
- Editor handoff.
- Capture preview UI.
- App Store copy, screenshots, or public positioning.

## Next Active Proposal — "M2-B Path C Dual-Output Coexistence Smoke"

**Do not start in this worktree.** This is a proposal for the next active.md
on a fresh worktree, after this decision active is archived.

Goal: empirically verify Path C on iPhone 17 Pro / iOS 26.4.2 before
committing the writer wiring for the lane.

Verification items:

1. **Coexistence**: `AVCaptureMovieFileOutput` and
   `AVCaptureVideoDataOutput` can both be added to the same
   `AVCaptureSession` while `device.activeFormat = formats[56]` and
   `device.activeColorSpace = .appleLog2`. `canAddOutput(_:)` returns true
   for both.
2. **hardwareCost**: `AVCaptureSession.hardwareCost` stays at or below
   `1.0` for the configured session at 4K Apple Log 2 + ProRes 422 HQ.
3. **Master output**: `AVCaptureMovieFileOutput.setOutputSettings(_:for:)`
   on its connection accepts ProRes 422 HQ; the resulting `.mov` opens in
   `ffprobe` with codec `apch`, dimensions 3840×2160, color tagging
   consistent with Apple Log 2.
4. **PTS alignment**: VDO sample buffers' `presentationTimeStamp` and the
   `AVCaptureMovieFileOutput`-produced `.mov` PTS are derivable from the
   same `AVCaptureSession.synchronizationClock`. Anchor recorded for M3
   to map Core Motion timestamps.
5. **Failure handling**: `AVCaptureSession.wasInterruptedNotification`
   handler logs `AVCaptureSessionInterruptionReason.systemPressure` and
   any other interruption reasons; smoke aborts cleanly without writing
   incomplete output.

Frozen Inputs (carry from M1):

| Key | Value |
|---|---|
| Device | `AVCaptureDeviceTypeBuiltInWideAngleCamera` (rear) |
| `formats[..]` index | **56** (4K@30) |
| `activeColorSpace` | `.appleLog2` (rawValue 4) |
| Dimensions | 3840 × 2160 |
| Frame rate | 30 fps |
| Master codec | `.proRes422HQ` via MovieFileOutput |
| Stabilization | `.off` (forced; record applied result) |

Order to follow (per Apple TN3121 + `.inputPriority` docs):

1. `session.beginConfiguration()`
2. `session.sessionPreset = .inputPriority` (explicit, not relying on
   auto-switch)
3. `session.automaticallyConfiguresCaptureDeviceForWideColor = false`
4. `session.addInput(deviceInput)`
5. `device.lockForConfiguration()`
6. `device.activeFormat = device.formats[56]`
7. `device.activeColorSpace = .appleLog2`
8. `device.activeVideoMinFrameDuration` / `activeVideoMaxFrameDuration`
9. `device.unlockForConfiguration()`
10. `let movieFileOutput = AVCaptureMovieFileOutput()`
11. `session.canAddOutput(movieFileOutput)` → addOutput
12. Configure ProRes 422 HQ via `movieFileOutput.setOutputSettings(_:for:)`
13. `let videoDataOutput = AVCaptureVideoDataOutput()` (timing side-band)
14. `session.canAddOutput(videoDataOutput)` → addOutput
15. **Now** query `videoDataOutput.availableVideoPixelFormatTypes`
    (per TN3121 connected-to semantics)
16. Set videoDataOutput.videoSettings (preferring lossless or lossy YUV
    bi-planar per TN3121 advice; this output is timing-only so 8-bit is
    acceptable here — explicitly labeled, not used as product master)
17. `session.commitConfiguration()`
18. `AVCaptureSession.hardwareCost` log

Path B fallback: if step 11 (canAddOutput MovieFileOutput) returns false,
or step 12 fails, or hardwareCost > 1.0 at this configuration, the next
active should pivot to a corrected-ordering VDO + AVAssetWriter sweep
(testing whether the M2-A ordering bug was the sole cause of the
M2-A blocker). That fallback investigation is M2-C, not M2-B.

Out of scope for the next active:

- Audio capture / `NSMicrophoneUsageDescription`.
- Motion recording / `NSMotionUsageDescription`.
- `.gcsv` generation.
- JS bridge surface.
- Capture preview UI.
- Final product capture flows.

## Unexpected / Blockers

- None.
