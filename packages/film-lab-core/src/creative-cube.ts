/**
 * 3D LUT cube grid walker. Generates a `size³` cube by sampling the input
 * domain `[0, 1]³` on a uniform grid and running each sample through a
 * pure transform function (typically `bakeColorOnly`).
 *
 * Layout matches the Adobe `.cube` standard and `cube-parser.ts`:
 *   index `i = b * size² + g * size + r` for grid coordinate `(r, g, b)`,
 *   i.e. R varies fastest, then G, then B.
 */

import {
  bakeColorOnly,
  BAKE_COLOR_IDENTITY,
  type BakeColorParams,
  type RGB,
} from "./bake-color-only";

export const CREATIVE_CUBE_DEFAULT_SIZE = 33 as const;

export interface CreativeCube {
  size: number;
  /** RGB triples packed `[r0, g0, b0, r1, g1, b1, ...]`, length = `size³ × 3`. */
  data: Float32Array;
}

/**
 * Run the baker over a `size × size × size` grid in Rec.709 [0, 1] and
 * return the resulting cube. R varies fastest in the output index.
 *
 * `transform` defaults to `bakeColorOnly` so the baker is the conventional
 * call-site; pass an alternate function only for tests / experiments.
 */
export function makeCreativeCube(input: {
  params: BakeColorParams;
  size?: number;
  transform?: (rgb: RGB, params: BakeColorParams) => RGB;
}): CreativeCube {
  const size = input.size ?? CREATIVE_CUBE_DEFAULT_SIZE;
  if (!Number.isInteger(size) || size < 2) {
    throw new RangeError(`Cube size must be an integer ≥ 2, got ${size}`);
  }
  const transform = input.transform ?? bakeColorOnly;
  const data = new Float32Array(size * size * size * 3);
  const denom = size - 1;

  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const out = transform({ r, g, b }, input.params);
        const idx = (bi * size * size + gi * size + ri) * 3;
        data[idx + 0] = out.r;
        data[idx + 1] = out.g;
        data[idx + 2] = out.b;
      }
    }
  }
  return { size, data };
}

/** Convenience: identity cube (no transform). Used for Phase 1 placeholders. */
export function makeIdentityCube(size: number = CREATIVE_CUBE_DEFAULT_SIZE): CreativeCube {
  return makeCreativeCube({ params: BAKE_COLOR_IDENTITY, size });
}

/**
 * Maximum |output - input| along the grid diagonal (R = G = B). Cheap
 * pre-screen for "is this cube near identity?" used by tests and the
 * orchestrator's Lipschitz pre-check.
 */
export function diagonalMaxDelta(cube: CreativeCube): number {
  const { size, data } = cube;
  const denom = size - 1;
  let max = 0;
  for (let i = 0; i < size; i++) {
    const t = i / denom;
    const idx = (i * size * size + i * size + i) * 3;
    const dr = Math.abs(data[idx + 0] - t);
    const dg = Math.abs(data[idx + 1] - t);
    const db = Math.abs(data[idx + 2] - t);
    if (dr > max) max = dr;
    if (dg > max) max = dg;
    if (db > max) max = db;
  }
  return max;
}
