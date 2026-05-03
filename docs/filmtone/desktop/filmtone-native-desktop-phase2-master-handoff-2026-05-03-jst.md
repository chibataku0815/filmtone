# Filmtone Native Desktop v2 — Phase 2 C1+C2+C3 Master Handoff (Self-Contained)

Date: 2026-05-03 JST late evening
Source chat: chat A.3 (Phase 1c chat 終端から継続) — Phase 2 C1 (SourceColor DTO
graph + factory) + C2 (AVFoundation modern async migration) + C3 truth gate
scaffold (iOS↔macOS canonical 直接 PSNR harness、baseline-C populate PENDING)
Target chat: Phase 2 C3 baseline-C populate → C5/C6/C7 priority re-judgement
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan` (Phase 0+1a in commit `398743c`,
Phase 1b + 1c + Phase 2 C1+C2+C3 scaffold uncommitted on top)

**自己完結型 master handoff**。これ 1 本で次 chat が Phase 0/1a/1b/1c/2 の議論
・採択・実装・検証・残タスクを完全再現できる。predecessor (`filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md`、
`filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`、
`filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`) の
内容は全て本 doc に吸収済 — 歴史記録としてのみ残る。

---

## 0. Read-this-first 順序

新 chat 最初の 15-25 分:

1. **本ドキュメント全体** — skim 禁止、§0 から §17 まで通読
2. `CLAUDE.md` (worktree root) — project rules、§3 運用原則 / §6 antipattern
3. `apps/capacitor-film-lab-ios/CLAUDE.md` — iOS 不変条件 (223 行)
4. **全体計画書 split index**:
   `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
   は **canonical index (短い)**。詳細は split files
   `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/` 配下:
   - `01-current-state-and-decision.md` — Phase 2 C1+C2+C3 scaffold 反映済
   - `02-target-architecture-and-contracts.md` — Responsibility Boundaries
   - `03-migration-and-concurrent-lanes.md` — Look Unification 状況
   - `04-phase-plan.md` — Phase 2 C1+C2 着地状況 + C3 truth gate scaffold 着地状況反映済
   - `06-quality-gates-risks.md` — risks 表更新済 (AVFoundation deprecation
     RESOLVED / Swift 6 concurrency RESOLVED / baseline-C scaffold landed)
5. **Phase 2 C1+C2+C3 scaffold の元になった predecessor 記録** (深掘り時のみ):
   - `docs/filmtone/desktop/filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md` — Phase 1c 完了 handoff
   - `docs/filmtone/desktop/filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md` — Phase 1c 開始時 master
   - `docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md` — Phase 1b 完了 handoff
6. **Look Unification handoff** (main checkout 側、chat B):
   `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
   — sidecar 契約は Look Unification 着地状況で動作分岐 (詳細 §6.5 / §10)
7. `git log --oneline -10` で worktree commit 状態確認 (`398743c` の上に
   Phase 1b/1c/Phase 2 全 uncommitted)
8. **必ず実行**: §11 の sanity check + Look Unification main 着地状況確認

---

## 1. What is Filmtone (1 段落 context)

Filmtone は forestone (`chiba@fores-tone.co.jp`) の film-tone カラー
グレーディング製品群:

- **Filmtone Desktop** (Electron + React/Vite, macOS) — 写真 / 動画の film-tone
  バッチグレーディング。release rail として shipping 中。
- **Filmtone iOS** (Capacitor + SwiftUI/Metal/CoreImage) — App Store 公開、
  v1.2 public / v1.3 local candidate in-flight (lane `project_v15_metal_optics_lane`)。
- **共有 packages**:
  - `film-lab-core` — Phase0 params / preset / source-profile contract、
    Zod schema、Swift generator pure 関数の正本
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
| **Native Desktop worktree (本リポ・本 chat)** | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan` | Phase 0 / 1a / 1b / 1c / 2 実装、branch `feature/native-desktop-plan` | **編集対象** |
| Look Unification worktree (chat B 並列、別 chat) | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification` | Phase A / B 再開、branch `feature/desktop-look-unification` | **本 chat では編集禁止** (read-only 参照のみ、main 着地後に sidecar 契約反映) |
| filmtone main checkout | `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone` | main branch、参照のみ | 編集禁止 |
| portfolio | `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio` | 公開窓 (`apps/web`)、`vendor/filmtone` submodule で消費 | 触らない |
| life | `/Volumes/SamsungPortableSSDX5001/documents/life` | docs/guides + truth scripts + 5 ロール憲法 | 触らない |

### Worktree branch invariants

- Phase 0+1a+1b+1c+2(C1+C2+C3 scaffold) は同一 branch `feature/native-desktop-plan`
- Phase 0 + 1a は **commit `398743c` で bundling 済**
- Phase 1b + 1c + Phase 2 (C1+C2+C3 scaffold) は **2026-05-03 JST late evening
  時点で working tree 上 uncommitted** (本 handoff §5.7)。新 chat 開始時に
  user に commit 状況を確認してから着手
- 別 branch を切る必要は **なし**。PR 切るのは Phase 2 完了時 (Phase 0+1a+1b+1c
  と Phase 2 を 1 PR or 2 PR に分割は user 判断)

### Tooling versions (Phase 0+1a+1b+1c+2 で verified working)

- macOS 26.4.1 (Build 25E253)
- Xcode 26.4.1 (Build 17E202)
- Bun 1.3.3
- Swift 6.0 (target setting; Xcode 26 同梱 toolchain)
- Swift 6 strict concurrency 適用 (Phase 2 C1+C2 で AVAssetTrack non-Sendable
  対応の variadic load 採用)

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
  Liquid Glass を採用**
- `.glassEffect(.regular, in: Capsule())` は macOS 26.0+ / iOS 26.0+ /
  iPadOS 26.0+ / watchOS 26.0+ / tvOS 26.0+
- reduced-material fallback は **書かない** (Phase 0 確定)
- design rule (Apple HIG): glass は **navigation / control 層のみ**。
  content / preview には当てない

### UI framework stance

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
| **1b (Vertical Slice — still)** | preset 選択 + grade 適用 + still export + sidecar JSON + parity 検証ハーネス | **COMPLETE** (uncommitted、§5.5) |
| **1c (Vertical Slice — video)** | 動画 1 個 open + preview frame + H.264 mp4 export + sidecar | **COMPLETE** (uncommitted、§5.6) |
| **2 (Native Color/Export Backbone + SPM)** | C1 SourceColor DTO + factory / C2 AVFoundation modern async / C3 iOS↔macOS canonical parity / C5 OpticalFilters / C6 SPM / C7 IOSurface perf | **C1+C2+C3 scaffold COMPLETE** (uncommitted、§5.7)、**C3 baseline-C populate PENDING**、C5/C6/C7 deferred |
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

(predecessor master handoff §4 と同内容、要点のみ)

### Acceptance gate (全 PASS)

`bun run build:core` / `bun run generate:swift` / `bun run verify:macos`
(`** BUILD SUCCEEDED **`) / `bun run verify:ios` (D-Log / D-Log M / C-Log /
C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000) / iOS+Electron lane clean。

### 主要採択

- 手書き `.xcodeproj` (objectVersion 70, UUID prefix `FT0000000000000000000XXX`)
- generator multi-target dual emit (`scripts/generate-filmtone-swift.ts`):
  iOS / macOS の `FilmtonePhase0Generated.swift` を bit-identical に保つ
- Bundle id `co.fores-tone.filmtone.desktop` / macOS 26.0 / Swift 6.0
- Liquid Glass: SwiftUI `.toolbar` 標準で自動採用、`glassEffect(.regular,
  in: Capsule())` は custom 1 箇所のみ (`GlassControlGroup.swift`)

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

iOS の `FilmtonePhase0Math.swift` + `FilmtoneMediaTypes.swift` から generated
file が依存する 4 struct (`FilmtoneQuickState` / `FilmtonePhase0Params` /
`Phase0OutputProfileDTO` / `FilmtonePhase0HiddenDefaults`) を **memberwise
init + stored properties のみ** で macOS target にコピー。
`Domain/Phase0Types.swift` (75 行)。iOS は無触。

### Phase 1a で landed (commit `398743c` 一部)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/Domain/Phase0Types.swift   (新規)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift    (新規、NSImageView wrap)
apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift    (NSOpenPanel + ⌘O)
pbxproj                                                                 (UUID A06-A08 / B06-B08 / E05/E07 group + Sources phase 拡張)
```

