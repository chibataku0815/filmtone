# Active - Phase 2B-8B ExportConnectPackageAssembler Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move Filmtone Connect package companion assembly out of
`FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: Connect package filenames, source-media
  copy behavior, cube/DCTL writer inputs, reference-after timing, and
  package URI ordering must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportConnectPackageAssembler` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportConnectPackageAssembler.swift` and move
Connect package companion artifact assembly out of `FilmtoneExportSession`.

This is not the sidecar writer extraction. Keep `writeExportSidecar(...)`
on `FilmtoneExportSession` for now; the session should continue passing
the resulting `SidecarPackage?` into sidecar build inputs. Move only the
Connect companion creation and package URI list construction.

## Current Boundary As Of 2B-8A

In scope:

| Current item | Responsibility | 2B-8B target |
|---|---|---|
| `ConnectPackageCompanions` | internal package companion value | move |
| `connectCubeFilenameSuffix` | combined cube suffix | move |
| `connectPreOpticalCubeFilenameSuffix` | pre-optical cube suffix | move |
| `connectPostOpticalCubeFilenameSuffix` | post-optical cube suffix | move |
| `connectReferenceAfterFilenameSuffix` | reference JPEG suffix | move |
| `connectDctlFilenameSuffix` | DCTL suffix | move |
| `makeConnectPackageCompanions(result:)` | copy source, write cubes/DCTL/reference, build `SidecarPackage` | move |
| `makePackageFileUris(sidecarUri:companions:)` | package URI ordering | move |

Keep `writeReferenceAfterImage(to:sourceDurationSec:)`,
`makePreviewPosterTime(sourceDurationSec:)`, `copyPreviewCGImage`, and
`writeJPEGImage` on `FilmtoneExportSession` in 2B-8B. The assembler
should receive a closure for reference-after writing so preview/JPEG
render internals do not move in this sub-stage.

## Intended Implementation Shape

Add:

```swift
final class ExportConnectPackageAssembler {
    struct Companions {
        let sourceMediaURL: URL
        let cubeURL: URL
        let preOpticalCubeURL: URL
        let postOpticalCubeURL: URL
        let dctlURL: URL
        let referenceAfterURL: URL
        let referenceAfterTimeSec: Double
        let sidecarPackage: SidecarPackage
    }

    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let outputURL: URL
    private let sourceSeed: Double

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        outputURL: URL,
        sourceSeed: Double
    )

    func makeCompanions(
        result: CompletedExport,
        writeReferenceAfterImage: (URL, Double?) throws -> Double
    ) -> Companions?

    func makePackageFileUris(
        sidecarUri: String?,
        companions: Companions?
    ) -> [String]?
}
```

In `FilmtoneExportSession`:

- add `private let connectPackageAssembler:
  ExportConnectPackageAssembler`.
- initialize it after `outputURL` and `sourceSeed` are available. If
  `sourceSeed` currently initializes after collaborators, either keep
  local `let sourceSeed = Self.makeStableSourceSeed(...)` and assign it
  once, or initialize the assembler immediately after `self.sourceSeed`.
- replace `makeConnectPackageCompanions(result:)` call sites with
  `connectPackageAssembler.makeCompanions(result:writeReferenceAfterImage:)`.
- pass a closure that calls the existing
  `writeReferenceAfterImage(to:sourceDurationSec:)`.
- replace `makePackageFileUris(sidecarUri:companions:)` with
  `connectPackageAssembler.makePackageFileUris(...)`.
- update local type references from `ConnectPackageCompanions` to
  `ExportConnectPackageAssembler.Companions`.
- remove the moved suffix constants, struct, and methods from the
  session.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `connectPackageAssembler`
  - remove moved Connect package constants / struct / methods
  - rewire call sites
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportConnectPackageAssembler.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportConnectPackageAssembler.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-8a-export-source-image-normalizer-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift`
  - sidecar schema container, read-only in 2B-8B
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneConnectCubeWriter.swift`
  - cube writer, read-only in 2B-8B
- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneConnectDctlWriter.swift`
  - DCTL writer, read-only in 2B-8B

## Checklist

- [ ] Create `Export/Internal/ExportConnectPackageAssembler.swift` with
  the imports needed by the moved code (`Foundation`, `FilmLabSwiftCore`
  as needed).
- [ ] Add `private let connectPackageAssembler:
  ExportConnectPackageAssembler` to `FilmtoneExportSession`.
- [ ] Initialize the assembler with the existing `request`, `sourceURL`,
  `outputURL`, and stable `sourceSeed`.
- [ ] Move `ConnectPackageCompanions` into the assembler as
  `Companions`.
- [ ] Move the five Connect package suffix constants into the assembler.
- [ ] Move `makeConnectPackageCompanions(result:)` into the assembler as
  `makeCompanions(result:writeReferenceAfterImage:)`.
- [ ] Move `makePackageFileUris(sidecarUri:companions:)` into the
  assembler.
- [ ] Keep `writeReferenceAfterImage`, `makePreviewPosterTime`,
  `copyPreviewCGImage`, and `writeJPEGImage` on the session.
- [ ] Rewire all session call sites and type names.
- [ ] Register `ExportConnectPackageAssembler.swift` in pbxproj 4
  sections.
- [ ] Verify
  `rg -n "ConnectPackageCompanions|connectCubeFilenameSuffix|connectPreOpticalCubeFilenameSuffix|connectPostOpticalCubeFilenameSuffix|connectReferenceAfterFilenameSuffix|connectDctlFilenameSuffix|makeConnectPackageCompanions|makePackageFileUris" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [ ] `grep -c 'ExportConnectPackageAssembler.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportConnectPackageAssembler.swift`
- moved Connect package declarations removed from `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-8B unless implementation changes behavior beyond
extraction.

## Done Conditions

- Connect package companion artifact assembly is delegated to
  `ExportConnectPackageAssembler`.
- Source media copy behavior is unchanged, including deleting an existing
  package source file before copy.
- Combined/pre-optical/post-optical cube filenames and DCTL filename
  suffixes are unchanged.
- `FilmtoneConnectCubeWriter` and `FilmtoneConnectDctlWriter` receive
  the same request, filenames, FPS, and source seed values as before.
- Reference-after JPEG writing remains session-owned through the closure,
  with the same poster-time logic and JPEG color-space behavior.
- `makePackageFileUris` output ordering remains:
  sidecar, source, rendered, reference-after, combined cube, pre-optical
  cube, post-optical cube, DCTL.
- `writeExportSidecar` remains session-owned and receives the same
  `SidecarPackage?` value.
- Public API, sidecar schema, export settings, and UI call sites are
  unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving the package assembler forces `writeExportSidecar`,
  `writeReferenceAfterImage`, preview image generation, JPEG writing, or
  sidecar schema changes. Stop and record the blocker instead of widening
  scope.
- The assembler cannot receive a stable `sourceSeed` without changing
  its value or timing. Stop and record the initialization dependency.

## Out Of Scope

- `writeExportSidecar` extraction.
- Sidecar schema, order, or builder changes.
- Reference-after JPEG writer extraction.
- `exportVideo` loop extraction.
- `exportStillImage` extraction.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Unexpected / Follow-up

- None yet.
