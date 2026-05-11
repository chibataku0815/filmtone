# Active - Phase 2B-9C ExportPreviewRenderer Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move preview rendering and reference-after JPEG artifact
generation out of `FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: still/video preview output, preview/export
  source symmetry, poster-time selection, preview tolerance fallback,
  JPEG color-space behavior, and reference-after timing must stay
  equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportPreviewRenderer` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportPreviewRenderer.swift` and move still/video
preview rendering plus reference-after JPEG writing out of
`FilmtoneExportSession`.

Keep public `FilmtoneExportSession.renderPreviewFrame()` as a facade that
clears CI caches and delegates to the preview renderer. Keep `applyGrade`
on `FilmtoneExportSession`; the renderer should receive an `applyGrade`
closure so the grade/optics/grain order stays session-owned in this
sub-stage.

## Current Boundary As Of 2B-9B

In scope:

| Current helper | Responsibility | 2B-9C target |
|---|---|---|
| `renderStillPreview()` | still preview original/graded JPEG pair | move |
| `renderVideoPreview()` | video poster frame original/graded JPEG pair | move |
| `copyPreviewCGImage(for:at:)` | zero-tolerance preview image + 0.5s fallback | move |
| `configuredPreviewGenerator(asset:tolerance:)` | `AVAssetImageGenerator` setup | move |
| `makePreviewPosterTime(sourceDurationSec:)` | 25% poster time clamp | move |
| `writePreviewImage(_:preferredName:)` | temporary preview JPEG URL + write | move |
| `writeReferenceAfterImage(to:sourceDurationSec:)` | Connect reference-after JPEG + poster time | move |
| `writeJPEGImage(_:to:)` | CI JPEG representation with `outputColorSpace` | move |

Keep these on the session:

- public `renderPreviewFrame()` facade
- `applyGrade(...)`
- `renderablePreviewVideoImage(...)`
- `renderableStillImage(...)`
- `scaledSize(...)` static sizing helpers for now

## Intended Implementation Shape

Add:

```swift
final class ExportPreviewRenderer {
    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let outputURL: URL
    private let cacheStore: CacheStore
    private let ciContext: CIContext
    private let outputColorSpace: CGColorSpace
    private let sourceImageNormalizer: ExportSourceImageNormalizer
    private let mezzanineRouter: ExportMezzanineRouter

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        outputURL: URL,
        cacheStore: CacheStore,
        ciContext: CIContext,
        outputColorSpace: CGColorSpace,
        sourceImageNormalizer: ExportSourceImageNormalizer,
        mezzanineRouter: ExportMezzanineRouter
    )

    func renderPreviewFrame(
        applyGrade: (CIImage, Double) -> CIImage
    ) throws -> Phase0PreviewRenderResultDTO

    func writeReferenceAfterImage(
        to url: URL,
        sourceDurationSec: Double?
    ) throws -> Double
}
```

The `applyGrade` closure should return the raw `applyGrade` result; the
renderer keeps the existing `.cropped(to: original.extent)` calls at the
same points. Use `FilmtoneExportSession.scaledSize(...)` for sizing in
2B-9C rather than moving sizing helpers in this sub-stage.

In `FilmtoneExportSession`:

- add `private let previewRenderer: ExportPreviewRenderer`.
- initialize it after `sourceImageNormalizer` and `mezzanineRouter` are
  available. If initialization order requires local lets, use them
  rather than recomputing collaborators.
- reduce `renderPreviewFrame()` to cache clearing +
  `previewRenderer.renderPreviewFrame(applyGrade: { [self] image, time in applyGrade(to: image, timeSeconds: time) })`.
- replace the Connect package closure with
  `previewRenderer.writeReferenceAfterImage(to:sourceDurationSec:)`.
- remove the moved private preview/JPEG helpers from the session.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `previewRenderer`
  - reduce `renderPreviewFrame()` facade
  - rewire Connect package reference-after closure
  - remove moved preview/JPEG helpers
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportPreviewRenderer.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportPreviewRenderer.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-9b-export-mezzanine-router-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMezzanineRouter.swift`
  - preview/export source URL provider
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceImageNormalizer.swift`
  - source loading and scaling collaborator

## Checklist

- [x] Create `Export/Internal/ExportPreviewRenderer.swift` with imports
  needed by moved preview/JPEG code (`AVFoundation`, `CoreGraphics`,
  `CoreImage`, `CoreMedia`, `FilmLabSwiftCore`, `Foundation`).
- [x] Add `private let previewRenderer: ExportPreviewRenderer` to
  `FilmtoneExportSession`.
- [x] Initialize the renderer with existing request/source/output/cache,
  CI context, output color space, source normalizer, and mezzanine router.
- [x] Move `renderStillPreview`, `renderVideoPreview`,
  `copyPreviewCGImage`, `configuredPreviewGenerator`,
  `makePreviewPosterTime`, `writePreviewImage`,
  `writeReferenceAfterImage`, and `writeJPEGImage` into the renderer.
- [x] Keep `applyGrade`, `renderablePreviewVideoImage`,
  `renderableStillImage`, and `scaledSize` on the session.
- [x] Rewire public `renderPreviewFrame()` to delegate through an
  `applyGrade` closure.
- [x] Rewire the Connect package reference-after closure to
  `previewRenderer.writeReferenceAfterImage(...)`.
- [x] Register `ExportPreviewRenderer.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "private func (renderStillPreview|renderVideoPreview|copyPreviewCGImage|configuredPreviewGenerator|makePreviewPosterTime|writePreviewImage|writeReferenceAfterImage|writeJPEGImage)" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [x] `grep -c 'ExportPreviewRenderer.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportPreviewRenderer.swift`
- moved private preview/JPEG helper declarations removed from
  `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-9C unless implementation changes behavior beyond
extraction.

## Done Conditions

- Public `renderPreviewFrame()` remains on `FilmtoneExportSession` and
  still clears CI caches via `defer`.
- Still preview loads the same source image, computes the same output
  size, writes the same original/graded preview JPEG names, and returns
  the same DTO fields.
- Video preview uses `mezzanineRouter.resolvedPreviewSourceURL()` and
  preserves preview/export source symmetry.
- Poster time remains 25% of valid duration, clamped to source duration,
  with invalid/empty duration returning 0.
- Preview CGImage generation keeps zero tolerance first and 0.5s fallback.
- JPEG writing still uses `ciContext.jpegRepresentation` with
  `outputColorSpace` and atomic write.
- Reference-after JPEG writing keeps `AVURLAsset(url: outputURL)`,
  asset-duration fallback, poster-time selection, preview CGImage copy,
  JPEG write, and returned poster time.
- `applyGrade` remains session-owned and is invoked through a closure at
  the same points, with the same crop calls.
- Public API, sidecar schema, package URI behavior, export settings,
  frame loop, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving preview rendering forces `applyGrade`, source normalization,
  mezzanine routing, still/video export loops, sidecar writer, or sizing
  helper changes. Stop and record the blocker instead of widening scope.

## Out Of Scope

- `applyGrade` / render pipeline extraction.
- `renderablePreviewVideoImage` extraction.
- `renderableStillImage` extraction.
- `scaledSize` helper extraction.
- `exportVideo` loop extraction.
- Preview PNG/byte-diff fixtures and simulator UI smoke.

## Line / File Deltas

- `FilmtoneExportSession.swift`: 1457 → **1361** 行 (−96 net; +20 doc + init
  + facade rewrite / −116 helper bodies). All 8 moved helpers' declarations
  are removed from the session.
- `Export/Internal/ExportPreviewRenderer.swift`: new, **183** 行.
- `project.pbxproj`: +4 行 (IDs `B21B` build / `B21C` ref, continuing the
  `B219` / `B21A` sequence from 2B-9B).
- `FilmtoneExportSidecarBuilder.swift`: untouched (`git diff --name-only |
  grep -i sidecar` empty).

## Gate Results

- `grep -c 'ExportPreviewRenderer.swift'
  apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` = **4**
  (PBXBuildFile + PBXFileReference + PBXGroup `Internal` + PBXSourcesBuildPhase).
- Strict ripgrep gate `rg -n "private func (renderStillPreview|
  renderVideoPreview|copyPreviewCGImage|configuredPreviewGenerator|
  makePreviewPosterTime|writePreviewImage|writeReferenceAfterImage|
  writeJPEGImage)"
  apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns **0** hits.
