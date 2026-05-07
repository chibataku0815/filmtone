# Active: M6 AVFoundation Stabilization Smoke

Date: 2026-05-07 JST
Worktree: `filmtone-worktrees/ios-v2-m6-avfoundation-stabilization-smoke`
Branch: `feature/ios-v2-capture-m6-avfoundation-stabilization-smoke`
Base: `eb9da63e` (M5-B BLOCKED record on top of M5-A `d0e847e1`)

## Why this active exists

M5-B closed as BLOCKED. Gyroflow v1.6.3 (macOS) is not iPhone-optimized: with
the M5-A package loaded, owner observed visual axis inversion when the
stabilization preview pipeline engaged. The recorded decision was:

- M5-A writer stays sensor-native (raw Core Motion is the honest capture
  truth, no image-frame remap baked into Filmtone).
- Gyroflow is not Filmtone's long-term motion consumer.
- Filmtone will need an iPhone-optimized motion / stabilization path.

Before committing to a from-scratch Filmtone stabilization library, this
active proves or rejects a cheaper option first: **AVFoundation built-in
video stabilization** (`AVCaptureConnection.preferredVideoStabilizationMode`
/ `activeVideoStabilizationMode`, gated per-format by
`AVCaptureDevice.Format.isVideoStabilizationModeSupported(_:)`). If Apple's
built-in stabilization is supported on the M5-A locked format and produces
acceptable on-device footage at owner-quality bar, capture-time stabilization
may be solved without a custom library — which would re-scope (or eliminate)
the Filmtone-optimized motion library lane that M5-B implied.

This active does **not** touch `.gcsv`, Core Motion writing, or Gyroflow
desktop behavior. The M5-A capture pipeline (Path C dual output:
`AVCaptureMovieFileOutput` ProRes 422 HQ Apple Log 2 master + VDO timing
side-band, plus raw gyro/accel) is reused unchanged.

## Relationship to strategy.md

`strategy.md` currently defines `M6` as "Editor Handoff And Honest Preview".
This active **reuses the `M6` label** because it is the immediate next
milestone the M5-B BLOCKED decision points to, and because the M5-B archive
already foreshadows it. Renumbering / renaming strategy.md milestones is
**out of scope for this active** and will be proposed as an explicit owner
review at active close, not baked in mid-flight.

## Done conditions (minimum)

1. M5-A capture format survives mode probing — i.e. enabling stabilization
   does not silently swap the format. Specifically: `formatIndex 56`,
   `pixelFormat = x422`, `colorSpace = AppleLog2`, `dimensions = [3840, 2160]`,
   `fps = 30`, writer codec `apch` (ProRes 422 HQ) all unchanged after a
   non-`.off` preferred mode is set.
2. Diagnostics include the full supported-modes set for the active format,
   evaluated against the iOS 26 cases: `.standard`, `.cinematic`,
   `.cinematicExtended`, `.previewOptimized`,
   `.cinematicExtendedEnhanced`, `.lowLatency`, `.auto`. Diagnostics also
   include the chosen `preferred` mode and the observed `active` mode after
   `startRecording`.
3. `activeVideoStabilizationMode != .off` is asserted as a smoke gate when
   the env-requested preferred mode was non-`.off`. If `.off`, the smoke
   FAILs and records the format / preferred / active / device snapshot —
   no silent fallback.
4. Two real-device 30s clips exist for off/on visual A/B:
   - one stabilization-off package (M5 conditions, baseline),
   - one stabilization-on package using the highest supported mode for the
     M5-A format (or the env-specified mode).
   Both packages are pullable via the existing M5 pull workflow and carry
   the diagnostics fields above.
5. The on-clip preserves Apple Log 2: `colorSpace == AppleLog2` after
   recording. Any silent downgrade to Log 1 / Rec.709 / non-Log is a
   Stop Condition.

## Owner Stop Conditions

- `format.isVideoStabilizationModeSupported(mode) == true` but
  `activeVideoStabilizationMode == .off` after recording with that mode set
  on `preferredVideoStabilizationMode` → STOP, escalate, no auto-fallback.
- Format silently swapped by AVFoundation when stabilization engages
  (`formatIndex`, `pixelFormat`, `colorSpace`, `dimensions`, `fps`, codec
  any of these change vs. M5-A baseline) → STOP, record the swap.
