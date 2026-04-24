/**
 * compositeUniforms — TS packer for the composite.wgsl `Composite` struct.
 *
 * Phase 2 T2-3 + v1.0 parity (2026-04-19). Mirrors the 6-vec4 layout defined
 * in `shaders/composite.frag.wgsl.ts`. Numeric params fall back to neutral
 * defaults so a partial params record still yields a valid upload.
 *
 * Layout (6 vec4 × 4 floats = 24 floats = 96 bytes):
 *   0: (resolutionX, resolutionY, imageResX, imageResY)
 *   1: (bloomStrength, halationIntensity, vignette, grainIntensity)
 *   2: (grainSize, grainRadialMix, fitMode, time)
 *   3: (lensSoftness, aberrationEdgeSoften, diffusion, depthMistGain)
 *   4: (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
 *   5: (rayAngleProbe, _, _, _)
 *
 * `depthMistGain` is the shared depth-aware Mist gain (0 = uniform mist,
 * 1 = full depth modulation). Values >= 1.5 stay reserved for the internal
 * raw-depth debug view. See `composite.frag.wgsl.ts` binding(7) uDepth.
 */

import { clampGrainIntensity } from "film-lab-core";

export const COMPOSITE_UNIFORM_FLOATS = 24;
export const COMPOSITE_UNIFORM_BYTES = COMPOSITE_UNIFORM_FLOATS * 4;
const ABERRATION_EDGE_SOFTEN_SCALE = 32;

export interface CompositeFrameState {
  resolutionX: number;
  resolutionY: number;
  imgResX: number;
  imgResY: number;
  fitMode: number;
  time: number;
  params: Record<string, number | string | boolean>;
}

export function packCompositeUniforms(
  state: CompositeFrameState,
  out: Float32Array = new Float32Array(COMPOSITE_UNIFORM_FLOATS),
): Float32Array {
  if (out.length !== COMPOSITE_UNIFORM_FLOATS) {
    throw new Error(
      `packCompositeUniforms: out length ${out.length} !== ${COMPOSITE_UNIFORM_FLOATS}`,
    );
  }
  const n = (key: string, fallback: number): number => {
    const v = state.params[key];
    return typeof v === "number" ? v : fallback;
  };
  const clamp01 = (value: number): number => Math.min(1, Math.max(0, value));
  out[0] = state.resolutionX;
  out[1] = state.resolutionY;
  out[2] = state.imgResX;
  out[3] = state.imgResY;
  out[4] = n("bloomStrength", 0);
  out[5] = n("halationIntensity", 0);
  out[6] = n("vignette", 0);
  out[7] = clampGrainIntensity(n("grainIntensity", 0));
  out[8] = n("grainSize", 0);
  out[9] = n("grainRadialMix", 1);
  out[10] = state.fitMode;
  out[11] = state.time;
  out[12] = n("lensSoftness", 0);
  out[13] = clamp01(n("rgbShift", 0) * ABERRATION_EDGE_SOFTEN_SCALE);
  out[14] = clamp01(n("diffusion", 0));
  // depthMistGain: 0..1 = shared depth-aware Mist modulation.
  // Values >= 1.5 are reserved for the internal raw-depth debug view.
  out[15] = Math.min(2, Math.max(0, n("depthMistGain", 0)));
  out[16] = 0;
  out[17] = 0;
  out[18] = 0;
  out[19] = 0;
  out[20] = n("rayAngleProbe", 0);
  out[21] = 0;
  out[22] = 0;
  out[23] = 0;
  return out;
}

/**
 * Parse a `#rrggbb` / `#rgb` hex string into linear-ish 0..1 components.
 * Matches the WebGL backend's `hexToVec3` so halation color upload produces
 * the same tint for a given preset string. Inputs are treated as sRGB
 * encoded, but the WebGL path also feeds them into the shader without an
 * sRGB→linear step, so parity is the safe choice here.
 */
export function hexToRgbTriple(hex: string): [number, number, number] {
  const raw = hex.replace(/^#/, "");
  const full =
    raw.length === 3
      ? raw
          .split("")
          .map((c) => c + c)
          .join("")
      : raw;
  const r = Number.parseInt(full.substring(0, 2), 16) / 255;
  const g = Number.parseInt(full.substring(2, 4), 16) / 255;
  const b = Number.parseInt(full.substring(4, 6), 16) / 255;
  return [
    Number.isFinite(r) ? r : 0,
    Number.isFinite(g) ? g : 0,
    Number.isFinite(b) ? b : 0,
  ];
}
