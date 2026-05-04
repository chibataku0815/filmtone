# Filmtone Native Desktop v2 Strategy

Date: 2026-05-04 JST

This file is the strategic source of truth for the Native Desktop v2 lane.
Keep it short. Do not put implementation steps or file-level details here.

## Goal

Replace the current Electron Desktop product lane with a macOS 26 native
SwiftUI/AppKit application that matches or beats the current Desktop release on
preview quality, still export, video export, sidecar correctness, and user-facing
Mac experience. The primary UI material is **Apple Liquid Glass** across control
surfaces (toolbar / sidebar / inspector / picker / control panels); the preview
content layer is intentionally excluded to keep color judgment uncompromised.

The native app must remain a parallel lane until it is clearly better than the
shipping Electron rail.

## Measurable Done Conditions

- Native macOS app opens still images and videos with native controls.
- Native preview, still export, and video export use the iOS-canonical Filmtone
  grade pipeline for the supported built-in Looks.
- Still and video exports write sidecars without a schema bump.
- Look vocabulary is unified before any public release cutover.
- Apple Liquid Glass is adopted as the primary UI material on toolbar / sidebar
  / inspector / picker / control panels; the preview content layer remains
  glass-free per Apple HIG.
- Electron Desktop release behavior remains unchanged until the native lane is
  explicitly promoted.
- The app can be built, smoke-tested, signed/notarized, and distributed as the
  primary Desktop release candidate.

## Milestones

| ID | Milestone | Depends on | Status | Done Conditions |
|---|---|---|---|---|
| M1 | Native Contract And Skeleton | none | Complete | Native app builds, launches a native window, uses SwiftUI/AppKit controls, and does not change the Electron release rail. |
| M2 | Still And Video Vertical Slice | M1 | Complete | Still and video open, preview, export, and sidecar paths work through the native app. |
| M3 | Native Color And Optics Parity | M2 | In progress | Built-in Looks use the iOS-canonical color and optics stages; performance is acceptable at 4K; remaining parity gaps are explicit. |
| M4 | Shared Contract Consolidation | M3 | Deferred | Shared Swift contract ownership is clear, generated Swift remains generated-only, and iOS/macOS consume the same canonical contract without destabilizing the iOS lane. |
| M5 | Native Editing UI | M3 | In progress | Core Desktop workflows are usable in native UI: look selection, preview navigation, export controls, progress/cancel, and Finder integration. Apple Liquid Glass is applied systematically to control surfaces (toolbar / sidebar / inspector / picker / control panels), preview content layer excluded. |
| M6 | Release Cutover | M4, M5 | Not started | Signed/notarized app, release QA, public copy, portfolio/submodule updates, and Look vocabulary gate are complete. |

## Current Strategic State

- M1 and M2 are complete.
- M3 remains open for known parity hardening gaps, but its source-color
  foundation, modern AVFoundation migration, RayAngleOptics, initial optical
  stages, and 4K performance measurement are complete enough to unblock M5.
- M5 is the current product milestone.
- M5-A.2 Look Canonical Parity (Stone / Urban Creative LUT Pack 01 port from
  iOS) landed 2026-05-04 across 3 commits and is archived.
- M5-A.3 Video Preview Scrub landed 2026-05-04 (single commit 3b12805,
  preview-only, no CLI / export regression — Stone hash byte-identical to
  M5-A.2 archive record). Visual scrub UX smoke deferred to user. Archived
  immediately to make room for the user-requested M5-B interrupt slice.
- M5-B Apple Liquid Glass Adoption Pass 1 + Pass 2 both landed and
  archived. All floating control panels use `.glassEffect(.regular, in: …)`,
  the right-rail stack is wrapped in `GlassEffectContainer` for
  coordinated refraction, and toolbar / window chrome runs on macOS 26
  system-default Apple Liquid Glass without explicit opt-in. Preview
  content layer remains glass-free per strategy. No active slice is
  currently open — next active.md should decide between (a) user
  visual smoke validating Pass 1 + Pass 2 on bright/dark preview
  backdrops, then optional M5-B Pass 3 (tint / variant exploration),
  or (b) advancing M5 product surface (Tier 1 #2 successor / Finder
  integration / look selection UX). Prioritize 本質 product quality.
