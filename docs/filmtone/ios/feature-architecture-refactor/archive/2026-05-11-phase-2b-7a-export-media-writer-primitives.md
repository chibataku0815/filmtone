# Active - Phase 2B-7A ExportMediaWriter Primitive Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Start the ExportMediaWriter split by moving writer setup,
reader-output setup, audio append, finish/wait, and CMTime helpers out of
`FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: writer settings, reader pixel formats,
  audio settings, cancellation behavior, wait timeouts, and presentation
  time math must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportMediaWriter` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportMediaWriter.swift` and move media writer /
reader primitives out of `FilmtoneExportSession`.

This is 2B-7A, not the full video-loop extraction. Keep `exportVideo` and
`exportStillImage` on `FilmtoneExportSession` for now, but route their
writer setup, reader output setup, audio append, finish/wait, and timing
helpers through `ExportMediaWriter`.

## Live Inventory As Of 2B-6A

### Methods to move

| Method | Current line | New shape |
|---|---:|---|
| `makeWriter(outputSize:)` | 1361 | `ExportMediaWriter.makeWriter(outputSize:)` |
| `makeVideoInput(outputSize:)` | 1367 | `ExportMediaWriter.makeVideoInput(outputSize:)` |
| `makeVideoReaderOutput(for:reader:codecFamily:)` | 1389 | `ExportMediaWriter.makeVideoReaderOutput(for:reader:codecFamily:)` |
| `makeAudioPipeline(for:)` | 1421 | `ExportMediaWriter.makeAudioPipeline(for:)` |
| `appendAudioSample(_:audioInput:writer:reader:waitForReady:)` | 1844 | `ExportMediaWriter.appendAudioSample(_:audioInput:writer:reader:waitForReady:checkCancelled:)` |
| `finish(writer:)` | 1862 | `ExportMediaWriter.finish(writer:checkCancelled:)` |
| `validPresentationTime(for:)` | 1882 | `ExportMediaWriter.validPresentationTime(for:)` |
| `nonNegativeTime(_:)` | 1890 | `ExportMediaWriter.nonNegativeTime(_:)` |
| `absoluteSecondsBetween(_:_:)` | 1897 | `ExportMediaWriter.absoluteSecondsBetween(_:_:)` |
| `waitUntilReadyForMoreMediaData(_:writer:reader:label:)` | 1936 | `ExportMediaWriter.waitUntilReadyForMoreMediaData(_:writer:reader:label:checkCancelled:)` |

### Cleanup in scope

`estimatedVideoFrameRate(for:)` currently has zero callers. Verify again
after the move and delete it in this sub-stage if it remains unused.

### Methods to keep on ExportSession in 2B-7A

| Method | Reason |
|---|---|
| `exportVideo(progress:highlightSegments:)` | Owns orchestration, depth matching, highlight timeline, progress, and frame loop for now. |
| `exportStillImage(progress:)` | Owns still export orchestration and still render path for now. |
| `appendVideoSample(...)` | Still calls `renderableImage`, `ciContext.render`, `attachOutputColorMetadata`, and performance signposts; move in a later writer-loop pass if needed. |
| `renderableImage` / `scaled*` / `sourceVideoImage` / `attachOutputColorMetadata` | Render pipeline and source image conversion stay on ExportSession for this sub-stage. |
| `renderingProgress` | Progress policy remains on ExportSession with the video loop for now. |
| `checkCancelled` | Session cancellation flag remains on ExportSession; pass it as a closure to writer helpers. |

## Intended Implementation Shape

Add:

```swift
final class ExportMediaWriter {
    private let outputURL: URL
    private let outputFPS: Int
    private let colorPipeline: FilmtoneColorPipelineContract

    init(
        outputURL: URL,
        outputFPS: Int,
        colorPipeline: FilmtoneColorPipelineContract
    )