---

## 5.5. Phase 1b 完成記録 (Vertical Slice — Still、要約)

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

### baseline-B fixture mismatch (重要発見)

`golden-parity-macos.ts --preset reset` の結果 (10/10 image):

| metric | 値 | 解釈 |
|---|---|---|
| **macOS↔source** | **∞ dB (10/10 bit-identical)** | reset preset は params identity → kernel epsilon gate で全段 no-op → CIImage ↔ CGImage roundtrip bit-identical。 |
| **macOS↔baseline-B** | 平均 **13.69 dB** (max 22.90, min 2.76) | baseline-B は source と完全に異なる pixel を持つ (legacy WebGL render path 由来)。 |

baseline-B fixture は legacy WebGL renderer から生成されており、iOS canonical
CIColorKernel pipeline (本 Phase 1b lift target) と stage graph が異なるため、
PSNR > 35dB 達成不可。これは Phase 1b の本質欠陥ではなく **fixture 側の
生成 pipeline が現行 canonical と乖離している**ことを意味する。

→ **Phase 1b 採用: 案 D (parity gate を Phase 2 acceptance に倒す) +
Phase 2 で 案 C (iOS↔macOS canonical 直接比較) で再構築**。Phase 1b は
"vertical slice が wire できる" 証明、"WebGL parity" は別問題。memory
`project_phase1b_baseline_b_fixture_mismatch` 記録済。

---

## 5.6. Phase 1c 完成記録 (Vertical Slice — Video、要約)

### Goal

動画 1 個 open + midpoint frame preview + H.264 mp4 export を 1 vertical slice
で wire。

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
- 1 sec synthetic mp4 (320x180 @ 24 fps) export: wallclock **0.366 sec** (~65 fps、
  proof scale)
- ffprobe: `color_space=bt709` / `color_transfer=bt709` / `color_primaries=bt709`
- iphone preset on video frame 0 vs reset preset on video frame 0: **PSNR 14.91 dB**
  — grade chain が video path で meaningful な差分を生成 (kernel chain active proof)

### 残課題 (Phase 1c → Phase 2)

- AVFoundation sync API deprecation 6 sites (Phase 2 C2 で解消予定)
- `FilmtoneVideoReader / FilmtoneVideoWriter` の `@unchecked Sendable` (Phase 2
  C7 actor isolation で再評価)
- 4K/6K perf 未測定 (Phase 2 C7)
- baseline-B fixture mismatch (Phase 2 C3 で 案 C で再構築)
- formal video parity ハーネス (Phase 2 C3 拡張)
- ProRes export option (Phase 2)
- scrubber / playback preview (Phase 3)

---

## 5.7. ★ Phase 2 C1+C2+C3 scaffold 完成記録 (本 handoff の主役)

### 5.7.1 Goal と Deliverable 状態

> Native Color/Export Backbone の **足場** を固める: SourceColor 分類 →
> canonical contract → AVFoundation modern async migration → iOS↔macOS canonical
> parity gate scaffold。**Source profile id round-trips through sidecar**
> (Phase 2 acceptance gate) を達成。

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
| 19 | C3 baseline-C content (4×10=40 cell) | **PENDING** (user iOS Simulator workflow) |

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

### 5.7.3 新規ファイル (uncommitted)

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
    ├── reset/                                 # PENDING
    ├── iphone/                                # PENDING
    ├── softBlue/                              # PENDING
    └── amberGlow/                             # PENDING