- Apple Log 2 → Log 1 downgrade when stabilization engages → STOP.
- ProRes 422 HQ → HEVC writer downgrade when stabilization engages → STOP.
- Stabilized footage shows visible warping / unacceptable crop / temporal
  artefacts at owner inspection → record artefact category, do not auto-pick
  another mode without owner review.

## Out of scope (do not silently expand)

- `.gcsv` / Core Motion writing changes.
- Gyroflow desktop validation.
- Custom Filmtone stabilization library implementation.
- Editor handoff / honest-preview work (existing strategy.md M6 scope).
- Rolling-shutter coefficient calibration (M5-C deferred).
- Audio capture / `NSMicrophoneUsageDescription` / external SSD output.
- App Store copy, broad device coverage, marketing.

## 30-min granular subtasks

1. **Locate single edit site.** Read M5-A capture wiring under
   `apps/capacitor-film-lab-ios/ios/App/App/` to find the
   `AVCaptureMovieFileOutput` configuration point and the existing
   stabilization-off enforcement (M2 Done: "Video stabilization is forced
   off when controllable"). Document the file path and one-line summary
   in this active before any code edit.
2. **Supported-modes probe.** For the M5-A active format, evaluate
   `format.isVideoStabilizationModeSupported(_:)` against every iOS 26
   `AVCaptureVideoStabilizationMode` case and write the resulting set to
   `m5-combined-timing.json` (or a sibling key — name decided in subtask 1).
   Default code path keeps preferred = `.off` (M5 behavior unchanged).
3. **Env-gated preferred mode.** Add an explicit env, e.g.
   `FILMTONE_M6_STABILIZATION_MODE=cinematicExtended`, that sets
   `connection.preferredVideoStabilizationMode` after the format is locked
   and before `startRecording`. Unrecognized values FAIL fast with the
   supported set echoed.
4. **Active-mode capture + Stop Condition gate.** After `startRecording`,
   read `connection.activeVideoStabilizationMode` and write it to
   diagnostics. Add the Done #3 / Stop Condition gate: assert
   `active != .off` when env requested non-`.off`; emit
   `smokeError` and exit non-zero on violation.
5. **Off + on real-device runs.** One `FILMTONE_M6_STABILIZATION_MODE`
   unset (M5 baseline parity) + one set to the highest supported mode from
   subtask 2's supported set. Pull both packages.
6. **Findings.** Append a "Findings" section to this active with: supported
   modes list, chosen preferred mode, observed active mode, format /
   colorSpace / codec parity verdict vs. M5-A baseline, owner visual A/B
   verdict at owner-quality bar (off vs. on, single 30s pan or handheld
   walk).

## Verification status

- [x] Subtask 1: single edit site identified —
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneGcsvSmoke.swift`
  L441-458 (stabilization-off enforcement) + diagnostics plumbing at
  L226-229 / L525-532 / L974-977. Implementation choice: **fork into
  new file** rather than modify in place, matching the M5-A → M4 fork
  precedent (M5-A archive at `d0e847e1` is truth-gated and frozen;
  modifying it requires re-running M5-A's PASS state to keep the
  archive valid). New file:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStabilizationSmoke.swift`.
- [x] Subtask 2: supported-modes probe + diagnostics field —
  `Self.candidateStabilizationModes` filtered by
  `lockedFormat.isVideoStabilizationModeSupported(_:)`; results written
  to `video.movieStabilization.supportedModes` /
  `video.movieStabilization.supportedModesRaw` in
  `m6-combined-timing.json`.
- [x] Subtask 3: env-gated preferred mode wiring —
  `FILMTONE_M6_STABILIZATION_MODE` parsed via
  `parseRequestedStabilizationMode()` (case-insensitive, unset → `.off`,
  unrecognized → `unrecognizedStabilizationModeEnv` SmokeError),
  applied to MovieFileOutput connection only; VDO timing side-band
  stays `.off` regardless. Unsupported-on-format requested mode →
  `unsupportedStabilizationModeForFormat` before recording.
- [x] Subtask 4: active-mode capture + Stop Condition gate —
  `captureActiveStabilizationStateAfterRecordStart()` re-reads
  `activeVideoStabilizationMode` (movie + vdo) +
  `device.activeColorSpace.rawValue` +
  `device.activeFormat === device.formats[lockedFormatIndex]`
  inside both `didStartRecordingTo` overloads (iOS 18.2+ startPTS
  variant + pre-18.2 fallback). Stop Conditions evaluated in
  `stopMotionAndAssemble()`:
  (a) requested != .off but active == .off →
  `stabilizationActiveModeOff`,
  (b) `colorSpaceRaw != 4 (AppleLog2)` →
  `stabilizationColorSpaceDowngraded`. Build verified:
  `xcodebuild -workspace App.xcworkspace -scheme App -destination
  'generic/platform=iOS' -configuration Debug build` →
  **BUILD SUCCEEDED**, zero warnings on new file. AppDelegate
  dispatcher wired (`FILMTONE_SMOKE_LANE=m6` →
  `runM6StabilizationSmokeOnLaunch`).
- [x] Subtask 5: off + on packages pulled (real-device runs) —
  iPhone 17 Pro (7) / iOS 26.4.2 / device id
  `3A2A3A66-D092-5F87-8CE7-9A1EBD238FE9`. Three packages on
  host:
  `/tmp/filmtone-m6-pull/run1-final/m6-package-dba11d83-3e89-4e6c-8ced-78a10f6921f8/`
  (off, 31.8s, 2.3 GB master),
  `/tmp/filmtone-m6-pull/run2/m6-package-afff5b15-226a-4f9a-a52b-a3ac286b8506/`
  (cinematicExtendedEnhanced, 29.0s, 2.8 GB master), and
  `/tmp/filmtone-m6-pull/run3/m6-package-35687c83-4079-4bc7-9bb4-3c78132d958a/`
  (cinematicExtendedEnhanced re-run after P1/P2 fixes, 30.0s,
  2.6 GB master). Run #1 was static (device on desk) —
  diagnostic-only baseline, not used for visual A/B. Run #2 is
  handheld pan + light shake — visual A/B judged on this clip
  alone (PASS). Run #3 verifies the new
  AVURLAsset-read codec gate and full iOS 26 stabilization mode
  candidate set (incl. `lowLatency`); diagnostic-only, no new
  visual judgment required because run #2 already covers
  `cinematicExtendedEnhanced` visually and run #3 produces the
  same active mode on the same locked format.
- [x] Subtask 6: findings recorded in this active (see "Findings" below).

## Run instructions (Subtask 5)

Two real-device runs from a clean Debug install on iPhone 17 Pro /
iOS 26.4.2. Pull packages between runs so they don't overwrite each
other in the device caches.

Baseline (M5-A parity, stabilization off):

```bash
xcrun devicectl device process launch --device <udid> \
  --environment-variables '{"FILMTONE_SMOKE_LANE":"m6","FILMTONE_M6_STABILIZATION_MODE":"off"}' \
  com.chibatakumi.film.lab.ios
```

Stabilization on (highest supported mode — confirm via the off-run's
`video.movieStabilization.supportedModes` field, then re-run with the
chosen mode):

```bash
xcrun devicectl device process launch --device <udid> \
  --environment-variables '{"FILMTONE_SMOKE_LANE":"m6","FILMTONE_M6_STABILIZATION_MODE":"cinematicExtended"}' \
  com.chibatakumi.film.lab.ios
```

Pull artifacts after each run:

```bash
xcrun devicectl device copy from --device <udid> \
  --domain-type appDataContainer \
  --domain-identifier com.chibatakumi.film.lab.ios \
  --source 'Library/Caches/Filmtone/captures' \
  --destination /tmp/filmtone-m6-pull
```

Each package directory is `m6-package-<UUID>/` with
`m6-master.mov`, `m6-motion.gcsv`, `m6-combined-timing.json`,
`m6-debug.log`.

## Findings

Verdict: **PASS**. AVFoundation built-in `cinematicExtendedEnhanced`
is acceptable as Filmtone capture-time stabilization on the M5-A
locked format.

### Diagnostic axis (technical Stop Conditions)

| field | run #1 (`off`) | run #2 (`cinematicExtendedEnhanced`) | run #3 (`cinematicExtendedEnhanced`, post P1/P2) | gate |
|---|---|---|---|---|
| `requested` / `prerecord` / `active` / `applied` | `off` × 4 | `cinematicExtendedEnhanced` × 4 (raw 5) | `cinematicExtendedEnhanced` × 4 (raw 5) | active resolves to requested ✓ (Stop a clear) |
| `colorSpaceRawAfterRecordStart` | 4 (`AppleLog2`) | 4 (`AppleLog2`) | 4 (`AppleLog2`) | no Log 1 / Rec.709 downgrade ✓ (Stop b clear) |
| `activeFormatMatchesLockedAfterRecordStart` | true | true | true | no silent format swap ✓ (Stop c clear) |
| `pixelFormat` / `dimensions` / `fps` / `formatIndex` | `x422` / 3840×2160 / 30 / 56 | `x422` / 3840×2160 / 30 / 56 | `x422` / 3840×2160 / 30 / 56 | M5-A baseline preserved ✓ |
| `writer.codec` (constant) / `availableVideoCodecTypes` | `apch` / `[apch,apcn,apcs,apco]` | `apch` / `[apch,apcn,apcs,apco]` | `apch` / `[apch,apcn,apcs,apco]` | what we asked the writer to produce |
| `writer.actualMediaSubType` (AVURLAsset-read from `.mov`) | (not gated) | (not gated) | `apch` | what AVFoundation actually wrote ✓ (Stop d clear) — runs #1 / #2 lacked this gate; run #3 adds it and the on-clip clears it |
| `writer.actualMediaSubTypeMatchesExpected` | (not gated) | (not gated) | true | recorded `.mov` first video track FourCC verified |
| `vdo.stabilization.requested/prerecord/active/applied` | `off` × 4 | `off` × 4 | `off` × 4 | VDO timing side-band never receives stabilization ✓ |
| `smokeError` | none | none | none | no auto-fallback path triggered ✓ |

### Supported modes for the M5-A format (formatIndex 56)

Probed against the full iOS 26 candidate set
(`off | standard | cinematic | cinematicExtended | previewOptimized |
cinematicExtendedEnhanced | lowLatency | auto`) via
`AVCaptureDevice.Format.isVideoStabilizationModeSupported(_:)` on
iPhone 17 Pro / iOS 26.4.2 (run #3, post-P2 — earlier runs omitted
`lowLatency` from the candidate list).

Supported on this format:
`['off', 'standard', 'cinematic', 'cinematicExtended',
'cinematicExtendedEnhanced', 'auto']` (raw `[0, 1, 2, 3, 5, -1]`).

NOT supported on this format:
- `previewOptimized` (raw 4) — preview pipeline mode, not delivered
  for this 4K30 ProRes-class format.
- `lowLatency` (raw 6) — confirmed unsupported by the per-format probe.
  This is empirical evidence from the device, replacing the earlier
  "out-of-scope" assumption that the lane carried before P2.

`cinematicExtendedEnhanced` (iOS 18+) is the highest-class mode
supported on the locked format and is the chosen mode for both
visual A/B (run #2) and the post-P1/P2 codec verification (run #3).

### Owner visual judgment (run #2)

- Shake / pan suppressed: stabilization visibly effective at
  owner-quality bar.
- Apple Log 2 flat tonal range preserved at owner-quality bar — no
  visible color-space downgrade.

### Implication for the Filmtone-optimized motion library lane

M5-B BLOCKED implied a from-scratch Filmtone stabilization library
as the capture-time stabilization path. M6 PASS shows the cheaper
option (`AVCaptureConnection.preferredVideoStabilizationMode =
.cinematicExtendedEnhanced` on the M5-A locked format) clears the
technical Stop Conditions and meets the owner-quality bar without a
custom library. **Proposal (owner review required, not applied
here):** the Filmtone-optimized motion library lane re-scopes from
"stabilization library" to "post-capture motion-data uses that
AVFoundation cannot do" (e.g. honest preview overlay, exporter
metadata, future Gyroflow-equivalent off-device integrations) — or is
deprioritised entirely if no such uses are identified. Strategy.md
edit to encode this re-scope is held for owner review per the active
"propose, do not apply" rule.

### Run-time implementation notes (operational, not user-facing)

- Initial run #1 launch hit on-device `ディスクに空きがありません` during
  ProRes 4K30 ProRes 422 HQ recording due to ~5 GB of stale m2b /
  m4 / m5 packages from prior lanes still in
  `Library/Caches/Filmtone/captures/`. Resolved by
  `xcrun devicectl device uninstall app …` →
  `device install app …` of the M6 build, which clears the app
  container. devicectl has no per-file delete API; uninstall is the
  documented way to clear app cache for the next run.
- `xcrun devicectl device process launch --console
  --log-output <path>` streams NSLog to the host but does not block
  on app exit when the app stays alive (Capacitor WebView). Polling
  `Library/Caches/Filmtone/captures/m6-package-*` via
  `device copy from` on a 5s interval is the reliable completion
  signal — `--console` waiting alone times out on
  Capacitor-hosted lanes.
- Run #2 active mode reads back as `cinematicExtendedEnhanced` (raw
  5) post-`startRecording`, confirming Apple's documented behavior
  that `activeVideoStabilizationMode` resolves only after recording
  starts. Pre-record reads correctly returned the requested mode in
  this build because the connection's preferred mode was set before
  `startRecording`; pre-record value is informational only — the
  Stop Condition is gated on the post-`startRecording` value.
