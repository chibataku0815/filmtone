# M5-D.2 AVPlayer Playback Spike (Design Only, No Implementation)

Date: 2026-05-05 JST
Branch: `feature/native-desktop-m5-d2-avplayer-spike`
Base: `65e3f3f6` (post M5-G Architecture Thin Cuts)
Milestone: M5 Native Editing UI / playback hardening
Mode: spike (調査 + 推奨設計、コード変更しない)

This is a branch-local spike doc per the M5-H parallel coordinator setup.
`strategy.md` は本 lane で触らない。Coordinator が後段で landing 時に
1〜3 行追記する想定。

## Trigger

`archive/2026-05-05-m5-d2-native-video-playback.md` で MVP timer-driven
ticker を着地後、user smoke で video playback がカクつくと判明。同 doc
末尾の「perf 不足が判明したら follow-up slice (M5-D.2.1 候補)」に該当。

## Goal Of This Spike

- カクつきの **root cause** を architecture 単位で特定する。
- iOS canonical (`FilmtoneVideoPreviewSession` + `AVMutableVideoComposition`
  + `applyingCIFiltersWithHandler`) との差を整理する。
- v1.4 release gate に乗せるか、v1.5 に回すか判断材料を出す。
- 推奨案 / 代替案 / 実装対象ファイル / performance risk を列挙する。
- 実装はしない。必要なら `xcodebuild` build verify のみ。

## Current Architecture (Snapshot @ 65e3f3f6)

### Playback ticker (`State/EditorState.swift:215-259`)

```swift
playbackTask = Task { @MainActor [weak self] in
    let dt = 1.0 / 24.0                            // hard-coded 24 fps
    let stepNanos = UInt64(dt * 1_000_000_000)
    while true {
        try? await Task.sleep(nanoseconds: stepNanos)   // 固定 sleep
        guard !Task.isCancelled, let s = self, s.isPlaying else { return }
        let next = (s.videoPreviewSeconds ?? 0) + dt    // 固定 increment
        if next >= duration { … return }
        s.videoPreviewSeconds = next
    }
}
```

ポイント:

- `videoPreviewSeconds` を 1/24 ずつ増やすだけ。Wall-clock とは無同期。
- 1 frame の grade が 200 ms かかっても sleep は 1/24 (≈42 ms) のまま。
  時刻が wall-clock より遅れていく (drift) か、`.task(id:)` の in-flight
  cancellation で massive frame drop が発生するか、どちらか。
- Audio は一切扱わない。

### Preview render (`UI/PreviewSurface.swift:78-161`)

```swift
.task(id: PreviewRenderKey(sourceURL, sourceKind, presetName, …,
                           videoPreviewSeconds, …)) {
    await renderCurrent()
}
```

`renderCurrent()` を 1 frame ぶん追うと:

1. `FilmtoneSourceProber.probeVideo(sourceURL:)` を **毎 tick 呼ぶ**。
   Color class 結果は per-source で不変だが cache していないので
   `AVURLAsset` を新規生成 → `loadTracks` → metadata 解析を毎フレーム反復。
2. `FilmtoneVideoFramePreviewLoader.loadFrame(from:atSeconds:)` (`Media/
   FilmtoneVideoFramePreview.swift:27-80`) で:
   - `AVURLAsset(url: sourceURL)` を新規生成 (毎フレーム)。
   - `try await asset.loadTracks(withMediaType: .video)` (毎フレーム)。
   - `try await videoTrack.load(.naturalSize, .preferredTransform)`。
   - `try await asset.load(.duration)`。
   - `AVAssetImageGenerator(asset:)` を新規生成 (毎フレーム)。
   - `try await generator.image(at: time)` ← **random-access seek + decode**。
3. Source 解像度のまま `FilmtoneGradePipeline.apply` を走らせる
   (`Color/FilmtoneGradePipeline.swift:17`):
   `baseGradeV2 → filmCompressionV2 → edgeOptics → glowFamily (bloom +
   halation 6-mip + diffusion) → vignette → grain → creativeLut → printStage`。
   **Preview downscale なし**。4K source なら 8.3 Mpx で halation の Gaussian
   pyramid 6 段を毎フレーム走らせる。
