# Active - Phase 2B-8A ExportSourceImageNormalizer Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move source image loading, HDR classification, orientation,
scaling, and preview extent validation out of `FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: video orientation, HDR-to-SDR tone-map
  detection, still/preview/video scale-crop behavior, and preview extent
  validation must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportSourceImageNormalizer` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportSourceImageNormalizer.swift` and move the
source image normalization helpers out of `FilmtoneExportSession`.

This is not a grade/render pipeline move. Keep `renderableImage`,
`renderableStillImage`, `renderablePreviewVideoImage`, `applyGrade`,
`applyVideoMotionStage`, `profileRenderSubstage`, `applyGrainStage`,
`exportVideo`, and `exportStillImage` on `FilmtoneExportSession` for now.
The session should delegate only source loading, image wrapping,
orientation transform, scale/crop, and preview extent validation.

## Current Boundary As Of 2B-7B

Helpers in scope:

| Current helper | Current responsibility | 2B-8A target |
|---|---|---|
| `loadedSourceImage(at:)` | still-source `CIImage(contentsOf:options:)` with `colorPipeline.stillImageOptions()` | move |
| `sourceVideoImage(from:)` | wraps `CVPixelBuffer` with `colorPipeline.sourceImageOptions` and HDR tone-map flag | move |
| `sourcePreviewVideoImage(from:)` | preserves AVVideoComposition presentation orientation | move |
| `scaledVideoSourceImage(_:transform:outputSize:)` | applies Core Image transform + normalize + scale/crop | move |
| `scaledPreviewVideoSourceImage(_:outputSize:)` | preview normalize + scale/crop | move |
| `scaledStillSourceImage(_:outputSize:)` | still normalize + scale/crop | move |
| `validatePreviewVideoImage(_:outputSize:)` | finite/expected extent validation | move |
| `coreImageVideoTransform(for:sourceExtent:)` | AVAssetTrack transform to Core Image bottom-left space | move as `static` |
| `shouldToneMapHDRToSDR(_:)` | HLG/PQ transfer-function detection | move as private helper |
| `scaledVideoFrameImage(from:transform:outputSize:)` | zero-caller wrapper around video source + scale | verify zero and delete |

Known cross-file dependency:

- `Services/MezzanineService.swift` calls
  `FilmtoneExportSession.coreImageVideoTransform(...)`. Rewire that call
  to `ExportSourceImageNormalizer.coreImageVideoTransform(...)`.

## Intended Implementation Shape

Add:

```swift
final class ExportSourceImageNormalizer {
    private let colorPipeline: FilmtoneColorPipelineContract

    init(colorPipeline: FilmtoneColorPipelineContract)

    func loadedSourceImage(at url: URL) -> CIImage?
    func sourceVideoImage(from imageBuffer: CVPixelBuffer) -> CIImage
    func sourcePreviewVideoImage(from image: CIImage) -> CIImage
    func scaledVideoSourceImage(
        _ image: CIImage,
        transform: CGAffineTransform,
        outputSize: CGSize
    ) -> CIImage
    func scaledPreviewVideoSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage
    func scaledStillSourceImage(_ image: CIImage, outputSize: CGSize) -> CIImage
    func validatePreviewVideoImage(_ image: CIImage, outputSize: CGSize) throws

