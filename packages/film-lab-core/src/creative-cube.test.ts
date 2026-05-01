import { describe, expect, test } from "bun:test";
import {
  CREATIVE_CUBE_DEFAULT_SIZE,
  diagonalMaxDelta,
  makeCreativeCube,
  makeIdentityCube,
} from "./creative-cube";
import { BAKE_COLOR_IDENTITY } from "./bake-color-only";
import { parseCube } from "./cube-parser";
import { serializeCreativeCubeToText } from "./creative-cube-serialize";

describe("makeCreativeCube — grid shape", () => {
  test("default size 33 produces 33³ × 3 floats", () => {
    const cube = makeIdentityCube();
    expect(cube.size).toBe(CREATIVE_CUBE_DEFAULT_SIZE);
    expect(cube.data.length).toBe(33 * 33 * 33 * 3);
  });

  test("custom size 17 produces 17³ × 3 floats", () => {
    const cube = makeIdentityCube(17);
    expect(cube.size).toBe(17);
    expect(cube.data.length).toBe(17 * 17 * 17 * 3);
  });

  test("size < 2 throws", () => {
    expect(() => makeIdentityCube(1)).toThrow();
    expect(() => makeIdentityCube(0)).toThrow();
  });
});

describe("makeIdentityCube — diagonal byte-identity", () => {
  test("diagonal samples lie within float32 tolerance of input", () => {
    const cube = makeIdentityCube();
    expect(diagonalMaxDelta(cube)).toBeLessThan(1e-6);
  });

  test("corners are exact 0 and 1", () => {
    const cube = makeIdentityCube();
    const size = cube.size;
    // (0,0,0) corner — first triple
    expect(cube.data[0]).toBeCloseTo(0, 6);
    expect(cube.data[1]).toBeCloseTo(0, 6);
    expect(cube.data[2]).toBeCloseTo(0, 6);
    // (size-1, size-1, size-1) corner — last triple
    const last = (size * size * size - 1) * 3;
    expect(cube.data[last + 0]).toBeCloseTo(1, 6);
    expect(cube.data[last + 1]).toBeCloseTo(1, 6);
    expect(cube.data[last + 2]).toBeCloseTo(1, 6);
  });

  test("R varies fastest in linear index", () => {
    const cube = makeIdentityCube(5);
    // index (1,0,0): r=1/4, g=0, b=0
    const idxR1 = (0 * 5 * 5 + 0 * 5 + 1) * 3;
    expect(cube.data[idxR1 + 0]).toBeCloseTo(0.25, 6);
    expect(cube.data[idxR1 + 1]).toBeCloseTo(0, 6);
    expect(cube.data[idxR1 + 2]).toBeCloseTo(0, 6);

    // index (0,1,0): r=0, g=1/4, b=0
    const idxG1 = (0 * 5 * 5 + 1 * 5 + 0) * 3;
    expect(cube.data[idxG1 + 0]).toBeCloseTo(0, 6);
    expect(cube.data[idxG1 + 1]).toBeCloseTo(0.25, 6);
    expect(cube.data[idxG1 + 2]).toBeCloseTo(0, 6);

    // index (0,0,1): r=0, g=0, b=1/4
    const idxB1 = (1 * 5 * 5 + 0 * 5 + 0) * 3;
    expect(cube.data[idxB1 + 0]).toBeCloseTo(0, 6);
    expect(cube.data[idxB1 + 1]).toBeCloseTo(0, 6);
    expect(cube.data[idxB1 + 2]).toBeCloseTo(0.25, 6);
  });
});

describe("serialize → parse round trip", () => {
  test("identity cube round-trips with max delta < 1e-5", () => {
    const original = makeIdentityCube();
    const text = serializeCreativeCubeToText(original, {
      title: "Filmtone Identity Test",
      precision: 6,
    });
    const parsed = parseCube(text);
    expect(parsed.size).toBe(original.size);
    expect(parsed.title).toBe("Filmtone Identity Test");

    // parseCube produces RGBA quads; original is RGB triples.
    let maxDelta = 0;
    const total = original.size * original.size * original.size;
    for (let i = 0; i < total; i++) {
      for (let c = 0; c < 3; c++) {
        const a = original.data[i * 3 + c];
        const b = parsed.data[i * 4 + c];
        const d = Math.abs(a - b);
        if (d > maxDelta) maxDelta = d;
      }
    }
    expect(maxDelta).toBeLessThan(1e-5);
  });

  test("non-identity cube round-trips", () => {
    const cube = makeCreativeCube({
      params: { ...BAKE_COLOR_IDENTITY, exposure: 0.3, contrast: 1.2 },
    });
    const text = serializeCreativeCubeToText(cube, {
      title: "Round Trip Test",
    });
    const parsed = parseCube(text);
    let maxDelta = 0;
    const total = cube.size * cube.size * cube.size;
    for (let i = 0; i < total; i++) {
      for (let c = 0; c < 3; c++) {
        const a = cube.data[i * 3 + c];
        const b = parsed.data[i * 4 + c];
        const d = Math.abs(a - b);
        if (d > maxDelta) maxDelta = d;
      }
    }
    expect(maxDelta).toBeLessThan(1e-5);
  });
});

describe("serializeCreativeCubeToText — header invariants", () => {
  test("emits TITLE / LUT_3D_SIZE / DOMAIN_MIN / DOMAIN_MAX", () => {
    const cube = makeIdentityCube(5);
    const text = serializeCreativeCubeToText(cube, { title: "Header Check" });
    expect(text).toContain('TITLE "Header Check"');
    expect(text).toContain("LUT_3D_SIZE 5");
    expect(text).toContain("DOMAIN_MIN 0.0 0.0 0.0");
    expect(text).toContain("DOMAIN_MAX 1.0 1.0 1.0");
  });

  test("emits comments with `# ` prefix", () => {
    const cube = makeIdentityCube(3);
    const text = serializeCreativeCubeToText(cube, {
      title: "Comment Check",
      comments: ["pack=test", "rev=0"],
    });
    expect(text).toContain("# pack=test");
    expect(text).toContain("# rev=0");
  });
});
