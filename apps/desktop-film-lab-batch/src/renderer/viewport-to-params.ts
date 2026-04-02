/**
 * Viewport.getParams() の戻り値を film-lab-core の Params に近づける。
 *
 * @overview getParams は halationColor（hex）を返し Params の halationHue は含まないため、フォールバックを使う。
 * @limitations LUT はここでは復元しない。
 */
import {
  PARAM_KEYS,
  cloneParams,
  PRESETS,
  type Params,
} from "film-lab-core";

/**
 * 0.4.0 の render process で追加した数値キー。
 *
 * @remarks
 * shared contract の worktree がまだ反映されていない状態でも、preview から export まで
 * 値を落とさないために、ここでは raw の数値をそのまま運ぶ。
 */
const renderProcessParamKeys = [
  "compressionAmount",
  "compressionRange",
  "printContrast",
  "cyan",
  "magenta",
  "yellow",
] as const;

/**
 * @param raw - Viewport.getParams() の戻り値
 * @param halationHueFallback - halationHue が raw に無いときの既定
 */
export function viewportRecordToParams(
  raw: Record<string, number | string>,
  halationHueFallback: number,
): Params {
  const out = cloneParams(PRESETS.cinematic);
  for (const key of PARAM_KEYS) {
    if (key === "halationHue") continue;
    const v = raw[key];
    if (typeof v === "number") {
      (out as Record<string, number>)[key] = v;
    }
  }
  for (const key of renderProcessParamKeys) {
    const v = raw[key];
    (out as Record<string, number>)[key] =
      typeof v === "number"
        ? v
        : key === "compressionRange"
          ? 0.5
          : 0;
  }
  out.halationHue =
    typeof raw.halationHue === "number"
      ? raw.halationHue
      : halationHueFallback;
  return out;
}
