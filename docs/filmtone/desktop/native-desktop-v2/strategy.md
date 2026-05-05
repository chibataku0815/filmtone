# Filmtone Native Desktop v2 Strategy

Date opened: 2026-05-04 JST
Last updated: 2026-05-05 JST

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
| M5 | Native Editing UI | M3 | Validation / thin fixes | Core Desktop workflows are usable in native UI: look selection, preview navigation, export controls, progress/cancel, Finder integration, App chrome/layout, Adjust/Library parity, and playback MVP. Apple Liquid Glass is applied systematically to control surfaces, preview content layer excluded. Final v1.4 product gate is user visual smoke plus D.2.0a / H.3-C1 go/no-go. |
| M6 | Release Cutover | M5 | In progress | release-cutover lane proved signing / notarize / stapled DMG pipeline and cutover identity. Version policy is iOS-aligned 1.4: Bundle ID `com.chibatakumi.film-lab-desktop` / Product Name `Filmtone` / MARKETING_VERSION `1.4`. After M5 validation freezes, regenerate the actual 1.4 artifact, notarize/staple it, and publish through the fixed Desktop update/download rail. Details: `../release-cutover/cutover-architecture.md`. |

## Current Strategic State

- M1 and M2 are complete.
- M3 remains open for known parity hardening gaps, but its source-color
  foundation, modern AVFoundation migration, RayAngleOptics, initial optical
  stages, and 4K performance measurement are complete enough to unblock M5.
- M5 is in v1.4 release-candidate validation. M5-C P0 is closed, the
  user-reported 5-gap surface has implementation coverage, and M5-H / D2
  fanout has been integrated. No `active.md` is currently open. The next
  implementation `active.md` should be only one of:
  - v1.4 visual-smoke defects from H1 chrome/layout, H2 Adjust/Library,
    D2 playback, Saved Look favorite/delete, and export/share;
  - M5-D.2.0a preview downscale + probe/asset cache if playback smoke shows
    unacceptable stutter;
  - M5-H.3 C1 creative LUT intensity wiring if the diff stays a thin
    correctness fix;
  - release-cutover 1.4 artifact regeneration / notarize after product scope
    freezes.
- M5-A.2 Look Canonical Parity (Stone / Urban Creative LUT Pack 01 port from
  iOS) landed 2026-05-04 across 3 commits and is archived.
- M5-A.3 Video Preview Scrub landed 2026-05-04 (single commit 3b12805,
  preview-only, no CLI / export regression — Stone hash byte-identical to
  M5-A.2 archive record). Visual scrub UX smoke deferred to user. Archived
  immediately to make room for the user-requested M5-B interrupt slice.
- M5-B Apple Liquid Glass adoption is closed across Pass 1 / 2 / 3 / 4 +
  F-cycle. Right-rail panels, scrub bar, inline export buttons, and window
  chrome now use the macOS 26 glass posture proven in user smoke; preview
  content remains glass-free for color judgment.
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
  + C.3a parity + C.4 inspector) すべて closed。Later user smoke opened
  the M5-E / D / F / C.3b / H follow-ups below, so the current 1.4 gate is
  visual smoke + D.2.0a / H.3-C1 go/no-go + release-cutover 1.4 artifact
  regeneration / notarize.
