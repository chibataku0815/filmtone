import { describe, expect, test } from "bun:test";
import {
  buildOpticalParamPatch,
  recommendOpticalFinish,
  type SceneDescriptorV1,
} from "./optical-recommendation";

function descriptor(
  patch: Partial<SceneDescriptorV1>,
): SceneDescriptorV1 {
  return {
    medianLuma: 0.5,
    highlightCoverage: 0.04,
    specularIslands: 0.2,
    pointLightScore: 0.2,
    globalContrast: 0.45,
    warmthScore: 0.4,
    portraitLikelihood: 0.2,
    nightScore: 0.2,
    sceneComplexity: 0.35,
    dominantShotCoverage: 0.82,
    ...patch,
  };
}

describe("recommendOpticalFinish", () => {
  test("warm indoor practical lights -> Glow / warmIndoor", () => {
    const recommendation = recommendOpticalFinish(
      descriptor({
        medianLuma: 0.42,
        highlightCoverage: 0.14,
        specularIslands: 0.48,
        pointLightScore: 0.44,
        globalContrast: 0.58,
        warmthScore: 0.76,
        nightScore: 0.32,
      }),
    );

    expect(recommendation.state).toBe("ready");
    expect(recommendation.primary.family).toBe("glow");
    expect(recommendation.primary.recipe).toBe("warmIndoor");
  });

  test("city night isolated lights -> Cross / nightSpot", () => {
    const recommendation = recommendOpticalFinish(
      descriptor({
        medianLuma: 0.18,
        highlightCoverage: 0.1,
        specularIslands: 0.84,
        pointLightScore: 0.88,
        globalContrast: 0.74,
        warmthScore: 0.28,
        nightScore: 0.82,
        sceneComplexity: 0.58,
      }),
    );

    expect(recommendation.state).toBe("ready");
    expect(recommendation.primary.family).toBe("cross");
    expect(recommendation.primary.recipe).toBe("nightSpot");
  });

  test("daylight close-up portrait -> Mist / skinCloseUp", () => {
    const recommendation = recommendOpticalFinish(
      descriptor({
        medianLuma: 0.62,
        highlightCoverage: 0.03,
        specularIslands: 0.08,
        pointLightScore: 0.14,
        globalContrast: 0.36,
        warmthScore: 0.46,
        portraitLikelihood: 0.82,
        nightScore: 0.08,
        sceneComplexity: 0.24,
      }),
    );

    expect(recommendation.state).toBe("ready");
    expect(recommendation.primary.family).toBe("mist");
    expect(recommendation.primary.recipe).toBe("skinCloseUp");
  });

  test("mixed montage with no dominant shot -> low-confidence + safe Mist fallback", () => {
    const recommendation = recommendOpticalFinish(
      descriptor({
        medianLuma: 0.32,
        highlightCoverage: 0.15,
        specularIslands: 0.76,
        pointLightScore: 0.84,
        globalContrast: 0.66,
        warmthScore: 0.52,
        portraitLikelihood: 0.48,
        nightScore: 0.64,
        sceneComplexity: 0.72,
        dominantShotCoverage: 0.34,
      }),
    );

    expect(recommendation.state).toBe("low-confidence");
    expect(recommendation.primary.family).toBe("mist");
    expect(recommendation.primary.profile).toBe("clean");
    expect(recommendation.primary.recipe).toBeNull();
  });
});

describe("buildOpticalParamPatch", () => {
  test("changes only the optical lane", () => {
    const recommendation = recommendOpticalFinish(
      descriptor({
        highlightCoverage: 0.14,
        specularIslands: 0.48,
        warmthScore: 0.76,
      }),
    );

    const patch = buildOpticalParamPatch(recommendation);
    expect(Object.keys(patch).sort()).toEqual([
      "bloomRadius",
      "bloomSoftKnee",
      "bloomStrength",
      "bloomThreshold",
      "crossFilterAngle",
      "crossFilterChromatic",
      "crossFilterHardMode",
      "crossFilterLength",
      "crossFilterMinSpacing",
      "crossFilterRandomness",
      "crossFilterSizeLimit",
      "crossFilterSpikes",
      "crossFilterStrength",
      "crossFilterThreshold",
      "diffusion",
      "halationHue",
      "halationIntensity",
      "halationRadius",
      "halationSoftKnee",
      "halationSpread",
      "halationThreshold",
      "lensSoftness",
      "rgbShift",
    ]);
  });
});
