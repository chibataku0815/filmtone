import { describe, expect, it } from "vitest";
import {
  FILMTONE_SOFT_FINISH_PATCH,
  PRESETS,
  createFilmtoneDefaultParams,
} from "film-lab-core";
import { createDefaultBatchGradeState } from "./batch-pipeline";

describe("desktop batch defaults", () => {
  it("starts from Neutral / Clean Base with the shared soft finish patch", () => {
    const grade = createDefaultBatchGradeState();

    expect(grade.params).toEqual(createFilmtoneDefaultParams());
    expect(grade.params.exposure).toBe(PRESETS.reset.exposure);
    expect(grade.params.temperature).toBe(PRESETS.reset.temperature);
    expect(grade.params.tint).toBe(PRESETS.reset.tint);
    expect(grade.params.rgbShift).toBe(PRESETS.reset.rgbShift);
    expect(grade.params.diffusion).toBe(FILMTONE_SOFT_FINISH_PATCH.diffusion);
    expect(grade.params.bloomStrength).toBe(
      FILMTONE_SOFT_FINISH_PATCH.bloomStrength,
    );
    expect(grade.depthTrack).toBeNull();
    expect(grade.lut1Data).toBeNull();
    expect(grade.lutData).toBeNull();
  });
});
