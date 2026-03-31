import { PARAM_KEYS, type Params } from "./params";
import {
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
} from "./split-tone-default-hues";

/**
 * 組み込みプリセット（Next Film Lab と同一数値）
 *
 * grainIntensity は composite で径方向マスク（中心弱・周辺強）が掛かるため、
 * グレインを使うプリセットのみ体感が薄くならないようわずかに上げている（2026-03-30）。
 * grainRadialMix は Pro で 0〜1 調整可。プリセット既定は 1（周辺比重オン）。
 */
export const PRESETS = {
  reset: {
    exposure: 0,
    contrast: 1,
    saturation: 1,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0,
    grainRadialMix: 1,
    vignette: 0,
    bloomThreshold: 0.8,
    bloomStrength: 0,
    bloomRadius: 0.4,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0,
    highlights: 0,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  /**
   * cinematic プリセット（v2・2026-03-31）
   * @description 初見のフィルター感とシアン肌を抑えつつ Teal & Orange の意図は維持。変更理由はリポ外ドキュメントに記載可。
   */
  cinematic: {
    exposure: 0.09,
    contrast: 1.24,
    saturation: 0.87,
    temperature: -0.11,
    tint: 0,
    rgbShift: 0.002,
    lensSoftness: 0,
    grainIntensity: 0.09,
    grainRadialMix: 1,
    vignette: 0.32,
    bloomThreshold: 0.86,
    bloomStrength: 0.24,
    bloomRadius: 0.48,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.025,
    highlights: -0.08,
    shadows: -0.11,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  portra: {
    exposure: 0.2,
    contrast: 1.1,
    saturation: 0.9,
    temperature: 0.1,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.14,
    grainRadialMix: 1,
    vignette: 0.2,
    bloomThreshold: 0.7,
    bloomStrength: 0.15,
    bloomRadius: 0.3,
    halationIntensity: 0.25,
    halationSpread: 20,
    halationHue: 20,
    fade: 0.05,
    highlights: 0,
    shadows: 0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  gold200: {
    exposure: 0.15,
    contrast: 1.2,
    saturation: 1.15,
    temperature: 0.18,
    tint: 0,
    rgbShift: 0.0012,
    lensSoftness: 0,
    grainIntensity: 0.12,
    grainRadialMix: 1,
    vignette: 0.25,
    bloomThreshold: 0.75,
    bloomStrength: 0.2,
    bloomRadius: 0.35,
    halationIntensity: 0.15,
    halationSpread: 18,
    halationHue: 30,
    fade: 0.03,
    highlights: 0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  pro400h: {
    exposure: 0.25,
    contrast: 1.05,
    saturation: 0.85,
    temperature: -0.1,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.075,
    grainRadialMix: 1,
    vignette: 0.15,
    bloomThreshold: 0.65,
    bloomStrength: 0.1,
    bloomRadius: 0.45,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.08,
    highlights: 0.05,
    shadows: 0.15,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  bw: {
    exposure: 0.1,
    contrast: 1.4,
    saturation: 0,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.18,
    grainRadialMix: 1,
    vignette: 0.5,
    bloomThreshold: 0.75,
    bloomStrength: 0.2,
    bloomRadius: 0.6,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0.02,
    highlights: -0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  ektar100: {
    exposure: 0.05,
    contrast: 1.25,
    saturation: 1.3,
    temperature: 0.02,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.05,
    grainRadialMix: 1,
    vignette: 0.15,
    bloomThreshold: 0.85,
    bloomStrength: 0.1,
    bloomRadius: 0.3,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    fade: 0,
    highlights: 0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  superia400: {
    exposure: 0.1,
    contrast: 1.18,
    saturation: 1.08,
    temperature: -0.08,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.115,
    grainRadialMix: 1,
    vignette: 0.2,
    bloomThreshold: 0.8,
    bloomStrength: 0.1,
    bloomRadius: 0.35,
    halationIntensity: 0.1,
    halationSpread: 15,
    halationHue: 10,
    fade: 0.04,
    highlights: 0,
    shadows: 0.05,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
  cinestill800t: {
    exposure: 0.15,
    contrast: 1.15,
    saturation: 0.95,
    temperature: -0.3,
    tint: 0,
    rgbShift: 0.00115,
    lensSoftness: 0,
    grainIntensity: 0.14,
    grainRadialMix: 1,
    vignette: 0.3,
    bloomThreshold: 0.6,
    bloomStrength: 0.35,
    bloomRadius: 0.5,
    halationIntensity: 0.4,
    halationSpread: 25,
    halationHue: 15,
    fade: 0.03,
    highlights: -0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  },
} satisfies Record<string, Params>;

export type PresetName = keyof typeof PRESETS;

/**
 * プリセットの数値が、今の Params と**全部同じ**かを調べる。
 *
 * 概要: URL 共有や保存データの Params から、どの組み込みプリセットに一致するかを逆引きする。
 * 仕様: `PARAM_KEYS` に並ぶキーを順番に比較し、完全一致した最初のプリセット名を返す。
 * 制限: 少しでも数値が違うと一致扱いにしない。近い値を「だいたい同じ」とは判定しない。
 *
 * @param params - 照合したい Film Lab のパラメータ
 */
export function findMatchingPreset(params: Params): PresetName | null {
  for (const [name, preset] of Object.entries(PRESETS) as [PresetName, Params][]) {
    if (PARAM_KEYS.every((key) => preset[key] === params[key])) {
      return name;
    }
  }
  return null;
}

/**
 * プリセットバーに並べる表示用メタ情報。
 *
 * 概要: ボタンの見出しと短い説明文だけをまとめ、Web / Desktop で同じ順番・同じ文言を使えるようにする。
 * 仕様: `name` は `PRESETS` のキーと一致し、UI はこの配列順で表示できる。
 * 制限: 見た目用の文言だけを持つ。色や数値パラメータ自体は `PRESETS` を参照する。
 */
export const PRESET_BUTTONS: {
  name: PresetName;
  label: string;
  subtitle: string;
}[] = [
  { name: "cinematic", label: "Cinematic", subtitle: "Teal & Orange" },
  { name: "portra", label: "Portra", subtitle: "Warm Pastel" },
  { name: "gold200", label: "Gold 200", subtitle: "Saturated Warm" },
  { name: "pro400h", label: "Pro 400H", subtitle: "Cool Soft" },
  { name: "ektar100", label: "Ektar 100", subtitle: "Vivid Sharp" },
  { name: "superia400", label: "Superia", subtitle: "Cool Green" },
  { name: "cinestill800t", label: "CineStill", subtitle: "Tungsten Glow" },
  { name: "bw", label: "B&W", subtitle: "Classic Mono" },
  { name: "reset", label: "Reset", subtitle: "No Grade" },
];
