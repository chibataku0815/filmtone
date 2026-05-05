# Filmtone Native Desktop v2 — Phase 1 Next Chat Handoff

Date: 2026-05-03 JST
Source chat: Phase 0 Contract & Skeleton 実装 chat (worktree branch
`feature/native-desktop-plan`)
Target chat: Phase 1 Vertical Slice 実装 chat (新規)

> **Status (2026-05-03 JST 同日更新)**: Phase 1a (Open + Preview precondition)
> は完了済み — Decision A 採択、`Domain/Phase0Types.swift` (4 struct stub)
> + `UI/PreviewSurface.swift` (`NSImageView` ラッパー) + `pbxproj` 拡張
> (Sources phase に 3 ファイル追加、Domain/SharedGenerated group 新設)
> + `RootWindowView` Open 配線 (`⌘O` / `NSOpenPanel`)。
> **Phase 1b 着手の canonical handoff は**
> `docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`。
> このドキュメントは Phase 0 完成記録 + Phase 1 全体像の **historical 正本**
> として残し、Phase 1b chat は子 handoff を先に読んでからここを参照する順。

このドキュメントだけ読めば前 chat の議論・決定・現状を完全に再現できる。
**冒頭から末尾まで一読してから Phase 1 に着手すること**。

---

## 0. Read-this-first 順序

新 chat の最初の 10-15 分:

1. このドキュメント全体 (Phase 0 完成状態 + Phase 1 scope + invariants +
   §10.5 Concurrent Lane: Desktop Look Unification)
2. 全体計画書 index
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   から read order を確認。Phase 1 は split docs の
   `04-phase-plan.md`、Look Unification 依存は `03-migration-and-concurrent-lanes.md`
   が正本
3. **Look Unification 元ハンドオフ** (main checkout 側)
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
   — sidecar dual emit / `lookId` / `lookVersion` / `BASE_LOOKS` 等の
   canonical contract。Phase 1 macOS sidecar emitter はこれに従う
4. `apps/filmtone-desktop-macos/README.md` (Phase 0 macOS app の自己説明)
5. Phase 0 設計判断のメモ
   `/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md`
   (なぜ SPM を Phase 0 から外したか、なぜ SharedGenerated を Compile Sources
   から外したか、UUID 命名規約等)
6. `git log --oneline -20` で worktree の commit 状態確認 (Phase 0 commit が
   入っているか)
7. **Look Unification の main 着地状況確認**:
   ```bash
   cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
   git log --oneline | grep -iE "look unification|baselook" | head
   grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
   grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
   ```
8. `bun run verify:macos` を即座に走らせて Phase 0 の build が現在も通ること
   を確認 (env 差で壊れていないことの sanity check)

---

## 1. Where you are

### Repos

| repo | path | 役割 |
|---|---|---|
| **このリポ (worktree)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0/1 の実装 worktree、branch `feature/native-desktop-plan` |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ。**ここで作業しない** |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 (`apps/web`)、`vendor/filmtone` submodule で消費。**Phase 1 は触らない** |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts + 5 ロール憲法 |

### Worktree branch invariants

- このリポは `feature/native-desktop-plan` branch
- Phase 0 commit が既に入っているはず (user が手動で commit した想定)
- Phase 0 commit が **未** だった場合: 新 chat は最初に user に commit を依頼。
  このドキュメント末尾の「Phase 0 commit 待ち時の対処」参照
- 別 branch を切る必要は **なし**。Phase 1 は同じ branch で続ける。
  PR 切るのは Phase 1 完了時 (Phase 0 + Phase 1 同一 PR)
- main checkout の dirty/untracked にある OpticalFilters 関連ファイル
  (`packages/film-lab-core/src/ios-optical-filter-payload.ts` 等) は
  **このワークツリーには来ていない**。lane が main へ landing 後に取り込む
  方針 (Phase 0 Out of Scope に明記済み)

### Tooling versions (verified working)

- macOS 26.4.1 (Build 25E253)
- Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3
- Swift 6.0 (target setting; toolchain は Xcode 26 同梱)

これらより古い env では Liquid Glass API がコンパイル通らない。

---

## 2. What is Filmtone (1 段落)

Filmtone は forestone の film-lab 系プロダクト群:

- **Filmtone Desktop** (Electron + React/Vite, macOS) — 写真/動画の film-tone
  バッチグレーディング
- **Filmtone iOS** (Capacitor + SwiftUI/Metal/CoreImage) — App Store 公開、
  v1.2 public / v1.3 local candidate in-flight
- **共有 packages**: `film-lab-core` (params/preset/source-profile contract,
  Zod schema), `film-lab-renderer` (WebGL/WebGPU shader graph), `film-lab-ui`,
  `film-lab-smart-look`

