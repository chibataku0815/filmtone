import type { Params } from "./params";
import { PRESETS } from "./presets";

export type OpticalFilterFamily =
  | "blackMist"
  | "cineBloom"
  | "pearlGlow"
  | "warmMist"
  | "cleanSoft"
  | "streak"
  | "prismHalo";

export type OpticalFilterDensity =
  | "subtle"
  | "1/8"
  | "1/4"
  | "1/2"
  | "5%"
  | "10%"
  | "20%"
  | "heavy";

export type OpticalFilterParamKey =
  | "bloomThreshold"
  | "bloomStrength"
  | "bloomRadius"
  | "diffusion"
  | "depthMistGain"
  | "depthGlowGain"
  | "depthRayAngleGamma"
  | "depthRayAngleInnerThreshold"
  | "depthMistRayAngleGain"
  | "depthBloomRayAngleGain"
  | "depthHalationRayAngleGain"
  | "depthMistFieldPsfGain"
  | "depthBloomFieldPsfGain"
  | "depthHalationFieldPsfGain"
  | "depthMistFieldPsfRadiusPx"
  | "depthBloomFieldPsfRadiusPx"
  | "depthHalationFieldPsfRadiusPx"
  | "halationIntensity"
  | "halationSpread"
  | "halationHue"
  | "halationThreshold"
  | "halationRadius"
  | "bloomSoftKnee"
  | "halationSoftKnee"
  | "rgbShift"
  | "lensSoftness"
  | "crossFilterStrength"
  | "crossFilterSpikes"
  | "crossFilterAngle"
  | "crossFilterLength"
  | "crossFilterThreshold"
  | "crossFilterChromatic"
  | "crossFilterSizeLimit"
  | "crossFilterRandomness"
  | "crossFilterHardMode"
  | "crossFilterMinSpacing"
  | "crossFilterDepthGain"
  | "crossFilterAngleGain"
  | "crossFilterAngleGamma"
  | "crossFilterAngleInnerThreshold"
  | "crossFilterEdgeLengthGain"
  | "crossFilterEdgeStrengthGain"
  | "haloPrismStrength"
  | "haloPrismRadius"
  | "haloPrismWidth"
  | "haloPrismChromatic"
  | "haloPrismThreshold"
  | "haloPrismSplit"
  | "haloPrismAngle"
  | "haloPrismSourceReactivity"
  | "opticalDirectTransmission"
  | "opticalBlackRetention"
  | "opticalScatterStrength"
  | "opticalHighlightReactivity"
  | "opticalWarmScatter"
  | "opticalSpectralTail";

export type OpticalFilterParamPatch = Pick<Params, OpticalFilterParamKey>;

export interface OpticalFilterBehavior {
  readonly blackRetention: number;
  readonly directTransmission: number;
  readonly scatterStrength: number;
  readonly scatterCore: number;
  readonly scatterTail: number;
  readonly highlightReactivity: number;
  readonly warmth: number;
  readonly spectralTail: number;
  readonly depthResponse: number;
  readonly rayAngleResponse: number;
  readonly fieldPsfScale: number;
}

export interface OpticalFilterProfile {
  readonly id: string;
  readonly family: OpticalFilterFamily;
  readonly density: OpticalFilterDensity;
  readonly displayName: string;
  readonly shortLabel: string;
  readonly description: string;
  readonly params: Partial<OpticalFilterParamPatch>;
  readonly behavior: OpticalFilterBehavior;
}

export const OPTICAL_FILTER_PARAM_KEYS = [
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "depthMistGain",
  "depthGlowGain",
  "depthRayAngleGamma",
  "depthRayAngleInnerThreshold",
  "depthMistRayAngleGain",
  "depthBloomRayAngleGain",
  "depthHalationRayAngleGain",
  "depthMistFieldPsfGain",
  "depthBloomFieldPsfGain",
  "depthHalationFieldPsfGain",
  "depthMistFieldPsfRadiusPx",
  "depthBloomFieldPsfRadiusPx",
  "depthHalationFieldPsfRadiusPx",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
  "rgbShift",
  "lensSoftness",
  "crossFilterStrength",
  "crossFilterSpikes",
  "crossFilterAngle",
  "crossFilterLength",
  "crossFilterThreshold",
  "crossFilterChromatic",
  "crossFilterSizeLimit",
  "crossFilterRandomness",
  "crossFilterHardMode",
  "crossFilterMinSpacing",
  "crossFilterDepthGain",
  "crossFilterAngleGain",
  "crossFilterAngleGamma",
  "crossFilterAngleInnerThreshold",
  "crossFilterEdgeLengthGain",
  "crossFilterEdgeStrengthGain",
  "haloPrismStrength",
  "haloPrismRadius",
  "haloPrismWidth",
  "haloPrismChromatic",
  "haloPrismThreshold",
  "haloPrismSplit",
  "haloPrismAngle",
  "haloPrismSourceReactivity",
  "opticalDirectTransmission",
  "opticalBlackRetention",
  "opticalScatterStrength",
  "opticalHighlightReactivity",
  "opticalWarmScatter",
  "opticalSpectralTail",
] as const satisfies readonly OpticalFilterParamKey[];

