# Filmtone Native Desktop v2 — Phase 1c Master Handoff (Self-Contained)

Date: 2026-05-03 JST
Source chats:
- chat A.1: Phase 0 (Skeleton) + Phase 1a (Open + Preview precondition) — commit
  `398743c` 済
- chat A.2: Phase 1b (preset → grade → still export → sidecar → parity) —
  uncommitted、本 handoff の trigger
Target chat: Phase 1c (動画 vertical slice — open .mov → preview frame →
H.264 mp4 export) または Phase 2 (Native Color/Export Backbone) 直行
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan`

このドキュメントは **完全自己完結型 master handoff**。これ 1 本だけ精読すれば、
Phase 0 / 1a / 1b で行われた議論・採択・実装・検証・残タスクを全て再現できる。
predecessor (`filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`)
と Phase 1b 完了 handoff
(`filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`) の
内容を全て吸収しており、historical record として残す以外には参照不要。

---

## 0. Read-this-first 順序

新 chat の最初の 15-25 分:

1. **このドキュメント全体** (1500+ 行、skim 禁止、§0 から §17 まで通読)
2. `CLAUDE.md` (worktree root) — project rules、§3 運用原則 / §6 antipattern
3. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (Phase 1c で iOS
   `FilmtoneExportSession` を lift する時の境界、223 行)
4. `apps/filmtone-desktop-macos/README.md` — Phase 0 + 1a の self-doc (1b
   landing は反映していない、必要なら本 handoff §5.5 を参照)
5. **全体計画書 split index**:
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   は **canonical index (短い)**。詳細は split files
   `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/` 配下:
   - `01-current-state-and-decision.md` — status / purpose / product decision
     (SwiftUI-first stance 追加済)
   - `02-target-architecture-and-contracts.md` — app shell / render core /
     **Responsibility Boundaries** (UI/State/Domain/Color/Export/Media/SharedGenerated 分担と依存方向、Phase 1b で実装済)
   - `03-migration-and-concurrent-lanes.md` — **Look Unification chat B 並列進行中** (本 handoff §6.5 参照)
   - `04-phase-plan.md` — Phase 0-5 deliverables / acceptance gate / **Phase 1b 着地状況追記済**
   - `05-future-lanes.md` — Continuity Export / Resolve / Pro NLE
   - `06-quality-gates-risks.md` — quality gates / open questions / risks /
     **baseline-B fixture mismatch リスク追記済**
6. **Phase 1b 完了 handoff** (本 handoff の元となった詳細記録):
   `docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`
   ← 実装内容と parity 結果の primary 一次資料
7. **Look Unification handoff** (main checkout 側 / chat B 起動済):
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
   — **Phase 1c の sidecar 契約は Look Unification 着地状況で動作分岐**
   (詳細は本 doc §6.5 / §10)
8. `git log --oneline -10` で worktree commit 状態確認 (Phase 0+1a が `398743c`
   で commit 済、Phase 1b が working tree 上 uncommitted)
9. **必ず実行**: §11 の Phase 1a + 1b sanity check + Look Unification main 着地
   状況確認

optional (深掘り時のみ):
- `~/.claude/plans/luminous-sparking-eclipse.md` — Phase 0 plan-mode 設計議論
- `~/.claude/plans/desktop-look-unification-bright-dusk.md` — Look Unification
  lane の元 plan
- `docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
  — 親 handoff (historical, Phase 0 完成記録の original)
- `docs/filmtone/desktop/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`
  — predecessor master (Phase 1b 開始時、§16 プロンプト含む)
- `docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
  — historical 子、master の前段で作った partial 版

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

### Repos と並列 chat

| repo / worktree | path | 役割 | 編集可否 |
|---|---|---|---|
| **Native Desktop worktree (本リポ・本 chat)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0 / 1a / 1b / 1c 実装、branch `feature/native-desktop-plan` | **編集対象** |
| **Look Unification worktree (chat B 並列、別 chat)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification` | Phase A / B 再開、branch `feature/desktop-look-unification` | **本 chat では編集禁止** (read-only 参照のみ、main 着地後に sidecar 契約反映) |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ | 編集禁止 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 (`apps/web`)、`vendor/filmtone` submodule で消費 | 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts + 5 ロール憲法 | 触らない |

### Worktree branch invariants

- Phase 0 + 1a + 1b + 1c は同一 branch `feature/native-desktop-plan`
- Phase 0 + 1a は **commit `398743c` で bundling 済**
- Phase 1b は **2026-05-03 JST 時点で working tree 上 uncommitted**(本
  handoff §5.5 参照)。新 chat の最初に user に commit を依頼してから着手
- 別 branch を切る必要は **なし**。PR 切るのは Phase 1c 完了時(Phase 0 +
  1a + 1b + 1c 同一 PR、または分割 PR は user 判断)
- main checkout の dirty / untracked にある OpticalFilters 関連ファイル
  (`packages/film-lab-core/src/ios-optical-filter-payload.ts` 等)は
  **このワークツリーには来ていない**。lane が main へ landing 後に取り込む

### Tooling versions (Phase 0+1a+1b で verified working)

- macOS 26.4.1 (Build 25E253)
- Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3
- Swift 6.0 (target setting; toolchain は Xcode 26 同梱)

これらより古い env では Liquid Glass API / Phase 1b の `@Observable` が
コンパイル通らない。

### 認証 / 環境

- Git user: `chibataku0815` (commit 自体は user 実行、auto commit 禁止)
- Email: `chiba@fores-tone.co.jp`

---

## 3. Native Desktop v2 全体計画 (要約)

Filmtone Desktop を **Electron 製 macOS アプリ** から **SwiftUI-first /
AppKit interop ベースの Native Desktop v2 (Liquid Glass first-class)** へ
移行する lane。

### 移行戦略

並行 lane: 現行 Electron Desktop は **release rail として shipping し続け**、
Native Desktop v2 が phase gate を通るまで default にしない。Phase 4
(Native Capability Replacement) で機能網羅を達成した後に default を切り替える。

### macOS 26 only (確定)

- macOS 26 SDK で build した SwiftUI `.toolbar` / `NSToolbar` は **自動的に
  Liquid Glass を採用**。コードを書く必要なし
- `.glassEffect(.regular, in: Capsule())` は macOS 26.0+ / iOS 26.0+ /
  iPadOS 26.0+ / watchOS 26.0+ / tvOS 26.0+
- reduced-material fallback は **書かない** (Phase 0 で確定)
- design rule (Apple HIG): glass は **navigation / control 層のみ**。
  content / preview には当てない

### UI framework stance (Phase 1b 並列で plan に追記済)

- SwiftUI を新規 native UI の主軸
- AppKit は macOS 固有の window / menu / panel / Finder integration / 深い
  interop に限定使用。**AppKit-first にしない**
- iOS UI は SwiftUI / UIKit の領域。AppKit を iOS に持ち込まない
- Cross-platform 共有は Domain / Color / generated contracts を通じて行い、
  共有 SwiftUI view はそれが両 platform を弱体化しない場合のみ

### Phase 段階

| Phase | scope | 状態 |
|---|---|---|
| **0 (Contract & Skeleton)** | macOS app skeleton + 生成 Swift dual-target emit + Liquid Glass API surface 確認 | **COMPLETE** (commit `398743c`) |
| **1a (Open + Preview precondition)** | SharedGenerated を compile-link、NSOpenPanel + still preview (grade なし) | **COMPLETE** (commit `398743c`) |
| **1b (Vertical Slice — still)** | preset 選択 + grade 適用 + still export + sidecar JSON + parity 検証ハーネス | **COMPLETE** (uncommitted、本 handoff §5.5) |
| **1c (Vertical Slice — video)** | 動画 1 個 open + preview frame + H.264 mp4 export | **次 chat (本 handoff の trigger)** |
| **2 (Native Color/Export Backbone + SPM)** | `packages/film-lab-swift-core/` SPM 化、iOS の grade pipeline 移管、`Domain/Phase0Types.swift` 削除 → import 切替、optics port、baseline-B fixture mismatch 解決 | TBD |
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

