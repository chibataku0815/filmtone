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

export function applyFilmtoneReferenceFingerprintTransform(sourceCube: CreativeCube): CreativeCube {
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

export function applyCreativePack01SourceTransform(
  sourceCube: CreativeCube,
  transformName: CreativePack01SourceTransform,
): CreativeCube {
  switch (transformName) {
    case CREATIVE_PACK_01_STONE_TRANSFORM:
    case CREATIVE_PACK_01_URBAN_TRANSFORM:
      return applyFilmtoneReferenceFingerprintTransform(sourceCube);
  }
}
