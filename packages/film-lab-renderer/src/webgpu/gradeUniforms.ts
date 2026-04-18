/**
 * gradeUniforms — TS packer for the 9-vec4 WGSL `Grade` struct.
 *
 * Mirrors `filmlab.frag.wgsl` layout exactly. Missing fields fall back to
 * neutral defaults so a partial params record (e.g. preset resolution
 * only) still yields a valid upload. Consumers should feed the full
 * `BuiltViewportParams` blob from `viewport-to-params` / `batch-pipeline`.
 *
 * Layout (vec4 index × 4 floats = 36 floats = 144 bytes):
 *   0: (exposure, contrast, saturation, _pad)
 *   1: (temperature, tint, fade, rgbShift)
 *   2: (highlights, shadows, compAmount, compRange)
 *   3: (shadowTint.r, shadowTint.g, shadowTint.b, _pad)
 *   4: (highlightTint.r, highlightTint.g, highlightTint.b, _pad)
 *   5: (splitPosition, lut1Intensity, lut1Enabled, lut2Intensity)
 *   6: (lut2Enabled, cyan, magenta, yellow)
 *   7: (printContrast, fitMode, imgResX, imgResY)
 *   8: (resolutionX, resolutionY, time, _pad)
 */

import {
  chromaUnitFromHueDegrees,
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE,
} from "film-lab-core";

export const GRADE_UNIFORM_FLOATS = 36;
export const GRADE_UNIFORM_BYTES = GRADE_UNIFORM_FLOATS * 4;

export interface GradeFrameState {
  /** Canvas render resolution. */
  resolutionX: number;
  resolutionY: number;
  /** Source image / video resolution, used by the cover/contain fit math. */
  imgResX: number;
  imgResY: number;
  /** 0.0 = cover, 1.0 = contain. */
  fitMode: number;
  /** Seconds since start — feeds time-based effects (grain etc.). */
  time: number;
  /** Before/after split slider in [-1, 1]; -1 disables the split UI. */
  splitPosition: number;
  /** Raw grade parameters (keys in film-lab-core `Params`). */
  params: Record<string, number | string | boolean>;
  /** LUT1 intensity (multiplied against lut1Enabled at pack time). */
  lut1Intensity: number;
  lut1Enabled: boolean;
  lut2Intensity: number;
  lut2Enabled: boolean;
}

export function packGradeUniforms(
  state: GradeFrameState,
  out: Float32Array = new Float32Array(GRADE_UNIFORM_FLOATS),
): Float32Array {
  if (out.length !== GRADE_UNIFORM_FLOATS) {
    throw new Error(
      `packGradeUniforms: out length ${out.length} !== ${GRADE_UNIFORM_FLOATS}`,
    );
  }
  const p = state.params;
  const n = (key: string, fallback: number): number => {
    const v = p[key];
    return typeof v === "number" ? v : fallback;
  };
  const shadowHue = n("shadowHue", FILM_LAB_DEFAULT_SHADOW_HUE);
  const shadowTone = n("shadowTone", 0);
  const [sx, sy, sz] = chromaUnitFromHueDegrees(shadowHue);
  const shadowMag = shadowTone * LEGACY_SHADOW_TONE_MAGNITUDE;
  const highlightHue = n("highlightHue", FILM_LAB_DEFAULT_HIGHLIGHT_HUE);
  const highlightTone = n("highlightTone", 0);
  const [hx, hy, hz] = chromaUnitFromHueDegrees(highlightHue);
  const highlightMag = highlightTone * LEGACY_HIGHLIGHT_TONE_MAGNITUDE;

  // vec4 0 — exposure / contrast / saturation
  out[0] = n("exposure", 0);
  out[1] = n("contrast", 1);
  out[2] = n("saturation", 1);
  out[3] = 0;
  // vec4 1 — temperature / tint / fade / rgbShift
  out[4] = n("temperature", 0);
  out[5] = n("tint", 0);
  out[6] = n("fade", 0);
  out[7] = n("rgbShift", 0);
  // vec4 2 — highlights / shadows / compAmount / compRange
  out[8] = n("highlights", 0);
  out[9] = n("shadows", 0);
  out[10] = n("compressionAmount", 0);
  out[11] = n("compressionRange", 0.5);
  // vec4 3 — shadow tint RGB
  out[12] = sx * shadowMag;
  out[13] = sy * shadowMag;
  out[14] = sz * shadowMag;
  out[15] = 0;
  // vec4 4 — highlight tint RGB
  out[16] = hx * highlightMag;
  out[17] = hy * highlightMag;
  out[18] = hz * highlightMag;
  out[19] = 0;
  // vec4 5 — splitPosition / LUT1 intensity+enabled / LUT2 intensity
  out[20] = state.splitPosition;
  out[21] = state.lut1Intensity;
  out[22] = state.lut1Enabled ? 1 : 0;
  out[23] = state.lut2Intensity;
  // vec4 6 — LUT2 enabled / print CMY
  out[24] = state.lut2Enabled ? 1 : 0;
  out[25] = n("cyan", 0);
  out[26] = n("magenta", 0);
  out[27] = n("yellow", 0);
  // vec4 7 — print contrast / fit / image resolution
  out[28] = n("printContrast", 0);
  out[29] = state.fitMode;
  out[30] = state.imgResX;
  out[31] = state.imgResY;
  // vec4 8 — render resolution / time
  out[32] = state.resolutionX;
  out[33] = state.resolutionY;
  out[34] = state.time;
  out[35] = 0;

  return out;
}
