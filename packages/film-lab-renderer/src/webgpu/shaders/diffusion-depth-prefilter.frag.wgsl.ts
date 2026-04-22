/**
 * Diffusion depth prefilter (WGSL) — shared depth-aware source mask.
 *
 * Physical model: a Pro-Mist / diffusion filter scatters light *at the source*
 * (in front of the lens), not as a post-composite opacity cut. Weighting the
 * source by depth before the diffusion pyramid is built therefore produces
 * atmospheric "馴染み" — near pixels contribute less to the halo, far pixels
 * contribute more — without the sharp silhouette re-cut that appears when
 * depth modulation is applied after the pyramid has already bled across
 * silhouettes (which reads as a "double image" / ghost).
 *
 * Output: source.rgb * mix(1 - gain, 1 + gain*4, depth). Feeds directly into
 * the existing diffusion pyramid (downsample.0 → … → upsample.0) in place of
 * the raw colorGraded view. Composite leaves diffusion uniform and unmodulated
 * (the depth shaping is now baked into the pyramid input).
 *
 * Bind group layout (group 1):
 *   @binding(0) uParams  : Params uniform (gain, fitMode, resolution)
 *   @binding(1) uSource  : texture_2d<f32>  (rt.colorGraded)
 *   @binding(2) uDepth   : texture_2d<f32>  (shared depth texture, rgba8unorm)
 *   @binding(3) uSampler : sampler          (linear, clamp-to-edge)
 *
 * `fitUv` mirrors the same image-aspect fit used by composite's vignette and
 * the current depth debug view, so the depth texture lands on the correct
 * image pixel regardless of canvas aspect.
 */
export const diffusionDepthPrefilterFragmentWgsl = /* wgsl */ `
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
  // Orientation-preserving fetch: every fullscreen pass inherently y-flips
  // the framebuffer once. The diffusion pyramid has 5 passes (3 downsamples
  // + 2 upsamples) = odd parity, and composite samples diffusion at
  // (u, 1 - v) to re-flip that odd-parity halo back in alignment. Adding
  // this prefilter pass would push the chain to even parity, which renders
  // the halo upside-down in composite. Sampling source/depth at the
  // y-flipped input coord adds one more flip here so the pass is net
  // orientation-preserving and the pyramid parity stays at 5 (odd) —
  // matching composite's existing sample coord assumption.
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
  // Balanced depth range: near keeps a soft Pro-Mist veil (× (1 - 0.5*gain))
  // instead of dropping to × 0, and far is boosted to × (1 + 2*gain) instead
  // of × 5. At gain = 1 that yields 0.5 → 3.0 (6:1 contrast), approximating
  // what a physical mist filter shows between near/far light sources without
  // over-blown highlights or a harsh "subject cleared" look.
  let mult = mix(1.0 - gain * 0.5, 1.0 + gain * 2.0, depthVal);
  return vec4f(color.rgb * mult, color.a);
}
`;
