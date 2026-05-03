import { describe, expect, test } from "bun:test";
import {
  LOOK_ID_BY_BASE_LOOK,
  LOOK_ID_BY_PRESET,
  LOOK_RECIPE_VERSION,
  PRESET_VERSION,
  lookIdForBaseLook,
  lookIdForPreset,
} from "./look-ids";

describe("Look-first canonical aliases (Look Unification)", () => {
  test("LOOK_RECIPE_VERSION is a strict reference to PRESET_VERSION", () => {
    expect(LOOK_RECIPE_VERSION).toBe(PRESET_VERSION);
  });

  test("lookIdForBaseLook is a reference to lookIdForPreset", () => {
    expect(lookIdForBaseLook).toBe(lookIdForPreset);
  });

  test("LOOK_ID_BY_BASE_LOOK shares the LOOK_ID_BY_PRESET object identity", () => {
    expect(LOOK_ID_BY_BASE_LOOK).toBe(LOOK_ID_BY_PRESET);
  });

  test("lookIdForBaseLook produces the same id as lookIdForPreset for every base look", () => {
    for (const name of Object.keys(LOOK_ID_BY_PRESET) as (keyof typeof LOOK_ID_BY_PRESET)[]) {
      expect(lookIdForBaseLook(name)).toBe(lookIdForPreset(name));
    }
  });

  test("LOOK_ID_BY_BASE_LOOK ids embed the canonical LOOK_RECIPE_VERSION", () => {
    for (const id of Object.values(LOOK_ID_BY_BASE_LOOK)) {
      expect(id.endsWith(`:${LOOK_RECIPE_VERSION}`)).toBe(true);
    }
  });
});
