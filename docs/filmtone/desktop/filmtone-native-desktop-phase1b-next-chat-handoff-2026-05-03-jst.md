# Filmtone Native Desktop v2 — Phase 1b Next Chat Handoff

Date: 2026-05-03 JST (same day as Phase 0 + 1a)
Source chat: Phase 1a (Open + Preview precondition) 実装 chat
Target chat: Phase 1b (grade + still export + sidecar + parity) 実装 chat
Branch: `feature/native-desktop-plan` (worktree)

このドキュメントだけ読めば前 chat の議論・現状を完全に再現できる。冒頭から
末尾まで一読してから Phase 1b に着手すること。

---

## 0. Read-this-first 順序

新 chat の最初の 10 分:

1. このドキュメント全体 (Phase 1a 完成状態 + Phase 1b scope + invariants)
2. Phase 1 の親 handoff
   `docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
   (Phase 0 完成状態の exhaustive 記録、Liquid Glass / pbxproj UUID 規約 / Lift
   候補一覧 はここが正本)
3. 全体計画書
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   は index。Phase 1b の gate は split doc
   `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md`
   を参照
4. `apps/filmtone-desktop-macos/README.md` (Phase 0 + 1a の self-doc)
5. `git log --oneline -10` で worktree の commit 状態確認 (Phase 0 + 1a が
   commit 済か)
6. `bun run verify:macos` を即座に走らせて Phase 1a build が現在も通ること
   を確認

---

## 1. Where you are

### Repos / branch (Phase 1 親 handoff §1 と同じ、変更なし)

| repo | path | 役割 |
|---|---|---|
| **このリポ (worktree)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | branch `feature/native-desktop-plan` |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | 参照のみ |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts |

### Tooling versions (Phase 1a で再確認、変更なし)

- macOS 26.4.1 (Build 25E253) / Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3 / Swift 6.0

### Worktree commit 状態

- Phase 0 + Phase 1a は 1 つの作業 chunk として bundling 済 (推奨 1 commit)。
  user が commit したかは新 chat 開始時に `git log` で確認
- 未 commit なら最初に user に commit を依頼:
  ```
  git add -A
  git commit -m "feat(macos): Native Desktop v2 Phase 0 + 1a (skeleton + Open/Preview slice)"
  ```
- Phase 1b は同じ branch で続ける (PR は Phase 1c 完了時、または
  Phase 1b 完了時に分割 PR にする判断は user)

---

## 2. Phase 1a 完了記録 (この chat で追加されたもの)

### Acceptance gate 結果 (全 PASS)

| # | 検証 | 結果 |
|---|------|------|
| 1 | `bun run verify:macos` (Phase 1a 後) | `** BUILD SUCCEEDED **` |
| 2 | `bun run generate:swift -- --check` | exit 0 (drift なし) |
| 3 | `diff -q` iOS vs macOS Phase0Generated.swift | bit-identical 保持 |
| 4 | `bun run verify:ios` | D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000、sidecar pass |
| 5 | `git status apps/capacitor-film-lab-ios/` | clean (iOS lane 無傷) |
| 6 | `git status apps/desktop-film-lab-batch/` | clean (Electron lane 無傷) |

### Files added / modified (Phase 1a 分)

```
?? apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift   (新規、75 行)
?? apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift    (新規、51 行)
M  apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift    (NSOpenPanel 配線)
M  apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj  (BuildFile/FileRef/Group/Sources phase 拡張)
M  apps/filmtone-desktop-macos/README.md                                  (Phase 0+1a 状態反映)
```

### Decision A 採択結果

Phase 1 親 handoff §6 の precondition で挙げた「Decision A vs B」のうち
**A (型 dep を macOS にコピー、Phase 2 で SPM 集約)** を採択し実装済み。

`Domain/Phase0Types.swift` には次 4 struct を **memberwise init + stored
properties のみ** で duplicate:

- `FilmtoneQuickState` (3 fields)
- `FilmtonePhase0Params` (35 fields)
- `Phase0OutputProfileDTO` (5 fields)
- `FilmtonePhase0HiddenDefaults` (19 fields)

method / Codable / DTO graph (`Phase0ParamsDTO`, `ParsedCubeLutDTO`,
`Phase0ExportRequestDTO` 等) は **意図的に未 port**。Phase 1b で実際に必要に
なった分だけ追加する原則。

### pbxproj UUID 割り当て (新規分)

Phase 1 親 handoff §4 の UUID convention に従って次を追加:

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

次 (Phase 1b) で割り当てる時は **A09 / B09 / E08** から開始。

### SwiftUI 配線

- `RootWindowView` に `@State private var imageURL: URL?` 追加
- ツールバー右上 Open ボタン (`Label("Open", systemImage: "folder")`) + `⌘O`
  キーボードショートカット (`.keyboardShortcut("o", modifiers: .command)`)
- `presentOpenPanel()` で `NSOpenPanel` 起動 (`allowedContentTypes = [.image]`、
  `allowsMultipleSelection = false`)
- preview placeholder を `PreviewSurface(imageURL: imageURL)` に置換

### PreviewSurface 実装

- 外側: `Color.black` 背景 (color judgment 用、Apple HIG: content 層に glass を
  当てない原則維持)
- 内側分岐: `imageURL` あり → `PreviewImageView` (NSViewRepresentable)、
  nil → `EmptyPreviewLabel` (SF Symbol `photo` + caption)
- `PreviewImageView` は `NSImageView` を `imageScaling =
  .scaleProportionallyUpOrDown`, `imageAlignment = .alignCenter`,
  `imageFrameStyle = .none`, `isEditable = false` で wrap
- `updateNSView` で `NSImage(contentsOf: imageURL)` を毎回 reload
  (Phase 1a は最適化なし、Phase 1b で grade pipeline 経由に置き換わるので
  そのタイミングで cache 戦略決める)

### 残された手動 smoke (CLI から GUI 操作不可)

新 chat 開始前に user が確認しているはず:
```
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# 起動 → ⌘O → 画像選択 → 中央に表示
```

---

## 3. Phase 1b scope (新 chat の本タスク)

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

### Phase 1b Acceptance gate (全体計画書 Phase 1 から派生)

- export された PNG/JPEG が Finder / QuickTime で repair なしに開く
- 同じ params で Electron `baseline-B/<preset>/<image>.png` と PSNR > 35dB
  (loose tolerance、perfect parity は Phase 2)
- Source profile (D-Log / S-Log3 等) は **未対応 OK** (Phase 1b では sRGB
  入力のみ前提、Camera Profile picker は Phase 2 範疇)
- preview と export が **同じ grade path** を通る (二重実装禁止)
- sidecar JSON が `parseFilmtoneExportSessionV1()` (Electron 側) で読める
  (round-trip テスト不要、parse error なしを目視確認)
- Liquid Glass UI が preview legibility を損ねない
- iOS Xcode project / Electron desktop は無傷

### Phase 1b で書くべき Swift (predicted)

Decision A の続き (lift candidate 一覧は Phase 1 親 handoff §6 参照):

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Domain/
│   └── Phase0Types.swift              (existing、必要なら field 追加)
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

UUID 割り当て予算:
- BuildFile: A09 ~ A0F (7 個分余裕)
- FileRef: B09 ~ B0F
- Group: E08 (Color), E09 (Export), E0A (State)

---

## 4. Critical Invariants (Phase 1 親 §5 から **更新**)

Phase 1a で **Decision A 採択により次が変わった**:

### Phase 1a までで成立済み (壊さない)

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** —
   v1.3 local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。
   Phase 1b で iOS Swift から lift する場合は **read-only 参照 + 内容コピー**。
   iOS の `.pbxproj` には触らない
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** —
   release rail。Phase 4 まで shipping rail。**parity 比較で test fixture を
   read するのは OK**
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/`
   を消さない**
