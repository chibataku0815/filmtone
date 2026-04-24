/**
 * Halation depth prefilter (WGSL) — shared depth-aware source mask for the
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
 *   @binding(2) uDepth   : texture_2d<f32>  (shared depth texture, rgba8unorm)
 *   @binding(3) uSampler : sampler          (linear, clamp-to-edge)
 *
 * Output feeds the existing halation pyramid as its `sourceView`,
 * replacing the raw colorGraded view with a depth- and field-weighted source.
 */
export const halationDepthPrefilterFragmentWgsl = /* wgsl */ `
struct Params {
  // (gain, fitMode, rayAngleGain, rayAngleGamma)
  misc: vec4f,
  // (resolutionX, resolutionY, imageResX, imageResY)
  size: vec4f,
  // (fieldPsfGain, fieldPsfRadiusPx, _, _)
  psf: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uDepth: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

const RAY_ANGLE_TAN_HALF_HFOV: f32 = 0.6370702608; // tan(65deg / 2)

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

fn rayAngleMask(imageUv: vec2f, imageResolution: vec2f, gamma: f32) -> f32 {
  let aspectY = imageResolution.y / max(imageResolution.x, 1.0);
  let sensor = (imageUv - vec2f(0.5)) * 2.0;
  let ray = vec2f(
    sensor.x * RAY_ANGLE_TAN_HALF_HFOV,
    sensor.y * RAY_ANGLE_TAN_HALF_HFOV * aspectY,
  );
  let viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);
  let incidence = 1.0 - viewZ;
  let cornerRay = vec2f(RAY_ANGLE_TAN_HALF_HFOV, RAY_ANGLE_TAN_HALF_HFOV * aspectY);
  let maxIncidence = 1.0 - (1.0 / sqrt(dot(cornerRay, cornerRay) + 1.0));
  let normalized = clamp(incidence / max(maxIncidence, 1e-5), 0.0, 1.0);
  return smoothstep(0.15, 1.0, pow(normalized, max(gamma, 0.001)));
}

fn weightedSource(
  sourceUv: vec2f,
  resolution: vec2f,
  imageResolution: vec2f,
  fitMode: f32,
  gain: f32,
  angleGain: f32,
  gamma: f32,
) -> vec4f {
  let color = textureSampleLevel(uSource, uSampler, sourceUv, 0.0);
  if (gain <= 0.0) {
    return color;
  }
  let depthUv = fitUv(sourceUv, resolution, imageResolution, fitMode);
  let depthVal = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;
  var mult = mix(1.0 - gain * 0.25, 1.0 + gain * 0.5, depthVal);
  if (angleGain > 0.0) {
    mult = mult * (1.0 + angleGain * rayAngleMask(depthUv, imageResolution, gamma));
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
  fieldMask: f32,
  fieldPsfGain: f32,
  fieldPsfRadiusPx: f32,
) -> vec4f {
  let center = weightedSource(sourceUv, resolution, imageResolution, fitMode, gain, angleGain, gamma);
  if (fieldPsfGain <= 0.0 || fieldPsfRadiusPx <= 0.0 || fieldMask <= 0.0) {
    return center;
  }

  let px = vec2f(1.0 / max(resolution.x, 1.0), 1.0 / max(resolution.y, 1.0))
    * fieldPsfRadiusPx
    * fieldMask;
  let diag = px * 0.70710678;
  let card =
      weightedSource(sourceUv + vec2f( px.x, 0.0), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f(-px.x, 0.0), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f(0.0,  px.y), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f(0.0, -px.y), resolution, imageResolution, fitMode, gain, angleGain, gamma);
  let corner =
      weightedSource(sourceUv + vec2f( diag.x,  diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f( diag.x, -diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f(-diag.x,  diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma)
    + weightedSource(sourceUv + vec2f(-diag.x, -diag.y), resolution, imageResolution, fitMode, gain, angleGain, gamma);
  let wide = (center * 4.0 + card * 2.0 + corner) / 16.0;
  return mix(center, wide, clamp(fieldPsfGain * fieldMask, 0.0, 1.0));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  // Orientation-preserving fetch — see bloom-depth-prefilter for parity
  // rationale. +1 fullscreen pass would flip downstream halo; sampling at
  // (u, 1 - v) cancels the inherent framebuffer flip so this pass is net
  // zero and the halation pyramid parity is unchanged.
  let flipUv = vec2f(uv.x, 1.0 - uv.y);
  let gain = clamp(uParams.misc.x, 0.0, 1.0);
  let fitMode = uParams.misc.y;
  let resolution = uParams.size.xy;
  let imageResolution = uParams.size.zw;
  let angleGain = max(uParams.misc.z, 0.0);
  let angleGamma = uParams.misc.w;
  let depthUv = fitUv(flipUv, resolution, imageResolution, fitMode);
  let fieldMask = rayAngleMask(depthUv, imageResolution, angleGamma);
  return fieldPsfSource(
    flipUv,
    resolution,
    imageResolution,
    fitMode,
    gain,
    angleGain,
    angleGamma,
    fieldMask,
    max(uParams.psf.x, 0.0),
    max(uParams.psf.y, 0.0),
  );
}
`;
