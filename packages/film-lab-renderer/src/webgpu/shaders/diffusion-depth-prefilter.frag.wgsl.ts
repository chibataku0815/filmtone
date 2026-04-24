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
 * Output: source.rgb * depthMult * rayAngleMult. Feeds directly into the
 * existing diffusion pyramid (downsample.0 → … → upsample.0) in place of the
 * raw colorGraded view. Composite leaves diffusion uniform and unmodulated
 * (the depth + field shaping is now baked into the pyramid input).
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
  // (gain, fitMode, rayAngleGain, rayAngleGamma)
  misc: vec4f,
  // (resolutionX, resolutionY, imageResX, imageResY)
  size: vec4f,
  // (fieldPsfGain, fieldPsfRadiusPx, _, _)
  psf: vec4f,
  // (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
  optics: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uDepth: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

const RAY_ANGLE_REFERENCE_TAN_HALF_HFOV: f32 = 0.6370702608; // tan(65deg / 2)

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

fn rayAngleMask(
  imageUv: vec2f,
  imageResolution: vec2f,
  tanHalfFov: vec2f,
  innerThreshold: f32,
  gamma: f32,
) -> f32 {
  let sensor = (imageUv - vec2f(0.5)) * 2.0;
  let ray = sensor * max(tanHalfFov, vec2f(1e-4));
  let viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);
  let incidence = 1.0 - viewZ;
  let aspectY = imageResolution.y / max(imageResolution.x, 1.0);
  let cornerRay = vec2f(
    RAY_ANGLE_REFERENCE_TAN_HALF_HFOV,
    RAY_ANGLE_REFERENCE_TAN_HALF_HFOV * aspectY,
  );
  let maxIncidence = 1.0 - (1.0 / sqrt(dot(cornerRay, cornerRay) + 1.0));
  let normalized = clamp(incidence / max(maxIncidence, 1e-5), 0.0, 1.0);
  return smoothstep(
    clamp(innerThreshold, 0.0, 0.8),
    1.0,
    pow(normalized, max(gamma, 0.001)),
  );
}

fn weightedSource(
  sourceUv: vec2f,
  resolution: vec2f,
  imageResolution: vec2f,
  fitMode: f32,
  gain: f32,
  angleGain: f32,
  gamma: f32,
  tanHalfFov: vec2f,
  innerThreshold: f32,
) -> vec4f {
  let color = textureSampleLevel(uSource, uSampler, sourceUv, 0.0);
  if (gain <= 0.0) {
    return color;
  }
  let depthUv = fitUv(sourceUv, resolution, imageResolution, fitMode);
  let depthVal = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;
  var mult = mix(1.0 - gain * 0.5, 1.0 + gain * 2.0, depthVal);
  if (angleGain > 0.0) {
    mult = mult * (1.0 + angleGain * rayAngleMask(depthUv, imageResolution, tanHalfFov, innerThreshold, gamma));
  }
  return vec4f(color.rgb * mult, color.a);
}

fn fieldPsfSource(
  sourceUv: vec2f,
  resolution: vec2f,
  imageResolution: vec2f,
  fitMode: f32,
  gain: f32,
  angleGain: f32,
  gamma: f32,
  tanHalfFov: vec2f,
  innerThreshold: f32,
  fieldMask: f32,
  fieldPsfGain: f32,
  fieldPsfRadiusPx: f32,
) -> vec4f {
  let center = weightedSource(sourceUv, resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold);
  if (fieldPsfGain <= 0.0 || fieldPsfRadiusPx <= 0.0 || fieldMask <= 0.0) {
    return center;
  }

  let px = vec2f(1.0 / max(resolution.x, 1.0), 1.0 / max(resolution.y, 1.0))
    * fieldPsfRadiusPx
    * fieldMask;
  let diag = px * 0.70710678;
  let card =
      weightedSource(sourceUv + vec2f( px.x, 0.0), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f(-px.x, 0.0), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f(0.0,  px.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f(0.0, -px.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold);
  let corner =
      weightedSource(sourceUv + vec2f( diag.x,  diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f( diag.x, -diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f(-diag.x,  diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold)
    + weightedSource(sourceUv + vec2f(-diag.x, -diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma, tanHalfFov, innerThreshold);
  let wide = (center * 4.0 + card * 2.0 + corner) / 16.0;
  return mix(center, wide, clamp(fieldPsfGain * fieldMask, 0.0, 1.0));
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
  let gain = clamp(uParams.misc.x, 0.0, 1.0);
  let fitMode = uParams.misc.y;
  let resolution = uParams.size.xy;
  let imageResolution = uParams.size.zw;
  let angleGain = max(uParams.misc.z, 0.0);
  let angleGamma = uParams.misc.w;
  let tanHalfFov = max(uParams.optics.xy, vec2f(1e-4));
  let innerThreshold = uParams.optics.z;
  let depthUv = fitUv(flipUv, resolution, imageResolution, fitMode);
  let fieldMask = rayAngleMask(depthUv, imageResolution, tanHalfFov, innerThreshold, angleGamma);
  return fieldPsfSource(
    flipUv,
    resolution,
    imageResolution,
    fitMode,
    gain,
    angleGain,
    angleGamma,
    tanHalfFov,
    innerThreshold,
    fieldMask,
    max(uParams.psf.x, 0.0),
    max(uParams.psf.y, 0.0),
  );
}
`;