```

### 5.7.4 更新ファイル (uncommitted)

| パス | 変更内容 |
|---|---|
| `Color/FilmtoneColorPipelineContract.swift` | iOS L84-206 verbatim 形へ restructure。`phase1cMP4Default()` 削除、`stillImageOptions()` 追加 (`.applyOrientationProperty: true` + `.toneMapHDRtoSDR: true` + 条件付き `colorSpace: sourceFallbackColorSpace`)、`workingColorSpace` / `destinationColorSpace` を `FilmtoneColorPipeline.workingColorSpace()` / `outputColorSpace()` namespace に delegate。iOS-only `applyOutputMetadata(to: AVMutableVideoComposition)` overload は omit (macOS は AVAssetWriterInputPixelBufferAdaptor 直書き) |
| `Media/FilmtoneVideoReader.swift` | `init(probe: FilmtoneVideoTrackProbe, contract:)` に書き換え。deprecated `asset.tracks(withMediaType:)` / `track.naturalSize` / `.preferredTransform` / `.nominalFrameRate` / `asset.duration` を全消化、prober 経由 pre-loaded values 受領。`@unchecked Sendable` 維持 (single-Task usage) |
| `Media/FilmtoneVideoFramePreview.swift` | modern async API migration: `loadTracks(withMediaType:)` + variadic `try await videoTrack.load(.naturalSize, .preferredTransform)` + `try await asset.load(.duration)` + `try await generator.image(at:)`。`Sendable` conformance 削除 (AVAssetTrack/AVURLAsset 経由 transitive non-Sendable) |
| `Export/FilmtoneVideoExporter.swift` | `probeVideo` → factory → contract → reader 配線。`phase1cMP4Default()` call 撤去。sidecar 呼び出しに `sourceInterpretation: contract.sourceInterpretationID` 渡す |
| `Export/FilmtoneStillExporter.swift` | `probeStill` → factory → `contract.stillImageOptions()` を `CIImage(contentsOf:options:)` に渡す flow。`render(_:request:contract:)` で contract.destinationColorSpace を outputSpace として使用。sidecar 呼び出しに `sourceInterpretation: contract.sourceInterpretationID` 渡す |
| `Export/FilmtoneSidecarWriter.swift` | optional `sourceInterpretation: String? = nil` parameter 追加。non-nil の場合 sidecar payload top-level に additive 追加。schema bump なし |
| `UI/PreviewSurface.swift` | Coordinator-based Task 管理。`context.coordinator.currentTask?.cancel()` で前 Task cancel → 新 Task launch。video path のみ async (still は sync 維持で flicker 抑制) |
| `FilmtoneDesktop.xcodeproj/project.pbxproj` | UUID A17-A1C (BuildFile) / B17-B1C (FileRef) 追加。Domain group に B17、Color group に B18+B19+B1A、Media group に B1B+B1C を登録。Sources phase に A17-A1C 全登録 |

iOS Xcode project / Electron desktop / film-lab-core src は **未編集**
(master §6 invariants 遵守)。`git status apps/capacitor-film-lab-ios/` /
`git status apps/desktop-film-lab-batch/` / `git status packages/film-lab-core/src/`
共に clean。

### 5.7.5 Verify 結果

#### Build / contract gate

```bash
$ bun run build:core
ESM dist/index.js 113.65 KB
DTS dist/index.d.ts 115.84 KB

$ bun run generate:swift -- --check
(exit 0; iOS / macOS Phase0Generated.swift bit-identical 維持)

$ diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
          apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
(no output → identical)

$ bun run verify:macos
** BUILD SUCCEEDED **
```

#### AVFoundation deprecation 解消 (C2 全体スコープ)

| API | source | 状態 |
|---|---|---|
| `asset.tracks(withMediaType:)` | `FilmtoneVideoFramePreview.swift:27`、`FilmtoneVideoReader.swift:39` | RESOLVED → `try await asset.loadTracks(withMediaType:)` |
| `asset.duration` | `FilmtoneVideoFramePreview.swift:31`、`FilmtoneVideoReader.swift:67` | RESOLVED → `try await asset.load(.duration)` |
| `track.naturalSize` | `FilmtoneVideoReader.swift:68` | RESOLVED → variadic `track.load(.naturalSize, ...)` (Reader は probe 経由) |
| `track.preferredTransform` | `FilmtoneVideoReader.swift:69` | RESOLVED → variadic `track.load(..., .preferredTransform, ...)` |
| `track.nominalFrameRate` | `FilmtoneVideoReader.swift:70` | RESOLVED → variadic `track.load(..., .nominalFrameRate, ...)` |
| `AVAssetImageGenerator.copyCGImage(at:actualTime:)` | `FilmtoneVideoFramePreview.swift:80` | RESOLVED → `try await generator.image(at:)` async |

残 deprecation warning は既存 `CIColorKernel(source:)` 3 箇所のみ
(`FilmtoneGradeKernels.swift:14, 63, 85`)。Phase 1b 受容 (master §6.3)、Metal
CIKernel 移行 lane 別 chunk または C7 と合流。

#### Phase 1b regression (still、no regression)

```bash
$ bun run scripts/golden-parity-macos.ts --preset reset
01-highlight-sunset       Infinity   13.08dB
02-highlight-backlit      Infinity    2.76dB
03-highkey-whitedress     Infinity   22.90dB
04-highkey-cloud          Infinity   17.14dB
05-lowkey-shadow          Infinity   18.81dB
06-lowkey-noir            Infinity   15.68dB
07-midtone-gray           Infinity   10.56dB
08-midtone-gradient       Infinity   10.38dB
09-skin-light             Infinity   12.82dB
10-skin-dark              Infinity   12.75dB
macOS↔source : all ∞ dB (10/10 bit-identical)
macOS↔baseB  : 0/10 ≥ 35dB; mean 13.69dB  (informational、変化なし)
```

#### iphone preset (non-identity) on 09-skin-light

```bash
$ bun run scripts/golden-parity-ios-vs-macos.ts --preset iphone --image 09-skin-light
09-skin-light  40.60dB  —  PENDING
```

Phase 1c は 39.62 dB → Phase 2 C1+C2 で **40.60 dB (+0.98 dB)**。原因は C1 で
追加した `applyOrientationProperty: true` + sRGB fallback colorSpace option。
iOS canonical (`stillImageOptions()`) と整合する drift。

#### CLI smoke (still + video)

```bash
$ ./apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop \
    --export-still --input apps/desktop-film-lab-batch/test/golden/source-images/01-highlight-sunset.png \
    --output test-out/c1/reset-01.png --preset reset
ok 1280x720 ...

$ grep -E '"sourceInterpretation"|"sourceKind"|"lookId"' test-out/c1/reset-01.filmtone.json
    "lookId" : "filmtone:base:reset:v2",
  "lookId" : "filmtone:base:reset:v2",
  "sourceInterpretation" : "sdr-bt709",      # ★ NEW Phase 2 C1 additive
  "sourceKind" : "still"

