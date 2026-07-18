/**
 * @fileoverview `FilmLabCanvas` の legacy debug fallback（depth probe / ray-angle probe）です。
 *
 * @description
 * `?depthProbe=1|2` / `?rayAngleProbe=1` という URL フラグはローカルデバッグ専用で、
 * 共有の preview/export contract（runtime `depthTrack` prop 等）には一切影響しません。
 * ここに集約することで `FilmLabCanvas.tsx` 本体からデバッグ専用ロジックを切り離します。
 */
import type { CameraOptics } from "film-lab-core";

/**
 * Legacy debug fallback for depth-aware Mist / Glow.
 * When no runtime `depthTrack` prop is supplied, `?depthProbe=1|2` keeps the
 * pre-bundled probe frames available for local debugging without making the
 * shared preview/export contract depend on URL state.
 */
/**
 * Reads `?depthProbe=` from the URL.
 *   "1" → normal amplified modulation (near=0x, far=5x mist) → gain 1.0
 *   "2" → debug view (raw depth texture as grayscale) → gain 2.0
 *   anything else → 0 (depth probe disabled)
 */
export function readDepthProbeGain(): number {
  if (typeof window === "undefined") return 0;
  try {
    const v = new URL(window.location.href).searchParams.get("depthProbe");
    if (v === "1") return 1.0;
    if (v === "2") return 2.0;
    return 0;
  } catch {
    return 0;
  }
}

export function readDepthProbeFlag(): boolean {
  return readDepthProbeGain() > 0;
}

export function readRayAngleProbeFlag(): boolean {
  if (typeof window === "undefined") return false;
  try {
    return new URL(window.location.href).searchParams.get("rayAngleProbe") === "1";
  } catch {
    return false;
  }
}

export function rayAngleProbeOpticsLabel(
  optics: CameraOptics | null | undefined,
): CameraOptics["source"] | "fallback65" {
  if (!optics) {
    return "fallback65";
  }
  const hasFov = [optics.fovXDeg, optics.fovYDeg].some(
    (value) =>
      typeof value === "number" &&
      Number.isFinite(value) &&
      value >= 1 &&
      value <= 178,
  );
  const hasFocalPixels = [optics.fxPx, optics.fyPx].some(
    (value) => typeof value === "number" && Number.isFinite(value) && value > 0,
  );
  const hasFiniteOptics = hasFov || hasFocalPixels;
  return hasFiniteOptics ? optics.source : "fallback65";
}
