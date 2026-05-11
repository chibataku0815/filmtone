# Active - Phase 2B-6A GradeRenderPipeline Color Stage Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Start the GradeRenderPipeline split by moving the non-optics
color stages and LUT application out of `FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  orchestrator. Do not turn this into another inventory-only pass.
- Product quality is the bar: grade math, LUT application, kernel
  selection, kernel argument order, and stage order must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture, or
  formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `GradeRenderPipeline` type under `Export/Internal/`.

## Goal

Create `Export/Internal/GradeRenderPipeline.swift` and move the pure
color-stage half of the grade pipeline out of `FilmtoneExportSession`.

This is 2B-6A, not the entire GradeRenderPipeline final form. It moves the
stages that do not need ExportSession decode/write state:

- input LUT application
- base grade kernel dispatch
- tone compression kernel dispatch
- creative LUT application
- print stage kernel dispatch
- shared LUT application helper

`FilmtoneExportSession.applyGrade` keeps the stage ordering for now and
delegates these color stages to `GradeRenderPipeline`. The optics stages
remain delegated to `OpticsCompositor`; grain remains on ExportSession in
this sub-stage because it depends on `sourceSeed` and time.

## Live Inventory As Of 2B-5B

### Fields to move or route

| Member | Current line | 2B-6A owner | Notes |
|---|---:|---|---|
| `preparedInputLut` | 88 | `GradeRenderPipeline` | Built in `FilmtoneExportSession.init`, then passed to pipeline init. |
| `preparedCreativeLut` | 89 | `GradeRenderPipeline` | Same as above. |
| `outputColorSpace` | 91 | keep on `FilmtoneExportSession`, pass to pipeline | Still used by render profiler, motion blur, sidecar/profile paths. Do not move ownership. |

### Methods to move

| Method | Current line | New shape |
|---|---:|---|
| `applyInputLutStage(to:)` | 1728 | `GradeRenderPipeline.applyInputLutStage(to:)` |
| `applyBaseGradeStage(to:params:presetVersion:)` | 1735 | `GradeRenderPipeline.applyBaseGradeStage(to:params:presetVersion:)` |
| `applyToneCompressionStage(to:params:presetVersion:)` | 1797 | `GradeRenderPipeline.applyToneCompressionStage(to:params:presetVersion:)` |
| `applyCreativeLutStage(to:)` | 1846 | `GradeRenderPipeline.applyCreativeLutStage(to:)` |
| `applyPrintStage(to:params:)` | 1853 | `GradeRenderPipeline.applyPrintStage(to:params:)` |
| `applyLut(_:to:)` | 1877 | private helper on `GradeRenderPipeline` |

### Methods to keep on ExportSession in 2B-6A

| Method | Reason |
|---|---|
| `applyGrade(to:timeSeconds:stageProfilingOutputSize:)` | Keeps total stage order while 2B-6A extracts color stages. |
| `applyLivePreviewGrade(to:timeSeconds:mode:)` | Public/internal surface used by preview/shared grade consumers. |
| `applyRecordingMonitorGrade(to:)` | Rewire its color stage calls, but keep the method on ExportSession for now. |
| `applyGrainStage(to:params:timeSeconds:)` | Depends on `sourceSeed` and belongs to a later grade/grain boundary decision. |
| `profileRenderSubstage` | Profiling lifecycle stays on ExportSession for now. |

## Intended Implementation Shape

Add:

```swift
final class GradeRenderPipeline {
    private let preparedInputLut: PreparedLut?
    private let preparedCreativeLut: PreparedLut?
    private let outputColorSpace: CGColorSpace

    init(
        preparedInputLut: PreparedLut?,
        preparedCreativeLut: PreparedLut?,
        outputColorSpace: CGColorSpace
    )

    func applyInputLutStage(to image: CIImage) -> CIImage
    func applyBaseGradeStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        presetVersion: String
    ) -> CIImage
    func applyToneCompressionStage(
        to image: CIImage,
        params: Phase0ParamsDTO,
        presetVersion: String
    ) -> CIImage
    func applyCreativeLutStage(to image: CIImage) -> CIImage
    func applyPrintStage(to image: CIImage, params: Phase0ParamsDTO) -> CIImage
}
```

`applyLut(_:,to:)` should become a private helper on the new type.

In `FilmtoneExportSession`:

- replace `preparedInputLut` / `preparedCreativeLut` stored properties
  with `private let gradeRenderPipeline: GradeRenderPipeline`.
- keep building prepared LUTs in `init` with the existing
  `ExportInputLutBuilder` calls and legacy creative LUT fallback. Assign
  them to local constants and pass them into `GradeRenderPipeline`.
- replace call sites in `applyGrade` and `applyRecordingMonitorGrade`:
  `applyInputLutStage` → `gradeRenderPipeline.applyInputLutStage`, etc.
- keep `outputColorSpace` on `FilmtoneExportSession`; pass it into
  `GradeRenderPipeline` init.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - remove moved color-stage methods and prepared LUT storage
  - add one `gradeRenderPipeline` collaborator
  - delegate color stage calls from full preview and recording monitor paths
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/GradeRenderPipeline.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `GradeRenderPipeline.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-5b-optics-compositor-extraction.md`
  - precedent for stateful collaborator extraction
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticsCompositor.swift`
  - current optics collaborator, read-only in 2B-6A
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/OpticalKernels.swift`
  - kernel definitions, read-only
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportInputLutBuilder.swift`
  - prepared LUT factory, read-only

