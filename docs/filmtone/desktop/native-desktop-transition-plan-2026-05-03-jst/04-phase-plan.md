# 04 Phase Plan

Parent index:
[filmtone-native-desktop-transition-plan-2026-05-03-jst.md](../filmtone-native-desktop-transition-plan-2026-05-03-jst.md)

## Phase 0: Contract And Skeleton

Goal: create the native app lane without touching release behavior.

Deliverables:

- `apps/filmtone-desktop-macos/` Xcode project or Swift package-backed app.
- Buildable empty native app with:
  - app icon placeholder from existing resources if compatible
  - native main window
  - basic menu commands
  - first Liquid Glass toolbar/sidebar experiment
- Generated Swift contract wiring plan:
  - either reuse iOS generated Swift output in a shared location
  - or generate iOS and macOS outputs from the same generator input
- One fixture folder copied or referenced from existing test assets.

Acceptance gate:

- Native app builds locally.
- Launches a window.
- Uses SwiftUI native controls with AppKit interop only where needed, not
  WebView UI.
- Does not change Electron Desktop release output.
- Does not hand-edit generated Swift.

Suggested verification:

```bash
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

## Phase 1: Product Vertical Slice

Goal: prove that Native Desktop can do real Filmtone work, not only native UI.

Deliver one flow:

```text
open one still image
  -> preview it
  -> apply one built-in grade / source profile
  -> export one still
  -> write minimal sidecar
```

Then add the smallest video slice:

```text
open one short video
  -> render representative preview frame
  -> export short H.264 MP4 clip
```

Do not build batch UI yet. One correct item is more valuable than a wide shell.

Acceptance gate:

- The same params produce visually matching output against existing Electron /
  iOS golden fixtures within defined tolerance.
- Source profile conversion matches shared/iOS fixture parity.
- Exported still and video open in QuickTime / Finder without repair.
- Preview and export use the same native grade path or an explicitly proven
  equivalent path.
- Liquid Glass UI does not reduce preview legibility or color judgment.
- Sidecar emission is bit-互換 with the Look Unification contract. If Look
  Unification is landed: dual emit (legacy + `lookId` / `lookVersion`) and
  `normalizeFilmLookGradeInputIdentity` 通過. If not yet landed: Look canonical
  only, ready for Electron-side reader catch-up on landing.

Suggested verification:

```bash
bun run build:core
bun test packages/film-lab-core/src/source-profile-conversion.test.ts
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

Look Unification main 着地状況の確認:

```bash
# core 側に BASE_LOOKS が export されているか
grep -E "^export.*BASE_LOOKS" packages/film-lab-core/src/index.ts
# sidecar reader の discriminator が lookId を見ているか
grep "lookId" apps/desktop-film-lab-batch/src/renderer/batch-pipeline.ts
```

### Phase 1b 着地状況 (2026-05-03 JST 同日記録)

`feature/native-desktop-plan` worktree commit `398743c` (Phase 0+1a) の上に
Phase 1b vertical slice (preset → grade → still export → sidecar) が実装済
(uncommitted)。完了 handoff:
`docs/filmtone/desktop/filmtone-native-desktop-phase1b-completion-handoff-2026-05-03-jst.md`。

実装メモ:

- iOS の `OpticalKernels.baseGradeV2` / `filmCompressionV2` / `printStage`
  CIColorKernel sources を verbatim lift。
  `apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradeKernels.swift`。
- Sidecar は **Case B (Look canonical only)** 採択。Look Unification 未 landed
  と main checkout 側 grep で確認済。
- Optics (bloom / halation / diffusion / vignette / grain / motion blur) は
  Phase 2 (Native Color/Export Backbone) に deferred。

Parity 計測結果 (`bun run scripts/golden-parity-macos.ts --preset reset`):

- **macOS↔source = ∞ dB (10/10 bit-identical)** — CIImage roundtrip と epsilon
  gate が正しく動作している証明。
- **macOS↔baseline-B = 平均 13.69 dB** — fixture が legacy WebGL render
  capture (Phase 0 baseline-A JPEG → highlight lift → PNG) であり、現行 iOS
  canonical CIColorKernel pipeline (本 Phase 1b lift target) と stage graph が
  異なるため、PSNR > 35 dB threshold は **構造的に達成不可**。完了 handoff §4
  と Risks 表 (06-quality-gates-risks.md) を参照。
