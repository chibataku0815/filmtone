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

Native Desktop v2 replaces the Electron Desktop product
(`apps/desktop-film-lab-batch`) as a **single-product cutover**; no parallel
distribution. Electron 1.0.4 is the final public build of the legacy lane
(frozen download for pre-macOS-26 users). Cutover details: see
`../release-cutover/cutover-architecture.md`.

## Measurable Done Conditions

- Native macOS app opens still images and videos with native controls.
- Native preview, still export, and video export use the iOS-canonical Filmtone
  grade pipeline for the supported built-in Looks.
- Still and video exports write sidecars without a schema bump.
- Look vocabulary is unified before any public release cutover.
- Apple Liquid Glass is adopted as the primary UI material on toolbar / sidebar
  / inspector / picker / control panels; the preview content layer remains
  glass-free per Apple HIG.
- Electron Desktop is sunsetting at 1.0.4 (frozen). Native Desktop v2 ships
  under the same Bundle ID `com.chibatakumi.film-lab-desktop` so existing
  installs upgrade in place when 1.4 lands.
- The app can be built, smoke-tested, signed/notarized, and distributed as the
  primary Desktop release candidate.

## Milestones

| ID | Milestone | Depends on | Status | Done Conditions |
|---|---|---|---|---|
| M1 | Native Contract And Skeleton | none | Complete | Native app builds, launches a native window, uses SwiftUI/AppKit controls, and does not change the Electron release rail. |
| M2 | Still And Video Vertical Slice | M1 | Complete | Still and video open, preview, export, and sidecar paths work through the native app. |
| M3 | Native Color And Optics Parity | M2 | In progress | Built-in Looks use the iOS-canonical color and optics stages; performance is acceptable at 4K; remaining parity gaps are explicit. |
| M4 | Shared Contract Consolidation | M3 | In progress (M4-B Phase0 core closed; preset / source profile / sidecar / cube parser slices follow) | Shared Swift contract ownership is clear, generated Swift remains generated-only, and iOS/macOS consume the same canonical contract without destabilizing the iOS lane. |
| M5 | Native Editing UI | M3 | In progress | Core Desktop workflows are usable in native UI: look selection, preview navigation, export controls, progress/cancel, and Finder integration. Apple Liquid Glass is applied systematically to control surfaces (toolbar / sidebar / inspector / picker / control panels), preview content layer excluded. |
| M6 | Release Cutover | M5 | In progress | release-cutover lane Phase 1-7 done (signing posture + pipeline + 0.1.0 smoke + cutover identity + distribution scripts; version policy corrected to iOS-aligned 1.4: Bundle ID `com.chibatakumi.film-lab-desktop` / Product Name `Filmtone` / MARKETING_VERSION `1.4`). Final 1.4 公開 gate = M5-C P0 (C.2 Look library / C.3 Adjustments / C.4 Export panel) closure。詳細: `../release-cutover/cutover-architecture.md`。 |

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
- M4-A Shared Swift Boundary Cut Line closed 2026-05-04 — boundary matrix +
  first extraction route at `packages/film-lab-swift-core` confirmed.
- M4-B Shared Phase0 Core Package closed 2026-05-04 (commits `5efb7072` +
  `7663bd1f`). `FilmLabSwiftCore` SPM lit up via XCLocalSwiftPackageReference
  on both Desktop and iOS targets; iOS local copies of `FilmtoneQuickState`,
  `FilmtonePhase0Params`, `FilmtonePhase0ParamsPatch`,
  `FilmtonePhase0HiddenDefaults`, `Phase0OutputProfileDTO`, and the generated
  `FilmtonePhase0Generated.swift` deleted; iOS-only Patch / Params methods
  preserved as extensions on the package types. Generator collapsed from
  3 outputs → 1 (package public). `swift test` 27/27 ✅, Desktop xcodebuild
  Debug ✅, iOS xcodebuild Debug ✅, Verify 36/36 ✅. Archive:
  `archive/2026-05-04-m4-b-shared-phase0-core-package.md`.
