# Active - Phase 2B-9B ExportMezzanineRouter Extraction

Date: 2026-05-11 JST
Phase: Phase 2B - ExportSession public-surface split
Milestone: Move mezzanine routing, quality prewarm, and route telemetry
out of `FilmtoneExportSession`.

## Owner Directive

- Essence first: keep shrinking `FilmtoneExportSession` toward a thin
  export orchestrator. This is implementation work, not inventory.
- Product quality is the bar: preview/export source symmetry, quality
  prewarm policy, cache validation, route fallback, debug messages, and
  sidecar mezzanine truth fields must stay equivalent.
- Outer shell minimal: no new XCTest, simulator smoke, PNG/PSNR fixture,
  or formal QA matrix in this sub-stage. Run the focused gates below.
- No extension-only split. The target is an independent
  `ExportMezzanineRouter` type under `Export/Internal/`.

## Goal

Create `Export/Internal/ExportMezzanineRouter.swift` and move the
mezzanine routing / quality prewarm helpers out of
`FilmtoneExportSession`.

This is not the full video-loop extraction. Keep `exportVideo(...)`,
asset opening, depth reader setup, writer setup, frame loop, preview
rendering, and sidecar writing on `FilmtoneExportSession` for now. The
router should decide which source URL to use and return route telemetry
that the session stores into the existing sidecar-facing properties.

## Current Boundary As Of 2B-9A

Helpers in scope:

| Current helper / block | Responsibility | 2B-9B target |
|---|---|---|
| `resolvedVideoSourceURL()` | preview/export route selection across hdr/sdr/qualityHDR/qualitySDR/source-direct | move |
| exportVideo mezzanine telemetry block | detect used variant, validate routed URL, snapshot URL component/metrics, set validation status | move into router result |
| `prepareQualityMezzanineForExport(progress:)` | quality prewarm gate + existing/generate status + progress + errors | move |
| `qualityMezzanineVariantForExport()` | quality prewarm variant policy | move private |
| `estimatedDataRate(from:)` | probe file-size/duration data-rate estimate | move private |

Keep mutation of session properties on the session. The router returns
plain values; `FilmtoneExportSession` assigns them to
`didUseMezzanineVariant`, `mezzanineValidationStatus`,
`mezzanineConsumedURLLastPathComponent`, `mezzanineConsumedMetrics`, and
`mezzanineGeneratedDuringExport`.

## Intended Implementation Shape

Add:

```swift
final class ExportMezzanineRouter {
    struct RouteResult {
        let sourceURL: URL
        let didUseVariant: ProfileVariant?
        let validationStatus: String?
        let consumedURLLastPathComponent: String?
        let consumedMetrics: MezzanineService.MezzanineMetrics?
    }

    private let request: Phase0ExportRequestDTO
    private let sourceURL: URL
    private let mezzanineService: MezzanineService?

    init(
        request: Phase0ExportRequestDTO,
        sourceURL: URL,
        mezzanineService: MezzanineService?
    )

    func resolvedPreviewSourceURL() -> URL
    func routeSourceForExport() -> RouteResult
    func prepareQualityMezzanineForExport(
        progress: (Phase0ExportProgressDTO) -> Void
    ) throws -> Bool?
}
```

`prepareQualityMezzanineForExport` returns:

- `nil` when no quality prewarm was required, matching the existing
  no-op return path.
- `false` when the required quality mezzanine already existed.
- `true` when the router generated the quality mezzanine during export.

`routeSourceForExport` should include the current race guard and
`disabled-on-ios` validation-status behavior. If the route falls back to
source-direct because a selected mezzanine was invalidated, return
`sourceURL`, `didUseVariant: nil`, `validationStatus:
"invalidated-before-open"`, and nil consumed metrics.

In `FilmtoneExportSession`:

- add `private let mezzanineRouter: ExportMezzanineRouter`.
- initialize it with `request`, `sourceURL`, and `mezzanineService`.
- replace preview `resolvedVideoSourceURL()` usage with
  `mezzanineRouter.resolvedPreviewSourceURL()`.
- replace `try prepareQualityMezzanineForExport(progress:)` with:
  `if let generated = try mezzanineRouter.prepareQualityMezzanineForExport(progress: progress) { mezzanineGeneratedDuringExport = generated }`
  so the existing no-op path does not force a new value.
- replace the route-selection + telemetry block at the start of
  `exportVideo(...)` with `let route = mezzanineRouter.routeSourceForExport()`
  and assignments from `RouteResult`.
- remove the moved helper declarations from the session.

