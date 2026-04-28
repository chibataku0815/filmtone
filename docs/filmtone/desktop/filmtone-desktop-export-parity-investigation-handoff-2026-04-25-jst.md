# Filmtone Desktop Export Parity Investigation Handoff

作成日: 2026-04-25 JST

## 目的

Filmtone Desktop の動画書き出しで、プレビューに見えているグロー、ミスト、フィルムグレイン、色収差、レンズソフトネスなどの光学効果が、出力 MP4 で同じ効き方にならない問題を次チャットへ完全に引き継ぐ。

この引き継ぎ時点の最新ユーザー報告:

- 2026-04-25 00:13 JST 時点でも、プレビューと出力で効果の効きにかなり差分がある。
- 直近修正後、書き出しがとんでもなく遅くなった。
- ユーザーは「アスペクト比は関係ない」と断言している。次調査ではアスペクト比を主因として扱わないこと。

## ユーザーの重要な前提

- プロダクト品質を最優先する。
- 保守的な意見、互換性優先、速度優先より、見た目の正確さと品質を優先する。
- ただし最新報告では速度悪化も重大な回帰として扱う必要がある。
- 不明点があれば検索または質問する。
- 思考が必要な場面では sequential-thinking を使う。
- 複数の独立操作は並列に実行する。
- ローカルデスクトップ版で確認するため、コマンドはフルパスで提示する。

## リポジトリと作業ディレクトリ

Repo:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio
```

Desktop app:

```text
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch
```

## 実サンプルとスクリーンショット

問題を再現した実サンプル:

```text
Source video:
/Users/chibatakumi/Downloads/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD.mp4

Existing exported mp4:
/Users/chibatakumi/Pictures/test-outputs/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD-graded.mp4

Existing sidecar:
/Users/chibatakumi/Pictures/test-outputs/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD-graded.filmtone-session.json
```

ユーザーが共有した画像:

```text
Preview screenshot:
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_K9ktCyAg2d/CleanShot 2026-04-24 at 23.52.23@2x.png

Output screenshot:
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_BjU2FFTJIN/CleanShot 2026-04-24 at 23.52.31@2x.png

Aspect-ratio dismissal / stacked comparison:
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_g5u74AvHWO/CleanShot 2026-04-24 at 23.54.11@2x.png