4. **`packages/film-lab-core/src/` の contract source は変更しない** — Phase 1b
   の sidecar schema 拡張が必要なら **別 lane** で議論する (handoff doc に
   `Phase 1b で発覚した contract 不足` セクションを追記して user 判断仰ぐ)
5. **生成 Swift を手編集しない** — generator only
6. **iOS と macOS の `Phase0Generated.swift` は bit-identical** — `diff -q` で
   常時確認
7. **`Domain/Phase0Types.swift` の field 順序を変えない / Codable を勝手に
   足さない** — generated file の memberwise init が壊れる。field 追加 OK だが
   既存 field の順序 / 名前は不変
8. **`SharedGenerated/FilmtonePhase0Generated.swift` は Compile Sources に
   入っている** (Phase 1a で wire 済) — Phase 1b で grade pipeline がここの
   `paramsByName` を参照する想定

### 用語ロック (CLAUDE.md §6 antipattern #5、変更なし)

- `動画` (× `短尺動画`) / `video` (× `short-form video`)
- canonical: life `docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`

### Bun mandatory (npm 禁止) / 出力ルール (変更なし)

- `bun install` / `bun run` / `bun add`
- 日本語、`path/to/file:line` 形式、簡潔・行動志向
- **Git 操作は user が実行** (auto commit 禁止)

