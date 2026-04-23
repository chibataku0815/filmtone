import { describe, expect, test } from "bun:test";
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  createFilmtoneDefaultParams,
} from "film-lab-core";
import { createInitialState } from "./film-lab-reducer";

describe("FilmLabControlPanelCore default state inputs", () => {
  test("starts from reset base preset with shared soft finish params", () => {
    const state = createInitialState(
      createFilmtoneDefaultParams(),
      FILMTONE_DEFAULT_BASE_PRESET,
    );

    expect(state.slotA.basePreset).toBe("reset");
    expect(state.slotB.basePreset).toBe("reset");
    expect(state.slotA.params.diffusion).toBe(0.08);
    expect(state.slotA.params.bloomStrength).toBe(0.22);
    expect(state.slotB.params.diffusion).toBe(0.08);
    expect(state.slotB.params.bloomStrength).toBe(0.22);
  });
});