Latest comparison after fixes, still visibly different and export very slow:
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_HuVs5oXvX9/CleanShot 2026-04-25 at 00.13.41@2x.png
```

最新画像では、左右比較でオレンジのミスト、ミラー縁のグロー、顔と肩周辺のハイライトの滲みがまだ一致していない。どちらがプレビューか出力かは次チャットでユーザーに再確認してよいが、差分が残っていることは確定。

## 実サンプルの観測値

source video の ffprobe:

```text
codec: h264
pix_fmt: yuvj420p
color_range: pc
color_space: bt709
color_primaries: bt709
avg_frame_rate: 25/1
r_frame_rate: 25/1
duration: 20.360000
nb_frames: 509
resolution: 1920x1080
```

修正前の既存 exported mp4 の ffprobe:

```text
codec: h264
encoder: h264_videotoolbox
pix_fmt: yuv420p
color_range: tv
color_space: bt709
avg_frame_rate: 24/1
r_frame_rate: 24/1
duration: 20.333333
nb_frames: 488
resolution: 1920x1080
```

sidecar の effect values:

```json
{
  "look.source": "editSync",
  "bloomStrength": 3,
  "halationIntensity": 0.22,
  "diffusion": 1,
  "grainIntensity": 0,
  "rgbShift": 0.0024,
  "lensSoftness": 1,
  "depthMistGain": 0,
  "depthGlowGain": 0,
  "bloomRadius": 0.62,
  "halationRadius": 0.6,
  "bloomThreshold": 0.64,
  "halationThreshold": 0.6
}
```

この sample では depthTrack は disabled、depth framePaths は空。depth mist/glow は対象外。見た目差の中心は bloom、halation、diffusion、lensSoftness、decode/color/range、resolution-dependent optical radius、timeline/history のどれか。

## ここまでに実装した変更

### 1. プレビューを export grade の source of truth に変更

追加:

```text
apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts
apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
```

内容:

- `viewport.getParams()` から同期的に `effectiveGrade` を作る。
- 動画/画像書き出しは `batchGrade` だけでなく、現在見えている Viewport params を優先する。
- Viewport がない、または `getParams()` 失敗時だけ `batchGrade` へ fallback。
- LUT、depthTrack、lookSource、preset choice、metadata lut refs を保持。
- `bloomStrength`、`halationIntensity`、`diffusion`、`grainIntensity`、`rgbShift`、`lensSoftness`、`depthMistGain`、`depthGlowGain` などをログ/summary に出す。
- depth effect が値ありなのに depth frames がない場合などを warning 化。

主に変更:

```text
apps/desktop-film-lab-batch/src/renderer/App.tsx
```

効果:

- 手動の「色を書き出しへ送る」直後に React state 更新を待てず古い `batchGrade` を読む race を回避。
- export と sidecar が同じ `effectiveGrade` を使う。

### 2. 画素 canary を追加

変更:

```text
apps/desktop-film-lab-batch/test/golden.harness.ts
apps/desktop-film-lab-batch/test/golden.spec.ts
```

内容:

- `captureParamsPngBuffer` と PNG diff helper を追加。
- `effect sensitivity canary` を追加。
- `PRESETS.reset` と強い `bloom/halation/diffusion/grain/rgbShift/lensSoftness` を比較し、meanAbs と changedRatio を要求。

注意:

- これは effect が完全に死んでいないことを検出する canary。
- プレビューと書き出し MP4 の完全 parity はまだ検証していない。

### 3. source fps を保持するよう変更

変更:

```text
apps/desktop-film-lab-batch/src/renderer/video-export-constants.ts
apps/desktop-film-lab-batch/src/renderer/video-export-constants.test.ts
apps/desktop-film-lab-batch/src/renderer/App.tsx
apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts
apps/desktop-film-lab-batch/src/renderer/batch-tab/BatchTabPanel.tsx
apps/desktop-film-lab-batch/messages/ja.json
apps/desktop-film-lab-batch/messages/en.json
```

内容:

- `VIDEO_EXPORT_FPS = 24` 固定をやめ、`VIDEO_EXPORT_FALLBACK_FPS = 24` に変更。
- `selectVideoExportFps()` を追加。
- ffprobe の source fps が trusted の場合はソース fps を保持。
- 実 sample は 25fps trusted なので、修正後 export は 25fps / 509 frames になる想定。
- UI 表示と estimate frame count も source fps を反映。

理由:

- 修正前は 25fps source を 24fps export にしており、同じ見た目のフレーム比較になっていなかった。
- 時間依存の optical effect、motion history、timeline sampling にも差が出うる。

### 4. final MP4 を full-range + 高品質寄りに変更

変更:

```text
apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts
apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.test.ts
```

修正前:

```text
-vf vflip,scale=in_range=full:out_range=limited
-color_range tv
darwin h264_videotoolbox -b:v 12M
linux libx264 -preset veryfast -crf 21
```

修正後:

```text
-vf vflip,scale=in_range=full:out_range=full,format=yuv420p
-color_range pc
-pix_fmt yuv420p
darwin h264_videotoolbox -b:v 24M
linux libx264 -preset slow -crf 16 -tune film
```

意図:

- GPU readback は full-range RGBA なので、最後に limited range へ squeeze してハイライト、ミスト、グローのトーンを変えないようにした。
- bitrate/quality を上げ、薄い mist や colored halation の圧縮劣化を減らす。

確認済み:

```text
合成 rawvideo 1 frame で ffmpeg 実行成功。
ffprobe で yuvj420p(pc), 25fps になった。
```

注意:

- `format=yuv420p` かつ `-color_range pc` のため ffprobe 表示は `yuvj420p(pc)` になる。
- 互換性より品質優先で入れた変更。
- ただしユーザー最新報告では、見た目差はまだ残っている。

### 5. WebCodecs export を既定OFFに変更

変更:

```text
apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts
apps/desktop-film-lab-batch/src/renderer/vite-env.d.ts
apps/desktop-film-lab-batch/vite.config.ts
```

内容:

- 既定は `HTMLVideoElement + VideoTexture` で export decode。
- `FILM_LAB_ENABLE_WEBCODECS_EXPORT=1` または `true` を付けたときだけ WebCodecs export を使う。

意図:

- プレビューが HTMLVideoElement/VideoTexture 系であるため、WebCodecs + CanvasTexture の色処理差を避ける。

重要:

- 最新ユーザー報告の「書き出しがとんでもなく遅くなった」は、この変更が主因の可能性が高い。
- 次チャットでは速度改善のため、WebCodecs を戻すか、WebCodecs と preview の color/upload parity を取る必要がある。

### 6. `.mov/.m4v` の export input sync 漏れを修正

変更:

```text
apps/desktop-film-lab-batch/src/renderer/App.tsx
```

内容:

- `desktopPreviewShowsUserVideo()` は `.mp4|.webm|.m4v|.mov` を user video として扱っていた。
- しかし `isVideoExportFileName()` は `.mp4|.webm` だけだったため、MOV/M4V を preview に載せても export input が古いままになる可能性があった。
- `isVideoExportFileName()` を `.mp4|.webm|.m4v|.mov` に拡張。

### 7. progressive mezzanine に source metadata を渡す

変更:

```text
apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts
```

内容:

- preview progressive mezzanine 生成時にも `sourceVideoMetadata` を渡す。
- export mezzanine は既に `sourceVideoMetadata` を渡していた。

意図:

- HDR/SDR policy や color metadata が preview mezzanine と export mezzanine でズレるのを減らす。

## ここまでに実行した検証

unit / vitest:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch test src/renderer/video-export-constants.test.ts electron/video-export-ffmpeg-args.test.ts src/renderer/video-export-frame-reuse.test.ts src/renderer/video-export-webcodecs.test.ts src/renderer/effective-export-grade.test.ts src/renderer/offscreen/apply-batch-grade-to-viewport.test.ts src/renderer/offscreen/webgpu-offscreen-render-session.test.ts src/renderer/export-metadata-session.test.ts
```

