# Filmtone iOS Feature-Based Architecture Refactor

Date: 2026-05-11 JST

## Placement

```text
docs/filmtone/ios/feature-architecture-refactor/
├── strategy.md   ← this file
├── active.md     ← current ≤ 30-min sub-task
└── archive/      ← per-task PASS/REJECT logs
```

This lane is downstream of v2-capture-gyroflow (closed M14+M15 PASS) and
capture-practicality (S1-S5 paused awaiting owner smoke). The 1.8 release
is `PENDING_DEVELOPER_RELEASE` (ASC approved, manual public release pending)
on top of public 1.7. The refactor branch (`feature/ios-feature-architecture`)
is based on `main @ dac08c81` (1.8 build 7 dirty state remains on main and
is not carried into this branch — to be committed by owner separately).

## Product Direction

Make the iOS native SwiftUI codebase ready for Gyroflow integration and V2
capture extensions by removing structural drag from three god objects and
the flat 111-file namespace.

This is essence work, not cosmetic reorg:

- `FilmtoneExportSession.swift` 5032 lines / 99 methods bundles decode,
  grade, Metal optics, writer, and sidecar metrics. Performance work and
  metrics work cannot proceed independently while they live in one file.
- `FilmtoneEditorStore.swift` 3441 lines / 106 methods / 14 types is the
  single ObservableObject every new project state must thread through.
- `FilmtoneCaptureSession.swift` 1849 lines / 43 methods bundles device,
  format, storage policy, state machine, and writer handoff. Gyroflow and
  V2 capture extensions cannot land cleanly through this monolith.
- `ios/App/App/` flat with 111 .swift files plus one .metal forces every
  search to scan the whole namespace.

## Execution Bias

- Essence first: split god objects to enable next product moves; do not
  treat folder reorg as the goal.
- No silent fallback: parity gates fail loud; thermal, lens, codec, color
  invariants are preserved exactly.
- Outer shell minimal: no new XCTest matrices, no formal QA grid, no
  banner / i18n decoration unless owner explicitly asks for QA.
- No conservative hedge: do not defer god-object splits if they are the
  blocker. Do not introduce silent fallbacks during extraction.

## Measurable Done Conditions

This lane is done when:

1. Every Swift source file lives in one of 10 feature folders (`Root/`,
   `Capture/`, `Editor/`, `Export/`, `Look/`, `Optics/`, `Source/`,
   `Services/`, `Smoke/`, `Strings/`) + the existing `ExportActivity/`
   target folder. No flat root `.swift` files. Note: `Root/` (not `App/`)
   houses entry surfaces because the pbxproj parent group is already named
   `App` and `App/App/` nesting would be confusing.
2. `FilmtoneExportSession` is a thin orchestrator (~1000 lines) backed by
   GradeRenderPipeline / OpticsCompositor / ExportMediaWriter /
   DepthPayloadManager / ExportMetrics. Sidecar canonical diff against a
   committed fixture is byte-identical. Still-export PNG byte diff is 0
   (or sidecar parity alone if encoder non-determinism shows up).
3. `FilmtoneEditorStore` is a thin facade (~500 lines) over ProjectState /
   LibraryManager / PreviewOrchestrator / ExportCoordinator / CaptureRelay.
   View files are unchanged except where the Phase 3A inventory ruled
   minimal adjustments necessary.
4. `FilmtoneCaptureSession` is a thin facade (~600 lines) over
   CaptureDeviceManager / RecordingStateController / CapturePackageAssembler
   with `sessionQueue` ownership decided in Phase 4A.
5. `bun run verify:ios` is green at every commit.
6. Real-device (iPhone 17 Pro Max iOS 26.2, UDID
   `D3011FE4-52CA-4B7F-B181-A55D9998E192`) capture smoke after Phase 4
   completes one record → grade → export cycle.

## Milestones

- **Phase 1A** — Lane docs + 111-file mapping + external reference
  inventory + Ruby pbxproj dry-run. No filesystem changes. ~0.5 day.
- **Phase 1B** — `git mv` + pbxproj rewrite + path repair on 3 external
  scripts + `verify:ios` + `git diff --find-renames` gate. ~1 day.
- **Phase 2A** — Extract top-level private helpers from ExportSession to
  `Export/Internal/` without changing public surface. ~0.5 day.
- **Phase 2B** — Public surface split into 6 files, `FilmtoneSharedGrade
  Processor` moves to `Look/` with API unchanged. ~2 days.