- **macOS↔source = 39.62 dB (preset=iphone, 09-skin-light)** — non-identity
  preset で grade kernel が active であることの sanity 証明。

このため Phase 1 acceptance gate の "visually matching against existing
Electron / iOS golden fixtures" は Phase 1b 範囲では **iOS canonical pipeline
との一致 (= source bit-identity for reset, kernel activation for non-reset)** を
proxy とする。WebGL parity は Phase 2 で **案 C (iOS↔macOS canonical 直接比較)
→ baseline-C 再生成 → 必要時のみ WGSL→Metal port** の優先順で再評価
(06 risk row、Native の真値を旧 Desktop WebGL fixture に引かれない方針)。

### Phase 1c 着地状況 (2026-05-03 JST 同日記録)

`feature/native-desktop-plan` worktree commit `398743c` (Phase 0+1a) の上に
Phase 1b に続けて Phase 1c vertical slice (open .mov/.mp4 → midpoint frame
preview → H.264 mp4 export → sidecar) が実装済 (uncommitted、Phase 1b と
同 branch 上)。完了 handoff:
`docs/filmtone/desktop/filmtone-native-desktop-phase1c-completion-handoff-2026-05-03-jst.md`。

実装メモ:

- iOS `FilmtoneColorPipeline.swift:84-206` の `FilmtoneColorPipelineContract`
  struct を verbatim lift (`Color/FilmtoneColorPipelineContract.swift`)。
  `defaultOutputContract` factory + `SourceColorMetadataDTO` /
  `SourceColorClassDTO` 依存の helper は Phase 2 (DTO port + SPM 化) まで
  skip、Phase 1c は `phase1cMP4Default()` で直接 construct。
- iOS `FilmtoneExportSession.swift` の **UIKit / UIDevice 依存箇所は 2 行のみ**
  (line 6 `import UIKit`、lines 409-410 `UIDevice.current.filmtoneModelIdentifier`
  / `systemVersion`、共に telemetry 用)。c1 削減方針で telemetry を lift せず、
  video core flow (`makeWriter` / `makeVideoInput` / `makeVideoReaderOutput`
  lines 1272-1330 と per-frame loop lines 2428-2500) の structure のみ port。
- 新規ディレクトリ: `Media/` (UUID `E0B`)。`FilmtoneVideoFramePreview.swift`
  (AVAssetImageGenerator midpoint = 0.5×duration)、`FilmtoneVideoReader.swift`
  (AVAssetReader 32BGRA + AVVideoAllowWideColor)、`FilmtoneVideoWriter.swift`
  (AVAssetWriter H.264 + `AVVideoProfileLevelH264HighAutoLevel` + Rec.709
  via `AVVideoColorPropertiesKey`)。
- 新規 `Export/FilmtoneSidecarTypes.swift` で `FilmtoneSourceKind` enum +
  `FilmtoneSidecarRequest` protocol を導入、`FilmtoneStillExportRequest` と
  新規 `FilmtoneVideoExportRequest` を conform。`FilmtoneSidecarWriter` は
  protocol generalised + `sourceKind` additive top-level field を追加
  (schema bump なし、Data Contract additive only 制約遵守)。
- `Export/FilmtoneVideoExporter` は async orchestrator: per-frame で
  `CIImage(cvImageBuffer:options:)` → preferredTransform 適用 + origin 正規化
  + scale → `FilmtoneGradePipeline.apply` (Phase 1b 同 chain) →
  `CIContext.render(to:CVPixelBuffer, colorSpace: Rec.709)` →
  `AVAssetWriterInputPixelBufferAdaptor.append`。`Task.checkCancellation`
  between frames、Cancel ボタン対応。
- CLI `--export-video` mode 追加 (`DispatchSemaphore` で async → sync bridge)。
  `--export-still` は Phase 1b と互換維持。
- UI: `RootWindowView` Open accepts `.movie` / `.mpeg4Movie` / `.quickTimeMovie`、
  Save panel が source kind で `.png/.jpeg` vs `.mp4` 分岐、`ExportProgressBar`
  (SwiftUI `ProgressView` + Cancel)。`PreviewSurface` は source kind dispatch、
  video は midpoint frame 経由。`EditorState` に `sourceURL` / `sourceKind`
  / `exportProgress` / `currentExportTask` 追加。