## Checklist

- [ ] Create `Export/Internal/GradeRenderPipeline.swift` with the imports
  required by moved methods (`CoreGraphics`, `CoreImage`, `FilmLabSwiftCore`
  if needed for `Phase0ParamsDTO`, `Foundation` only if the compiler needs
  it).
- [ ] Move `preparedInputLut` / `preparedCreativeLut` ownership into
  `GradeRenderPipeline`.
- [ ] Keep `outputColorSpace` on `FilmtoneExportSession` and pass it into
  `GradeRenderPipeline`.
- [ ] Move the six methods listed above into `GradeRenderPipeline`.
- [ ] Rewire `applyGrade` color stage calls to `gradeRenderPipeline`.
- [ ] Rewire `applyRecordingMonitorGrade` color stage calls to
  `gradeRenderPipeline`.
- [ ] Register `GradeRenderPipeline.swift` in pbxproj 4 sections.
- [ ] Verify
  `rg -n "private func (applyInputLutStage|applyBaseGradeStage|applyToneCompressionStage|applyCreativeLutStage|applyPrintStage|applyLut)" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [ ] Verify
  `rg -n "preparedInputLut|preparedCreativeLut" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns only expected init-local or `GradeRenderPipeline` init argument
  references, not stored properties.
- [ ] `grep -c 'GradeRenderPipeline.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `GradeRenderPipeline.swift`
- moved-method grep shows ExportSession no longer declares the six color
  stage helpers
- prepared LUT grep shows ExportSession no longer owns prepared LUT state
- `bun run verify:ios`
- `git diff --check`

Do not add sidecar canonical fixtures, PNG byte-diff fixtures, or
simulator smoke in 2B-6A unless the implementation changes behavior beyond
extraction.

## Done Conditions

- `FilmtoneExportSession.swift` delegates input LUT, base grade, tone
  compression, creative LUT, and print stage work to `GradeRenderPipeline`.
- `GradeRenderPipeline` owns prepared LUT state and LUT application.
- `outputColorSpace` remains available to ExportSession users that already
  need it.
- `applyGrade` stage order remains:
  input LUT → base grade → tone compression → edge optics → glow family →
  vignette → grain → creative LUT → print.
- `applyRecordingMonitorGrade` keeps its current reduced stage list:
  input LUT → base grade → tone compression → creative LUT → print.
- Kernel selection for `presetVersion` and kernel argument order remain
  equivalent.
- Public API, view code, sidecar schema, and DTO schema are untouched.
- `bun run verify:ios` and `git diff --check` are green.

## Stop Conditions

- Stop if moving these methods requires changing `applyGrade` stage order.
- Stop if `OpticalKernels` source strings or kernel argument order need to
  change.
- Stop if `outputColorSpace` ownership would need to leave ExportSession.
- Stop if sidecar schema/order or `FilmtoneExportSidecarBuilder` needs to
  change.
- Stop after 3 consecutive build or `verify:ios` failures.

## Out Of Scope

- Moving `applyGrade` itself.
- Moving `applyLivePreviewGrade`.
- Moving `applyRecordingMonitorGrade` itself.
- Moving `applyGrainStage`.
- Changing `OpticsCompositor`.
- `ExportMediaWriter`.
- Phase 2C parity fixtures.
- New XCTest, simulator smoke, or formal QA matrix.
- Any view code or public DTO/API schema change.

## Copy / History Impact

No copy/history impact expected: this is an internal iOS export
architecture extraction with no user-facing copy, release claim, or public
implementation-history wording change.

Article Opportunity: Developer note only after the broader ExportSession
split is complete, not for this sub-stage alone.

Change-History Opportunity: Mention in the eventual lane summary that
grade color stages became a separate pipeline after optics state moved to
`OpticsCompositor`.

## Unexpected / Follow-up

- None yet.
