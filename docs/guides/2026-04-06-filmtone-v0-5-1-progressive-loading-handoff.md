# Filmtone v0.5.1 Progressive Loading Handoff

> 作成: 2026-04-06  
> ステータス: **実装途中 / build は通過 / 要件達成は未確認 / ユーザー確認で未達扱い**  
> 対象: `apps/desktop-film-lab-batch`（Desktop Electron のみ）  
> 作業場所: `chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading`

## 結論

この作業では、ユーザーが提示した「Filmtone v0.5.1 — Progressive Loading 実装計画」に沿って、

- Electron main の `thumbnail / proxy / mezzanine` パイプラインの土台
- renderer 側の progressive loading hook
- `FilmLabCanvas` の texture swap API
- `SD` バッジ UI

までは実装した。

ただし、**要件を満たしたと判断できる状態ではない**。

理由は次の通り。

- Desktop 実機での受け入れ確認を完了していない
- `~1秒で静止画表示`、`黒フレームなしのシームレス切替`、`ProRes / HEVC / H.264 の3系統` をまだ保証していない
- ユーザーが Desktop を確認した結果、**「要件満たせてなくない？」** という反応だった

したがって、次の担当は **「実装を足す」より先に、実機で何が未達なのかを正確に特定すること」** を優先すること。

## まず最初に理解すべきこと

この handoff の最重要ポイントは、

- **build と既存テストが通った**
- しかし **要件達成は証明されていない**
- しかも **ユーザーの体感上は未達**

という点。

この作業を「完了済みの feature 実装」と扱ってはいけない。

正しくは:

- **progressive loading の配線を入れた試作実装**
- **次チャットで Desktop 実機確認と不具合修正を前提に続行するための中間状態**

である。

## ユーザーが最初に提示した計画の要点

### 背景

重い動画素材（ProRes MOV、4K HEVC など）を読むと、mezzanine 変換完了まで何も見えず、
数十秒から数分のブラックスクリーンが発生していた。

### ユーザー確認済み要件

- 3 段階 pipeline: `thumbnail -> proxy -> full-quality mezzanine`
- Desktop Electron のみ
- 全 stage でカラーグレード（Pass 1-8）適用
- 控えめなバッジ UI（`SD`）
- WebGPU 可だが、最小リスクで既存 WebGL pipeline 維持

### ユーザーが意図した新フロー

1. `ffprobe`
2. Stage 1: JPEG thumbnail 抽出
3. Stage 2: 低解像度 H.264 proxy 生成
4. Stage 3: フル品質 mezzanine 生成
5. black screen を完全排除

### 受け入れ条件の中核

- 約 1 秒以内に graded な静止画が見える
- 数秒後に proxy 動画へ切り替わる
- 最終的に full-quality mezzanine へシームレス切替
- 切替時に flicker / black frame がない
- `SD` バッジが適切に表示・消灯する
- H.264 は bypass される
- proxy 中は export 不可

## 実際に作業した場所

- Repo root:
  - `/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading`
- Branch:
  - `wt/filmtone-v0-5-1-progressive-loading`

worktree は既存 `main` を汚さないために作成した。

## 実装したこと

## 1. Electron main 側

変更ファイル:

- `apps/desktop-film-lab-batch/electron/main.ts`
- `apps/desktop-film-lab-batch/electron/video-src-protocol.ts`

追加した主な内容:

- `thumbnailProcess`
- `proxyProcess`
- progressive preview temp file 管理用 `Set`
- proxy progress channel
- `computeProxyDimensions()`
- `buildFfmpegThumbnailArgs()`
- `buildFfmpegProxyArgs()`
- `video-preview-extract-thumbnail` IPC
- `video-preview-generate-proxy` IPC
- `video-preview-abort-proxy` IPC
- `will-quit` で thumbnail / proxy / mezzanine process kill + temp cleanup

### thumbnail でやったこと

- ffmpeg で 1 フレーム JPEG 抽出
- `scale=1280:-2`
- `colorspace=iall=bt709:all=bt709`
- `-q:v 2`

### proxy でやったこと

- Apple Silicon では `h264_videotoolbox`
- fallback は `libx264`
- `scale=1280:-2`
- `format=yuv420p`
- all-I-frame (`-g 1`)
- audio なし (`-an`)
- stderr の `time=` から進捗を計算

