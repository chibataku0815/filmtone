/**
 * composite.frag (WGSL) — Phase 2 T2-3 final display pass.
 *
 * Inputs: `uSource` (filmlab output, rgba16float), `uBloom` + `uHalation`
 * (accumulated pyramid outputs, rgba16float), `uGrain` (256×256 r8unorm
 * blue-noise tile sampled with a repeat sampler). Output goes straight to
 * the swap chain (`rgba8unorm-srgb`) so the hardware OETF handles the
 * linear→sRGB transform — no in-shader gamma math.
 *
 * Scope for v1.0 commit bundle (T2-0b + T2-3):
 *   - Bloom + halation screen-blend with soft shoulder (WebGL parity).
 *   - Image-space vignette.
 *   - Blue-noise grain (DIRECTION §2: pre-baked tile, no per-pixel hash).
 *     Radial weighting mirrors the WebGL `uGrainRadialMix` pattern.
 *
 * Deferred (Phase 3):
 *   - Split/A-B compare, diffusion (lazy 3-mip), lens softness blur,
 *     aberration edge soften, motion blur feedback, dust overlay.
 *
 * Bind group layout (DIRECTION §10 Phase 2 — 2 bind groups):
 *   - group(0) — frame flags (`vec4f`, currently unused here but kept
 *     for pipeline layout parity with filmlab/blit).
 *   - group(1) — per-frame uniforms + texture stack:
 *     binding(0) uComposite : Composite uniform struct (vec4-packed)
 *     binding(1) uSource    : texture_2d<f32>   (rt.colorGraded)
 *     binding(2) uBloom     : texture_2d<f32>   (rt.bloom full-res mip[0])
 *     binding(3) uHalation  : texture_2d<f32>   (rt.halation full-res mip[0])
 *     binding(4) uGrain     : texture_2d<f32>   (blue-noise 256² tile)
 *     binding(5) uSampler   : sampler           (linear, clamp-to-edge)
 *     binding(6) uGrainSamp : sampler           (linear, repeat)
 */
export const compositeFragmentWgsl = /* wgsl */ `
struct Composite {
  // (resolution.xy, imageResolution.xy)
  resolution: vec4f,
  // (bloomStrength, halationIntensity, vignette, grainIntensity)
  effects: vec4f,
  // (grainSize, grainRadialMix, fitMode, time)
  grainFit: vec4f,
};

@group(1) @binding(0) var<uniform> uComposite: Composite;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uBloom: texture_2d<f32>;
@group(1) @binding(3) var uHalation: texture_2d<f32>;
@group(1) @binding(4) var uGrain: texture_2d<f32>;
@group(1) @binding(5) var uSampler: sampler;
@group(1) @binding(6) var uGrainSampler: sampler;

const LUMA_R709 = vec3f(0.2126, 0.7152, 0.0722);

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

fn insideUv(uv: vec2f) -> f32 {
  let s = step(vec2f(0.0), uv) * step(uv, vec2f(1.0));
  return s.x * s.y;
}

// Soft shoulder: map HDR glow energy into a [0,1] screen-blend opacity so
// bloom + halation don't clip into flat white plates.
fn glowShoulder(energy: vec3f) -> vec3f {
  return vec3f(1.0) - exp(-max(energy, vec3f(0.0)));
}

fn glowHeadroom(baseRgb: vec3f, floorValue: f32) -> f32 {
  let luma = dot(baseRgb, LUMA_R709);
  let k = sqrt(clamp(1.0 - luma, 0.0, 1.0));
  return mix(floorValue, 1.0, k);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let resolution = uComposite.resolution.xy;
  let imageResolution = uComposite.resolution.zw;
  let bloomStrength = uComposite.effects.x;
  let halationIntensity = uComposite.effects.y;
  let vignette = uComposite.effects.z;
  let grainIntensity = uComposite.effects.w;
  let grainSize = uComposite.grainFit.x;
  let grainRadialMix = uComposite.grainFit.y;
  let fitMode = uComposite.grainFit.z;

  var color = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let baseRgb = color.rgb;

  // Bloom + halation screen-blend with soft shoulder (WebGL parity).
  let bloom = textureSampleLevel(uBloom, uSampler, uv, 0.0).rgb * bloomStrength;
  let halation = textureSampleLevel(uHalation, uSampler, uv, 0.0).rgb * halationIntensity;
  let glow = glowShoulder(bloom + halation) * glowHeadroom(baseRgb, 0.82);
  color = vec4f(vec3f(1.0) - (vec3f(1.0) - color.rgb) * (vec3f(1.0) - glow), color.a);

  // Vignette in image space (follows image frame).
  let vigUv = fitUv(uv, resolution, imageResolution, fitMode);
  let vigMask = insideUv(vigUv);
  let dist = length(vigUv - vec2f(0.5)) * 1.414;
  let vig = 1.0 - vignette * dist * dist;
  color = vec4f(color.rgb * mix(1.0, clamp(vig, 0.0, 1.0), vigMask), color.a);

  // Grain — blue-noise tile, radial weight, 256² repeat sampling.
  let grainCenterUv = fitUv(uv, resolution, imageResolution, fitMode);
  let grainBoundaryMask = insideUv(grainCenterUv);
  var grainDelta = grainCenterUv - vec2f(0.5);
  grainDelta.x = grainDelta.x * (imageResolution.x / max(imageResolution.y, 1.0));
  let grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
  // grainSize [0..1] modulates the effective radial fall-off exponent: at 0
  // (fine Velvia) the weight reaches mid-frame earlier, at 1 (clumpy HP5)
  // the grain concentrates at the edges. WebGL uses per-pixel hash + a
  // density clump; here the blue-noise tile already supplies even-dist
  // high-freq noise, so size just reshapes the radial envelope.
  let grainRadialWeight = pow(grainRadial, mix(1.2, 2.4, clamp(grainSize, 0.0, 1.0)));
  let grainRadialEffective = mix(1.0, grainRadialWeight, clamp(grainRadialMix, 0.0, 1.0));
  // Tile sampling — wrap via repeat sampler. 256² covers ~2k×1k frame in
  // 8×4 repeats, visually indistinguishable from per-pixel noise.
  let tileUv = uv * resolution / 256.0;
  let grainSample = textureSampleLevel(uGrain, uGrainSampler, tileUv, 0.0).r - 0.5;
  let grainWeight = grainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask;
  color = vec4f(color.rgb + vec3f(grainSample) * grainWeight, color.a);

  // rgba8unorm-srgb handles the final clamp + OETF automatically.
  return vec4f(color.rgb, 1.0);
}
`;