- 2026-05-04 user smoke で 5 個の追加ギャップ判明 → 推奨順で計画化:
  - **M5-E.1 App Icon Asset Population** (Tier A, ~20 min) — **closed
    2026-05-05**。詳細は Completion Log を参照。
  - **M5-D.1 Video Scrub Bar Visibility** (Tier A, ~15 min) — **closed
    2026-05-05**。詳細は Completion Log を参照。当初 scope (`.glassEffect`
    未適用 + bottom-anchored 不足) は M5-B Pass 1 / Pass 4 で既に landed
    済みだったため、実際の visibility 問題 (右レール `.clear.tint` と素
    `.clear` の posture 不一致) に再 scope して closure。
  - **M5-F.1 Inline Button Glass Posture Pass** (Tier B, ~30 min) — **closed
    2026-05-05**。詳細は Completion Log を参照。Apple canonical macOS 26
    `.buttonStyle(.glassProminent)` / `.glass` で 4 button (Export primary /
    Cancel / Reveal / Export Again) を統一。当初 ~1-2h 推定だったが Apple
    canonical 1 行解決で 30 分に短縮。
  - **M5-D.2 Native Video Playback** (Tier B, ~50 min) — **closed
    2026-05-05** (MVP path)。詳細は Completion Log を参照。strategy 旧 gate
    (raw decode vs decode+grade の user 判断) は前提が変わったため bypass:
    既存 scrub-driven preview pipeline (in-flight Task cancellation で
    frame-drop を natural に出す) で Timer driven `videoPreviewSeconds`
    増分の MVP が成立。AVPlayer migration は perf 不足が visual smoke で
    判明した場合の follow-up slice (M5-D.2.1 候補)。
    **Correction (2026-05-05、M5-D.2 spike で判明)**: 当初本行で
    `previewMaxLong scaled` と書いていたが、Desktop には preview scale
    symbol が存在せず、source 解像度のまま grade pipeline を流していた。
    M5-D.2.0a (v1.4 hot-fix candidate) で probe / asset cache + 1280
    long-side downscale、M5-D.2.1 (v1.5) で AVPlayer Primary route 着地予定。
  - **M5-D.2.0a Preview Downscale + Probe/Asset Cache** (Tier B hot-fix
    candidate, ~半日) — **registered 2026-05-05、v1.4 候補 (採否は visual
    smoke 判定)**。spike 推奨 Alt A: AVAsset 単一 instance 共有 + probe 結果
    cache + `composition.renderSize` を long-side 1280 に固定。drift /
    audio absent は残置 (architecture 起因、Primary route で解消)。Primary
    route まで待てるなら hold して v1.5 一括着地でも可。詳細:
    `archive/2026-05-05-m5-d2-avplayer-playback-spike.md` §「v1.4 / v1.5
    への載せ方」。
  - **M5-D.2.1 AVPlayer Preview Route (iOS-canonical port)** (Tier B
    Primary, 5 step 想定) — **registered 2026-05-05、v1.5 lane**。AVPlayer
    + AVMutableVideoComposition + `applyingCIFiltersWithHandler` で
    iOS canonical preview architecture に揃える。grade pipeline 本体は
    app-local 並走、playback 出力の still / export parity を Verify で
    pin。Audio + 速度切替 + compare mode が同時に lit up する。詳細:
    spike doc §「Primary route 推奨」+ §「v1.4 / v1.5 への載せ方」。
  - **M5-C.3b Advanced Per-Parameter Override Editing UX** (Tier C, ~半日):
    **closed 2026-05-05**。詳細は Completion Log を参照。Option B (popover)
    採用。iOS catalog mirror + clamp + per-key reset + Reset All で 30 + 2
    field を直接編集可能化。catalog data は責務分離のため `Domain/`
    AdvancedAdjustCatalog、editing helpers は `EditorState+ParamOverrides`
    extension に切り出し。これで当時の 5-gap 5/5 は実装 close。現在の
    v1.4 gate は後続 H/D2 checkpoint の visual smoke + thin-fix go/no-go。
- 2026-05-05 multi-agent review が M5-C.3b 着地後の architecture / coverage
  gap を 4 件 (P2 × 3 + P3 × 1) 指摘 → **M5-G Architecture Thin Cuts** 2 slice
  で着地済 (commits `a68d5884` + `c0a12463`):
  - **M5-G.1 ExportCoordinator extraction + SaveLookPayload lift** —
    `RootWindowView` から ~150 行の export user flow を `State/
    ExportCoordinator.swift` (`@MainActor final class`) に切り出し、root
    view は panel composition + toolbar wiring に縮小。`SaveLookPayload`
    を `EditorState` nested struct から `State/SaveLookPayload.swift` の
    top-level struct に lift、`LibraryViewModel.saveCurrentLook` は
    `(name:payload:)` に変更で library feature が EditorState 全体に依存
    しなくなる。Build PASS / Verify 36/36 ✅。
  - **M5-G.2 AdvancedAdjustCatalog parity in Verify** — `Domain/
    AdvancedAdjustCatalog.swift` を Verify SOURCES に追加、Test group 9
    (6 tests: 構成 / video filter / Phase0 keyPaths parity / 範囲 clamp 各
    branch / shutterAngle iOS-canonical 不連続 / default identity) で
    M5-C.3b の silent regression を防止。Verify 36 → 42 ✅。
  - 残 follow-up (本 lane 範囲外、必要時に別 slice): export state field
    (`isExporting` / `lastExportResult` 等) を ExportCoordinator に促進
    する Phase 2、`FilmtonePhase0Math.clampParam` を film-lab-swift-core
    に promote する Phase 3 (iOS canonical surface 触るので別 review)。