- M5-C.4 Mac-native Export Inspector closed 2026-05-04 (commits `5cea00c6`
  + `d4d46cf3` + `d3d2ab6d`). 4-state inspector (blocked / progress /
  finished / ready) + Reveal in Finder + NSSharingServicePicker (button-
  anchored) + format picker (PNG↔JPEG) + JPEG quality slider (clamped
  0.5...1.0) + source-cap amber reason cards、Desktop xcodebuild Debug ✅、
  Verify 36/36 ✅。Visual runtime smoke は user-driven sanity に deferred、
  code-level wiring 検証で 8 Done 条件すべて satisfied。Archive:
  `archive/2026-05-04-m5-c4-export-inspector.md`. → M5-C P0 (C.2a foundation
  + C.3a parity + C.4 inspector) すべて closed。M6 1.4 公開 gate は残り
  user-driven notarize submission のみ。
- 2026-05-04 user smoke で 5 個の追加ギャップ判明 → 推奨順で計画化:
  - **M5-E.1 App Icon Asset Population** (Tier A, ~20 min): `Assets.xcassets/
    AppIcon.appiconset/Contents.json` は 10 entry 宣言済みだが .png 0 個 →
    placeholder アイコンのまま起動。iOS の `AppIcon-512@2x.png` を source に
    macOS sips で 10 size 生成、Contents.json に `filename` 補完。
  - **M5-D.1 Video Scrub Bar Glass Posture + Visibility** (Tier A, ~30 min):
    `VideoScrubBar` (RootWindowView.swift:371) は landed 済みだが
    `.glassEffect` 未適用 + bottom-anchored capsule wrap なし → 発見しづらい。
    Pass 4 `.clear` posture に統一。
  - **M5-F.1 Inline Button Glass Posture Pass** (Tier B, ~1-2h): Export
    Inspector / Grade / QuickAdjust 等の inline button が `.borderedProminent`
    system default (smoke screenshot で「しょぼすぎる」と判定)。Pass 1-4 は
    panel/capsule/scrub/toolbar のみ → Pass 5 として inline button を
    `.glassEffect(.clear)` 系 posture に統一、配色も dark glass と調和させる。
  - **M5-D.2 Native Video Playback** (Tier B, ~2-3h): Play/Pause button +
    AVPlayer 駆動の time observer + Space-key shortcut。realtime grade 維持は
    重い → 着手前に「play 中は raw decoded frame で grade-off プレビュー」か
    「decode + grade で frame drop 容認」を user 判断。
  - **M5-C.3b Advanced Per-Parameter Override Editing UX** (Tier C, ~半日):
    iOS canonical `FilmtoneStrengthSheet` + `FilmtoneAdjustmentHelpSheet` の
    Desktop 版。30 個前後の paramOverrides field を category 別に list 化、
    paramOverrides storage / apply 経路は M5-C.3a で lit up 済み。Desktop UX
    は sheet ではなく right-rail 拡張 panel か popover で適合化。
- Future product direction: cross-device SSD workflow. The intended shape is
  source media moved by SSD / Files / Finder, shared sidecar + Look intent moved
  with the source, Desktop as the master / 4K-capable exporter, and iPhone as
  the lightweight FHD / Postcard exporter. This is not a first native release
  gate yet, but M4 shared core and sidecar decisions must preserve this route.
- Future product direction: DaVinci highlight-marker handoff. Filmtone iOS and
  Desktop should be able to write source-relative highlight markers into the
  shared sidecar/package, so a DaVinci Workspace Script can create markers or a
  marker-centered rough-cut timeline from the same source media after SSD /
  Files / Finder handoff. This is a future sidecar/Connect slice, not an M4-B
  Phase0 core requirement. Plan:
  `davinci-highlight-marker-handoff-plan.md`.
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

## Interrupt / Decision Log

- 2026-05-04: User flagged that Native Desktop v2 feels like it is not actually
  reusing iOS implementation. Decision: pause M5-C.4 temporarily and pull M4-A
  forward as a bounded architecture slice that defines reusable pure Swift
  ownership vs. Mac-native UI/platform shell before any SPM/file movement.
- 2026-05-04: User confirmed the larger cross-device direction: SSD-based
  source handoff, Desktop for master / 4K output, iPhone for simpler FHD /
  Postcard output. Decision: treat this as a strategic compatibility constraint
  for M4 shared core / sidecar / output-profile work, not as an immediate M5-C
  UI requirement.
