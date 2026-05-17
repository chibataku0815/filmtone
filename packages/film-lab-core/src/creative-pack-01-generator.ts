import type { CreativeCube } from "./creative-cube";

export const CREATIVE_PACK_01_STONE_TRANSFORM =
  "filmtone-stone-dlogm-palermo-display-v2" as const;
export const CREATIVE_PACK_01_URBAN_TRANSFORM =
  "filmtone-urban-palermo-green-density-v1" as const;
export const CREATIVE_PACK_01_REC709_SAFE_TRANSFORM =
  "filmtone-rec709-safe-color-v1" as const;

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

function luma(r: number, g: number, b: number): number {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function channelChroma(rgb: [number, number, number]): number {
  return Math.max(rgb[0], rgb[1], rgb[2]) - Math.min(rgb[0], rgb[1], rgb[2]);
}

function compressRgbDistanceFromNeutral(
  rgb: [number, number, number],
  threshold: number,
  limit: number,
): [number, number, number] {
  const y = luma(rgb[0], rgb[1], rgb[2]);
  const distances = [rgb[0] - y, rgb[1] - y, rgb[2] - y] as const;
  const maxDistance = Math.max(
    Math.abs(distances[0]),
    Math.abs(distances[1]),
    Math.abs(distances[2]),
  );
  if (maxDistance <= threshold || maxDistance <= 1e-8) {
    return rgb;
  }

  const t = Math.min(threshold, limit);
  const excess = maxDistance - t;
  const compressed = t + excess / (1 + excess / Math.max(1e-4, limit - t));
  const scale = Math.min(1, compressed / maxDistance);
  return [
    clamp01(y + distances[0] * scale),
    clamp01(y + distances[1] * scale),
    clamp01(y + distances[2] * scale),
  ];
}

function preserveInputLuma(
  input: [number, number, number],
  output: [number, number, number],
  amount: number,
): [number, number, number] {
  if (amount <= 0) return output;
  const inputY = luma(input[0], input[1], input[2]);
  const outputY = luma(output[0], output[1], output[2]);
  const targetY = mix(outputY, inputY, clamp01(amount));
  const delta = targetY - outputY;
  return [
    clamp01(output[0] + delta),
    clamp01(output[1] + delta),
    clamp01(output[2] + delta),
  ];
}

function rec709Decode(encoded: number): number {
  const v = clamp01(encoded);
  if (v < 0.081) return v / 4.5;
  return Math.pow((v + 0.099) / 1.099, 1 / 0.45);
}

function inverseFilmtoneSdrShoulder(shouldered: number): number {
  const y = clamp01(shouldered);
  const exposed = y <= 0.18 ? y : (0.9244 * y) / (1 - 0.42 * y);
  return exposed / 1.18;
}

function dlogMEncode(linear: number): number {
  const cut = 0.1113510236;
  const linearOffset = 0.000000012;
  const linearSlope = 7.5547639793;
  const logA = 1.538947658;
  const logB = -1.8459129538;
  const logC = 0.0165823994;
  const logD = 0.3103580873;
  const linearCut = (cut - linearOffset) / linearSlope;
  const value = Math.max(0, linear);
  if (value <= linearCut) {
    return clamp01(value * linearSlope + linearOffset);
  }
  return clamp01((Math.log10(value * logD + logC) - logB) / logA);
}

function rec709DisplayToDlogMCode(
  r: number,
  g: number,
  b: number,
): [number, number, number] {
  const rr = inverseFilmtoneSdrShoulder(rec709Decode(r));
  const rg = inverseFilmtoneSdrShoulder(rec709Decode(g));
  const rb = inverseFilmtoneSdrShoulder(rec709Decode(b));
  const dR = 0.7134498128 * rr + 0.271008975 * rg + 0.0155412122 * rb;
  const dG = 0.0489651885 * rr + 0.8951909448 * rg + 0.0558438666 * rb;
  const dB = 0.0406336115 * rr + 0.1954332565 * rg + 0.763933132 * rb;
  return [dlogMEncode(dR), dlogMEncode(dG), dlogMEncode(dB)];
}

function sampleCube(sourceCube: CreativeCube, r: number, g: number, b: number): [number, number, number] {
  const n = sourceCube.size - 1;
  const x = clamp01(r) * n;
  const y = clamp01(g) * n;
  const z = clamp01(b) * n;
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const z0 = Math.floor(z);
  const x1 = Math.min(n, x0 + 1);
  const y1 = Math.min(n, y0 + 1);
  const z1 = Math.min(n, z0 + 1);
  const fx = x - x0;
  const fy = y - y0;
  const fz = z - z0;
  let outR = 0;
  let outG = 0;
  let outB = 0;

  for (let dz = 0; dz < 2; dz++) {
    for (let dy = 0; dy < 2; dy++) {
      for (let dx = 0; dx < 2; dx++) {
        const ix = dx ? x1 : x0;
        const iy = dy ? y1 : y0;
        const iz = dz ? z1 : z0;
        const weight =
          (dx ? fx : 1 - fx) *
          (dy ? fy : 1 - fy) *
          (dz ? fz : 1 - fz);
        const index = (iz * sourceCube.size * sourceCube.size + iy * sourceCube.size + ix) * 3;
        outR += sourceCube.data[index + 0] * weight;
        outG += sourceCube.data[index + 1] * weight;
        outB += sourceCube.data[index + 2] * weight;
      }
    }
  }

  return [outR, outG, outB];
}

function protectShadowFloor(
  input: [number, number, number],
  output: [number, number, number],
): [number, number, number] {
  const inputLuma = luma(input[0], input[1], input[2]);
  const outputLuma = luma(output[0], output[1], output[2]);
  if (inputLuma >= 0.26 || outputLuma <= 0.0001) return output;

  const shadowMask = 1 - smoothstep(0.08, 0.26, inputLuma);
  const maxLift = 0.004 + inputLuma * (1.05 + 0.18 * (1 - shadowMask));
  if (outputLuma <= maxLift) return output;

  const scale = mix(1, maxLift / outputLuma, shadowMask);
  return [
    clamp01(output[0] * scale),
    clamp01(output[1] * scale),
    clamp01(output[2] * scale),
  ];
}

function dominantGreenMask(r: number, g: number, b: number, inputLuma: number): number {
  const dominance = g - Math.max(r, b);
  const lumaGate = smoothstep(0.12, 0.32, inputLuma) * (1 - smoothstep(0.68, 0.9, inputLuma));
  return smoothstep(0.035, 0.22, dominance) * lumaGate;
}

function cyanSkyMask(r: number, g: number, b: number, inputLuma: number): number {
  const blueDominance = b - r;
  const cyanBody = Math.min(b - g * 0.72, g - r * 0.58);
  const lumaGate = smoothstep(0.22, 0.42, inputLuma) * (1 - smoothstep(0.88, 1.0, inputLuma));
  return smoothstep(0.08, 0.36, blueDominance) * smoothstep(0.06, 0.28, cyanBody) * lumaGate;
}

function warmSkinMask(r: number, g: number, b: number, inputLuma: number): number {
  const warmOrder =
    smoothstep(0.035, 0.18, r - g) *
    smoothstep(0.025, 0.16, g - b);
  const lumaGate = smoothstep(0.20, 0.42, inputLuma) * (1 - smoothstep(0.76, 0.94, inputLuma));
  const saturationGuard = 1 - smoothstep(0.52, 0.9, Math.max(r, g, b) - Math.min(r, g, b));
  return warmOrder * lumaGate * saturationGuard;
}

function saturatedDisplayRiskMask(
  input: [number, number, number],
  output: [number, number, number],
): number {
  const inputLuma = luma(input[0], input[1], input[2]);
  const inputChroma = channelChroma(input);
  const outputChroma = channelChroma(output);
  const highSat =
    smoothstep(0.28, 0.72, inputChroma) *
    smoothstep(0.22, 0.60, outputChroma);
  const highKey = smoothstep(0.58, 0.92, inputLuma);
  const midKey = smoothstep(0.18, 0.42, inputLuma) * (1 - smoothstep(0.80, 0.98, inputLuma));
  return clamp01(highSat * (0.45 + 0.55 * highKey + 0.20 * midKey));
}

function rec709SafeLookOutput(
  slug: string,
  input: [number, number, number],
  output: [number, number, number],
): [number, number, number] {
  const inputLuma = luma(input[0], input[1], input[2]);
  const risk = saturatedDisplayRiskMask(input, output);
  const skin = warmSkinMask(input[0], input[1], input[2], inputLuma);
  const sky = cyanSkyMask(input[0], input[1], input[2], inputLuma);
  const green = dominantGreenMask(input[0], input[1], input[2], inputLuma);
  const neutral = 1 - smoothstep(0.035, 0.18, channelChroma(input));

  let threshold = 0.30;
  let limit = 0.50;
  let compressionMix = risk;
  let lumaProtect = risk * 0.18;

  switch (slug) {
    case "filmtone-creative-pack-01-stone":
      threshold = 0.245;
      limit = 0.40;
      compressionMix = clamp01(risk * 0.88 + sky * 0.30 + green * 0.18 - skin * 0.20);
      lumaProtect = clamp01(risk * 0.22 + sky * 0.12);
      break;
    case "filmtone-creative-pack-01-urban":
      threshold = 0.255;
      limit = 0.42;
      compressionMix = clamp01(risk * 0.78 + green * 0.22 + sky * 0.18 - skin * 0.12);
      lumaProtect = clamp01(risk * 0.18);
      break;
    case "filmtone-creative-pack-01-noir":
      threshold = 0.08;
      limit = 0.16;
      compressionMix = clamp01(0.72 + risk * 0.20);
      lumaProtect = clamp01(smoothstep(0.60, 0.95, inputLuma) * 0.16);
      break;
  }

  const compressed = compressRgbDistanceFromNeutral(output, threshold, limit);
  let safe: [number, number, number] = [
    mix(output[0], compressed[0], compressionMix),
    mix(output[1], compressed[1], compressionMix),
    mix(output[2], compressed[2], compressionMix),
  ];

  // Keep ordinary neutrals and skin from drifting toward the protective
  // compression. The safe variant should cure display-referred color failures,
  // not erase the intended photographic color on trustworthy colors.
  const trust = clamp01(neutral * 0.35 + skin * 0.45);
  safe = [
    mix(safe[0], output[0], trust),
    mix(safe[1], output[1], trust),
    mix(safe[2], output[2], trust),
  ];

  safe = preserveInputLuma(input, safe, lumaProtect);
  return [
    clamp01(safe[0]),
    clamp01(safe[1]),
    clamp01(safe[2]),
  ];
}

export function applyRec709SafeCreativePack01Transform(
  cube: CreativeCube,
  slug: string,
): CreativeCube {
  const { size } = cube;
  const data = new Float32Array(cube.data.length);
  const denom = size - 1;

  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const input: [number, number, number] = [r, g, b];
        const output: [number, number, number] = [
          cube.data[idx + 0],
          cube.data[idx + 1],
          cube.data[idx + 2],
        ];
        const safe = rec709SafeLookOutput(slug, input, output);
        data[idx + 0] = safe[0];
        data[idx + 1] = safe[1];
        data[idx + 2] = safe[2];
      }
    }
  }

  return { size, data };
}

