# Filmtone Native Desktop v2 — Phase 1c Completion Handoff

Date: 2026-05-03 JST
Worktree: `/Volumes/SamsungPortableSSDX5001/documents/forestone/filmtone-native-desktop-plan`
Branch: `feature/native-desktop-plan` (Phase 0+1a in commit `398743c`, Phase 1b
+ 1c uncommitted on top)
Predecessor: `filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md`
(canonical), `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`
(Phase 1b record)

このドキュメントは Phase 1c (動画 vertical slice — open .mov/.mp4 → preview
midpoint frame → H.264 mp4 export → sidecar JSON) の **landing 報告**。次 chat
は Phase 2 (Native Color/Export Backbone + SPM) を起点に進める。

---

## 1. Landing summary

Phase 1c の deliverable は全て wired:

| # | Deliverable | 状態 |
|---|---|---|
| 1 | .mov/.mp4 1 個を NSOpenPanel で open | ✅ landed |
| 2 | midpoint frame を CIImage で preview に表示 (grade 適用) | ✅ landed |
| 3 | AVAssetReader → CIImage → grade → CIContext.render(to:CVPixelBuffer) → AVAssetWriter で H.264 mp4 export | ✅ landed |
| 4 | sidecar JSON (Case B 継続 + `sourceKind:"video"` additive) | ✅ landed |
| 5 | 進捗 UI (SwiftUI ProgressView + Cancel ボタン) | ✅ landed |
| 6 | CLI `--export-video` mode | ✅ landed |

**Vertical slice として完結**: GUI でも CLI でも source .mp4 → preset → graded
.mp4 + sidecar JSON が一回の path で出る。`bun run verify:macos` 通過、generator
drift なし、iOS / Electron lane 無傷。

---

## 2. 実装内容 (新規 + 更新ファイル)

### 新規 (worktree, branch `feature/native-desktop-plan` の uncommitted 分)

```
apps/filmtone-desktop-macos/FilmtoneDesktop/
├── Color/
│   └── FilmtoneColorPipelineContract.swift   # struct lift from iOS
│                                             # FilmtoneColorPipeline.swift:84-206
├── Media/                                    # 新規グループ (E0B)
│   ├── FilmtoneVideoFramePreview.swift       # AVAssetImageGenerator 0.5*duration
│   ├── FilmtoneVideoReader.swift             # AVAssetReader wrap (32BGRA only)
│   └── FilmtoneVideoWriter.swift             # AVAssetWriter wrap (H.264 + Rec.709)
└── Export/
    ├── FilmtoneSidecarTypes.swift            # FilmtoneSourceKind enum + protocol
    └── FilmtoneVideoExporter.swift           # async orchestrator (reader→grade→writer)
```

### 更新 (既存ファイル)

| パス | 変更内容 |
|---|---|
| `App/FilmtoneDesktopApp.swift` | `--export-video` CLI mode 追加 (DispatchSemaphore で sync bridge) |
| `Export/FilmtoneStillExporter.swift` | `FilmtoneStillExportRequest` を `FilmtoneSidecarRequest` に conform、`sourceKind: .still` 追加 |
| `Export/FilmtoneSidecarWriter.swift` | `writeSidecar(for: any FilmtoneSidecarRequest)` に generalize、payload に `sourceKind` 追加 (additive) |
| `State/EditorState.swift` | `imageURL` → `sourceURL` rename + `sourceKind` / `exportProgress` / `exportProgressMessage` / `currentExportTask` 追加 + `cancelExport()` |
| `UI/RootWindowView.swift` | Open accepts `.movie` / `.mpeg4Movie` / `.quickTimeMovie`、Save dispatches by `sourceKind`、`ExportProgressBar` (ProgressView + Cancel) 追加 |
| `UI/PreviewSurface.swift` | `imageURL` → `sourceURL` rename、`sourceKind` で still/video dispatch、video は `FilmtoneVideoFramePreviewLoader.loadMidpointFrame` |
| `FilmtoneDesktop.xcodeproj/project.pbxproj` | UUID A11-A16 (BuildFile) / B11-B16 (FileRef) / E0B (Media group) 追加。FilmtoneDesktop group に Media、Color group に ColorPipelineContract、Export group に SidecarTypes + VideoExporter |

