import { describe, expect, test } from "bun:test";
import { filmLabParamsSchema, filmLookGradeInputSchema } from "./schema";
import { PRESETS } from "./presets";
import { LOOK_ID_BY_PRESET, PRESET_VERSION } from "./look-ids";

describe("filmLabParamsSchema", () => {
  test("accepts cinematic preset", () => {
    const r = filmLabParamsSchema.safeParse(PRESETS.cinematic);
    expect(r.success).toBe(true);
  });

  test("rejects missing key", () => {
    const bad = { ...PRESETS.cinematic };
    delete (bad as Record<string, unknown>).exposure;
    const r = filmLabParamsSchema.safeParse(bad);
    expect(r.success).toBe(false);
  });

  test("grainRadialMix 省略時は既定 1（後方互換）", () => {
    const { grainRadialMix: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.grainRadialMix).toBe(1);
    }
  });

  test("lensSoftness 省略時は既定 0（後方互換）", () => {
    const { lensSoftness: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.lensSoftness).toBe(0);
    }
  });
});

describe("filmLookGradeInputSchema", () => {
  test("accepts valid bundle", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
    });
    expect(r.success).toBe(true);
  });

  test("rejects wrong version", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: "v0",
      grade: PRESETS.portra,
    });
    expect(r.success).toBe(false);
  });

  test("optional LUT フィールドなしでも受理する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
    });
    expect(r.success).toBe(true);
  });

  test("LUT 相対パス・強度を付けて受理する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
      lutCubeRelPath: "luts/warm-cinematic.cube",
      lutEnabled: true,
      lutIntensity: 0.85,
    });
    expect(r.success).toBe(true);
  });

  test("動画ソースパスと解像度を付けて受理する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
      gradeSourceVideoRelPath: "videos/IMG_0513.MOV",
      gradeSourceVideoWidth: 3840,
      gradeSourceVideoHeight: 2160,
    });
    expect(r.success).toBe(true);
  });
});