- Loose grep (`rg -n "renderStillPreview|renderVideoPreview|
  copyPreviewCGImage|configuredPreviewGenerator|makePreviewPosterTime|
  writePreviewImage|writeReferenceAfterImage|writeJPEGImage" ...session.swift`)
  returns 4 intentional hits: 2 doc-comment mentions (`previewRenderer`
  field doc + `connectPackageAssembler` field doc) + 2 closure call sites
  in the Connect package `makeCompanions` call forwarding into
  `previewRenderer.writeReferenceAfterImage(...)`.
- `bun run verify:ios` EXIT **0** (`set -e` semantics: generated swift
  contract drift, ios build, grain catalog, Phase0 contract, motion blur
  math, cube parser, capture transform LUT classifier, cache store, source
  color classifier, ray-angle optics, source profile math, D-Log / D-Log M /
  C-Log / C-Log 3 / V-Log / S-Log3 accuracy 0.000 ΔE / 0.000 / 255, look ×
  veil energy merge 10/10, sidecar builder all green).
- `git diff --check` exit 0.
- `FilmtoneExportSidecarBuilder.swift` not in `git diff --name-only`.

## Behavior Equivalence

- `renderPreviewFrame()` public facade: still defers
  `ciContext.clearCaches()`, still routes by `request.sourceKind` (now
  inside the renderer), and still returns the same
  `Phase0PreviewRenderResultDTO` field-for-field.
