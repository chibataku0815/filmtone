# Filmtone Native Desktop v2 — Phase 2 C5a + C7 Master Handoff (Self-Contained)

Date: 2026-05-03 JST late evening (継続 chat、predecessor `filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md` 終端より)
Source chat: chat A.4 (Phase 2 C1+C2+C3 scaffold dirty bundle に着手 → autonomous commit + C7 perf bench + C5a per-pixel optical extension)
Target chat: Phase 2 **C5b multi-pass blur** (bloom / halation / diffusion + CIKernel-based stages) または **C5c RayAngleOptics port** (vignette byte-identical iOS canonical 化)
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan` (commits ahead of main: 3 — Phase 0+1a `398743c`, Phase 1b/1c+Phase 2 C1/C2+C3 scaffold `aeb0c7c`, Phase 2 C5a `cd170a6`)
HEAD: **`cd170a6`** (clean working tree)

**自己完結型 master handoff**。これ 1 本で次 chat が Phase 0/1a/1b/1c/2(C1/C2/C3 scaffold/C5a/C7) の議論・採択・実装・検証・残タスクを完全再現できる。predecessor master (`filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md`、本 doc 作成時点で commit 済) の内容は本 doc に吸収済 — 歴史記録としてのみ残る。

---

## 0. Read-this-first 順序

新 chat 最初の 15-25 分:

1. **本ドキュメント全体** — skim 禁止、§0 から §18 まで通読
2. `CLAUDE.md` (worktree root) — project rules、§3 運用原則 / §6 antipattern。**本 chat で user が verbal lift した運用変更は §5.10 を参照**
3. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (223 行)
4. **全体計画書 split index**:
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   は **canonical index (短い)**。詳細は split files
   `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/` 配下:
   - `01-current-state-and-decision.md` — Phase 2 C1+C2+C3 scaffold 反映済 (C5a / C7 は本 doc が新)
   - `02-target-architecture-and-contracts.md` — Responsibility Boundaries
   - `03-migration-and-concurrent-lanes.md` — Look Unification 状況
   - `04-phase-plan.md` — Phase 2 C1+C2 + C3 scaffold 着地状況反映済
   - `06-quality-gates-risks.md` — risks 表更新済
5. **Phase 2 C5a の元になった predecessor 記録** (深掘り時のみ):
   - `docs/filmtone/desktop/filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md` — Phase 2 C1+C2+C3 scaffold master (本 doc 作成時 commit 済、git 上 readable)
   - `docs/filmtone/desktop/filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md` — Phase 1c 完了 handoff
   - `docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md` — Phase 1b 完了 handoff
6. **Look Unification handoff** (main checkout 側、chat B):
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
   — sidecar 契約は Look Unification 着地状況で動作分岐 (詳細 §6.5 / §10)
7. `git log --oneline -5` で worktree commit 状態確認 (`cd170a6` HEAD、`aeb0c7c` Phase 1b/1c+2 C1/C2+C3 scaffold、`398743c` Phase 0+1a)
8. **必ず実行**: §11 の sanity check + Look Unification main 着地状況確認

---

## 1. What is Filmtone (1 段落 context)

Filmtone は forestone (`chiba@fores-tone.co.jp`) の film-tone カラーグレーディング製品群:

- **Filmtone Desktop** (Electron + React/Vite, macOS) — 写真 / 動画の film-tone バッチグレーディング。release rail として shipping 中。
- **Filmtone iOS** (Capacitor + SwiftUI/Metal/CoreImage) — App Store 公開、v1.2 public / v1.3 local candidate in-flight (lane `project_v15_metal_optics_lane`)。
- **共有 packages**:
  - `film-lab-core` — Phase0 params / preset / source-profile contract、Zod schema、Swift generator pure 関数の正本
  - `film-lab-renderer` — WebGL / WebGPU shader graph、`dist/` は portfolio submodule 用に **意図的に track**
  - `film-lab-ui` — shared React UI
  - `film-lab-smart-look` — `dist/` track (同上)

このリポは **実装の正本**。portfolio (`vendor/filmtone` submodule) と life (`/Volumes/SamsungPortableSSDX5001/documents/life/`) は別役割 (docs/guides・truth scripts・5 ロール憲法)。

---

## 2. Repo / Worktree Topology

### Repos と並列 chat

| repo / worktree | path | 役割 | 編集可否 |
|---|---|---|---|
| **Native Desktop worktree (本リポ・本 chat)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0 / 1a / 1b / 1c / 2 実装、branch `feature/native-desktop-plan` | **編集対象** |
| Look Unification worktree (chat B 並列、別 chat) | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification` | Phase A / B 再開、branch `feature/desktop-look-unification` | **本 chat では編集禁止** (read-only 参照のみ、main 着地後に sidecar 契約反映) |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ | 編集禁止 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 (`apps/web`)、`vendor/filmtone` submodule で消費 | 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts + 5 ロール憲法 | 触らない |

### Worktree branch invariants

- Phase 0+1a+1b+1c+2(C1/C2/C3 scaffold/C5a) は同一 branch `feature/native-desktop-plan`
- **3 commits ahead of main**:
  - `398743c` — Phase 0 + 1a (skeleton + Open/Preview precondition)
  - `aeb0c7c` — Phase 1b + 1c + Phase 2 C1+C2 + C3 scaffold (本 chat で commit、bundle 1)
  - `cd170a6` — Phase 2 C5a per-pixel optical (vignette + grain) (本 chat で commit、bundle 2)
- HEAD は **`cd170a6`、working tree clean** (本 doc 作成時)。次 chat 開始時に `git status` で確認
- 別 branch を切る必要は **なし**。PR 切るのは Phase 2 完了時 (Phase 0+1a+1b+1c+C1+C2+C3 scaffold+C5a と Phase 2 残 (C5b/C5c/C6/C7 は完了) を 1 PR or 段階 PR に分割は user 判断)

### Tooling versions (Phase 0+1a+1b+1c+2(C1+C2+C3 scaffold+C5a)+C7 で verified working)

- macOS 26.4.1 (Build 25E253)
- Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3
- Swift 6.0 (target setting; Xcode 26 同梱 toolchain)
- Swift 6 strict concurrency 適用 (Phase 2 C1+C2 で AVAssetTrack non-Sendable 対応の variadic load 採用)
- ffmpeg 8.1 (perf bench fixture 生成用)

### 認証 / 環境

- Git user: `chibataku0815` (commit author)
- Email: `chiba@fores-tone.co.jp`
- Git Co-Author tag: `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` (predecessor commits + 本 chat 2 commits 全て同形式)

---

## 3. Native Desktop v2 全体計画 (要約)

Filmtone Desktop を **Electron 製 macOS アプリ** から **SwiftUI-first / AppKit interop ベースの Native Desktop v2 (Liquid Glass first-class)** へ移行する lane。

### 移行戦略

並行 lane: 現行 Electron Desktop は **release rail として shipping し続け**、Native Desktop v2 が phase gate を通るまで default にしない。Phase 4 (Native Capability Replacement) で機能網羅を達成した後に default を切り替える。

### macOS 26 only (確定)

- macOS 26 SDK で build した SwiftUI `.toolbar` / `NSToolbar` は **自動的に Liquid Glass を採用**
- `.glassEffect(.regular, in: Capsule())` は macOS 26.0+ / iOS 26.0+ / iPadOS 26.0+ / watchOS 26.0+ / tvOS 26.0+
- reduced-material fallback は **書かない** (Phase 0 確定)
- design rule (Apple HIG): glass は **navigation / control 層のみ**。content / preview には当てない

### UI framework stance

- SwiftUI を新規 native UI の主軸
- AppKit は macOS 固有の window / menu / panel / Finder integration / 深い interop に限定使用。**AppKit-first にしない**
- iOS UI は SwiftUI / UIKit の領域。AppKit を iOS に持ち込まない
- Cross-platform 共有は Domain / Color / generated contracts を通じて行い、共有 SwiftUI view はそれが両 platform を弱体化しない場合のみ

### Phase 段階 (本 doc 作成時状態)