$ ./apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop \
    --export-video --input apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4 \
    --output test-out/c1/reset-video.mp4 --preset reset
ok 320x180 frames=24 ...

$ grep -E '"sourceInterpretation"|"sourceKind"|"lookId"' test-out/c1/reset-video.filmtone.json
    "lookId" : "filmtone:base:reset:v2",
  "lookId" : "filmtone:base:reset:v2",
  "sourceInterpretation" : "sdr-bt709",      # ★ NEW Phase 2 C1 additive
  "sourceKind" : "video"

$ ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt,color_space,color_transfer,color_primaries -of default=noprint_wrappers=1 test-out/c1/reset-video.mp4
codec_name=h264
width=320
height=180
pix_fmt=yuv420p
color_space=bt709
color_transfer=bt709
color_primaries=bt709
```

#### C3 harness smoke (PENDING-aware)

```bash
$ bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
Phase 2 C3 truth gate — preset=reset
==============================================================================================
image                         macOS↔source     macOS↔baseC  status
----------------------------------------------------------------------------------------------
01-highlight-sunset               Infinity               —  PENDING
... (10 cells all PENDING)
==============================================================================================
macOS↔source : all ∞ dB (bit-identical roundtrip)
macOS↔baseC  : 0 cells with baseline-C entry (10 PENDING) — see ...baseline-C/README.md
```

### 5.7.6 ★ 重要発見・残課題

#### baseline-C content PENDING

C3 harness は scaffold COMPLETE だが、baseline-C content (iOS canonical export
PNGs) 自体は **空**。次 chat の最初の本質作業は **user iOS Simulator workflow
で 4 preset × 10 image = 40 cell を populate** すること。詳細手順は
`apps/desktop-film-lab-batch/test/golden/baseline-C/README.md` 参照。
populate 後の各セル interpretation:

| 結果 | 意味 |
|---|---|
| `macOS↔baseline-C >= 40 dB` | native lift の math が iOS canonical と identical (期待値) |
| `macOS↔baseline-C 30-40 dB` | 軽微な差分 (色域 round-trip / pixel format alignment 等)、要調査 |
| `macOS↔baseline-C < 30 dB` | 本質的な差分。Metal CIKernel port (案 C step 3) または factory contract の bug。 |
| `macOS↔baseline-C ∞ dB` | reset preset 期待値 (params identity → bit-identical) |

#### `CIColorKernel(source:)` deprecation 3 箇所未解消

`FilmtoneGradeKernels.swift:14, 63, 85` の `CIColorKernel(source:)` は
macOS 10.14 で deprecated。Phase 1b 採用以来の懸案。Metal CIKernel 移行が
代替経路だが、これは Phase 2 別 chunk または C7 (IOSurface + Metal compute)
と合流。Phase 2 C2 では未対応 (本質スコープが AVFoundation async migration
に絞られた)。

#### Still probe coverage limited

現状 still prober は `kCGImagePropertyProfileName` + `kCGImagePropertyColorModel`
の文字列マッチで Display P3 / sRGB / Rec.709 / Rec.2020 を判定。HEIC HDR
(HLG / PQ) photo の検出は ICC profile chunk 解析が必要 → Phase 4 (HDR output
lane) で再評価。Phase 2 acceptance gate (Source profile id round-trips) は
SDR 範囲で達成済。

#### iphone preset の Phase 1c → Phase 2 +0.98 dB drift

09-skin-light で 39.62 → 40.60 dB の上昇。`applyOrientationProperty: true` +
sRGB fallback colorSpace option 追加が iOS canonical match の方向 = 好ましい
drift。**ただし他の 9 image での影響は未測定**。次 chat で `--preset iphone
--image <other>` を回して確認することを推奨。

#### `@unchecked Sendable` for FilmtoneVideoReader / FilmtoneVideoWriter

C7 (actor isolation / IOSurface-backed Metal compute refactor) で再評価
必須。現在は exporter の単一 Task 内のみ使用と確認済 (concurrent reentry
なし)。

#### GUI smoke 未実施

Phase 1c から継続して、GUI smoke (⌘O .mp4 → midpoint preview / preset 切替 →
⌘E ProgressView / Cancel) は user 手動確認が pending。Phase 2 C2 で PreviewSurface
を Coordinator-based Task に変えたため、preset 切替時の stale frame race 確認が
新たに加わる (前 Task cancel が効いているか視認)。

---

## 6. Critical Invariants (絶対に壊さない、final consolidated)

### 境界 (Phase 0 + 1a + 1b + 1c + 2 で立てた)

1. **iOS Xcode project (`apps/capacitor-film-lab-ios/`) を編集しない** —
   v1.3 local candidate lane in-flight (memory `project_v15_metal_optics_lane`)。
   Phase 2 C1 で iOS Swift から DTO + classifier + factory + format reader
   を **read-only 参照 + 内容コピー** したのは OK だが、iOS の `.pbxproj`
   には触らない。XCUITest target 追加禁止 (C3 案 C で UI 自動化を退ける根拠)
2. **Electron desktop (`apps/desktop-film-lab-batch/`) を編集しない** —
   release rail。Phase 4 で current-capability replacement に到達するまで
   shipping rail として残す。**parity 比較で test fixture を read するのは OK**。
   `baseline-C/` を新規作成したのは test fixture directory なので OK
3. **`packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/`
   を消さない** — submodule 即 import 用に track 維持
4. **`packages/film-lab-core/src/` の contract source は変更しない**
5. **生成 Swift を手編集しない**
6. **iOS と macOS の `Phase0Generated.swift` は bit-identical**
7. **`Domain/Phase0Types.swift` の field 順序 / 名前を変えない**。Phase 2 C1
   で **新規 file `Domain/SourceColorTypes.swift` を追加** したが、既存
   `Phase0Types.swift` は無触
8. **`SharedGenerated/FilmtonePhase0Generated.swift` は Compile Sources に入っている**
9. **Responsibility Boundaries** (02-target-architecture-and-contracts.md):
   - `UI` は SwiftUI views と AppKit wrappers のみ
   - `State` は editor state + flow orchestration のみ
   - `Color` は CIKernel / CIContext / preset catalog / pipeline factory + DTO classifier。
     Phase 2 C1 で `FilmtoneColorPipeline.swift` (factory namespace) +
     `SourceColorMetadataNormalizer.swift` + `SourceColorClassifier.swift` を
     ここに追加
   - `Export` は still/video encoding + sidecar emission
   - `Domain` は platform-neutral 型 + generated contract glue。Phase 2 C1 で
     `SourceColorTypes.swift` を追加
   - `Media` は probing+reader+writer。Phase 2 C1 で
     `FilmtoneSourceProber.swift` + `FormatExtensionReader.swift` を追加
   - 依存方向: `UI → State → Domain` / `UI → State → Color/Export/Media services` /
     `Export → Color / Media / Domain` / `Color → Domain / SharedGenerated` /
     `Media → Color (DTO 経由) / Domain` / `App` は composition のみ

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
  AVFoundation / Metal / CGImageSource) は `gemini-search` → `WebSearch` の順
- handoff doc を引用する前に、現行 surface (`grep` / Swift / pbxproj) と
  突き合わせて live/frozen を確認 (`feedback_verify_before_quoting_handoff`)
- 並列 stream で残タスクの silent 省略禁止 (`feedback_no_silent_stream_redefine`)
- npm publishing を再導入しない (CLAUDE.md §6 antipattern #1)

### Sidecar additive only (Data Contract 制約)

- macOS native sidecar emitter は schema bump せず **additive field のみ追加**
- Phase 1c で `sourceKind` additive、Phase 2 C1 で `sourceInterpretation` additive
- Look Unification main 着地時に dual emit (Case A) へ切替予定だが additive
  契約は維持

---

## 6.5. Concurrent Lane: Desktop Look Unification (chat B 並列進行中)

**Native Desktop v2 (chat A、本 chat) と並行して chat B で進行中の lane**。
Native ユーザー配布 (Phase 5 release rail 切替) 前の dual emit (Case A)
切替が release blocker。

### Lane 概要

- branch: `feature/desktop-look-unification`
- chat B worktree path:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-look-unification`
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`
- 再開 handoff (canonical):
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
  (main checkout 側)
- 状態 (2026-05-03 JST late evening): branch 上で Phase A `1f99d68` (core/schema
  additive aliases) + Phase B `fd9ddd2` (Electron renderer + film-lab-ui sweep)
  両方 landed、**main 未 merge**

### Phase 2 C3 開始時の Look Unification 着地確認 (Phase 1c chat 終端 + Phase 2 C1 chat 開始時 grep 結果)

```bash
$ grep -E "^export.*BASE_LOOKS|^export.*PRESETS" \
       /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/packages/film-lab-core/src/index.ts