結果:

```text
8 test files passed
46 tests passed
```

typecheck:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio typecheck:desktop
```

結果:

```text
passed
```

Playwright canary:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch playwright test --config=test/playwright.config.ts -g "effect sensitivity canary"
```

結果:

```text
1 passed
```

ffmpeg full-range sanity:

```bash
/usr/bin/perl -e 'print "\xff\x80\x20\xff" x (64*64)' | /opt/homebrew/bin/ffmpeg -hide_banner -loglevel error -y -f rawvideo -pix_fmt rgba -s 64x64 -r 25 -i pipe:0 -an -vf 'vflip,scale=in_range=full:out_range=full,format=yuv420p' -color_range pc -colorspace bt709 -color_trc bt709 -color_primaries bt709 -pix_fmt yuv420p -c:v h264_videotoolbox -b:v 24M -allow_sw 1 /tmp/filmtone-fullrange-sanity.mp4 && /opt/homebrew/bin/ffprobe -hide_banner -show_streams -print_format json /tmp/filmtone-fullrange-sanity.mp4
```

結果:

```text
ffmpeg succeeded
ffprobe: h264, yuvj420p(pc), bt709, 25fps
```

## 現在の working tree

この引き継ぎ時点の `git status --short` には以下が出ている。

```text
 M apps/desktop-film-lab-batch/electron/ffmpeg-cli-resolve.test.ts
 M apps/desktop-film-lab-batch/electron/ffmpeg-cli-resolve.ts
 M apps/desktop-film-lab-batch/electron/main.ts
 M apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.test.ts
 M apps/desktop-film-lab-batch/electron/video-export-ffmpeg-args.ts
 M apps/desktop-film-lab-batch/messages/en.json
 M apps/desktop-film-lab-batch/messages/ja.json
 M apps/desktop-film-lab-batch/package.json
 M apps/desktop-film-lab-batch/src/renderer/App.tsx
 M apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.test.tsx
 M apps/desktop-film-lab-batch/src/renderer/HdrPolicyNotice.tsx
 M apps/desktop-film-lab-batch/src/renderer/batch-tab/BatchTabPanel.tsx
 M apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts
 M apps/desktop-film-lab-batch/src/renderer/video-export-constants.ts
 M apps/desktop-film-lab-batch/src/renderer/video-export-pipeline.ts
 M apps/desktop-film-lab-batch/src/renderer/vite-env.d.ts
 M apps/desktop-film-lab-batch/test/golden.harness.ts
 M apps/desktop-film-lab-batch/test/golden.spec.ts
 M apps/desktop-film-lab-batch/vite.config.ts
 M docs/filmtone-desktop-v1.0.3-qa-handoff-2026-04-24-jst.md
?? apps/desktop-film-lab-batch/src/renderer/effective-export-grade.test.ts
?? apps/desktop-film-lab-batch/src/renderer/effective-export-grade.ts
?? apps/desktop-film-lab-batch/src/renderer/video-export-constants.test.ts
?? docs/filmtone-desktop-hdr-sdr-complete-implementation-handoff-2026-04-25-jst.md
?? docs/filmtone-ios-v1.1-release-handoff-2026-04-25-jst.md
```