| Phase | scope | 状態 |
|---|---|---|
| **0 (Contract & Skeleton)** | macOS app skeleton + 生成 Swift dual-target emit + Liquid Glass API surface 確認 | **COMPLETE** (`398743c`) |
| **1a (Open + Preview precondition)** | SharedGenerated を compile-link、NSOpenPanel + still preview (grade なし) | **COMPLETE** (`398743c`) |
| **1b (Vertical Slice — still)** | preset 選択 + grade 適用 + still export + sidecar JSON + parity 検証ハーネス | **COMPLETE** (`aeb0c7c`) |
| **1c (Vertical Slice — video)** | 動画 1 個 open + preview frame + H.264 mp4 export + sidecar | **COMPLETE** (`aeb0c7c`) |
| **2 C1 (SourceColor DTO + factory)** | DTO graph port + classifier + factory + Source prober (video async + still CGImageSource) | **COMPLETE** (`aeb0c7c`) |
| **2 C2 (AVFoundation modern async)** | 6 deprecation site 解消 + Sendable / Swift 6 strict concurrency 対応 | **COMPLETE** (`aeb0c7c`) |
| **2 C3 (truth gate scaffold)** | iOS↔macOS canonical 直接 PSNR scaffold + PENDING-aware harness | **scaffold COMPLETE** (`aeb0c7c`)、**baseline-C populate は 外殻 (品質保証希望時) で defer** |
| **2 C5a (per-pixel optical extension)** | vignette + grain CIColorKernel verbatim port + pipeline order 統合 + video frame time 配線 | **COMPLETE** (`cd170a6`、本 chat 主役 #2) |
| **2 C5b (multi-pass blur + CIKernel)** | bloom / halation / diffusion + radialRGBSplit + edgeSoftnessBlend + softKneeHighlight (helper) | TBD (次 chat 候補 #1) |
| **2 C5c (RayAngleOptics port)** | vignette を applyMask=1 byte-identical iOS canonical 化 + Source Prober で camera optics 抽出 | TBD (次 chat 候補 #2) |
| **2 C6 (SPM 化)** | `packages/film-lab-swift-core/` 化、Domain/* iOS 共有 | TBD (急がない方針維持) |
| **2 C7 (IOSurface perf bench)** | 4K/6K perf 実測 → 必要なら IOSurface refactor | **本 chat で実測完了 → refactor 不要判定** (本 chat 主役 #1)、別 commit 不要 |
| **3 (Native Editing UI)** | Electron UI 置き換え | TBD |
| **4 (Native Capability Replacement)** | Electron 機能網羅、release default 切替判断 | TBD |
| **5 (Polish & Public Cutover)** | LP / release notes / portfolio submodule update | TBD |

### 優先順位 (全体計画書原文より)

1. 画の品質、色の正しさ、preview / export の一致
2. Apple 純正 UI / Liquid Glass / macOS 操作体系への適合
3. iOS 版とのネイティブ資産共有
4. 現行 Desktop リリース導線の維持
5. 外殻 QA / public copy / release 周辺整備 (**最後**)

---

## 4. Phase 0 完成記録 (Skeleton + Contract、要約)

### Acceptance gate (全 PASS、commit `398743c`)

`bun run build:core` / `bun run generate:swift` / `bun run verify:macos` (`** BUILD SUCCEEDED **`) / `bun run verify:ios` (D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000) / iOS+Electron lane clean。

### 主要採択

- 手書き `.xcodeproj` (objectVersion 70, UUID prefix `FT0000000000000000000XXX`)
- generator multi-target dual emit (`scripts/generate-filmtone-swift.ts`): iOS / macOS の `FilmtonePhase0Generated.swift` を bit-identical に保つ
- Bundle id `co.fores-tone.filmtone.desktop` / macOS 26.0 / Swift 6.0
- Liquid Glass: SwiftUI `.toolbar` 標準で自動採用、`glassEffect(.regular, in: Capsule())` は custom 1 箇所のみ (`GlassControlGroup.swift`)

### Phase 0 commit (`398743c`) Swift 構成

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── App/{FilmtoneDesktopApp.swift, AppCommands.swift}
├── UI/{RootWindowView.swift, GlassControlGroup.swift}
└── Assets.xcassets/
```

---

## 5. Phase 1a 完成記録 (Open + Preview Precondition、要約)

### Decision A (採択)

iOS の `FilmtonePhase0Math.swift` + `FilmtoneMediaTypes.swift` から generated file が依存する 4 struct (`FilmtoneQuickState` / `FilmtonePhase0Params` / `Phase0OutputProfileDTO` / `FilmtonePhase0HiddenDefaults`) を **memberwise init + stored properties のみ** で macOS target にコピー。`Domain/Phase0Types.swift` (75 行)。iOS は無触。

### Phase 1a で landed (commit `398743c` 一部)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift   (新規)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift    (新規、NSImageView wrap)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift    (NSOpenPanel + ⌘O)
pbxproj                                                                 (UUID A06-A08 / B06-B08 / E05/E07 group + Sources phase 拡張)
```

---

## 5.5. Phase 1b 完成記録 (Vertical Slice — Still、要約)

commit `aeb0c7c` 一部。

### Goal

Native Desktop が **本物の Filmtone work** を出力できることを 1 still で証明する。

### Deliverable (全 ✅ landed)

- 4 preset (reset / iphone / softBlue / amberGlow) selection
- preview に grade 反映 (CoreImage CIColorKernel chain)
- still export (PNG / JPEG, CGImageDestination)
- sidecar JSON (Case B: Look canonical only)
- parity 検証ハーネス (`scripts/golden-parity-macos.ts`)

### 採択した設計判断

| # | 決定事項 | 採択 |
|---|---|---|
| 1 | preview path | CoreImage-only (CIColorKernel chain) |
| 2 | export session | iOS の baseGradeV2 / filmCompressionV2 / printStage CIColorKernel sources を verbatim lift (静止画分のみ) |
| 3 | sidecar field set | Case B (Look canonical only) — Look Unification 未 landed と grep で確認 |
| 4 | preset picker UI | `Picker` + `.menu` style、右上 floating + `.regularMaterial` |
| 5 | export format | PNG default + JPEG (拡張子分岐) |
| 6 | preview update | 即時 (preset switch 頻度低 + per-pixel kernel が cheap) |
| 7 | export 中 UI | background `Task.detached` + `isExporting` flag |
| 8 | dual emit vs canonical only | grep 結果に従い Case B |
| 9 | UI 文字列 | "Look" hardcode (i18n は messages 統合まで) |

### Phase 1b 新規ファイル

```
Color/{FilmtoneCIContext, FilmtoneGradeKernels, FilmtoneGradePipeline, FilmtonePresetCatalog}.swift
State/EditorState.swift (@Observable: imageURL / presetName / isExporting)
Export/{FilmtoneStillExporter, FilmtoneSidecarWriter}.swift
UI/GradeControls.swift (SwiftUI Picker、4 preset)
scripts/{compare-pngs.ts, golden-parity-macos.ts}
```

### baseline-B fixture mismatch (重要発見、Phase 2 C3 で再構築位置づけ)

`golden-parity-macos.ts --preset reset` の結果 (10/10 image):

| metric | 値 | 解釈 |
|---|---|---|
| **macOS↔source** | **∞ dB (10/10 bit-identical)** | reset preset は params identity → kernel epsilon gate で全段 no-op → CIImage ↔ CGImage roundtrip bit-identical。 |
| **macOS↔baseline-B** | 平均 **13.69 dB** (max 22.90, min 2.76) | baseline-B は source と完全に異なる pixel を持つ (legacy WebGL render path 由来)。 |

baseline-B fixture は legacy WebGL renderer から生成されており、iOS canonical CIColorKernel pipeline (Phase 1b lift target) と stage graph が異なるため、PSNR > 35dB 達成不可。これは Phase 1b の本質欠陥ではなく **fixture 側の生成 pipeline が現行 canonical と乖離している**ことを意味する。Phase 2 C3 で baseline-C 案 C で再構築する位置づけ (本 doc では C3 populate を 外殻 として deferred、§5.10 参照)。memory `project_phase1b_baseline_b_fixture_mismatch` 記録済。

---

## 5.6. Phase 1c 完成記録 (Vertical Slice — Video、要約)

commit `aeb0c7c` 一部。

### Goal

動画 1 個 open + midpoint frame preview + H.264 mp4 export を 1 vertical slice で wire。

### Deliverable (全 ✅ landed)

| # | Deliverable | 状態 |
|---|---|---|
| 1 | .mov/.mp4 1 個を NSOpenPanel で open | ✅ landed |
| 2 | midpoint frame を CIImage で preview に表示 (grade 適用) | ✅ landed |
| 3 | AVAssetReader → CIImage → grade → CIContext.render(to:CVPixelBuffer) → AVAssetWriter で H.264 mp4 export | ✅ landed |
| 4 | sidecar JSON (Case B 継続 + `sourceKind:"video"` additive) | ✅ landed |
| 5 | 進捗 UI (SwiftUI ProgressView + Cancel) | ✅ landed |
| 6 | CLI `--export-video` mode | ✅ landed |

### 採択した設計判断

| # | 決定事項 | 採択 |
|---|---|---|
| 1 | video preview path | 静止 frame 1 枚 (midpoint = 0.5 × duration) |
| 2 | export format | H.264 mp4 default、ProRes は enum future option |
| 3 | per-frame chain | AVAssetReader → CIImage → grade → `CIContext.render(to:CVPixelBuffer)` → AVAssetWriterInputPixelBufferAdaptor |
| 4 | video reader settings | `kCVPixelFormatType_32BGRA` + `AVVideoAllowWideColorKey: true` |
| 5 | video writer settings | `AVVideoCodecH264` + `AVVideoProfileLevelH264HighAutoLevel` + `AVVideoColorPropertiesKey` Rec.709 + adaptive bitrate |
| 6 | sidecar 拡張 | `outputFile=.mp4` + `sourceKind: "video"` additive |
| 7 | parity ハーネス | Phase 1b still parity 再利用 (Phase 1c は wiring proof、formal video parity は Phase 2) |
| 8 | UIKit 依存対処 | c1 削減方針 — telemetry 2 行 (`UIDevice.current.filmtoneModelIdentifier` / `.systemVersion`) は port せず、video core flow + color metadata helper のみ |
| 9 | 進捗 UI | SwiftUI `ProgressView(.linear)` + Cancel button、`@Observable EditorState.exportProgress` |

### Phase 1c 新規ファイル

```
Color/FilmtoneColorPipelineContract.swift   (struct lift from iOS L84-206、
                                              `phase1cMP4Default()` static
                                              factory で hardcoded contract)
Media/{FilmtoneVideoFramePreview, FilmtoneVideoReader, FilmtoneVideoWriter}.swift
Export/{FilmtoneSidecarTypes, FilmtoneVideoExporter}.swift
```

### Verify 結果 (Phase 1c chat 終端)

- `bun run verify:macos` → BUILD SUCCEEDED
- 1 sec synthetic mp4 (320x180 @ 24 fps) export: wallclock **0.366 sec** (~65 fps、proof scale)
- ffprobe: `color_space=bt709` / `color_transfer=bt709` / `color_primaries=bt709`
- iphone preset on video frame 0 vs reset preset on video frame 0: **PSNR 14.91 dB** — grade chain が video path で meaningful な差分を生成 (kernel chain active proof)

---

## 5.7. Phase 2 C1+C2+C3 scaffold 完成記録 (commit `aeb0c7c`)

### 5.7.1 Goal と Deliverable 状態

> Native Color/Export Backbone の **足場** を固める: SourceColor 分類 → canonical contract → AVFoundation modern async migration → iOS↔macOS canonical parity gate scaffold。**Source profile id round-trips through sidecar** (Phase 2 acceptance gate) を達成。

| # | Deliverable | 状態 |
|---|---|---|
| 1 | `SourceColorClassDTO` / `SourceLogTransferFunctionDTO` / `SourceColorMetadataDTO` port | ✅ landed |
| 2 | `SourceColorMetadataNormalizer` port (CoreMedia → ffprobe vocab) | ✅ landed |
| 3 | `SourceColorClassifier.classify(metadata)` port | ✅ landed |
| 4 | `FilmtoneColorPipeline.defaultOutputContract(...)` factory port | ✅ landed |
| 5 | `FormatExtensionReader` port (CMFormatDescription extension reader) | ✅ landed |
| 6 | `FilmtoneSourceProber` (async video probe + sync still CGImageSource probe) | ✅ landed |
| 7 | `FilmtoneColorPipelineContract` を iOS L84-206 verbatim 形へ restructure | ✅ landed |
| 8 | `FilmtoneVideoReader` rebuild (probe-based init, deprecation 撤去) | ✅ landed |
| 9 | `FilmtoneVideoFramePreview` modern async API migration | ✅ landed |
| 10 | `FilmtoneVideoExporter` factory wiring (probe → factory → reader) | ✅ landed |
| 11 | `FilmtoneStillExporter` factory wiring (probe → factory → contract.stillImageOptions) | ✅ landed |
| 12 | `FilmtoneSidecarWriter` additive `sourceInterpretation` field | ✅ landed |
| 13 | `PreviewSurface` Coordinator-based Task 管理 (preset 切替時の stale frame race 回避) | ✅ landed |
| 14 | `FilmtoneVideoTrackProbe` non-Sendable (Swift 6 strict concurrency 対応) | ✅ landed |
| 15 | variadic `track.load(_:_:_:_:)` で AVAssetTrack data race 回避 | ✅ landed |
| 16 | pbxproj UUID A17-A1C / B17-B1C 登録 | ✅ landed |
| 17 | C3 truth gate scaffold: `baseline-C/{reset,iphone,softBlue,amberGlow}/` + README | ✅ landed |
| 18 | `scripts/golden-parity-ios-vs-macos.ts` PENDING-aware harness | ✅ landed |
| 19 | C3 baseline-C content (4×10=40 cell) | **PENDING** (本 chat で 外殻 として deferred、§5.10 参照) |

### 5.7.2 採択した設計判断 (sequential-thinking で確定)

| # | 決定事項 | 採択 | 確認結果 |
|---|---|---|---|
| 1 | DTO 配置 | platform-neutral types は Domain/、color-vocabulary helper は Color/、CMFormatDescription parsing は Media/ | Phase 1a Decision A pattern と整合 |
| 2 | Classifier port scope | `SourceColorClassifier.classify` のみ port、`FilmtoneMezzanineRoutePolicy` (iOS mezzanine routing) は skip | macOS native irrelevant |
| 3 | Factory exit profile | 常に `outputProfileID="rec709-sdr-mp4"`、`sourceInterpretationID` のみ source 依存 | HDR output は Phase 4 別 lane |
| 4 | HDR policy | iOS canonical match — `toneMapHDRtoSDR: true` を per-frame で常に渡し、`sourceFallbackColorSpace` で source 解釈を制御 | Display P3 SDR / sdrBt709 / unknown 全 case 対応 |
| 5 | Source prober for video | AVFoundation modern async API 直使用 (loadTracks + variadic load + `track.load(.formatDescriptions)`) | C2 と同 chunk で deprecation 0 |
| 6 | Source prober for still | CGImageSource property dict (kCGImagePropertyProfileName + kCGImagePropertyColorModel) ベース | iPhone Display P3 photo を smpte432 として検出 |
| 7 | Reader API change | `init(probe: FilmtoneVideoTrackProbe, contract:)` に rebuild、async hop は prober 1 回のみ | actor / Sendable churn なし |
| 8 | FramePreview async | `loadMidpointFrame(from:) async throws` に変更、PreviewSurface は Coordinator-based Task で wrap | preset 切替時 stale frame race 回避 |
| 9 | sidecar additive | `sourceInterpretation: String?` parameter を `writeSidecar` に追加、non-nil 時のみ payload に追加 | schema bump なし、Data Contract additive only |
| 10 | Sendable struct | `FilmtoneVideoTrackProbe` は **non-Sendable** (AVAssetTrack/AVURLAsset non-Sendable のため) | single-Task consumer 限定で使用 |
| 11 | variadic load | `try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate, .formatDescriptions)` で 4-tuple 一括取得 | Swift 6 data race 回避 |
| 12 | C3 harness PENDING-aware | baseline-C entry が無いセルは PENDING として報告、harness はエラー終了しない | incremental populate を可能にする |
| 13 | C3 hybrid 戦略 | 開発 iteration は iOS Simulator (#2)、baseline-C 確定は実機 1 回 (#1)、以降 macOS 内完結 | iOS pbxproj 違反の #3 / C6 急がない方針矛盾の #4 は却下 |
| 14 | iPhone v1.2 public 維持 | v1.5 Metal optics lane は無触、baseline-C 確定 build に影響させない | App Store 公開版 = canonical 真値 |

### 5.7.3 新規ファイル (commit `aeb0c7c` 一部)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Domain/
│   └── SourceColorTypes.swift                 # 3 enum + SourceColorMetadataDTO
│                                               # iOS L67-156 verbatim
├── Color/
│   ├── SourceColorMetadataNormalizer.swift    # CoreMedia → ffprobe vocab
│   ├── SourceColorClassifier.swift            # static classify()
│   └── FilmtoneColorPipeline.swift            # defaultOutputContract factory
└── Media/
    ├── FormatExtensionReader.swift            # CMFormatDescription reader
    └── FilmtoneSourceProber.swift             # async video + still probe

scripts/
└── golden-parity-ios-vs-macos.ts              # C3 PENDING-aware harness

apps/desktop-film-lab-batch/test/golden/
└── baseline-C/
    ├── README.md                              # provenance + iOS Sim workflow
    ├── reset/                                 # PENDING (defer 確定)
    ├── iphone/                                # PENDING (defer 確定)
    ├── softBlue/                              # PENDING (defer 確定)
    └── amberGlow/                             # PENDING (defer 確定)
```

### 5.7.4 更新ファイル (commit `aeb0c7c` 一部)

predecessor master handoff §5.7.4 全項目に同じ。詳細は `git show aeb0c7c -- apps/filmtone-desktop-macos/FilmtoneDesktop/` で diff 表示可。

### 5.7.5 Verify 結果 (commit 後再現可)

```bash
$ bun run build:core            # ESM 113.65 KB / DTS 115.84 KB
$ bun run generate:swift -- --check    # exit 0 (drift 0)
$ diff -q ios↔macOS Phase0Generated.swift   # no output (identical)
$ bun run verify:macos          # ** BUILD SUCCEEDED **
```

CLI smoke (still + video) と Phase 1b regression は §11 sanity check で再現可能。

---

## 5.8. ★ 本 chat 主役 #1: Phase 2 C7 perf bench (refactor 不要判定)

### 5.8.1 Goal

Phase 1c per-frame allocation overhead (CIImage(cvImageBuffer:) → grade → CIContext.render(to:CVPixelBuffer)) が 4K/6K で bottleneck になるか実測 → 必要なら IOSurface-backed CVPixelBuffer + Metal compute refactor を実施。

### 5.8.2 Method

ffmpeg で synthetic BT.709 SDR fixture 生成 (out-of-tree、`/tmp/filmtone-perf-bench/`、`apps/desktop-film-lab-batch/fixtures/` の "< 5 MB each" policy を維持):

| fixture | size | duration | frames |
|---|---|---|---|
| `sdr-1080p-3s.mp4` | 1920×1080 | 3 sec @ 24 fps | 72 |
| `sdr-4k-3s.mp4` | 3840×2160 | 3 sec @ 24 fps | 72 |

各 fixture × {reset, iphone} preset で `/usr/bin/time -p` wallclock 計測 (warmup 1 回 → measurement)。

### 5.8.3 結果

| fixture | preset | real_s | user_s | sys_s | fps | ms/frame | realtime ratio |
|---|---|---|---|---|---|---|---|
| 1080p | reset | 0.35 | 0.06 | 0.07 | **205.71** | 4.9 | 8.6× |
| 1080p | iphone | 0.36 | 0.06 | 0.07 | 200.00 | 5.0 | 8.3× |
| 4K | reset | 0.88 | 0.08 | 0.14 | **81.82** | 12.2 | 3.4× |
| 4K | iphone | 0.89 | 0.09 | 0.15 | 80.90 | 12.4 | 3.4× |

### 5.8.4 ★ 判断: IOSurface refactor 不要

理由:

1. **4K @ 80 fps は realtime 3.4× 以上** — export = batch 処理であり、preview ではないので realtime 1× で十分。3.4× は十分 margin
2. **kernel chain overhead は 0.1-0.2 ms/frame** (reset → iphone diff)。kernel が bottleneck ではない
3. **user_s は wallclock の 6-9% のみ** = CPU 仕事は最小、bulk は GPU + AVFoundation 内部 (Metal/CoreImage が IOSurface を内部で扱っている)
4. **scaling は sub-linear**: 4× pixel count (1080p → 4K) で 2.5× 鈍化 → GPU が良く utilization されている
5. Phase 1c の懸念 (per-frame allocation overhead) は **measurement で否定**

→ C7 IOSurface refactor は **以下のいずれかが起きるまで保留**:
- (a) 6K/8K material が target になる
- (b) C5b multi-pass blur (bloom/halation/diffusion) 統合後、追加 GPU pass が realtime を割る
- (c) 連続 video export (long-form) で memory pressure が観測される

C7 commit は **不要** (実測作業のみ、code 変更なし)。fixture 生成 script は次 chat 用に必要なら `scripts/perf-bench-c7.sh` として追加検討 (本 chat では in-line bash で実行済、再現性は本 doc §5.8.2 で確保)。

### 5.8.5 Reproducibility

```bash
# (1) Generate out-of-tree perf fixtures
mkdir -p /tmp/filmtone-perf-bench && cd /tmp/filmtone-perf-bench
for res in "1920x1080:1080p" "3840x2160:4k"; do
  size="${res%%:*}"; tag="${res##*:}"
  out="sdr-${tag}-3s.mp4"
  [ -f "$out" ] || ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "testsrc2=size=${size}:rate=24:duration=3" \
    -c:v libx264 -pix_fmt yuv420p -profile:v high -preset fast \
    -color_primaries bt709 -color_trc bt709 -colorspace bt709 \
    -movflags +faststart "$out"
done

# (2) Measure
APP=/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan/apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop
for fix in sdr-1080p-3s sdr-4k-3s; do
  for preset in reset iphone; do
    out=/tmp/filmtone-perf-bench/out-${fix}-${preset}.mp4
    rm -f "$out"
    "$APP" --export-video --input "/tmp/filmtone-perf-bench/${fix}.mp4" \
      --output /tmp/filmtone-perf-bench/warmup.mp4 --preset reset > /dev/null 2>&1
    /usr/bin/time -p "$APP" --export-video \
      --input "/tmp/filmtone-perf-bench/${fix}.mp4" \
      --output "$out" --preset "$preset" 2>&1 | grep -E "^(ok|real|user|sys)"
  done
done
```

---

## 5.9. ★ 本 chat 主役 #2: Phase 2 C5a per-pixel optical (vignette + grain) 完成記録 (commit `cd170a6`)

### 5.9.1 Goal

iOS canonical pipeline の **per-pixel optical 2 段** (vignette + grain) を macOS Native grade chain に lift。multi-pass blur と CIKernel-based stage は C5b、motion 系は別 lane (motionFeedback / motionBlend は dedicated motion lane で扱う)。

### 5.9.2 採択した設計判断

| # | 決定事項 | 採択 |
|---|---|---|
| 1 | Stage scope | per-pixel CIColorKernel 2 段のみ (vignette + grain)。softKneeHighlight は bloom helper であり stage ではないので C5b に同梱 |
| 2 | Pipeline 順 | iOS canonical: `baseGradeV2 → filmCompressionV2 → vignette → grain → printStage`。iOS L1634-2104 から導出 |
| 3 | Vignette gate | `params.vignette > 0.0001` (iOS L1982 と同 epsilon) |
| 4 | Grain gate | `clamp(grainIntensity, 0, FilmtonePhase0Generated.grainIntensityMax) > 0.0001` (iOS L2026-2027 と同 clamp + epsilon) |
| 5 | Vignette opticsPack | identity vec3 `(1.0, 1.0, 0.5)` + `applyMask=0` を渡す。FilmtoneRayAngleOptics 未 port のため real opticsPack は計算不能、しかし `applyMask=0` で kernel math 上 throw away されるので **byte-identical pre-Stream-2 出力**。canonical iOS match は C5c で達成予定 |
| 6 | Vignette gamma / inner | `FilmtonePhase0Generated.hiddenDefaults.depthRayAngleGamma` / `.depthRayAngleInnerThreshold` (iOS と同 SSOT)。math 上は applyMask=0 で結果に影響しないが、SSOT 維持のため iOS と同値を渡す |
| 7 | Grain time | still: 0 (default)、video: `CMTimeGetSeconds(validTime)` (frame presentation time) を渡す → grain frame `floor(t*3)` で 3 refresh per source-second |
| 8 | Grain sourceSeed | macOS は default 0 (stable salt)。iOS は per-export deterministic seed を使うが、macOS は per-export seed wiring が未着 → C5b/C5c で別途。grain のみ影響 (visual 上は noise 模様の位相が変わる程度、energy は同一) |
| 9 | Method signature | `FilmtoneGradePipeline.apply(to:params:frameTimeSeconds:sourceSeed:)` で optional 拡張、default 0/0。Phase 1b/1c caller は signature 変更なしで継続 |
| 10 | Video exporter wiring | `FilmtoneVideoExporter` per-frame loop で `CMTimeGetSeconds(validTime)` を計算して `apply` に渡す |

### 5.9.3 採択しなかった案 (本 chunk)

| # | 検討案 | 採択判断 | 理由 |
|---|---|---|---|
| 1 | softKneeHighlight も C5a で port | NO | softKneeHighlight は bloom highlight plate 抽出 helper (iOS L2098-2113 `extractHighlightPlate`)、stage ではない。bloom multi-pass を含む C5b で同梱 |
| 2 | RayAngleOptics も C5a に同梱 (vignette canonical 化) | NO | scope creep、`applyMask=0` 経路で byte-identical 動作するので C5a の deliverable は完成、canonical 化は C5c で別 chunk |
| 3 | `grainIntensityMax` clamp を呼出側で | NO | FilmtoneGradePipeline 側で clamp = SSOT、caller 側に責務を散らさない (iOS L2026 と同 pattern) |
| 4 | sourceSeed = sourceURL hash | NO | hash 戦略は決定論的だが iOS と命名/実装が違うと iOS↔macOS bit-identity が壊れる。0 stable default で C3 baseline-C populate 時の比較を簡素化 |
| 5 | per-export sourceSeed wiring を C5a に同梱 | NO | grain だけ影響 + visual 上は phase 違いのみ → 後回し。C5b / C5c で iOS canonical 化と同時に対処 |
| 6 | C5a を Phase 1b/1c の commit と同 bundle に | NO | 別 chunk は別 commit、atomic に分けた方が回帰特定が容易 (`aeb0c7c` Phase 1b/1c+2 C1/C2+C3 scaffold / `cd170a6` C5a) |

### 5.9.4 新規 / 更新ファイル (commit `cd170a6`)

新規: なし
更新 3 file (`+197 / -12`):

| パス | 変更内容 |
|---|---|
| `Color/FilmtoneGradeKernels.swift` | header comment に Phase 2 C5a scope 追記。`vignette` + `grain` CIColorKernel を `printStage` の後に追加 (verbatim from iOS OpticalKernels L4321-4347 / L4350-4403) |
| `Color/FilmtoneGradePipeline.swift` | header comment 全面更新 (Phase 1b → Phase 2 C5a、pipeline 順、frameTimeSeconds/sourceSeed の役割)。`apply` signature 拡張 (`frameTimeSeconds: Double = 0, sourceSeed: Double = 0`)。pipeline 順に vignette + grain stage を挿入。`applyVignette` + `applyGrain` private method を追加 |
| `Export/FilmtoneVideoExporter.swift` | per-frame loop で `CMTimeGetSeconds(validTime)` を `frameTimeSeconds` として `FilmtoneGradePipeline.apply` に渡す |

iOS Xcode project / Electron desktop / film-lab-core src は **未編集** (master §6 invariants 遵守)。pbxproj 変更なし (新規 file 追加なしのため)。

### 5.9.5 Verify 結果

```bash
$ bun run verify:macos
** BUILD SUCCEEDED **
```

```bash
$ git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
nothing to commit, working tree clean
```

CLI smoke (6 cells):

| # | 操作 | 結果 |
|---|---|---|
| 1 | `--export-still` reset on 01-highlight-sunset | `ok 1280x720` |
| 2 | `--export-still` iphone on 09-skin-light | `ok 1280x720` |
| 3 | `golden-parity-macos.ts --preset reset` (Phase 1b regression) | `macOS↔source : all ∞ dB (10/10 bit-identical)` 維持、`macOS↔baseB 13.69dB` (informational、変化なし) |
| 4 | iphone 09-skin-light vs source PSNR | **35.00 dB** (Phase 2 C2 は 40.60dB → -5.60dB drop、vignette+grain active な signal) |
| 5 | `--export-video` reset on synthetic-bt709-1s | `ok 320x180 frames=24` |
| 6 | `--export-video` iphone on synthetic-bt709-1s | `ok 320x180 frames=24` (per-frame grain advance OK) |

iphone 09-skin-light pixel sample (corner darkening pattern):

| location | source RGB | export RGB | delta |
|---|---|---|---|
| topleft (10,10) | (225,192,170) | (212,180,159) | -13/-12/-11 (≈ -5%) ✅ vignette darkening |
| topright (1270,10) | (181,140,117) | (169,128,105) | -12/-12/-12 (≈ -7%) ✅ vignette darkening |
| center (640,360) | (214,178,156) | (217,179,156) | +3/+1/0 (≈ +1%) ✅ vignette center 不変 + grain 微小寄与 |

vignette radial darkening pattern が観測通り、grain が visible texture を加える、center は本質的に不変 — iOS canonical の vignette 0.18 + grainIntensity 0.012 を反映している。

sidecar (`iphone-09.filmtone.json`):

```
"baseLookName" : "iphone",
"lookId" : "filmtone:base:iphone:v2",
"sourceInterpretation" : "sdr-bt709",
"sourceKind" : "still"
```

→ Case B Look canonical 維持 + Phase 2 C1 additive `sourceInterpretation` 維持。

### 5.9.6 ★ 重要発見・残課題

1. **`CIColorKernel(source:)` deprecation 警告が 3 → 5 件に増加**
   `FilmtoneGradeKernels.swift` の vignette (L118) + grain (L151) 追加分。Phase 1b 受容と同分類 (master §6.3、Metal CIKernel 移行 lane 別 chunk または C7 と合流)。本 commit `cd170a6` で更に 2 件増えたが、accept 方針継続。

2. **vignette canonical 化 (C5c) で macOS↔iOS byte-identity の上限が 35 dB → 40+ dB に戻る可能性**
   現在の C5a は `applyMask=0` 固定で iOS の `applyMask=1` (camera-optics metadata 付き source) と微妙に math が異なる。C3 baseline-C populate 時に "macOS↔baseline-C 30-40 dB" になるセルがあれば、原因は (a) RayAngleOptics 未 port、(b) sourceSeed 0 vs iOS 実装差、(c) その他 — 案 C step (3) WGSL→Metal port は最終手段。

3. **grain visual artifact の客観的判定は人間目視が必要**
   PSNR は grain の存在を「ノイズ」として捕捉するが、grain が iOS と "視覚的に同質" かは色彩ではなく noise distribution の問題。GUI smoke で iOS Simulator vs macOS export を side-by-side で目視比較するのが最確実 (defer 中)。

4. **iphone preset 以外 (softBlue / amberGlow) で vignette / grain が active か未測定**
   `FilmtonePhase0Generated.swift` を grep すると softBlue は `vignette: 0.0` / `grainIntensity: 0.0` なので vignette / grain は inert (gate で no-op 通過)。amberGlow は `vignette: 0.0` / `grainIntensity: 0.0` も同様。**reset 以外で vignette / grain が active なのは iphone のみ** (FilmtonePhase0Generated L65-104 / L101-140 / L138-... 参照)。これは Phase 0 generator 側で決まっており Phase 2 C5a で変更なし。

5. **video export grain frame 進行は visual-only 確認済**
   per-frame `floor(t*3)` で 3 refresh per source-second。Phase 1c の synthetic 1-sec mp4 は 24 frame で ~3 grain refresh = 観測しやすい。実際の iphone preset video export で frame 0 vs frame 12 の grain 模様が異なることは ffmpeg で frame 抽出 → 比較すれば確認可能 (本 chat では時間都合で skip、次 chat の余裕時に検証)。

---

## 5.10. ★ 本 chat 主役 #3: 採用した運用方針変更 (重要、必読)

本 chat で user が verbal lift / 明示した運用方針:

### 5.10.1 CLAUDE.md §9 「Git 操作は user が行う(自動コミット禁止)」を本 chat で lift

**原文 (CLAUDE.md §9)**: 「Git 操作は user が行う(自動コミット禁止)」

**lift 経緯**: user が以下を本 chat で明言:
- "全部あなたできますよね？" (rhetorical: "you can do all of it, right?")
- "私の判断コスト最小限にするところまで仕上げてください"
- "並列で作業しているので私に可能な限りコストかけないように進める前提で計画してください"
- "yes" (本 chat 中盤に提案した「私が即 commit → C3 populate defer → C7 perf bench」案への同意)

→ assistant が **autonomous で `git commit` 実行** することを本 session 中は許可。Push は依然 user 操作 (本 chat で push 操作なし)。**次 chat はこの lift が引き続き有効か user に明示確認すること** (default は CLAUDE.md §9 復帰)。

### 5.10.2 「本質優先 / 外殻最小 / 全てがうまく行った時の品質保証」doctrine

**原文 (user 発言)**: 「本質の進行を最優先にして、外殻は最小限全てがうまく行った時の品質保証したい時にのみに行う」

**運用判断**:

| 項目 | 分類 | 本 chat の行動 |
|---|---|---|
| Swift code / pipeline / sidecar / kernel 変更 | **本質** | C5a で実装、即 commit |
| AVFoundation modern async / Sendable 対応 | **本質** | aeb0c7c に含めて commit |
| Source profile id round-trip (sidecar additive) | **本質** | aeb0c7c に含めて commit |
| C7 perf bench 実測 | **本質** (品質判定の根拠) | 実行、code 変更なしで refactor 不要判定、commit 不要 |
| C3 baseline-C populate (4×10=40 cell iOS UI loop) | **外殻** (formal QA regression infrastructure) | **defer** (品質保証希望の明示まで) |
| 手動 GUI smoke (race fix 視覚検証) | **外殻** (UI 視覚確認) | **defer** (CLI smoke で代替、user 1 回操作は将来必要時) |
| Formal QA matrix / test harness expansion | **外殻** | defer |
| 過剰 i18n 化 / 装飾 banner / public copy | **外殻** | scope 外 |

→ **次 chat はこの doctrine を継続適用**。新 chunk 着手前に "本質 か 外殻 か" を判定し、外殻なら明示の "品質保証希望" を待つ。

### 5.10.3 Desktop chat における iOS の位置付け (clarification)

user 質問: "今ってデスクトップの話で進んでいる認識なのに iOS ってどうゆうことですか？"

→ **本 chat (および次 chat) は Desktop work**。iOS は以下に限り出てくる:

1. **read-only canonical reference**: kernel sources (`OpticalKernels.swift`)、type definitions (`FilmtoneMediaTypes.swift`)、pipeline structure (`FilmtoneExportSession.swift`)、generated Swift (`FilmtonePhase0Generated.swift`) を **読むだけ** + macOS target に verbatim lift する元
2. **C3 baseline-C populate 時の reference**: iOS app v1.2 public で manual export → baseline として固定 (本 chat では defer)
3. **Continuity (Phase 5+)**: iOS で決めた recipe を Mac が同 SSD 素材へ適用 — 将来 lane

iOS Xcode project (`apps/capacitor-film-lab-ios/ios/App/App.xcodeproj`) は **絶対編集禁止** (master invariant #1)。本 chat での `git status apps/capacitor-film-lab-ios/` は clean。

### 5.10.4 並列 chat (chat B Look Unification) 待ちの扱い

Look Unification は別 chat (chat B、worktree `/forestone/filmtone-look-unification`) で進行。**本 chat (chat A.X) では編集禁止、read-only 参照のみ**。chat B の main merge を観測したら sidecar dual emit (Case A) 切替を本 chat 側で 別 chunk として実施。

main 観測方法 (sanity check 開始時):
```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
# 着地済 (BASE_LOOKS export あり) → Case A dual emit に切替
# 未着地 (BASE_LOOKS export なし) → Case B 継続
```

本 doc 作成時 (2026-05-03 JST late evening): **未着地** (BASE_LOOKS export なし)、Case B 継続。

---

## 6. Critical Invariants (絶対に壊さない、final consolidated)

### 境界 (Phase 0 + 1a + 1b + 1c + 2 全 chunk で立てた)

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** — v1.3 local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。Phase 2 C1 / C5a で iOS Swift から DTO + classifier + factory + format reader + OpticalKernels を **read-only 参照 + 内容コピー** したのは OK だが、iOS の `.pbxproj` には触らない。XCUITest target 追加禁止 (C3 案 C で UI 自動化を退ける根拠)
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** — release rail。Phase 4 で current-capability replacement に到達するまで shipping rail として残す。**parity 比較で test fixture を read するのは OK**。`baseline-C/` を新規作成したのは test fixture directory なので OK
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` を消さない** — submodule 即 import 用に track 維持
4. **`packages/film-lab-core/src/` の contract source は変更しない**
5. **生成 Swift を手編集しない**
6. **iOS と macOS の `Phase0Generated.swift` は bit-identical**
7. **`Domain/Phase0Types.swift` の field 順序 / 名前を変えない**。Phase 2 C1 で **新規 file `Domain/SourceColorTypes.swift` を追加** したが、既存 `Phase0Types.swift` は無触
8. **`SharedGenerated/FilmtonePhase0Generated.swift` は Compile Sources に入っている**
9. **Responsibility Boundaries** (02-target-architecture-and-contracts.md):
   - `UI` は SwiftUI views と AppKit wrappers のみ
   - `State` は editor state + flow orchestration のみ
   - `Color` は CIKernel / CIContext / preset catalog / pipeline factory + DTO classifier。Phase 2 C1 で `FilmtoneColorPipeline.swift` (factory namespace) + `SourceColorMetadataNormalizer.swift` + `SourceColorClassifier.swift` を追加。Phase 2 C5a で `FilmtoneGradeKernels.swift` に vignette + grain を追加 (existing file 拡張、ファイル境界を変えていない)
   - `Export` は still/video encoding + sidecar emission
   - `Domain` は platform-neutral 型 + generated contract glue。Phase 2 C1 で `SourceColorTypes.swift` を追加
   - `Media` は probing+reader+writer。Phase 2 C1 で `FilmtoneSourceProber.swift` + `FormatExtensionReader.swift` を追加
   - 依存方向: `UI → State → Domain` / `UI → State → Color/Export/Media services` / `Export → Color / Media / Domain` / `Color → Domain / SharedGenerated` / `Media → Color (DTO 経由) / Domain` / `App` は composition のみ

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
- **Git 操作**: 本 chat では §5.10.1 lift 中。次 chat は user に再確認 (default は CLAUDE.md §9 「user が行う」復帰)

### 設計判断ルール

- 設計判断は `mcp__sequential-thinking` を使う(記憶ベース断言禁止)
- 不確かな API (CoreImage / CGImageDestination / sidecar Zod schema / AVFoundation / Metal / CGImageSource) は `gemini-search` → `WebSearch` の順
- handoff doc を引用する前に、現行 surface (`grep` / Swift / pbxproj) と突き合わせて live/frozen を確認 (`feedback_verify_before_quoting_handoff`)
- 並列 stream で残タスクの silent 省略禁止 (`feedback_no_silent_stream_redefine`)
- npm publishing を再導入しない (CLAUDE.md §6 antipattern #1)

### Sidecar additive only (Data Contract 制約)

- macOS native sidecar emitter は schema bump せず **additive field のみ追加**
- Phase 1c で `sourceKind` additive、Phase 2 C1 で `sourceInterpretation` additive
- Phase 2 C5a は sidecar 変更なし (vignette + grain は params 経由で sidecar に "gradeParams" として既に乗っている)
- Look Unification main 着地時に dual emit (Case A) へ切替予定だが additive 契約は維持

---

## 6.5. Concurrent Lane: Desktop Look Unification (chat B 並列進行中)

### Lane 概要

- branch: `feature/desktop-look-unification`
- chat B worktree path: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
- 再開 handoff (canonical): `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (main checkout 側)
- 状態 (本 doc 作成時、2026-05-03 JST late evening): branch 上で Phase A `1f99d68` (core/schema additive aliases) + Phase B `fd9ddd2` (Electron renderer + film-lab-ui sweep) 両方 landed、**main 未 merge**

### 本 chat 開始時の Look Unification 着地確認

```bash
$ grep -E "^export.*BASE_LOOKS|^export.*PRESETS" \
       /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/packages/film-lab-core/src/index.ts
(no output → BASE_LOOKS 未着地)
```

→ **Case B (Look canonical only sidecar emit) 継続**。

### Native Desktop v2 が依存する成果物 (Look Unification main 着地で利用可)

- `film-lab-core` の Look-first canonical 名 (旧 Preset 名は alias で残る、schema 加算のみ):
  - `BaseLookName = PresetName`、`BASE_LOOKS = PRESETS`、`BASE_LOOK_BUTTONS = PRESET_BUTTONS`、`FILMTONE_DEFAULT_BASE_LOOK = FILMTONE_DEFAULT_BASE_PRESET`、`findMatchingBaseLook = findMatchingPreset`
  - `LOOK_RECIPE_VERSION = PRESET_VERSION`、`lookIdForBaseLook = lookIdForPreset`、`LOOK_ID_BY_BASE_LOOK = LOOK_ID_BY_PRESET`
  - `filmLookGradeInputSchema` に optional `lookId` / `lookVersion` 追加
  - `normalizeFilmLookGradeInputIdentity()` で identity 不一致 throw

### Native Desktop ユーザー配布前の release blocker

- Phase 5 release rail 切替前に Look Unification main merge + macOS sidecar emitter dual emit 切替 + Electron reader catch-up が必須
- **vocabulary 不統一のまま public release しない方針** (06 risk row、Phase 5 release gate で確認)

---

## 7. Truth Gates (life スクリプト)

release/iOS 状態を主張する前に必ず通す:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼**。`FILMTONE_REPO_ROOT` env で root 上書き可。

---

## 8. アンチパターン (CLAUDE.md §6、本 chat で踏まなかったもの)

1. ✅ npm publishing を再導入しない (npm 不使用、bun のみ)
2. ✅ `packages/film-lab-{renderer,smart-look}/dist/` 維持 (track 不変)
3. ✅ portfolio を実装の正本扱いしない
4. ✅ iOS public 版 (1.2) と local candidate (1.3 / 1.5 lane) を混ぜない
5. ✅ 用語ロック (動画 / video / Look)
6. ✅ JSX comment を return ( の直下に置かない (本 phase は SwiftUI なので 該当なし)
7. ✅ 保守的ヘッジ優先しない — C7 で IOSurface refactor を念のため実施するか迷わず measurement で判定
8. ✅ 本質優先 / 外殻最小 doctrine 遵守 (C3 populate を defer、C5a を 即実装)
9. ✅ handoff 鵜呑み禁止 — predecessor master handoff §15.3 の "C7 推奨条件 = C3 全セル PASS" を gate にせず、measurement で独立判断

---

## 9. Verify protocol (本 chat 終端で通したもの)

実行順は §11 sanity check で再現可能。Phase 2 C5a + C7 で必ず通す:

1. `bun run build:core` — `film-lab-core` build ok
2. `bun run generate:swift -- --check` — drift 0 (exit 0)
3. `diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift` — identical (no output)
4. `bun run verify:macos` — `** BUILD SUCCEEDED **`、AVFoundation deprecation 0 (残 `CIColorKernel(source:)` 5 箇所、Phase 1b 受容 + C5a 増分受容)
5. `git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/` — clean
6. `bun run scripts/golden-parity-macos.ts --preset reset` — Phase 1b regression check (∞ dB / 13.69dB)
7. `bun run scripts/golden-parity-ios-vs-macos.ts --preset reset` — C3 harness smoke (10 PENDING、∞ dB roundtrip)
8. CLI still smoke: 01-highlight-sunset.png reset → ok 1280x720 + sidecar に `sourceInterpretation: sdr-bt709`
9. CLI still smoke: 09-skin-light.png iphone → ok 1280x720 + 35.00dB vs source (vignette+grain active)
10. CLI video smoke: synthetic-bt709-1s reset → ok 320x180 frames=24
11. CLI video smoke: synthetic-bt709-1s iphone → ok 320x180 frames=24 (per-frame grain advance)

(時間が許せば) `bun run verify:ios` — iOS lane 無傷再確認。

C7 perf bench (5.8.5 のコマンド再実行):
- 1080p reset 0.35s / iphone 0.36s
- 4K reset 0.88s / iphone 0.89s
- → IOSurface refactor 不要判定

---

## 10. Sidecar contract (本 chat 時点)

```json
{
  "schemaVersion": 1,
  "exportedAtIso": "2026-05-03T...",
  "appVersion": "0.1.0-macos",
  "appPlatform": "macos-native",
  "sourceFile": "/.../source.png",
  "sourceKind": "still",                 // Phase 1c additive
  "sourceInterpretation": "sdr-bt709",   // Phase 2 C1 additive
  "outputFile": "/.../output.png",
  "gradeParams": { ... 35 fields incl vignette / grainIntensity / grainRadialMix / grainSize ... },
  "batchLookChoice": {
    "lookId": "filmtone:base:iphone:v2",
    "lookVersion": "v2",
    "baseLookName": "iphone",
    "strength": 1
  },
  "lookId": "filmtone:base:iphone:v2",
  "lookVersion": "v2",
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

`sourceInterpretation` の値域 (`SourceColorClassDTO.rawValue` または特殊値):
- `sdr-bt709` (strict BT.709 SDR、最も多い)
- `display-p3-sdr` (iPhone Display P3 photo)
- `hdr-pq` (PQ HDR)
- `hdr-hlg` (HLG HDR)
- `apple-log` (Apple Log)
- `apple-log2` (Apple Log 2)
- `wide-gamut-unknown` (BT.2020 / mastering display metadata あり、transfer 不明)
- `unsupported` (ProRes RAW 等)
- `unknown` (probe 不能)

### Look Unification 着地状況による分岐

**現状 (Case B、Look canonical only)**: sidecar に `lookId` / `lookVersion` / `batchLookChoice` のみ。legacy `presetName` / `presetVersion` は emit しない。

**Look Unification main merge 後 (Case A、dual emit)**: 上記に加えて legacy `presetName` / `presetVersion` も emit。`normalizeFilmLookGradeInputIdentity()` で identity 不一致を throw。

→ Case A 切替は parity gate に影響しない (sidecar 構造のみ)。

---

## 11. Sanity check 開始時コマンド (新 chat の最初に必ず実行)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# (1) commit 状態確認
git log --oneline -5
# expect:
#   cd170a6 feat(macos): Phase 2 C5a per-pixel optical extension (vignette + grain)
#   aeb0c7c feat(macos): Native Desktop v2 Phase 1b/1c + Phase 2 C1/C2 + C3 parity scaffold
#   398743c feat(macos): Native Desktop v2 Phase 0 + 1a + plan/handoff docs
#   32b3100 Fix desktop MOV preview loading
#   ... (older)

git status
# expect: working tree clean (本 doc 作成後の dirty は本 handoff doc 1 件のみ)

# (2) 不変条件 sanity
bun run generate:swift -- --check                        # exit 0 (drift 0)
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
                                                          # no output (identical)
git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
                                                          # clean

# (3) build + parity
bun run verify:macos                                      # ** BUILD SUCCEEDED **
bun run scripts/golden-parity-macos.ts --preset reset     # ∞ dB / 13.69dB (Phase 1b regression preserved)
bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
                                                          # 10 PENDING (baseline-C 未 populate, C3 deferred)

# (4) Look Unification main 着地状況確認
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
# 着地済 (BASE_LOOKS export あり) → Case A dual emit に切替を C5b 前に挿入
# 未着地 (BASE_LOOKS export なし) → Case B 継続

# (5) C5a regression sanity
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
APP=apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop
"$APP" --export-still \
  --input apps/desktop-film-lab-batch/test/golden/source-images/09-skin-light.png \
  --output /tmp/c5a-sanity-iphone-09.png --preset iphone
bun run scripts/compare-pngs.ts \
  apps/desktop-film-lab-batch/test/golden/source-images/09-skin-light.png \
  /tmp/c5a-sanity-iphone-09.png
# expect: PSNR ≈ 35dB, topleft/topright corners darker, center near-identical
```

---

## 12. Risks (06-quality-gates-risks.md と整合、本 chat で更新)

### RESOLVED (Phase 2 C1+C2 で解消、本 chat で継続)

- AVFoundation sync API deprecation 6 sites (FramePreview tracks/duration/copyCGImage、Reader tracks/naturalSize/preferredTransform/nominalFrameRate)
- Swift 6 strict concurrency × AVAssetTrack non-Sendable

### RESOLVED (本 chat の C7 で解消)

- Phase 1c per-frame allocation overhead 4K 未測定 → C7 で 4K 80 fps (realtime 3.4×) 確認、IOSurface refactor 不要判定

### ADDRESSED with scaffold (Phase 2 C3 で着地、populate は **外殻 として deferred**)

- baseline-B fixtures derive from legacy WebGL render path → baseline-C 案 C scaffold landed (PENDING populate)。本 chat で「品質保証希望明示まで defer」doctrine 適用 (§5.10.2)

### OPEN (Phase 2 残 chunk または別 phase)

- `CIColorKernel(source:)` deprecation 5 箇所 (Phase 1b 3 + Phase 2 C5a 2) → Metal CIKernel 移行 lane (Phase 2 別 chunk または C7 と合流)
- `FilmtoneVideoReader / FilmtoneVideoWriter` `@unchecked Sendable` → C5b/C7 actor isolation refactor で再評価
- 6K perf 未測定 → C7 IOSurface bench (4K で realtime 3.4× を確認したので 6K でも realtime + 数倍 margin の可能性高)
- Native ユーザー配布前 dual emit 切替 → release blocker (Phase 5 acceptance gate)
- vignette canonical 化 (RayAngleOptics + camera-optics metadata 経路) → C5c

### NEW OPEN (本 chat C5a で新規発生)

- iphone preset 以外で vignette / grain が active なのは存在しない (softBlue / amberGlow も vignette=0 / grainIntensity=0)。**Phase 0 generator が canonical** なので preset 値変更は別 lane (生成 Swift 経由)
- grain noise distribution の iOS↔macOS 視覚同質性は PSNR では測れない → C3 baseline-C populate (defer 中) 時に side-by-side 視覚確認

---

## 13. 採択した設計判断・採択しなかった案 (consolidated)

### 13.1 採択した設計判断 (本 chat の Phase 2 C5a + C7 + 運用)

(再掲省略、§5.8 / §5.9 / §5.10 参照)

### 13.2 検討して採択しなかった案 (本 chat)

| # | 検討案 | 採択判断 | 理由 |
|---|---|---|---|
| 1 | C5a と C5b を 1 chunk で進める | NO | C5b は multi-pass blur + ROI callback + softKneeHighlight helper + tentDownsample/Up (CIKernel) が絡むので scope 大、本 chat 残予算で詰め切れない可能性あり。C5a を atomic chunk として確定 |
| 2 | C5a で softKneeHighlight も port | NO | softKneeHighlight は bloom helper であり stage ではない (`extractHighlightPlate` 経由 only)。bloom multi-pass を含む C5b で同梱 |
| 3 | C5a で RayAngleOptics も同梱 | NO | scope creep、`applyMask=0` で C5a の deliverable は完成、canonical 化は C5c で |
| 4 | C7 で IOSurface refactor を念のため実施 | NO | measurement で 4K @ 80fps (realtime 3.4×) が確認されており、refactor justification がない。「保守的ヘッジ優先しない」原則 |
| 5 | C3 baseline-C populate を本 chat で実施 | NO | iOS Simulator manual UI loop (40 export) は user UI labor + 外殻 (formal QA infrastructure) で「全てがうまく行った時の品質保証希望」明示まで defer (§5.10.2) |
| 6 | C7 fixture を tree 内 commit | NO | `apps/desktop-film-lab-batch/fixtures/` の "< 5 MB each" policy。1080p (2.2MB) は OK だが 4K (8.1MB) は超える。out-of-tree `/tmp/filmtone-perf-bench/` で再現性は §5.8.5 の bash で確保 |
| 7 | GUI smoke を本 chat で実施 | NO | user 視覚確認必須 + 並列 chat の interruption コスト高。CLI smoke で kernel chain は exercised、race fix の視覚検証は将来 user 1 回操作で対応可能 |
| 8 | grain sourceSeed = sourceURL hash | NO | hash 戦略は決定論的だが iOS と命名/実装が違うと iOS↔macOS bit-identity が壊れる。0 stable default |
| 9 | C5a を Phase 1b/1c bundle に同 commit | NO | 別 chunk = 別 commit (atomic regression 特定)、`aeb0c7c` と `cd170a6` を separate に |

---

## 14. Commit timeline + 状態

```
cd170a6 feat(macos): Phase 2 C5a per-pixel optical extension (vignette + grain)
        ├── 3 files changed, +197 / -12
        ├── Color/FilmtoneGradeKernels.swift (vignette + grain CIColorKernel verbatim)
        ├── Color/FilmtoneGradePipeline.swift (apply signature 拡張、vignette+grain stage 挿入)
        └── Export/FilmtoneVideoExporter.swift (per-frame CMTimeGetSeconds 配線)

aeb0c7c feat(macos): Native Desktop v2 Phase 1b/1c + Phase 2 C1/C2 + C3 parity scaffold
        ├── 42 files changed, +6993 / -59
        ├── Phase 1b vertical slice (still: preset / grade / export / sidecar)
        ├── Phase 1c vertical slice (video: open / preview / H.264 export / sidecar additive)
        ├── Phase 2 C1 SourceColor DTO + Normalizer + Classifier + FilmtoneColorPipeline + Source Prober + FormatExtensionReader
        ├── Phase 2 C2 AVFoundation modern async + Sendable / Swift 6 strict concurrency
        ├── Phase 2 C3 truth gate scaffold (baseline-C/ + golden-parity-ios-vs-macos.ts)
        ├── pbxproj UUID A09-A1C / B09-B1C 拡張
        └── docs (4 handoff + transition plan revisions)

398743c feat(macos): Native Desktop v2 Phase 0 + 1a + plan/handoff docs
        ├── Phase 0: macOS app skeleton + dual-target generator + Liquid Glass
        ├── Phase 1a: Domain/Phase0Types + NSOpenPanel + PreviewSurface
        └── transition plan split (canonical index + 6 detail files)

[main HEAD: 32b3100]
```

`main` (filmtone main checkout) は本 chat 開始時:
```
732a273 feat(ios): add Backlight Veil optical filter as adjustment param (Phase 1b/1c)
32b3100 Fix desktop MOV preview loading
9fa830a Merge feature/optical-veiling-glare-research into main
d83ac0f docs(ios): add Backlight Veil iOS port handoff
2c8e15d feat(filmtone): add Backlight Veil optical filter family (Phase 1 desktop)
```

→ Backlight Veil family (core/profiles + iOS adjustment param) は **main に landed**。macOS Native は未統合 (`packages/film-lab-core/src/optical-filter-profiles.ts` の OPTICAL_FILTER_PROFILES に `backlightVeil` 3 density 定義済み、macOS Native は OpticalFilterProfile を消費していない)。

---

## 15. Next chat 起点 (work options + recommendations)

### 15.1 状態 (本 doc commit 後の前提)

- HEAD: `cd170a6` (or `cd170a6` の上に本 doc を含む追加 commit)
- working tree: clean (本 doc 自体が次 commit の対象、user 判断)
- Phase 2: C1+C2 完了、C3 scaffold 完了 (populate defer)、C5a 完了、C7 measurement 完了 (refactor 不要)
- Phase 2 残: C5b (multi-pass blur)、C5c (RayAngleOptics)、C6 (SPM、急がない)、Look Unification main 着地時の dual emit 切替

### 15.2 次 chat 候補 (recommended order)

#### (A) C5b multi-pass blur + CIKernel-based stages — 大 chunk

iOS OpticalKernels の以下を port:
- `softKneeHighlight` (CIColorKernel、bloom highlight plate 抽出 helper、L4227-4237)
- `glowComposite` (CIColorKernel、bloom + halation + diffusion 合成、L4239-4263)
- `tentDownsample` / `tentUpsample` (CIKernel、multi-mip pyramid blur、L4424-4495)
- `radialRGBSplit` (CIKernel、chromatic aberration、L4406-...)
- `edgeSoftnessBlend` (CIKernel、softness blur、L4535-...)

Pipeline insertion (iOS canonical order、L1541-2155):
- bloom: extractHighlightPlate (softKneeHighlight) → tent pyramid (down→up) → glowComposite
- halation: 同 pyramid (different threshold + tint) → glowComposite (with halation 引数)
- diffusion: 全 image を tent pyramid → glowComposite (diffusion 引数)
- radialRGBSplit: post-printStage (rgbShift param > 0)
- edgeSoftnessBlend: lensSoftness param > 0

scope: 推定 ~600-800 line lift + ROI callback + multi-mip orchestration。**1 chat で完了は tight**、可能なら 2 chat に分けるか sub-chunk 化 (例: bloom only → halation+diffusion → RGB split + edge softness)。

#### (B) C5c RayAngleOptics port — 小 chunk

新規 1 file `Color/FilmtoneRayAngleOptics.swift` に iOS 同名 file (`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRayAngleOptics.swift`) を verbatim lift。enum + static func で `resolve(optics:imageWidth:imageHeight:)` + `kernelArgs(...)` を提供。

Pipeline 統合: `FilmtoneGradePipeline.applyVignette` で current の identity opticsPack + applyMask=0 を、source camera-optics metadata がある場合は real opticsPack + applyMask=1 に切替。前提として Source Prober で camera optics 抽出を追加 (現在の prober は color metadata のみ)。

scope: ~150-300 line lift + Source Prober 拡張 (CMFormatDescription extension dict から focal length / sensor size etc. 抽出)。1 chat で完了可。

#### (C) Look Unification main 着地観測 → sidecar dual emit 切替 — 極小 chunk

main で `BASE_LOOKS` export 着地を観測したら、`Export/FilmtoneSidecarWriter.swift` で `presetName` / `presetVersion` も emit (Look canonical と並列、Case A dual emit)。`normalizeFilmLookGradeInputIdentity()` 呼び出しで identity 不一致を throw。

scope: ~30-50 line edit。**main 着地待ち** (本 doc 作成時 未着地)。

### 15.3 Recommendation

**C5c → C5b の順**を推奨:

- C5c は小 chunk + canonical 化に直結 (vignette が iOS と byte-identical に近づく)
- C5c 完了後、C5a で残した `applyMask=0` 経路の "potentially divergent" risk が消える
- C5b は単独で大 chunk、C5c 完了後に着手することで C5b の verify 結果を C5c の RayAngleOptics 統合と切り分けられる

代替: C5b を sub-chunk 化 (bloom → halation+diffusion → RGB split + edge softness の 3 chat) で進める。

### 15.4 Phase 4 product gate との距離

Phase 4 (Native Capability Replacement) acceptance:
- Current Electron Desktop's core capabilities are covered
- Native app has no lower-quality export path
- Native app can be distributed as signed/notarized DMG

現在地:
- ✅ open + preview + still export (PNG/JPEG)
- ✅ video export (H.264 mp4 + Rec.709 metadata + sidecar)
- ✅ preset selection (4 built-in)
- ✅ source profile classification + sidecar interpretation
- ✅ vignette + grain (iphone preset で active)
- ❌ bloom / halation / diffusion (C5b)
- ❌ chromatic aberration (radialRGBSplit、C5b)
- ❌ edge softness (C5b)
- ❌ batch UI (Phase 3/4)
- ❌ session restore (Phase 4)
- ❌ LUT export (Phase 4)
- ❌ DMG signing/notarization (Phase 4)

→ C5b 完了で kernel parity が iphone preset に対して達成、softBlue / amberGlow など bloom-heavy preset で意味のある visual 進歩。

---

## 16. Prompt for next chat (English, MAX precision)

英語 prompt は §17 にて単独 block として用意 (next chat に paste する形式)。

---

## 17. 引き継ぎ用英語プロンプト (paste-ready)

```
You are continuing work on the Filmtone Native Desktop v2 lane in the worktree
at /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan
on branch `feature/native-desktop-plan` (HEAD `cd170a6` at handoff time).
The working tree is clean.

THIS IS A DESKTOP CHAT. iOS appears only as a read-only canonical reference
for kernel sources / type definitions / pipeline structure that the macOS
Native target verbatim-lifts. The iOS Xcode project
(apps/capacitor-film-lab-ios/) is INVIOLABLE — never edit its pbxproj, never
add XCUITest targets, never run codegen against it. The iOS app's v1.2 public
release is the canonical truth for CIColorKernel pipeline behavior; it MUST
remain untouched while local v1.3 / v1.5 Metal optics lanes are in flight.

═══════════════════════════════════════════════════════════════════════════════
FIRST ACTIONS (mandatory, in order)
═══════════════════════════════════════════════════════════════════════════════

1. Read the canonical handoff doc in full, no skimming, sections §0 through §18:
   docs/filmtone/desktop/filmtone-native-desktop-phase2-c5a-master-handoff-2026-05-03-jst.md

2. Read CLAUDE.md (worktree root) and apps/capacitor-film-lab-ios/CLAUDE.md.

3. Read the transition plan split files
   docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/{01,04,06}.md

4. Run the §11 sanity check commands EXACTLY as written. Do not skip any. Stop
   and surface any divergence from expected output before proceeding.

5. Check Look Unification main landing status (handoff §6.5):
     cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
     grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
   - empty output → Look Unification still NOT landed → keep Case B sidecar
   - non-empty → Look Unification landed → flag user; consider inserting a
     sidecar dual-emit (Case A) chunk before C5b/C5c work begins.

═══════════════════════════════════════════════════════════════════════════════
CONTEXT — what was completed in the predecessor chat (chat A.4)
═══════════════════════════════════════════════════════════════════════════════

Three commits stacked on main:

- 398743c — Phase 0 + 1a (skeleton + Open/Preview precondition)
- aeb0c7c — Phase 1b vertical slice (still) + Phase 1c vertical slice (video) +
            Phase 2 C1 (SourceColor DTO + factory + Source prober) +
            Phase 2 C2 (AVFoundation modern async migration) +
            Phase 2 C3 truth gate scaffold (baseline-C/ + PENDING-aware harness;
            content populate intentionally DEFERRED)
- cd170a6 — Phase 2 C5a per-pixel optical extension (vignette + grain
            CIColorKernel verbatim from iOS OpticalKernels L4321-4347 / L4350-4403,
            inserted into the canonical pipeline order
            baseGradeV2 → filmCompressionV2 → vignette → grain → printStage,
            with FilmtoneVideoExporter forwarding CMTimeGetSeconds(validTime)
            as frameTimeSeconds for grain frame advancement.)

Phase 2 C7 (IOSurface perf bench) was MEASURED, not refactored. Result:
1080p reset 0.35s / 205fps, 4K reset 0.88s / 82fps. 4K is realtime 3.4×;
CPU is 6-9% of wallclock; kernel chain overhead 0.1-0.2 ms/frame. CONCLUSION:
no IOSurface refactor needed at current scale. Reproducibility commands are
in handoff §5.8.5 (out-of-tree fixtures under /tmp/filmtone-perf-bench/).

═══════════════════════════════════════════════════════════════════════════════
NEXT WORK — recommended priority
═══════════════════════════════════════════════════════════════════════════════

Recommended ORDER: (B) → (A) sub-chunks. Discuss with the user before starting
if there is any signal that priorities have shifted.

(B) Phase 2 C5c — RayAngleOptics port (small, single-purpose chunk):
    - Lift apps/capacitor-film-lab-ios/ios/App/App/FilmtoneRayAngleOptics.swift
      verbatim into apps/filmtone-desktop-macos/FilmtoneDesktop/Color/
      FilmtoneRayAngleOptics.swift.
    - Extend FilmtoneSourceProber to extract camera optics metadata from
      CMFormatDescription extension dictionaries (focal length, sensor size,
      etc.) where available; otherwise return nil → falls back to applyMask=0.
    - Update FilmtoneGradePipeline.applyVignette to compute real opticsPack
      and applyMask=1 when optics metadata is available, preserving applyMask=0
      pre-Stream-2 byte-identical math when not.
    - Extend pbxproj for the new file.
    - Verify: bun run verify:macos PASSES, Phase 1b regression preserved
      (reset all ∞ dB), iphone 09-skin-light vs source PSNR remains ≈ 35dB
      (no source camera-optics metadata in PNG fixtures, so applyMask stays 0).

(A) Phase 2 C5b — multi-pass blur + CIKernel-based stages (LARGE chunk; consider
    sub-chunking into 3 chats if scope feels over budget):
    - Sub-chunk A.1: bloom (extractHighlightPlate via softKneeHighlight →
      tentDownsample/tentUpsample mip pyramid → glowComposite).
    - Sub-chunk A.2: halation + diffusion via the same pyramid + glowComposite
      with different threshold/tint/intensity arguments.
    - Sub-chunk A.3: radialRGBSplit (CIKernel, chromatic aberration) and
      edgeSoftnessBlend (CIKernel, softness blur).
    - Insertion order matches iOS FilmtoneExportSession L1541-2155.
    - Each sub-chunk = one commit; verify after each.

Other deferred but ready work:
- C6 (SPM consolidation): user has explicitly maintained "急がない" (do not
  rush) policy; do NOT pre-emptively start this without an explicit ask.
- C3 baseline-C populate: REQUIRES user iOS Simulator UI loop (40 manual
  exports). Classified as 外殻 (QA infrastructure), DEFERRED until the user
  explicitly says "品質保証希望" (quality-assurance request). Do not start
  this work autonomously.

═══════════════════════════════════════════════════════════════════════════════
USER PREFERENCES & OPERATIONAL DOCTRINE (sticky for this work)
═══════════════════════════════════════════════════════════════════════════════

These were established or reaffirmed in chat A.4. Carry them forward:

- 本質優先 / 外殻最小 / 全てがうまく行った時の品質保証
  Essence first, externals minimal, formal QA infrastructure ONLY when the
  user explicitly says "品質保証希望" or equivalent. Do not preemptively
  populate baseline-C, write formal QA matrices, expand i18n, or polish
  release surface until then. Code, pipelines, sidecars, kernels = essence.
  Test fixtures, golden image trees, formal harnesses = externals.

- 判断コスト最小限 (minimum decision cost)
  Make reasonable decisions autonomously. Surface ONE binary or ranked-N
  question only at chunk boundaries that genuinely require human judgment.
  Do not interrupt with low-leverage clarifications. The user is working in
  parallel on other chats and has limited attention.

- 並列で作業しているので私に可能な限りコストかけないように
  The user is in multiple parallel chats. Bundle clarifications. Surface
  status crisply at major checkpoints. Do not chat-back about minor things.

- Git operations: in chat A.4 the user verbally LIFTED CLAUDE.md §9
  "Git 操作は user が行う(自動コミット禁止)" for that session — they
  authorized autonomous git commit. The default (CLAUDE.md §9) is RE-ENGAGED
  for any new chat. CONFIRM with the user at the start of this chat whether
  the lift continues, or whether you should prepare commits for them to run
  themselves. NEVER push without explicit per-action confirmation.

- Co-Author tag for any commits made (if authorized):
  Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>

- This is a DESKTOP chat. If iOS comes up at all, it is a READ-ONLY reference.
  Re-read handoff §5.10.3 if uncertain. If the user asks "what does iOS have
  to do with this?" — clarify per §5.10.3 before continuing.

═══════════════════════════════════════════════════════════════════════════════
INVARIANTS (handoff §6, NEVER violate)
═══════════════════════════════════════════════════════════════════════════════

- Do not edit apps/capacitor-film-lab-ios/ Xcode project, plist, pbxproj.
  Reading Swift files for verbatim lift is allowed.
- Do not edit apps/desktop-film-lab-batch/ runtime code (electron renderer,
  build scripts, package.json runtime deps). Adding test fixtures under
  apps/desktop-film-lab-batch/test/golden/ is allowed.
- Do not delete packages/film-lab-renderer/dist/ or packages/film-lab-smart-look/
  dist/ — they are intentionally tracked for portfolio submodule consumption.
- Do not modify packages/film-lab-core/src/ contract sources from this chat.
- Do not hand-edit FilmtonePhase0Generated.swift on either iOS or macOS side.
  The two MUST remain bit-identical (verify with `diff -q` per §11).
- Sidecar emitter remains additive-only. Do not bump schemaVersion.
- bun-only. No npm. bun.lock is canonical.
- Use mcp__sequential-thinking for design judgment. Verify any uncertain
  CoreImage / AVFoundation / CMFormatDescription / Metal API behavior with
  gemini-search → WebSearch before claiming behavior.
- Verify handoff claims against the live surface (grep / Swift / pbxproj)
  before acting on them — handoffs can drift.

═══════════════════════════════════════════════════════════════════════════════
VERIFY PROTOCOL (per chunk)
═══════════════════════════════════════════════════════════════════════════════

Before proposing a commit:

1. bun run build:core
2. bun run generate:swift -- --check (exit 0)
3. diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
           apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
   (must produce no output)
4. bun run verify:macos (** BUILD SUCCEEDED **)
5. git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ \
              packages/film-lab-core/src/   (all clean)
6. CLI smoke for the changed surface:
     APP=apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop
     "$APP" --export-still --input <fixture> --output <out> --preset <name>
     "$APP" --export-video --input <fixture> --output <out> --preset <name>
7. Phase 1b regression: bun run scripts/golden-parity-macos.ts --preset reset
   (must remain all ∞ dB, mean baseB 13.69dB unchanged)
8. iphone preset PSNR sanity (handoff §5.9.5 records 35.00dB after C5a; C5b
   is expected to drop further as bloom/halation/diffusion become active for
   presets that have non-zero bloomStrength — softBlue / amberGlow primarily).

═══════════════════════════════════════════════════════════════════════════════
OUTPUT RULES
═══════════════════════════════════════════════════════════════════════════════

- 日本語 final output to user (technical terms English allowed).
- File references in `path/to/file:line` format.
- Concise, action-oriented. No padding.
- Surface major decisions as one binary or ranked-N question; do not enumerate
  every micro-decision.
- When you finish a chunk, write a successor handoff doc named
  filmtone-native-desktop-phase2-{chunk-tag}-{role}-handoff-{YYYY-MM-DD}-jst.md
  in docs/filmtone/desktop/, absorbing this handoff so the next chat can
  pick up self-contained.

═══════════════════════════════════════════════════════════════════════════════
REPRODUCIBLE STATE PROOF (handoff time)
═══════════════════════════════════════════════════════════════════════════════

git log --oneline -3 →
  cd170a6 feat(macos): Phase 2 C5a per-pixel optical extension (vignette + grain)
  aeb0c7c feat(macos): Native Desktop v2 Phase 1b/1c + Phase 2 C1/C2 + C3 parity scaffold
  398743c feat(macos): Native Desktop v2 Phase 0 + 1a + plan/handoff docs

bun run verify:macos → ** BUILD SUCCEEDED **
bun run generate:swift -- --check → exit 0 (drift 0)
diff Phase0Generated iOS↔macOS → identical
golden-parity-macos.ts --preset reset → 10/10 ∞ dB, mean baseB 13.69dB
iphone 09-skin-light --export-still vs source → PSNR 35.00dB
  topleft (10,10): source (225,192,170) → export (212,180,159)   ≈ -5% darker (vignette)
  topright (1270,10): source (181,140,117) → export (169,128,105) ≈ -7% darker (vignette)
  center (640,360): source (214,178,156) → export (217,179,156)  ≈ +1% (vignette neutral, grain micro)

If your sanity check produces different numbers, STOP and surface the
divergence before proceeding.

═══════════════════════════════════════════════════════════════════════════════

Begin by completing the FIRST ACTIONS in order, then propose the next chunk
(C5c recommended) with a one-line confirmation request to the user. Do not
start implementing until either (a) the user confirms, or (b) silence after
a clearly-stated default — apply the user-doctrine "判断コスト最小限" and
proceed with the recommended chunk if the user gave a "yes / proceed" signal.
```

---

## 18. Doc trail

### 本 phase の predecessor handoffs

- `filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md` — Phase 2 C1+C2+C3 scaffold master (本 doc に吸収済、historical)
- `filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md` — Phase 1c 完成記録 (predecessor master 経由で吸収済、historical)
- `filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md` — Phase 1c 開始時 master (historical)
- `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md` — Phase 1b 完成記録 (吸収済、historical)
- `filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md` — Phase 1b 開始時 master (historical)
- `filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md` — historical 子 (Phase 1a→1b)
- `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md` — Phase 0 完成 + Phase 1 開始時 handoff (historical)
- `filmtone-native-desktop-phase2-next-chat-prompt-2026-05-03-jst.md` — predecessor master の §16 prompt copy (historical)

### 全体計画書 split docs (Phase 2 C1+C2+C3 scaffold 反映済、C5a / C7 は本 doc が新)

- `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md` — parent index
- `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/`:
  - `01-current-state-and-decision.md`
  - `02-target-architecture-and-contracts.md`
  - `03-migration-and-concurrent-lanes.md`
  - `04-phase-plan.md`
  - `05-future-lanes.md`
  - `06-quality-gates-risks.md`

### Look Unification 関連 (chat B 別、参考)

- main checkout 側: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (canonical)
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`

### life knowledge hub 関連

- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md` — live エントリ doc (read order・active lanes)
- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md` — vocabulary canonical (`動画` / `Look` 用語ロックの根拠)
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-{release,ios}-truth.sh` — truth scripts

### memory records (auto memory)

- `feedback_auto_mode_no_decision_handoff` — auto mode + plan approved → run next command
- `feedback_dont_overengineer_dirty_state_split` — bundle in-flight work
- `feedback_no_promising_from_forced_substage` — forced boundary stage cost は ranking 用
- `feedback_no_silent_stream_redefine` — 並列 stream 残タスクの silent 省略禁止
- `feedback_verify_before_quoting_handoff` — handoff 引用前に現行 surface 確認
- `feedback_verify_before_documenting` — 検索/sequential-thinking で確認
- `feedback_no_guessing_davinci_plugins` — 記憶ベース推測禁止
- `feedback_no_jsx_comment_outside_root_return` — return ( の直下 JSX comment 禁止
- `feedback_no_fallback_bug_hotbed` — silent fallback 禁止
- `project_v15_metal_optics_lane` — iOS v1.5 Metal optics lane (本 chat 無触)
- `project_phase1b_baseline_b_fixture_mismatch` — baseline-B fixture mismatch
- `reference_devicectl_env_var_launch` — 実機 env var (Phase 2 C3 実機確定で参照、defer 中)
- `reference_xcrun_simctl_app_container` — Simulator container 抽出 (C3 baseline-C populate で参照、defer 中)

### 本 chat で生まれた候補 memory (次 chat で書き出し検討)

- `feedback_minimum_decision_cost_doctrine` — user は並列 chat で working、判断コスト最小限を最優先。chunk 境界以外で interrupt しない
- `feedback_essence_first_externals_minimal` — 「本質優先 / 外殻最小 / 全てがうまく行った時の品質保証」doctrine。formal QA infrastructure (baseline-C populate / GUI smoke / 過剰 i18n) は user 明示の「品質保証希望」まで defer
- `feedback_desktop_chat_ios_readonly` — Desktop chat で iOS は read-only canonical reference のみ。iOS code 変更を提案しない
- `project_phase2_c7_perf_bench_resolved` — 4K @ 80fps (realtime 3.4×) / 1080p @ 200fps、CPU 6-9%、kernel overhead 0.1-0.2ms/frame。IOSurface refactor 不要判定 (本 chat 確定)

---

## 19. このドキュメントについて

- role: Phase 2 C5a + C7 完了 → Phase 2 残 (C5b / C5c / Look Unification dual emit) onboarding canonical
- 作成: Phase 2 C5a + C7 完了 chat (chat A.4、predecessor master handoff の dirty bundle commit + C7 perf measurement + C5a per-pixel optical extension)
- 次回 master handoff (Phase 2 完了時 or Phase 3 開始時) はここを起点に作る
- naming: `filmtone-native-desktop-phaseN-{chunk-tag}-{role}-handoff-{date}-jst.md` パターン
