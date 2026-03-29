/**
 * Film Lab のグレード数値パラメータ定義（ブラウザ・Remotion 共通の単一の真実）
 */
export const PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "rgbShift",
  "grainIntensity",
  "vignette",
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "fade",
  "highlights",
  "shadows",
  "shadowTone",
  "highlightTone",
  "shadowHue",
  "highlightHue",
] as const;

export type ParamKey = (typeof PARAM_KEYS)[number];

export interface Params {
  exposure: number;
  contrast: number;
  saturation: number;
  temperature: number;
  tint: number;
  rgbShift: number;
  grainIntensity: number;
  vignette: number;
  bloomThreshold: number;
  bloomStrength: number;
  bloomRadius: number;
  halationIntensity: number;
  halationSpread: number;
  halationHue: number;
  fade: number;
  highlights: number;
  shadows: number;
  shadowTone: number;
  highlightTone: number;
  /** シャドウスプリットトーンの色相（度 0〜360） */
  shadowHue: number;
  /** ハイライトスプリットトーンの色相（度 0〜360） */
  highlightHue: number;
}

export function cloneParams(params: Params): Params {
  return { ...params };
}
