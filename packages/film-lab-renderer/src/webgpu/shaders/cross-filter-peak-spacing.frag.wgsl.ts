/**
 * Cross-filter peak-spacing gate (WGSL).
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-peak-spacing.frag.ts`.
 *
 * Final stage of the spacing enforcement: pass through the center pixel
 * only if the winner coordinate in `uLocalMax` matches the current pixel
 * (within a 0.25 px tolerance), otherwise black out. This is what prevents
 * adjacent peaks closer than `uMinSpacing` from both casting streaks.
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

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let texelSize = uParams.texelAndSpacing.xy;
  let minSpacing = uParams.texelAndSpacing.z;

  let pixelCoord = floor(uv / texelSize + 0.5);
  let centerUv = (pixelCoord + 0.5) * texelSize;
  let center = textureSampleLevel(uSource, uSampler, centerUv, 0.0);
  let centerLuma = dot(center.rgb, LUMA_709);
  if (centerLuma <= 1e-4 || minSpacing <= 1e-4) {
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
  return vec4f(0.0, 0.0, 0.0, 1.0);
}
`;