iOS Xcode project / Electron desktop / film-lab-core src は **未編集**
(master handoff §6 invariants 遵守)。`git status apps/capacitor-film-lab-ios/`
/ `git status apps/desktop-film-lab-batch/` / `git status packages/film-lab-core/src/`
共に clean。

---

## 3. 採択した設計判断 (master handoff §13 推奨値ベース、全 9 件)

| # | 決定事項 | 採択 | 確認結果 |
|---|---|---|---|
| 1 | video preview path | 静止 frame 1 枚 (midpoint = 0.5 × duration) | `FilmtoneVideoFramePreviewLoader` |
| 2 | export format | H.264 mp4 default、ProRes は enum future option (実装未) | `FilmtoneVideoCodec.h264` |
| 3 | per-frame chain | AVAssetReader → CIImage → grade → `CIContext.render(to:CVPixelBuffer)` → AVAssetWriterInputPixelBufferAdaptor | `FilmtoneVideoExporter.export` |
| 4 | video reader settings | `kCVPixelFormatType_32BGRA` + `AVVideoAllowWideColorKey: true` | `videoReaderOutputSettings(pixelFormat:)` |
| 5 | video writer settings | `AVVideoCodecH264` + `AVVideoProfileLevelH264HighAutoLevel` + `AVVideoColorPropertiesKey` Rec.709 + adaptive bitrate (`max(w*h*6, 3MB)`) | `FilmtoneVideoWriter.init` |
| 6 | sidecar 拡張 | `outputFile=.mp4` + `sourceKind: "video"` additive (top-level) | `FilmtoneSidecarWriter.sidecarPayload` |
| 7 | parity ハーネス | Phase 1b still parity 再利用 (Phase 1c は wiring proof、formal video parity は Phase 2) | regression-free |
| 8 | sidecar dual emit vs canonical only | Case B 継続 (Look Unification 未 main-merged を grep で確認) | sidecar に `lookId`/`batchLookChoice` のみ、legacy `presetName` 不在 |
| 9 | 進捗 UI | SwiftUI `ProgressView(.linear)` + Cancel button、`@Observable EditorState.exportProgress` | `ExportProgressBar` in RootWindowView |

(c) iOS `FilmtoneExportSession.swift` の UIKit 依存対処 — c1 削減方針採択。
grep で `import UIKit` (line 6) と `UIDevice.current.filmtoneModelIdentifier`
/ `UIDevice.current.systemVersion` (lines 409-410) が **telemetry 用 2 箇所のみ**
と確認済。Phase 1c は telemetry を lift せず、video core flow (`makeWriter` /
`makeVideoInput` / `makeVideoReaderOutput` lines 1272-1330 と per-frame loop
lines 2428-2500) の **structure のみ** lift。`FilmtoneColorPipelineContract`
struct (lines 84-206) は UIKit-clean なので verbatim lift、factory
(`defaultOutputContract`) は `SourceColorMetadataDTO` / `SourceColorClassDTO`
依存のため Phase 2 まで skip。

(d) Case B 継続 + 片読み期間継続 — 明示的 user 了承済。chat 中に Look
Unification main merge を観測したら dual emit に切り替える方針。

---

## 4. Verify 結果 (現状)

### 4.1 Build / contract gate

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

$ git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/ packages/film-lab-core/src/
nothing to commit, working tree clean
```

### 4.2 Phase 1b regression (still、no regression)

```bash
$ FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop --export-still \
    --input apps/desktop-film-lab-batch/test/golden/source-images/01-highlight-sunset.png \
    --output test-out/reset-01.png --preset reset
ok 1280x720 ...test-out/reset-01.png

$ grep -E '"sourceKind"|"lookId"' test-out/reset-01.filmtone.json
  "lookId" : "filmtone:base:reset:v2",      # batchLookChoice (Case B)
  "lookId" : "filmtone:base:reset:v2",      # top-level (Case B)
  "sourceKind" : "still"                    # NEW Phase 1c additive

