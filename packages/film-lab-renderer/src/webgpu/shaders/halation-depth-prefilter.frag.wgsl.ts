/**
 * Halation depth prefilter (WGSL) — dev-only AI depth source mask for the
 * halation pyramid. Same structure as `bloom-depth-prefilter` and the Mist
 * reference; differs only in the near/far coefficients.
 *
 * Near × (1 - 0.25 * gain), far × (1 + 0.5 * gain). At gain = 1 that yields
 * 0.75 → 1.5 (2:1). Halation is a tinted red-orange highlight shoulder —
 * pushing far too hard would over-saturate distant practicals into orange
 * smears, so the gradient is the gentlest of the three pillars.
 *
 * Bind group layout mirrors `diffusionDepthPrefilterGroupLayout` —
 *   @binding(0) uParams  : Params uniform (gain, fitMode, resolution)
 *   @binding(1) uSource  : texture_2d<f32>  (rt.colorGraded)
 *   @binding(2) uDepth   : texture_2d<f32>  (depth probe, rgba8unorm)
 *   @binding(3) uSampler : sampler          (linear, clamp-to-edge)
 *
 * Output feeds the existing halation pyramid as its `sourceView`,
 * replacing the raw colorGraded view.
 */
export const halationDepthPrefilterFragmentWgsl = /* wgsl */ `
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
  // Orientation-preserving fetch — see bloom-depth-prefilter for parity
  // rationale. +1 fullscreen pass would flip downstream halo; sampling at
  // (u, 1 - v) cancels the inherent framebuffer flip so this pass is net
  // zero and the halation pyramid parity is unchanged.
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
  // Gentler range than bloom (0.7 → 1.8) to avoid over-saturating distant
  // tinted highlights. At gain = 1: near × 0.75, far × 1.5 (2:1).
  let mult = mix(1.0 - gain * 0.25, 1.0 + gain * 0.5, depthVal);
  return vec4f(color.rgb * mult, color.a);
}
`;