このリポは **実装の正本**。portfolio (`vendor/filmtone` submodule) と life
(docs/guides・truth scripts) は別役割。詳細は worktree の `CLAUDE.md` §2。

---

## 3. The transition (Native Desktop v2)

全体計画書
(`docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`)
の要約。**Phase 1 を進める前に必ず原文を読む**。

- Filmtone Desktop を Electron から **SwiftUI/AppKit native macOS app
  (Liquid Glass)** に移行する。
- 並行 lane 戦略: 現行 Electron Desktop は release rail として残し続け、
  Native Desktop v2 が phase gate を通るまで default にしない。
- macOS 26 only (Liquid Glass first-class、reduced-material fallback は
  書かない — user 確認済み)。
- Phase 0 → Phase 5 の段階。Phase 0 = 今日完了。

---

## 4. Phase 0 完了記録 (exhaustive)

### Acceptance gate 結果 (全部 PASS)

| # | 検証 | 結果 |
|---|------|------|
| 1 | `bun run build:core` | SUCCESS (148 KB ESM + 70 KB DTS) |
| 2 | `bun run generate:swift` | iOS / macOS 両方 emit、bit-identical |
| 2a | iOS git diff (vs HEAD before refactor) | **空** (bit-identical 保持) |
| 2b | iOS vs macOS Phase0Generated.swift | `diff -q` IDENTICAL |
| 3 | `bun run generate:ios-swift` (shim) | dispatch 動作、emit 同一 |
| 4 | `bun run generate:swift -- --check` | exit 0 |
| 5 | `bun run verify:ios` | exit 0、Phase0 contract / motion blur / cube parser / cache store / source-color-classifier / ray-angle optics / source profile math (D-Log/D-Log M/C-Log/C-Log 3/V-Log/S-Log3 ΔE2000 全て 0.000) / sidecar builder 全 pass |
| 6 | `bun run verify:macos` | `** BUILD SUCCEEDED **` |
| 7 | App launch | `co.fores-tone.filmtone.desktop` / LSMinimumSystemVersion 26.0、PID 取得確認 |
| 8 | `git status apps/desktop-film-lab-batch/` | empty (Electron unchanged) |
| 8b | `git status apps/capacitor-film-lab-ios/` | empty (iOS unchanged) |

### Files added / modified (Phase 0 commit に入る分)

```
M  .gitignore
M  package.json
M  scripts/generate-filmtone-ios-swift.ts        (shim 化、3 行)
?? scripts/generate-filmtone-swift.ts            (新 multi-target generator、52 行)
?? docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
?? apps/filmtone-desktop-macos/
   ├── README.md
   ├── FilmtoneDesktop.xcodeproj/
   │   ├── project.pbxproj
   │   ├── project.xcworkspace/contents.xcworkspacedata
   │   └── xcshareddata/xcschemes/FilmtoneDesktop.xcscheme
   └── FilmtoneDesktop/
       ├── App/
       │   ├── FilmtoneDesktopApp.swift          (@main, WindowGroup, Commands)
       │   └── AppCommands.swift                 (Help menu link 1 個)
       ├── UI/
       │   ├── RootWindowView.swift              (toolbar + preview placeholder)
       │   └── GlassControlGroup.swift           (.glassEffect(.regular, in: Capsule()))
       ├── SharedGenerated/
       │   └── FilmtonePhase0Generated.swift     (generator 出力、Compile Sources 外)
       └── Assets.xcassets/
           ├── Contents.json
           └── AppIcon.appiconset/Contents.json
```

`apps/filmtone-desktop-macos/build/` は xcodebuild output、`.gitignore` で除外。

### 生成器 multi-target の構造

`scripts/generate-filmtone-swift.ts` (canonical):

```ts
const targets: SwiftTarget[] = [
  { id: "ios",   outputPath: ".../apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift" },
  { id: "macos", outputPath: ".../apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift" },
]
```

両 target に同じ内容を書く。pure 関数 `renderFilmtoneIosSwiftPayload()` は
変更していない (iOS bit-identical のため)。`--check` 通過 = drift 無し。

`scripts/generate-filmtone-ios-swift.ts` は 1 行 shim:
```ts
import "./generate-filmtone-swift.ts";
```

`package.json` scripts:
- `generate:swift` = canonical
- `generate:ios-swift` = `bun run generate:swift` (alias)
- `verify:macos` = `xcodebuild ... -derivedDataPath apps/filmtone-desktop-macos/build build`

**OpticalFilters は Phase 0 に含めていない** — `renderFilmtoneIosOpticalFiltersSwift()`
が main の untracked ファイル
(`packages/film-lab-core/src/ios-optical-filters-swift.ts`) にしかないため。
main で OpticalFilters lane が landing したら、`targets[]` ループに同様の
generator 呼び出しを追加するだけ (trivial 拡張、Phase 1 で並行可)。