    func makeWriter(outputSize: CGSize) throws -> AVAssetWriter
    func makeVideoInput(outputSize: CGSize) -> AVAssetWriterInput
    func makeVideoReaderOutput(
        for track: AVAssetTrack,
        reader: AVAssetReader,
        codecFamily: SourceCodecFamilyDTO?
    ) -> (output: AVAssetReaderTrackOutput, degradedDecodePath: Bool)?
    func makeAudioPipeline(
        for track: AVAssetTrack
    ) -> (input: AVAssetWriterInput, output: AVAssetReaderTrackOutput)
    func appendAudioSample(
        _ sampleBuffer: CMSampleBuffer,
        audioInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        waitForReady: Bool,
        checkCancelled: () throws -> Void
    ) throws
    func finish(
        writer: AVAssetWriter,
        checkCancelled: () throws -> Void
    ) throws
    func waitUntilReadyForMoreMediaData(
        _ input: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader?,
        label: String,
        checkCancelled: () throws -> Void
    ) throws

    static func validPresentationTime(for sampleBuffer: CMSampleBuffer) -> CMTime
    static func nonNegativeTime(_ time: CMTime) -> CMTime
    static func absoluteSecondsBetween(_ lhs: CMTime, _ rhs: CMTime) -> Double
}
```

In `FilmtoneExportSession`:

- add `private let mediaWriter: ExportMediaWriter`.
- initialize it after `outputURL`, `colorPipeline`, and `outputColorSpace`
  are available:
  `ExportMediaWriter(outputURL: outputURL, outputFPS: request.output.fps,
  colorPipeline: colorPipeline)`.
- replace call sites:
  - `makeWriter` → `mediaWriter.makeWriter`
  - `makeVideoInput` → `mediaWriter.makeVideoInput`
  - `makeVideoReaderOutput` → `mediaWriter.makeVideoReaderOutput`
  - `makeAudioPipeline` → `mediaWriter.makeAudioPipeline`
  - `appendAudioSample` → `mediaWriter.appendAudioSample(..., checkCancelled: checkCancelled)`
  - `finish(writer:)` → `mediaWriter.finish(writer: writer, checkCancelled: checkCancelled)`
  - `waitUntilReadyForMoreMediaData` call sites inside still/video paths →
    `mediaWriter.waitUntilReadyForMoreMediaData(..., checkCancelled: checkCancelled)`
  - `Self.validPresentationTime` / `Self.nonNegativeTime` /
    `Self.absoluteSecondsBetween` → `ExportMediaWriter.<name>`.
- keep `appendVideoSample` on ExportSession, but route its wait call to
  `mediaWriter.waitUntilReadyForMoreMediaData`.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `mediaWriter`
  - remove moved writer/reader/audio/timing helpers
  - rewire call sites
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportMediaWriter.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-6a-grade-render-pipeline-color-stages.md`
  - latest export split precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  - grade collaborator, read-only in 2B-7A
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  - optics collaborator, read-only in 2B-7A

## Checklist

- [x] Create `Export/Internal/ExportMediaWriter.swift` with imports needed
  by moved methods (`AVFoundation`, `CoreGraphics`, `CoreVideo`,
  `FilmLabSwiftCore`, `Foundation`; trim only if build feedback shows
  unused import concerns).
- [x] Add `private let mediaWriter: ExportMediaWriter` to
  `FilmtoneExportSession`.
- [x] Move the 10 methods listed in "Methods to move" into
  `ExportMediaWriter`.
- [x] Rewire all call sites listed in "Intended Implementation Shape".
- [x] Keep `appendVideoSample` on `FilmtoneExportSession` and route only
  its wait call through `mediaWriter`.
- [x] Delete `estimatedVideoFrameRate(for:)` if repeated grep confirms
  zero callers.
- [x] Register `ExportMediaWriter.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "private func (makeWriter|makeVideoInput|makeVideoReaderOutput|makeAudioPipeline|appendAudioSample|finish|waitUntilReadyForMoreMediaData|estimatedVideoFrameRate)|private static func (validPresentationTime|nonNegativeTime|absoluteSecondsBetween)" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [x] Verify `appendVideoSample` still exists on ExportSession.
- [x] `grep -c 'ExportMediaWriter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportMediaWriter.swift`
- moved writer/timing method grep shows ExportSession no longer declares
  those helpers
