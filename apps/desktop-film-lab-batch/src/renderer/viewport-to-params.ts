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

type ViewportParamKey = Exclude<(typeof PARAM_KEYS)[number], "halationHue">;

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

function isViewportParamKey(key: (typeof PARAM_KEYS)[number]): key is ViewportParamKey {
  return key !== "halationHue";
}

/**
 * @param raw - Viewport.getParams() の戻り値
 * @param halationHueFallback - halationHue が raw に無いときの既定
 */
export function viewportRecordToParams(
  raw: Record<string, number | string>,
  halationHueFallback: number,
): Params {
  const out = cloneParams(PRESETS.cinematic);
  for (const key of PARAM_KEYS.filter(isViewportParamKey)) {
    const v = raw[key];
    if (typeof v === "number") {
      out[key] = v;
    }
  }
  for (const key of renderProcessParamKeys) {
    const v = raw[key];
    out[key] = typeof v === "number" ? v : key === "compressionRange" ? 0.5 : 0;
  }
  out.halationHue =
    typeof raw.halationHue === "number"
      ? raw.halationHue
      : halationHueFallback;
  return out;
}
