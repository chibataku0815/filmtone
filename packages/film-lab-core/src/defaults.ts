import { cloneParams, type Params } from "./params";
import { PRESETS } from "./presets";
import { LOOK_ID_BY_PRESET, PRESET_VERSION } from "./look-ids";
import type { FilmLookGradeInputProps, FilmLookSpikeInputProps } from "./schema";

/** Remotion FilmLookSpike の defaultProps */
export const filmLookSpikeDefaultProps: FilmLookSpikeInputProps = {
  title: "Filmtone × Remotion",
};

/** Remotion FilmLookGrade の defaultProps（cinematic 基準） */
export function createDefaultFilmLookGradeProps(): FilmLookGradeInputProps {
  const grade: Params = cloneParams(PRESETS.cinematic);
  return {
    lookPresetId: LOOK_ID_BY_PRESET.cinematic,
    presetVersion: PRESET_VERSION,
    grade,
  };
}

export const filmLookGradeDefaultProps: FilmLookGradeInputProps =
  createDefaultFilmLookGradeProps();
