# Active: S1 - Capture Stabilization Toggle

Date: 2026-05-09 JST
Status: Paused — code-complete, pending owner-device smoke

Paused reason: All coder-side work for S1 (stabilization toggle, package
truth, sidecar truth, F3-R DIAG overlay removal, missing-connection loud
fail) is landed and verified (`git diff --check` clean, `xcodebuild`
BUILD SUCCEEDED, `verify:swift-contract` green). The remaining done
condition is the owner-device smoke (On clip / Off clip / package +
sidecar truth / editor adoption / short export / cockpit DIAG-free
visual). That smoke can only run on owner hardware and is therefore
deferred to the owner. S2 - Active Lens Visibility starts in parallel
because it depends only on the cockpit having settled, which it has
code-side.

## Milestone

S1 - Capture Stabilization Toggle

## Goal

Add an explicit capture-time stabilization On / Off control so the owner can
shoot handheld with the current `cinematicExtendedEnhanced` baseline and shoot
on a gimbal with stabilization fully off.

This is product behavior work. Do not expand into SSD duration, preview
performance, App Store work, screenshot work, or broad QA.

## Product Locks

- Default is On.
- On means requested stabilization is `cinematicExtendedEnhanced`.
- Off means requested stabilization is `.off`.
- On must fail loudly if AVFoundation resolves the active mode to anything
  other than `cinematicExtendedEnhanced`.
- Off must fail loudly if AVFoundation resolves the active mode to anything
  other than `.off`.
- Apple Log 2, ProRes 422 HQ, 4K24, lens selection, proxy generation,
  editor adoption, and master/proxy export truth must remain unchanged.
- No automatic fallback to another stabilization mode.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCapturePackage.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCapturePackagePersistence.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureView.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Capture/FilmtoneCaptureCockpitTopBar.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift`

Only add new Swift files if the existing cockpit components become too crowded.
If a new Swift file is added, register it in the Xcode project 4-section gate.

## Read-Only References

- `docs/filmtone/ios/capture-practicality/strategy.md`
- `docs/filmtone/ios/v2-capture-gyroflow/strategy.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-07-m6-avfoundation-stabilization-smoke.md`
- `docs/filmtone/ios/v2-capture-gyroflow/archive/2026-05-08-m7-product-capture-stabilization.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`

## Checklist

- [x] Confirm current live stabilization hard-lock sites in
  `FilmtoneCaptureSession`.
- [x] Add a small capture-domain type for requested/observed stabilization
  if the existing string-only `FilmtoneCaptureParameters.stabilization`
  is too weak for package and sidecar truth.
- [x] Add view/session state for requested stabilization, defaulting to On.
- [x] Wire the capture UI control into the existing cockpit surface.
- [x] Apply requested stabilization during `prepare(lens:)`.
- [x] Update post-record active-mode gate so On expects
  `cinematicExtendedEnhanced` and Off expects `.off`.
- [x] Persist requested and observed stabilization in `capture-package.json`
  without breaking older package decode.
- [x] Carry stabilization truth into export sidecar provenance where the
  current sidecar shape supports it.
- [x] Update owner-visible error copy only where the existing failure message
  would lie for Off mode.
- [x] Run focused verification and record results here.

## Owner Findings Added During S1

- [x] Remove or hide the developer diagnostics overlay that remains visible
  after applying a Look and blocks camera controls such as ISO / Shutter.
  This is an S1 acceptance blocker because it prevents using the capture
  cockpit after exercising Look + stabilization together.

Notes:

- This is not S5 preview tuning. It is debug UI removal / gating so the
  capture controls remain reachable.
- Active lens visibility and continuous shooting are now strategy
  milestones S2 and S3; do not implement them inside this S1 active.

## Verification

Required before archive:

```bash
git diff --check
xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace \
  -scheme App -destination 'generic/platform=iOS Simulator' \
  -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

If Swift package contracts or generated bridge contracts are touched:

```bash
cd apps/capacitor-film-lab-ios
bun run verify:swift-contract
```

Device smoke before declaring product PASS:

1. Record one short clip with stabilization On.
2. Record one short clip with stabilization Off.
3. Confirm `capture-package.json` records requested and observed
   stabilization for both clips.
4. Confirm On clip still passes ProRes 422 HQ / Apple Log 2 / 4K24 / lens
   truth gates.
5. Confirm Off clip passes the same master gates and does not fail because
   active stabilization is `.off`.
6. Adopt each clip into the editor and export a short result to confirm
   master/proxy provenance remains intact.

## Done Conditions

- Capture surface can toggle stabilization On / Off before recording.
- Recording disables or locks the control so state cannot change mid-write.
- On and Off both produce explicit package truth.
- Applying a Look does not leave developer diagnostics over ISO / Shutter /
  other capture controls.
- Existing capture loop still works: record, proxy, editor adoption, export.
- Verification results are appended to this file.
- This file is moved to `archive/YYYY-MM-DD-s1-stabilization-toggle.md`.
- `strategy.md` gets only a 1-3 line completion log entry.

## Stop Conditions

Stop and report if any of these fires:

- The implementation requires changing codec, color space, fps, or lens
  contract to make Off work.
- On mode no longer resolves to `cinematicExtendedEnhanced`.
- Off mode cannot resolve to `.off` on the owner device.
- ProRes 422 HQ or Apple Log 2 downgrades under either mode.
- Three consecutive verification failures occur from the same unresolved
  root cause.
- The work starts to require S2 active-lens visibility, S3 continuous
  capture flow, S4 SSD duration, or S5 preview changes.
- Hiding the developer diagnostics requires redesigning the live-preview
  render path instead of simply removing/gating debug UI.

