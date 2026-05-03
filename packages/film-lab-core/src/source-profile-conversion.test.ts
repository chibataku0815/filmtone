import { describe, expect, test } from "bun:test";
import { resolve } from "node:path";
import {
  SOURCE_PROFILE_CATALOG,
  buildSourceProfileLut,
  canonClogPixelToRec709,
  canonLog3CineGamutPixelToRec709,
  canonLog3Decode,
  canonLogDecode,
  dlogDecode,
  dlogMDecode,
  dlogMPixelToRec709,
  dlogPixelToRec709,
  getSourceProfile,
  makeAppleLogToRec709Cube,
  makeDlogToRec709Cube,
  slog3Decode,
  slog3PixelToRec709,
  vlogDecode,
  vlogPixelToRec709,
  type SourceProfileCurve,
  type SourceProfileId,
} from "./source-profile-conversion";

const FIXTURES_ROOT = resolve(
  import.meta.dir,
  "../../../apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile",
);

const RAMP_TOLERANCE = 1e-3;
const PIXEL_MAX_TOLERANCE = 2 / 255;
const PIXEL_MEAN_TOLERANCE = 0.5 / 255;

interface RampSample {
  vEncoded: number;
  lLinear: number;
}

interface MacbethPatch {
  index: number;
  rec709EncodedExpected: [number, number, number];
  rec709LinearReference: [number, number, number];
  // curve-specific encoded array (dlogEncoded / clogEncoded / vlogEncoded / slog3Encoded)
  [key: string]: unknown;
}

async function loadJson<T>(path: string): Promise<T> {
  const file = Bun.file(path);
  return (await file.json()) as T;
}

describe("source profile catalog", () => {
  test("exposes the v1.4 built-in catalog (Rec.709 + 8 curves)", () => {
    expect(SOURCE_PROFILE_CATALOG.map((entry) => entry.id)).toEqual([
      "built-in:source-profile.rec709",
      "built-in:source-profile.apple-log",
      "built-in:source-profile.apple-log-2",
      "built-in:source-profile.dji-dlog",
      "built-in:source-profile.dji-dlog-m",
      "built-in:source-profile.canon-clog",
      "built-in:source-profile.canon-log3-cinema-gamut",
      "built-in:source-profile.panasonic-vlog",
      "built-in:source-profile.sony-slog3",
    ]);
  });

  test("entries are immutable built-ins with the expected impl mix", () => {
    for (const entry of SOURCE_PROFILE_CATALOG) {
      expect(entry.builtIn).toBe(true);
      expect(entry.immutable).toBe(true);
    }
    expect(getSourceProfile("built-in:source-profile.rec709")?.impl).toBe(
      "nil-profile",
    );
    expect(getSourceProfile("built-in:source-profile.apple-log")?.impl).toBe(
      "native-policy",
    );
    expect(
      getSourceProfile("built-in:source-profile.apple-log-2")?.impl,
    ).toBe("native-policy");
    expect(getSourceProfile("built-in:source-profile.dji-dlog")?.impl).toBe(
      "synthesized",
    );
    expect(getSourceProfile("built-in:source-profile.dji-dlog-m")?.impl).toBe(
      "synthesized",
    );
    expect(getSourceProfile("built-in:source-profile.canon-clog")?.impl).toBe(
      "synthesized",
    );
    expect(
      getSourceProfile("built-in:source-profile.canon-log3-cinema-gamut")?.impl,
    ).toBe("synthesized");
    expect(
      getSourceProfile("built-in:source-profile.panasonic-vlog")?.impl,
    ).toBe("synthesized");
    expect(getSourceProfile("built-in:source-profile.sony-slog3")?.impl).toBe(
      "synthesized",
    );
  });

  test("getSourceProfile returns null for unknown ids", () => {
    expect(getSourceProfile("built-in:source-profile.bogus")).toBeNull();
    expect(getSourceProfile("")).toBeNull();
  });
});

