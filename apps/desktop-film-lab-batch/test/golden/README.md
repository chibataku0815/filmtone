# Golden Test Baselines

Phase 0 WebGPU migration の品質保証基盤。

## Files

- `adapter-info.json` — Phase 0 T1 で CDP 経由取得した WebGPU adapter 情報(vendor / features / limits)。source: `cdp-automated-phase-0`
- `source-images/` — 10 枚の synthetic テスト画像 + `manifest.json`。seed 固定で決定論的再生成可能。Phase 1 で real photography に差し替え予定の場合 manifest を更新。
- `baseline-A/{preset}/{image}.jpg` — 現行 WebGL 実出力(clamp 込み)、**JPEG Q=95**、80 枚。
- `baseline-B/` — Phase 1 で生成(post-hoc linearized、WebGPU path)、PSNR 比較の target。

## Baseline A encoding 注記

Baseline A は JPEG Q=95 で保存。理由:
- PNG 時合計 131MB → リポジトリ膨張を避けるため 50MB 超で JPEG 化(Phase 0 plan §4 Size gate)
- Baseline A は smoke / regression reference(PSNR ≥ 40dB の target は **Baseline B**)。JPEG Q=95 の劣化(~0.5 dB 級)は smoke 用途で許容

Phase 1 で Baseline B を生成する際は:
- 同じ 8 preset × 10 image = 80 枚
- **PNG** で保存(PSNR 測定の reference、JPEG 劣化を挟まない)
- Baseline A と目視比較して regression 検出

## Re-run

```bash
# 画像再生成(synthetic):
bun run test/golden/generate-source-images.ts

# Baseline A 再取得:
FILMTONE_GOLDEN_BASELINE=A bun run test:golden:baseline-a
```

Baseline A の capture は dev server (Vite :5173) が稼働していることが前提。`bun run desktop` 起動後、別 terminal で再実行。

## Known gotchas

- harness の `captureOne` は `canvas.toDataURL('image/png')` で読み出し。Phase 1 で Baseline B 生成時、gamma 整合を確認(on-screen の render と比較、plan R1 / F4)。
- DPR 1.0 強制: harness が `__filmtoneTest.setCanvasSize(1280, 720)` で canvas 実サイズを固定。Retina での backing store 2× を打ち消す。
- Y-flip: `setExportFlipY(true)` で composite pass のみフリップ。capture 後にポスト flip しない(二重反転防止)。
