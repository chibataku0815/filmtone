// Derived-uniform helper for the Detail Softness render pass (Phase 2).
// Single source of truth shared across macOS native, iOS export, WebGPU,
// and WebGL renderers so derived units stay in lockstep.
//
// Algorithm shape: local-reference high-pass attenuation with edge guard
// and luma-vs-chroma separation. See
// `docs/filmtone/detail-softness/archive/2026-05-12-phase-2a-research-charter.md`
// §Algorithm decision.

export const DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.45;

const DETAIL_SOFTNESS_KERNEL_RADIUS_MIN = 0.62;
const DETAIL_SOFTNESS_KERNEL_RADIUS_MAX = 2.0;
const DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE = 0.7;
const DETAIL_SOFTNESS_EDGE_GUARD_LO = 0.04;
const DETAIL_SOFTNESS_EDGE_GUARD_HI = 0.2;
const DETAIL_SOFTNESS_HIGHLIGHT_BIAS = 1.18;

export interface DetailSoftnessUniforms {
  effectiveDetailSoftness: number;
  kernelRadiusPx: number;
  chromaAttenScale: number;
  edgeGuardLo: number;
  edgeGuardHi: number;
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
    chromaAttenScale: DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE,
    edgeGuardLo: DETAIL_SOFTNESS_EDGE_GUARD_LO,
    edgeGuardHi: DETAIL_SOFTNESS_EDGE_GUARD_HI,
    highlightBias: DETAIL_SOFTNESS_HIGHLIGHT_BIAS,
  };
}