- 2026-05-04: M5-C.4 archive 後の user smoke で 5 個の追加ギャップ surface —
  (1) playback 機能なし、(2) scrub bar が discoverable でない (`.glassEffect`
  未適用)、(3) iOS 「調整」+ 詳細変更 (FilmtoneStrengthSheet + AdjustmentHelpSheet)
  が Desktop 不在、(4) AppIcon.appiconset に .png 0 個で placeholder アイコン、
  (5) inline button が `.borderedProminent` system default で dark glass posture
  と整合せず「しょぼい」。Decision: Tier A → Tier B → Tier C の順で 5 slice 化
  (M5-E.1 → M5-D.1 → M5-F.1 → M5-D.2 → M5-C.3b)。Tier A 2 件は本質直結 + 短い
  ので連続着手、Tier B B2 → B1 順、C は M5-C P0 closure 後の P1 だが体感
  優先度から B 着手中に再評価。
- 2026-05-04: User confirmed the DaVinci highlight-marker direction. Local
  Resolve docs and existing Lua scripts show the route is feasible:
  source-relative Filmtone markers can become Resolve markers or direct
  `AppendToTimeline` clip ranges. Decision: preserve this as an additive
  sidecar/package compatibility constraint; do not mix it into the current
  Phase0 core extraction. Detailed future-slice plan captured in
  `davinci-highlight-marker-handoff-plan.md`.

## Constraints

- macOS target is macOS 26 only.
- SwiftUI-first; AppKit only for macOS-specific interop and platform behavior.
- iOS is the canonical color/optics reference, but the iOS project must remain
  untouched unless the active task explicitly says otherwise.
- Electron Desktop 1.0.4 is the final public legacy build. Native Desktop v2 takes
  over the same Bundle ID (`com.chibatakumi.film-lab-desktop`) + fixed
  download URL on cutover (gated on M5-C P0 closure).
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
- Which exact output-profile vocabulary should represent Desktop master / 4K
  vs. iPhone FHD / Postcard without overloading the current iOS
  `quality` / `speed` render-mode enum?
- What source identity / relink fields should the sidecar carry so an SSD-moved
  source can reconnect cleanly on both Mac and iPhone?
- What exact additive sidecar shape should represent highlight markers
  (`sourceTimeSec`, `sourceFrame`, `sourceFps`, `preRollSec`, `postRollSec`,
  marker color/name/note, and stable marker IDs) so DaVinci can round-trip them
  through marker `customData` without binding Filmtone to Resolve-only fields?

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
- 2026-05-04: M5-B Pass 4 (GradeControls readability) closed — user
  smoke after Pass 3 surfaced that the only operating panel
  (`GradeControls` Picker + Strength + Slider) lost text/track
  contrast over bright preview content. Diagnostic-first single
  build proved `Glass.clear.tint(.black.opacity(_:))` actually wires
  on `.clear` despite prior memory caveat (which only applied to
  *light* tints), and a one-shot pivot landed: `GradeControls` panel
  uses `.clear.tint(.black.opacity(0.30))`, labels use
  `.foregroundStyle(.white)` (`.white.opacity(0.7)` for the percent),
  Slider uses `.tint(.white)`, and the Picker takes `.colorScheme
  (.dark)` so its AppKit-bridged NSPopUpButton renders white-label
  dark-chrome instead of the SwiftUI-ignored `.foregroundStyle(.white)`.
  Capsule, scrub bar, toolbar, and chrome unchanged — Pass 3 `.clear`
  posture preserved everywhere except the operating panel. M5-B body
  of work is now closed across Pass 1 / 2 / 3 / 4 + F-cycle.
- 2026-05-04: M5-C iOS Feature Parity Audit closed — read iOS Phase 0
  editor + Swift surfaces and Native Desktop v2 source, built a
  workflow-grouped parity gap table, and classified P0 (Source
  Profile, source-cap/HDR gate, Look library, Adjustments, Export
  panel), P1 (playback compare, custom creative LUT, persistence,
  optical/depth surfacing), P2 (literal iOS onboarding, Live
  Activity / notifications). Recommended **M5-C.1 Native Source
  Profile And Source Gate Parity** as the next implementation slice
  because it closes the highest correctness gap (iOS Auto/Apple Log/
  Apple Log 2/DJI/Canon/Panasonic/Sony/Rec.709 normalization is
  missing on Desktop and silently changes export truth). Archived as
  `archive/2026-05-04-m5-c-ios-feature-parity-audit.md`; new
  `active.md` opens M5-C.1.