### custom protocol でやったこと

既存 `path-to-file-url` / `film-lab-video://` 経路は元々動画前提だったが、
thumbnail JPEG も同じ経路で読めるように `guessVideoContentType()` を拡張した。

対応追加:

- `.jpg`
- `.jpeg`
- `.png`
- `.webp`
- `.gif`

## 2. preload / bridge / 型

変更ファイル:

- `apps/desktop-film-lab-batch/electron/preload.ts`
- `apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts`

追加した API:

- `videoPreviewExtractThumbnail()`
- `videoPreviewGenerateProxy()`
- `videoPreviewAbortProxy()`
- `subscribeProxyProgress()`

追加した主な型:

- `VideoPreviewExtractThumbnailInput`
- `VideoPreviewExtractThumbnailResult`
- `VideoPreviewGenerateProxyInput`
- `VideoPreviewGenerateProxyResult`
- `VideoPreviewProxyProgressPayload`

## 3. renderer hook

新規ファイル:

- `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`

ここでやったこと:

- `thumbnail -> proxy -> mezzanine -> ready` の state 管理
- `sessionId` による stale 完了通知の無効化
- proxy / mezzanine progress 購読
- temp file cleanup
- `cancel()` で旧 session を invalidate
- 初回戻り値を
  - `image`（thumbnail）
  - `video`（proxy / mezzanine fallback）
  のどちらでも返せるようにした

設計上の意図:

- `App.tsx` を重くしない
- 失敗時の fallback を hook 内で閉じ込める
- 中断・再ドロップ・古い Promise の race を `sessionId` で吸収する

## 4. App.tsx

変更ファイル:

- `apps/desktop-film-lab-batch/src/renderer/App.tsx`

やったこと:

- `useProgressiveLoad()` を接続
- `preprocessVideoFile()` を単純な mezzanine 変換から progressive load へ変更
- `handleProgressiveTextureSwap()` を追加
- `QualityBadge` を追加
- `videoCanExport` に progressive load の ready 条件を加えた
- `canvasHasUserVideo` を `qualityLabel !== "thumbnail"` と組み合わせた

### ここでの重要な設計

`preprocessVideoFile()` はもう「mezzanine URL を返すだけ」ではない。

今は:

- H.264 等の軽い素材: `null`
- 重い素材: `FilmLabCanvasPreprocessResult`

を返す。

つまり、**初回表示は画像でもよい** という構造へ変えた。

## 5. FilmLabCanvas

変更ファイル:

- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- `packages/film-lab-ui/src/FilmLabCanvasPackageEntry.tsx`
- `packages/film-lab-ui/src/index.ts`

やったこと:

- `FilmLabCanvasPreprocessResult` 型を追加
- `preprocessVideoFile` が `image / video` を返せるように拡張
- `swapProgressiveTexture()` を `FilmLabCanvasRef` に追加
- `activeTextureRef` を追加
- texture / video cleanup 共通処理を追加
- `replaceSourceFromPngBase64Body()` も新しい共通 texture 適用関数を使うように変更

### `swapProgressiveTexture()` の意図

- proxy 読み込み時:
  - 新しい VideoTexture を作って差し替える
- mezzanine 読み込み時:
  - 現在の動画の `currentTime` を読む
  - 新 video をその位置に seek
  - texture swap
  - 元の再生状態を復元

つまり、**proxy -> mezzanine を「見た目上つながって見える」方向へ持っていく配線** を入れた。

## 6. Quality badge

新規ファイル:

- `apps/desktop-film-lab-batch/src/renderer/QualityBadge.tsx`

変更ファイル:

- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/desktop-film-lab-batch/messages/en.json`

やったこと:

- `thumbnail` / `proxy` の間だけ `SD` を表示
- `ready` 時は fade out
- `aria-live="polite"` と `aria-label` を追加

## 今回の実装で確認したこと

実行したコマンド:

```bash
cd "/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading"
/opt/homebrew/bin/bun install
/opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch build:electron
/opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch build:renderer
/opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch test
```

結果:

- `build:electron` 成功
- `build:renderer` 成功
- `vitest` 成功
  - `10 files`
  - `43 tests`
  - `43 passed`

## 今回 **確認していない** こと

ここが最重要。

未確認項目:

- Desktop 実機で ProRes 読み込み時に約 1 秒以内で静止画が見えるか
- 4K HEVC で同様に動くか
- H.264 が bypass されるか
- proxy への切替で black frame が無いか
- mezzanine への切替で black frame が無いか
- シーク位置が実運用上ずれないか
- `SD` バッジがちょうどよいタイミングで出入りするか
- proxy 中の export disable が UI 全導線で守られるか
- file switch 中断時に temp leak がないか

つまり、この作業で確認したのは **型 / build / 既存 test の健全性** までであり、
**ユーザー要求そのものの実機達成確認は未実施**。

## ユーザーの実機確認結果

この作業のあと、ユーザーは Desktop を確認し、

- 「確認しましたが要件満たせてなくない？」

と述べた。

これは次チャットで極めて重要な事実。

意味は:

- この feature は **未完了**
- 「build が通ったから OK」という認識は誤り
- 次は **再設計より前に現象確認** が必要

## 現在の git 状態

変更ファイル:

- `apps/desktop-film-lab-batch/electron/main.ts`
- `apps/desktop-film-lab-batch/electron/preload.ts`
- `apps/desktop-film-lab-batch/electron/video-src-protocol.ts`
- `apps/desktop-film-lab-batch/messages/en.json`
- `apps/desktop-film-lab-batch/messages/ja.json`
- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts`
- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- `packages/film-lab-ui/src/FilmLabCanvasPackageEntry.tsx`
- `packages/film-lab-ui/src/index.ts`
- `apps/desktop-film-lab-batch/src/renderer/QualityBadge.tsx`
- `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`

未コミット。

## 現時点での重要な前提

## 1. これは Desktop 専用

今回の実装対象は `apps/desktop-film-lab-batch` のみ。
Web へ横展開しないこと。

## 2. 要件の本丸は black screen 排除

見た目が少し良くなることではなく、

- 最初に何か見えること
- その後の切替で黒落ちしないこと

が本丸。

## 3. 現在のコードは「配線」寄りで、品質保証ではない

`use-progressive-load.ts` と `swapProgressiveTexture()` は入っているが、
それでユーザー体験が要件を満たすかは別問題。

## 4. 進捗 state はあるが、UI 露出は不十分

`stageProgress` は hook 側にあるが、
現状の UI は主に `SD` バッジで、progress 表示としては弱い。

ユーザー計画上の「proxy / HD 変換中」文脈の UI は十分ではない。

## 5. 次の担当は「推測で直さない」

まず実機で、

- 何が出るか
- 何が出ないか
- どの stage で詰まるか
- どのファイル形式で失敗するか

を確認すること。

## 次チャットで最初にやるべきこと

順番はこれが最短。

1. Desktop を起動
2. ProRes MOV を読み込む
3. 4K HEVC を読み込む
4. H.264 を読み込む
5. それぞれで以下を観察する

- 静止画が見えるまでの時間
- proxy に切り替わるか
- mezzanine に切り替わるか
- 切替時に黒フレームが出るか
- `SD` バッジの表示タイミング
- export ボタン状態

## 確認用コマンド

開発確認:

```bash
cd "/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading" && /opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch desktop
```

ビルド済み起動:

```bash
cd "/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading" && /opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch start
```

## 次チャットで見るべき論点

## A. 本当に thumbnail が初手で見えているか

もし black screen のままなら、まず疑うのは:

- `preprocessVideoFile()` が return するまで `mediaOverlay.loading` が出続けている
- `thumbnail` 抽出が失敗している
- custom protocol 経由の JPEG 読み込みに失敗している
- `FilmLabCanvas` の image path 分岐が実際に通っていない

## B. proxy / mezzanine の swap が視覚的に繋がっていない

疑う点:

- `loadVideoFromURL()` 完了後の `loadeddata` タイミング
- seek 完了前に swap している
- old texture dispose / video cleanup の順番
- currentTime の再現が足りない

## C. file switch / cancel で race している

疑う点:

- `interactivePreviewSource` の更新タイミング
- `activeSourcePath` と `videoInputPath` のズレ
- 旧 session の Promise 完了が新 session へ混入

## D. export gate が甘い

疑う点:

- `videoCanExport` は止めたが、他の UI 導線から実行できていないか
- `proxy` 表示中のまま export action が呼べないか

