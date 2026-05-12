import { describe, expect, test } from "bun:test";
import {
  applyShadowLatitudeSample,
  shadowLatitudeLuma,
  SHADOW_LATITUDE_CONSTANTS,
  type ShadowLatitudeRgb,
} from "./shadow-latitude";

function delta(a: ShadowLatitudeRgb, b: ShadowLatitudeRgb): number {
  return Math.max(
    Math.abs(a.r - b.r),
    Math.abs(a.g - b.g),
    Math.abs(a.b - b.b),
  );
}

function chromaVector(rgb: ShadowLatitudeRgb): [number, number, number] {
  const y = shadowLatitudeLuma(rgb);
  return [rgb.r - y, rgb.g - y, rgb.b - y];
}

function hueCosine(a: ShadowLatitudeRgb, b: ShadowLatitudeRgb): number {
  const av = chromaVector(a);
  const bv = chromaVector(b);
  const al = Math.hypot(av[0], av[1], av[2]);
  const bl = Math.hypot(bv[0], bv[1], bv[2]);
  if (al < 1e-9 || bl < 1e-9) {
    return 1;
  }
  return (av[0] * bv[0] + av[1] * bv[1] + av[2] * bv[2]) / (al * bl);
}

function expectChannelOrderPreserved(input: ShadowLatitudeRgb, output: ShadowLatitudeRgb): void {
  for (const [a, b] of [["r", "g"], ["r", "b"], ["g", "b"]] as const) {
    const before = Math.sign(input[a] - input[b]);
    const after = Math.sign(output[a] - output[b]);
    expect(after).toBe(before);
  }
}

describe("shadowLatitude scalar model", () => {
  test("amount 0 is identity", () => {
    const samples: ShadowLatitudeRgb[] = [
      { r: 0.02, g: 0.04, b: 0.03 },
      { r: 0.08, g: 0.12, b: 0.16 },
      { r: 0.26, g: 0.22, b: 0.18 },
    ];
    for (const sample of samples) {
      expect(applyShadowLatitudeSample(sample, 0)).toEqual(sample);
    }
  });

  test("neutral grays remain neutral", () => {
    for (const v of [0, 0.025, 0.06, 0.12, 0.18, 0.3]) {
      const out = applyShadowLatitudeSample({ r: v, g: v, b: v }, 1, {
        clampOutput: true,
      });
      expect(Math.abs(out.r - out.g)).toBeLessThan(1e-12);
      expect(Math.abs(out.g - out.b)).toBeLessThan(1e-12);
    }
  });

  test("deep black anchor changes by at most 0.002 at or below luma 0.025", () => {
    const samples: ShadowLatitudeRgb[] = [
      { r: 0.0, g: 0.0, b: 0.0 },
      { r: 0.025, g: 0.025, b: 0.025 },
      { r: 0.04, g: 0.02, b: 0.01 },
    ];
    for (const sample of samples) {
      expect(shadowLatitudeLuma(sample)).toBeLessThanOrEqual(0.025);
      const out = applyShadowLatitudeSample(sample, 1, { clampOutput: true });
      expect(delta(sample, out)).toBeLessThanOrEqual(0.002);
    }
  });

  test("low-mid shadow samples gain separation in the main band", () => {
    for (const v of [0.06, 0.10, 0.18]) {
      const sample = { r: v, g: v, b: v };
      const out = applyShadowLatitudeSample(sample, 1, { clampOutput: true });
      expect(shadowLatitudeLuma(out)).toBeGreaterThan(shadowLatitudeLuma(sample));
    }
  });

  test("normal midtones are released by luma 0.30", () => {
    for (const v of [0.30, 0.42, 0.70]) {
      const sample = { r: v, g: v, b: v };
      const out = applyShadowLatitudeSample(sample, 1, { clampOutput: true });
      expect(delta(sample, out)).toBeLessThanOrEqual(0.003);
    }
  });

  test("hue direction is preserved for representative dark colors", () => {
    const samples: ShadowLatitudeRgb[] = [
      { r: 0.035, g: 0.12, b: 0.045 }, // foliage
      { r: 0.055, g: 0.085, b: 0.15 }, // cool shadow
      { r: 0.16, g: 0.095, b: 0.055 }, // warm shadow
      { r: 0.22, g: 0.13, b: 0.095 }, // skin shadow
    ];
    for (const sample of samples) {
      const out = applyShadowLatitudeSample(sample, 1, { clampOutput: true });
      expect(hueCosine(sample, out)).toBeGreaterThan(0.999);
    }
  });

  test("channel order is preserved and clamped output stays in range", () => {
    const samples: ShadowLatitudeRgb[] = [
      { r: 0.035, g: 0.12, b: 0.045 },
      { r: 0.055, g: 0.085, b: 0.15 },
      { r: 0.16, g: 0.095, b: 0.055 },
    ];
    for (const sample of samples) {
      const out = applyShadowLatitudeSample(sample, 1, { clampOutput: true });
      expectChannelOrderPreserved(sample, out);
      expect(out.r).toBeGreaterThanOrEqual(0);
      expect(out.g).toBeGreaterThanOrEqual(0);
      expect(out.b).toBeGreaterThanOrEqual(0);
      expect(out.r).toBeLessThanOrEqual(1);
      expect(out.g).toBeLessThanOrEqual(1);
      expect(out.b).toBeLessThanOrEqual(1);
    }
  });

  test("parity constants are explicit", () => {
    expect(SHADOW_LATITUDE_CONSTANTS.blackAnchor).toBe(0.025);
    expect(SHADOW_LATITUDE_CONSTANTS.mainBandStart).toBe(0.055);
    expect(SHADOW_LATITUDE_CONSTANTS.mainBandEnd).toBe(0.18);
    expect(SHADOW_LATITUDE_CONSTANTS.releaseEnd).toBe(0.30);
    expect(SHADOW_LATITUDE_CONSTANTS.lumaGainMax).toBe(0.22);
    expect(SHADOW_LATITUDE_CONSTANTS.chromaRetentionMax).toBe(0.08);
  });
});
