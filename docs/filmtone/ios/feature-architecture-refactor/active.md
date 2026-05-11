# Active - Phase 2B-8C ExportSidecarWriter Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move sidecar input assembly and sidecar file write out of
`FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: sidecar V1 schema, builder inputs,
  identity timing, depth/mezzanine telemetry, Saved Look / Camera Profile
  sidecar blocks, highlight/capture provenance, write failure semantics,
  and returned sidecar URL must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportSidecarWriter` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportSidecarWriter.swift` and move
`writeExportSidecar(...)` out of `FilmtoneExportSession`.

Do not touch `FilmtoneExportSidecarBuilder.swift`. The builder remains
the sidecar schema source of truth. This sub-stage only moves the
session-local `SidecarBuildInputs` assembly, sidecar URL resolution,
payload build/write, and nil-on-failure fallback into a collaborator.

## Current Boundary As Of 2B-8B

`writeExportSidecar(...)` currently owns:

- `SidecarDeviceIdentity` construction from `Bundle.main`, `UIDevice`,
  iOS version, and `Date()` formatted through
  `ISO8601DateFormatter.filmtoneSidecar`
- HDR policy forwarding from `request.sourceProbe`
- `SidecarDepthInfo` assembly from session depth telemetry
- `SidecarSavedLookRef` assembly from `appliedSavedLook`
- `SidecarCameraProfile` assembly through `ExportSourceProfileResolver`
- `SidecarBuildInputs` assembly
- sidecar URL resolution through `FilmtoneExportSidecarBuilder.sidecarURL`
- `FilmtoneExportSidecarBuilder.build(inputs)` and atomic write
- debug log + `nil` fallback on any thrown build/write failure

Move that whole boundary. Keep all telemetry state mutation on
`FilmtoneExportSession`; pass a snapshot into the writer at write time.

## Intended Implementation Shape

Add:

```swift
final class ExportSidecarWriter {
    struct Telemetry {
        let degradedDecodePath: Bool
        let depthResolution: (width: Int, height: Int)?
        let videoDepthFramesProcessed: Int?
        let videoDepthSourceLabel: String?
        let didUseMezzanineVariant: ProfileVariant?
        let mezzanineConsumedURLLastPathComponent: String?
        let mezzanineConsumedMetrics: MezzanineService.MezzanineMetrics?
        let mezzanineGeneratedDuringExport: Bool?
        let mezzanineValidationStatus: String?
    }

    private let request: Phase0ExportRequestDTO
    private let outputURL: URL
    private let colorPipeline: FilmtoneColorPipelineContract
    private let appliedSavedLook: SavedLookEntry?
    private let cameraProfileSelection: CameraProfileSelection?
    private let highlightMarkers: FilmtoneHighlightMarkers?
    private let captureProvenance: SidecarCaptureProvenance?

    init(
        request: Phase0ExportRequestDTO,
        outputURL: URL,
        colorPipeline: FilmtoneColorPipelineContract,
        appliedSavedLook: SavedLookEntry?,
        cameraProfileSelection: CameraProfileSelection?,
        highlightMarkers: FilmtoneHighlightMarkers?,
        captureProvenance: SidecarCaptureProvenance?
    )

