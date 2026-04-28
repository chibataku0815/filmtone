# 3D LUT（.cube）の 2D パック（WebGL1 / Remotion 用）

## 目的

ヘッドレス Chromium（SwiftShader 等）では **`sampler3D` / `Data3DTexture` が使えない**ことがあり、Film Lab 本番（WebGL2）とは GPU 機能が異なる。Remotion 側では **RGBA Float の 2D `DataTexture`** に LUT を並べ替え、フラグメントシェーダで **トリリニア補間**する。

## レイアウト

- `.cube` の並びは **赤が最速**（index \(i = r + N g + N^2 b\)）とする（`parseCube` と一致）。
- テクスチャサイズ: **幅 \(N^2\)** × **高さ \(N\)**。
- ピクセル \((x,y) = (r + g N,\; b)\) に `lut(r,g,b)` の RGB を格納（A は 1）。

## API

- `packCubeLutToFloatRgbaGrid(lut: CubeLUT)` — `packages/film-lab-core/src/lut-pack-2d.ts`
- シェーダ側 UV: `uv = (vec2(r + g*N, b) + 0.5) / vec2(N*N, N)`

## 制限

- `DOMAIN_MIN` / `DOMAIN_MAX` が 0〜1 以外のときは、シェーダで入力色のリマップが必要（現状の Remotion シェーダは 0〜1 前提）。
- ブラウザ Film Lab の **8-pass や Bloom** とは別パイプのため、G2 の許容差は `docs/remotion/remotion-film-lab-g2-golden.md` に従う。