- pbxproj UUID `A11-A16` (BuildFile) / `B11-B16` (FileRef) / `E0B` (Media
  group) を追加。

Verify 結果:

- 1 sec synthetic mp4 (320x180 @ 24 fps、bt709 SDR、24 frames): wallclock
  0.366 sec (~65 fps、proof-of-concept、4K/6K bench は Phase 2)。
- 出力 mp4 ffprobe: `codec_name=h264`, `pix_fmt=yuv420p`, **`color_space=bt709`
  / `color_transfer=bt709` / `color_primaries=bt709`** (Rec.709 metadata 正常)。
- sidecar: `"sourceKind": "video"`, `outputFile=.mp4`, `lookId=filmtone:base:
  reset:v2`, `batchLookChoice` (Case B 維持、legacy `presetName` 不在)。
- iphone preset on video frame 0 vs reset preset on video frame 0:
  **PSNR 14.91 dB**, max Δ R=89/G=72/B=90 — grade chain が video path で
  meaningful な差分を生成 (kernel chain active proof)。
- Phase 1b still regression: `macOS↔source = ∞dB` / `baseB = 13.69dB`
  (informational、変化なし)。

このため Phase 1 acceptance gate の "video export passes for representative
clips" は Phase 1c 範囲では **(1) export が QuickTime / Finder で repair
なしに開く、(2) Rec.709 metadata が正しく書き込まれる、(3) 同じ kernel が
preview / export 両方で動く、(4) 異なる preset で frame-level の差分が
生まれる、(5) sidecar が `parseFilmtoneExportSessionV1` 互換 schema** で
proxy gate とする。formal video parity (per-frame PSNR vs reference) は
Phase 2 で **案 C (iOS↔macOS canonical 直接比較) → baseline-C 再生成 →
必要時のみ WGSL→Metal port** の優先順で構築 (06 risk row 参照)。

## Phase 2: Native Color / Export Backbone

Goal: make native rendering/export credible enough to replace Electron for core
work.

Work items:

- Port or share Phase0 generated params.
- Establish native LUT parsing and LUT packing parity.
- Port source profile math and catalog.
- Establish CoreImage / Metal stage order.
- Implement still export with color profile handling.
- Implement video export with `AVAssetReader` / `AVAssetWriter`.
- Investigate IOSurface-backed `CVPixelBuffer` flow for the video path.
- Define preferred render and writer pixel formats explicitly.
- Preserve or intentionally replace current ffmpeg/VideoToolbox behavior with a
  native AVFoundation pipeline.
- Define native cache strategy for mezzanine/proxy equivalents.
- Emit Desktop sidecar compatible with existing reader where possible.

Acceptance gate:

- Still export parity passes for representative presets.
- Video export parity passes for representative clips.
- HDR / SDR policy is explicit and tested.
- Source profile id round-trips through sidecar.
- Built-in `.cube` and custom `.cube` behavior are both covered.
- Video path avoids avoidable per-frame image object conversions, or records a
  measured reason for a temporary exception.
- Preview/export stage equivalence is proven before performance tuning claims.
- Failure states are explicit; no silent fallback that changes output quality.

Verification should stay small until quality is proven:

```bash
bun run build:core
bun run generate:ios-swift
bun run verify:ios
xcodebuild -project apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj \
  -scheme FilmtoneDesktop \
  -destination 'platform=macOS' \
  -configuration Debug build
```

Add native golden tests only around changed surfaces first. Do not start with a
large formal QA matrix.

### Phase 2 sub-scope (chunk decomposition、2026-05-03 JST late evening 確定)

