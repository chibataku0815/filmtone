/**
 * Downsample (WGSL) — 13-tap tent, Jimenez/COD-AW.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/downsample.frag.ts. Mirror
 * addressing is kept for parity with the WebGL path; the sampler-provided
 * `address-mode: mirror-repeat` would be cheaper but we retain the manual
 * `mirrorUv` to keep WebGL ↔ WebGPU pixel equivalence within PSNR range.
 */
export const downsampleFragmentWgsl = /* wgsl */ `
struct Params {
  // (texelSize.xy, _, _)
  texelSize: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

fn mirrorUv(uv: vec2f) -> vec2f {
  let tiled = vec2f(uv.x - floor(uv.x * 0.5) * 2.0, uv.y - floor(uv.y * 0.5) * 2.0);
  return vec2f(1.0, 1.0) - abs(tiled - vec2f(1.0, 1.0));
}

fn sampleMirror(uv: vec2f) -> vec4f {
  return textureSampleLevel(uSource, uSampler, mirrorUv(uv), 0.0);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let d = uParams.texelSize.xy;

  let a = sampleMirror(uv + vec2f(-2.0 * d.x,  2.0 * d.y));
  let b = sampleMirror(uv + vec2f( 0.0,         2.0 * d.y));
  let c = sampleMirror(uv + vec2f( 2.0 * d.x,  2.0 * d.y));

  let dd = sampleMirror(uv + vec2f(-d.x,  d.y));
  let e  = sampleMirror(uv + vec2f( d.x,  d.y));

  let f = sampleMirror(uv + vec2f(-2.0 * d.x, 0.0));
  let g = sampleMirror(uv);
  let h = sampleMirror(uv + vec2f( 2.0 * d.x, 0.0));

  let ii = sampleMirror(uv + vec2f(-d.x, -d.y));
  let j  = sampleMirror(uv + vec2f( d.x, -d.y));

  let k = sampleMirror(uv + vec2f(-2.0 * d.x, -2.0 * d.y));
  let l = sampleMirror(uv + vec2f( 0.0,        -2.0 * d.y));
  let m = sampleMirror(uv + vec2f( 2.0 * d.x, -2.0 * d.y));

  return (dd + e + ii + j) * 0.125
       + g * 0.125
       + (a + c + k + m) * 0.03125
       + (b + f + h + l) * 0.0625;
}
`;