- 2026-05-05: **M5-I.1 Localization / Copy Parity closed** (worktree
  `filmtone-native-desktop-m5-i1-localization`)。`Domain/FilmtoneDesktopStrings.swift`
  新規 (EN/JA struct + `.current` Locale 解決)、`AdvancedAdjustCatalog` /
  `AdvancedAdjustEditor` から hard-coded EN を全廃、JA host で iOS canonical
  階調 / なし / 標準 / 強め / 爽やか / 夕景 / 深み / シャッターアングル /
  残像の長さ が surface する。Verify 56 → 65 PASS (新 9 tests: EN/JA group /
  preset / tone recipe / paramLabel / affordance copy + JA catalog 経路 2)、
  xcodebuild Debug ✅。Archive: `archive/2026-05-05-m5-i1-localization-copy-parity.md`。
- 2026-05-05 M5-H / D2 integration checkpoint: H1 App Chrome / Preview
  Layout, H2 Adjust + Library iOS canonical parity, H3 Dual LUT design
  spike, and D2 AVPlayer playback spike are integrated on the native plan
  branch. Current Verify is 56/56. H3 C1 (creative LUT intensity wiring) is
  v1.4-preferred only if it remains a tiny correctness fix; full Dual LUT
  (`InputLutBinding` + UI + sidecar dual block) is v1.5. D2.0a is a v1.4
  hot-fix candidate only if user smoke proves the timer-driven playback MVP
  is not acceptable.
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
  `docs/filmtone/desktop/release-cutover/` as a separate work scope from this
  lane. Phase 1 closed 2026-05-04: M3 LOW gap `printContrast` sign-gate
  fixed, M6 signing posture wired (Hardened Runtime + Developer ID + entitlements
  + secure timestamp), `scripts/release-macos.sh` + `scripts/package-dmg.sh` +
  `ExportOptions.plist` shipped, archive + exportArchive verified against the
  real Developer ID Application identity (Team C3G77H8NM6, universal binary,
  notarize-ready). The pipeline has already produced notarized/stapled
  artifacts in earlier release-cutover phases, but the real public artifact
  must be regenerated after v1.4 product scope freezes. Keep release-cutover
  dirty/script work separate from native M5 validation unless that lane owner
  explicitly merges it.

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
  download URL on cutover (gated on v1.4 visual smoke, thin-fix decisions, and
  release-cutover artifact regeneration).
- Sidecar changes are additive only; avoid schema bumps until a product need
  requires one.
- Generated Swift must not be hand-edited.
- Use `bun` for repository commands.
- Keep `packages/film-lab-renderer/dist/` and `packages/film-lab-smart-look/dist/`
  tracked.

## Open Questions

- Does baseline-C need to be populated now, or only when formal QA is requested?
- Should deprecated Core Image kernel construction be migrated to Metal CIKernel
  before release cutover or tracked as a post-parity hardening task?
- Does M5-D.2.0a need to land in v1.4, or is timer-driven playback acceptable
  for the first native cutover after visual smoke?
- Should M5-H.3 C1 creative LUT intensity wiring land before v1.4 notarize, or
  move with the full Dual LUT surface to v1.5?
- What is the minimum user visual-smoke set that freezes v1.4 product scope?
- What exact release-cutover metadata and fixed-download update payload should
  ship with the regenerated 1.4 notarized DMG?
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

