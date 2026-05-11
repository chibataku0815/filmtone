# Active — Phase 2B-2 Source-Profile / Input-LUT Helpers Extraction

Date: 2026-05-11 JST
Phase: Phase 2B — ExportSession public-surface split (sub-stage 2 of N)
Milestone: First real god-object decomposition cut. Pull the `private
static` source-profile / input-LUT helpers out of `FilmtoneExportSession`
into independent helper types under `Export/Internal/`.

## Owner directive (2026-05-11 JST)

The previous sub-stage (2B-1) lifted `extension ISO8601DateFormatter` —
acceptable because it is an extension on a Foundation type, not on
`FilmtoneExportSession`. This sub-stage is different.

**Do not create another `extension FilmtoneExportSession` file.** Splitting
a god object into a separate file that is still an `extension` of the
same class keeps the responsibility on the god class and defeats the
lane's purpose.

Extract the source-profile / input-LUT helpers into **independent
internal helper types** under `Export/Internal/`. Rewrite the call
sites inside `FilmtoneExportSession.swift` to call the helper types.
Public API of `FilmtoneExportSession` is unchanged.

Memory: `feedback_no_extension_only_file_for_god_object_split`.

## Goal

Reduce `FilmtoneExportSession.swift` from 4488 lines by moving ~330
lines of `private static` source-profile / input-LUT helpers — currently
clustered at lines 3064–3372 — into two independent helper types. The
helpers are pure functions plus one `NSCache`; no instance state and
no observable side effects beyond cache reuse.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  (delete the ~330 lines, rewrite 4 call sites)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportInputLutBuilder.swift`
  (new — input-LUT construction)
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSourceProfileResolver.swift`
  (new — camera-profile sidecar provenance)
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  (4-section registration, one entry per new file)
- `docs/filmtone/ios/feature-architecture-refactor/active.md` (this file)

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md` (commit gate; §3 4-section grep)
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-1-sidecar-formatter-extraction.md`
  (compatibility table + 2B-2 plan correction)
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileMath.swift`
  (math primitives the helpers wrap — not modified)
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileCatalog.swift`
  (catalog the resolver consults — not modified)

## Helper type design

### `ExportInputLutBuilder` (Export/Internal/ExportInputLutBuilder.swift)

`enum` namespace (no instance state needed; the `NSCache` is a static
property). All members `static`. Public surface to call sites:

- `static func makePreparedLut(from lut: SerializableLutDTO?) -> PreparedLut?`
- `static func makeActiveInputLut(for selection: CameraProfileSelection?, probe: SourceProbeDTO?) -> PreparedLut?`

Private/file-private inside the new file:

- `static func makeAutomaticInputLut(for: SourceInputTransformPolicyDTO?)`
- `static func makeInputLut(forImpl: SourceProfileImpl)`
- `static func makeSynthesizedInputLut(curve: SourceProfileCurve)`
- `static func makeAppleLogToRec709Lut(size:rec2020GamutMap:)`
- `static func appleLogPixelToRec709(red:green:blue:rec2020GamutMap:)`
- `static func appleLogDecode(_:)`, `rec2020ToRec709(red:green:blue:)`,
  `filmtoneSdrShoulder(_:)`, `rec709Encode(_:)` (thin wrappers around
  `FilmtoneSourceProfileMath`; kept as `@inline(__always)`)
- `static func packRgbToRgbaCubeData(rgb:size:)`, `rgbaCubeData(from:size:)`
- `private static let synthesizedInputLutCache = NSCache<NSString, NSData>()`

### `ExportSourceProfileResolver` (Export/Internal/ExportSourceProfileResolver.swift)

`enum` namespace.

- `static func makeCameraProfileSidecar(for selection: CameraProfileSelection?, probeColorClass: SourceColorClassDTO?) -> SidecarCameraProfile?`
- `private static func implTag(_ impl: SourceProfileImpl) -> String`

These two are coupled (only `makeCameraProfileSidecar` calls `implTag`)
and have no relation to LUT building beyond sharing the catalog. They
get their own file.

### Rationale for the split

- Builder type owns LUT construction including cache and Apple Log math
  helpers; Resolver type owns sidecar provenance + impl tag. Each is a
  single responsibility.
- `enum` namespace (vs `final class`) avoids accidental instantiation
  and signals "static utility". Matches the convention of existing
  Filmtone math namespaces (e.g. `FilmtoneSourceProfileMath`).
- Method names are kept identical to the current `private static` names
  so call-site diffs are mechanical (`Self.makePreparedLut(...)` →
  `ExportInputLutBuilder.makePreparedLut(...)`). No public API churn.

## Call-site repair list inside `FilmtoneExportSession.swift`

Four real call sites (the rest are matched by comments only):

| Line (current) | Current call | New call |
|---|---|---|
| 230 | `Self.makePreparedLut(from: request.inputLut)` | `ExportInputLutBuilder.makePreparedLut(from: request.inputLut)` |
| 231 | `Self.makeActiveInputLut(for: request.cameraProfile, probe: request.sourceProbe)` | `ExportInputLutBuilder.makeActiveInputLut(for: request.cameraProfile, probe: request.sourceProbe)` |
| 238 | `Self.makePreparedLut(from: legacyCreativeLut)` | `ExportInputLutBuilder.makePreparedLut(from: legacyCreativeLut)` |
| 530 | `Self.makeCameraProfileSidecar(for: …, probeColorClass: …)` | `ExportSourceProfileResolver.makeCameraProfileSidecar(for: …, probeColorClass: …)` |