## Out of Scope

- SSD 5-minute recording.
- Preview smoothness, preview color, or render-loop work.
- Active lens visibility beyond preserving the current lens UI while adding
  stabilization.
- Continuous capture / "keep shooting" workflow.
- New stabilization choices such as Standard / Cinematic / Auto.
- Gyroflow motion sidecars.
- App Store metadata, screenshots, public landing-page copy.
- Broad multi-device QA.

## Unexpected Blockers

- Developer diagnostics remain visible after Look application and obstruct
  camera controls such as ISO. Must be removed or gated before S1 archive.

## Verification Log

- 2026-05-09 JST — Implementation pass (S1):
  - `git diff --check` clean across edited iOS Swift surface.
  - `xcodebuild -workspace ios/App/App.xcworkspace -scheme App
    -destination 'generic/platform=iOS Simulator' -configuration Debug
    build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **` (no
    warnings, no errors).
  - `bun run verify:swift-contract` (scripts/verify-phase0-contract.sh)
    → all sub-tests pass: phase0 contract, source-profile math (D-Log /
    D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 within budget),
    look × veil energy merge (10/10), sidecar builder.
  - No new Swift files added — S1 fits inside existing components
    (`FilmtoneCapturePackage.swift`, `FilmtoneCapturePackagePersistence.swift`,
    `FilmtoneCaptureSession.swift`, `FilmtoneCaptureCockpitTopBar.swift`,
    `FilmtoneCaptureView.swift`, `FilmtoneExportSidecarBuilder.swift`,
    `FilmtoneEditorStore.swift`), so no `project.pbxproj` 4-section
    registration was needed.
- 2026-05-09 JST — Re-verification (no code change since
  Implementation pass; both gates re-confirmed):
  - `git diff --check` clean.
  - `xcodebuild ... build CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`.
  - `bun run verify:swift-contract` → all sub-tests pass (phase0 contract,
    source-profile math, look × veil energy merge 10/10, sidecar builder).
- 2026-05-09 JST — Revision pass after owner code review caught two
  in-scope gaps:
  - Removed the F3-R DIAG developer overlay from `FilmtoneCaptureView`
    (call site + helper deleted). `activeLiveDiagnostics` state and
    `logLiveDiagnostics(_:)` are kept so engineering signal still
    reaches Console, but the cockpit no longer carries top-left
    debug chrome that obstructed ISO / Shutter visibility after a
    Look application.
  - Tightened the post-record stabilization gate in
    `FilmtoneCaptureSession`: a missing `movieOutput` connection now
    fails loudly with
    `stabilizationDowngraded(active: "connection-unavailable")`
    instead of recording the requested mode as "observed". No silent
    fallback path remains.
  - Re-ran `git diff --check` (clean), `xcodebuild ... build
    CODE_SIGNING_ALLOWED=NO` → `** BUILD SUCCEEDED **`, and
    `bun run verify:swift-contract` → all sub-tests pass.
- Device smoke (On clip / Off clip / package + sidecar truth / editor
  adoption / short export, plus visual confirmation that no F3-R DIAG
  overlay remains over the cockpit after a Look application) —
  pending owner-device run; surface is ready and quiescent.

## Implementation Notes

- New domain type `FilmtoneRequestedStabilization` (`.on` / `.off`)
  lives in `FilmtoneCapturePackage.swift` next to
  `FilmtoneCaptureParameters`. `.on -> cinematicExtendedEnhanced`,
  `.off -> .off` — the only mapping S1 ships, no fallback case.
- `FilmtoneCaptureParameters.stabilization` (legacy string) now equals
  `requestedStabilization.canonicalModeName` so pre-S1 importers keep
  reading the canonical AVFoundation mode name.
- `FilmtoneCaptureFailure.stabilizationDowngraded` now carries
  `requested:` and `active:` so the banner names which gate fired
  (e.g. "Stabilization off was rejected; active mode = cinematic").
- Session `setRequestedStabilization(_:)` is gated on `state == .ready`
  and reconfigures the live `AVCaptureSession` via
  `beginConfiguration` / `commitConfiguration`. Recording disables the
  chip in UI and the session rejects mid-record toggles.
- New cockpit chip `STAB` (one-shot toggle, `isScrubberChip == false`)
  shows `On` / `Off`. Accessibility label spells "Stabilization On" /
  "Stabilization Off". Disabled-while-recording inherits from the
  parameter chip row's existing recording guard.
- `FilmtoneCapturePackage.observedStabilization: String?` records the
  AVFoundation mode name observed at record-finish (always equal to the
  request on a clean run since the gate fails the run otherwise).
  Persisted alongside `parametersRequestedStabilization` in
  `capture-package.json` (additive, schemaVersion stays 2).
- `SidecarCaptureProvenance` extended with optional
  `requestedStabilization` + `observedStabilization` strings (encoded
  with `encodeIfPresent`). `FilmtoneEditorStore.sidecarCaptureProvenance`
  threads them from the active capture package on every export.
- Revision pass (2026-05-09 JST):
  - F3-R DIAG developer overlay removed from `FilmtoneCaptureView`. The
    overlay was anchored over the cockpit's top-leading region and
    obstructed ISO / Shutter readouts after a Look application; only
    the call site + helper were removed, the underlying diagnostics
    state and `logLiveDiagnostics(_:)` (Console signal) remain.
  - Post-record stabilization gate now fails loudly on a missing AV
    movie connection. Previously the `else` branch silently set
    `observedStabilizationName = requested.canonicalModeName`; that
    is the exact silent-fallback shape S1 forbids. Replaced with an
    explicit `state = .failed(.stabilizationDowngraded(...,
    active: "connection-unavailable"))` early return.
