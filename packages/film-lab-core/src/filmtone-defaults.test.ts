import { describe, expect, test } from "bun:test";
import { PARAM_KEYS } from "./params";
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  FILMTONE_SOFT_FINISH_PATCH,
  PRESET_BUTTONS,
  PRESETS,
  createFilmtoneDefaultParams,
  findMatchingPreset,
} from "./presets";

describe("Filmtone Web/Desktop default look", () => {
  test("uses reset as the shared base preset identity", () => {
    expect(FILMTONE_DEFAULT_BASE_PRESET).toBe("reset");
  });

  test("keeps reset clean while adding only the soft finish patch to startup params", () => {
    const params = createFilmtoneDefaultParams();

    expect(params).not.toBe(PRESETS.reset);
    expect(PRESETS.reset.bloomStrength).toBe(0);
    expect(PRESETS.reset.diffusion).toBe(0);
    expect(PRESETS.reset.halationIntensity).toBe(0);

    for (const key of PARAM_KEYS) {
      if (key in FILMTONE_SOFT_FINISH_PATCH) {
        expect(params[key]).toBe(FILMTONE_SOFT_FINISH_PATCH[key]);
      } else {
        expect(params[key]).toBe(PRESETS.reset[key]);
      }
    }
  });

  test("does not masquerade the soft-finish startup params as a built-in preset", () => {
    expect(findMatchingPreset(createFilmtoneDefaultParams())).toBeNull();
  });

  test("labels the existing reset preset as Neutral / Clean Base", () => {
    const resetButton = PRESET_BUTTONS.find((button) => button.name === "reset");

    expect(PRESET_BUTTONS[0]?.name).toBe("reset");
    expect(resetButton).toEqual({
      name: "reset",
      label: "Neutral",
      subtitle: "Clean Base",
      category: "utility",
    });
  });
});
