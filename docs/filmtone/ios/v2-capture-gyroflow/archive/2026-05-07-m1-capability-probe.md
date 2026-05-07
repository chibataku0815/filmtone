# Active - M1 Capability Probe

Date: 2026-05-07 JST

## Milestone

M1 - Capability Probe

## Goal

Add the smallest hidden/debug capability probe that can enumerate the owner
device's rear-camera capture modes and return or write a JSON artifact. Do not
record video yet.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaPlugin.swift`
- `apps/capacitor-film-lab-ios/src/native/filmtoneMedia.ts`
- `apps/capacitor-film-lab-ios/src/native/filmtoneMedia.web.ts`
- `apps/capacitor-film-lab-ios/ios/App/App/Info.plist` only if the probe proves
  camera permission is required for enumeration
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` only if a
  new Swift file is added
- Optional helper if needed:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneCaptureCapabilityProbe.swift`

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- `docs/filmtone/ios/archive/legacy-handoffs-2026-04-20-to-2026-05-03/filmtone-v2-capture-gyroflow-realtime-preview-feasibility-2026-05-01-jst.md`

## Checklist

- [x] Inspect current native bridge method patterns.
  - Reviewed `FilmtoneMediaPlugin.swift:1-444` — `@PluginMethod` registration
    + `@objc func` + `Task { @MainActor in ... call.resolve(...) }` is the
    canonical async pattern (e.g. `pickSource`, `runExport`).
  - Synchronous JSON-dict resolves use the positional `call.resolve(_:)`
    overload; the `call.resolve(with:)` form requires `Encodable`.
- [x] Confirm the probe does not start `AVCaptureSession` or recording.
  - `FilmtoneCaptureCapabilityProbe.run()` only calls
    `AVCaptureDevice.DiscoverySession.devices` and reads `device.formats`.
    No `AVCaptureSession` instance is created. No `activeFormat` /
    `activeColorSpace` mutation. No `startRunning()`.
- [x] Define the minimal capability JSON fields.
  - Schema: `schemaVersion=1`, `generatedAt`, `runtime`, `devices[]`,
    `m2Recommendation`. Per-format: `mediaSubType` (4cc),
    `dimensions`, `frameRateRanges`, `supportedColorSpaces`
    (rawValue-keyed; name only when known), `supportedVideoStabilizationModes`,
    `isVideoHDRSupported`, optional `formatDescriptionExtensions`.
- [x] Enumerate rear-camera video formats and fps ranges.
  - DiscoverySession deviceTypes covers wide / ultraWide / telephoto / dual
    family / triple / trueDepth / LiDAR; iOS 17+ adds external + continuity.
- [x] Include color-space support when the runtime exposes it.
  - `format.supportedColorSpaces` is mapped through a raw-value lookup.
    Apple Log = 3, Apple Log 2 = 4 (canonical names verified via Apple
    AVCaptureColorSpace docs + WWDC 2025 references). Unknown raw values are
    surfaced as `{rawValue: N}` only — never inferred.
- [x] Include dimensions and stabilization hints when available.
  - `CMVideoFormatDescriptionGetDimensions` for size,
    `format.isVideoStabilizationModeSupported(_:)` probed against rawValues
    `-1...5` (off / standard / cinematic / cinematicExtended /
    previewOptimized / cinematicExtendedEnhanced / auto).
- [x] Record whether permission was required; if so, add only the needed usage
  key and note why.
  - **Not required for enumeration.** `AVCaptureDevice.DiscoverySession` and
    `AVCaptureDevice.Format` reads do not require `NSCameraUsageDescription`
    nor an `AVAuthorizationStatus.authorized` gate. Only
    `AVCaptureSession.startRunning()` triggers the camera prompt.
    `Info.plist` was therefore intentionally NOT modified in M1.
- [x] Expose one hidden/debug native method.
  - `FilmtoneMediaPlugin.probeCaptureCapabilities` registered alongside
    existing methods; no production UI invokes it. TS interface tags it
    `@internal` and the `.web.ts` shim throws — natural Capacitor pattern
    for "iOS-only debug" surface.
- [x] Add matching TypeScript native surface.
  - `src/native/filmtoneMedia.ts` exports
    `CaptureCapabilityProbeResult` / `...Payload` / `...Device` / `...Format` /
    `...Recommendation` interfaces; `.web.ts` throws with a clear message.
- [x] Add Xcode project references if a new Swift file is created.
  - `FilmtoneCaptureCapabilityProbe.swift` registered in all 4 pbxproj
    sections (PBXBuildFile / PBXFileReference / PBXSourcesBuildPhase /
    PBXGroup); IDs `C…002F` / `D…002F`. `grep -c` returns 4.
- [x] Run the minimum compile verification.
  - `bun run build` (tsc --noEmit + vite build): PASS.
  - `xcodebuild ... iOS Simulator Debug build CODE_SIGNING_ALLOWED=NO`:
    `** BUILD SUCCEEDED **` (log: `/tmp/m1-xcodebuild.log`).
- [x] Run the probe on the real device and save or inspect the JSON.
  - Real-device run completed 2026-05-07 ~12:02 JST on iPhone 17 Pro
    (iPhone18,1) iOS 26.4.2 (paired UDID
    `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`).
  - Trigger: `AppDelegate.application(_:didFinishLaunchingWithOptions:)` runs
    a synchronous `runM1CapabilityProbeOnLaunch()` under `#if DEBUG` before
    SwiftUI bootstrap. The original plan to hook into
    `FilmtoneMediaPlugin.load()` was abandoned because this app uses a
    SwiftUI `FilmtoneRootHostingController` as `rootViewController`, not a
    `CAPBridgeViewController` — so the Capacitor plugin's `load()` never
    fires (the bridge is only instantiated lazily for plugin calls). Logged
    in Unexpected.
  - Output path on device:
    `Library/Caches/Filmtone/diagnostics/m1-capability-probe.json`
    (resolved through `FileManager.default.url(for: .cachesDirectory)`).
  - Pulled to host via:
    `xcrun devicectl device copy from --device 3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9 --domain-type appDataContainer --domain-identifier com.chibatakumi.film.lab.ios --source 'Library/Caches/Filmtone/diagnostics/m1-capability-probe.json' --destination apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`.
  - Local artifact: `apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`
    (916 KB).
