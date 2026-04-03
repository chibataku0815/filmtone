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

  // === 0.4.0 新規キー: デフォルトフォールバック ===

  test("6 新キー全省略時でもパース成功 — デフォルト充填される", () => {
    const {
      compressionAmount: _ca,
      compressionRange: _cr,
      printContrast: _pc,
      cyan: _cy,
      magenta: _mg,
      yellow: _yl,
      ...rest
    } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
  });

  test("compressionAmount 省略時は既定 0", () => {
    const { compressionAmount: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.compressionAmount).toBe(0);
    }
  });

  test("compressionRange 省略時は既定 0.5（0 ではない）", () => {
    const { compressionRange: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.compressionRange).toBe(0.5);
    }
  });

  test("printContrast 省略時は既定 0", () => {
    const { printContrast: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.printContrast).toBe(0);
    }
  });

  test("cyan 省略時は既定 0", () => {
    const { cyan: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.cyan).toBe(0);
    }
  });

  test("magenta 省略時は既定 0", () => {
    const { magenta: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.magenta).toBe(0);
    }
  });

  test("yellow 省略時は既定 0", () => {
    const { yellow: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.yellow).toBe(0);
    }
  });

  // === 0.4.0 新規キー: 有効値パース ===

  test("6 新キーの有効値が正しくパースされる", () => {
    const input = {
      ...PRESETS.cinematic,
      compressionAmount: 0.5,
      compressionRange: 0.3,
      printContrast: 0.8,
      cyan: -0.5,
      magenta: 0.3,
      yellow: -0.2,
    };
    const r = filmLabParamsSchema.safeParse(input);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.compressionAmount).toBe(0.5);
      expect(r.data.compressionRange).toBe(0.3);
      expect(r.data.printContrast).toBe(0.8);
      expect(r.data.cyan).toBe(-0.5);
      expect(r.data.magenta).toBe(0.3);
      expect(r.data.yellow).toBe(-0.2);
    }
  });

  // === 0.4.0 新規キー: 範囲バリデーション ===

  test("compressionAmount が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, compressionAmount: val });
      expect(r.success).toBe(true);
    }
  });

  test("compressionAmount が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, compressionAmount: val });
      expect(r.success).toBe(false);
    }
  });

  test("compressionRange が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, compressionRange: val });
      expect(r.success).toBe(true);
    }
  });

  test("compressionRange が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, compressionRange: val });
      expect(r.success).toBe(false);
    }
  });

  test("printContrast が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, printContrast: val });
      expect(r.success).toBe(false);
    }
  });

  test("cyan が −1–1 の境界値（-1, 0, 1）を受理する", () => {
    for (const val of [-1, 0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, cyan: val });
      expect(r.success).toBe(true);
    }
  });

  test("cyan が範囲外（-1.1, 1.1）を拒否する", () => {
    for (const val of [-1.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, cyan: val });
      expect(r.success).toBe(false);
    }
  });

  test("magenta が範囲外（-1.1, 1.1）を拒否する", () => {
    for (const val of [-1.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, magenta: val });
      expect(r.success).toBe(false);
    }
  });

  test("yellow が範囲外（-1.1, 1.1）を拒否する", () => {
    for (const val of [-1.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, yellow: val });
      expect(r.success).toBe(false);
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
