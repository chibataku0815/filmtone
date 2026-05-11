# Active - Phase 2B-10C Video Export Queue Bundle

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video export queue orchestration out of
`FilmtoneExportSession.exportVideo`.
Commit: `90553a4d` (`refactor(ios): extract export video queue pumps`)

## Owner Directive

- Use a larger, product-coherent bundle. The previous 10A/10B helper
  extractions were intentionally small to isolate timing/depth risk; from
  this point, avoid one-helper commits when adjacent queue lifecycle code
  can move together without changing behavior.
- Essence first: shrink `FilmtoneExportSession` toward the thin
  orchestrator target. This sub-stage should remove a meaningful block of
  `exportVideo(...)`, not only one local helper cluster.
- Product quality is the bar: dispatch-group balance, writer/input
  finishing, cancellation-on-first-failure, video sample selection,
  timeline mapping, audio preservation, progress cadence, and frame
  append ordering must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. Use independent helper types under
  `Export/Internal/`.

## Goal

Create a single larger extraction bundle for the video export queues:

1. `ExportVideoCompletionCoordinator`
   - owns dispatch group, completion/failure locks, finished flags,
     captured error, input finishing, reader/writer cancellation on first
     failure, waiting, and captured-error throw handoff.
2. `ExportVideoFramePump`
   - owns the video queue body: decode sample pull, previous/lookahead
     selection, source-reader exhaustion, output-frame loop index,
     per-frame progress emission, and delegation to a render/append
     closure.
3. `ExportVideoAudioPump`
   - owns the audio queue body: audio sample pull, reader failure check,
     AAC append through `ExportMediaWriter`, and finish/failure
     delegation through the completion coordinator.

This is still not the full video pipeline extraction. Keep writer/reader
setup, `AVAssetReader`/`AVAssetWriter` creation, `ExportVideoTimeline`,
`ExportVideoDepthMatcher`, `appendOutputFrame(...)`,
`prepareDepthForSourceTime(...)`, render stage order, sidecar fields, and
`CompletedExport` assembly on `FilmtoneExportSession` for now.

## Current Worktree Note

There is already a partial uncommitted 10C implementation in the worktree:

- `Export/Internal/ExportVideoCompletionCoordinator.swift`
- `FilmtoneExportSession.swift` rewired to use
  `completionCoordinator`

Treat that as the first piece of this larger bundle, not as a finished
sub-stage. Complete pbxproj registration only as part of the whole bundle
commit, together with the frame/audio pump extraction.

## Intended Implementation Shape

### 1. Completion Coordinator

Keep or complete:

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

Preserve first-error-wins semantics and one `DispatchGroup.leave()` per
entered side.

### 2. Video Frame Pump

Add:

```swift
final class ExportVideoFramePump {
    struct AppendRequest {
        let sample: ExportVideoTimeline.TimedSample
        let outputPresentationTime: CMTime
        let sourceLookupTime: CMTime
        let sourceSegmentIndex: Int?
    }

    init(
        videoInput: AVAssetWriterInput,
        videoOutput: AVAssetReaderTrackOutput,
        reader: AVAssetReader,
        videoQueue: DispatchQueue,
        timeline: ExportVideoTimeline,
        completion: ExportVideoCompletionCoordinator,
        performanceMetrics: FilmtoneExportPerformanceMetrics,
        signposter: OSSignposter
    )

    private(set) var renderedFrames: Int { get }

    func start(
        progress: @escaping (Phase0ExportProgressDTO) -> Void,
        checkCancelled: @escaping () throws -> Void,
        appendFrame: @escaping (AppendRequest) throws -> Void
    )
}
```

The pump should own the old local state:

- `previousVideoSample`
- `lookaheadVideoSample`
- `sourceReaderExhausted`
- `nextOutputFrameIndex`
- `renderedFrames`

The pump must keep the old sample-selection rule:

- decode first sample into `previous`
- decode lookahead when available
- compare `previous.timelineTime` and `lookahead.timelineTime` to
  `timeline.sourceLookupTime(for:)`
- choose the nearest sample by
  `ExportMediaWriter.absoluteSecondsBetween`
- when source is exhausted, keep using the last `previous` sample

The session should keep `appendOutputFrame(...)` and pass it as the
`appendFrame` closure. That preserves depth preparation, motion blur
reset, render, and frame append ordering.