$ bun run scripts/golden-parity-macos.ts --preset reset
macOS↔source : all ∞ dB (10/10 bit-identical)
macOS↔baseB  : 0/10 ≥ 35dB; mean 13.69dB
(baseline-B fixture mismatch — informational, master handoff §5.5.5)
```

### 4.3 Phase 1c video vertical slice

```bash
$ ffprobe -v error -select_streams v:0 -show_entries stream=... \
    apps/desktop-film-lab-batch/fixtures/video/sdr/synthetic-bt709-1s-20260424.mp4
codec_name=h264 width=320 height=180 pix_fmt=yuv420p r_frame_rate=24/1 duration=1.000000

$ time FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop --export-video \
    --input synthetic-bt709-1s-20260424.mp4 \
    --output test-out/reset-video.mp4 --preset reset
ok 320x180 frames=24 /.../test-out/reset-video.mp4
real    0.366 s

$ ffprobe -v error -show_entries stream=... test-out/reset-video.mp4
codec_name=h264
width=320 height=180
pix_fmt=yuv420p
color_space=bt709         # ★Rec.709 metadata correctly written
color_transfer=bt709
color_primaries=bt709
r_frame_rate=24/1
duration=1.000000

$ cat test-out/reset-video.filmtone.json | jq '.sourceKind, .outputFile, .lookId'
"video"
"/.../test-out/reset-video.mp4"
"filmtone:base:reset:v2"
```

### 4.4 Grade active proof (iphone preset on video path)

```bash
$ FilmtoneDesktop.app/Contents/MacOS/FilmtoneDesktop --export-video \
    --input synthetic-bt709-1s-20260424.mp4 \
    --output test-out/iphone-video.mp4 --preset iphone
ok 320x180 frames=24

