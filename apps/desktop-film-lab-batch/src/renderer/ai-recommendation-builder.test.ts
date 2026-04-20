import { describe, expect, it } from "vitest";
import type { SceneDescriptorV1 } from "film-lab-core";
import { buildOpticalParamPatch } from "film-lab-core";

import { buildAiRecommendation } from "./ai-recommendation-builder";
import type { AiScenePickResult } from "./ai-scene-pick";

const DESCRIPTOR: SceneDescriptorV1 = {
  medianLuma: 0.5,
  highlightCoverage: 0.12,
  specularIslands: 0.3,
  pointLightScore: 0.4,
  globalContrast: 0.5,
  warmthScore: 0.6,
  portraitLikelihood: 0.2,
  nightScore: 0.3,
  sceneComplexity: 0.3,
  dominantShotCoverage: 0.9,
  sampleCount: 12,
};

function aiResult(overrides: Partial<AiScenePickResult> = {}): AiScenePickResult {
  return {
    bestFrameIndex: 5,
    family: "glow",
    recipe: "warmIndoor",
    confidence: "high",
    manualFallback: false,
    reason: "warm practical lights",
    latencyMs: 100,
    ...overrides,
  };
}

describe("buildAiRecommendation", () => {
  it("returns null when manualFallback is true", () => {
    expect(buildAiRecommendation(aiResult({ manualFallback: true }), DESCRIPTOR)).toBe(null);
  });

  it("returns null when family is null", () => {
    expect(buildAiRecommendation(aiResult({ family: null }), DESCRIPTOR)).toBe(null);
  });

  it("builds a ready recommendation for high-confidence input", () => {
    const rec = buildAiRecommendation(aiResult(), DESCRIPTOR);
    expect(rec).not.toBe(null);
    if (!rec) return;
    expect(rec.state).toBe("ready");
    expect(rec.primary.family).toBe("glow");
    expect(rec.primary.recipe).toBe("warmIndoor");
    expect(rec.primary.profile).toBe("warm");
    expect(rec.primary.confidence).toBe("high");
    expect(rec.alternates).toEqual([]);
    expect(rec.descriptor).toBe(DESCRIPTOR);
  });

  it("maps low confidence to low-confidence state", () => {
    const rec = buildAiRecommendation(
      aiResult({ confidence: "low" }),
      DESCRIPTOR,
    );
    expect(rec?.state).toBe("low-confidence");
  });

  it("uses a fallback descriptor when none supplied", () => {
    const rec = buildAiRecommendation(aiResult(), null);
    expect(rec?.descriptor.sampleCount).toBe(0);
  });

  it("produces a valid patch for recipe=null via family:clean fallback", () => {
    const rec = buildAiRecommendation(
      aiResult({ family: "mist", recipe: null }),
      DESCRIPTOR,
    );
    expect(rec).not.toBe(null);
    if (!rec) return;
    expect(rec.primary.profile).toBe("clean");
    expect(rec.primary.recipe).toBe(null);

    const patch = buildOpticalParamPatch(rec);
    // mist:clean patch sets diffusion; value should be present and numeric.
    expect(typeof patch.diffusion).toBe("number");
  });

  it("maps each recipe to its corresponding profile", () => {
    const cases: Array<
      [AiScenePickResult["recipe"], string]
    > = [
      ["warmIndoor", "warm"],
      ["nightCity", "night"],
      ["skinCloseUp", "portrait"],
      ["nightSpot", "spotlight"],
      ["productEdge", "product"],
      ["coverStillMatch", "stillMatch"],
    ];
    for (const [recipe, expectedProfile] of cases) {
      const rec = buildAiRecommendation(
        aiResult({ family: recipe === "nightSpot" ? "cross" : "glow", recipe }),
        DESCRIPTOR,
      );
      expect(rec?.primary.profile).toBe(expectedProfile);
    }
  });
});