- 2026-05-05: **M5-J3 Slider Visual Polish v2 closed** (worktree
  `filmtone-native-desktop-m5-j3-slider-polish-v2`、base `ca9acea6`)。
  `FilmtoneGlassSlider` を 1 file in-place 改修 — knob 32→18pt
  (hover/drag 22pt)、track 8→5pt、unfilled `Color.white.opacity(0.12)`、
  filled `Color.white.opacity(0.45)` glass highlight、knob radius 補償の
  edge-of-track 算出、`@Environment(\.isEnabled)` で disabled dim、
  `onChange(of: isEnabled)` で drag 中 disabled flip 時 latch を防止。
  `range:` / `step:` / `onEditingChanged:` API、cursor、`onDisappear`
  cleanup は維持。5 call site 触らず。Verify 65/65 ✅、
  `bun run verify:macos` Debug ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-j3-slider-polish-v2.md`。
- 2026-05-05: **M5-I integration branch closed**。I1 localization, I2
  AVPlayer preview route, I4a preview/background, parent glass control polish,
  and parent 1.4 release-cutover / AGENTS dirty state were integrated as
  separated commits on `feature/native-desktop-m5-i-integration`. Verify 65/65
  ✅、`bun run verify:macos` Debug build ✅、`git diff --check` clean。
- 2026-05-05: **M5-I.3 Control Spacing And Slider Polish closed**。Right rail
  panel gap / padding を 8px grid ベース (16/24) に整理、Source / Look の
  large nested card background を削除して value chip のみを select affordance
  に残した。Native SwiftUI Slider は right rail / adjust popover / scrub bar
  で `FilmtoneGlassSlider` に置換し、下部の不要線を除去。`bun run
  verify:macos` ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i3-control-spacing-and-slider-polish.md`。
- 2026-05-05: **M5-I.2 Glass Control Visual Correction closed**。M5-I.1 の
  reference 解釈を修正し、黒テーマではなく既存 Liquid Glass 上の shine /
  inner highlight のみに寄せた。Source / Look trigger は左ラベル + 発光
  value chip の custom capsule に変更。stale duplicate Debug process を
  kill して current build を relaunch。`bun run verify:macos` ✅、
  `git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i2-glass-control-visual-correction.md`。
