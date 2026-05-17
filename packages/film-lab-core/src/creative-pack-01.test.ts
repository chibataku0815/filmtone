import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
} from "./bake-color-only";
import {
  CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
  CREATIVE_PACK_01_LOOKS,
} from "./creative-pack-01";
import { CREATIVE_PACK_01_REC709_SAFE_TRANSFORM } from "./creative-pack-01-generator";
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
const NOIR_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-noir.cube",
);
const STONE_REC709_SAFE_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-stone-rec709-safe.cube",
);
const URBAN_REC709_SAFE_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-urban-rec709-safe.cube",
);
const NOIR_REC709_SAFE_CUBE_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-noir-rec709-safe.cube",
);
const CREATIVE_PACK_01_MANIFEST_PATH = resolve(
  REPO_ROOT,
  "apps/capacitor-film-lab-ios/Tests/Fixtures/creative-pack-01/manifest.json",
);
const PALERMO_DLOGM_SOURCE =
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

function spread(rgb: SamplePoint): number {
  return Math.max(...rgb) - Math.min(...rgb);
}

describe("Creative LUT Pack 01 — runtime color neutralization", () => {
  test("ships Stone, Urban, and Noir Looks", () => {
    expect(CREATIVE_PACK_01_LOOKS).toHaveLength(3);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.slug)).toEqual([
      "filmtone-creative-pack-01-stone",
      "filmtone-creative-pack-01-urban",
      "filmtone-creative-pack-01-noir",
    ]);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.englishName)).toEqual([
      "Stone",
      "Urban",
      "Noir",
    ]);
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.canonicalUUID)).toEqual([
      "FB1A0001-0000-4000-8000-000000000006",
      "FB1A0001-0000-4000-8000-000000000007",
      "FB1A0001-0000-4000-8000-000000000010",
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

  test("every Look declares Rec.709-safe source policy", () => {
    expect(
      CREATIVE_PACK_01_LOOKS.map((look) => [
        look.slug,
        look.expectedProcessSpace,
        look.rec709SafeIntensityCeiling,
      ]),
    ).toEqual([
      [
        "filmtone-creative-pack-01-stone",
        CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
        0.86,
      ],
      [
        "filmtone-creative-pack-01-urban",
        CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
        0.84,
      ],
      [
        "filmtone-creative-pack-01-noir",
        CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
        0.92,
      ],
    ]);
  });

  test("runtime toe separation stays neutral until an authored pass adopts it", () => {
    expect(BAKE_COLOR_PARAM_KEYS).not.toContain("shadowLatitude");
    expect(CREATIVE_PACK_01_LOOKS.map((look) => look.paramOverrides.shadowLatitude)).toEqual([
      undefined,
      undefined,
      undefined,
    ]);
  });

  test("Stone carries a stronger localized optical baseline without lowering the bloom threshold", () => {
    const stone = CREATIVE_PACK_01_LOOKS.find(
      (look) => look.slug === "filmtone-creative-pack-01-stone",
    );
    expect(stone?.paramOverrides.bloomThreshold).toBe(0.72);
    expect(stone?.paramOverrides.bloomStrength).toBeGreaterThanOrEqual(0.13);
    expect(stone?.paramOverrides.bloomStrength).toBeLessThanOrEqual(0.14);
    expect(stone?.paramOverrides.bloomRadius).toBe(0.60);
    expect(stone?.paramOverrides.halationIntensity).toBeGreaterThanOrEqual(0.06);
    expect(stone?.paramOverrides.halationIntensity).toBeLessThanOrEqual(0.07);
    expect(stone?.paramOverrides.rgbShift).toBeGreaterThanOrEqual(0.002);
    expect(stone?.paramOverrides.lensSoftness).toBeGreaterThanOrEqual(0.08);
    expect(stone?.paramOverrides.diffusion).toBe(0.015);
    expect(stone?.paramOverrides.fade).toBe(0);
  });
});