### Xcode project の構造

- **手書きの project.pbxproj** (xcodegen 等使わず)。理由は plan
  (`~/.claude/plans/luminous-sparking-eclipse.md`) 参照
- **objectVersion = 70** (`compatibilityVersion = "Xcode 16.0"`、Xcode 26 で
  受理確認)
- **UUID convention**: 24-char hex with `FT0000000000000000000XXX` prefix。
  reproducible / merge-conflict に強い。Phase 1 で source file 追加する時は
  `FT0000000000000000000B06` (FileRef), `FT0000000000000000000A06` (BuildFile)
  のように **既存の最大値の次** を割り当てる
- **GENERATE_INFOPLIST_FILE = YES** — Info.plist は build setting から自動
  生成 (PRODUCT_BUNDLE_IDENTIFIER 等)。明示的 Info.plist ファイルは作って
  いない
- **Bundle id**: `co.fores-tone.filmtone.desktop` (iOS と区別)
- **Deployment target**: macOS 26.0
- **SWIFT_VERSION**: 6.0
- **ENABLE_HARDENED_RUNTIME**: YES (Debug でも、code sign は ad-hoc)
- **Compile Sources** に含まれているのは: `FilmtoneDesktopApp.swift`,
  `AppCommands.swift`, `RootWindowView.swift`, `GlassControlGroup.swift` の 4 個。
  `SharedGenerated/FilmtonePhase0Generated.swift` は **PBXFileReference 自体
  作っていない** (Xcode が project navigator で見えない、disk 上の contract
  artifact のみ)

### SwiftUI の構成

- `@main FilmtoneDesktopApp` — `WindowGroup("Filmtone Desktop")`、
  `windowResizability(.contentMinSize)`、`commands { AppCommands() }`
- `RootWindowView` — `ZStack(alignment: .topTrailing)` で preview placeholder
  + 右上 floating GlassControlGroup。`.toolbar` (macOS 26 SDK で自動 Liquid
  Glass)、左に `camera.aperture` SF Symbol、右に Open ボタン (Phase 1 で
  enable)
- `GlassControlGroup` — `HStack` に play.fill / "Phase 0" / circle.dashed、
  padding 後に `.glassEffect(.regular, in: Capsule())`

### Liquid Glass facts (verified)

- `glassEffect(_:in:)` は macOS 26.0+ / iOS 26.0+ / iPadOS 26.0+ /
  watchOS 26.0+ / tvOS 26.0+
- `GlassEffectContainer` も同じ available 範囲
- 標準 SwiftUI `.toolbar` / `NSToolbar` は **macOS 26 SDK で build すると
  自動的に Liquid Glass を採用**。コードを書く必要なし
- design rule (Apple HIG): glass は navigation/control 層のみ。content/preview
  には当てない

参照:
- https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass

---

## 5. Critical Invariants (絶対に壊さない)

### Phase 0 で立てた境界

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** — v1.3
   local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。
   Phase 1 で iOS Swift ファイルから型をコピー/参照するのは OK だが、iOS
   Xcode project の `.pbxproj` には触らない
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** —
   release rail。Phase 4 で current-capability replacement に到達するまで
   shipping rail として残す
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/`
   を消さない** — submodule 即 import 用に track 維持。`.gitignore` に
   `dist` を追加しない (CLAUDE.md §6 antipattern #2)
4. **`packages/film-lab-core/src/` の contract source は変更しない** —
   generator は pure 関数を呼ぶだけ。schema 変更は別 lane
5. **生成 Swift を手編集しない** — `bun run generate:swift` の出力のみ。
   ヘッダの `// AUTO-GENERATED ...` コメントが残っている
6. **iOS と macOS の Phase0Generated.swift は bit-identical** — どちらかが
   ずれたら generator バグ。`diff -q` で常時確認可

### 用語ロック (CLAUDE.md §6 antipattern #5)

- `動画` (× `短尺動画`) / `video` (× `short-form video`)
- canonical: life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
- video vocabulary lock: life commit `5ce6d55` (2026-05-01)

### Bun mandatory (npm 禁止)

- `bun install` / `bun run` / `bun add`
- `bun.lock` が正本

### 出力ルール (life CLAUDE.md §11)

- 日本語、技術用語英語可
- ファイル参照: `path/to/file:line` 形式
- 簡潔・行動志向
- **Git 操作は user が実行** (auto commit 禁止)

---

## 6. Phase 1 scope (新 chat の本タスク)

全体計画書 Phase 1 の原文要約。**全文は plan 原文を読むこと**。

### Goal
> prove that Native Desktop can do real Filmtone work, not only native UI.

### Deliverables (vertical slice、1 個ずつ)