- 2026-05-05: **M5-I.1 UI/UX Glass Control Pass closed**。Source / Look /
  Export Format を default Picker から full-width glass menu / segment control
  に置換し、primary / secondary / icon button hierarchy + enabled-only
  pointing-hand cursor helper を追加。Preview content layer は未変更。
  `bun run verify:macos` ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i1-ui-ux-glass-control-pass.md`。
- 2026-05-05: **M5-G Architecture Thin Cuts closed** (commits `a68d5884`
  + `c0a12463`)。Post-M5-C.3b multi-agent review が 4 件 (P2 RootWindowView
  export orchestration / P2 AdvancedAdjustCatalog + EditorState+
  ParamOverrides の Verify 未カバレッジ / P2 catalog の iOS canonical 重複 /
  P3 LibraryViewModel が EditorState 全体に依存) を指摘 → 2 slice で着地。
  **M5-G.1**: `State/ExportCoordinator.swift` 新規 (`@MainActor final
  class`、`presentExportPanel(for:)` + 内部 still / video panel methods、
  `EditorState` に対しては stateless)、RootWindowView から 3 つの
  presentExportPanel / presentStillExportPanel / presentVideoExportPanel
  関数を削除し toolbar Export button + `ExportInspectorPanel.onExportTap`
  の 2 call site が `exportCoordinator.presentExportPanel(for: state)` に
  delegate。`SaveLookPayload` を `EditorState` nested から `State/
  SaveLookPayload.swift` の top-level struct に lift、`LibraryViewModel.
  saveCurrentLook` を `(name:payload:)` に変更、`LookLibraryControls` は
  `state.currentLookSavePayload()` を渡す形に。pbxproj A35/B34 (Export
  Coordinator) + A36/B35 (SaveLookPayload) を State group + Sources phase
  に登録。Build (xcodebuild Debug) PASS、Verify 36/36 ✅、Swift 6 strict
  clean、警告なし。**M5-G.2**: `Verify/main.swift` に Test group 9 を追加 —
  (a) `allGroups` 6 groups × 31 controls + key collision 防止、(b) video-
  only filter (still mode = 29、video mode = 31、motion 2 が still で
  非露出)、(c) catalog keys ⊂ `FilmtonePhase0Params.keyPaths` (31 全 key
  が Phase0 surface に解決することを初めて pin)、(d) per-key clamp 範囲
  (各 distinct branch: ±2 exposure / 0...2 contrast / ±1 temperature /
  0...40 halationSpread / 0...100 halationHue / 0...0.95 trailIntensity /
  rgbShift / grainIntensity が `FilmtonePhase0Generated.*Max` に bind /
  汎用 0...1)、(e) shutterAngle の iOS-canonical 不連続 (`<90` → 0、
  `90..<180` → 180、180...720 線形、>720 → 720)、(f) default branch =
  identity passthrough。`Verify/run.sh` SOURCES に `Domain/Advanced
  AdjustCatalog.swift` 追加。Verify 36 → 42 ✅。`FilmtonePhase0Math.
  clampParam` は film-lab-swift-core に未昇格 (現状 iOS app 内専用) のため
  catalog clamp の delegate 化はせず、Desktop 側 surface の自己 pin で着地。
  shared package promotion は別 lane (M4-B Phase 3 候補) で扱う。
  out-of-scope: export state field (`isExporting` / `lastExportResult`
  等) を ExportCoordinator に migrate する Phase 2 (ExportInspectorPanel
  bind 全部触るので別 slice 推奨)、OpenCoordinator 抽出 (1 関数 / call
  site も 1 つで thin cut の justification なし)。Archived as
  `archive/2026-05-05-m5-g-architecture-thin-cuts.md`。
- 2026-05-05: **M5-C.3b Advanced Per-Parameter Override Editing UX (Desktop)
  closed**。Option B (popover) 採用で着手 — auto-mode、user 直接 review なし
  (standing directive: 本質優先 / 保守的に hedge しない / commit agent 委譲)。
  実装内容: (1) `Domain/AdvancedAdjustCatalog.swift` 新規 — iOS canonical
  `FilmtoneStrengthSheetData.advancedParamGroups` の port (basic 6 / process 6
  / optics 3 / glow 11 / grain 3 / motion 2 video-only = 31 field)、`clamp`
  関数は iOS `FilmtonePhase0Math.clampParam` のミラー (shutterAngle の 90 未満
  → 0 / 90..<180 → 180 snap も含む)。(2) `State/EditorState+ParamOverrides.swift`
  新規 — `effectiveParamValue(for:)` / `isParamOverridden(_:)` /
  `setParamOverride(_:for:)` / `clearParamOverride(for:)` /
  `clearAllParamOverrides()` / `paramOverridesActiveCount` /
  `paramOverridesAvailableCount`。EditorState 本体の god object 化を緩和する
  ため extension file に分離。(3) `UI/AdvancedAdjustEditor.swift` 新規 —
  Popover content (480×600pt 固定)。Header (title + N/M active badge + close
  button) / Scrollable DisclosureGroup × 6 (basic デフォルト展開、各 group は
  active count chip 付き) / Footer (Reset All Overrides button)。各 row は
  active dot + label + value + per-row reset button + Slider。(4)
  `UI/QuickAdjustControls.swift` 改修 — 末尾に `.buttonStyle(.glass)` の
  "Adjust…" button + override count chip (active 時のみ表示) を追加、
  `.popover(arrowEdge: .trailing)` で AdvancedAdjustEditor anchor。(5)
  `FilmtoneDesktop.xcodeproj` 4 file 登録 (catalog は Domain group、editor は
  UI group、extension は State group、build IDs A32/A33/A34 + file refs
  B31/B32/B33)。**責務分離の course correction**: 着手中に user から
  「責務分離と feature アーキテクチャ意識して作ってますか」と問われ、最初
  catalog を `UI/`、helpers を EditorState 本体に直入れしていたのを honest
  に認め、build 前に catalog を `Domain/` 移動 + helpers を extension file 化
  へ refactor。これで pure data + clamp = Domain 層、SwiftUI View = UI 層、
  EditorState 本体 = source/preset/look/quick/export/playback、override 編集
  helpers = extension file、と層が分離。Build clean (Swift 6 strict, xcodebuild
  Debug PASS, 警告なし)。Archived as
  `archive/2026-05-05-m5-c3b-advanced-adjust-editor.md`。**当時の 5-gap
  implementation は close**: E.1 / D.1 / F.1 / D.2 / C.3b 全完了。現在は
  M5-H / D2 checkpoint 後の visual smoke + thin-fix go/no-go が v1.4 gate。
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
  に supersede 済み (実 release は v1.4 visual smoke + thin-fix decisions 後)。
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
  C.4) はここで closure。Later user smoke で追加 H/D2 follow-up が開いた
  ため、現在の 1.4 公開 gate は visual smoke + thin-fix decisions + regenerated
  1.4 notarized artifact。
- 2026-05-05: M5-E.1 App Icon Asset Population closed — iOS canonical
  `AppIcon-512@2x.png` (1024×1024) を source に `sips -z` で 10 size
  生成 (16/32/128/256/512 × 1x/2x、計 10 PNG)、`AppIcon.appiconset/
  Contents.json` に `filename` keys 補完。Desktop xcodebuild Debug ✅、
  `Filmtone.app/Contents/Resources/AppIcon.icns` 99k 生成確認、image-
  resource warning なし。Tier A 5-gap 1 件目 closure。Visual smoke
  (Dock / Finder / About box の icon 表示) は user-driven。Archived as
  `archive/2026-05-04-m5-e1-app-icon.md`、commit `758ada3a`。
- 2026-05-05: M5-D.1 Video Scrub Bar Visibility closed — 着手時に当初
  scope (`.glassEffect` 未適用 + bottom-anchored capsule wrap なし) が
  M5-B Pass 1 / Pass 4 で既に landed 済みであることが判明。実際の
  visibility 問題は scrub bar capsule の素 `.clear` posture が右レール
  panel 5 個 (`SourceProfile` / `LookLibrary` / `QuickAdjust` / `Grade` /
  `ExportInspector`) の `.clear.tint(.black.opacity(0.30))` posture と
  不整合 → 明るい preview 上で消失する点。Re-scope して capsule posture
  を `.clear.tint(.black.opacity(0.30))` に統一 (`RootWindowView.swift:112-117`、
  inline comment 追加)。Desktop xcodebuild Debug ✅、Swift 6 strict
  concurrency warning なし。Tier A 5-gap 2 件目 closure。Visual smoke
  (bright / dark preview 両方で scrub bar が一目でわかる) は user-driven。
  Archived as `archive/2026-05-05-m5-d1-scrub-bar-visibility.md`。
- 2026-05-05: M5-F.1 Inline Button Glass Posture Pass (Pass 5) closed —
  ExportInspectorPanel の 4 button posture を Apple canonical macOS 26
  Liquid Glass family に統一: primary Export Video/Still
  `.buttonStyle(.borderedProminent)` → `.glassProminent`、secondary
  Cancel / Reveal / Export Again → `.buttonStyle(.glass)` 追加。`.glassProminent`
  / `.glass` は macOS 26 SwiftUI SDK 既定 (xcodebuild compile で SDK
  存在検証 → custom `.glassEffect` modifier wrapping fallback 不要)。
  Smoke screenshot で名指しされた system blue solid box が dark glass
  chrome から消失。Desktop xcodebuild Debug ✅、Swift 6 strict
  concurrency warning なし。Tier B 5-gap 1 件目 closure (~30 分、当初
  ~1-2h 見積より大幅短縮)。Out of scope: NSButton AppKit Share bridge
  (anchor 制御保持のため)、LookLibrary `.borderless` (smoke 不満なし)、
  QuickAdjust default (same)、toolbar buttons (macOS 26 HIG default)。
  Visual smoke (4 button が dark glass container と調和) は user-driven。
  Archived as `archive/2026-05-05-m5-f1-inline-button-glass-pass.md`。
- 2026-05-05: M5-D.2 Native Video Playback (MVP) closed — Timer-driven
  `videoPreviewSeconds` 24 fps 増分で再生機能を最小実装。EditorState に
  `isPlaying` / `playbackTask` + `togglePlayback()` / `startPlayback()` /
  `stopPlayback()` (`@MainActor` Task ループ、`[weak self]` で self-rebind
  pattern)、`setSource(_:)` で `stopPlayback()` hook。VideoScrubBar に
  `play.fill` / `pause.fill` SF Symbol button (`.buttonStyle(.glass)` +
  `.keyboardShortcut(.space)` + `.help`)、Slider に `onEditingChanged` で
  drag → auto-pause。AVPlayer + AVPlayerItemVideoOutput 移行は perf
  不足の証拠なしで先取り回避 (overengineering 判定)、follow-up slice
  M5-D.2.1 候補として deferred。strategy 旧 gate (raw decode vs
  decode+grade の user 判断) は前提が変わったため bypass: 既存 scrub-driven
  pipeline が既に decode+grade で frame-drop を natural に出すので
  user 判断不要。Desktop xcodebuild Debug ✅ (1 round trip 後の self-bind
  訂正含む)、Swift 6 strict concurrency warning なし、pre-existing
  CIKernel deprecation warnings は無関係。Tier B 5-gap 2 件目 closure。
  Visual smoke (短い 1080p video で graded playback、Space-key、scrub
  drag → auto-pause) は user-driven。Archived as
  `archive/2026-05-05-m5-d2-native-video-playback.md`。
- 2026-05-05: **M5-H fanout integrated** (worker → coordinator merge)。
  M5-H.1 App Chrome / Preview Layout (3 commits: 0251b585 + d12f1318 +
  9dd0c2c2、cherry-pick 6ea6fbe9..c9195010) — RootWindowView 4-region
  chrome + PreviewSurface backdrop / cached frame source-identity gating。
  M5-H.2 Adjust + Library iOS canonical parity (3 commits: a4c471b9 +
  072b0c07 + 86da5b23、cherry-pick 77d2998c..a1ed95f9 + 5bb99e58) —
  AdvancedAdjustCatalog full iOS parity、SavedLookStore built-in
  favorite + resolve order、LookLibraryControls UI、P1 で resolve-order
  test を host 非依存にする determinism fix(quickWeights dict iteration
  順 → sorted、clamp 損失しない key を選択)、Verify 42 → 56 PASS。M5-H.3 Dual LUT + intensity
  slider spike (3 doc-only commits: 985ccfd9 + fdd1a9d7 + 793226c3、
  cherry-pick e20ec45a..699b1b4f) — read-only design spike、実装は次 slice
  (C1 v1.4-preferred thin fix / C2-C3 v1.5) で worker 配賦。M5-H.4 は
  worktree / spike doc 不在のため今回統合スコープ外。Desktop xcodebuild
  Debug ✅、Verify 56/56 ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-h1-chrome-preview-layout.md` /
  `archive/2026-05-05-m5-h2-adjust-library-parity.md` /
  `archive/2026-05-05-m5-h3-dual-lut-spike.md`。
