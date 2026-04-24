import type { Params } from "./params";
import { PRESETS } from "./presets";

export type OpticalFamily = "mist" | "glow" | "cross" | "lens";

export type BehaviorProfile =
  | "clean"
  | "warm"
  | "night"
  | "portrait"
  | "spotlight"
  | "product"
  | "stillMatch";

export type OpticalRecipeId =
  | "warmIndoor"
  | "nightCity"
  | "skinCloseUp"
  | "nightSpot"
  | "productEdge"
  | "coverStillMatch";

export type SceneAnalysisState =
  | "idle"
  | "analyzing"
  | "ready"
  | "low-confidence"
  | "error";

export interface SceneDescriptorV1 {
  medianLuma: number;
  highlightCoverage: number;
  specularIslands: number;
  pointLightScore: number;
  globalContrast: number;
  warmthScore: number;
  portraitLikelihood: number;
  nightScore: number;
  sceneComplexity: number;
  dominantShotCoverage: number;
  sampleCount?: number;
}

type RecommendationConfidence = "low" | "medium" | "high";

type RationaleTag =
  | "practicalLights"
  | "portraitSafe"
  | "pointLights"
  | "mixedScenes";

type OpticalRecommendationEntry = {
  family: OpticalFamily;
  profile: BehaviorProfile;
  recipe: OpticalRecipeId | null;
  confidence: RecommendationConfidence;
  rationale: RationaleTag[];
};

export interface OpticalRecommendationV1 {
  state: Extract<SceneAnalysisState, "ready" | "low-confidence">;
  descriptor: SceneDescriptorV1;
  primary: OpticalRecommendationEntry;
  alternates: OpticalRecommendationEntry[];
}

export interface OpticalAnalyzerProvider {
  readonly analyzerVersion: string;
  analyze(input: {
    sourcePath: string;
    sourceUrl?: string | null;
    trimStartSec: number;
    trimEndSec: number;
    sourceDurationSec: number;
  }): Promise<{
    state: SceneAnalysisState;
    descriptor: SceneDescriptorV1 | null;
    recommendation: OpticalRecommendationV1 | null;
  }>;
}

const OPTICAL_PARAM_KEYS = [
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
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
  "crossFilterEdgeLengthGain",
  "crossFilterEdgeStrengthGain",
  "rgbShift",
  "lensSoftness",
] as const;

type OpticalParamKey = (typeof OPTICAL_PARAM_KEYS)[number];

type OpticalParamPatch = Pick<Params, OpticalParamKey>;

const OPTICAL_BASE_PATCH = Object.fromEntries(
  OPTICAL_PARAM_KEYS.map((key) => [key, PRESETS.reset[key]]),
) as OpticalParamPatch;

const OPTICAL_RECIPE_PATCHES: Record<
  OpticalRecipeId | `${OpticalFamily}:clean`,
  Partial<OpticalParamPatch>
> = {
  "mist:clean": {
    diffusion: 0.08,
    bloomStrength: 0.06,
    bloomThreshold: 0.84,
    bloomRadius: 0.36,
    halationIntensity: 0.03,
    halationSpread: 15,
    halationRadius: 0.28,
    halationHue: 18,
  },
  "glow:clean": {
    bloomStrength: 0.22,
    bloomThreshold: 0.72,
    bloomRadius: 0.52,
    diffusion: 0.08,
    halationIntensity: 0.1,
    halationSpread: 22,
    halationRadius: 0.44,
    halationHue: 20,
  },
  "cross:clean": {
    crossFilterStrength: 0.28,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.2,
    crossFilterSizeLimit: 0.12,
    crossFilterRandomness: 0.9,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1,
    crossFilterDepthGain: 0.25,
    crossFilterAngleGain: 0.35,
    crossFilterAngleGamma: 1.4,
    crossFilterEdgeLengthGain: 0.45,
    crossFilterEdgeStrengthGain: 0.25,
  },
  "lens:clean": {
    rgbShift: 0.0008,
    lensSoftness: 0.08,
  },
  warmIndoor: {
    bloomStrength: 0.28,
    bloomThreshold: 0.7,
    bloomRadius: 0.54,
    diffusion: 0.1,
    halationIntensity: 0.12,
    halationSpread: 24,
    halationRadius: 0.46,
    halationHue: 24,
  },
  nightCity: {
    bloomStrength: 0.34,
    bloomThreshold: 0.68,
    bloomRadius: 0.62,
    diffusion: 0.1,
    halationIntensity: 0.16,
    halationSpread: 28,
    halationRadius: 0.58,
    halationHue: 18,
  },
  skinCloseUp: {
    diffusion: 0.14,
    bloomStrength: 0.1,
    bloomThreshold: 0.82,
    bloomRadius: 0.38,
    halationIntensity: 0.05,
    halationSpread: 18,
    halationRadius: 0.32,
    halationHue: 20,
  },
  nightSpot: {
    crossFilterStrength: 0.56,
    crossFilterSpikes: 6,
    crossFilterAngle: 12,
    crossFilterLength: 0.66,
    crossFilterThreshold: 0.9,
    crossFilterChromatic: 0.38,
    crossFilterSizeLimit: 0.2,
    crossFilterRandomness: 0.72,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1.2,
  },
  productEdge: {
    rgbShift: 0.0015,
    lensSoftness: 0.18,
  },
  coverStillMatch: {
    rgbShift: 0.0008,
    lensSoftness: 0.12,
  },
};

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}

