# Active: M5-G Architecture Thin Cuts (post-M5-C.3b review)

Date: 2026-05-05 JST

## Scope

Post-M5-C.3b multi-agent review surfaced four responsibility / coverage
gaps. v1.4 user smoke + notarize submission still gate on this lane
landing first so the next round of UI changes does not pile onto a god
object.

Source review verbatim:

> P2 RootWindowView owns export orchestration (presentExportPanel /
> presentStillExportPanel / presentVideoExportPanel — ~150 lines + ~10
> EditorState mutations).
> P2 AdvancedAdjustCatalog + EditorState+ParamOverrides have no Verify
> coverage — M5-C.3b can regress while verify:macos passes.
> P2 AdvancedAdjustCatalog hardcodes the iOS canonical advanced adjust
> catalog without a parity guarantee.
> P3 LibraryViewModel.saveCurrentLook depends on the whole EditorState
> just to extract a payload that already exists.

`FilmtonePhase0Math.clampParam` does NOT live in `film-lab-swift-core`
(only `FilmtoneQuickState.clampAxis` is shared). So Task 3 lands as a
parity test — promoting clampParam into the shared package is a
larger lift owned by a separate M4-B follow-up slice.

## Sub-tasks (each ~30 min)

### M5-G.1 — ExportCoordinator extraction + SaveLookPayload lift

- Create `State/ExportCoordinator.swift` (`@MainActor final class`,
  stateless against `EditorState` for now). Move
  `presentExportPanel` / `presentStillExportPanel` /
  `presentVideoExportPanel` from `RootWindowView` verbatim, take
  `state: EditorState` per call.
- `RootWindowView` holds `@State private var exportCoordinator =
  ExportCoordinator()` and replaces both call sites
  (toolbar Export button + ExportInspectorPanel.onExportTap) with
  `exportCoordinator.presentExportPanel(for: state)`. The 3 private
  funcs are deleted from `RootWindowView`.
- Lift `SaveLookPayload` out of `EditorState` into
  `State/SaveLookPayload.swift` as a top-level struct so library
  consumers don't transitively pull `EditorState`.
- `LibraryViewModel.saveCurrentLook(name:from:)` →
  `saveCurrentLook(name:payload:)`. `LookLibraryControls` call site
  becomes `library.saveCurrentLook(name: name, payload:
  state.currentLookSavePayload())`.
- pbxproj: A35 / B34 ExportCoordinator, A36 / B35 SaveLookPayload —
  both into the `State` group + Sources phase.
- Build: `xcodebuild -scheme FilmtoneDesktop -configuration Debug
  build`. Must pass without warnings.
- Commit.

### M5-G.2 — AdvancedAdjustCatalog parity test in Verify

- Add Test group 9 to `Verify/main.swift` exercising:
  - `AdvancedAdjustCatalog.allGroups` field count + uniqueness of keys.
  - `AdvancedAdjustCatalog.clamp(_:for:)` honors each known case
    (boundary in / below / above; shutterAngle discontinuity at 0 / 89
    / 90 / 179 / 180 / 720 / 800; rgbShift / grainIntensity hard
    `FilmtonePhase0Generated.*Max` ceiling).
  - Catalog keys ⊂ `FilmtonePhase0Params.keyPaths.keys` (sanity that
    every catalog key is a real Phase0 param).
- Add `AdvancedAdjustCatalog.swift` to `Verify/run.sh` SOURCES.
- `bun run verify:macos` must show `N/N passed` (current 36; new
  count = 36 + new tests).
- Commit.

### M5-G.3 — strategy.md log + active.md archive

- After M5-G.1 + M5-G.2 land, add a Completion Log entry to
  `strategy.md` covering both slices and what they enable.
- Move this active.md to
  `archive/2026-05-05-m5-g-architecture-thin-cuts.md`.

## Out of scope (intentionally deferred)

- Pulling export state fields (`isExporting` / `lastExportResult` etc.)
  out of `EditorState` into `ExportCoordinator` (Task 2 in the user's
  priority list). Promote ExportCoordinator to `@Observable` first; do
  it as a separate slice once the seam is in the codebase and the
  consumer surface (ExportInspectorPanel) is reviewable in isolation.
- Promoting `FilmtonePhase0Math.clampParam` into
  `film-lab-swift-core` for true catalog delegation. Tracked as a
  shared-package follow-up (M4-B-3 candidate) since it touches the iOS
  canonical surface.
- `presentOpenPanel` / `detectSourceKind` extraction into an
  `OpenCoordinator`. One func, no state mutation choreography — leave
  in `RootWindowView` until a second open path appears.

## Status

Not started. Implementation begins immediately after this file lands.
