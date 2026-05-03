import { describe, expect, test } from "bun:test";
import { PRESETS } from "./presets";
import {
  OPTICAL_FILTER_PROFILES,
  buildOpticalFilterParamPatch,
  getOpticalFilterProfile,
} from "./optical-filter-profiles";

describe("optical filter profiles", () => {
  test("exposes the initial product-facing filter set", () => {
    expect(OPTICAL_FILTER_PROFILES.map((profile) => profile.id)).toEqual([
      "blackMist-1-8",
      "blackMist-1-4",
      "blackMist-1-2",
      "cineBloom-5",
      "cineBloom-10",
      "cineBloom-20",
      "warmMist-1-8",
      "warmMist-1-4",
      "pearlGlow-subtle",
      "pearlGlow-1-4",
      "cleanSoft-subtle",
      "backlightVeil-1-8",
      "backlightVeil-1-4",
      "backlightVeil-1-2",
    ]);
  });

  test("resolves profiles by id", () => {
    expect(getOpticalFilterProfile("blackMist-1-4")?.displayName).toBe(
      "Black Mist 1/4",
    );
    expect(getOpticalFilterProfile("missing")).toBeNull();
  });

  test("black mist profiles activate direct scatter", () => {
    const patch = buildOpticalFilterParamPatch("blackMist-1-4");

    expect(patch.opticalDirectTransmission).toBeLessThan(1);
    expect(patch.opticalScatterStrength).toBeGreaterThan(0);
    expect(patch.opticalBlackRetention).toBeGreaterThan(0.8);
  });

  test("patches reset stale optical lane values before applying a profile", () => {
    const patch = buildOpticalFilterParamPatch("cleanSoft-subtle");

    expect(patch.crossFilterStrength).toBe(PRESETS.reset.crossFilterStrength);
    expect(patch.haloPrismStrength).toBe(PRESETS.reset.haloPrismStrength);
    expect(patch.opticalScatterStrength).toBe(
      PRESETS.reset.opticalScatterStrength,
    );
    expect(patch.lensSoftness).toBeGreaterThan(0);
  });

  test("throws for unknown profile ids", () => {
    expect(() => buildOpticalFilterParamPatch("missing")).toThrow(
      "Unknown optical filter profile",
    );
  });
});