### 3. Audio Pump

Add:

```swift
final class ExportVideoAudioPump {
    init(
        audioInput: AVAssetWriterInput,
        audioOutput: AVAssetReaderTrackOutput,
        reader: AVAssetReader,
        writer: AVAssetWriter,
        audioQueue: DispatchQueue,
        mediaWriter: ExportMediaWriter,
        completion: ExportVideoCompletionCoordinator
    )

    func start(checkCancelled: @escaping () throws -> Void)
}
```

Only instantiate/start it when both `audioInput` and `audioOutput` are
non-nil. Preserve the old body:

- stop when a captured error exists
- pull `audioOutput.copyNextSampleBuffer()`
- if nil and reader failed, throw existing localized reader error
- if nil and reader did not fail, finish audio input
- append via `mediaWriter.appendAudioSample(...)`
- route errors to `completion.failExport(error)`

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove local completion lifecycle state/helpers
  - remove video queue sample-selection body from the session
  - remove audio queue body from the session
  - keep writer/reader setup, `appendOutputFrame`, depth/timeline/grade
    orchestration, and `CompletedExport` assembly
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoCompletionCoordinator.swift`
  - new or complete existing untracked file
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoFramePump.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoAudioPump.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for all new files
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-10b-export-video-timeline-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift`
  - output/source timing contract
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoDepthMatcher.swift`
  - depth matching contract, unchanged here
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  - frame append primitive, unchanged here
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - audio append / timing helpers, unchanged here

## Checklist

- [x] Complete `ExportVideoCompletionCoordinator` and pbxproj-register it.
- [x] Create `ExportVideoFramePump.swift` and move video queue sample
  decode / lookahead / output-frame loop state into it.
- [x] Create `ExportVideoAudioPump.swift` and move audio queue sample pull
  / append body into it.
- [x] Rewire `FilmtoneExportSession.exportVideo(...)` to instantiate the
  coordinator and pumps, start them, wait through the coordinator, and
  read `videoFramePump.renderedFrames` for final progress/result.
- [x] Preserve `appendOutputFrame(...)` on the session and call it through
  the frame pump closure.
- [x] Preserve progress cadence: first rendered frame and every 12 frames.
- [x] Preserve video sample selection and end-of-source last-frame reuse.
- [x] Preserve audio preservation gate:
  `highlightTimeline == nil && request.output.preserveAudio`.
- [x] Preserve first-error-wins cancellation semantics.
- [x] Register all new Swift files in pbxproj 4 sections.
- [x] Verify declaration/body-removal grep on `FilmtoneExportSession.swift`
  has no stale local lifecycle or pump state declarations:
  `rg -n "completionLock|failureLock|dispatchGroup|videoInputFinished|audioInputFinished|capturedError|previousVideoSample|lookaheadVideoSample|sourceReaderExhausted|nextOutputFrameIndex|func finishVideoInput|func finishAudioInput|func failExport|videoOutput\\.copyNextSampleBuffer\\(|audioOutput\\.copyNextSampleBuffer\\(" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [x] `grep -c 'ExportVideoCompletionCoordinator.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `grep -c 'ExportVideoFramePump.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `grep -c 'ExportVideoAudioPump.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this larger bundle:

- pbxproj 4-section grep for all 3 new files
- stale local lifecycle / pump-state grep on `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in this sub-stage unless implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.exportVideo(...)` no longer owns dispatch-group
  lifecycle, first-error capture, video sample lookahead state, or audio
  sample pump body.
- `ExportVideoCompletionCoordinator` owns completion/failure lifecycle
  and preserves first-error-wins semantics.
- `ExportVideoFramePump` owns video queue sample decode / selection /
  output-frame loop state and preserves nearest-sample selection.
- `ExportVideoAudioPump` owns the audio queue body and preserves AAC
  append/cancel/finish behavior.
- `appendOutputFrame(...)` remains session-owned and is invoked through a
  closure, preserving depth preparation → motion blur reset → render /
  append ordering.
- The session still waits for media queues before recording media-pipeline
  elapsed time, checking captured error, checking reader status, and
  finishing the writer.
- Reader/writer setup, timeline math, depth matcher behavior, render
  stage order, progress cadence, audio preservation gate, public API,
  sidecar schema, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving queue orchestration forces changes to writer/reader setup,
  timeline math, depth matcher behavior, render stage order, sidecar
  fields, export settings, or public API. Stop and record the blocker
  instead of widening scope.