/**
 * M3 Stone signature shaping.
 *
 * The Palermo PowerGrade analysis showed that the shippable signal is not the
 * opaque DRX body. It is a set of visible behaviors: warm neutral blue
 * suppression, dense skin, cyan/sky separation, green density, and a print
 * ceiling. This function adds those behaviors as an original Filmtone pass on
 * top of the display-domain Palermo sample rather than copying the vendor LUT
 * endpoint shape.
 */
function applyStonePalermoSignature(
  input: [number, number, number],
  output: [number, number, number],
): [number, number, number] {
  const inputLuma = luma(input[0], input[1], input[2]);
  const inputChroma = Math.max(input[0], input[1], input[2]) - Math.min(input[0], input[1], input[2]);
  const neutralMask =
    (1 - smoothstep(0.025, 0.20, inputChroma)) *
    smoothstep(0.12, 0.42, inputLuma) *
    (1 - smoothstep(0.88, 1.0, inputLuma));
  const skinMask = warmSkinMask(input[0], input[1], input[2], inputLuma);
  const skyMask = cyanSkyMask(input[0], input[1], input[2], inputLuma);
  const greenMask = dominantGreenMask(input[0], input[1], input[2], inputLuma);

  let r = output[0];
  let g = output[1];
  let b = output[2];

  // Palermo-like neutral warmth is primarily a blue suppression move, not a
  // red-gain wash. Keep the magnitude modest so grays stay plausible.
  r *= 1 + 0.012 * neutralMask;
  g *= 1 + 0.004 * neutralMask;
  b *= 1 - 0.055 * neutralMask;

  // Dense skin: restore the red/green-to-blue separation that M2.2 kept too
  // thin, while deliberately stopping short of the vendor LUT's very deep blue
  // collapse.
  r *= 1 + 0.030 * skinMask;
  g *= 1 - 0.030 * skinMask;
  b *= 1 - 0.235 * skinMask;

  // Cyan / sky separation: Palermo strips red hard from sky colors. Filmtone
  // keeps more red than the source LUT but needs a stronger cyan lane than
  // M2.2, otherwise the reference character disappears.
  r *= 1 - 0.46 * skyMask;
  g *= 1 + 0.018 * skyMask;
  b *= 1 + 0.030 * skyMask;

  // Green density without an overall mud wash. This is hue-targeted and
  // luma-gated so low, neutral walls do not get crushed like foliage.
  r *= 1 - 0.050 * greenMask;
  g *= 1 - 0.045 * greenMask;
  b *= 1 - 0.020 * greenMask;

  return [clamp01(r), clamp01(g), clamp01(b)];
}

