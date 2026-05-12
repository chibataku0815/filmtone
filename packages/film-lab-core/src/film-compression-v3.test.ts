import { describe, expect, test } from "bun:test";
import {
  applyFilmCompressionV3Sample,
  filmCompressionChromaMagnitude,
  filmCompressionLuma,
  FILM_COMPRESSION_V3_CONSTANTS,
  type FilmCompressionRgb,
} from "./film-compression-v3";

const EPS = 1e-12;

function chromaVector(rgb: FilmCompressionRgb): [number, number, number] {
  const y = filmCompressionLuma(rgb);
  return [rgb.r - y, rgb.g - y, rgb.b - y];
}

function chromaRatio(input: FilmCompressionRgb, output: FilmCompressionRgb): number {
  return (
    filmCompressionChromaMagnitude(output) /
    Math.max(filmCompressionChromaMagnitude(input), 1e-9)
  );
}

function hueCosine(a: FilmCompressionRgb, b: FilmCompressionRgb): number {
  const av = chromaVector(a);
  const bv = chromaVector(b);
  const al = Math.hypot(av[0], av[1], av[2]);
  const bl = Math.hypot(bv[0], bv[1], bv[2]);
  if (al < 1e-9 || bl < 1e-9) {
    return 1;
  }
  return (av[0] * bv[0] + av[1] * bv[1] + av[2] * bv[2]) / (al * bl);
}

function maxChannel(rgb: FilmCompressionRgb): number {
  return Math.max(rgb.r, rgb.g, rgb.b);
}

describe("filmCompressionV3 scalar model", () => {
  test("amount 0 is identity", () => {
    const samples: FilmCompressionRgb[] = [
      { r: 0.95, g: 0.72, b: 0.36 },
      { r: 0.14, g: 0.42, b: 0.95 },
      { r: 1.2, g: 0.35, b: 0.25 },
    ];
    for (const sample of samples) {
      const out = applyFilmCompressionV3Sample(sample, 0, 0.5);
      expect(out.r).toBe(sample.r);
      expect(out.g).toBe(sample.g);
      expect(out.b).toBe(sample.b);
    }
  });

  test("neutral gray remains neutral", () => {
    for (const v of [0, 0.08, 0.18, 0.5, 0.82, 1]) {
      const out = applyFilmCompressionV3Sample(
        { r: v, g: v, b: v },
        0.8,
        0.62,
        { clampOutput: true },
      );
      expect(Math.abs(out.r - out.g)).toBeLessThan(EPS);
      expect(Math.abs(out.g - out.b)).toBeLessThan(EPS);
    }
  });

  test("preserves chroma direction for representative hues", () => {
    const samples: FilmCompressionRgb[] = [
      { r: 0.92, g: 0.63, b: 0.48 },
      { r: 0.42, g: 0.68, b: 0.94 },
      { r: 0.35, g: 0.72, b: 0.38 },
      { r: 1.0, g: 0.12, b: 0.06 },
      { r: 0.08, g: 0.92, b: 1.0 },
    ];
    for (const sample of samples) {
      const out = applyFilmCompressionV3Sample(sample, 0.85, 0.58, {
        clampOutput: true,
      });
      expect(hueCosine(sample, out)).toBeGreaterThan(0.999);
    }
  });

  test("bright saturated samples compress chroma more than midtone samples", () => {
    const bright = { r: 0.18, g: 1.0, b: 1.0 };
    const mid = { r: 0.09, g: 0.5, b: 0.5 };
    const brightOut = applyFilmCompressionV3Sample(bright, 0.85, 0.6, {
      clampOutput: true,
    });
    const midOut = applyFilmCompressionV3Sample(mid, 0.85, 0.6, {
      clampOutput: true,
    });
    expect(chromaRatio(bright, brightOut)).toBeLessThan(chromaRatio(mid, midOut));
  });

  test("warm skin direction is protected relative to practical cyan", () => {
    const skin = { r: 0.92, g: 0.63, b: 0.48 };
    const cyan = { r: 0.14, g: 0.86, b: 0.92 };
    const skinOut = applyFilmCompressionV3Sample(skin, 0.9, 0.55, {
      clampOutput: true,
    });
    const cyanOut = applyFilmCompressionV3Sample(cyan, 0.9, 0.55, {
      clampOutput: true,
    });
    expect(chromaRatio(skin, skinOut)).toBeGreaterThan(chromaRatio(cyan, cyanOut));
  });

  test("shadows are identity-preserving (no lift, full chroma)", () => {
    // The one-sided shoulder leaves luma ≤ ~0.13 untouched: shadowRelease
    // gates the chroma compression to zero and the sigmoid floor is clipped
    // by min(luma, sigmoid). Deep blacks must not lift, and their chroma
    // must not be boosted or attenuated.
    const shadow = { r: 0.05, g: 0.1, b: 0.15 };
    const out = applyFilmCompressionV3Sample(shadow, 0.9, 0.65, {
      clampOutput: true,
    });
    expect(out.r).toBe(shadow.r);
    expect(out.g).toBe(shadow.g);
    expect(out.b).toBe(shadow.b);
    expect(filmCompressionChromaMagnitude(out)).toBe(
      filmCompressionChromaMagnitude(shadow),
    );
    expect(hueCosine(shadow, out)).toBeGreaterThan(0.99999999);
  });

  test("problem-color guard pulls saturated boundary colors inward", () => {
    const sample = { r: 1.0, g: 0.05, b: 0.04 };
    const out = applyFilmCompressionV3Sample(sample, 0.95, 0.58, {
      clampOutput: true,
    });
    expect(filmCompressionChromaMagnitude(out)).toBeLessThan(
      filmCompressionChromaMagnitude(sample),
    );
    expect(out.r).toBeLessThan(sample.r);
  });

  test("highlight density landing strongly rounds saturated practical cores", () => {
    const practicals: FilmCompressionRgb[] = [
      { r: 1.0, g: 0.05, b: 0.04 },
      { r: 0.18, g: 1.0, b: 1.0 },
      { r: 0.08, g: 0.22, b: 1.0 },
      { r: 1.0, g: 0.05, b: 1.0 },
    ];

    for (const sample of practicals) {
      const out = applyFilmCompressionV3Sample(sample, 0.9, 0.6, {
        clampOutput: true,
      });
      expect(maxChannel(out)).toBeLessThan(0.92);
      expect(hueCosine(sample, out)).toBeGreaterThan(0.999);
      expect(filmCompressionChromaMagnitude(out)).toBeLessThan(
        filmCompressionChromaMagnitude(sample),
      );
    }
  });

  test("parity constants are explicit", () => {
    expect(FILM_COMPRESSION_V3_CONSTANTS.chromaCompressionMax).toBe(0.42);
    expect(FILM_COMPRESSION_V3_CONSTANTS.problemColorGuardMax).toBe(0.22);
    expect(FILM_COMPRESSION_V3_CONSTANTS.warmProtectStrength).toBe(0.35);
    expect(FILM_COMPRESSION_V3_CONSTANTS.shadowReleaseStart).toBe(0.14);
    expect(FILM_COMPRESSION_V3_CONSTANTS.shadowReleaseEnd).toBe(0.3);
    expect(FILM_COMPRESSION_V3_CONSTANTS.highlightDensityLandingStart).toBe(0.78);
    expect(FILM_COMPRESSION_V3_CONSTANTS.highlightDensityLandingStrength).toBe(0.88);
  });
});