    func write(
        outputSize: CGSize,
        fileSizeBytes: Int?,
        elapsedMs: Int,
        realtimeRatio: Double?,
        audioPreserved: Bool?,
        package: SidecarPackage?,
        performance: SidecarPerformance?,
        telemetry: Telemetry
    ) -> String?
}
```

If the compiler requires a different shape for nested tuple storage or
UIKit imports, adjust minimally while keeping the same data flow. The
writer should generate `Date()` and `UIDevice.current...` inside `write`,
not during `init`, so exported-at timing remains write-time behavior.

In `FilmtoneExportSession`:

- add `private let sidecarWriter: ExportSidecarWriter`.
- initialize it after `outputURL`, `colorPipeline`, and the session's
  applied-look / camera-profile / marker / capture provenance properties
  are assigned.
- replace `writeExportSidecar(...)` call with `sidecarWriter.write(...)`.
- build `ExportSidecarWriter.Telemetry` from current session state at the
  call site.
- remove `writeExportSidecar(...)` from the session.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `sidecarWriter`
  - remove `writeExportSidecar(...)`
  - rewire call site with a telemetry snapshot
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSidecarWriter.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportSidecarWriter.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-8b-export-connect-package-assembler-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift`
  - sidecar schema source of truth, read-only in 2B-8C
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceProfileResolver.swift`
  - camera-profile sidecar resolver, read-only in 2B-8C

## Checklist

- [ ] Create `Export/Internal/ExportSidecarWriter.swift` with the imports
  needed by the moved code (`CoreGraphics`, `FilmLabSwiftCore`,
  `Foundation`, `UIKit`).
- [ ] Add `private let sidecarWriter: ExportSidecarWriter` to
  `FilmtoneExportSession`.
- [ ] Initialize the writer with existing request/output/color/look/profile
  / highlight / capture provenance values.
- [ ] Move `writeExportSidecar(...)` into `ExportSidecarWriter.write(...)`.
- [ ] Add a `Telemetry` snapshot type that carries the mutable session
  state needed by sidecar inputs.
- [ ] Rewire the session call site to `sidecarWriter.write(...)` and pass
  a snapshot built from current session properties.
- [ ] Keep `FilmtoneExportSidecarBuilder.swift` untouched.
- [ ] Register `ExportSidecarWriter.swift` in pbxproj 4 sections.
- [ ] Verify
  `rg -n "writeExportSidecar|SidecarDeviceIdentity|SidecarBuildInputs\\(" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [ ] Verify `git diff --name-only` does not include
  `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift`.
- [ ] `grep -c 'ExportSidecarWriter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportSidecarWriter.swift`
- sidecar input assembly declarations removed from `FilmtoneExportSession`
- `FilmtoneExportSidecarBuilder.swift` untouched
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-8C unless implementation changes behavior beyond
extraction. The existing sidecar builder test in `verify:ios` is the
outer-shell gate for this pass.

## Done Conditions

- `FilmtoneExportSession.swift` delegates sidecar file writing to
  `ExportSidecarWriter`.
- `SidecarDeviceIdentity` values and `exportedAtIso` timing remain
  write-time behavior.
- Depth `used: true/false`, `framesWithDepth`, and
  `videoDepthSource` logic remain equivalent.
- Saved Look sidecar block keeps the same bundled/user-entry behavior.
- Camera Profile sidecar block still goes through
  `ExportSourceProfileResolver.makeCameraProfileSidecar`.
- Mezzanine truth fields keep the same values:
  used variant, profile version, consumed URL component, metrics,
  prewarm-hit inversion, generated-during-export, and validation status.
- `FilmtoneExportSidecarBuilder.build(inputs)` receives the same
  semantic inputs; `FilmtoneExportSidecarBuilder.swift` is not modified.
- Atomic write uses the same `FilmtoneExportSidecarBuilder.sidecarURL`
  result and returns `sidecarURL.absoluteString` on success.
- Build/write failure still logs through
  `filmtonePreviewCompositionDebugLog` and returns `nil` without failing
  export.
- Public API, sidecar schema, export settings, package URI behavior, and
  UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving sidecar writing forces changes to
  `FilmtoneExportSidecarBuilder.swift`, sidecar schema fields, sidecar
  encoding order, export loop behavior, Connect package assembly, or
  result DTO shape. Stop and record the blocker instead of widening
  scope.
- The telemetry snapshot cannot preserve current values without changing
  mutation timing in `exportVideo` / `exportStillImage`. Stop and record
  the dependency problem.

## Out Of Scope

- `FilmtoneExportSidecarBuilder.swift` edits.
- Sidecar schema, field names, encoding order, or canonical fixture work.
- `exportVideo` loop extraction.
- `exportStillImage` extraction.
- Connect package assembly changes.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Unexpected / Follow-up

- None yet.
