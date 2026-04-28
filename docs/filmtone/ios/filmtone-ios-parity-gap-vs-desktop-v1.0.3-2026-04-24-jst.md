# Filmtone iOS — Desktop v1.0.3 候補に対する未対応項目まとめ

- 日付: 2026-04-24 JST
- Desktop 基準: `desktop-v1.0.2..HEAD`（30 commits 候補 = v1.0.3、確認時点 `03389d26`）
- iOS 基準: `apps/capacitor-film-lab-ios` 現行 HEAD（v1.0 Waiting for Review 後の main 変更を含む）
- 用途: iOS v1.1 スコープ決定、v1.0 公開前の「しない」リスト確定、UI 側の透明性改善優先度判定
- 関連計画: `docs/filmtone/ios/filmtone-ios-v1.1-parity-plan-2026-04-24-jst.md`

## 0. 結論サマリ

Desktop v1.0.3 候補で増えた主な差分は「実際の画づくり」よりも、まず **metadata / policy / sidecar / optics transparency** に集中している。iOS は HDR を完全に無視しているわけではなく、Core Image の `toneMapHDRtoSDR` による暗黙の SDR 化を持つ。ただし source probe、UI、sidecar に HDR policy が出ないため、ユーザーにも Desktop にも判断材料が残らない。

| 優先度 | 領域 | iOS 状態 | v1.1 判断 |
|-------|-----|---------|----------|
| **P0** | HDR source visibility + policy notice | partial: export は暗黙 tone-map、probe/UI/policy は欠落 | 入れる |
| **P0** | Export sidecar JSON | 完全欠落 | 入れる |
| **P1** | Camera optics を renderer に反映 | intake 止まり | 入れる |
| **P1** | Camera optics の UI label 表示 | DTO にはあるが無表示 | 入れる |
| **P1** | Source video metadata（color / display / FPS trust） | partial: rotation 処理あり、metadata model は不足 | 入れる |
| **P1** | iOS contract regeneration guardrails | 手動生成・hidden defaults 不足 | 入れる |
| **P2** | Cross Filter native parity | native 実装なし | v1.2 候補 |
| **P2** | Bloom / Halation / Diffusion depth coupling | native depth coupling なし | v1.2 候補 |
| **P3** | Progressive loading Quality badge | mezzanine foundation はあるが UI 品質表示なし | 設計後 |
| **P3** | Export format / Files workflow | MP4 固定、still も 3 秒 MP4、sidecar 同梱導線なし | 要望次第 |
| — | Preset catalog 網羅性 | 同等。10 presets | ケア不要 |
| — | Default Neutral + soft finish | 同等。実装パターンは異なる | ケア不要 |
| — | Compare reveal | iOS は sheet still-frame reveal、Desktop は canvas draggable split | 差分として扱わない |

## 1. P0 — iOS v1.1 で入れるべき

### 1.1 HDR source visibility + policy notice

- **Desktop が持つもの**
  - ffprobe で `colorTransfer / colorPrimaries / mastering display / content light` を取得
  - `colorClass` を `sdr-bt709 / hdr-pq / hdr-hlg / wide-gamut-unknown / unknown` に分類
  - `hdrPreparationPolicy.strategy/reason` を導出し、sidecar に保存
  - `HdrPolicyNotice.tsx` は `reason === "ffmpeg-missing-hdr-filters"` のときだけ琥珀色 callout を出す
- **iOS の現状**
  - `SourceProbeService.swift` は寸法、尺、公称 framerate、codec、camera optics まで。color metadata は読まない
  - `FilmtoneExportSession.swift` は image / video の両方で Core Image の HDR→SDR tone-map 経路を持つ
  - ただし `SourceProbeDTO` に `colorClass` / `hdrPreparationPolicy` がなく、UI 警告も sidecar 記録もない
- **ユーザー影響**
  - iPhone HDR / HLG / PQ 素材を読み込んだとき、内部で SDR 化され得ることが見えない
  - Desktop へ持ち帰ったときに「HDR 素材だった」「iOS でどう扱った」が復元できない
- **v1.1 で必要な変更**
  - `AVAssetTrack.formatDescriptions` と `CVImageBuffer` attachment 相当から transfer / primaries / color space を読む
  - iOS 用の `SourceColorClass` と `HdrPreparationPolicy` を追加
  - UI に non-blocking notice を表示する。ffmpeg install CTA は不要
  - sidecar に source color metadata と iOS policy reason を保存する

### 1.2 Export sidecar JSON

- **Desktop が持つもの**
  - `<output>.filmtone-export-metadata.json` に preset / grade / camera optics / source metadata / HDR policy / app version を格納
  - 再インポートで grade の出発点を復元可能
- **iOS の現状**
  - export は一時 output URL に 1 ファイルを書き、Photos 保存または share に渡す
  - sidecar JSON は作らない
  - Photos asset の隣に任意 JSON を置く前提は成立しにくい
- **ユーザー影響**
  - iPhone で作った look を Desktop 側で復元しづらい
  - HDR / optics / source metadata の透明性改善が export artifact に残らない