- Still preview path: same `sourceImageNormalizer.loadedSourceImage(at:)`,
  same `FilmtoneExportSession.scaledSize(for: image.extent.size, longEdge:)`,
  same `scaledStillSourceImage`, same `applyGrade` invocation at
  `timeSeconds: 0` via closure, same `.cropped(to: original.extent)`,
  same `filmtone-preview-original` / `filmtone-preview-graded` preferred
  names, same `posterTimeSec: nil`.
- Video preview path: same
  `mezzanineRouter.resolvedPreviewSourceURL()` → `AVURLAsset(url:)`,
  same `tracks(withMediaType: .video).first` guard with the same
  `FilmtoneMediaError.unsupportedSource("No video track was found …")`
  message, same `CMTimeGetSeconds(asset.duration)`, same
  `makePreviewPosterTime(sourceDurationSec:)`, same
  `FilmtoneExportSession.scaledSize(for: videoTrack, longEdge:)`,
  same `CMTime(seconds: posterTimeSec, preferredTimescale: 600)`, same
  `copyPreviewCGImage(for:at:)` with zero-tolerance → 0.5s fallback,
  same `CIImage(cgImage:)`, same `scaledStillSourceImage`, same
  `applyGrade` at `timeSeconds: posterTimeSec` via closure, same
  `.cropped(to: original.extent)`, same `posterTimeSec` field returned.
- Preview/export source symmetry: video preview still routes through the
  same `mezzanineRouter.resolvedPreviewSourceURL()` that the export path
  uses via `routeSourceForExport()` (shared private `resolveSourceURL()`
  in the router).
- Poster time: `makePreviewPosterTime` semantics unchanged (25% clamp;
  invalid / non-finite / non-positive duration → 0; otherwise
  `min(max(candidate, 0), sourceDurationSec)`).
- Preview JPEG write: `cacheStore.temporaryPreviewURL(preferredName:,
  pathExtension: "jpg")` → CI `jpegRepresentation` with the session's
  `outputColorSpace` and `[:]` options → atomic write.
- Reference-after JPEG (Connect package): still
  `AVURLAsset(url: outputURL)` (the export output, not the source), same
  asset-duration fallback to the caller-supplied `sourceDurationSec`,
  same poster-time computation, same preview CGImage copy with
  zero-tolerance → 0.5s fallback, same JPEG write, same returned
  `posterTimeSec`. Closure is now captured as `[previewRenderer]`.
- `applyGrade` remains session-owned and `fileprivate`, invoked through
  a `(CIImage, Double) -> CIImage` closure at the same two points the
  in-place helpers used. The closure body is
  `applyGrade(to: image, timeSeconds: time)` — no
  `stageProfilingOutputSize` parameter, matching the prior call sites in
  `renderStillPreview()` / `renderVideoPreview()`.
- Session storage / public API: `applyGrade(...)`,
  `renderableStillImage(...)`, `renderablePreviewVideoImage(...)`,
  `FilmtoneExportSession.scaledSize(...)` (both overloads), and all
  telemetry / mezzanine / sidecar state remain on the session unchanged.

## Unexpected / Follow-up

- None.
- Note 1: The loose-grep residual count (4 hits) is intentional — 2 doc
  comments and the 2 closure call sites that forward into the renderer
  by spec (active.md "Rewire the Connect package reference-after closure
  to `previewRenderer.writeReferenceAfterImage(...)`"). The strict
  `private func ...` ripgrep gate is the authoritative check and returns
  0 hits.
- Note 2: The renderer accepts a non-`@escaping` `(CIImage, Double) ->
  CIImage` closure because `renderPreviewFrame(applyGrade:)` invokes it
  synchronously inside the call and does not store it. `applyGrade`
  remains `fileprivate` on the session and is bound via `[self]` capture
  in the facade. `writeReferenceAfterImage` is closure-free.
- Note 3: SourceKit emits the recurring non-fatal
  `No such module 'FilmLabSwiftCore'` diagnostic on
  `ExportPreviewRenderer.swift:5` and `FilmtoneExportSession.swift:4` —
  identical indexer noise to 2B-7A/7B/8A/8B/8C/9A/9B. `bun run
  verify:ios` exit 0 confirms `xcodebuild` resolves the module.