- 2026-05-05: **M5-I.2 AVPlayer Preview Route landed** — promoted from
  v1.5 lane to current blocker after user reported continued stutter on
  the M5-D.2 timer-driven MVP. Added `Media/FilmtoneDesktopVideoSession.swift`
  (@MainActor; owns one AVPlayer + graded AVPlayerItem; periodic 30Hz
  time observer drives `videoPreviewSeconds`; debounced 100ms composition
  refresh + same-time re-seek; play / pause / seek / 1×–4× rate API),
  `Media/FilmtoneDesktopVideoComposition.swift` (factory builds
  `AVMutableVideoComposition.applyingCIFiltersWithHandler` running
  `FilmtoneSourceInputTransform` + `FilmtoneGradePipeline` at
  1280-long-edge `renderSize`, honoring track `preferredTransform` so
  vertical iPhone footage stays vertical), and `UI/FilmtoneDesktopPlayerView.swift`
  (`NSViewRepresentable` over `AVPlayerView` with `controlsStyle = .none`
  / `videoGravity = .resizeAspect`). EditorState dropped the 24fps
  `playbackTask` ticker entirely and now delegates `togglePlayback` /
  `seekVideo` / `setPlaybackRate` to the session; `setSource(.video)`
  spins up the session asynchronously and writes `probedSourceColorClass`
  from the session probe (no longer per-frame in `PreviewSurface`).
  `PreviewSurface` branches to the player view when the session lands;
  the still path is unchanged. `RootWindowView`'s `VideoScrubBar`
  drives `player.seek(to:)` directly and gains a 1×/2×/3× rate menu;
  param changes flow through one `VideoCompositionRefreshKey`-driven
  `.onChange` (the chain of 7 individual `.onChange` modifiers tripped
  the SwiftUI body type-checker). Audio works because AVPlayer routes
  it natively. Build (`bun run verify:macos`) PASS, Verify 56/56 ✅,
  `git diff --check` clean. Two macOS 26.0 deprecation **warnings** on
  the synchronous `AVMutableVideoComposition` initializer remain — the
  async `AVVideoComposition.videoComposition(with:applyingCIFilters
  WithHandler:)` migration is a follow-up slice (M5-I.3 candidate).
  Visual smoke (1080p / 4K iPhone footage smooth playback + audio +
  rate menu + scrub-during-playback + edit-while-playing) is
  user-driven. Archived as
  `archive/2026-05-05-m5-i2-avplayer-preview-route.md`.