(Line numbers will shift as the helpers are removed; the worker reads
the file fresh at edit time. Use the call expression as the anchor, not
the line number.)

## Comment updates outside ExportSession (cosmetic, not behavioural)

Five files reference the helpers by their old `FilmtoneExportSession.<helper>`
form **in comments only** (no real calls). Update the comment to point
at the new helper type:

- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorFacade.swift:152`
  — `FilmtoneExportSession.makeActiveInputLut(for:probe:)` →
  `ExportInputLutBuilder.makeActiveInputLut(for:probe:)`
- `apps/capacitor-film-lab-ios/ios/App/App/Editor/FilmtoneEditorStore.swift:1305`
  — `FilmtoneExportSession.makeAutomaticInputLut(for:)` →
  `ExportInputLutBuilder.makeAutomaticInputLut(for:)`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileCatalog.swift:12`
  — `makeAppleLogToRec709Lut` reference → reference new type path
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileMath.swift:481`
  — `FilmtoneExportSession.makeAppleLogToRec709Lut` →
  `ExportInputLutBuilder.makeAppleLogToRec709Lut`
- `apps/capacitor-film-lab-ios/ios/App/App/Source/FilmtoneSourceProfileSchema.swift:105`
  — `makeAppleLogToRec709Lut from FilmtoneExportSession` →
  `from ExportInputLutBuilder`

## Things deliberately *not* moved in this sub-stage

- `FilmtoneExportSidecarBuilder.swift:1078`/`:1157` carries its own
  `appleLogPixelToRec709` private static. That is a duplicate copy
  living in a different file. Consolidating the duplicate is a separate
  concern (potential follow-up); 2B-2 does not touch SidecarBuilder.
- `FilmtoneSharedGradeProcessor`, `FilmtoneMotionBlurAccumulator`,
  `OpticalKernels` (file-level companions). They go in 2B-4 because
  their `fileprivate` access ladder must be bumped together.
- Any kernel-chain (`applyGrade`, `applyInputLutStage`, etc.) — that is
  2B-6 with the 2C parity gate.
- `FilmtoneExportSession` public API: signatures, sidecar field order,
  render math, kernel chain order all stay byte-identical.

## Checklist

- [ ] Create `Export/Internal/ExportInputLutBuilder.swift` containing
  the LUT helpers as listed above (move, not rewrite).
- [ ] Create `Export/Internal/ExportSourceProfileResolver.swift` with
  `makeCameraProfileSidecar` + `implTag`.
- [ ] Delete the same ~330 lines (3064–3372 in the pre-edit file) from
  `FilmtoneExportSession.swift`.
- [ ] Rewrite the 4 call sites in `FilmtoneExportSession.swift`
  (`Self.<helper>` → `<HelperType>.<helper>`).
- [ ] Update the 5 cosmetic comments listed above.
- [ ] Register both new files in `project.pbxproj` (4 sections each).
- [ ] `grep -c 'ExportInputLutBuilder' project.pbxproj` >= 4.
- [ ] `grep -c 'ExportSourceProfileResolver' project.pbxproj` >= 4.
- [ ] `bun run verify:ios` — PASS.
- [ ] `git diff --check` — PASS.

## Verification gates

- pbxproj 4-section registration verified per file
- `bun run verify:ios` green at every commit (CLAUDE.md §3)
- `git diff --check` clean (whitespace)
- `git diff --stat` shows roughly: −330 in ExportSession.swift,
  +<helper file sizes> in two new files, +call-site rewrites in
  ExportSession, +small comment edits
- No edit to `FilmtoneSourceProfileMath.swift` /
  `FilmtoneSourceProfileCatalog.swift` /
  `FilmtoneExportSidecarBuilder.swift` (other than the comment update
  in catalog/math/schema files)

## Done Conditions

- `FilmtoneExportSession.swift` no longer contains
  `makePreparedLut`, `makeCameraProfileSidecar`, `implTag`,
  `makeAutomaticInputLut`, `makeActiveInputLut`, `makeInputLut`,
  `makeSynthesizedInputLut`, `makeAppleLogToRec709Lut`,
  `appleLogPixelToRec709`, `appleLogDecode`, `rec2020ToRec709`,
  `filmtoneSdrShoulder`, `rec709Encode`, `packRgbToRgbaCubeData`,
  `rgbaCubeData`, or `synthesizedInputLutCache`.
- Two new helper types own those symbols; no `extension
  FilmtoneExportSession` exists in the new files.
- All gates green.
- No change to public API, sidecar field order, render math, or kernel
  chain order.

## Stop Conditions

- Stop if the helper move requires changing any `FilmtoneExportSession`
  public/internal-default signature.
- Stop if the move requires changing the order of fields written by
  `writeExportSidecar` or the order of LUT preparation in `init` (the
  `makePreparedLut(...) ?? makeActiveInputLut(...)` fallback pattern
  must be preserved verbatim at line ~230).
- Stop after 3 consecutive build/verification failures.
- Stop if the App target `PBXSourcesBuildPhase` file count changes by
  anything other than +2.

## Out Of Scope

- Consolidating the duplicate `appleLogPixelToRec709` inside
  `FilmtoneExportSidecarBuilder.swift`.
- Moving any other helper bucket from the 2B-1 inventory.
- View / Editor / Capture code.
- New tests, new fixtures.

## Unexpected / Follow-up

(empty — worker fills at completion)