```
Still flow:
  open one still image
    -> preview it
    -> apply one built-in grade / source profile
    -> export one still
    -> write minimal sidecar

Then video slice:
  open one short video
    -> render representative preview frame
    -> export short H.264 MP4 clip
```

**batch UI を作らない**。one correct item is more valuable than a wide shell.

### Phase 1 Acceptance gate (plan 原文)

- 同じ params で Electron / iOS golden fixtures と visually matching output
  (defined tolerance 内)
- Source profile conversion が shared/iOS fixture parity に一致
- Exported still / video が QuickTime / Finder で repair なしに開く
- Preview と export が同じ native grade path、または明示的に proven equivalent
- Liquid Glass UI が preview legibility / color judgment を損ねない

### Phase 1 precondition (Phase 0 で deferred したもの)

**SharedGenerated を compile-link 可能にする**。`FilmtonePhase0Generated.swift`
は次の型に依存する:

| 依存型 | 定義場所 (iOS app dir) |
|---|---|
| `FilmtoneQuickState` | `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift` |
| `FilmtonePhase0Params` | 同上 |
| `Phase0OutputProfileDTO` | `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaTypes.swift` |
| `FilmtonePhase0HiddenDefaults` | 同上 |

これらを macOS app target で利用可能にしないと Phase 1 で grade params を
扱えない。**Phase 1 chat の最初の判断**:

#### Decision A: 型 dep を macOS target にコピー (recommended、速い)
- `FilmtonePhase0Math.swift` と `FilmtoneMediaTypes.swift` を
  `apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/` に
  ファイル参照でコピー (Xcode "Add files... do not copy") **しない**。
  内容コピーで `apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/` 配下に
  別ファイルとして置き、`SharedGenerated/FilmtonePhase0Generated.swift` を
  Compile Sources に追加
- iOS 側は **完全に無触**、duplication は temporary
- Phase 2 で SPM 集約する時に macOS 側コピーを削除して package import に
  切り替える
- リスク: iOS 側で型が変わると macOS 側が drift。**生成器に依存型 hash
  チェックを追加する手も** (Phase 2 候補)

#### Decision B: Phase 2 を先行して SPM を今作る
- `packages/film-lab-swift-core/` を `swift-tools-version: 6.2` で作成
- ColorPipeline / SourceProfileMath / CubeParser / LutBlobCodec /
  Phase0Generated 等を SPM に集約
- 生成器に **public variant target** を追加 (`public enum`、`public static`)。
  iOS の bit-identical は維持 (iOS 用 target は変更なし)
- iOS Xcode project は今回も触らず — iOS は引き続き local copy を消費。
  Phase 2 後半で iOS を SPM 消費に切り替え
- 利点: 綺麗、duplication なし
- 欠点: Phase 0 で deferred した複雑さを今 Phase 1 でやることになる。
  visibility 二重生成、iOS 出力の bit-identical を generator レベルで保証
  する必要

**推奨: Decision A** (本質優先 / 外殻最小)。Phase 1 の本質は color/render/
export であり、SPM 化は Phase 2 で iOS 移管とまとめてやる方が触る面積が
小さい。Phase 1 chat 開始時に user 確認すること。

### Phase 1 で書くべき Swift (predicted)

precondition の Decision A を採った場合の追加ファイル予想:

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Domain/                           # 新規、iOS から型コピー
│   ├── FilmtonePhase0Math.swift     (or 抽出した型のみ)
│   └── FilmtoneMediaTypes.swift     (or 抽出した型のみ)
├── Color/                            # 新規
│   ├── FilmtoneColorPipeline.swift  (iOS から lift、CoreImage path)
│   ├── FilmtoneSourceProfileMath.swift
│   ├── FilmtoneSourceProfileCatalog.swift
│   ├── FilmtoneCubeParser.swift
│   └── FilmtoneLutBlobCodec.swift
├── Export/                           # 新規
│   ├── FilmtoneStillExporter.swift  (CGImageDestination、PNG / JPEG)
│   └── FilmtoneSidecarWriter.swift  (Desktop sidecar contract 互換)
├── Media/                            # 新規
│   └── FilmtoneSourcePicker.swift   (NSOpenPanel)
└── UI/
    ├── RootWindowView.swift         (UPDATED: Open ボタン enable、preview に画像)
    ├── PreviewSurface.swift         (新規、CoreImage 描画)
    └── GradeControls.swift          (新規、Phase0 params の minimal UI)
