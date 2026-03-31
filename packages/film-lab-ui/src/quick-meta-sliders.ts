/**
 * @fileoverview Quick モード専用の 3 メタスライダー（フィルム調・新旧・ダイナミック）と `Params` の対応。
 */

import type { Params } from "film-lab-core";

/** 3 本のメタスライダーを区別するための名前（i18n キーと対応させる） */
export type QuickMetaAxis = "filmLook" | "era" | "dynamics";

const clamp01 = (value: number): number => Math.max(0, Math.min(1, value));

const lerp = (from: number, to: number, t: number): number => from + (to - from) * t;

const clamp = (value: number, lo: number, hi: number): number =>
  Math.max(lo, Math.min(hi, value));

/**
 * メタスライダー 1 本が担当するキーだけを `value01`（0〜1）に沿って上書きするパッチを作る。
 */
export function quickMetaPatchForValue(axis: QuickMetaAxis, value01: number): Partial<Params> {
  const t = clamp01(value01);
  if (axis === "filmLook") {
    return {
      saturation: clamp(1 + (t - 0.5) * 2.2, 0, 3),
      temperature: clamp((t - 0.5) * 1.4, -1, 1),
      grainIntensity: clamp(t * t * 0.48, 0, 0.5),
      vignette: clamp(t * 0.38, 0, 1),
      tint: clamp((t - 0.5) * 0.55, -1, 1),
    };
  }
  if (axis === "era") {
    return {
      fade: clamp(t * 0.29, 0, 0.3),
      halationIntensity: clamp(t * 0.92, 0, 1),
      halationSpread: clamp(lerp(7, 34, t), 0, 50),
    };
  }
  return {
    exposure: clamp((t - 0.5) * 2.5, -3, 3),
    contrast: clamp(1 + (t - 0.5) * 0.95, 0, 3),
    bloomStrength: clamp(t * t * 1.28, 0, 3),
    bloomThreshold: clamp(lerp(0.86, 0.52, t), 0, 1),
    bloomRadius: clamp(lerp(0.2, 0.62, t), 0, 1),
  };
}

/**
 * 現在の `params` から Quick のつまみ位置（0〜1）を **だいたい**復元する（合成表示用）。
 */
export function quickMetaDisplayValue(axis: QuickMetaAxis, params: Params): number {
  if (axis === "filmLook") {
    const tSat = 0.5 + (params.saturation - 1) / 2.2;
    const tTemp = 0.5 + params.temperature / 1.4;
    const tGrain = params.grainIntensity <= 0 ? 0 : Math.sqrt(params.grainIntensity / 0.48);
    const tVig = params.vignette / 0.38;
    const tTint = 0.5 + params.tint / 0.55;
    return clamp01(
      clamp01(tSat) * 0.38 +
        clamp01(tTemp) * 0.27 +
        clamp01(tGrain) * 0.18 +
        clamp01(tVig) * 0.1 +
        clamp01(tTint) * 0.07,
    );
  }
  if (axis === "era") {
    const tFade = params.fade / 0.29;
    const tHala =
      params.halationIntensity <= 0 ? 0 : params.halationIntensity / 0.92;
    const tSpread = (params.halationSpread - 7) / (34 - 7);
    return clamp01((clamp01(tFade) * 0.45 + clamp01(tHala) * 0.4 + clamp01(tSpread) * 0.15));
  }
  const tExp = 0.5 + params.exposure / 2.5;
  const tCon = 0.5 + (params.contrast - 1) / 0.95;
  const tBloom =
    params.bloomStrength <= 0 ? 0 : Math.sqrt(params.bloomStrength / 1.28);
  const tTh = (0.86 - params.bloomThreshold) / (0.86 - 0.52);
  const tRad = (params.bloomRadius - 0.2) / (0.62 - 0.2);
  return clamp01(
    clamp01(tExp) * 0.28 +
      clamp01(tCon) * 0.22 +
      clamp01(tBloom) * 0.32 +
      clamp01(tTh) * 0.1 +
      clamp01(tRad) * 0.08,
  );
}
