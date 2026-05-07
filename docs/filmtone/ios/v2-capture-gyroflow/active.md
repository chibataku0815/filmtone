# Active: M2-A Video-Only Writer Smoke — BLOCKED on Frozen Inputs

Status: **BLOCKED 2026-05-07 JST.** Frozen Inputs broken by device truth.
Stop here. Do not pivot to BGRA / MovieFileOutput / mystery-FourCC in this
active.md — `feedback_no_silent_stream_redefine` says lane re-scope must
happen in a fresh active.md after user review (see "Scope Review Required"
below).

Date: 2026-05-07 JST
Lane: Filmtone iOS V2 Capture / Gyroflow
Branch: `feature/ios-v2-capture-m2-writer-smoke`
Worktree: `filmtone-worktrees/ios-v2-m2-writer-smoke`
Base: `origin/feature/ios-v2-capture-m1-capability-probe` (M1 head `e82ffe6a`)

## Scope

M2-A is the **first half** of strategy.md M2 "Video-Only Writer Smoke". It
proves the M1-locked capture mode can be wired into a real `AVCaptureSession`
+ `AVAssetWriter` pipeline and produce a 5-10 second `.mov` that opens in
QuickTime / `ffprobe`, with the minimum diagnostics fields the M2 Done
Conditions require.

**Deferred to M2-B (separate active.md, after M2-A archive):**

- Diagnostics formatting / schema polish.
- Multiple-mode coverage (UltraWide / Telephoto / non-WideAngle codepaths).
- Telemetry beyond the M2 Done Conditions list.
- Any debug UI, JS bridge surface, or onboarding hook.
- Motion recording, `.gcsv` generation, editor handoff, capture-time preview.
  Those belong to M3+.

## Frozen Inputs (do not redecide here)

From M1 real-device evidence (iPhone 17 Pro / iOS 26.4.2,
`apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`):

| Key                   | Value                                              |
| --------------------- | -------------------------------------------------- |
| Device                | `AVCaptureDeviceTypeBuiltInWideAngleCamera` (rear) |
| `formats[..]` index   | **56**                                             |
| Pixel format          | `x422` (10-bit 4:2:2, kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange) |
| `activeColorSpace`    | `.appleLog2` (rawValue 4, iOS 26+)                 |
| Dimensions            | 3840 × 2160                                        |
| Frame rate            | 30 fps                                             |
| `AVAssetWriter` codec | `.proRes422HQ`                                     |
| Stabilization         | `.off` (forced; record actual applied mode)        |
| Output container      | `.mov`                                             |
| Output path           | `Library/Caches/Filmtone/captures/m2a-smoke.mov`   |

If runtime cannot honor any of these (e.g., device.activeFormat = formats[56]
fails, or `.appleLog2` not selectable), **fail loudly with a clear NSLog and
abort the smoke** — do not silently fall back. M2 strategy: "No silent
capture fallback."

## Done Conditions (this active.md)

- [ ] `NSCameraUsageDescription` added to `Info.plist` (or wired through
      `Localizable.xcstrings` if existing i18n pattern requires it). Wording
      is camera-agnostic and references video capture.
- [ ] New file `FilmtoneCaptureWriter.swift` implements:
      `AVCaptureSession` + `AVCaptureDeviceInput` (Wide rear) +
      `AVCaptureVideoDataOutput` + `AVAssetWriter` + `AVAssetWriterInput`.
- [ ] `device.activeFormat = device.formats[56]` and
      `device.activeColorSpace = .appleLog2` applied between
      `lockForConfiguration` / `unlockForConfiguration`.
- [ ] `AVAssetWriterInput` `outputSettings` use
      `AVVideoCodecKey: AVVideoCodecType.proRes422HQ`,
      `AVVideoWidthKey: 3840`, `AVVideoHeightKey: 2160`.
- [ ] `AVCaptureConnection.videoRotationAngle` (or
      `videoOrientation` deprecated path) is pinned to a single explicit
      value and recorded in diagnostics.