- Baseline-C population is intentionally treated as quality shell work unless
  formal parity proof is requested.
- M4 SPM consolidation remains deferred until native behavior is stable enough
  that module movement will not distract from product quality.
- **Parallel release lane** is in progress at
  `docs/filmtone/desktop/release-cutover/` (separate active.md singleton from
  this lane). Phase 1 closed 2026-05-04: M3 LOW gap `printContrast` sign-gate
  fixed, M6 signing posture wired (Hardened Runtime + Developer ID + entitlements
  + secure timestamp), `scripts/release-macos.sh` + `scripts/package-dmg.sh` +
  `ExportOptions.plist` shipped, archive + exportArchive verified against the
  real Developer ID Application identity (Team C3G77H8NM6, universal binary,
  notarize-ready). The remaining release-cutover gates are (a) the user-driven
  notarize submission via the user's `ASC_ISSUER_ID` env, and (b) optional App
  Category polish.

## Constraints

- macOS target is macOS 26 only.
- SwiftUI-first; AppKit only for macOS-specific interop and platform behavior.
- iOS is the canonical color/optics reference, but the iOS project must remain
  untouched unless the active task explicitly says otherwise.
- Electron Desktop remains the shipping rail until release cutover.
- Sidecar changes are additive only; avoid schema bumps until a product need
  requires one.
- Generated Swift must not be hand-edited.
- Use `bun` for repository commands.
- Keep `packages/film-lab-renderer/dist/` and `packages/film-lab-smart-look/dist/`
  tracked.

## Open Questions

- When will Desktop Look Unification land on main, enabling sidecar dual emit?
- Does baseline-C need to be populated now, or only when formal QA is requested?
- Should SPM consolidation happen before or after Native Editing UI work?
- Should deprecated Core Image kernel construction be migrated to Metal CIKernel
  before release cutover or tracked as a post-parity hardening task?
- What is the minimum signed/notarized distribution surface for the first native
  Desktop release candidate?

## Completion Log

- 2026-05-03: M1 completed with the native macOS skeleton and generated Swift
  contract lane.
- 2026-05-03: M2 completed with native still/video vertical slices and sidecar
  output.
- 2026-05-04: M3 advanced through source-color foundation, AVFoundation async
  migration, optics work, and performance measurement. Current checkpoint is
  captured in `active.md`.
- 2026-05-04: M3 C5b/C5d checkpoint clean — sourceSeed verbatim from iOS,
  pipeline order matches canonical, build/parity green. LOW gaps (Input/Creative
  LUT, printContrast abs, terminal `cropped`) tracked but no-op for built-in 4
  presets. Archived as `archive/2026-05-04-c5b-c5d-checkpoint.md`. Awaiting
  user-manual commit (INV-7) before next active task is created.
- 2026-05-04: M5-A.1 Look Strength Slider landed — iOS-canonical parameter-space
  interpolation (`reset → target` lerp, pivot = `resetParams`), Slider UI in
  `GradeControls`, plumbed through preview / export / sidecar / CLI. Default
  strength (=1.0) preserves C5b parity bytewise (reset 28.08 dB, iphone
  09-skin-light 28.81 dB). Sidecar `batchLookChoice.strength` now records intent;
  `gradeParams` records effective interpolated values. Archived as
  `archive/2026-05-04-m5-a1-look-strength-slider.md`. Awaiting user-manual commit.
- 2026-05-04: M5-A.1 Visual Smoke passed — Slider 0↔1 drag preview live, Reset
  disable visible, Soft Blue / Amber Glow same sweep behaviour confirmed.
  Archived as `archive/2026-05-04-m5-a1-visual-smoke.md`.