4. `FilmtoneCIContext.shared.createCGImage(from: graded.extent, …)` を
   source 解像度で実行 → NSImage 包装。

### 致命点 (Why It Stutters)

| # | 問題 | 影響 |
|---|---|---|
| C1 | `AVURLAsset` + `AVAssetImageGenerator` を毎フレーム new | I/O + metadata 再解析、decoder state 再構築 (sequential decode の利点ゼロ) |
| C2 | `AVAssetImageGenerator` は random-seek 用 API | Sequential 24fps 再生では最悪の primitive。1 frame 1 seek + decode、I-frame distance に応じて latency が爆発する |
| C3 | `FilmtoneSourceProber.probeVideo` を毎 tick 呼ぶ | 結果 invariant な metadata 解析を 24Hz で反復 |
| C4 | Preview の resolution cap が一切ない | 4K source = 8.3 Mpx を halation 6-mip 含む full grade pipeline に毎フレーム流す。M-series でも厳しい |
| C5 | Sleep が `1/24` 固定 (cost 無視) | Wall-clock との同期なし。drift か frame drop か |
| C6 | Audio サポートなし | 「映像アプリなのに音が出ない」product gap |
| C7 | iOS と preview architecture が違う | iOS は `AVMutableVideoComposition + applyingCIFiltersWithHandler` (sequential decode + AVFoundation pipelining)、Desktop は random-access timer。M4-B で parameter contract (`FilmtonePhase0Params` ほか) は共有しているが、grade math 本体は Desktop / iOS とも app-local 並走で、preview pipeline shell も divergent |

## iOS Canonical (Reference)

`apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift:228-280`
+ `FilmtoneMediaRuntime.swift:156-195` + `FilmtoneExportSession.swift:
3795-3827`:

- `FilmtoneVideoPreviewSession` actor が `original: FilmtonePreparedVideoPreviewItem`
  + `graded: FilmtonePreparedVideoPreviewItem` を保持し、`AVPlayer` を 1 個
  rebuild なしで生かしておく。
- `gradedItem.videoComposition = AVMutableVideoComposition(asset:
  applyingCIFiltersWithHandler:)` で **per-frame CIImage を AVFoundation 側
  scheduler から渡される**。コード:

  ```swift
  let composition = AVMutableVideoComposition(
    asset: asset,
    applyingCIFiltersWithHandler: { [session] request in
      let timeSeconds = CMTimeGetSeconds(request.compositionTime)
      let processed = try session.renderablePreviewVideoImage(
        from: request.sourceImage,
        outputSize: outputSize,
        timeSeconds: timeSeconds,
        motionAccumulator: self.motionBlurAccumulator
      )
      request.finish(with: processed, context: session.ciContext)
    }
  )
  composition.renderSize = outputSize
  composition.frameDuration = CMTime(value: 1, timescale: outputFrameRate)
  ```

- `outputSize` は `FilmtoneExportSession.scaledSize(for:longEdge:)` で
  preview 用の long edge cap (典型: 1280px or render-mode の preview cap)
  に scale 済み。
- Compare mode toggle は graded/original `AVPlayerItem` を `replaceCurrentItem`
  + `currentTime` 復元 + `rate` 復元。
- Param/Look 変更時は `AVMutableVideoComposition` を作り直して
  `gradedItem.videoComposition = newComposition` + `seekingWaitsForVideoComposition
  Rendering = true` で前フレーム時刻を再 render。
- 表示は `AVPlayerViewController` (iOS) — UI / scrub / play-pause / audio が
  全部 OS 標準。

## 推奨案 (Primary): AVPlayer + AVMutableVideoComposition (iOS-canonical port)

iOS と **同じ primitive を使う**。

**Shared today (M4-B Phase0 core)**: parameter contract — `FilmtonePhase0Params`
/ `FilmtonePhase0ParamsPatch` / `FilmtoneQuickState` / `Phase0OutputProfileDTO`
+ 生成 `FilmtonePhase0Generated` のみ (`packages/film-lab-swift-core/Sources/
FilmLabSwiftCore/`)。

