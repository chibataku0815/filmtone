# M5-H.1 App Chrome / Preview Layout

Date: 2026-05-05 JST
Branch: `feature/native-desktop-m5-h1-chrome-layout`
Base: `65e3f3f6` (post M5-G Architecture Thin Cuts)
Milestone: M5 (Native Editing UI)

This is a branch-local `active.md` per the M5-H parallel coordinator setup.
Strategy.md is intentionally untouched in this branch; the coordinator will
log the M5-H landing in strategy after all M5-H lanes have merged.

## Goal

Close the user-smoke chrome / layout / brand defects surfaced after the
M5-C P0 closure: window title, initial window sizing, brand assets,
preview aspect-ratio handling, residual `Phase 0` placeholder copy, and
4/8-grid alignment of root paddings. macOS 26 Apple Liquid Glass posture
established in M5-B Pass 1–4 must be preserved.

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/App/AppCommands.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/GlassControlGroup.swift`

## Read-only References

- `docs/filmtone/desktop/native-desktop-v2/strategy.md` (M5-B / M5-G context)
- iOS canonical AppIcon already shipped into
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Assets.xcassets/AppIcon.appiconset/`
  (M5-E.1, commit `758ada3a`)

## Checklist

- [x] Window title `Filmtone Desktop` → `Filmtone`
- [x] Initial window size pinned via `.defaultSize(width: 1280, height: 800)`
- [x] `minWidth` / `minHeight` raised 880×560 → 1080×720 so the 5-panel right
      rail stays in-frame after a source is opened
- [x] Toolbar `camera.aperture` placeholder replaced with
      `NSApp.applicationIconImage` (Group-wrapped to satisfy
      `ToolbarContentBuilder`)
- [x] `Phase 0` copy stripped from `GlassControlGroup` and the help-menu link
      (`Filmtone Native Desktop v2 (Phase 0)` → `Filmtone Help`)
- [x] `GlassControlGroup()` invocation removed from the right rail; the file
      itself is repurposed as a brand pill (AppIcon + `Filmtone` wordmark in
      a Liquid Glass capsule), currently unwired but available
- [x] Preview switches from `.scaledToFill().clipped()` to `.scaledToFit()`;
      the new `FilmtoneBackdrop` carries `.backgroundExtensionEffect()` so
      the toolbar continues to refract a real surface
- [x] Empty-preview state rebuilt: `FilmtoneBackdrop` warm near-black
      gradient + AppIcon mark (96pt) + `Filmtone` wordmark (28pt, tracking 4)
      + Japanese CTA `素材を開いて始めましょう`
- [x] Right-rail panel `.padding(.horizontal, 14)` → `16` across all 5
      panels and the bottom scrub bar; vertical 8pt and rail spacing 12pt
      already on grid

## Verification

- `apps/filmtone-desktop-macos/Verify/run.sh` → 42/42 passed (no regression
  vs. M5-G.2 baseline).
- `bun run verify:macos` → xcodebuild Debug `** BUILD SUCCEEDED **`,
  Swift 6 strict concurrency clean, codesign + Validate + LaunchServices
  registration green.
- Visual smoke (still + video open, right-rail visibility, scaledToFit
  letterboxing, brand launch screen) deferred to user-driven sanity per
  active scope.

## Done Conditions

- [x] All checklist items checked.
- [x] xcodebuild Debug PASS.
- [x] Verify script PASS (42/42).
- [x] No `Phase 0` substring remains in user-facing surfaces; only the two
      M5-H.1 explanatory comments (in `GlassControlGroup.swift` and
      `RootWindowView.swift`) reference the retired banner historically,
      and `Color/FilmtoneGradeKernels.swift` keeps its internal generator
      reference per active scope.

## Out of Scope

- Advanced Adjust internals (M5-C.3b surface frozen)
- Saved Look operations (LibraryViewModel)
- Dual LUT (M5-H.3 worktree)
- Playback architecture / AVPlayer migration (M5-D.2.1 candidate / M5-D2 worktree)
- release-cutover docs/scripts
- Portfolio submodule

## Verification

- `bun run verify:macos`
- `apps/filmtone-desktop-macos/Verify/run.sh`
- xcodebuild Debug (Swift 6 strict concurrency)
- Visual smoke (deferred to user): open still + video, confirm right rail
  stays in-frame and preview is letterboxed without clipping

## Done Conditions

- All checklist items checked.
- xcodebuild Debug PASS.
- Verify script PASS (no regression vs. M5-G.2 baseline = 42 tests).
- No `Phase 0` substring remains in `apps/filmtone-desktop-macos/FilmtoneDesktop/`
  user-facing surfaces (Color/ source comment is allowed).

## Unexpected / Follow-up

(populated as work progresses)