## Edit Targets

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  - add `mezzanineRouter`
  - remove moved mezzanine routing/prewarm helpers
  - rewire preview and export call sites
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMezzanineRouter.swift`
  - new file
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  - 4-section registration for `ExportMezzanineRouter.swift`
- `docs/filmtone/ios/feature-architecture-refactor/active.md`
  - update checklist and unexpected notes as implementation proceeds

## Read-Only References

- `apps/capacitor-film-lab-ios/CLAUDE.md`
  - commit gate and 4-section pbxproj rule
- `docs/filmtone/ios/feature-architecture-refactor/strategy.md`
  - Phase 2B / 2C milestones
- `docs/filmtone/ios/feature-architecture-refactor/archive/2026-05-11-phase-2b-9a-export-still-image-writer-extraction.md`
  - latest extraction precedent
- `apps/capacitor-film-lab-ios/ios/App/App/Services/MezzanineService.swift`
  - routing service API, read-only in 2B-9B
- `apps/capacitor-film-lab-ios/ios/App/App/Services/FilmtoneMezzanineRoutePolicy.swift`
  - route policy, read-only in 2B-9B

## Checklist

- [x] Create `Export/Internal/ExportMezzanineRouter.swift` with imports
  needed by the moved code (`AVFoundation` only if compiler requires it,
  `FilmLabSwiftCore`, `Foundation`).
- [x] Add `private let mezzanineRouter: ExportMezzanineRouter` to
  `FilmtoneExportSession`.
- [x] Initialize the router with `request`, `sourceURL`, and
  `mezzanineService`.
- [x] Move `resolvedVideoSourceURL`, `prepareQualityMezzanineForExport`,
  `qualityMezzanineVariantForExport`, and `estimatedDataRate` into the
  router.
- [x] Move the export-only route telemetry block into
  `routeSourceForExport() -> RouteResult`.
- [x] Rewire `renderVideoPreview()` to
  `mezzanineRouter.resolvedPreviewSourceURL()`.
- [x] Rewire the start of `exportVideo(...)` to call
  `prepareQualityMezzanineForExport` and `routeSourceForExport`, then
  assign existing session telemetry fields from the result.
- [x] Keep `exportVideo` asset opening, depth reader, writer setup, frame
  loop, progress, sidecar writing, and result assembly on the session.
- [x] Register `ExportMezzanineRouter.swift` in pbxproj 4 sections.
- [x] Verify
  `rg -n "resolvedVideoSourceURL|prepareQualityMezzanineForExport|qualityMezzanineVariantForExport|estimatedDataRate\\(" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [x] `grep -c 'ExportMezzanineRouter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [x] `bun run verify:ios` passes.
- [x] `git diff --check` passes.

## Verification Gates

Minimum gates for this sub-stage:

- pbxproj 4-section grep for `ExportMezzanineRouter.swift`
- moved mezzanine helper declarations removed from
  `FilmtoneExportSession`
- `bun run verify:ios`
- `git diff --check`

Do not add simulator smoke, sidecar canonical fixtures, or PNG byte-diff
fixtures in 2B-9B unless implementation changes behavior beyond
extraction.

## Done Conditions

- Preview still resolves the same effective URL the export routing would
  consume for the current render mode.
- Quality prewarm behavior remains equivalent:
  no-op when policy returns nil, hard failure when required service is
  absent, existing-mezzanine path sets generated-during-export false,
  generated path sets it true, same preflight progress messages and
  fractions.
- Export route telemetry remains equivalent:
  used variant detection order qualityHDR → qualitySDR → hdr → sdr,
  invalidated-before-open fallback, valid status with consumed URL
  component/metrics snapshot, and disabled-on-ios status when quality
  mode has no mezzanine.
- Session property mutation timing remains at the start of
  `exportVideo(...)`, before `AVURLAsset(url:)` is opened.
- Debug log messages are preserved.
- Public API, sidecar schema, package URI behavior, export settings,
  frame loop, and UI call sites are unchanged.

## Stop Conditions

- Done conditions are met.
- `bun run verify:ios` fails 3 consecutive times for the same issue.
- Moving routing forces video frame loop, preview render math,
  sidecar-writing, mezzanine service implementation, or route policy
  changes. Stop and record the blocker instead of widening scope.

## Out Of Scope

- `exportVideo` frame loop extraction.
- `renderVideoPreview` extraction beyond changing the source URL provider.
- `MezzanineService.swift` edits.
- `FilmtoneMezzanineRoutePolicy` edits.
- Sidecar schema or writer changes.
- Export parity fixtures, PSNR/PNG comparison, simulator UI smoke, and
  formal QA matrix.

## Line / File Deltas

- `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`:
  1646 → 1457 (−189 net, +13 / −202).
- `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportMezzanineRouter.swift`:
  new, 256 lines.
- `apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`:
  +4 lines (IDs `B219` build / `B21A` ref, continuing from B217/B218).
- `FilmtoneExportSidecarBuilder.swift`: untouched (not in `git diff --name-only`).

## Gate Results

- `grep -c 'ExportMezzanineRouter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  returns 4 (PBXBuildFile + PBXFileReference + PBXGroup Internal + PBXSourcesBuildPhase).
- `rg -n "resolvedVideoSourceURL|prepareQualityMezzanineForExport|qualityMezzanineVariantForExport|estimatedDataRate\(" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 1 hit at the call site `mezzanineRouter.prepareQualityMezzanineForExport(progress: progress)`.
  All four moved helper declarations are gone from the session. The
  remaining hit is the intentional router-call site whose method name
  matches the regex (the active.md sketch specifies the router method
  keeps the same name), consistent with the 2B-9A "0 hits OR only
  intentional references outside the moved loop" precedent.
- `bun run verify:ios` EXIT 0. `set -e` script — every downstream stage
  (ios grain catalog, ios swift contract, motion blur math, cube parser,
  capture transform LUT classifier, cache store, source-color-classifier,
  ray-angle optics, source profile math, D-Log / D-Log M / C-Log /
  C-Log 3 / V-Log / S-Log3 accuracy at 0.000 ΔE2000 / 0.000/255 full-frame
  budgets, look × veil energy merge 10/10, sidecar builder) ran and
  passed, which requires the `==> ios build` stage to have already
  succeeded.
- `git diff --check` EXIT 0 (no whitespace problems).
- `git diff --name-only | grep -i sidecar` empty: `FilmtoneExportSidecarBuilder.swift`
  not in the diff set.

## Behavior Equivalence

- Preview path: `renderVideoPreview()` now calls
  `mezzanineRouter.resolvedPreviewSourceURL()`, whose body is the verbatim
  former `resolvedVideoSourceURL()`. Same nil-mezzanine-service guard,
  same four `existingMezzanineURL` calls in the same order, same
  `FilmtoneMezzanineRoutePolicy.selectedVariant` call with the same
  arguments, same per-branch debug log strings, same `?? sourceURL`
  fallbacks. Preview ↔ export bytes still resolve to the same effective
  URL for the same renderMode.
- Quality prewarm path: `prepareQualityMezzanineForExport` returns
  `nil` when policy returns nil (matching the original no-op early
  return — the call site only assigns `mezzanineGeneratedDuringExport`
  when the result is non-nil, so the existing nil-default property
  remains untouched), `false` when an existing mezzanine is found
  (matches original `mezzanineGeneratedDuringExport = false`), and
  `true` after a successful `ensureMezzanineBlocking` (matches
  original `= true`). Same preflight progress emit at 0.06, same per-
  fraction progress at `0.06 + min(0.049, max(0.0, fraction) * 0.049)`,
  same debug log strings ("Quality mezzanine ready before export: …",
  "Quality mezzanine generated for export: …"). Same error message
  strings: missing service ("Quality mezzanine is required for this
  heavy source, but the cache service is unavailable.") and generation
  failure ("Quality mezzanine generation failed for this heavy source
  (\(variant.rawValue)): \(error.localizedDescription)").
- Export route telemetry: `routeSourceForExport()` produces a
  `RouteResult` whose fields are byte-equivalent to the prior in-
  session computation. Same `[.qualityHDR, .qualitySDR, .hdr, .sdr]`
  preference order. Same race-guard log ("Mezzanine race: routed-to
  URL invalidated before AVURLAsset open, falling back to source-
  direct"). Same `"invalidated-before-open"` / `"valid"` /
  `"disabled-on-ios"` validation-status strings. Same
  `mezzanineConsumedURLLastPathComponent` /
  `mezzanineConsumedMetrics` snapshot timing relative to URL pick. The
  session assigns the five telemetry fields from `RouteResult` before
  `AVURLAsset(url:)` opens, preserving the original truth-snapshot
  timing the sidecar writer reads.
- Session property mutation timing: assignments to
  `didUseMezzanineVariant`, `mezzanineValidationStatus`,
  `mezzanineConsumedURLLastPathComponent`,
  `mezzanineConsumedMetrics`, and `mezzanineGeneratedDuringExport`
  still happen at the start of `exportVideo(...)`, before
  `AVURLAsset(url:)` is opened, matching the previous ordering.
- Public API, sidecar schema, package URI behavior, export settings,
  frame loop, and UI call sites are unchanged.

## Unexpected / Follow-up

- None. Three explanatory notes:
  - The 1 residual strict-ripgrep hit is the router call site
    `mezzanineRouter.prepareQualityMezzanineForExport(progress: progress)`.
    The router method intentionally shares the name with the removed
    session helper per active.md's sketch, so the regex matches it.
    All four moved helper declarations are gone from the session.
    Consistent with the 2B-9A precedent of "0 hits OR only intentional
    references outside the moved loop".
  - The router method `prepareQualityMezzanineForExport(progress:)`
    keeps `@escaping` on the progress closure to compile against
    `MezzanineService.ensureMezzanineBlocking`'s optional `((Double)
    -> Void)?` parameter (optional closures are implicitly escaping).
    active.md's sketch elided `@escaping` for brevity; behavior is
    unchanged.
  - SourceKit emits "No such module 'FilmLabSwiftCore'" on
    `ExportMezzanineRouter.swift:1` and `FilmtoneExportSession.swift:4`.
    This is the recurring non-fatal indexer noise observed from
    2B-7A onward; `bun run verify:ios` EXIT 0 confirms xcodebuild
    module resolution is correct.