**Not shared (app-local on both sides)**: grade math 本体。Desktop の
`apps/filmtone-desktop-macos/FilmtoneDesktop/Color/FilmtoneGradePipeline.swift`
と iOS の `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift`
内 `renderablePreviewVideoImage` は **別実装が並走**。iOS canonical との parity
は Verify (M5-G.2 で 42/42、AdvancedAdjustCatalog parity 等) + 手 port で
維持されている状態。

つまり Primary route の作業は (a) parameter resolve は M4-B 既存路線で済む、
(b) composition handler から呼ぶ grade pipeline は **既存の Desktop
`FilmtoneGradePipeline.apply` を再利用** (新規実装ではない)、(c) ただし
playback path 経由の出力が still preview / export path の出力と byte 一致
することを **明示的に parity 確認** する必要がある (preview shell の入出
力契約変更を伴うため)。「移植は shell だけ」と書くと grade parity の
確認 cost を見落とすので避ける。

### 設計

1. **`FilmtoneDesktopVideoSession` (新規 actor / @MainActor class)**
   - iOS `FilmtoneVideoPreviewSession` の Mac 版 mirror。
   - `AVPlayer` を 1 個 hold、`gradedItem` / `originalItem` 2 つの
     `AVPlayerItem` を持って compare mode で swap。
   - `gradedItem.videoComposition = makeGradedVideoComposition(...)` で
     `applyingCIFiltersWithHandler` を attach。
   - `gradedItem.seekingWaitsForVideoCompositionRendering = true`。
   - Param / Look / Quick / Strength / Override / Profile が変わったら
     composition を作り直して再 assign + 同 time に再 seek。
2. **`FilmtoneDesktopVideoComposition` (新規)**
   - `makeGradedVideoComposition(asset:videoTrack:outputSize:resolveParams:)`
     を提供。`applyingCIFiltersWithHandler` の中で:
     - 現在の preview params (preset / strength / look / quick / overrides /
       sourceProfile) を `EditorState` snapshot から resolve。
     - `FilmtoneSourceInputTransform.apply(to: request.sourceImage, …)` で
       input transform。
     - `FilmtoneGradePipeline.apply(to:params:sourceSeed:creativeLut:)` で
       grade。
     - `processed.cropped(to: request.sourceImage.extent)` で extent clamp
       (halation で extent が膨らむため AVFoundation 側で reject されないよう)。
     - `request.finish(with: processed, context: FilmtoneCIContext.shared)`。
   - `composition.renderSize = scaledSize(longEdge: 1280)` (preview cap)。
   - `composition.frameDuration = CMTime(value: 1, timescale: nominalFrameRate)`
     — `videoTrack.nominalFrameRate` を使う (24/25/29.97/30/50/59.94/60)。
3. **`FilmtoneDesktopPlayerView` (新規 NSViewRepresentable)**
   - `AVPlayerView` を wrap。`controlsStyle = .inline`、`videoGravity =
     .resizeAspect`。Apple Liquid Glass 文脈で chrome が透ける必要があるので
     `controlsStyle = .none` にして自前の `VideoScrubBar` を使う案も検討
     (M5-B / M5-D.1 posture と整合させるため)。
   - 親 `PreviewSurface` から `player: AVPlayer?` を渡す。
4. **`PreviewSurface`** (modify)
   - `if let videoPlayer = videoSession?.player, sourceKind == .video {
     FilmtoneDesktopPlayerView(player: videoPlayer) }` 分岐。
   - Still / pre-load 状態は現状の `Image(nsImage:)` + `FilmtoneBackdrop`
     を残す。
   - M5-H.1.2 の `renderedSourceURL` identity gating はそのまま (still 経路
     は変えない)。