- 2026-05-04: M5-C.1 Native Source Profile And Source Gate Parity landed —
  iOS-canonical source profile catalog + math ported to Native Desktop.
  Three new Color/ files (`FilmtoneSourceProfileMath.swift` lift verbatim
  from iOS plus an Apple Log cube builder; `FilmtoneSourceProfileCatalog.swift`
  with the 9 built-in entries — Apple Log / Apple Log 2 / DJI D-Log / D-Log M
  / Canon C-Log / Canon Log 3 + Cinema Gamut / V-Log / S-Log3 / Rec.709 —
  with iOS-identical slugs and englishName; `FilmtoneSourceInputTransform.swift`
  with NSLock-cached cube builder + CIColorCubeWithColorSpace apply +
  source-cap reasoning). One new UI file (`SourceProfileControls.swift`)
  surfaces a Picker on the right rail above GradeControls (same Pass 4
  `.clear.tint(.black.opacity(0.30))` glass + `.colorScheme(.dark)` posture
  for AppKit-bridged label). EditorState gained `sourceProfileSelection`
  (`.auto` default, sticky `.builtIn`) and `probedSourceColorClass`
  (PreviewSurface writes it after probe so the source-cap gate / Auto
  resolution caption stay live). PreviewSurface + Still + Video exporters
  apply the input transform before the grade pipeline; sidecar adds an
  additive `sourceProfile { selection, resolvedId, resolvedName,
  resolvedCurve }` block. Toolbar Export disables with a tooltip reason
  when Auto sees an HDR / wide-gamut source the Desktop pipeline can't
  faithfully render. Build clean (Swift 6, xcodebuild Debug). Auto-path
  byte identity is preserved by design: SDR Rec.709 / Display P3 / unknown
  sources match the catalog Rec.709 entry whose `curve == nil`, so
  `prepareCube(for: nil)` returns nil and `apply` is identity (no
  CIFilter inserted). Visual smoke on a real log source deferred to user
  (no Apple Log fixture in repo). Archive `active.md` once user opens the
  next slice.
- 2026-05-04: M5-C.2a Saved Look Library Foundation And Save Current Look
  landed — looks-only port of iOS `FilmtoneLibrarySchema` /
  `LibraryStoreActor` to Native Desktop (`FilmtoneSavedLookSchema.swift`
  + `FilmtoneSavedLookStore.swift` actor, atomic per-entry writes under
  `~/Library/Application Support/Filmtone/library/looks/`, built-in
  Stone / Urban materialized at read time via new
  `FilmtoneCreativePackCatalog.materializeAsSavedLookEntry` adapter).
  New `LibraryViewModel` (@MainActor @Observable) and
  `LookLibraryControls` UI replace the hardcoded `lookOptions` Picker —
  snapshot-driven Picker with Built-in / Saved sections plus a "Save
  Current Look…" NSAlert prompt. EditorState gains `selectedSavedLookId`
  + `applySavedLook` + `currentLookSavePayload`. `FilmtoneQuickState` /
  `FilmtonePhase0ParamsPatch` widened to Codable + Equatable + Sendable
  on the declaring struct (cross-file extension blocked Swift's Sendable
  same-file requirement). Build clean (Swift 6, xcodebuild Debug). LUT
  library import / quota / orphan GC remain deferred to M5-C.2c (P1);
  favorite / rename / delete UX remains deferred to M5-C.2b. User to
  verify visually: save a Look at strength 0.6, switch away, switch back
  — preview should return to that saved state and survive relaunch.
- 2026-05-04: Release-cutover Phase 4 pre-flight readiness audit pass —
  ASC env 不要範囲 (archive Step 1 + exportArchive Step 2) を本 chat で実行。
  最近 M5 lane で着地した Pass 3 / Pass 4 / scrub bar / F-S6.1-2 toolbar +
  preview Image refactor は Release build path を壊していない。
  `codesign --verify --deep --strict` pass、`flags=0x10000(runtime)` +
  Authority chain (Developer ID Application → Developer ID CA → Apple Root CA)
  + secure timestamp 確認。生成 Info.plist の version=0.1.0 / build=1 /
  category=photography / copyright=© 2026 Takumi Chiba / min-system=26.0
  正常。spctl は notarize 前の expected `Unnotarized Developer ID` reject。
  release-cutover lane の M6-6 は user の `ASC_ISSUER_ID` 設定で
  `scripts/release-macos.sh` を流すだけの状態。Archived as
  `archive/2026-05-04-release-phase-4-preflight-readiness.md`。
