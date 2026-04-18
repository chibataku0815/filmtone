/**
 * filmlab.frag (WGSL) — **identity placeholder** for Phase 1 T1-3.
 *
 * DIRECTION §10 Phase 1 default: "identity LUT(33³ linear)で pipeline 通し
 * てから実 .cube データ". This shader is the primary-grade pass wired into
 * the Phase 1 end-to-end pipeline — it currently passes the media texture
 * through unchanged so bloom/halation stages can be verified visually
 * against the WebGL output.
 *
 * **Phase 2 T2-1 replaces this with the real 31-uniform primary grade +
 * soft-shaper + LUT2 + print pipeline (DIRECTION §3).**
 */
export const filmlabFragmentWgsl = /* wgsl */ `
@group(1) @binding(0) var uMedia: texture_2d<f32>;
@group(1) @binding(1) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  return textureSampleLevel(uMedia, uSampler, uv, 0.0);
}
`;
