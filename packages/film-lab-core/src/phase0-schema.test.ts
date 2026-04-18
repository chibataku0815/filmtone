import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  createDefaultPhase0Params,
  createPhase0ProjectState,
  interpolatePhase0PresetParams,
  mergePhase0Params,
  phase0ParamsSchema,
  phase0ProjectSchema,
  pickPhase0Params,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_PRESET_STRENGTH_DEFAULT,
} from "./phase0-schema";

describe("phase0 schema", () => {
  test("picks the reduced subset from a full preset", () => {
    const phase0 = pickPhase0Params(PRESETS.cinematic);
    expect(phase0.exposure).toBe(PRESETS.cinematic.exposure);
    expect(phase0.grainIntensity).toBe(PRESETS.cinematic.grainIntensity);
  });

  test("defaults to the cinematic preset", () => {
    const phase0 = createDefaultPhase0Params();
    expect(phase0).toEqual(pickPhase0Params(PRESETS.cinematic));
  });

  test("rejects out-of-range reduced params", () => {
    const result = phase0ParamsSchema.safeParse({
      ...pickPhase0Params(PRESETS.reset),
      vignette: 2,
    });
    expect(result.success).toBe(false);
  });

  test("merges and revalidates reduced params", () => {
    const merged = mergePhase0Params(pickPhase0Params(PRESETS.reset), {
      exposure: 0.25,
      vignette: 0.4,
    });
    expect(merged.exposure).toBe(0.25);
    expect(merged.vignette).toBe(0.4);
  });

  test("creates a project state with the fixed output profile", () => {
    const project = createPhase0ProjectState();
    expect(project.output).toEqual(PHASE0_OUTPUT_PROFILE);
    expect(project.params).toEqual(pickPhase0Params(PRESETS.cinematic));
    expect(project.strength).toBe(PHASE0_PRESET_STRENGTH_DEFAULT);
    expect(project.inputLut).toBeNull();
    expect(project.creativeLut).toBeNull();
  });

  test("interpolates preset params from reset by strength", () => {
    const half = interpolatePhase0PresetParams("cinematic", 0.5);
    const full = pickPhase0Params(PRESETS.cinematic);
    const reset = pickPhase0Params(PRESETS.reset);

    expect(half.exposure).toBeCloseTo((reset.exposure + full.exposure) / 2, 5);
    expect(half.contrast).toBeCloseTo((reset.contrast + full.contrast) / 2, 5);
  });

  test("migrates legacy lut projects into creativeLut", () => {
    const legacy = phase0ProjectSchema.parse({
      schemaVersion: 1,
      projectId: "legacy-project",
      createdAt: "2026-04-19T00:00:00.000Z",
      updatedAt: "2026-04-19T00:00:00.000Z",
      presetName: "cinematic",
      params: pickPhase0Params(PRESETS.cinematic),
      lut: {
        title: "Legacy Look",
        size: 2,
        data: Array(32).fill(1),
        intensity: 0.6,
      },
      output: PHASE0_OUTPUT_PROFILE,
    });

    expect(legacy.inputLut).toBeNull();
    expect(legacy.creativeLut?.title).toBe("Legacy Look");
    expect(legacy.creativeLut?.intensity).toBe(0.6);
  });
});
