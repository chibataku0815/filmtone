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
  /** 周辺ほど等方ブラーを足すレンズの柔らかさ（0〜1、Pro）。中心固定。 */
  "lensSoftness",
  "grainIntensity",
  // 0=一様、1=周辺強め（既定1で後方互換）
  "grainRadialMix",
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
  /** レンズ周辺のソフトネス（0〜1）。色収差の周辺ソフトとは別 param。 */
  lensSoftness: number;
  grainIntensity: number;
  /** グレインの周辺比重（0〜1）。0 で径方向マスクなし、1 で現行の周辺強め。 */
  grainRadialMix: number;
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
