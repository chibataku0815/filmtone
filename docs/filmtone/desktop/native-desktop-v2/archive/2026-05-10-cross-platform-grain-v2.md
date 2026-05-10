# Active - Cross-Platform Grain V2

Date opened: 2026-05-10 JST
Milestone: `M3 Native Color And Optics Parity` / `M4 Shared Contract Consolidation`

## Goal

Raise Filmtone grain quality beyond the current old-renderer parity level on
iOS and Native Desktop with one shared native Core Image kernel. The product
target is calmer video grain, cleaner skin/highlights, stronger luma texture in
B&W and near-monochrome footage, and more organic shadow/midtone grain without
schema or UI identity churn.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheetData.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
- `apps/filmtone-desktop-macos/Verify/main.swift`
- `scripts/check-ios-grain-catalog.mjs`
- this `active.md`

## Read-Only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md`
- `docs/filmtone/desktop/native-desktop-v2/archive/2026-05-10-cross-platform-grain-quality.md`
- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `packages/film-lab-renderer/src/webgl/shaders/composite.frag.ts`
- `packages/film-lab-renderer/src/webgpu/shaders/composite.frag.wgsl.ts`
- AOMedia Film Grain Synthesis / Kodak grain notes from the prior investigation.

## Plan

1. Implement a shared CIKL grain v2 kernel with temporal phase blending,
   tone-scaled strength, luma/chroma correlation, and softer coarse footprint.
2. Retune the existing UI-only grain recipes to the new kernel response.
3. Keep the public contract unchanged: no `grainType`, no generated Swift
   contract change, no sidecar field, no schema bump, no stage-order change.
4. Run only the smallest verification that proves the changed surface, then do
   broader visual QA only if the core implementation is good enough to warrant
   it.

## Checklist

- [x] Create the scoped grain v2 plan / `active.md`.
- [x] Update iOS grain kernel.
- [x] Update Native Desktop grain kernel with identical logic.
- [x] Retune iOS and Native Desktop grain recipe values.
- [x] Update existing catalog checks for recipe values.
- [x] Run Core Image kernel parse smoke and kernel identity check.
- [x] Run `bash apps/filmtone-desktop-macos/Verify/run.sh`.
- [x] Run `bun run verify:ios`.
- [x] Run `bun run verify:macos`.
- [x] Run `git diff --check`.
- [x] Record verification and archive this task.

## Verification

- Kernel identity diff between iOS `OpticalKernels.grain` and Native Desktop
  `FilmtoneGradeKernels.grain`: passed with no diff.
- Core Image `CIColorKernel(source:)` parse smoke for both grain sources:
  passed.
- `node scripts/check-ios-grain-catalog.mjs`: passed.
- `bash apps/filmtone-desktop-macos/Verify/run.sh`: passed, 124/124.
- `bun run verify:ios`: passed. Existing Core Image / AVFoundation
  deprecation warnings remain.
- `bun run verify:macos`: passed. Existing Core Image / AVFoundation
  deprecation warnings remain.
- `git diff --check`: passed.

## Done Conditions

- iOS `OpticalKernels.grain` and Native Desktop `FilmtoneGradeKernels.grain`
  remain identical.
- Grain motion is smoother than the current stepped refresh.
- Shadow/midtone grain reads organic without visible block/grid pattern.
- Skin/highlight chroma speckle is restrained.
- B&W and near-monochrome output favors luma grain over color noise.
- Existing public interfaces remain unchanged.

## Stop Conditions

- Done conditions are met.
- Stop on any unexpected need for schema, sidecar, generated Swift, release
  rail, or Metal/texture-pipeline changes.
- Stop after 3 consecutive verification failures on the same step.

## Out Of Scope

- `grainType` or persisted grain identity.
- Legacy Electron/WebGL/WebGPU implementation changes.
- Metal rewrite, blue-noise texture restoration, or new renderer pipeline.
- Release publication, App Store/TestFlight state, portfolio submodule work,
  staging, commit, or push.

## Unexpected / Blockers

None.
