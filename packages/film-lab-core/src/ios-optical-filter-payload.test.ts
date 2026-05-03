import { describe, expect, test } from "bun:test";
import { OPTICAL_FILTER_PROFILES } from "./optical-filter-profiles";
import {
  IOS_OPTICAL_FILTER_OPTICAL_KEYS,
  IOS_OPTICAL_FILTER_PAYLOAD,
  IOS_OPTICAL_FILTER_SPATIAL_KEYS,
  buildIosOpticalFilterPayload,
} from "./ios-optical-filter-payload";

describe("ios optical filter payload", () => {
  test("ships exactly the three Backlight Veil entries (1/8, 1/4, 1/2)", () => {
    expect(IOS_OPTICAL_FILTER_PAYLOAD.map((entry) => entry.id)).toEqual([
      "backlightVeil-1-8",
      "backlightVeil-1-4",
      "backlightVeil-1-2",
    ]);
    for (const entry of IOS_OPTICAL_FILTER_PAYLOAD) {
      expect(entry.family).toBe("backlightVeil");
    }
  });

  test("mirrors all 12 spatial keys 1:1 from the desktop catalog", () => {
    for (const entry of IOS_OPTICAL_FILTER_PAYLOAD) {
      const desktop = OPTICAL_FILTER_PROFILES.find(
        (profile) => profile.id === entry.id,
      );
      expect(desktop).toBeDefined();
      for (const key of IOS_OPTICAL_FILTER_SPATIAL_KEYS) {
        expect(entry.spatial[key]).toBe(desktop!.params[key] as number);
      }
    }
  });

  test("mirrors all 6 optical keys 1:1 from the desktop catalog", () => {
    const opticalKeyMap: Record<string, string> = {
      directTransmission: "opticalDirectTransmission",
      blackRetention: "opticalBlackRetention",
      scatterStrength: "opticalScatterStrength",
      highlightReactivity: "opticalHighlightReactivity",
      warmScatter: "opticalWarmScatter",
      spectralTail: "opticalSpectralTail",
    };
    for (const entry of IOS_OPTICAL_FILTER_PAYLOAD) {
      const desktop = OPTICAL_FILTER_PROFILES.find(
        (profile) => profile.id === entry.id,
      );
      expect(desktop).toBeDefined();
      for (const key of IOS_OPTICAL_FILTER_OPTICAL_KEYS) {
        const desktopKey = opticalKeyMap[key];
        expect(entry.optical[key]).toBe(
          desktop!.params[
            desktopKey as keyof typeof desktop.params
          ] as number,
        );
      }
    }
  });

  test("locks the canonical 1/2 ship-gate values", () => {
    const halfDensity = IOS_OPTICAL_FILTER_PAYLOAD.find(
      (entry) => entry.id === "backlightVeil-1-2",
    );
    expect(halfDensity).toBeDefined();
    expect(halfDensity!.optical).toEqual({
      directTransmission: 0.7,
      blackRetention: 0.36,
      scatterStrength: 0.9,
      highlightReactivity: 0.95,
      warmScatter: 0.24,
      spectralTail: 0.1,
    });
    expect(halfDensity!.spatial.bloomStrength).toBe(0.6);
    expect(halfDensity!.spatial.diffusion).toBe(0.38);
    expect(halfDensity!.spatial.halationIntensity).toBe(0.22);
  });

  test("locks the canonical 1/4 mid-strength values", () => {
    const quarter = IOS_OPTICAL_FILTER_PAYLOAD.find(
      (entry) => entry.id === "backlightVeil-1-4",
    );
    expect(quarter).toBeDefined();
    expect(quarter!.optical).toEqual({
      directTransmission: 0.81,
      blackRetention: 0.56,
      scatterStrength: 0.66,
      highlightReactivity: 0.78,
      warmScatter: 0.17,
      spectralTail: 0.07,
    });
  });

  test("locks the canonical 1/8 subtle values", () => {
    const eighth = IOS_OPTICAL_FILTER_PAYLOAD.find(
      (entry) => entry.id === "backlightVeil-1-8",
    );
    expect(eighth).toBeDefined();
    expect(eighth!.optical).toEqual({
      directTransmission: 0.92,
      blackRetention: 0.78,
      scatterStrength: 0.42,
      highlightReactivity: 0.62,
      warmScatter: 0.1,
      spectralTail: 0.04,
    });
  });

  test("buildIosOpticalFilterPayload skips non-portable families", () => {
    const subset = OPTICAL_FILTER_PROFILES.filter(
      (profile) => profile.family !== "backlightVeil",
    );
    expect(buildIosOpticalFilterPayload(subset)).toEqual([]);
  });
});
