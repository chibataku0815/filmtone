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
  /** ハレーション発火の輝度閾値（0〜1、旧ハードコード 0.6 を可変化） */
  "halationThreshold",
  /** ハレーションのミップウェイト分布（0=狭い、1=広い。halationSpread の後継） */
  "halationRadius",
  /** ブルーム閾値のソフトニー幅（0=ハード、1=最大ソフト） */
  "bloomSoftKnee",
  /** ハレーション閾値のソフトニー幅（0=ハード、1=最大ソフト） */
  "halationSoftKnee",
  "fade",
  "highlights",
  "shadows",
  "shadowTone",
  "highlightTone",
  "shadowHue",
  "highlightHue",
  // === 0.4.0 新規: Film Process (Negative Stage / Print Stage) ===
  /** フィルム latitude 圧縮量（0=なし、1=フル圧縮）。range: 0–1 */
  "compressionAmount",
  /** 圧縮の shoulder/toe 幅（0=急峻、1=緩やか）。range: 0–1 */
  "compressionRange",
  /** 印画紙コントラスト（0=no effect、1=最大硬調）。range: 0–1 */
  "printContrast",
  /** CMY enlarger color head: Cyan filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "cyan",
  /** CMY enlarger color head: Magenta filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "magenta",
  /** CMY enlarger color head: Yellow filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "yellow",
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
  /** ハレーション発火の輝度閾値（0〜1） */
  halationThreshold: number;
  /** ハレーションのミップウェイト分布（0〜1。halationSpread の後継） */
  halationRadius: number;
  /** ブルーム閾値のソフトニー幅（0〜1） */
  bloomSoftKnee: number;
  /** ハレーション閾値のソフトニー幅（0〜1） */
  halationSoftKnee: number;
  fade: number;
  highlights: number;
  shadows: number;
  shadowTone: number;
  highlightTone: number;
  /** シャドウスプリットトーンの色相（度 0〜360） */
  shadowHue: number;
  /** ハイライトスプリットトーンの色相（度 0〜360） */
  highlightHue: number;
  // === 0.4.0 新規: Film Process ===
  /** フィルム latitude 圧縮量（0=なし、1=フル圧縮）。negative ステージに適用。 */
  compressionAmount: number;
  /** 圧縮の shoulder/toe 幅（0=急峻、1=緩やか）。compressionAmount > 0 のとき有効。 */
  compressionRange: number;
  /** 印画紙コントラスト（0=no effect、1=最大硬調）。print ステージに適用。 */
  printContrast: number;
  /** CMY enlarger color head: Cyan filter（-1〜1、0=ニュートラル）。print ステージ。 */
  cyan: number;
  /** CMY enlarger color head: Magenta filter（-1〜1、0=ニュートラル）。print ステージ。 */
  magenta: number;
  /** CMY enlarger color head: Yellow filter（-1〜1、0=ニュートラル）。print ステージ。 */
  yellow: number;
}

export function cloneParams(params: Params): Params {
  return { ...params };
}