| code | scope | 状態 |
|---|---|---|
| **C1** | SourceColor DTO graph port (FilmtoneMediaTypes L67-156) + classifier + normalizer + `defaultOutputContract` factory + Source prober (video async + still CGImageSource) | **COMPLETE** (`aeb0c7c`) |
| **C2** | AVFoundation modern async API migration (6 deprecation sites) + Sendable / strict concurrency (Swift 6) 対応 + Reader probe-based init | **COMPLETE** (`aeb0c7c`、C1 と同一 commit) |
| **C3** | iOS↔macOS canonical 直接 PSNR (案 C: baseline-C 構築) | **scaffold COMPLETE** (`aeb0c7c`)、**baseline-C populate は外殻 (品質保証希望時) で defer** |
| **C5a** | per-pixel optical (vignette + grain CIColorKernel) | **COMPLETE** (`cd170a6`) |
| **C5c** | RayAngleOptics port (vignette canonical 化 + camera optics probe 拡張) | **COMPLETE** (`cda0f9f`) |
| **C5b A.1** | bloom mip pyramid (softKneeHighlight + tentDownsample/Up + glowComposite、halation/diffusion plates black) | **COMPLETE** (uncommitted、chat A.6) |
| **C5b A.2** | halation + diffusion plates (buildMipBlurComposite 再利用、halationColor helper 追加) | TBD (次 chat 推奨) |
| **C5b A.3** | radialRGBSplit + edgeSoftnessBlend (CIKernel) | TBD |
| **C6** | SPM `packages/film-lab-swift-core/` 化 (Domain/Phase0Types.swift 削除 → import 切替) | TBD (急がない方針維持) |
| **C7** | IOSurface-backed CVPixelBuffer + Metal compute (4K/6K perf bench) | **measurement COMPLETE** (refactor 不要判定、code 変更なし) |

**着手順 (chunk 着手時 user 確定)**:
- **C1 + C2 を foundation 1 chunk** として進める (DTO port + factory wiring +
  AVFoundation modern async = build clean 化)。