---

## 5. iOS Swift Lift 戦略 (Phase 1b の核心)

### `FilmtoneColorPipeline.swift` の lift

Phase 1 親 handoff §6 で「YES (CoreImage / CoreVideo / CoreGraphics、UIKit
なし) → lift as-is」と分類済。**Phase 1b 開始時に必ず再確認すること**:

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
- `Phase0ParamsDTO` は sidecar / export DTO 用。sidecar が `params`
  field を含むなら port
- 完全 graph (`FilmtoneProjectState` / `FilmtoneRequestBuildError` 等) は
  Phase 2 SPM 化と一緒にやる方が結果的に綺麗

### Lift 元の探索

Phase 0 探査時 (`/Users/chibatakumi/.claude/plans/luminous-sparking-eclipse.md`)
の結論は Phase 1 親 handoff §6 にも転記済。Phase 1b では追加 lift 候補
として:

| iOS file | 用途 |
|---|---|
| `FilmtoneColorPipeline.swift` | grade chain 本体 |
| `FilmtoneSourceProfileMath.swift` | Phase 1b では未使用 (sRGB only)、Phase 2 で |
| `FilmtoneSourceProfileCatalog.swift` | 同上 |
| `FilmtoneCubeParser.swift` | Phase 1b は preset only、LUT は未対応 (Phase 2) |
| `FilmtoneLutBlobCodec.swift` | 同上 |

---

## 6. Parity 検証セットアップ (Electron baseline)

### Fixture 場所

```
apps/desktop-film-lab-batch/test/golden/
├── source-images/          (10 PNG: 01-highlight-sunset … 10-skin-dark)
├── baseline-A/<preset>/<image>.png   (80 files、8 presets × 10 images)
└── baseline-B/<preset>/<image>.png   (80 files、post-hoc linearized reference)
```

Phase 1b は **baseline-B** を参照 (Phase 1 親 handoff §6 で確定済)。

### 比較ツール (TS 既存)

- `apps/desktop-film-lab-batch/test/golden-psnr.ts` — PSNR
- `apps/desktop-film-lab-batch/test/golden.harness.ts` — pixelmatch

### Phase 1b parity ハーネスの選択肢

選択肢 A: macOS export PNG を bun script で読んで TS 既存ツールに食わせる
  - 利点: 既存 PSNR/pixelmatch ロジック再利用
  - 欠点: Swift ↔ TS の相互運用に script 1 個追加

選択肢 B: Swift 内部に簡易 PSNR 関数を書く
  - 利点: Swift 完結
  - 欠点: TS 結果と微差出る可能性 (libpng の RGBA 読み出し差等)

**推奨 A** (既存と同じ計算で比較できる方が信頼度高い)。`scripts/golden-parity-macos.ts`
を新規作成して `apps/filmtone-desktop-macos/test-out/` に export を吐かせる
flow。

---

## 7. Sidecar contract (Phase 1b で吐く JSON)

### Source of truth

```
apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts
  — Zod schema、reader/writer、最も新しい contract version
```

