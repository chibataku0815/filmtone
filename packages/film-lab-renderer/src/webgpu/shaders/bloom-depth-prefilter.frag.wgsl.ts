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
 * from this depth- and field-weighted intermediate.
 */
export const bloomDepthPrefilterFragmentWgsl = /* wgsl */ `
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
  var mult = mix(1.0 - gain * 0.3, 1.0 + gain * 0.8, depthVal);
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
  // Orientation-preserving fetch: bloom pyramid has 2N-1 fullscreen passes
  // (prefilter + downsamples + upsamples); composite samples bloom at
  // (u, 1 - v) assuming that existing parity. Inserting +1 pass flips
  // parity and mirrors the halo. Sampling source/depth at the y-flipped
  // input coord adds one offsetting flip so this pass is net zero and
  // downstream parity is unchanged.
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
