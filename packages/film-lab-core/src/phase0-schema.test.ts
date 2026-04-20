import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  createDefaultPhase0Params,
  createPhase0ProjectState,
  interpolatePhase0PresetParams,
  mergePhase0Params,
  PHASE0_HALATION_HUE_MAX,
  PHASE0_HALATION_HUE_MIN,
  phase0ParamsSchema,
  phase0ProjectSchema,
  pickPhase0Params,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_RGB_SHIFT_MAX,
  PHASE0_SCHEMA_VERSION,
  PHASE0_PRESET_STRENGTH_DEFAULT,
} from "./phase0-schema";

describe("phase0 schema", () => {
  test("picks the reduced subset from a full preset", () => {
    const phase0 = pickPhase0Params(PRESETS.cinematic);
    expect(phase0.exposure).toBe(PRESETS.cinematic.exposure);
    expect(phase0.rgbShift).toBe(PRESETS.cinematic.rgbShift);
    expect(phase0.bloomStrength).toBe(PRESETS.cinematic.bloomStrength);
    expect(phase0.diffusion).toBe(PRESETS.cinematic.diffusion);
    expect(phase0.printContrast).toBe(PRESETS.cinematic.printContrast);
    expect(phase0.cyan).toBe(PRESETS.cinematic.cyan);
    expect(phase0.magenta).toBe(PRESETS.cinematic.magenta);
    expect(phase0.yellow).toBe(PRESETS.cinematic.yellow);
    expect(phase0.grainIntensity).toBe(PRESETS.cinematic.grainIntensity);
  });

  test("defaults to the cinematic preset", () => {
    const phase0 = createDefaultPhase0Params();
    expect(phase0).toEqual(pickPhase0Params(PRESETS.cinematic));
  });

  test("accepts halationHue slider boundary values", () => {
    const reset = pickPhase0Params(PRESETS.reset);

    expect(
      phase0ParamsSchema.parse({
        ...reset,
        halationHue: PHASE0_HALATION_HUE_MIN,
      }).halationHue,
    ).toBe(PHASE0_HALATION_HUE_MIN);
    expect(
      phase0ParamsSchema.parse({
        ...reset,
        halationHue: PHASE0_HALATION_HUE_MAX,
      }).halationHue,
    ).toBe(PHASE0_HALATION_HUE_MAX);
  });

  test("accepts rgbShift at the shared phase0 max", () => {
    const reset = pickPhase0Params(PRESETS.reset);

    expect(
      phase0ParamsSchema.parse({
        ...reset,
        rgbShift: PHASE0_RGB_SHIFT_MAX,
      }).rgbShift,
    ).toBe(PHASE0_RGB_SHIFT_MAX);
  });

  test("rejects out-of-range reduced params", () => {
    const result = phase0ParamsSchema.safeParse({
      ...pickPhase0Params(PRESETS.reset),
      vignette: 2,
    });
    expect(result.success).toBe(false);
  });

  test("rejects out-of-range halationHue slider values", () => {
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        halationHue: PHASE0_HALATION_HUE_MIN - 0.01,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        halationHue: PHASE0_HALATION_HUE_MAX + 0.01,
      }).success,
    ).toBe(false);
  });

  test("rejects rgbShift above the shared phase0 max", () => {
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        rgbShift: PHASE0_RGB_SHIFT_MAX + 0.0001,
      }).success,
    ).toBe(false);
  });

  test("merges and revalidates reduced params", () => {
    const merged = mergePhase0Params(pickPhase0Params(PRESETS.reset), {
      exposure: 0.25,
      vignette: 0.4,
      halationHue: PHASE0_HALATION_HUE_MAX,
    });
    expect(merged.exposure).toBe(0.25);
    expect(merged.vignette).toBe(0.4);
    expect(merged.halationHue).toBe(PHASE0_HALATION_HUE_MAX);
  });

  test("rejects out-of-range halationHue patches during merge", () => {
    expect(() =>
      mergePhase0Params(pickPhase0Params(PRESETS.reset), {
        halationHue: PHASE0_HALATION_HUE_MAX + 1,
      }),
    ).toThrow();
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
    expect(half.bloomStrength).toBeCloseTo((reset.bloomStrength + full.bloomStrength) / 2, 5);
  });

  test("merges sparse project params onto the derived preset base", () => {
    const baseInput = {
      schemaVersion: PHASE0_SCHEMA_VERSION,
      projectId: "derived-project",
      createdAt: "2026-04-19T00:00:00.000Z",
      updatedAt: "2026-04-19T00:00:00.000Z",
      presetName: "cinematic",
      strength: 0.5,
      quickState: {
        filmCharacter: 0,
        era: 1,
        dynamics: 0,
      },
      output: PHASE0_OUTPUT_PROFILE,
    };

    const base = phase0ProjectSchema.parse({
      ...baseInput,
      params: {},
    });
    const patched = phase0ProjectSchema.parse({
      ...baseInput,
      params: {
        halationHue: PHASE0_HALATION_HUE_MAX,
      },
    });

    expect(patched.params.halationHue).toBe(PHASE0_HALATION_HUE_MAX);
    expect(patched.params.exposure).toBe(base.params.exposure);
    expect(patched.params.halationSpread).toBe(base.params.halationSpread);
  });

  test("rejects out-of-range project param patches", () => {
    expect(() =>
      phase0ProjectSchema.parse({
        schemaVersion: PHASE0_SCHEMA_VERSION,
        projectId: "bad-project",
        createdAt: "2026-04-19T00:00:00.000Z",
        updatedAt: "2026-04-19T00:00:00.000Z",
        presetName: "cinematic",
        params: {
          halationHue: PHASE0_HALATION_HUE_MAX + 1,
        },
        output: PHASE0_OUTPUT_PROFILE,
      }),
    ).toThrow();
  });

  test("migrates legacy lut projects into creativeLut and widens missing params", () => {
    const legacy = phase0ProjectSchema.parse({
      schemaVersion: PHASE0_SCHEMA_VERSION,
      projectId: "legacy-project",
      createdAt: "2026-04-19T00:00:00.000Z",
      updatedAt: "2026-04-19T00:00:00.000Z",
      presetName: "cinematic",
      params: {
        exposure: PRESETS.cinematic.exposure,
        contrast: PRESETS.cinematic.contrast,
        saturation: PRESETS.cinematic.saturation,
        temperature: PRESETS.cinematic.temperature,
        tint: PRESETS.cinematic.tint,
        fade: PRESETS.cinematic.fade,
        vignette: PRESETS.cinematic.vignette,
        grainIntensity: PRESETS.cinematic.grainIntensity,
      },
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
    expect(legacy.params.bloomStrength).toBe(PRESETS.cinematic.bloomStrength);
    expect(legacy.params.diffusion).toBe(PRESETS.cinematic.diffusion);
    expect(legacy.params.halationHue).toBe(PRESETS.cinematic.halationHue);
    expect(legacy.params.printContrast).toBe(PRESETS.cinematic.printContrast);
    expect(legacy.params.cyan).toBe(PRESETS.cinematic.cyan);
    expect(legacy.params.magenta).toBe(PRESETS.cinematic.magenta);
    expect(legacy.params.yellow).toBe(PRESETS.cinematic.yellow);
  });
});