`parseFilmtoneExportSessionV1()` が Phase 1b の interop ポイント。

### Phase 1b で書く field (最小)

Phase 1 親 handoff §9 Risk より、必須のみ初版で吐く:

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
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

optional (LUT / source profile / quick state weights) は Phase 2 で。

### Round-trip 確認

Phase 1b chat 内で TS 側に scratch script (`scripts/verify-sidecar-roundtrip.ts`)
を作って `parseFilmtoneExportSessionV1(JSON.parse(...))` が throw しないこと
だけ確認。**書き込みは macOS 側、検証は TS 側** で双方向 schema integrity を
保証する最小構成。

---

## 8. Verify commands (Phase 1b 用 cheat sheet)

```bash
# 全実行は worktree 内で
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# Phase 1a sanity (新 chat 開始時に必ず実行、Phase 1 親 handoff §8 と同じ)
bun run build:core
bun run generate:swift
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
bun run verify:macos
bun run verify:ios

# Phase 1b 開発中 (頻繁に走らせる)
bun run verify:macos                          # ビルド常時 green キープ

# Phase 1b 完了 gate (新規)
# (a) export を実際に吐く (実装後に追加 script)
# bun run scripts/golden-parity-macos.ts --preset iphone --image 04-portrait-warm
# (b) sidecar round-trip
# bun run scripts/verify-sidecar-roundtrip.ts test-out/04-portrait-warm.json

# 不変条件確認
git status apps/capacitor-film-lab-ios/      # empty 必須
git status apps/desktop-film-lab-batch/      # empty 必須
```

---

## 9. Active Risks for Phase 1b

| Risk | 対策 |
|---|---|
| iOS `FilmtoneColorPipeline.swift` に UIKit dep が混入していたら lift 失敗 | 開始時に grep。混入があれば platform guard or 削減 (削減できないなら設計変更を user 確認) |
| CoreImage の color management 設定が WebGPU と微差 | ColorSpace 明示 (`CGColorSpace(name: CGColorSpace.sRGB)!`)。PSNR 35dB threshold で受ける、perfect parity は Phase 2 |
| `Phase0ParamsDTO` 不在で sidecar 書けない | Domain に DTO 追加 OR 直接 `[String: Double]` で書く (sidecar JSON 側は `[String: Double]` で問題ない) |
| sidecar Zod schema 解読負荷 | export-metadata-session.ts の Zod を読むのが正本。**手で「こう書けば動くはず」と推測しない** (`feedback_no_guessing_davinci_plugins` 適用) |
| AVFoundation 動画 export 検証は Phase 1c | Phase 1b では一切触らない。`#if os(macOS)` の動画関連コードを書かない |
| OpticalFilters lane が main で landing → 合流 conflict | Phase 1b 着手時に main の状態を確認。conflict あれば user に判断仰ぐ |
| context budget 超過 | Phase 1b 内で grade と export と parity を同時に追えなくなったら、parity を Phase 1c に分離する判断 |
| 生成 Swift と Domain stub の field 順序 drift | generator が `paramKeys` 順で吐くので、`Phase0Types.swift` の `FilmtonePhase0Params` field 順序を `paramKeys` と揃える (現状は揃っている、追加 / 並び替え NG) |

---

## 10. Open design questions (Phase 1b で答える)

Phase 1 親 §6 の Open Questions より、Phase 1b でついに actionable:

1. **Best preview path**: CoreImage-only / Metal-only / hybrid
   → **Phase 1b 推奨: CoreImage-only**。CIImage chain で grade を適用、
   `NSImageView` の代わりに `MTKView` ベースの surface に切り替えるかは
   Phase 2 (Native Color/Export Backbone) で決める
2. **`FilmtoneExportSession` の共有戦略**: as-is / split / 選択 port
   → **Phase 1b 推奨: 選択 port**。静止画 export 部分のみ。telemetry 系は
   `#if os(iOS)` で囲うか単純削除
3. **sidecar field set**: 必須のみ / full
   → **Phase 1b 推奨: §7 の最小 field set**。LUT / source profile は Phase 2
