import { clampGrainIntensity, type Params } from "film-lab-core";

export const MOBILE_PHASE0_QUICK_KEYS = [
  "filmLook",
  "era",
  "dynamics",
] as const;

export type MobilePhase0QuickKey = (typeof MOBILE_PHASE0_QUICK_KEYS)[number];

export type MobilePhase0QuickValues = Record<MobilePhase0QuickKey, number>;

export const MOBILE_PHASE0_QUICK_DEFAULTS: MobilePhase0QuickValues = {
  filmLook: 0,
  era: 0,
  dynamics: 0,
};

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function clampSignedUnit(value: number): number {
  return clamp(value, -1, 1);
}

/**
 * Phase 0 mobile quick semantics deliberately stay inside the reduced export subset.
 * They do not touch bloom, halation, lens softness, split tone, or any full-parity path.
 */
export function createMobilePhase0QuickPatch(
  base: Params,
  quick: MobilePhase0QuickValues,
): Partial<Params> {
  const filmLook = clampSignedUnit(quick.filmLook);
  const era = clampSignedUnit(quick.era);
  const dynamics = clampSignedUnit(quick.dynamics);

  const saturation = clamp(base.saturation + filmLook * 0.18 - era * 0.04, 0, 2);
  const temperature = clamp(base.temperature + filmLook * 0.1 + era * 0.18, -1, 1);
  const tint = clamp(base.tint + filmLook * 0.04 - era * 0.05, -1, 1);
  const fade = clamp(base.fade + era * 0.12, 0, 1);
  const vignette = clamp(base.vignette + filmLook * 0.16, 0, 1);
  const grainIntensity = clampGrainIntensity(
    base.grainIntensity + Math.max(0, filmLook) * 0.045 + Math.abs(era) * 0.015,
  );
  const exposure = clamp(base.exposure + dynamics * 0.22, -2, 2);
  const contrast = clamp(base.contrast + dynamics * 0.2 - era * 0.03, 0, 2);

  return {
    saturation,
    temperature,
    tint,
    fade,
    vignette,
    grainIntensity,
    exposure,
    contrast,
  };
}

export function applyMobilePhase0QuickToParams(
  base: Params,
  quick: MobilePhase0QuickValues,
): Params {
  return {
    ...base,
    ...createMobilePhase0QuickPatch(base, quick),
  };
}

export function setMobilePhase0QuickValue(
  current: MobilePhase0QuickValues,
  key: MobilePhase0QuickKey,
  value: number,
): MobilePhase0QuickValues {
  return {
    ...current,
    [key]: clampSignedUnit(value),
  };
}