5. **`EditorState`** (modify)
   - `playbackTask` / `togglePlayback` / `startPlayback` / `stopPlayback` を
     **drop**。代わりに `videoSession?.player.play() / .pause() / .seek(to:)`。
   - `videoPreviewSeconds` は player の `addPeriodicTimeObserver` から
     反映 (UI 表示用 read-only)、user drag は `player.seek(to:)` 経由。
   - `isPlaying` は `player.timeControlStatus` から派生。
   - `setSource(_:)` で旧 session を tear down + 新 session 構築。
6. **`VideoScrubBar`** (modify)
   - Play/Pause button → `player.play()` / `player.pause()` に直接 dispatch。
   - Slider → `player.seek(to: CMTime, toleranceBefore: .zero,
     toleranceAfter: .zero)`。`onEditingChanged` で seek + pause。
   - 任意: 1× / 2× / 3× rate Menu button (`player.rate = 1.0/2.0/3.0`)。
     UI は scrub bar 左、Play/Pause の右隣に Menu。
7. **Param 変更による composition rebuild**
   - `EditorState` の preset / strength / lookSlug / sourceProfileSelection /
     quickState / paramOverrides が変わったら、`videoSession.refreshGraded
     Composition()` を呼ぶ。中身は `AVMutableVideoComposition` 再生成 →
     `gradedItem.videoComposition = newComposition` → 現在 time に
     `player.seek` (`seekingWaitsForVideoCompositionRendering = true` が
     1 frame 内に reflow を保証)。
   - 連続 slider drag 時は debounce (≈100 ms) で rebuild 回数を抑制。

### iOS との parity

| 領域 | iOS | Desktop (推奨後) | Share status |
|---|---|---|---|
| Parameter contract | `FilmLabSwiftCore` (Phase0Params / Patch / Quick / OutputProfile) | 同 | M4-B で既に共有 |
| Grade math 本体 | `FilmtoneExportSession.renderablePreviewVideoImage` (app-local) | `FilmtoneGradePipeline.apply` (app-local) | **並走 (parity は Verify + 手 port で維持)** |
| Per-frame loop | `applyingCIFiltersWithHandler` | 同 | OS primitive |
| Compare mode | graded / original AVPlayerItem swap | 同 | OS primitive |
| Composition refresh | `gradedItem.videoComposition = new` + re-seek | 同 | OS primitive |
| 表示 | `AVPlayerViewController` | `AVPlayerView` (NSViewRepresentable) | platform shell |
| Audio | AVPlayer 標準 | 同 | OS primitive |
| Time scrub | `AVPlayerViewController` 標準 controls | 自前 `VideoScrubBar` (Liquid Glass posture 維持) or `AVPlayerView` controls。後者を採れば work が更に減る | UI 層 |

### 必須の secondary mitigation (route 共通)

- **Preview resolution cap**: `composition.renderSize` を `scaledSize(longEdge:
  1280)` に必ず設定する。iOS と同じ。Visual judgement 上ほぼ無視可、cost は
  〜10 倍下がる (4K → 1280 long で px は 8.3M → 1.0M)。
- **Persistent AVURLAsset / probedColorClass**: M5-C.1 で既に
  `EditorState.probedSourceColorClass` を持っているので、composition handler
  が毎回 prober を叩かないようにする (snapshot を closure capture)。
- **Halation mip cap**: 1280 long edge で grade すれば自動で mip 段数の
  実コストが下がる (mip level constant は 6 のままで OK)。

### Performance risk

