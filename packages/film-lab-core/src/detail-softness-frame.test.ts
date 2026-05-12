import { describe, expect, test } from "bun:test";
import { deriveDetailSoftnessUniforms } from "./detail-softness";

// CPU mirror of the Detail Softness shader (Phase 5-B). Used to assert
// the *frame-level* behavior of the algorithm without GPU access:
//
//   1. Identity at slider 0.
//   2. Non-zero softening on flat-noise / micro-detail regions.
//   3. Step-edge amplitude preserved across the bilateral pass — this
//      is the "non-blur" metric. A low-pass blur would compress the
//      step; an amplitude-gated bilateral keeps it intact.
//
// Sampling is nearest-neighbour with clamp-to-edge, which approximates
// the shader's LINEAR / clampedToExtent path well enough for behavior
// assertions. Numerical tolerances are intentionally loose so the test
// stays stable under future tuning of effectiveMax / radius / sigma
// inside the documented bounds.

type RGB = [number, number, number];
type Image = { width: number; height: number; pixels: RGB[] };

const LUMA_W: RGB = [0.2126, 0.7152, 0.0722];

function luma(rgb: RGB): number {
  return rgb[0] * LUMA_W[0] + rgb[1] * LUMA_W[1] + rgb[2] * LUMA_W[2];
}

function smoothstep(lo: number, hi: number, x: number): number {
  const t = Math.max(0, Math.min(1, (x - lo) / (hi - lo)));
  return t * t * (3 - 2 * t);
}

function mix(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

function clampInt(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

function sample(img: Image, fx: number, fy: number): RGB {
  const ix = clampInt(Math.round(fx), 0, img.width - 1);
  const iy = clampInt(Math.round(fy), 0, img.height - 1);
  return img.pixels[iy * img.width + ix]!;
}

function applyDetailSoftness(input: Image, slider: number): Image {
  const u = deriveDetailSoftnessUniforms(slider);
  const out: RGB[] = new Array(input.pixels.length);
  if (u.effectiveDetailSoftness < 0.0001) {
    for (let i = 0; i < input.pixels.length; i += 1) {
      const p = input.pixels[i]!;
      out[i] = [p[0], p[1], p[2]];
    }
    return { width: input.width, height: input.height, pixels: out };
  }

  const r = Math.max(u.kernelRadiusPx, 0.0001);
  const rd = r * 0.70710678;
  const sigma2 = Math.max(u.rangeSigma * u.rangeSigma, 1e-6);
  const offsets: [number, number][] = [
    [r, 0],
    [-r, 0],
    [0, r],
    [0, -r],
    [rd, rd],
    [-rd, rd],
    [rd, -rd],
    [-rd, -rd],
  ];

  for (let y = 0; y < input.height; y += 1) {
    for (let x = 0; x < input.width; x += 1) {
      const center = input.pixels[y * input.width + x]!;
      const lumaC = luma(center);

      let sumR = center[0];
      let sumG = center[1];
      let sumB = center[2];
      let sumW = 1.0;
      for (const [ox, oy] of offsets) {
        const tap = sample(input, x + ox, y + oy);
        const dL = luma(tap) - lumaC;
        const w = Math.exp(-(dL * dL) / sigma2);
        sumR += tap[0] * w;
        sumG += tap[1] * w;
        sumB += tap[2] * w;
        sumW += w;
      }
      const refR = sumR / sumW;
      const refG = sumG / sumW;
      const refB = sumB / sumW;
      const detailR = center[0] - refR;
      const detailG = center[1] - refG;
      const detailB = center[2] - refB;
      const detailLuma =
        detailR * LUMA_W[0] + detailG * LUMA_W[1] + detailB * LUMA_W[2];
      const dlvR = detailLuma * LUMA_W[0];
      const dlvG = detailLuma * LUMA_W[1];
      const dlvB = detailLuma * LUMA_W[2];
      const dcR = detailR - dlvR;
      const dcG = detailG - dlvG;
      const dcB = detailB - dlvB;

      const detailMag = Math.abs(detailLuma);
      const gate =
        1.0 - smoothstep(u.detailAmplitudeLo, u.detailAmplitudeHi, detailMag);
      const highlightWeight = mix(
        1.0,
        u.highlightBias,
        smoothstep(0.6, 0.9, lumaC),
      );
      const lumaAtten = u.effectiveDetailSoftness * gate * highlightWeight;
      const chromaAtten = lumaAtten * u.chromaAttenScale;

      out[y * input.width + x] = [
        center[0] - dlvR * lumaAtten - dcR * chromaAtten,
        center[1] - dlvG * lumaAtten - dcG * chromaAtten,
        center[2] - dlvB * lumaAtten - dcB * chromaAtten,
      ];
    }
  }
  return { width: input.width, height: input.height, pixels: out };
}

function lcg(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s, 1664525) + 1013904223) | 0;
    return (s >>> 0) / 0xffffffff - 0.5;
  };
}