注意:

- `ffmpeg-cli-resolve*`, `main.ts`, `package.json`, `HdrPolicyNotice*`, 一部 docs はこの調査以外の既存変更を含んでいる可能性がある。
- 次チャットでは絶対に `git reset --hard` や `git checkout --` で消さないこと。
- 必ず差分を読んで、今回の export parity 修正と別作業を分けて扱う。

## サブエージェント調査結果の要約

### source/decode/progressive path

主な findings:

- Preview は `.mp4|.webm|.m4v|.mov` を user video とみなすが、修正前 export input sync は `.mp4|.webm` のみだった。
- unsupported/heavy codec の preview は thumbnail -> 1280px proxy -> H.264 all-I-frame mezzanine と段階的に差し替わる。
- export は `progressiveLoad.stage === "ready"` かつ `activeSourcePath === videoInputPath` のときだけ progressive mezzanine を再利用する。
- HDR path では preview mezzanine と export mezzanine の metadata 渡し方に差があった。これは `use-progressive-load.ts` で修正済み。
- H.264 MP4/MOV では export が WebCodecs + CanvasTexture を使い、preview は HTMLVideoElement/VideoTexture。decode/color path が異なっていた。

### WebGPU/offscreen parity

主な findings:

- WebGPU の core shader path は preview と export で基本共通。
- export-only の bloom/halation/diffusion shader は見つかっていない。
- ただし optical softness は render resolution 依存の可能性が高い。
- Lens softness は hard pixel radius blur で、約 1.5 to 4.2 px。Bloom/halation/diffusion も fixed mip/downsample chain による。
- Preview render resolution は UI container 由来。Export は FHD-capped source dimensions。
- これはアスペクト比ではなく、同じ grade でも render size と pixel radius の違いで halo width、mist density、lens softness が変わる問題。
- Depth readiness は preview と export で異なる可能性があるが、今回の sample は depth disabled。
- Camera optics は preview と export で race する可能性があるが、今回 sample で主因かは未確定。

## 現在も未解決の問題

### 1. 最新報告で見た目差がまだ残っている

fps/range/decode path の修正後も、ユーザーは「まだ効果の効きに差分がかなりあります」と報告。

