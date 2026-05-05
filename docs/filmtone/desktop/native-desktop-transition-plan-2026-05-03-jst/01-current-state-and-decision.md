# 01 Current State And Decision

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Status (2026-05-04 JST 更新)

- **Phase 0 (Contract & Skeleton): COMPLETE** (commit `398743c`、同日)。8 件の
  acceptance gate 全 pass。macOS native app は macOS 26.4.1 / Xcode 26.4.1 で起動。
- **Phase 1a (Open + Preview precondition): COMPLETE** (commit `398743c`、同日)。
  Decision A 採択 — `Domain/Phase0Types.swift` (4 struct memberwise stub) で
  `SharedGenerated/FilmtonePhase0Generated.swift` を Compile Sources 取込、
  `RootWindowView` に `NSOpenPanel` (`⌘O`) + `PreviewSurface` (NSImageView 経由)
  配線。grade なし生表示。
- **Phase 1b (Vertical Slice — still): COMPLETE** (uncommitted、同日)。preset
  選択 4 個 (reset / iphone / softBlue / amberGlow) + iOS verbatim lift の
  CIColorKernel chain (baseGradeV2 / filmCompressionV2 / printStage) + still
  export (PNG/JPEG `CGImageDestination`) + sidecar JSON (Case B Look canonical
  only) + parity ハーネス (`scripts/golden-parity-macos.ts`)。macOS↔source =
  **∞dB (10/10 bit-identical for reset)**, macOS↔baseline-B = 13.69 dB
  (informational、fixture mismatch — 06-quality-gates-risks.md)。
- **Phase 1c (Vertical Slice — video): COMPLETE** (uncommitted、同日)。.mp4/.mov
  open + midpoint frame preview + AVAssetReader → CIImage → grade →
  CIContext.render(to:CVPixelBuffer) → AVAssetWriter (H.264 + AVVideoProfileLevelH264HighAutoLevel
  + Rec.709 metadata) → sidecar JSON (`sourceKind:"video"` additive、Case B 継続) +
  進捗 UI (SwiftUI ProgressView + Cancel) + CLI `--export-video` mode。`Color/
  FilmtoneColorPipelineContract.swift` を iOS から struct lift (factory は Phase 2)。
  iOS `FilmtoneExportSession.swift` の UIKit dep は telemetry 2 行のみ (line 6,
  409-410) と確認、c1 削減方針で video core flow + color metadata helper のみ
  港。output mp4 は color_space/transfer/primaries=bt709。iphone vs reset
  frame 0 PSNR 14.91 dB が grade chain active を proof。
- `bun run verify:macos` BUILD SUCCEEDED、iOS lane / Electron lane / film-lab-core
  無傷、generator dual-target bit-identical 維持。
- Phase 0 完成記録:
  `docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
- Phase 1a 完成 + Phase 1b 着手 handoff:
  `docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
- Phase 1b 完成 handoff:
  `docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`
- Phase 1c 着手 master handoff (self-contained):
  `docs/filmtone/desktop/filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md`
- Phase 1c 完成 handoff:
  `docs/filmtone/desktop/filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`
