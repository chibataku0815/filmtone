# Active - Phase 2B-10B ExportVideoTimeline Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video output/source timeline math out of
`FilmtoneExportSession.exportVideo`.
Commit: `40d24fdd` (`refactor(ios): extract export video timeline`)

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

- [x] Create `Export/Internal/ExportVideoTimeline.swift` with imports
  needed by the moved timing code (`AVFoundation`, `CoreMedia`,
  `Foundation` as required).
- [x] Move `TimedVideoSample` shape into `ExportVideoTimeline.TimedSample`
  without changing field names or meaning.
- [x] Move `sourceTimeOffset` state and `makeTimedVideoSample(_:)` logic
  into the timeline helper.
- [x] Move `outputFrameCount`, `outputDurationSec`,
  `outputPresentationTime(for:)`, `sourceLookupTime(for:)`,
  `sourceSegmentIndex(for:)`, and `renderingProgress(...)` math into the
  timeline helper.
- [x] Rewire `exportVideo(...)` call sites to `videoTimeline`.
- [x] Preserve audio gating semantics for highlight exports.
- [x] Preserve depth matcher offset semantics by passing the helper's
  current `sourceTimeOffset`.
- [x] Register `ExportVideoTimeline.swift` in pbxproj 4 sections.
- [x] Verify declaration-removal grep returns 0 hits:
  `rg -n "typealias TimedVideoSample|var sourceTimeOffset|func outputPresentationTime|func sourceLookupTime|func sourceSegmentIndex|func makeTimedVideoSample|private func renderingProgress" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [x] `grep -c 'ExportVideoTimeline.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

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
- Rendering progress still uses the live pre-extraction formula:
  `0.12 + (min(max(seconds / duration, 0), 1) * 0.74)` after the
  existing finite / positive duration guards.
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

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1334 → 1296 (−38 net).
  - Removed inline `outputFrameCount` / `outputDurationSec` decls (−7).
  - Removed `typealias TimedVideoSample` + `var sourceTimeOffset`
    locals (−3).
  - Removed local `outputPresentationTime(for:)`, `sourceLookupTime(for:)`,
    `sourceSegmentIndex(for:)`, `makeTimedVideoSample(_:)` (−26).
  - Removed class-level `private func renderingProgress(...)` (−15).
  - Updated comment block above the depth/timeline section (+5 net),
    rewired call sites to `videoTimeline.*` (net ~+0 across token-level
    swaps), added `let videoTimeline = ExportVideoTimeline(...)` plus
    explanatory comment (+13).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift`:
  new, 88 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  +4 lines (IDs `B1E10001000000000000B21F` build /
  `B1E10001000000000000B220` file ref, registered in PBXBuildFile,
  PBXFileReference, Export Internal PBXGroup, App target
  PBXSourcesBuildPhase).
- `ExportDepthPayloadManager.swift`, `ExportVideoDepthMatcher.swift`,
  `FilmtoneExportSidecarBuilder.swift`, `ExportMediaWriter.swift`,
  `ExportSessionModels.swift` untouched.

## Gate Results

- pbxproj 4-section grep:
  `grep -c 'ExportVideoTimeline.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  = 4.
