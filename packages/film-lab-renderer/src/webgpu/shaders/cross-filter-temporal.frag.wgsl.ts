/**
 * Cross-filter temporal hold (WGSL).
 *
 * Phase 3 T3-2. Ported from
 * `src/webgl/shaders/cross-filter-temporal.frag.ts`.
 *
 * Runs after peak detection (and optional spacing suppression), before
 * central-bloom and streak generation. Holds previous-frame peaks with a
 * luma-gated exponential decay so new peaks light up immediately while old
 * ones fade instead of hard-switching at the detection threshold.
 *
 *   prevMask    = smoothstep(0.002, 0.03, luma709(prev))
 *   held        = prev * (uDecay * prevMask)
 *   stabilized  = max(current, held)
 */
export const crossFilterTemporalFragmentWgsl = /* wgsl */ `
struct Params {
  // (decay, _, _, _)
  decay: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uPrev: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let current = textureSampleLevel(uSource, uSampler, uv, 0.0).rgb;
  let prev = textureSampleLevel(uPrev, uSampler, uv, 0.0).rgb;
  let prevLuma = dot(prev, LUMA_709);
  let prevMask = smoothstep(0.002, 0.03, prevLuma);
  let held = prev * (uParams.decay.x * prevMask);
  let stabilized = max(current, held);
  return vec4f(stabilized, 1.0);
}
`;
