/**
 * Dust + scratch overlay (WGSL). Ported from src/webgl/shaders/dust.frag.ts.
 *
 * Phase 1 T1-3. Screen blend for dust, additive for scratches. Animated
 * offsets are driven by `uTime` (seconds). Dust/scratch textures are
 * sampled at `wrap-repeat` address mode so the scrolling tiles cleanly.
 */
export const dustFragmentWgsl = /* wgsl */ `
struct Params {
  // (dustAmount, scratchAmount, time, _)
  amountsAndTime: vec4f,
  // (resolution.x, resolution.y, _, _)
  resolution: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uDust: texture_2d<f32>;
@group(1) @binding(3) var uScratch: texture_2d<f32>;
@group(1) @binding(4) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  var color = textureSampleLevel(uSource, uSampler, uv, 0.0);

  let dustAmount = uParams.amountsAndTime.x;
  let scratchAmount = uParams.amountsAndTime.y;
  let time = uParams.amountsAndTime.z;

  if (dustAmount > 0.0) {
    let dustUv = uv * 3.0 + vec2f(time * 0.02, time * 0.015);
    let dust = textureSampleLevel(uDust, uSampler, dustUv, 0.0).r;
    let dustUv2 = uv * 1.7 + vec2f(-time * 0.013, time * 0.009);
    let dust2 = textureSampleLevel(uDust, uSampler, dustUv2, 0.0).r;
    let dustCombined = max(dust, dust2 * 0.7);
    let dustColor = vec3f(dustCombined * dustAmount);
    color = vec4f(1.0 - (1.0 - color.rgb) * (1.0 - dustColor), color.a);
  }

  if (scratchAmount > 0.0) {
    let jitterPhase = floor(time * 4.0);
    let scratchUv = vec2f(uv.x * 2.0, uv.y * 0.5 + jitterPhase * 0.37);
    let scratch = textureSampleLevel(uScratch, uSampler, scratchUv, 0.0).r;
    color = vec4f(color.rgb + vec3f(scratch * scratchAmount * 0.6), color.a);
  }

  return vec4f(clamp(color.rgb, vec3f(0.0), vec3f(1.0)), color.a);
}
`;
