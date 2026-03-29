/**
 * @fileoverview .cube（3D LUT）を WebGL1 / GLSL100 向けの **2D テクスチャ**に並べ替える。
 *
 * 主な仕様:
 * - `parseCube` が返す `data` は「赤が最も速く動く」標準 .cube 順（index = r + N·g + N²·b）とみなす。
 * - 出力は幅 N²・高さ N のグリッド。ピクセル (x,y) = (r + g·N, b) に lut(r,g,b) を置く。
 * - Remotion のヘッドレス環境では `sampler3D` が使えないことが多いため、このパック＋シェーダ側トリリニアで代替する。
 *
 * 制限事項:
 * - DOMAIN_MIN / DOMAIN_MAX が 0〜1 以外の .cube は、シェーダ側で別途リマップが必要（現状は 0〜1 前提）。
 */
import type { CubeLUT } from "./cube-parser";

/**
 * 2D テクスチャ用の RGBA Float32 グリッド（Three.js `DataTexture` にそのまま渡せる）。
 */
export interface PackedCubeLut2D {
  /** テクスチャ幅（= N²） */
  width: number;
  /** テクスチャ高さ（= N） */
  height: number;
  /** 1 次元 LUT サイズ N（例: 17） */
  size: number;
  /** 長さ width·height·4 の RGBA 浮動小数点データ */
  data: Float32Array;
}

/**
 * 3D LUT を 2D にパックする（WebGL1 互換の LUT サンプリング用）。
 *
 * @param {CubeLUT} lut - `parseCube` の結果
 * @returns {PackedCubeLut2D} RGBAFloat のグリッド
 */
export function packCubeLutToFloatRgbaGrid(lut: CubeLUT): PackedCubeLut2D {
  const n = lut.size;
  const width = n * n;
  const height = n;
  const data = new Float32Array(width * height * 4);
  const src = lut.data;

  for (let b = 0; b < n; b++) {
    for (let g = 0; g < n; g++) {
      for (let r = 0; r < n; r++) {
        const idx = r + n * g + n * n * b;
        const sx = idx * 4;
        const x = r + g * n;
        const y = b;
        const dst = (y * width + x) * 4;
        data[dst] = src[sx] ?? 0;
        data[dst + 1] = src[sx + 1] ?? 0;
        data[dst + 2] = src[sx + 2] ?? 0;
        data[dst + 3] = src[sx + 3] ?? 1;
      }
    }
  }

  return { width, height, size: n, data };
}
