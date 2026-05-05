# Filmtone Native Desktop v2 — Phase 1b Master Handoff (Self-Contained)

Date: 2026-05-03 JST
Source chat: Phase 0 (Skeleton) + Phase 1a (Open + Preview precondition)
実装 chat — 同一日中に両 phase 完了
Target chat: Phase 1b (preset 選択 → grade 適用 → still export → sidecar JSON
→ Electron baseline-B との PSNR parity) 実装 chat
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

このドキュメントは **完全自己完結型 master handoff**。これ 1 本だけ精読すれば、
前 chat で行われた議論・採択・実装・検証・残タスクを全て再現できる構成。
他の handoff doc (`phase1-next-chat-handoff` / `phase1b-next-chat-handoff`)
は historical record として残しているが、参照は **必要に応じて** で良い。
全体計画書 (`filmtone-native-desktop-transition-plan-2026-05-03-jst.md`) は
原文として最後に確認推奨だが、Phase 1b 実行に必要な要点はこの doc に転記済。

---

## 0. Read-this-first 順序

新 chat の最初の 15-20 分:

1. **このドキュメント全体** (700+ 行、skim 禁止、§0 から §17 まで通読)
2. `CLAUDE.md` (worktree root) — project rules、§3 運用原則 / §6 antipattern
   は実行中に違反しないため必須
3. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (Phase 1b で iOS
   Swift を lift する時の境界)
4. `apps/filmtone-desktop-macos/README.md` — Phase 0 + 1a の self-doc
5. **全体計画書 split index**:
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   は **canonical index (短い)**。詳細は split files
   `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/` 配下:
   - `01-current-state-and-decision.md` — status / purpose / product decision
   - `02-target-architecture-and-contracts.md` — app shell / render core / data contract
   - `03-migration-and-concurrent-lanes.md` — **Look Unification 依存 (必読)**
   - `04-phase-plan.md` — Phase 0-5 deliverables / acceptance gate / verify
   - `05-future-lanes.md` — Continuity Export / Resolve / Pro NLE
   - `06-quality-gates-risks.md` — quality gates / open questions / risks / DoD
6. **Look Unification lane handoff (main checkout 側)**:
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
   — sidecar dual emit / `lookId` / `lookVersion` / `BASE_LOOKS` 等の canonical
   contract。**Phase 1b の sidecar emitter はこれに従う** (詳細は本 doc §6.5)
7. `git log --oneline -10` で worktree commit 状態確認 (Phase 0 + 1a が
   commit 済みか)
8. **必ず実行**: §11 の Phase 1a sanity check + Look Unification main 着地
   状況確認 (`bun run verify:macos` / `bun run verify:ios` / generator drift /
   `BASE_LOOKS` export 有無 / sidecar reader discriminator)

optional (深掘り時のみ):
- `~/.claude/plans/luminous-sparking-eclipse.md` — Phase 0 plan-mode 設計議論
  記録 (なぜ SPM を Phase 0/1 から外したか、UUID 規約、Initial Plan Review)
- `~/.claude/plans/desktop-look-unification-bright-dusk.md` — Look Unification
  lane の元 plan
- `docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
  — 親 handoff (Phase 0 完成記録 + §10.5 Concurrent Lane の完全版)
- `docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
  — 子 handoff (Look Unification 反映済の partial 版)

---

## 1. What is Filmtone (1 段落 context)

Filmtone は forestone (`chiba@fores-tone.co.jp`) の film-tone カラー
グレーディング製品群:

- **Filmtone Desktop** (Electron + React/Vite, macOS) — 写真 / 動画の film-tone
  バッチグレーディング。release rail として shipping 中。
- **Filmtone iOS** (Capacitor + SwiftUI/Metal/CoreImage) — App Store 公開、
  v1.2 public / v1.3 local candidate in-flight (lane `project_v15_metal_optics_lane`)。
- **共有 packages**:
  - `film-lab-core` — Phase0 params / preset / source-profile contract、Zod schema、
    Swift generator pure 関数の正本
  - `film-lab-renderer` — WebGL / WebGPU shader graph、`dist/` は portfolio
    submodule 用に **意図的に track**
  - `film-lab-ui` — shared React UI
  - `film-lab-smart-look` — `dist/` track (同上)

このリポは **実装の正本**。portfolio (`vendor/filmtone` submodule) と life
(`/Volumes/SamsungPortableSSDX5001/documents/life/`) は別役割
(docs/guides・truth scripts・5 ロール憲法)。

---

## 2. Repo / Worktree Topology

### Repos

| repo | path | 役割 | 編集可否 |
|---|---|---|---|
| **このリポ (worktree)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0/1a/1b の実装 worktree、branch `feature/native-desktop-plan` | **編集対象** |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ | 編集禁止 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 (`apps/web`)、`vendor/filmtone` submodule で消費 | Phase 1b 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts + 5 ロール憲法 | Phase 1b 触らない |

### Worktree branch invariants

- Phase 0 + Phase 1a + Phase 1b は同一 branch `feature/native-desktop-plan`
- Phase 0 + 1a は **1 commit に bundling 済** (推奨)
- 別 branch を切る必要は **なし**。PR 切るのは Phase 1c 完了時 (Phase 0 +
  1a + 1b + 1c 同一 PR、または分割 PR は user 判断)
- main checkout の dirty / untracked にある OpticalFilters 関連ファイル
  (`packages/film-lab-core/src/ios-optical-filter-payload.ts` 等) は
  **このワークツリーには来ていない**。lane が main へ landing 後に取り込む
  方針 (Phase 0 Out of Scope に明記済み)

### Tooling versions (Phase 0 + 1a で verified working)

- macOS 26.4.1 (Build 25E253)
- Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3
- Swift 6.0 (target setting; toolchain は Xcode 26 同梱)

これらより古い env では Liquid Glass API がコンパイル通らない。

### 認証 / 環境

- Git user: `chibataku0815` (commit 自体は user 実行、auto commit 禁止)
- Email: `chiba@fores-tone.co.jp`

---

## 3. Native Desktop v2 全体計画 (要約)

Filmtone Desktop を **Electron 製 macOS アプリ** から **SwiftUI / AppKit
ベースの Native Desktop v2 (Liquid Glass first-class)** へ移行する lane。

### 移行戦略

並行 lane: 現行 Electron Desktop は **release rail として shipping し続け**、
Native Desktop v2 が phase gate を通るまで default にしない。Phase 4
(Native Capability Replacement) で機能網羅を達成した後に default を切り替える。

### macOS 26 only (確定)

- macOS 26 SDK で build した SwiftUI `.toolbar` / `NSToolbar` は **自動的に
  Liquid Glass を採用**。コードを書く必要なし
- `.glassEffect(.regular, in: Capsule())` は macOS 26.0+ / iOS 26.0+ /
  iPadOS 26.0+ / watchOS 26.0+ / tvOS 26.0+
- reduced-material fallback は **書かない** (user 確認済み、Phase 0 で確定)
- design rule (Apple HIG): glass は **navigation / control 層のみ**。
  content / preview には当てない

### Phase 段階

| Phase | scope | 状態 |
|---|---|---|
| **0 (Contract & Skeleton)** | macOS app skeleton + 生成 Swift dual-target emit + Liquid Glass API surface 確認 | **COMPLETE** (今 chat) |
| **1a (Open + Preview precondition)** | SharedGenerated を compile-link、NSOpenPanel + still preview (grade なし) | **COMPLETE** (今 chat) |
| **1b (Vertical Slice — still)** | preset 選択 + grade 適用 + still export + sidecar JSON + Electron baseline-B parity | **次 chat (Phase 1b)** |
| **1c (Vertical Slice — video)** | 動画 1 個 open + preview frame + H.264 mp4 export | Phase 1b 後 |
| **2 (Native Color/Export Backbone + SPM)** | `packages/film-lab-swift-core/` SPM 化、iOS の grade pipeline 移管、`Domain/Phase0Types.swift` 削除 → import 切替 | TBD |
| **3 (Asset Pipeline & Mezzanine)** | source profile / LUT / cube parser / mezzanine cache の native 統合 | TBD |
| **4 (Native Capability Replacement)** | Electron 機能網羅、release default 切替判断 | TBD |
| **5 (Polish & Public Cutover)** | LP / release notes / portfolio submodule update | TBD |