$ ffmpeg -i reset-video.mp4 ... reset-frame0.png
$ ffmpeg -i iphone-video.mp4 ... iphone-frame0.png
$ bun run scripts/compare-pngs.ts reset-frame0.png iphone-frame0.png
PSNR: 14.91 dB                              # ★grade chain active
max |Δ| per channel: R=89 G=72 B=90
center (160,90)  reset(2,24,255)  → iphone(71,72,250)
topright (310,10) reset(0,234,255) → iphone(87,238,253)
```

reset と iphone preset の差分が video path で正しく生まれている。`FilmtoneGradePipeline.apply`
が CIImage chain (still と同じ kernel) を video frames に対して動作している証明。

---

## 5. ★ 重要発見・残課題

### 5.1 baseline-B fixture mismatch は Phase 1c でも未解決 (Phase 1b 同様)

Phase 1c は formal video parity を **保留** (master handoff §13 #7、§9)。
`scripts/golden-parity-macos.ts` は still のみ対応。video parity は Phase 2
で **(1) 案 C: iOS↔macOS canonical 直接比較で正本確定 → (2) baseline-C を
canonical pipeline で再生成 → (3) 必要時のみ WGSL→Metal port (不足 effect path
が特定された場合のみ)** の優先順で再構築。Native Desktop の真値を旧 Desktop
WebGL/WGSL 由来 fixture に引かれない方針 (Native 移行の意図と整合、
06 risk row 参照)。

### 5.2 deprecation warnings (CIColorKernel(source:) と AVFoundation sync API)

Phase 1c で新たに発生した deprecation warning (build success には影響なし):

| API | source | 替案 (Phase 2) |
|---|---|---|
| `asset.tracks(withMediaType:)` | `FilmtoneVideoFramePreview.swift:27`、`FilmtoneVideoReader.swift:39` | `try await asset.loadTracks(withMediaType:)` |
| `asset.duration` | `FilmtoneVideoFramePreview.swift:31`、`FilmtoneVideoReader.swift:67` | `try await asset.load(.duration)` |
| `track.naturalSize` | `FilmtoneVideoReader.swift:68` | `try await track.load(.naturalSize)` |
| `track.preferredTransform` | `FilmtoneVideoReader.swift:69` | `try await track.load(.preferredTransform)` |
| `track.nominalFrameRate` | `FilmtoneVideoReader.swift:70` | `try await track.load(.nominalFrameRate)` |
| `AVAssetImageGenerator.copyCGImage(at:actualTime:)` | `FilmtoneVideoFramePreview.swift:80` | macOS 15+ `generator.image(at:)` async |

Phase 2 で AVFoundation modern async API へ migrate。Phase 1c は wiring proof
として deprecation 受容 (Phase 1b の `CIColorKernel(source:)` deprecation
受容と整合、master §6.3)。

### 5.3 `@unchecked Sendable` for FilmtoneVideoReader / FilmtoneVideoWriter

AVAssetReader / AVAssetWriter / AVAssetWriterInputPixelBufferAdaptor は
Sendable でないが、`FilmtoneVideoReader` / `FilmtoneVideoWriter` は exporter
の単一 Task 内のみで使用される。`@unchecked Sendable` で vouch。Phase 2 で
actor 隔離 / IOSurface-backed Metal compute へ refactor 時に再評価。

### 5.4 Performance baseline (synthetic 1 sec mp4)

| metric | 値 |
|---|---|
| source | 320x180 @ 24 fps × 1.0 sec (24 frames) |
| total wallclock | 0.366 sec |
| frames/sec | ~65 fps |

これは proof-of-concept ベンチ。実 4K/6K clip では:
- per-frame CIImage allocation overhead が増える
- `CVPixelBufferPoolCreatePixelBuffer` が main bottleneck になり得る
- `CIContext.render(to:CVPixelBuffer)` は Metal-backed なので scale するが、
  IOSurface-backed flow なしには上限あり

Phase 2 で 4K/6K clip のベンチ + IOSurface-backed CVPixelBuffer + Metal compute
の検討 (master handoff §12 risk row 3、master plan 02-architecture
"Performance Render Spine")。

### 5.5 GUI 動作確認 (CLI smoke 経由のみ)

CLI `--export-video` で full pipeline (read → grade → write → sidecar) を
verify 済。GUI 部分 (Open panel video accept / Save panel `.mp4` filter /
ProgressView 表示 / Cancel button 動作) は **user の手動 visual smoke** で
最終確認推奨。launch 手順:

```bash
open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
# 1. ⌘O で synthetic-bt709-1s-20260424.mp4 を open
#    → midpoint frame (0.5 sec 地点) が grade 適用された状態で preview に出る
# 2. preset を "iphone" に切替 → preview 即座更新
# 3. ⌘E で Save panel が `.mp4` filter で開く
#    → output path 指定して保存
# 4. 進捗 ProgressView と "Rendering frame N/24" が表示される
# 5. Cancel ボタンで mid-export 中断
# 6. 完了時: "Exported 320×180, 24 frames → output.mp4" lastExportSummary
```

---

## 6. 次 chat (Phase 2 or 1d) の起点

### 6.1 commit 戦略

#### Pre-commit gate (実行順)

GUI smoke を最優先で実行。問題があれば Phase 1b/1c bundle 内で修正してから
commit する (新 commit を分けない、memory `feedback_dont_overengineer_dirty_state_split`):

1. **GUI manual smoke** (user 実行) — CLI で full pipeline は verify 済、
   GUI 部分 (Open panel video accept / Save panel `.mp4` filter / ProgressView /
   Cancel button / midpoint preview) のみ視覚確認:
   ```bash
   open apps/filmtone-desktop-macos/build/Build/Products/Debug/FilmtoneDesktop.app
   # ⌘O → synthetic-bt709-1s-20260424.mp4 → midpoint preview
   # preset 切替 → preview 即更新
   # ⌘E → .mp4 Save panel → ProgressView + Cancel 確認
   ```
2. **問題があれば修正** → Phase 1b/1c bundle 内に取り込む。新 commit を分けない。
3. **`git diff --check`** で whitespace 不整合確認。
4. **`bun run verify:macos`** 再実行 (期待: `** BUILD SUCCEEDED **`)。
5. (時間が許せば) **`bun run verify:ios`** で iOS lane 無傷再確認
   (期待: D-Log / D-Log M / C-Log / C-Log 3 / V-Log / S-Log3 ΔE2000 全 0.000、
   sidecar pass)。
6. **user commit** (gpg/hooks 通常運用通り、`feedback_dont_overengineer_dirty_state_split`
   に従い 1 commit bundle 推奨、Phase 1b/1c 分離は user 判断)。
7. **Phase 2 着手** (C1 SourceColor DTO port → C2 AVFoundation modern async →
   C3 案 C parity 再構築 …)。

#### Bundle vs split

Phase 0+1a (commit `398743c`) の上に Phase 1b + Phase 1c を **1 commit に
bundle** が memory `feedback_dont_overengineer_dirty_state_split` に従い
推奨。または Phase 1b と 1c を分離 (user 判断)。

提案 commit message (1c 単独):

```
feat(macos): Phase 1c vertical slice (open .mov → midpoint preview → H.264 mp4 export)

