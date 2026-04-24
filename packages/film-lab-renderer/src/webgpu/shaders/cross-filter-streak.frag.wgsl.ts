/**
 * Cross-filter streak march (WGSL) — Soft Mode only for v1.0.
 *
 * Phase 3 T3-1. Ported from
 * `src/webgl/shaders/cross-filter-streak.frag.ts`. Hard Mode is gated in
 * the UI for v1.0 (DIRECTION §1 D5) — v1.0 always drives `uHardMode = 0.0`,
 * so the `mix(soft, hard, uHardMode)` branches collapse to Soft behavior.
 * Hard Mode values are kept in the shader for v1.1 forward-compat.
 *
 * Walks up to `MAX_STREAK_PX=64` texels in both +uDirection and
 * -uDirection. The first luma-above-threshold sample casts a streak
 * through the current pixel, tinted by the wavelength spectrum for
 * chromatic dispersion and attenuated by falloff.
 *
 * Depth/ray-angle shaping stays after the compact peak pass so broad
 * windows, white walls, skin, and candle bodies remain suppressed by the
 * existing local-maximum gate. Here it only modulates the accepted compact
 * source sample and the field-dependent streak response.
 */
export const crossFilterStreakFragmentWgsl = /* wgsl */ `
struct Params {
  // (direction.xy, texelSize.xy)
  dirAndTexel: vec4f,
  // (length, chromatic, brightnessMul, randomness)
  lengthAndChroma: vec4f,
  // (hardMode, depthGain, angleGain, angleGamma)
  hardModeAndDepth: vec4f,
  // (edgeLengthGain, edgeStrengthGain, fitMode, _)
  edgeAndFit: vec4f,
  // (resolutionX, resolutionY, imageResX, imageResY)
  size: vec4f,
  // (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
  optics: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uDepth: texture_2d<f32>;
@group(1) @binding(3) var uSampler: sampler;

const MAX_STREAK_PX: i32 = 64;
const FALLOFF_K_SOFT: f32 = 4.0;
const FALLOFF_K_HARD: f32 = 2.0;
const STREAK_GAIN_SOFT: f32 = 2.5;
const STREAK_GAIN_HARD: f32 = 6.0;
const PEAK_THRESHOLD_SOFT: f32 = 0.01;
const PEAK_THRESHOLD_HARD: f32 = 0.005;
const CHROMA_HARD_FLOOR: f32 = 0.7;
const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);
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

fn sourceWeight(
  sourceUv: vec2f,
  resolution: vec2f,
  imageResolution: vec2f,
  fitMode: f32,
  depthGain: f32,
  angleGain: f32,
  angleGamma: f32,
  tanHalfFov: vec2f,
  innerThreshold: f32,
) -> f32 {
  let depthUv = fitUv(sourceUv, resolution, imageResolution, fitMode);
  var depthMult = 1.0;
  if (depthGain > 0.0) {
    let depthVal = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;
    depthMult = mix(1.0 - depthGain * 0.3, 1.0 + depthGain * 0.8, depthVal);
  }
  let angleMult = 1.0 + max(angleGain, 0.0) * rayAngleMask(depthUv, imageResolution, tanHalfFov, innerThreshold, angleGamma);
  return depthMult * angleMult;
}

fn wavelengthToRGB(t: f32) -> vec3f {
  var c = vec3f(0.0);
  c.x = clamp(1.0 - t * 2.0, 0.0, 1.0);
  c.y = clamp(1.0 - abs(t - 0.45) * 3.2, 0.0, 1.0);
  c.z = clamp((t - 0.45) * 3.0, 0.0, 1.0);
  let maxC = max(c.x, max(c.y, c.z));
  return c / max(maxC, 1e-4);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let direction = uParams.dirAndTexel.xy;
  let texelSize = uParams.dirAndTexel.zw;
  let lengthParam = uParams.lengthAndChroma.x;
  let chromatic = uParams.lengthAndChroma.y;
  let brightnessMul = uParams.lengthAndChroma.z;
  let randomness = uParams.lengthAndChroma.w;
  let hardMode = uParams.hardModeAndDepth.x;
  let depthGain = uParams.hardModeAndDepth.y;
  let angleGain = uParams.hardModeAndDepth.z;
  let angleGamma = uParams.hardModeAndDepth.w;
  let edgeLengthGain = max(uParams.edgeAndFit.x, 0.0);
  let edgeStrengthGain = max(uParams.edgeAndFit.y, 0.0);
  let fitMode = uParams.edgeAndFit.z;
  let resolution = uParams.size.xy;
  let imageResolution = uParams.size.zw;
  let tanHalfFov = max(uParams.optics.xy, vec2f(1e-4));
  let innerThreshold = uParams.optics.z;
  let currentImageUv = fitUv(uv, resolution, imageResolution, fitMode);
  let currentFieldMask = rayAngleMask(currentImageUv, imageResolution, tanHalfFov, innerThreshold, angleGamma);
  let effectiveLength = lengthParam * (1.0 + edgeLengthGain * currentFieldMask);
  let effectiveBrightnessMul = brightnessMul * (1.0 + edgeStrengthGain * currentFieldMask);

  let falloffK = mix(FALLOFF_K_SOFT, FALLOFF_K_HARD, hardMode);
  let streakGain = mix(STREAK_GAIN_SOFT, STREAK_GAIN_HARD, hardMode);
  let peakThresh = mix(PEAK_THRESHOLD_SOFT, PEAK_THRESHOLD_HARD, hardMode);
  let chromaEffective = mix(chromatic, max(chromatic, CHROMA_HARD_FLOOR), hardMode);

  var maxSteps = i32(effectiveLength * f32(MAX_STREAK_PX));
  maxSteps = clamp(maxSteps, 1, MAX_STREAK_PX);

  var resultFwd = vec3f(0.0);
  for (var i: i32 = 1; i <= MAX_STREAK_PX; i = i + 1) {
    if (i > maxSteps) { break; }
    let sampleUV = uv - direction * texelSize * f32(i);
    let peakLuma = dot(textureSampleLevel(uSource, uSampler, sampleUV, 0.0).rgb, LUMA_709)
      * sourceWeight(sampleUV, resolution, imageResolution, fitMode, depthGain, angleGain, angleGamma, tanHalfFov, innerThreshold);
    if (peakLuma > peakThresh) {
      let cell = floor(sampleUV / texelSize);
      let peakHash = fract(sin(dot(cell, vec2f(127.1, 311.7))) * 43758.5453);
      if (peakHash > randomness) { break; }
      let t = f32(i) / f32(maxSteps);
      let falloff = exp(-f32(i) * falloffK / f32(maxSteps));
      let tint = mix(vec3f(1.0), wavelengthToRGB(t), chromaEffective);
      resultFwd = peakLuma * tint * falloff;
      break;
    }
  }

  var resultBwd = vec3f(0.0);
  for (var i: i32 = 1; i <= MAX_STREAK_PX; i = i + 1) {
    if (i > maxSteps) { break; }
    let sampleUV = uv + direction * texelSize * f32(i);
    let peakLuma = dot(textureSampleLevel(uSource, uSampler, sampleUV, 0.0).rgb, LUMA_709)
      * sourceWeight(sampleUV, resolution, imageResolution, fitMode, depthGain, angleGain, angleGamma, tanHalfFov, innerThreshold);
    if (peakLuma > peakThresh) {
      let cell = floor(sampleUV / texelSize);
      let peakHash = fract(sin(dot(cell, vec2f(127.1, 311.7))) * 43758.5453);
      if (peakHash > randomness) { break; }
      let t = f32(i) / f32(maxSteps);
      let falloff = exp(-f32(i) * falloffK / f32(maxSteps));
      let tint = mix(vec3f(1.0), wavelengthToRGB(t), chromaEffective);
      resultBwd = peakLuma * tint * falloff;
      break;
    }
  }

  let combined = resultFwd + resultBwd;
  let toneSoft = vec3f(1.0) - exp(-combined * streakGain * effectiveBrightnessMul);
  let toneHard = combined * streakGain * effectiveBrightnessMul;
  let result = mix(toneSoft, toneHard, hardMode);
  return vec4f(result, 1.0);
}
`;