| リスク | 対策 |
|---|---|
| `applyingCIFiltersWithHandler` が main thread を blocking する誤解 | AVFoundation は private dispatch queue で handler を呼ぶ。`MainActor` 不要 (むしろ避ける)。`FilmtoneCIContext.shared` は thread-safe 前提で利用 |
| Halation mip pyramid + grain で 1280 でも 24fps 落ちる古い Mac | `composition.renderSize` を更に下げる (1024 / 720) flag を v1.5 に追加可。M-series mac mini 級なら 1280 で 30fps 行ける見立て (iOS が iPhone 15 で動いている) |
| `videoComposition` 差し替え時の 1 frame 黒抜け | `seekingWaitsForVideoCompositionRendering = true` + `player.seek(to: currentTime)` で再 render を強制 |
| `request.finish(with: processed)` の extent mismatch | `processed.cropped(to: request.sourceImage.extent)` で必ず source extent に揃える |
| Param 変更を 60Hz で叩いた時の rebuild 嵐 | composition rebuild を debounce (100 ms) + 同一 params hash で skip |
| Playback 中の compare mode 切替 latency | iOS は `replaceCurrentItem` + `currentTime` 復元で対応済み — 同 pattern を移植 |
| `AVPlayerView` の chrome が macOS 26 Liquid Glass と衝突 | `controlsStyle = .none` で AppKit controls 抑制、自前 scrub bar を使う (M5-D.1 / M5-F.1 posture 維持)。`videoGravity = .resizeAspect` で letterbox は AVPlayer 側、それを `Color.black` で囲む (M5-H.1.1 color judgment integrity 継続) |

### v1.4 必須かどうか

- **v1.4 公開 gate (strategy.md §Current Strategic State)**: M5-C P0 closure +
  notarize submission のみ。M5-D.2 MVP は post-cutover hardening として既に
  archived。
- **判断**: v1.4 公開には **必須ではない**。ただし Electron Desktop 1.0.4 は
  WebGL renderer で 0 lag video preview を実現済みで、Native Desktop が
  「同じ video を開いてもまともに再生できない」状態で cutover すると
  user-perceived regression になる。
- **推奨**: **v1.5 blocking**。v1.4 については Alt A hot-fix candidate を
  用意しておき、user visual smoke で「v1.4 公開許容ラインか」を判定して
  採否を決める。許容できないなら v1.4 を hold して v1.5 と一括で Primary
  を入れる選択肢も残す。Audio + 速度切替 + compare mode は Primary route
  でしか lit up しないので、いずれにせよ v1.5 で Primary 着地する想定。
  - v1.4 hot-fix candidate (Alt A 参照): PreviewSurface に
    `CILanczosScaleTransform` cap (longEdge 1280 等) + asset/probe cache
    を入れる。架構移行はしない。**実効果は実機 / 実 source 依存で断定
    しない** — 採否は visual smoke 判定。詳細は §代替案 §Alt A を参照。
- **v1.5 開ければ**: 本 spike の Primary route を 1 active.md に細分化 (Step
  1 = video session skeleton + AVPlayerView wrap、Step 2 = composition handler
  + grade wiring、Step 3 = scrub/play wiring + EditorState rewrite、Step 4 =
  compare mode + rate menu、Step 5 = Verify update + visual smoke)。総工数
  は実装中に再見積もり。

## 代替案

### Alt A: Timer + Preview Downscale + Asset Cache (Defensive Hot-fix Candidate)

最小 diff で C1 / C3 / C4 だけ潰す。Architecture 残置。

- **仮説 (要 visual smoke 検証)**: downscale + asset reuse + probe cache の
  3 点で C1/C3/C4 起因のフレーム時間は理論上数倍〜10 倍下がる見込み。
  「何 % 改善」「何 fps」は実機 / 実 source 依存なので断定しない。
- 残: audio なし、wall-clock drift 残置、`AVAssetImageGenerator` random-seek
  primitive 残置 (long-GOP H.265 で頭出しが遅い source は依然厳しい)。
- 用途: **v1.4 hot-fix candidate**。採否は Primary route 投入前に user
  visual smoke で「v1.4 公開許容ラインか」を判定してから決める。許容
  できないなら v1.4 を hold して v1.5 と一括で Primary を入れる選択肢も
  残す。
- 工数感 (目安、保証ではない): 新規ファイル 0、modify 2 ファイル
  (`Media/FilmtoneVideoFramePreview.swift` + `UI/PreviewSurface.swift`)、
  実装 + xcodebuild + visual smoke で短時間で着地し得る。pbxproj 触らない。

### Alt B: AVAssetReader Sequential Decode → CIImage → Grade → MTKView

`AVAssetReader` で sequential decode、自前で frame ring + grade pipeline、
`MTKView` で表示。

