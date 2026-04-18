# Phase 0 — Electron WebGPU 疎通 + Golden Baseline A

**Budget**: 2h
**目的**: 最大リスク(Electron で WebGPU 動かない)を Day 1 開始前に潰す + 品質測定の基盤を作る

---

## Entry criteria(開始前に確認)

- [ ] `chibatakumi-portfolio` を bun workspace として ready (`bun install` 済み)
- [ ] `apps/desktop-film-lab-batch` が現行 v0.6.2 で `bun run desktop` で起動する(壊れていない)
- [ ] macOS Tahoe 26 以降 / arm64 Mac
- [ ] `DIRECTION.md` と `~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md` を読んだ

---

## Tasks

### T0. Orient (10min)

必読 3 点:
- `@~/.claude/plans/sequential-thinking-gemini-web-swirling-prism.md` (master plan)
- `@apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md` (不変原則)
- `@apps/desktop-film-lab-batch/docs/webgpu-migration/STATUS.md` (進捗)

### T1. Electron WebGPU hello-triangle (60min)

**目的**: `navigator.gpu.requestAdapter()` が Electron で non-null を返すことを確認。必要なら flag を追加。

手順:
```bash
cd apps/desktop-film-lab-batch
bun run desktop
```
現状(WebGL2 path)で起動すること先に確認。

次に DevTools を開き、Console で以下:
```js
(async () => {
  if (!navigator.gpu) {
    console.error('navigator.gpu undefined — WebGPU 完全非対応');
    return;
  }
  const adapter = await navigator.gpu.requestAdapter();
  if (!adapter) {
    console.error('requestAdapter returned null — driver / flag 要確認');
    return;
  }
  const device = await adapter.requestDevice();
  console.log('OK', {
    adapter: adapter.info,
    features: [...adapter.features],
    limits: adapter.limits,
    device
  });
})();
```

#### Case A: 成功(adapter 取得できた)
- adapter.features / adapter.limits を記録(`test/golden/adapter-info.json` に保存)
- flag 追加不要。T2 へ。

#### Case B: `navigator.gpu undefined` または `requestAdapter returned null`
`electron/main.ts` の `app.whenReady()` より**前**に次を追加:
```ts
app.commandLine.appendSwitch('enable-unsafe-webgpu');
app.commandLine.appendSwitch('enable-features', 'Vulkan');
```
再度 `bun run desktop` で起動 → DevTools で再確認。

#### Case C: それでも失敗
- Direction chat に戻る(計画全体を見直し)。Day 1 に進まない

**記録**: 結果を `STATUS.md` の Progress セクション Day 0 State と Notes に書く。

### T2. Golden harness scaffold + Baseline A 取得 (50min)

**目的**: Phase 2-3 で使う PSNR 測定基盤を先に建てる。Baseline A = 現行 WebGL 実出力(clamp 込み)。

#### T2-1. 依存追加
```bash
cd apps/desktop-film-lab-batch
bun add -d playwright @playwright/test pixelmatch pngjs
```
※Electron 起動テストが必要なら `playwright-electron` または自前 Electron spawn 方式を採用(既存の Electron runtime を再利用)。

#### T2-2. テスト画像選定 (10 枚)

`film-lab-core/src/params.ts` の既存プリセット定義から **8 preset** を選定(Direction chat で絞る時間がなかった場合はコード内 preset の **先頭 8 種**を default で使用)。

テスト画像 10 枚 は以下を含むこと:
- ハイライト情報豊富(夕日 / 逆光ポートレート)×2
- 白飛び直前の高キー画像 × 2
- 低キー / シャドウ側ディテール画像 × 2
- 中間調プリセット検証用 × 2
- 肌色が含まれるもの × 2

画像は `apps/desktop-film-lab-batch/test/golden/source-images/` に配置。既存の開発用サンプル画像があれば流用、なければ `film-lab-core` 内の fixtures を探す。

#### T2-3. Harness 作成

