/**
 * グレード JSON のエクスポート（Web / Remotion 互換のラッパー形）
 *
 * @overview findMatchingPreset で look ID を決め、grade 本体は Params のまま保存する。
 */
import {
  lookIdForPreset,
  PRESET_VERSION,
  type FilmLookGradeInputProps,
  type Params,
  type PresetName,
} from "film-lab-core";
import { findMatchingPreset } from "film-lab-core";

/**
 * @param params - 現在のグレード
 * @returns grade JSON の構造化 payload
 */
export function buildGradeJsonPayload(params: Params): FilmLookGradeInputProps {
  const preset: PresetName = findMatchingPreset(params) ?? "cinematic";
  return {
    lookPresetId: lookIdForPreset(preset),
    presetVersion: PRESET_VERSION,
    grade: params,
  };
}

/**
 * @param params - 現在のグレード
 * @returns 整形済み JSON 文字列（filmLookGradeInput に近い形、LUT パスは含めない）
 */
export function exportGradeJsonText(params: Params): string {
  const payload = buildGradeJsonPayload(params);
  return `${JSON.stringify(payload, null, 2)}\n`;
}