    static func coreImageVideoTransform(
        for preferredTransform: CGAffineTransform,
        sourceExtent: CGRect
    ) -> CGAffineTransform
}
```

In `FilmtoneExportSession`:

- add `private let sourceImageNormalizer: ExportSourceImageNormalizer`.
- initialize it with the existing local `colorPipeline`.
- replace helper call sites with `sourceImageNormalizer.<method>`.
- replace `Self.coreImageVideoTransform` references with
  `ExportSourceImageNormalizer.coreImageVideoTransform` where needed.
- remove the moved helper declarations from the session.
- delete `scaledVideoFrameImage(...)` if repeated grep confirms zero
  callers after the move.

In `MezzanineService.swift`:

- replace `FilmtoneExportSession.coreImageVideoTransform(...)` with
  `ExportSourceImageNormalizer.coreImageVideoTransform(...)`.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `sourceImageNormalizer`
  - remove moved source normalization helpers
  - rewire call sites
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceImageNormalizer.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App/Services/MezzanineService.swift`
  - update the cross-file transform call
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportSourceImageNormalizer.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-7b-export-frame-appender-extraction.md`
  - latest append/render boundary precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  - appender collaborator, read-only in 2B-8A
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  - grade collaborator, read-only in 2B-8A
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  - optics collaborator, read-only in 2B-8A

## Checklist

- [x] Create `Export/Internal/ExportSourceImageNormalizer.swift` with the
  imports needed by the moved helpers (`CoreGraphics`, `CoreImage`,
  `CoreVideo`, `FilmLabSwiftCore`, `Foundation` as needed).
- [x] Add `private let sourceImageNormalizer:
  ExportSourceImageNormalizer` to `FilmtoneExportSession`.
- [x] Initialize the normalizer from the existing local `colorPipeline`.
- [x] Move `loadedSourceImage`, `sourceVideoImage`,
  `sourcePreviewVideoImage`, `scaledVideoSourceImage`,
  `scaledPreviewVideoSourceImage`, `scaledStillSourceImage`,
  `validatePreviewVideoImage`, `coreImageVideoTransform`, and private
  HDR tone-map detection into the normalizer.
- [x] Rewire all session call sites through `sourceImageNormalizer`.
- [x] Rewire `MezzanineService.swift` to
  `ExportSourceImageNormalizer.coreImageVideoTransform`.
- [x] Verify `scaledVideoFrameImage(...)` has zero callers and delete it
  rather than moving dead code.
- [x] Register `ExportSourceImageNormalizer.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "FilmtoneExportSession\\.coreImageVideoTransform|private func (loadedSourceImage|sourceVideoImage|sourcePreviewVideoImage|scaledVideoFrameImage|scaledVideoSourceImage|scaledPreviewVideoSourceImage|scaledStillSourceImage|validatePreviewVideoImage)|static func coreImageVideoTransform|private func shouldToneMapHDRToSDR" apps/capacitor-film-lab-ios/ios/App/App`
  returns 0 hits or only intentional references outside `FilmtoneExportSession`.
- [x] `grep -c 'ExportSourceImageNormalizer.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportSourceImageNormalizer.swift`
- no stale `FilmtoneExportSession.coreImageVideoTransform` references
- moved helper declarations removed from `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-8A unless implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.swift` delegates source image loading, video
  pixel-buffer wrapping, HDR tone-map detection, orientation transform,
  still/video/preview scale-crop, and preview extent validation to
  `ExportSourceImageNormalizer`.
- `renderableImage`, `renderableStillImage`, and
  `renderablePreviewVideoImage` still own grade/motion orchestration on
  the session, so stage order is unchanged.
- `MezzanineService` continues using the same Core Image video transform
  math through the new type.
- `sourcePreviewVideoImage` behavior remains a no-op identity wrapper,
  preserving the AVVideoComposition presentation-orientation rationale.
- `scaledVideoFrameImage` dead wrapper is removed only after zero-caller
  verification.
- Public API, sidecar schema, export settings, and UI call sites are
  unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving the helpers forces `applyGrade`, `renderableImage` stage order,
  `exportVideo`, `exportStillImage`, or `ExportFrameAppender` behavior
  changes. Stop and record the blocker instead of widening scope.
- The cross-file `MezzanineService` transform call cannot be rewired
  without widening visibility beyond module-internal. Stop and record the
  dependency problem.

## Out Of Scope

- Full `exportVideo` loop extraction.
- `exportStillImage` extraction.
- `renderableImage`, `renderableStillImage`,
  `renderablePreviewVideoImage`, `applyGrade`, `applyVideoMotionStage`,
  `profileRenderSubstage`, and `applyGrainStage` extraction.