- Color/FilmtoneColorPipelineContract: lift iOS contract struct (Rec.709
  AVVideo metadata, CVBuffer attachments, sourceImageOptions). Factory
  enum skipped pending Phase 2 SourceColor DTO port.
- Media/ stack: VideoFramePreview (AVAssetImageGenerator midpoint frame),
  VideoReader (AVAssetReader 32BGRA), VideoWriter (AVAssetWriter
  H.264 + AVVideoProfileLevelH264HighAutoLevel + AVVideoColorPropertiesKey
  Rec.709). @unchecked Sendable for single-Task usage.
- Export/FilmtoneSidecarTypes: FilmtoneSourceKind enum + FilmtoneSidecarRequest
  protocol. StillExportRequest conforms with .still, VideoExportRequest with
  .video. SidecarWriter generalised over the protocol; payload adds
  top-level "sourceKind" additive field.
- Export/FilmtoneVideoExporter: async orchestrator. Per-frame CIImage chain
  through FilmtoneGradePipeline → CIContext.render(to:CVPixelBuffer, colorSpace:
  Rec.709) → AVAssetWriterInputPixelBufferAdaptor.append. Track.preferredTransform
  applied + origin-normalised + scaled to display size. Task.checkCancellation
  between frames.
- State/EditorState: imageURL → sourceURL rename + sourceKind, exportProgress,
  exportProgressMessage, currentExportTask + cancelExport().
- UI: RootWindowView Open accepts video UTType; Save panel branches by
  sourceKind; ExportProgressBar (ProgressView + Cancel) added. PreviewSurface
  midpoint-frame load for video.
- App: FilmtoneDesktopCLI --export-video mode (DispatchSemaphore async→sync
  bridge). Existing --export-still preserved.
- pbxproj: UUID A11-A16 / B11-B16 / E0B (Media group) added; FilmtoneDesktop /
  Color / Export groups updated.

