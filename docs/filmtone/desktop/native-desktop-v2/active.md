# M4-A Shared Swift Boundary Cut Line

Date opened: 2026-05-04 JST

## Milestone

M4 Shared Contract Consolidation, opened as a milestone-changing interrupt from
M5-C.4 after the user flagged that Native Desktop v2 is drifting into
Desktop-only copies of iOS logic.

## Goal

Define the boundary between:

- **Reusable iOS-canonical pure Swift logic** that should be consumed by both
  iOS and macOS from one shared owner.
- **Mac-native UI / platform shell** that should remain Desktop-specific even
  when it mirrors iOS workflows.

This slice intentionally does not move files yet. It creates the cut line and
extraction order so the next implementation slice can consolidate without
destabilizing the iOS lane or mixing architecture work into M5-C.4 UI code.

## Why this slice

- M5-C.1 / C.2 / C.3 / C.4 have correctly treated iOS as canonical, but much of
  the result is hand-ported code, not shared code.
- More M5 work will add more copies unless the shared boundary is explicit now.
- M4 was deferred to avoid premature module churn, but Native Desktop behavior
  is now stable enough that the highest-risk shared contracts can be identified
  before they sprawl further.

## Scope

### In

- Build a compact matrix of current iOS/macOS logic ownership:
  - share now
  - share after one cleanup
  - keep platform-specific
  - generated-only / do-not-hand-edit
- Identify the minimum first shared Swift module or package boundary.
- Define migration order and safety gates for the first extraction.
- Record no-go areas where Mac must translate iOS behavior into native idioms
  instead of sharing implementation.

### Out

- Moving code into an SPM target.
- Editing iOS behavior.
- Editing Desktop product behavior.
- Refactoring M5-C.4 Export Inspector code.
- Changing generated Swift manually.

## Current Findings

### Share Now

These are pure Swift contracts with little or no platform dependency:

- `FilmtonePhase0Generated.swift` — already byte-identical between iOS and
  Desktop. It should stay generated-only and be consumed from one generated
  artifact.
- `FilmtonePhase0ParamsPatch` / param key accessors / patch application.
- `FilmtoneQuickState` helpers and quick-weight application.
- Preset interpolation and resolve order:
  `interpolate preset -> paramOverrides -> quickState`.
- Source-profile math primitives (`FilmtoneSourceProfileMath`) after the
  Desktop Apple Log cube-builder placement is normalized.
- Cube parsing and RGB/RGBA packing helpers, with platform-specific packing kept
  as an adapter if Core Image requirements diverge.
- Creative Pack 01 catalog identities: Stone / Urban slugs, UUIDs, filenames,
  pinned hashes, intensity, pack id, and param override patches.
- Saved Look schema types (`SavedLookEntry`, `CreativeLutBinding`,
  `LibrarySnapshot`) once file-store behavior is separated from schema.

### Share After One Cleanup

These are close, but need a seam before sharing:

- Source-profile catalog and selection:
  iOS has `.userImport`; Desktop currently omits it. Shared core should own
  built-in catalog identities and Auto resolution, while each app owns user LUT
  availability.
- Export result / progress DTOs:
  iOS has `Phase0ExportProgressDTO` / `Phase0ExportResultDTO`; Desktop has
  `ExportResultSnapshot`. Shared core should own neutral export metrics, while
  iOS Save-to-Photos and Mac Reveal/Share stay platform-specific.
- Human-readable file size and elapsed labels:
  current Desktop `FilmtoneFormatters` duplicates iOS string behavior only
  partially. Shared core can own raw formatter policy; UI localization remains
  app-owned.
- Sidecar payload construction:
  iOS has the canonical large builder; Desktop has a smaller writer. Shared
  core should own schema structs / payload construction, with each app supplying
  platform identity, output URL, and optional platform telemetry.

### Keep Platform-Specific

- SwiftUI/AppKit view structure: `RootWindowView`, `ExportInspectorPanel`,
  Liquid Glass surfaces, toolbar, right rail, `NSSavePanel`.