describe("buildSourceProfileLut", () => {
  test("rec709 nil-profile returns null (callers should clear lut1)", () => {
    expect(buildSourceProfileLut("built-in:source-profile.rec709")).toBeNull();
  });

  test("unknown id returns null", () => {
    expect(buildSourceProfileLut("built-in:source-profile.bogus")).toBeNull();
  });

  test("returns RGBA Float32Array of length size³ × 4 with alpha = 1", () => {
    const built = buildSourceProfileLut(
      "built-in:source-profile.panasonic-vlog",
    );
    expect(built).not.toBeNull();
    if (!built) return;
    expect(built.size).toBe(33);
    expect(built.data).toBeInstanceOf(Float32Array);
    expect(built.data.length).toBe(33 * 33 * 33 * 4);
    expect(built.id).toBe("built-in:source-profile.panasonic-vlog");
    expect(built.displayName).toBe("V-Log");
    for (let i = 3; i < built.data.length; i += 4) {
      expect(built.data[i]).toBe(1);
    }
  });

  test("rejects size < 2 or non-integer size", () => {
    expect(() =>
      buildSourceProfileLut("built-in:source-profile.dji-dlog", 1),
    ).toThrow("size must be an integer");
    expect(() =>
      buildSourceProfileLut("built-in:source-profile.dji-dlog", 32.5),
    ).toThrow("size must be an integer");
  });

  test("returns the same data buffer for repeated calls (cached)", () => {
    const a = buildSourceProfileLut("built-in:source-profile.dji-dlog");
    const b = buildSourceProfileLut("built-in:source-profile.dji-dlog");
    expect(a?.data).toBe(b?.data);
  });

  test("supports custom sizes (round-trip via cache)", () => {
    const small = buildSourceProfileLut(
      "built-in:source-profile.canon-clog",
      8,
    );
    expect(small?.data.length).toBe(8 * 8 * 8 * 4);
    expect(small?.size).toBe(8);
  });

  test("builds the v1.4 D-Log M and Canon Log 3 source-profile cubes", () => {
    const dlogM = buildSourceProfileLut("built-in:source-profile.dji-dlog-m");
    const clog3 = buildSourceProfileLut(
      "built-in:source-profile.canon-log3-cinema-gamut",
    );
    expect(dlogM?.displayName).toBe("DJI D-Log M");
    expect(clog3?.displayName).toBe("Canon Log 3 / Cinema Gamut");
    expect(dlogM?.data.length).toBe(33 * 33 * 33 * 4);
    expect(clog3?.data.length).toBe(33 * 33 * 33 * 4);
  });
});

// =====================================================================
// Fixture parity — reads iOS Swift's reference fixtures and asserts the
// TS port reproduces the same numbers within a tight budget. If any of
// these fail, the math constants in source-profile-conversion.ts have
// drifted from FilmtoneSourceProfileMath.swift — fix the TS, do not
// loosen the budget.
// =====================================================================

const CURVE_FIXTURES: Array<{
  curve: SourceProfileCurve;
  dirName: string;
  encodedKey: string;
  decode: (encoded: number) => number;
  pixel: (r: number, g: number, b: number) => [number, number, number];
}> = [
  {
    curve: "dji-dlog",
    dirName: "dji-dlog",
    encodedKey: "dlogEncoded",
    decode: dlogDecode,
    pixel: dlogPixelToRec709,
  },
  {
    curve: "dji-dlog-m",
    dirName: "dji-dlog-m",
    encodedKey: "dlogMEncoded",
    decode: dlogMDecode,
    pixel: dlogMPixelToRec709,
  },
  {
    curve: "canon-clog",
    dirName: "canon-clog",
    encodedKey: "clogEncoded",
    decode: canonLogDecode,
    pixel: canonClogPixelToRec709,
  },
  {
    curve: "canon-log3-cinema-gamut",
    dirName: "canon-log3-cinema-gamut",
    encodedKey: "clog3Encoded",
    decode: canonLog3Decode,
    pixel: canonLog3CineGamutPixelToRec709,
  },
  {
    curve: "panasonic-vlog",
    dirName: "panasonic-vlog",
    encodedKey: "vlogEncoded",
    decode: vlogDecode,
    pixel: vlogPixelToRec709,
  },
  {
    curve: "sony-slog3",
    dirName: "sony-slog3",
    encodedKey: "slog3Encoded",
    decode: slog3Decode,
    pixel: slog3PixelToRec709,
  },
];