したがって、次チャットでは以下を前提にする:

- `batchGrade` race だけではない。
- ffmpeg full/limited range だけではない。
- WebCodecs vs HTMLVideoElement だけではない可能性がある。
- スクリーンショット比較ではなく、同一時刻、同一 frame、同一 source、同一 grade の raw render output を比較する必要がある。

### 2. 書き出しが非常に遅くなった

最も疑わしい変更:

- WebCodecs export を既定OFFにした。
- `HTMLVideoElement` の seek/decode path は WebCodecs より遅い。
- libx264 fallback も `slow/crf16/tune film` にしたが、macOS sample は VideoToolbox なので主因は decode path の可能性が高い。
- VideoToolbox bitrate 12M -> 24M は多少重くなるが、「とんでもなく遅い」の主因とは考えにくい。

次チャットでは、品質を壊さず WebCodecs の速度を戻す方法を検証する必要がある。

## 次に最優先でやるべき調査

### A. スクリーンショット比較をやめ、pre-ffmpeg raw render を比較する

目的:

- Player/QuickLook/スクリーンショット/UI scaling/OS color management を除外する。
- WebGPU render の出力そのものが preview と export で違うのか、ffmpeg 後に違うのかを切る。

推奨実装:

- preview 側に「現在フレームを Viewport readback PNG として保存」する debug API を追加。
- export 側に「指定 frame/time の WebGPU render readback PNG を ffmpeg に渡す前に保存」する debug API を追加。
- 両方に以下を sidecar/debug JSON として保存:
  - original source path
  - effective input path
  - progressive stage
  - proxy/mezzanine path
  - decode mode: HTMLVideoElement, WebCodecs, proxy, mezzanine
  - media currentTime / requested time / frame index
  - output render size
  - source media dimensions
  - viewport params summary
  - camera optics
  - depth readiness
  - WebGPU backend capabilities
  - `bloomStrength`, `halationIntensity`, `diffusion`, `lensSoftness`, `rgbShift`, `grainIntensity`

比較方法:

- 同じ `t` の preview PNG と export-preffmpeg PNG を pixel diff。
- その後 export-preffmpeg PNG と MP4 decode PNG を diff。
- これで差分の場所を `preview render`、`export render`、`ffmpeg encode/decode` に分離できる。

### B. render resolution dependent optical radius を検証する

ユーザーはアスペクト比を否定している。ここで見るべきはアスペクト比ではなく render resolution と pixel radius。

仮説:

- Preview canvas size と export FHD size が違うと、同じ pixel-radius blur/mip chain が見た目上違う。
- Bloom/halation/diffusion/lensSoftness の半径を resolution-normalized にすべき。

検証:

- 同一 source frame を 1280x720, 1920x1080, preview actual canvas size で render。
- すべてを同じ size に resample して radial halo profile と MTF を比較。
- `lensSoftness=1`, `diffusion=1`, `bloomStrength=3`, `halationIntensity=0.22` で差が出るか確認。

修正候補:

- shader uniform に `opticalReferenceResolution` または `renderScale` を渡す。
- blur radius/mip influence を export/preview の display scale ではなく source/display reference に正規化。
- あるいは preview parity mode は export resolution で offscreen render し、それを canvas 表示用に downsample する。

### C. WebCodecs を速度のために戻す。ただし color/upload parity を取る

現在は遅い。WebCodecs を完全に捨てるのは品質問題を隠すだけで、製品として厳しい。

検証:

