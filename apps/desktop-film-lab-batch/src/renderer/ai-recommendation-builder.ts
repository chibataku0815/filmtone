/**
 * @file Dev-only PoC: maps an AI scene-pick decision into the existing
 * deterministic `OpticalRecommendationV1` shape. The AI never authors renderer
 * params directly — this builder is the single constrained bridge, so
 * `buildOpticalParamPatch` remains authoritative.
 */

import type {
  BehaviorProfile,
  OpticalFamily,
  OpticalRecipeId,
  OpticalRecommendationV1,
  SceneDescriptorV1,
} from "film-lab-core";

import type { AiScenePickResult } from "./ai-scene-pick";

const RECIPE_TO_PROFILE: Record<OpticalRecipeId, BehaviorProfile> = {
  warmIndoor: "warm",
  nightCity: "night",
  skinCloseUp: "portrait",
  nightSpot: "spotlight",
  productEdge: "product",
  coverStillMatch: "stillMatch",
};

function emptyDescriptor(): SceneDescriptorV1 {
  return {
    medianLuma: 0.5,
    highlightCoverage: 0.08,
    specularIslands: 0.1,
    pointLightScore: 0.1,
    globalContrast: 0.5,
    warmthScore: 0.3,
    portraitLikelihood: 0.2,
    nightScore: 0.2,
    sceneComplexity: 0.3,
    dominantShotCoverage: 0.8,
    sampleCount: 0,
  };
}

export function buildAiRecommendation(
  ai: AiScenePickResult,
  descriptor: SceneDescriptorV1 | null,
): OpticalRecommendationV1 | null {
  if (ai.manualFallback || ai.family == null) {
    return null;
  }

  const family: OpticalFamily = ai.family;
  const recipe: OpticalRecipeId | null = ai.recipe;
  const profile: BehaviorProfile =
    recipe != null ? RECIPE_TO_PROFILE[recipe] : "clean";
  const state: OpticalRecommendationV1["state"] =
    ai.confidence === "low" ? "low-confidence" : "ready";

  return {
    state,
    descriptor: descriptor ?? emptyDescriptor(),
    primary: {
      family,
      profile,
      recipe,
      confidence: ai.confidence,
      rationale:
        family === "mist"
          ? ["portraitSafe"]
          : family === "cross"
            ? ["pointLights"]
            : ["practicalLights"],
    },
    alternates: [],
  };
}