- [x] Record pass/fail notes in this file.
  - See "Real-device findings" below.

## Real-device findings (2026-05-07, iPhone 17 Pro / iOS 26.4.2)

- 10 devices total; 7 rear cameras: WideAngle / UltraWide / Telephoto /
  Dual / DualWide / Triple / LiDAR.
- All 7 rear cameras runtime-report **both** Apple Log (rawValue 3) and
  Apple Log 2 (rawValue 4) on enough formats to lock a video-only writer
  in M2.
- Pixel layouts present at the format level on the rear cameras:
  - `x422` — 10-bit 4:2:2 (the ProRes 422 / 422 HQ writer pairing)
  - `x420` — 10-bit 4:2:0 (HEVC 10-bit Log writer pairing)
  - `420v` / `420f` — 8-bit 4:2:0 (preview / non-Log capture)
  - `btp2` — Bayer pattern 10-bit (raw stills, not video)
- Resolutions on the rear WideAngle camera include 4K UHD (3840×2160),
  4K square sensor (4032×3024), and 4224×2240 / 4224×3024 high-res still.
- The recommendation logic was corrected once on a real device: the format
  level reports the **pixel format** (`x422` / `x420`), not the encoded
  codec (`ap4h` / `apch`). The encoded codec is selected at
  `AVAssetWriter` time. The probe's first run produced
  `m2Recommendation.candidate = null` because of this; the second run
  scored by pixel format and produced the candidate below.

### M2 video-only writer candidate (locked by this probe)

```jsonc
{
  "deviceUniqueID":      "com.apple.avfoundation.avcapturedevice.built-in_video:0",
  "deviceLocalizedName": "背面カメラ",
  "deviceType":          "AVCaptureDeviceTypeBuiltInWideAngleCamera",
  "formatIndex":         56,
  "pixelFormat":         "x422",
  "writerCandidate":     "ProRes422HQ",
  "colorSpace":          "appleLog2",
  "dimensions":          { "width": 3840, "height": 2160 },
  "fps":                 30,
  "score":               1300
}
```

M2 should configure the capture session with:
- `device.activeFormat = device.formats[56]` on the BuiltInWideAngleCamera
  (uniqueID above).
- `device.activeColorSpace = .appleLog2`.
- An `AVAssetWriter` video input with codec type `.proRes422HQ`,
  10-bit 4:2:2 source pixel format, 3840×2160 @ 30 fps.

## Verification

