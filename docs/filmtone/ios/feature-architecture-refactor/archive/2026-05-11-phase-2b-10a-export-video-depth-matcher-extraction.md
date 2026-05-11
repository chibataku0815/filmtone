# Active - Phase 2B-10A ExportVideoDepthMatcher Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move video depth-frame matching state out of
`FilmtoneExportSession.exportVideo`.
Commit: `33551dae` (`refactor(ios): extract export video depth matcher`)

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: video depth-track matching, decode timing,
  graceful depth-frame failure behavior, `last-known depth` behavior, and
  sidecar/runtime depth telemetry must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportVideoDepthMatcher` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportVideoDepthMatcher.swift` and move the
per-frame video depth matching state machine out of `exportVideo(...)`.

This is not the full video-loop extraction. Keep `exportVideo(...)`,
reader/writer setup, output frame loop, `appendOutputFrame(...)`,
`loadedDepthMap`, `depthResolution`, `videoDepthFramesProcessed`,
`videoDepthDecodeMs`, and `videoDepthSourceLabel` storage on
`FilmtoneExportSession` for now. The matcher should own only the depth
reader cursor state and return a per-frame result that the session uses
to update existing telemetry fields.

## Current Boundary As Of 2B-9C

Inside `exportVideo(...)`, the depth matching block currently owns:

- local state:
  - `lastDepthFrame`
  - `pendingDepthFrame`
  - `depthReaderExhausted`
- local function `prepareDepthForSourceTime(at:)`
- pull loop using `ExportDepthPayloadManager.pullNextFrame(reader:)`
- matching rule: advance pending frames while
  `pendingDepthFrame.presentationTime <= lookupTime`
- lookup time: `sourceLookupTime + (sourceTimeOffset ?? .zero)`
- mid-stream failure behavior: log once, clear pending, mark exhausted,
  keep `lastDepthFrame` as last-known depth
- per-frame decode time measurement through `Date()`
- session-side telemetry updates:
  - `videoDepthDecodeMs += decodeMs`
  - `loadedDepthMap = result.depthMap`
  - increment `videoDepthFramesProcessed` when depth exists
  - set `depthResolution` on first matched frame

Move cursor state and pull-loop behavior. Keep session telemetry fields
and their write timing on `FilmtoneExportSession`.

## Intended Implementation Shape

Add:

```swift
final class ExportVideoDepthMatcher {
    struct MatchResult {
        let depthMap: FilmtoneDepthMap?
        let decodeMs: Double
    }

    private let reader: ExportDepthPayloadManager.Reader?

    init(reader: ExportDepthPayloadManager.Reader?)

    var hasReader: Bool { get }

    func cancel()

    func matchDepthFrame(
        for sourceLookupTime: CMTime,
        sourceTimeOffset: CMTime?
    ) -> MatchResult
}
```

If the exact reader type is not named `ExportDepthPayloadManager.Reader`,
use the concrete type returned by `ExportDepthPayloadManager.resolveReader`
without changing that manager's public surface. Do not alter
`ExportDepthPayloadManager.swift` unless the compiler forces a narrow
typealias for readability.

In `FilmtoneExportSession`:

- replace `defer { depthReader?.cancel() }` with a matcher-owned
  cancel call.
- initialize `let depthMatcher = ExportVideoDepthMatcher(reader:
  depthReader)`.
- keep existing `if depthReader != nil` telemetry initialization, or
  switch it to `if depthMatcher.hasReader` with identical effects.
- replace the local state + `prepareDepthForSourceTime(at:)` body with a
  small session helper/local closure that:
  - calls `depthMatcher.matchDepthFrame(for:sourceTimeOffset:)`
  - adds `decodeMs` to `videoDepthDecodeMs`
  - assigns `loadedDepthMap`
  - increments `videoDepthFramesProcessed` and initializes
    `depthResolution` when a depth map is returned
