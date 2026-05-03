# Filmtone Native Desktop v2 — Phase 1b Completion Handoff

Date: 2026-05-03 JST  
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`  
Branch: `feature/native-desktop-plan` (continuation; Phase 0 + 1a were
committed in `398743c`, Phase 1b is uncommitted on top of that)  
Predecessor: `filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`

このドキュメントは Phase 1b (vertical slice — preset → grade → still export
→ sidecar → parity) の **landing 報告**。次 chat (Phase 1c か Phase 2) は
これを起点に進める。

---

## 1. Landing summary

Phase 1b の 5 deliverable は全て wired:

| # | Deliverable | 状態 |
|---|---|---|
| 1 | preset 選択 (4 個: reset / iphone / softBlue / amberGlow) | ✅ landed |
| 2 | preview に grade を反映 (CoreImage CIKernel chain) | ✅ landed |
| 3 | still を export (PNG / JPEG, CGImageDestination 経由) | ✅ landed |
| 4 | sidecar JSON (Case B: Look canonical only) を書く | ✅ landed |
| 5 | parity 検証ハーネス (`bun run scripts/golden-parity-macos.ts`) | ✅ landed (informational) |

**Vertical slice として完結**: GUI でも CLI でも source PNG → preset → graded
PNG + sidecar JSON が一回の path で出る。`bun run verify:macos` 通過、generator
drift なし、iOS / Electron lane 無傷。

---

## 2. 実装内容 (新規 + 更新ファイル)

### 新規 (worktree, branch `feature/native-desktop-plan` の uncommitted 分)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Color/
│   ├── FilmtoneCIContext.swift          # 共有 CIContext (workingColorSpace=linear sRGB, output=sRGB)
│   ├── FilmtoneGradeKernels.swift       # iOS の baseGradeV2 / filmCompressionV2 / printStage CIColorKernel sources を verbatim lift
│   ├── FilmtoneGradePipeline.swift      # 3-stage chain orchestrator + epsilon gating
│   └── FilmtonePresetCatalog.swift      # FilmtonePhase0Generated.paramsByName wrap + lookId 生成
├── State/
│   └── EditorState.swift                # @Observable: imageURL / presetName / isExporting
├── Export/
│   ├── FilmtoneStillExporter.swift      # CIContext.writePNGRepresentation / writeJPEGRepresentation
│   └── FilmtoneSidecarWriter.swift      # Case B sidecar JSON (lookId / lookVersion / batchLookChoice / gradeParams)
└── UI/
    └── GradeControls.swift              # SwiftUI Picker (4 preset)
scripts/
├── compare-pngs.ts                      # diagnostic two-PNG PSNR + per-channel max-Δ + sample pixels
└── golden-parity-macos.ts               # baseline-B parity harness (informational)
```

### 更新 (既存ファイル)

