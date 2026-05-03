# 01 Current State And Decision

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Status (2026-05-03 JST)

- **Phase 0 (Contract & Skeleton): COMPLETE.** All 8 acceptance gate checks
  pass. macOS native app launches on macOS 26.4.1 with Xcode 26.4.1.
- **Phase 1a (Open + Preview precondition): COMPLETE (same day).** Decision A
  採択 — `Domain/Phase0Types.swift` (4 struct memberwise stub) で
  `SharedGenerated/FilmtonePhase0Generated.swift` を Compile Sources に取り込み、
  `RootWindowView` に `NSOpenPanel` (`⌘O`) + `PreviewSurface` (NSImageView 経由)
  を配線。grade なし生表示。`bun run verify:macos` BUILD SUCCEEDED、iOS lane /
  Electron lane 無傷、generator dual-target bit-identical 維持。
- Phase 0 完成記録 (Liquid Glass facts、pbxproj UUID 規約、Lift 候補一覧):
  `docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
- Phase 1a 完成記録 + Phase 1b 着手 handoff (canonical):
  `docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
- Phase 0 internal design plan (architectural reasoning):
  `~/.claude/plans/luminous-sparking-eclipse.md`
- **Next: Phase 1b** (preset 選択 -> grade 適用 -> still export ->
  sidecar JSON -> Electron baseline-B との PSNR parity)。Phase 1c は動画 slice。

## Purpose

Filmtone Desktop を Electron 製の macOS アプリから、SwiftUI / AppKit
ベースの Native Desktop v2 へ移行する。

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

- SwiftUI / AppKit で Native Desktop v2 の薄い縦切りを作る。
- 最新 macOS / Xcode の Liquid Glass を第一級ターゲットにする。
- 現行 Electron は Native v2 が preview / export 品質で勝つまで release rail
  として残す。
- iOS 側 Swift 実装と shared core の契約を使い、色処理と export の drift を
  golden gate で潰す。

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