- **Phase 2 C1+C2 (Foundation: DTO port + AVFoundation modern async): COMPLETE**
  (uncommitted、同日 late evening)。`Domain/SourceColorTypes.swift` (3 enum +
  metadata struct)、`Color/SourceColorMetadataNormalizer.swift` (CoreMedia →
  ffprobe 語彙)、`Color/SourceColorClassifier.swift` (`classify(metadata)`)、
  `Color/FilmtoneColorPipeline.swift` (`defaultOutputContract` factory +
  `isDisplayP3SDR` / `workingColorSpace` / `outputColorSpace` namespace)、
  `Media/FormatExtensionReader.swift` (CMFormatDescription extension reader)、
  `Media/FilmtoneSourceProber.swift` (async video probe via `loadTracks` +
  variadic `track.load(_:_:_:_:)` / 還元 sync 化、still CGImageSource probe)。
  `Color/FilmtoneColorPipelineContract.swift` を iOS L84-206 verbatim 形へ
  restructure (`phase1cMP4Default()` 削除、`stillImageOptions()` 追加)。
  `Media/FilmtoneVideoReader.swift` を `FilmtoneVideoTrackProbe` 受領形へ
  rebuild (deprecated `asset.tracks` / `track.naturalSize` 等を全消化)。
  `Media/FilmtoneVideoFramePreview.swift` を modern async API (`generator.image
  (at:)` / variadic load) へ migrate。`Export/FilmtoneSidecarWriter.swift` に
  additive `sourceInterpretation` (Phase 2 acceptance "Source profile id
  round-trips through sidecar")。`UI/PreviewSurface.swift` に Coordinator-based
  Task 管理 (preset 切替時の stale frame race 回避)。pbxproj UUID A17-A1C /
  B17-B1C 追加。`bun run verify:macos` BUILD SUCCEEDED、AVFoundation sync
  deprecation 6 sites 全解消、generator drift 0、iOS↔macOS Phase0Generated
  bit-identical、iOS / Electron / core src clean。Phase 1b regression: still
  reset macOS↔source ∞dB / baseline-B 13.69dB 維持、iphone on 09-skin-light
  **40.60 dB** (Phase 1c は 39.62dB → +0.98dB、source color の sRGB fallback
  + applyOrientationProperty 適用が iOS canonical 方向への drift)。video
  CLI smoke: synthetic-bt709-1s.mp4 → reset.mp4 (Rec.709 metadata 正常)、
  sidecar に `sourceInterpretation: "sdr-bt709"`。
- **Phase 2 C3 truth gate scaffold: COMPLETE** (uncommitted、同日)。
  `apps/desktop-film-lab-batch/test/golden/baseline-C/{reset,iphone,softBlue,
  amberGlow}/` + provenance README (iOS Simulator workflow + 実機 1 回確定の
  手順)、`scripts/golden-parity-ios-vs-macos.ts` (PENDING-aware harness、
  threshold default 35dB、PASS/FAIL/PENDING/ERROR status)。baseline-C content
  自体は user iOS Simulator export 待ちで **PENDING**。harness は空 baseline-C
  でも実行可能 (smoke 実行済: `--preset reset` 全 10 PENDING、`--preset iphone
  --image 09-skin-light` で macOS↔source = 40.60 dB / baseline-C = PENDING)。
- Phase 2 C1+C2+C3 scaffold master handoff (canonical、本 chat 成果):
  `docs/filmtone/desktop/filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md`
- Phase 0 internal design plan: `~/.claude/plans/luminous-sparking-eclipse.md`
- **Next: Phase 2 C3 baseline-C populate (user iOS Simulator workflow)** →
  `bun run scripts/golden-parity-ios-vs-macos.ts --preset <name>` 各セル PSNR
  確認 → C3 結果 + OpticalFilters main 着地状況で C5 (OpticalFilters 合流) /
  C6 (SPM 化、急がない方針) / C7 (IOSurface perf bench) の優先付け再判断
  (chunk 着手時 user 確定: 現時点で C5/C6/C7 順序固定しない)。
- **Phase 2 C5a (per-pixel optical: vignette + grain CIColorKernel): COMPLETE**
  (commit `cd170a6`、2026-05-03 JST late evening 続き)。`Color/
  FilmtoneGradeKernels.swift` に vignette / grain `CIColorKernel` を iOS
  canonical から verbatim lift、`FilmtoneGradePipeline.swift` の post-base
  stage に挿入。`bun run verify:macos` BUILD SUCCEEDED、iphone preset で
  09-skin-light fixture macOS↔source PSNR が +5dB 程度向上 (per-pixel
  optical chain の正方向 drift)。
- **Phase 2 C5c (RayAngleOptics port: vignette canonical 化 + camera optics
  probe 拡張): COMPLETE** (commit `cda0f9f`、2026-05-04 JST 早朝)。RayAngle
  optics canonical params を iOS から port、camera optics probe を
  `FilmtoneSourceProber` に additive 拡張。
- **Phase 2 C5b A.1 (bloom mip pyramid: softKneeHighlight + tentDownsample/Up
  + glowComposite、halation/diffusion plates black): COMPLETE** (commit
  `ad23753`、2026-05-04 JST 早朝)。`FilmtoneGradeKernels.swift` に bloom
  系 kernel 4 個 (softKneeHighlight / tentDownsample / tentUpsample /
  glowComposite) verbatim lift、`FilmtoneGradePipeline.swift` に
  `extractHighlightPlate` / `buildMipBlurComposite` / `applyGlowFamilyStage`
  追加 (halation/diffusion は black プレースホルダ)。`bun run verify:macos`
  BUILD SUCCEEDED、reset PSNR ~40dB / iphone PSNR 35.59dB (09-skin-light)。
- **Phase 2 C5b A.2 (halation + diffusion plates: buildMipBlurComposite 再利用、
  halationColor helper 追加): COMPLETE** (uncommitted、2026-05-04 JST、chat
  A.7)。`FilmtoneGradePipeline.swift` の halation/diffusion black 行を
  production block に置換 (iOS L1839-1905 verbatim)、`halationColor(for:)`
  static helper 追加 (hue 0→100 で `#E81020`→`#C06010` 線形補間、iOS
  L2392-2398 verbatim)。BUILD SUCCEEDED、reset PSNR 28.08dB (`paramsByName
  ["reset"]` に diffusion=0.08 含むため期待値変動)、iphone PSNR 22.47dB
  mean / 29.17dB (09-skin-light、halation+diffusion active)。
- **Phase 2 C5b A.3 (edgeOptics: radialRGBSplit + edgeSoftnessBlend CIKernel
  + applyEdgeOpticsStage): COMPLETE** (uncommitted、2026-05-04 JST、chat
  A.8)。`FilmtoneGradeKernels.swift` に `radialRGBSplit` + `edgeSoftnessBlend`
  CIKernel verbatim lift (iOS L4567-4583 / L4696-4715)。
  `FilmtoneGradePipeline.swift` に 7 constants
  (`aberrationEdgeSoftenScale=32.0` / `aberrationEdgeSoftenMax=0.52` /
  `aberrationEdgeSoftenCurve=1.55` 他) + `applyEdgeOpticsStage` /
  `applyRadialRGBShift` / `applyEdgeSoftness` / `aberrationEdgeSoften` /
  `lerp` (iOS L1714-1722 / L2237-2298 / L2521-2545 verbatim)。pipeline 順序
  を iOS canonical (`baseGradeV2 → filmCompressionV2 → edgeOptics →
  glowFamily → vignette → grain → printStage`) に一致。BUILD SUCCEEDED、
  reset PSNR 28.08dB (`rgbShift=0.0`/`lensSoftness=0.0` で full no-op、A.2
  と byte-identical)、iphone PSNR mean 22.36dB / 29.17→28.81dB
  (09-skin-light、`rgbShift=0.0012`/`lensSoftness=0.14` で edge softening
  正常反映、A.2 比 -0.11dB mean / -0.36dB)。
- **C5b 全段完了、macOS Native pipeline iOS canonical 一致達成**。残 C 系列
  blocker: C3 baseline-C populate (外殻判定、user iOS Simulator workflow
  待ち)、C6 SPM 化 (急がない方針維持)、C7 IOSurface perf bench (measurement
  COMPLETE、refactor 不要判定)。
- **Phase 2 C5d (iOS canonical pipeline driver line-by-line audit + sourceSeed
  配線): COMPLETE** (uncommitted、2026-05-04 JST、chat A.9)。`applyGrade`
  (iOS `FilmtoneExportSession.swift:1532-1567`) と macOS `FilmtoneGradePipeline.apply`
  を line-by-line 突合、port deviation を **5 件** 検出。HIGH severity 1 件
  (`sourceSeed=0` 全 caller で hardcode → grain pattern が iOS canonical と
  divergent) を修正: `FilmtoneGradePipeline.makeStableSourceSeed(from:)` を
  追加 (iOS L2411-2418 verbatim FNV-1a hash mod 8192)、`FilmtoneStillExporter`
  / `FilmtoneVideoExporter` / `PreviewSurface` の 3 caller に配線。LOW
  severity 4 件 (LUT 2 stage 欠落 / 最終 crop / printContrast abs gate) は
  built-in 4 preset で no-op、将来 lane で対応。BUILD SUCCEEDED、reset PSNR
  28.08dB (A.3 と byte-identical、grainIntensity=0 で no-op)、iphone PSNR
  mean 22.36dB (sourceSeed は noise pattern のみ変更、intensity 不変なので
  macOS↔source 数値も A.3 と一致)。真の効果は macOS↔baseline-C で観測される
  が baseline-C populate 後に grain noise floor の上限制限が消えることを保証
  (substance correctness)。
- Phase 2 C5b A.2 master handoff (canonical、A.3 着手時の self-contained
  prompt): `docs/filmtone/desktop/filmtone-native-desktop-phase2-c5b-a2-master-handoff-2026-05-04-jst.md`
- **Next**: (a) C5b + C5d 合計 7 ファイル uncommitted の user 手動 commit
  (`FilmtoneGradeKernels.swift` / `FilmtoneGradePipeline.swift` /
  `FilmtoneStillExporter.swift` / `FilmtoneVideoExporter.swift` /
  `PreviewSurface.swift` / 04 / 06 / 01)、(b) C3 baseline-C populate
  (外殻、user iOS Simulator workflow) — populate 完了後に C5d の真の PSNR
  改善が観測可能、(c) Look Unification main merge 観測時に macOS sidecar
  emitter を Case A (dual emit) へ切替、(d) C6 SPM 化 / C7 IOSurface
  (低優先)、(e) GLSL→MSL kernel 移行 (iOS と同期した大手術 lane)。

## Purpose

Filmtone Desktop を Electron 製の macOS アプリから、SwiftUI-first の
Native Desktop v2 へ移行する。AppKit は macOS 固有の深い統合が必要な箇所で
interop として使う。

この計画の目的は、見た目の glass 化だけではない。Filmtone を
「Web 技術で作った Mac 用ツール」から「Apple プラットフォームの写真 /
映像アプリ」へ上げることを目的にする。

優先順位:

1. 画の品質、色の正しさ、preview / export の一致
2. Apple 純正 UI / Liquid Glass / macOS 操作体系への適合
3. iOS 版とのネイティブ資産共有
4. 現行 Desktop リリース導線の維持
5. 外殻 QA / public copy / release 周辺整備

長期的には Native Desktop v2 を、単なる Electron 置き換えではなく次の
拡張に耐える土台にする:

- Apple ecosystem: iOS で決めた recipe を Mac が SSD 上の同一素材へ適用して
  書き出す Continuity 体験。
- Pro NLE: まず `.cube` LUT export、次に DaVinci Resolve 連携、必要になったら
  DCTL / OFX を検討できる render core 境界。

ただし、これらは Phase 1 / Phase 2 の縦切り proof を遅らせない。最初の
product gate は引き続き preview / export parity と一個の正しい flow。

外殻は最後に回す。計画書、issue 整理、LP、網羅 QA、release notes
整備は、native vertical slice が製品品質で勝ってから行う。

## Product Decision

Native Desktop v2 を新しい製品レーンとして開始する。

やらないこと:

- Electron UI を Liquid Glass 風に微調整するだけで終わらせない。
- 現行 Electron アプリを即座に捨てない。
- 初手で release / public site / portfolio / App Store 的な外殻を整備しない。
- macOS 11 互換を Native v2 の最初の制約にしない。
- CloudKit / Handoff / Resolve / OFX / DCTL を Phase 1 の scope にしない。
- Adobe Premiere / After Effects 連携を Native v2 初期 roadmap の gate にしない。

やること:

- SwiftUI-first で Native Desktop v2 の薄い縦切りを作る。
- AppKit は macOS 固有の window / menu / panel / Finder integration などに
  限って使う。
- 最新 macOS / Xcode の Liquid Glass を第一級ターゲットにする。
- 現行 Electron は Native v2 が preview / export 品質で勝つまで release rail
  として残す。
- iOS 側 Swift 実装と shared core の契約を使い、色処理と export の drift を
  golden gate で潰す。
- iOS UI は SwiftUI / UIKit の領域であり、AppKit 共有を前提にしない。

## Current Facts

### Desktop

- 現行 Desktop は Electron + React / Vite。
- `apps/desktop-film-lab-batch/package.json` は `electron`,
  `react`, `vite`, shared `film-lab-*` packages に依存している。
- macOS window は `BrowserWindow` で `titleBarStyle: "hidden"`,
  `vibrancy: "under-window"`, `visualEffectState: "active"` を使っている。
- CSS 側には `.fl-card--frost` と WebGL / WebGPU backdrop workaround がある。
- 既存 glass rulebook は Electron renderer 内の glass 統一であり、Apple
  native component の Liquid Glass ではない。

### iOS

- iOS 側には SwiftUI, AVFoundation, CoreImage, Metal 系の実装資産がある。
- 主要資産:
  - `FilmtoneRootView.swift`
  - `FilmtoneRootChrome.swift`
  - `FilmtonePreviewView.swift`
  - `FilmtoneExportSession.swift`
  - `FilmtoneColorPipeline.swift`
  - `FilmtoneMetalOpticsRenderer.swift`
  - `FilmtoneSourceProfileMath.swift`
  - `FilmtonePhase0Generated.swift`
- `FilmtonePhase0Generated.swift` は generated Swift で、手編集禁止。
  Native Desktop でも同じ原則を維持する。

### Apple / Electron Platform Facts

- SwiftUI は新規 native UI の主軸。platform-specific behavior が必要な箇所で
  UIKit / AppKit と interop する。
- AppKit は macOS 用 UI framework。iOS / iPadOS の UI は SwiftUI / UIKit。
- Apple は Liquid Glass を SwiftUI / UIKit / AppKit の標準 component と
  custom view effect に載せる設計として提供している。
- SwiftUI custom view では `glassEffect`, `Glass`, `GlassEffectContainer`
  が Liquid Glass の中心 API になる。
- AVFoundation は iOS / iPadOS / macOS など横断の audiovisual framework。
  custom frame export は `AVAssetReader` / `AVAssetWriter` 系で組むのが本筋。
- Electron が提供するのは BrowserWindow の vibrancy / titlebar / background
  material などの window-level integration であり、SwiftUI の標準
  component と同じ Liquid Glass UI ではない。

References:

- Apple macOS 26: https://developer.apple.com/macos/whats-new/
- Apple Liquid Glass overview:
  https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass
- Apple SwiftUI custom Liquid Glass:
  https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- Apple AVFoundation:
  https://developer.apple.com/av-foundation/
- Electron BaseWindow options:
  https://www.electronjs.org/docs/latest/api/structures/base-window-options
