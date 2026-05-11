# Active - Phase 2B-10D Video IO Setup Bundle

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video writer/reader setup and sizing helpers out of
`FilmtoneExportSession.exportVideo`.
Commit: `25a9f0ae` (`refactor(ios): extract export video io setup`)

## Owner Directive

- Keep the larger bundle grain. This sub-stage should remove the remaining
  writer/reader setup block from `exportVideo(...)`, not only a tiny
  helper.
- Treat the shapes below as the preferred implementation, not a rigid
  line-by-line prescription. If the codebase wants a slightly different
  context shape, take it as long as the boundary, invariants, stale grep,
  and `verify:ios` gates remain intact.
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

Preferred shape:

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

Preferred shape:

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

- [x] Create `ExportGeometry.swift` and move both scaled-size helpers.
- [x] Update all `FilmtoneExportSession.scaledSize` / `Self.scaledSize`
  call sites to `ExportGeometry.scaledSize`.
- [x] Create `ExportVideoIOBuilder.swift` and move writer/reader setup
  into `makeContext(...)`.
- [x] Rewire `exportVideo(...)` to use the IO context values.
- [x] Preserve `degradedDecodePath` assignment timing.
- [x] Preserve audio preservation gate and audio pipeline add behavior.
- [x] Preserve writer/reader start order and error messages.
- [x] Register both new Swift files in pbxproj 4 sections.
- [x] Verify stale setup grep on `FilmtoneExportSession.swift` is clean:
  `rg -n "AVAssetWriterInputPixelBufferAdaptor|writer\\.canAdd\\(videoInput\\)|writer\\.add\\(videoInput\\)|makeAudioPipeline|makeVideoReaderOutput|writer\\.startWriting\\(|reader\\.startReading\\(|startSession\\(atSourceTime: \\.zero\\)|static func scaledSize" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- [x] `grep -c 'ExportGeometry.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `grep -c 'ExportVideoIOBuilder.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

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

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1127 → 1078 lines (−49 net; +36 / −77 vs HEAD).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportGeometry.swift`:
  new file, 33 lines.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoIOBuilder.swift`:
  new file, 140 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  +8 lines (4-section registration × 2 new files; IDs B227/B228 +
  B229/B22A).
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneMediaRuntime.swift`,
  `apps/capacitor-film-lab-ios/ios/App/App/Services/MezzanineService.swift`,
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportPreviewRenderer.swift`:
  callsite swaps `FilmtoneExportSession.scaledSize` →
  `ExportGeometry.scaledSize` (6 occurrences total) and one doc-comment
  cleanup in `ExportPreviewRenderer.swift` removing the "scaledSize(...)
  stays on the session" mention.

## Gate Results

- pbxproj 4-section grep:
  - `grep -c 'ExportGeometry.swift' project.pbxproj` = **4**
  - `grep -c 'ExportVideoIOBuilder.swift' project.pbxproj` = **4**
- Stale setup grep on `FilmtoneExportSession.swift`:
  `rg -n "AVAssetWriterInputPixelBufferAdaptor|writer\.canAdd\(videoInput\)|writer\.add\(videoInput\)|makeAudioPipeline|makeVideoReaderOutput|writer\.startWriting\(|reader\.startReading\(|startSession\(atSourceTime: \.zero\)|static func scaledSize"`
  → 0 hits (ripgrep exit 1).
- Repo-wide `FilmtoneExportSession.scaledSize` reference grep
  (`grep -rn "FilmtoneExportSession\.scaledSize" apps/capacitor-film-lab-ios/ios/App/App/`):
  0 hits.
- `bun run verify:ios`: exit 0. All sub-gates green:
  generated-Swift drift, `xcodebuild ... BUILD SUCCEEDED`, ios grain
  catalog, ios swift contract, motion-blur math, cube parser, capture
  transform LUT classifier, cache store, source-color classifier,
  ray-angle optics, source profile math (D-Log / D-Log M + D-Gamut M /
  C-Log / C-Log 3 + Cinema Gamut / V-Log / S-Log3 all max |Δ|=0.000000,
  Macbeth ΔE2000 max=0.000), look × veil energy merge, sidecar builder.
- `git diff --check`: exit 0.

## Behavior Equivalence

