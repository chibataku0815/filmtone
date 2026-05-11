# Active — Phase 2B-1 ExportSession Inventory & First Cut

Date: 2026-05-11 JST
Phase: Phase 2B — ExportSession public-surface split (sub-stage 1 of N)
Milestone: Build the responsibility map; land one zero-risk extraction
to prove the cut mechanic before larger pieces move.

## Goal

`FilmtoneExportSession.swift` is currently 4498 lines after Phase 2A,
containing one 3577-line class plus four file-level companions
(`FilmtoneSharedGradeProcessor`, `filmtonePreviewCompositionDebugLog`,
`extension ISO8601DateFormatter`, `fileprivate FilmtoneMotionBlurAccumulator`,
`private enum OpticalKernels`). Phase 2B's strategy.md target is six
files. Before splitting any piece that touches render math or sidecar
order, we need an inventory that proves each candidate's fan-in and
access-modifier impact. This sub-stage builds that inventory, then lands
the single lowest-risk move so the pbxproj 4-section gate and the
verify chain are exercised again on this file.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (remove date formatter extension)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarDateFormatter.swift` (new — sole owner of the sidecar `ISO8601DateFormatter`)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` (4-section registration)
- `docs/filmtone/ios/feature-architecture-refactor/active.md` (this file)

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md` (commit gate)
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2a-export-session-helper-extraction.md`

## Responsibility Inventory

Sole class is `FilmtoneExportSession`. After Phase 2A its remaining
~120 `func` declarations and ~22 file-private static constants fall
into the following responsibilities. Future sub-stages (2B-2 …) consume
this table directly.

### Compatibility Table — Class Members

