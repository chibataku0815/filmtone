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
 *   - **Hybrid grain** — WebGL parity: low-end uses calmer fine-grain
 *     structured noise with weak chroma, while mid/high keeps the existing
 *     silver-halide per-pixel hash + clump modulation. `grainSize` blends
 *     between the two so 0.01–0.10 remains perceptually useful.
 *   - **Lens softness + aberration edge soften** — WebGL parity: 8-tap
 *     cross+diagonal blur on `uSource`, mixed into the base via an edge
 *     mask whose weight follows `uLensSoftness` and `uAberrationEdgeSoften`.
 *     Reproduces the WebGL "film-lens soft periphery" behaviour.
 *
 * Deferred:
 *   - Split / A-B compare, motion blur feedback (handled upstream in the
 *     backend), dust overlay, cross-filter streaks / shafts.
 *
 * Bind group layout (DIRECTION §10 Phase 2 — 2 bind groups):
 *   - group(0) — frame flags (`vec4f`, currently unused here but kept
 *     for pipeline layout parity with filmlab/blit).
 *   - group(1) — per-frame uniforms + texture stack:
 *     binding(0) uComposite : Composite uniform struct (vec4-packed)
 *     binding(1) uSource    : texture_2d<f32>   (rt.colorGraded)
 *     binding(2) uBloom     : texture_2d<f32>   (rt.bloom full-res mip[0])
 *     binding(3) uHalation  : texture_2d<f32>   (rt.halation full-res mip[0])
 *     binding(4) uDiffusion : texture_2d<f32>   (diffusion top mip,
 *                                                reusing the legacy grain
 *                                                texture slot to avoid a
 *                                                layout change)
 *     binding(5) uSampler   : sampler           (linear, clamp-to-edge)
 *     binding(6) uGrainSamp : sampler           (linear, repeat — also
 *                                                kept for layout parity).
 *     binding(7) uDepth     : texture_2d<f32>   (shared depth texture for
 *                                                Mist / Glow, populated by
 *                                                either the runtime depth
 *                                                track or the internal
 *                                                debug probe; 0=near / 1=far.
 *                                                Gated by uComposite.lens.w =
 *                                                depthMistGain).
 */
