# Active - Phase 2B-5B OpticsCompositor Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move the stateful optics compositor out of
`FilmtoneExportSession` after 2B-5A already extracted the stateless
resampling helpers.

## Owner Directive

- Essence first: this sub-stage must reduce the ExportSession god object,
  not produce a conservative inventory-only pass.
- Outer shell minimal: do not add XCTest fixtures, simulator UI smoke, or
  formal QA matrices here. Use the focused gates below.
- Product quality is the bar: Metal-vs-CI behavior, sidecar telemetry,
  Backlight Veil spatial/optical math, depth prefilter timing, and kernel
  argument order must be preserved exactly.
- No extension-only split. The target is an independent type,
  `OpticsCompositor`, not `extension FilmtoneExportSession`.

## Goal

Create `Export/Internal/OpticsCompositor.swift` and move the stateful
optics orchestration out of `FilmtoneExportSession.swift`.

5A moved the pure math. 5B moves the state boundary:

- Metal gate and renderer ownership
- Metal once/per-frame telemetry flags
- Backlight Veil profile resolution and spatial override merge
- edge optics / glow family / vignette / CI fallback orchestration
- depth prefilter timing accumulation for the glow trio

`FilmtoneExportSession` should keep the export order and call the
compositor as a collaborator. Public API and view code stay unchanged.

## Live Inventory As Of 2B-5A

### Stored state to move from ExportSession to OpticsCompositor

| Member | Current line | New owner | Notes |
|---|---:|---|---|
| `disableGlowFamilyForExport` | 76 | `OpticsCompositor` | Init from `FILMTONE_EXPORT_DISABLE_GLOW_FAMILY`. Sidecar disabled stage reads through compositor. |
| `useMetalOpticsForExport` | 81 | `OpticsCompositor` | Init from `FILMTONE_EXPORT_METAL_OPTICS`. Gate predicate unchanged. |
| `metalOpticsRenderer` | 82 | `OpticsCompositor` | Keep lazy init with the same `workingColorSpace` and `ciContext`. |
| `metalOpticsActiveOnce` | 87 | `OpticsCompositor` | `private(set)` telemetry surface for sidecar accelerated stages. |
| `metalVignetteActiveOnce` | 91 | `OpticsCompositor` | `private(set)` telemetry surface for sidecar accelerated stages. |
| `metalVignetteAppliedThisFrame` | 95 | `OpticsCompositor` | Private per-frame flag reset before grade and recording-monitor grade. |
| `depthPrefilterMs` | 115 | `OpticsCompositor` | Writer is inside moved glow-family path. ExportSession sidecar reads through compositor. |

### State to keep on ExportSession

| Member | Current line | Reason |
|---|---:|---|
| `request` | class init | ExportSession remains the source of export request truth. Pass it into the compositor at init. |
| `loadedDepthMap` | 112 | Depth payload lifetime belongs to still/video decode paths; pass the current value into `applyGlowFamilyStage`. |
| `depthResolution` / `videoDepth*` | 118-131 | Depth payload and reader accounting are not optics-compositor state. |
| `sourceSeed` | 104 | Grain stage stays on ExportSession in 5B. |
| `ciContext` / `colorPipeline` | 65-66 | Still shared by rendering and preview; pass dependencies into compositor. |

### Methods to move

Move these methods out of `FilmtoneExportSession` and keep their bodies
as close to verbatim as Swift access permits:

