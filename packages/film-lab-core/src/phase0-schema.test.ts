import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  createDefaultPhase0Params,
  createFilmtoneDefaultPhase0Params,
  createPhase0ProjectState,
  interpolatePhase0PresetParams,
  mergePhase0Params,
  PHASE0_HALATION_HUE_MAX,
  PHASE0_HALATION_HUE_MIN,
  phase0ParamsSchema,
  phase0ProjectSchema,
  pickPhase0Params,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_PARAM_KEYS,
  PHASE0_RGB_SHIFT_MAX,
  PHASE0_SCHEMA_VERSION,
  PHASE0_PRESET_DEFAULT,
  PHASE0_PRESET_STRENGTH_DEFAULT,
} from "./phase0-schema";
import { FILM_GRAIN_INTENSITY_MAX } from "./params";

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
    expect(phase0.shutterAngle).toBe(PRESETS.cinematic.shutterAngle);
    expect(phase0.trailIntensity).toBe(PRESETS.cinematic.trailIntensity);
    expect(phase0.filmBreathAmount).toBe(PRESETS.cinematic.filmBreathAmount);
    expect(phase0.dustAmount).toBe(PRESETS.cinematic.dustAmount);
    expect(phase0.scratchAmount).toBe(PRESETS.cinematic.scratchAmount);
    expect(phase0.grainIntensity).toBe(PRESETS.cinematic.grainIntensity);
    expect(phase0.detailSoftness).toBe(PRESETS.cinematic.detailSoftness);
    expect(phase0.shadowLatitude).toBe(PRESETS.cinematic.shadowLatitude);
  });

  test("detailSoftness defaults to 0 when omitted from a phase0 patch", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { detailSoftness: _omit, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    expect(parsed.detailSoftness).toBe(0);
  });

  test("detailSoftness accepts 0/1 boundaries and rejects out-of-range values", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    for (const val of [0, 1]) {
      expect(phase0ParamsSchema.parse({ ...reset, detailSoftness: val }).detailSoftness).toBe(val);
    }
    for (const val of [-0.01, 1.01]) {
      expect(
        phase0ParamsSchema.safeParse({ ...reset, detailSoftness: val }).success,
      ).toBe(false);
    }
  });

  test("shadowLatitude defaults to 0 when omitted from a phase0 patch", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { shadowLatitude: _omit, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    expect(parsed.shadowLatitude).toBe(0);
  });

  test("shadowLatitude accepts 0/1 boundaries and rejects out-of-range values", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    for (const val of [0, 1]) {
      expect(phase0ParamsSchema.parse({ ...reset, shadowLatitude: val }).shadowLatitude).toBe(val);
    }
    for (const val of [-0.01, 1.01]) {
      expect(
        phase0ParamsSchema.safeParse({ ...reset, shadowLatitude: val }).success,
      ).toBe(false);
    }
  });

  test("blackPoint defaults to 0 when omitted from a phase0 patch", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { blackPoint: _omit, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    expect(parsed.blackPoint).toBe(0);
  });

  test("blackPoint accepts -1/+1 boundaries and rejects out-of-range values", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    for (const val of [-1, -0.5, 0, 0.5, 1]) {
      expect(phase0ParamsSchema.parse({ ...reset, blackPoint: val }).blackPoint).toBe(val);
    }
    for (const val of [-1.01, 1.01]) {
      expect(
        phase0ParamsSchema.safeParse({ ...reset, blackPoint: val }).success,
      ).toBe(false);
    }
  });

  test("toeContrast defaults to 0 when omitted from a phase0 patch", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { toeContrast: _omit, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    expect(parsed.toeContrast).toBe(0);
  });

  test("toeContrast accepts 0/1 boundaries and rejects out-of-range values", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    for (const val of [0, 0.5, 1]) {
      expect(phase0ParamsSchema.parse({ ...reset, toeContrast: val }).toeContrast).toBe(val);
    }
    for (const val of [-0.01, 1.01]) {
      expect(
        phase0ParamsSchema.safeParse({ ...reset, toeContrast: val }).success,
      ).toBe(false);
    }
  });

  test("mergePhase0Params preserves detailSoftness and still strips unknown keys", () => {
    const merged = mergePhase0Params(pickPhase0Params(PRESETS.reset), {
      detailSoftness: 0.42,
      shadowLatitude: 0.42,
      // unknown sibling — must be stripped, not retained
      // @ts-expect-error: intentionally probing strip behavior
      bogusUnknownKey: 1,
    });
    expect(merged.detailSoftness).toBe(0.42);
    expect(merged.shadowLatitude).toBe(0.42);
    expect((merged as Record<string, unknown>).bogusUnknownKey).toBeUndefined();
  });

  test("defaults to reset identity with the shared soft finish", () => {
    const phase0 = createDefaultPhase0Params();
    const pureReset = pickPhase0Params(PRESETS.reset);
    const softDefault = createFilmtoneDefaultPhase0Params();

    expect(PHASE0_PRESET_DEFAULT).toBe("reset");
    expect(phase0).toEqual(softDefault);
    expect(phase0).not.toEqual(pureReset);
    expect(phase0.bloomStrength).toBeGreaterThan(pureReset.bloomStrength);
    expect(phase0.halationIntensity).toBeGreaterThan(pureReset.halationIntensity);
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

  test("accepts motion slider boundary values", () => {
    const reset = pickPhase0Params(PRESETS.reset);

    expect(
      phase0ParamsSchema.parse({
        ...reset,
        shutterAngle: 720,
        trailIntensity: 0.95,
        filmBreathAmount: 1,
      }).shutterAngle,
    ).toBe(720);
    expect(
      phase0ParamsSchema.parse({
        ...reset,
        shutterAngle: 0,
        trailIntensity: 0,
        filmBreathAmount: 0,
      }).trailIntensity,
    ).toBe(0);
  });

  test("filmBreathAmount defaults to 0 and lands directly after trailIntensity", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { filmBreathAmount: _omit, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    const trailIndex = PHASE0_PARAM_KEYS.indexOf("trailIntensity");
    const breathIndex = PHASE0_PARAM_KEYS.indexOf("filmBreathAmount");

    expect(parsed.filmBreathAmount).toBe(0);
    expect(breathIndex).toBe(trailIndex + 1);
  });

  test("film damage params default to 0 and land after filmBreathAmount", () => {
    const reset = pickPhase0Params(PRESETS.reset);
    const { dustAmount: _omitDust, scratchAmount: _omitScratch, ...sparse } = reset;
    const parsed = phase0ParamsSchema.parse(sparse);
    const breathIndex = PHASE0_PARAM_KEYS.indexOf("filmBreathAmount");
    const dustIndex = PHASE0_PARAM_KEYS.indexOf("dustAmount");
    const scratchIndex = PHASE0_PARAM_KEYS.indexOf("scratchAmount");

    expect(parsed.dustAmount).toBe(0);
    expect(parsed.scratchAmount).toBe(0);
    expect(dustIndex).toBe(breathIndex + 1);
    expect(scratchIndex).toBe(dustIndex + 1);
  });

  test("rejects out-of-range reduced params", () => {
    const result = phase0ParamsSchema.safeParse({
      ...pickPhase0Params(PRESETS.reset),
      vignette: 2,
    });
    expect(result.success).toBe(false);
  });

  test("caps legacy over-strong reduced grain at the product-safe maximum", () => {
    const result = phase0ParamsSchema.parse({
      ...pickPhase0Params(PRESETS.reset),
      grainIntensity: 0.18,
    });
    expect(result.grainIntensity).toBe(FILM_GRAIN_INTENSITY_MAX);
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

  test("rejects out-of-range motion slider values", () => {
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        shutterAngle: 721,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        trailIntensity: 0.951,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        filmBreathAmount: -0.001,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        filmBreathAmount: 1.001,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        dustAmount: -0.001,
      }).success,
    ).toBe(false);
    expect(
      phase0ParamsSchema.safeParse({
        ...pickPhase0Params(PRESETS.reset),
        scratchAmount: 1.001,
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
    expect(project.presetName).toBe("reset");
    expect(project.params).toEqual(createFilmtoneDefaultPhase0Params());
    expect(project.strength).toBe(PHASE0_PRESET_STRENGTH_DEFAULT);
    expect(project.inputLut).toBeNull();
    expect(project.creativeLut).toBeNull();
  });

  test("interpolates the reset default from pure reset to soft finish", () => {
    const pureReset = pickPhase0Params(PRESETS.reset);
    const softDefault = createFilmtoneDefaultPhase0Params();
    const zero = interpolatePhase0PresetParams("reset", 0);
    const full = interpolatePhase0PresetParams("reset", 1);
    const half = interpolatePhase0PresetParams("reset", 0.5);

    expect(zero).toEqual(pureReset);
    expect(full).toEqual(softDefault);
    expect(half.bloomStrength).toBeCloseTo(
      (pureReset.bloomStrength + softDefault.bloomStrength) / 2,
      5,
    );
    expect(half.halationIntensity).toBeCloseTo(
      (pureReset.halationIntensity + softDefault.halationIntensity) / 2,
      5,
    );
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

  test("falls back unknown presets to the reset soft default", () => {
    const parsed = phase0ProjectSchema.parse({
      schemaVersion: PHASE0_SCHEMA_VERSION,
      projectId: "unknown-preset-project",
      createdAt: "2026-04-19T00:00:00.000Z",
      updatedAt: "2026-04-19T00:00:00.000Z",
      presetName: "missing-preset",
      params: {},
      output: PHASE0_OUTPUT_PROFILE,
    });

    expect(parsed.presetName).toBe("reset");
    expect(parsed.params).toEqual(createFilmtoneDefaultPhase0Params());
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