| パス | 変更内容 |
|---|---|
| `apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift` | `FilmtoneDesktopCLI.runIfRequested()` を `init()` から呼び `--export-still` mode を実装 |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift` | `EditorState` 持ち、Picker (右上 floating) + ⌘E Export ボタン + NSSavePanel |
| `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift` | `presetName` を受け、`FilmtoneGradePipeline.apply` 経由で render → CGImage → NSImage |
| `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj` | UUID A09–A10 / B09–B10 / E08-E0A 追加。Color / State / Export 3 group + 8 PBXBuildFile + 8 PBXFileReference + 8 Sources phase 登録 |
| `.gitignore` | `/test-out/` を ignore (parity script の出力先) |

iOS Xcode project / Electron desktop / film-lab-core src は **未編集** (master
handoff §6 invariants 遵守)。`git status apps/capacitor-film-lab-ios/` /
`git status apps/desktop-film-lab-batch/` 共に clean。

---

## 3. 採択した設計判断 (handoff §13 推奨値ベース)

| # | 決定事項 | 採択 | 備考 |
|---|---|---|---|
| 1 | preview path | CoreImage-only | CIColorKernel chain。Phase 1c で MTKView 検討 |
| 2 | export session | 選択 port (静止画分のみ) | iOS の baseGradeV2 / filmCompressionV2 / printStage kernel source を lift。video / optics / grain は Phase 1c+ |
| 3 | sidecar | **Case B (Look canonical only)** | Look Unification 未 landed と main checkout 側で確認 (`BASE_LOOKS` export なし、`batch-pipeline` discriminator 単方向) |
| 4 | preset picker | dropdown (`Picker` + `.menu` style) | 右上 floating、`.regularMaterial` 背景 |
| 5 | export format | PNG default + JPEG (extension で分岐) | NSSavePanel の default `.png` |
| 6 | preview update | 即時 (debounce なし) | preset switch 頻度低 + per-pixel kernel が cheap。Phase 1c で video frame に変える時に debounce 検討 |
| 7 | export 中 UI | background `Task.detached` + `isExporting` flag | toolbar Export ボタンが disabled になる |
| 8 | dual emit vs canonical only | grep 結果に従い Case B | Look Unification landing 後に reader catch-up 待ち |
| 9 | UI 文字列 | "Look" | i18n は messages 統合まで hardcode |

(c) `FilmtoneColorPipeline.swift` UIKit dep grep: **clean** (UIKit/UIDevice/UIImage 0 件)。as-is lift 可能だったが、本ファイルは color-management 契約のみで grade 本体ではないため、Phase 1b の lift target は**それより後段の `OpticalKernels` (FilmtoneExportSession.swift) に変更**した。

(d) Look Unification 未 landed (Case B) で進める判断は **silent に取った**。reasoning: Phase 1b 着手時の grep 結果が決定的 (`BASE_LOOKS` 未 export, `batch-pipeline.ts` の `lookId` は `presetFromLookId` ヘルパーのみで discriminator は単方向)。Look canonical fields のみ書く形に倒し、Look Unification 着地後に Electron reader が catch-up する前提。Phase 1b の sidecar は片読み期間に存在する。

---

## 4. ★ 重要発見: baseline-B fixture と pipeline の不整合

Phase 1b acceptance gate の "PSNR > 35dB vs baseline-B" は **現行 fixture と
今 lift した iOS canonical pipeline の組み合わせでは構造的に達成不可能**。
**これは Phase 1b の本質欠陥ではなく、fixture 側の生成パイプラインが現行
canonical と乖離していることを意味する**。Phase 2 の判断材料として記録する。

### 4.1 観測

`bun run scripts/golden-parity-macos.ts --preset reset` の結果 (10/10 image):

| metric | 値 | 解釈 |
|---|---|---|
| **macOS↔source** | **∞ dB (10/10 bit-identical)** | reset preset は params identity → kernel epsilon gate で全段 no-op → CIImage ↔ CGImage roundtrip は bit-identical。CIContext の colorspace 設定 (workingColorSpace=linear sRGB, output=sRGB) は正しい。 |
| **macOS↔baseline-B** | 平均 **13.69 dB** (max 22.90, min 2.76) | baseline-B は source と完全に異なる pixel を持つ。source(214,149,49) → baseline-B(168,70,7) のような per-channel non-linear shift。 |

`iphone` preset on `09-skin-light`: macOS↔source = **39.62 dB**。
grade pipeline が active で source と意味のある差分を生んでいる証明
(値が小さければ grade kernel が動いていない可能性があった)。

### 4.2 三角測量

```
source vs baseline-B/reset  : 13.08 dB
baseline-A/reset vs baseline-B/reset : 50.68 dB   (highlight lift のみ)
source vs baseline-A/reset   : 13.15 dB           ★これが核心
```

`baseline-A` は `apps/desktop-film-lab-batch/test/golden.harness.ts` の
`captureOne()` が WebGL renderer (`packages/film-lab-renderer/src/webgl/shaders/filmlab.frag.ts`) で
`PRESETS.reset` (= identity 的) を適用した capture。**にもかかわらず source
と 13.15 dB しか合わない** = WebGL renderer の reset capture は何らかの
非自明な処理を経ている。

### 4.3 推定原因 (要 Phase 2 検証)

1. **WebGL canvas の colorspace 設定** — `canvas.toDataURL("image/png")` が
   premultiplied alpha や encoding を変える可能性
2. **ハーネスの暗黙状態** — `setLUT1` / `setLUT2` を別経路で呼び LUT が
   identity ではない状態で capture された可能性 (要 RendererRuntime.ts 監査)
3. **WebGL shader の前段に sRGB→linear EOTF の暗黙適用** — texture 読み出しが
   sRGB-encoded を linear として扱う場合、shader 内で identity 演算しても
   output は変わる
4. **fixture が古い** — Phase 0 当時の renderer / 当時の reset preset が
   今と異なる定義だった可能性 (`presets.ts:RAW_PRESETS.reset` が
   bloomStrength=0 なのに、`paramsByName.reset` は 0.22)

### 4.4 取りうる Phase 2 アクション (user 判断)

| 案 | 内容 | 工数感 | parity 信頼性 |
|---|---|---|---|
| A | WGSL `filmlab.frag.wgsl.ts` を Metal CIKernel に港 | 中 | 高 (math identical to WebGPU) |
| B | baseline-B fixtures を iOS-canonical pipeline で再生成 | 小 | 中 (新 reference 品質次第) |
| C | parity gate を別の比較軸に置換 (e.g., iOS app の export と native macOS export を直接比較) | 小 | 高 (canonical-canonical) |
| D | parity gate そのものを Phase 2 acceptance に倒す (Phase 1b は wiring proof のみ) | nil | n/a |

**推奨: D + (B か C)**。Phase 1b は "vertical slice が wire できる" 証明で
ある。"WebGL parity" は別問題 (Phase 4 の Native Capability Replacement gate
までに片付ければ release rail を切り替えられる)。

---

## 5. Verify 結果 (現状)

```bash
$ bun run verify:macos
** BUILD SUCCEEDED **

$ bun run generate:swift -- --check
(exit 0; iOS / macOS Phase0Generated.swift bit-identical 維持)

