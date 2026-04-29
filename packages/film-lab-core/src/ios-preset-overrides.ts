import type { Phase0Params } from "./phase0-schema";

/**
 * iOS Phase 0 ships with a deliberately small preset set.
 *
 * Shared PRESETS remain the canonical Desktop/Web defaults. iOS uses these
 * mobile-specific patches over Filmtone's soft default base so the phone app
 * has fewer, clearer choices without changing other product surfaces.
 */
export const FILMTONE_IOS_PRESET_NAMES = [
  "reset",
  "iphone",
  "softBlue",
  "amberGlow",
] as const;

export type FilmtoneIosPresetName =
  (typeof FILMTONE_IOS_PRESET_NAMES)[number];

export const FILMTONE_IOS_PRESET_PATCHES = {
  reset: {
    halationIntensity: 0,
  },
  iphone: {
    exposure: 0.02,
    contrast: 1.03,
    saturation: 0.98,
    temperature: 0.02,
    tint: 0.0,
    rgbShift: 0.0012,
    lensSoftness: 0.14,
    grainSize: 0.26,
    bloomThreshold: 0.74,
    bloomStrength: 0.16,
    bloomRadius: 0.48,
    diffusion: 0.05,
    halationIntensity: 0.018,
    halationSpread: 18,
    halationHue: 22,
    halationRadius: 0.38,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    fade: 0.02,
    vignette: 0.18,
    grainIntensity: 0.012,
  },
  softBlue: {
    exposure: 0.04,
    contrast: 0.99,
    saturation: 1.02,
    temperature: -0.08,
    tint: -0.04,
    rgbShift: 0.0016,
    lensSoftness: 0.22,
    grainSize: 0.34,
    bloomThreshold: 0.66,
    bloomStrength: 0.18,
    bloomRadius: 0.72,
    diffusion: 0.075,
    halationIntensity: 0.02,
    halationSpread: 24,
    halationHue: 18,
    halationThreshold: 0.54,
    halationRadius: 0.5,
    bloomSoftKnee: 0.72,
    halationSoftKnee: 0.42,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0.015,
    magenta: -0.03,
    yellow: -0.025,
    fade: 0.1,
    vignette: 0.16,
    grainIntensity: 0.014,
  },
  amberGlow: {
    exposure: 0.01,
    contrast: 1.03,
    saturation: 1.03,
    temperature: 0.1,
    tint: 0.02,
    rgbShift: 0.0015,
    lensSoftness: 0.16,
    grainSize: 0.32,
    bloomThreshold: 0.64,
    bloomStrength: 0.20,
    bloomRadius: 0.5,
    diffusion: 0.10,
    halationIntensity: 0.04,
    halationSpread: 22,
    halationHue: 30,
    halationThreshold: 0.52,
    halationRadius: 0.46,
    bloomSoftKnee: 0.62,
    halationSoftKnee: 0.44,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: -0.025,
    magenta: 0.03,
    yellow: 0.045,
    fade: 0.04,
    vignette: 0.22,
    grainIntensity: 0.016,
  },
} satisfies Partial<Record<FilmtoneIosPresetName, Partial<Phase0Params>>>;