| Bucket | Member sample (line) | Current access | Cross-file readers today | Move target (per strategy.md) | Risk when extracted |
|---|---|---|---|---|---|
| Facade / Orchestration | `cancel()` 254, `run(...)` 275, `runHighlightReel(...)` 411, `renderPreviewFrame()` 262, `makeSharedGradeProcessor()` 258, `requestSnapshot` 140, `environmentFlagEnabled` 162, `checkCancelled()` 2986 | mostly internal/private | `ExportCoordinator` etc via `FilmtoneExportSession` public methods | Stay in `Export/FilmtoneExportSession.swift` (facade) | Low — orchestrator; preserved as the public surface. |
| Geometry / CMTime statics | `scaledSize(for: AVAssetTrack)` 3560, `scaledSize(for: CGSize)` 3566, `coreImageVideoTransform` 1618, `validPresentationTime` 2892, `nonNegativeTime` 2900, `absoluteSecondsBetween` 2907, `clamp` 2685, `lerp` 2689 | `static`, default internal/private | Self-use; no cross-file | Stay in facade as `static` until last (`Export/Internal/ExportGeometry.swift` candidate, defer). | Low but currently low-value to move. |
| ExportMediaWriter | `makeWriter` 1376, `makeVideoInput` 1382, `makeVideoReaderOutput` 1404, `makeAudioPipeline` 1436, `appendVideoSample` 2693, `appendAudioSample` 2767, `finish(writer:)` 2872, `exportVideo` 684, `exportStillImage` 1186, `waitUntilReadyForMoreMediaData` 2946, `attachOutputColorMetadata` 3060, `shouldToneMapHDRToSDR` 3047, `writeJPEGImage` 3017, `writePreviewImage` 2992, `writeReferenceAfterImage` 2998, `copyPreviewCGImage` 1358, `configuredPreviewGenerator` 1368, `resolvedVideoSourceURL` 3375, `prepareQualityMezzanineForExport` 3442, `qualityMezzanineVariantForExport` 3498, `estimatedDataRate` 3524, `estimatedVideoFrameRate` 2912, `renderingProgress` 2923, `makePreviewPosterTime` 2938, `writeExportSidecar` 458, `makeConnectPackageCompanions` 588, `makePackageFileUris` 665 | private | None (all consumed by `run/runHighlightReel`) | `Export/ExportMediaWriter.swift` plus `Export/Internal/ExportConnectPackageBuilder.swift` for the DaVinci Connect companions | Highest — `exportVideo` (~500 lines) owns the frame loop, depth handoff, writer/reader pair lifecycle. Splitting it requires a wrapping struct that keeps `nextOutputFrameIndex`, `sourceTimeOffset`, `lastDepthFrame` together. **Sidecar canonical order lives inside `writeExportSidecar`; do not change field order during move.** |
| GradeRenderPipeline | `renderableImage` 1462, `renderableStillImage` 1490, `renderablePreviewVideoImage` 1500, `applyGrade` 1636, `applyLivePreviewGrade` 1685, `applyRecordingMonitorGrade` 1698, `applyInputLutStage` 1753, `applyBaseGradeStage` 1760, `applyToneCompressionStage` 1822, `applyCreativeLutStage` 2311, `applyPrintStage` 2318, `applyLut` 2342, `applyGrainStage` 2286, `applyVideoMotionStage` 1725, `scaledVideoFrameImage` 1522, `scaledVideoSourceImage` 1534, `scaledStillSourceImage` 1568, `scaledPreviewVideoSourceImage` 1555, `validatePreviewVideoImage` 1580, `sourceVideoImage` 3032, `sourcePreviewVideoImage` 3040, `loadedSourceImage` 3028, `renderStillPreview` 1304, `renderVideoPreview` 1325, `profileRenderSubstage` 1742 | private / fileprivate (the `apply*` and `renderablePreviewVideoImage` reach into `SharedGradeProcessor` and live capture) | `applyLivePreviewGrade` → `FilmtoneSharedGradeProcessor.applyForLivePreview` reaches indirectly from Capture views | `Export/GradeRenderPipeline.swift` (kernel chain order is **invariant**) | High — `applyGrade` is the canonical kernel chain. Move only with a parity gate. Static seed/lerp/clamp/coreImageVideoTransform tag along; they have no behavioural state. |
| OpticsCompositor | `applyEdgeOpticsStage` 1846, `applyGlowFamilyStage` 1950, `applyVignetteStage` 2240, `vignetteFrameParams` 2205, `currentBacklightVeilProfile` 1871, `applyBacklightVeilSpatialOverrides` 1907, `extractHighlightPlate` 2363, `applyRadialRGBShift` 2381, `applyEdgeSoftness` 2401, `buildMipBlurComposite` 2444, `buildMipPyramid` 2485, `downsampledImage` 2515, `upsampledImage` 2525, `tentDownsampledImage` 2544, `tentUpsampledImage` 2573, `scaledImage` 2600, `weightedImage` 2610, `addImages` 2628, `blackImage` 2636, `extentOriginVector` 2640, `extentSizeVector` 2644, `computeMipWeights` 2648, `halationColor` 2657, `aberrationEdgeSoften` 2665, `makeStableSourceSeed` 2676 | private / static | None (closed over `metalOpticsRenderer`, `useMetalOpticsForExport`, `metalOpticsActiveOnce`, `metalVignetteActiveOnce`, `metalVignetteAppliedThisFrame`) | `Export/OpticsCompositor.swift` (Metal + CI fallback) + `Export/Internal/MipBlurMath.swift` for the static mip helpers | High — the Metal dispatch order, glow/halation kernel mix, and vignette frame params are all part of the canonical render chain. Must extract behind the same kernel chain order. **Mip helpers are pure static math and can move first** as a 2B-3 cut. |
| DepthPayloadManager | `resolveVideoDepthReader` 2793, `pullNextVideoDepthFrame` 2850 (+ enum `VideoDepthFramePullResult` 2844) | private | None | `Export/DepthPayloadManager.swift` | Medium — handoff is well-bounded; uses `DispatchSemaphore` so move keeps thread semantics. |
| Source-profile input-LUT helpers | `makePreparedLut` 3064, `makeCameraProfileSidecar` 3085, `implTag` 3139, `makeAutomaticInputLut` 3148, `makeActiveInputLut` 3169, `makeInputLut` 3191, `makeSynthesizedInputLut` 3213, `packRgbToRgbaCubeData` 3246, `rgbaCubeData` 3259, `makeAppleLogToRec709Lut` 3287, `appleLogPixelToRec709` 3320, `appleLogDecode` 3352, `rec2020ToRec709` 3357, `filmtoneSdrShoulder` 3366, `rec709Encode` 3371, `synthesizedInputLutCache` 3163 | private static | None | `Export/Internal/InputLutBuilders.swift` (or `Look/InputLutBuilders.swift` if Look pipeline reads it later) | Low — pure static factories with one cache. Best candidate for 2B-2. |
| Render stage profiler factory | `makeRenderStageProfiler` 3535 | private static | Calls `FilmtoneExportRenderStageProfiler` from `Internal/ExportMetrics.swift` | Stay in facade (only orchestrator constructs the profiler) | Low. |

### Compatibility Table — File-Level Companions

