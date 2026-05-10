# S5 - Recording Preview Performance

Date: 2026-05-10 JST

## Goal

Improve live capture preview performance when a Look is applied during
recording, especially with stabilization On, without changing the ProRes
master, package truth, editor adoption, or export-quality Look rendering.

The owner-selected product tradeoff is "Lightweight Look": recording-time live
monitoring may be lighter than export parity, but it must preserve the Look's
color direction and must make the lightweight monitor state visible.

## Edit Targets

- `FilmtoneCaptureSession.swift`
- `FilmtoneCaptureLivePreview.swift`
- `FilmtoneCaptureView.swift`
- `FilmtoneExportSession.swift`
- `docs/filmtone/ios/capture-practicality/active.md`

Read-only references:

- `docs/filmtone/ios/capture-practicality/strategy.md`
- Apple AVFoundation docs for `AVCaptureVideoDataOutput.videoSettings`,
  native pixel formats, and preview-sized output buffers.

## Product Locks

- Do not touch the `AVCaptureMovieFileOutput` master path or its gates:
  ProRes 422 HQ, Apple Log 2, 4K24, selected lens, requested/observed
  stabilization, capture rotation, package persistence, editor handoff, and
  export sidecar provenance.
- VDO remains preview-only. It must not become an alternate writer or source of
  truth.
- Recording-time live preview may use a lightweight monitor grade. Full-quality
  Look rendering remains the editor/export responsibility.
- Stabilization On for movie output must not force VDO stabilization. The VDO
  connection is monitor-only and should keep stabilization Off where supported.
- Fallback or lightweight monitor state must be visible. Do not silently present
  raw or light preview as export parity.
- Existing S6/S3/S7 dirty worktree changes are preserved. Do not revert or
  "clean up" unrelated capture work.

## Checklist

- [x] Pause the prior S6 active file before replacing `active.md`.
- [x] Add preview-output policy that prefers native/device-efficient VDO
  buffers and preview-sized dimensions when available.
- [x] Keep VDO stabilization explicitly separate from the movie connection.
- [x] Add live-preview backpressure so camera frames do not queue unbounded main
  thread draws.
- [x] Add a lightweight live-monitor grade mode that preserves input LUT, base
  tone, tone compression, creative LUT, and print color while skipping heavy
  spatial optics/grain for recording monitor use.
- [x] Switch live preview to the lightweight mode while recording with
  stabilization On, and keep full preview outside that hot path.
- [x] Surface the lightweight monitor state in the existing cockpit badge flow.
- [x] Run focused verification and record results.

## Verification

Coder-side:

- `git diff --check`
- `xcodebuild -workspace apps/capacitor-film-lab-ios/ios/App/App.xcworkspace
  -scheme App -configuration Debug -destination 'generic/platform=iOS'
  build CODE_SIGNING_ALLOWED=NO`
- `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` only if
  package, sidecar, or Swift contract shape changes.

Owner-device smoke:

1. Stabilization On + Stone / Urban / Noir / custom LUT: record 10 seconds and
   confirm preview does not visibly stall.
2. Stabilization Off + Look: confirm no regression.
3. Filmtone default / no Look: confirm raw monitor remains smooth.
4. Adopt the recorded package and export: editor/export still render full
   quality Look.
5. Confirm package/master gates still report `apch`, Apple Log 2, and the
   requested stabilization state.

## Done Conditions

- Recording with Look + stabilization On uses the lightweight monitor mode.
- Live preview frame delivery is bounded; stale frames are dropped instead of
  queued.
- VDO output is configured as a monitor source rather than a full-resolution
  BGRA processing burden where the platform supports lighter buffers.
- Lightweight monitor state is visible to the owner.
- Generic iOS xcodebuild succeeds.

## Stop Conditions

- Stop after 3 consecutive verification failures.
- Stop if changing VDO pixel format or dimensions breaks the preview on the
  generic build in a way that requires device-specific API assumptions.
- Stop if the implementation would require changing master codec/color/stab
  truth.

## Out Of Scope

- Replacing `AVCaptureMovieFileOutput`.
- Baking Looks into the recorded ProRes master.
- Export pipeline quality changes.
- New waveform / false color / focus peaking tools.
- App Store, screenshots, release metadata, or portfolio work.

## Implementation Notes

- 2026-05-10: Opened S5 performance active after owner identified the dominant
  defect: Look-applied recording is heavy, and stabilization On is the worst
  case. Prior S6 active file copied to
  `paused/2026-05-10-s6-capture-orientation-contract-paused.md`.
- 2026-05-10: Implemented the S5 monitor split. Preview VDO now requests native
  AVFoundation buffers and preview-sized output, keeps its stabilization Off,
  and records DEBUG telemetry for actual pixel format / dimensions. The frame
  sink now has single-callback backpressure and throttles recording-monitor
  draws to 12 fps. `FilmtoneSharedGradeProcessor` now has `fullPreview` and
  `recordingMonitor` modes; recordingMonitor preserves input/base/tone/creative
  LUT/print color and skips heavy spatial optics/grain. Capture UI shows
  `Live Look · Light` when recording with stabilization On and a Look processor.
- 2026-05-10: Owner interrupt after device smoke: the previous S3 take-picker
  revisions still failed both product constraints, because multiple rich take
  rows rendered inside the sheet and exact Look rendering was still reachable
  from picker-row work. Rebuilt the picker as a single focused-take inspector
  with a lightweight take selector. `FilmtoneCaptureTakePreviewModel` now owns
  focus changes, sample selection, loading state, and task cancellation;
  `FilmtoneCaptureTakePreviewLoader` samples only the focused take, caches raw
  source plus readable display stills, and exact Look / custom-LUT rendering is
  limited to the selected large still.

## Verification Log

- 2026-05-10: `git diff --check` clean.
- 2026-05-10: First generic iOS xcodebuild failed on actor isolation from the
  VDO delegate calling main-actor static helpers. Fixed by making pure
  formatting helpers `nonisolated` and adding the iOS 26 `.lowLatency`
  stabilization label.
- 2026-05-10: `xcodebuild -workspace
  apps/capacitor-film-lab-ios/ios/App/App.xcworkspace -scheme App
  -configuration Debug -destination 'generic/platform=iOS' build
  CODE_SIGNING_ALLOWED=NO` succeeded.
- 2026-05-10: Re-ran `git diff --check` and the same generic iOS xcodebuild
  after final render-mode wiring; both succeeded.
- `bun run --cwd apps/capacitor-film-lab-ios verify:swift-contract` not run;
  this task did not change package, sidecar, or Swift contract shape.
- 2026-05-10: Take-picker focused-inspector rebuild: `git diff --check` clean
  on the take-picker overlay, preview loader/model, live-preview API alignment,
  and pbxproj; pbxproj grep count is 4 for both
  `FilmtoneCaptureTakePreviewLoader.swift` and
  `FilmtoneCaptureTakePreviewModel.swift`. Fresh-DerivedData generic iOS
  xcodebuild succeeded with
  `/tmp/filmtone-take-picker-rebuild-generic`; `bun run --cwd
  apps/capacitor-film-lab-ios verify:swift-contract` passed; device xcodebuild
  succeeded with `/tmp/filmtone-take-picker-rebuild-device`; `xcrun devicectl
  device install app` installed bundle `com.chibatakumi.film.lab.ios`. No
  launch was run.