```bash
FILM_LAB_ENABLE_WEBCODECS_EXPORT=1 /opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

見ること:

- 速度が戻るか。
- 見た目差が増えるか減るか。
- `CanvasTexture` の `LinearSRGBColorSpace` 設定が正しいか。
- WebCodecs `VideoFrame` -> Canvas2D -> Texture 経由が preview の `HTMLVideoElement` upload と同じ luma/chroma になるか。

修正候補:

- WebCodecs output を preview と同じ `rgba8unorm-srgb` contract に正規化。
- WebCodecs と HTMLVideoElement の raw source frame を shader 前に capture して比較。
- WebCodecs を default on に戻し、parity debug mode だけ HTML path にする。

### D. motion/history/time dependent effect を確認する

疑う点:

- Preview は再生しながら motion blur/cross filter/lens history が積まれる。
- Export は `resetMotionBlurHistory()` して frame 0 から処理。
- `setTime(t)` と `viewport.render()` のタイミングが preview と export で違う。
- source fps 変更後も、比較しているスクリーンショットが同一 frame/time とは限らない。

確認:

- preview currentTime と export target time をログ化。
- preview の「今の frame index」を sidecar/debug JSON に出す。
- motionBlur/crossFilter/light shafts が 0 か、条件未充足かを明示。

## 現時点で避けるべき結論

- 「効果が未適用」はもう単純には言えない。sidecar に効果値は入っているし canary も通っている。
- 「アスペクト比が原因」はユーザーが明確に否定しているため、主張しない。
- 「ffmpeg だけが原因」と断定しない。最新報告では full-range 変更後も差がある。
- 「WebCodecs を切れば解決」としない。速度が大きく悪化した。
- QuickTime や CleanShot の見え方だけで判断しない。raw render / pre-ffmpeg / decoded frame の三点比較が必要。

## ローカル確認コマンド

通常 dev 起動:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

WebCodecs を明示的に有効にして速度比較:

```bash
FILM_LAB_ENABLE_WEBCODECS_EXPORT=1 /opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

動画書き出し debug log:

```bash
FILM_LAB_DEBUG_VIDEO_EXPORT=1 /opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

verbose trace:

```bash
FILM_LAB_VERBOSE_VIDEO_EXPORT=true /opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch dev
```

source ffprobe:

```bash
/opt/homebrew/bin/ffprobe -hide_banner -show_streams -show_format -print_format json /Users/chibatakumi/Downloads/6535378_Woman\ Mourning\ Mirror\ Heartbroken_By_Zed_Artlist_HD.mp4
```

export ffprobe:

```bash
/opt/homebrew/bin/ffprobe -hide_banner -show_streams -show_format -print_format json /Users/chibatakumi/Pictures/test-outputs/6535378_Woman\ Mourning\ Mirror\ Heartbroken_By_Zed_Artlist_HD-graded.mp4
```

sidecar effect params:

```bash
/usr/bin/jq '.look.grade.grade | {bloomStrength,halationIntensity,diffusion,grainIntensity,rgbShift,lensSoftness,depthMistGain,depthGlowGain,bloomRadius,halationRadius,bloomThreshold,halationThreshold}' /Users/chibatakumi/Pictures/test-outputs/6535378_Woman\ Mourning\ Mirror\ Heartbroken_By_Zed_Artlist_HD-graded.filmtone-session.json
```

unit tests:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch test src/renderer/video-export-constants.test.ts electron/video-export-ffmpeg-args.test.ts src/renderer/video-export-frame-reuse.test.ts src/renderer/video-export-webcodecs.test.ts src/renderer/effective-export-grade.test.ts src/renderer/offscreen/apply-batch-grade-to-viewport.test.ts src/renderer/offscreen/webgpu-offscreen-render-session.test.ts src/renderer/export-metadata-session.test.ts
```

typecheck:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio typecheck:desktop
```

effect canary:

```bash
/opt/homebrew/bin/bun run --cwd /Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch playwright test --config=test/playwright.config.ts -g "effect sensitivity canary"
```

## 次チャットへの最高精度引き継ぎプロンプト

以下をそのまま新規チャットへ貼る。

```text
Filmtone Desktop の動画書き出しで、プレビューと出力 MP4 のグロー、ミスト、レンズソフトネス、色収差などの効きが一致しない問題を、ここから再調査してください。プロダクト品質を最優先し、保守的な互換性意見より見た目の正確さを優先してください。ただし直近修正で書き出しが非常に遅くなったため、速度回帰も重大問題として同時に扱ってください。

