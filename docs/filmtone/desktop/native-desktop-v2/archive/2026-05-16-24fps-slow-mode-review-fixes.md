# Active: 24fps Slow Mode Review Fixes

Date opened: 2026-05-16 JST
Branch: `feature/24fps-slow-mode`
Scope: 24fps Slow Mode lane (iOS + macOS native) の post-merge code review で
顕在化した二つの副作用を畳む。Slow Mode 自体の挙動・契約は維持。

## Background

[`archive/2026-05-15-24fps-slow-mode-active.md`] で iOS / macOS の native
preview-export-sidecar に explicit 24fps Slow オプションを wire-up した直後、
同じ surface へのコードレビューで以下が見つかった:

- F1: `FilmtoneVideoTimingMetadataDTO` を image export でも build しているため、
  image sidecar の `output` block に `videoTimingMode: "normal"` /
  `audioPolicy: "preserve-source"` などの video-only な fields が混入する。
  Phase0 export result DTO 側も同じ問題。
- F2: `CompletedExport.sourceDurationSec` に `videoTimeline.outputDurationSec`
  を代入しており、slow24 (例: 120fps→24fps 5x) では source duration ではなく
  output duration が入る。同じ `feedback_check_ios_canonical_*` で抽出した
  「output container vs source-conform」collapse の duration 軸版。
  実害は `realtimeRatio` が source 基準でなく slow output 基準で計算される点
  (Connect companion silent drop は `assetDuration` 優先で実際には発火しない
  が、field 名と意味の collapse は残る)。
- F3: VFR fallback で `estimatedFrameRate` が未参照。`SourceProbeService` が
  常に nil を書く現状では実害なし → 別 lane に追い出す。

## Plan

### F1 — Gate video timing metadata to video exports

| 場所 | 変更 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (`runImageOrVideo` / 通常 export パス, line ~529) | `request.sourceKind == .video` のときだけ `FilmtoneVideoTimingMetadataDTO.make` を呼ぶ。image のときは `videoTimingMode: nil, audioPolicy: nil` で `Phase0ExportResultDTO` を組み立てる |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift` (`SidecarOutput` 組み立て, line ~729) | 同じ gate。image なら全 timing fields を nil |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSidecarBuilder.swift` (`struct SidecarOutput` 定義, line ~240) | `videoTimingMode` / `targetFps` / `speedMultiplier` / `audioPolicy` を optional 化 (既存 nullable fields と整合) |

`Phase0ExportResultDTO.videoTimingMode` / `audioPolicy` は既に `String?`。
sidecar 側は default-synthesized `Encodable` で optional は JSON `null` として
serialize される。完全 omit は `SidecarOutput` の他 nullable fields の慣行
(現状 null 出力) と非対称になるため、null 出力に揃える。Filmtone Export Panel の
slow24 表示判定 (`result.videoTimingMode == FilmtoneVideoTimingMode.slow24.rawValue`)
は nil-safe。

### F2 — Split `CompletedExport.sourceDurationSec` vs `outputDurationSec`

