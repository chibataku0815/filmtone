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
});