```

### Phase 1 で参照する既存 iOS Swift (lift 候補、platform-neutral 確認済み)

Phase 0 探査の結論 (`/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md`
内) より:

| iOS file | platform-neutral? | macOS 戦略 |
|---|---|---|
| `FilmtoneColorPipeline.swift` | YES (CoreImage / CoreVideo / CoreGraphics、UIKit なし) | lift as-is |
| `FilmtoneSourceProfileMath.swift` | YES (Foundation のみ) | lift as-is |
| `FilmtoneSourceProfileCatalog.swift` | YES | lift as-is |
| `FilmtoneCubeParser.swift` | YES | lift as-is |
| `FilmtoneLutBlobCodec.swift` | YES (Foundation + CryptoKit) | lift as-is |
| `FilmtoneMetalOpticsRenderer.swift` | YES (Metal / CIImage、MTKView 不使用) | lift as-is、Phase 1 で使うかは preview path 設計次第 |
| `FilmtoneExportSession.swift` | partial (UIDevice telemetry あり) | lift with `#if os(iOS)` for telemetry のみ |

**Phase 1 では Phase0 grade only から始め**、Metal optics は Phase 2 (Native
Color/Export Backbone) に回すのが plan の意図。

### Phase 1 で参照する Electron 側 fixture (parity gate)

Phase 0 探査結果より:

```
apps/desktop-film-lab-batch/test/golden/
├── source-images/          (10 PNG: 01-highlight-sunset … 10-skin-dark)
├── baseline-A/<preset>/<image>.png   (80 files, 8 presets × 10 images)
├── baseline-B/<preset>/<image>.png   (80 files, post-hoc linearized reference)
```

比較ツール:
- `apps/desktop-film-lab-batch/test/golden-psnr.ts` — PSNR
- `apps/desktop-film-lab-batch/test/golden.harness.ts` — pixelmatch (meanAbs +
  changedRatio)

Phase 1 macOS export はまず **baseline-B** との PSNR 比較から始める。

Sidecar contract:
- `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts`
  — Zod schema、reader/writer entry。macOS 側で `parseFilmtoneExportSessionV1()`
  互換 JSON を吐く

### Open design questions for Phase 1 chat

plan の "Open Questions" セクションを Phase 1 で答える:

1. **Best preview path**: CoreImage-only / Metal-only / hybrid。
   Phase 1 still preview は CoreImage で始めるのが楽 (CIImage + NSImageView)。
   Metal は動画 / optics で必要になった時に投入
2. **`FilmtoneExportSession` の共有戦略**: as-is / split / 選択 port。
   Phase 1 では選択 port (静止画 export 部分のみ)、Phase 2 で動画 export 時に
   split 判断
3. **AVFoundation vs ffmpeg for video**: Phase 1 は静止画のみなので保留。
   Phase 1 後半の video slice で初めて触る。**silent fallback 禁止**
4. **macOS support floor**: 26 only で確定 (user 確認済み、不変)

---

## 7. Reference paths (cheat sheet)

### この worktree (実装する場所)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/
├── CLAUDE.md                                        # project rules、必読
├── README.md                                        # workspaces + scripts
├── package.json                                     # bun scripts
├── apps/
│   ├── filmtone-desktop-macos/                     # ★Phase 1 で拡張
│   │   ├── README.md
│   │   ├── FilmtoneDesktop.xcodeproj/
│   │   └── FilmtoneDesktop/...
│   ├── capacitor-film-lab-ios/                     # ★参照のみ、編集禁止
│   │   ├── CLAUDE.md                               # iOS 専用 invariants
│   │   └── ios/App/App/                            # iOS Swift sources
│   └── desktop-film-lab-batch/                     # ★編集禁止、parity 参照
│       ├── test/golden/                            # baseline-A/B
│       ├── src/renderer/export-metadata-session.ts # sidecar contract
│       └── src/renderer/video-export-webcodecs.ts  # 静止画 export 参考
├── packages/
│   ├── film-lab-core/src/
│   │   ├── ios-swift-payload.ts                   # Phase0 generator pure 関数
│   │   ├── phase0-schema.ts                        # PHASE0_PARAM_KEYS 等
│   │   ├── presets.ts                              # PRESETS + CONTRACT_DEFAULTS
│   │   ├── source-profile-conversion.test.ts       # parity test
│   │   └── ...
│   ├── film-lab-renderer/                          # WebGPU/WebGL backend
│   │   └── dist/                                   # tracked、submodule 用
│   └── film-lab-smart-look/dist/                   # 同上
├── scripts/
│   ├── generate-filmtone-swift.ts                  # canonical generator
│   ├── generate-filmtone-ios-swift.ts              # shim
│   ├── verify-ios.sh
│   ├── verify-desktop.sh
│   └── verify-phase0-contract.sh
└── docs/filmtone/desktop/
    ├── filmtone-native-desktop-transition-plan-2026-05-03-jst.md  # 全体計画書
    └── filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md  # この doc
