# Active - Phase 2B-9A ExportStillImageWriter Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move still-image writer/adaptor/render/append loop out of
`FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: still-image output duration, frame count,
  writer settings, pixel-buffer attributes, render bounds/color space,
  output metadata, progress cadence, cancellation checks, finish timing,
  and thrown error messages must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportStillImageWriter` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportStillImageWriter.swift` and move the
post-grade still-image writer loop out of `FilmtoneExportSession`.

This is not full still-export extraction. Keep source loading, HEIC depth
payload loading, `loadedDepthMap` / `depthResolution` mutation, output
size calculation, and `renderableStillImage(...)` on
`FilmtoneExportSession` for now. The session should produce the
`filteredImage` exactly where it does today, then delegate writer/adaptor
setup, the 3-second frame loop, render/metadata/append, progress updates,
and finish to the new writer.

## Current Boundary As Of 2B-8C

Inside `exportStillImage(progress:)`, the section after
`filteredImage = renderableStillImage(...)` currently owns:

- `mediaWriter.makeWriter(outputSize:)`
- `mediaWriter.makeVideoInput(outputSize:)`
- `AVAssetWriterInputPixelBufferAdaptor` with BGRA / width / height
  source pixel-buffer attributes
- writer `canAdd`, `add`, `startWriting`, `startSession(atSourceTime:
  .zero)`
- `frameCount = max(request.output.fps * 3, 1)`
- `adaptor.pixelBufferPool` guard
- frame loop with `checkCancelled`
- `mediaWriter.waitUntilReadyForMoreMediaData`
- `CVPixelBufferPoolCreatePixelBuffer`
- `ciContext.render(filteredImage, bounds: .zero/outputSize,
  colorSpace: outputColorSpace)`
- `attachOutputColorMetadata(to:)`
- presentation time `CMTime(value: frameIndex, timescale:
  request.output.fps)`
- append failure message `"The still frame could not be appended."`
- rendering progress every first frame / 12 frames
- `videoInput.markAsFinished()`
- writing progress at 0.92
- `mediaWriter.finish(...)`
- `CompletedExport(...)` for still image output

Move that boundary. Do not move depth payload loading or grade/motion
rendering in this sub-stage.

## Intended Implementation Shape

Add:

```swift
final class ExportStillImageWriter {
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let colorPipeline: FilmtoneColorPipelineContract
    private let mediaWriter: ExportMediaWriter
    private let outputFPS: Int

    init(
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        colorPipeline: FilmtoneColorPipelineContract,
        mediaWriter: ExportMediaWriter,
        outputFPS: Int
    )

    func write(
        filteredImage: CIImage,
        outputSize: CGSize,
        progress: (Phase0ExportProgressDTO) -> Void,
        checkCancelled: () throws -> Void
    ) throws -> CompletedExport
}
```

In `FilmtoneExportSession`:

- add `private let stillImageWriter: ExportStillImageWriter`.
- initialize it with the existing `ciContext`, `outputColorSpace`,
  `colorPipeline`, `mediaWriter`, and `request.output.fps`.
- keep `exportStillImage(progress:)` as the orchestration shell:
  load source image, load HEIC depth payload, compute output size, compute
  `filteredImage`, then call `stillImageWriter.write(...)`.
- delete `attachOutputColorMetadata(to:)` if it has zero callers after
  the writer move; the writer should call
  `colorPipeline.applyOutputMetadata(to:)` directly.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `stillImageWriter`
  - reduce `exportStillImage(progress:)` to source/depth/render
    orchestration + writer delegate
  - delete `attachOutputColorMetadata(to:)` if zero-callered
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportStillImageWriter.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportStillImageWriter.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-8c-export-sidecar-writer-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - writer primitive collaborator
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  - video appender collaborator; read-only in 2B-9A
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarWriter.swift`
  - sidecar collaborator; read-only in 2B-9A

## Checklist

- [ ] Create `Export/Internal/ExportStillImageWriter.swift` with imports
  needed by the moved writer loop (`AVFoundation`, `CoreGraphics`,
  `CoreImage`, `CoreMedia`, `CoreVideo`, `FilmLabSwiftCore`,
  `Foundation`).
- [ ] Add `private let stillImageWriter: ExportStillImageWriter` to
  `FilmtoneExportSession`.
- [ ] Initialize the writer with `ciContext`, `outputColorSpace`,
  `colorPipeline`, `mediaWriter`, and `request.output.fps`.
- [ ] Move writer/adaptor setup, 3-second frame loop, render/metadata
  application, append, progress, finish, and `CompletedExport` assembly
  into `ExportStillImageWriter.write(...)`.
- [ ] Keep source image loading, depth payload loading, `loadedDepthMap`
  / `depthResolution` mutation, output size calculation, and
  `renderableStillImage(...)` on the session.
- [ ] Rewire `exportStillImage(progress:)` to compute `filteredImage` and
  delegate to `stillImageWriter.write(...)`.
- [ ] Delete `attachOutputColorMetadata(to:)` if repeated grep confirms
  zero callers.
- [ ] Register `ExportStillImageWriter.swift` in pbxproj 4 sections.
- [ ] Verify
  `rg -n "attachOutputColorMetadata|AVAssetWriterInputPixelBufferAdaptor|The still frame could not be appended|Rendering still image|Writing output" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits or only intentional references outside the moved loop.
- [ ] `grep -c 'ExportStillImageWriter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportStillImageWriter.swift`
- moved still writer-loop declarations removed from
  `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-9A unless implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.exportStillImage(progress:)` delegates the
  post-grade writer/adaptor/render/append/finish loop to
  `ExportStillImageWriter`.
- Still source loading and HEIC depth loading remain session-owned, so
  `loadedDepthMap` and `depthResolution` mutation timing is unchanged.
- `renderableStillImage(image, outputSize:timeSeconds: 0)` is still
  called by the session before delegation, preserving grade/optics/depth
  stage order.
- Writer setup remains equivalent: same `mediaWriter.makeWriter`,
  `mediaWriter.makeVideoInput`, BGRA pixel format, rounded output width /
  height, `canAdd`, `add`, `startWriting`, and `.zero` session start.
- Frame count remains `max(outputFPS * 3, 1)`.
- Per-frame cancellation check, wait-for-ready call, pixel-buffer-pool
  guard, buffer creation, render bounds/color space, metadata application,
  presentation time, append, and error messages remain equivalent.
- Progress updates remain first frame / every 12 frames during rendering,
  plus 0.92 writing progress before finish.
- Returned `CompletedExport` fields remain equivalent.
- Public API, sidecar schema, package URI behavior, export settings, and
  UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving the still writer loop forces depth loading, `renderableStillImage`,
  `applyGrade`, source loading, sidecar writing, or result DTO changes.
  Stop and record the blocker instead of widening scope.

## Out Of Scope

- Full `exportStillImage` extraction.
- HEIC depth payload loading extraction.
- `renderableStillImage`, `applyGrade`, or still source scaling changes.
- `exportVideo` loop extraction.
- Preview rendering/JPEG extraction.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Unexpected / Follow-up

- None yet.