- **v1.1 で必要な変更**
  - Desktop と同じ schema family の iOS sidecar builder を追加
  - JSON は app container の export artifact として保存し、share sheet で output と一緒に渡せるようにする
  - Photos 保存は media のみ、Files / AirDrop は media + sidecar を基本導線にする

## 2. P1 — 光学コンテキストと source metadata

### 2.1 Camera optics は取れているが renderer に反映されない

- **Desktop が持つもの**
  - `deriveCameraOpticsFromFfprobeMeta()` で make / model / lens / focal / HFOV を取得
  - `resolveRayAngleOptics()` が `CameraOptics` から `tanHalfFovX/Y` を解決し、WebGPU shader に渡す
  - fallback は 65 deg HFOV
- **iOS の現状**
  - `SourceProbeService.swift` は `CMFormatDescriptionExtension_HorizontalFieldOfView` と `AVAsset.metadata` から `CameraOpticsDTO` を作る
  - `Phase0ExportRequestDTO.sourceProbe.cameraOptics` までは届く
  - `FilmtoneExportSession.swift` の Core Image kernels は optics を参照していない
- **ユーザー影響**
  - 広角/望遠/metadata/assumed の差が iOS の vignette、edge softness、glow field response に反映されない
- **v1.1 で必要な変更**
  - iOS 側に Desktop `rayAngleOptics.ts` 相当の small math helper を移植する
  - `request.sourceProbe?.cameraOptics` から `tanHalfFovX/Y` を解決する
  - まず vignette / edge softness など既存 Core Image kernels の field mask に適用する
  - `depthRayAngleGamma` / `depthRayAngleInnerThreshold` は hidden default として扱い、UI には出さない

### 2.2 Camera optics の UI label 表示

- **Desktop**
  - source metadata line に camera make/model/lens/HFOV/source を表示する
- **iOS**
  - `SourceProbeDTO.cameraOptics` はあるが preview meta / export panel には出ない
- **ユーザー影響**
  - その素材の optics metadata が拾えたか、assumed なのかが分からない
- **v1.1 で必要な変更**
  - `previewMetaLabel` と export panel の source info に optics summary を追加
  - 表示は短くし、`metadata` と `assumed` の差を明示する

### 2.3 Source video metadata（color / display / FPS trust）

- **Desktop が持つもの**
  - `display.rotationDeg / display.source`
  - `color.colorRange / colorSpace / colorTransfer / colorPrimaries`
  - `timing.sourceFrameRateTrusted / trustReason`
- **iOS の現状**
  - rotation は `preferredTransform` を使って preview / export に適用している
  - `SourceProbeDTO` には display metadata と trust reason がない
  - color / transfer / primaries は欠落
  - FPS は `nominalFrameRate` を使い、VFR trust 判定がない
- **ユーザー影響**
  - 縦撮り export の既知対策はあるが、sidecar や QA で追跡できない
  - VFR クリップで frame pacing / audio sync 問題が起きたときに診断しづらい
- **v1.1 で必要な変更**
  - `SourceProbeDTO.sourceVideoMetadata` 相当の nested DTO を追加
  - rotation は実装済みとして、fixture /実機で検証し sidecar に残す
  - FPS trust は `nominalFrameRate` と sample timing の差を見て段階的に導入する

### 2.4 iOS contract regeneration guardrails

- **現状**
  - iOS `FilmtonePhase0Generated.swift` は Desktop preset の最終値を直書きしている
  - Desktop の hidden defaults（depth / ray-angle / cross-filter 系）は iOS の public Phase0 param set に入っていない
- **ユーザー影響**
  - Desktop で default / contract が変わっても iOS へ自動反映されない
  - 見た目のズレが「仕様」なのか「生成漏れ」なのか判断しにくい
- **v1.1 で必要な変更**
  - shared contract から iOS generated payload を再生成するスクリプトと fixture を整える
  - iOS で使わない hidden defaults も sidecar / renderer helper の default source として保持する

## 3. P2 — v1.2 へ分離する画づくり差分

### 3.1 Cross Filter native parity

- **Desktop が持つもの**
  - `cross-filter-streak.frag.wgsl.ts` の `sourceWeight()` が depth + ray-angle + edge gain で streak を変調
  - hidden defaults: `crossFilterDepthGain / crossFilterAngleGain / crossFilterAngleGamma / crossFilterAngleInnerThreshold / crossFilterEdgeLengthGain / crossFilterEdgeStrengthGain`
- **iOS の現状**
  - native export path に Cross Filter 実装自体がない
  - Phase0 generated params に `crossFilter*` はない
- **判断**
  - 「depth-aware 化」ではなく「native Cross Filter 実装」から始まるため、v1.1 では scope 外にする

### 3.2 Bloom / Halation / Diffusion depth coupling

- **Desktop が持つもの**
  - `bloom-depth-prefilter / halation-depth-prefilter / diffusion-depth-prefilter`
  - `depthMistGain / depthGlowGain / depth*RayAngleGain / depthMistFieldPsfGain`