(predecessor master handoff §4 の内容を維持。要約のみ。詳細は predecessor 参照)

### Acceptance gate 結果 (全 PASS)

`bun run build:core` / `bun run generate:swift` / `bun run verify:macos`
(`** BUILD SUCCEEDED **`) / `bun run verify:ios` (D-Log / D-Log M / C-Log /
C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000) / iOS+Electron lane clean。

### 主要採択

- 手書き `.xcodeproj` (objectVersion 70, UUID prefix `FT0000000000000000000XXX`)
- generator multi-target dual emit (`scripts/generate-filmtone-swift.ts`):
  iOS / macOS の `FilmtonePhase0Generated.swift` を bit-identical に保ち、
  iOS 側 git diff は空。`generate:ios-swift` は shim
- Bundle id `co.fores-tone.filmtone.desktop` / macOS 26.0 / Swift 6.0
- Liquid Glass: SwiftUI `.toolbar` 標準で自動採用、`glassEffect(.regular, in: Capsule())` は
  custom 1 箇所のみ (`GlassControlGroup.swift`)
- OpticalFilters は Phase 0 に含めず (main untracked、main 着地後に generator
  に追加)

### Phase 0 commit (`398743c`) に含まれる Swift 構成

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── App/
│   ├── FilmtoneDesktopApp.swift   (@main, WindowGroup)
│   └── AppCommands.swift          (Help menu)
├── UI/
│   ├── RootWindowView.swift       (toolbar + preview placeholder)
│   └── GlassControlGroup.swift    (.glassEffect 検証)
└── Assets.xcassets/
```

`SharedGenerated/FilmtonePhase0Generated.swift` は generator 出力先のみ、
Phase 0 時点では Compile Sources 外。Phase 1a で取り込み済。

---

## 5. Phase 1a 完成記録 (Open + Preview Precondition)

(predecessor master handoff §5 の内容を維持。要約のみ)

### Decision A (採択): 型 dep を macOS target にコピー

iOS の `FilmtonePhase0Math.swift` + `FilmtoneMediaTypes.swift` から generated
file が依存する 4 struct (`FilmtoneQuickState` / `FilmtonePhase0Params` /
`Phase0OutputProfileDTO` / `FilmtonePhase0HiddenDefaults`) を **memberwise
init + stored properties のみ** で macOS target にコピー。`Domain/Phase0Types.swift`
(75 行)。iOS は無触。Phase 2 で SPM `packages/film-lab-swift-core/` 集約予定。

Decision B (棄却): SPM 先行は Phase 1a の本質ではない (本質優先 / 外殻最小)。

### Phase 1a で landed したファイル (commit `398743c` 一部)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift   (新規)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift    (新規、NSImageView wrap)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift    (NSOpenPanel + ⌘O)
pbxproj                                                                 (BuildFile/FileRef/Group/Sources phase 拡張)
```

### Phase 1a Acceptance gate (全 PASS)

`bun run verify:macos` / `bun run generate:swift -- --check` / `diff -q` iOS↔macOS / `bun run verify:ios` / `git status apps/capacitor-film-lab-ios apps/desktop-film-lab-batch` (clean) / 手動 smoke (⌘O → 画像選択 → 表示)。

---

## 5.5. ★ Phase 1b 完成記録 (Vertical Slice — Still、本 handoff の主役)

### 5.5.1 Goal と Deliverable 状態

> Native Desktop が **本物の Filmtone work** を出力できることを 1 still で証明する。

| # | Deliverable | 状態 |
|---|---|---|
| 1 | preset 選択 (4 個: reset / iphone / softBlue / amberGlow) | ✅ landed |
| 2 | preview に grade を反映 (CoreImage CIKernel chain) | ✅ landed |
| 3 | still を export (PNG / JPEG, CGImageDestination 経由) | ✅ landed |
| 4 | sidecar JSON (Case B: Look canonical only) を書く | ✅ landed |
| 5 | parity 検証ハーネス (`bun run scripts/golden-parity-macos.ts`) | ✅ landed (informational) |

### 5.5.2 採択した設計判断 (predecessor §13 推奨値ベース、確定)

| # | 決定事項 | 採択 |
|---|---|---|
| 1 | preview path | CoreImage-only (CIColorKernel chain) |
| 2 | export session | 選択 port (静止画分のみ、kernel sources を verbatim lift) |
| 3 | sidecar field set | **Case B (Look canonical only)** — Look Unification 未 landed と grep で確認 |
| 4 | preset picker UI | `Picker` + `.menu` style、右上 floating + `.regularMaterial` |
| 5 | export format | PNG default + JPEG (拡張子分岐) |
| 6 | preview update | 即時 (preset switch 頻度低 + per-pixel kernel が cheap) |
| 7 | export 中 UI | background `Task.detached` + `isExporting` flag |
| 8 | dual emit vs canonical only | grep 結果に従い Case B |
| 9 | UI 文字列 | "Look" hardcode (i18n は messages 統合まで) |

### 5.5.3 新規ファイル (uncommitted)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Color/
│   ├── FilmtoneCIContext.swift          (共有 CIContext: workingColorSpace=linear sRGB / output=sRGB)
│   ├── FilmtoneGradeKernels.swift       (iOS の baseGradeV2 / filmCompressionV2 / printStage を verbatim lift)
│   ├── FilmtoneGradePipeline.swift      (3-stage chain orchestrator + epsilon gate)
│   └── FilmtonePresetCatalog.swift      (FilmtonePhase0Generated.paramsByName wrap + lookId 生成)
├── State/
│   └── EditorState.swift                (@Observable: imageURL / presetName / isExporting)
├── Export/
│   ├── FilmtoneStillExporter.swift      (CIContext.writePNGRepresentation / writeJPEGRepresentation)
│   └── FilmtoneSidecarWriter.swift      (Case B Look canonical only sidecar JSON)
└── UI/
    └── GradeControls.swift              (SwiftUI Picker、4 preset)
