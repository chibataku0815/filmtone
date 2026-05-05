# M5-D.2 Native Video Playback (MVP, Timer-driven scrub increment)

Date opened: 2026-05-05 JST (auto-mode、Tier B 5-gap 2 件目 = 5-gap 4 件目)

## Milestone

M5 Native Editing UI / video preview slice。strategy.md "2026-05-04 user
smoke で 5 個の追加ギャップ判明" の **M5-D.2**。

## Goal

Filmtone Desktop で video source を開いた時、Play/Pause で graded preview
が時間軸上に再生される動作を最小実装する。Space-key shortcut + scrub bar
への Play button 追加。

## Why this slice (本質)

- User smoke 4 不満中 #1「再生機能やプレビューシークがない」の playback
  半分。scrub は M5-A.3 + M5-D.1 で discoverable + 機能化済み、残るは
  「自動的に時間が進む graded preview」。
- 1.4 公開前に「video アプリなのに再生できない」状態は本質的に欠陥。

## Architectural choice (本質優先 / 外殻最小)

**選択: MVP Timer-driven `videoPreviewSeconds` 増分。既存 AVAssetImageGenerator
preview pipeline をそのまま再利用。AVPlayer 移行は perf 不足が判明した
場合の follow-up slice。**

理由:
- **既存 preview pipeline (`PreviewSurface` + `FilmtoneVideoFramePreviewLoader`
  + grade pipeline) が動作済み**。scrub bar の値が変わると 1 frame ごとに
  非同期 decode + grade + display する仕組みが M5-A.3 で landed。Timer で
  `videoPreviewSeconds` を nominal rate で前進させれば、既存 in-flight Task
  cancellation pattern が自然に frame-drop を実現する。
  > **Correction (2026-05-05、M5-D.2 spike で判明)**: 当初「`scaled preview
  > (previewMaxLong)` で動作」と書いていたが、Desktop には preview scale
  > symbol が存在せず、source 解像度のまま grade pipeline を流していた
  > (`grep -r previewMaxLong apps/filmtone-desktop-macos/` → 0 hit)。
  > frame-drop は実現するが decode コスト自体は MVP 前提より高く、M5-D.2.0a
  > (v1.4 hot-fix candidate) で probe + 1280 long-side downscale を入れる
  > 案、M5-D.2.1 (v1.5) で AVPlayer Primary route 着地予定。
- AVPlayer + AVPlayerItemVideoOutput への移行は別 architecture (CVPixelBuffer
  → CIImage 経路、CMTime 同期、別 grade pipeline branch) で 2-3h+ の slice。
  perf 不足の証拠なしで先取り実装は overengineering。
- 明示的に「raw decode で grade-off vs decode+grade で frame drop」の二択を
  user に問う案は不要 — 既存 pipeline が既に decode+grade で frame-drop を
  natural に出すため。
- Memory `feedback_auto_mode_no_decision_handoff` 適用: auto-mode で plan
  approved → 次手を打つ。strategy 旧 gate (user 判断) は前提が変わったので
  bypass する (理由: 既存 pipeline の特性確認後)。

## Scope

### In

1. **EditorState 拡張**
   - `isPlaying: Bool = false`
   - `@ObservationIgnored var playbackTask: Task<Void, Never>?`
   - `togglePlayback()` / `startPlayback()` / `stopPlayback()` methods
   - `setSource(_:)` で `stopPlayback()` を call (新 source で stale playback
     が残らないように)
2. **playback Task 実装**
   - 24 fps 既定 (1/24 秒 sleep)。`videoDurationSeconds` 不在なら停止。
   - 各 tick で `videoPreviewSeconds += 1.0/24.0`、duration 到達で `stopPlayback()`
     + `videoPreviewSeconds = duration` に固定 (loop は v1 では出さない、
     end-of-video で自然停止)。
   - Task.checkCancellation で interrupt 可能。
3. **VideoScrubBar に Play/Pause button 追加**
   - 既存の time label 左に SF Symbol button (`play.fill` / `pause.fill`)。
   - `.buttonStyle(.glass)` で M5-F.1 posture と整合。
   - `keyboardShortcut(.space, modifiers: [])` で Space-key toggle。
4. **scrub-during-playback 動作**
   - User が slider を drag したら `stopPlayback()` を call。
   - SwiftUI `Slider` の `onEditingChanged: { editing in if editing { state.stopPlayback() } }`。