4. **preset picker UI**: dropdown / segmented / large card
   → **Phase 1b 推奨: dropdown** (`Picker` + `MenuStyle`)。large card は
   Phase 4 (UX polish) 範疇
5. **export format**: PNG only / JPEG only / both
   → **Phase 1b 推奨: PNG default + JPEG option**。both 実装は trivial
   (`CGImageDestination` の type 引数だけ変える)

---

## 11. 引き継ぎ詳細プロンプト (新 chat に貼る用)

```
このリポは Filmtone (forestone film-lab 系プロダクト)。Phase 0 (Skeleton)
+ Phase 1a (Open + Preview precondition) が完了し、今は Phase 1b
(grade + still export + sidecar + golden parity) を進めたい。

作業 worktree:
/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
branch: feature/native-desktop-plan

最初に必ず以下を順番に読んで前 chat の文脈を完全復元してから作業に入る:

1. docs/filmtone/desktop/filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md
   ← この一本に Phase 1a 完成記録 + Phase 1b scope + 更新 invariants + lift
   戦略 + parity セットアップ + sidecar contract + risks が exhaustive に
   まとまっている。skim 禁止、全文読む。

2. docs/filmtone/desktop/filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md
   親 handoff (Phase 0 完成記録、Liquid Glass facts、pbxproj UUID 規約、Lift
   候補一覧 はここが正本)

3. docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md
   全体計画書 index。Phase 1 gate は split doc
   docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md
   が正本

4. apps/filmtone-desktop-macos/README.md
   Phase 0 + 1a の self-doc

5. CLAUDE.md (worktree root) — project rules
6. apps/capacitor-film-lab-ios/CLAUDE.md — iOS invariants

読み終わったら以下を実行して Phase 1a が現在も動くことを sanity check:

  cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
  git log --oneline -10
  bun run build:core
  bun run generate:swift
  diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
          apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
  bun run verify:macos
  bun run verify:ios

全部通ったら Phase 1b の planning に入る。最初に user に確認すること:

(a) Phase 0 + 1a が commit 済か? 未 commit ならまず commit を依頼
    (git は user 実行)。
(b) handoff §10 の 5 つの open question の推奨値で進めて良いか:
    - preview: CoreImage-only
    - export session: 選択 port
    - sidecar: 最小 field set
    - preset picker: dropdown
    - export format: PNG default + JPEG option
(c) Phase 1b を 1 commit にまとめるか、grade 実装 / export+sidecar /
    parity ハーネスを別 commit に分けるか。

絶対に守る invariants (handoff §4 参照):
- iOS Xcode project (apps/capacitor-film-lab-ios/) を編集しない
- Electron desktop (apps/desktop-film-lab-batch/) を編集しない
  (test fixture を read するのは OK)
- packages/film-lab-renderer/dist/ packages/film-lab-smart-look/dist/ を
  消さない
- 生成 Swift (FilmtonePhase0Generated.swift) を手編集しない、generator のみ
- iOS と macOS の Phase0Generated.swift は bit-identical 維持
- Domain/Phase0Types.swift の field 順序 / 名前を変えない (memberwise init
  契約)
- bun mandatory、npm 禁止
- 用語ロック: 動画 / video、短尺動画 禁止
- git は user 実行 (auto commit 禁止)

設計判断は sequential-thinking で考える。記憶ベース断言は禁止。CoreImage /
CGImageDestination / sidecar Zod schema が曖昧な場合は gemini-search /
WebSearch で必ず確認。

handoff 全文を読み終えたら、まず読んだ要約を 5 行で出して、上記
(a)(b)(c) を user に確認すること。
```

---

## 12. このドキュメント自身について

- 作成者: Phase 1a 実装 chat
- 作成時刻: 2026-05-03 JST (Phase 0 + Phase 1a と同日)
- 親 handoff: `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
- 更新タイミング: Phase 1b 完了時に Phase 1c handoff として書き直す。または
  Phase 1c をスキップして Phase 2 へ直行する判断なら Phase 2 handoff へ
- canonical naming: `filmtone-native-desktop-phaseN-next-chat-handoff-{date}-jst.md`