## E. temp cleanup

疑う点:

- 成功時 cleanup は stage 昇格時だけで、失敗時や切替時に残っていないか
- app quit 前に unlink が走らないケース

## 次チャットで触ってよいファイル

- `apps/desktop-film-lab-batch/electron/main.ts`
- `apps/desktop-film-lab-batch/electron/preload.ts`
- `apps/desktop-film-lab-batch/electron/video-src-protocol.ts`
- `apps/desktop-film-lab-batch/src/renderer/App.tsx`
- `apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts`
- `apps/desktop-film-lab-batch/src/renderer/QualityBadge.tsx`
- `apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts`
- `packages/film-lab-ui/src/FilmLabCanvas.tsx`
- `packages/film-lab-ui/src/FilmLabCanvasPackageEntry.tsx`
- `packages/film-lab-ui/src/index.ts`
- 必要なら `messages/ja.json` / `messages/en.json`

## できるだけ後回しにするもの

- Web 側
- 大きいリファクタ
- WebGPU 化
- 別 package 抽出
- test の先回り大量追加

まずは「Desktop 実機で何が未達か」を潰すこと。

## 次チャット用の最重要指示

- この handoff を source of truth として扱う
- まず実機確認する
- まだ要件達成済みだと仮定しない
- 問題の切り分け前に大きい設計変更をしない
- Desktop only を守る

## 最高精度の引き継ぎプロンプト

以下をそのまま新規チャットに渡してよい。

```text
Filmtone v0.5.1 progressive loading の続きを、この worktree で行ってください。

作業ディレクトリ:
/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading

まず最初に必ずこの handoff を読んでください:
docs/guides/2026-04-06-filmtone-v0-5-1-progressive-loading-handoff.md

重要前提:
- これは Desktop Electron 専用タスクです。Web には広げないでください。
- progressive loading の配線は一部実装済みですが、要件達成は未確認です。
- ユーザーが実機確認した結果、「要件を満たしていない」という認識です。
- build と既存 test は通っていますが、それは feature 完了の証明ではありません。

今回の最優先ゴール:
1. 実機で何が未達かを正確に再現する
2. 最小差分で修正する
3. ProRes / 4K HEVC / H.264 の3ケースで受け入れ条件を満たすことを確認する

受け入れ条件:
- 重い動画で約1秒以内に graded な静止画が見える
- その後 proxy 動画へ切り替わる
- 最終的に mezzanine へ切り替わる
- 切替時に black frame / flicker がない
- SD バッジが適切に表示される
- H.264 は bypass される
- proxy 中は export 不可
- file switch / cancel / temp cleanup が破綻しない

まずやること:
1. Desktop を起動して現象を確認
2. ProRes MOV, 4K HEVC, H.264 を順に読み込み
3. どの stage で何が起きるかを整理
4. 最小差分で修正
5. build/test を再実行
6. 可能なら手動確認結果をまとめる

起動コマンド:
cd "/Volumes/SamsungPortableSSDX5001/documents/forestone/chibatakumi-portfolio/.worktrees/filmtone-v0-5-1-progressive-loading" && /opt/homebrew/bin/bun run --cwd apps/desktop-film-lab-batch desktop

今回触ってよい主ファイル:
- apps/desktop-film-lab-batch/electron/main.ts
- apps/desktop-film-lab-batch/electron/preload.ts
- apps/desktop-film-lab-batch/electron/video-src-protocol.ts
- apps/desktop-film-lab-batch/src/renderer/App.tsx
- apps/desktop-film-lab-batch/src/renderer/use-progressive-load.ts
- apps/desktop-film-lab-batch/src/renderer/QualityBadge.tsx
- apps/desktop-film-lab-batch/src/renderer/desktop-api.d.ts
- packages/film-lab-ui/src/FilmLabCanvas.tsx
- packages/film-lab-ui/src/FilmLabCanvasPackageEntry.tsx
- packages/film-lab-ui/src/index.ts
- 必要なら messages/ja.json, messages/en.json

やらないこと:
- Web へ横展開
- WebGPU 化
- 大規模リファクタ
- 不具合の切り分け前に構造を大きく変えること

最終的には、何が原因だったか、何を直したか、どのケースで確認できたかを簡潔に報告してください。
```