- Stop Condition (d) is read from the recorded `.mov` itself — the
  smoke opens an `AVURLAsset` over the master after
  `didFinishRecordingTo` fires, calls `loadTracks(withMediaType:
  .video)` and `track.load(.formatDescriptions)`, and reads the
  first video track's `CMFormatDescriptionGetMediaSubType`. Run #3
  reports `apch` for the on-clip, so we have direct evidence that
  AVFoundation did not silently downgrade ProRes 422 HQ → HEVC when
  stabilization engaged. Earlier runs #1 / #2 only had the constant
  writer.codec field in JSON (which records what we asked for, not
  what was actually written). The `writer.actualMediaSubType` /
  `writer.actualMediaSubTypeMatchesExpected` /
  `writer.actualMediaSubTypeReadError` fields were added in the
  post-P1/P2 build and are present on run #3 only.
- Stabilization mode candidate list now includes the full iOS 26
  enum, including `.lowLatency` (raw 6). The post-P2 build probes
  per-format support for every candidate and records the supported
  set authoritatively. On formatIndex 56 (4K30 ProRes Apple Log 2),
  `.lowLatency` returns false from
  `isVideoStabilizationModeSupported(_:)`, so it is empirically
  unsupported on this format on this device — recorded as fact, not
  inferred from candidate-list omissions.