- [ ] `connection.preferredVideoStabilizationMode = .off` is attempted;
      `connection.activeVideoStabilizationMode` is read back AFTER session
      starts and recorded in diagnostics (M2 Done #6).
- [ ] AppDelegate `#if DEBUG` launch hook runs the smoke once per Debug cold
      launch, after the M1 probe. Synchronous wrapper, async session inside.
      No JS bridge / UI surface introduced.
- [ ] Smoke records ~5-7 seconds, then `assetWriter.finishWriting { ... }`
      completes and writes a `.mov` to the internal sandbox.
- [ ] Diagnostics JSON written next to the `.mov` with at minimum:
      `writerStatus`, `firstSamplePTS`, `lastSamplePTS`, `frameCount`,
      `droppedFrameCount`, `selectedFormat` (FourCC + dims + fps),
      `colorSpace`, `fps`, `dimensions`, `orientation`,
      `requestedStabilization`, `appliedStabilization`,
      `outputPath`, `schemaVersion`.
- [ ] Pull `.mov` + diagnostics from device via `xcrun devicectl device copy
      from --domain-type appDataContainer`.
- [ ] `ffprobe` confirms: container valid, codec = ProRes 422 HQ
      (`fourcc` `apch` is the writer's emitted tag for `.proRes422HQ`),
      color transfer reflects Apple Log 2 tagging, dimensions 3840×2160,
      duration ≈ smoke duration.
- [ ] QuickTime opens the `.mov` (or, if it does not, the Unexpected
      section records the exact failure mode).
- [ ] No `AVCaptureSession.startRunning` happens outside the DEBUG smoke
      path. Release builds compile cleanly with no capture session
      side-effects.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Info.plist`
  → add `NSCameraUsageDescription`.
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureWriter.swift`
  (new) → session + writer wiring + minimal diagnostics struct.
- `apps/capacitor-film-lab-ios/ios/App/App/AppDelegate.swift`
  → add `runM2AWriterSmokeOnLaunch()` under `#if DEBUG`, called after the
  M1 probe.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  → register `FilmtoneCaptureWriter.swift` (4 sections — same pattern as
  M1's `FilmtoneCaptureCapabilityProbe.swift`).

**Out of scope (do not touch in this active.md):**

- `FilmtoneMediaPlugin.swift` (no JS bridge method in M2-A).
- `src/native/filmtoneMedia.ts` / `.web.ts` (no TS surface).
- Existing editor / library / facade code.
- `ios/App/App/public/` (regenerated dist; only re-rsync if cap sync needs).
- `Localizable.xcstrings` (M2-A wording lives in Info.plist directly; i18n
  comes in M2-B if needed).

## Verification Plan

1. `cd apps/capacitor-film-lab-ios && bun install` (worktree-fresh).
2. Copy `capacitor.config.json` and `config.xml` from main repo and rsync
   `dist/` → `ios/App/App/public/` (worktree gem-permission workaround
   inherited from M1 — see archived M1 active.md).
3. `cd ios/App && pod install`.
4. `xcodebuild -workspace App.xcworkspace -scheme App -configuration Debug
   -destination 'id=<iPhone 17 Pro UDID>' -allowProvisioningUpdates build`.
5. `xcrun devicectl device install app --device <UDID> <built .app>`.
6. `xcrun devicectl device process launch --device <UDID>
   io.fores-tone.filmtone` (cold launch → M1 probe writes capability JSON,
   then M2-A smoke records ~5-7s).
7. Wait for the diagnostics line in device console (`log stream
   --predicate 'eventMessage CONTAINS "[FilmtoneM2Smoke]"'`).
8. `xcrun devicectl device copy from --device <UDID> --domain-type
   appDataContainer --domain-identifier io.fores-tone.filmtone --source
   Library/Caches/Filmtone/captures/m2a-smoke.mov --destination <local>`.
9. Same for `m2a-writer-smoke.json`.
10. `ffprobe -hide_banner -show_streams -show_format <.mov>`.
11. Open `.mov` in QuickTime; record outcome.
12. Tick Done Conditions with evidence.

## Hard Invariants (M2-A boundary)

- **No silent fallback.** If `.appleLog2` selection fails on this device,
  the smoke aborts with a logged reason and Done Conditions stay unchecked.
- **No external SSD / security-scoped output.** Internal sandbox only
  (strategy.md Known Constraints).
- **No audio track.** Strategy says M1-M4 produce silent video; do not add
  `AVCaptureAudioDataOutput` or `NSMicrophoneUsageDescription`.
- **No JS bridge surface in M2-A.** Bridging is M2-B / M3 territory.
- **No CoreMotion.** Motion recording is M3.
- **Forbidden fallbacks:** HEVC 8-bit + Log; HEVC 10-bit; sRGB / P3 with Log
  intent; Bayer (`btp2`) writer paths. ProRes 422 HQ only this active.md.

## Real-device Findings — M2-A blocked

Run on iPhone 17 Pro (UDID `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`,
iOS 26.4.2, iPhoneOS 26.4 SDK), Debug build of branch
`feature/ios-v2-capture-m2-writer-smoke` HEAD ahead of M1.

The smoke set `device.activeFormat = formats[56]` and
`device.activeColorSpace = .appleLog2` successfully (Done Condition #3 met
at the device layer), then failed at the
`AVCaptureVideoDataOutput.availableVideoPixelFormatTypes` check. The
`m2a-debug.log` written from on-device dlog reads:

```
M2-A smoke begin
start() requesting camera authorization (status=3)
requestAccess granted=true
configureSession() — locating wide rear camera…
wide=背面カメラ formats=70
formats[56].supportedColorSpaces (raw)=0,2,3,4
activeFormat + activeColorSpace=appleLog2 applied
availableVideoPixelFormatTypes=420v(0x34323076),420f(0x34323066),BGRA(0x42475241),
                               &8v0(0x26387630),-8v0(0x2d387630),
                               &8f0(0x26386630),-8f0(0x2d386630),
                               &BGA(0x26424741),-BGA(0x2d424741)
configureSession threw: Wanted pixel format x422 not in available [
  "420v", "420f", "BGRA", "&8v0", "-8v0", "&8f0", "-8f0", "&BGA", "-BGA"
].
```

Decoded findings:

- The 9 deliverable pixel formats are `420v`, `420f`, `BGRA`, plus 6 variants
  (`&8v0`, `-8v0`, `&8f0`, `-8f0`, `&BGA`, `-BGA`).
- **`x422` (`kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange`) is not
  deliverable** by `AVCaptureVideoDataOutput` for this device + format on
  iOS 26.4. `x420` (10-bit 4:2:0) is also absent.
- **The 6 mystery FourCCs are not the iOS 26 10-bit HDR / Apple Log path.**
  They are `lossless`/`lossy` *compressed* variants of the existing 8-bit
  `420v` / `420f` / `BGRA` (per user, 2026-05-07). They do not preserve
  Apple Log 2 dynamic range.
- M1 reported `formats[56].pixelFormat = x422` correctly — but that is the
  device's *internal* capture format, not the set
  `AVCaptureVideoDataOutput` is willing to deliver. The two layers don't
  agree, and the M2-A Frozen Inputs treated them as if they did.

This means the M1 "candidate" (Wide formatIndex 56 + `appleLog2` +
ProRes 422 HQ via `AVCaptureVideoDataOutput`) is **not directly buildable**
on iOS 26.4. M1 evidence and capability probe remain valid; the broken
assumption is that the deliverable VDO format would equal the
format-level mediaSubType.

## Scope Review Required (next active.md, not this one)

Decided 2026-05-07 (user direction):

- **Do not** silently fall back to BGRA → ProRes 422 HQ in this active.md.
  Loses Apple Log 2 dynamic range at color conversion; violates strategy.md
  "No silent capture fallback".
- **Do not** silently iterate the 6 mystery FourCCs in this active.md.
  They are 8-bit compressed variants, not the HDR / 10-bit path.
- **Do not** silently switch to `AVCaptureMovieFileOutput` in this
  active.md. It would preserve native ProRes 422 HQ + Apple Log 2 master,
  but loses per-frame PTS / dropped-frame counts that M3 (motion-only) and
  M4 (combined timing) explicitly require for Gyroflow `.gcsv` mapping.

Candidate paths for the next active.md (user-led design):

1. **Quality-first dual-output**: `AVCaptureMovieFileOutput` writes the
   ProRes Apple Log 2 master, `AVCaptureVideoDataOutput` runs side-by-side
   purely for timing / diagnostic samples. Need to verify both can attach
   to the same session simultaneously on iOS 26 and that VDO timestamps
   align with the MovieFileOutput's PTS.
2. **Format search**: enumerate `availableVideoPixelFormatTypes` across
   *every* format the wide camera reports (not just `formats[56]`), and
   check whether any combination of `activeFormat` + `activeColorSpace`
   yields a 10-bit VDO-deliverable pixel format. Releases the
   `formats[56]` assumption from M1; may also require a different M3+ PTS
   / Gyroflow design.
3. **Timing-first explicit diagnostic**: VDO 8-bit / BGRA used **only as a
   diagnostic** to validate writer plumbing and timing, separately
   labeled as not-product-quality. Quality master comes from a different
   path. Acceptable as a diagnostic, not as M2 product capture.

User scoping decisions captured 2026-05-07:

- Path "BGRA fallback" alone = unacceptable (drops product quality).
- Path "iterate mystery FourCCs" = wrong premise (they are not 10-bit HDR).
- Path "format search" = candidate, but changes M3+ PTS / Gyroflow
  assumptions and must be redesigned before implementation.

The next active.md is therefore not "M2-A continued" — it is a new design
review on the Frozen Inputs. Do not start it inside this worktree.

## Halted Done Conditions

The following Done Conditions remain **unchecked**:

- [ ] `FilmtoneCaptureWriter.swift` writer wiring (file exists, but throws
      `pixelFormatNotAvailable` before configuration commits).
- [ ] AVAssetWriterInput ProRes 422 HQ output settings.
- [ ] `videoRotationAngle` pin / read-back.
- [ ] `preferredVideoStabilizationMode = .off` apply / read-back.
- [ ] AppDelegate launch hook successful smoke run (the hook fires; the
      smoke aborts cleanly).
- [ ] 5-7 second `.mov` produced.
- [ ] Diagnostics JSON next to `.mov`.
- [ ] devicectl pull of `.mov` + diagnostics.
- [ ] `ffprobe` open / QuickTime open verification.
- [ ] No release-build side-effect verified (still true at the
      `#if DEBUG` boundary; not blocked by this finding).

The following Done Conditions are **met** even though M2-A is blocked:

- [x] `NSCameraUsageDescription` added to `Info.plist`.
- [x] `device.activeFormat = formats[56]` + `activeColorSpace = .appleLog2`
      applied via `lockForConfiguration` (confirmed in
      `m2a-debug.log` line "activeFormat + activeColorSpace=appleLog2
      applied").

## Unexpected / Blockers

- **2026-05-07 — M2-A blocking finding**: `AVCaptureVideoDataOutput`'s
  deliverable pixel formats on iPhone 17 Pro / iOS 26.4 do **not** include
  `x422` or `x420` for the `formats[56]` Apple Log 2 path. The M1 candidate
  cannot be built directly through `AVCaptureVideoDataOutput +
  AVAssetWriter`. Scope review required (see "Scope Review Required"
  above).
- Inherited from M1 (already known): worktree `cap sync ios` is blocked by
  host gem permissions; workaround = copy `capacitor.config.json` + rsync
  `dist/`. AppDelegate hook is required because Capacitor bridge plugin
  `load()` does not fire on cold launch (SwiftUI rootViewController).
- New 2026-05-07: `xcrun devicectl ... --console` does not stream NSLog
  output for sandboxed iOS apps. To capture diagnostic traces from
  early-failure smoke runs, write to a fixed on-disk log path (this M2-A
  iteration uses `Library/Caches/Filmtone/captures/m2a-debug.log` via
  `dlog(_:)`) and pull via `xcrun devicectl device copy from`.

## Out of Scope / Follow-up (M2-B candidates)

- Multiple format coverage (UltraWide / Telephoto / lower-res fallback
  matrix).
- HEVC 10-bit fallback path with explicit user opt-in (strategy allows it as
  a labeled fallback).
- JS bridge surface (`startWriterSmoke` / `stopWriterSmoke` /
  `getWriterDiagnostics`).
- Capture preview (M6 territory but may surface earlier as a M2-B follow-up
  if exposure decisions need it).
- Diagnostics schema versioning policy beyond v1.
- Owner-facing UI button to trigger record / stop.
- Telemetry export to host / share sheet.