- **Phase 2C** — Sidecar canonical diff + still PNG byte diff against
  committed fixture. ~0.5 day.
- **Phase 3A** — `$store.` and `store.` access inventory across views,
  compatibility table written into active.md. No code changes. ~0.5 day.
- **Phase 3B** — Sub-store extraction with bridge strategy per
  compatibility table. ~3 days.
- **Phase 3C** — Simulator view-side smoke covering all sheets, library,
  compare. ~0.5 day.
- **Phase 4A** — sessionQueue + delegate ownership decisions written into
  active.md. ~0.5 day.
- **Phase 4B** — Capture extraction + real-device smoke. ~2 days.

Total: 11-13 working days.

## Out Of Scope

- View body decomposition (`FilmtoneFullscreenLutEditor` 1262 lines /
  `FilmtoneCaptureView` 1086 lines). SwiftUI body size is structural;
  velocity impact is small relative to god-object splits.
- XCTest expansion, formal QA matrices, PSNR fixtures beyond Phase 2C.

## Interrupt / Decision Log

- 2026-05-11 JST — Lane opened on
  `feature/ios-feature-architecture` branch fast-forwarded to
  `main @ dac08c81`. 1.8 release dirty state on owner's main worktree is
  not carried into this branch (owner commits when ready; merge strategy
  is straight merge because 1.8 bump touches build settings while refactor
  touches file references — different pbxproj sections).

## Completion Log

- 2026-05-11 JST — Phase 1B source layout migration is complete in the
  feature worktree: 109 former root files moved into 10 feature folders,
  pbxproj and active script paths repaired, `bun run verify:ios` green.
- 2026-05-11 JST — Phase 2A helper extraction is complete: export models,
  render-stage metrics, and prepared LUT helpers moved into
  `Export/Internal/`; pbxproj registration and `bun run verify:ios` green.
- 2026-05-11 JST — Phase 2B-1 (sidecar formatter extraction + ExportSession
  responsibility inventory) is complete in the feature worktree.
  `extension ISO8601DateFormatter { static let filmtoneSidecar }` moved to
  `Export/Internal/ExportSidecarDateFormatter.swift`; FilmtoneExportSession.swift
  reduced from 4498 to 4488 lines; pbxproj 4-section registration verified;
  `bun run verify:ios` green; `git diff --check` clean. Owner correction
  recorded: subsequent extractions (2B-2 onward) must produce independent
  helper types, not extensions on `FilmtoneExportSession`. See
  `archive/2026-05-11-phase-2b-1-sidecar-formatter-extraction.md`.
