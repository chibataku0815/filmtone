# 02 Target Architecture And Contracts

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## App Shell

Create a new macOS native app surface:

```text
apps/filmtone-desktop-macos/
```

Initial shape:

```text
apps/filmtone-desktop-macos/
  FilmtoneDesktop.xcodeproj
  FilmtoneDesktop/
    App/
    UI/
    Preview/
    Export/
    Media/
    SharedGenerated/
    Fixtures/
  Tests/
```

Use SwiftUI for primary UI and AppKit where macOS behavior requires it:

- `App` / `Scene` / `Commands`
- native menu commands
- `WindowGroup` or document-like window strategy after spike
- `NavigationSplitView` or AppKit-backed sidebar only if it improves workflow
- `NSToolbar` / AppKit window configuration when SwiftUI window APIs are
  insufficient
- `NSOpenPanel`, `NSSavePanel`, Finder reveal, drag and drop

Liquid Glass target surfaces:

- top toolbar / command layer
- source and look sidebars
- floating preview controls
- export footer and progress controls
- modal sheets and popovers

Do not apply heavy glass to the image/video preview itself. The preview is a
color judgment surface; glass belongs to the control layer above and around it.

## Media / Render Core

Native Desktop v2 should not port UI first and defer image correctness. The
first useful app must render and export.

Preferred pipeline:

```text
source file
  -> native source probe
  -> source profile normalization
  -> generated Phase0 params / LUT graph
  -> CoreImage / Metal render path
  -> preview surface
  -> AVFoundation export
  -> sidecar / metadata
```

Reuse from iOS where the code is already product-grade:

- `FilmtoneExportSession`
- `FilmtoneColorPipeline`
- `FilmtoneCubeParser`
- `FilmtoneLutBlobCodec`
- `FilmtoneSourceProfileMath`
- `FilmtoneSourceProfileCatalog`
- `FilmtoneMetalOpticsRenderer`
- `MezzanineService` concepts, not necessarily exact cache policy

Use shared TS packages as contract source where they are already source of
truth:

- `packages/film-lab-core` for params, presets, source profile schema, LUT
  payload contract
- `packages/film-lab-renderer` for shader parity references and fixture
  expectations
- existing `scripts/generate-filmtone-ios-swift.ts` should become a broader
  generated Swift contract path for iOS + macOS, or split into a shared
  generator while preserving current iOS output exactly.

## Performance Render Spine

Phase 1 may use the smallest native path that proves still preview/export
parity. The final Native Desktop v2 render spine should be designed toward:

```text
AVAssetReader
  -> CVPixelBuffer (IOSurface-backed where feasible)
  -> source profile normalization
  -> shared grade / LUT / optical finish stages
  -> Metal or CoreImage+Metal render target
  -> AVAssetWriter
```

Principles:

- Avoid per-frame `NSImage` / `CGImage` / JS `ImageData` round trips in the
  video path.
- Prefer a preview/export pipeline that shares the same stage order and shader
  constants; if paths differ, prove equivalence with golden tests.
- Pick pixel formats intentionally for both render correctness and encoder
  compatibility instead of accepting implicit conversions.
- Treat IOSurface-backed `CVPixelBuffer` and Metal compute as Phase 2 proof
  targets, not Phase 1 blockers.
- Benchmark representative 4K/6K clips before making public speed claims.

## Data Contract

Native Desktop must keep these stable:

- `Params`
- source profile id / curve / display name
- LUT slots and `.cube` parsing semantics
- Desktop sidecar import/export behavior
- preview/export parity
- iOS fixture parity for source profile math
- recipe JSON fields needed for future iOS -> Mac export handoff:
  input identity, source profile id, params/look identity, trim range, output
  intent, and material verification hash when available

If the native app needs new metadata, add fields in an additive way first.
Avoid schema version bumps until a product need requires them.