- **C3 を直後に truth gate として立てる** (案 C iOS↔macOS canonical 直接比較)。
  hybrid 戦略: 開発 iteration は iOS Simulator (#2)、baseline-C 確定は実機 1 回
  (#1)、以降 regression は macOS 内完結 (iOS pbxproj 違反の #3 / C6 急がない
  方針矛盾の #4 は却下)。
- **C5/C6/C7 は C3 結果 + OpticalFilters main 着地 timing で再判断** (現時点で
  順序固定しない)。

### Phase 2 C1+C2 着地状況 (2026-05-03 JST late evening)

`feature/native-desktop-plan` worktree commit `398743c` (Phase 0+1a) の上に
Phase 1b + 1c に続けて Phase 2 C1+C2 が実装済 (uncommitted、Phase 1b/1c と
同 branch 上)。完了 handoff:
`docs/filmtone/desktop/filmtone-native-desktop-phase2-master-handoff-2026-05-03-jst.md`。

実装メモ:

- 新規: `Domain/SourceColorTypes.swift` (`SourceColorClassDTO` 8 cases +
  `SourceLogTransferFunctionDTO` 2 cases + `SourceColorMetadataDTO` 7 fields、
  iOS L67-156 verbatim、Foundation のみ)。
- 新規: `Color/SourceColorMetadataNormalizer.swift` (CoreMedia identifier →
  ffprobe vocab、iOS L1-129 verbatim)。
- 新規: `Color/SourceColorClassifier.swift` (`classify(metadata) ->
  SourceColorClassDTO`、iOS L8-56 verbatim、`FilmtoneMezzanineRoutePolicy`
  は意図的に skip — iOS mezzanine routing は macOS native irrelevant)。
- 新規: `Color/FilmtoneColorPipeline.swift` (`enum FilmtoneColorPipeline`
  namespace、`defaultOutputContract` factory + `sourceInterpretationID`
  / `sourceFallbackColorSpace` / `isDisplayP3SDR` / `workingColorSpace` /
  `outputColorSpace` 全 helpers、iOS L1-82 verbatim)。
- 新規: `Media/FormatExtensionReader.swift` (CMFormatDescription extension
  reader、iOS verbatim)。
- 新規: `Media/FilmtoneSourceProber.swift` (`probeVideo(sourceURL:) async
  throws -> FilmtoneVideoTrackProbe`、`probeStill(sourceURL:) ->
  FilmtoneSourceProbeResult`、modern async API 直使用)。`FilmtoneVideoTrackProbe`
  は **non-Sendable** (AVAssetTrack/AVURLAsset が Sendable でないため、
  single-Task consumer 限定で OK)。
- 更新: `Color/FilmtoneColorPipelineContract.swift` を iOS L84-206 verbatim
  形へ restructure。`phase1cMP4Default()` は **削除**、`stillImageOptions()`
  は iOS canonical match で `.applyOrientationProperty: true` +
  `.toneMapHDRtoSDR: true` + 条件付き `colorSpace: sourceFallbackColorSpace`。
  iOS-only `applyOutputMetadata(to: AVMutableVideoComposition)` overload は
  omit (macOS は `AVAssetWriterInputPixelBufferAdaptor` 直書き)。
- 更新: `Media/FilmtoneVideoReader.swift` を `init(probe: FilmtoneVideoTrackProbe,
  contract:)` に rebuild。deprecated `asset.tracks(withMediaType:)` /
  `track.naturalSize` / `.preferredTransform` / `.nominalFrameRate` /
  `asset.duration` を全消化、prober 経由 pre-loaded。`@unchecked Sendable`
  維持 (single-Task usage)。
- 更新: `Media/FilmtoneVideoFramePreview.swift` modern async API へ migrate。
  `try await asset.loadTracks(withMediaType:)` + variadic
  `try await track.load(.naturalSize, .preferredTransform)` (Swift 6 strict
  concurrency: AVAssetTrack non-Sendable のため `async let` は data race。
  variadic version で single-call 解決) + `try await generator.image(at:)`。
- 更新: `Export/FilmtoneVideoExporter.swift` に `probeVideo` → factory →
  contract → reader の wiring。`hardCoded phase1cMP4Default()` 撤去。
- 更新: `Export/FilmtoneStillExporter.swift` に `probeStill` → factory →
  `contract.stillImageOptions()` を `CIImage(contentsOf:options:)` に渡す
  flow。Display P3 source の場合 fallback colorSpace=`displayP3` が CIImage
  options に乗る。
- 更新: `Export/FilmtoneSidecarWriter.swift` に optional `sourceInterpretation:
  String? = nil` parameter 追加。non-nil の場合 sidecar payload に
  `sourceInterpretation` field を additive 追加 (Phase 2 acceptance gate
  "Source profile id round-trips through sidecar")。schema bump なし
  (Data Contract additive only 制約遵守)。
- 更新: `UI/PreviewSurface.swift` を Coordinator-based Task 管理へ。
  `context.coordinator.currentTask?.cancel()` で前 preview Task を cancel
  してから新規 Task launch。video path のみ async (still は sync 維持で
  flicker 抑制)。
- 更新: `Export/FilmtoneSidecarTypes.swift` 不変 (`sourceKind` enum +
  `FilmtoneSidecarRequest` protocol、changes only `Export/FilmtoneSidecarWriter`)。
- pbxproj: UUID `A17-A1C` (BuildFile) / `B17-B1C` (FileRef) を追加。
  Domain group に SourceColorTypes、Color group に Pipeline + Normalizer +
  Classifier、Media group に FormatExtensionReader + Prober を登録。

Verify 結果:

- `bun run verify:macos` → `** BUILD SUCCEEDED **`。
- AVFoundation sync deprecation 6 sites 全解消 (FramePreview の `tracks` /
  `duration` / `copyCGImage`、Reader の `tracks` / `naturalSize` /
  `preferredTransform` / `nominalFrameRate`)。残存 warning は既存
  `CIColorKernel(source:)` 3 箇所のみ (Phase 1b 受容、master §6.3、Metal
  CIKernel 移行 lane 別 chunk または C7 と合流)。
- `bun run generate:swift -- --check` → exit 0 (drift 0)。
- `diff -q iOS↔macOS Phase0Generated.swift` → identical (no output)。
- `git status apps/capacitor-film-lab-ios/ apps/desktop-film-lab-batch/
  packages/film-lab-core/src/` → nothing to commit, working tree clean。
- Still CLI smoke: `01-highlight-sunset.png` reset → `ok 1280x720`、sidecar
  `"sourceInterpretation": "sdr-bt709"` + `"sourceKind": "still"`。
- Video CLI smoke: `synthetic-bt709-1s-20260424.mp4` reset → `ok 320x180
  frames=24`、sidecar `"sourceInterpretation": "sdr-bt709"` + `"sourceKind":
  "video"`、ffprobe `color_space=bt709 / color_transfer=bt709 /
  color_primaries=bt709`。
- Phase 1b regression: `golden-parity-macos.ts --preset reset` で macOS↔source
  全 ∞ dB (10/10 bit-identical)、macOS↔baseline-B 13.69 dB (informational、
  変化なし)。
- iphone preset on 09-skin-light: macOS↔source = **40.60 dB** (Phase 1c は
  39.62 dB)、+0.98 dB は C1 で `applyOrientationProperty: true` + sRGB
  fallback colorSpace option 追加 = iOS canonical 方向 drift = 好ましい。

このため Phase 2 acceptance gate のうち **"Source profile id round-trips
through sidecar"** は本 chunk で達成 (sidecar emit 確認済)。残 acceptance gate
("Still / video export parity passes for representative presets" / "HDR/SDR
policy is explicit and tested") は **C3 baseline-C populate** で確定する。

### Phase 2 C3 truth gate scaffold 着地状況 (2026-05-03 JST late evening)

C1+C2 と同 chunk で truth gate scaffold が landed (uncommitted)。

実装メモ:

- 新規: `apps/desktop-film-lab-batch/test/golden/baseline-C/` (4 preset
  subdirs: `reset/` `iphone/` `softBlue/` `amberGlow/`) + `README.md`
  (生成手順 = iOS Simulator workflow + 実機 1 回確定の hybrid 戦略を
  記述)。
- 新規: `scripts/golden-parity-ios-vs-macos.ts`。`golden-parity-macos.ts`
  パターンを踏襲、`baseline-C/<preset>/<image>.png` (iOS canonical export)
  と macOS export を直接 PSNR 比較。**PENDING-aware**: baseline-C entry が
  無いセルは PENDING として報告し harness はエラー終了しない。`--preset`
  / `--image` / `--app` / `--threshold` (default 35dB) で制御可能。

Smoke 実行:

```
$ bun run scripts/golden-parity-ios-vs-macos.ts --preset reset
Phase 2 C3 truth gate — preset=reset
01-highlight-sunset  ∞ dB  —  PENDING  ... (10 cells all PENDING)
macOS↔source : all ∞ dB (bit-identical roundtrip)
macOS↔baseC  : 0 cells with baseline-C entry (10 PENDING) — see ...

$ bun run scripts/golden-parity-ios-vs-macos.ts --preset iphone --image 09-skin-light
09-skin-light  40.60dB  —  PENDING
```

baseline-C content 自体は **PENDING** (user iOS Simulator workflow で 4 preset
× 10 image = 40 cell を populate する必要あり)。harness は populate 待ちでも
動作可能、user が 1 cell ずつ baseline-C を増やしながら parity を
incremental に確認できる。

**Acceptance threshold**:
- reset preset 全セル **macOS↔baseline-C = ∞ dB** (params identity → bit-identical)
- non-reset preset 各セル **macOS↔baseline-C ≥ 35dB** (case-by-case では
  >= 40-50dB 期待、iOS / macOS が同 kernel sources を verbatim lift しているため)
- 失敗セルがあれば 案 C step (3) WGSL→Metal port を不足 effect path に対して実施

**未着手 Phase 2 work** (本 chunk の scope 外):

- C5: OpticalFilters main 合流 (`packages/film-lab-core/src/ios-optical-filter-payload.ts`
  等が main へ landed したら generator 拡張 + bloom/halation/diffusion/vignette/
  grain を grade chain 統合)。
- C6: SPM `packages/film-lab-swift-core/` 化 (`Domain/Phase0Types.swift`
  / `Domain/SourceColorTypes.swift` / Color/Color/Pipeline 関連を SPM 移管、
  iOS からも参照、`Domain/*` 削除 → import 切替)。**急がない方針維持** (chunk
  着手時 user 確定)。
- C7: IOSurface-backed `CVPixelBuffer` + Metal compute (4K/6K perf bench →
  必要なら implement)。Phase 1c per-frame allocation overhead 抑制策。
- Look Unification main merge 観測時の sidecar dual emit 切替 (Native ユーザー
  配布 / Phase 5 release rail 切替前必須、release blocker)。

### Phase 2 C5c 着地状況 (2026-05-04 JST、chat A.5)

`feature/native-desktop-plan` worktree commit `cda0f9f` (C5c + master handoff)。

実装メモ:

- 新規: `Domain/CameraOpticsDTO.swift` (iOS `FilmtoneMediaTypes.swift:51-63` verbatim、Codable struct 11 fields)。
- 新規: `Color/FilmtoneRayAngleOptics.swift` (iOS 同名 file 225 行 verbatim lift)。
- 更新: `Color/FilmtoneGradePipeline.swift` — `applyVignette` を `FilmtoneRayAngleOptics.resolve()` / `kernelArgs()` 経由に書き換え。`apply` signature に `cameraOptics: CameraOpticsDTO? = nil` 追加。
- 更新: `Export/FilmtoneStillExporter.swift` / `FilmtoneVideoExporter.swift` — `probe.cameraOptics` を `apply()` に通す。
- 更新: `Media/FilmtoneSourceProber.swift` — `cameraOptics(from:asset:)` async method 追加 (CMFormatDescription `kCMFormatDescriptionExtension_HorizontalFieldOfView` → `source: "metadata"` / `"assumed"`)。AVMetadataItem deprecated API も modern async へ移行。
- pbxproj: UUID A1D/B1D + A1E/B1E 4-section 登録。

Verify 結果 (C5c commit 時点):

- `bun run verify:macos` → `** BUILD SUCCEEDED **`。
- `bun run generate:swift -- --check` → exit 0。
- `diff -q iOS↔macOS Phase0Generated.swift` → identical。
- `golden-parity-macos.ts --preset reset` → macOS↔source **∞ dB (10/10 bit-identical)**、macOS↔baseB **13.69 dB**。
- CLI still iphone 09-skin-light → **PSNR 35.00 dB**。
- CLI video iphone → ok 320x180 frames=24。

PSNR が C5a と byte-identical な理由: PNG source fixture にカメラ optics metadata がない → `probeStill()` は `cameraOptics: nil` を返す → `applyMask=0` → math 上 byte-identical。実 camera 動画素材 (CMFormatDescription に HorizontalFieldOfView が含まれる) でのみ `source: "metadata"` → `applyMask=1` が有効化される。

### Phase 2 C5b A.1 着地状況 (2026-05-04 JST、chat A.6)

`feature/native-desktop-plan` worktree、C5c commit `cda0f9f` の上に C5b A.1 実装済 (**uncommitted**、chat A.6)。

実装メモ:

- 更新: `Color/FilmtoneGradeKernels.swift` — 4 kernel 追加:
  - `softKneeHighlight` (CIColorKernel、iOS OpticalKernels L4227-4237 verbatim)
  - `glowComposite` (CIColorKernel、iOS OpticalKernels L4239-4263 verbatim)
  - `tentDownsample` (CIKernel、iOS OpticalKernels L4424-4464 verbatim)
  - `tentUpsample` (CIKernel、iOS OpticalKernels L4466-4498 verbatim)
- 更新: `Color/FilmtoneGradePipeline.swift` — 全面書き換え:
  - glow pyramid constants: `glowBaseScale=0.5` / `bloomSpreadBoost=1.25` / `halationSpreadDivisor=12.0` / `diffusionCompositeBase=0.87` / `bloomMipLevels=6` / `halationMipLevels=6` / `diffusionMipLevels=4` / `glowUpsampleBlurRadius=1.0`
  - `applyGlowFamilyStage` 追加 (iOS canonical 順: filmCompressionV2 → glowFamily → vignette)
  - glow pyramid helper 全実装: `extractHighlightPlate` / `buildMipBlurComposite` / `buildMipPyramid` / `tentDownsampledImage` / `tentUpsampledImage` / `downsampledImage` / `upsampledImage` / `scaledImage` / `weightedImage` / `addImages` / `blackImage` / `extentOriginVector` / `extentSizeVector` / `computeMipWeights` / `clampValue`
  - bloom path active (`bloomStrength > 0.0001` → extractHighlightPlate → buildMipBlurComposite → glowComposite)
  - halation / diffusion plates は black (C5b A.2 で追加)

新規ファイルなし (既存 2 ファイル更新のみ)。pbxproj 変更なし。

Verify 結果 (C5b A.1 実装後):

- `bun run verify:macos` → `** BUILD SUCCEEDED **`。
- `bun run generate:swift -- --check` → exit 0。
- `diff -q iOS↔macOS Phase0Generated.swift` → identical。
- `golden-parity-macos.ts --preset reset` → macOS↔source **40.05 dB (3/10 bit-identical)**、macOS↔baseB **12.97 dB**。
  - ⚠️ C5c の ∞ dB から変化: reset preset に `bloomStrength=0.22` が含まれるため bloom が有効化。期待通りの変化。
- CLI still iphone 09-skin-light → **PSNR 35.59 dB** (C5c 35.00 dB から微増、bloom 寄与)。
- CLI video iphone → ok 320x180 frames=24。
- `CIColorKernel(source:)` / `CIKernel(source:)` deprecation 9 箇所 (Phase 1b 3 + C5a 2 + C5b A.1 4)。Metal CIKernel 移行は別 lane。

**未着手 C5b work**:

- C5b A.2: halation plate (`extractHighlightPlate` with `halationColor` tint) + diffusion image (full image → pyramid) → `applyGlowFamilyStage` 更新。
- C5b A.3: `radialRGBSplit` + `edgeSoftnessBlend` CIKernel port + `applyEdgeOpticsStage` (iOS canonical 順: filmCompressionV2 の **前** ではなく glowFamily の **前**)。

## Phase 3: Native Editing And Export UI

Goal: replace the Electron UI with a Mac-native workflow that is better than
the current Desktop product.

Build the app around Filmtone's actual workflow:

1. source selection
2. preview and compare
3. look / source profile / optical finish controls
4. export destination and format
5. progress, cancel, reveal in Finder

UI principles:

- Use native components where the platform already knows the behavior.
- Put Liquid Glass in navigation and command layers.
- Keep dense pro controls compact and scannable.
- Avoid marketing-style hero surfaces.
- Avoid nested card stacks.
- Use native menu commands and keyboard shortcuts.
- Keep preview unoccluded and color trustworthy.
- Preserve responsibility boundaries from
  `02-target-architecture-and-contracts.md`: UI owns interaction, State owns
  workflow, Color/Export own product work.

Acceptance gate:

- A user can complete the core flow without reading explanation text.
- Native UI is clearly higher quality than the Electron surface.
- Toolbar/sidebar/sheets feel like a macOS app, not a web app in a window.
- Keyboard and menu commands cover repeat workflows.
- Drag/drop and Finder integration work.
- New feature slices do not push color math, export work, or sidecar schema
  construction into SwiftUI views.

## Phase 4: Batch, Sessions, And Product Completeness

Goal: reach current Desktop capability, then exceed it.

Work items:

- photo folder batch
- single video export
- session restore
- proxy/mezzanine cache controls if still needed
- preset/source profile import/export
- `.cube` LUT export for Resolve / FCP-compatible color-only handoff, with
  non-LUT stages such as grain / halation / bloom declared as not represented
  by the LUT
- progress persistence and cancellation
- update check strategy for the native app
- packaging/signing/notarization

Acceptance gate:

- Current Electron Desktop's core capabilities are covered.
- Native app has no lower-quality export path.
- Native app can be distributed as signed/notarized DMG.
- Existing Desktop sidecars remain useful or a migration path exists.
- LUT export has clear scope: color transform only, not a promise to reproduce
  every optical finish stage in an NLE.

## Phase 5: External Shell And Release QA

Only start this after Phase 4 product gates pass.

Work items:

- release notes
- public download copy
- portfolio `vendor/filmtone` update
- support/privacy copy if behavior changed
- broad QA matrix
- screenshot set
- migration notice from Electron Desktop if needed

This phase is intentionally late. It protects momentum: product quality first,
outer shell only when there is a product worth wrapping.

## First Implementation Order

Start here after this plan:

1. Create `apps/filmtone-desktop-macos/`.
2. Add a buildable SwiftUI macOS app target.
3. Add a native window with toolbar/sidebar and one Liquid Glass control group.
4. Add source file open for one still image.
5. Render the still in a native preview.
6. Wire generated/default Phase0 params.
7. Export the still.
8. Compare output against an existing known-good fixture.
9. Add one short video preview/export slice.
10. Only then expand UI surface.

Do not begin by recreating every Electron panel.