- 2026-05-11 JST — Phase 2B-2 (source-profile / input-LUT helpers
  extraction) committed as `c3a87601`. Two independent `enum`-namespace
  helper types landed under `Export/Internal/`:
  `ExportInputLutBuilder.swift` (input-LUT factories + Apple Log math +
  `synthesizedInputLutCache`) and `ExportSourceProfileResolver.swift`
  (sidecar provenance + `implTag`). `FilmtoneExportSession.swift`
  reduced from 4488 → 4178 lines (−310); 4 call sites rewritten from
  `Self.<helper>` to the new namespaces; `makePreparedLut ?? makeActiveInputLut`
  fallback preserved verbatim; 5 cosmetic comment updates in
  Editor/Source files. pbxproj 4-section grep = 4 each; `bun run verify:ios`
  green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-2-source-profile-input-lut-helpers-extraction.md`.
- 2026-05-11 JST — Phase 2B-3 (depth payload manager extraction)
  committed as `205f2b54`. New `enum` namespace
  `ExportDepthPayloadManager` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportDepthPayloadManager.swift`
  (99 lines) now owns the video-depth reader probe + per-frame pull
  sync-bridge. `request.depthEnabled` lifted to a parameter so the
  helper is stateless; `DispatchSemaphore` byte-identical to pre-move.
  `FilmtoneExportSession.swift` reduced from 4178 → 4094 lines (−84);
  two call sites rewritten (`resolveVideoDepthReader` →
  `ExportDepthPayloadManager.resolveReader(asset:depthEnabled:)`,
  `pullNextVideoDepthFrame` → `ExportDepthPayloadManager.pullNextFrame`);
  `PullResult` case names (`.frame` / `.endOfStream` / `.failure`)
  unchanged so the frame-loop `switch` body needed no per-case edit.
  pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-3-depth-payload-manager-extraction.md`.
- 2026-05-11 JST — Phase 2B-4 (shared grade processor + motion blur
  accumulator + optical kernels atomic bundle) committed as `7ff201c9`.
  Three coupled top-level types lifted out of `FilmtoneExportSession.swift`
  in one sub-stage because their `fileprivate ↔ private ↔ internal`
  access ladder had to move atomically:
  `final class FilmtoneSharedGradeProcessor` →
  `Look/FilmtoneSharedGradeProcessor.swift` (cross-cutting visual
  contract; 9 cross-file consumers' diff = 0 because type name preserved);
  `final class FilmtoneMotionBlurAccumulator` →
  `Export/Internal/FilmtoneMotionBlurAccumulator.swift`;
  `enum OpticalKernels` →
  `Export/Internal/OpticalKernels.swift` (CIKernel/CIColorKernel source
  strings byte-identical). `FilmtoneExportSession.swift` reduced from
  4094 → 3189 lines (−905). 6 `fileprivate` modifiers dropped on the
  exact members the moved types read across the module boundary
  (`ciContext`, `colorPipeline`, `renderablePreviewVideoImage`,
  `applyLivePreviewGrade`, `outputFrameRate`,
  `makeMotionBlurAccumulator`) plus 1 `private` dropped on the free
  function `filmtonePreviewCompositionDebugLog`; `applyGrade`'s
  `fileprivate` remains by design. pbxproj 4-section grep = 4 each;
  `bun run verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-4-shared-grade-motion-blur-optical-kernels-bundle.md`.
- 2026-05-11 JST — Phase 2B-5A (optics resampling pure-helper extraction)
  is complete in the feature worktree. New `enum` namespace
  `OpticsResampling` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsResampling.swift`
  (234 lines) now owns the 15 optics constants and 14 pure helpers
  (`buildMipPyramid` / `downsampledImage` / `upsampledImage` /
  `tentDownsampledImage` / `tentUpsampledImage` / `scaledImage` /
  `weightedImage` / `addImages` / `blackImage` / `extentOriginVector` /
  `extentSizeVector` / `computeMipWeights` / `halationColor` /
  `aberrationEdgeSoften`) lifted out of `FilmtoneExportSession.swift`.
  Bodies copied verbatim; 42 `Self.<name>` call sites rewritten to
  `OpticsResampling.<name>`; `Self.clamp` (10 sites), `Self.lerp`
  (1 site), and `Self.makeStableSourceSeed` (1 site) preserved per 5A
  scope (clamp has 30+ non-optics call sites on `FilmtoneExportSession`,
  so a 2-arg fallback is duplicated as `private static func` inside
  `OpticsResampling`). Metal flag stored properties
  (`useMetalOpticsForExport` / `metalOpticsRenderer` /
  `metalOpticsActiveOnce` / `metalVignetteActiveOnce` /
  `metalVignetteAppliedThisFrame` / `loadedDepthMap`) and the 10
  optics-touching instance methods (`applyEdgeOpticsStage` /
  `applyGlowFamilyStage` / `applyVignetteStage` / `vignetteFrameParams` /
  `currentBacklightVeilProfile` / `applyBacklightVeilSpatialOverrides` /
  `extractHighlightPlate` / `applyRadialRGBShift` / `applyEdgeSoftness` /
  `buildMipBlurComposite`) remain on `FilmtoneExportSession` for Phase
  2B-5B `OpticsCompositor`. One out-of-spec 1-line text edit in
  `Optics/FilmtoneMetalOpticsRenderer.swift:832` (mirror-pointer
  comment `Mirrors FilmtoneExportSession.halationColor` →
  `Mirrors OpticsResampling.halationColor`) flagged in archive
  Unexpected/Follow-up per `feedback_no_sweeping_diff_claims`.
  `FilmtoneExportSession.swift` reduced from 3189 → 2984 lines (−205).
  pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-5a-optics-resampling-extraction.md`.
- 2026-05-11 JST — Phase 2B-5B (stateful optics compositor extraction)
  committed as `ca6579a3`. New `final class OpticsCompositor` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  (671 lines) now owns the Metal optics gate / renderer lifecycle,
  once-per-export Metal telemetry flags, per-frame vignette skip flag,
  Backlight Veil profile resolution, edge optics, glow family, vignette,
  CI fallback path, and depth-prefilter timing accumulation.
  `FilmtoneExportSession.swift` reduced from 2984 → 2400 lines (−584)
  and delegates optics stages through the compositor while keeping
  `loadedDepthMap` lifetime on the session. Two now-dead private
  `FilmtoneExportSession.clamp` / `lerp` helpers were deleted after the
  move left them with zero callers. pbxproj 4-section grep = 4;
  `bun run verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-5b-optics-compositor-extraction.md`.
- 2026-05-11 JST — Phase 2B-6A (GradeRenderPipeline color-stage
  extraction) committed as `4c18c763`. New `final class
  GradeRenderPipeline` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  (175 lines) now owns prepared input / creative LUT state and the
  non-optics color stages: input LUT, base grade, tone compression,
  creative LUT, print, and LUT application. `FilmtoneExportSession.swift`
  reduced from 2400 → 2262 lines (−138) while preserving the full
  `applyGrade` stage order and recording-monitor reduced stage list.
  pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-6a-grade-render-pipeline-color-stages.md`.