describe("source profile math — iOS fixture parity", () => {
  for (const fixture of CURVE_FIXTURES) {
    test(`${fixture.curve}: linearization ramp matches Swift within ${RAMP_TOLERANCE}`, async () => {
      const samples = await loadJson<RampSample[]>(
        resolve(FIXTURES_ROOT, fixture.dirName, "linearization-ramp.json"),
      );
      let maxDelta = 0;
      for (const sample of samples) {
        const got = fixture.decode(sample.vEncoded);
        const delta = Math.abs(got - sample.lLinear);
        if (delta > maxDelta) maxDelta = delta;
      }
      expect(maxDelta).toBeLessThanOrEqual(RAMP_TOLERANCE);
    });

    test(`${fixture.curve}: ColorChecker patches match expected Rec.709 within ${PIXEL_MAX_TOLERANCE.toFixed(4)} max / ${PIXEL_MEAN_TOLERANCE.toFixed(4)} mean`, async () => {
      const patches = await loadJson<MacbethPatch[]>(
        resolve(FIXTURES_ROOT, fixture.dirName, "macbeth-patches.json"),
      );
      let maxAbsErr = 0;
      let sumAbsErr = 0;
      let count = 0;
      for (const patch of patches) {
        const encoded = patch[fixture.encodedKey] as [number, number, number];
        const got = fixture.pixel(encoded[0], encoded[1], encoded[2]);
        for (let c = 0; c < 3; c++) {
          const err = Math.abs(got[c]! - patch.rec709EncodedExpected[c]!);
          if (err > maxAbsErr) maxAbsErr = err;
          sumAbsErr += err;
          count += 1;
        }
      }
      const meanAbsErr = sumAbsErr / count;
      expect(maxAbsErr).toBeLessThanOrEqual(PIXEL_MAX_TOLERANCE);
      expect(meanAbsErr).toBeLessThanOrEqual(PIXEL_MEAN_TOLERANCE);
    });
  }

  test("D-Log cube generation matches the per-pixel function (33³ smoke)", () => {
    const cube = makeDlogToRec709Cube(33);
    expect(cube.length).toBe(33 * 33 * 33 * 4);
    // Spot check a few corners and middle: index = ((b * size + g) * size + r) * 4
    const size = 33;
    const samples: Array<[number, number, number]> = [
      [0, 0, 0],
      [size - 1, 0, 0],
      [0, size - 1, 0],
      [0, 0, size - 1],
      [size - 1, size - 1, size - 1],
      [16, 16, 16],
    ];
    for (const [r, g, b] of samples) {
      const denom = size - 1;
      const expected = dlogPixelToRec709(r / denom, g / denom, b / denom);
      const idx = ((b * size + g) * size + r) * 4;
      expect(cube[idx]).toBeCloseTo(expected[0], 5);
      expect(cube[idx + 1]).toBeCloseTo(expected[1], 5);
      expect(cube[idx + 2]).toBeCloseTo(expected[2], 5);
      expect(cube[idx + 3]).toBe(1);
    }
  });

  test("Apple Log cube (rec2020GamutMap=false vs true) differ but share alpha=1", () => {
    const a = makeAppleLogToRec709Cube(8, false);
    const b = makeAppleLogToRec709Cube(8, true);
    expect(a.length).toBe(b.length);
    let differ = false;
    for (let i = 0; i < a.length; i += 4) {
      if (a[i] !== b[i] || a[i + 1] !== b[i + 1] || a[i + 2] !== b[i + 2]) {
        differ = true;
      }
      expect(a[i + 3]).toBe(1);
      expect(b[i + 3]).toBe(1);
    }
    expect(differ).toBe(true);
  });
});

// Small type-only assertion so the SourceProfileId union stays in sync with
// the catalog at compile time. (No runtime expect — TS would fail compile
// if a known id became unknown.)
const _ID_GUARD: SourceProfileId =
  "built-in:source-profile.canon-log3-cinema-gamut";
void _ID_GUARD;