### 優先順位 (全体計画書原文より)

1. 画の品質、色の正しさ、preview / export の一致
2. Apple 純正 UI / Liquid Glass / macOS 操作体系への適合
3. iOS 版とのネイティブ資産共有
4. 現行 Desktop リリース導線の維持
5. 外殻 QA / public copy / release 周辺整備 (**最後**)

---

## 4. Phase 0 完成記録 (Skeleton + Contract)

### Acceptance gate 結果 (全 PASS)

| # | 検証 | 結果 |
|---|------|------|
| 1 | `bun run build:core` | SUCCESS (148 KB ESM + 70 KB DTS) |
| 2 | `bun run generate:swift` | iOS / macOS 両方 emit、bit-identical |
| 2a | iOS git diff (vs HEAD before refactor) | **空** (bit-identical 保持) |
| 2b | iOS vs macOS Phase0Generated.swift | `diff -q` IDENTICAL |
| 3 | `bun run generate:ios-swift` (shim) | dispatch 動作、emit 同一 |
| 4 | `bun run generate:swift -- --check` | exit 0 |
| 5 | `bun run verify:ios` | exit 0、Phase0 contract / motion blur / cube parser / cache store / source-color-classifier / ray-angle optics / source profile math (D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000) / sidecar builder pass |
| 6 | `bun run verify:macos` | `** BUILD SUCCEEDED **` |
| 7 | App launch | `co.fores-tone.filmtone.desktop` / LSMinimumSystemVersion 26.0、PID 取得確認 |
| 8 | `git status apps/desktop-film-lab-batch/` | empty (Electron unchanged) |
| 8b | `git status apps/capacitor-film-lab-ios/` | empty (iOS unchanged) |

### Files (Phase 0 commit に入る分)

```
M  .gitignore                                        (build/ 除外、dist 例外維持)
M  package.json                                      (verify:macos 等 scripts)
M  scripts/generate-filmtone-ios-swift.ts            (shim 化、3 行)
?? scripts/generate-filmtone-swift.ts                (新 multi-target generator、52 行)
?? docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
?? apps/filmtone-desktop-macos/
   ├── README.md
   ├── FilmtoneDesktop.xcodeproj/
   │   ├── project.pbxproj
   │   ├── project.xcworkspace/contents.xcworkspacedata
   │   └── xcshareddata/xcschemes/FilmtoneDesktop.xcscheme
   └── FilmtoneDesktop/
       ├── App/
       │   ├── FilmtoneDesktopApp.swift              (@main, WindowGroup, Commands)
       │   └── AppCommands.swift                     (Help menu link 1 個)
       ├── UI/
       │   ├── RootWindowView.swift                  (toolbar + preview placeholder)
       │   └── GlassControlGroup.swift               (.glassEffect(.regular, in: Capsule()))
       ├── SharedGenerated/
       │   └── FilmtonePhase0Generated.swift         (generator 出力、Phase 0 時点では Compile Sources 外)
       └── Assets.xcassets/
           ├── Contents.json
           └── AppIcon.appiconset/Contents.json
```

`apps/filmtone-desktop-macos/build/` は xcodebuild output、`.gitignore` で除外。

### Generator multi-target 構造

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
が main の untracked ファイル (`packages/film-lab-core/src/ios-optical-filters-swift.ts`)
にしかないため。main で OpticalFilters lane が landing したら、`targets[]`
ループに同様の generator 呼び出しを追加するだけ (trivial 拡張)。

### Xcode project 構造

- **手書きの project.pbxproj** (xcodegen 等使わず)。理由: bun monorepo に
  外部 Swift toolchain を足したくない / target 1 個のみ / merge conflict 耐性
- **objectVersion = 70** (`compatibilityVersion = "Xcode 16.0"`、Xcode 26 で
  受理確認)
- **UUID convention**: 24-char hex with `FT0000000000000000000XXX` prefix。
  reproducible / merge-conflict 強。新規ファイル追加時は **既存最大値の次** を
  割り当てる
- **GENERATE_INFOPLIST_FILE = YES** — Info.plist は build setting から自動
  生成 (`PRODUCT_BUNDLE_IDENTIFIER` 等)。明示的 Info.plist ファイルは作って
  いない
- **Bundle id**: `co.fores-tone.filmtone.desktop` (iOS と区別)
- **Deployment target**: macOS 26.0
- **SWIFT_VERSION**: 6.0
- **ENABLE_HARDENED_RUNTIME**: YES (Debug でも、code sign は ad-hoc)

### Phase 0 時点の Compile Sources

`FilmtoneDesktopApp.swift`, `AppCommands.swift`, `RootWindowView.swift`,
`GlassControlGroup.swift` の 4 個。`SharedGenerated/FilmtonePhase0Generated.swift`
は **PBXFileReference 自体作っていない** (Xcode が project navigator で見えない、
disk 上の contract artifact のみ)。**Phase 1a で取り込み済**。

### SwiftUI 構成 (Phase 0)

- `@main FilmtoneDesktopApp` — `WindowGroup("Filmtone Desktop")`、
  `windowResizability(.contentMinSize)`、`commands { AppCommands() }`
- `RootWindowView` — `ZStack(alignment: .topTrailing)` で preview placeholder
  + 右上 floating GlassControlGroup。`.toolbar` (macOS 26 SDK で自動 Liquid
  Glass)、左に `camera.aperture` SF Symbol、右に Open ボタン (Phase 1 で
  enable)
- `GlassControlGroup` — `HStack` に `play.fill` / "Phase 0" / `circle.dashed`、
  padding 後に `.glassEffect(.regular, in: Capsule())`

### Liquid Glass facts (verified Phase 0)

- `glassEffect(_:in:)` は macOS 26.0+ / iOS 26.0+ / iPadOS 26.0+ /
  watchOS 26.0+ / tvOS 26.0+
- `GlassEffectContainer` も同じ available 範囲
- 標準 SwiftUI `.toolbar` / `NSToolbar` は **macOS 26 SDK で build すると
  自動的に Liquid Glass を採用**。コードを書く必要なし
- design rule (Apple HIG): glass は navigation/control 層のみ。content/preview
  には当てない

参照 URL:
- https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)
- https://developer.apple.com/documentation/swiftui/glasseffectcontainer
- https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass

---

## 5. Phase 1a 完成記録 (Open + Preview Precondition)

### Decision A vs B → A 採択

Phase 0 で deferred した「`SharedGenerated` を compile-link 可能にする」
precondition の 2 案:

#### Decision A: 型 dep を macOS target にコピー (採択)
- iOS の `FilmtonePhase0Math.swift` + `FilmtoneMediaTypes.swift` から
  generated file が依存する 4 struct (`FilmtoneQuickState` /
  `FilmtonePhase0Params` / `Phase0OutputProfileDTO` /
  `FilmtonePhase0HiddenDefaults`) を **memberwise init + stored properties
  のみ** で macOS target にコピー
- iOS 側は **完全に無触**、duplication は temporary
- Phase 2 で SPM 集約する時に macOS 側コピーを削除して package import に
  切り替え
- リスク: iOS 側で型が変わると macOS 側が drift。**生成器に依存型 hash
  チェックを追加する手も** (Phase 2 候補)

#### Decision B: Phase 2 を先行して SPM を今作る (棄却)
- `packages/film-lab-swift-core/` を `swift-tools-version: 6.2` で作成
- ColorPipeline / SourceProfileMath / CubeParser / LutBlobCodec /
  Phase0Generated 等を SPM に集約
- iOS Xcode project は触らず — iOS は引き続き local copy を消費。
  Phase 2 後半で iOS を SPM 消費に切り替え
- 利点: 綺麗、duplication なし
- 棄却理由: Phase 0 で deferred した複雑さを今 Phase 1a で背負うのは
  「本質優先 / 外殻最小」(CLAUDE.md §3) 違反

### 採択理由 (本質優先 / 外殻最小)

