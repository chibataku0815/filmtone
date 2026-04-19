import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  createDefaultPhase0Params,
  createPhase0ProjectState,
  mergePhase0Params,
  phase0ParamsSchema,
  pickPhase0Params,
  PHASE0_OUTPUT_PROFILE,
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
  });
});
