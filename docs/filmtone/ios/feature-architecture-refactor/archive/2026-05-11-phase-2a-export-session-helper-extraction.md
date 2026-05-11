# Active — Phase 2A ExportSession Helper Extraction

Date: 2026-05-11 JST
Phase: Phase 2A — ExportSession internal helper extraction
Milestone: Export session split groundwork

## Goal

Reduce `FilmtoneExportSession.swift` by moving low-risk top-level helper
models and metrics utilities into `Export/Internal/`, while keeping the
public API, sidecar ordering, render math, and view-facing call sites
unchanged.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/`
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`

## Checklist

- [x] Extract `CompletedExport` and `FilmtoneHighlightReelFrameTimeline`
  into `Export/Internal/ExportSessionModels.swift`.
- [x] Extract `FilmtoneExportRenderSubstage`,
  `FilmtoneExportRenderStageProfiler`, and
  `FilmtoneExportPerformanceMetrics` into
  `Export/Internal/ExportMetrics.swift`.
- [x] Extract `PreparedLut` into `Export/Internal/ExportRenderHelpers.swift`.
- [x] Leave `FilmtoneSharedGradeProcessor`, `FilmtoneMotionBlurAccumulator`,
  `ISO8601DateFormatter`, and `OpticalKernels` in place for this subtask
  unless a direct build issue requires a smaller local adjustment.
- [x] Register every new Swift file in the App target through `xcodeproj`.
- [x] Run pbxproj registration checks for the new Swift files.
- [x] Run `bun run verify:ios`.
- [x] Run `git diff --check`.

## Verification

- `grep -c '<new Swift file>' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  — PASS: `ExportMetrics.swift`, `ExportRenderHelpers.swift`, and
  `ExportSessionModels.swift` each appear 4 times.
- `git diff --check` — PASS.
- `bun run verify:ios` — PASS: generated Swift drift check, iOS
  xcodebuild, grain catalog, Swift contract, motion blur math, cube parser,
  capture transform LUT classifier, cache store, source-color classifier,
  ray-angle optics, source profile math, look × veil energy, and sidecar
  builder checks all passed.

Existing Swift/iOS deprecation and Sendable warnings remain present in the
build output; no new build error was introduced by the helper extraction.

## Copy / History Impact

No public copy impact: this is an internal Swift helper relocation with no
user-facing copy, version, App Store, privacy, codec/export, or release-claim
change.

Article Opportunity: Developer note.
Change-History Opportunity: Developer note, because this records the first
step from monolithic export implementation toward feature-owned internals.

## Done Conditions

- `FilmtoneExportSession.swift` no longer owns the extracted helper models or
  metrics utilities.
- New helper files compile as part of the App target and each has pbxproj
  registration count >= 4.
- Export public API and view-side references remain untouched.
- `bun run verify:ios` and `git diff --check` pass.

## Stop Conditions

- Stop after 3 consecutive build/verification failures.
- Stop if extraction would require changing view-facing API signatures.
- Stop if sidecar schema/order or generated Swift drift appears.

## Out Of Scope

- Splitting the frame render loop, writer, sidecar builder, or optics kernels.
- XCTest expansion, PSNR fixture work, or full capture/export QA matrix.
- Simulator UI smoke unless compile gates reveal a runtime-only risk.

## Unexpected / Follow-up

- Pending.
