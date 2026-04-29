import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  applyQuickStateToParams,
  applyQuickStateToPhase0Params,
  coerceQuickState,
  DEFAULT_QUICK_STATE,
} from "./quick-semantics";
import { pickPhase0Params } from "./phase0-schema";
import { FILM_GRAIN_INTENSITY_MAX } from "./params";

describe("quick semantics", () => {
  test("zeroed quick state keeps params unchanged", () => {
    const next = applyQuickStateToParams(PRESETS.cinematic, DEFAULT_QUICK_STATE);
    expect(next).toEqual(PRESETS.cinematic);
  });

  test("filmCharacter increases texture-facing values", () => {
    const next = applyQuickStateToParams(PRESETS.reset, {
      filmCharacter: 1,
      era: 0,
      dynamics: 0,
    });
    expect(next.saturation).toBeGreaterThan(PRESETS.reset.saturation);
    expect(next.grainIntensity).toBeGreaterThan(PRESETS.reset.grainIntensity);
    expect(next.vignette).toBeGreaterThan(PRESETS.reset.vignette);
  });

  test("phase0 quick mapping keeps halation opt-in", () => {
    const next = applyQuickStateToPhase0Params(pickPhase0Params(PRESETS.reset), {
      filmCharacter: 0,
      era: 1,
      dynamics: 1,
    });
    expect(next.fade).toBeGreaterThan(0);
    expect(next.exposure).toBeGreaterThan(0);
    expect(next.contrast).toBeGreaterThan(1);
    expect(next.bloomStrength).toBeGreaterThan(0);
    expect(next.halationIntensity).toBe(PRESETS.reset.halationIntensity);
  });

  test("quick mapping never exceeds the safe grain maximum", () => {
    const full = applyQuickStateToParams(PRESETS.bw, {
      filmCharacter: 1,
      era: 1,
      dynamics: 1,
    });
    const phase0 = applyQuickStateToPhase0Params(pickPhase0Params(PRESETS.bw), {
      filmCharacter: 1,
      era: 1,
      dynamics: 1,
    });
    expect(full.grainIntensity).toBe(FILM_GRAIN_INTENSITY_MAX);
    expect(phase0.grainIntensity).toBe(FILM_GRAIN_INTENSITY_MAX);
  });

  test("coerceQuickState clamps out-of-range values", () => {
    const state = coerceQuickState({
      filmCharacter: 2,
      era: -2,
      dynamics: 0.4,
    });
    expect(state.filmCharacter).toBe(1);
    expect(state.era).toBe(-1);
    expect(state.dynamics).toBe(0.4);
  });
});