- 2026-05-11 JST — Phase 2B-7A (ExportMediaWriter primitive extraction)
  committed as `0a895169`. New `final class ExportMediaWriter` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMediaWriter.swift`
  (231 lines) now owns writer setup, video reader-output setup, audio
  pipeline setup, audio append, finish/wait, and CMTime helpers.
  `FilmtoneExportSession.swift` reduced from 2262 → 2080 lines (−182);
  `exportVideo`, `exportStillImage`, and `appendVideoSample` remain on
  the session for the next frame-append boundary pass. The zero-caller
  `estimatedVideoFrameRate(for:)` helper was deleted. pbxproj 4-section
  grep = 4; `bun run verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-7a-export-media-writer-primitives.md`.
- 2026-05-11 JST — Phase 2B-7B (ExportFrameAppender extraction)
  committed as `c1c236f4`. New `final class ExportFrameAppender` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportFrameAppender.swift`
  (122 lines) now owns per-frame writer readiness wait,
  pixel-buffer-pool allocation, CI render, output color metadata
  application, adaptor append, and matching wait/build/render/append
  signposts + performance metrics. `FilmtoneExportSession.swift`
  reduced from 2080 → 2031 lines (−49); `renderableImage` stays on the
  session through a render closure so grade / motion / depth order is
  unchanged. pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-7b-export-frame-appender-extraction.md`.
- 2026-05-11 JST — Phase 2B-8A (ExportSourceImageNormalizer extraction)
  committed as `f795eb2b`. New `final class ExportSourceImageNormalizer`
  at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceImageNormalizer.swift`
  (161 lines) now owns still-source loading, video pixel-buffer wrapping
  with HDR tone-map detection, AVAssetTrack → Core Image orientation
  transform, still/video/preview scale-crop, and preview extent
  validation. `FilmtoneExportSession.swift` reduced from 2031 → 1896
  lines (−135); `MezzanineService` now calls the same transform math via
  the new namespace. Dead zero-caller `scaledVideoFrameImage(...)` was
  deleted. pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-8a-export-source-image-normalizer-extraction.md`.
- 2026-05-11 JST — Phase 2B-8B (ExportConnectPackageAssembler
  extraction) committed as `774ba264`. New `final class
  ExportConnectPackageAssembler` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportConnectPackageAssembler.swift`
  (151 lines) now owns Filmtone Connect source-media copy, combined /
  pre-optical / post-optical cube writes, DCTL write, reference-after
  path orchestration via a session closure, `SidecarPackage` payload, and
  ordered package-file URI construction. `FilmtoneExportSession.swift`
  reduced from 1896 → 1805 lines (−91); `writeExportSidecar` and
  reference-after JPEG rendering stay on the session. pbxproj 4-section
  grep = 4; `bun run verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-8b-export-connect-package-assembler-extraction.md`.
- 2026-05-11 JST — Phase 2B-8C (ExportSidecarWriter extraction)
  committed as `445a0e10`. New `final class ExportSidecarWriter` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarWriter.swift`
  (193 lines) now owns sidecar identity/depth/Saved Look/Camera Profile
  block assembly, `SidecarBuildInputs` construction, sidecar URL
  resolution, atomic write, and nil-on-failure logging. The session
  passes a write-time `Telemetry` snapshot for mutable decode/depth /
  mezzanine truth fields. `FilmtoneExportSession.swift` reduced from
  1805 → 1701 lines (−104); `FilmtoneExportSidecarBuilder.swift`
  remains untouched. pbxproj 4-section grep = 4; `bun run verify:ios`
  green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-8c-export-sidecar-writer-extraction.md`.