- 2026-05-04: M5-C.3a Quick Adjust Parity And Saved-Look Round-Trip
  landed — `FilmtoneQuickState` helpers (`clamped` / `value(forAxis:)` /
  `clampAxis`) ported verbatim from iOS canonical into
  `Domain/Phase0Types.swift`. New `FilmtonePresetCatalog.applyQuickState`
  + 5-arg `resolved(...)` thread `quickState` and `paramOverrides`
  through the existing single resolve site so Preview / StillExporter /
  VideoExporter / SidecarWriter all honor them with no per-consumer
  re-plumbing. EditorState gains `quickState` + `paramOverrides`
  storage; `applySavedLook` / `currentLookSavePayload` /
  `clearSavedLookSelection` complete the saved-Look round-trip (was
  previously dropping both fields). New `QuickAdjustControls.swift` —
  3 signed sliders (Film / Era / Dynamics, [-1,+1], step 0.01) +
  Reset Quick button, Pass 4 dark-tint `.clear` Liquid Glass posture.
  Sidecar `quickState` block now emits live values instead of
  `[0,0,0]`. Build clean (Swift 6, xcodebuild Debug). M5-C.3b advanced
  per-parameter override editing UX remains deferred (storage / apply
  path is already lit up for it). User to verify visually:
  filmCharacter / era / dynamics move preview, save+restore round-trip
  preserves Quick offsets, sidecar carries live quickState.
- 2026-05-04: Release-cutover Phase 5 — M6-6 end-to-end release run pass。
  `ASC_ISSUER_ID` を `apps/capacitor-film-lab-ios/.env.local` から流用
  (iOS Fastfile parity)、`scripts/release-macos.sh` 6/6 step + `scripts/
  package-dmg.sh` 6/6 step 全 pass。`FilmtoneDesktop.app` (notarized +
  stapled、`Notarization Ticket=stapled`) と `FilmtoneDesktop-0.1.0.dmg`
  (notarized + stapled、6.9 MB、Gatekeeper `accepted source=Notarized
  Developer ID`) を `apps/filmtone-desktop-macos/build/release/0.1.0/` に
  着地。M6 release-cutover lane 全タスク Done。残 = `git push` / `git tag
  v0.1.0` / portfolio submodule bump / 配布チャネル決定 — 全て本 chat
  scope 外 (CLAUDE.md §9 user 委任、§7 portfolio bump 手順)。
- 2026-05-04: Release-cutover Phase 6 — Cutover Architecture & Brand
  Alignment landed。user 明示 direction「Native Desktop v2 = iOS 踏襲 +
  Electron 単一置換、並走しない」を auto-mode で本 chat が代理確定し、
  `cutover-architecture.md` (persistent reference doc、decisions A〜K +
  OQ-1〜OQ-4 列挙) を ship。pbxproj Debug+Release 両方を Bundle ID
  `co.fores-tone.filmtone.desktop` → `com.chibatakumi.film-lab-desktop`
  (Electron drop-in upgrade)、PRODUCT_NAME `$(TARGET_NAME)` → `Filmtone`、
  MARKETING_VERSION `0.1.0` → `2.0.0` (later superseded by the iOS-aligned
  `1.4` version policy below) に
  更新。`scripts/release-macos.sh` + `scripts/package-dmg.sh` の APP_NAME /
  BUNDLE_ID を同期。`xcodebuild -scheme FilmtoneDesktop -configuration Debug
  build` → `** BUILD SUCCEEDED **`、生成 `Filmtone.app` Info.plist で
  CFBundleIdentifier=com.chibatakumi.film-lab-desktop /
  CFBundleShortVersionString=2.0.0 / CFBundleName=Filmtone / 全 8 key 期待値
  確認。Phase 6 当時の `2.0.0` artifact plan は本日 user 決定で `1.4`
  に supersede 済み (実 release は M5-C P0 closure 後)。
  Archived as `archive/2026-05-04-release-phase-6-cutover-architecture-brand-alignment.md`。
