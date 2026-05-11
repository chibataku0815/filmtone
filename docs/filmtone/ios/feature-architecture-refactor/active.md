# Active - Phase 2B-7B ExportFrameAppender Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Continue the ExportMediaWriter lane by moving video frame
append mechanics out of `FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: presentation timing, writer readiness,
  pixel-buffer allocation, CI render bounds/color space, output color
  metadata, append failure behavior, signposts, and performance metrics
  must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportFrameAppender` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportFrameAppender.swift` and move
`appendVideoSample(...)` out of `FilmtoneExportSession`.

This is not the full `exportVideo` loop extraction. Keep `exportVideo`,
`exportStillImage`, `renderableImage`, `applyGrade`, source conversion,
depth matching, highlight timeline, progress policy, and sidecar metrics
on `FilmtoneExportSession` for now. The appender should take a render
closure from the session so the grade/motion pipeline order remains owned
by the current session facade during this sub-stage.

## Current Boundary As Of 2B-7A

`FilmtoneExportSession.appendVideoSample(...)` currently mixes:

- writer readiness wait through `mediaWriter.waitUntilReadyForMoreMediaData`
- `CMSampleBufferGetImageBuffer`
- adaptor pixel-buffer-pool access and `CVPixelBufferPoolCreatePixelBuffer`
- source/output presentation-time resolution via `ExportMediaWriter`
  static helpers
- `performanceMetrics.measure(.buildGraph/.render/.append)`
- `signposter.withIntervalSignpost("wait-encoder" / "build-graph" /
  "render" / "append")`
- `ciContext.render(..., bounds: CGRect(origin: .zero, size: outputSize),
  colorSpace: outputColorSpace)`
- `colorPipeline.applyOutputMetadata(to:)`
- `adaptor.append(..., withPresentationTime:)`
- writer-error surfacing and `performanceMetrics.recordRenderedFrame()`

Move that mechanical append/rasterization boundary into the appender.

## Intended Implementation Shape

Add:

```swift
final class ExportFrameAppender {
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let colorPipeline: FilmtoneColorPipelineContract
    private let performanceMetrics: FilmtoneExportPerformanceMetrics
    private let signposter: OSSignposter
    private let mediaWriter: ExportMediaWriter

    init(
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        colorPipeline: FilmtoneColorPipelineContract,
        performanceMetrics: FilmtoneExportPerformanceMetrics,
        signposter: OSSignposter,
        mediaWriter: ExportMediaWriter
    )

    func appendVideoSample(
        _ sampleBuffer: CMSampleBuffer,
        videoInput: AVAssetWriterInput,
        writer: AVAssetWriter,
        reader: AVAssetReader,
        adaptor: AVAssetWriterInputPixelBufferAdaptor,
        videoTrack: AVAssetTrack,
        outputSize: CGSize,
        outputPresentationTime: CMTime?,
        renderTimeSeconds: Double?,
        waitForReady: Bool,
        checkCancelled: () throws -> Void,
        renderFrameImage: (CVPixelBuffer, CGAffineTransform, CGSize, Double) -> CIImage
    ) throws -> Bool
}
```

In `FilmtoneExportSession`:

- add `private let frameAppender: ExportFrameAppender`.
- initialize it after `mediaWriter` is available.
- replace `appendVideoSample(...)` call sites with
  `frameAppender.appendVideoSample(...)`.
- pass `checkCancelled` as a closure.
- pass a render closure that calls the existing `renderableImage(from:
  transform:outputSize:timeSeconds:)`.
- delete `FilmtoneExportSession.appendVideoSample(...)` after call sites
  are rewired.

If Swift complains about `OSSignposter` storage or import shape, keep the
same signpost labels and interval placement, but adjust the helper
dependency shape minimally. Do not remove the signposts.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `frameAppender`
  - remove `appendVideoSample(...)`
  - rewire video loop and still/video append call sites
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportFrameAppender.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-7a-export-media-writer-primitives.md`
  - latest writer split precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - writer collaborator
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  - grade collaborator, read-only in 2B-7B
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  - optics collaborator, read-only in 2B-7B

## Checklist

- [ ] Create `Export/Internal/ExportFrameAppender.swift` with the imports
  needed by the moved method (`AVFoundation`, `CoreGraphics`,
  `CoreImage`, `CoreVideo`, `FilmLabSwiftCore`, `Foundation`, `os` as
  needed by the existing signposter usage).
- [ ] Add `private let frameAppender: ExportFrameAppender` to
  `FilmtoneExportSession`.
- [ ] Initialize the appender from the existing `ciContext`,
  `outputColorSpace`, `colorPipeline`, `performanceMetrics`,
  `signposter`, and `mediaWriter` dependencies.
- [ ] Move `appendVideoSample(...)` into `ExportFrameAppender` and keep
  the body behavior equivalent.
- [ ] Replace all session call sites with `frameAppender.appendVideoSample`
  and pass a render closure to the existing `renderableImage(...)`.
- [ ] Keep `exportVideo`, `exportStillImage`, `renderableImage`,
  `applyGrade`, `applyVideoMotionStage`, `sourceVideoImage`,
  `attachOutputColorMetadata`'s behavior, depth matching, progress, and
  sidecar metrics outside this move except for the metadata application
  now performed by the appender through `colorPipeline`.
- [ ] Register `ExportFrameAppender.swift` in pbxproj 4 sections.
- [ ] Verify
  `rg -n "private func appendVideoSample|func appendVideoSample" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [ ] Verify `rg -n "appendVideoSample" apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  shows the moved appender method.
- [ ] `grep -c 'ExportFrameAppender.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportFrameAppender.swift`
- `appendVideoSample` declaration removed from `FilmtoneExportSession`
- moved method exists in `ExportFrameAppender`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-7B unless implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.swift` delegates video sample append/rasterize
  mechanics to `ExportFrameAppender`.
- Existing grade/render source remains session-owned via the render
  closure, so `applyGrade` stage order and motion blur interleave are
  unchanged.
- Existing writer readiness wait remains before image-buffer extraction
  when `waitForReady == true`.
- Presentation time math still uses `ExportMediaWriter.validPresentationTime`.
- CI render bounds remain `CGRect(origin: .zero, size: outputSize)`.
- CI render color space remains `outputColorSpace`.
- Output color metadata still uses `colorPipeline.applyOutputMetadata(to:)`.
- Append failure still throws the writer error localized description when
  present and `"The frame could not be appended."` otherwise.
- `performanceMetrics.recordRenderedFrame()` still fires after a
  successful append.
- Public API, sidecar schema, export settings, and UI call sites are
  unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving `appendVideoSample` forces `exportVideo` loop, depth matching,
  sidecar metrics, or `applyGrade` stage-order changes. Stop and record
  the blocker instead of widening scope.
- The extracted appender cannot retain the current signpost/metrics
  placement without changing observable behavior. Stop and record the
  dependency problem.

## Out Of Scope

- Full `exportVideo` loop extraction.
- `exportStillImage` extraction.
- `renderableImage`, `scaled*`, `sourceVideoImage`,
  `sourcePreviewVideoImage`, `shouldToneMapHDRToSDR`,
  `applyVideoMotionStage`, `profileRenderSubstage`, and `applyGrainStage`
  extraction.
- Sidecar/package writer extraction.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Unexpected / Follow-up

- None yet.
