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
const URBAN_DENSITY_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-urban-density.cube",
);
const URBAN_DENSITY_ANALYSIS_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/LUT + Extras/Palermo + Colour Density + Green Density.cube";
const PALERMO_REFERENCE_SOURCE =
  "/Volumes/SamsungPortableSSDX5001/filmtone/Palermo_Powergrade & LUTs/Palermo Standalone LUTs/DJI_DLOG-M-Palermo.cube";

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
  test("ships one flagship urban-density Look", () => {
    expect(CREATIVE_PACK_01_LOOKS).toHaveLength(1);
    expect(CREATIVE_PACK_01_LOOKS[0].slug).toBe(
      "filmtone-creative-pack-01-urban-density",
    );
    expect(CREATIVE_PACK_01_LOOKS[0].englishName).toBe("Filmtone Urban Density");
    expect(CREATIVE_PACK_01_LOOKS[0].canonicalUUID).toBe(
      "FB1A0001-0000-4000-8000-000000000006",
    );
    expect(
      CREATIVE_PACK_01_LOOKS.some((look) =>
        look.canonicalUUID.endsWith("000000000007"),
      ),
    ).toBe(false);
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

describe("Creative LUT Pack 01 — Urban Density cube", () => {
  test("generated cube is originalized, not a Palermo byte copy", () => {
    const generated = readFileSync(URBAN_DENSITY_CUBE_PATH);
    const generatedText = generated.toString("utf8");
    expect(generatedText).toContain("generator=filmtone-urban-density-v1");
    expect(generatedText).not.toContain("Palermo");

    for (const sourcePath of [
      URBAN_DENSITY_ANALYSIS_SOURCE,
      PALERMO_REFERENCE_SOURCE,
    ]) {
      if (!existsSync(sourcePath)) continue;
      expect(sha256Hex(generated)).not.toBe(sha256Hex(readFileSync(sourcePath)));
    }
  });

  test("sample points keep the intended urban-density behavior", () => {
    const cube = parseCube(readFileSync(URBAN_DENSITY_CUBE_PATH, "utf8"));

    const gray18 = sampleCube(cube, [0.18, 0.18, 0.18]);
    expect(luma(gray18)).toBeGreaterThan(0.09);
    expect(luma(gray18)).toBeLessThan(0.12);

    const gray50 = sampleCube(cube, [0.5, 0.5, 0.5]);
    expect(gray50[1]).toBeGreaterThan(gray50[0] + 0.04);
    expect(gray50[2]).toBeGreaterThan(gray50[0] + 0.06);
    expect(luma(gray50)).toBeGreaterThan(0.4);
    expect(luma(gray50)).toBeLessThan(0.45);

    const road = sampleCube(cube, [0.32, 0.34, 0.3]);
    expect(road[1]).toBeGreaterThan(road[0] + 0.04);
    expect(road[2]).toBeGreaterThan(road[0]);
    expect(luma(road)).toBeGreaterThan(0.18);
    expect(luma(road)).toBeLessThan(0.24);

    const redSign = sampleCube(cube, [0.78, 0.08, 0.05]);
    expect(redSign[0]).toBeGreaterThan(0.58);
    expect(redSign[0]).toBeGreaterThan(redSign[1] + 0.5);
    expect(redSign[1]).toBeGreaterThan(0.01);
    expect(redSign[2]).toBeGreaterThan(0.008);

    const skin = sampleCube(cube, [0.78, 0.54, 0.4]);
    expect(skin[0]).toBeGreaterThan(skin[1]);
    expect(skin[1]).toBeGreaterThan(skin[2]);
    expect(skin[2]).toBeGreaterThan(0.1);
    expect(luma(skin)).toBeGreaterThan(0.42);

    const foliage = sampleCube(cube, [0.18, 0.42, 0.16]);
    expect(foliage[1]).toBeGreaterThan(foliage[0] + 0.15);
    expect(foliage[1]).toBeGreaterThan(foliage[2] + 0.12);
    expect(luma(foliage)).toBeGreaterThan(0.17);
    expect(luma(foliage)).toBeLessThan(0.23);

    const sky = sampleCube(cube, [0.35, 0.58, 0.82]);
    expect(sky[2]).toBeGreaterThan(sky[1] + 0.25);
    expect(sky[1]).toBeGreaterThan(sky[0] + 0.25);
    expect(luma(sky)).toBeGreaterThan(0.33);
    expect(luma(sky)).toBeLessThan(0.4);

    const yellowStone = sampleCube(cube, [0.72, 0.62, 0.38]);
    expect(yellowStone[0]).toBeGreaterThan(yellowStone[1]);
    expect(yellowStone[1]).toBeGreaterThan(yellowStone[2]);
    expect(yellowStone[2]).toBeGreaterThan(0.1);
    expect(luma(yellowStone)).toBeGreaterThan(0.5);
    expect(luma(yellowStone)).toBeLessThan(0.56);
  });
});