Result: synthetic-bt709-1s-20260424.mp4 → 24-frame 320x180 .mp4 in 0.366s,
Rec.709 SDR metadata correctly written. iphone vs reset PSNR 14.91dB confirms
grade kernel chain active in video path. Phase 1b still regression-free
(macOS↔source ∞dB; baseline-B 13.69dB informational, master §5.5.5).
```

### 6.2 Phase 2 候補スコープ (master handoff §3 phase plan)

a. **SourceColorMetadataDTO / SourceColorClassDTO の port** — Phase 1c で skip
   した `FilmtoneColorPipeline.defaultOutputContract` factory を再活性化、source
   profile catalog の port と合わせる。

b. **AVFoundation modern async API への migration** — §5.2 の deprecation 解消。

c. **案 C (iOS↔macOS canonical 直接比較) → baseline-C 再生成 → 必要時のみ
   WGSL→Metal port** — §5.1 baseline-B fixture mismatch を解いて formal
   video parity gate を立てる。優先順は Native の真値を旧 Desktop WebGL 由来
   fixture に引かれない方針 (Native 移行の意図と整合、06 risk row 参照)。

d. **IOSurface-backed CVPixelBuffer + Metal compute** — §5.4 4K/6K perf
   bench → 必要なら implement。

e. **SPM `packages/film-lab-swift-core/`** — Domain/Phase0Types.swift /
   FilmtoneColorPipelineContract / グレード kernel sources を SPM 化、iOS
   からも参照、`Domain/Phase0Types.swift` 削除 → import 切替。

f. **OpticalFilters main 着地後の合流** — 現 main の untracked
   `packages/film-lab-core/src/ios-optical-filter-payload.ts` 等が landing
   したら generator に追加、bloom/halation/diffusion/vignette/grain を
   Native Desktop の grade chain に統合。

g. **Look Unification main merge 観測時の dual emit 切替** — chat B が
   merge 完了したら sidecar emitter を Case A (legacy + Look canonical 両方)
   に切替。

### 6.3 Open carryover (Phase 1c で未着手だが触れた周辺)

- **video parity formal harness** — Phase 1b still parity の延長として、video
  frames の per-frame PSNR を測る harness。Phase 2 で構築。
- **ProRes export option** — `FilmtoneVideoCodec.proRes422` enum case を未実装。
  Phase 2 で `AVVideoCodecType.proRes422` + alpha 系 codec の実装。
- **scrubber / playback preview** — Phase 1c は midpoint frame 1 枚のみ。
  Phase 3 (Native Editing UI) で AVPlayer / scrubber 実装。
- **video preview debounce** — preset 切替時の midpoint frame 再生成は最大数百ms
  かかり得る。Phase 3 で debounce 検討。

---

## 7. Critical Invariants 再確認 (本 commit で守ったもの)

- ✅ iOS Xcode project (`apps/capacitor-film-lab-ios/`) 編集なし
- ✅ Electron desktop (`apps/desktop-film-lab-batch/`) 編集なし — fixture (`fixtures/video/sdr/synthetic-bt709-1s-...mp4`) は read-only 参照のみ
- ✅ `packages/film-lab-renderer/dist/` / `packages/film-lab-smart-look/dist/` track 維持
- ✅ `packages/film-lab-core/src/` contract source 編集なし
- ✅ 生成 Swift (`FilmtonePhase0Generated.swift`) 手編集なし、generator drift 0
- ✅ iOS と macOS の `Phase0Generated.swift` bit-identical (`diff -q` exit 0)
- ✅ `Domain/Phase0Types.swift` field 順序 / 名前 不変 (Phase 1a 時点と同一)
- ✅ bun のみ使用、npm 未使用
- ✅ git は user 実行 (auto commit なし)
- ✅ 用語: UI に "Look" を hardcode、`動画` / `video` 表記
- ✅ Responsibility Boundaries (master §6 #9): UI は views + AppKit wrap のみ /
  State は flow orchestration / Color は CIKernel/CIContext/contract / Export
  は encoding+sidecar / Media は probing+reader+writer / Domain は型のみ
- ✅ Sidecar schema: additive (`sourceKind`)、version bump なし

---

## 8. 関連 doc

- `filmtone-native-desktop-phase1c-master-handoff-2026-05-03-jst.md` — Phase 1c 開始時 self-contained master (predecessor)
- `filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md` — Phase 1b 完了 handoff
- `native-desktop-transition-plan-2026-05-03-jst/04-phase-plan.md` — Phase 0-5 全体 acceptance gate 正本
- `filmtone-desktop-look-unification-handoff-2026-05-03-jst.md` (main checkout 側) — Look Unification、Phase A `1f99d68` + Phase B `fd9ddd2` が branch にあるが main 未 merge → Case B 継続根拠

---

## 9. このドキュメントについて

- role: Phase 1c → Phase 2 (or 1d) onboarding canonical
- 作成: Phase 1c 実装 chat (同一日中に Phase 0+1a の commit `398743c` に続けて
  Phase 1b + 1c を実装)
- 次回 master handoff (Phase 2) はここを起点に作る
- naming: `filmtone-native-desktop-phaseN-completion-handoff-{date}-jst.md` パターン
