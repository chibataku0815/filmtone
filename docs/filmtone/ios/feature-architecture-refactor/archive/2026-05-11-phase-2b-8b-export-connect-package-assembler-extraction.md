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

- [x] Create `Export/Internal/ExportConnectPackageAssembler.swift` with
  the imports needed by the moved code (`Foundation`, `FilmLabSwiftCore`
  as needed).
- [x] Add `private let connectPackageAssembler:
  ExportConnectPackageAssembler` to `FilmtoneExportSession`.
- [x] Initialize the assembler with the existing `request`, `sourceURL`,
  `outputURL`, and stable `sourceSeed`.
- [x] Move `ConnectPackageCompanions` into the assembler as
  `Companions`.
- [x] Move the five Connect package suffix constants into the assembler.
- [x] Move `makeConnectPackageCompanions(result:)` into the assembler as
  `makeCompanions(result:writeReferenceAfterImage:)`.
- [x] Move `makePackageFileUris(sidecarUri:companions:)` into the
  assembler.
- [x] Keep `writeReferenceAfterImage`, `makePreviewPosterTime`,
  `copyPreviewCGImage`, and `writeJPEGImage` on the session.
- [x] Rewire all session call sites and type names.
- [x] Register `ExportConnectPackageAssembler.swift` in pbxproj 4
  sections.
- [x] Verify
  `rg -n "ConnectPackageCompanions|connectCubeFilenameSuffix|connectPreOpticalCubeFilenameSuffix|connectPostOpticalCubeFilenameSuffix|connectReferenceAfterFilenameSuffix|connectDctlFilenameSuffix|makeConnectPackageCompanions|makePackageFileUris" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [x] `grep -c 'ExportConnectPackageAssembler.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

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
  rendered, sidecar, source, pre-optical cube, post-optical cube,
  combined cube, DCTL, reference-after.
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

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1896 → 1805 (−91 net; +25 insertions / −116 deletions).
  Insertions: 9-line storage decl comment + `private let connectPackageAssembler`
  decl, 6-line `ExportConnectPackageAssembler(...)` init after `self.sourceSeed`,
  10-line rewired `if request.connectPackage == true` block that calls
  `connectPackageAssembler.makeCompanions(result:writeReferenceAfterImage:)`
  with a `{ [self] url, sourceDurationSec in try writeReferenceAfterImage(...) }`
  closure, single-line `connectPackageAssembler.makePackageFileUris(...)` swap.
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportConnectPackageAssembler.swift`:
  new, 151 lines. `final class ExportConnectPackageAssembler` with nested
  `struct Companions` (8 fields), 5 `private static let` filename suffix
  constants, `init(request:sourceURL:outputURL:sourceSeed:)`,
  `makeCompanions(result:writeReferenceAfterImage:)`, and
  `makePackageFileUris(sidecarUri:companions:)`.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`: +4
  lines (IDs `B1E10001000000000000B213` build / `B1E10001000000000000B214`
  ref, continuing from B212).

Deleted from `FilmtoneExportSession`:

- 5 `private static let connect*FilenameSuffix` constants (lines 156-160 of
  the 2B-8A end-state).
- `private struct ConnectPackageCompanions` (8 fields, 10 lines).
- `private func makeConnectPackageCompanions(result:) -> ConnectPackageCompanions?`
  body (76 lines).
- `private func makePackageFileUris(sidecarUri:companions:) -> [String]?`
  body (18 lines).

`writeReferenceAfterImage`, `makePreviewPosterTime`, `copyPreviewCGImage`,
`writeJPEGImage`, `writeExportSidecar`, and `makeStableSourceSeed` remain on
`FilmtoneExportSession` as required by the active. The new file imports
`Foundation` and `FilmLabSwiftCore`.

## Gate Results

- `bun run verify:ios`: EXIT 0. All sub-tests pass — generated Swift
  contract, ios build (xcodebuild Simulator), ios grain catalog, ios swift
  contract, motion blur math, cube parser, capture transform LUT
  classifier, cache store, source-color-classifier, ray-angle optics,
  source profile math, D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3
  accuracy gates (all 0.000 ΔE / 0.000 ΔRGB), look × veil energy merge,
  sidecar builder.
- `grep -c 'ExportConnectPackageAssembler.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  4 (PBXBuildFile + PBXFileReference + PBXGroup `Export/Internal/` +
  PBXSourcesBuildPhase).
- Strict ripgrep gate against
  `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1 hit (line 415: the intentional rewired call site
  `connectPackageAssembler.makePackageFileUris(...)` which the spec itself
  prescribes — the literal `makePackageFileUris` substring necessarily
  remains in the dot-prefixed call). Zero stale `ConnectPackageCompanions`,
  zero stale `connect*FilenameSuffix` constants, zero stale
  `makeConnectPackageCompanions` declarations or callers, zero stale
  un-prefixed `makePackageFileUris` declarations or callers. Same pattern
  as 2B-8A's intentional hits inside the new file.
- Strict ripgrep against the new
  `Export/Internal/ExportConnectPackageAssembler.swift`: 11 intentional
  hits (5 suffix constants, 5 path-component references, 1
  `makePackageFileUris` method decl).