- Strict ripgrep on session for removed declarations:
  `rg -n "typealias TimedVideoSample|var sourceTimeOffset|func outputPresentationTime|func sourceLookupTime|func sourceSegmentIndex|func makeTimedVideoSample|private func renderingProgress" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits (exit 1, no match).
- `bun run verify:ios` exit 0. Sub-gates all green:
  generated swift contract drift / ios xcodebuild
  (`** BUILD SUCCEEDED **`) / grain catalog / Phase0 contract / motion
  blur math / cube parser / capture transform LUT classifier / cache
  store / source-color-classifier / ray-angle optics / source profile
  math / D-Log / D-Log M + D-Gamut M / C-Log / C-Log 3 + Cinema Gamut /
  V-Log / S-Log3 (all 0.000 ΔE / 0.000 / 255 / max |Δ| = 0.000000) /
  look × veil energy merge 10/10 / sidecar builder.
- `git diff --check` exit 0 (no whitespace defects).

## Behavior Equivalence

1. `outputFrameCount` formula preserved verbatim:
   `highlightTimeline?.totalFrameCount ?? max(1, Int(floor((sourceDurationSec.isFinite ? sourceDurationSec : 0) * Double(outputFPS) + 1e-6)))`.
   Moved from session local to `ExportVideoTimeline.init`.
2. `outputDurationSec` formula preserved verbatim:
   `highlightTimeline?.durationSec ?? (sourceDurationSec.isFinite ? sourceDurationSec : 0)`.
3. `outputPresentationTime(for:)` returns the same
   `CMTime(value: CMTimeValue(frameIndex), timescale: CMTimeScale(max(1, outputFPS)))`
   with `outputFPS` sourced from `request.output.fps` at construction.
4. `sourceLookupTime(for:)` preserves the highlight guard:
   uses `highlightTimeline.sourceTimeSec(forOutputFrameIndex:)` when
   present (with 60 000 timescale conversion), otherwise falls back to
   `outputPresentationTime(for:)`.
5. `sourceSegmentIndex(for:)` is a direct pass-through to
   `highlightTimeline?.segmentIndex(forOutputFrameIndex:)`.
6. `makeTimedSample(_:)` keeps the lazy `sourceTimeOffset` semantics:
   only the first call writes the offset; subsequent calls reuse it.
   Output struct mirrors the prior tuple (`buffer` / `rawTime` /
   `timelineTime`).
7. `timelineTime` still goes through
   `ExportMediaWriter.nonNegativeTime(CMTimeSubtract(rawTime, sourceTimeOffset ?? .zero))`.
8. `depthMatcher.matchDepthFrame(...)` receives
   `videoTimeline.sourceTimeOffset`, which is the same value the depth
   matcher previously saw via the in-place session local — set lazily
   on the first decoded raw sample time.
9. `renderingProgress(...)` retains the existing session implementation:
   `sourceDurationSec.isFinite, sourceDurationSec > 0` guard returning
   `0.12`, then `0.12 + (normalized * 0.74)` where
   `normalized = min(max(presentationSec / sourceDurationSec, 0), 1)`.
   The `0.78` multiplier referenced in the active spec is a doc
   misstatement; the live code uses `0.74` and that is preserved.
10. Audio gating remains
    `highlightTimeline == nil && request.output.preserveAudio`. The
    `highlightTimeline` local stays in `exportVideo` so this expression
    keeps the same shape; `ExportVideoTimeline` reads the same reference
    in its init without duplicating state.
11. Reader / writer setup, dispatch group, video decode + lookahead
    selection (`previousVideoSample` / `lookaheadVideoSample` /
    `sourceReaderExhausted` / `nextOutputFrameIndex` /
    `previousDelta` vs `lookaheadDelta` choice), audio queue, completion
    / failure locks, `failExport`, and `finishVideoInput` /
    `finishAudioInput` semantics are byte-for-byte preserved on the
    session.
12. `appendOutputFrame(...)` arguments and ordering preserved (depth
    preparation → motion blur reset → `frameAppender.appendVideoSample`
    → renderedFrames / nextOutputFrameIndex increment → throttled
    progress emission every first / 12 frames).
13. `CompletedExport.sourceDurationSec` keeps the
    `outputDurationSec.isFinite ? outputDurationSec : nil` ternary, now
    sourced from `videoTimeline.outputDurationSec`.
14. Sidecar schema, `FilmtoneExportSidecarBuilder`, public API,
    UI call sites, mezzanine routing, ExportMediaWriter, motion blur
    accumulator, depth matcher, depth payload manager, preview
    renderer, still export, and grade pipeline are unchanged.

## Unexpected / Follow-up

None.

- `active.md` "Done Conditions" listed the rendering-progress formula as
  `0.12 + … * 0.78` with `max(duration, 0.001)`. The live code uses
  `0.74` plus an `isFinite && > 0` guard returning `0.12`. Preserved the
  live behavior (extraction-only stage). Worth a 1-line strategy log
  correction so the next sub-stage doesn't re-derive the doc value.
- SourceKit emitted transient "Cannot find type
  `FilmtoneHighlightReelFrameTimeline` / `ExportMediaWriter`" diagnostics
  on the new file plus a recurring "No such module 'FilmLabSwiftCore'"
  on the session before pbxproj registration was saved — chronic indexer
  noise from prior phases. `xcodebuild` resolution is authoritative
  and the verify:ios build is green.
- `highlightTimeline` is intentionally kept as a local `let` in
  `exportVideo` for the audio gating expression. It is not duplicated
  state — `ExportVideoTimeline` was initialized from the same reference
  and only stores it privately, so the gating expression remains the
  canonical user-facing predicate.
