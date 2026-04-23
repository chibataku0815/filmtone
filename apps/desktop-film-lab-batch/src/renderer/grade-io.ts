/**
 * グレード JSON のエクスポート（Web / Remotion 互換のラッパー形）
 *
 * @overview findMatchingPreset で look ID を決め、grade 本体は Params のまま保存する。
 */
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  lookIdForPreset,
  PRESET_VERSION,
  type FilmLookGradeInputProps,
  type Params,
  type PresetName,
} from "film-lab-core";
import { findMatchingPreset } from "film-lab-core";
import type { BatchDepthTrackSource } from "./depth-track";

type GradeJsonPayload = FilmLookGradeInputProps & {
  depthTrack?: BatchDepthTrackSource;
};

/**
 * @param params - 現在のグレード
 * @returns grade JSON の構造化 payload
 */
export function buildGradeJsonPayload(
  params: Params,
  depthTrack: BatchDepthTrackSource | null = null,
): GradeJsonPayload {
  const preset: PresetName =
    findMatchingPreset(params) ?? FILMTONE_DEFAULT_BASE_PRESET;
  return {
    lookPresetId: lookIdForPreset(preset),
    presetVersion: PRESET_VERSION,
    grade: params,
    ...(depthTrack ? { depthTrack } : {}),
  };
}

/**
 * @param params - 現在のグレード
 * @returns 整形済み JSON 文字列（filmLookGradeInput に近い形、LUT パスは含めない）
 */
export function exportGradeJsonText(
  params: Params,
  depthTrack: BatchDepthTrackSource | null = null,
): string {
  const payload = buildGradeJsonPayload(params, depthTrack);
  return `${JSON.stringify(payload, null, 2)}\n`;
}
