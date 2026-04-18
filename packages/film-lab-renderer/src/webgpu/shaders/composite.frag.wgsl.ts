/**
 * composite.frag (WGSL) — Phase 2 T2-3 final display pass.
 *
 * Inputs: `uSource` (filmlab output, rgba16float), `uBloom` + `uHalation`
 * (accumulated pyramid outputs, rgba16float). Output goes straight to the
 * swap chain (`rgba8unorm-srgb`) so the hardware OETF handles the
 * linear→sRGB transform — no in-shader gamma math.
 *
 * v1.0 parity port (2026-04-19):
 *   - Bloom + halation screen-blend with soft shoulder (WebGL parity).
 *   - **Bloom/halation are sampled with flipped uv.y**. The procedural
 *     fullscreen vertex shader derives uv from NDC y (`y*0.5 + 0.5`), which
 *     inverts texture rows once per render pass. The base reaches the swap
 *     chain after an even number of passes (media upload + filmlab +
 *     composite + blit); bloom/halation reach the swap chain after an odd
 *     number of passes (media + filmlab + prefilter + …pyramid… + composite
 *     + blit) and therefore arrive mirrored along y relative to the base.
 *     Sampling them at `(uv.x, 1.0 - uv.y)` re-aligns the glow with the
 *     base image without touching the pyramid or any upstream orientation.
 *   - Image-space vignette.
 *   - **Per-pixel grain** — WebGL parity: silver-halide per-pixel hash, per
 *     channel chroma/luma separation, low-frequency clump noise density
 *     modulation, and 3 Hz temporal stepping. Replaces the earlier blue-
 *     noise tile sampler (which looked too uniform / "smooth" to the user).
 *   - **Lens softness + aberration edge soften** — WebGL parity: 8-tap
 *     cross+diagonal blur on `uSource`, mixed into the base via an edge
 *     mask whose weight follows `uLensSoftness` and `uAberrationEdgeSoften`.
 *     Reproduces the WebGL "film-lens soft periphery" behaviour.
 *
 * Deferred:
 *   - Split / A-B compare, diffusion (lazy 3-mip), motion blur feedback
 *     (handled upstream in the backend), dust overlay, cross-filter
 *     streaks / shafts.
 *
 * Bind group layout (DIRECTION §10 Phase 2 — 2 bind groups):
 *   - group(0) — frame flags (`vec4f`, currently unused here but kept
 *     for pipeline layout parity with filmlab/blit).
 *   - group(1) — per-frame uniforms + texture stack:
 *     binding(0) uComposite : Composite uniform struct (vec4-packed)
 *     binding(1) uSource    : texture_2d<f32>   (rt.colorGraded)
 *     binding(2) uBloom     : texture_2d<f32>   (rt.bloom full-res mip[0])
 *     binding(3) uHalation  : texture_2d<f32>   (rt.halation full-res mip[0])
 *     binding(4) uGrain     : texture_2d<f32>   (legacy blue-noise tile,
 *                                                kept in the layout for
 *                                                compatibility; unused by
 *                                                the shader body now that
 *                                                grain is per-pixel).
 *     binding(5) uSampler   : sampler           (linear, clamp-to-edge)
 *     binding(6) uGrainSamp : sampler           (linear, repeat — also
 *                                                kept for layout parity).
 */
