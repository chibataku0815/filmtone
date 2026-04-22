/**
 * Bloom depth prefilter (WGSL) — shared depth-aware source mask for the
 * bloom pyramid. Mirrors the Mist diffusion prefilter pattern
 * (see `diffusion-depth-prefilter.frag.wgsl.ts` and
 * `.claude/knowledge/patterns/2026-04-21-depth-weighted-source-masking-for-atmospheric-filters.md`)
 * but uses a tighter near/far range because bloom's highlight scatter
 * is less volumetric than low-frequency diffusion.
 *
 * Near × (1 - 0.3 * gain), far × (1 + 0.8 * gain). At gain = 1 that yields
 * 0.7 → 1.8 (≈2.6:1), so close highlights retain "glow presence" while
 * distant practicals lift into a softer atmospheric bloom. Range tightened
 * vs Mist (0.5 → 3.0) because bloom already starts at bright pixels; the
 * depth weight biases *which* highlights bloom most, not whether they bloom.
 *
 * Bind group layout mirrors `diffusionDepthPrefilterGroupLayout` —
 *   @binding(0) uParams  : Params uniform (gain, fitMode, resolution)
 *   @binding(1) uSource  : texture_2d<f32>  (rt.colorGraded)
 *   @binding(2) uDepth   : texture_2d<f32>  (shared depth texture, rgba8unorm)
 *   @binding(3) uSampler : sampler          (linear, clamp-to-edge)
 *
 * Output feeds the existing bloom pyramid as its `sourceView`, replacing
 * the raw colorGraded view. The luma gate (`bloom-prefilter`) then reads
 * from this depth-weighted intermediate.
 */
export const bloomDepthPrefilterFragmentWgsl = /* wgsl */ `
struct Params {
  // (gain, fitMode, _pad0, _pad1)
  misc: vec4f,
  // (resolutionX, resolutionY, imageResX, imageResY)
  size: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uDepth: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

fn fitUv(uv: vec2f, resolution: vec2f, imageResolution: vec2f, fitMode: f32) -> vec2f {
  let screenAspect = resolution.x / max(resolution.y, 1.0);
  let imageAspect = imageResolution.x / max(imageResolution.y, 1.0);
  let coverScale = select(
    vec2f(screenAspect / imageAspect, 1.0),
    vec2f(1.0, imageAspect / screenAspect),
    screenAspect > imageAspect,
  );
  let containScale = select(
    vec2f(1.0, imageAspect / screenAspect),
    vec2f(screenAspect / imageAspect, 1.0),
    screenAspect > imageAspect,
  );
  let scale = mix(coverScale, containScale, fitMode);
  var result = (uv - vec2f(0.5)) * scale + vec2f(0.5);
  let narrowPortrait = step(2.0, scale.x) * fitMode;
  result.x = result.x + 0.18 * scale.x * narrowPortrait;
  return result;
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  // Orientation-preserving fetch: bloom pyramid has 2N-1 fullscreen passes
  // (prefilter + downsamples + upsamples); composite samples bloom at
  // (u, 1 - v) assuming that existing parity. Inserting +1 pass flips
  // parity and mirrors the halo. Sampling source/depth at the y-flipped
  // input coord adds one offsetting flip so this pass is net zero and
  // downstream parity is unchanged.
  let flipUv = vec2f(uv.x, 1.0 - uv.y);
  let color = textureSampleLevel(uSource, uSampler, flipUv, 0.0);
  let gain = clamp(uParams.misc.x, 0.0, 1.0);
  if (gain <= 0.0) {
    return color;
  }
  let fitMode = uParams.misc.y;
  let resolution = uParams.size.xy;
  let imageResolution = uParams.size.zw;
  let depthUv = fitUv(flipUv, resolution, imageResolution, fitMode);
  let depthVal = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;
  // Tighter range than Mist (0.5 → 3.0) because bloom already gates by
  // luma downstream. At gain = 1: near × 0.7, far × 1.8 (≈2.6:1).
  let mult = mix(1.0 - gain * 0.3, 1.0 + gain * 0.8, depthVal);
  return vec4f(color.rgb * mult, color.a);
}
`;
