import type { CreativeCube } from "./creative-cube";
import type { RGB } from "./bake-color-only";

export const CREATIVE_PACK_01_URBAN_DENSITY_TRANSFORM =
  "filmtone-urban-density-v1" as const;

export type CreativePack01SourceTransform =
  typeof CREATIVE_PACK_01_URBAN_DENSITY_TRANSFORM;

function clamp01(x: number): number {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}

function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function smoothstep(edge0: number, edge1: number, x: number): number {
  const t = clamp01((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}

function luma(rgb: RGB): number {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}

function hueDegrees(rgb: RGB): number {
  const maxChannel = Math.max(rgb.r, rgb.g, rgb.b);
  const minChannel = Math.min(rgb.r, rgb.g, rgb.b);
  const chroma = maxChannel - minChannel;
  if (chroma < 1e-6) return 0;

  let hue: number;
  if (maxChannel === rgb.r) {
    hue = ((rgb.g - rgb.b) / chroma) % 6;
  } else if (maxChannel === rgb.g) {
    hue = (rgb.b - rgb.r) / chroma + 2;
  } else {
    hue = (rgb.r - rgb.g) / chroma + 4;
  }

  const degrees = hue * 60;
  return degrees < 0 ? degrees + 360 : degrees;
}

function hueWeight(hue: number, center: number, width: number): number {
  const delta = Math.abs(((hue - center + 540) % 360) - 180);
  return 1 - smoothstep(width * 0.35, width, delta);
}

function scaleToLuma(rgb: RGB, targetLuma: number): RGB {
  const currentLuma = luma(rgb);
  if (currentLuma < 1e-5) {
    return { r: targetLuma, g: targetLuma, b: targetLuma };
  }

  const scale = targetLuma / currentLuma;
  return {
    r: rgb.r * scale,
    g: rgb.g * scale,
    b: rgb.b * scale,
  };
}

function blendRgb(a: RGB, b: RGB, t: number): RGB {
  return {
    r: mix(a.r, b.r, t),
    g: mix(a.g, b.g, t),
    b: mix(a.b, b.b, t),
  };
}

function clampRgb(rgb: RGB): RGB {
  return {
    r: clamp01(rgb.r),
    g: clamp01(rgb.g),
    b: clamp01(rgb.b),
  };
}

function transformUrbanDensitySample(input: RGB, source: RGB): RGB {
  const inputLuma = luma(input);
  const sourceLuma = luma(source);
  const maxInput = Math.max(input.r, input.g, input.b);
  const minInput = Math.min(input.r, input.g, input.b);
  const inputChroma = maxInput - minInput;
  const hue = hueDegrees(input);
  const saturatedWeight = smoothstep(0.05, 0.22, inputChroma);
  const neutralWeight = 1 - smoothstep(0.025, 0.16, inputChroma);

  const authoredLuma = clamp01(0.01 + 0.982 * Math.pow(inputLuma, 1.32));
  let targetLuma = mix(sourceLuma, authoredLuma, 0.56);
  targetLuma +=
    0.008 *
    smoothstep(0.015, 0.08, inputLuma) *
    (1 - smoothstep(0.12, 0.23, inputLuma));
  targetLuma = clamp01(targetLuma);

  let out = scaleToLuma(source, targetLuma);
  const highlightProtect = 1 - smoothstep(0.76, 0.98, inputLuma);
  const neutralCool =
    neutralWeight * highlightProtect * (0.45 + 0.55 * smoothstep(0.1, 0.72, inputLuma));
  out = {
    r: out.r * (1 - 0.125 * neutralCool),
    g: out.g * (1 + 0.025 * neutralCool),
    b: out.b * (1 + 0.18 * neutralCool),
  };

  const redWeight =
    Math.max(hueWeight(hue, 0, 34), hueWeight(hue, 360, 34)) * saturatedWeight;
  const skinWeight = hueWeight(hue, 31, 35) * saturatedWeight * smoothstep(0.24, 0.72, inputLuma);
  const yellowWeight = hueWeight(hue, 55, 42) * saturatedWeight;
  const foliageWeight = hueWeight(hue, 122, 52) * saturatedWeight;
  const skyWeight =
    Math.max(hueWeight(hue, 202, 62), hueWeight(hue, 225, 50)) * saturatedWeight;

  if (redWeight > 0) {
    out = blendRgb(
      out,
      {
        r: clamp01(Math.max(out.r, targetLuma * 3.95)),
        g: clamp01(Math.max(out.g, targetLuma * 0.24 + 0.008)),
        b: clamp01(Math.max(out.b, targetLuma * 0.16 + 0.006)),
      },
      0.42 * redWeight,
    );
  }

  if (skinWeight > 0) {
    out = blendRgb(
      out,
      {
        r: clamp01(targetLuma * 1.62 + 0.035),
        g: clamp01(targetLuma * 0.94 + 0.015),
        b: clamp01(targetLuma * 0.5 + 0.045),
      },
      0.34 * skinWeight,
    );
  }

  if (yellowWeight > 0) {
    out = blendRgb(
      out,
      {
        r: clamp01(targetLuma * 1.42 + 0.03),
        g: clamp01(targetLuma * 1.05 + 0.015),
        b: clamp01(targetLuma * 0.34 + 0.035),
      },
      0.34 * yellowWeight,
    );
  }

  if (foliageWeight > 0) {
    out = blendRgb(
      out,
      {
        r: clamp01(targetLuma * 0.58 + 0.018),
        g: clamp01(targetLuma * 1.2 + 0.02),
        b: clamp01(targetLuma * 0.55 + 0.018),
      },
      0.32 * foliageWeight,
    );
  }

  if (skyWeight > 0) {
    out = blendRgb(
      out,
      {
        r: clamp01(targetLuma * 0.2 + 0.018),
        g: clamp01(targetLuma * 1.02 + 0.018),
        b: clamp01(targetLuma * 1.82 + 0.025),
      },
      0.28 * skyWeight,
    );
  }

  const outputLuma = luma(out);
  const outputChroma = Math.max(out.r, out.g, out.b) - Math.min(out.r, out.g, out.b);
  const chromaLimiter = smoothstep(0.48, 0.82, outputChroma) * smoothstep(0.06, 0.38, outputLuma) * 0.1;
  return clampRgb({
    r: mix(out.r, outputLuma, chromaLimiter),
    g: mix(out.g, outputLuma, chromaLimiter),
    b: mix(out.b, outputLuma, chromaLimiter),
  });
}

export function applyFilmtoneUrbanDensityTransform(sourceCube: CreativeCube): CreativeCube {
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
        const out = transformUrbanDensitySample(
          { r, g, b },
          {
            r: sourceCube.data[idx + 0],
            g: sourceCube.data[idx + 1],
            b: sourceCube.data[idx + 2],
          },
        );
        data[idx + 0] = out.r;
        data[idx + 1] = out.g;
        data[idx + 2] = out.b;
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
    case CREATIVE_PACK_01_URBAN_DENSITY_TRANSFORM:
      return applyFilmtoneUrbanDensityTransform(sourceCube);
  }
}
