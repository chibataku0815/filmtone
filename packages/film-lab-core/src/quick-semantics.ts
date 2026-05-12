import { z } from "zod";
import type { Params } from "./params";
import { clampGrainIntensity } from "./params";
import { PHASE0_RGB_SHIFT_MAX } from "./phase0-constants";

export const QUICK_AXIS_IDS = [
  "filmCharacter",
  "era",
  "dynamics",
] as const;

export type QuickAxisId = (typeof QUICK_AXIS_IDS)[number];

export type QuickState = Record<QuickAxisId, number>;

export interface Phase0QuickTarget {
  exposure: number;
  contrast: number;
  saturation: number;
  temperature: number;
  tint: number;
  rgbShift: number;
  lensSoftness: number;
  detailSoftness: number;
  shadowLatitude: number;
  fade: number;
  vignette: number;
  grainIntensity: number;
  grainRadialMix: number;
  grainSize: number;
  bloomThreshold: number;
  bloomStrength: number;
  bloomRadius: number;
  diffusion: number;
  halationIntensity: number;
  halationSpread: number;
  halationHue: number;
  halationThreshold: number;
  halationRadius: number;
  bloomSoftKnee: number;
  halationSoftKnee: number;
  compressionAmount: number;
  compressionRange: number;
}

export const QUICK_AXIS_DEFAULT_RANGE = {
  min: -1,
  max: 1,
  step: 0.01,
} as const;

export const DEFAULT_QUICK_STATE: QuickState = {
  filmCharacter: 0,
  era: 0,
  dynamics: 0,
};

const quickStateShape = Object.fromEntries(
  QUICK_AXIS_IDS.map((axis) => [
    axis,
    z.number().min(QUICK_AXIS_DEFAULT_RANGE.min).max(QUICK_AXIS_DEFAULT_RANGE.max),
  ]),
) as z.ZodRawShape;

export const quickStateSchema = z.object(quickStateShape);

type QuickFullPatch = Partial<
  Pick<
    Params,
    | "exposure"
    | "contrast"
    | "saturation"
    | "temperature"
    | "tint"
    | "grainIntensity"
    | "vignette"
    | "fade"
    | "halationIntensity"
    | "halationSpread"
    | "bloomStrength"
    | "bloomThreshold"
    | "bloomRadius"
  >
>;

type QuickPhase0Patch = Partial<Phase0QuickTarget>;

export const QUICK_FULL_AXIS_WEIGHTS: Record<QuickAxisId, QuickFullPatch> = {
  filmCharacter: {
    saturation: 0.24,
    temperature: 0.16,
    tint: -0.06,
    grainIntensity: 0.1,
    vignette: 0.12,
  },
  era: {
    fade: 0.18,
    saturation: -0.14,
    contrast: -0.08,
  },
  dynamics: {
    exposure: 0.24,
    contrast: 0.18,
    bloomStrength: 0.16,
    bloomThreshold: -0.06,
    bloomRadius: 0.12,
  },
};

export const QUICK_PHASE0_AXIS_WEIGHTS: Record<QuickAxisId, QuickPhase0Patch> = {
  filmCharacter: {
    saturation: 0.24,
    temperature: 0.16,
    tint: -0.06,
    grainIntensity: 0.1,
    vignette: 0.12,
  },
  era: {
    fade: 0.18,
    saturation: -0.14,
    contrast: -0.08,
  },
  dynamics: {
    exposure: 0.24,
    contrast: 0.18,
    bloomStrength: 0.16,
    bloomThreshold: -0.06,
    bloomRadius: 0.12,
  },
};

function clampAxisValue(value: number): number {
  return Math.max(
    QUICK_AXIS_DEFAULT_RANGE.min,
    Math.min(QUICK_AXIS_DEFAULT_RANGE.max, value),
  );
}

function clampParamValue(key: string, value: number): number {
  switch (key) {
    case "exposure":
      return Math.max(-2, Math.min(2, value));
    case "contrast":
    case "saturation":
      return Math.max(0, Math.min(2, value));
    case "temperature":
    case "tint":
      return Math.max(-1, Math.min(1, value));
    case "rgbShift":
      return Math.max(0, Math.min(PHASE0_RGB_SHIFT_MAX, value));
    case "grainIntensity":
      return clampGrainIntensity(value);
    case "vignette":
    case "fade":
    case "lensSoftness":
    case "detailSoftness":
    case "shadowLatitude":
    case "grainRadialMix":
    case "grainSize":
    case "halationIntensity":
    case "halationThreshold":
    case "halationRadius":
    case "bloomStrength":
    case "bloomThreshold":
    case "bloomRadius":
    case "diffusion":
    case "bloomSoftKnee":
    case "halationSoftKnee":
    case "compressionAmount":
    case "compressionRange":
      return Math.max(0, Math.min(1, value));
    case "halationSpread":
      return Math.max(0, Math.min(40, value));
    default:
      return value;
  }
}

function applyWeightedPatch(
  base: Record<string, number>,
  state: QuickState,
  weights: Record<QuickAxisId, Record<string, number | undefined>>,
): Record<string, number> {
  const next = { ...base };

  for (const axis of QUICK_AXIS_IDS) {
    const axisValue = clampAxisValue(state[axis]);
    for (const [key, weight] of Object.entries(weights[axis])) {
      if (typeof weight !== "number") continue;
      next[key] = clampParamValue(key, next[key] + axisValue * weight);
    }
  }

  return next;
}

export function coerceQuickState(
  input: Partial<Record<QuickAxisId, number>> | null | undefined,
): QuickState {
  return {
    filmCharacter: clampAxisValue(input?.filmCharacter ?? 0),
    era: clampAxisValue(input?.era ?? 0),
    dynamics: clampAxisValue(input?.dynamics ?? 0),
  };
}

export function applyQuickStateToParams(base: Params, state: QuickState): Params {
  return applyWeightedPatch(
    base as unknown as Record<string, number>,
    state,
    QUICK_FULL_AXIS_WEIGHTS,
  ) as unknown as Params;
}

export function applyQuickStateToPhase0Params<T extends Phase0QuickTarget>(
  base: T,
  state: QuickState,
): T {
  return applyWeightedPatch(
    base as unknown as Record<string, number>,
    state,
    QUICK_PHASE0_AXIS_WEIGHTS,
  ) as unknown as T;
}