Setup block extraction is a verbatim move into
`ExportVideoIOBuilder.makeContext(...)`; `FilmtoneExportSession`
constructs the builder in `init`, calls `makeContext` from
`exportVideo`, and assigns the returned context fields into the same
local names the inline block produced. The following invariants are
preserved by construction:

1. `ExportGeometry.scaledSize` formulas are byte-identical to the
   former static `Self.scaledSize` helpers (including the
   `naturalSize.applying(preferredTransform)`, `abs(...)`,
   degenerate-source → `CGSize(width:longEdge, height:longEdge)`,
   never-upscale clamp, and `max(2, Int(...) / 2 * 2)` even-edge
   enforcement).
2. Setup order inside `makeContext` matches the pre-extraction order:
   outputSize → writer → videoInput → adaptor → `canAdd(videoInput)`
   guard → `add(videoInput)` → audio track resolution gated by
   `highlightTimeline == nil && request.output.preserveAudio` →
   `makeAudioPipeline` → `writer.add(audioInput)` when `canAdd` →
   `AVAssetReader(asset:)` → `makeVideoReaderOutput(for:reader:codecFamily:)`
   with the same `codecFamily ?? sourceVideoMetadata?.codecFamily`
   fallback → `videoOutputSelection` guard with the same error string
   → `reader.add(videoOutput)` → optional `reader.add(audioOutput)`
   gated by `reader.canAdd(audioOutput)` → `writer.startWriting()`
   guard → `reader.startReading()` guard →
   `writer.startSession(atSourceTime: .zero)`.
3. Error message strings preserved verbatim: `"Video writer input
   could not be added."`, `"Video reader output could not be added."`,
   `writer.error?.localizedDescription ?? "The writer failed to
   start."`, `reader.error?.localizedDescription ?? "The reader
   failed to start."`.
4. `degradedDecodePath` is assigned on the session right after the
   builder returns (before any queue pump construction), preserving
   pre-pump visibility for downstream telemetry.
5. Adaptor pixel-buffer attribute dictionary is byte-identical:
   `kCVPixelFormatType_32BGRA`, `Int(outputSize.width.rounded())`,
   `Int(outputSize.height.rounded())`.
6. Audio preservation gate (`highlightTimeline == nil && request.output.preserveAudio`)
   is evaluated inside the builder with the highlight timeline value
   passed in, so behavior matches the previous in-session evaluation.
7. `ExportMediaWriter` API surface unchanged: `makeWriter(outputSize:)`,
   `makeVideoInput(outputSize:)`, `makeAudioPipeline(for:)`,
   `makeVideoReaderOutput(for:reader:codecFamily:)` are all called
   with the same arguments at the same logical points.
8. Public API unchanged: `FilmtoneExportSession` public signatures,
   sidecar V1 schema, render stage order, depth matcher behavior,
   timeline math, queue pump behavior, `appendOutputFrame(...)`,
   `CompletedExport` assembly, UI call sites all unaffected.
9. Adaptor reference is forwarded from the context but, as before,
   only constructed at this stage; later frame-append code that needs
   the adaptor reads it from the same local binding.
10. Codec-family lookup uses the same expression
    `request.sourceProbe?.codecFamily ?? request.sourceProbe?.sourceVideoMetadata?.codecFamily`,
    so `prores422` candidate ordering inside `makeVideoReaderOutput`
    is unchanged.

## Unexpected / Follow-up

- Pre-existing deprecation warnings on `track.naturalSize` /
  `track.preferredTransform` migrated verbatim into
  `ExportGeometry.scaledSize(for:longEdge:)`. They surface
  identically in `verify:ios` output as before; no behavior change.
  Migration to `load(.naturalSize)` / `load(.preferredTransform)` is
  out of scope (would require async re-plumbing and lives in a future
  AVAsset-modernization lane).
- `ExportPreviewRenderer.swift` had a stale doc comment claiming
  `scaledSize(...)` "stays on the session" — corrected in this
  sub-stage to keep the doc surface consistent with reality.
- SourceKit transiently reported `No such module 'FilmLabSwiftCore'`
  on the new files and on `FilmtoneExportSession.swift` between the
  Write and the pbxproj save. This is the chronic indexer
  pre-registration noise documented in prior 10A/10B/10C extractions
  (`feedback_no_promising_from_forced_substage`-adjacent). Cleared on
  `xcodebuild` rebuild; `verify:ios` exit 0 confirms.

## Unexpected / Follow-up

Pending implementation.
