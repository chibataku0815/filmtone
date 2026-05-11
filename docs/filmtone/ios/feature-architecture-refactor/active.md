# Active - Phase 2B-10B ExportVideoTimeline Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video output/source timeline math out of
`FilmtoneExportSession.exportVideo`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: highlight-reel timeline mapping, source
  sample time normalization, progress cadence, audio-preservation gating,
  and depth lookup offsets must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportVideoTimeline` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportVideoTimeline.swift` and move the pure video
timeline / timing helpers out of `exportVideo(...)`.

This is not the full video loop extraction. Keep reader/writer setup,
dispatch queues, sample decode, lookahead selection, frame append,
audio append, completion/failure locks, and `ExportVideoDepthMatcher`
ownership in `FilmtoneExportSession` for now. The new timeline helper
should own only output frame count / duration, source lookup mapping,
source-time-offset normalization, per-sample timeline time, segment index,
and rendering progress math.

## Current Boundary As Of 2B-10A

Inside `exportVideo(...)`, timeline responsibility currently includes:

- local `highlightTimeline` from `highlightSegments`
- local `outputFrameCount`
- local `outputDurationSec`
- local `typealias TimedVideoSample`
- local `sourceTimeOffset`
- local helpers:
  - `outputPresentationTime(for:)`
  - `sourceLookupTime(for:)`
  - `sourceSegmentIndex(for:)`
  - `makeTimedVideoSample(_:)`
- class helper:
  - `private func renderingProgress(presentationTime:sourceDurationSec:)`
- call-site dependencies:
  - audio preservation is disabled when `highlightTimeline != nil`
  - depth matcher receives the same `sourceTimeOffset`
  - frame append receives the same output presentation time, source lookup
    time, and source segment index

Move the timing math and source-time-offset state. Keep sample decode,
lookahead selection, and append scheduling on the session.

## Intended Implementation Shape

Add:

```swift
final class ExportVideoTimeline {
    struct TimedSample {
        let buffer: CMSampleBuffer
        let rawTime: CMTime
        let timelineTime: CMTime
    }

    init(
        highlightTimeline: FilmtoneHighlightReelFrameTimeline?,
        outputFPS: Int,
        sourceDurationSec: Double
    )

    var outputFrameCount: Int { get }
    var outputDurationSec: Double { get }
    var sourceTimeOffset: CMTime? { get }

    func outputPresentationTime(for frameIndex: Int) -> CMTime
    func sourceLookupTime(for frameIndex: Int) -> CMTime
    func sourceSegmentIndex(for frameIndex: Int) -> Int?
    func makeTimedSample(_ sampleBuffer: CMSampleBuffer) -> TimedSample
    func renderingProgress(presentationTime: CMTime) -> Double
}
```

Use the existing `ExportMediaWriter.validPresentationTime(for:)`,
`ExportMediaWriter.nonNegativeTime(_:)`, and
`ExportMediaWriter.absoluteSecondsBetween(_:_:)` primitives as-is. Do not
move or rename those writer helpers in this sub-stage.

In `FilmtoneExportSession`:

- construct `let videoTimeline = ExportVideoTimeline(...)` after
  `sourceDurationSec` and `highlightTimeline` are available.
- replace `outputFrameCount` / `outputDurationSec` local constants with
  `videoTimeline.outputFrameCount` / `videoTimeline.outputDurationSec`
  or local lets sourced from the helper.
- replace `TimedVideoSample` with `ExportVideoTimeline.TimedSample`.
- replace `makeTimedVideoSample(...)` call sites with
  `videoTimeline.makeTimedSample(...)`.
- replace `outputPresentationTime(for:)`,
  `sourceLookupTime(for:)`, `sourceSegmentIndex(for:)`, and
  `renderingProgress(...)` call sites with timeline delegates.
- pass `videoTimeline.sourceTimeOffset` into
  `depthMatcher.matchDepthFrame(...)` through
  `prepareDepthForSourceTime(at:)`.
- keep `highlightTimeline == nil && request.output.preserveAudio` as the
  audio gating expression, or replace it with an equivalently named
  timeline property only if doing so avoids duplicated state.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove local timeline helper declarations from `exportVideo`
  - remove `private func renderingProgress(...)`
  - delegate timeline math to `ExportVideoTimeline`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportVideoTimeline.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-10a-export-video-depth-matcher-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoDepthMatcher.swift`
  - depth matcher dependency on `sourceTimeOffset`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSessionModels.swift`
  - `FilmtoneHighlightReelFrameTimeline` mapping contract

## Checklist

- [ ] Create `Export/Internal/ExportVideoTimeline.swift` with imports
  needed by the moved timing code (`AVFoundation`, `CoreMedia`,
  `Foundation` as required).
- [ ] Move `TimedVideoSample` shape into `ExportVideoTimeline.TimedSample`
  without changing field names or meaning.
- [ ] Move `sourceTimeOffset` state and `makeTimedVideoSample(_:)` logic
  into the timeline helper.
- [ ] Move `outputFrameCount`, `outputDurationSec`,
  `outputPresentationTime(for:)`, `sourceLookupTime(for:)`,
  `sourceSegmentIndex(for:)`, and `renderingProgress(...)` math into the
  timeline helper.
- [ ] Rewire `exportVideo(...)` call sites to `videoTimeline`.
- [ ] Preserve audio gating semantics for highlight exports.
- [ ] Preserve depth matcher offset semantics by passing the helper's
  current `sourceTimeOffset`.
- [ ] Register `ExportVideoTimeline.swift` in pbxproj 4 sections.
- [ ] Verify declaration-removal grep returns 0 hits:
  `rg -n "typealias TimedVideoSample|var sourceTimeOffset|func outputPresentationTime|func sourceLookupTime|func sourceSegmentIndex|func makeTimedVideoSample|private func renderingProgress" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [ ] `grep -c 'ExportVideoTimeline.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportVideoTimeline.swift`
- timeline helper declarations removed from `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-10B unless implementation changes behavior beyond
extraction.

## Done Conditions

- Output frame count / duration computation lives in
  `ExportVideoTimeline`.
- Output presentation time remains
  `CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(max(1, request.output.fps)))`.
- Source lookup time still uses
  `highlightTimeline.sourceTimeSec(forOutputFrameIndex:)` when present,
  otherwise output presentation time.
- Source segment index still comes from
  `highlightTimeline.segmentIndex(forOutputFrameIndex:)`.
- Source sample timeline normalization still sets `sourceTimeOffset` from
  the first valid raw sample time and uses
  `ExportMediaWriter.nonNegativeTime(CMTimeSubtract(rawTime, offset))`.
- Depth matching receives the same offset value as before.
- Rendering progress still uses
  `0.12 + min(max(seconds / max(duration, 0.001), 0), 1) * 0.78`.
- Audio preservation remains disabled for highlight-reel exports.
- Reader/writer setup, dispatch group, decode loop, lookahead sample
  selection, depth preparation order, motion blur reset order, frame
  append, audio append, public API, sidecar schema, and UI call sites are
  unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving timeline math forces changes to writer/reader setup, decode loop,
  lookahead selection policy, audio pipeline, depth matcher behavior,
  render stage order, or sidecar fields. Stop and record the blocker
  instead of widening scope.

## Out Of Scope

- Full `exportVideo` loop extraction.
- Dispatch group / lock / failure lifecycle extraction.
- Video sample decode and lookahead selection changes.
- `ExportMediaWriter` helper changes.
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