| Method | Current line | New shape |
|---|---:|---|
| `applyEdgeOpticsStage(to:params:)` | 1836 | `OpticsCompositor.applyEdgeOpticsStage(to:params:)` |
| `currentBacklightVeilProfile()` | 1861 | private compositor helper |
| `applyBacklightVeilSpatialOverrides(_:spatial:)` | 1897 | compositor helper, public/internal only if needed by ExportSession |
| `applyGlowFamilyStage(to:params:)` | 1940 | `OpticsCompositor.applyGlowFamilyStage(to:params:loadedDepthMap:)` |
| `vignetteFrameParams(image:params:)` | 2195 | private compositor helper |
| `applyVignetteStage(to:params:)` | 2230 | `OpticsCompositor.applyVignetteStage(to:params:)` |
| `extractHighlightPlate(from:threshold:knee:tintColor:)` | 2353 | private compositor helper |
| `applyRadialRGBShift(_:to:)` | 2371 | private compositor helper |
| `applyEdgeSoftness(to:aberrationSoften:lensSoftness:)` | 2391 | private compositor helper |
| `buildMipBlurComposite(from:radius:levelCount:spreadMultiplier:useTentResampling:)` | 2434 | private compositor helper |

Do not move `applyGrainStage` even though it uses
`OpticsResampling.extent*`; grain remains outside this optics-compositor
sub-stage.

## Intended Implementation Shape

### New type

Add:

```swift
final class OpticsCompositor {
    private let request: Phase0ExportRequestDTO
    private let disableGlowFamilyForExport: Bool
    private let useMetalOpticsForExport: Bool
    private let ciContext: CIContext
    private let colorPipeline: FilmtoneColorPipelineContract

    private lazy var metalOpticsRenderer: FilmtoneMetalOpticsRenderer? =
        FilmtoneMetalOpticsRenderer(
            workingColorSpace: colorPipeline.workingColorSpace,
            ciContext: ciContext
        )

    private(set) var metalOpticsActiveOnce = false
    private(set) var metalVignetteActiveOnce = false
    private var metalVignetteAppliedThisFrame = false
    private(set) var depthPrefilterMs: Double?

    var disabledRenderStages: [String] { ... }
    var acceleratedRenderStages: [String] { ... }

    func resetFrameState()
    func paramsApplyingBacklightVeil(to params: Phase0ParamsDTO) -> Phase0ParamsDTO
    func applyEdgeOpticsStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage
    func applyGlowFamilyStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        loadedDepthMap: FilmtoneDepthMap?
    ) -> CIImage
    func applyVignetteStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage
}
```

Names can be adjusted if Swift call sites become cleaner, but keep the
contract equivalent. The important boundary is: ExportSession delegates
optics stage work to one collaborator, and the collaborator owns Metal
state.

### ExportSession wiring

- Replace the six optics env/Metal stored properties with one
  `private let opticsCompositor: OpticsCompositor`.
- In `init`, compute env flags as local constants before logging:
  `let disableGlowFamilyForExport = Self.environmentFlagEnabled(...)`
  and `let useMetalOpticsForExport = Self.environmentFlagEnabled(...)`.
  Pass those locals into `OpticsCompositor`.
- Keep both current `NSLog` messages and their conditions unchanged,
  using the local env flag values.
- In `applyGrade`, replace:
  - Backlight Veil params merge with
    `opticsCompositor.paramsApplyingBacklightVeil(to: request.grade.params)`
  - `metalVignetteAppliedThisFrame = false` with
    `opticsCompositor.resetFrameState()`
  - `applyEdgeOpticsStage` / `applyGlowFamilyStage` /
    `applyVignetteStage` with compositor calls.
- In `applyRecordingMonitorGrade`, preserve the current reset by calling
  `opticsCompositor.resetFrameState()` even though no optics stages run
  in that path today.
- In the sidecar performance block, replace direct flag reads with:
  `opticsCompositor.disabledRenderStages` and
  `opticsCompositor.acceleratedRenderStages`.
- In `writeExportSidecar`, use `opticsCompositor.depthPrefilterMs`
  wherever the sidecar inputs currently read `depthPrefilterMs`.

### Access and helper policy

- Prefer moving helper bodies into `OpticsCompositor` over widening
  `FilmtoneExportSession`.