const OPTICAL_FILTER_BASE_PATCH = Object.fromEntries(
  OPTICAL_FILTER_PARAM_KEYS.map((key) => [key, PRESETS.reset[key]]),
) as OpticalFilterParamPatch;

function behavior(
  patch: Partial<OpticalFilterBehavior>,
): OpticalFilterBehavior {
  return {
    blackRetention: 1,
    directTransmission: 1,
    scatterStrength: 0,
    scatterCore: 0.35,
    scatterTail: 0.35,
    highlightReactivity: 0,
    warmth: 0,
    spectralTail: 0,
    depthResponse: 0,
    rayAngleResponse: 0,
    fieldPsfScale: 1,
    ...patch,
  };
}

export const OPTICAL_FILTER_DISCLAIMER =
  "Inspired by common diffusion-filter families. Not a manufacturer-certified emulation.";

export const OPTICAL_FILTER_PROFILES = [
  {
    id: "blackMist-1-8",
    family: "blackMist",
    density: "1/8",
    displayName: "Black Mist 1/8",
    shortLabel: "1/8",
    description: "Controlled highlight bloom with strong black retention.",
    params: {
      bloomThreshold: 0.8,
      bloomStrength: 0.1,
      bloomRadius: 0.42,
      diffusion: 0.06,
      halationIntensity: 0.035,
      halationSpread: 16,
      halationHue: 18,
      halationThreshold: 0.66,
      halationRadius: 0.34,
      bloomSoftKnee: 0.58,
      halationSoftKnee: 0.34,
      lensSoftness: 0.035,
      opticalDirectTransmission: 0.965,
      opticalBlackRetention: 0.92,
      opticalScatterStrength: 0.18,
      opticalHighlightReactivity: 0.42,
      opticalWarmScatter: 0.08,
      opticalSpectralTail: 0.04,
    },
    behavior: behavior({
      blackRetention: 0.92,
      directTransmission: 0.965,
      scatterStrength: 0.18,
      scatterCore: 0.42,
      scatterTail: 0.3,
      highlightReactivity: 0.42,
      warmth: 0.08,
      spectralTail: 0.04,
    }),
  },
  {
    id: "blackMist-1-4",
    family: "blackMist",
    density: "1/4",
    displayName: "Black Mist 1/4",
    shortLabel: "1/4",
    description: "Visible halation and highlight roll with protected shadows.",
    params: {
      bloomThreshold: 0.76,
      bloomStrength: 0.18,
      bloomRadius: 0.52,
      diffusion: 0.1,
      depthMistGain: 0.22,
      depthGlowGain: 0.18,
      depthMistRayAngleGain: 0.42,
      depthBloomRayAngleGain: 0.32,
      depthHalationRayAngleGain: 0.24,
      halationIntensity: 0.07,
      halationSpread: 20,
      halationHue: 20,
      halationThreshold: 0.62,
      halationRadius: 0.42,
      bloomSoftKnee: 0.64,
      halationSoftKnee: 0.42,
      lensSoftness: 0.055,
      opticalDirectTransmission: 0.93,
      opticalBlackRetention: 0.86,
      opticalScatterStrength: 0.34,
      opticalHighlightReactivity: 0.58,
      opticalWarmScatter: 0.12,
      opticalSpectralTail: 0.06,
    },
    behavior: behavior({
      blackRetention: 0.86,
      directTransmission: 0.93,
      scatterStrength: 0.34,
      scatterCore: 0.48,
      scatterTail: 0.42,
      highlightReactivity: 0.58,
      warmth: 0.12,
      spectralTail: 0.06,
      depthResponse: 0.2,
      rayAngleResponse: 0.32,
      fieldPsfScale: 1.1,
    }),
  },
  {
    id: "blackMist-1-2",
    family: "blackMist",
    density: "1/2",
    displayName: "Black Mist 1/2",
    shortLabel: "1/2",
    description: "Dense highlight bloom with a broad low-frequency tail.",
    params: {
      bloomThreshold: 0.7,
      bloomStrength: 0.28,
      bloomRadius: 0.64,
      diffusion: 0.16,
      depthMistGain: 0.32,
      depthGlowGain: 0.28,
      depthMistRayAngleGain: 0.48,
      depthBloomRayAngleGain: 0.38,
      depthHalationRayAngleGain: 0.28,
      depthMistFieldPsfRadiusPx: 22,
      depthBloomFieldPsfRadiusPx: 12,
      depthHalationFieldPsfRadiusPx: 15,
      halationIntensity: 0.12,
      halationSpread: 26,
      halationHue: 21,
      halationThreshold: 0.58,
      halationRadius: 0.54,
      bloomSoftKnee: 0.72,
      halationSoftKnee: 0.5,
      lensSoftness: 0.08,
      opticalDirectTransmission: 0.88,
      opticalBlackRetention: 0.78,
      opticalScatterStrength: 0.52,
      opticalHighlightReactivity: 0.72,
      opticalWarmScatter: 0.16,
      opticalSpectralTail: 0.08,
    },
    behavior: behavior({
      blackRetention: 0.78,
      directTransmission: 0.88,
      scatterStrength: 0.52,
      scatterCore: 0.52,
      scatterTail: 0.58,
      highlightReactivity: 0.72,
      warmth: 0.16,
      spectralTail: 0.08,
      depthResponse: 0.3,
      rayAngleResponse: 0.4,
      fieldPsfScale: 1.25,
    }),
  },
  {
    id: "cineBloom-5",
    family: "cineBloom",
    density: "5%",
    displayName: "Cine Bloom 5%",
    shortLabel: "5%",
    description: "Soft digital-edge bloom with a clean haze floor.",
    params: {
      bloomThreshold: 0.78,
      bloomStrength: 0.14,
      bloomRadius: 0.5,
      diffusion: 0.08,
      halationIntensity: 0.03,
      halationSpread: 16,
      halationHue: 16,
      halationRadius: 0.34,
      bloomSoftKnee: 0.62,
      lensSoftness: 0.045,
    },
    behavior: behavior({ scatterTail: 0.44, highlightReactivity: 0.28 }),
  },
  {
    id: "cineBloom-10",
    family: "cineBloom",
    density: "10%",
    displayName: "Cine Bloom 10%",
    shortLabel: "10%",
    description: "Dreamier broad bloom for practicals and skin.",
    params: {
      bloomThreshold: 0.72,
      bloomStrength: 0.24,
      bloomRadius: 0.62,
      diffusion: 0.13,
      halationIntensity: 0.06,
      halationSpread: 22,
      halationHue: 18,
      halationRadius: 0.46,
      bloomSoftKnee: 0.7,
      halationSoftKnee: 0.4,
      lensSoftness: 0.065,
    },
    behavior: behavior({ scatterTail: 0.6, highlightReactivity: 0.38 }),
  },
  {
    id: "cineBloom-20",
    family: "cineBloom",
    density: "20%",
    displayName: "Cine Bloom 20%",
    shortLabel: "20%",
    description: "Heavy broad glow for an intentionally dreamy finish.",
    params: {
      bloomThreshold: 0.64,
      bloomStrength: 0.42,
      bloomRadius: 0.74,
      diffusion: 0.22,
      halationIntensity: 0.1,
      halationSpread: 28,
      halationHue: 18,
      halationRadius: 0.6,
      bloomSoftKnee: 0.78,
      halationSoftKnee: 0.48,
      lensSoftness: 0.1,
    },
    behavior: behavior({ scatterTail: 0.78, highlightReactivity: 0.5 }),
  },
  {
    id: "warmMist-1-8",
    family: "warmMist",
    density: "1/8",
    displayName: "Warm Mist 1/8",
    shortLabel: "1/8",
    description: "Warm practical-light bloom with restrained softness.",
    params: {
      bloomThreshold: 0.76,
      bloomStrength: 0.16,
      bloomRadius: 0.48,
      diffusion: 0.07,
      halationIntensity: 0.08,
      halationSpread: 20,
      halationHue: 28,
      halationThreshold: 0.6,
      halationRadius: 0.4,
      bloomSoftKnee: 0.62,
      halationSoftKnee: 0.42,
      lensSoftness: 0.04,
      opticalWarmScatter: 0.18,
      opticalSpectralTail: 0.04,
    },
    behavior: behavior({ warmth: 0.18, spectralTail: 0.04, highlightReactivity: 0.35 }),
  },
  {
    id: "warmMist-1-4",
    family: "warmMist",
    density: "1/4",
    displayName: "Warm Mist 1/4",
    shortLabel: "1/4",
    description: "Tasteful amber halation for night ambience.",
    params: {
      bloomThreshold: 0.7,
      bloomStrength: 0.24,
      bloomRadius: 0.58,
      diffusion: 0.11,
      depthGlowGain: 0.16,
      halationIntensity: 0.14,
      halationSpread: 26,
      halationHue: 30,
      halationThreshold: 0.56,
      halationRadius: 0.5,
      bloomSoftKnee: 0.68,
      halationSoftKnee: 0.5,
      lensSoftness: 0.06,
      opticalWarmScatter: 0.28,
      opticalSpectralTail: 0.06,
    },
    behavior: behavior({
      warmth: 0.28,
      spectralTail: 0.06,
      highlightReactivity: 0.45,
      depthResponse: 0.1,
    }),
  },
  {
    id: "pearlGlow-subtle",
    family: "pearlGlow",
    density: "subtle",
    displayName: "Pearl Glow Subtle",
    shortLabel: "Subtle",
    description: "Polished skin softness with minimal halo.",
    params: {
      bloomThreshold: 0.84,
      bloomStrength: 0.06,
      bloomRadius: 0.34,
      diffusion: 0.045,
      halationIntensity: 0.015,
      halationSpread: 14,
      halationRadius: 0.26,
      bloomSoftKnee: 0.58,
      lensSoftness: 0.055,
    },
    behavior: behavior({ scatterCore: 0.45, scatterTail: 0.24 }),
  },
  {
    id: "pearlGlow-1-4",
    family: "pearlGlow",
    density: "1/4",
    displayName: "Pearl Glow 1/4",
    shortLabel: "1/4",
    description: "Beauty-forward diffusion with clean highlights.",
    params: {
      bloomThreshold: 0.8,
      bloomStrength: 0.1,
      bloomRadius: 0.42,
      diffusion: 0.085,
      halationIntensity: 0.025,
      halationSpread: 16,
      halationRadius: 0.3,
      bloomSoftKnee: 0.64,
      lensSoftness: 0.08,
    },
    behavior: behavior({ scatterCore: 0.5, scatterTail: 0.32 }),
  },
  {
    id: "cleanSoft-subtle",
    family: "cleanSoft",
    density: "subtle",
    displayName: "Clean Soft Subtle",
    shortLabel: "Subtle",
    description: "Less clinical sharpness without obvious filter glow.",
    params: {
      bloomThreshold: 0.9,
      bloomStrength: 0.035,
      bloomRadius: 0.28,
      diffusion: 0.02,
      halationIntensity: 0,
      lensSoftness: 0.075,
      rgbShift: 0.0006,
    },
    behavior: behavior({ scatterCore: 0.32, scatterTail: 0.16 }),
  },
] as const satisfies readonly OpticalFilterProfile[];

export type OpticalFilterProfileId =
  (typeof OPTICAL_FILTER_PROFILES)[number]["id"];

export function getOpticalFilterProfile(
  id: OpticalFilterProfileId | string,
): OpticalFilterProfile | null {
  return OPTICAL_FILTER_PROFILES.find((profile) => profile.id === id) ?? null;
}

export function buildOpticalFilterParamPatch(
  id: OpticalFilterProfileId | string,
): Partial<Params> {
  const profile = getOpticalFilterProfile(id);
  if (!profile) {
    throw new Error(`Unknown optical filter profile: ${id}`);
  }

  return {
    ...OPTICAL_FILTER_BASE_PATCH,
    ...profile.params,
  };
}