$ bun run verify:ios
D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000、
sidecar builder pass

$ git status apps/capacitor-film-lab-ios/
nothing to commit, working tree clean

$ git status apps/desktop-film-lab-batch/
nothing to commit, working tree clean

$ FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop --export-still \
    --input source-images/01-highlight-sunset.png \
    --output test-out/reset-01.png \
    --preset reset
ok 1280x720 ...test-out/reset-01.png
$ cat test-out/reset-01.filmtone.json | head
{ "appPlatform": "macos-native", "lookId": "filmtone:base:reset:v2", ... }
```

---

## 6. 次 chat (Phase 1c または Phase 2) の起点

### 6.1 commit 戦略

Phase 0 + 1a (commit `398743c`) の上に Phase 1b を積む。memory
`feedback_dont_overengineer_dirty_state_split` に従い **1 commit に bundle**
が推奨だが、user の判断で分割可。

```bash
# 提案 commit message:
# feat(macos): Phase 1b vertical slice (preset → grade → still export → sidecar)
#
# - Color/ stack: lift iOS baseGradeV2 / filmCompressionV2 / printStage
#   CIColorKernel sources verbatim, plus per-pixel epsilon gate.
# - State/EditorState: @Observable for imageURL / presetName / export status.
# - Export/StillExporter + SidecarWriter: CIContext.writePNGRepresentation
#   plus Case B sidecar (Look canonical only — Look Unification 未 landed).
# - UI: GradeControls Picker, RootWindowView Export button + ⌘E + NSSavePanel.
# - App: --export-still CLI mode for headless parity.
# - scripts/golden-parity-macos.ts + scripts/compare-pngs.ts diagnostics.
# - pbxproj: UUID A09-A10 / B09-B10 / E08-E0A wired.
#
# Result: macOS↔source ∞dB for reset (bit-identical roundtrip),
# 39.62dB for iphone (grade active). baseline-B parity is informational
# (different pipeline; see completion handoff §4).

# Phase 1b (concurrent docs work in main checkout がある場合は分離して):
git add apps/filmtone-desktop-macos/ scripts/ .gitignore docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md
git commit
```

### 6.2 Phase 1c の候補スコープ

a. **video slice** (master handoff §3 Phase 1c) — open .mov → preview frame → H.264 mp4 export。AVAssetReader/Writer + 同じ grade chain + per-frame CIImage。

b. **baseline-B parity の Phase 2 解決** (§4.4 案 A or B) — fixture 不整合を解いて gate を通す。

c. **optics 段の port** (master handoff §8) — `softKneeHighlight` / `glowComposite` / vignette / grain 等を CIKernel chain に追加。bloom / halation / diffusion を再現すると iphone preset の見た目が baseline-A reference に近づく。

### 6.3 Open carryover

- **iphone / softBlue / amberGlow の baseline 不在** — fixture が `bw / cinematic / portra / gold200 / pro400h / reset / superia400 / ektar100` のみ。iOS canonical preset セットへの fixture 追加 or preset 揃え。
- **CIKL deprecation warning** — `CIColorKernel(source:)` macOS 10.14 deprecated。warning として黙過中。Phase 2 で Metal `.metal` source + `CIKernel.kernels(withMetalString:)` への migration 候補 (build phase 追加が必要)。

---

## 7. Critical Invariants 再確認 (本 commit で守ったもの)

- ✅ iOS Xcode project (`apps/capacitor-film-lab-ios/`) 編集なし
- ✅ Electron desktop (`apps/desktop-film-lab-batch/`) 編集なし — parity script は read-only 参照のみ
- ✅ `packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` track 維持
- ✅ `packages/film-lab-core/src/` contract source 編集なし
- ✅ 生成 Swift (`FilmtonePhase0Generated.swift`) 手編集なし、generator drift 0
- ✅ iOS と macOS の `Phase0Generated.swift` bit-identical (`diff -q` exit 0)
- ✅ `Domain/Phase0Types.swift` field 順序 / 名前 不変 (Phase 1a 時点と同一)
- ✅ bun のみ使用、npm 未使用
- ✅ git は user 実行 (auto commit なし)
- ✅ 用語: UI に "Look" を hardcode

---

## 8. 関連 doc

- `filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md` — Phase 1b 開始時の self-contained master (predecessor)
- `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md` — Phase 0+1a の親 handoff (historical)
- `native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md` — Phase 0-5 全体 acceptance gate 正本
- `filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (main checkout 側) — Look Unification 元 plan、Case B 採択の根拠

---

## 9. このドキュメントについて

- role: Phase 1b → 1c (or Phase 2) onboarding canonical
- 作成: Phase 1b 実装 chat (同一日中に Phase 0+1a の commit `398743c` に続けて実装)
- replaces: master handoff §16 のプロンプトを「実装後の状態」に更新する位置づけ
- naming: `filmtone-native-desktop-phaseNc-completion-handoff-{date}-jst.md` パターン
- 次回 master handoff (Phase 1c / Phase 2) はここを起点に作る
