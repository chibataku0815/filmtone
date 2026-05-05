# Filmtone Native Desktop v2 (Phase 0 + 1a + M4-B Phase 2)

SwiftUI / AppKit ベースの macOS native app。全体計画書は
`docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`。

## 現状 Scope

Phase 0 (Skeleton) + Phase 1a (Open + Preview precondition) + M4-B Phase 2
(FilmLabSwiftCore SPM 取り込み) まで完了。grade / export / sidecar / parity
は **Phase 1b 以降**、video slice は **Phase 1c**。

含まれているもの:

- `App/FilmtoneDesktopApp.swift` — `@main` SwiftUI App, `WindowGroup`
- `App/AppCommands.swift` — Help menu link 1 個
- `UI/RootWindowView.swift` — root window, `.toolbar` (macOS 26 SDK で自動
  Apple Liquid Glass), Open ボタン (`⌘O`) → `NSOpenPanel` → `@State imageURL`
- `UI/PreviewSurface.swift` — `NSImageView` を `NSViewRepresentable` で
  ラップした静止画 preview。`Color.black` 背景。grade なし生表示
- `UI/GlassControlGroup.swift` — `glassEffect(.regular, in: Capsule())` の
  custom 例
- Phase 0 types (`FilmtoneQuickState` / `FilmtonePhase0Params` /
  `FilmtonePhase0ParamsPatch` / `Phase0OutputProfileDTO` /
  `FilmtonePhase0HiddenDefaults`) は `packages/film-lab-swift-core`
  (FilmLabSwiftCore) に集約済み。Desktop は `import FilmLabSwiftCore` で
  consume する (M4-B Phase 2、2026-05-04)。

## Build

```bash
# 1. Core パッケージビルド (TS contract source)
bun run build:core

# 2. 生成 Swift を emit (Phase 2 時点では iOS internal + package public の 2 出力)
bun run generate:swift

# 3. macOS app build
bun run verify:macos

# 4. Launch
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
```

## FilmLabSwiftCore (SPM) との関係

Phase 0 types はすべて `packages/film-lab-swift-core` の
`FilmLabSwiftCore` モジュールに公開 API として配置されている。
`FilmtoneDesktop.xcodeproj` は `XCLocalSwiftPackageReference` 経由で
package を参照し、Swift ファイルでは `import FilmLabSwiftCore` で取り込む。

M4-B Phase 3 で iOS App も同 package を取り込むと、generator は
`apps/capacitor-film-lab-ios/...` 出力を捨てて package public 1 出力に
集約される予定。

## Hand-written `.xcodeproj` について

`xcodegen` などの外部ツールを使わず、`project.pbxproj` を手書きしている。理由:

- bun monorepo に外部 Swift toolchain を足したくない
- target は 1 個のみで pbxproj は最小構成
- 同じ理由で `Package.swift` (SPM) も Phase 0/1a では作らない (Phase 2 で導入)

UUID は `FT0000...` prefix で reproducible に並べてあり、merge conflict が
起きにくい構造になっている。新規ファイル追加時は **既存最大値の次** を割り当てる
(handoff doc §Xcode project の構造 参照)。

## Apple Liquid Glass

戦略上、本アプリの UI material 主軸は **Apple Liquid Glass** とする
(`docs/filmtone/desktop/native-desktop-v2/strategy.md` Goal / M5 Done
Conditions / M5-B slice 参照)。

macOS 26 SDK で build すると標準 SwiftUI `.toolbar` は自動的に Apple Liquid
Glass を採用する。現状、明示的に `glassEffect()` を呼ぶのは
`GlassControlGroup.swift` の 1 箇所のみで、これは API surface が確実に
コンパイル通るかの検証目的。**M5-B で sidebar / inspector / Look picker /
control panels への系統適用を行う**(計画は active.md 化時に確定)。

content layer (`PreviewSurface`) には Apple Liquid Glass を当てない
(Apple HIG + 全体計画書 §UI principles)。preview 背景は `Color.black` で
color judgment を阻害しない — この除外方針は M5-B でも維持する。