export const compositeFragmentWgsl = /* wgsl */ `
struct Composite {
  // (resolution.xy, imageResolution.xy)
  resolution: vec4f,
  // (bloomStrength, halationIntensity, vignette, grainIntensity)
  effects: vec4f,
  // (grainSize, grainRadialMix, fitMode, time)
  grainFit: vec4f,
  // (lensSoftness, aberrationEdgeSoften, diffusion, _)
  lens: vec4f,
};

@group(1) @binding(0) var<uniform> uComposite: Composite;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uBloom: texture_2d<f32>;
@group(1) @binding(3) var uHalation: texture_2d<f32>;
@group(1) @binding(4) var uDiffusion: texture_2d<f32>;
@group(1) @binding(5) var uSampler: sampler;
@group(1) @binding(6) var uGrainSampler: sampler;
@group(1) @binding(7) var uDepth: texture_2d<f32>;

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
// Coarse path uses the current per-pixel hash silver-halide look; low-end uses
// a calmer structured fine-grain basis and smoothly crossfades into coarse.
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

fn grainRotate(p: vec2f, angle: f32) -> vec2f {
  let s = sin(angle);
  let c = cos(angle);
  return vec2f(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn grainFineNoise(p: vec2f, fineScale: f32, seedA: f32, seedB: f32) -> f32 {
  let q0 = grainRotate(p * fineScale + vec2f(seedA * 0.37, seedB * 0.19), 0.61);
  let q1 = grainRotate(
    p * (fineScale * 1.41) + vec2f(seedB * 0.23 + 17.0, seedA * 0.41 + 9.0),
    -0.73,
  );
  let n0 = grainClumpNoise(q0) - 0.5;
  let n1 = grainClumpNoise(q1) - 0.5;
  return mix(n0, n1, 0.42);
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
  let diffusion = clamp(uComposite.lens.z, 0.0, 1.0);
  // Shared depth-aware Mist control:
  //   0.0      = no depth modulation (uniform mist, WebGL parity)
  //   0.0..1.0 = depth-modulated mist (near = 0x, far = (1 + 4*gain)x)
  //   >= 1.5   = internal debug view: render raw depth texture as grayscale
  //              (bypasses all subsequent stages — for alignment check only).
  let depthMistGain = clamp(uComposite.lens.w, 0.0, 2.0);

  // Debug view: show the depth texture directly over the image-space UV
  // so we can confirm the AI depth map is uploaded and aligned before
  // judging its effect on mist. The depth PNG is in IMAGE aspect, while
  // the canvas may be a different aspect — so sample in image-fit UV
  // (same transform vignette uses).
  if (depthMistGain >= 1.5) {
    let depthUv = fitUv(uv, uComposite.resolution.xy, uComposite.resolution.zw, uComposite.grainFit.z);
    let d = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;
    return vec4f(d, d, d, 1.0);
  }

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

  if (diffusion > 0.0) {
    // Shared depth-aware Mist path: depth shaping is now applied UPSTREAM, in
    // diffusion-depth-prefilter.frag, so the diffusion pyramid input is
    // already depth-weighted at the source before any blur. Composite
    // therefore just samples the pre-baked halo without a per-pixel depth
    // mask, which removes the ghost / double-image that appeared when a
    // sharp depth cut was applied after the pyramid had bled across
    // silhouettes. WebGL parity is preserved: when depthMistGain = 0 the
    // prefilter is skipped and the pyramid receives raw colorGraded.
    let diffused = textureSampleLevel(uDiffusion, uSampler, glowUv, 0.0).rgb;
    let diffOpacity = glowShoulder(diffused * diffusion * 0.29) * glowHeadroom(baseRgb, 0.88);
    color = vec4f(
      vec3f(1.0) - (vec3f(1.0) - color.rgb) * (vec3f(1.0) - diffOpacity),
      color.a,
    );
  }

  // Vignette in image space (follows image frame).
  let vigUv = fitUv(uv, resolution, imageResolution, fitMode);
  let vigMask = insideUv(vigUv);
  let dist = length(vigUv - vec2f(0.5)) * 1.414;
  let vig = 1.0 - vignette * dist * dist;
  color = vec4f(color.rgb * mix(1.0, clamp(vig, 0.0, 1.0), vigMask), color.a);

  // --- Grain: low-end fine grain + high-end clumped silver-halide hybrid ---
  let grainCenterUv = fitUv(uv, resolution, imageResolution, fitMode);
  let grainBoundaryMask = insideUv(grainCenterUv);
  var grainDelta = grainCenterUv - vec2f(0.5);
  grainDelta.x = grainDelta.x * (imageResolution.x / max(imageResolution.y, 1.0));
  let grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
  let grainRadialWeight = pow(grainRadial, 1.65);
  let grainRadialEffective = mix(1.0, grainRadialWeight, clamp(grainRadialMix, 0.0, 1.0));

  let grainSizeClamped = clamp(grainSize, 0.0, 1.0);
  let coarseBlend = smoothstep(0.08, 0.28, grainSizeClamped);

  // Deterministic temporal stepping for preview/export parity. Fine grain
  // updates a little more slowly than coarse grain to keep the low end calm.
  let grainFrame = floor(time * mix(2.0, 3.0, coarseBlend));

  let pixCoord = uv * resolution;
  let fineWarp = vec2f(
    grainClumpNoise(pixCoord / 96.0 + vec2f(11.7, grainFrame * 0.07 + 3.1)),
    grainClumpNoise(pixCoord / 96.0 + vec2f(grainFrame * 0.09 + 5.3, 23.4)),
  ) - vec2f(0.5);
  let fineCoord = pixCoord + fineWarp * 1.45;
  let fineScale = mix(1.75, 1.05, smoothstep(0.0, 0.25, grainSizeClamped));
  let fineLuma = grainFineNoise(
    fineCoord,
    fineScale,
    grainFrame * 1.13 + 7.0,
    grainFrame * 1.71 + 19.0,
  );
  let fineChromaStrength = mix(0.035, 0.16, smoothstep(0.02, 0.24, grainSizeClamped));
  let fineChromaR = grainFineNoise(
    fineCoord + vec2f(17.0, 0.0),
    fineScale * 1.07,
    grainFrame * 1.37 + 41.0,
    grainFrame * 1.91 + 67.0,
  ) * fineChromaStrength;
  let fineChromaB = grainFineNoise(
    fineCoord + vec2f(0.0, 19.0),
    fineScale * 1.11,
    grainFrame * 1.53 + 83.0,
    grainFrame * 2.07 + 109.0,
  ) * fineChromaStrength;

  // Coarse path preserves the current sharp per-pixel character.
  let coarseLuma = grainPixelHash(pixCoord, grainFrame * 1.7);
  let coarseChromaR = grainPixelHash(pixCoord, grainFrame * 2.3 + 500.0) * 0.3;
  let coarseChromaB = grainPixelHash(pixCoord, grainFrame * 3.1 + 1000.0) * 0.3;

  let fineDensity = mix(
    0.92,
    1.08,
    grainClumpNoise(pixCoord / 180.0 + vec2f(grainFrame * 0.11, 31.0)),
  );
  let clumpScale = mix(80.0, 20.0, grainSizeClamped);
  let coarseClump = grainClumpNoise(pixCoord / clumpScale + vec2f(grainFrame * 0.5));
  let coarseDensity = mix(1.0, 0.3 + coarseClump * 1.4, grainSizeClamped * 0.7);
  let densityMod = mix(fineDensity, coarseDensity, coarseBlend);

  let lumaGrain = mix(fineLuma, coarseLuma, coarseBlend);
  let chromaR = mix(fineChromaR, coarseChromaR, coarseBlend);
  let chromaB = mix(fineChromaB, coarseChromaB, coarseBlend);
  let lowEndPresence = mix(1.06, 1.0, coarseBlend);

  let grainWeight =
    grainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask * lowEndPresence;
  var rgb = color.rgb;
  rgb.r = rgb.r + (lumaGrain + chromaR) * grainWeight * densityMod;
  rgb.g = rgb.g + lumaGrain * grainWeight * densityMod;
  rgb.b = rgb.b + (lumaGrain + chromaB) * grainWeight * densityMod;
  color = vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), color.a);

  // Keep the legacy repeat sampler live so the bind-group layout does not
  // need to change even though grain is now procedural.
  let legacySamplerKeepalive = textureSampleLevel(uDiffusion, uGrainSampler, glowUv, 0.0).r;
  color = vec4f(color.rgb + vec3f(legacySamplerKeepalive) * 0.0, color.a);

  // rgba8unorm-srgb handles the final clamp + OETF automatically.
  return vec4f(color.rgb, 1.0);
}
`;
