// Film Compression V3 scalar reference.
//
// This is the canonical CPU sample model for the shader / CIKernel ports. The
// stage keeps the existing luma shoulder, then compresses chroma magnitude
// around the post-shoulder neutral axis so hue direction and luma stay stable.

export interface FilmCompressionRgb {
  r: number;
  g: number;
  b: number;
}

export interface FilmCompressionV3Options {
  clampOutput?: boolean;
}

export const FILM_COMPRESSION_V3_CONSTANTS = {
  lumaKMin: 2.85,
  lumaKMax: 5.15,
  rangeSoftStart: 0.82,
  rangeSoftEnd: 1.0,
  rangeAmountTrim: 0.18,
  chromaCompressionMax: 0.42,
  problemColorGuardMax: 0.22,
  shadowReleaseStart: 0.14,
  shadowReleaseEnd: 0.30,
  highlightKneeStartLowRange: 0.62,
  highlightKneeStartHighRange: 0.42,
  highlightKneeEndLowRange: 0.96,
  highlightKneeEndHighRange: 0.78,
  chromaStressStart: 0.16,
  chromaStressEnd: 0.70,
  gamutStressStart: 0.82,
  gamutStressEnd: 1.08,
  warmProtectStrength: 0.35,
  highlightDensityLandingStart: 0.78,
  highlightDensityLandingStrength: 0.88,
  highlightDensityLandingChromaStart: 0.18,
  highlightDensityLandingChromaEnd: 0.62,
  highlightDensityLandingWarmProtect: 0.35,
} as const;

export function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

function clampRange(x: number, lo: number, hi: number): number {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}

export function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

export function filmCompressionLuma(rgb: FilmCompressionRgb): number {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

export function filmCompressionChromaMagnitude(rgb: FilmCompressionRgb): number {
  const y = filmCompressionLuma(rgb);
  const cr = rgb.r - y;
  const cg = rgb.g - y;
  const cb = rgb.b - y;
  return Math.sqrt(cr * cr + cg * cg + cb * cb);
}

function max3(a: number, b: number, c: number): number {
  return Math.max(a, Math.max(b, c));
}

function min3(a: number, b: number, c: number): number {
  return Math.min(a, Math.min(b, c));
}

function warmHueProtect(cr: number, cg: number, cb: number, mag: number): number {
  if (mag <= 0.000001) {
    return 0;
  }
  const dr = cr / mag;
  const dg = cg / mag;
  const db = cb / mag;
  const redWarm = smoothstep(0.32, 0.72, dr);
  const blueOpposed = 1 - smoothstep(-0.58, -0.20, db);
  const greenModerate = 1 - smoothstep(0.18, 0.58, Math.abs(dg));
  return clamp01(redWarm * blueOpposed * greenModerate);
}

export function applyFilmCompressionV3Sample(
  rgb: FilmCompressionRgb,
  amount: number,
  range: number,
  options: FilmCompressionV3Options = {},
): FilmCompressionRgb {
  if (amount < 0.001) {
    return rgb;
  }

  const c = FILM_COMPRESSION_V3_CONSTANTS;
  const r = clamp01(range);
  const k = mix(c.lumaKMax, c.lumaKMin, r);
  const rangeSoft = smoothstep(c.rangeSoftStart, c.rangeSoftEnd, r);
  const amt = amount * (1 - c.rangeAmountTrim * rangeSoft);

  const y = filmCompressionLuma(rgb);
  const x = clampRange(k * (y - 0.5), -5.5, 5.5);
  const sigmoid = 1 / (1 + Math.exp(-x));
  // One-sided shoulder: only roll highlights down, never lift shadows.
  // A symmetric sigmoid centered at 0.5 would pull shadows toward 0.5 just
  // as hard as it rolls highlights — that lifts deep blacks and boosts
  // their chroma, the opposite of the filmic density target.
  const shoulderY = Math.min(y, mix(y, sigmoid, amt));
  const lumaScale = y > 0.001 ? shoulderY / y : 1;

  const lr = rgb.r * lumaScale;
  const lg = rgb.g * lumaScale;
  const lb = rgb.b * lumaScale;

  const cr = lr - shoulderY;
  const cg = lg - shoulderY;
  const cb = lb - shoulderY;
  const chromaMag = Math.sqrt(cr * cr + cg * cg + cb * cb);

  const shadowRelease = smoothstep(
    c.shadowReleaseStart,
    c.shadowReleaseEnd,
    shoulderY,
  );
  const kneeStart = mix(
    c.highlightKneeStartLowRange,
    c.highlightKneeStartHighRange,
    r,
  );
  const kneeEnd = mix(
    c.highlightKneeEndLowRange,
    c.highlightKneeEndHighRange,
    r,
  );
  const highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY);
  const chromaStress = smoothstep(
    c.chromaStressStart,
    c.chromaStressEnd,
    chromaMag,
  );
  const maxChannel = max3(lr, lg, lb);
  const minChannel = min3(lr, lg, lb);
  const highEdgeStress = smoothstep(
    c.gamutStressStart,
    c.gamutStressEnd,
    maxChannel,
  );
  const lowEdgeStress = smoothstep(
    c.gamutStressStart,
    c.gamutStressEnd,
    -minChannel,
  );
  const gamutStress =
    Math.max(highEdgeStress, lowEdgeStress) *
    chromaStress *
    smoothstep(0.08, 0.24, shoulderY);
  const warmProtect = warmHueProtect(cr, cg, cb, chromaMag);

  const highlightCompression =
    c.chromaCompressionMax *
    highlightMask *
    shadowRelease *
    mix(0.55, 1.0, chromaStress);
  const guardCompression =
    c.problemColorGuardMax * gamutStress * shadowRelease;
  const protectedCompression =
    (highlightCompression + guardCompression) *
    (1 - c.warmProtectStrength * warmProtect);
  const chromaScale = clamp01(1 - amt * protectedCompression);

  const landedCr = cr * chromaScale;
  const landedCg = cg * chromaScale;
  const landedCb = cb * chromaScale;
  const out = {
    r: shoulderY + landedCr,
    g: shoulderY + landedCg,
    b: shoulderY + landedCb,
  };
  const outMax = max3(out.r, out.g, out.b);
  const landingChroma = smoothstep(
    c.highlightDensityLandingChromaStart,
    c.highlightDensityLandingChromaEnd,
    chromaMag,
  );
  const landingMask =
    smoothstep(c.highlightDensityLandingStart, 0.98, outMax) *
    landingChroma *
    shadowRelease *
    (1 - c.highlightDensityLandingWarmProtect * warmProtect);

  if (outMax > c.highlightDensityLandingStart && outMax > shoulderY + 0.000001) {
    const over = outMax - c.highlightDensityLandingStart;
    const headroom = 1 - c.highlightDensityLandingStart;
    const softMax =
      c.highlightDensityLandingStart +
      (headroom * over) / (over + headroom);
    const landingScale = clamp01((softMax - shoulderY) / (outMax - shoulderY));
    const landingBlend = clamp01(
      amt * c.highlightDensityLandingStrength * landingMask,
    );
    const finalScale = mix(1, landingScale, landingBlend);
    out.r = shoulderY + landedCr * finalScale;
    out.g = shoulderY + landedCg * finalScale;
    out.b = shoulderY + landedCb * finalScale;
  }

  if (options.clampOutput) {
    return {
      r: clamp01(out.r),
      g: clamp01(out.g),
      b: clamp01(out.b),
    };
  }

  return out;
}