- 利点: AVPlayer の AppKit chrome 制約を回避、render path を完全制御。
- 欠点: 自前で playback clock + audio + scrub + EOF + format 多様性
  (HEVC / ProRes / H.264 / various pix fmt) を全部書くことに。AVPlayer ルートの
  3-5 倍の実装工数。iOS と pipeline 形が divergent になる (M4-B 共有の趣旨に逆)。
- 結論: **却下**。AVPlayer route が同じ計算結果を 1/N の工数で得られる。

### Alt C: Raw Decode Preview + Graded Still on Pause

再生中は raw video を AVPlayer で素通し、Pause 時に現フレームを graded
still として overlay 差し替え。

- 利点: 再生中は GPU 負荷ゼロ近く、scrub も raw だけならヌルヌル。
- 欠点: iOS と product behavior が divergent (iOS は再生中 graded)。Native
  Editing UI の「色を見ながら時間軸を辿る」価値命題を捨てる。Look の良し悪しを
  pause しないと判断できない UX は editor として弱い。
- 結論: **却下**。ただし将来 "raw / graded toggle" として compare mode を
  もう 1 段増やす設計は価値あり (iOS の compare mode と整合)。

### Alt D: Two-tier Pipeline (Fast During Drag / Full After)

Slider drag 中は cheap-tier (no halation, no grain, no optics)、release
した瞬間 full grade に差し替え。

- 利点: scrub の即応性を最大化。
- 欠点: Color truth が 2 系統になる、tier 切替の境界 frame で dimming/snap
  artifact が出やすい、pipeline 倍管理。
- 結論: **却下 (v1.5)**。Primary route 投入後に AVPlayer rate change の
  perf 実測を見てから検討。

## 実装対象ファイル (Primary route 採用時)

新規:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoSession.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneDesktopVideoComposition.swift`
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/FilmtoneDesktopPlayerView.swift`

修正:

- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift`
  (playback Task drop、player ownership、time observer、compare mode swap、
  composition refresh hook)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift`
  (sourceKind == .video 分岐で player view、still 経路は維持)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  (`VideoScrubBar` を player-bound に refactor、optional 1×/2×/3× Menu
  button)
- `apps/filmtone-desktop-macos/FilmtoneDesktop.xcodeproj/project.pbxproj`
  (3 新規 file の Build / Sources phase 登録、Media + UI group)

参照のみ:

- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneEditorStore.swift:228-410`
  (FilmtoneVideoPreviewSession の MainActor lifecycle + transition pattern)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneMediaRuntime.swift:125-234`
  (makeOriginal/Graded/Composition の signature と continuation pattern)
- `apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSession.swift:3787-3827`
  (`makeVideoComposition` の applyingCIFiltersWithHandler reference impl)

Verify 観点:

- `apps/filmtone-desktop-macos/Verify/run.sh` には現状 playback path の
  unit verify がない (UI / runtime path)。Spike 段階では追加なし。Primary
  route 着地時は composition handler が parameters を正しく resolve する
  単体 test を 1-2 本足す検討余地あり (deterministic input → expected
  PNG hash 等)。

Build verify (本 spike 内では実行しない、参考):

- `bun run verify:macos` (xcodebuild Debug PASS)
- `apps/filmtone-desktop-macos/Verify/run.sh` (現状 42/42)

## Performance Risk Summary

| Risk | 対象 route | Severity | Mitigation |
|---|---|---|---|
| 1280 cap でも halation + grain で M1 base が 24fps 落ちる | Primary | Med | `composition.renderSize` を 1024 / 720 に flag 化、または halation mip 段数を preview 専用 1 減 |
| Composition 差し替え嵐で UI thrash | Primary | Med | Param hash + 100ms debounce で rebuild 回数を抑制 |
| `videoComposition` 差し替えで 1 frame 黒抜け | Primary | Low | `seekingWaitsForVideoCompositionRendering = true` + 現 time に re-seek |
| Liquid Glass chrome と AVPlayerView controls 衝突 | Primary | Low | `controlsStyle = .none` + 自前 VideoScrubBar |
| Long-GOP H.265 source の seek latency | Alt A | High | mitigation 困難 (random-seek primitive の限界)。v1.5 で Primary 解決 |
| Audio absent 「映像 app なのに音が出ない」 product gap | MVP / Alt A | High | mitigation 不可 (architecture 起因)。Primary 移行で解決 |
| 4K source frame rate drift | MVP | High | mitigation 不可 (固定 sleep)。Primary 移行で解決 |