- `git diff --check`: clean (exit 0). No whitespace anomalies.
- SourceKit "No such module 'FilmLabSwiftCore'" diagnostics on the new
  file's `import FilmLabSwiftCore` and on the existing `FilmtoneExportSession.swift`:
  known non-fatal indexer noise per 2B-7A / 2B-7B / 2B-8A precedent.
  `xcodebuild` is authoritative; verify:ios EXIT 0 confirms the actual
  module resolution is correct.

## Behavior Equivalence

- Source-media copy: `FileManager.default.fileExists(atPath:)` →
  `removeItem(at:)` → `copyItem(at:to:)` sequence preserved verbatim,
  including the existing-file delete (active.md done-gate item explicit).
- Combined / pre-optical / post-optical cube filenames:
  `\(packageStem)-combined-color.cube`,
  `\(packageStem)-pre-optical-color.cube`,
  `\(packageStem)-post-optical-color.cube` literal-byte-identical to the
  pre-8B output (suffix constants moved verbatim into the assembler).
- DCTL filename: `\(packageStem)-filmtone-bridge.dctl` byte-identical.
- Reference-after JPEG filename: `\(packageStem)-reference-after.jpg`
  byte-identical.
- `FilmtoneConnectCubeWriter.write{Combined,PreOptical,PostOptical}ColorCube(for:to:)`
  and `FilmtoneConnectDctlWriter.writeBridgeDctl(for:cubeFilename:preOpticalColorFilename:postOpticalColorFilename:outputFps:sourceSeed:to:)`
  receive identical `request`, filename, `request.output.fps`, and
  `sourceSeed` arguments. The `sourceSeed` value is the same stable
  FNV-1a hash of `sourceURL.absoluteString` computed by
  `Self.makeStableSourceSeed(...)` on `FilmtoneExportSession`; the
  assembler reads it from its init-time `sourceSeed: Double` rather than
  recomputing.
- Reference-after JPEG writing: the assembler invokes the session-supplied
  `(URL, Double?) throws -> Double` closure, which dispatches verbatim into
  `FilmtoneExportSession.writeReferenceAfterImage(to:sourceDurationSec:)`.
  That session method still owns `AVURLAsset(url: outputURL)`,
  `CMTimeGetSeconds(asset.duration)`-vs-fallback duration selection,
  `makePreviewPosterTime`, `copyPreviewCGImage`, `writeJPEGImage`, and the
  `outputColorSpace` JPEG color profile — none of those moved.
- `do { ... } catch { filmtonePreviewCompositionDebugLog(...); return nil }`
  failure path preserved: cube / DCTL / reference write throws still fall
  through to the same debug log and `Companions? == nil`, which propagates
  to `packageCompanions == nil` and `packageFileUris == nil`. `writeExportSidecar`
  then receives `package: nil`. The Phase0ExportResultDTO emits `nil` for
  `packageFileUris`, matching pre-8B behavior.
- `SidecarPackage(...)` payload: all 8 fields (sourceMediaFilename,
  renderedMediaFilename, referenceAfterFilename, referenceAfterTimeSec,
  combinedColorFilename, preOpticalColorFilename, postOpticalColorFilename,
  effectsDctlFilename) populated from the same URL last-path-components.
- `makePackageFileUris` ordering — rendered, sidecar, source,
  pre-optical cube, post-optical cube, combined cube, DCTL,
  reference-after — is enforced inside
  `FilmtoneConnectPackageFiles.orderedPackageFileUris`, which the
  assembler calls with identical labeled arguments
  (`renderedUri`, `sidecarUri`, `sourceMediaUri`, `preOpticalCubeUri`,
  `postOpticalCubeUri`, `cubeUri`, `dctlUri`, `referenceAfterUri`).
  Ordering preserved by construction.
- `request.connectPackage == true` gating preserved on the session side
  exactly as before — the assembler is constructed unconditionally in
  `init` but `makeCompanions(...)` is only invoked when the flag is set.
  Save-to-Photos / share-sheet flows still leave the multi-GB package
  unwritten.
- `writeExportSidecar` remains session-owned and still receives the same
  `SidecarPackage?` value (now sourced from
  `packageCompanions?.sidecarPackage` where `packageCompanions` is typed
  `ExportConnectPackageAssembler.Companions?`). Sidecar V1 schema /
  field-order output unchanged.
- Public API, `Phase0ExportResultDTO` shape, `Phase0ExportRequestDTO`
  consumption, and UI call sites unchanged. Pipeline phase order
  (preflight → exportVideo/exportStillImage → sidecar → package URI
  assembly → completed progress) preserved.

## Unexpected / Follow-up

- None.

The single remaining strict-ripgrep hit on `makePackageFileUris` in
`FilmtoneExportSession.swift:415` is the intentional rewired call site
`connectPackageAssembler.makePackageFileUris(...)`, prescribed verbatim by
the active.md "Replace … with `connectPackageAssembler.makePackageFileUris(...)`"
shape spec. Documented in Gate Results above as the intentional hit (same
pattern as 2B-8A's two intentional hits inside the new file).