- 2026-05-04: M5-A.2 Look Canonical Parity landed — Stone / Urban Creative LUT
  Pack 01 ported from iOS (FilmtonePhase0ParamsPatch + CubeParser + Pack
  catalog + Loader + GradePipeline integration + 2-tier Look/Preset UI +
  sidecar additive `creativeLut` block + `--look` CLI). 3 commits
  (b8b3bd4 / 29d287f / 430c5a0). CLI smoke green: distinct PNG hashes per
  Look + per strength, D4-ii bareline at strength=0, exit 64 on unknown
  slug. Visual app smoke deferred to user. Archived as
  `archive/2026-05-04-m5-a2-look-canonical-parity.md`. Surprise logged:
  yellow-folder PBXGroup flattens cubes into `Contents/Resources/`, so the
  Loader resolves by name + extension (no `subdirectory:`) — revisit the
  blue-vs-yellow note when iOS / Desktop pbxproj patterns are unified.
- 2026-05-04: Release-cutover Phase 1 closed (parallel lane,
  `docs/filmtone/desktop/release-cutover/`). 5 commits: `4e72aae` M3
  printContrast canonical fix; `ac51869` M6 signing prep (Hardened Runtime +
  Developer ID + entitlements + --timestamp); `2942f9a` lane doc tree;
  `8bd41b4` release pipeline (release-macos.sh, package-dmg.sh,
  ExportOptions.plist); `37205a0` Phase 1 archive + portfolio bump 手順.
  Archive + exportArchive verified bytewise on real Developer ID identity.
  Remaining: user-driven notarize submit + DMG publish.
- 2026-05-04: M5-A.3 Video Preview Scrub landed — preview gains a
  scrub bar over a video source's timeline (0…duration slider); Loader
  factored to `loadFrame(from:atSeconds:)` with `loadMidpointFrame` as a
  thin wrapper; `EditorState` lifted to `@MainActor` so the new
  duration-probe Task satisfies Swift 6 strict concurrency. Single commit
  3b12805. CLI regression check: Stone @ 1.0 hash byte-identical to the
  M5-A.2 archive record → preview-only changes did not perturb export
  paths. Visual scrub UX smoke deferred to user. Archived as
  `archive/2026-05-04-m5-a3-video-preview-scrub.md`.
- 2026-05-04: M5-B Apple Liquid Glass Adoption Pass 1 landed — single
  commit f7ee950 swaps `.background(.regularMaterial, in: …)` →
  `.glassEffect(.regular, in: …)` on the three floating control panels
  in `RootWindowView.swift` (`GradeControls`, `ExportProgressBar`,
  `VideoScrubBar`), matching the existing `GlassControlGroup` posture.
  Preview content layer remains glass-free per Apple HIG + color-judgment
  integrity. Build clean under Swift 6 strict concurrency. CLI smoke
  skipped (本質外: modifier swap has zero linkage to the Electron
  CLI). Visual material smoke deferred to user. Archived as
  `archive/2026-05-04-m5-b-liquid-glass-pass-1.md`. Pass 2
  (`GlassEffectContainer` grouping, toolbar / chrome audit, tint
  exploration) tracked in archive Follow-up.
- 2026-05-04: M5-B Apple Liquid Glass Adoption Pass 2 landed — single
  commit e603067 wraps the right-rail VStack in `GlassEffectContainer`
  so `GlassControlGroup` + `GradeControls` + `ExportProgressBar`
  refract as one coordinated Apple Liquid Glass surface instead of
  three independent lenses. Per-panel `.glassEffect(.regular, in: …)`
  modifiers preserved verbatim. Bottom-center `VideoScrubBar` left
  standalone (single-child container is a no-op). Toolbar / window
  chrome audit: `FilmtoneDesktopApp` declares only `WindowGroup` +
  `.windowResizability(.contentMinSize)` and no explicit
  `windowToolbarStyle` / `toolbarBackground`, so macOS 26 default
  Apple Liquid Glass chrome is in force without opt-in. Build clean
  under Swift 6 strict concurrency. Visual coordination smoke
  deferred to user. Archived as
  `archive/2026-05-04-m5-b-liquid-glass-pass-2.md`. Pass 3
  (tint / variant exploration) deferred until base-posture visual
  smoke validates `.regular`.
