# Active — M5-M Portrait Layout + Backlight Veil + Compact Opening

Date opened: 2026-05-05 JST
Milestone: `M5-M Portrait Layout + Backlight Veil + Compact Opening`
Integration branch: `feature/native-desktop-plan`
Parallel streams:

- CC-A: `feature/native-desktop-m5-m-shell-layout`
- CC-B: `feature/native-desktop-m5-m-backlight-optics`

The integrator coordinates both streams in this worktree. CC-A and CC-B edit
disjoint file sets; no commits are made by either stream — the integrator runs
verification on the merged uncommitted state in this worktree.

## Goal

1. Portrait video editing must not place editor panels or the scrub bar over
   the loaded media. When the source aspect is portrait (height > width), the
   editor sidebar and scrub bar must sit beside / below the media instead of
   overlaying it.
2. Backlight Veil must visibly affect both still and video preview, and must
   visibly affect export. The control surface must expose a cursor (continuous
   intensity) in addition to the existing density chips, and the user must be
   able to verify the optical effect with the eye on a representative source.
3. The empty opening screen must stay compact. The branded plate and Open CTA
   must keep a fixed compact footprint regardless of window size, instead of
   stretching with the window.

Out of scope: release packaging, notarization, portfolio submodule bump,
wide-population QA, schema bump, new Look additions, additional optical
filter families.

## Edit Targets

### Shell layout (CC-A)

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  - portrait-aware overlay layout for `EditorSidebar` and `VideoScrubBar`
  - compact opening container constraints
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
  - aspect-aware reservation of editor / scrub-bar safe regions when needed
  - compact `EmptyPreviewLabel` plate sizing
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/EditorSidebar.swift`
  - portrait inspector posture (allowed to drop fixed width, switch to a
    narrower bottom-or-side rail) when the source is portrait
- `apps/filmtone-desktop-macos/Verify/main.swift`
  - portrait layout assertions if a contract test surface is needed

### Backlight optics (CC-B)

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/QuickAdjustControls.swift`
  - add Backlight Veil intensity cursor (continuous `0…1`) alongside None /
    1/8 / 1/4 / 1/2 chips
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/AdvancedAdjustCatalog.swift`
  - extend `FilmtoneOpticalFilterCatalog` so a continuous intensity scales the
    profile patch, with `renderParamOverrides` interpolating from the resolved
    base
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
  - intensity state (clamped, observable) folded into `renderParamOverrides`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneColorPipelineContract.swift`
  - confirm bloom / halation / diffusion keys are honored end-to-end so the
    visible effect is real on the preview path
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift`
  - confirm composition handler reads the patched `paramOverrides`; no schema
    bump
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneStillExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneVideoExporter.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Export/FilmtoneSidecarWriter.swift`
  - propagate intensity through export request, sidecar payload, and exporter
    pipelines without breaking existing sidecar consumers
- `apps/filmtone-desktop-macos/Verify/main.swift`
  - intensity scaling regression check

### Read-only references

- `packages/film-lab-core/src/optical-filter-profiles.ts`
- `packages/film-lab-core/src/ios-optical-filter-payload.ts`
- iOS canonical: `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrengthSheet*.swift`
  for cursor/intensity affordance shape

## Checklist

- [x] CC-A: detect portrait media via `state.videoSession.displayAspectRatio`
  for video and the rendered frame size for stills; flip the sidebar and
  scrub-bar layout accordingly
