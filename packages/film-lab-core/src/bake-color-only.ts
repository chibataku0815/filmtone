/**
 * Color-only baker for Filmtone iOS Creative LUT Pack v1.4.
 *
 * Implements Stages 2 (baseGrade), 3 (filmCompression), and 9 (printStage) of
 * the Filmtone iOS export pipeline as a pure function on a single Rec.709 RGB
 * triple. 14 color-only ops total: exposure / contrast / saturation /
 * temperature / tint / toeContrast / blackPoint / fade / compressionAmount /
 * compressionRange / printContrast / cyan / magenta / yellow.
 *
 * NOTE: this baker is an APPROXIMATION of baseGradeV2 — it does not implement
 * the 3-piece contrast curve, the crosstalk split-tone, or the shadow-only
 * fade mask. New ops (toeContrast / blackPoint) are inserted in the position
 * matching the CIKL `baseGradeV2` (just before fade) but otherwise the baker's
 * fidelity to the GPU pipeline is approximate. Full parity is tracked as a
 * separate lane (see plans/worktree-recursive-badger.md "Follow-up").
 *
 * This TS implementation is the canonical reference for the Swift port shipped
 * via the v1.4 in-app "Look → .cube export" lane. Both must produce
 * byte-identical output at Float32 precision; that contract is enforced by
 * Tier 1 fixtures in Phase 2 PR.
 *
 * Direct float64 port of:
 *   apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
 *     applyBaseGrade / applyFilmCompression / applyPrintStage
 * which is itself the CPU equivalent of the GPU stages in
 * `FilmtoneExportSession.swift`. Keeping this file aligned with the Swift
 * sidecar baker is the SSOT contract.
 */

import { applyFilmCompressionV3Sample } from "./film-compression-v3";
import type { Phase0Params } from "./phase0-schema";

/** RGB triple. All channels in linear-display Rec.709 [0, 1] domain. */
export interface RGB {
  r: number;
  g: number;
  b: number;
}

/** Linear interpolation. `t=0` returns `a`, `t=1` returns `b`. */
function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

/** GLSL-style smoothstep. Matches CIKL `smoothstep(edge0, edge1, x)`. */
function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/** Rec.709 luminance. Matches `RGB.luma` extension in Swift. */
function luma(rgb: RGB): number {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

function clampedRGB(rgb: RGB): RGB {
  return { r: clamp01(rgb.r), g: clamp01(rgb.g), b: clamp01(rgb.b) };
}

/**
 * Pull only the 14 color-only fields from a full `Phase0Params`. Used to make
 * the baker contract independent from spatial fields (halation / bloom /
 * grain / vignette) that cannot be expressed in a 3D color cube.
 */
export interface BakeColorParams {
  exposure: number;
  contrast: number;
  saturation: number;
  temperature: number;
  tint: number;
  toeContrast: number;
  blackPoint: number;
  fade: number;
  compressionAmount: number;
  compressionRange: number;
  printContrast: number;
  cyan: number;
  magenta: number;
  yellow: number;
}

export const BAKE_COLOR_PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "toeContrast",
  "blackPoint",
  "fade",
  "compressionAmount",
  "compressionRange",
  "printContrast",
  "cyan",
  "magenta",
  "yellow",
] as const satisfies readonly (keyof BakeColorParams)[];

/**
 * Neutral (identity) color params. Baking with these yields the identity cube
 * within float64 precision. Used by Phase 1 placeholder cubes and as the test
 * baseline.
 */
export const BAKE_COLOR_IDENTITY: BakeColorParams = {
  exposure: 0,
  contrast: 1,
  saturation: 1,
  temperature: 0,
  tint: 0,
  toeContrast: 0,
  blackPoint: 0,
  fade: 0,
  compressionAmount: 0,
  compressionRange: 0.5,
  printContrast: 0,
  cyan: 0,
  magenta: 0,
  yellow: 0,
};

export function pickBakeColorParams(
  params: Pick<Phase0Params, keyof BakeColorParams>,
): BakeColorParams {
  return {
    exposure: params.exposure,
    contrast: params.contrast,
    saturation: params.saturation,
    temperature: params.temperature,
    tint: params.tint,
    toeContrast: params.toeContrast,
    blackPoint: params.blackPoint,
    fade: params.fade,
    compressionAmount: params.compressionAmount,
    compressionRange: params.compressionRange,
    printContrast: params.printContrast,
    cyan: params.cyan,
    magenta: params.magenta,
    yellow: params.yellow,
  };
}