- 2026-05-04: M5-B F-cycle + Pass 3 closed — user smoke surfaced 4
  failures and three rounds of speculation produced no visible change
  until a diagnostic build (extreme red tint + toolbar background
  hidden) decisively localised the root causes. Two architectural
  blockers were the actual problem: (1) `PreviewSurface` rendered via
  `NSViewRepresentable`/`NSImageView`, opaque to the Liquid Glass
  pixel sampler; refactored to SwiftUI `Image(nsImage:).resizable()
  .scaledToFill().backgroundExtensionEffect()`, and (2) AppKit was
  painting an opaque toolbar background on top of the Liquid Glass
  chrome — `.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`
  is the missing opt-in (`.windowToolbarStyle(.unified)` alone is not
  enough). Production posture: all panels + capsule + scrub bar use
  `.glassEffect(.clear, in: …)` for the dramatic refraction the user
  expected; `GlassEffectContainer(spacing: 12)` coordinates the right
  rail; scrub bar centered horizontally via outer
  `.frame(maxWidth: .infinity)` with `.padding(.bottom, 60)`. Commits
  `cab2a953` (Image refactor), `6c27b372` (toolbar background +
  diagnostic-confirmed `.regular` base), and Pass 3 unification as
  part of the F-cycle. Archived as
  `archive/2026-05-04-m5-b-liquid-glass-fcycle-and-pass3.md`. M5-B
  visual base posture is closed; further dimensions
  (sidebar/inspector/menu surfaces) only when those views exist.

## Interrupt / Decision Log

- 2026-05-04: M5-A.2 Look Canonical Parity inserted as mid-size Interrupt.
  Visual Smoke surfaced that the Desktop Look picker (Reset / iPhone / Soft Blue
  / Amber Glow) corresponds to the iOS Preset layer, not the Look layer.
  iOS-canonical Looks (Creative LUT Pack 01: Stone / Urban) are missing from
  Desktop. Original Tier 1 #2 (video scrubbing) is deferred behind M5-A.2 so
  the 2-tier Look/Preset structure is established before further UI work.
  No milestone-table change; M5 still owns this slice.
- 2026-05-04: Decided to open **M5-B (UI Material — Apple Liquid Glass)** as a
  slice within M5 rather than a new milestone. Reasoning: it is a UI quality
  dimension of Native Editing UI (M5), not an independent dependency; mirrors
  the M5-A.* slice pattern; avoids milestone-table churn. Scope: systematic
  adoption of Apple Liquid Glass across toolbar / sidebar / inspector / picker
  / control panels; preview content layer explicitly excluded (Apple HIG +
  color-judgment integrity). Goal and Done Conditions updated to make this an
  explicit release-grade requirement. Implementation prioritization vs. Tier 1
  #2 (video scrubbing) is left to the next active.md decision.

## Operating Rules

- Read this file at session start and completion only.
- Read `active.md` every implementation turn.
- If `active.md` is missing, propose the next subtask and wait for review.
- Do not implement without an `active.md`.
- Keep only one `active.md` at a time.
- For 5-30 minute small fixes, record them in the current `active.md` under
  `Unexpected` or `Follow-up`, and handle them there only when they belong to
  the active scope.
- For half-day-to-multi-day interrupts, append a `Paused` section to the current
  `active.md`, briefly list done vs. not done, move it to
  `paused/YYYY-MM-DD-{slug}.md`, then create one interrupt-only `active.md`.
- The interrupt `active.md` must name its milestone, or say `Interrupt` when it
  is outside the current milestone.
- After the interrupt finishes, archive it to `archive/YYYY-MM-DD-{slug}.md`,
  append 1-3 lines here only if strategy state changed, then restore the paused
  file back to `active.md`.
- For milestone-changing interrupts, append a short note to
  `Interrupt / Decision Log` before creating the interrupt `active.md`.
- Treat long-term direction changes as milestone-structure changes and get
  review before implementation.
- Do not use old handoffs as current truth; they are historical references.
- Archive completed active tasks into `archive/` and append only a short
  milestone note here.
