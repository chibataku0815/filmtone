/**
 * Film Lab Params → ffmpeg -vf の近似変換（メインプロセス専用）
 *
 * @overview プレビュー（WebGL シェーダー）とは一致しない。高速トランスコードでプリセットの「雰囲気」だけ寄せる。
 * @limitations bloom / halation / スプリットトーンの色相は未実装。grain・vignette は ffmpeg 素朴表現。
 */
import type { Params } from "film-lab-core";

/**
 * @description 数値を ffmpeg に渡す短い文字列へ
 */
function fmt(n: number): string {
  const t = Math.round(n * 10000) / 10000;
  if (Number.isInteger(t)) return String(t);
  return String(t);
}

/**
 * @description min〜max に収める
 */
function clamp(n: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, n));
}

/**
 * @description メモリ上の Params からカンマ区切りフィルタ連鎖を生成（lut3d / fps / scale は含めない）
 */
export function buildGradeApproximationVF(params: Params): string {
  const p = params;
  const parts: string[] = [];

  const brightness = clamp(p.exposure * 0.34, -0.48, 0.48);
  const contrast = clamp(p.contrast, 0.35, 2.85);
  const saturation = clamp(p.saturation, 0, 2.85);
  const gamma = clamp(
    1 + p.fade * 0.1 + p.shadows * 0.07 - p.highlights * 0.055,
    0.78,
    1.28,
  );

  parts.push(
    `eq=contrast=${fmt(contrast)}:brightness=${fmt(brightness)}:saturation=${fmt(saturation)}:gamma=${fmt(gamma)}`,
  );

  const rm = clamp(p.temperature * -0.11 + p.tint * 0.045, -0.24, 0.24);
  const bm = clamp(p.temperature * 0.1 + p.tint * 0.035, -0.24, 0.24);
  const gm = clamp(p.tint * -0.055, -0.16, 0.16);
  if (Math.abs(rm) > 0.003 || Math.abs(bm) > 0.003 || Math.abs(gm) > 0.003) {
    parts.push(
      `colorbalance=rm=${fmt(rm)}:bm=${fmt(bm)}:gm=${fmt(gm)}`,
    );
  }

  const hueDeg = clamp(p.rgbShift * 20, -14, 14);
  if (Math.abs(hueDeg) > 0.15) {
    parts.push(`hue=h=${fmt(hueDeg)}`);
  }

  /**
   * @description WebGL composite は `1 - uVignette * dist²`（周辺は緩やか）。ffmpeg の `vignette=angle`
   * はレンズモデルで、旧式 `PI*(0.14 + v*0.95)` は同じ数値でも周辺が潰れやすかった。
   * 既定角 PI/5 付近を底にし、√v で中間を抑えてプレビューに寄せる。
   */
  if (p.vignette > 0.015) {
    const v = clamp(p.vignette, 0, 1);
    const angleMin = Math.PI / 5;
    const angleMax = Math.PI / 2;
    const angle = angleMin + Math.sqrt(v) * (angleMax - angleMin) * 0.45;
    parts.push(`vignette=angle=${fmt(angle)}:mode=forward`);
  }

  if (p.grainIntensity > 0.035) {
    const amt = Math.round(clamp(p.grainIntensity, 0, 1) * 22);
    parts.push(`noise=alls=${amt}:allf=t`);
  }

  return parts.join(",");
}
