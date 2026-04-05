import { z } from "zod";
import { PARAM_KEYS, type Params } from "./params";
import { PRESETS, type PresetName } from "./presets";
import { PRESET_VERSION } from "./look-ids";

/**
 * grainRadialMix は省略時 1（後方互換）、lensSoftness は省略時 0。
 * 0.4.0 追加: compressionRange は省略時 0.5、それ以外の新 process keys は省略時 0。
 * デフォルト付きキーは Remotion や旧 JSON の grace fallback として機能する。
 */
const paramShape = Object.fromEntries(
  PARAM_KEYS.map((key) => [
    key,
    key === "grainRadialMix"
      ? z.number().min(0).max(1).default(1)
      : key === "lensSoftness"
        ? z.number().min(0).max(1).default(0)
        : key === "compressionRange"
          ? z.number().min(0).max(1).default(0.5)
          : key === "compressionAmount" || key === "printContrast"
            ? z.number().min(0).max(1).default(0)
            : key === "cyan" || key === "magenta" || key === "yellow"
              ? z.number().min(-1).max(1).default(0)
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
                        : z.number(),
  ]),
) as z.ZodRawShape;

/**
 * 単体のグレードパラメータ（Film Lab の Params と同一形）
 */
export const filmLabParamsSchema = z.object(paramShape);

export type FilmLabParamsValidated = z.infer<typeof filmLabParamsSchema>;

/**
 * Remotion Composition 向け: ルック ID + バージョン + 数値グレード
 */
export const filmLookGradeInputSchema = z.object({
  lookPresetId: z.string().min(1),
  presetVersion: z.literal(PRESET_VERSION),
  grade: filmLabParamsSchema,
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