- 2026-05-05: **M5-D.2 AVPlayer playback spike** integrated (3 doc-only
  commits: ec89bfc3 + abcfd4f5 + 4e6ff041、cherry-pick efca41a7..86ab8436)。
  M5-D.2 MVP の Timer-driven 再生で frame-drop が natural に出る前提を
  C1〜C7 7 軸で精査、AVPlayer + AVMutableVideoComposition Primary route と
  Alt A〜D 代替案を列挙、Performance risk を route × severity で表化。
  副産物として **MVP archive + strategy 旧記述の factual error** を spike
  worker grep で特定 — `previewMaxLong` symbol は Desktop に存在せず source
  解像度のまま decode + grade していた事実を訂正(strategy.md L114 + archive
  `2026-05-05-m5-d2-native-video-playback.md` L31)。Coordinator 側で 2 follow-up
  lane を Current Strategic State に登録: **M5-D.2.0a** (v1.4 hot-fix candidate、
  probe / asset cache + 1280 long-side downscale、採否 visual smoke 判定)
  + **M5-D.2.1** (v1.5 Primary route、iOS canonical AVPlayer port)。実装ゼロ /
  pbxproj 不変 / Verify 不変。Archived as
  `archive/2026-05-05-m5-d2-avplayer-playback-spike.md`。