- Duplicate private `clamp` and `lerp` inside `OpticsCompositor`
  if needed. Do not move the existing `FilmtoneExportSession.clamp` or
  `FilmtoneExportSession.lerp`; they still serve non-optics code.
- Do not change `OpticsResampling` in 5B unless the compiler requires an
  access-level adjustment for the moved compositor.
- Do not alter `OpticalKernels` source strings or argument order.
- Do not change `FilmtoneMetalOpticsRenderer` behavior.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove moved optics state and methods
  - add one `opticsCompositor` collaborator
  - route optics stage calls and sidecar telemetry through it
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `OpticsCompositor.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist / unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-5a-optics-resampling-extraction.md`
  - 5A state-boundary inventory and `OpticsResampling` precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsResampling.swift`
  - pure optics constants and resampling helpers
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  - kernel definitions, read only
- `apps/capacitor-film-lab-ios/ios/App/App/Optics/FilmtoneMetalOpticsRenderer.swift`
  - Metal renderer contract, read only unless a stale comment must be corrected

## Checklist

- [x] Created `Export/Internal/OpticsCompositor.swift` with the four
  imports required by the moved methods (`CoreGraphics`, `CoreImage`,
  `FilmLabSwiftCore`, `Foundation`); no unused imports.
- [x] Moved six env/Metal stored properties and `depthPrefilterMs`
  ownership from ExportSession to `OpticsCompositor`. ExportSession
  retains `var depthPrefilterMs: Double? { opticsCompositor.depthPrefilterMs }`
  as a pass-through so `FilmtoneMediaRuntime.swift:629`
  (`collector.recordDepthPrefilterMs(session.depthPrefilterMs)`) keeps
  the existing accessor.
- [x] Kept `loadedDepthMap` on ExportSession and passed it into
  `OpticsCompositor.applyGlowFamilyStage(to:params:loadedDepthMap:)`.
- [x] Moved the 10 optics methods into `OpticsCompositor`:
  `applyEdgeOpticsStage`, `currentBacklightVeilProfile`,
  `applyBacklightVeilSpatialOverrides` (used through the new
  `paramsApplyingBacklightVeil(to:)` entry point), `applyGlowFamilyStage`,
  `vignetteFrameParams`, `applyVignetteStage`, `extractHighlightPlate`,
  `applyRadialRGBShift`, `applyEdgeSoftness`, `buildMipBlurComposite`.
- [x] Added private static `clamp` (2-arg fallback) and `lerp` on
  `OpticsCompositor` with bodies identical to ExportSession's previous
  helpers. ExportSession's own `Self.clamp` / `Self.lerp` turned out to
  have zero callers after the 10 optics methods moved (the active.md
  scope assumption that they "still serve non-optics code" was false in
  the post-5B state), so they were deleted in this same sub-stage
  rather than carried as a follow-up.
- [x] Rewired ExportSession call sites:
  `applyGrade` now calls `opticsCompositor.paramsApplyingBacklightVeil`,
  `resetFrameState`, `applyEdgeOpticsStage`, `applyGlowFamilyStage`,
  `applyVignetteStage`. `applyRecordingMonitorGrade` calls
  `resetFrameState`. The `run()` sidecar performance block reads
  `opticsCompositor.disabledRenderStages` and `acceleratedRenderStages`.
- [x] Registered `OpticsCompositor.swift` in pbxproj 4 sections with
  PBXBuildFile ID `B1E10001000000000000B209` and PBXFileReference ID
  `B1E10001000000000000B20A`. `grep -c 'OpticsCompositor.swift' …
  project.pbxproj == 4`.
- [x] Moved-method grep on ExportSession (10 method names) returns
  zero hits.
- [x] Moved-state grep on ExportSession returns only the six expected
  init-local/log references on lines 182, 183, 203, 204, 224, 227 (env
  flags passed into the compositor at init and logged once); no stored
  properties for the Metal state remain on the session.
- [x] `bun run verify:ios` passes (exit 0; xcodebuild build, grain
  catalog check, swift contract / D-Log / D-Log M / C-Log / C-Log 3 /
  V-Log / S-Log3 accuracy gates, motion blur math, cube parser, capture
  transform LUT classifier, cache store, source color classifier,
  ray-angle optics, source profile math, look × veil energy merge,
  sidecar builder all PASS).
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `OpticsCompositor.swift`
- moved-method grep shows ExportSession no longer declares the 10 optics
  methods
- moved-state grep shows ExportSession no longer owns the Metal state
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke or new fixtures in 5B unless the implementation
changes behavior beyond extraction.

## Done Conditions

- `FilmtoneExportSession.swift` delegates edge optics, glow family, and
  vignette stages to `OpticsCompositor`.
- `OpticsCompositor` owns Metal renderer lifecycle and Metal telemetry
  state.
- `loadedDepthMap` lifetime remains on ExportSession; compositor receives
  it per glow-family call.
- `acceleratedRenderStages` and `disabledRenderStages` sidecar inputs are
  equivalent to the pre-move logic.
- `depthPrefilterMs` accumulation remains equivalent and is still surfaced
  into sidecar inputs.
- Metal gate predicate remains exactly:
  `useMetalOpticsForExport && !disableGlowFamilyForExport &&
  request.sourceKind == .video && (request.renderMode ?? .quality) ==
  .quality && loadedDepthMap == nil && metalOpticsRenderer != nil`.
- CI fallback path and Backlight Veil composite path keep the same kernel
  order and argument order.
- `bun run verify:ios` and `git diff --check` are green.

## Stop Conditions

- Stop if the move requires changing sidecar schema, sidecar field order,
  or `FilmtoneExportSidecarBuilder`.
- Stop if kernel argument order or `OpticalKernels` source strings need to
  change.
- Stop if the Metal path would become unreachable or always-on.
- Stop if `loadedDepthMap` ownership needs to move out of ExportSession;
  that belongs to depth payload lifecycle, not compositor extraction.
- Stop after 3 consecutive build or `verify:ios` failures.

## Out Of Scope

- `GradeRenderPipeline` / `applyGrade` full extraction. 5B only delegates
  the optics stage calls from `applyGrade`.
- `ExportMediaWriter`.
- `ExportMetrics` redesign.
- New XCTest, PSNR, PNG parity fixtures, or simulator UI smoke.
- Any view code.
- Any public API or DTO schema change.
- Any change to `FilmtoneMetalOpticsRenderer` execution behavior.

## Copy / History Impact

No copy/history impact expected: this is an internal iOS export
architecture extraction with no user-facing copy, release claim, or public
implementation-history wording change.

Article Opportunity: Developer note only after the broader ExportSession
split is complete, not for this sub-stage alone.

Change-History Opportunity: Mention in the eventual lane summary that
Metal/CI optics state became an explicit compositor boundary before
GradeRenderPipeline extraction.

## Unexpected / Follow-up

- After the 10 optics methods moved, `private static func clamp` and
  `private static func lerp` on `FilmtoneExportSession` had zero
  remaining callers (verified by
  `grep -nE "Self\.(clamp|lerp)\(|FilmtoneExportSession\.(clamp|lerp)\("`
  returning empty across `apps/capacitor-film-lab-ios/` and
  `packages/`). Both helpers are `private`, so the assumption written
  earlier in this active.md ("they still serve non-optics code") was
  false in the post-5B state. The reviewer confirmed the observation
  and asked to fold the deletion into this same sub-stage instead of
  leaving it as a follow-up. Both functions were removed in-stage.

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  2984 → 2400 lines (−584). 5B move alone was 2984 → 2408 (−576); the
  in-stage `clamp` / `lerp` deletion contributed the remaining −8.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  new, 671 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  +4 lines (4-section registration; IDs B1E10001000000000000B209 /
  B1E10001000000000000B20A).