Phase 1 / 1b の本質は **color / render / export**。SPM 化は Phase 2 で
iOS 移管とまとめてやる方が **触る面積が小さい** (iOS Xcode project は v1.3
local candidate lane in-flight、SPM 移管時に 1 回だけ触りたい)。

### Files added / modified (Phase 1a 分)

```
?? apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift   (新規、75 行)
?? apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift    (新規、51 行)
M  apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift    (NSOpenPanel 配線、46 行)
M  apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj  (BuildFile/FileRef/Group/Sources phase 拡張)
M  apps/filmtone-desktop-macos/README.md                                  (Phase 0+1a 状態反映)
```

### Domain/Phase0Types.swift 設計 (full content)

`apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift`:

```swift
import Foundation

// Minimal type stubs so SharedGenerated/FilmtonePhase0Generated.swift
// compile-links inside the macOS target. Field shapes mirror the iOS
// definitions in apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Math.swift
// and FilmtoneMediaTypes.swift. Phase 2 (SPM packages/film-lab-swift-core)
// absorbs both copies; this file is deleted at that point.

struct FilmtoneQuickState {
    var filmCharacter: Double
    var era: Double
    var dynamics: Double
}

struct FilmtonePhase0Params {
    // 35 stored properties: exposure, contrast, saturation, temperature, tint,
    // rgbShift, lensSoftness, grainRadialMix, grainSize, bloomThreshold,
    // bloomStrength, bloomRadius, diffusion, halationIntensity, halationSpread,
    // halationHue, halationThreshold, halationRadius, bloomSoftKnee,
    // halationSoftKnee, compressionAmount, compressionRange, printContrast,
    // cyan, magenta, yellow, shutterAngle, trailIntensity, fade, shadowTone,
    // highlightTone, shadowHue, highlightHue, vignette, grainIntensity
    // (順序は generated file の paramKeys 配列と一致、変更禁止)
}

struct Phase0OutputProfileDTO {
    var longEdge: Int
    var fps: Int
    var codec: String
    var container: String
    var preserveAudio: Bool
}

struct FilmtonePhase0HiddenDefaults {
    // 19 stored properties: depthMistGain, depthGlowGain, depthRayAngleGamma,
    // depthRayAngleInnerThreshold, depthMistRayAngleGain, depthBloomRayAngleGain,
    // depthHalationRayAngleGain, depthMistFieldPsfGain, depthBloomFieldPsfGain,
    // depthHalationFieldPsfGain, depthMistFieldPsfRadiusPx,
    // depthBloomFieldPsfRadiusPx, depthHalationFieldPsfRadiusPx,
    // crossFilterDepthGain, crossFilterAngleGain, crossFilterAngleGamma,
    // crossFilterAngleInnerThreshold, crossFilterEdgeLengthGain,
    // crossFilterEdgeStrengthGain
}
```

**重要**: method / Codable / DTO graph (`Phase0ParamsDTO`, `ParsedCubeLutDTO`,
`Phase0ExportRequestDTO`, `FilmtoneProjectState` 等) は **意図的に未 port**。
Phase 1b で実際に必要になった分だけ追加する原則。

### pbxproj 変更 (Phase 1a 分)

UUID 割り当て (Phase 0 の最大値 A05 / B05 / E04 + E06 の次):

| UUID | 種別 | 対象 |
|---|---|---|
| `FT0000000000000000000A06` | PBXBuildFile | Phase0Types.swift in Sources |
| `FT0000000000000000000A07` | PBXBuildFile | FilmtonePhase0Generated.swift in Sources |
| `FT0000000000000000000A08` | PBXBuildFile | PreviewSurface.swift in Sources |
| `FT0000000000000000000B06` | PBXFileReference | Phase0Types.swift |
| `FT0000000000000000000B07` | PBXFileReference | FilmtonePhase0Generated.swift |
| `FT0000000000000000000B08` | PBXFileReference | PreviewSurface.swift |
| `FT0000000000000000000E05` | PBXGroup | Domain |
| `FT0000000000000000000E07` | PBXGroup | SharedGenerated |

Group 構造 (FilmtoneDesktop group の children):
- `App` (E03) — FilmtoneDesktopApp.swift, AppCommands.swift
- `UI` (E04) — RootWindowView.swift, GlassControlGroup.swift, **PreviewSurface.swift**
- **`Domain` (E05) — Phase0Types.swift** (NEW)
- **`SharedGenerated` (E07) — FilmtonePhase0Generated.swift** (NEW)
- `Assets.xcassets` (B05)

PBXSourcesBuildPhase (11A1) files に A06/A07/A08 を追加。

### RootWindowView 配線 (Phase 1a 後の full content)

```swift
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct RootWindowView: View {
    @State private var imageURL: URL?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PreviewSurface(imageURL: imageURL)
            GlassControlGroup()
                .padding(20)
        }
        .frame(minWidth: 880, minHeight: 560)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Image(systemName: "camera.aperture")
                    .symbolRenderingMode(.hierarchical)
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    presentOpenPanel()
                } label: {
                    Label("Open", systemImage: "folder")
                }
                .keyboardShortcut("o", modifiers: .command)
                .help("Open a still image")
            }
        }
    }

    private func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"
        panel.message = "Choose a still image to preview"
        if panel.runModal() == .OK, let url = panel.url {
            imageURL = url
        }
    }
}
```

### PreviewSurface 実装 (full content)

```swift
import AppKit
import SwiftUI

struct PreviewSurface: View {
    let imageURL: URL?

    var body: some View {
        Color.black
            .overlay {
                if let imageURL {
                    PreviewImageView(imageURL: imageURL)
                } else {
                    EmptyPreviewLabel()
                }
            }
    }
}

private struct PreviewImageView: NSViewRepresentable {
    let imageURL: URL

    func makeNSView(context: Context) -> NSImageView {
        let view = NSImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.imageAlignment = .alignCenter
        view.imageFrameStyle = .none
        view.isEditable = false
        return view
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.image = NSImage(contentsOf: imageURL)
    }
}

private struct EmptyPreviewLabel: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.secondary)
            Text("Open a still image to preview")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }
}
```

設計ポイント:
- 外側: `Color.black` 背景 (color judgment 用、Apple HIG: content 層に glass を
  当てない原則維持)
- 内側分岐: `imageURL` あり → `PreviewImageView` (NSViewRepresentable)、
  nil → `EmptyPreviewLabel` (SF Symbol `photo` + caption)
- `updateNSView` で `NSImage(contentsOf: imageURL)` を毎回 reload
  (Phase 1a は最適化なし、Phase 1b で grade pipeline 経由に置き換わるので
  そのタイミングで cache 戦略決める)

### Phase 1a Acceptance gate 結果 (全 PASS)

| # | 検証 | 結果 |
|---|------|------|
| 1 | `bun run verify:macos` (Phase 1a 後) | `** BUILD SUCCEEDED **` |
| 2 | `bun run generate:swift -- --check` | exit 0 (drift なし) |
| 3 | `diff -q` iOS vs macOS Phase0Generated.swift | bit-identical 保持 |
| 4 | `bun run verify:ios` | D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000、sidecar pass |
| 5 | `git status apps/capacitor-film-lab-ios/` | clean (iOS lane 無傷) |
| 6 | `git status apps/desktop-film-lab-batch/` | clean (Electron lane 無傷) |

### 残された手動 smoke (CLI から GUI 操作不可)

新 chat 開始前に user が確認しているはず:
```
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# 起動 → ⌘O → 画像選択 → 中央に表示
```

---

## 6. Critical Invariants (絶対に壊さない、final consolidated)

### 境界 (Phase 0 + 1a で立てた)

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** —
   v1.3 local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。
   Phase 1b で iOS Swift から型を **read-only 参照 + 内容コピー** するのは OK
   だが、iOS の `.pbxproj` には触らない
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** —
   release rail。Phase 4 で current-capability replacement に到達するまで
   shipping rail として残す。**parity 比較で test fixture を read するのは OK**
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/`
   を消さない** — submodule 即 import 用に track 維持。`.gitignore` に
   `dist` を追加しない (CLAUDE.md §6 antipattern #2)
4. **`packages/film-lab-core/src/` の contract source は変更しない** —
   generator は pure 関数を呼ぶだけ。Phase 1b の sidecar schema 拡張が必要なら
   **別 lane** で議論する
5. **生成 Swift を手編集しない** — `bun run generate:swift` の出力のみ。
   ヘッダの `// AUTO-GENERATED ...` コメントが残っている