## Out Of Scope

- Full export video setup extraction.
- Writer/reader construction changes.
- `ExportMediaWriter` helper changes.
- `ExportVideoTimeline` behavior changes.
- `ExportVideoDepthMatcher` behavior changes.
- `ExportFrameAppender` behavior changes.
- Motion blur, grade, optics, sidecar, connect package, preview, still
  export, or mezzanine routing changes.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Line / File Deltas

Bundle delta vs `main` HEAD (pre-10C):

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1296 → 1127 (−169 net; +53 / −222 vs HEAD).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoCompletionCoordinator.swift`:
  new, 119 lines.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoFramePump.swift`:
  new, 191 lines.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoAudioPump.swift`:
  new, 84 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  3 new files × 4 sections (`PBXBuildFile` + `PBXFileReference` +
  `PBXGroup Internal` + `PBXSourcesBuildPhase`). IDs assigned:
  - CompletionCoordinator: `B1E10001000000000000B221` (build) /
    `B1E10001000000000000B222` (ref)
  - FramePump: `B1E10001000000000000B223` (build) /
    `B1E10001000000000000B224` (ref)
  - AudioPump: `B1E10001000000000000B225` (build) /
    `B1E10001000000000000B226` (ref)

## Gate Results

- `grep -c 'ExportVideoCompletionCoordinator.swift' project.pbxproj`: **4**
- `grep -c 'ExportVideoFramePump.swift' project.pbxproj`: **4**
- `grep -c 'ExportVideoAudioPump.swift' project.pbxproj`: **4**
- Strict ripgrep on `FilmtoneExportSession.swift` for
  `completionLock|failureLock|dispatchGroup|videoInputFinished|audioInputFinished|capturedError|previousVideoSample|lookaheadVideoSample|sourceReaderExhausted|nextOutputFrameIndex|func finishVideoInput|func finishAudioInput|func failExport|videoOutput\.copyNextSampleBuffer\(|audioOutput\.copyNextSampleBuffer\(`:
  **0 hits** (rg exit=1).
- `bun run verify:ios`: **exit 0** — all sub-gates green (generated
  swift contract drift / ios build / grain catalog / swift contract /
  motion blur math / cube parser / capture transform LUT classifier /
  cache store / source-color-classifier / ray-angle optics / source
  profile math / D-Log / D-Log M+D-Gamut M / C-Log / C-Log 3+Cinema
  Gamut / V-Log / S-Log3 accuracy gates with max |Δ|=0.000000 and
  ΔE2000 max=0.000 / look×veil 10/10 / sidecar builder).
- `git diff --check`: **exit 0** (no whitespace anomalies).

## Behavior Equivalence

Verified by code comparison vs pre-10C inline body. Invariants
preserved:

1. **Dispatch group enter/leave count**: video side `enter()` always
   called once, balanced by exactly one `finishVideoInput` `leave()`.
   Audio side `enter()` is gated by the session's `if let audioInput,
   let audioOutput` block and balanced by exactly one
   `finishAudioInput` `leave()` (pre-lock `guard let audioInput` in
   `finishAudioInput` suppresses leave when `audioInput` is nil).
2. **First-error-wins**: `ExportVideoCompletionCoordinator.failExport`
   stores the error under `failureLock` only if `capturedError == nil`,
   then early-returns for non-first callers. Only the first caller
   cancels reader/writer and finishes both inputs.
3. **Reader/writer cancel order**: `reader.cancelReading()` →
   `writer.cancelWriting()` → `finishVideoInput(markAsFinished: true)`
   → `finishAudioInput(markAsFinished: true)`.
4. **`finishVideoInput` / `finishAudioInput` idempotence**: each
   acquires `completionLock`, checks `!videoInputFinished` /
   `!audioInputFinished`, marks input finished only on first call,
   sets the flag, leaves the group exactly once.
5. **`audioInputFinished` initial value**: `audioInput == nil` at
   `init`, preserving the no-audio short-circuit path.
6. **Video sample selection rule**: identical decode-then-lookahead
   sequence, identical `CMTimeCompare(sourceTime, lookahead.timelineTime)
   < 0` gate, identical `ExportMediaWriter.absoluteSecondsBetween`
   tie-break (`previousDelta <= lookaheadDelta`).
7. **End-of-source last-frame reuse**: `sourceReaderExhausted &&
   previousVideoSample != nil` branch re-appends `previous` at the
   next output frame index without re-decoding.
8. **Decode telemetry path**: every `videoOutput.copyNextSampleBuffer()`
   in the frame pump is wrapped in
   `performanceMetrics.measure(.decode) { signposter.withIntervalSignpost("decode") { ... } }`,
   matching the pre-10C call sites at session.swift:802-806 and
   819-823.
9. **Reader-failure error message**: `FilmtoneMediaError.exportFailed(
   reader.error?.localizedDescription ?? "Video read failed.")` and
   `"Audio read failed."` strings preserved verbatim.
10. **First-frame error message**: `"The first decoded video frame
    was unavailable."` preserved verbatim.
11. **Append failure error message**: `"The decoded video sample did
    not contain an image buffer."` preserved verbatim.
12. **Progress cadence**: emit at `renderedFrames == 1 ||
    renderedFrames % 12 == 0`, with
    `progress = min(0.9, timeline.renderingProgress(presentationTime: outputTime))`,
    `currentFrame = renderedFrames`,
    `totalFrames = timeline.outputFrameCount`,
    `message = "Rendering frames"`. Emitted after a successful append
    (post-increment) in both the lookahead-selected branch and the
    exhausted-reuse branch.
13. **`appendOutputFrame` body ordering**: `prepareDepthForSourceTime`
    → motion blur reset on `sourceSegmentIndex` change →
    `frameAppender.appendVideoSample` → `appendedFrame` guard.
    Counter increments and progress emission moved to
    `ExportVideoFramePump.recordAppendedFrame`, invoked exactly when
    the closure call returns without throwing — so per-frame ordering
    is `(depth prep → motion blur reset → render/append) → (counter
    increment → progress emit)`, identical to pre-10C.
14. **Audio queue body**: identical hasCapturedError gate,
    `audioOutput.copyNextSampleBuffer()` nil-check + reader-status
    branch, `mediaWriter.appendAudioSample(...,  waitForReady: false,
    checkCancelled: checkCancelled)` invocation, and
    `completion.failExport(error)` catch.
15. **Post-wait session sequence**: `completionCoordinator.wait()` →
    `performanceMetrics.recordMediaPipeline(elapsedSince:)` →
    `try completionCoordinator.throwCapturedErrorIfNeeded()` →
    `reader.status == .failed` re-check →
    `progress(.writing, 0.92, currentFrame: videoFramePump.renderedFrames)`
    → `performanceMetrics.measure(.writerFinish) { mediaWriter.finish }`
    → `CompletedExport(frameCount: videoFramePump.renderedFrames, ...)`.
    Ordering identical; `renderedFrames` is now read from the pump
    rather than from a local var, but its value is the same count.
16. **Audio preservation gate** unchanged (still at
    `FilmtoneExportSession.exportVideo` outer scope; AudioPump is only
    instantiated inside the `if let audioInput, let audioOutput` block).
17. **Public API / sidecar schema / UI call sites / depth matcher /
    timeline / motion blur / render stage order / writer/reader setup
    / `CompletedExport` shape**: all untouched.

## Unexpected / Follow-up

None. Notes for reviewers:

- `ExportVideoCompletionCoordinator.hasCapturedError` is a
  lock-synchronized read; the pre-10C inline check was unsynchronized.
  This is a deliberate strengthening permitted by the bundle's
  read-only-predicate contract (no semantic change — predicate is
  read by the queue loops only).
- `appendOutputFrame` lost the per-frame counter increments and the
  per-frame progress emission to the pump's `recordAppendedFrame`.
  The closure-call boundary is the only point where those side effects
  could fire pre-10C; they fire at the same boundary post-10C.
- SourceKit emits transient "Cannot find type 'ExportVideoTimeline' /
  'ExportVideoCompletionCoordinator' / 'FilmtoneExportPerformanceMetrics'
  / 'Phase0ExportProgressDTO' / 'ExportMediaWriter' / 'FilmtoneMediaError'
  in scope" and "No such module 'FilmLabSwiftCore'" diagnostics while
  the new files are not yet indexed and the session's package import
  is unresolved by the indexer. `xcodebuild` is authoritative; all
  diagnostics clear at `bun run verify:ios` green.