- [x] CC-A: keep `⌘\` sidebar toggle, Compare toggle, and the K4 scrub
  thumbnail overlay all functional in both layout postures
- [x] CC-A: empty `EmptyPreviewLabel` plate stays at a fixed compact size
  regardless of window width / height; opening backdrop still glass-clear
- [x] CC-A: verify the post-source-open `resizeWindow(toMediaDisplaySize:)`
  flow still reaches an aspect-fit window without forcing the new portrait
  layout to clip
- [x] CC-B: continuous intensity cursor (e.g. slider 0…1) lives next to the
  density chips; cursor must drive a visible preview change on the same source
- [x] CC-B: chip None must clear both density and intensity contribution;
  selecting any density without moving the cursor must still produce the same
  effect that landed in M5-L3 (no silent regression)
- [x] CC-B: still preview reflects the patched params AND the Backlight
  Veil optical scatter composite (PreviewSurface now takes
  `opticalFilterProfileId` / `opticalFilterIntensity` from `state` and
  threads probe-derived `cameraOptics` into `renderFrames`; the still
  PreviewRenderKey gained both fields so chip / cursor changes invalidate
  the cached frame)
- [x] CC-B: video composition rebuilds when intensity changes — confirm
  `VideoCompositionRefreshKey(state:)` already reads `state.renderParamOverrides`
- [x] CC-B: still export, video export, and sidecar writer carry the new
  intensity without bumping schema
- [x] CC-B (scatter math): six iOS-canonical `OpticalScatterParams`
  coefficients (`directTransmission`, `blackRetention`, `scatterStrength`,
  `highlightReactivity`, `warmScatter`, `spectralTail`) attached to every
  Backlight Veil profile and routed through a new
  `glowCompositeBacklightVeil` CIColorKernel
- [x] CC-B (scatter math): `FilmtoneGradePipeline.apply` accepts an
  internal defaulted `opticalFilterProfileId` argument, wired through
  still export, video export, video composition, scrub thumbnail, and
  the PreviewSurface still-preview hook
- [x] CC-B (scatter math): `CameraOpticsDTO` Sendable; video composition,
  session, and scrub thumbnail provider carry `cameraOptics` end-to-end
- [x] CC-B (chip ergonomics): Backlight Veil chip uses `contentShape(Capsule())`
  so click + pointing-hand cursor cover the full visible capsule
- [ ] Integrator: visually smoke-test on one portrait video (iPhone), one
  landscape video, one still, with Backlight Veil at None / chip-only /
  chip+cursor variations — **user-pending** (Debug app launch by user)
- [x] Integrator: run `bash apps/filmtone-desktop-macos/Verify/run.sh`,
  `bun run verify:macos`, `git diff --check`
- [ ] Integrator: archive this `active.md` and append a 1-3 line note to
  `strategy.md` — **deferred until visual smoke passes**

## Verification Result (2026-05-05 JST, post-review fix)

- `bash apps/filmtone-desktop-macos/Verify/run.sh` → **111/111 passed, 0 failed**
  (M5-M intensity tests now assert energy/structural split + anti-regression
  for the legacy `mapValues * intensity` bug, plus three new
  `intensityScaledScatter` tests covering the 1.0 byte-equivalence,
  the 0.0 nil-fallback, and the 0.5 mix toward neutral coefficients).
- `bun run verify:macos` → **BUILD SUCCEEDED** (Debug build, FilmtoneDesktop +
  FilmLabSwiftCore link clean against macOS 26.4 SDK).
- `git diff --check` → clean (no whitespace errors).
- Portrait video visual smoke → **deferred to user**. The integrator cannot
  load a portrait iPhone clip into the Debug app from the harness; the user
  is asked to confirm that (a) the editor sidebar and scrub bar do not overlay
  the portrait media, (b) the empty opening plate stays compact regardless of
  window size, (c) moving the Backlight Veil intensity cursor visibly changes
  the still and video preview on a representative source.

## Integrated Surfaces (final)

- CC-A (`feature/native-desktop-m5-m-shell-layout`): `RootWindowView.swift`
  splits into landscape (existing ZStack overlay) and portrait (HStack media
  column + 332pt sidebar column, scrub bar below media) layouts, with
  `isPortraitSource` driven by `videoSession.displayAspectRatio` for video and
  a new `sourceAspectRatio` state for still. `resizeWindow` clears the aspect
  lock and reserves the sidebar column when portrait. `EmptyPreviewLabel` is
  pinned with `.fixedSize()` so the plate never stretches with the window.
  EditorSidebar is not modified.
- CC-B (`feature/native-desktop-m5-m-backlight-optics`): adds
  `state.opticalFilterIntensity` (clamped 0…1, default 1.0), folded into
  `state.renderParamOverrides` via the new
  `FilmtoneOpticalFilterCatalog.renderParamOverrides(profileId:intensity:userOverrides:)`
  signature (the old signature stays as a default-1.0 overload for source compat).
  The control surface adds a `FilmtoneGlassSlider` cursor next to the chip row
  in `QuickAdjustControls`, dimmed/disabled when chip is None and reset to 1.0
  on chip change. CC-B also discovered the actual wiring gap: the Backlight
  Veil composite scatter math (`OpticalScatterParams` six coefficients)
  needed to be ported into a new `FilmtoneOpticalScatterMath` Foundation port
  and wired through a new `glowCompositeBacklightVeil` CIColorKernel from
  `FilmtoneGradeKernels`, then carried end-to-end through still export, video
  export, video composition, scrub thumbnail, and PreviewSurface. Without
  this kernel the bloom/halation/diffusion patch values reached the pipeline
  but did not produce the iOS-canonical scatter look. Sidecar payload now
  carries `opticalFilterIntensity` only when ≠ 1.0 (additive, no schema bump).
  Export coordinator forwards intensity. Verify harness `run.sh` was extended
  to compile `FilmtoneOpticalScatterMath.swift`, and the Xcode project file
  was updated to include the same source so the Debug build links.

## Verification

```bash
bash apps/filmtone-desktop-macos/Verify/run.sh
bun run verify:macos
git diff --check
```

Plus manual portrait video visual smoke (Debug app launch, open a portrait
iPhone clip, confirm sidebar and scrub bar do not overlay the media; toggle
Backlight Veil cursor and confirm the preview visibly changes).

## Stop Conditions

- Done when all checklist items are checked, the verification commands pass,
  and the portrait visual smoke is acceptable.
- Stop on an unexpected blocker that would force out-of-scope changes (schema
  bump, catalog redesign, AVPlayer composition rebuild architecture change).
- Stop after 3 consecutive verification failures on the same step (per AGENTS.md
  default).

## Out Of Scope

- Release packaging, notarization, portfolio submodule bump, public DMG
  re-upload.
- Broader real-media QA across non-portrait, non-Apple-Log sources.
- Any optical filter family other than Backlight Veil.
- Sidecar schema bump.

## Integration Risks To Watch

- Still preview optical profile connection: `PreviewSurface` receives
  `paramOverrides: state.renderParamOverrides`, and `renderParamOverrides`
  merges Backlight Veil + user paramOverrides. CC-B must not pass
  `state.paramOverrides` directly anywhere.
- Video composition refresh key: `VideoCompositionRefreshKey(state:)` in
  `RootWindowView` reads `state.renderParamOverrides`. Adding intensity must
  flow through `renderParamOverrides` so the key changes when the user moves
  the cursor.
- Preview sample contract: per `feedback_nsviewrepresentable_blocks_liquid_glass`,
  the still preview must remain a SwiftUI sample (`Image(nsImage:)`); the
  portrait layout refactor must not reintroduce `NSImageView` /
  `NSViewRepresentable` for the loaded-media layer.
- macOS picker dark chrome: per
  `reference_macos_picker_dark_chrome_via_colorscheme`, any new menu/picker on
  the dark Liquid Glass surface must keep `.colorScheme(.dark)`.

## Unexpected / Follow-up

CC-B scatter math (2026-05-05):

- Verify additions: `Backlight Veil profiles carry six optical scatter
  coefficients with monotonic progression`,
  `Backlight Veil composite delta progresses None < 1/8 < 1/4 < 1/2 on a
  synthetic bright frame`, and
  `Backlight Veil composite preserves shadow ordering and warm-biases scatter`.
  All 107 Verify cases pass; `bun run verify:macos` succeeded; `git diff
  --check` clean.
- Synthetic-frame probes use a deep-shadow base (subject silhouetted
  against bright bloom plates), which is the actual Backlight Veil
  scenario. At very bright bases, direct loss can dominate scatter
  growth, so absolute pixel delta is non-monotonic — a property of the
  iOS-canonical math, not a regression.
- PreviewSurface still preview is now actually wired. Previous note
  described a "minimal hook with default nil" that left the still live
  preview without Backlight Veil math; review (2026-05-05) caught the
  gap. PreviewSurface gained explicit `opticalFilterProfileId` /
  `opticalFilterIntensity` struct fields, the still-path probe pulls
  `cameraOptics` from `FilmtoneSourceProber.probeStill`, and both
  RootWindowView call sites (landscape + portrait) now pass them from
  `state`. The Backlight Veil composite is therefore visible on still
  live preview at the user's chosen intensity, matching video preview
  and exports.
- Backlight chip click + pointing-hand cursor now cover the full
  capsule via `contentShape(Capsule())` on the chip label.

CC-B intensity math fix (2026-05-05, post-review):

- `FilmtoneOpticalFilterCatalog.renderParamOverrides` previously did
  `patch.mapValues { $0 * intensity }`. That blindly attenuated every
  profile key including thresholds, radii, hue, and soft-knee — at
  intensity=0.5 the 1/4 profile's `bloomThreshold` dropped from 0.56 to
  0.28, which means the bloom kicks in on darker pixels (more aggressive
  at half intensity than full). Replaced with an `energyScaledKeys` set
  (`bloomStrength`, `halationIntensity`, `diffusion`, `lensSoftness`,
  `rgbShift`) that scales linearly; structural keys pass through profile
  values verbatim while the profile is engaged, and at `intensity=0` no
  profile keys are emitted at all (only explicit user overrides remain).
- `FilmtoneGradePipeline.apply` now takes `opticalFilterIntensity:
  Double = 1.0`. It resolves the optical scatter via a new
  `FilmtoneOpticalFilterCatalog.intensityScaledScatter(for:intensity:)`
  helper that returns `nil` at `intensity ≤ 0`, so the Backlight Veil
  composite path is fully bypassed (legacy `glowComposite` runs instead)
  when the user has zeroed the cursor — no Backlight-specific direct
  loss / scatter math leaks into the render. At intermediate intensity,
  scatter coefficients blend toward neutral (`directTransmission → 1.0`,
  all others → 0).
- Verify additions: `intensity scales energy keys linearly; structural
  keys pass through verbatim`,
  `intensity does not pre-load thresholds (anti-regression for mapValues
  bug)`, `intensityScaledScatter returns nil at intensity 0 (legacy glow
  fallback)`, `intensityScaledScatter at 1.0 equals catalog scatter
  byte-for-byte`, `intensityScaledScatter at 0.5 blends toward
  neutral-no-effect coefficients`. The earlier monotonic-linear-scale
  test was removed because it locked in the wrong implementation.
- Threaded `opticalFilterIntensity` through
  `FilmtoneDesktopVideoRenderInputs`, `FilmtoneDesktopVideoSession.resolveInputs`,
  `EditorState.currentVideoRenderInputs`, the still and video exporter
  GradePipeline call sites, and the composition factory handler.

Compact opening fix (2026-05-05, post-review, integrator):

- ultrareview flagged P1-B: `RootWindowView` initial `minimumContentSize`
  was `1080×720` and the empty-state plate's `.fixedSize()` only
  constrained the inner plate, so the launch window opened at the
  desktop minimum 1080×720. Real fix: introduced two statics —
  `compactOpeningMinimumSize = 480×400` (floor) and
  `compactOpeningInitialSize = 600×500` (initial frame). Initial
  `@State minimumContentSize` now reads from the floor static; on first
  window resolve `resolveWindow` sets `window.contentMinSize` and, if the
  user has not opened media yet, calls `applyCompactOpeningFrame` to
  shrink the actual window frame to the compact initial size centered on
  the active screen.
- Added `applyCompactOpeningPosture()` invoked from
  `.onChange(of: state.sourceURL == nil)` so closing a source restores
  the compact opening frame instead of leaving the user with the prior
  source's expanded window. Once media opens,
  `resizeWindow(toMediaDisplaySize:)` continues to drive both the floor
  and the frame to fit the source.
- ultrareview P1-A ("still preview never receives Backlight optical
  profile") and P2 ("intensity scales absolute target values from zero")
  inspected against current code: both **stale review** — already
  addressed by the PreviewSurface wiring + `energyScaledKeys`
  categorization fixes recorded above. Re-verification passes.
- Verification: `bash apps/filmtone-desktop-macos/Verify/run.sh` →
  111/111; `bun run verify:macos` → BUILD SUCCEEDED;
  `git diff --check` → clean.

Portrait sidebar reservation fix (2026-05-05, post-review, integrator):

- ultrareview flagged P2: `RootWindowView.resizeWindow(toMediaDisplaySize:)`
  computed `contentMinimum` from `availableContentSize` and assigned it
  to both `minimumContentSize` and `window.contentMinSize` without ever
  adding `sidebarReservation`. The `mediaSize` clamp also subtracted
  `sidebarReservation` from a value that did not contain it, so the
  total window minimum was effectively media-only. Combined with the
  absence of any `.onChange(of: sidebarOpen)`, opening a portrait video
  with the sidebar closed (`@AppStorage` remembered state) and then
  toggling `⌘\` shoved the 332pt sidebar column into the existing window
  width, crushing the media column.
- Real fix: introduce a `mediaContentMinimum` derived from the
  screen-available budget *minus* the sidebar reservation, then build
  `contentMinimum = mediaContentMinimum + sidebarReservation` so the
  total window floor includes the sidebar column. The `mediaSize` clamp
  now compares against `mediaContentMinimum` directly. Cache the opened
  media display size in a new `@State lastMediaDisplaySize` so a
  portrait `.onChange(of: sidebarOpen)` can re-run
  `resizeWindow(toMediaDisplaySize:)` with the same media size, growing
  or shrinking the window by exactly `portraitSidebarColumnWidth` and
  re-asserting the new floor. `applyCompactOpeningPosture()` clears the
  cache so an empty-state sidebar toggle does not re-apply stale media
  sizing.
- Landscape skips the sidebar onChange branch — landscape uses a ZStack
  overlay where `EditorSidebar` floats over the preview, so toggling the
  sidebar there does not change layout geometry.
- Verification: `bash apps/filmtone-desktop-macos/Verify/run.sh` →
  111/111; `bun run verify:macos` → BUILD SUCCEEDED;
  `git diff --check` → clean.

Video pre-session aspect fallback fix (2026-05-05, integrator):

- Follow-up review flagged a remaining timing gap: `isPortraitSource` uses
  `videoSession.displayAspectRatio` for videos, but `videoSession` arrives
  asynchronously. During that prepare window the fallback `sourceAspectRatio`
  could still hold the previous source's still aspect, and the new portrait
  sidebar reapply gate could skip a user sidebar toggle before the session
  attached. Fixed by clearing `sourceAspectRatio` and `lastMediaDisplaySize`
  at the start of every new source resize path, then seeding
  `sourceAspectRatio` from the video probe's display size before calling
  `resizeWindow(toMediaDisplaySize:)`.
- Verification: `git diff --check` → clean;
  `bash apps/filmtone-desktop-macos/Verify/run.sh` → 111/111;
  `bun run verify:macos` → BUILD SUCCEEDED.

Close note (2026-05-05):

- M5-M implementation is ready for main merge per user direction. Remaining
  product risk: manual Debug-app visual smoke with a real portrait iPhone clip
  was not run in this chat; machine gates and static review are clean.

Look Strength continuous response (2026-05-05, post-M5-M):

- Reported: the Look Strength slider in the Native Desktop v2 UI behaved as
  a 0/100 binary because `FilmtoneGradePipeline.applyCreativeLutStage` had
  no path for user-strength alpha (Pack 01 pinned `lut.intensity = 1.0`),
  and the preset 35-param lerp alone could not visibly compete with the
  LUT color cube as the dominant signal.
- Fix (`feature/native-desktop-look-strength-fix` worktree, branched from
  main `cb802a2c`): `FilmtoneGradePipeline.apply` gains `lutIntensity:
  Double = 1.0`; `applyCreativeLutStage` ports the iOS canonical
  `applyLut` alpha-blend (`CIColorMatrix` + `CISourceOverCompositing`) with
  a fast path at `≥0.999` (cube only) and `≤0.001` (passthrough).
  `FilmtonePresetCatalog.resolved` now resolves the Look path to its full
  `target` params unconditionally (no preset-lerp), so the Strength slider
  is owned exclusively by the LUT alpha and avoids `t²` double attenuation.
  All five callers — `PreviewSurface`, `FilmtoneStillExporter`,
  `FilmtoneVideoExporter` (×2 `VideoFrameRenderContext` initializers + the
  per-frame `apply` call), and `FilmtoneDesktopVideoComposition` — pass
  `clampStrength(presetStrength)` into the pipeline. The
  `presetStrength > 0` LUT-load gate is preserved as a second line of
  defense.
- iOS canonical deviation: iOS keeps `presetStrength` as a preset-lerp
  driver with `lut.intensity = 1.0` (Pack 01 pin); macOS now drives
  `lut.intensity = presetStrength`. `strength = 1.0` is byte-identical
  across platforms and across the pre/post-fix macOS path; intermediate
  strengths diverge by design.
- Verification: `xcodebuild ... build` → BUILD SUCCEEDED (warnings are
  pre-existing CIKernel deprecation + `AVMutableVideoComposition`
  deprecation; no new diagnostics from this fix). Visual A/B (Stone /
  Urban × strength {0, 0.25, 0.50, 0.75, 1.0}) and `cmp` byte-parity at
  `strength = 1.0` deferred to user smoke.
- Strategy note for archive time: this is the `M5-M.fixup` referenced
  earlier — promote to `strategy.md` Completion Log only after user
  visual smoke confirms continuous response + 1.0 byte parity.
- Closed 2026-05-05 by user visual smoke (Stone / Urban Strength slider
  responds continuously across the 0–100 % range). Promoted to
  `strategy.md` Completion Log; merged into `main` along with M5-M.