6. **iOS と macOS の `Phase0Generated.swift` は bit-identical** — どちらかが
   ずれたら generator バグ。`diff -q` で常時確認可
7. **`Domain/Phase0Types.swift` の field 順序 / 名前を変えない** —
   generated file の memberwise init が壊れる。field 追加 OK だが既存 field の
   順序 / 名前は不変。`FilmtonePhase0Params` の field 順は generated file の
   `paramKeys` 配列と一致している
8. **`SharedGenerated/FilmtonePhase0Generated.swift` は Compile Sources に
   入っている** (Phase 1a で wire 済) — Phase 1b で grade pipeline がここの
   `paramsByName` を参照する想定

### 用語ロック (CLAUDE.md §6 antipattern #5)

- `動画` (× `短尺動画`) / `video` (× `short-form video`)
- canonical: life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
- video vocabulary lock: life commit `5ce6d55` (2026-05-01)

### Bun mandatory (npm 禁止)

- `bun install` / `bun run` / `bun add`
- `bun.lock` が正本
- `package-lock.json` が出現したら削除

### 出力ルール (life CLAUDE.md §11)

- 日本語、技術用語英語可
- ファイル参照: `path/to/file:line` 形式
- 簡潔・行動志向
- **Git 操作は user が実行** (auto commit 禁止)

### 設計判断ルール

- 設計判断は `mcp__sequential-thinking` を使う(記憶ベース断言禁止)
- 不確かな API (CoreImage / CGImageDestination / sidecar Zod schema /
  AVFoundation / Metal) は `gemini-search` → `WebSearch` の順で確認
- handoff doc を引用する前に、現行 surface (`grep` / Swift / pbxproj) と
  突き合わせて live/frozen を確認 (`feedback_verify_before_quoting_handoff`)
