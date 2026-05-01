import { describe, expect, test } from "bun:test";
import {
  bakeColorOnly,
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
  type BakeColorParams,
} from "./bake-color-only";

const SAMPLE_GRID = [0, 0.18, 0.5, 0.82, 1.0];
const IDENTITY_TOL = 1e-12;

function mkSamples(): { r: number; g: number; b: number }[] {
  const out: { r: number; g: number; b: number }[] = [];
  for (const r of SAMPLE_GRID) {
    for (const g of SAMPLE_GRID) {
      for (const b of SAMPLE_GRID) {
        out.push({ r, g, b });
      }
    }
  }
  return out;
}

describe("bakeColorOnly — identity contract", () => {
  test("identity params return input unchanged within float64 tolerance", () => {
    for (const sample of mkSamples()) {
      const out = bakeColorOnly(sample, BAKE_COLOR_IDENTITY);
      expect(Math.abs(out.r - sample.r)).toBeLessThan(IDENTITY_TOL);
      expect(Math.abs(out.g - sample.g)).toBeLessThan(IDENTITY_TOL);
      expect(Math.abs(out.b - sample.b)).toBeLessThan(IDENTITY_TOL);
    }
  });

  test("BAKE_COLOR_PARAM_KEYS contains exactly 12 ops", () => {
    expect(BAKE_COLOR_PARAM_KEYS.length).toBe(12);
    expect(new Set(BAKE_COLOR_PARAM_KEYS).size).toBe(12);
  });
});

describe("bakeColorOnly — Stage 2 (baseGrade) directional checks", () => {
  test("exposure +1 doubles linear output (clamped at 1)", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, exposure: 1 };
    const out = bakeColorOnly({ r: 0.25, g: 0.25, b: 0.25 }, params);
    expect(out.r).toBeCloseTo(0.5, 6);
    expect(out.g).toBeCloseTo(0.5, 6);
    expect(out.b).toBeCloseTo(0.5, 6);
  });

  test("contrast 1.0 leaves mid-gray fixed", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, contrast: 1.0 };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(out.r).toBeCloseTo(0.5, 12);
    expect(out.g).toBeCloseTo(0.5, 12);
    expect(out.b).toBeCloseTo(0.5, 12);
  });

  test("contrast > 1 pushes shadows down and highlights up around 0.5 pivot", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, contrast: 1.5 };
    const dark = bakeColorOnly({ r: 0.25, g: 0.25, b: 0.25 }, params);
    const bright = bakeColorOnly({ r: 0.75, g: 0.75, b: 0.75 }, params);
    expect(dark.r).toBeLessThan(0.25);
    expect(bright.r).toBeGreaterThan(0.75);
  });

  test("saturation 0 returns equal RGB at the luma value", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, saturation: 0 };
    const sample = { r: 0.8, g: 0.4, b: 0.2 };
    const out = bakeColorOnly(sample, params);
    expect(out.r).toBeCloseTo(out.g, 6);
    expect(out.g).toBeCloseTo(out.b, 6);
  });

  test("temperature > 0 pushes red up and blue down", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, temperature: 0.5 };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(out.r).toBeGreaterThan(0.5);
    expect(out.b).toBeLessThan(0.5);
  });

  test("fade > 0 lifts black", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, fade: 0.5 };
    const out = bakeColorOnly({ r: 0, g: 0, b: 0 }, params);
    expect(out.r).toBeCloseTo(0.5, 6);
  });
});

describe("bakeColorOnly — Stage 3 (filmCompression)", () => {
  test("compressionAmount 0 is no-op", () => {
    const params: BakeColorParams = {
      ...BAKE_COLOR_IDENTITY,
      compressionAmount: 0,
    };
    const sample = { r: 0.95, g: 0.7, b: 0.3 };
    const out = bakeColorOnly(sample, params);
    expect(out.r).toBeCloseTo(sample.r, 12);
    expect(out.g).toBeCloseTo(sample.g, 12);
    expect(out.b).toBeCloseTo(sample.b, 12);
  });

  test("compressionAmount > 0 leaves output bounded in [0, 1]", () => {
    const params: BakeColorParams = {
      ...BAKE_COLOR_IDENTITY,
      compressionAmount: 0.8,
      compressionRange: 0.5,
    };
    for (const sample of mkSamples()) {
      const out = bakeColorOnly(sample, params);
      expect(out.r).toBeGreaterThanOrEqual(0);
      expect(out.r).toBeLessThanOrEqual(1);
      expect(out.g).toBeGreaterThanOrEqual(0);
      expect(out.g).toBeLessThanOrEqual(1);
      expect(out.b).toBeGreaterThanOrEqual(0);
      expect(out.b).toBeLessThanOrEqual(1);
    }
  });
});

describe("bakeColorOnly — Stage 9 (printStage)", () => {
  test("cyan > 0 reduces red channel", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, cyan: 1 };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(out.r).toBeLessThan(0.5);
  });

  test("magenta > 0 reduces green channel", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, magenta: 1 };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(out.g).toBeLessThan(0.5);
  });

  test("yellow > 0 reduces blue channel", () => {
    const params: BakeColorParams = { ...BAKE_COLOR_IDENTITY, yellow: 1 };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(out.b).toBeLessThan(0.5);
  });

  test("printContrast > 0 keeps mid-gray near pivot", () => {
    const params: BakeColorParams = {
      ...BAKE_COLOR_IDENTITY,
      printContrast: 0.5,
    };
    const out = bakeColorOnly({ r: 0.5, g: 0.5, b: 0.5 }, params);
    expect(Math.abs(out.r - 0.5)).toBeLessThan(0.01);
  });
});

describe("bakeColorOnly — output bounds", () => {
  test("any combination keeps RGB in [0, 1]", () => {
    const aggressive: BakeColorParams = {
      exposure: 1.5,
      contrast: 1.8,
      saturation: 1.5,
      temperature: 0.8,
      tint: -0.5,
      fade: 0.3,
      compressionAmount: 0.7,
      compressionRange: 0.5,
      printContrast: 0.6,
      cyan: 0.5,
      magenta: -0.4,
      yellow: 0.7,
    };
    for (const sample of mkSamples()) {
      const out = bakeColorOnly(sample, aggressive);
      expect(out.r).toBeGreaterThanOrEqual(0);
      expect(out.r).toBeLessThanOrEqual(1);
      expect(out.g).toBeGreaterThanOrEqual(0);
      expect(out.g).toBeLessThanOrEqual(1);
      expect(out.b).toBeGreaterThanOrEqual(0);
      expect(out.b).toBeLessThanOrEqual(1);
    }
  });
});
