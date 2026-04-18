/**
 * Cross-filter peak detection (WGSL).
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-peak.frag.ts`.
 *
 * Bright center + local-peak isolation: returns the center color scaled by
 * how much it exceeds a 16-tap ring average, attenuated by neighbor density
 * so large bright blobs don't cast streaks (controlled by `uSizeLimit`).
 *
 * Bind group layout (group1):
 *   0 uniform `Params { texelSize: vec2f, sizeLimit: f32, _: f32 }`
 *   1 texture_2d<f32> uSource
 *   2 sampler uSampler
 */
export const crossFilterPeakFragmentWgsl = /* wgsl */ `
struct Params {
  // (texelSize.xy, sizeLimit, _pad)
  texelSizeAndSize: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

const RING_SAMPLES: i32 = 16;
const RING_RADIUS: f32 = 24.0;
const NEIGHBOR_SAMPLES: i32 = 16;
const NEIGHBOR_RADIUS: f32 = 8.0;
const NEIGHBOR_THRESHOLD: f32 = 0.01;
const TAU: f32 = 6.283185307;
const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let texelSize = uParams.texelSizeAndSize.xy;
  let sizeLimit = uParams.texelSizeAndSize.z;

  let center = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let centerLuma = dot(center.rgb, LUMA_709);

  var avgLuma: f32 = 0.0;
  for (var i: i32 = 0; i < RING_SAMPLES; i = i + 1) {
    let angle = f32(i) * (TAU / f32(RING_SAMPLES));
    let offset = vec2f(cos(angle), sin(angle)) * RING_RADIUS * texelSize;
    let ringSample = textureSampleLevel(uSource, uSampler, uv + offset, 0.0);
    avgLuma = avgLuma + dot(ringSample.rgb, LUMA_709);
  }
  avgLuma = avgLuma / f32(RING_SAMPLES);

  let peakness = centerLuma - avgLuma;

  var neighborCount: f32 = 0.0;
  for (var i: i32 = 0; i < NEIGHBOR_SAMPLES; i = i + 1) {
    let angle = f32(i) * (TAU / f32(NEIGHBOR_SAMPLES));
    let offset = vec2f(cos(angle), sin(angle)) * NEIGHBOR_RADIUS * texelSize;
    let nSample = textureSampleLevel(uSource, uSampler, uv + offset, 0.0);
    let lum = dot(nSample.rgb, LUMA_709);
    neighborCount = neighborCount + step(NEIGHBOR_THRESHOLD, lum);
  }

  let maxNeighbors = mix(f32(NEIGHBOR_SAMPLES), 1.0, sizeLimit);
  let densityFactor = 1.0 - smoothstep(maxNeighbors, maxNeighbors + 2.0, neighborCount);
  let factor = smoothstep(0.0, 0.2, peakness) * densityFactor;

  return center * factor;
}
`;