- **iOS の現状**
  - Core Image で bloom / halation / diffusion は実装済み
  - depth map pipeline と depth-aware prefilter はない
- **判断**
  - depth texture の lifecycle と UI/API contract が必要。v1.2 以降へ分離する

## 4. P3 — 設計後に入れる

### 4.1 Progressive loading / Quality badge

- **Desktop**
  - `use-progressive-load.ts` と `QualityBadge.tsx` で thumbnail / proxy / mezzanine を表示
- **iOS**
  - `MezzanineService` は import 後に background generation される
  - ただし standard preview/export は original capture を使う設計で、quality badge はない
- **判断**
  - v1.1 では metadata transparency を優先し、quality badge は設計後

### 4.2 Export format / Files workflow

- **Desktop**
  - image batch は PNG / JPEG
  - video UI は現在 `-graded.mp4` 固定
- **iOS**
  - output profile は H.264 / MP4 固定
  - still image source も final export は 3 秒 MP4。JPEG は preview artifact
  - Photos 保存は media だけ、share は 1 file
- **判断**
  - sidecar 同梱導線を先に整え、PNG / still-image final export や MOV は要望次第で分離する

## 5. 同等または差分扱いしないもの

### 5.1 Preset catalog

- Desktop / iOS ともに 10 presets
- 内訳: `reset`, `cinematic`, `portra`, `gold200`, `pro400h`, `bw`, `ektar100`, `superia400`, `cinestill800t`, `velvia50`

### 5.2 Default Neutral + soft finish

- Desktop: `createFilmtoneDefaultParams() = reset + FILMTONE_SOFT_FINISH_PATCH`
- iOS: generated payload に soft finish 後の final reset 値を保持
- 見た目は同等。ただし iOS は再生成フローが必要

### 5.3 Compare reveal

- iOS: Strength sheet に still-frame reveal slider がある
- Desktop: WebGPU canvas compare に draggable split と A/B slot edit がある
- どちらも連続比較 UI を持つため、Desktop 未対応とは扱わない。差は表示面と導線

## 6. v1.1 提案スコープ

v1.1 は「silent / implicit behavior を visible policy に変える」ことを主目的にする。

1. HDR source visibility + policy notice
2. Export sidecar JSON
3. Source video metadata DTO 拡張
4. Camera optics renderer wiring
5. Camera optics UI label
6. Contract regeneration guardrails
7. Rotation / HDR / sidecar の QA fixtures

Cross Filter native parity と depth coupling は v1.2 へ分離する。Progressive quality badge と export format 多様化は v1.1 の後続設計に回す。

## Appendix A — Desktop 側 reference 実装マップ

| 領域 | Desktop 実装 |
|-----|-------------|
| Default soft finish | `packages/film-lab-core/src/presets.ts` |
| Shared params / hidden defaults | `packages/film-lab-core/src/params.ts`, `packages/film-lab-core/src/presets.ts` |
| Cross filter depth-aware | `packages/film-lab-renderer/src/webgpu/shaders/cross-filter-streak.frag.wgsl.ts` |
| Ray-angle optics | `packages/film-lab-renderer/src/webgpu/rayAngleOptics.ts` |
| Depth prefilters | `packages/film-lab-renderer/src/webgpu/shaders/{bloom,halation,diffusion}-depth-prefilter.frag.wgsl.ts` |
| Camera optics intake | `apps/desktop-film-lab-batch/electron/video-export-camera-optics.ts` |
| Source video metadata | `apps/desktop-film-lab-batch/electron/video-export-source-metadata.ts` |
| HDR policy notice | `apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx` |
| Sidecar writer | `apps/desktop-film-lab-batch/src/renderer/export-metadata-session.ts` |
| Progressive load | `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`, `QualityBadge.tsx` |

## Appendix B — iOS 側現行ファイル

| 領域 | iOS 実装 |
|-----|---------|
| Preset catalog | `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePresetCatalog.swift` |
| Phase0 params & math | `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePhase0Generated.swift`, `FilmtonePhase0Math.swift` |
| Source probe | `apps/capacitor-film-lab-ios/ios/App/App/SourceProbeService.swift` |
| Export session | `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift` |
| Preview / export UI | `apps/capacitor-film-lab-ios/ios/App/App/FilmtonePreviewView.swift`, `FilmtoneExportPanel.swift` |
| Mezzanine cache | `apps/capacitor-film-lab-ios/ios/App/App/MezzanineService.swift` |
| Snapshot support | `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneSnapshotSupport.swift` |

## Appendix C — 追加確認が必要な未解決ポイント

- Core Image `toneMapHDRtoSDR` の結果が Desktop policy とどこまで揃うか。v1.1 では「同等変換」ではなく「policy visibility」として扱う
- 縦撮り export は `coreImageVideoTransform` で対策済みだが、fixture /実機で regression test を追加する
- Mezzanine service は background generation されるが standard preview/export は original capture 優先。v1.1 では品質表示の対象にしない
- Photos に sidecar を隣接保存する前提は置かず、Files / AirDrop / share sheet 経由を主導線にする