```

### Phase 0 設計判断のメモ (worktree 外、~/.claude/plans/)

```
/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md
  — なぜ SPM を Phase 0 から外したか
  — なぜ SharedGenerated を Compile Sources から外したか
  — UUID 命名規約
  — 全体計画書 Phase 0 の plan-mode 議論のフル記録
  — Initial Plan Review (P1/P2 修正記録)
```

### life truth scripts (state 確認用、必要時に呼ぶ)

```
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼**。`FILMTONE_REPO_ROOT` env
で root 上書き可 (worktree を指す時に使う)。

---

## 8. Verify commands (cheat sheet)

```bash
# 全実行は worktree 内で
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# Phase 0 sanity check (新 chat 開始時に必ず実行)
bun run build:core
bun run generate:swift
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
# expect: identical

bun run verify:macos
# expect: ** BUILD SUCCEEDED **

open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# expect: window with toolbar + Liquid Glass control group launches

# iOS lane 無傷確認
bun run verify:ios
FILMTONE_REPO_ROOT=$PWD /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh

# Electron 無傷確認
git status apps/desktop-film-lab-batch/
# expect: empty
```

---

## 9. Active Risks for Phase 1

| Risk | 対策 |
|---|---|
| iOS 側型を macOS にコピーすると iOS 改修時に drift | 生成器に対象型の hash を埋め込み、コピー版が古いとビルド時に warn する小ツール (Phase 1 内で 30 分仕事) |
| macOS の CoreImage 結果が WebGPU と微差 | Phase 1 ではまず PSNR > 35dB 程度の loose tolerance で受ける。perfect parity は Phase 2 |
| Sidecar Zod schema が膨大で Swift 表現が手間 | 必須フィールドのみ初版で吐く (`exportedAtIso` / `appVersion` / `gradeParams` / `batchPresetChoice` or `batchLookChoice`)。optional は Phase 2 |
| AVFoundation 動画 export で edge format 拒否 | Phase 1 は H.264 mp4 のみ、ffmpeg fallback は **書かない**。silent downgrade 禁止 (plan rule) |
| OpticalFilters lane が main で landing → このリポに合流時の conflict | 合流時に `targets[]` ループへ optical generator 呼び出しを追加するだけ。trivial |
| **Look Unification lane** が Phase 1 着手時に未着地 | macOS sidecar emitter は Look canonical (`lookId` / `lookVersion`) で書く。Electron reader 側 dual-emit catch-up は Look Unification 側の責務。詳細 §11.5 |
| **Look Unification lane** が Phase 1 中に main へ landing し、本 worktree との合流が必要 | Phase 1 を一旦区切り、main を rebase で取り込んでから sidecar contract を Look Unification の dual emit に揃える。conflict は film-lab-core の re-export 部分が中心、解消は機械的 |
| Phase 1 が大きすぎて context budget 超過 | Phase 1a (precondition + 静止画 open + preview) と Phase 1b (export + sidecar + parity) と Phase 1c (動画 slice) に分割可。判断は途中での chat 状態次第 |

---

## 10. Phase 0 commit 待ち時の対処

新 chat が `git log` を見て Phase 0 commit が **入っていない** 場合:

```
git status (worktree) で次が見える想定:
  M  .gitignore
  M  package.json
  M  scripts/generate-filmtone-ios-swift.ts
  ?? scripts/generate-filmtone-swift.ts
  ?? apps/filmtone-desktop-macos/
  ?? docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
  ?? docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md
```

新 chat の最初の発話で user に Phase 0 commit を依頼:

```
user, before Phase 1 starts, please commit Phase 0:
  git add -A
  git commit -m "feat(macos): Native Desktop v2 Phase 0 (skeleton + plan + generator dual-target)"
```

git は user 実行原則 (CLAUDE.md §3 + life §11)。新 chat が auto commit
してはいけない。

---

## 10.5 Concurrent Lane: Desktop Look Unification

main checkout 側で並行する **Desktop "Preset → Look" vocabulary 統一**作業
が走っている。本 worktree (`feature/native-desktop-plan`) と直接の git 接点
は無いが、Phase 1 の sidecar / batch session emitter 設計が直接影響を受ける。

全体計画書の split doc
`docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/03-migration-and-concurrent-lanes.md`
に詳細統合済。**Phase 1 着手前に必ず読む**。

### 要点 (Phase 1 chat に必要な部分だけ)

- Look Unification 元ハンドオフ: `/Volumes/SamsungPortableSSDX5001/documents/
  forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-
  handoff-2026-05-03-jst.md` (main checkout 側)
- Look Unification は branch + worktree が一度喪失。Phase A (core/schema 加算)
  は完了して verify 通過済、Phase B (Electron renderer + film-lab-ui sweep)
  は部分完了で worktree 喪失
- Status 確認: main checkout で
  `git log --oneline | grep -i "look unification\|baselook"` または
  `grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts`