scripts/
├── compare-pngs.ts                      (diagnostic: PNG↔PNG PSNR + 4 sample pixels)
└── golden-parity-macos.ts               (baseline-B parity harness、informational)
```

### 5.5.4 更新ファイル (uncommitted)

| パス | 変更 |
|---|---|
| `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift` | `FilmtoneDesktopCLI.runIfRequested()` を `init()` 内で呼び `--export-still` headless mode を実装 |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` | `EditorState` 持ち、Picker (右上 floating) + ⌘E Export ボタン + NSSavePanel |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift` | `presetName` を受け、`FilmtoneGradePipeline.apply` 経由で render → CGImage → NSImage |
| `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` | UUID A09–A10 / B09–B10 / E08-E0A 追加。Color / State / Export 3 group + 8 PBXBuildFile + 8 PBXFileReference + 8 Sources phase 登録 |
| `.gitignore` | `/test-out/` を ignore (parity script の出力先) |

iOS Xcode project / Electron desktop / film-lab-core src は **未編集**。

### 5.5.5 ★ baseline-B fixture と canonical pipeline の不整合 (重要発見)

#### 観測

`bun run scripts/golden-parity-macos.ts --preset reset` の結果 (10/10 image):

| metric | 値 | 解釈 |
|---|---|---|
| **macOS↔source** | **∞ dB (10/10 bit-identical)** | reset preset は params identity → kernel epsilon gate で全段 no-op → CIImage ↔ CGImage roundtrip は bit-identical。CIContext の colorspace 設定 (workingColorSpace=linear sRGB, output=sRGB) は正しい。 |
| **macOS↔baseline-B** | 平均 **13.69 dB** (max 22.90, min 2.76) | baseline-B は source と完全に異なる pixel を持つ。source(214,149,49) → baseline-B(168,70,7) のような per-channel non-linear shift。 |

`iphone` preset on `09-skin-light`: macOS↔source = **39.62 dB**。grade pipeline が active で source と意味のある差分を生んでいる証明。

#### 三角測量

```
source vs baseline-B/reset                : 13.08 dB
baseline-A/reset vs baseline-B/reset      : 50.68 dB   (highlight lift のみ — 既知の差分)
source vs baseline-A/reset                : 13.15 dB   ★これが核心
```

`baseline-A` は `apps/desktop-film-lab-batch/test/golden.harness.ts` の
`captureOne()` が WebGL renderer (`packages/film-lab-renderer/src/webgl/shaders/filmlab.frag.ts`) で
`PRESETS.reset` (= identity 的) を適用した capture。**にもかかわらず source と
13.15 dB しか合わない** = WebGL renderer の reset capture は何らかの非自明な
処理を経ている (canvas EOTF/OETF / 暗黙 LUT / harness 残留状態のいずれか)。

#### 結論と影響

Phase 1b acceptance gate の "PSNR > 35dB vs baseline-B" は **現行 fixture と
今 lift した iOS canonical pipeline の組み合わせでは構造的に達成不可能**。
これは Phase 1b の本質欠陥ではなく、**fixture 側の生成パイプラインが現行
canonical と乖離している**ことを意味する。

Phase 2 で取りうるアクション (user 判断、本 handoff §13 にも記録):

| 案 | 内容 | 工数感 | parity 信頼性 |
|---|---|---|---|
| A | WGSL `filmlab.frag.wgsl.ts` を Metal CIKernel に港 | 中 | 高 (math identical to WebGPU) |
| B | baseline-B fixtures を iOS-canonical pipeline で再生成 (baseline-C 命名) | 小 | 中 (新 reference 品質次第) |
| C | parity gate を別の比較軸に置換 (e.g., iOS app の export と native macOS export を直接比較) | 小 | 高 (canonical-canonical) |
| D | parity gate そのものを Phase 2 acceptance に倒す (Phase 1b は wiring proof のみ) | nil | n/a |

**Phase 1b 採用: D + (B or C を Phase 2 で)**。Phase 1b は "vertical slice が
wire できる" 証明である。"WebGL parity" は別問題。memory
`project_phase1b_baseline_b_fixture_mismatch` 記録済。

### 5.5.6 Phase 1b verify 結果

```bash
$ bun run verify:macos          → ** BUILD SUCCEEDED **
$ bun run generate:swift -- --check    → exit 0 (drift なし)
$ diff -q iOS↔macOS Phase0Generated.swift   → identical
$ bun run verify:ios            → ΔE2000 全 0.000、sidecar pass
$ git status apps/capacitor-film-lab-ios/   → clean
$ git status apps/desktop-film-lab-batch/   → clean

$ FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop \
    --export-still --input source-images/01-highlight-sunset.png \
    --output test-out/reset-01.png --preset reset
ok 1280x720 ...test-out/reset-01.png

$ cat test-out/reset-01.filmtone.json | head
{ "appPlatform": "macos-native", "appVersion": "0.1.0-macos",
  "lookId": "filmtone:base:reset:v2", "lookVersion": "v2", ... }
