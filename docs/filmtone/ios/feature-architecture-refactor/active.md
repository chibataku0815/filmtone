# Active - Phase 2B-10C ExportVideoCompletionCoordinator Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video export completion / failure lifecycle out of
`FilmtoneExportSession.exportVideo`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: dispatch-group balance, writer/input
  finishing, cancellation-on-first-failure, captured-error precedence,
  and audio/video queue shutdown semantics must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportVideoCompletionCoordinator` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportVideoCompletionCoordinator.swift` and move
the local completion / failure lifecycle helpers out of
`exportVideo(...)`.

This is not the full video loop extraction. Keep writer/reader setup,
video sample decode, lookahead selection, depth matching, timeline
mapping, frame append, audio append body, and render stage order on
`FilmtoneExportSession` for now. The new coordinator should own only the
dispatch group, completion/failure locks, finished flags, captured error,
input finishing, reader/writer cancellation on first failure, waiting,
and captured-error throw handoff.

## Current Boundary As Of 2B-10B

Inside `exportVideo(...)`, completion responsibility currently includes:

- local state:
  - `completionLock`
  - `failureLock`
  - `dispatchGroup`
  - `videoInputFinished`
  - `audioInputFinished`
  - `capturedError`
- local helpers:
  - `finishVideoInput(markAsFinished:)`
  - `finishAudioInput(markAsFinished:)`
  - `failExport(_:)`
- call-site dependencies:
  - both media queues check `capturedError != nil`
  - video queue calls `finishVideoInput(markAsFinished: true)`
  - audio queue calls `finishAudioInput(markAsFinished: true)`
  - catch blocks call `failExport(error)`
  - after queue registration, session calls `dispatchGroup.wait()`
  - after waiting, session throws `capturedError` if present

Move the lifecycle state and helper bodies. Keep the queue bodies and
their sample work on the session.

## Intended Implementation Shape

Add:

```swift
final class ExportVideoCompletionCoordinator {
    init(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        videoInput: AVAssetWriterInput,
        audioInput: AVAssetWriterInput?
    )

    var hasCapturedError: Bool { get }

    func enterVideo()
    func enterAudio()
    func finishVideoInput(markAsFinished: Bool)
    func finishAudioInput(markAsFinished: Bool)
    func failExport(_ error: Error)
    func wait()
    func throwCapturedErrorIfNeeded() throws
}
```

Implementation notes:

- `enterVideo()` / `enterAudio()` should be thin wrappers over the same
  `DispatchGroup.enter()` calls that currently live in the session.
- `finishVideoInput(markAsFinished:)` must keep the exact lock /
  already-finished guard / optional `markAsFinished()` / finished flag /
  `dispatchGroup.leave()` ordering.
- `finishAudioInput(markAsFinished:)` must keep the exact `guard let
  audioInput else { return }` behavior before locking.
- `failExport(_:)` must keep first-error-wins semantics:
  lock failure, set captured error only when nil, unlock, return if this
  was not the first error, then cancel reader/writer and finish both
  inputs with `markAsFinished: true`.
- `hasCapturedError` may lock around the read, but it must remain a
  read-only predicate used by the queue loops.

In `FilmtoneExportSession`:

- replace local completion state and helper declarations with
  `let completionCoordinator = ExportVideoCompletionCoordinator(...)`.
- replace `dispatchGroup.enter()` with coordinator enter calls.
- replace `capturedError != nil` checks with
  `completionCoordinator.hasCapturedError`.
- replace `finishVideoInput`, `finishAudioInput`, `failExport`,
  `dispatchGroup.wait()`, and captured-error throw sites with the
  coordinator API.
- do not move decode, append, audio sample, or reader/writer construction
  into this coordinator.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove local lifecycle state / helpers from `exportVideo`
  - delegate lifecycle calls to `ExportVideoCompletionCoordinator`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoCompletionCoordinator.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportVideoCompletionCoordinator.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-10b-export-video-timeline-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - writer/finish primitive, read-only in this sub-stage
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift`
  - timeline state, read-only in this sub-stage

## Checklist

- [ ] Create `Export/Internal/ExportVideoCompletionCoordinator.swift`
  with `AVFoundation` / `Foundation` imports as needed.
- [ ] Move `completionLock`, `failureLock`, `dispatchGroup`,
  `videoInputFinished`, `audioInputFinished`, and `capturedError` into
  the coordinator.
- [ ] Move `finishVideoInput(markAsFinished:)`,
  `finishAudioInput(markAsFinished:)`, and `failExport(_:)` bodies into
  the coordinator without changing ordering.
- [ ] Add queue-safe `hasCapturedError`, `enterVideo`, `enterAudio`,
  `wait`, and `throwCapturedErrorIfNeeded` wrappers.
- [ ] Rewire video queue call sites to the coordinator.
- [ ] Rewire audio queue call sites to the coordinator.
- [ ] Preserve first-error-wins cancellation semantics.
- [ ] Register `ExportVideoCompletionCoordinator.swift` in pbxproj 4
  sections.
- [ ] Verify declaration-removal grep returns 0 hits:
  `rg -n "completionLock|failureLock|dispatchGroup|videoInputFinished|audioInputFinished|capturedError|func finishVideoInput|func finishAudioInput|func failExport" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [ ] `grep -c 'ExportVideoCompletionCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportVideoCompletionCoordinator.swift`
- lifecycle helper declarations removed from `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-10C unless implementation changes behavior beyond
extraction.

## Done Conditions

- Dispatch group ownership lives in `ExportVideoCompletionCoordinator`.
- Video and audio input finishing still leave the dispatch group exactly
  once per entered queue.
- `finishAudioInput(markAsFinished:)` still returns immediately when
  `audioInput` is nil.
- First captured error still wins; later failures do not overwrite it.
- Reader cancel + writer cancel still run only for the first failure.
- First failure still finishes both inputs with `markAsFinished: true`.
- Queue loops still stop when a captured error exists.
- The session still waits for the same group before checking reader
  status and finishing the writer.
- The session still throws the captured error before reader-status
  failure handling.
- Reader/writer setup, decode loop, lookahead selection, timeline math,
  depth preparation order, motion blur reset order, frame append, audio
  append, public API, sidecar schema, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving completion lifecycle forces changes to decode loop policy,
  sample selection, audio pipeline creation, writer/reader setup, frame
  append, depth matcher behavior, render stage order, or sidecar fields.
  Stop and record the blocker instead of widening scope.

## Out Of Scope

- Full `exportVideo` loop extraction.
- Video sample decode / lookahead selection extraction.
- Audio append body extraction.
- `ExportMediaWriter` helper changes.
- `ExportVideoTimeline` behavior changes.
- `ExportVideoDepthMatcher` behavior changes.
- Motion blur, grade, optics, sidecar, connect package, preview, still
  export, or mezzanine routing changes.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Line / File Deltas

Pending implementation.

## Gate Results

Pending implementation.

## Behavior Equivalence

Pending implementation.

## Unexpected / Follow-up

Pending implementation.
