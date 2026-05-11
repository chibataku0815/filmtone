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

- [ ] Create `Export/Internal/ExportMezzanineRouter.swift` with imports
  needed by the moved code (`AVFoundation` only if compiler requires it,
  `FilmLabSwiftCore`, `Foundation`).
- [ ] Add `private let mezzanineRouter: ExportMezzanineRouter` to
  `FilmtoneExportSession`.
- [ ] Initialize the router with `request`, `sourceURL`, and
  `mezzanineService`.
- [ ] Move `resolvedVideoSourceURL`, `prepareQualityMezzanineForExport`,
  `qualityMezzanineVariantForExport`, and `estimatedDataRate` into the
  router.
- [ ] Move the export-only route telemetry block into
  `routeSourceForExport() -> RouteResult`.
- [ ] Rewire `renderVideoPreview()` to
  `mezzanineRouter.resolvedPreviewSourceURL()`.
- [ ] Rewire the start of `exportVideo(...)` to call
  `prepareQualityMezzanineForExport` and `routeSourceForExport`, then
  assign existing session telemetry fields from the result.
- [ ] Keep `exportVideo` asset opening, depth reader, writer setup, frame
  loop, progress, sidecar writing, and result assembly on the session.
- [ ] Register `ExportMezzanineRouter.swift` in pbxproj 4 sections.
- [ ] Verify
  `rg -n "resolvedVideoSourceURL|prepareQualityMezzanineForExport|qualityMezzanineVariantForExport|estimatedDataRate\\(" apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift`
  returns 0 hits.
- [ ] `grep -c 'ExportMezzanineRouter.swift' apps/capacitor-film-lab-ios/ios/App/App.xcodeproj/project.pbxproj`
  is 4.
- [ ] `bun run verify:ios` passes.
- [ ] `git diff --check` passes.

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

## Unexpected / Follow-up

- None yet.
