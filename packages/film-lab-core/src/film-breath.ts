export interface FilmBreathOffsets {
  exposure: number;
  contrast: number;
  temperature: number;
  tint: number;
}

export const FILM_BREATH_ZERO_OFFSETS: FilmBreathOffsets = {
  exposure: 0,
  contrast: 0,
  temperature: 0,
  tint: 0,
};

const FILM_BREATH_LIMITS = {
  exposure: 0.5,
  contrast: 0.15,
  temperature: 0.22,
  tint: 0.12,
} as const;

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function clamp01(value: number): number {
  return clamp(value, 0, 1);
}

function smoothstep(t: number): number {
  const x = clamp01(t);
  return x * x * (3 - 2 * x);
}

function normalizeSeed(sourceSeed: number): number {
  if (!Number.isFinite(sourceSeed)) {
    return 0;
  }
  return Math.trunc(Math.abs(sourceSeed)) >>> 0;
}

function hashUnit(seed: number, lattice: number, salt: number): number {
  let x = seed >>> 0;
  x ^= Math.imul((lattice | 0) >>> 0, 0x9e3779b1) >>> 0;
  x ^= Math.imul(salt >>> 0, 0x85ebca6b) >>> 0;
  x ^= x >>> 16;
  x = Math.imul(x, 0x7feb352d) >>> 0;
  x ^= x >>> 15;
  x = Math.imul(x, 0x846ca68b) >>> 0;
  x ^= x >>> 16;
  return (x >>> 0) / 0xffffffff;
}

function valueNoise(timeSeconds: number, seed: number, salt: number, periodSeconds: number): number {
  const phase = hashUnit(seed, 0, salt ^ 0xa511e9b3) * 8;
  const position = timeSeconds / periodSeconds + phase;
  const lattice = Math.floor(position);
  const fraction = position - lattice;
  const a = hashUnit(seed, lattice, salt) * 2 - 1;
  const b = hashUnit(seed, lattice + 1, salt) * 2 - 1;
  return a + (b - a) * smoothstep(fraction);
}

function breathNoise(timeSeconds: number, seed: number, salt: number): number {
  // Medium (4.8s) carries the projector-breath fundamental; fast (1.8s) adds
  // sub-second flutter without dominating; slow/long are residual drift.
  // Independent-phase sums collapse toward zero (E|Σw·U| ≈ 0.27 for these
  // weights), so the 2.5× calibration lifts typical magnitude into the
  // visible band and the clamp truncates rare in-phase peaks at ±1.
  const fast = valueNoise(timeSeconds, seed, salt ^ 0x52a7b9c4, 1.8);
  const medium = valueNoise(timeSeconds, seed, salt, 4.8);
  const slow = valueNoise(timeSeconds, seed, salt ^ 0x6d2b79f5, 8.6);
  const long = valueNoise(timeSeconds, seed, salt ^ 0x1b873593, 15.5);
  const weighted = fast * 0.15 + medium * 0.55 + slow * 0.2 + long * 0.1;
  return clamp(weighted * 2.5, -1, 1);
}

export function deriveFilmBreathOffsets(
  amount: number,
  timeSeconds: number,
  sourceSeed: number,
): FilmBreathOffsets {
  const clampedAmount = clamp01(amount);
  if (clampedAmount <= 0 || !Number.isFinite(timeSeconds) || timeSeconds <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }

  const drive = Math.pow(clampedAmount, 1.35);
  const envelope = smoothstep(timeSeconds / 1.25);
  const scale = drive * envelope;
  if (scale <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }

  const seed = normalizeSeed(sourceSeed);
  return {
    exposure: breathNoise(timeSeconds, seed, 0x4f1bbcdc) * FILM_BREATH_LIMITS.exposure * scale,
    contrast: breathNoise(timeSeconds, seed, 0x9e2c6b6f) * FILM_BREATH_LIMITS.contrast * scale,
    temperature: breathNoise(timeSeconds, seed, 0x27d4eb2f) * FILM_BREATH_LIMITS.temperature * scale,
    tint: breathNoise(timeSeconds, seed, 0x165667b1) * FILM_BREATH_LIMITS.tint * scale,
  };
}