describe("Creative LUT Pack 01 — generated cubes", () => {
  test("manifest pins Rec.709-safe color variants next to the full cubes", () => {
    const manifest = JSON.parse(readFileSync(CREATIVE_PACK_01_MANIFEST_PATH, "utf8"));
    expect(manifest.schemaVersion).toBe(2);
    expect(
      manifest.looks.map((look: Record<string, unknown>) => ({
        slug: look.slug,
        rec709SafeCubeRelPath: look.rec709SafeCubeRelPath,
        rec709SafeCubeSize: look.rec709SafeCubeSize,
        rec709SafeCubeSha256: look.rec709SafeCubeSha256,
        rec709SafeSourceCubeTransform: look.rec709SafeSourceCubeTransform,
      })),
    ).toEqual([
      {
        slug: "filmtone-creative-pack-01-stone",
        rec709SafeCubeRelPath:
          "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-stone-rec709-safe.cube",
        rec709SafeCubeSize: 65,
        rec709SafeCubeSha256:
          "65aa4c8294361cf1c55fcb9c5c7bb357b9e6ead08778c043885e86d336e49dbe",
        rec709SafeSourceCubeTransform: CREATIVE_PACK_01_REC709_SAFE_TRANSFORM,
      },
      {
        slug: "filmtone-creative-pack-01-urban",
        rec709SafeCubeRelPath:
          "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-urban-rec709-safe.cube",
        rec709SafeCubeSize: 65,
        rec709SafeCubeSha256:
          "e958a500f0d7f9ffe4c77143be60691b248ccf688a727c8ee4b8b09110805505",
        rec709SafeSourceCubeTransform: CREATIVE_PACK_01_REC709_SAFE_TRANSFORM,
      },
      {
        slug: "filmtone-creative-pack-01-noir",
        rec709SafeCubeRelPath:
          "apps/capacitor-film-lab-ios/ios/App/App/Resources/CreativeLuts/filmtone-creative-pack-01-noir-rec709-safe.cube",
        rec709SafeCubeSize: 65,
        rec709SafeCubeSha256:
          "f8f321d576f17045861e81441c0e17d303ec31b6243c26b59c31734c7d6057ea",
        rec709SafeSourceCubeTransform: CREATIVE_PACK_01_REC709_SAFE_TRANSFORM,
      },
    ]);

    for (const look of manifest.looks) {
      const safePath = resolve(
        REPO_ROOT,
        look.rec709SafeCubeRelPath as string,
      );
      expect(sha256Hex(readFileSync(safePath))).toBe(look.rec709SafeCubeSha256);
    }
  });

  test("source-derived Stone and Urban cubes are originalized, not Palermo byte copies", () => {
    const cases = [
      {
        cubePath: STONE_CUBE_PATH,
        sourcePath: PALERMO_DLOGM_SOURCE,
        generator: "generator=filmtone-stone-dlogm-palermo-display-v2",
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

  test("Stone adapts D-Log M Palermo into an original dense display-domain cube with a protected black floor", () => {
    const stoneLook = CREATIVE_PACK_01_LOOKS.find(
      (look) => look.slug === "filmtone-creative-pack-01-stone",
    );
    expect(stoneLook?.sourceCubeTransform).toBe(
      "filmtone-stone-dlogm-palermo-display-v2",
    );
    const stone = parseCube(readFileSync(STONE_CUBE_PATH, "utf8"));
    const stoneText = readFileSync(STONE_CUBE_PATH, "utf8");
    expect(stoneText).toContain("generator=filmtone-stone-dlogm-palermo-display-v2");
    expect(stoneText).not.toContain("filmtone-stone-palermo-reference");

    const black = sampleCube(stone, [0.02, 0.02, 0.02]);
    const shadow = sampleCube(stone, [0.08, 0.08, 0.08]);
    const gray18 = sampleCube(stone, [0.18, 0.18, 0.18]);
    const mid = sampleCube(stone, [0.45, 0.45, 0.45]);
    const high = sampleCube(stone, [0.72, 0.72, 0.72]);
    const lanternRed = sampleCube(stone, [0.78, 0.08, 0.05]);
    const skin = sampleCube(stone, [0.62, 0.45, 0.36]);
    const sky = sampleCube(stone, [0.35, 0.58, 0.82]);
    const foliage = sampleCube(stone, [0.18, 0.42, 0.16]);

    expect(luma(black)).toBeLessThanOrEqual(0.022);
    expect(luma(shadow)).toBeLessThan(0.079);
    expect(luma(gray18)).toBeGreaterThan(0.088);
    expect(luma(gray18)).toBeLessThan(0.105);
    expect(luma(mid)).toBeGreaterThan(0.37);
    expect(luma(mid)).toBeLessThan(0.405);
    expect(luma(high)).toBeGreaterThan(0.69);
    expect(luma(high)).toBeLessThan(0.71);
    expect(lanternRed[0]).toBeGreaterThan(0.52);
    expect(lanternRed[0]).toBeLessThan(0.57);
    expect(lanternRed[0]).toBeGreaterThan(lanternRed[1] * 8);
    expect(lanternRed[2]).toBeLessThan(0.004);
    expect(Math.abs(luma(skin) - luma([0.62, 0.45, 0.36]))).toBeLessThan(0.09);
    expect(skin[0]).toBeGreaterThan(skin[1] * 1.48);
    expect(skin[1]).toBeGreaterThan(skin[2] * 1.55);
    expect(skin[2]).toBeGreaterThan(0.18);
    expect(skin[2]).toBeLessThan(0.24);
    expect(sky[0]).toBeGreaterThan(0.07);
    expect(sky[0]).toBeLessThan(0.13);
    expect(sky[1]).toBeGreaterThan(0.50);
    expect(sky[2]).toBeGreaterThan(0.66);
    expect(foliage[1]).toBeGreaterThan(foliage[0] * 2.5);
    expect(luma(foliage)).toBeLessThan(0.205);
  });

  test("source-derived Urban sample points stay aligned to Palermo within tolerance", () => {
    // Urban layers Filmtone's "cool urban density" character on top of the
    // Green Density source, so its delta envelope is intentionally bounded
    // while still clearly distinct from Stone.
    const cases = [
      {
        cubePath: URBAN_CUBE_PATH,
        sourcePath: PALERMO_GREEN_DENSITY_SOURCE,
        channelTol: 0.05,
        lumaTol: 0.04,
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

    for (const { cubePath, sourcePath, channelTol, lumaTol } of cases) {
      const cube = parseCube(readFileSync(cubePath, "utf8"));
      const reference = parseCube(readFileSync(sourcePath, "utf8"));
      for (const point of points) {
        const actual = sampleCube(cube, point);
        const expected = sampleCube(reference, point);
        for (let i = 0; i < 3; i++) {
          expect(Math.abs(actual[i] - expected[i])).toBeLessThanOrEqual(channelTol);
        }
        expect(Math.abs(luma(actual) - luma(expected))).toBeLessThanOrEqual(lumaTol);
      }
    }
  });

  test("Stone and Urban are clearly visually distinct", () => {
    const stone = parseCube(readFileSync(STONE_CUBE_PATH, "utf8"));
    const urban = parseCube(readFileSync(URBAN_CUBE_PATH, "utf8"));
    // Mix of neutral, skin, sky, foliage, signage — the everyday photo
    // distribution where the previous build read as "ほぼ同じ".
    const points: readonly SamplePoint[] = [
      [0.18, 0.18, 0.18],
      [0.45, 0.45, 0.45],
      [0.62, 0.45, 0.36],
      [0.30, 0.45, 0.70],
      [0.25, 0.50, 0.20],
      [0.85, 0.65, 0.40],
      [0.20, 0.25, 0.32],
    ];
    let totalAbs = 0;
    let maxDelta = 0;
    for (const point of points) {
      const a = sampleCube(stone, point);
      const b = sampleCube(urban, point);
      for (let i = 0; i < 3; i++) {
        const d = Math.abs(a[i] - b[i]);
        totalAbs += d;
        if (d > maxDelta) maxDelta = d;
      }
    }
    const meanAbs = totalAbs / (points.length * 3);
    expect(meanAbs).toBeGreaterThan(0.025);
    expect(maxDelta).toBeGreaterThan(0.05);
  });

  test("Rec.709-safe Stone and Urban variants compress risky display chroma while preserving neutral and skin behavior", () => {
    const cases = [
      {
        fullPath: STONE_CUBE_PATH,
        safePath: STONE_REC709_SAFE_CUBE_PATH,
        risky: [
          [0.9, 0.05, 0.05],
          [0.05, 0.9, 0.05],
          [0.05, 0.25, 0.95],
        ],
      },
      {
        fullPath: URBAN_CUBE_PATH,
        safePath: URBAN_REC709_SAFE_CUBE_PATH,
        risky: [
          [0.9, 0.05, 0.05],
          [0.05, 0.9, 0.05],
          [0.05, 0.25, 0.95],
        ],
      },
    ] as const;

    for (const { fullPath, safePath, risky } of cases) {
      const full = parseCube(readFileSync(fullPath, "utf8"));
      const safeText = readFileSync(safePath, "utf8");
      const safe = parseCube(safeText);
      expect(safeText).toContain("variant=rec709-safe");
      expect(safeText).toContain(`generator=${CREATIVE_PACK_01_REC709_SAFE_TRANSFORM}`);

      for (const point of [
        [0.45, 0.45, 0.45],
        [0.62, 0.45, 0.36],
      ] as const) {
        const fullSample = sampleCube(full, point);
        const safeSample = sampleCube(safe, point);
        for (let i = 0; i < 3; i++) {
          expect(Math.abs(safeSample[i] - fullSample[i])).toBeLessThanOrEqual(
            0.001,
          );
        }
      }

      for (const point of risky) {
        const fullSample = sampleCube(full, point);
        const safeSample = sampleCube(safe, point);
        expect(spread(safeSample)).toBeLessThan(spread(fullSample));
        expect(Math.abs(luma(safeSample) - luma(fullSample))).toBeLessThan(0.05);
      }
    }
  });

  test("Noir is a toned print monochrome cube with bounded residual chroma", () => {
    const noir = parseCube(readFileSync(NOIR_CUBE_PATH, "utf8"));
    const points: readonly SamplePoint[] = [
      [0.08, 0.08, 0.08],
      [0.18, 0.18, 0.18],
      [0.45, 0.45, 0.45],
      [0.72, 0.72, 0.72],
      [0.62, 0.45, 0.36],
      [0.30, 0.45, 0.70],
      [0.85, 0.65, 0.40],
    ];

    let totalLumaDelta = 0;
    let maxSpread = 0;
    let maxResidualSpread = 0;
    for (const point of points) {
      const actual = sampleCube(noir, point);
      const spread = Math.max(...actual) - Math.min(...actual);
      expect(spread).toBeLessThanOrEqual(0.08);
      maxSpread = Math.max(maxSpread, spread);
      if (spread > 0.0001) {
        maxResidualSpread = Math.max(maxResidualSpread, spread);
      }
      totalLumaDelta += Math.abs(luma(actual) - luma(point));
    }

    const gray18 = sampleCube(noir, [0.18, 0.18, 0.18]);
    const mid = sampleCube(noir, [0.45, 0.45, 0.45]);
    const high = sampleCube(noir, [0.72, 0.72, 0.72]);
    const white = sampleCube(noir, [1, 1, 1]);
    const skin = sampleCube(noir, [0.62, 0.45, 0.36]);

    expect(luma(gray18)).toBeGreaterThanOrEqual(0.075);
    expect(luma(gray18)).toBeLessThanOrEqual(0.10);
    expect(luma(mid)).toBeGreaterThanOrEqual(0.27);
    expect(luma(mid)).toBeLessThanOrEqual(0.31);
    expect(luma(high)).toBeGreaterThanOrEqual(0.69);
    expect(luma(high)).toBeLessThanOrEqual(0.73);
    expect(luma(white)).toBeLessThanOrEqual(0.93);
    expect(mid[1] - mid[2]).toBeGreaterThanOrEqual(0.045);
    expect(high[1] - high[2]).toBeGreaterThanOrEqual(0.05);
    expect(skin[1] - skin[2]).toBeGreaterThanOrEqual(0.05);
    expect(maxResidualSpread).toBeGreaterThanOrEqual(0.055);
    expect(maxSpread).toBeLessThanOrEqual(0.08);
    expect(totalLumaDelta / points.length).toBeGreaterThan(0.06);
  });

  test("Rec.709-safe Noir variant stays pinned to the monochrome print family", () => {
    const full = parseCube(readFileSync(NOIR_CUBE_PATH, "utf8"));
    const safeText = readFileSync(NOIR_REC709_SAFE_CUBE_PATH, "utf8");
    const safe = parseCube(safeText);
    expect(safeText).toContain("variant=rec709-safe");
    expect(safeText).toContain(`generator=${CREATIVE_PACK_01_REC709_SAFE_TRANSFORM}`);

    for (const point of [
      [0.9, 0.05, 0.05],
      [0.05, 0.9, 0.05],
      [0.05, 0.25, 0.95],
      [0.62, 0.45, 0.36],
      [0.45, 0.45, 0.45],
    ] as const) {
      const fullSample = sampleCube(full, point);
      const safeSample = sampleCube(safe, point);
      expect(spread(safeSample)).toBeLessThanOrEqual(0.081);
      expect(Math.abs(spread(safeSample) - spread(fullSample))).toBeLessThan(0.002);
      expect(Math.abs(luma(safeSample) - luma(fullSample))).toBeLessThan(0.002);
    }
  });
});