- 2026-05-05: **M5-I.4a Preview Background / Liquid Glass Treatment** closed.
  Empty state now uses a branded Liquid Glass open CTA; loaded media letterbox /
  pillarbox uses a neutral dark frosted matte instead of pure black while preview
  content remains `.scaledToFit()` and glass-free. Desktop xcodebuild Debug ✅、
  Verify 56/56 ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i4a-preview-background-liquid-glass.md`。
- 2026-05-05: **M5-I.4a clear opening follow-up** closed after user visual
  smoke. Opening posture changed from dark gradient + gray slab to a full-window
  clear Liquid Glass field with a transparent glass CTA; loaded preview behavior
  unchanged. Desktop xcodebuild Debug ✅、Verify 56/56 ✅、`git diff --check`
  clean。Archived as
  `archive/2026-05-05-m5-i4a-clear-opening-glass-follow-up.md`。
- 2026-05-05: **M5-I.4a QuickTime-style aspect-fit window follow-up** closed.
  Opening a still / video now probes display size and resizes the macOS content
  window toward source aspect ratio within screen bounds, with relaxed dynamic
  content minimums + `contentAspectRatio`; preview remains `.scaledToFit()`.
  Desktop xcodebuild Debug ✅、Verify 56/56 ✅、`git diff --check` clean。
  Archived as `archive/2026-05-05-m5-i4a-quicktime-aspect-fit-window.md`。
- 2026-05-05: **M5-I.4a opening true transparency follow-up** closed.
  Opening now makes the hosting `NSWindow` non-opaque with a clear backing
  color, and the empty backdrop fill was reduced so Liquid Glass can actually
  reveal content behind the Filmtone window. Loaded preview behavior unchanged.
  Desktop xcodebuild Debug ✅、Verify 56/56 ✅、`git diff --check` clean。
  Archived as `archive/2026-05-05-m5-i4a-opening-true-transparency.md`。
- 2026-05-05: **M5-I.4a titlebar brand cleanup** closed. Removed the custom
  navigation app icon and hid the AppKit titlebar title so the clear opening
  surface is not duplicated by a top-left `Filmtone` wordmark; Open / Export
  toolbar actions remain. Desktop xcodebuild Debug ✅、Verify 56/56 ✅、
  `git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i4a-titlebar-brand-cleanup.md`。
- 2026-05-05: **M5-I.4a preview-area aspect correction** closed after visual
  smoke still showed side matte. Resize math now measures / infers top toolbar
  safe-area and fits the actual preview body to source aspect before adding
  chrome height back to the window content size. Desktop xcodebuild Debug ✅、
  Verify 56/56 ✅、`git diff --check` clean。Archived as
  `archive/2026-05-05-m5-i4a-preview-area-aspect-fit.md`。
- 2026-05-05: **M5-I.4a full-size preview chrome** closed after visual smoke
  showed the macOS titlebar still consuming top preview space. Hosting window
  now uses `.fullSizeContentView`, clears / hides title, and treats top chrome
  allowance as zero for aspect-fit resize; Open / Export toolbar actions remain.
  Desktop xcodebuild Debug ✅、Verify 56/56 ✅、`git diff --check` clean。
  Archived as `archive/2026-05-05-m5-i4a-full-size-preview-chrome.md`。

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