- keep `appendOutputFrame(...)` calling `prepareDepthForSourceTime(at:)`
  before motion blur reset and render.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove depth cursor local state from `exportVideo`
  - delegate matching to `ExportVideoDepthMatcher`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoDepthMatcher.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportVideoDepthMatcher.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-9c-export-preview-renderer-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportDepthPayloadManager.swift`
  - depth reader open/pull primitive

## Checklist

- [x] Create `Export/Internal/ExportVideoDepthMatcher.swift` with imports
  needed by the moved matching code (`AVFoundation`, `Foundation`,
  `FilmLabSwiftCore` if required by `FilmtoneDepthMap`).
- [x] Move `lastDepthFrame`, `pendingDepthFrame`,
  `depthReaderExhausted`, and the `pullNextFrame` loop into the matcher.
- [x] Keep session telemetry fields on `FilmtoneExportSession`.
- [x] Rewire `exportVideo(...)` so `prepareDepthForSourceTime(at:)`
  delegates to the matcher and updates session telemetry from
  `MatchResult`.
- [x] Preserve `loadedDepthMap = nil` behavior when no depth reader
  exists.
- [x] Preserve the mid-stream pull failure debug log text.
- [x] Preserve `defer` cancellation behavior for the depth reader.
- [x] Register `ExportVideoDepthMatcher.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "lastDepthFrame|pendingDepthFrame|depthReaderExhausted|ExportDepthPayloadManager\\.pullNextFrame" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [x] `grep -c 'ExportVideoDepthMatcher.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportVideoDepthMatcher.swift`
- depth cursor state removed from `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-10A unless implementation changes behavior beyond
extraction.

## Done Conditions

- The depth reader cursor state and pull loop live in
  `ExportVideoDepthMatcher`.
- The session still owns and updates `loadedDepthMap`,
  `videoDepthDecodeMs`, `videoDepthFramesProcessed`,
  `depthResolution`, and `videoDepthSourceLabel`.
- Lookup time remains `sourceLookupTime + (sourceTimeOffset ?? .zero)`.
- Matching still uses the most recent depth frame whose pts is less than
  or equal to the current lookup time.
- End-of-stream and pull-failure behavior remains equivalent.
- The pull-failure log remains:
  `"FilmtoneExportSession: video depth frame pull failed: \\(error). Continuing without depth for remaining frames."`
- `appendOutputFrame(...)` still prepares depth before segment-change
  motion blur reset and render.
- Public API, sidecar schema, depth sidecar truth fields, frame loop,
  export settings, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving depth matching forces video writer loop, frame sample selection,
  render stage order, sidecar writer, or `ExportDepthPayloadManager`
  behavior changes. Stop and record the blocker instead of widening
  scope.

## Out Of Scope

- Full `exportVideo` loop extraction.
- `ExportDepthPayloadManager` behavior changes.
- Depth sidecar schema changes.
- Motion blur, grade, optics, or sample-selection changes.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Line / File Deltas

- `FilmtoneExportSession.swift`: 1361 → 1334 (−27 net)
  - `-9` lines of inline depth-cursor decl + comment (`lastDepthFrame` /
    `pendingDepthFrame` / `depthReaderExhausted`), replaced by a 4-line
    comment pointing to `ExportVideoDepthMatcher`.
  - `-43` lines of inline `prepareDepthForSourceTime(at:)` body (lookup
    time + decode timing + pull loop + tri-state switch + telemetry),
    replaced by a `+18` line matcher-delegating body.
  - `+2` lines around `defer { depthMatcher.cancel() }` /
    `let depthMatcher = ExportVideoDepthMatcher(reader: depthReader)` /
    `if depthMatcher.hasReader { ... }` rewiring.
- `Export/Internal/ExportVideoDepthMatcher.swift`: new, 80 lines.
- `project.pbxproj`: +4 lines (IDs `B21D` build / `B21E` ref).
- `FilmtoneExportSidecarBuilder.swift`: untouched.
- `ExportDepthPayloadManager.swift`: untouched.

## Gate Results

- `grep -c 'ExportVideoDepthMatcher.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`: **4**.
- Strict ripgrep
  `rg -n "lastDepthFrame|pendingDepthFrame|depthReaderExhausted|ExportDepthPayloadManager\.pullNextFrame" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  **0 hits**.
- `bun run verify:ios`: **exit 0**. All sub-gates green: generated
  Swift contract drift, ios build, grain catalog, Phase0 contract,
  motion-blur math, cube parser, capture transform LUT classifier,
  cache store, source-color-classifier, ray-angle optics, source
  profile math, D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3
  accuracy (0.000 ΔE, 0.000 /255), look × veil energy merge 10/10,
  sidecar builder.
- `git diff --check apps/capacitor-film-lab-ios/...`: **exit 0**.

## Behavior Equivalence

1. `defer` cancellation: `defer { depthReader?.cancel() }` →
   `defer { depthMatcher.cancel() }`. Matcher forwards to
   `reader?.cancel()`. Equivalent for non-nil and nil reader.
2. Telemetry init guard: `if depthReader != nil { ... }` →
   `if depthMatcher.hasReader { ... }`. Same predicate.
3. No-reader fast-path: session-side `guard depthMatcher.hasReader else { loadedDepthMap = nil; return }` mirrors the original
   `guard let reader = depthReader else { loadedDepthMap = nil; return }`. `videoDepthDecodeMs` stays `nil` when there is no
   reader, matching the pre-extraction state.
4. Lookup time: `CMTimeAdd(sourceLookupTime, sourceTimeOffset ?? .zero)`
   computed inside the matcher with the same `sourceTimeOffset` value
   passed by the session per call. Equivalent.
5. Pull loop predicate: while
   `!readerExhausted && (pendingDepthFrame == nil || CMTimeCompare(pendingDepthFrame!.presentationTime, lookupTime) <= 0)`.
   Verbatim move of the pre-extraction body.
6. Mid-stream failure log: identical literal
   `"FilmtoneExportSession: video depth frame pull failed: \(error). Continuing without depth for remaining frames."`.
7. End-of-stream behavior: `pendingDepthFrame = nil; readerExhausted = true`. Verbatim.
8. Failure behavior: same `pendingDepthFrame = nil; readerExhausted = true`, `lastDepthFrame` is preserved → last-known depth.
9. Decode timing: `Date() ... timeIntervalSince(decodeStart) * 1000.0`
   measured inside the matcher across the pull loop only; session adds
   it via `(videoDepthDecodeMs ?? 0) + result.decodeMs`. Same scope as
   before because the matcher path is taken only when `hasReader` is
   true.
10. `loadedDepthMap` assignment: assigned every call from
    `result.depthMap` (which is `lastDepthFrame?.depthMap`). Identical
    to pre-extraction `let depthMapForThisFrame = lastDepthFrame?.depthMap; loadedDepthMap = depthMapForThisFrame`.
11. `videoDepthFramesProcessed` + `depthResolution`: incremented and
    initialized only when `result.depthMap` is non-nil. Same condition.
12. `appendOutputFrame(...)` still calls
    `prepareDepthForSourceTime(at: sourceLookupTime)` before
    `exportMotionBlurAccumulator.reset()` / render. Unchanged.
13. `FilmtoneExportSidecarBuilder`, sidecar schema, video writer / reader
    setup, frame loop, export settings, and UI call sites unchanged.

## Unexpected / Follow-up

- None.
  - `defer { depthMatcher.cancel() }` is invoked once on the
    matcher rather than directly on the optional `depthReader`. Net
    behavior is identical because the matcher holds the reader as a
    `private let` and its `cancel()` calls `reader?.cancel()`.
  - The matcher does not import `FilmLabSwiftCore`; `FilmtoneDepthMap`
    is defined in this app target (`ios/App/App/Optics/FilmtoneDepthMap.swift`) and `VideoDepthFrameReader` in
    `ios/App/App/Services/VideoDepthSourceService.swift`. Same module,
    so module-level imports are limited to `AVFoundation` / `CoreMedia` / `Foundation`.
  - SourceKit indexer briefly reports `Cannot find type ...` for the
    new file before the pbxproj registration is saved. Resolved as
    soon as the 4-section entries land — xcodebuild authoritative,
    `bun run verify:ios` confirms.
