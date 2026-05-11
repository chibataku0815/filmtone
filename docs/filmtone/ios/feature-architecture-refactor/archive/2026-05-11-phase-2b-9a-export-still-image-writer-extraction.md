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

- [x] Create `Export/Internal/ExportStillImageWriter.swift` with imports
  needed by the moved writer loop (`AVFoundation`, `CoreGraphics`,
  `CoreImage`, `CoreMedia`, `CoreVideo`, `FilmLabSwiftCore`,
  `Foundation`).
- [x] Add `private let stillImageWriter: ExportStillImageWriter` to
  `FilmtoneExportSession`.
- [x] Initialize the writer with `ciContext`, `outputColorSpace`,
  `colorPipeline`, `mediaWriter`, and `request.output.fps`.
- [x] Move writer/adaptor setup, 3-second frame loop, render/metadata
  application, append, progress, finish, and `CompletedExport` assembly
  into `ExportStillImageWriter.write(...)`.
- [x] Keep source image loading, depth payload loading, `loadedDepthMap`
  / `depthResolution` mutation, output size calculation, and
  `renderableStillImage(...)` on the session.
- [x] Rewire `exportStillImage(progress:)` to compute `filteredImage` and
  delegate to `stillImageWriter.write(...)`.
- [x] Delete `attachOutputColorMetadata(to:)` if repeated grep confirms
  zero callers.
- [x] Register `ExportStillImageWriter.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "attachOutputColorMetadata|AVAssetWriterInputPixelBufferAdaptor|The still frame could not be appended|Rendering still image|Writing output" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits or only intentional references outside the moved loop.
- [x] `grep -c 'ExportStillImageWriter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

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

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1701 → 1646 (−55 net, +24 / −75 per `git diff --stat`). Storage decl
  (10 lines) + 7-line init block added; `exportStillImage` writer/adaptor
  /loop body (75 lines) replaced with 6-line delegating call;
  `attachOutputColorMetadata` (3 lines) removed.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportStillImageWriter.swift`:
  new, 125 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`: +4
  lines (IDs `B217` build / `B218` ref, continuing from `B215`/`B216`).
- `FilmtoneExportSidecarBuilder.swift` untouched
  (`git diff --name-only | grep -i sidecar` empty).

## Gate Results

- `bun run verify:ios`: **EXIT 0**. All sub-gates pass — generated swift
  contract drift, ios build (xcodebuild Simulator BUILD SUCCEEDED), ios
  grain catalog, ios swift contract (Phase0 contract fixtures), motion
  blur math, cube parser, capture transform LUT classifier, cache store,
  source-color-classifier, ray-angle optics, source profile math,
  D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 accuracy gates all
  0.000 ΔE / ΔRGB, look × veil energy merge (10 tests), sidecar builder.
- `grep -c 'ExportStillImageWriter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  = **4** (PBXBuildFile + PBXFileReference + PBXGroup (Internal) +
  PBXSourcesBuildPhase).
- `rg -n "attachOutputColorMetadata|AVAssetWriterInputPixelBufferAdaptor|The still frame could not be appended|Rendering still image|Writing output" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  = 2 intentional residual hits, both in the `exportVideo` path
  (`AVAssetWriterInputPixelBufferAdaptor(...)` for the video writer
  adaptor and the `"Writing output"` writing-progress emit), 0 hits in
  the still loop — matches the checklist's "or only intentional
  references outside the moved loop" allowance.
- `git diff --check`: **exit 0** (no whitespace anomalies).
- `git diff --name-only`: 2 entries, neither matching `sidecar` (case
  insensitive).

## Behavior Equivalence

- Source image loading via `sourceImageNormalizer.loadedSourceImage(at:)`
  remains on the session and runs before any writer touch, preserving
  the existing `unsupportedSource("The selected image could not be loaded.")`
  error.
