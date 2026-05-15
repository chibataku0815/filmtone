import { describe, expect, test } from "bun:test";
import { deriveFilmBreathOffsets } from "./film-breath";

const LIMITS = {
  exposure: 0.16,
  contrast: 0.055,
  temperature: 0.09,
  tint: 0.04,
} as const;

describe("deriveFilmBreathOffsets", () => {
  test("is exact identity when amount is 0 or timeSeconds is 0", () => {
    expect(deriveFilmBreathOffsets(0, 12.5, 42)).toEqual({
      exposure: 0,
      contrast: 0,
      temperature: 0,
      tint: 0,
    });
    expect(deriveFilmBreathOffsets(0.7, 0, 42)).toEqual({
      exposure: 0,
      contrast: 0,
      temperature: 0,
      tint: 0,
    });
  });

  test("is deterministic for the same amount, time, and seed", () => {
    const first = deriveFilmBreathOffsets(0.68, 8.25, 1234);
    const second = deriveFilmBreathOffsets(0.68, 8.25, 1234);
    expect(second).toEqual(first);
  });

  test("stays inside the product amplitude bounds", () => {
    for (let frame = 1; frame < 24 * 90; frame += 7) {
      const offsets = deriveFilmBreathOffsets(1, frame / 24, 7331);
      expect(Math.abs(offsets.exposure)).toBeLessThanOrEqual(LIMITS.exposure);
      expect(Math.abs(offsets.contrast)).toBeLessThanOrEqual(LIMITS.contrast);
      expect(Math.abs(offsets.temperature)).toBeLessThanOrEqual(LIMITS.temperature);
      expect(Math.abs(offsets.tint)).toBeLessThanOrEqual(LIMITS.tint);
    }
  });

  test("maximum amount is visually inspectable on representative frames", () => {
    const offsets = deriveFilmBreathOffsets(1, 24.72, 7331);
    const visibleEnergy =
      Math.abs(offsets.exposure) +
      Math.abs(offsets.contrast) +
      Math.abs(offsets.temperature) +
      Math.abs(offsets.tint);

    expect(visibleEnergy).toBeGreaterThan(0.08);
  });

  test("moves smoothly between adjacent 24fps frames", () => {
    let previous = deriveFilmBreathOffsets(1, 1 / 24, 99);
    for (let frame = 2; frame < 24 * 30; frame++) {
      const current = deriveFilmBreathOffsets(1, frame / 24, 99);
      expect(Math.abs(current.exposure - previous.exposure)).toBeLessThan(0.011);
      expect(Math.abs(current.contrast - previous.contrast)).toBeLessThan(0.0042);
      expect(Math.abs(current.temperature - previous.temperature)).toBeLessThan(0.006);
      expect(Math.abs(current.tint - previous.tint)).toBeLessThan(0.003);
      previous = current;
    }
  });
});