/**
 * Stone — display-referred adaptation of the DJI D-Log M Palermo source LUT.
 *
 * The source cube is valuable, but its input domain is D-Log M / D-Gamut M.
 * Applying it directly to display-referred Rec.709 was the M1/M2 failure mode:
 * shadows went gray and the result read sleepy. This transform maps each
 * Rec.709 display-domain lattice point back into an approximate D-Log M code
 * value before sampling Palermo, then clamps the result through a black-floor
 * protector. That keeps Palermo's color separation / highlight personality
 * without treating Rec.709 values as Log values.
 */
export function applyStoneDisplayPalermoTransform(sourceCube: CreativeCube): CreativeCube {
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
        const input: [number, number, number] = [r, g, b];
        const sourceInput = rec709DisplayToDlogMCode(r, g, b);
        const palermo = sampleCube(sourceCube, sourceInput[0], sourceInput[1], sourceInput[2]);
        const signedPalermo = applyStonePalermoSignature(input, palermo);
        const safePalermo = protectShadowFloor(input, signedPalermo);
        const inputLuma = luma(r, g, b);
        // M2.2: Stone must be Palermo-primary. Earlier versions mixed the
        // sampled Palermo output back toward identity across the whole lattice,
        // which made the Look technically safe but visually stripped out the
        // source LUT's density and color separation. Keep only a deep-shadow
        // identity blend so the black floor stays anchored; from low-mids up,
        // ship the protected Palermo output directly.
        const strength = smoothstep(0.025, 0.12, inputLuma);

        data[idx + 0] = clamp01(mix(r, safePalermo[0], strength));
        data[idx + 1] = clamp01(mix(g, safePalermo[1], strength));
        data[idx + 2] = clamp01(mix(b, safePalermo[2], strength));
      }
    }
  }

  return { size, data };
}

/**
 * Legacy Stone fingerprint helper retained for older pack-generation
 * experiments. The current product Stone path uses
 * `applyStoneDisplayPalermoTransform`.
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
      return applyStoneDisplayPalermoTransform(sourceCube);
    case CREATIVE_PACK_01_URBAN_TRANSFORM:
      return applyUrbanCoolDensityTransform(sourceCube);
  }
}
