import type { CreativeCube } from "./creative-cube";

export const CREATIVE_PACK_01_STONE_TRANSFORM =
  "filmtone-stone-palermo-reference-v1" as const;
export const CREATIVE_PACK_01_URBAN_TRANSFORM =
  "filmtone-urban-palermo-green-density-v1" as const;

export type CreativePack01SourceTransform =
  | typeof CREATIVE_PACK_01_STONE_TRANSFORM
  | typeof CREATIVE_PACK_01_URBAN_TRANSFORM;

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

/**
 * Stone — fingerprint-only transform applied to the Palermo Reference source.
 * Intentionally tiny: produces a non-byte-identical cube that stays within
 * 0.006 / channel of source. Stone's role is the faithful Palermo Reference
 * base; per-Look character lives in the bundled cube selection, not here.
 */
export function applyStoneFingerprintTransform(sourceCube: CreativeCube): CreativeCube {
  const { size } = sourceCube;
  const data = new Float32Array(sourceCube.data.length);
  const denom = size - 1;

  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const sourceR = sourceCube.data[idx + 0];
        const sourceG = sourceCube.data[idx + 1];
        const sourceB = sourceCube.data[idx + 2];
        const inputLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        const inputChroma = Math.max(r, g, b) - Math.min(r, g, b);
        const neutralWeight = 1 - smoothstep(0.025, 0.18, inputChroma);
        const shadowWeight = 1 - smoothstep(0.1, 0.42, inputLuma);
        const midWeight =
          smoothstep(0.18, 0.62, inputLuma) * (1 - smoothstep(0.72, 0.95, inputLuma));
        const highlightProtect = 1 - smoothstep(0.76, 0.98, inputLuma);
        const cool = neutralWeight * highlightProtect;

        data[idx + 0] = clamp01(sourceR * (1 - 0.012 * cool) - 0.002 * shadowWeight);
        data[idx + 1] = clamp01(sourceG * (1 + 0.003 * cool * midWeight));
        data[idx + 2] = clamp01(sourceB * (1 + 0.014 * cool * midWeight));
      }
    }
  }

  return { size, data };
}

/**
 * Urban — Filmtone "cool urban density" character applied on top of the
 * Palermo Green Density source. The source already carries Palermo's color
 * density; this transform layers Filmtone's signature urban personality:
 *
 *   - Cool shadow tilt with a slight black-point lift so shadows stay
 *     readable rather than crushed.
 *   - Gray/green concrete cast on neutral midtones (gated by chroma so
 *     saturated colors — red signage, skin — keep their hue).
 *   - Highlights left mostly intact (clean Palermo brights).
 *
 * Magnitudes are tuned so neutrals shift by ~0.02–0.03 / channel — a clearly
 * perceptible change in the everyday photo path that previously read as
 * byte-identical with Reference, while saturated regions remain restrained
 * to avoid the "feels cheap" outcome the user flagged in earlier iterations.
 */
export function applyUrbanCoolDensityTransform(sourceCube: CreativeCube): CreativeCube {
  const { size } = sourceCube;
  const data = new Float32Array(sourceCube.data.length);
  const denom = size - 1;

  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const sourceR = sourceCube.data[idx + 0];
        const sourceG = sourceCube.data[idx + 1];
        const sourceB = sourceCube.data[idx + 2];

        const inputLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        const inputChroma = Math.max(r, g, b) - Math.min(r, g, b);

        const shadowWeight = 1 - smoothstep(0.05, 0.45, inputLuma);
        const midWeight =
          smoothstep(0.18, 0.5, inputLuma) * (1 - smoothstep(0.65, 0.92, inputLuma));
        const highlightWeight = smoothstep(0.78, 0.96, inputLuma);
        const neutralMask = 1 - smoothstep(0.02, 0.22, inputChroma);

        const coolStrength = shadowWeight * 0.120 + midWeight * neutralMask * 0.075;
        const greenCastStrength = midWeight * neutralMask * 0.035;
        const shadowLift = shadowWeight * 0.028;
        const highlightCool = highlightWeight * neutralMask * 0.008;

        const newR =
          sourceR * (1 - coolStrength * 1.05 - highlightCool) + shadowLift * 0.7;
        const newG = sourceG * (1 + greenCastStrength) + shadowLift;
        const newB =
          sourceB * (1 + coolStrength * 1.3 + highlightCool * 0.5) + shadowLift * 1.1;

        data[idx + 0] = clamp01(newR);
        data[idx + 1] = clamp01(newG);
        data[idx + 2] = clamp01(newB);
      }
    }
  }

  return { size, data };
}

export function applyCreativePack01SourceTransform(
  sourceCube: CreativeCube,
  transformName: CreativePack01SourceTransform,
): CreativeCube {
  switch (transformName) {
    case CREATIVE_PACK_01_STONE_TRANSFORM:
      return applyStoneFingerprintTransform(sourceCube);
    case CREATIVE_PACK_01_URBAN_TRANSFORM:
      return applyUrbanCoolDensityTransform(sourceCube);
  }
}