| Symbol (lines) | Today | Cross-file readers | Move target | Risk |
|---|---|---|---|---|
| `FilmtoneSharedGradeProcessor` (3579–3651, ~73 lines) | `final class`, default `internal` | `FilmtoneCaptureView`, `FilmtoneCaptureLivePreview`, `FilmtoneCaptureTakePicker*`, `FilmtoneCaptureTakePreview*`, `FilmtoneEditorStore`, `FilmtoneEditorFacade`, `FilmtoneMediaRuntime` (already module-internal) | `Look/FilmtoneSharedGradeProcessor.swift` per strategy.md | Medium — once moved, six current `fileprivate` session members (`applyLivePreviewGrade`, `renderablePreviewVideoImage`, `ciContext`, `colorPipeline`, `makeMotionBlurAccumulator`, `outputFrameRate`) and one `fileprivate class` (`FilmtoneMotionBlurAccumulator`) must bump to `internal`. No public API surface change because internal is the module-default. Defer to 2B-4. |
| `filmtonePreviewCompositionDebugLog(_:)` (3653–3657) | `private` free func | One caller inside `FilmtoneSharedGradeProcessor.makeVideoComposition` | Travels with `FilmtoneSharedGradeProcessor` move; rename to internal helper at that time. | Low; coupled to the SharedGrade move. |
| `extension ISO8601DateFormatter { static let filmtoneSidecar }` (3659–3667, 8 lines) | extension, default `internal` (extensions on Foundation types are internal-by-default) | Two call sites inside ExportSession (`exportedAtIso`, `updatedAtIso`); one inside `Editor/FilmtoneEditorStore.swift` line 1776 (already cross-file today) | `Export/Internal/ExportSidecarDateFormatter.swift` | **Lowest** — already cross-file consumed. No access bump. No render/sidecar order touched (the formatter is a constant). Picked for this sub-stage. |
| `fileprivate final class FilmtoneMotionBlurAccumulator` (3669–3851, ~183 lines) | `fileprivate` | None today | Eventually `Export/Internal/MotionBlurAccumulator.swift`, but must bump to `internal` first, and must move OR keep `OpticalKernels.motionFeedback` + `motionBlend` accessible (the accumulator references both). Defer to 2B-4 alongside SharedGrade move. | Medium — internal bumps must be paired with `FilmtoneSharedGradeProcessor.private lazy var motionBlurAccumulator`. |
| `private enum OpticalKernels` (3853–end, ~640 lines) | `private` enum of `CIColorKernel`/`CIKernel` source strings | None today (file-private) | Eventually `Export/Internal/OpticalKernels.swift`, internal bump | Medium — many readers inside the session class. Pure static literals, no behaviour change, but the move bloats one file. Land after MotionBlurAccumulator move so kernel definitions don't outlive their consumer. |

### Extraction Risk Rank (lowest → highest)

1. `extension ISO8601DateFormatter` — pure constant, already cross-file. **Picked for 2B-1.**
2. `Source-profile input-LUT helpers` (~330 lines of pure static factories + one `NSCache`) — no behavioural state; candidate for 2B-2.
3. `DepthPayloadManager` (resolve + pullNext + enum) — bounded handoff, candidate for 2B-3.
4. `FilmtoneSharedGradeProcessor` + `FilmtoneMotionBlurAccumulator` + `OpticalKernels` bundle (must move together due to fileprivate↔internal access ladder) — candidate for 2B-4.
5. `OpticsCompositor` (large — Metal dispatch + glow family + vignette + mip math + 5 closed-over `private var` flags) — candidate for 2B-5; must keep frame-loop flag mutation semantics intact.
6. `GradeRenderPipeline` (kernel chain order is the canonical contract) — candidate for 2B-6; needs the 2C parity gate to ship.
7. `ExportMediaWriter` (frame loop owns the depth/timeline state) — candidate for 2B-7, paired with sidecar parity gate (2C).

This stays the working order unless the build reveals a smaller-scope blocker.

## This sub-stage's single extraction

Move `extension ISO8601DateFormatter` into a new file:

- New file: `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarDateFormatter.swift`
- Removed lines in `FilmtoneExportSession.swift`: 3659–3667 (the `extension ISO8601DateFormatter` block).
- pbxproj: register the new file in `PBXBuildFile`, `PBXFileReference`, `PBXGroup` (`Export/Internal`), and `PBXSourcesBuildPhase` for the `App` target.
- Existing call sites need **no changes** because the extension is module-scoped today and remains module-scoped after the move:
  - `FilmtoneExportSession.swift:472`
  - `FilmtoneExportSession.swift:519`
  - `Editor/FilmtoneEditorStore.swift:1776`

