import type { BaseLookName } from "./presets";

/**
 * スキーマと JSON（共有 URL・Remotion）で使う Base Look レシピのバージョンタグ。
 * 値を変えると Look ID が変わり互換に影響する。手順は `docs/PRESET_VERSIONING.md`。
 */
export const LOOK_RECIPE_VERSION = "v1" as const;

/**
 * iOS-only kernel version, decoupled from shared `LOOK_RECIPE_VERSION` so
 * iOS can bump kernel math (`OpticalKernels.baseGradeV2` /
 * `filmCompressionV2`) without invalidating desktop / web / Remotion Look IDs.
 *
 * Stamped onto `SavedLookEntry.presetVersion` (Swift と shared field 名は不変) at
 * save time and consulted by `FilmtoneExportSession.applyBaseGradeStage` /
 * `FilmtoneExportSession.applyToneCompressionStage` to dispatch v1 vs v2
 * kernels. v1 saved Looks continue to render through v1 kernels; new
 * built-ins and new user-saved Looks render through v2.
 */
export const IOS_PRESET_VERSION = "v2" as const;

/**
 * 機械可読 Look ID（CD ストリームの命名規則）
 */
export function lookIdForBaseLook(name: BaseLookName): string {
  return `look:mp:${String(name)}:${LOOK_RECIPE_VERSION}`;
}

export const LOOK_ID_BY_BASE_LOOK: Record<BaseLookName, string> = {
  reset: lookIdForBaseLook("reset"),
  cinematic: lookIdForBaseLook("cinematic"),
  portra: lookIdForBaseLook("portra"),
  gold200: lookIdForBaseLook("gold200"),
  pro400h: lookIdForBaseLook("pro400h"),
  bw: lookIdForBaseLook("bw"),
  ektar100: lookIdForBaseLook("ektar100"),
  superia400: lookIdForBaseLook("superia400"),
  cinestill800t: lookIdForBaseLook("cinestill800t"),
  velvia50: lookIdForBaseLook("velvia50"),
};

// === Deprecated Preset-named aliases (kept for legacy consumers) ===
// `IOS_PRESET_VERSION` は kernel dispatch tag なので alias 対象外 (Swift と shared)。
// `gradeMatchesBaseLook` は `schema.ts` 側の export とする (look-ids → schema → look-ids
// の循環依存を避けるため、ここからは re-export しない)。
/** @deprecated Use {@link LOOK_RECIPE_VERSION}. */
export const PRESET_VERSION = LOOK_RECIPE_VERSION;
/** @deprecated Use {@link lookIdForBaseLook}. */
export const lookIdForPreset = lookIdForBaseLook;
/** @deprecated Use {@link LOOK_ID_BY_BASE_LOOK}. */
export const LOOK_ID_BY_PRESET = LOOK_ID_BY_BASE_LOOK;
