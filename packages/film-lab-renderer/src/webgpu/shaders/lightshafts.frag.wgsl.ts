/**
 * Lightshafts (WGSL) — radial occlusion sampling, 64 taps.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/lightshafts.frag.ts. The
 * 64-tap loop is unrolled by the WGSL compiler; `textureSampleLevel` is
 * used unconditionally (no dynamic UV-dependent branches), satisfying
 * the DIRECTION §4 non-uniform-control-flow rule.
 */
export const lightshaftsFragmentWgsl = /* wgsl */ `
struct Params {
  // (lightOrigin.xy, decay, density)
  originDecayDensity: vec4f,
  // (exposure, _, _, _)
  exposure: vec4f,
};

const NUM_SAMPLES: u32 = 64u;
const LUMINANCE_THRESHOLD: f32 = 0.65;

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let lightOrigin = uParams.originDecayDensity.xy;
  let decay = uParams.originDecayDensity.z;
  let density = uParams.originDecayDensity.w;
  let exposure = uParams.exposure.x;

  var deltaUv = uv - lightOrigin;
  deltaUv = deltaUv * (density / f32(NUM_SAMPLES));

  var sampleUv = uv;
  var accum = vec4f(0.0);
  var illuminationDecay = 1.0;

  for (var i: u32 = 0u; i < NUM_SAMPLES; i = i + 1u) {
    sampleUv = sampleUv - deltaUv;
    let clamped = clamp(sampleUv, vec2f(0.0), vec2f(1.0));
    var s = textureSampleLevel(uSource, uSampler, clamped, 0.0);
    let luma = dot(s.rgb, vec3f(0.2126, 0.7152, 0.0722));
    let contribution = smoothstep(LUMINANCE_THRESHOLD - 0.05, LUMINANCE_THRESHOLD + 0.05, luma);
    s = vec4f(s.rgb * contribution, s.a);
    s = s * illuminationDecay;
    accum = accum + s;
    illuminationDecay = illuminationDecay * decay;
  }

  accum = accum / f32(NUM_SAMPLES);
  return vec4f(accum.rgb * exposure, 1.0);
}
`;