// 64×32 synthetic frame:
//   - Left half  (x < 32): flat base luma 0.35 with high-frequency
//     micro-detail (±0.01 sinusoid at 2-pixel period — digital
//     acutance simulation).
//   - Right half (x ≥ 32): flat base luma 0.70 with deterministic
//     ±0.015 noise (sensor-noise simulation).
//   - Sharp luma step at x=32. Mean(right) − Mean(left) ≈ 0.35.
function buildSyntheticImage(): Image {
  const W = 64;
  const H = 32;
  const rand = lcg(0xc0ffee);
  const pixels: RGB[] = [];
  for (let y = 0; y < H; y += 1) {
    for (let x = 0; x < W; x += 1) {
      let v: number;
      if (x < 32) {
        const sign = x % 2 === 0 ? 1 : -1;
        v = 0.35 + sign * 0.01;
      } else {
        v = 0.7 + rand() * 0.03;
      }
      pixels.push([v, v, v]);
    }
  }
  return { width: W, height: H, pixels };
}

function meanLumaDelta(
  a: Image,
  b: Image,
  xLo: number,
  xHi: number,
  yLo: number,
  yHi: number,
): number {
  let sum = 0;
  let count = 0;
  for (let y = yLo; y < yHi; y += 1) {
    for (let x = xLo; x < xHi; x += 1) {
      const pa = a.pixels[y * a.width + x]!;
      const pb = b.pixels[y * b.width + x]!;
      sum += Math.abs(luma(pa) - luma(pb));
      count += 1;
    }
  }
  return sum / count;
}

function meanLuma(
  img: Image,
  xLo: number,
  xHi: number,
  yLo: number,
  yHi: number,
): number {
  let sum = 0;
  let count = 0;
  for (let y = yLo; y < yHi; y += 1) {
    for (let x = xLo; x < xHi; x += 1) {
      sum += luma(img.pixels[y * img.width + x]!);
      count += 1;
    }
  }
  return sum / count;
}

describe("detail softness frame-level behavior", () => {
  const input = buildSyntheticImage();

  test("identity at detailSoftness = 0", () => {
    const out = applyDetailSoftness(input, 0);
    for (let i = 0; i < input.pixels.length; i += 1) {
      const a = input.pixels[i]!;
      const b = out.pixels[i]!;
      expect(b[0]).toBeCloseTo(a[0], 10);
      expect(b[1]).toBeCloseTo(a[1], 10);
      expect(b[2]).toBeCloseTo(a[2], 10);
    }
  });

  test("noise region softens at slider max", () => {
    const out = applyDetailSoftness(input, 1.0);
    // Right block flat-noise interior, away from the edge column and
    // image borders so the ring samples stay inside the right block.
    const noiseDelta = meanLumaDelta(input, out, 40, 60, 4, 28);
    expect(noiseDelta).toBeGreaterThan(0.001);
  });

  test("micro-detail softens at slider max", () => {
    const out = applyDetailSoftness(input, 1.0);
    // Left block interior. Sinusoid ±0.01 amplitude gives ≈0.006 delta
    // at effective = 0.65.
    const microDelta = meanLumaDelta(input, out, 4, 28, 4, 28);
    expect(microDelta).toBeGreaterThan(0.001);
  });

  test("step-edge amplitude preserved at slider max (non-blur metric)", () => {
    const out = applyDetailSoftness(input, 1.0);
    // 3-pixel strip on either side of the step (x=29..31 vs x=32..34),
    // avoiding the top/bottom borders so the ring stays inside the
    // frame. The bilateral reference must keep cross-side luma from
    // bleeding into the local average, which preserves the step.
    const meanLeftIn = meanLuma(input, 29, 32, 8, 24);
    const meanRightIn = meanLuma(input, 32, 35, 8, 24);
    const meanLeftOut = meanLuma(out, 29, 32, 8, 24);
    const meanRightOut = meanLuma(out, 32, 35, 8, 24);
    const stepIn = meanRightIn - meanLeftIn;
    const stepOut = meanRightOut - meanLeftOut;
    // A low-pass blur of radius ≈2.5 would collapse this step by
    // ~10-30%. Bilateral + amplitude gate must keep it within 3%.
    expect(stepOut).toBeGreaterThan(stepIn * 0.97);
  });
});
