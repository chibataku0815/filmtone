import { describe, expect, test } from "bun:test";
import {
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
} from "./bake-color-only";
import { CREATIVE_PACK_01_LOOKS } from "./creative-pack-01";

describe("Creative LUT Pack 01 — runtime color neutralization", () => {
  test("every Look neutralizes baked color ops and v2 split-tone strengths", () => {
    expect(CREATIVE_PACK_01_LOOKS.length).toBe(2);

    for (const look of CREATIVE_PACK_01_LOOKS) {
      for (const key of BAKE_COLOR_PARAM_KEYS) {
        expect(look.paramOverrides[key]).toBe(BAKE_COLOR_IDENTITY[key]);
      }
      expect(look.paramOverrides.shadowTone).toBe(0);
      expect(look.paramOverrides.highlightTone).toBe(0);
    }
  });
});