重要: ユーザーは「アスペクト比は関係ない」と断言しています。アスペクト比を主因として扱わないでください。ただし render resolution / pixel radius / optical kernel scale の依存性は別問題として検証して構いません。

必ず sequential-thinking を使って推論してください。不明点がある場合は検索または質問してください。独立した調査やファイル読み取りは並列化してください。ローカル確認コマンドはフルパスで提示してください。

Repo:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio

Desktop app:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/apps/desktop-film-lab-batch

Handoff document:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/docs/filmtone-desktop-export-parity-investigation-handoff-2026-04-25-jst.md

実 sample:
Source:
/Users/chibatakumi/Downloads/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD.mp4

Export:
/Users/chibatakumi/Pictures/test-outputs/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD-graded.mp4

Sidecar:
/Users/chibatakumi/Pictures/test-outputs/6535378_Woman Mourning Mirror Heartbroken_By_Zed_Artlist_HD-graded.filmtone-session.json

最新 screenshot:
/Users/chibatakumi/Library/Application Support/CleanShot/media/media_HuVs5oXvX9/CleanShot 2026-04-25 at 00.13.41@2x.png

ここまでの修正:
1. export grade は batchGrade ではなく、書き出し開始時の viewport.getParams() を source of truth にした。
2. effective-export-grade helper と unit test を追加した。
3. sidecar/log に bloom/halation/diffusion/grain/rgbShift/lensSoftness/depthMist/depthGlow などを出すようにした。
4. effect sensitivity canary を追加した。
5. source fps を保持するようにした。今回 sample は 25fps trusted なので 25fps/509 frames で出る想定。
6. final MP4 を full-range(pc) にした。ffmpeg filter は `vflip,scale=in_range=full:out_range=full,format=yuv420p`、`-color_range pc`、`-pix_fmt yuv420p`。
7. macOS h264_videotoolbox bitrate を 12M から 24M にした。libx264 fallback は slow/crf16/tune film。
8. WebCodecs export は既定OFFにし、`FILM_LAB_ENABLE_WEBCODECS_EXPORT=1` のときだけ使うようにした。これはプレビュー一致目的だったが、現在の速度回帰の主因の可能性が高い。
9. `.mov/.m4v` を export input sync 対象に追加した。
10. progressive mezzanine 生成にも sourceVideoMetadata を渡すようにした。

最新ユーザー報告:
修正後も効果の効きにかなり差があり、さらに書き出しがとんでもなく遅くなった。

最優先の調査方針:
1. スクリーンショット比較をやめ、preview render readback PNG、export pre-ffmpeg readback PNG、export MP4 decoded PNG の三点を同一 frame/time で比較できる debug path を作ってください。
2. まず差分が preview render vs export render で発生しているのか、ffmpeg 後に発生しているのかを切り分けてください。
3. WebCodecs を戻すと速度が改善するか、`FILM_LAB_ENABLE_WEBCODECS_EXPORT=1` で比較してください。ただし見た目差も raw frame で比較してください。
4. render resolution dependent optical radius を検証してください。これはアスペクト比ではなく、固定 pixel radius/mip chain が preview size と export size で違う見た目になる問題です。
5. motion/history/time dependent effect、currentTime/frame index、motion blur/cross filter state、camera optics race、depth readiness もログ化してください。

避けるべき結論:
- 「効果が完全に未適用」と単純化しない。sidecar には強い effect 値が入っており canary も通っています。
- 「アスペクト比が原因」と言わない。
- 「ffmpeg だけが原因」と断定しない。
- 「WebCodecs を切れば解決」としない。速度が大きく悪化しています。

まずは docs/filmtone/desktop/filmtone-desktop-export-parity-investigation-handoff-2026-04-25-jst.md を読んで、現在の working tree の変更を把握してください。ユーザー変更を消さないでください。git reset --hard や checkout で戻さないでください。
```
