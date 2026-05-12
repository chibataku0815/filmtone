# Filmtone Desktop for macOS

This is the official Filmtone Desktop implementation. It is the native
SwiftUI/AppKit macOS app in `apps/filmtone-desktop-macos/`.

Do not use `apps/desktop-film-lab-batch/` for normal Desktop work. That app is
the frozen legacy Electron rail and is only for tasks that explicitly say
legacy Electron, old Desktop, or rollback.

## Current Source Of Truth

Current Native Desktop v2 state lives in:

```text
docs/filmtone/desktop/native-desktop-v2/strategy.md
docs/filmtone/desktop/native-desktop-v2/active.md
```

Read `active.md` only if present. If it is missing, no Native Desktop v2
product subtask is open; propose the next scoped task before implementing.

This README is only the local app/build orientation. Historical phase plans and
handoffs are evidence, not current truth.

Do not infer the current Preset / Look product model from generated or
compatibility preset IDs such as `iphone`, `softBlue`, or `amberGlow`. Those IDs
may remain in generated payloads, parity fixtures, and compatibility code. Use
`packages/film-lab-core/src/presets.ts`, `packages/film-lab-core/src/look-ids.ts`,
and the active lane docs for current product truth.

## App Structure

- `App/FilmtoneDesktopApp.swift` — `@main` SwiftUI App, `WindowGroup`
- `App/AppCommands.swift` — Help menu link 1 個
- `UI/` — SwiftUI/AppKit window, browser, preview, compare, scrub, and control
  surfaces
- `Color/` — native grade and preset pipeline
- `Export/` — native still/video export and sidecar writing
- `Verify/` — native verification helpers and fixtures
- `fastlane/` — Mac App Store metadata and release lanes
- `packages/film-lab-swift-core` — shared Swift contract consumed through
  `import FilmLabSwiftCore`

## Build

```bash
bun run build:core
bun run generate:swift
bun run verify:desktop
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
```

## FilmLabSwiftCore (SPM) との関係

Shared Filmtone contract types live in `packages/film-lab-swift-core` as the
`FilmLabSwiftCore` module.
`FilmtoneDesktop.xcodeproj` は `XCLocalSwiftPackageReference` 経由で
package を参照し、Swift ファイルでは `import FilmLabSwiftCore` で取り込む。

## Hand-written `.xcodeproj` について

`xcodegen` などの外部ツールを使わず、`project.pbxproj` を手書きしている。理由:

- bun monorepo に外部 Swift toolchain を足したくない
- app target は 1 個のみで pbxproj は最小構成
- shared Swift contract は `packages/film-lab-swift-core` の local SPM package
  として参照する

UUID は `FT0000...` prefix で reproducible に並べてあり、merge conflict が
起きにくい構造になっている。新規ファイル追加時は **既存最大値の次** を割り当てる
(handoff doc §Xcode project の構造 参照)。

## Apple Liquid Glass

戦略上、本アプリの UI material 主軸は **Apple Liquid Glass** とする
(`docs/filmtone/desktop/native-desktop-v2/strategy.md` 参照)。

macOS 26 SDK で build すると標準 SwiftUI `.toolbar` は自動的に Apple Liquid
Glass を採用する。UI 方針や残りの polish は `strategy.md` と現在の
`active.md` に従う。

content layer (`PreviewSurface`) には Apple Liquid Glass を当てない
(Apple HIG + strategy UI principles)。preview 背景は `Color.black` で
color judgment を阻害しない。