- Still-frame writer append extraction.
- Sidecar/package writer extraction.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  2031 → 1896 lines (−135 net; 21 insertions for collaborator decl /
  init / `sourceImageNormalizer.` prefixes on 9 call sites, 156 deletions
  covering the 7 mid-block helpers plus 4 tail-block helpers).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceImageNormalizer.swift`
  new, 161 lines.
- `apps/capacitor-film-lab-ios/ios/App/App/Services/MezzanineService.swift`
  +1 / −1 line (`FilmtoneExportSession.coreImageVideoTransform` →
  `ExportSourceImageNormalizer.coreImageVideoTransform` at line 1026).
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  +4 lines (IDs `B211` build / `B212` ref; PBXBuildFile +
  PBXFileReference + Export/Internal PBXGroup + PBXSourcesBuildPhase).
- `scaledVideoFrameImage` dead wrapper: confirmed zero callers
  (`grep -rn 'scaledVideoFrameImage' apps/capacitor-film-lab-ios/ios/App/App`
  returned only the declaration), deleted rather than moved.

## Gate Results

- `bun run verify:ios`: EXIT 0. ios build, ios grain catalog, ios swift
  contract, motion blur math, cube parser, capture transform LUT
  classifier, cache store, source-color-classifier, ray-angle optics,
  source profile math (D-Log / D-Log M / C-Log / C-Log 3 / V-Log /
  S-Log3 accuracy gates all 0.000 ΔE/ΔRGB), look × veil energy merge,
  sidecar builder — all pass.
- pbxproj 4-section grep: `grep -c 'ExportSourceImageNormalizer.swift'
  apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` = 4.
- Strict ripgrep gate (per active.md checklist): 2 hits, both
  intentional inside the new file (`static func coreImageVideoTransform`
  at line 131, `private func shouldToneMapHDRToSDR` at line 149). No
  stale `FilmtoneExportSession.coreImageVideoTransform` reference, no
  remaining private `loadedSourceImage` / `sourceVideoImage` /
  `sourcePreviewVideoImage` / `scaledVideoFrameImage` /
  `scaledVideoSourceImage` / `scaledPreviewVideoSourceImage` /
  `scaledStillSourceImage` / `validatePreviewVideoImage` declarations in
  `FilmtoneExportSession`.
- `git diff --check`: clean (exit 0).

## Behavior Equivalence

- `colorPipeline.stillImageOptions()` is still the still-image load
  option source; `colorPipeline.sourceImageOptions(for:toneMapHDRToSDR:)`
  is still the video pixel-buffer wrapping option source.
- HLG / PQ tone-map detection (`kCVImageBufferTransferFunction_ITU_R_2100_HLG`
  / `_SMPTE_ST_2084_PQ`) keeps identical short-circuit return on missing
  attachment.
- `coreImageVideoTransform(for:sourceExtent:)` math is byte-identical:
  same `inputFlip.concatenating(preferredTransform).concatenating(outputFlip)`
  composition using the displayed-rect height.
- Scale/crop helpers preserve the existing translate-by-`-extent.origin`
  normalization, `scaleX = outputSize.width / normalized.extent.width`
  (resp. height), and `cropped(to: CGRect(origin: .zero, size: outputSize))`.
- `sourcePreviewVideoImage(from:)` remains a no-op identity wrapper so
  the AVVideoComposition presentation-orientation rationale is intact.
- `validatePreviewVideoImage` thresholds (0.5 px guard on
  origin / size, `isFinite` / `!isNull` / `!isInfinite` checks) and the
  two `FilmtoneMediaError.exportFailed(filmtoneLocalized(...))`
  messages with their exact localization keys
  (`filmtone.preview.video.invalid_extent`,
  `filmtone.preview.video.unexpected_extent`) are unchanged.
- `MezzanineService.orientAndScale` still applies the same
  Core-Image-bottom-left transform; only the namespace of the static
  helper changed.
- `attachOutputColorMetadata` / `applyOutputMetadata(to:)` / signpost
  intervals / `performanceMetrics` phases / depth / motion / grade
  stage order remain on `FilmtoneExportSession`.

## Unexpected / Follow-up

- None.