function normalizeDescriptor(descriptor: SceneDescriptorV1): SceneDescriptorV1 {
  return {
    medianLuma: clamp01(descriptor.medianLuma),
    highlightCoverage: clamp01(descriptor.highlightCoverage),
    specularIslands: clamp01(descriptor.specularIslands),
    pointLightScore: clamp01(descriptor.pointLightScore),
    globalContrast: clamp01(descriptor.globalContrast),
    warmthScore: clamp01(descriptor.warmthScore),
    portraitLikelihood: clamp01(descriptor.portraitLikelihood),
    nightScore: clamp01(descriptor.nightScore),
    sceneComplexity: clamp01(descriptor.sceneComplexity),
    dominantShotCoverage: clamp01(descriptor.dominantShotCoverage),
    sampleCount:
      typeof descriptor.sampleCount === "number" && descriptor.sampleCount > 0
        ? Math.round(descriptor.sampleCount)
        : undefined,
  };
}

function buildScores(descriptor: SceneDescriptorV1): Record<OpticalFamily, number> {
  const glowScore = clamp01(
    descriptor.highlightCoverage * 1.4 +
      descriptor.specularIslands * 0.22 +
      descriptor.warmthScore * 0.26 +
      descriptor.globalContrast * 0.18 +
      descriptor.pointLightScore * 0.08 +
      (1 - descriptor.sceneComplexity) * 0.12,
  );
  const crossScore = clamp01(
    descriptor.pointLightScore * 0.56 +
      descriptor.specularIslands * 0.16 +
      descriptor.nightScore * 0.16 +
      descriptor.globalContrast * 0.08 +
      descriptor.sceneComplexity * 0.04,
  );
  const mistScore = clamp01(
    descriptor.portraitLikelihood * 0.44 +
      (1 - descriptor.highlightCoverage) * 0.16 +
      (1 - descriptor.pointLightScore) * 0.18 +
      descriptor.medianLuma * 0.08 +
      descriptor.warmthScore * 0.06 +
      (1 - descriptor.sceneComplexity) * 0.08,
  );
  const lensScore = clamp01(
    descriptor.globalContrast * 0.24 +
      (1 - descriptor.sceneComplexity) * 0.18 +
      descriptor.specularIslands * 0.12,
  );

  return {
    mist: mistScore,
    glow: glowScore,
    cross: crossScore,
    lens: lensScore,
  };
}

function entryConfidence(
  familyScore: number,
  lowConfidence: boolean,
): RecommendationConfidence {
  if (lowConfidence) return "low";
  if (familyScore >= 0.78) return "high";
  if (familyScore >= 0.58) return "medium";
  return "low";
}

