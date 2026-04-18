/**
 * motionblur-blend (WGSL) — Phase 2 T2-4.
 *
 * N-slot weighted average over the 8-layer ring buffer
 * (`texture_2d_array<f32>`, DIRECTION §4). CPU pre-normalizes weights so
 * `weights[i] = 0` for `i >= activeFrames` — removes the branch the WebGL
 * path used, keeps the loop tight + gradient-free.
 *
 * Motion detection compares newest vs oldest slot luminance and fades
 * toward the newest frame for stationary pixels (`motionThreshold > 0`).
 * `motionThreshold = 0` disables detection — always use the blurred
 * average. CPU passes `oldestSlot` directly so the shader doesn't need
 * to know `activeFrames`.
 *
 * Bind group layout (group 1):
 *   binding(0) uParams : Params (weights[0..7] packed into 2 vec4 +
 *                        (currentSlot, oldestSlot, motionThreshold, _))
 *   binding(1) uRing   : texture_2d_array<f32>  (8 layers)
 *   binding(2) uSampler: sampler
 */
export const motionblurBlendFragmentWgsl = /* wgsl */ `
struct Params {
  // weights[0..3] — index 0 = newest, 7 = oldest.
  weights0: vec4f,
  weights1: vec4f,
  // (currentSlot, oldestSlot, motionThreshold, _)
  ring: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uRing: texture_2d_array<f32>;
@group(1) @binding(2) var uSampler: sampler;

const LUMA_R709 = vec3f(0.2126, 0.7152, 0.0722);

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let currentSlot = i32(uParams.ring.x);
  let oldestSlot = i32(uParams.ring.y);
  let motionThreshold = uParams.ring.z;

  var weights: array<f32, 8>;
  weights[0] = uParams.weights0.x;
  weights[1] = uParams.weights0.y;
  weights[2] = uParams.weights0.z;
  weights[3] = uParams.weights0.w;
  weights[4] = uParams.weights1.x;
  weights[5] = uParams.weights1.y;
  weights[6] = uParams.weights1.z;
  weights[7] = uParams.weights1.w;

  var sum = vec4f(0.0);
  for (var i: i32 = 0; i < 8; i = i + 1) {
    // +16 keeps the intermediate non-negative for every (currentSlot, i)
    // pair in [0..7] × [0..7]; the % 8 then wraps cleanly.
    let layer = (currentSlot - i + 16) % 8;
    let sample = textureSampleLevel(uRing, uSampler, uv, layer, 0.0);
    sum = sum + sample * weights[i];
  }

  let newest = textureSampleLevel(uRing, uSampler, uv, currentSlot, 0.0);
  let oldest = textureSampleLevel(uRing, uSampler, uv, oldestSlot, 0.0);
  let lumaDelta = abs(dot(newest.rgb - oldest.rgb, LUMA_R709));
  let motionMask = select(
    1.0,
    smoothstep(motionThreshold * 0.5, motionThreshold * 2.0, lumaDelta),
    motionThreshold > 0.0,
  );

  return mix(newest, sum, motionMask);
}
`;