`apps/desktop-film-lab-batch/test/golden.harness.ts` を新規作成:
- Playwright(or electron runtime spawn)で app を起動
- source-images 10 枚 × preset 8 種で順次ロード → preset 適用 → canvas の `toDataURL` または `readPixels` で PNG 取得
- `test/golden/baseline-A/{preset}/{image}.png` に保存
- 実行は `bun run test:golden` で走らせる(`package.json` に script 追加)

**重要**:
- Y-flip に注意(既存 `setExportFlipY` 参照)
- canvas pixel ratio を 1.0 に固定(DPR 依存で PSNR 比較が崩れる)
- preset 適用後、**1 frame 描画を待つ** (`requestAnimationFrame` 2 回挟む)

#### T2-4. PSNR utility

`apps/desktop-film-lab-batch/test/golden-psnr.ts` に軽い PSNR 計算ユーティリティを実装(後フェーズで Baseline B 比較時に使用):
```ts
export function psnr(a: Buffer, b: Buffer, width: number, height: number): number {
  // MSE → PSNR (dB)
}
```
pixelmatch ではなく PSNR スカラー出力で良い。単体テスト不要。

#### T2-5. Baseline A capture 実行

```bash
bun run test:golden -- --baseline A
```
`test/golden/baseline-A/` に 80 PNG が揃うことを確認。

---

## Exit criteria(全て必達、未達なら Day 1 に進まない)

- [ ] `navigator.gpu.requestAdapter()` が Electron で non-null(flag 有無を明記)
- [ ] `test/golden/baseline-A/` に 8×10 = 80 PNG
- [ ] `test/golden/adapter-info.json` に GPU 情報記録
- [ ] `test/golden.harness.ts` + `test/golden-psnr.ts` 存在
- [ ] `package.json` に `"test:golden"` script
- [ ] `STATUS.md` の Day 0 State → done、Progress notes 追記
- [ ] `phase-1-handoff.md` を書く(Phase 1 実行用)

---

## Known gotchas / 注意点

- **Playwright + Electron**: `playwright-electron` パッケージが最も楽。なければ `child_process.spawn` で自前起動 + CDP 接続。迷ったら spawn 方式で時短
- **readPixels の Y-flip**: Three.js WebGL は BR 原点、DOM canvas は TL 原点。既存 `setExportFlipY` を使うか、PNG 保存時に反転
- **Preset 適用タイミング**: `setExposure` 等の setter は即反映だが、内部 render は次 RAF。`await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)))` で 2 frame 待つと安全
- **DPR**: window.devicePixelRatio が 2 や 3 だと PNG サイズが変わる。harness 内で明示的に 1.0 に設定(canvas style + attribute)
- **画像選定に時間を使いすぎない**: 完璧より進行。手元サンプルで 10 枚確保できたら OK

---

## Fail-stop 条件

- T1 Case C (WebGPU が Electron で動かない) → **計画中止、direction chat へ**
- Playwright 環境構築が 1h 以上かかりそう → **自前 spawn 方式に切替**、その学びを handoff に記録

---

## First command in Day 1 chat (Phase 0 完了時にここを更新)

(Phase 0 完了時、ここに Phase 1 の starting command を書き加える)

```
# 例:
# @apps/desktop-film-lab-batch/docs/webgpu-migration/DIRECTION.md と
# @apps/desktop-film-lab-batch/docs/webgpu-migration/phase-1-handoff.md を読んで Phase 1 を実行してください
```

---

## 完了時チェックリスト(Phase 0 終了時に記入)

- [ ] Exit criteria 全達
- [ ] `STATUS.md` 更新
- [ ] `phase-1-handoff.md` 作成
- [ ] 本 phase の学びを `Known gotchas` に追記
- [ ] ユーザーに完了報告 + commit 提案

完了報告 template:
> Phase 0 完了。adapter 取得 {成功/flag 付きで成功/失敗}、Baseline A {n}枚取得完了。Phase 1 handoff 書きました。commit しますか？