- `appendVideoSample` still exists on ExportSession
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-7A unless implementation changes behavior beyond extraction.

## Done Conditions

- `FilmtoneExportSession.swift` delegates writer setup, video reader output
  setup, audio pipeline setup, audio append, finish, wait, and CMTime helper
  work to `ExportMediaWriter`.
- Writer output settings remain equivalent:
  - `.mp4`
  - H.264 codec
  - `AVVideoAverageBitRateKey = max(width * height * 6, 3_000_000)`
  - `AVVideoExpectedSourceFrameRateKey = request.output.fps`
  - `AVVideoProfileLevelH264HighAutoLevel`
  - `AVVideoAllowFrameReorderingKey = false`
  - `colorPipeline.writerColorProperties`
- Reader output pixel format candidate order remains equivalent:
  ProRes 422 → `422YpCbCr16`, `64RGBAHalf`, `32BGRA`; non-ProRes →
  `32BGRA`.
- Audio output/input settings remain equivalent.
- Wait timeout remains 15 seconds; finish timeout remains 30 seconds.
- Cancellation checks still use ExportSession's `checkCancelled`.
- `exportVideo`, `exportStillImage`, `appendVideoSample`, render image
  conversion, sidecar schema/order, and public API remain unchanged.
- `bun run verify:ios` and `git diff --check` are green.

## Stop Conditions

- Stop if moving primitives requires changing video frame loop order,
  depth matching, highlight-reel timeline selection, or render timing.
- Stop if writer/reader settings need to change.
- Stop if `appendVideoSample` must move in this sub-stage to make the build
  pass; that is a larger writer-loop extraction and should be scoped
  separately.
- Stop if sidecar schema/order or `FilmtoneExportSidecarBuilder` needs to
  change.
- Stop after 3 consecutive build or `verify:ios` failures.

## Out Of Scope

- Moving `exportVideo` or `exportStillImage`.
- Moving `appendVideoSample`.
- Moving render image conversion (`renderableImage`, `sourceVideoImage`,
  `attachOutputColorMetadata`, scaled source helpers).
- Changing `GradeRenderPipeline` or `OpticsCompositor`.
- Export performance metric redesign.
- Phase 2C parity fixtures.
- New XCTest, simulator smoke, or formal QA matrix.
- Any view code or public DTO/API schema change.

## Copy / History Impact

No copy/history impact expected: this is an internal iOS export
architecture extraction with no user-facing copy, release claim, or public
implementation-history wording change.

Article Opportunity: Developer note only after the broader ExportSession
split is complete, not for this sub-stage alone.

Change-History Opportunity: Mention in the eventual lane summary that
writer/reader primitives became an explicit `ExportMediaWriter` boundary
before the full video-loop extraction.

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  2262 → 2080 lines (−182). 11 method declarations removed (10 moved + 1
  unused `estimatedVideoFrameRate` deletion).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`:
  new file, 231 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  +4 lines (IDs `B1E10001000000000000B20D` build / `B1E10001000000000000B20E` ref).
- `outputURL` init switched to a local `let` so `mediaWriter` can be
  constructed from the same value used to assign `self.outputURL`.

## Gate Results

- `rg` for moved private/static helpers on `FilmtoneExportSession.swift`:
  0 hits.
- `appendVideoSample` still defined on `FilmtoneExportSession` (line 1697).
- `grep -c 'ExportMediaWriter.swift' project.pbxproj`: 4.
- `bun run verify:ios`: exit 0 (ios build, grain catalog, swift contract,
  motion blur math, cube parser, capture LUT classifier, cache store, source
  color classifier, ray-angle optics, source profile math, D-Log / D-Log M /
  C-Log / C-Log 3 / V-Log / S-Log3 accuracy, look × veil energy merge,
  sidecar builder — all PASS).
- `git diff --check`: exit 0.

## Unexpected / Follow-up

- None.
