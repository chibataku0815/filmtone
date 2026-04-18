/**
 * Upsample (WGSL) — 9-tap tent.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/upsample.frag.ts. Output is
 * the weighted contribution alone; additive accumulation is performed by
 * the render pass blend state (`blend: { color: { operation: add, src: one,
 * dst: one } }`).
 */
export const upsampleFragmentWgsl = /* wgsl */ `
struct Params {
  // (texelSize.xy, weight, _)
  texelAndWeight: vec4f,
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
  let d = uParams.texelAndWeight.xy;
  let weight = uParams.texelAndWeight.z;

  let s  = sampleMirror(uv);
  let s0 = sampleMirror(uv + vec2f(-d.x,  d.y));
  let s1 = sampleMirror(uv + vec2f( 0.0,  d.y));
  let s2 = sampleMirror(uv + vec2f( d.x,  d.y));
  let s3 = sampleMirror(uv + vec2f(-d.x,  0.0));
  let s4 = sampleMirror(uv + vec2f( d.x,  0.0));
  let s5 = sampleMirror(uv + vec2f(-d.x, -d.y));
  let s6 = sampleMirror(uv + vec2f( 0.0, -d.y));
  let s7 = sampleMirror(uv + vec2f( d.x, -d.y));

  var upsampled = s * 4.0
                + (s1 + s3 + s4 + s6) * 2.0
                + (s0 + s2 + s5 + s7) * 1.0;
  upsampled = upsampled / 16.0;
  return upsampled * weight;
}
`;