5. **build verify**
   - `xcodebuild -scheme FilmtoneDesktop -configuration Debug build` ✅
   - Swift 6 strict concurrency warning なし (Task は @MainActor reentrancy)
6. **commit (single)**

### Out (deferred / out of scope)

- **AVPlayer + AVPlayerItemVideoOutput migration** — perf 不足の証拠なしで
  別 architecture を引き込まない (2-3h+ の architectural slice)
- **正確な frame rate 同期** — v1 は 24 fps 固定。実 source の
  `nominalFrameRate` 取得は v2 (FilmtoneSourceProber 経由で probedSourceColorClass
  と一緒に追加が canonical だが今 slice では out of scope)
- **Loop / scrub-back** — end-of-video で自然停止、loop は別 slice
- **Audio playback** — Filmtone は color/grade-focused、audio preview は別 product 議論
- **Frame-by-frame stepping (←/→ key)** — 別 slice (M5-D.3 候補)
- **Playhead visualization の glassy 強化** — 既存 Slider thumb で OK

## Approach

```swift
// EditorState.swift addition
@MainActor
extension EditorState {
    var isPlaying: Bool /* @Observable backed */
    @ObservationIgnored var playbackTask: Task<Void, Never>?

    func togglePlayback() {
        if isPlaying { stopPlayback() } else { startPlayback() }
    }

    func startPlayback() {
        guard let duration = videoDurationSeconds, duration > 0 else { return }
        guard videoPreviewSeconds != nil else { return }
        stopPlayback()
        isPlaying = true
        playbackTask = Task { @MainActor [weak self] in
            let nominalFps: Double = 24
            let dt = 1.0 / nominalFps
            while let self, !Task.isCancelled, self.isPlaying {
                try? await Task.sleep(nanoseconds: UInt64(dt * 1_000_000_000))
                guard let self, !Task.isCancelled, self.isPlaying else { return }
                let next = (self.videoPreviewSeconds ?? 0) + dt
                if next >= duration {
                    self.videoPreviewSeconds = duration
                    self.isPlaying = false
                    return
                }
                self.videoPreviewSeconds = next
            }
        }
    }

    func stopPlayback() {
        playbackTask?.cancel()
        playbackTask = nil
        isPlaying = false
    }
}
```

```swift
// VideoScrubBar additions (RootWindowView.swift)
HStack(spacing: 12) {
    Button { state.togglePlayback() } label: {
        Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
    }
    .buttonStyle(.glass)
    .controlSize(.small)
    .keyboardShortcut(.space, modifiers: [])
    Text(format(...)) ...
    Slider(value: seconds, in: 0...max(duration, 0.001), onEditingChanged: { editing in
        if editing { state.stopPlayback() }
    })
    Text(format(duration)) ...
}
```

## Done conditions

- `isPlaying: Bool` + `playbackTask` が EditorState に landed
- Play/Pause button が VideoScrubBar に表示、glass posture 整合
- Space-key で Play/Pause toggle
- User drag scrub → playback 自動停止
- `setSource(_:)` で playback 自動停止 (stale Task 残さない)
- `xcodebuild Debug` PASS
- Swift 6 strict concurrency warning なし
- Visual smoke (1080p 短い video で graded playback) は user-driven

## Edit Targets

- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift` (modify)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/RootWindowView.swift`
  (VideoScrubBar struct + scrub Slider onEditingChanged)

## Read-Only References

- `apps/filmtone-desktop-macos/FilmtoneDesktop/UI/PreviewSurface.swift:99-104`
  (existing scrub-driven frame load path — reused unchanged)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/Media/FilmtoneVideoFramePreview.swift`
  (existing AVAssetImageGenerator-based loader — unchanged)
- `apps/filmtone-desktop-macos/FilmtoneDesktop/State/EditorState.swift:138-186`
  (setSource + duration probe — playback stop hook を追加する場所)

## Out Of Scope

- AVPlayer / AVPlayerItemVideoOutput 移行
- 正確な nominalFrameRate 取得 (v1 は 24 fps 固定)
- Audio playback
- Frame-by-frame stepping
- Loop / scrub-back
- グラデオフ raw decode preview mode

## Estimated size

~45-60 分。EditorState 拡張 + VideoScrubBar UI + 1 slider hook + xcodebuild +
commit。

## Operating mode

Auto-mode: 5-gap Tier B 2 件目。コミットは agent。perf 不足が visual smoke
で判明したら follow-up slice (M5-D.2.1 AVPlayer migration) を別 active.md
で起こす。
