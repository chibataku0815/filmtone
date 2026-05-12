import { describe, expect, test } from "bun:test";
import { filmLabParamsSchema, filmLookGradeInputSchema } from "./schema";
import { PRESETS } from "./presets";
import { LOOK_ID_BY_PRESET, PRESET_VERSION } from "./look-ids";
import { FILM_GRAIN_INTENSITY_MAX } from "./params";

describe("filmLabParamsSchema", () => {
  test("accepts cinematic preset", () => {
    const r = filmLabParamsSchema.safeParse(PRESETS.cinematic);
    expect(r.success).toBe(true);
  });

  test("caps legacy over-strong grain at the product-safe maximum", () => {
    const r = filmLabParamsSchema.safeParse({
      ...PRESETS.cinematic,
      grainIntensity: 0.18,
    });
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.grainIntensity).toBe(FILM_GRAIN_INTENSITY_MAX);
    }
  });

  test("rejects negative grain intensity", () => {
    const r = filmLabParamsSchema.safeParse({
      ...PRESETS.cinematic,
      grainIntensity: -0.01,
    });
    expect(r.success).toBe(false);
  });

  test("all built-in presets stay within the product-safe grain maximum", () => {
    for (const preset of Object.values(PRESETS)) {
      expect(preset.grainIntensity).toBeLessThanOrEqual(FILM_GRAIN_INTENSITY_MAX);
    }
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

  test("detailSoftness 省略時は既定 0（後方互換）", () => {
    const { detailSoftness: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.detailSoftness).toBe(0);
    }
  });

  test("detailSoftness が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, detailSoftness: val });
      expect(r.success).toBe(true);
    }
  });

  test("detailSoftness が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, detailSoftness: val });
      expect(r.success).toBe(false);
    }
  });

  test("shadowLatitude 省略時は既定 0（後方互換）", () => {
    const { shadowLatitude: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.shadowLatitude).toBe(0);
    }
  });

  test("shadowLatitude が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, shadowLatitude: val });
      expect(r.success).toBe(true);
    }
  });

  test("shadowLatitude が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, shadowLatitude: val });
      expect(r.success).toBe(false);
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

  // === 0.5.0 新規キー: grainSize / diffusion ===

  test("grainSize 省略時は既定 0.3", () => {
    const { grainSize: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.grainSize).toBe(0.3);
    }
  });

  test("diffusion 省略時は既定 0", () => {
    const { diffusion: _omit, ...rest } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.diffusion).toBe(0);
    }
  });

  test("depthMistGain / depthGlowGain 省略時は既定 0", () => {
    const {
      depthMistGain: _omitMist,
      depthGlowGain: _omitGlow,
      ...rest
    } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.depthMistGain).toBe(0);
      expect(r.data.depthGlowGain).toBe(0);
    }
  });

  test("cross filter depth/ray-angle hidden controls 省略時は推奨既定値", () => {
    const {
      crossFilterDepthGain: _omitDepth,
      crossFilterAngleGain: _omitAngle,
      crossFilterAngleGamma: _omitGamma,
      crossFilterAngleInnerThreshold: _omitInner,
      crossFilterEdgeLengthGain: _omitLength,
      crossFilterEdgeStrengthGain: _omitStrength,
      ...rest
    } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.crossFilterDepthGain).toBe(0.25);
      expect(r.data.crossFilterAngleGain).toBe(0.35);
      expect(r.data.crossFilterAngleGamma).toBe(1.4);
      expect(r.data.crossFilterAngleInnerThreshold).toBe(0.1);
      expect(r.data.crossFilterEdgeLengthGain).toBe(0.45);
      expect(r.data.crossFilterEdgeStrengthGain).toBe(0.25);
    }
  });

  test("depth ray-angle / field PSF hidden controls 省略時は推奨既定値", () => {
    const {
      depthRayAngleGamma: _omitGamma,
      depthRayAngleInnerThreshold: _omitInner,
      depthMistRayAngleGain: _omitMistAngle,
      depthBloomRayAngleGain: _omitBloomAngle,
      depthHalationRayAngleGain: _omitHalationAngle,
      depthMistFieldPsfGain: _omitMistPsfGain,
      depthBloomFieldPsfGain: _omitBloomPsfGain,
      depthHalationFieldPsfGain: _omitHalationPsfGain,
      depthMistFieldPsfRadiusPx: _omitMistPsfRadius,
      depthBloomFieldPsfRadiusPx: _omitBloomPsfRadius,
      depthHalationFieldPsfRadiusPx: _omitHalationPsfRadius,
      ...rest
    } = PRESETS.cinematic;
    const r = filmLabParamsSchema.safeParse(rest);
    expect(r.success).toBe(true);
    if (r.success) {
      expect(r.data.depthRayAngleGamma).toBe(1.4);
      expect(r.data.depthRayAngleInnerThreshold).toBe(0.1);
      expect(r.data.depthMistRayAngleGain).toBe(0.35);
      expect(r.data.depthBloomRayAngleGain).toBe(0.25);
      expect(r.data.depthHalationRayAngleGain).toBe(0.18);
      expect(r.data.depthMistFieldPsfGain).toBe(1);
      expect(r.data.depthBloomFieldPsfGain).toBe(1);
      expect(r.data.depthHalationFieldPsfGain).toBe(1);
      expect(r.data.depthMistFieldPsfRadiusPx).toBe(18);
      expect(r.data.depthBloomFieldPsfRadiusPx).toBe(9);
      expect(r.data.depthHalationFieldPsfRadiusPx).toBe(12);
    }
  });

  test("grainSize が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, grainSize: val });
      expect(r.success).toBe(true);
    }
  });

  test("grainSize が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, grainSize: val });
      expect(r.success).toBe(false);
    }
  });

  test("diffusion が 0–1 の境界値（0, 1）を受理する", () => {
    for (const val of [0, 1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, diffusion: val });
      expect(r.success).toBe(true);
    }
  });

  test("diffusion が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const val of [-0.1, 1.1]) {
      const r = filmLabParamsSchema.safeParse({ ...PRESETS.cinematic, diffusion: val });
      expect(r.success).toBe(false);
    }
  });

  test("depthMistGain / depthGlowGain が 0–1 の境界値を受理する", () => {
    for (const key of ["depthMistGain", "depthGlowGain"] as const) {
      for (const val of [0, 1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
    }
  });

  test("depthMistGain / depthGlowGain が範囲外（-0.1, 1.1）を拒否する", () => {
    for (const key of ["depthMistGain", "depthGlowGain"] as const) {
      for (const val of [-0.1, 1.1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(false);
      }
    }
  });

  test("cross filter hidden gains が 0–1 の境界値を受理する", () => {
    for (const key of [
      "crossFilterDepthGain",
      "crossFilterAngleGain",
      "crossFilterEdgeLengthGain",
      "crossFilterEdgeStrengthGain",
    ] as const) {
      for (const val of [0, 1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
    }
  });

  test("depth ray-angle / field PSF gains が 0–1 の境界値を受理する", () => {
    for (const key of [
      "depthMistRayAngleGain",
      "depthBloomRayAngleGain",
      "depthHalationRayAngleGain",
      "depthMistFieldPsfGain",
      "depthBloomFieldPsfGain",
      "depthHalationFieldPsfGain",
    ] as const) {
      for (const val of [0, 1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
      for (const val of [-0.1, 1.1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(false);
      }
    }
  });

  test("ray-angle gamma は 0.1–4 の範囲だけ受理する", () => {
    for (const key of ["depthRayAngleGamma", "crossFilterAngleGamma"] as const) {
      for (const val of [0.1, 1.4, 4]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
      for (const val of [0.09, 4.1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(false);
      }
    }
  });

  test("ray-angle inner threshold は 0–0.8 の範囲だけ受理する", () => {
    for (const key of [
      "depthRayAngleInnerThreshold",
      "crossFilterAngleInnerThreshold",
    ] as const) {
      for (const val of [0, 0.1, 0.8]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
      for (const val of [-0.1, 0.81]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(false);
      }
    }
  });

  test("field PSF radius は 0–64px の範囲だけ受理する", () => {
    for (const key of [
      "depthMistFieldPsfRadiusPx",
      "depthBloomFieldPsfRadiusPx",
      "depthHalationFieldPsfRadiusPx",
    ] as const) {
      for (const val of [0, 12, 64]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(true);
      }
      for (const val of [-0.1, 64.1]) {
        const r = filmLabParamsSchema.safeParse({
          ...PRESETS.cinematic,
          [key]: val,
        });
        expect(r.success).toBe(false);
      }
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

  test("depthTrack を付けて受理する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
      depthTrack: {
        kind: "frameSequence",
        fps: 25,
        frameRelPaths: ["depth/0001.png"],
      },
    });
    expect(r.success).toBe(true);
  });

  test("cameraOptics を付けて受理する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
      cameraOptics: {
        source: "metadata",
        fovXDeg: 54.4,
        fovYDeg: 32.3,
        fxPx: 2400,
        fyPx: 2400,
        lensModel: "35mm FF equiv",
      },
    });
    expect(r.success).toBe(true);
  });

  test("cameraOptics の FOV 範囲外を拒否する", () => {
    const r = filmLookGradeInputSchema.safeParse({
      lookPresetId: LOOK_ID_BY_PRESET.portra,
      presetVersion: PRESET_VERSION,
      grade: PRESETS.portra,
      cameraOptics: {
        source: "manual",
        fovXDeg: 179,
      },
    });
    expect(r.success).toBe(false);
  });
});