- `bun run build` (tsc --noEmit + vite build): **PASS** (2026-05-07).
- `xcodebuild -workspace ios/App/App.xcworkspace -scheme App -destination 'generic/platform=iOS Simulator' -configuration Debug build CODE_SIGNING_ALLOWED=NO`:
  **PASS** (2026-05-07, log saved to `/tmp/m1-xcodebuild.log`).
  - Note: worktree pre-build setup required `bun install` + `pod install` +
    copying `capacitor.config.json` / `config.xml` from the main repo plus
    rsync of `dist/` → `ios/App/App/public/` (the worktree's `cap sync` was
    blocked by a host-level Bundler permission issue; the artifacts are
    deterministic from the same commit, so the workaround is safe).
- Real-device capability probe run: **PENDING (user-driven)**.
- `bun run verify:ios`: not invoked — bridge contract change is additive only
  (one new `@PluginMethod`, new TS surface; no shared-contract field rename
  or removal). Re-run if M2 expands the surface.

## Done Conditions

- [x] `capture-capabilities.json` or equivalent returned JSON exists from a
  real device run.
  - `apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json` (916 KB,
    written by AppDelegate launch trigger and pulled via devicectl).
- [x] JSON includes at least one rear-camera video mode.
  - 7 rear cameras × dozens of formats each. WideAngle reports 70 formats.
- [x] Apple Log / Apple Log 2 support is present only when runtime-reported.
  - rawValue 3 (`appleLog`) and rawValue 4 (`appleLog2`) appear only on
    formats whose `format.supportedColorSpaces` actually contains them.
    Names are mapped from raw values; unknown raw values are emitted as
    `{rawValue: N}` only — never inferred. Confirmed on iPhone 17 Pro:
    both Apple Log and Apple Log 2 are present on rear cameras.
- [x] Unsupported modes are represented as absent or disabled, not inferred.
  - The probe iterates `device.formats` and copies what the runtime reports.
    No filling-in, no defaulted color spaces, no synthesized stabilization
    modes (each is probed via `format.isVideoStabilizationModeSupported(_:)`).
- [x] The result is specific enough to choose the M2 video-only writer mode.
  - `m2Recommendation.candidate` returns concrete
    `{ deviceUniqueID, formatIndex, pixelFormat: "x422",
       writerCandidate: "ProRes422HQ", colorSpace: "appleLog2",
       dimensions: 3840×2160, fps: 30 }` — enough for M2 to lock
    `device.activeFormat` and configure `AVAssetWriter` deterministically.

## Stop Conditions

- 3 consecutive compile or device-probe failures.
- Runtime enumeration cannot expose enough data to choose a first recording
  mode.
- Required camera permission / entitlement behavior blocks the probe and needs
  a product decision.

## Out Of Scope

- Video recording.
- Motion recording.
- `.gcsv` generation.
- Capture preview UI.
- Editor handoff.
- App Store copy, screenshots, or public positioning.

## Unexpected / Blockers

- Worktree `cap sync ios` was blocked by a host-level Bundler / Ruby gem
  permission issue (`/Library/Ruby/Gems/2.6.0` is not user-writable). Workaround:
  copy `capacitor.config.json` + `config.xml` from the main repo and rsync
  `dist/` → `ios/App/App/public/`. Both reflect deterministic
  cap-sync output for the same commit, so the simulator build is exercised
  against the same Capacitor bundle. Long-term fix is unrelated to M1
  (host gem environment); flagged here so M2 does not retry the same path.
- Capacitor `call.resolve(with:)` requires `Encodable`. M1 uses
  `[String: Any]` so the positional `call.resolve(_:)` overload is the right
  call. Recorded in case M2 adds another bridge entry.
- This app is not a typical Capacitor-first app: `AppDelegate.application(_:didFinishLaunchingWithOptions:)`
  installs a SwiftUI `FilmtoneRootHostingController` as `rootViewController`
  rather than the storyboard-referenced `FilmtoneBridgeViewController`. The
  Capacitor bridge therefore never wakes on app start, and `FilmtoneMediaPlugin.load()`
  is not called during a cold launch. The launch-time M1 trigger lives in
  `AppDelegate` instead. M2 work that wants any pre-UI bridge state should
  hook into AppDelegate, not the plugin's `load()`.
- Format-level `mediaSubType` reports the **pixel format**, not the encoded
  codec. iOS rear-camera formats use `x422` (10-bit 4:2:2) / `x420` (10-bit
  4:2:0) / `420v` / `420f` — the encoded codec (ProRes vs HEVC) is chosen at
  `AVAssetWriter` time. M2 recommendation logic must score by pixel layout,
  not by codec FourCC. This was caught and fixed mid-M1 after the first
  device run produced `m2Recommendation.candidate = null`.