- Finder actions: `NSWorkspace.shared.activateFileViewerSelecting`.
- Mac share popover: `NSSharingServicePicker`.
- iOS Photos save, iOS share sheet, Live Activity, notifications, WebView /
  Capacitor bridge, app cache protection.
- AVFoundation session orchestration where iOS background execution or Photos
  permissions affect behavior.

### Generated / Do Not Hand Edit

- iOS generated Swift such as
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`.
- Desktop generated mirror:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift`.

## Proposed First Extraction

Create a shared pure Swift contract target at
`packages/film-lab-swift-core`, owned by this repo and consumed locally by both
apps before any public release cutover.

Repo check:

- There is no existing `Package.swift` in this worktree.
- Current `packages/` entries are Bun/TypeScript workspaces only.
- Neither the iOS nor macOS Xcode project currently has
  `XCLocalSwiftPackageReference` / `XCRemoteSwiftPackageReference` package
  integration.
- Therefore the first implementation slice should introduce the local Swift
  package and wire both Xcode app targets to that local package explicitly,
  rather than hiding shared Swift under an existing JS package.

First payload should be intentionally narrow:

1. Generated Phase 0 params artifact.
2. `FilmtonePhase0ParamsPatch`.
3. `FilmtoneQuickState` helpers.
4. Preset resolve / interpolation / quick application.
5. Creative Pack 01 identity catalog without Bundle resource loading.

Reason: these are high-value, already exercised by Desktop Verify, and mostly
independent of AppKit/UIKit/AVFoundation. Source-profile and sidecar sharing
should follow once the first shared target compiles in both apps.

## First Implementation Route

Open a follow-up active slice, **M4-B Shared Phase0 Core Package**, with this
implementation order:

1. Add `packages/film-lab-swift-core/Package.swift`.
2. Add `Sources/FilmLabSwiftCore/` with only Foundation-level files from the
   Proposed First Extraction list.
3. Add focused package tests for preset interpolation, Quick application,
   param patch application, and Creative Pack identity constants.
4. Wire Desktop `FilmtoneDesktop.xcodeproj` to the local package product.
5. Wire iOS `App.xcodeproj` to the same local package product.
6. Remove duplicated app-local copies only after both targets compile against
   the shared product.

Do not start with source-profile, sidecar, export session, AVFoundation, or UI.
Those are second-wave extractions after the first package proves the integration
path.

## Migration Safety Gates

- iOS build / verify remains green after consuming the shared target.
- macOS build / Verify harness remains green after consuming the shared target.
- Generated Swift remains generated-only; no manual edits to generated outputs.
- No sidecar schema bump.
- No UI changes in the first extraction slice.
- Existing Desktop M5-C.4 paused work resumes with no product behavior changes.

## Checklist

- [x] Pause current M5-C.4 active task without reverting its code.
- [x] Record strategy decision for pulling M4-A forward.
- [x] Create this M4-A active task with a bounded non-code scope.
- [x] Identify first-pass share / platform-specific boundaries.
- [x] Confirm exact build integration route for the first shared target.
- [x] Decide whether the first extraction uses a repo-local SPM package under
  `packages/film-lab-swift-core` or an app-local Swift package before moving to
  `packages/`.
- [ ] Close M4-A with the selected first implementation slice and restore the
  paused M5-C.4 active task.

## Read-Only References

- iOS canonical:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`
- iOS canonical:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift`
- iOS canonical:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileMath.swift`
- iOS canonical:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSourceProfileCatalog.swift`
- iOS canonical:
  `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift`
- Desktop current:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/`
- Desktop current:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/`
- Desktop current:
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/`
- Paused M5-C.4:
  `paused/2026-05-04-m5-c4-export-inspector.md`

## Verification

- 2026-05-04 JST: Docs / strategy-only change.
- `git diff --check` passed.
- No product build required until an implementation extraction begins.

## Done Conditions

- The first shared-code extraction target and route are explicit.
- The platform-specific no-go list is explicit enough to prevent accidental
  UIKit/AppKit coupling in shared core.
- A follow-up implementation active can be opened without rereading the whole
  Native Desktop history.
- M5-C.4 can be restored from `paused/` after M4-A without losing its current
  verification state.
