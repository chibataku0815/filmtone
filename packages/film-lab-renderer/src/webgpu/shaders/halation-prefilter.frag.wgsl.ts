/**
 * Halation prefilter (WGSL) — same soft-knee gate as bloom, tinted by the
 * halation color. Ported from src/webgl/shaders/halation-prefilter.frag.ts.
 *
 * Phase 1 T1-3. Packed uniforms as vec4 to avoid WGSL 16-byte silent
 * padding pitfalls (DIRECTION §4): halationColor stored as `.xyz` of a
 * vec4, threshold + knee on a second vec4.
 */
export const halationPrefilterFragmentWgsl = /* wgsl */ `
struct Params {
  // (halationColor.rgb, threshold)
  colorThreshold: vec4f,
  // (knee, _, _, _)
  knee: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let color = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let luma = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));

  let threshold = uParams.colorThreshold.w;
  let halationColor = uParams.colorThreshold.xyz;
  let knee = max(uParams.knee.x * threshold, 1e-4);
  let t = clamp((luma - threshold + knee) / (2.0 * knee), 0.0, 1.0);
  var contribution = t * t * mix(knee, 1.0, t);
  contribution = max(contribution, max(0.0, luma - threshold));

  let halation = color.rgb * contribution * halationColor;
  return vec4f(halation, 1.0);
}
`;
