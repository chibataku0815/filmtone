/**
 * Cross-filter blend (WGSL).
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-blend.frag.ts`.
 *
 * Additive combine of up to 4 directional streak RTs with Soft Reinhard
 * rolloff on excess. Hard Mode's central-bloom input is always black in
 * v1.0 (UI gated, DIRECTION §1 D5) so the `bloom` term collapses to 0.
 * `uHardMode` remains wired for v1.1 forward-compat without branching.
 */
export const crossFilterBlendFragmentWgsl = /* wgsl */ `
struct Params {
  // (streakCount, intensity, hardMode, _)
  counts: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uStreak0: texture_2d<f32>;
@group(1) @binding(3) var uStreak1: texture_2d<f32>;
@group(1) @binding(4) var uStreak2: texture_2d<f32>;
@group(1) @binding(5) var uStreak3: texture_2d<f32>;
@group(1) @binding(6) var uCentralBloom: texture_2d<f32>;
@group(1) @binding(7) var uSampler: sampler;

const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let streakCount = uParams.counts.x;
  let intensity = uParams.counts.y;
  let hardMode = uParams.counts.z;

  let original = textureSampleLevel(uSource, uSampler, uv, 0.0);
  var streaks = textureSampleLevel(uStreak0, uSampler, uv, 0.0).rgb
              + textureSampleLevel(uStreak1, uSampler, uv, 0.0).rgb;
  if (streakCount > 2.5) {
    streaks = streaks + textureSampleLevel(uStreak2, uSampler, uv, 0.0).rgb;
  }
  if (streakCount > 3.5) {
    streaks = streaks + textureSampleLevel(uStreak3, uSampler, uv, 0.0).rgb;
  }
  streaks = streaks / max(streakCount, 1.0);

  let bloom = textureSampleLevel(uCentralBloom, uSampler, uv, 0.0).rgb * hardMode * 1.5;

  let origLuma = dot(original.rgb, LUMA_709);
  let centerProtect = mix(1.0, 1.0 - smoothstep(0.65, 0.95, origLuma), hardMode);

  let overlay = (streaks + bloom) * intensity * centerProtect;
  let combined = original.rgb + overlay;
  let excess = max(combined - vec3f(1.0), vec3f(0.0));
  let result = combined - excess + excess / (vec3f(1.0) + excess * 2.0);

  return vec4f(result, original.a);
}
`;