| 場所 | 変更 |
|---|---|
| `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportSessionModels.swift` (`struct CompletedExport`) | `outputDurationSec: Double?` を追加。`sourceDurationSec` はそのまま、ただし意味は「実 source video duration、stills は nil」に縮める |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (`exportVideo` line 838-843) | `sourceDurationSec: sourceDurationSec.isFinite ? sourceDurationSec : nil` (line 640 の AVURLAsset duration を直結)、`outputDurationSec: videoTimeline.outputDurationSec.isFinite ? videoTimeline.outputDurationSec : nil` |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/Internal/ExportStillImageWriter.swift` (`CompletedExport` 戻り, line 118-123) | `sourceDurationSec: nil`、`outputDurationSec: Double(frameCount)/Double(outputFPS)` (3 秒固定) |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (`realtimeRatio` 計算 line 474, 578) | `result.sourceDurationSec ?? result.outputDurationSec` を使う。video は source 基準を維持、still は 3 秒 (output) 基準で従来 telemetry を維持 |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (writeReferenceAfterImage 渡し line 490-494) | 引数を `result.outputDurationSec` に変更。inside で asset duration 取得失敗時のフォールバックなので、output 経路 = output duration を渡すのが意味整合 |
| `apps/capacitor-film-lab-ios/ios/App/App/Export/FilmtoneExportSession.swift` (sidecar `timingMetadata.make(...)` line 529-533) | 引数の `sourceDurationSec: request.sourceProbe?.durationSec` は維持 (sidecar metadata の source 値は source probe 由来が正解) |

`realtimeRatio` の意味: video は wall-clock vs source playback duration の比率、
still は wall-clock vs 3 秒 filler の比率。slow24 video で source 基準にすると、
120fps→24fps 5x の場合 ratio は元 source playback 基準になり ≪1 でも可。
output 基準にすると ratio が 1/5 倍になる→ slow オプションが「速く処理した」
ように見えてミスリード。**source 基準を維持する**。

### F3 — Defer

このブランチでは扱わない。archive に Follow-up として記録のみ:

- `Phase0ExportRequestDTO.sourceVideoFPS` (`FilmtoneMediaTypes.swift:485`) と
  `FilmtoneEditorStore` の eligibility 判定が `sourceProbe.frameRate ??
  nominalFrameRate` のみ。`SourceProbeService` が `estimatedFrameRate` を
  常に nil で書く現状では実害なし。VFR fixture / trust-handling lane で扱う。

## Verification (実装後)

| Command | 必須 |
|---|---|
| `bun run verify:ios` | yes |
| `bun run verify:desktop` | yes |
| `bun run check:filmtone-context` | yes |
| `git diff --check` | yes |
| `bun run check:filmtone-copy` | 保険 (copy 文言は触らない) |
| `cd packages/film-lab-swift-core && swift test` | 任意 (Swift core 不変) |

## Done Conditions

- [x] F1: image export の `Phase0ExportResultDTO.videoTimingMode` / `audioPolicy`
      が nil で returns、image sidecar の `output` block で同 fields が null。
- [x] F2: `CompletedExport.sourceDurationSec` は実 source 値 (stills は nil)、
      `outputDurationSec` が timeline 値を保持。`realtimeRatio` は source 基準
      (stills は `outputDurationSec` フォールバックで従来 telemetry を維持)。
- [x] 既存 contract tests (sidecar fixture, slow24 test, image job)、Swift core
      timing tests がすべて pass (`swift test`: 76 tests pass)。
- [x] 検証コマンド (verify:ios / verify:desktop / check:filmtone-context /
      git diff --check) が全て pass。`check:filmtone-copy` も保険として pass。
- [x] このブランチに F1 / F2 の修正が commit (user 実行) 可能な状態で待機。

## Verification Log (2026-05-16 JST)

- `bun run verify:ios` → Phase0 contract / sidecar builder / 全 swift contract
  test pass。
- `bun run verify:desktop` → `** BUILD SUCCEEDED **`。共有 Swift core 不変
  なので回帰なし。
- `bun run check:filmtone-context` → reference guards / context sync pass。
  impact markers = archived 24fps active + 24fps handoff (本 lane の文脈)。
- `git diff --check` → exit 0 (whitespace clean)。
- `bun run check:filmtone-copy` → copy quality pass (文言は変更していない)。
- `cd packages/film-lab-swift-core && swift test` → 76 tests pass。

## Stop / Caution

- 3 consecutive verification failures on the same surface → Stop。
- 共有 Swift core (`FilmtoneVideoTiming.swift` 等) や macOS normal fps 挙動には
  触らない (slow24 lane の `feedback_dont_overengineer_dirty_state_split` 範囲)。
- copy 文言を変更しない (`bun run check:filmtone-copy` 保険として保持)。

## Follow-up (archive 移動時に記録)

- F3 VFR `estimatedFrameRate` fallback / VFR trust handling — `SourceProbeService`
  が estimated を埋めるようになった時点で `FilmtoneEditorStore` /
  `Phase0ExportRequestDTO.sourceVideoFPS` の fallback chain も拡張する。
- Cross-platform sidecar shape unification (iOS embed-in-output vs macOS
  top-level `videoTiming`) — 24fps Slow Mode archive の Follow-up と統合。
