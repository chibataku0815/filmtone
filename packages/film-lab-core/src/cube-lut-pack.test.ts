import { describe, expect, test } from "bun:test";
import { parseCube } from "./cube-parser";
import { packCubeLutToFloatRgbaGrid } from "./lut-pack-2d";

describe("packCubeLutToFloatRgbaGrid", () => {
  test("2³ の最小 .cube で r+g*N+N²*b の位置が一致する", () => {
    const text = [
      "TITLE \"tiny\"",
      "LUT_3D_SIZE 2",
      "DOMAIN_MIN 0.0 0.0 0.0",
      "DOMAIN_MAX 1.0 1.0 1.0",
      "0.1 0.0 0.0",
      "0.2 0.0 0.0",
      "0.3 0.0 0.0",
      "0.4 0.0 0.0",
      "0.5 0.0 0.0",
      "0.6 0.0 0.0",
      "0.7 0.0 0.0",
      "0.8 0.0 0.0",
    ].join("\n");

    const lut = parseCube(text);
    const packed = packCubeLutToFloatRgbaGrid(lut);
    expect(packed.size).toBe(2);
    expect(packed.width).toBe(4);
    expect(packed.height).toBe(2);

    const readAt = (r: number, g: number, b: number) => {
      const x = r + g * 2;
      const y = b;
      const o = (y * packed.width + x) * 4;
      return packed.data[o] ?? -1;
    };

    expect(readAt(0, 0, 0)).toBeCloseTo(0.1);
    expect(readAt(1, 0, 0)).toBeCloseTo(0.2);
    expect(readAt(0, 1, 0)).toBeCloseTo(0.3);
    expect(readAt(1, 1, 0)).toBeCloseTo(0.4);
    expect(readAt(0, 0, 1)).toBeCloseTo(0.5);
    expect(readAt(1, 0, 1)).toBeCloseTo(0.6);
    expect(readAt(0, 1, 1)).toBeCloseTo(0.7);
    expect(readAt(1, 1, 1)).toBeCloseTo(0.8);
  });
});