/** Stage 2 — baseGrade: exposure, contrast, saturation, temperature, tint, fade. */
function applyBaseGrade(rgb: RGB, params: BakeColorParams): RGB {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;

  const exposureScale = Math.pow(2, params.exposure);
  r *= exposureScale;
  g *= exposureScale;
  b *= exposureScale;

  r = (r - 0.5) * params.contrast + 0.5;
  g = (g - 0.5) * params.contrast + 0.5;
  b = (b - 0.5) * params.contrast + 0.5;

  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  r = mix(lum, r, params.saturation);
  g = mix(lum, g, params.saturation);
  b = mix(lum, b, params.saturation);

  r += params.temperature * 0.1;
  b -= params.temperature * 0.1;
  r += params.tint * 0.05;
  g -= params.tint * 0.08;
  b += params.tint * 0.05;

  // === toe contrast → black point (fade 直前位置、CIKL baseGradeV2 と同位置) ===
  // 順序: toe 先 → blackPoint 後。blackPoint=+1 と toe=1 を独立に操作可能にするため。
  const lumaTB = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  if (params.toeContrast > 0.0001) {
    const toeMaskAmt = (1 - smoothstep(0, 0.15, lumaTB)) * params.toeContrast;
    if (toeMaskAmt > 0) {
      const exponent = 1 + toeMaskAmt * 1.5;
      const tR = Math.pow(Math.max(r, 0), exponent);
      const tG = Math.pow(Math.max(g, 0), exponent);
      const tB = Math.pow(Math.max(b, 0), exponent);
      r = mix(r, tR, toeMaskAmt);
      g = mix(g, tG, toeMaskAmt);
      b = mix(b, tB, toeMaskAmt);
    }
  }
  const bpPos = Math.max(params.blackPoint, 0);
  const bpNeg = Math.max(-params.blackPoint, 0);
  if (bpPos > 0.0001) {
    const luma2 = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const shadowMaskBp = 1 - smoothstep(0, 0.35, luma2);
    const lift = bpPos * 0.18 * shadowMaskBp;
    r += lift;
    g += lift;
    b += lift;
  }
  if (bpNeg > 0.0001) {
    const f = bpNeg * 0.15;
    const xR = Math.max(r, 0);
    const xG = Math.max(g, 0);
    const xB = Math.max(b, 0);
    r = (xR * xR * (1 + f)) / (xR + f);
    g = (xG * xG * (1 + f)) / (xG + f);
    b = (xB * xB * (1 + f)) / (xB + f);
  }

  r = r + params.fade * (1 - r);
  g = g + params.fade * (1 - g);
  b = b + params.fade * (1 - b);

  return { r, g, b };
}

/** Stage 3 — filmCompressionV3: luma shoulder plus chroma density rolloff. */
function applyFilmCompression(rgb: RGB, params: BakeColorParams): RGB {
  return applyFilmCompressionV3Sample(
    rgb,
    params.compressionAmount,
    params.compressionRange,
    { clampOutput: true },
  );
}

/** Stage 9 — printStage: CMY tint + sigmoid print contrast. */
function applyPrintStage(rgb: RGB, params: BakeColorParams): RGB {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;

  const cmyScale = 0.15;
  r -= params.cyan * cmyScale;
  g -= params.magenta * cmyScale;
  b -= params.yellow * cmyScale;

  if (params.printContrast >= 0.001) {
    const k = mix(1, 5, params.printContrast);
    const sR = 1 / (1 + Math.exp(-k * (r - 0.5)));
    const sG = 1 / (1 + Math.exp(-k * (g - 0.5)));
    const sB = 1 / (1 + Math.exp(-k * (b - 0.5)));
    r = mix(r, sR, params.printContrast);
    g = mix(g, sG, params.printContrast);
    b = mix(b, sB, params.printContrast);
  }

  return clampedRGB({ r, g, b });
}

/**
 * Compose Stages 2 → 3 → 9 on a single Rec.709 RGB triple. Output stays in
 * Rec.709 [0, 1].
 *
 * Note: the iOS pipeline runs Stage 9 (printStage) AFTER the creative LUT
 * stage at runtime. To represent the entire color expression in a single
 * cube, the baker composes all three stages here. When a baked cube is
 * applied as a creative LUT at runtime, the host preset's 12 color params
 * MUST be neutralized via paramOverrides so the look does not double-apply.
 * That neutralization contract is enforced by `creative-pack-01.ts` per Look
 * (and validated by Phase 2 fixture comparisons).
 */
export function bakeColorOnly(rgb: RGB, params: BakeColorParams): RGB {
  const stage2 = applyBaseGrade(rgb, params);
  const stage3 = applyFilmCompression(stage2, params);
  const stage9 = applyPrintStage(stage3, params);
  return stage9;
}