- 並列 stream で残タスクの silent 省略禁止 (`feedback_no_silent_stream_redefine`)
- npm publishing を再導入しない (CLAUDE.md §6 antipattern #1)

---

## 6.5. Concurrent Lane: Desktop Look Unification (sidecar contract 依存)

**Native Desktop v2 と並行して進行する lane**。Phase 1b の sidecar 出力契約に
直接影響するので **必ず status を確認してから sidecar emitter を書く**。

### Lane 概要

- branch: `feature/desktop-look-unification`
- chat B worktree (確定、2026-05-03 JST 起動):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`
  (Native Desktop worktree `filmtone-native-desktop-plan` とは **完全分離**)
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
- 再開 handoff (canonical):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
- 状態 (2026-05-03 JST 同日更新): 一度 worktree 喪失 → chat B 起動済 (Phase 1b
  chat A と並列)。Phase A (core/schema 加算) は喪失前に完了 verify 通過、
  chat B は **main への Phase A 着地状況 grep verify から再開** → Phase B
  (Electron renderer + film-lab-ui sweep) を完成させる方針

### chat 間 coordination protocol

- chat 間の直接通信はない、user が橋渡し
- chat A (Phase 1b、本 doc 利用側) は **chat B の worktree
  `filmtone-look-unification` を絶対に触らない**
- chat B は **本 worktree `filmtone-native-desktop-plan` を絶対に触らない**
- chat B が main へ Phase A + B を merged したら user が chat A に通知 →
  chat A は sidecar emitter を Case B (Look canonical only) → Case A
  (dual emit) に切り替え可能になる
- merged 前に chat A が sidecar 着手する場合は Case B で書いて先送り、
  後で Case A 化する選択もアリ (本 doc §10 参照)

### chat B 着手時に確定済の本 PR スコープ方針

| # | 領域 | 方針 |
|---|---|---|
| 1 | `filmLabUiContract.ts` slot 名 (`beforePresets` → `beforeLooks` 等) | alias 残さず一気に rename |
| 2 | `batch-session` writer | `batchLookChoice` 単独 emit (Electron 専用 userData、dual 不要) |
| 3 | テスト fixture | 既存 `"preset"` 残置 (parser fallback regression) + 新規 `"builtInLook"` canonical |
| 4 | iOS messages.ts キー名参照書き換え | **本 PR では実施しない (別 PR)**。i18n 値書き換えで iOS 文字列は自動 Look 化、specific reference rewrite は別 |

### 本質

Desktop の **製品面** から `Preset` の語彙を消し、Edit / Export / Metadata /
Batch session を `Look` 起点に統一する (vocabulary canonical:
`life docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`)。code
identifier の整理は副次。

Electron Desktop は Native Desktop v2 が品質 gate を越えるまで release rail
として残るので、SwiftUI 移行を理由に Electron の Look 統一を捨ててはいけない
(handoff §2 第 2 版判断の誤り教訓)。

### Native Desktop v2 が依存する成果物 (Look Unification 着地で利用可)

- `film-lab-core` の Look-first canonical 名 (旧 Preset 名は alias で残る、
  schema 加算のみ):
  - `BaseLookName = PresetName`、`BASE_LOOKS = PRESETS`、
    `BASE_LOOK_BUTTONS = PRESET_BUTTONS`、
    `FILMTONE_DEFAULT_BASE_LOOK = FILMTONE_DEFAULT_BASE_PRESET`、
    `findMatchingBaseLook = findMatchingPreset`
  - `LOOK_RECIPE_VERSION = PRESET_VERSION`、
    `lookIdForBaseLook = lookIdForPreset`、
    `LOOK_ID_BY_BASE_LOOK = LOOK_ID_BY_PRESET`
  - `filmLookGradeInputSchema` に optional `lookId` / `lookVersion` 追加
  - `normalizeFilmLookGradeInputIdentity()` で identity 不一致 throw
  - `gradeMatchesBaseLook = gradeMatchesPreset` alias
- Desktop sidecar dual emit (legacy + Look 両方を含む):
  - `buildGradeJsonPayload` が `lookId` / `lookVersion` を追加 emit
  - `batch-pipeline` discriminator は `("lookPresetId" in o || "lookId" in o)`
- Batch session contract (additive):
  - `FilmLabBatchSessionV1` の **on-disk shape は固定** (Data Contract の
    "additive only" 制約準拠、version: 1 のまま)
  - parser は `o.batchLookChoice ?? o.batchPresetChoice` で fallback
  - writer は `batchLookChoice` を canonical
- `lookSource` enum:
  - `METADATA_LOOK_SOURCES` に `"builtInLook"` を canonical 追加
  - parser は legacy `"preset"` を `"builtInLook"` として読む
- i18n: `messages/en.json` / `ja.json` の `controls.presets` 系の **値だけ**
  Look 化 + 新 `controls.looks` キー追加

### Phase 1b sidecar 契約 (Look Unification 着地状況で分岐)

**Phase 1b 着手時に main へ Look Unification が landed しているかで動作変更**:

| 状況 | macOS sidecar emitter の動作 |
|---|---|
| **Look Unification landed** | **dual emit** — legacy (`presetName` / `presetVersion`) と Look canonical (`lookId` / `lookVersion`) の両方を吐く。`normalizeFilmLookGradeInputIdentity()` を通せば identity 不一致が即 throw されるので必ず通す。Electron 側 reader の `("lookPresetId" in o \|\| "lookId" in o)` discriminator で両読みされる |
| **Look Unification 未 landed** | **Look canonical only** — `lookId` / `lookVersion` のみで書く。legacy field は省略。Look Unification 着地後に Electron 側 reader が catch-up してから両読みできるようになる |

**判定方法** (Phase 1b chat 開始時に必ず実行):

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
```

- `BASE_LOOKS` export がある + `batch-pipeline` discriminator に `lookId`
  → landed → **dual emit**
- 上記が無い → 未 landed → **Look canonical only**

### iOS catch-up は別 PR (Phase 1b scope 外)

- `apps/capacitor-film-lab-ios/src/lib/messages.ts` の `presetRowAriaLabel` 等
  の参照書き換え
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneStrings.swift:1580` "Preset
  Strength"

これらは Look Unification PR / 本 plan のどちらにも含まれない。Phase 1b chat
は触らない。

### Phase 段階別影響表

| Phase | Look Unification 着地済 | 着地前 |
|---|---|---|
| Phase 0 (skeleton) | 影響なし | 同左 |
| **Phase 1b (今)** | macOS sidecar emitter は **dual emit を継承** | macOS sidecar emitter は **Look canonical のみ**、Electron reader catch-up を待つ |
| Phase 2 (color/render backbone) | 生成 Swift の Look 名 alias を generator 拡張に追加可能 | 生成器拡張は Look Unification 着地待ち |
| Phase 3 (native UI) | i18n 値は Look 化済、macOS app が messages/*.json を消費するなら追加作業なし | macOS app は自前で Look 文言を持ち、後で messages へ統合 |
| Phase 4 (batch / session) | `FilmLabBatchSessionV1` parser fallback / `batchLookChoice` writer 仕様に従う | 旧 `batchPresetChoice` のみ書く |
| Phase 5 (release) | public copy / screenshot / release notes も Look 統一 | **release 前に Look Unification を着地必須** |

---

## 7. Phase 1b Scope (新 chat の本タスク)

### Goal

> Native Desktop が **本物の Filmtone work** を出力できることを 1 still で
> 証明する。Electron / iOS と visually matching な静止画 export + sidecar が
> 出る。

### Deliverables (vertical slice、1 個ずつ)

```
1. preset 選択 (built-in 4 個: reset / iphone / softBlue / amberGlow)
2. preview に grade を反映 (CoreImage path、CIImage chain)
3. still を export (PNG または JPEG、CGImageDestination)
4. sidecar JSON を書く (Desktop schema 互換、必須 field のみ)
5. parity 検証 (Electron baseline-B vs macOS export、PSNR > 35dB)
```

batch UI は **作らない**。1 image / 1 preset で完結。multi-select / queue は
Phase 4 (Native Capability Replacement) の領分。

### Phase 1b Acceptance gate

- export された PNG/JPEG が Finder / QuickTime で repair なしに開く
- 同じ params で Electron `baseline-B/<preset>/<image>.png` と PSNR > 35dB
  (loose tolerance、perfect parity は Phase 2)
- Source profile (D-Log / S-Log3 等) は **未対応 OK** (Phase 1b では sRGB
  入力のみ前提、Camera Profile picker は Phase 2 範疇)
- preview と export が **同じ grade path** を通る (二重実装禁止)
- sidecar JSON が `parseFilmtoneExportSessionV1()` (Electron 側) で読める
  (round-trip テスト不要、parse error なしを目視確認)
- Liquid Glass UI が preview legibility を損ねない
- iOS Xcode project / Electron desktop は無傷 (`git status` empty)
- `bun run verify:macos` 通過、generator drift なし

### Phase 1b で書くべき Swift (predicted)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Domain/
│   └── Phase0Types.swift              (existing、必要なら field 追加可)
├── Color/                              # 新規
│   ├── FilmtoneColorPipeline.swift   (iOS から lift、CoreImage path のみ抽出)
│   └── FilmtonePresetCatalog.swift   (4 preset の参照、generated から引く)
├── Export/                             # 新規
│   ├── FilmtoneStillExporter.swift   (CGImageDestination、PNG/JPEG)
│   └── FilmtoneSidecarWriter.swift   (Desktop sidecar contract 互換 JSON)
├── State/                              # 新規 (or RootWindowView 内の @State 拡張)
│   └── EditorState.swift             (imageURL + presetName + params)
└── UI/
    ├── RootWindowView.swift          (UPDATED: preset picker, Export ボタン)
    ├── PreviewSurface.swift          (UPDATED: grade chain 経由で表示)
    └── GradeControls.swift           (新規、preset picker minimal UI)
```

### UUID 割り当て予算 (Phase 1b)

Phase 1a 最大値 A08 / B08 / E07 の次から:

| UUID | 種別 | 用途 |
|---|---|---|
| A09 ~ A0F | PBXBuildFile | 7 個分余裕 |
| B09 ~ B0F | PBXFileReference | 同上 |
| E08 | PBXGroup | Color |
| E09 | PBXGroup | Export |
| E0A | PBXGroup | State |
| E0B | PBXGroup | (予備) |

---

## 8. iOS Swift Lift 戦略

### `FilmtoneColorPipeline.swift` の lift (Phase 1b 第一)

Phase 0 探査で「YES (CoreImage / CoreVideo / CoreGraphics、UIKit なし)
→ lift as-is」と分類済。**Phase 1b 開始時に必ず再確認すること**:

```bash
grep -n "import UIKit\|import SwiftUI\|UIDevice\|UIImage" \
  apps/capacitor-film-lab-ios/ios/App/App/FilmtoneColorPipeline.swift
```

UIKit dep が 0 なら as-is コピー。1 行でもあれば platform guard
(`#if os(iOS)`) で切り出すか、unused なら削る。

### Method / DTO graph の段階的 port

`Domain/Phase0Types.swift` に method を足す時の原則:

- **使うものだけ** port。`asDTO()` が grade pipeline で使われていなければ
  port しない
- `applyingPatch()` / `value(for:)` / `setValue()` は preset 適用 + slider
  編集で必要 → 早めに port
- `Phase0ParamsDTO` は sidecar / export DTO 用。sidecar が `params` field を
  含むなら port (代替: `[String: Double]` を直接吐く方が小さい)
- 完全 graph (`FilmtoneProjectState` / `FilmtoneRequestBuildError` 等) は
  Phase 2 SPM 化と一緒にやる方が結果的に綺麗

### Lift 候補一覧 (Phase 0 探査結果)

| iOS file | platform-neutral? | macOS 戦略 | Phase |
|---|---|---|---|
| `FilmtoneColorPipeline.swift` | YES (CoreImage / CoreVideo / CoreGraphics、UIKit なし) | lift as-is | **1b** |
| `FilmtoneSourceProfileMath.swift` | YES (Foundation のみ) | lift as-is | 2 |
| `FilmtoneSourceProfileCatalog.swift` | YES | lift as-is | 2 |
| `FilmtoneCubeParser.swift` | YES | lift as-is | 2 |
| `FilmtoneLutBlobCodec.swift` | YES (Foundation + CryptoKit) | lift as-is | 2 |
| `FilmtoneMetalOpticsRenderer.swift` | YES (Metal / CIImage、MTKView 不使用) | lift as-is、Phase 1 で使うかは preview path 設計次第 | 2 |
| `FilmtoneExportSession.swift` | partial (UIDevice telemetry あり) | lift with `#if os(iOS)` for telemetry のみ | 1b (静止画部分のみ) |

**Phase 1b では Phase0 grade only から始め**、Metal optics は Phase 2 (Native
Color/Export Backbone) に回すのが plan の意図。

---

## 9. Parity 検証セットアップ (Electron baseline)

### Fixture 場所

```
apps/desktop-film-lab-batch/test/golden/
├── source-images/          (10 PNG: 01-highlight-sunset … 10-skin-dark)
├── baseline-A/<preset>/<image>.png   (80 files、8 presets × 10 images)
└── baseline-B/<preset>/<image>.png   (80 files、post-hoc linearized reference)
```

Phase 1b は **baseline-B** を参照 (post-hoc linearized = Electron 出力 PNG を
sRGB linearize し直した reference、より厳密な color comparison 用)。

### 比較ツール (TS 既存)

- `apps/desktop-film-lab-batch/test/golden-psnr.ts` — PSNR
- `apps/desktop-film-lab-batch/test/golden.harness.ts` — pixelmatch
  (meanAbs + changedRatio)

### Phase 1b parity ハーネスの選択肢

**選択肢 A (推奨)**: macOS export PNG を bun script で読んで TS 既存ツール
に食わせる
- 利点: 既存 PSNR / pixelmatch ロジック再利用、Electron との計算一致
- 欠点: Swift ↔ TS の相互運用に script 1 個追加
- 実装: `scripts/golden-parity-macos.ts` を新規作成、macOS export を
  `apps/filmtone-desktop-macos/test-out/` に吐かせる flow

**選択肢 B**: Swift 内部に簡易 PSNR 関数を書く
- 利点: Swift 完結
- 欠点: TS 結果と微差出る可能性 (libpng の RGBA 読み出し差等)

→ **A 採択推奨** (既存と同じ計算で比較できる方が信頼度高い)

### Sidecar contract source

```
apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts
  — Zod schema、reader/writer entry。最も新しい contract version
```

`parseFilmtoneExportSessionV1()` が Phase 1b の interop ポイント。

---

## 10. Sidecar Contract (Phase 1b で吐く JSON、Look Unification 状況で分岐)

§6.5 の Look Unification 着地状況確認 (`BASE_LOOKS` export + `lookId`
discriminator の有無 grep) を **必ず先に実行** してから emitter を書く。

### Case A: Look Unification landed → **dual emit** (legacy + Look)

```json
{
  "schemaVersion": 1,
  "exportedAtIso": "2026-05-03T...",
  "appVersion": "0.1.0-macos",
  "appPlatform": "macos-native",
  "sourceFile": "/path/to/input.jpg",
  "outputFile": "/path/to/output.png",
  "gradeParams": { ... 35 fields from FilmtonePhase0Params ... },
  "batchPresetChoice": {
    "presetName": "iphone",
    "presetVersion": "v2",
    "strength": 1.0
  },
  "batchLookChoice": {
    "lookId": "filmtone:base:iphone:v2",
    "lookVersion": "v2",
    "baseLookName": "iphone",
    "strength": 1.0
  },
  "lookId": "filmtone:base:iphone:v2",
  "lookVersion": "v2",
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

- **書き込み後**: TS 側 `normalizeFilmLookGradeInputIdentity()` で identity 不一致
  検証 (legacy preset と Look が指す対象が同じか確認)。throw したら emitter
  bug
- Electron 側 reader は `("lookPresetId" in o || "lookId" in o)` discriminator
  で両読み

### Case B: Look Unification 未 landed → **Look canonical only**

```json
{
  "schemaVersion": 1,
  "exportedAtIso": "2026-05-03T...",
  "appVersion": "0.1.0-macos",
  "appPlatform": "macos-native",
  "sourceFile": "/path/to/input.jpg",
  "outputFile": "/path/to/output.png",
  "gradeParams": { ... 35 fields from FilmtonePhase0Params ... },
  "batchLookChoice": {
    "lookId": "filmtone:base:iphone:v2",
    "lookVersion": "v2",
    "baseLookName": "iphone",
    "strength": 1.0
  },
  "lookId": "filmtone:base:iphone:v2",
  "lookVersion": "v2",
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

- **legacy `batchPresetChoice` / `presetName` / `presetVersion` は省略**
- Electron 側 reader が catch-up するまで、この sidecar は Look-only として
  存在
- Look Unification 着地後に Electron 側 reader が両読みできるようになる
  (Phase 1b 範囲外の作業)

### 共通: optional は Phase 2 で

LUT / source profile / quick state weights / depth / camera profile / mezzanine
metadata 等は **Phase 2** で。

### Source of truth (両 case 共通)

```
apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts
  — Zod schema、reader/writer entry。最も新しい contract version
apps/desktop-film-lab-batch/src/renderer/grade-io.ts
  — buildGradeJsonPayload (Look Unification 着地時 dual emit)
apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
  — discriminator (("lookPresetId" in o || "lookId" in o))
```

### Round-trip 確認

Phase 1b chat 内で TS 側に scratch script (`scripts/verify-sidecar-roundtrip.ts`)
を作って:
- `parseFilmtoneExportSessionV1(JSON.parse(...))` が throw しないこと
- (Case A) `normalizeFilmLookGradeInputIdentity()` が throw しないこと

**書き込みは macOS 側、検証は TS 側** で双方向 schema integrity を保証する
最小構成。

### Schema 不足が判明した時の対処

**Phase 1b 内で `packages/film-lab-core/src/` の contract を変更しない**
(Critical Invariant #4)。schema 変更が本当に必要なら:
1. handoff doc に `Phase 1b で発覚した contract 不足` セクションを追記
2. user に判断を仰ぐ (別 lane で議論、Look Unification PR に追加 / Phase 2
   SPM 化と一緒にやる選択肢含む)
3. Phase 1b は **既存 schema の subset** で完結させる方向を優先

---

## 11. Verify Commands Cheat Sheet

```bash
# 全実行は worktree 内で (Look Unification check は main checkout で)
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# === Phase 1a sanity (新 chat 開始時に必ず実行) ===
bun run build:core
bun run generate:swift
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
# expect: identical (2 ファイルが完全一致、output なし)

bun run verify:macos
# expect: ** BUILD SUCCEEDED **

bun run verify:ios
# expect: D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000

# === lane 無傷確認 ===
git status apps/desktop-film-lab-batch/
# expect: clean
git status apps/capacitor-film-lab-ios/
# expect: clean

# === Look Unification main 着地状況確認 (sidecar 契約分岐の判定) ===
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
# expect: commit があれば landed、無ければ未 landed

grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
# expect: BASE_LOOKS export 行があれば landed

grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
# expect: discriminator に lookId があれば reader が両読み対応済

# 上記 3 つ全部 hit → Case A (dual emit)
# どれか missing → Case B (Look canonical only)

# === 起動 (smoke、user が手動) ===
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# expect: window 起動、⌘O → 画像選択 → 表示

# === Phase 1b 開発中 (頻繁に走らせる) ===
bun run verify:macos                          # ビルド常時 green キープ

# === Phase 1b 完了 gate (新規実装後に追加 script) ===
# (a) export を実際に吐く
# bun run scripts/golden-parity-macos.ts --preset iphone --image 04-portrait-warm
# (b) sidecar round-trip (Case A は normalizeFilmLookGradeInputIdentity も)
# bun run scripts/verify-sidecar-roundtrip.ts test-out/04-portrait-warm.json

# === life truth scripts (state 確認用、必要時) ===
FILMTONE_REPO_ROOT=$PWD /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
FILMTONE_REPO_ROOT=$PWD /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼** (CLAUDE.md §5)。

---

## 12. Active Risks for Phase 1b

| Risk | 対策 |
|---|---|
| iOS `FilmtoneColorPipeline.swift` に UIKit dep が混入していたら lift 失敗 | 開始時に `grep "import UIKit\|UIDevice\|UIImage"`。混入があれば platform guard or 削減 (削減できないなら設計変更を user 確認) |
| CoreImage の color management 設定が WebGPU と微差 | ColorSpace 明示 (`CGColorSpace(name: CGColorSpace.sRGB)!`)。PSNR 35dB threshold で受ける、perfect parity は Phase 2 |
| `Phase0ParamsDTO` 不在で sidecar 書けない | `Domain/Phase0Types.swift` に DTO 追加 OR 直接 `[String: Double]` で書く (sidecar JSON 側は `[String: Double]` で問題ない) |
| sidecar Zod schema 解読負荷 | `export-metadata-session.ts` の Zod を読むのが正本。**手で「こう書けば動くはず」と推測しない** (`feedback_no_guessing_davinci_plugins` 適用) |
| AVFoundation 動画 export 検証は Phase 1c | Phase 1b では一切触らない。動画関連コードを書かない |
| OpticalFilters lane が main で landing → 合流 conflict | Phase 1b 着手時に main の状態を確認。conflict あれば user に判断仰ぐ |
| context budget 超過 | Phase 1b 内で grade と export と parity を同時に追えなくなったら、parity を Phase 1c に分離する判断 |
| 生成 Swift と Domain stub の field 順序 drift | generator が `paramKeys` 順で吐くので、`Phase0Types.swift` の `FilmtonePhase0Params` field 順序を `paramKeys` と揃える (現状は揃っている、追加 / 並び替え NG) |
| iOS から `FilmtoneColorPipeline` をコピーした時に他 lift 候補 (例 `FilmtoneSourceProfileMath`) を chain で釣り上げてしまう | **Phase 1b は Phase0 grade only**。source profile 連鎖は意識的に切る (Phase 2 まとめて) |
| preset 選択 UI の Liquid Glass over-application | Picker 単体に glass を当てない。toolbar 内の Picker は SwiftUI 標準で OK、custom dropdown は背景に black/secondary、glass は floating control にだけ |

---

## 13. Open Design Questions (Phase 1b で答える、推奨値付き)

| # | 質問 | 推奨 | 理由 |
|---|---|---|---|
| 1 | **Best preview path**: CoreImage-only / Metal-only / hybrid | **CoreImage-only** | CIImage chain で grade 適用、`MTKView` 切替は Phase 2 (Native Color/Export Backbone)。Phase 1b 本質 = parity proof |
| 2 | **`FilmtoneExportSession` 共有戦略**: as-is / split / 選択 port | **選択 port** | 静止画 export 部分のみ。telemetry 系は `#if os(iOS)` か削除 |
| 3 | **sidecar field set**: 必須のみ / full | **§10 の最小 field set** (Case A or B) | LUT / source profile は Phase 2 |
| 4 | **preset picker UI**: dropdown / segmented / large card | **dropdown** (`Picker` + `MenuStyle`) | large card は Phase 4 (UX polish) 範疇 |
| 5 | **export format**: PNG only / JPEG only / both | **PNG default + JPEG option** | both 実装は trivial (`CGImageDestination` の type 引数だけ変える) |
| 6 | **preview update timing**: 即時 / debounce | **debounce 120ms** (iOS と同値、`FilmtonePhase0Math.previewRenderDebounceNanoseconds`) | iOS と同じ feel が parity 的に有利 |
| 7 | **export 中の UI freeze**: blocking modal / background | **background + progress** | NSOpenPanel と違って long-running、user 操作妨害したくない |
| 8 | **Look Unification dual emit vs canonical only** | **§6.5 / §11 の grep 結果に従う** | landed なら dual emit、未 landed なら Look canonical only。**実行時に判定、推測しない** |
| 9 | **preview UI 内の preset 名表示**: "Preset" / "Look" 文字列 | **"Look"** (Look Unification 着地状況に関わらず) | macOS app は新規構築なので最初から canonical 語彙で書く。i18n キー `controls.looks` を直接参照するか、ハードコード OK (Phase 3 で messages 統合) |

これらは Phase 1b chat 開始時に user に再確認 (推奨 vs 別案) して進める。

---

## 14. Reference Paths Cheat Sheet

### この worktree (実装する場所)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/
├── CLAUDE.md                                        # project rules、必読
├── README.md                                        # workspaces + scripts
├── package.json                                     # bun scripts
├── apps/
│   ├── filmtone-desktop-macos/                     # ★Phase 1b で拡張
│   │   ├── README.md                               # Phase 0+1a self-doc
│   │   ├── FilmtoneDesktop.xcodeproj/
│   │   └── FilmtoneDesktop/
│   │       ├── App/
│   │       │   ├── FilmtoneDesktopApp.swift
│   │       │   └── AppCommands.swift
│   │       ├── Domain/                             # Phase 1a 新設
│   │       │   └── Phase0Types.swift
│   │       ├── SharedGenerated/                    # Phase 1a Compile Sources 取込
│   │       │   └── FilmtonePhase0Generated.swift
│   │       ├── UI/
│   │       │   ├── RootWindowView.swift            # Phase 1a で NSOpenPanel 配線
│   │       │   ├── GlassControlGroup.swift
│   │       │   └── PreviewSurface.swift            # Phase 1a 新設
│   │       └── Assets.xcassets/
│   ├── capacitor-film-lab-ios/                     # ★参照のみ、編集禁止
│   │   ├── CLAUDE.md                               # iOS 専用 invariants (223 行)
│   │   └── ios/App/App/                            # iOS Swift sources (lift 元)
│   │       ├── FilmtonePhase0Math.swift            # 781 行 (FilmtoneQuickState 等の正本)
│   │       ├── FilmtoneMediaTypes.swift            # 763 行 (Phase0OutputProfileDTO 等)
│   │       ├── FilmtoneColorPipeline.swift         # ★Phase 1b lift 第一候補
│   │       └── FilmtonePhase0Generated.swift       # generator 出力 iOS 版
│   └── desktop-film-lab-batch/                     # ★編集禁止、parity 参照
│       ├── test/golden/                            # baseline-A/B fixture
│       └── src/renderer/
│           ├── export-metadata-session.ts          # ★sidecar contract 正本
│           └── video-export-webcodecs.ts           # 静止画 export 参考
├── packages/
│   ├── film-lab-core/src/
│   │   ├── ios-swift-payload.ts                    # Phase0 generator pure 関数
│   │   ├── phase0-schema.ts                        # PHASE0_PARAM_KEYS 等
│   │   ├── presets.ts                              # PRESETS + CONTRACT_DEFAULTS
│   │   ├── source-profile-conversion.test.ts       # parity test
│   │   └── ...
│   ├── film-lab-renderer/dist/                     # tracked、submodule 用
│   └── film-lab-smart-look/dist/                   # 同上
├── scripts/
│   ├── generate-filmtone-swift.ts                  # canonical generator
│   ├── generate-filmtone-ios-swift.ts              # shim
│   ├── verify-ios.sh
│   ├── verify-desktop.sh
│   └── verify-phase0-contract.sh
└── docs/filmtone/desktop/
    ├── filmtone-native-desktop-transition-plan-2026-05-03-jst.md           # 全体計画書 index (短い)
    ├── native-desktop-transition-plan-2026-05-03-jst/                      # 詳細 split docs
    │   ├── 01-current-state-and-decision.md
    │   ├── 02-target-architecture-and-contracts.md
    │   ├── 03-migration-and-concurrent-lanes.md                            # ★Look Unification 依存
    │   ├── 04-phase-plan.md                                                # ★Phase 1b gate の正本
    │   ├── 05-future-lanes.md
    │   └── 06-quality-gates-risks.md
    ├── filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md  # 親 handoff (historical)
    ├── filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md # 子 handoff (historical)
    └── filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md    # ★この doc (canonical)
```

### main checkout 側 (Look Unification handoff)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/
└── docs/filmtone/desktop/
    └── filmtone-desktop-look-unification-handoff-2026-05-03-jst.md         # ★Phase 1b sidecar 契約の正本
```

このリポは Native Desktop worktree なので Look Unification doc は **見えていない**。
main checkout 側の path を直接 Read する。

### Phase 0 / Look Unification 設計判断のメモ (worktree 外)

```
/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md
  — なぜ SPM を Phase 0 から外したか
  — なぜ SharedGenerated を Compile Sources から外したか (Phase 1a で解除)
  — UUID 命名規約
  — 全体計画書 Phase 0 の plan-mode 議論のフル記録
  — Initial Plan Review (P1/P2 修正記録)

/Users/chibatakumi/.claude/plans/desktop-look-unification-bright-dusk.md
  — Look Unification lane の元 plan
```

### life truth scripts

```
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

`FILMTONE_REPO_ROOT` env で root 上書き可 (worktree を指す時に使う)。

---

## 15. Memory Entries (auto-loaded)

新 chat にも自動 load される
(`/Users/chibatakumi/.claude/projects/-Volumes-SamsungPortableSSDX5001-documents-forestone-filmtone/memory/`):

| memory file | 内容 |
|---|---|
| `feedback_auto_mode_no_decision_handoff.md` | auto mode + plan approved → 実行する、user に decision punt しない |
| `feedback_dont_overengineer_dirty_state_split.md` | in-flight work は 1 commit に bundle、unstage / patch-split しない (user 指示なき限り) |
| `feedback_no_promising_from_forced_substage.md` | forced boundary stage cost は ranking 用、speed promise には使わない |
| `project_v15_metal_optics_lane.md` | iOS v1.5 Metal optics、Phase 1 perf passed 95.6s、quality gate (視覚 A/B) PENDING (Phase 1b で iOS Xcode に触らない理由) |
| `reference_devicectl_env_var_launch.md` | `xcrun devicectl device process launch --environment-variables` で実機 env var |

これら以外に `MEMORY.md` にも index がある。**新規 memory 追加は user
明示指示がある時のみ**。

---

## 16. 引き継ぎ詳細プロンプト (新 chat に貼る用、最高精度版)

新 chat の **1 発目にこれを丸ごと貼る**。これだけで Phase 1b に satisfaction
で入れる。

```
このリポは Filmtone (forestone film-lab 系プロダクト)。Phase 0 (Skeleton)
+ Phase 1a (Open + Preview precondition) が完了し commit 済 (1 commit に
bundle)、今は Phase 1b (preset 選択 → grade 適用 → still export → sidecar
JSON → Electron baseline-B との PSNR parity) を進めたい。

作業 worktree:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
branch: feature/native-desktop-plan

並行 lane (重要、sidecar 契約に影響):
- Desktop Look Unification (branch: feature/desktop-look-unification、worktree
  喪失中) が main checkout 側で再開待ち。Phase 1b の sidecar emitter は
  この lane の main 着地状況で動作分岐 (詳細は master handoff §6.5 / §10)。

最初に必ず以下を順番に読んで前 chat の文脈を完全復元してから作業に入る:

1. docs/filmtone/desktop/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md
   ← 完全自己完結 master handoff (900+ 行)。Phase 0 完成記録 + Phase 1a
   Decision A 採択経緯 + 実装 full content + Phase 1b scope + 更新 invariants
   + Look Unification 依存 (§6.5) + lift 戦略 + parity セットアップ + sidecar
   contract dual-emit/canonical 分岐 (§10) + risks + open questions の推奨値
   が全部入っている。**skim 禁止、§0 から §17 まで通読**。

2. CLAUDE.md (worktree root) — project rules (8 項目の運用原則 + 6 antipattern)
3. apps/capacitor-film-lab-ios/CLAUDE.md — iOS 不変条件 (Phase 1b で iOS Swift
   を lift する時の境界、223 行)
4. apps/filmtone-desktop-macos/README.md — Phase 0 + 1a の self-doc
5. 全体計画書 split docs (詳細はこちら、index は短い):
   - docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/
     03-migration-and-concurrent-lanes.md  ← Look Unification 依存 (必読)
     04-phase-plan.md                       ← Phase 1b acceptance gate の正本
6. Look Unification handoff (main checkout 側、このリポでは見えない):
   /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/
     filmtone-desktop-look-unification-handoff-2026-05-03-jst.md
   ← Phase 1b sidecar 契約 (BASE_LOOKS / lookId / lookVersion /
     normalizeFilmLookGradeInputIdentity) の正本

optional (深掘り時のみ):
- ~/.claude/plans/luminous-sparking-eclipse.md (Phase 0 plan-mode 議論)
- ~/.claude/plans/desktop-look-unification-bright-dusk.md (Look Unification 元 plan)
- docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md
  (親 handoff、§10.5 Concurrent Lane 詳細)

読み終わったら以下を実行して Phase 1a が現在も動くこと + Look Unification 着地
状況を sanity check:

  # === Phase 1a sanity ===
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
  git log --oneline -10
  bun run build:core
  bun run generate:swift
  diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
          apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
  bun run verify:macos
  bun run verify:ios
  git status apps/capacitor-film-lab-ios/
  git status apps/desktop-film-lab-batch/

  # === Look Unification main 着地状況 ===
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
  git log --oneline | grep -iE "look unification|baselook" | head
  grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
  grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
  # 全部 hit → Case A (dual emit) / どれか missing → Case B (Look canonical only)

全部通ったら Phase 1b の planning に入る。最初に user に確認すること:

(a) master handoff §13 の 9 つの open question の推奨値で進めて良いか:
    1. preview path: CoreImage-only
    2. export session: 選択 port (静止画部分のみ)
    3. sidecar: §10 の最小 field set (Case A or B、grep 結果に従う)
    4. preset picker: dropdown
    5. export format: PNG default + JPEG option
    6. preview update: debounce 120ms
    7. export 中 UI: background + progress
    8. sidecar dual emit vs canonical only: §11 grep 結果に従う (推測禁止)
    9. UI 内文字列: "Look" (Look Unification 着地状況に関わらず)

(b) Phase 1b を 1 commit にまとめるか、grade 実装 / export+sidecar /
    parity ハーネスを別 commit に分けるか。
    (memory feedback_dont_overengineer_dirty_state_split: 1 commit bundle 推奨)

(c) lift 開始時の grep 結果で `FilmtoneColorPipeline.swift` に UIKit dep が
    混入していた場合の対処方針 (削減 / platform guard / 設計変更)。

(d) Look Unification 未 landed (Case B) で進める場合、Electron 側 reader が
    catch-up するまで sidecar が Look-only になる。これを **明示的に user 了承**
    するか (sidecar の片読み期間が発生)。

絶対に守る invariants (master handoff §6 参照、ハードコア):
- iOS Xcode project (apps/capacitor-film-lab-ios/) を編集しない
  (v1.3 lane in-flight、Swift lift 元の read-only 参照は OK)
- Electron desktop (apps/desktop-film-lab-batch/) を編集しない
  (parity 比較で test fixture を read するのは OK)
- packages/film-lab-renderer/dist/ packages/film-lab-smart-look/dist/ を
  消さない (submodule track 用)
- packages/film-lab-core/src/ の contract source は変更しない
  (sidecar schema 不足判明時は user に判断仰ぐ、Look Unification PR への追加 or
   Phase 2 SPM と一緒の選択肢含む)
- 生成 Swift (FilmtonePhase0Generated.swift) を手編集しない、generator のみ
- iOS と macOS の Phase0Generated.swift は bit-identical 維持
  (diff -q で常時確認)
- Domain/Phase0Types.swift の field 順序 / 名前を変えない
  (memberwise init 契約、FilmtonePhase0Params の field 順は generated file の
   paramKeys 配列と一致)
- bun mandatory、npm 禁止
- 用語ロック: 動画 / video、短尺動画 禁止 / Preset → Look (UI 文字列)
- git は user 実行 (auto commit 禁止)、commit message は user スタイル準拠
- handoff doc を引用する前に現行 surface (grep / Swift / pbxproj) と突き合わせて
  live/frozen 確認 (feedback_verify_before_quoting_handoff)

設計判断は mcp__sequential-thinking で考える。記憶ベース断言は禁止。
不確かな API (CoreImage / CGImageDestination / sidecar Zod schema /
AVFoundation / Metal) は gemini-search → WebSearch で必ず確認。

handoff 全文を読み終えたら:
  (i) 読んだ要約を 5 行で出す (Phase 1a 結果 / Phase 1b deliverable / Look
      Unification 着地状況 / 主要 risk を含む)
  (ii) 上記 (a)(b)(c)(d) を user に確認
  (iii) 実装着手前に Phase 0 + 1a が commit 済か git log で確認
       (commit 未なら user に commit を依頼してから着手)
```

---

## 17. このドキュメント自身について

- **role**: 完全自己完結 master handoff (canonical)
- 作成者: Phase 0 + Phase 1a 実装 chat (同一 chat)
- 作成時刻: 2026-05-03 JST
- 関連 doc:
  - `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
    (historical 親、Phase 0 完成記録の original)
  - `filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
    (historical 子、master の前段で作った partial 版)
  - `filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
    (全体計画書、Phase 2-5 の長期 architecture も含む原文)
- 更新タイミング:
  - Phase 1b 完了時に Phase 1c master handoff として書き直す
  - Phase 1c をスキップして Phase 2 へ直行する判断なら Phase 2 master へ
- canonical naming convention:
  `filmtone-native-desktop-phaseN-master-handoff-{date}-jst.md`
  (master = 自己完結型、partial pointer 系は `next-chat-handoff` を継続使用)
- replaces: `phase1-next-chat-handoff` / `phase1b-next-chat-handoff` の
  「次 chat が読むべき canonical」役割を完全に引き受ける