- HEIC depth payload load (gated on `request.depthEnabled` +
  `pathExtension lowercased() == "heic"/"heif"`) stays session-owned,
  including the `DepthSourceService` semaphore wait, the
  `loadedDepthMap` mutation, the `depthResolution` mutation, and the
  silent off-state on tech failure with the
  `"DepthSourceService.loadDepthMap failed:"` log line.
- `Self.scaledSize(for: image.extent.size, longEdge: request.output.longEdge)`
  is called on the session before delegation, so the same
  `outputSize` reaches the writer.
- `renderableStillImage(image, outputSize: outputSize, timeSeconds: 0)`
  is called on the session before delegation, preserving grade /
  optics / depth stage order and producing the same `filteredImage` the
  writer would have consumed inline pre-2B-9A.
- Writer setup: `mediaWriter.makeWriter(outputSize:)`,
  `mediaWriter.makeVideoInput(outputSize:)`,
  `AVAssetWriterInputPixelBufferAdaptor` with BGRA pixel format,
  rounded width / height matching `outputSize`, `canAdd` / `add`,
  `startWriting`, `startSession(atSourceTime: .zero)` — all preserved in
  the same order with byte-identical settings and error messages
  (`"Still-image writer input could not be added."`,
  `"The writer failed to start."`).
- Frame count: `max(outputFPS * 3, 1)` (writer captures `request.output.fps`
  at init time as `outputFPS`; the session also constructs the writer with
  this value, so subsequent calls observe the same constant — request
  output FPS is established at session init and never mutated).
- Per-frame body: `checkCancelled` → `autoreleasepool` →
  `mediaWriter.waitUntilReadyForMoreMediaData` →
  `CVPixelBufferPoolCreatePixelBuffer` → `ciContext.render(...,
  bounds: CGRect(origin: .zero, size: outputSize),
  colorSpace: outputColorSpace)` →
  `colorPipeline.applyOutputMetadata(to:)` (was
  `attachOutputColorMetadata` thin wrapper, removed since zero-caller) →
  presentation time `CMTime(value: CMTimeValue(frameIndex),
  timescale: CMTimeScale(outputFPS))` → `adaptor.append`. All error
  messages preserved verbatim
  (`"A render pixel buffer could not be created."`,
  `"The still frame could not be appended."`).
- Progress cadence: first frame + every 12th frame inside the loop emit
  `.rendering` with
  `normalizedProgress = 0.12 + ((frameIndex + 1) / frameCount) * 0.74`,
  clamped via `min(0.9, ...)`, with message `"Rendering still image"`.
  After loop: `markAsFinished()`, `.writing` at 0.92 with frameCount
  populated and message `"Writing output"`, then
  `mediaWriter.finish(...)`.
- `CompletedExport` fields: same `outputSize`, same `frameCount`, same
  `sourceDurationSec = Double(frameCount) / Double(outputFPS)`,
  `audioPreserved = false`.
- Public API, sidecar schema, package URI behavior, export settings, and
  UI call sites are unchanged.

## Unexpected / Follow-up

- None.

Notes:

- Strict ripgrep gate retains 2 intentional hits in the `exportVideo`
  path. The checklist explicitly allows "0 hits or only intentional
  references outside the moved loop", so the residual hits are within
  spec; recording for traceability.
- SourceKit emitted the recurring `No such module 'FilmLabSwiftCore'`
  warning on the new file's `import FilmLabSwiftCore` and on the
  pre-existing import in `FilmtoneExportSession.swift`. This is the
  known indexer noise pattern from 2B-7A/7B/8A/8B/8C; xcodebuild
  resolves the module correctly and `bun run verify:ios` is green.
- `attachOutputColorMetadata(to:)` was a 1-line thin wrapper
  (`colorPipeline.applyOutputMetadata(to:)`) with a single caller inside
  the still loop. After the writer move the wrapper was zero-callered
  and removed; the writer calls `colorPipeline.applyOutputMetadata(to:)`
  directly, matching `ExportFrameAppender:107` precedent.