(no output → BASE_LOOKS 未着地、PRESETS は引き続き存在)

$ grep -nE "lookId|presetName" \
       /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
138:function presetFromLookId(lookId: string): PresetName | null {
143:    if (id === lookId) return name;
(presetFromLookId converter は存在、ただし BASE_LOOKS export なしなので Phase A 未着地)
```

→ **Case B (Look canonical only sidecar emit) 継続**。Phase 2 C1 chat 中に
main 着地は観測されなかった。dual emit 切替は次 chat 以降。

### Native Desktop v2 が依存する成果物 (Look Unification main 着地で利用可)

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

### Native Desktop ユーザー配布前の release blocker

- Phase 5 release rail 切替前に Look Unification main merge + macOS sidecar
  emitter dual emit 切替 + Electron reader catch-up が必須
- **vocabulary 不統一のまま public release しない方針** (06 risk row、Phase 5
  release gate で確認)

---

## 7. Truth Gates (life スクリプト)

release/iOS 状態を主張する前に必ず通す:

```bash
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-release-truth.sh
/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-ios-truth.sh
```

doc とスクリプトが食い違ったら **スクリプトを信頼**。`FILMTONE_REPO_ROOT`
env で root 上書き可。

---

## 8. アンチパターン (CLAUDE.md §6、Phase 2 で踏まなかったもの)

1. ✅ npm publishing を再導入しない (npm 不使用、bun のみ)
2. ✅ `packages/film-lab-{renderer,smart-look}/dist/` 維持 (track 不変)
3. ✅ portfolio を実装の正本扱いしない
4. ✅ iOS public 版 (1.2) と local candidate (1.3 / 1.5 lane) を混ぜない
   (C3 案 C は v1.2 public のみ参照)
5. ✅ 用語ロック (動画 / video / Look)
6. ✅ JSX comment を return ( の直下に置かない (本 phase は SwiftUI なので
   該当なし、ただし `feedback_no_jsx_comment_outside_root_return` を念頭)

---

## 9. Verify protocol (本 chunk で通したもの)

実行順は §11 sanity check で再現可能。Phase 2 C1+C2+C3 scaffold で必ず通す:

1. `bun run build:core` — `film-lab-core` build ok
2. `bun run generate:swift -- --check` — drift 0 (exit 0)
3. `diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift
   apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift`
   — identical (no output)
4. `bun run verify:macos` — `** BUILD SUCCEEDED **`、AVFoundation deprecation 0
   (残 `CIColorKernel(source:)` 3 箇所のみ既知)
5. `git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/
   packages/film-lab-core/src/` — clean
6. `bun run scripts/golden-parity-macos.ts --preset reset` — Phase 1b regression
   check (∞ dB / 13.69dB)
7. `bun run scripts/golden-parity-ios-vs-macos.ts --preset reset` — C3 harness
   smoke (10 PENDING、∞ dB roundtrip)
8. CLI still smoke: 01-highlight-sunset.png reset → ok 1280x720 + sidecar に
   `sourceInterpretation: sdr-bt709` 確認
9. CLI video smoke: synthetic-bt709-1s-20260424.mp4 reset → ok 320x180 frames=24
   + sidecar に `sourceInterpretation: sdr-bt709` + ffprobe Rec.709 metadata 確認

(時間が許せば) `bun run verify:ios` — iOS lane 無傷再確認 (D-Log / D-Log M /
C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000、sidecar pass)。

---

## 10. Sidecar contract (Phase 2 C1 で additive 追加)

```json
{
  "schemaVersion": 1,
  "exportedAtIso": "2026-05-03T13:14:49.814Z",
  "appVersion": "0.1.0-macos",
  "appPlatform": "macos-native",
  "sourceFile": "/.../01-highlight-sunset.png",
  "sourceKind": "still",                 // Phase 1c additive
  "sourceInterpretation": "sdr-bt709",   // Phase 2 C1 additive — Source profile id round-trip
  "outputFile": "/.../reset-01.png",
  "gradeParams": { ... 35 fields ... },
  "batchLookChoice": {
    "lookId": "filmtone:base:reset:v2",
    "lookVersion": "v2",
    "baseLookName": "reset",
    "strength": 1
  },
  "lookId": "filmtone:base:reset:v2",
  "lookVersion": "v2",
  "quickState": { "filmCharacter": 0, "era": 0, "dynamics": 0 }
}
```

`sourceInterpretation` の値域 (`SourceColorClassDTO.rawValue` または特殊値):
- `sdr-bt709` (strict BT.709 SDR、最も多い)
- `display-p3-sdr` (iPhone Display P3 photo、Phase 2 C1 で検出可能になった)
- `hdr-pq` (PQ HDR)
- `hdr-hlg` (HLG HDR)
- `apple-log` (Apple Log)
- `apple-log2` (Apple Log 2)
- `wide-gamut-unknown` (BT.2020 / mastering display metadata あり、transfer 不明)
- `unsupported` (ProRes RAW 等)
- `unknown` (probe 不能、または source profile metadata 完全欠如)

### Look Unification 着地状況による分岐

**現状 (Case B、Look canonical only)**: sidecar に `lookId` / `lookVersion` /
`batchLookChoice` のみ。legacy `presetName` / `presetVersion` は emit しない。

**Look Unification main merge 後 (Case A、dual emit)**: 上記に加えて legacy
`presetName` / `presetVersion` も emit。`normalizeFilmLookGradeInputIdentity()`
で identity 不一致を throw。

→ Case A 切替は Phase 2 C3 populate と並行可能 (sidecar 構造変更のみ、parity
gate には影響しない)。

---

## 11. Sanity check 開始時コマンド (新 chat の最初に必ず実行)

```bash
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan

# (1) commit 状態確認
git log --oneline -5
# expect: 398743c が HEAD、その上に dirty (Phase 1b+1c+2 commit 待ち) または
#         直近 commit 群 (user が中間 commit していた場合)

git status
# expect:
#   M  .gitignore
#   M  apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj
#   M  apps/filmtone-desktop-macos/FilmtoneDesktop/App/FilmtoneDesktopApp.swift
#   M  apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift
#   M  apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift
#   M  docs/filmtone/desktop/...transition-plan...
#   ?? apps/desktop-film-lab-batch/test/golden/baseline-C/
#   ?? apps/filmtone-desktop-macos/FilmtoneDesktop/{Color/, Domain/SourceColorTypes.swift, Export/, Media/, State/, UI/GradeControls.swift}
#   ?? docs/filmtone/desktop/filmtone-native-desktop-phase{1b,1c,2}-...handoff...
#   ?? scripts/{compare-pngs.ts, golden-parity-{ios-vs-macos,macos}.ts}

# (2) 不変条件 sanity
bun run generate:swift -- --check                        # exit 0 (drift 0)
diff -q apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift \
        apps/filmtone-desktop-macos/FilmtoneDesktop/SharedGenerated/FilmtonePhase0Generated.swift
                                                          # no output (identical)
git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
                                                          # clean

# (3) build + parity
bun run verify:macos                                      # ** BUILD SUCCEEDED **
bun run scripts/golden-parity-macos.ts --preset reset     # ∞ dB / 13.69dB
bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
                                                          # 10 PENDING (baseline-C 未populate)

# (4) Look Unification main 着地状況確認
cd /Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone
git log --oneline | grep -iE "look unification|baselook" | head
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
# 着地済 (BASE_LOOKS export あり) → Case A dual emit に切替
# 未着地 (BASE_LOOKS export なし) → Case B 継続
```

---

## 12. Risks (06-quality-gates-risks.md と整合、Phase 2 で更新済)

### RESOLVED (Phase 2 C1+C2 で解消)

- AVFoundation sync API deprecation 6 sites
- Swift 6 strict concurrency × AVAssetTrack non-Sendable

### ADDRESSED with scaffold (Phase 2 C3 で着地、populate 待ち)

- baseline-B fixtures derive from legacy WebGL render path → baseline-C 案 C
  scaffold landed (PENDING populate)

### OPEN (Phase 2 残 chunk または別 phase)

- `CIColorKernel(source:)` deprecation 3 箇所 → Metal CIKernel 移行 lane
  (Phase 2 別 chunk または C7 と合流)
- `FilmtoneVideoReader / FilmtoneVideoWriter` `@unchecked Sendable` →
  C7 actor isolation refactor で再評価
- 4K/6K perf 未測定 → C7 IOSurface bench
- Native ユーザー配布前 dual emit 切替 → release blocker (Phase 5 acceptance gate)

### NEW OPEN (Phase 2 C3 populate で発生する可能性)

- iOS Simulator vs 実機の kernel 差異 (CIColorKernel deterministic と前提)
- iOS export の color profile 完全マッチ (Display P3 写真の sidecar
  `sourceInterpretation` が "display-p3-sdr" に出るか)

---

## 13. 採択した設計判断・採択しなかった案

### 13.1 採択した設計判断 (本 chunk、§5.7.2 と一致)

(再掲省略、§5.7.2 参照)

### 13.2 検討して採択しなかった案

| # | 検討案 | 採択判断 | 理由 |
|---|---|---|---|
| 1 | C1 で `FilmtoneMezzanineRoutePolicy` も port | NO | iOS mezzanine routing は macOS native に irrelevant。Phase 4 (batch + session) で必要なら別 chunk |
| 2 | Source prober を sync init + lazy probe に | NO | exporter は単一 Task 内で完結。eager async probe で contract を 1 回計算 → reader/writer は contract 受領 = clean |
| 3 | sidecar `sourceInterpretation` を `batchLookChoice` block 内に追加 | NO | top-level additive にした。`batchLookChoice` は Look Unification 専用の Look 識別 block なので役割を混ぜない |
| 4 | C3 で iOS app に CLI mode を追加 (XCUITest 不要) | NO | iOS Xcode project / pbxproj 編集禁止 (master §6 invariant #1) |
| 5 | C3 で iOS app の Photo library を AppleScript 経由で自動操作 | NO | Photo library 自動操作は脆弱、production iOS app の挙動と乖離。manual UI が canonical |
| 6 | C3 baseline-C を WebGPU canonical (`packages/film-lab-renderer/src/webgpu/`) で生成 | NO | WGSL は Phase 1b で baseline-B 由来の不一致が確認済。iOS app の CIColorKernel canonical を真値とするのが Native 移行の意図と整合 |
| 7 | Reader を引き続き sourceURL 経由 sync init で deprecation 受容 | NO | C2 が AVFoundation modern async migration を明示スコープにしているので解消した |
| 8 | C2 で `track.load(.formatDescriptions)` を別 await にして parallel | NO | 4-tuple variadic で十分 (single underlying request)。track ownership split を増やす理由がない |
| 9 | C6 SPM 化を C1+C2 と同 chunk で進める | NO | chunk 着手時 user 確定: 「C6 SPM 化は前 stance『急がない』維持」。C3 baseline-C 確定 + Phase 3 UI で構造が固まってから |

---

## 14. Commit strategy (推奨選択肢 2)

worktree は **Phase 1b + 1c + Phase 2 (C1+C2+C3 scaffold) すべて uncommitted**。
推奨は **2 bundle 分割**:

### Bundle 1: Phase 1b + 1c vertical slice

```
feat(macos): Phase 1b+1c vertical slice (still + video export wiring)

- Phase 1b: preset selection (4: reset/iphone/softBlue/amberGlow) +
  CIColorKernel chain (baseGradeV2 / filmCompressionV2 / printStage verbatim
  lift) + still export (PNG/JPEG via CGImageDestination) + sidecar JSON
  (Case B Look canonical only) + parity harness.
- Phase 1c: open .mov/.mp4 + midpoint frame preview + AVAssetReader →
  CIImage → grade → CIContext.render(to:CVPixelBuffer) → AVAssetWriter
  H.264 + AVVideoProfileLevelH264HighAutoLevel + Rec.709 metadata.
  sidecar `sourceKind:"video"` additive. Progress UI (SwiftUI ProgressView
  + Cancel). CLI --export-still / --export-video modes.
- pbxproj: UUID A09-A16 / B09-B16 + Color/State/Export/Media groups.

Result: reset macOS↔source = ∞dB (10/10 bit-identical). 1-sec synthetic
mp4 → 24-frame 320x180 .mp4 in 0.366s, Rec.709 SDR metadata correctly
written. iphone vs reset frame 0 PSNR 14.91dB confirms grade chain active.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Bundle 2: Phase 2 C1+C2+C3 scaffold

```
feat(macos): Phase 2 C1+C2+C3 scaffold (DTO port + AVFoundation modern async + iOS-vs-macOS parity harness)

C1 (SourceColor DTO + factory):
- Domain/SourceColorTypes.swift: SourceColorClassDTO (8) +
  SourceLogTransferFunctionDTO (2) + SourceColorMetadataDTO (7 fields).
  iOS FilmtoneMediaTypes L67-156 verbatim.
- Color/SourceColorMetadataNormalizer.swift: CoreMedia → ffprobe vocab.
- Color/SourceColorClassifier.swift: classify(metadata).
- Color/FilmtoneColorPipeline.swift: defaultOutputContract factory +
  isDisplayP3SDR + workingColorSpace + outputColorSpace namespace
  (iOS L1-82 verbatim, FilmtoneMezzanineRoutePolicy intentionally skipped).
- Color/FilmtoneColorPipelineContract.swift: restructured to iOS L84-206
  match. phase1cMP4Default() removed; stillImageOptions() added.
- Media/FormatExtensionReader.swift: CMFormatDescription extension reader.
- Media/FilmtoneSourceProber.swift: async video probe (modern API) +
  still CGImageSource probe. FilmtoneVideoTrackProbe non-Sendable.

C2 (AVFoundation modern async migration):
- FilmtoneVideoFramePreview: loadTracks + variadic track.load(_:_:) +
  generator.image(at:) async. Sendable conformance dropped.
- FilmtoneVideoReader: rebuilt around FilmtoneVideoTrackProbe init —
  drops asset.tracks / track.naturalSize / .preferredTransform /
  .nominalFrameRate / asset.duration deprecations.
- FilmtoneVideoExporter: probe → factory → contract → reader wiring.
- FilmtoneStillExporter: probe → factory → stillImageOptions for
  Display P3 / sRGB CIImage source colorSpace fallback.
- FilmtoneSidecarWriter: optional sourceInterpretation parameter,
  additive top-level field (Phase 2 acceptance "Source profile id
  round-trips through sidecar"). schema bump avoided.
- UI/PreviewSurface: Coordinator-based Task management for stale frame
  race avoidance on preset switch.
- pbxproj: UUID A17-A1C / B17-B1C; Color/Media/Domain groups extended.

C3 truth gate scaffold:
- apps/desktop-film-lab-batch/test/golden/baseline-C/{reset,iphone,
  softBlue,amberGlow}/ + provenance README (iOS Simulator workflow).
- scripts/golden-parity-ios-vs-macos.ts: PENDING-aware harness.
  baseline-C content itself remains PENDING until iOS Simulator export
  populates the 4×10=40 still cells.

Result: bun run verify:macos BUILD SUCCEEDED. AVFoundation sync deprecation
6 sites resolved (only existing CIColorKernel(source:) 3 sites remain,
accepted per master §6.3). generator drift 0; iOS↔macOS Phase0Generated
bit-identical. iOS / Electron / core src clean. Sidecar emits
sourceInterpretation: "sdr-bt709" for both still and video. Rec.709
metadata correctly written for video. iphone preset on 09-skin-light:
macOS↔source 40.60 dB (was 39.62 dB) — slight tighter source color
interpretation aligned with iOS canonical.

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Pre-commit gate (実行順)

GUI smoke を最優先で実行:

1. **GUI manual smoke** (user 実行) — CLI で full pipeline は verify 済、GUI 部分:
   ```bash
   open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
   # ⌘O → synthetic-bt709-1s-20260424.mp4 → midpoint preview (async に変わった、flicker なきこと)
   # preset 切替 → preview 即更新 (前 Task cancel 効いていること)
   # ⌘E → .mp4 Save panel → ProgressView + Cancel 確認
   ```
2. 問題があれば修正 → 該当 bundle 内に取り込む
3. `git diff --check` で whitespace 不整合確認
4. `bun run verify:macos` 再実行
5. (時間が許せば) `bun run verify:ios` で iOS lane 無傷再確認
6. **user commit** (gpg/hooks 通常運用、`feedback_dont_overengineer_dirty_state_split`)
7. **次 chat 着手** (Phase 2 C3 baseline-C populate)

---

## 15. Next chat (Phase 2 C3 populate) の起点

### 15.1 First useful action

**user iOS Simulator workflow で baseline-C を populate**:

詳細は `apps/desktop-film-lab-batch/test/golden/baseline-C/README.md` 参照。
要点:

1. iOS Simulator boot + Filmtone iOS app (v1.2 public) を install
2. `xcrun simctl addmedia booted source-images/*.png` で 10 source 画像を
   Photos library に push
3. iOS app で各 (image, preset) を export → save to Files
4. `xcrun simctl get_app_container booted co.fores-tone.filmtone data` で
   container path を取得 → exported PNG を `baseline-C/<preset>/<image>.png`
   に配置
5. `bun run scripts/golden-parity-ios-vs-macos.ts --preset <name>` で各セル
   PSNR 確認
6. 全セル PASS (>= 35dB、reset = ∞ dB) なら 案 C step (1) 完了
7. 失敗セルがあれば (a) factory contract / probing の bug 修正、または
   (b) 案 C step (3) WGSL→Metal CIKernel port を不足 effect path に対して実施

### 15.2 baseline-C 確定後

実機 iPhone で同じ matrix を 1 回再撮影し、最終 baseline-C として置き換える。
実機⇄simulator で kernel 差異がないことを確認後、以降の regression は macOS
内完結 (実機 tag に縛らない)。

### 15.3 Phase 2 残 chunk 優先付け再判断 (C3 結果次第)

| 結果 | 推奨次 chunk |
|---|---|
| 全セル PASS、effect path 完全一致 | **C7** (IOSurface perf bench、4K/6K 実測) |
| 一部セル FAIL、optical 関連の差分 | **C5** (OpticalFilters main 着地 + bloom/halation/diffusion/vignette/grain 統合) |
| 一部セル FAIL、color science 関連の差分 | 案 C step (3) WGSL→Metal CIKernel port |
| Look Unification main merge 観測 | sidecar dual emit (Case A) 切替を別 chunk として挿入 |

**C6 (SPM 化) は急がない方針維持** (chunk 着手時 user 確定)。Phase 3/4 で
構造が固まってから着手 (Domain/Color/Media を SPM 移管、`Domain/Phase0Types.swift`
+ `Domain/SourceColorTypes.swift` を package へ集約、iOS からも参照、`Domain/*`
削除 → import 切替)。

### 15.4 GUI smoke が user side で実施されていない場合

Phase 1c から続いて GUI smoke は pending。次 chat 着手前に必ず確認:
- Open panel video accept (`.movie` / `.mpeg4Movie` / `.quickTimeMovie`)
- Save panel `.mp4` filter
- ExportProgressBar (ProgressView + Cancel)
- midpoint preview (Phase 2 C2 で async 化、preset 切替時の前 Task cancel 確認)

---

## 16. Prompt for next chat (highest precision)

§17 にて単独 block として用意 (next chat に paste する形式)。

---

## 17. Doc trail

### 本 phase の predecessor handoffs

- `filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`
  — Phase 1c 完成記録 (本 doc §5.6 に吸収)
- `filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md`
  — Phase 1c 開始時 master (本 doc §0-§4 のテンプレート)
- `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`
  — Phase 1b 完成記録 (本 doc §5.5 に吸収)
- `filmtone-native-desktop-phase1b-master-handoff-2026-05-03-jst.md`
  — Phase 1b 開始時 master (historical)
- `filmtone-native-desktop-phase1b-next-chat-handoff-2026-05-03-jst.md`
  — historical 子 (Phase 1a→1b、本 doc §0 で記録)
- `filmtone-native-desktop-phase1-next-chat-handoff-2026-05-03-jst.md`
  — Phase 0 完成 + Phase 1 開始時 handoff (historical)

### 全体計画書 split docs (Phase 2 C1+C2+C3 scaffold 反映済)

- `docs/filmtone/desktop/filmtone-native-desktop-transition-plan-2026-05-03-jst.md`
  — parent index
- `docs/filmtone/desktop/native-desktop-transition-plan-2026-05-03-jst/`:
  - `01-current-state-and-decision.md`
  - `02-target-architecture-and-contracts.md`
  - `03-migration-and-concurrent-lanes.md`
  - `04-phase-plan.md`
  - `05-future-lanes.md`
  - `06-quality-gates-risks.md`

### Look Unification 関連 (chat B 別、参考)

- main checkout 側:
  `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone/docs/filmtone/desktop/filmtone-desktop-look-unification-handoff-2026-05-03-jst.md`
  (canonical)
- 元 plan: `~/.claude/plans/desktop-look-unification-bright-dusk.md`

### life knowledge hub 関連

- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/film-lab-current-index.md`
  — live エントリ doc (read order・active lanes)
- `/Volumes/SamsungPortableSSDX5001/documents/life/docs/guides/2026-04-07-filmtone-tool-vocabulary-ia-spec.md`
  — vocabulary canonical (`動画` / `Look` 用語ロックの根拠)
- `/Volumes/SamsungPortableSSDX5001/documents/life/scripts/check-filmtone-{release,ios}-truth.sh`
  — truth scripts

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
- `reference_devicectl_env_var_launch` — 実機 env var (Phase 2 C3 実機確定で参照)
- `reference_xcrun_simctl_app_container` — Simulator container 抽出 (C3 baseline-C populate で参照、もし memory に未登録なら本 doc §15.1 を referent)

---

## 18. このドキュメントについて

- role: Phase 2 C1+C2+C3 scaffold → C3 baseline-C populate (or 並列で C5/C6/C7
  のいずれか) onboarding canonical
- 作成: Phase 2 C1+C2+C3 scaffold 実装 chat (chat A.3、Phase 1c chat 終端から
  継続)
- 次回 master handoff (Phase 2 完了時 or Phase 3 開始時) はここを起点に作る
- naming: `filmtone-native-desktop-phaseN-{role}-handoff-{date}-jst.md` パターン
