/**
 * Cross-filter peak-spacing directional max (WGSL).
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-peak-spacing-max.frag.ts`.
 *
 * Two-pass sweep (horizontal then vertical) that walks up to ±MAX_RADIUS
 * pixels along `uAxis` and records the strongest-ranked peak's coordinate
 * and rank. When `uReadMetadata >= 0.5` the input already carries
 * `(winnerX, winnerY, _, rank)` from the previous axis; otherwise the rank
 * is computed from the color's luma with a small spatial tie-breaker hash.
 *
 * Output layout matches WebGL: `vec4(bestCoord.xy, 0, bestRank)`.
 */
export const crossFilterPeakSpacingMaxFragmentWgsl = /* wgsl */ `
struct Params {
  // (texelSize.xy, axis.xy)
  texelAndAxis: vec4f,
  // (radiusPx, readMetadata, _, _)
  radiusAndMeta: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

const MAX_RADIUS: i32 = 48;
const RANK_LUMA_SCALE: f32 = 64.0;
const RANK_TIE_BIAS: f32 = 0.1;
const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);

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
  let texelSize = uParams.texelAndAxis.xy;
  let axis = uParams.texelAndAxis.zw;
  let radiusPx = uParams.radiusAndMeta.x;
  let readMetadata = uParams.radiusAndMeta.y;

  let pixelCoord = floor(uv / texelSize + 0.5);
  let maxCoord = max(vec2f(0.0), floor(vec2f(1.0) / texelSize) - 1.0);
  var bestCoord = vec2f(0.0);
  var bestRank: f32 = 0.0;

  for (var i: i32 = -MAX_RADIUS; i <= MAX_RADIUS; i = i + 1) {
    let fi = f32(i);
    if (abs(fi) > radiusPx) {
      continue;
    }
    let sampleCoord = clamp(pixelCoord + axis * fi, vec2f(0.0), maxCoord);
    let sampleUv = (sampleCoord + 0.5) * texelSize;
    let sampleValue = textureSampleLevel(uSource, uSampler, sampleUv, 0.0);
    var sampleRank: f32 = 0.0;
    var sampleWinnerCoord = vec2f(0.0);
    if (readMetadata >= 0.5) {
      sampleWinnerCoord = floor(sampleValue.xy + 0.5);
      sampleRank = sampleValue.a;
    } else {
      sampleWinnerCoord = sampleCoord;
      sampleRank = rankPeak(sampleValue.rgb, sampleCoord);
    }
    if (sampleRank > bestRank) {
      bestRank = sampleRank;
      bestCoord = sampleWinnerCoord;
    }
  }

  return vec4f(bestCoord, 0.0, bestRank);
}
`;
