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
- [ ] Run the probe on the real device and save or inspect the JSON.
  - Pending real-device run (user-driven, single Xcode Run).
  - `FilmtoneMediaPlugin.load()` now contains a `#if DEBUG` launch trigger
    (`runM1CapabilityProbeOnLaunch`) that calls
    `FilmtoneCaptureCapabilityProbe.run()` once per Debug launch, so a single
    Xcode Run on the iPhone produces the JSON without needing a JS bridge
    call. Release builds skip this path entirely.
  - Output path: `Library/Caches/Filmtone/diagnostics/m1-capability-probe.json`
    inside the app sandbox.
  - Pull from device:
    `xcrun devicectl device copy from --device <UDID> --domain-type appDataContainer --domain-identifier com.chibatakumi.film.lab.ios --source 'Library/Caches/Filmtone/diagnostics/m1-capability-probe.json' --destination apps/capacitor-film-lab-ios/diagnostics/m1-capability-probe.json`.
  - Manual JS path is also still available:
    `await window.Capacitor.Plugins.FilmtoneMedia.probeCaptureCapabilities()`.
- [ ] Record pass/fail notes in this file.
  - To be appended after the real-device run lands the JSON.

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

- [ ] `capture-capabilities.json` or equivalent returned JSON exists from a
  real device run.
- [ ] JSON includes at least one rear-camera video mode.
- [ ] Apple Log / Apple Log 2 support is present only when runtime-reported.
- [ ] Unsupported modes are represented as absent or disabled, not inferred.
- [ ] The result is specific enough to choose the M2 video-only writer mode.

All Done Conditions remain unchecked until the real-device JSON is in hand.
The implementation is structured to satisfy them by construction (no
inference, raw-value-keyed color spaces, M2 recommendation derived from
runtime data only), but evidence is required.

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
