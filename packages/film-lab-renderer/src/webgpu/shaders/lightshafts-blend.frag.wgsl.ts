/**
 * Lightshafts blend (WGSL) — additive shaft overlay onto the scene.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/lightshafts-blend.frag.ts.
 * The clamp to [0,1] is retained for exact WebGL parity even though
 * DIRECTION §1 removes `clamp(0,1)` from the PRIMARY grade; this is a
 * composite stage, so the clamp stays.
 */
export const lightshaftsBlendFragmentWgsl = /* wgsl */ `
struct Params {
  // (intensity, _, _, _)
  intensity: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uScene: texture_2d<f32>;
@group(1) @binding(2) var uShafts: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let scene = textureSampleLevel(uScene, uSampler, uv, 0.0).rgb;
  let shafts = textureSampleLevel(uShafts, uSampler, uv, 0.0).rgb;
  let result = scene + shafts * uParams.intensity.x;
  return vec4f(clamp(result, vec3f(0.0), vec3f(1.0)), 1.0);
}
`;