- 2026-05-11 JST — Phase 2B-9A (ExportStillImageWriter extraction)
  committed as `3cbeb7f7`. New `final class ExportStillImageWriter` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportStillImageWriter.swift`
  (125 lines) now owns the post-grade still-image writer/adaptor
  setup, 3-second frame loop, CI render, output metadata, append,
  progress, finish, and `CompletedExport` assembly. `FilmtoneExportSession.swift`
  reduced from 1701 → 1646 lines (−55); still source loading, HEIC
  depth loading, output-size calculation, and `renderableStillImage`
  remain session-owned. pbxproj 4-section grep = 4; `bun run
  verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-9a-export-still-image-writer-extraction.md`.
- 2026-05-11 JST — Phase 2B-9B (ExportMezzanineRouter extraction)
  committed as `e0ad9cd7`. New `final class ExportMezzanineRouter` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMezzanineRouter.swift`
  (256 lines) now owns preview/export source routing, quality prewarm,
  route validation, consumed mezzanine URL/metrics snapshot, and
  `disabled-on-ios` validation status. `FilmtoneExportSession.swift`
  reduced from 1646 → 1457 lines (−189); session still owns
  `AVURLAsset` opening, depth reader, writer/reader setup, frame loop,
  and sidecar property storage. pbxproj 4-section grep = 4; `bun run
  verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-9b-export-mezzanine-router-extraction.md`.
- 2026-05-11 JST — Phase 2B-9C (ExportPreviewRenderer extraction)
  committed as `9d50b705`. New `final class ExportPreviewRenderer` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportPreviewRenderer.swift`
  (183 lines) now owns still/video preview rendering, poster-time
  selection, preview CGImage tolerance fallback, preview JPEG writing, and
  Connect reference-after JPEG writing. `FilmtoneExportSession.swift`
  reduced from 1457 → 1361 lines (−96); public `renderPreviewFrame()`
  stays as a cache-clearing facade and `applyGrade` stays session-owned
  via closure. pbxproj 4-section grep = 4; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-9c-export-preview-renderer-extraction.md`.
- 2026-05-11 JST — Phase 2B-10A (ExportVideoDepthMatcher extraction)
  committed as `33551dae`. New `final class ExportVideoDepthMatcher` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoDepthMatcher.swift`
  (80 lines) now owns per-frame video depth cursor state and the
  depth-track pull loop. `FilmtoneExportSession.swift` reduced from
  1361 → 1334 lines (−27); session still owns depth telemetry assignment
  and updates `loadedDepthMap`, `videoDepthDecodeMs`,
  `videoDepthFramesProcessed`, and `depthResolution`. pbxproj 4-section
  grep = 4; `bun run verify:ios` green; `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-10a-export-video-depth-matcher-extraction.md`.
- 2026-05-11 JST — Phase 2B-10B (ExportVideoTimeline extraction)
  committed as `40d24fdd`. New `final class ExportVideoTimeline` at
  `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportVideoTimeline.swift`
  (88 lines) now owns output frame count / duration, presentation time,
  source lookup time, source segment index, lazy source-time-offset
  normalization, timed sample shape, and rendering progress math.
  `FilmtoneExportSession.swift` reduced from 1334 → 1296 lines (−38);
  decode / lookahead / append orchestration remains session-owned.
  The live rendering-progress multiplier remains `0.74`; the 10B active
  doc corrected an earlier `0.78` planning typo before commit. pbxproj
  4-section grep = 4; `bun run verify:ios` green; `git diff --check`
  clean. See
  `archive/2026-05-11-phase-2b-10b-export-video-timeline-extraction.md`.
- 2026-05-11 JST — Phase 2B-10C (video export queue bundle) committed
  as `90553a4d`. Three queue collaborators landed under
  `Export/Internal/`: `ExportVideoCompletionCoordinator` (119 lines)
  owns dispatch-group / first-error lifecycle, `ExportVideoFramePump`
  (191 lines) owns video sample decode / lookahead / output-frame loop /
  progress cadence, and `ExportVideoAudioPump` (84 lines) owns the audio
  queue body. `FilmtoneExportSession.swift` reduced from 1296 → 1127
  lines (−169); session still owns writer/reader setup, depth prep,
  render/append closure, and `CompletedExport` assembly. pbxproj
  4-section grep = 4 for all 3 files; `bun run verify:ios` green;
  `git diff --check` clean. See
  `archive/2026-05-11-phase-2b-10c-video-export-queue-bundle.md`.
