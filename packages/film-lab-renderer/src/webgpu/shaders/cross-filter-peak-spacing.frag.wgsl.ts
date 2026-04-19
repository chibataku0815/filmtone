/**
 * Cross-filter peak-spacing gate (WGSL).
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-peak-spacing.frag.ts`.
 *
 * Final stage of the spacing enforcement: pass through the center pixel
 * at full strength only if the winner coordinate in `uLocalMax` matches
 * the current pixel (within a 0.25 px tolerance). Near-tie losers keep a
 * very small residual contribution to reduce abrupt blink at the new 1.00
 * floor, while values above 1.00 tighten that shoulder without changing
 * the winner map itself.
 */
export const crossFilterPeakSpacingFragmentWgsl = /* wgsl */ `
struct Params {
  // (texelSize.xy, minSpacing, _pad)
  texelAndSpacing: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uLocalMax: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);
const RANK_LUMA_SCALE: f32 = 64.0;
const RANK_TIE_BIAS: f32 = 0.1;
const LOSER_WEIGHT_MAX: f32 = 0.06;
const LOSER_WEIGHT_MAX_STRONG: f32 = 0.02;
const RANK_GAP_START: f32 = 0.08;
const RANK_GAP_END: f32 = 0.20;

fn hash12(p: vec2f) -> f32 {
  let ip = floor(p);
  let h = sin(dot(ip, vec2f(127.1, 311.7))) * 43758.5453;
  return fract(h);
}

fn rankPeak(color: vec3f, pixelCoord: vec2f) -> f32 {
  let luma = dot(color, LUMA_709);
  if (luma <= 1e-4) {
    return 0.0;
  }
  return luma * RANK_LUMA_SCALE + hash12(pixelCoord) * RANK_TIE_BIAS;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let texelSize = uParams.texelAndSpacing.xy;
  let spacingControl = max(uParams.texelAndSpacing.z, 1.0);
  let spacingBoost = clamp(spacingControl - 1.0, 0.0, 1.0);

  let pixelCoord = floor(uv / texelSize + 0.5);
  let centerUv = (pixelCoord + 0.5) * texelSize;
  let center = textureSampleLevel(uSource, uSampler, centerUv, 0.0);
  let centerLuma = dot(center.rgb, LUMA_709);
  if (centerLuma <= 1e-4) {
    return vec4f(center.rgb, 1.0);
  }

  let localMax = textureSampleLevel(uLocalMax, uSampler, centerUv, 0.0);
  let winnerCoord = floor(localMax.xy + 0.5);
  let keep =
    localMax.a > 0.0 &&
    abs(winnerCoord.x - pixelCoord.x) <= 0.25 &&
    abs(winnerCoord.y - pixelCoord.y) <= 0.25;

  if (keep) {
    return vec4f(center.rgb, 1.0);
  }

  let centerRank = rankPeak(center.rgb, pixelCoord);
  let winnerRank = localMax.a;
  let rankGap = max(winnerRank - centerRank, 0.0);
  let nearTie = 1.0 - smoothstep(RANK_GAP_START, RANK_GAP_END, rankGap);
  let loserWeightMax = mix(LOSER_WEIGHT_MAX, LOSER_WEIGHT_MAX_STRONG, spacingBoost);
  let loserWeight = loserWeightMax * nearTie * nearTie;

  return vec4f(center.rgb * loserWeight, 1.0);
}
`;