This is the minimum that exercises the pbxproj registration mechanic on
this round and removes a piece of cross-cutting state from the monster
file. It also lets future sidecar parity gates (Phase 2C) reference the
formatter without anchoring to ExportSession.

## Checklist

- [x] Add `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarDateFormatter.swift` with the `extension ISO8601DateFormatter` block.
- [x] Remove the corresponding 10-line block (former lines 3659–3668, the extension body plus its trailing blank line) from `FilmtoneExportSession.swift`.
- [x] Register the new file via `xcodeproj` (`PBXBuildFile` + `PBXFileReference` + `PBXSourcesBuildPhase` + parent `PBXGroup`).
- [x] `grep -c 'ExportSidecarDateFormatter.swift' project.pbxproj` >= 4.
- [x] `bun run verify:ios` — PASS.
- [x] `git diff --check` — PASS.

## Verification

- `grep -c 'ExportSidecarDateFormatter' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj` = **4** (PBXBuildFile line 12, PBXFileReference line 298, PBXGroup `Internal` line 383, PBXSourcesBuildPhase line 901).
- `bun run verify:ios` — **PASS (exit 0)** with the following gates green: generated swift contract drift check, iOS xcodebuild build, iOS grain catalog (`[ios-grain-catalog] ok`), iOS swift contract, motion blur math, cube parser, capture transform LUT classifier, cache store, source-color classifier + normalizer + HDR policy, ray-angle optics, source profile math (D-Log, D-Log M + D-Gamut M, C-Log, C-Log 3 + Cinema Gamut, V-Log, S-Log3 — each linearization max |Δ| = 0.000000 within 1e-3 budget; Macbeth ΔE2000 max = 0.000 mean = 0.000 within 2.0/1.0 budget; full-frame max = 0.000 mean = 0.000 within 2.0/0.5 budget), look × veil energy merge (10 tests), sidecar builder.
- `git diff --check` — **PASS (exit 0)**, no whitespace issues.
- Pre-existing Swift 6 Sendable / actor isolation warnings on `FilmtoneMediaRuntime`, `FilmtoneExportSession`, and `BenchmarkCollector` are unchanged (no new diagnostic introduced by the extraction).

## Done Conditions

- `FilmtoneExportSession.swift` no longer contains the `ISO8601DateFormatter` extension.
- `Export/Internal/ExportSidecarDateFormatter.swift` is the unique definition of `ISO8601DateFormatter.filmtoneSidecar` and is the only file owning the sidecar date format.
- All gates green.
- This sub-stage does **not** rename, alter sidecar order, change render math, change kernel chain order, or change any public API.

## Stop Conditions

- Stop after 3 consecutive build/verification failures.
- Stop if extracting the formatter touches a call site signature or import set in any consumer file beyond the new `Foundation` import.
- Stop if the App target's `PBXSourcesBuildPhase` file count changes by anything other than +1.

## Out Of Scope

- Moving `FilmtoneSharedGradeProcessor`, `FilmtoneMotionBlurAccumulator`, or `OpticalKernels`.
- Splitting any `apply*` stage out of `applyGrade`.
- View-side changes (Capture / Editor / Source).
- New parity fixtures.

## Unexpected / Follow-up

- The Foundation `extension ISO8601DateFormatter` was lifted as-is; no
  call sites required edits because the extension's access remains
  module-internal in its new home (`Editor/FilmtoneEditorStore.swift:1776`
  continues to resolve the same symbol).
- `FilmtoneExportSession.swift` is now 4488 lines (down 10 from 4498).
- **2B-2 plan correction (2026-05-11 JST, owner)**: the Source-profile /
  input-LUT helpers (~330 lines of currently `private static` factories)
  must be extracted into an **independent internal helper type** under
  `Export/Internal/` (e.g. `ExportSourceProfileResolver` /
  `ExportInputLutBuilder`), **not** an `extension FilmtoneExportSession`
  in a new file. Splitting a god object into a separate file that is
  still an extension of the same class keeps the responsibility on the
  god class and defeats the lane's purpose. Call sites inside
  `FilmtoneExportSession` must be rewritten to use the helper type.
  Recorded as `feedback_no_extension_only_file_for_god_object_split` in
  user memory.
- The compatibility table row "Source-profile input-LUT helpers" in the
  Responsibility Inventory above lists the move target as
  `Export/Internal/InputLutBuilders.swift`. That move target is correct,
  but per the 2B-2 plan correction the destination is an independent
  helper type, not an extension on `FilmtoneExportSession`.