## v1.4 / v1.5 への載せ方 (推奨)

- **v1.4 (今 release gate 上)**:
  - Alt A を hot-fix candidate として用意可能。Title 案: `M5-D.2.0a Preview
    Downscale & Probe/Asset Cache (Hot-fix)`。**採否は visual smoke 判定**
    — Primary route まで待てるなら v1.4 で hold して v1.5 一括着地でも可。
  - hot-fix を入れた場合の残: drift と audio absent は残置 (architecture
    起因のため Alt A では解消しない)。user-perceived 改善が「再生できる」
    ラインに届くかは実 source / 実機での visual smoke で判定する。
- **v1.5 (公開後 immediately follow)**:
  - Primary route を 5 step active.md に分割して着地。
  - iOS canonical preview architecture に揃える (parameter contract は
    M4-B 既存共有、grade pipeline 本体は app-local 並走のまま、playback
    出力の still/export parity を Verify で pin する)。Audio + 速度切替 +
    compare mode が同時に lit up する。
  - Title 案: `M5-D.2.1 AVPlayer Preview Route (iOS-canonical port)`。

## Out Of Scope (本 spike)

- 実装 (新規 file 0、modify 0)
- Verify テスト追加
- pbxproj 更新
- Visual smoke
- 動画 export pipeline (本 spike は preview 専用、export 側は
  `FilmtoneVideoWriter` が別経路で正しく grade 済み)

## Done Conditions

- [x] 現 timer-driven 再生の root cause を architecture 単位で特定
  (C1〜C7 の 7 軸)
- [x] iOS canonical preview architecture を reference 化
  (`FilmtoneVideoPreviewSession` + `applyingCIFiltersWithHandler` +
  graded/original swap)
- [x] Primary 推奨 (AVPlayer + AVMutableVideoComposition) と secondary
  mitigation を分離して列挙
- [x] 代替案 4 件 (Alt A〜D) と却下理由を明記
- [x] 実装対象ファイル (新規 3 / 修正 4) を absolute path で列挙
- [x] Performance risk を route × severity × mitigation の表で整理
- [x] v1.4 必須かどうか → 必須ではない、v1.4 hot-fix (Alt A) + v1.5 Primary
  の二段着地を推奨

## Unexpected / Follow-up

- **C3 (毎 tick probeVideo) は M5-D.2 MVP の見落とし**。MVP archive doc は
  「既存 scrub-driven preview pipeline (`previewMaxLong` scaled + in-flight
  Task cancellation) が既に decode+grade で frame-drop を natural に出すので
  user 判断不要」と書いていたが、**実際には `previewMaxLong` 等の preview
  scale は Desktop には存在しない** (`grep -r previewMaxLong apps/filmtone-
  desktop-macos/` → 0 hit)。MVP archive の前提が誤っていた。strategy.md の
  M5-D.2 完了行も同じ前提で書かれているので、本 spike を archive する
  タイミングで Coordinator 側で 1 行 correction (「Desktop には preview
  scale が存在せず、source 解像度のまま grade pipeline を流していた。
  spike で判明、v1.4 hot-fix + v1.5 Primary route で解消」) を追記推奨。
- **C2 (AVAssetImageGenerator random-seek)** は scrub bar drag 時の
  primitive としては OK (single seek)。Playback 中だけ Primary route に
  切り替えれば、scrub は legacy path を残せる。Primary route 設計は scrub
  も AVPlayer.seek(to:) に統一する想定だが、tolerance .zero の seek が
  long-GOP で遅い場合は scrub 中だけ tolerance を緩める分岐が要る (iOS
  と同じ pattern)。