function pickProfileAndRecipe(
  family: OpticalFamily,
  descriptor: SceneDescriptorV1,
): Pick<OpticalRecommendationEntry, "profile" | "recipe"> {
  if (family === "glow") {
    if (
      descriptor.warmthScore >= 0.58 &&
      descriptor.warmthScore >= descriptor.nightScore
    ) {
      return { profile: "warm", recipe: "warmIndoor" };
    }
    if (descriptor.nightScore >= 0.55) {
      return { profile: "night", recipe: "nightCity" };
    }
  }

  if (family === "mist" && descriptor.portraitLikelihood >= 0.55) {
    return { profile: "portrait", recipe: "skinCloseUp" };
  }

  if (family === "cross") {
    return { profile: "spotlight", recipe: "nightSpot" };
  }

  if (family === "lens") {
    if (descriptor.globalContrast >= 0.72) {
      return { profile: "product", recipe: "productEdge" };
    }
    return { profile: "stillMatch", recipe: "coverStillMatch" };
  }

  return { profile: "clean", recipe: null };
}

function dedupeRationale(tags: RationaleTag[]): RationaleTag[] {
  return Array.from(new Set(tags));
}

function buildRationale(
  family: OpticalFamily,
  descriptor: SceneDescriptorV1,
  lowConfidence: boolean,
): RationaleTag[] {
  const tags: RationaleTag[] = [];
  if (family === "glow") {
    if (descriptor.highlightCoverage >= 0.08 || descriptor.warmthScore >= 0.58) {
      tags.push("practicalLights");
    }
  }
  if (family === "mist" && descriptor.portraitLikelihood >= 0.55) {
    tags.push("portraitSafe");
  }
  if (family === "cross" || descriptor.pointLightScore >= 0.6) {
    tags.push("pointLights");
  }
  if (lowConfidence || descriptor.dominantShotCoverage < 0.45) {
    tags.push("mixedScenes");
  }
  if (tags.length === 0 && family === "mist") {
    tags.push("portraitSafe");
  }
  if (tags.length === 0) {
    tags.push("practicalLights");
  }
  return dedupeRationale(tags);
}

function createEntry(
  family: OpticalFamily,
  descriptor: SceneDescriptorV1,
  familyScore: number,
  lowConfidence: boolean,
): OpticalRecommendationEntry {
  const recipeInfo = pickProfileAndRecipe(family, descriptor);
  return {
    family,
    profile: recipeInfo.profile,
    recipe: recipeInfo.recipe,
    confidence: entryConfidence(familyScore, lowConfidence),
    rationale: buildRationale(family, descriptor, lowConfidence),
  };
}

export function recommendOpticalFinish(
  descriptor: SceneDescriptorV1,
): OpticalRecommendationV1 {
  const normalizedDescriptor = normalizeDescriptor(descriptor);
  const scores = buildScores(normalizedDescriptor);
  const lowConfidence = normalizedDescriptor.dominantShotCoverage < 0.45;

  const crossEligible =
    normalizedDescriptor.pointLightScore >= 0.6 && scores.cross >= 0.72;
  const glowEligible =
    normalizedDescriptor.highlightCoverage >= 0.08 && scores.glow >= 0.62;

  let primaryFamily: OpticalFamily = "mist";
  if (!lowConfidence) {
    if (crossEligible && scores.cross >= scores.glow) {
      primaryFamily = "cross";
    } else if (glowEligible) {
      primaryFamily = "glow";
    }
  }

  const rankedFamilies = (["mist", "glow", "cross"] as const)
    .filter((family) => family !== primaryFamily)
    .sort((left, right) => scores[right] - scores[left]);

  const alternates = rankedFamilies.slice(0, 2).map((family) =>
    createEntry(family, normalizedDescriptor, scores[family], lowConfidence),
  );

  return {
    state: lowConfidence ? "low-confidence" : "ready",
    descriptor: normalizedDescriptor,
    primary: createEntry(
      primaryFamily,
      normalizedDescriptor,
      scores[primaryFamily],
      lowConfidence,
    ),
    alternates,
  };
}

export function buildOpticalParamPatch(
  recommendation: OpticalRecommendationV1,
): Partial<Params> {
  const primary = recommendation.primary;
  const recipeKey = primary.recipe ?? `${primary.family}:clean`;
  const recipePatch = OPTICAL_RECIPE_PATCHES[recipeKey];
  return {
    ...OPTICAL_BASE_PATCH,
    ...recipePatch,
  };
}