```

---

## 6. Critical Invariants (絶対に壊さない、final consolidated)

### 境界 (Phase 0 + 1a + 1b で立てた)

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** —
   v1.3 local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。
   Phase 1c で iOS Swift から `FilmtoneExportSession` の動画 path を **read-only
   参照 + 内容コピー** するのは OK だが、iOS の `.pbxproj` には触らない
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** —
   release rail。Phase 4 で current-capability replacement に到達するまで
   shipping rail として残す。**parity 比較で test fixture を read するのは OK**
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/`
   を消さない** — submodule 即 import 用に track 維持。`.gitignore` に
   `dist` を追加しない (CLAUDE.md §6 antipattern #2)
4. **`packages/film-lab-core/src/` の contract source は変更しない** —
   generator は pure 関数を呼ぶだけ。Phase 1c の sidecar schema 拡張が必要なら
   **別 lane** (Look Unification / Phase 2 SPM) で議論する
5. **生成 Swift を手編集しない** — `bun run generate:swift` の出力のみ。
   ヘッダの `// AUTO-GENERATED ...` コメントが残っている
6. **iOS と macOS の `Phase0Generated.swift` は bit-identical** — どちらかが
   ずれたら generator バグ。`diff -q` で常時確認可
7. **`Domain/Phase0Types.swift` の field 順序 / 名前を変えない** —
   generated file の memberwise init が壊れる。field 追加 OK だが既存 field の
   順序 / 名前は不変。`FilmtonePhase0Params` の field 順は generated file の
   `paramKeys` 配列と一致している
8. **`SharedGenerated/FilmtonePhase0Generated.swift` は Compile Sources に入っている**
9. **(NEW Phase 1b) Responsibility Boundaries** (02-target-architecture-and-contracts.md):
   - `UI` は SwiftUI views と AppKit wrappers のみ。render math / file encoding /
     sidecar schema / long-running export work を持たせない
   - `State` は editor state + flow orchestration のみ。color math や file format
     を実装しない
   - `Color` は CIKernel / CIContext / preset catalog。SwiftUI/AppKit dep なし
   - `Export` は still/video encoding + sidecar emission。UI 所有なし
   - `Domain` は platform-neutral 型 + generated contract glue
   - 依存方向: `UI → State → Domain` / `UI → State → Color/Export/Media services` /
     `Export → Color/Domain` / `Color → Domain/SharedGenerated` / `App` は composition のみ

### 用語ロック (CLAUDE.md §6 antipattern #5)

- `動画` (× `短尺動画`) / `video` (× `short-form video`)
- canonical: life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
- video vocabulary lock: life commit `5ce6d55` (2026-05-01)
- UI 文字列: `Look` (Phase 1b で hardcode 採用、i18n は Phase 3 messages 統合まで)

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

## 6.5. Concurrent Lane: Desktop Look Unification (chat B 並列進行中)

**Native Desktop v2 (chat A、本 chat) と並行して chat B で進行中の lane**。
Phase 1c の sidecar 出力契約に直接影響する可能性あり。

### Lane 概要

- branch: `feature/desktop-look-unification`
- chat B worktree path (確定):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
- 再開 handoff (canonical):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
  (main checkout 側)
- 状態 (2026-05-03 JST): chat B 起動済。Phase A (core/schema 加算) は喪失前に
  完了して verify 通過、Phase B (Electron renderer + film-lab-ui sweep) 部分
  完了で worktree 喪失。chat B は **main へ Phase A 着地状況を grep verify
  してから再開**

### chat B の確定方針 (本 chat スコープ外、参考)

| # | 領域 | 方針 |
|---|---|---|
| 1 | `filmLabUiContract.ts` slot 名 (`beforePresets` → `beforeLooks` 等) | alias 残さず一気に rename |
| 2 | `batch-session` writer | `batchLookChoice` 単独 emit (Electron 専用 userData) |
| 3 | テスト fixture | 既存 `lookSource: "preset"` fixture は parser fallback regression 用に残す |
| 4 | iOS messages.ts 参照書き換え | 別 PR (本 PR は値だけ書き換え) |

### Phase 1c sidecar 契約 (Look Unification 着地状況で分岐、Phase 1b 同様)

**Phase 1c chat 開始時に main へ Look Unification が landed しているかで動作変更**:

| 状況 | macOS sidecar emitter の動作 |
|---|---|
| **Look Unification landed** | **dual emit** — legacy (`presetName` / `presetVersion`) と Look canonical (`lookId` / `lookVersion`) の両方を吐く。`normalizeFilmLookGradeInputIdentity()` を通せば identity 不一致が即 throw されるので必ず通す |
| **Look Unification 未 landed (現状)** | **Look canonical only** — `lookId` / `lookVersion` のみで書く (Phase 1b と同じ Case B) |

**判定方法** (Phase 1c chat 開始時に必ず実行、§11 参照)。

### Native Desktop v2 が依存する成果物 (Look Unification main 着地で利用可)

- `film-lab-core` の Look-first canonical 名 (旧 Preset 名は alias で残る、schema 加算のみ):
  - `BaseLookName = PresetName`、`BASE_LOOKS = PRESETS`、`BASE_LOOK_BUTTONS = PRESET_BUTTONS`、`FILMTONE_DEFAULT_BASE_LOOK = FILMTONE_DEFAULT_BASE_PRESET`、`findMatchingBaseLook = findMatchingPreset`
  - `LOOK_RECIPE_VERSION = PRESET_VERSION`、`lookIdForBaseLook = lookIdForPreset`、`LOOK_ID_BY_BASE_LOOK = LOOK_ID_BY_PRESET`
  - `filmLookGradeInputSchema` に optional `lookId` / `lookVersion` 追加
  - `normalizeFilmLookGradeInputIdentity()` で identity 不一致 throw
- Desktop sidecar dual emit:
  - `buildGradeJsonPayload` が `lookId` / `lookVersion` を追加 emit
  - `batch-pipeline` discriminator は `("lookPresetId" in o || "lookId" in o)`
- Batch session contract: `FilmLabBatchSessionV1` の on-disk shape は固定 (additive only)、parser fallback、writer canonical は `batchLookChoice`
- `lookSource` enum: `METADATA_LOOK_SOURCES` に `"builtInLook"` を canonical 追加
- i18n: `messages/en.json` / `ja.json` の `controls.presets` 系の値を Look 化 + 新 `controls.looks` キー追加

### Phase 段階別影響表

| Phase | Look Unification 着地済 | 着地前 |
|---|---|---|
| Phase 0 (skeleton) | 影響なし | 同左 |
| Phase 1b (still) | dual emit を継承 | **Look canonical only ← 現状採用** |
| **Phase 1c (video、次 chat)** | dual emit を継承 | Look canonical only (1b と同方針継続) |
| Phase 2 (color/render backbone) | 生成 Swift の Look 名 alias を generator 拡張に追加可能 | 生成器拡張は着地待ち |
| Phase 3 (native UI) | i18n 値は Look 化済 | macOS app は自前で Look 文言を持ち、後で messages へ統合 |
| Phase 4 (batch / session) | `FilmLabBatchSessionV1` parser fallback / `batchLookChoice` writer 仕様に従う | 旧 `batchPresetChoice` のみ書く |
| Phase 5 (release) | public copy / screenshot / release notes も Look 統一 | **release 前に Look Unification を着地必須** |

---

## 7. Phase 1c Scope (新 chat の本タスク)

### Goal

> Native Desktop が **動画** vertical slice を完結できる proof。short clip
> open → preview frame (with grade) → H.264 mp4 export → sidecar JSON → 既存
> reader で読める。

### Deliverables (vertical slice、1 個ずつ)

```
1. .mov / .mp4 1 個を NSOpenPanel で open
2. 代表 1 frame (e.g., midpoint) を CIImage 化して preview に表示 (grade 適用)
3. AVAssetReader / AVAssetWriter で H.264 mp4 を書き出す
   - per-frame CIImage → grade chain (Phase 1b と同じ FilmtoneGradePipeline) →
     CVPixelBuffer → AVAssetWriter
4. sidecar JSON を書く (Phase 1b SidecarWriter 拡張、Case A/B 分岐は §6.5 grep 結果に従う)
5. parity 検証 (任意、Phase 1b と同様 informational; baseline-B fixture mismatch
   は Phase 1c でも未解決)
```

batch UI / multi-clip は **作らない**。1 video / 1 preset で完結。

### Phase 1c Acceptance gate

- export された .mp4 が QuickTime / Finder で repair なしに開く
- 同じ params で iOS app の export (canonical) と visually matching (proxy gate
  として `macOS↔source` PSNR が non-trivial = 数十 dB 帯であることを確認、
  reset preset で frame-by-frame 一貫性チェック)
- preview frame と export が **同じ grade path** を通る (二重実装禁止)
- sidecar JSON が `parseFilmtoneExportSessionV1()` (Electron 側) で読める
- Liquid Glass UI が preview legibility を損ねない
- iOS Xcode project / Electron desktop は無傷 (`git status` empty)
- `bun run verify:macos` 通過、generator drift なし

### Phase 1c で書くべき Swift (predicted)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Color/
│   ├── FilmtoneCIContext.swift          (existing)
│   ├── FilmtoneGradeKernels.swift       (existing — kernel sources は再利用)
│   ├── FilmtoneGradePipeline.swift      (existing — per-frame CIImage に同じ chain)
│   └── FilmtonePresetCatalog.swift      (existing)
├── Media/                                # 新規 (02-architecture では既存予定スロット)
│   ├── FilmtoneVideoReader.swift        (AVAssetReader wrap、CVPixelBuffer 取得)
│   └── FilmtoneVideoWriter.swift        (AVAssetWriter wrap、H.264 settings)
├── Export/
│   ├── FilmtoneStillExporter.swift      (existing)
│   ├── FilmtoneVideoExporter.swift      (新規、reader → grade → writer chain orchestrator)
│   └── FilmtoneSidecarWriter.swift      (existing — `outputFile` 拡張子 .mp4 対応 / sourceKind 追加検討)
├── State/
│   └── EditorState.swift                (existing — videoURL / 進捗 % 追加)
└── UI/
    ├── RootWindowView.swift             (UPDATED: video file 受付、進捗 UI)
    ├── PreviewSurface.swift             (UPDATED: video frame 取得、scrubber 検討)
    └── GradeControls.swift              (existing)
```

iOS の `FilmtoneExportSession.swift` (4554 行) は session 管理 + AVFoundation
video + telemetry を含むが、telemetry は UIKit dep のため **選択 port のみ**
(master handoff §8 の Phase 1c lift 戦略)。最小限:
- video reader/writer の core flow (per-frame CIImage chain)
- color management (`FilmtoneColorPipeline.workingColorSpace()` などの helper)

### UUID 割り当て予算 (Phase 1c)

Phase 1b 最大値 A10 / B10 / E0A の次から:

| UUID | 種別 | 用途 |
|---|---|---|
| A11 ~ A18 | PBXBuildFile | 8 個分余裕 |
| B11 ~ B18 | PBXFileReference | 同上 |
| E0B | PBXGroup | Media |

---

## 8. iOS Swift Lift 戦略 (updated)

### Phase 1b で完了した lift

- `OpticalKernels.baseGradeV2` → `Color/FilmtoneGradeKernels.swift` (verbatim)
- `OpticalKernels.filmCompressionV2` → 同上
- `OpticalKernels.printStage` → 同上
- chain orchestration (iOS の `applyBaseGradeStage` / `applyToneCompressionStage` /
  `applyPrintStage` の epsilon gate) → `Color/FilmtoneGradePipeline.swift`

### Phase 1c で lift 候補

| iOS file | platform-neutral? | macOS 戦略 | 優先度 |
|---|---|---|---|
| `FilmtoneExportSession.swift` (静止画+動画) | partial (UIDevice telemetry あり) | video read/write の core flow のみ port、telemetry は `#if os(iOS)` か削除 | **Phase 1c 第一** |
| `FilmtoneColorPipeline.swift` | YES (CoreImage/CoreVideo/CoreGraphics、UIKit なし) — `workingColorSpace()` / `outputColorSpace()` helper | as-is lift (Phase 1c で AVFoundation writer の color metadata 設定に必要) | Phase 1c |
| `FilmtoneSourceProfileMath.swift` | YES (Foundation のみ) | as-is | Phase 2 |
| `FilmtoneSourceProfileCatalog.swift` | YES | as-is | Phase 2 |
| `FilmtoneCubeParser.swift` | YES | as-is | Phase 2 |
| `FilmtoneLutBlobCodec.swift` | YES (Foundation + CryptoKit) | as-is | Phase 2 |
| `FilmtoneMetalOpticsRenderer.swift` (985 行) | YES (Metal/CIImage、MTKView 不使用) | as-is、Phase 2 で bloom/halation/diffusion の WebGPU parity に使う | Phase 2 |
| `OpticalKernels.softKneeHighlight / glowComposite / motionFeedback / motionBlend / printStage` | YES (CIKL/CIColorKernel) | Phase 2 で optics chain 構築時に lift | Phase 2 |

### Method / DTO graph の段階的 port

`Domain/Phase0Types.swift` に method を足す時の原則:

- **使うものだけ** port。`asDTO()` が grade pipeline で使われていなければ port しない
- `applyingPatch()` / `value(for:)` / `setValue()` は preset 適用 + slider 編集で必要 (Phase 3 UI で必要になったら port)
- `Phase0ParamsDTO` は sidecar / export DTO 用。Phase 1b は `[String: Double]` 直書きで対応 (sidecar JSON の `gradeParams` field)
- 完全 graph (`FilmtoneProjectState` / `FilmtoneRequestBuildError` 等) は Phase 2 SPM 化と一緒にやる方が結果的に綺麗

---

## 9. Parity 検証セットアップ (現状と Phase 2 への持ち越し)

### Fixture 場所

```
apps/desktop-film-lab-batch/test/golden/
├── source-images/          (10 PNG: 01-highlight-sunset … 10-skin-dark)
├── baseline-A/<preset>/<image>.jpg   (80 files、8 presets × 10 images、Phase 0 WebGL JPEG Q=95)
└── baseline-B/<preset>/<image>.png   (80 files、post-hoc linearized reference、Phase 1 で生成)
```

### Phase 1b で landed した parity ハーネス

- `scripts/golden-parity-macos.ts` — macOS .app の `--export-still` を子プロセス
  実行、各 image を export して `compareAgainstBaselineB` で PSNR + `psnr` で
  source 比較、サマリー出力
- `scripts/compare-pngs.ts` — diagnostic 用、2 PNG の PSNR + max-Δ + sample
  pixel 4 点表示

### 既知の問題: baseline-B fixture mismatch (§5.5.5)

baseline-B は legacy WebGL render path 由来。iOS canonical CIColorKernel
pipeline (Phase 1b lift target) と stage graph が異なるため、PSNR > 35 dB
threshold は構造的に達成不可。**Phase 1c は同じ informational gate を継続使用**
し、Phase 2 で fixture 再生成または WGSL→Metal port のいずれかを通じて gate
再構築。

### Phase 1c の parity 戦略

- video parity の formal harness は Phase 2 まで保留
- Phase 1c は smoke + frame 1 枚の still parity (= Phase 1b ハーネス再利用) で gate
- video は QuickTime で開ける + sidecar が parse できる + frame visual 確認のみ

---

## 10. Sidecar Contract (Phase 1c で吐く JSON、現状 Case B)

### Phase 1b で landed した形式 (Case B、Look canonical only)

```json
{
  "schemaVersion": 1,
  "exportedAtIso": "2026-05-03T...",
  "appVersion": "0.1.0-macos",
  "appPlatform": "macos-native",
  "sourceFile": "/path/to/input.png",
  "outputFile": "/path/to/output.png",
  "gradeParams": { ... 35 fields from FilmtonePhase0Params ... },
  "batchLookChoice": {
    "lookId": "filmtone:base:reset:v2",
    "lookVersion": "v2",
    "baseLookName": "reset",
    "strength": 1.0
  },
  "lookId": "filmtone:base:reset:v2",
  "lookVersion": "v2",
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

### Phase 1c で必要な拡張

- `outputFile` の拡張子が `.mp4` に対応
- 必要なら `sourceKind: "video"` field 追加 (既存 reader が ignore できる additive field)
- 既存の Look canonical only / dual emit 分岐 logic を流用

### Source of truth (両 case 共通)

```
apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts
  — Zod schema、reader/writer entry。最も新しい contract version
apps/desktop-film-lab-batch/src/renderer/grade-io.ts
  — buildGradeJsonPayload (Look Unification 着地時 dual emit)
apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
  — discriminator (("lookPresetId" in o || "lookId" in o))
```

### Phase 1c 着手時の判定 (Look Unification 着地状況、必ず実行)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
# 全部 hit → Case A (dual emit、Phase 1b sidecar に legacy field 追加)
# どれか missing → Case B (Look canonical only、Phase 1b 同方針継続)
```

### Schema 不足が判明した時の対処

**Phase 1c 内で `packages/film-lab-core/src/` の contract を変更しない**
(Critical Invariant #4)。schema 変更が本当に必要なら:
1. handoff doc に `Phase 1c で発覚した contract 不足` セクションを追記
2. user に判断を仰ぐ (別 lane で議論、Look Unification PR への追加 / Phase 2 SPM と一緒の選択肢含む)
3. Phase 1c は **既存 schema の subset** で完結させる方向を優先

---

## 11. Verify Commands Cheat Sheet

```bash
# 全実行は worktree 内で (Look Unification check は main checkout で)
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# === Phase 1a + 1b sanity (新 chat 開始時に必ず実行) ===
git log --oneline -10
# expect: 398743c (Phase 0+1a) HEAD with Phase 1b uncommitted on top

bun run build:core
bun run generate:swift
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
# expect: identical

bun run verify:macos
# expect: ** BUILD SUCCEEDED ** (Phase 1b 込み)

bun run verify:ios
# expect: D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000

# === Phase 1b smoke (CLI export + parity) ===
mkdir -p test-out
apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop \
  --export-still \
  --input apps/desktop-film-lab-batch/test/golden/source-images/01-highlight-sunset.png \
  --output test-out/reset-01.png \
  --preset reset
# expect: ok 1280x720 ...test-out/reset-01.png + reset-01.filmtone.json

bun run scripts/golden-parity-macos.ts --preset reset
# expect: macOS↔source = ∞ (10/10 bit-identical), macOS↔baseB ≈ 13-14 dB (informational mismatch)

# === lane 無傷確認 ===
git status apps/desktop-film-lab-batch/   # expect: clean
git status apps/capacitor-film-lab-ios/   # expect: clean

# === Look Unification main 着地状況確認 (sidecar 契約分岐の判定) ===
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
# 全部 hit → Case A (dual emit、Phase 1c sidecar に legacy field 追加)
# どれか missing → Case B (Look canonical only、Phase 1b 同方針継続)

# === 起動 (smoke、user が手動) ===
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# expect: window 起動、⌘O → 画像選択 → 表示、Picker で preset 切替で preview 変化、
#         ⌘E → NSSavePanel → export → sidecar JSON 出力

# === Phase 1c 開発中 (頻繁に走らせる) ===
bun run verify:macos                          # ビルド常時 green キープ

# === life truth scripts (state 確認用、必要時) ===
FILMTONE_REPO_ROOT=$PWD /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
FILMTONE_REPO_ROOT=$PWD /Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼** (CLAUDE.md §5)。

---

## 12. Active Risks for Phase 1c

| Risk | 対策 |
|---|---|
| iOS `FilmtoneExportSession` の動画 path が UIDevice / UIKit telemetry と密結合 | `applyToneCompressionStage` / video reader/writer の core flow だけ port、telemetry は `#if os(iOS)` か削除。`grep "import UIKit\|UIDevice"` で UIKit 依存を最初に確認 |
| AVAssetReader/Writer の color metadata 設定ミスで HDR/SDR 崩れ | `FilmtoneColorPipeline.outputColorSpace()` (Rec.709) と `videoColorPrimariesTag` / `videoTransferFunctionTag` / `videoYCbCrMatrixTag` 設定を iOS 側から copy |
| per-frame CIImage chain の performance | Phase 1c は smoke proof。Phase 2 で IOSurface-backed CVPixelBuffer / Metal compute 検討 (`FilmtoneMetalOpticsRenderer` lift と合わせて) |
| baseline-B fixture mismatch (Phase 1b 同様) | Phase 1c でも informational gate のみ。Phase 2 で再構築 |
| OpticalFilters lane が main で landing → 合流 conflict | Phase 1c 着手時に main の状態を確認。conflict あれば user に判断仰ぐ |
| context budget 超過 | Phase 1c 内で video reader / writer / parity を同時に追えなくなったら、parity を Phase 2 に分離する判断 |
| 生成 Swift と Domain stub の field 順序 drift | generator が `paramKeys` 順で吐くので、`Phase0Types.swift` の `FilmtonePhase0Params` field 順序を `paramKeys` と揃える (現状揃っている、追加 / 並び替え NG) |
| iOS から `FilmtoneExportSession` をコピーした時に他 lift 候補 (例 `FilmtoneSourceProfileMath`) を chain で釣り上げてしまう | **Phase 1c は Phase0 grade only + video core flow**。source profile 連鎖は意識的に切る (Phase 2 まとめて) |
| Look Unification chat B が main へ landing → sidecar dual emit 必要 | §6.5 / §11 の grep を chat 開始時 + 中間時に再実行、変化があれば sidecar 動作切替 |
| Phase 1b が user の手で commit されない状態で Phase 1c に入る | 新 chat の最初に `git log --oneline -10` で `398743c` の上に Phase 1b commit があるか確認、無ければ user に commit を依頼してから Phase 1c 着手 |

---

## 13. Open Design Questions (Phase 1c で答える、推奨値付き)

| # | 質問 | 推奨 | 理由 |
|---|---|---|---|
| 1 | **video preview path**: 静止 frame 1 枚 / scrubber / playback | **静止 frame 1 枚 (midpoint)** | Phase 1c proof。scrubber/playback は Phase 3 (UI) に回す |
| 2 | **export format**: H.264 mp4 / ProRes / 両方 | **H.264 mp4 default、ProRes は option** | Phase 1c proof。AVAssetWriter で codec 切替 trivial |
| 3 | **per-frame chain**: AVAssetReader → CIImage → grade → CVPixelBuffer → Writer / 別 path | **AVAssetReader → CIImage → grade → CIContext.render(to: CVPixelBuffer) → Writer** | iOS canonical と同じ flow、CIContext 再利用 |
| 4 | **video reader 設定**: pixel format / colorspace | **kCVPixelFormatType_32BGRA + AVVideoAllowWideColor** | iOS `videoReaderOutputSettings` と一致 |
| 5 | **video writer 設定**: H.264 profile / bitrate | **AVVideoCodecH264 + High profile + 既定 bitrate** | iOS と同じ default、Phase 4 で codec/quality picker |
| 6 | **sidecar `outputFile` 拡張**: `.mp4` / `sourceKind: "video"` 追加 | **`.mp4` 拡張子 + 必要なら sourceKind 追加 (additive)** | parser ignore で互換 |
| 7 | **parity ハーネス**: video frame 1 枚で baseline-B 比較 / 別 metric | **frame 1 枚 still parity (Phase 1b 再利用)** | Phase 1c は wiring proof、formal video parity は Phase 2 |
| 8 | **Look Unification dual emit vs canonical only** | **§6.5 / §11 の grep 結果に従う** (Phase 1b 同方針) | landed なら dual emit、未 landed なら Look canonical only |
| 9 | **進捗 UI**: progress bar / cancel button | **progress bar (NSProgressIndicator wrap or SwiftUI ProgressView) + cancel** | long-running export なので必須、`@Observable` exportProgress field 追加 |

これらは Phase 1c chat 開始時に user に再確認 (推奨 vs 別案) して進める。

---

## 14. Reference Paths Cheat Sheet

### この worktree (実装する場所)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/
├── CLAUDE.md                                        # project rules、必読
├── README.md                                        # workspaces + scripts
├── package.json                                     # bun scripts
├── apps/
│   ├── filmtone-desktop-macos/                     # ★Phase 1c で拡張
│   │   ├── README.md                               # Phase 0+1a self-doc (1b 未反映)
│   │   ├── FilmtoneDesktop.xcodeproj/
│   │   └── FilmtoneDesktop/
│   │       ├── App/
│   │       │   ├── FilmtoneDesktopApp.swift        # Phase 1b で CLI mode 追加
│   │       │   └── AppCommands.swift
│   │       ├── Color/                              # Phase 1b 新設 ★
│   │       │   ├── FilmtoneCIContext.swift
│   │       │   ├── FilmtoneGradeKernels.swift     # iOS verbatim lift
│   │       │   ├── FilmtoneGradePipeline.swift
│   │       │   └── FilmtonePresetCatalog.swift
│   │       ├── Domain/                             # Phase 1a 新設
│   │       │   └── Phase0Types.swift
│   │       ├── Export/                             # Phase 1b 新設 ★
│   │       │   ├── FilmtoneStillExporter.swift
│   │       │   └── FilmtoneSidecarWriter.swift
│   │       ├── Media/                              # ★Phase 1c で新設予定
│   │       ├── SharedGenerated/                    # Phase 1a Compile Sources 取込
│   │       │   └── FilmtonePhase0Generated.swift
│   │       ├── State/                              # Phase 1b 新設 ★
│   │       │   └── EditorState.swift
│   │       ├── UI/
│   │       │   ├── RootWindowView.swift            # Phase 1b で Picker + Export
│   │       │   ├── GlassControlGroup.swift
│   │       │   ├── PreviewSurface.swift            # Phase 1b で grade 経由 render
│   │       │   └── GradeControls.swift             # Phase 1b 新設
│   │       └── Assets.xcassets/
│   ├── capacitor-film-lab-ios/                     # ★参照のみ、編集禁止
│   │   ├── CLAUDE.md                               # iOS 専用 invariants
│   │   └── ios/App/App/                            # iOS Swift sources (lift 元)
│   │       ├── FilmtoneExportSession.swift         # ★Phase 1c lift 第一候補 (4554 行)
│   │       ├── FilmtoneColorPipeline.swift         # color management helper (UIKit-clean)
│   │       ├── FilmtoneMetalOpticsRenderer.swift   # Phase 2 candidate (985 行)
│   │       ├── FilmtonePhase0Math.swift            # 781 行 (FilmtoneQuickState 等の正本)
│   │       └── FilmtoneMediaTypes.swift            # 763 行 (Phase0OutputProfileDTO 等)
│   └── desktop-film-lab-batch/                     # ★編集禁止、parity 参照
│       ├── test/golden/                            # baseline-A/B fixture
│       │   └── golden-psnr.ts                      # PSNR / pixelmatch ロジック
│       └── src/renderer/
│           ├── export-metadata-session.ts          # ★sidecar contract 正本
│           └── video-export-webcodecs.ts           # 静止画 export 参考 (動画は別)
├── packages/
│   ├── film-lab-core/src/
│   │   ├── ios-swift-payload.ts                    # Phase0 generator pure 関数
│   │   ├── ios-preset-overrides.ts                 # iphone / softBlue / amberGlow 定義
│   │   ├── phase0-schema.ts                        # PHASE0_PARAM_KEYS 等
│   │   ├── presets.ts                              # PRESETS + CONTRACT_DEFAULTS (legacy)
│   │   ├── split-tone-default-hues.ts              # FILM_LAB_DEFAULT_*_HUE
│   │   └── source-profile-conversion.test.ts       # parity test
│   ├── film-lab-renderer/
│   │   ├── src/webgpu/shaders/filmlab.frag.wgsl.ts # ★Phase 2 で Metal port 候補 (248 行)
│   │   ├── src/webgpu/gradeUniforms.ts             # tint 計算の TS 正本
│   │   └── dist/                                   # tracked、submodule 用
│   └── film-lab-smart-look/dist/                   # 同上
├── scripts/
│   ├── generate-filmtone-swift.ts                  # canonical generator
│   ├── generate-filmtone-ios-swift.ts              # shim
│   ├── golden-parity-macos.ts                      # Phase 1b 新設 ★
│   ├── compare-pngs.ts                             # Phase 1b 新設 (diagnostic)
│   ├── verify-ios.sh
│   ├── verify-desktop.sh
│   └── verify-phase0-contract.sh
└── docs/filmtone/desktop/
    ├── filmtone-native-desktop-transition-plan-2026-05-03-jst.md           # 全体計画書 index
    ├── native-desktop-transition-plan-2026-05-03-jst/                      # 詳細 split docs
    │   ├── 01-current-state-and-decision.md                                # SwiftUI-first stance 追加済
    │   ├── 02-target-architecture-and-contracts.md                         # ★Responsibility Boundaries 追加済
    │   ├── 03-migration-and-concurrent-lanes.md                            # ★Look Unification chat B 状況追加済
    │   ├── 04-phase-plan.md                                                # ★Phase 1b 着地状況追加済
    │   ├── 05-future-lanes.md                                              # SwiftUI-first 整合
    │   └── 06-quality-gates-risks.md                                       # ★baseline-B fixture mismatch リスク追加済
    ├── filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md  # 親 handoff (historical)
    ├── filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md # 子 handoff (historical)
    ├── filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md    # predecessor master (Phase 1b 開始時、historical)
    ├── filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md # ★Phase 1b 完了 handoff (本 master の元)
    └── filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md    # ★この doc (canonical)
```

### main checkout 側 (Look Unification handoff)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/
└── docs/filmtone/desktop/
    └── filmtone-desktop-look-unification-handoff-2026-05-03-jst.md         # ★Phase 1c sidecar 契約の正本
```

このリポは Native Desktop worktree なので Look Unification doc は **見えていない**。
main checkout 側の path を直接 Read する。

### chat B Look Unification worktree (read-only 参照)

```
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification/
```

本 chat (chat A) からは編集禁止。Look Unification の進行状況確認は main checkout 側の grep で行う。

### Phase 0 / Phase 1b 設計判断のメモ (worktree 外)

```
/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md
  — なぜ SPM を Phase 0 から外したか / なぜ SharedGenerated を Compile Sources
    から外したか (Phase 1a で解除) / UUID 命名規約 / Initial Plan Review

/Users/chibatakumi/.claude/plans/desktop-look-unification-bright-dusk.md
  — Look Unification lane の元 plan (chat B が消費)
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
| `project_v15_metal_optics_lane.md` | iOS v1.5 Metal optics、Phase 1 perf passed 95.6s、quality gate (視覚 A/B) PENDING (Phase 1c で iOS Xcode に触らない理由) |
| `project_phase1b_baseline_b_fixture_mismatch.md` | ★Phase 1b で発覚: baseline-B fixture は legacy WebGL 由来、iOS canonical CIKernel grade とは別 pipeline。PSNR gate は Phase 2 で再設計 |
| `reference_devicectl_env_var_launch.md` | `xcrun devicectl device process launch --environment-variables` で実機 env var |

これら以外に `MEMORY.md` にも index がある。**新規 memory 追加は user 明示指示がある時のみ**。

---

## 16. 引き継ぎ詳細プロンプト (新 chat に貼る用、最高精度版)

新 chat の **1 発目にこれを丸ごと貼る**。これだけで Phase 1c に satisfaction
で入れる。

```
このリポは Filmtone (forestone film-lab 系プロダクト)。Phase 0 (Skeleton) +
Phase 1a (Open + Preview precondition) + Phase 1b (preset → grade → still
export → sidecar → parity) が完了し、Phase 0+1a は commit `398743c` で
landed、Phase 1b は **uncommitted の状態で worktree 上にある**。今は Phase
1c (動画 vertical slice — open .mov → preview frame → H.264 mp4 export →
sidecar) を進めたい。

作業 worktree:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
branch: feature/native-desktop-plan

並行 lane (重要、sidecar 契約に影響):
- Desktop Look Unification (branch: feature/desktop-look-unification、
  worktree: /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification)
  が **chat B として並列起動済**。Phase 1c の sidecar emitter は main checkout
  への着地状況で動作分岐 (詳細は phase1c master handoff §6.5 / §10)。
- Phase 1b 着手時の grep では未 landed = Case B (Look canonical only) で書いた。
  Phase 1c chat 開始時に再 grep、状況変化があれば dual emit 切替。

最初に必ず以下を順番に読んで前 chat の文脈を完全復元してから作業に入る:

1. docs/filmtone/desktop/filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md
   ← 完全自己完結 master handoff (1500+ 行)。Phase 0/1a/1b 完成記録 + Phase 1c
   scope + 更新 invariants + Look Unification chat B 並列状況 (§6.5) +
   lift 戦略 (§8 updated) + parity セットアップ (§9、baseline-B fixture
   mismatch §5.5.5 含む) + sidecar contract Case B 採択済 (§10) + risks +
   open questions (§13) の推奨値が全部入っている。**skim 禁止、§0 から §17
   まで通読**。

2. docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md
   ← Phase 1b 完了 handoff (本 master の元一次資料)。実装内容 / parity 結果 /
   採択した §13 推奨値の確定理由がさらに詳細。

3. CLAUDE.md (worktree root) — project rules (8 項目の運用原則 + 6 antipattern)
4. apps/capacitor-film-lab-ios/CLAUDE.md — iOS 不変条件 (Phase 1c で iOS
   FilmtoneExportSession を lift する時の境界、223 行)
5. apps/filmtone-desktop-macos/README.md — Phase 0+1a の self-doc (Phase 1b
   landing は反映していないので master handoff §5.5 を信頼)
6. 全体計画書 split docs (本質、index は短い):
   - docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/
     02-target-architecture-and-contracts.md  ← ★Responsibility Boundaries 必読
     03-migration-and-concurrent-lanes.md     ← Look Unification chat B 並列詳細
     04-phase-plan.md                          ← Phase 1 acceptance gate + Phase 1b 着地状況
     06-quality-gates-risks.md                 ← baseline-B fixture mismatch リスク
7. Look Unification handoff (main checkout 側、このリポでは見えない):
   /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/
     filmtone-desktop-look-unification-handoff-2026-05-03-jst.md
   ← Phase 1c sidecar 契約 (BASE_LOOKS / lookId / lookVersion /
     normalizeFilmLookGradeInputIdentity) の正本

optional (深掘り時のみ):
- ~/.claude/plans/luminous-sparking-eclipse.md (Phase 0 plan-mode 議論)
- ~/.claude/plans/desktop-look-unification-bright-dusk.md (Look Unification 元 plan)
- docs/filmtone/desktop/filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md
  (Phase 1b 開始時の predecessor master、§16 プロンプト参考)

読み終わったら以下を実行して Phase 1a + 1b が現在も動くこと + Look
Unification main 着地状況を sanity check:

  # === Phase 1a + 1b sanity ===
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
  git log --oneline -10
  # expect: 398743c が HEAD か、その上に Phase 1b commit (新 chat 開始前に
  #         user が commit していれば追加 commit、未 commit なら 398743c のまま
  #         worktree dirty)

  bun run build:core
  bun run generate:swift
  diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
          apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
  bun run verify:macos
  bun run verify:ios
  git status apps/capacitor-film-lab-ios/
  git status apps/desktop-film-lab-batch/

  # Phase 1b smoke (CLI export + parity)
  mkdir -p test-out
  apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop \
    --export-still \
    --input apps/desktop-film-lab-batch/test/golden/source-images/01-highlight-sunset.png \
    --output test-out/reset-01.png \
    --preset reset
  bun run scripts/golden-parity-macos.ts --preset reset
  # expect: macOS↔source = ∞ (10/10 bit-identical), macOS↔baseB ≈ 13-14 dB
  #         (baseline-B fixture mismatch、informational only — master §5.5.5)

  # === Look Unification main 着地状況 ===
  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
  git log --oneline | grep -iE "look unification|baselook" | head
  grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
  grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
  # 全部 hit → Case A (dual emit、Phase 1c sidecar に legacy field 追加)
  # どれか missing → Case B (Look canonical only、Phase 1b 同方針継続)

全部通ったら Phase 1c の planning に入る。最初に user に確認すること:

(a) Phase 1b が現在 commit 済か未 commit か (`git log` で確認)。
    未 commit なら Phase 1c 着手前に commit を依頼する
    (memory feedback_dont_overengineer_dirty_state_split: 1 commit bundle 推奨;
     提案 commit message は完了 handoff §6.1 にある)。

(b) master handoff §13 の 9 つの open question の推奨値で進めて良いか:
    1. video preview path: 静止 frame 1 枚 (midpoint)
    2. export format: H.264 mp4 default + ProRes option
    3. per-frame chain: AVAssetReader → CIImage → grade → CIContext.render(to:CVPixelBuffer) → Writer
    4. video reader: kCVPixelFormatType_32BGRA + AVVideoAllowWideColor
    5. video writer: AVVideoCodecH264 + High profile
    6. sidecar 拡張: outputFile .mp4 + 必要なら sourceKind: "video" 追加 (additive)
    7. parity ハーネス: frame 1 枚 still parity (Phase 1b 再利用)
    8. sidecar dual emit vs canonical only: §11 grep 結果に従う (推測禁止)
    9. 進捗 UI: progress bar (NSProgressIndicator wrap or SwiftUI ProgressView) + cancel

(c) lift 開始時の grep で `FilmtoneExportSession.swift` の動画 path に
    UIKit/UIDevice 依存があった場合の対処方針 (削減 / `#if os(iOS)` / 削除)。

(d) Look Unification 未 landed (Case B) で Phase 1c も進める場合、Electron
    側 reader が catch-up するまで sidecar が Look-only になる。これを
    **明示的に user 了承** するか (sidecar の片読み期間が継続)。

絶対に守る invariants (master handoff §6 参照、ハードコア):
- iOS Xcode project (apps/capacitor-film-lab-ios/) を編集しない
  (v1.3 lane in-flight、Swift lift 元の read-only 参照は OK)
- Electron desktop (apps/desktop-film-lab-batch/) を編集しない
  (parity 比較で test fixture を read するのは OK)
- packages/film-lab-renderer/dist/ packages/film-lab-smart-look/dist/ を
  消さない (submodule track 用)
- packages/film-lab-core/src/ の contract source は変更しない
  (sidecar schema 不足判明時は user に判断仰ぐ、Look Unification PR への追加
   or Phase 2 SPM と一緒の選択肢含む)
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
- ★ Responsibility Boundaries (master §6 #9) 遵守:
  UI は SwiftUI views + AppKit wrapper のみ、render math/file encoding/sidecar
  schema を持たせない。State は flow orchestration、Color は CIKernel/CIContext、
  Export は encoding+sidecar、Domain は型のみ。Phase 1c の Media/ ディレクトリは
  この dependency direction に従って配置する。

設計判断は mcp__sequential-thinking で考える。記憶ベース断言は禁止。
不確かな API (AVFoundation / AVAssetReader / AVAssetWriter / CVPixelBuffer /
CIContext.render(to:) / CGImageDestination / sidecar Zod schema / Metal) は
gemini-search → WebSearch で必ず確認。

handoff 全文を読み終えたら:
  (i) 読んだ要約を 5 行で出す (Phase 0/1a/1b 結果 / Phase 1c deliverable /
      Look Unification 着地状況 / baseline-B fixture mismatch / 主要 risk を含む)
  (ii) 上記 (a)(b)(c)(d) を user に確認
  (iii) 実装着手前に Phase 0+1a が commit 済 (`398743c`) か git log で確認、
        Phase 1b の commit 状況も確認 (uncommitted なら user に commit を依頼)
```

---

## 17. このドキュメント自身について

- **role**: 完全自己完結 master handoff (canonical, Phase 1c chat 用)
- 作成者: Phase 1b 実装 chat (chat A.2、本 chat。Phase 0+1a 実装 chat と同一日)
- 作成時刻: 2026-05-03 JST
- 関連 doc:
  - `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md` —
    本 master の元一次資料 (Phase 1b 完了 handoff)
  - `filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md` —
    predecessor master (Phase 1b 開始時、historical)
  - `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md` —
    historical 親、Phase 0 完成記録の original
  - `filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md` —
    historical 子、master の前段で作った partial 版
  - `filmtone-native-desktop-transition-plan-2026-05-03-jst.md` — 全体計画書
- 更新タイミング:
  - Phase 1c 完了時に Phase 2 master handoff として書き直す
  - Phase 1c をスキップして Phase 2 へ直行する判断なら Phase 2 master へ
- canonical naming convention:
  `filmtone-native-desktop-phaseN-master-handoff-{date}-jst.md`
  (master = 自己完結型、partial pointer 系は `next-chat-handoff` を継続使用、
   completion record は `phaseN-completion-handoff` を使用)
- replaces: `phase1b-master-handoff` の「次 chat が読むべき canonical」役割を
  完全に引き受ける。Phase 1b master / completion / phase1-next-chat / phase1b-next-chat
  はいずれも historical record として残す。
