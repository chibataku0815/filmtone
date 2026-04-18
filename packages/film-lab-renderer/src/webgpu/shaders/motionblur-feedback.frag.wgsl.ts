/**
 * motionblur-feedback (WGSL) — Phase 2 T2-4.
 *
 * Writes the current graded/composited frame into the next ring slot,
 * optionally mixing in the most recently written slot for extended trail.
 * Ported from `src/webgl/shaders/motionblur.frag.ts` `feedbackCopy` shader.
 *
 * Bind group layout (group 1):
 *   binding(0) uParams : Params  (trail, hasPrev, _, _)
 *   binding(1) uSource : texture_2d<f32>  (composited current frame)
 *   binding(2) uPrev   : texture_2d<f32>  (previous ring slot; black when hasPrev=0)
 *   binding(3) uSampler: sampler
 */
export const motionblurFeedbackFragmentWgsl = /* wgsl */ `
struct Params {
  // (trail, hasPrev, _, _) — trail is scaled by hasPrev so a fresh ring
  // (no valid previous slot) falls back to a clean copy without requiring
  // a separate pipeline.
  trail: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uPrev: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let src = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let prev = textureSampleLevel(uPrev, uSampler, uv, 0.0);
  let t = clamp(uParams.trail.x * uParams.trail.y, 0.0, 0.95);
  return mix(src, prev, t);
}
`;
