# Filmtone Native Desktop v2 (Phase 0 + 1a)

SwiftUI / AppKit ベースの macOS native app。全体計画書は
`docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`。

## 現状 Scope

Phase 0 (Skeleton) + Phase 1a (Open + Preview precondition) まで完了。
grade / export / sidecar / parity は **Phase 1b 以降**、video slice は
**Phase 1c**。

含まれているもの:

- `App/FilmtoneDesktopApp.swift` — `@main` SwiftUI App, `WindowGroup`
- `App/AppCommands.swift` — Help menu link 1 個
- `UI/RootWindowView.swift` — root window, `.toolbar` (macOS 26 SDK で自動
  Liquid Glass), Open ボタン (`⌘O`) → `NSOpenPanel` → `@State imageURL`
- `UI/PreviewSurface.swift` — `NSImageView` を `NSViewRepresentable` で
  ラップした静止画 preview。`Color.black` 背景。grade なし生表示
- `UI/GlassControlGroup.swift` — `glassEffect(.regular, in: Capsule())` の
  custom 例
- `Domain/Phase0Types.swift` — `FilmtoneQuickState` / `FilmtonePhase0Params` /
  `Phase0OutputProfileDTO` / `FilmtonePhase0HiddenDefaults` の最小 stub。
  iOS 側型を duplicate しているのは Phase 2 SPM 化までの暫定 (本書 §SharedGenerated)
- `SharedGenerated/FilmtonePhase0Generated.swift` — TS contract から生成された
  Swift。Phase 1a で **Compile Sources に取り込み済み** (`Domain/Phase0Types.swift`
  が依存型を提供しているため)

## Build

```bash
# 1. Core パッケージビルド (TS contract source)
bun run build:core

# 2. 生成 Swift を emit (iOS と macOS 両方へ)
bun run generate:swift

# 3. macOS app build
bun run verify:macos

# 4. Launch
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
```

## SharedGenerated と Domain の関係

`SharedGenerated/FilmtonePhase0Generated.swift` は次の型に依存する:

- `FilmtoneQuickState`
- `FilmtonePhase0Params`
- `Phase0OutputProfileDTO`
- `FilmtonePhase0HiddenDefaults`

iOS では `FilmtonePhase0Math.swift` + `FilmtoneMediaTypes.swift` がこれを
提供する (両方 481 / 763 行ある full implementation)。macOS では Phase 1a
時点では **Domain/Phase0Types.swift の memberwise-init 用 stub** だけを
duplicate して `SharedGenerated` を compile-link 可能にしている。Method /
Codable / DTO graph は Phase 1b 以降で必要になった分だけ port する。

**Phase 2** で iOS の `FilmtoneColorPipeline` / `FilmtoneMetalOpticsRenderer`
移管とまとめて SPM 化する (`packages/film-lab-swift-core/` 予定、
`swift-tools-version: 6.2`)。SPM が登場した時点で `Domain/Phase0Types.swift`
は削除し、import に切り替える。iOS と macOS の `Phase0Generated.swift` は
generator dual-target emit によって機械的に bit-identical (`diff -q` で常時
確認可能)。

## Hand-written `.xcodeproj` について

`xcodegen` などの外部ツールを使わず、`project.pbxproj` を手書きしている。理由:

- bun monorepo に外部 Swift toolchain を足したくない
- target は 1 個のみで pbxproj は最小構成
- 同じ理由で `Package.swift` (SPM) も Phase 0/1a では作らない (Phase 2 で導入)

UUID は `FT0000...` prefix で reproducible に並べてあり、merge conflict が
起きにくい構造になっている。新規ファイル追加時は **既存最大値の次** を割り当てる
(handoff doc §Xcode project の構造 参照)。

## Liquid Glass

macOS 26 SDK で build すると標準 SwiftUI `.toolbar` が自動的に Liquid Glass を
採用する。明示的に `glassEffect()` を呼ぶのは `GlassControlGroup.swift` の
1 箇所のみで、これは API surface が確実にコンパイル通るかの検証目的。

content layer (`PreviewSurface`) には glass を当てない (Apple HIG + 全体計画書
§UI principles)。preview 背景は `Color.black` で color judgment を阻害しない。
