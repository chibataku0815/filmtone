import { z } from "zod";
import { PARAM_KEYS, type Params } from "./params";
import { PRESETS, type PresetName } from "./presets";
import { PRESET_VERSION } from "./look-ids";

const paramShape = Object.fromEntries(
  PARAM_KEYS.map((key) => [key, z.number()]),
) as Record<(typeof PARAM_KEYS)[number], z.ZodNumber>;

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
   * Remotion `public/` からの相対パス（例: `luts/warm-cinematic.cube`）。
   * 未指定のときは LUT をかけない。
   */
  lutCubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lutCubeRelPath` があっても LUT を無効化する。未指定は `true` 扱い。 */
  lutEnabled: z.boolean().optional(),
  /** ブラウザ Film Lab の `uLUTIntensity` に相当（0〜1）。未指定は `1`。 */
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

export type FilmLookGradeInputProps = z.infer<typeof filmLookGradeInputSchema>;

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
