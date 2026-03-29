/**
 * スプリットトーンの既定色相（度）とレガシー強度スケール
 *
 * 概要: Next Film Lab 以前は固定 RGB 方向 × スカラーだった。色相 UI 追加後も URL 互換のため、
 *       旧固定ベクトルに最も近い HSL 彩度方向の角度を既定値とする。
 * 仕様: HSL→RGB は CSS / Three.js と同系の標準アルゴリズム（S=1, L=0.5）。
 * 制限: 彩度円上の方向と旧ベクトルは完全一致しない（ドット積最大の角度を採用）。
 */

/** 旧シャドウ固定方向（Viewport レガシー `SHADOW_TONE_DIRECTION` と同値） */
const LEGACY_SHADOW_DIR = [0.12, 0.18, 0.42] as const;

/** 旧ハイライト固定方向 */
const LEGACY_HIGHLIGHT_DIR = [0.38, 0.16, 0.06] as const;

/**
 * HSL（h は度、S/L は 0〜1）から sRGB 線形 0〜1 を返す
 * @param hDegrees - 色相（度）
 * @param s - 彩度 0〜1
 * @param l - 明度 0〜1
 */
export function hslToRgb01(hDegrees: number, s: number, l: number): { r: number; g: number; b: number } {
  const hNorm = (((hDegrees % 360) + 360) % 360) / 360;
  if (s <= 0) {
    return { r: l, g: l, b: l };
  }
  const hue2rgb = (p: number, q: number, t: number): number => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p + (q - p) * 6 * tt;
    if (tt < 1 / 2) return q;
    if (tt < 2 / 3) return p + (q - p) * (2 / 3 - tt) * 6;
    return p;
  };
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const r = hue2rgb(p, q, hNorm + 1 / 3);
  const g = hue2rgb(p, q, hNorm);
  const b = hue2rgb(p, q, hNorm - 1 / 3);
  return { r, g, b };
}

/**
 * 色相（度）に対応する灰色中心の彩度単位ベクトル（長さ 1）
 * @param hueDegrees - 0〜360
 */
export function chromaUnitFromHueDegrees(hueDegrees: number): [number, number, number] {
  const { r, g, b } = hslToRgb01(hueDegrees, 1, 0.5);
  let x = r - 0.5;
  let y = g - 0.5;
  let z = b - 0.5;
  const len = Math.hypot(x, y, z);
  if (len < 1e-9) {
    return [0, 0, 1];
  }
  const inv = 1 / len;
  return [x * inv, y * inv, z * inv];
}

/**
 * 方向ベクトルに最も近い彩度単位の色相（度）を返す
 * @param dir - 非ゼロの 3 成分
 */
export function nearestHueDegreesToDirection(dir: readonly [number, number, number]): number {
  const [dx0, dy0, dz0] = dir;
  const len = Math.hypot(dx0, dy0, dz0);
  if (len < 1e-12) {
    return 0;
  }
  const dx = dx0 / len;
  const dy = dy0 / len;
  const dz = dz0 / len;
  let bestHue = 0;
  let bestDot = -2;
  for (let h = 0; h < 360; h += 1) {
    const [ux, uy, uz] = chromaUnitFromHueDegrees(h);
    const dot = ux * dx + uy * dy + uz * dz;
    if (dot > bestDot) {
      bestDot = dot;
      bestHue = h;
    }
  }
  return bestHue;
}

/** 旧シャドウ方向に揃えた既定色相（`PRESETS` / 欠損キー埋めに使用） */
export const FILM_LAB_DEFAULT_SHADOW_HUE = nearestHueDegreesToDirection(LEGACY_SHADOW_DIR);

/** 旧ハイライト方向に揃えた既定色相 */
export const FILM_LAB_DEFAULT_HIGHLIGHT_HUE = nearestHueDegreesToDirection(LEGACY_HIGHLIGHT_DIR);

/** 旧 `uShadowTint` のスケール（固定ベクトルのノルム） */
export const LEGACY_SHADOW_TONE_MAGNITUDE = Math.hypot(...LEGACY_SHADOW_DIR);

/** 旧ハイライト側のノルム */
export const LEGACY_HIGHLIGHT_TONE_MAGNITUDE = Math.hypot(...LEGACY_HIGHLIGHT_DIR);
