import type { PresetName } from "./presets";

/**
 * スキーマと JSON（共有 URL・Remotion）で使うプリセット定義のバージョンタグ。
 * 値を変えると Look ID が変わり互換に影響する。手順は `docs/PRESET_VERSIONING.md`。
 */
export const PRESET_VERSION = "v1" as const;

/**
 * iOS-only preset / kernel version, decoupled from shared `PRESET_VERSION` so
 * iOS can bump kernel math (`OpticalKernels.baseGradeV2` /
 * `filmCompressionV3`) without invalidating desktop / web / Remotion Look IDs.
 *
 * Stamped onto `SavedLookEntry.presetVersion` at save time and consulted by
 * `FilmtoneExportSession.applyBaseGradeStage` /
 * `FilmtoneExportSession.applyToneCompressionStage` to dispatch v1 vs v2
 * kernels. v1 saved Looks continue to render through v1 kernels; new
 * built-ins and new user-saved Looks render through v2.
 */
export const IOS_PRESET_VERSION = "v2" as const;

/**
 * 機械可読 Look ID（CD ストリームの命名規則）
 */
export function lookIdForPreset(name: PresetName): string {
  return `look:mp:${String(name)}:${PRESET_VERSION}`;
}

export const LOOK_ID_BY_PRESET: Record<PresetName, string> = {
  reset: lookIdForPreset("reset"),
  cinematic: lookIdForPreset("cinematic"),
  portra: lookIdForPreset("portra"),
  gold200: lookIdForPreset("gold200"),
  pro400h: lookIdForPreset("pro400h"),
  bw: lookIdForPreset("bw"),
  ektar100: lookIdForPreset("ektar100"),
  superia400: lookIdForPreset("superia400"),
  cinestill800t: lookIdForPreset("cinestill800t"),
  velvia50: lookIdForPreset("velvia50"),
};
