/**
 * Bloom prefilter (WGSL) — quadratic soft-knee luma gate.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/bloom-prefilter.frag.ts.
 * Output writes into an `rgba16float` RT (DIRECTION §2), no clamp — HDR
 * overshoot is preserved for the downsample stage.
 *
 * Bind group layout (group 1, shared with halation/lightshafts/dust):
 *   @binding(0) uParams : vec4<f32>  // (threshold, knee, _, _)
 *   @binding(1) uSource : texture_2d<f32>
 *   @binding(2) uSampler: sampler
 */
export const bloomPrefilterFragmentWgsl = /* wgsl */ `
struct Params {
  threshold: f32,
  knee: f32,
  _pad0: f32,
  _pad1: f32,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let color = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let luma = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));

  let knee = max(uParams.knee * uParams.threshold, 1e-4);
  let t = clamp((luma - uParams.threshold + knee) / (2.0 * knee), 0.0, 1.0);
  var contribution = t * t * mix(knee, 1.0, t);

  // Guard pow/log/sqrt inputs per DIRECTION §3 (no negative luma).
  let overshoot = max(0.0, luma - uParams.threshold);
  contribution = max(contribution, overshoot);

  return vec4f(color.rgb * contribution, 1.0);
}
`;