## Closure rule

This active stays active until owner verdict on the off/on A/B:

- **PASS** ("AVFoundation built-in stabilization is acceptable as
  Filmtone capture-time stabilization"): close with PASS, archive this
  active under
  `archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`, append
  1-3 line completion log entry to `strategy.md`, and **propose** (not
  apply) a strategy.md re-scope of the planned Filmtone-optimized motion
  library lane. Owner reviews before strategy.md edit lands.
- **FAIL / BLOCKED** ("AVFoundation built-in stabilization is not
  acceptable"): close with FAIL/BLOCKED, archive findings, and the
  Filmtone-optimized motion library lane becomes the next active
  (defined separately, not in this active).

No silent continuation from this active into a custom-library
implementation.

## Notes

- M5-A capture format snapshot for parity check (from
  `m5-combined-timing.json`, run-local
  `m5-package-a8ca4b0a-7f8e-4747-833b-9921a56ade4f`):
  device `iPhone18,1` / iOS `26.4.2`, format `formatIndex 56`,
  `pixelFormat x422`, `colorSpace AppleLog2 (rawValue 4)`,
  `dimensions [3840, 2160]`, `fps 30`, writer `codec apch`, master
  `30.567s / 2.69 GB`, `movieRotation appliedAngle 90`,
  `movieStabilization applied off / appliedRaw 0`. M6 on-clip must match
  except `movieStabilization`.
- `synchronizationClock = HostTimeClock` is unchanged from M4 / M5-A and
  is not modified by this active.
- iPhone built-in `Camera` app uses cinematicExtended-class stabilization
  on this hardware; this active treats `cinematicExtended` /
  `cinematicExtendedEnhanced` as the highest-likelihood candidates,
  with the supported-modes probe (subtask 2) authoritative over that
  guess.
