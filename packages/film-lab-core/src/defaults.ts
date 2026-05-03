import { cloneParams, type Params } from "./params";
import { PRESETS } from "./presets";
import { LOOK_ID_BY_PRESET, PRESET_VERSION } from "./look-ids";
import type { FilmLookGradeInputProps, FilmLookSpikeInputProps } from "./schema";

/** Remotion FilmLookSpike の defaultProps */
export const filmLookSpikeDefaultProps: FilmLookSpikeInputProps = {
  title: "Filmtone × Remotion",
};

/** Remotion FilmLookGrade の defaultProps（cinematic 基準）— Look Unification dual emit */
export function createDefaultFilmLookGradeProps(): FilmLookGradeInputProps {
  const grade: Params = cloneParams(PRESETS.cinematic);
  const id = LOOK_ID_BY_PRESET.cinematic;
  return {
    lookPresetId: id,
    presetVersion: PRESET_VERSION,
    lookId: id,
    lookVersion: PRESET_VERSION,
    grade,
  };
}

export const filmLookGradeDefaultProps: FilmLookGradeInputProps =
  createDefaultFilmLookGradeProps();
