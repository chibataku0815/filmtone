/**
 * グレード JSON のエクスポート（Web / Remotion 互換のラッパー形）
 *
 * @overview findMatchingPreset で look ID を決め、grade 本体は Params のまま保存する。
 */
import {
  lookIdForPreset,
  PRESET_VERSION,
  type Params,
  type PresetName,
} from "film-lab-core";
import { findMatchingPreset } from "film-lab-core";

/**
 * @param params - 現在のグレード
 * @returns 整形済み JSON 文字列（filmLookGradeInput に近い形、LUT パスは含めない）
 */
export function exportGradeJsonText(params: Params): string {
  const preset: PresetName = findMatchingPreset(params) ?? "cinematic";
  const payload = {
    lookPresetId: lookIdForPreset(preset),
    presetVersion: PRESET_VERSION,
    grade: params,
  };
  return `${JSON.stringify(payload, null, 2)}\n`;
}