### Phase 1 sidecar emission の分岐

| Look Unification main 着地状況 | Phase 1 macOS sidecar emitter |
|---|---|
| **着地済** (BASE_LOOKS export あり、grade-io.ts に `lookId` あり) | dual emit (`lookPresetId` + `presetVersion` legacy + `lookId` + `lookVersion` Look canonical)。`normalizeFilmLookGradeInputIdentity` 通過確認 |
| **未着地** (旧 PRESETS のみ) | **Look canonical のみ** で emit (`lookId` / `lookVersion`)。Electron 側 reader 互換は Look Unification 側の責務、Phase 1 は気にしない |

どちらにせよ macOS app は `lookId` / `lookVersion` を **必ず吐く**。schema
version bump は禁止 (本 plan §Data Contract additive only)。

### Look Unification が定めた canonical 名 (Phase 1 で使う)

Look Unification main 着地後に `film-lab-core` から import 可能になるシンボル
(着地前は旧 Preset 名で参照、着地後は Look 名で参照に切り替え):

| 旧 (現状) | 新 canonical (Look Unification 着地後) |
|---|---|
| `PresetName` | `BaseLookName` |
| `PRESETS` | `BASE_LOOKS` |
| `PRESET_VERSION` | `LOOK_RECIPE_VERSION` |
| `lookIdForPreset` | `lookIdForBaseLook` |
| `LOOK_ID_BY_PRESET` | `LOOK_ID_BY_BASE_LOOK` |
| `findMatchingPreset` | `findMatchingBaseLook` |
| `gradeMatchesPreset` | `gradeMatchesBaseLook` |
| `FILMTONE_DEFAULT_BASE_PRESET` | `FILMTONE_DEFAULT_BASE_LOOK` |

**旧 Preset 名は alias として残る** (Look Unification PR で alias 維持を決定
済)。Phase 1 macOS app は **着地後に書くなら最初から Look 名で書く** (migration
debt なし)。

### Phase 1 で **触らない** Look Unification 関連 (本 lane の責務)

- Electron renderer の `batchPresetChoice` / `canvasPreset` /
  `batchGradeStateFromPreset` rename
- `messages/en.json` / `ja.json` の `controls.presets` 系の値書き換え
- `film-lab-ui` の `PresetSearchSelect.tsx` → `LookSearchSelect.tsx` rename
- `film-lab-reducer.ts` の State `basePreset` → `baseLook`、Action `APPLY_PRESET`
  → `APPLY_BASE_LOOK`
- `lookSource` enum `"preset"` → `"builtInLook"` の parser fallback
- iOS messages.ts / FilmtoneStrings.swift catch-up

これらは **すべて Look Unification lane の責務**。Phase 1 macOS app は
sidecar contract のみ揃える。

### Phase 5 release gate との関係

本 plan の Phase 5 (External Shell And Release QA) に進む前に **Look
Unification が main へ landed していること** が gate 条件 (vocabulary 不統一の
まま public release しない)。Phase 1-4 の間に Look Unification が遅れたら、
Phase 4 完了時点で Look Unification を merge してから Phase 5 に入る。

---

## 11. その他 context

### 既知の memory entries (`/Users/chibatakumi/.claude/projects/.../memory/`)

新 chat にも自動 load される:

- `feedback_auto_mode_no_decision_handoff.md` — auto mode + plan approved →
  実行する、user に decision punt しない
- `feedback_dont_overengineer_dirty_state_split.md` — in-flight work は 1
  commit に bundle、unstage / patch-split しない (user 指示なき限り)
- `feedback_no_promising_from_forced_substage.md` — forced boundary stage cost
  は ranking 用、speed promise には使わない
- `project_v15_metal_optics_lane.md` — iOS v1.5 Metal optics、Phase 1 perf
  passed 95.6s、quality gate (視覚 A/B) PENDING (Phase 1 で iOS Xcode に
  触らない理由)
- `reference_devicectl_env_var_launch.md` — `xcrun devicectl device process
  launch --environment-variables` で実機 env var

### 5 ロール憲法 (life)

life `docs/guides/` 配下に存在。Filmtone 関連は本 chat / Phase 1 chat の
範囲では触らない (本質は production code)。

---

## 12. 引き継ぎ詳細プロンプト (新 chat に貼る用)

ここまでの情報を最高密度で運ぶプロンプト。**新 chat の最初の発話に貼る**:

