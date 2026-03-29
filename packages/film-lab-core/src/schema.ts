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
