// Shadow Latitude / Toe Separation scalar reference.
//
// This pass restores separation in the recoverable toe without acting like
// Fade or a global shadow lift. The black anchor remains fixed, the effect
// peaks in low-mid shadows, and it releases before normal midtones.

export interface ShadowLatitudeRgb {
  r: number;
  g: number;
  b: number;
}

export interface ShadowLatitudeOptions {
  clampOutput?: boolean;
}

export const SHADOW_LATITUDE_CONSTANTS = {
  blackAnchor: 0.025,
  mainBandStart: 0.055,
  mainBandEnd: 0.18,
  releaseEnd: 0.30,
  lumaGainMax: 0.22,
  chromaRetentionMax: 0.08,
} as const;

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

export function shadowLatitudeLuma(rgb: ShadowLatitudeRgb): number {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

export function applyShadowLatitudeSample(
  rgb: ShadowLatitudeRgb,
  amount: number,
  options: ShadowLatitudeOptions = {},
): ShadowLatitudeRgb {
  const amt = clamp01(amount);
  if (amt < 0.001) {
    return rgb;
  }

  const c = SHADOW_LATITUDE_CONSTANTS;
  const y = shadowLatitudeLuma(rgb);
  const blackProtect = smoothstep(c.blackAnchor, c.mainBandStart, y);
  const release = 1 - smoothstep(c.mainBandEnd, c.releaseEnd, y);
  const band = blackProtect * release;

  if (band <= 0.000001) {
    return options.clampOutput
      ? { r: clamp01(rgb.r), g: clamp01(rgb.g), b: clamp01(rgb.b) }
      : rgb;
  }

  const toeShape = Math.max(0, 1 - y / c.releaseEnd);
  const lumaLift = y * toeShape * c.lumaGainMax * amt * band;
  const outY = y + lumaLift;
  const chromaScale = 1 + c.chromaRetentionMax * amt * band;

  const out = {
    r: outY + (rgb.r - y) * chromaScale,
    g: outY + (rgb.g - y) * chromaScale,
    b: outY + (rgb.b - y) * chromaScale,
  };

  return options.clampOutput
    ? { r: clamp01(out.r), g: clamp01(out.g), b: clamp01(out.b) }
    : out;
}
