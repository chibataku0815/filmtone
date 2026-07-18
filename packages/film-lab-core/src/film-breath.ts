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

export const FILM_BREATH_CONTRACT_VERSION = 1 as const;

/**
 * Versioned numeric and algorithm contract for Film Breath implementations.
 *
 * This object is the Filmtone-owned source used by both this TypeScript
 * implementation and generated native handoffs. Keep implementation-specific
 * ports out of this package and bump the version when these semantics change.
 */
export const FILM_BREATH_CONTRACT = {
  contractVersion: FILM_BREATH_CONTRACT_VERSION,
  algorithm: "filmtone-value-noise-v1",
  seedNormalization: "absolute-truncate-uint32-wrap",
  amount: {
    min: 0,
    max: 1,
    exponent: 1.35,
    envelopeSeconds: 1.25,
  },
  limits: {
    exposure: 0.5,
    contrast: 0.15,
    temperature: 0.22,
    tint: 0.12,
  },
  outputSalts: {
    exposure: 0x4f1bbcdc,
    contrast: 0x9e2c6b6f,
    temperature: 0x27d4eb2f,
    tint: 0x165667b1,
  },
  hash: {
    latticeMultiplier: 0x9e3779b1,
    saltMultiplier: 0x85ebca6b,
    avalancheMultiplierA: 0x7feb352d,
    avalancheMultiplierB: 0x846ca68b,
    divisor: 0xffffffff,
  },
  noise: {
    phaseSaltXor: 0xa511e9b3,
    phaseScale: 8,
    calibration: 2.5,
    min: -1,
    max: 1,
    bands: {
      fast: {
        periodSeconds: 1.8,
        weight: 0.15,
        saltXor: 0x52a7b9c4,
      },
      medium: {
        periodSeconds: 4.8,
        weight: 0.55,
        saltXor: 0,
      },
      slow: {
        periodSeconds: 8.6,
        weight: 0.2,
        saltXor: 0x6d2b79f5,
      },
      long: {
        periodSeconds: 15.5,
        weight: 0.1,
        saltXor: 0x1b873593,
      },
    },
  },
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
  const hash = FILM_BREATH_CONTRACT.hash;
  let x = seed >>> 0;
  x ^= Math.imul((lattice | 0) >>> 0, hash.latticeMultiplier) >>> 0;
  x ^= Math.imul(salt >>> 0, hash.saltMultiplier) >>> 0;
  x ^= x >>> 16;
  x = Math.imul(x, hash.avalancheMultiplierA) >>> 0;
  x ^= x >>> 15;
  x = Math.imul(x, hash.avalancheMultiplierB) >>> 0;
  x ^= x >>> 16;
  return (x >>> 0) / hash.divisor;
}

function valueNoise(timeSeconds: number, seed: number, salt: number, periodSeconds: number): number {
  const noise = FILM_BREATH_CONTRACT.noise;
  const phase = hashUnit(seed, 0, salt ^ noise.phaseSaltXor) * noise.phaseScale;
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
  const noise = FILM_BREATH_CONTRACT.noise;
  const fastBand = noise.bands.fast;
  const mediumBand = noise.bands.medium;
  const slowBand = noise.bands.slow;
  const longBand = noise.bands.long;
  const fast = valueNoise(timeSeconds, seed, salt ^ fastBand.saltXor, fastBand.periodSeconds);
  const medium = valueNoise(timeSeconds, seed, salt ^ mediumBand.saltXor, mediumBand.periodSeconds);
  const slow = valueNoise(timeSeconds, seed, salt ^ slowBand.saltXor, slowBand.periodSeconds);
  const long = valueNoise(timeSeconds, seed, salt ^ longBand.saltXor, longBand.periodSeconds);
  const weighted =
    fast * fastBand.weight +
    medium * mediumBand.weight +
    slow * slowBand.weight +
    long * longBand.weight;
  return clamp(weighted * noise.calibration, noise.min, noise.max);
}

export function deriveFilmBreathOffsets(
  amount: number,
  timeSeconds: number,
  sourceSeed: number,
): FilmBreathOffsets {
  const contract = FILM_BREATH_CONTRACT;
  const clampedAmount = clamp(amount, contract.amount.min, contract.amount.max);
  if (clampedAmount <= 0 || !Number.isFinite(timeSeconds) || timeSeconds <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }

  const drive = Math.pow(clampedAmount, contract.amount.exponent);
  const envelope = smoothstep(timeSeconds / contract.amount.envelopeSeconds);
  const scale = drive * envelope;
  if (scale <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }

  const seed = normalizeSeed(sourceSeed);
  return {
    exposure:
      breathNoise(timeSeconds, seed, contract.outputSalts.exposure) * contract.limits.exposure * scale,
    contrast:
      breathNoise(timeSeconds, seed, contract.outputSalts.contrast) * contract.limits.contrast * scale,
    temperature:
      breathNoise(timeSeconds, seed, contract.outputSalts.temperature) *
      contract.limits.temperature *
      scale,
    tint: breathNoise(timeSeconds, seed, contract.outputSalts.tint) * contract.limits.tint * scale,
  };
}
