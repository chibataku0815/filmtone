import { z } from "zod";
import {
  PARAM_KEYS,
  clampGrainIntensity,
  type ParamKey,
  type Params,
} from "./params";
import { PRESETS, type PresetName } from "./presets";
import { PRESET_VERSION } from "./look-ids";
import type { CameraOptics } from "./native-bridge";

type ParamSchemaShape = {
  [K in ParamKey]: z.ZodType<Params[K]>;
};

function schemaForParamKey(key: ParamKey): z.ZodType<number> {
  return key === "grainIntensity"
    ? z.number().min(0).transform(clampGrainIntensity)
    : key === "grainRadialMix"
    ? z.number().min(0).max(1).default(1)
    : key === "grainSize"
      ? z.number().min(0).max(1).default(0.3)
      : key === "diffusion"
        ? z.number().min(0).max(1).default(0)
        : key === "depthMistGain" || key === "depthGlowGain"
          ? z.number().min(0).max(1).default(0)
        : key === "depthRayAngleGamma"
          ? z.number().min(0.1).max(4).default(1.4)
        : key === "depthRayAngleInnerThreshold"
          ? z.number().min(0).max(0.8).default(0.1)
        : key === "depthMistRayAngleGain"
          ? z.number().min(0).max(1).default(0.35)
        : key === "depthBloomRayAngleGain"
          ? z.number().min(0).max(1).default(0.25)
        : key === "depthHalationRayAngleGain"
          ? z.number().min(0).max(1).default(0.18)
        : key === "depthMistFieldPsfGain" ||
            key === "depthBloomFieldPsfGain" ||
            key === "depthHalationFieldPsfGain"
          ? z.number().min(0).max(1).default(1)
        : key === "depthMistFieldPsfRadiusPx"
          ? z.number().min(0).max(64).default(18)
        : key === "depthBloomFieldPsfRadiusPx"
          ? z.number().min(0).max(64).default(9)
        : key === "depthHalationFieldPsfRadiusPx"
          ? z.number().min(0).max(64).default(12)
        : key === "lensSoftness"
          ? z.number().min(0).max(1).default(0)
          : key === "opticalDirectTransmission"
            ? z.number().min(0).max(1).default(1)
          : key === "opticalBlackRetention"
            ? z.number().min(0).max(1).default(1)
          : key === "opticalScatterStrength" ||
              key === "opticalHighlightReactivity" ||
              key === "opticalWarmScatter" ||
              key === "opticalSpectralTail"
            ? z.number().min(0).max(1).default(0)
          : key === "compressionRange"
            ? z.number().min(0).max(1).default(0.5)
            : key === "compressionAmount" || key === "printContrast"
              ? z.number().min(0).max(1).default(0)
              : key === "cyan" || key === "magenta" || key === "yellow"
                ? z.number().min(-1).max(1).default(0)
                : key === "shutterAngle"
                  ? z.number().min(0).max(720).default(0)
                  : key === "trailIntensity"
                    ? z.number().min(0).max(0.95).default(0)
                    : key === "motionBlurAmount" || key === "dustAmount" || key === "scratchAmount"
                      ? z.number().min(0).max(1).default(0)
                      : key === "shaftIntensity"
                        ? z.number().min(0).max(1).default(0)
                        : key === "shaftDecay"
                          ? z.number().min(0).max(1).default(0.5)
                          : key === "shaftOriginX"
                            ? z.number().min(0).max(1).default(0.5)
                            : key === "shaftOriginY"
                              ? z.number().min(0).max(1).default(0.15)
                              : key === "crossFilterStrength"
                                ? z.number().min(0).max(1).default(0)
                                : key === "crossFilterSpikes"
                                  ? z.number().min(4).max(8).default(4)
                                  : key === "crossFilterAngle"
                                    ? z.number().min(0).max(360).default(0)
                                    : key === "crossFilterLength"
                                      ? z.number().min(0).max(1).default(0.4)
                                      : key === "crossFilterThreshold"
                                        ? z.number().min(0).max(1).default(0.92)
                                        : key === "crossFilterChromatic"
                                          ? z.number().min(0).max(1).default(0.3)
                                          : key === "crossFilterSizeLimit"
                                            ? z.number().min(0).max(1).default(0)
                                            : key === "crossFilterRandomness"
                                              ? z.number().min(0).max(1).default(1)
                                              : key === "crossFilterHardMode"
                                                ? z.number().min(0).max(1).default(1)
                                                : key === "crossFilterMinSpacing"
                                                  ? z.number().min(0).max(2).default(1)
                                                  : key === "crossFilterDepthGain"
                                                    ? z.number().min(0).max(1).default(0.25)
                                                    : key === "crossFilterAngleGain"
                                                      ? z.number().min(0).max(1).default(0.35)
                                                      : key === "crossFilterAngleGamma"
                                                        ? z.number().min(0.1).max(4).default(1.4)
                                                        : key === "crossFilterAngleInnerThreshold"
                                                          ? z.number().min(0).max(0.8).default(0.1)
                                                        : key === "crossFilterEdgeLengthGain"
                                                          ? z.number().min(0).max(1).default(0.45)
                                                          : key === "crossFilterEdgeStrengthGain"
                                                            ? z.number().min(0).max(1).default(0.25)
                                                            : key === "haloPrismStrength"
                                                              ? z.number().min(0).max(1).default(0)
                                                            : key === "haloPrismRadius"
                                                              ? z.number().min(0).max(1).default(0.62)
                                                            : key === "haloPrismWidth"
                                                              ? z.number().min(0).max(1).default(0.22)
                                                            : key === "haloPrismChromatic"
                                                              ? z.number().min(0).max(1).default(0.65)
                                                            : key === "haloPrismThreshold"
                                                              ? z.number().min(0).max(1).default(0.9)
                                                            : key === "haloPrismSplit"
                                                              ? z.number().min(0).max(1).default(0.7)
                                                            : key === "haloPrismAngle"
                                                              ? z.number().min(0).max(360).default(0)
                                                            : key === "haloPrismSourceReactivity"
                                                              ? z.number().min(0).max(1).default(0.85)
                                                  : z.number();
}