- 2026-05-04: M5-C.3a verified visually (user confirmed Quick adjust
  Film/Era/Dynamics ripple into preview, saved-Look round-trip restores
  Quick offsets, Reset Quick zeroes axes, sidecar `quickState` block
  carries live values). Standalone swiftc verification harness landed
  at `apps/filmtone-desktop-macos/Verify/run.sh` — 29/29 PASS covers
  preset×strength parity, Quick math, sidecar payload, SavedLookEntry
  Codable round-trip, ordering, Hashable distinctness. Archived as
  `archive/2026-05-04-m5-c3a-quick-adjust-parity-and-saved-look-round-trip.md`.
  M5-C.3 series remaining: M5-C.3b advanced per-parameter override
  editing UX (paramOverrides storage / apply path already lit up).
- 2026-05-04: M4-A Shared Swift Boundary Cut Line closed — boundary matrix
  set (share-now / share-after-cleanup / keep-platform-specific /
  generated-only) and first extraction route confirmed: repo-local Swift
  Package at `packages/film-lab-swift-core`, both Xcode targets consume via
  XCLocalSwiftPackageReference. No code moved (boundary slice only).
  Archived as `archive/2026-05-04-m4-a-shared-swift-boundary-cut-line.md`;
  M4-B Shared Phase0 Core Package opens as the implementation slice. M5-C.4
  Export Inspector remains paused.
- 2026-05-04: M4-B Shared Phase0 Core Package closed — `FilmLabSwiftCore`
  SPM 化完了 (Phase 1 = package skeleton + 27/27 tests、Phase 1.5 =
  emitter `accessLevel` + public API、Phase 2 = Desktop wired + Verify
  module-link、Phase 3 = iOS wired + iOS-only methods を extension 化 +
  generator 1-output 集約)。iOS / Desktop 両方 xcodebuild Debug ✅、
  Verify 36/36 ✅、generator --check ✅。Archived as
  `archive/2026-05-04-m4-b-shared-phase0-core-package.md`、commit `5efb7072`。
  M5-C.4 Export Inspector を `active.md` に復帰。
- 2026-05-04: M5-C.4 Mac-native Export Inspector closed — 4-state surface
  (blocked / progress / finished / ready) を Mac-native idioms で実装:
  Reveal in Finder = `NSWorkspace.activateFileViewerSelecting`、Share =
  `NSSharingServicePicker` button-anchored via NSViewRepresentable bridge、
  pre-export format picker (PNG↔JPEG segmented) + JPEG quality slider
  (clamped 0.5...1.0)、result metric grid (output dims / file size /
  sidecar) + Export Again reset、source-cap amber reason cards。
  Implementation commits `5cea00c6` (initial) + `d4d46cf3` (M4-B 整合
  follow-up) + `d3d2ab6d` (Resume #1 verify tick)。Final gates: Desktop
  xcodebuild Debug ✅、Verify/run.sh 36/36 ✅。Visual runtime smoke は
  user-driven sanity に deferred、code-level wiring inspection で 8 Done
  条件 (xcodebuild / Inspector mount / format toggle / NSSavePanel /
  progress + Cancel / finished metrics / Reveal / Share / Export Again /
  blocked / Verify) すべて satisfied 確認済み。Archived as
  `archive/2026-05-04-m5-c4-export-inspector.md`。M5-C P0 (C.2a + C.3a +
  C.4) ここで closure → release-cutover lane 1.4 公開 gate は残り
  user-driven notarize submission のみ。

## Interrupt / Decision Log

- 2026-05-04: **Native Desktop v2 = Electron Desktop の単一置換後継** に
  direction 確定 (user 明示)。Goal / Measurable Done Conditions / Constraints
  / M6 milestone 行を本日 update、parallel-lane 前提を削除。詳細決定は
  `../release-cutover/cutover-architecture.md` (decisions A〜K)、未決定は
  Open Questions OQ-1〜OQ-4 (本質に直接影響しない、後続 user 判断)。
  Memory 永続化: `~/.claude/projects/-Volumes-.../memory/project_native_v2_replaces_electron.md`。

- 2026-05-04: **Native Desktop v2 release version = `1.4`** に correction
  (user 明示)。理由: Native Desktop v2 は iOS canonical の Mac 版なので iOS public/local
  version `1.4` と揃える。Electron public latest `1.0.4` より semver 上は高いため
  existing update path は維持。current pbxproj `MARKETING_VERSION = 1.4`、release
  artifact は `Filmtone-1.4.dmg`。

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
