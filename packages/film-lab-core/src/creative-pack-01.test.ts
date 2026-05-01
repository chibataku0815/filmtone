import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
} from "./bake-color-only";
import { CREATIVE_PACK_01_LOOKS } from "./creative-pack-01";
import { parseCube, type CubeLUT } from "./cube-parser";

type SamplePoint = readonly [number, number, number];

const REPO_ROOT = resolve(import.meta.dir, "../../..");
const STONE_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-stone.cube",
);
const URBAN_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-urban.cube",
);
const PALERMO_REFERENCE_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/DJI_DLOG-M-Palermo.cube";
const PALERMO_GREEN_DENSITY_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/LUT + Extras/Palermo + Colour Density + Green Density.cube";

function sha256Hex(bytes: Uint8Array): string {
  const hash = createHash("sha256");
  hash.update(bytes);
  return hash.digest("hex");
}

function sampleCube(cube: CubeLUT, rgb: SamplePoint): SamplePoint {
  const n = cube.size - 1;
  const coords = rgb.map((value) => Math.max(0, Math.min(1, value)) * n);
  const i0 = coords.map(Math.floor);
  const i1 = i0.map((value) => Math.min(n, value + 1));
  const f = coords.map((value, index) => value - i0[index]);
  const out = [0, 0, 0];

  for (let bz = 0; bz < 2; bz++) {
    for (let gy = 0; gy < 2; gy++) {
      for (let rx = 0; rx < 2; rx++) {
        const r = rx ? i1[0] : i0[0];
        const g = gy ? i1[1] : i0[1];
        const b = bz ? i1[2] : i0[2];
        const weight =
          (rx ? f[0] : 1 - f[0]) *
          (gy ? f[1] : 1 - f[1]) *
          (bz ? f[2] : 1 - f[2]);
        const idx = (b * cube.size * cube.size + g * cube.size + r) * 4;
        out[0] += cube.data[idx + 0] * weight;
        out[1] += cube.data[idx + 1] * weight;
        out[2] += cube.data[idx + 2] * weight;
      }
    }
  }

  return out as SamplePoint;
}

function luma(rgb: SamplePoint): number {
  return 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2];
}

describe("Creative LUT Pack 01 — runtime color neutralization", () => {
  test("ships Stone base and Urban green-density Looks", () => {
    expect(CREATIVE_PACK_01_LOOKS).toHaveLength(2);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.slug)).toEqual([
      "filmtone-creative-pack-01-stone",
      "filmtone-creative-pack-01-urban",
    ]);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.englishName)).toEqual([
      "Stone",
      "Urban",
    ]);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.canonicalUUID)).toEqual([
      "FB1A0001-0000-4000-8000-000000000006",
      "FB1A0001-0000-4000-8000-000000000007",
    ]);
  });

  test("every Look neutralizes baked color ops and v2 split-tone strengths", () => {
    for (const look of CREATIVE_PACK_01_LOOKS) {
      for (const key of BAKE_COLOR_PARAM_KEYS) {
        expect(look.paramOverrides[key]).toBe(BAKE_COLOR_IDENTITY[key]);
      }
      expect(look.paramOverrides.shadowTone).toBe(0);
      expect(look.paramOverrides.highlightTone).toBe(0);
    }
  });
});

describe("Creative LUT Pack 01 — generated cubes", () => {
  test("generated cube is originalized, not a Palermo byte copy", () => {
    const cases = [
      {
        cubePath: STONE_CUBE_PATH,
        sourcePath: PALERMO_REFERENCE_SOURCE,
        generator: "generator=filmtone-stone-palermo-reference-v1",
      },
      {
        cubePath: URBAN_CUBE_PATH,
        sourcePath: PALERMO_GREEN_DENSITY_SOURCE,
        generator: "generator=filmtone-urban-palermo-green-density-v1",
      },
    ] as const;

    for (const { cubePath, sourcePath, generator } of cases) {
      const generated = readFileSync(cubePath);
      const generatedText = generated.toString("utf8");
      expect(generatedText).toContain(generator);
      expect(generatedText).not.toContain("Palermo");
      if (!existsSync(sourcePath)) continue;
      expect(sha256Hex(generated)).not.toBe(sha256Hex(readFileSync(sourcePath)));
    }
  });

  test("sample points stay tightly aligned to their Palermo source", () => {
    const cases = [
      {
        cubePath: STONE_CUBE_PATH,
        sourcePath: PALERMO_REFERENCE_SOURCE,
      },
      {
        cubePath: URBAN_CUBE_PATH,
        sourcePath: PALERMO_GREEN_DENSITY_SOURCE,
      },
    ] as const;
    const points: readonly SamplePoint[] = [
      [0.18, 0.18, 0.18],
      [0.5, 0.5, 0.5],
      [0.32, 0.34, 0.3],
      [0.78, 0.08, 0.05],
      [0.78, 0.54, 0.4],
      [0.18, 0.42, 0.16],
      [0.35, 0.58, 0.82],
      [0.72, 0.62, 0.38],
    ];

    for (const { cubePath, sourcePath } of cases) {
      const cube = parseCube(readFileSync(cubePath, "utf8"));
      const reference = parseCube(readFileSync(sourcePath, "utf8"));
      for (const point of points) {
        const actual = sampleCube(cube, point);
        const expected = sampleCube(reference, point);
        for (let i = 0; i < 3; i++) {
          expect(Math.abs(actual[i] - expected[i])).toBeLessThanOrEqual(0.006);
        }
        expect(Math.abs(luma(actual) - luma(expected))).toBeLessThanOrEqual(0.004);
      }
    }
  });
});