export const compositeFragmentWgsl = /* wgsl */ `
struct Composite {
  // (resolution.xy, imageResolution.xy)
  resolution: vec4f,
  // (bloomStrength, halationIntensity, vignette, grainIntensity)
  effects: vec4f,
  // (grainSize, grainRadialMix, fitMode, time)
  grainFit: vec4f,
  // (lensSoftness, aberrationEdgeSoften, _, _)
  lens: vec4f,
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

// --- Film grain (WebGL parity) ---
//
// Per-pixel hash: sharp, random, no grid artifacts — reproduces the sharp
// silver-halide look. Ported verbatim from webgl/shaders/composite.frag.ts.
fn grainPixelHash(p: vec2f, seed: f32) -> f32 {
  let s = sin(dot(p + vec2f(seed), vec2f(12.9898, 78.233))) * 43758.5453;
  return fract(s) - 0.5;
}

// Low-frequency smooth noise for grain density modulation (clumping).
fn grainClumpHash(p: vec2f) -> f32 {
  var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);
  p3 = p3 + vec3f(dot(p3, p3.yzx + vec3f(33.33)));
  return fract((p3.x + p3.y) * p3.z);
}

fn grainClumpNoise(p: vec2f) -> f32 {
  let i = floor(p);
  var f = fract(p);
  f = f * f * (vec2f(3.0) - 2.0 * f);
  let a = grainClumpHash(i);
  let b = grainClumpHash(i + vec2f(1.0, 0.0));
  let c = grainClumpHash(i + vec2f(0.0, 1.0));
  let d = grainClumpHash(i + vec2f(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
  let time = uComposite.grainFit.w;
  let lensSoftness = clamp(uComposite.lens.x, 0.0, 1.0);
  let aberrationEdgeSoften = clamp(uComposite.lens.y, 0.0, 1.0);

  // --- Lens softness + aberration edge soften (WebGL parity) ---
  // Edge mask weighting: periphery gets more of the 8-tap blur. Cardinal
  // vs diagonal directions are both used (8 taps total) to keep the soft
  // periphery isotropic instead of X-shaped.
  var edgeDelta = uv - vec2f(0.5);
  edgeDelta.x = edgeDelta.x * (resolution.x / max(resolution.y, 1.0));
  let edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);
  let edgeMask = smoothstep(0.25, 1.0, edgeR);
  let sharpRgb = textureSampleLevel(uSource, uSampler, uv, 0.0).rgb;
  let lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);
  let lensW = pow(lensR, 1.52);
  // γ < 1 so mid-slider positions stay visible (matches WebGL).
  let lensDrive = pow(lensSoftness, 0.78);
  let lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
  // Blur radius grows with aberration + lens softness. Capped to 4.2 px so
  // we don't smear fine detail even at slider 1.0.
  var blurRadiusPx = mix(1.5, 2.75, aberrationEdgeSoften) + lensWeight * 1.35;
  blurRadiusPx = min(blurRadiusPx, 4.2);
  let px = vec2f(1.0 / max(resolution.x, 1.0), 1.0 / max(resolution.y, 1.0)) * blurRadiusPx;
  let diag = px * 0.70710678;
  let blurRgb = (
      textureSampleLevel(uSource, uSampler, uv + vec2f(px.x, 0.0), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv - vec2f(px.x, 0.0), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv + vec2f(0.0, px.y), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv - vec2f(0.0, px.y), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv + vec2f(diag.x,  diag.y), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv + vec2f(diag.x, -diag.y), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv + vec2f(-diag.x,  diag.y), 0.0).rgb
    + textureSampleLevel(uSource, uSampler, uv + vec2f(-diag.x, -diag.y), 0.0).rgb
  ) * 0.125;
  let lensMix = lensWeight * 0.72;
  let softenAmt = clamp(aberrationEdgeSoften * edgeMask + lensMix * edgeMask, 0.0, 1.0);
  var color = vec4f(mix(sharpRgb, blurRgb, softenAmt), 1.0);
  let baseRgb = color.rgb;

  // Bloom + halation screen-blend with soft shoulder (WebGL parity).
  // Sample with flipped uv.y: bloom/halation accumulate an odd number of
  // fullscreen render passes relative to uSource, so their texture rows
  // arrive inverted along y. This single y-flip at sample time re-aligns
  // them with the base without touching the pyramid or the vertex shader.
  let glowUv = vec2f(uv.x, 1.0 - uv.y);
  let bloom = textureSampleLevel(uBloom, uSampler, glowUv, 0.0).rgb * bloomStrength;
  let halation = textureSampleLevel(uHalation, uSampler, glowUv, 0.0).rgb * halationIntensity;
  let glow = glowShoulder(bloom + halation) * glowHeadroom(baseRgb, 0.82);
  color = vec4f(vec3f(1.0) - (vec3f(1.0) - color.rgb) * (vec3f(1.0) - glow), color.a);

  // Vignette in image space (follows image frame).
  let vigUv = fitUv(uv, resolution, imageResolution, fitMode);
  let vigMask = insideUv(vigUv);
  let dist = length(vigUv - vec2f(0.5)) * 1.414;
  let vig = 1.0 - vignette * dist * dist;
  color = vec4f(color.rgb * mix(1.0, clamp(vig, 0.0, 1.0), vigMask), color.a);

  // --- Grain: per-pixel hash + per-channel chroma/luma + clump + 3 Hz temporal ---
  let grainCenterUv = fitUv(uv, resolution, imageResolution, fitMode);
  let grainBoundaryMask = insideUv(grainCenterUv);
  var grainDelta = grainCenterUv - vec2f(0.5);
  grainDelta.x = grainDelta.x * (imageResolution.x / max(imageResolution.y, 1.0));
  let grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
  let grainRadialWeight = pow(grainRadial, 1.65);
  let grainRadialEffective = mix(1.0, grainRadialWeight, clamp(grainRadialMix, 0.0, 1.0));

  // 3 Hz temporal stepping: each "grain frame" holds a stable pattern for
  // ~0.33 s — still images feel stable, video feels projected.
  let grainFrame = floor(time * 3.0);

  // Per-pixel hash keyed in absolute pixel coords so granularity is tied to
  // the presented resolution, not the image-space uv.
  let pixCoord = uv * resolution;
  let lumaGrain = grainPixelHash(pixCoord, grainFrame * 1.7);
  let chromaR = grainPixelHash(pixCoord, grainFrame * 2.3 + 500.0) * 0.3;
  let chromaB = grainPixelHash(pixCoord, grainFrame * 3.1 + 1000.0) * 0.3;

  // Clump density modulation: grainSize=0 → uniform fine grain, =1 →
  // pronounced clusters. clumpScale shrinks the zones as size grows.
  let grainSizeClamped = clamp(grainSize, 0.0, 1.0);
  let clumpScale = mix(80.0, 20.0, grainSizeClamped);
  let clump = grainClumpNoise(uv * resolution / clumpScale + vec2f(grainFrame * 0.5));
  let densityMod = mix(1.0, 0.3 + clump * 1.4, grainSizeClamped * 0.7);

  let grainWeight = grainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask * densityMod;
  var rgb = color.rgb;
  rgb.r = rgb.r + (lumaGrain + chromaR) * grainWeight;
  rgb.g = rgb.g + lumaGrain * grainWeight;
  rgb.b = rgb.b + (lumaGrain + chromaB) * grainWeight;
  color = vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), color.a);

  // Keep legacy grain bindings live so the pipeline layout matches the
  // bind-group entries set up in WebGPUBackend. Sampled but scaled to 0 so
  // it contributes nothing to the output.
  let legacyTile = textureSampleLevel(uGrain, uGrainSampler, uv, 0.0).r;
  color = vec4f(color.rgb + vec3f(legacyTile) * 0.0, color.a);

  // rgba8unorm-srgb handles the final clamp + OETF automatically.
  return vec4f(color.rgb, 1.0);
}
`;