/**
 * grainRadialMix は省略時 1（後方互換）、lensSoftness は省略時 0。
 * depth-aware Mist / Glow gains は省略時 0（uniform）。
 * Cross filter の depth/ray-angle hidden controls は省略時に推奨値を持つ（effect off 時は dormant）。
 * 0.4.0 追加: compressionRange は省略時 0.5、それ以外の新 process keys は省略時 0。
 * デフォルト付きキーは Remotion や旧 JSON の grace fallback として機能する。
 */
const paramShape = Object.fromEntries(
  PARAM_KEYS.map((key) => [key, schemaForParamKey(key)]),
) as ParamSchemaShape;

/**
 * 単体のグレードパラメータ（Film Lab の Params と同一形）
 */
export const filmLabParamsSchema = z.object(paramShape);

export type FilmLabParamsValidated = z.infer<typeof filmLabParamsSchema>;

/**
 * Shared depth-track contract.
 *
 * `frameRelPaths` are resolved relative to the imported grade JSON so the
 * same look can round-trip through preview, export, and saved-session
 * surfaces without falling back to renderer-only state.
 */
export const filmLabDepthTrackSchema = z.object({
  kind: z.literal("frameSequence"),
  fps: z.number().positive().max(120).default(25),
  frameRelPaths: z.array(z.string().min(1)).min(1),
});

export type FilmLabDepthTrackInput = z.infer<typeof filmLabDepthTrackSchema>;

export const cameraOpticsSchema = z.object({
  source: z.enum(["metadata", "assumed", "manual"]),
  fxPx: z.number().positive().optional(),
  fyPx: z.number().positive().optional(),
  cxPx: z.number().optional(),
  cyPx: z.number().optional(),
  fovXDeg: z.number().min(1).max(178).optional(),
  fovYDeg: z.number().min(1).max(178).optional(),
  focalLength35mm: z.number().positive().optional(),
  lensModel: z.string().min(1).optional(),
  cameraMake: z.string().min(1).optional(),
  cameraModel: z.string().min(1).optional(),
}) satisfies z.ZodType<CameraOptics>;

/**
 * Remotion Composition 向け: ルック ID + バージョン + 数値グレード
 */
export const filmLookGradeInputSchema = z.object({
  lookPresetId: z.string().min(1),
  presetVersion: z.literal(PRESET_VERSION),
  grade: filmLabParamsSchema,
  /** Optional depth track that drives depth-aware Mist / Glow across preview and export. */
  depthTrack: filmLabDepthTrackSchema.optional(),
  /** Optional source camera optics for ray-angle masks. */
  cameraOptics: cameraOpticsSchema.nullable().optional(),
  /**
   * Input Transform LUT（グレーディング前 — Log→Rec709 等）。
   * 未指定のときは Input Transform をかけない。
   */
  lut1CubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lut1CubeRelPath` があっても LUT1 を無効化する。未指定は `true` 扱い。 */
  lut1Enabled: z.boolean().optional(),
  /** Input Transform の適用強度（0〜1）。未指定は `1`。 */
  lut1Intensity: z.number().min(0).max(1).optional(),
  /**
   * Creative LUT（グレーディング後 — フィルムルック等）。
   * Remotion `public/` からの相対パス（例: `luts/warm-cinematic.cube`）。
   * 未指定のときは Creative LUT をかけない。
   */
  lutCubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lutCubeRelPath` があっても Creative LUT を無効化する。未指定は `true` 扱い。 */
  lutEnabled: z.boolean().optional(),
  /** Creative LUT の適用強度（0〜1）。未指定は `1`。 */
  lutIntensity: z.number().min(0).max(1).optional(),
  /**
   * Remotion `public/` 内の動画（.mov / .mp4 等）。
   * 指定時は `film-lab-default.jpg` の代わりにフレームをテクスチャに焼く（`@remotion/media`）。
   */
  gradeSourceVideoRelPath: z.string().min(1).optional(),
  /** 動画の実ピクセル幅（アスペクト・cover 用）。未指定は 3840（4K 横想定）。 */
  gradeSourceVideoWidth: z.number().int().positive().max(7680).optional(),
  /** 動画の実ピクセル高さ。未指定は 2160。 */
  gradeSourceVideoHeight: z.number().int().positive().max(4320).optional(),
});

/** z.object(ZodRawShape) 経由だと grade が Record に寛容になるため、Params で上書き */
export type FilmLookGradeInputProps = Omit<
  z.infer<typeof filmLookGradeInputSchema>,
  "grade"
> & {
  grade: Params;
  cameraOptics?: CameraOptics | null;
};

/**
 * Phase 0 スパイク用（ルックと無関係なテキストのみ）
 */
export const filmLookSpikeInputSchema = z.object({
  title: z.string().min(1),
});

export type FilmLookSpikeInputProps = z.infer<typeof filmLookSpikeInputSchema>;

/**
 * プリセット名と grade が PRESETS と一致するか（厳密一致）
 */
export function gradeMatchesPreset(
  presetName: PresetName,
  grade: Params,
): boolean {
  const expected = PRESETS[presetName];
  return PARAM_KEYS.every((key) => grade[key] === expected[key]);
}
