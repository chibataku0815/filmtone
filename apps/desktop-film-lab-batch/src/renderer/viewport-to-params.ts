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
  out.halationHue =
    typeof raw.halationHue === "number"
      ? raw.halationHue
      : halationHueFallback;
  return out;
}