```
このリポは Filmtone (forestone film-lab 系プロダクト)。今は Native Desktop v2
の Phase 0 (Contract & Skeleton) が完了したばかりで、Phase 1 (vertical slice:
still 1 枚 open → preview → grade → still export → sidecar → golden parity、
さらに動画 1 個の slice) を進めたい。

作業 worktree:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
branch: feature/native-desktop-plan

最初に必ず以下を順番に読んで前 chat の文脈を完全復元してから作業に入る:

1. docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md
   ← この一本に Phase 0 の全完成記録 + Phase 1 scope + invariants + open
   decisions + verify commands + risks + concurrent lane (§10.5 Look
   Unification) が exhaustive にまとまっている。絶対に skim ではなく全文読む。

2. docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
   全体計画書 index。Phase 1 acceptance gate は split doc `04-phase-plan.md`、
   UI principles / risk responses は `04-phase-plan.md` と
   `06-quality-gates-risks.md`、Look Unification との接続は
   `03-migration-and-concurrent-lanes.md` が正本。

3. /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md
   並行 lane の Look Unification 元ハンドオフ (main checkout 側)。Phase 1 の
   sidecar dual emit / `lookId` / `lookVersion` / `BASE_LOOKS` 等の canonical
   契約はここが正本。

4. apps/filmtone-desktop-macos/README.md
   Phase 0 macOS app の self-doc。SharedGenerated を Compile Sources から
   外している理由とその解除タイミングがここに書いてある。

5. /Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md
   Phase 0 の plan-mode 設計議論記録。なぜ SPM を Phase 0 から外したか、
   pbxproj UUID 命名規約、Initial Plan Review (P1/P2) の経緯。

6. CLAUDE.md (worktree root) — project rules
7. apps/capacitor-film-lab-ios/CLAUDE.md — iOS invariants

読み終わったら以下を実行して Phase 0 が現在も動くこと + Look Unification の
main 着地状況を sanity check:

  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
  git log --oneline -5
  bun run build:core
  bun run generate:swift
  diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
          apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
  bun run verify:macos
  bun run verify:ios

  # Look Unification main 着地確認 (main checkout 側)
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
  git log --oneline | grep -iE "look unification|baselook" | head
  grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts || echo "Look Unification not yet landed"

全部通ったら Phase 1 の planning に入る。**最初に user に確認すること**:

(a) Phase 0 が commit 済みか? 未 commit ならまず commit を依頼 (git は user
    実行)。
(b) Phase 1 precondition (SharedGenerated を compile-link 可能にする) の
    Decision A (型 dep を macOS にコピー、Phase 2 で SPM 集約) と Decision B
    (Phase 2 を先行して SPM を今作る) のどちらで進めるか。**推奨は A** (本質
    優先 / 外殻最小)。
(c) Phase 1 を 1 PR でまとめるか、1a (precondition + open + preview) /
    1b (export + sidecar + parity) / 1c (動画 slice) に分けるか。
(d) Look Unification main 着地状況に応じた sidecar emission 方針:
    着地済 → dual emit (legacy + Look canonical)、未着地 → Look canonical
    のみ (handoff doc §10.5 参照)。

絶対に守る invariants (handoff doc §5 参照):
- iOS Xcode project (apps/capacitor-film-lab-ios/) を編集しない (v1.3 lane
  in-flight)
- Electron desktop (apps/desktop-film-lab-batch/) を編集しない
- packages/film-lab-renderer/dist/ packages/film-lab-smart-look/dist/ を消さ
  ない (submodule 用 track)
- 生成 Swift (FilmtonePhase0Generated.swift) を手編集しない、generator のみ
- iOS と macOS の Phase0Generated.swift は bit-identical を維持
- sidecar / batch session schema の **version bump 禁止** (additive only、
  Look Unification も同方針)
- bun mandatory、npm 禁止
- 用語ロック: `動画` / `video`、`短尺動画` 禁止 / `Preset` の新規追加禁止
  (Look Unification 完了に向けて Look canonical を使う)
- git は user 実行 (auto commit 禁止)
- Look Unification lane の作業 (Electron renderer rename / film-lab-ui rename
  / messages.json 値書き換え 等) は **Phase 1 では絶対に触らない**。Look
  Unification 側の責務

設計判断は sequential-thinking で考える。記憶ベース断言は禁止。不確かな API
は gemini-search / web search で確認 (Liquid Glass / AVFoundation /
CoreImage / Metal の最新仕様)。

handoff doc を読み終えたら、まず読んだ要約を 5 行で出して、上記 (a)(b)(c)(d)
を user に確認すること。
```

これを丸ごとコピーして新 chat の 1 発目に貼る。

---

## 13. このドキュメント自身について

- 作成者: 前 chat (Phase 0 実装担当)
- 作成時刻: 2026-05-03 JST
- 更新タイミング: Phase 1 完了時に Phase 2 handoff として書き直す。または
  Phase 1 が分割された場合は Phase 1b/1c handoff を別ファイルで作る
- canonical naming: `filmtone-native-desktop-phaseN-next-chat-handoff-{date}-jst.md`
