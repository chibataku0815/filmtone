// Derived-uniform helper for the Detail Softness render pass (Phase 5-B).
// Single source of truth shared across macOS native, iOS export, WebGPU,
// and WebGL renderers so derived units stay in lockstep.
//
// Algorithm shape: amplitude-gated bilateral detail-layer attenuation.
//   1. Sample a ring of 8 neighbours at `kernelRadiusPx` around the
//      center pixel (4 cardinal + 4 diagonal, all on the same circle).
//   2. Build a range-weighted (bilateral) local reference using a
//      Gaussian over luma distance with width `rangeSigma`. Taps that
//      lie on the other side of a luma step receive near-zero weight,
//      so the reference stays near the center on edges instead of
//      averaging across them.
//   3. `detail = center - reference`. The detail layer carries
//      micro-contrast / digital acutance / sharpening halos, not the
//      large step itself (those were excluded by the bilateral weights).
//   4. Apply a soft amplitude gate so any residual high-amplitude
//      detail (transition zones near edges, fine print, contour lines)
//      is released and passes through unattenuated:
//        gate = 1 - smoothstep(detailAmplitudeLo, detailAmplitudeHi, |detailLuma|)
//   5. Split detail into luma + chroma components and attenuate them by
//      `effective * gate * highlightWeight` and the chroma fraction
//      `chromaAttenScale`. Final pixel:
//        center - detailLumaVec * lumaAtten - detailChroma * chromaAtten
//
// This is *not* a defocus blur: large step edges are preserved by both
// the bilateral reference and the amplitude gate. It is digital
// acutance / micro-contrast relief, which is what `detailSoftness` is
// supposed to model.

export const DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.65;

const DETAIL_SOFTNESS_KERNEL_RADIUS_MIN = 1.0;
const DETAIL_SOFTNESS_KERNEL_RADIUS_MAX = 2.5;
const DETAIL_SOFTNESS_RANGE_SIGMA = 0.07;
const DETAIL_SOFTNESS_DETAIL_AMPLITUDE_LO = 0.0;
const DETAIL_SOFTNESS_DETAIL_AMPLITUDE_HI = 0.05;
const DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE = 0.7;
const DETAIL_SOFTNESS_HIGHLIGHT_BIAS = 1.18;

export interface DetailSoftnessUniforms {
  effectiveDetailSoftness: number;
  kernelRadiusPx: number;
  rangeSigma: number;
  detailAmplitudeLo: number;
  detailAmplitudeHi: number;
  chromaAttenScale: number;
  highlightBias: number;
}

export interface DetailSoftnessOptions {
  sourceDetailBias?: number;
}

export function deriveDetailSoftnessUniforms(
  detailSoftness: number,
  opts: DetailSoftnessOptions = {},
): DetailSoftnessUniforms {
  const bias = opts.sourceDetailBias ?? 0;
  const combined = detailSoftness + bias;
  const effective = Math.max(
    0,
    Math.min(DETAIL_SOFTNESS_EFFECTIVE_MAX, combined),
  );
  const t = effective / DETAIL_SOFTNESS_EFFECTIVE_MAX;
  const kernelRadiusPx =
    DETAIL_SOFTNESS_KERNEL_RADIUS_MIN +
    t * (DETAIL_SOFTNESS_KERNEL_RADIUS_MAX - DETAIL_SOFTNESS_KERNEL_RADIUS_MIN);
  return {
    effectiveDetailSoftness: effective,
    kernelRadiusPx,
    rangeSigma: DETAIL_SOFTNESS_RANGE_SIGMA,
    detailAmplitudeLo: DETAIL_SOFTNESS_DETAIL_AMPLITUDE_LO,
    detailAmplitudeHi: DETAIL_SOFTNESS_DETAIL_AMPLITUDE_HI,
    chromaAttenScale: DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE,
    highlightBias: DETAIL_SOFTNESS_HIGHLIGHT_BIAS,
  };
}
