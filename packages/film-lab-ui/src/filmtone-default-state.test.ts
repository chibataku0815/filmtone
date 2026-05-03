import { describe, expect, test } from "bun:test";
import {
  FILMTONE_DEFAULT_BASE_LOOK,
  createFilmtoneDefaultParams,
} from "film-lab-core";
import { createInitialState } from "./film-lab-reducer";

describe("FilmLabControlPanelCore default state inputs", () => {
  test("starts from reset Base Look with shared soft finish params", () => {
    const state = createInitialState(
      createFilmtoneDefaultParams(),
      FILMTONE_DEFAULT_BASE_LOOK,
    );

    expect(state.slotA.baseLook).toBe("reset");
    expect(state.slotB.baseLook).toBe("reset");
    expect(state.slotA.params.diffusion).toBe(0.08);
    expect(state.slotA.params.bloomStrength).toBe(0.22);
    expect(state.slotB.params.diffusion).toBe(0.08);
    expect(state.slotB.params.bloomStrength).toBe(0.22);
  });
});
