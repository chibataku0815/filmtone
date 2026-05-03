# 04 Phase Plan

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Phase 0: Contract And Skeleton

Goal: create the native app lane without touching release behavior.

Deliverables:

- `apps/filmtone-desktop-macos/` Xcode project or Swift package-backed app.
- Buildable empty native app with:
  - app icon placeholder from existing resources if compatible
  - native main window
  - basic menu commands
  - first Liquid Glass toolbar/sidebar experiment
- Generated Swift contract wiring plan:
  - either reuse iOS generated Swift output in a shared location
  - or generate iOS and macOS outputs from the same generator input
- One fixture folder copied or referenced from existing test assets.

Acceptance gate:

- Native app builds locally.
- Launches a window.
- Uses SwiftUI / AppKit native controls, not WebView UI.
- Does not change Electron Desktop release output.
- Does not hand-edit generated Swift.

Suggested verification:

```bash
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

## Phase 1: Product Vertical Slice

Goal: prove that Native Desktop can do real Filmtone work, not only native UI.

Deliver one flow:

```text
open one still image
  -> preview it
  -> apply one built-in grade / source profile
  -> export one still
  -> write minimal sidecar
```

Then add the smallest video slice:

```text
open one short video
  -> render representative preview frame
  -> export short H.264 MP4 clip
```

Do not build batch UI yet. One correct item is more valuable than a wide shell.

Acceptance gate:

- The same params produce visually matching output against existing Electron /
  iOS golden fixtures within defined tolerance.
- Source profile conversion matches shared/iOS fixture parity.
- Exported still and video open in QuickTime / Finder without repair.
- Preview and export use the same native grade path or an explicitly proven
  equivalent path.
- Liquid Glass UI does not reduce preview legibility or color judgment.
- Sidecar emission is bit-互換 with the Look Unification contract. If Look
  Unification is landed: dual emit (legacy + `lookId` / `lookVersion`) and
  `normalizeFilmLookGradeInputIdentity` 通過. If not yet landed: Look canonical
  only, ready for Electron-side reader catch-up on landing.

Suggested verification:

```bash
bun run build:core
bun test packages/film-lab-core/src/source-profile-conversion.test.ts
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

Look Unification main 着地状況の確認:

```bash
# core 側に BASE_LOOKS が export されているか
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
# sidecar reader の discriminator が lookId を見ているか
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
```

## Phase 2: Native Color / Export Backbone

Goal: make native rendering/export credible enough to replace Electron for core
work.

Work items:

- Port or share Phase0 generated params.
- Establish native LUT parsing and LUT packing parity.
- Port source profile math and catalog.
- Establish CoreImage / Metal stage order.
- Implement still export with color profile handling.
- Implement video export with `AVAssetReader` / `AVAssetWriter`.
- Investigate IOSurface-backed `CVPixelBuffer` flow for the video path.
- Define preferred render and writer pixel formats explicitly.
- Preserve or intentionally replace current ffmpeg/VideoToolbox behavior with a
  native AVFoundation pipeline.
- Define native cache strategy for mezzanine/proxy equivalents.
- Emit Desktop sidecar compatible with existing reader where possible.

Acceptance gate:

- Still export parity passes for representative presets.
- Video export parity passes for representative clips.
- HDR / SDR policy is explicit and tested.
- Source profile id round-trips through sidecar.
- Built-in `.cube` and custom `.cube` behavior are both covered.
- Video path avoids avoidable per-frame image object conversions, or records a
  measured reason for a temporary exception.
- Preview/export stage equivalence is proven before performance tuning claims.
- Failure states are explicit; no silent fallback that changes output quality.

Verification should stay small until quality is proven:

```bash
bun run build:core
bun run generate:ios-swift
bun run verify:ios
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

Add native golden tests only around changed surfaces first. Do not start with a
large formal QA matrix.

## Phase 3: Native Editing And Export UI

Goal: replace the Electron UI with a Mac-native workflow that is better than
the current Desktop product.

Build the app around Filmtone's actual workflow:

1. source selection
2. preview and compare
3. look / source profile / optical finish controls
4. export destination and format
5. progress, cancel, reveal in Finder

UI principles:

- Use native components where the platform already knows the behavior.
- Put Liquid Glass in navigation and command layers.
- Keep dense pro controls compact and scannable.
- Avoid marketing-style hero surfaces.
- Avoid nested card stacks.
- Use native menu commands and keyboard shortcuts.
- Keep preview unoccluded and color trustworthy.

Acceptance gate:

- A user can complete the core flow without reading explanation text.
- Native UI is clearly higher quality than the Electron surface.
- Toolbar/sidebar/sheets feel like a macOS app, not a web app in a window.
- Keyboard and menu commands cover repeat workflows.
- Drag/drop and Finder integration work.

## Phase 4: Batch, Sessions, And Product Completeness

Goal: reach current Desktop capability, then exceed it.

Work items:

- photo folder batch
- single video export
- session restore
- proxy/mezzanine cache controls if still needed
- preset/source profile import/export
- `.cube` LUT export for Resolve / FCP-compatible color-only handoff, with
  non-LUT stages such as grain / halation / bloom declared as not represented
  by the LUT
- progress persistence and cancellation
- update check strategy for the native app
- packaging/signing/notarization

Acceptance gate:

- Current Electron Desktop's core capabilities are covered.
- Native app has no lower-quality export path.
- Native app can be distributed as signed/notarized DMG.
- Existing Desktop sidecars remain useful or a migration path exists.
- LUT export has clear scope: color transform only, not a promise to reproduce
  every optical finish stage in an NLE.

## Phase 5: External Shell And Release QA

Only start this after Phase 4 product gates pass.

Work items:

- release notes
- public download copy
- portfolio `vendor/filmtone` update
- support/privacy copy if behavior changed
- broad QA matrix
- screenshot set
- migration notice from Electron Desktop if needed

This phase is intentionally late. It protects momentum: product quality first,
outer shell only when there is a product worth wrapping.

## First Implementation Order

Start here after this plan:

1. Create `apps/filmtone-desktop-macos/`.
2. Add a buildable SwiftUI macOS app target.
3. Add a native window with toolbar/sidebar and one Liquid Glass control group.
4. Add source file open for one still image.
5. Render the still in a native preview.
6. Wire generated/default Phase0 params.
7. Export the still.
8. Compare output against an existing known-good fixture.
9. Add one short video preview/export slice.
10. Only then expand UI surface.

Do not begin by recreating every Electron panel.
