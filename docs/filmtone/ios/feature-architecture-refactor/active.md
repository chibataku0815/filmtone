# Active - Phase 2B-10D Video IO Setup Bundle

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video writer/reader setup and sizing helpers out of
`FilmtoneExportSession.exportVideo`.

## Owner Directive

- Keep the larger bundle grain. This sub-stage should remove the remaining
  writer/reader setup block from `exportVideo(...)`, not only a tiny
  helper.
- Essence first: finish pushing `FilmtoneExportSession` toward the thin
  orchestrator target before Phase 2C parity. The expected result is
  roughly 1000-1050 lines, with video export IO setup delegated.
- Product quality is the bar: writer settings, reader output selection,
  audio preservation, degraded decode telemetry, start-order, and output
  sizing must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. Use independent helper types under
  `Export/Internal/`.

## Goal

Create a larger IO setup bundle:

1. `ExportGeometry`
   - owns the two `scaledSize(...)` helpers currently on
     `FilmtoneExportSession`.
   - used by video export, still export, and any cross-file call sites
     that currently reference `FilmtoneExportSession.scaledSize`.
2. `ExportVideoIOBuilder`
   - owns the video export writer/reader setup block:
     output size, writer, video input, adaptor, audio pipeline, reader,
     video reader output selection, degraded decode path, input
     registration, `startWriting`, `startReading`, and
     `startSession(atSourceTime: .zero)`.

Keep mezzanine routing, asset/video-track lookup, depth reader setup,
timeline construction, queue pumps, `appendOutputFrame(...)`, post-wait
finish, and `CompletedExport` assembly on `FilmtoneExportSession`.

## Intended Implementation Shape

### 1. ExportGeometry

Add:

```swift
enum ExportGeometry {
    static func scaledSize(for track: AVAssetTrack, longEdge: Int) -> CGSize
    static func scaledSize(for sourceSize: CGSize, longEdge: Int) -> CGSize
}
```

Move the existing formulas verbatim. Update session call sites from
`Self.scaledSize(...)` to `ExportGeometry.scaledSize(...)`. If any
cross-file consumers reference `FilmtoneExportSession.scaledSize`, update
them to the new namespace without changing arguments.

### 2. ExportVideoIOBuilder

Add:

```swift
final class ExportVideoIOBuilder {
    struct Context {
        let outputSize: CGSize
        let writer: AVAssetWriter
        let videoInput: AVAssetWriterInput
        let adaptor: AVAssetWriterInputPixelBufferAdaptor
        let audioInput: AVAssetWriterInput?
        let audioOutput: AVAssetReaderTrackOutput?
        let reader: AVAssetReader
        let videoOutput: AVAssetReaderTrackOutput
        let degradedDecodePath: Bool
    }

    init(
        request: Phase0ExportRequestDTO,
        mediaWriter: ExportMediaWriter
    )

    func makeContext(
        asset: AVURLAsset,
        videoTrack: AVAssetTrack,
        highlightTimeline: FilmtoneHighlightReelFrameTimeline?
    ) throws -> Context
}
```

The builder should preserve the current order:

1. compute `outputSize`
2. create writer / video input / adaptor
3. `guard writer.canAdd(videoInput)` with same error string
4. `writer.add(videoInput)`
5. resolve audio track only when
   `highlightTimeline == nil && request.output.preserveAudio`
6. create audio pipeline and add audio input if possible
7. create `AVAssetReader(asset:)`
8. create video reader output using the same codec-family expression
9. throw same `"Video reader output could not be added."` error if nil
10. set `degradedDecodePath` from the selection
11. `reader.add(videoOutput)`
12. add audio output if reader can add it
13. `writer.startWriting()` with same failure string
14. `reader.startReading()` with same failure string
15. `writer.startSession(atSourceTime: .zero)`

In `FilmtoneExportSession`, build the context and assign:

```swift
let io = try videoIOBuilder.makeContext(...)
degradedDecodePath = io.degradedDecodePath
```

Then pass `io.writer`, `io.reader`, `io.videoInput`, `io.adaptor`,
`io.videoOutput`, `io.audioInput`, `io.audioOutput`, and
`io.outputSize` to the existing queue pumps and append closure.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove static `scaledSize` helpers
  - remove writer/reader setup block from `exportVideo`
  - delegate to `ExportVideoIOBuilder`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportGeometry.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for both files
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-10c-video-export-queue-bundle.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  - writer/reader primitive APIs
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoFramePump.swift`
  - video queue consumer of IO context
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoAudioPump.swift`
  - audio queue consumer of IO context

## Checklist

- [ ] Create `ExportGeometry.swift` and move both scaled-size helpers.
- [ ] Update all `FilmtoneExportSession.scaledSize` / `Self.scaledSize`
  call sites to `ExportGeometry.scaledSize`.
- [ ] Create `ExportVideoIOBuilder.swift` and move writer/reader setup
  into `makeContext(...)`.
- [ ] Rewire `exportVideo(...)` to use the IO context values.
- [ ] Preserve `degradedDecodePath` assignment timing.
- [ ] Preserve audio preservation gate and audio pipeline add behavior.
- [ ] Preserve writer/reader start order and error messages.
- [ ] Register both new Swift files in pbxproj 4 sections.
- [ ] Verify stale setup grep on `FilmtoneExportSession.swift` is clean:
  `rg -n "AVAssetWriterInputPixelBufferAdaptor|writer\\.canAdd\\(videoInput\\)|writer\\.add\\(videoInput\\)|makeAudioPipeline|makeVideoReaderOutput|writer\\.startWriting\\(|reader\\.startReading\\(|startSession\\(atSourceTime: \\.zero\\)|static func scaledSize" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [ ] `grep -c 'ExportGeometry.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `grep -c 'ExportVideoIOBuilder.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this bundle:

- pbxproj 4-section grep for both new files
- stale setup grep on `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in this sub-stage unless implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.exportVideo(...)` no longer owns writer/reader
  setup, adaptor creation, reader output selection, or static sizing math.
- `ExportVideoIOBuilder` returns a complete context with identical writer
  settings, reader output choice, audio pipeline behavior, degraded decode
  flag, and start order.
- `ExportGeometry` owns the scaled-size formulas and all call sites use
  that namespace.
- The session still owns mezzanine routing, asset/video-track lookup,
  depth reader setup, timeline construction, queue pump orchestration,
  `appendOutputFrame(...)`, post-wait finish, and `CompletedExport`
  assembly.
- Public API, sidecar schema, render stage order, queue behavior, audio
  preservation, export settings, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving IO setup forces changes to queue pump behavior, render stage
  order, sidecar fields, export settings, timeline math, depth matcher
  behavior, or public API. Stop and record the blocker instead of
  widening scope.

## Out Of Scope

- Full video export facade extraction.
- Mezzanine routing changes.
- Depth matcher behavior changes.
- Queue pump behavior changes.
- `ExportMediaWriter` helper changes.
- Motion blur, grade, optics, sidecar, connect package, preview, still
  export, or capture/editor work.
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
