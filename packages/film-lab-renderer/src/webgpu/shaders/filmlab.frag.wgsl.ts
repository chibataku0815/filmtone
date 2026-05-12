/**
 * filmlab.frag (WGSL) — Phase 2 T2-1 + T2-2.
 *
 * Full v1.0 filmlab pipeline in Linear Rec.709 + rgba16float, following
 * DIRECTION §3 pipeline order: primary grade (exposure → film compression
 * → shadow latitude) → Reinhard soft-shaper → LUT2 (Creative) → print CMY cast → print
 * contrast. No `clamp(0,1)` at any step; `max(x, 0.0)` guards sit in front
 * of pow/log/exp inputs per DIRECTION §10 Phase 2 default. LUT1
 * (Log→Linear input transform) is sampled before exposure; LUT2 sits after
 * the HDR primary-grade boundary with soft-shaper as the bounded input.
 *
 * Uniform layout (9 vec4 = 144 bytes, WGSL 16-byte aligned per DIRECTION
 * §4). See `packGradeUniforms` in `webgpu/gradeUniforms.ts` for the TS-side
 * packer.
 */
export const filmlabFragmentWgsl = /* wgsl */ `
struct Grade {
  // (exposure, contrast, saturation, _pad)
  exposureContrastSaturation: vec4f,
  // (temperature, tint, fade, rgbShift)
  temperatureTintFadeRgbShift: vec4f,
  // (highlights, shadows, compAmount, compRange)
  highlightsShadowsComp: vec4f,
  // (shadowTint.rgb, _pad)
  shadowTint: vec4f,
  // (highlightTint.rgb, _pad)
  highlightTint: vec4f,
  // (splitPosition, lut1Intensity, lut1Enabled, lut2Intensity)
  splitLut: vec4f,
  // (lut2Enabled, cyan, magenta, yellow)
  lut2PrintCmY: vec4f,
  // (printContrast, fitMode, imgResX, imgResY)
  printContrastFit: vec4f,
  // (resolutionX, resolutionY, time, shadowLatitude)
  resolutionTime: vec4f,
};

@group(1) @binding(0) var<uniform> uGrade: Grade;
@group(1) @binding(1) var uMedia: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;
@group(1) @binding(3) var uLUT1: texture_3d<f32>;
@group(1) @binding(4) var uLUT2: texture_3d<f32>;

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

fn rgbShiftRadial(uv: vec2f, amount: f32, imageResolution: vec2f) -> vec4f {
  var delta = uv - vec2f(0.5);
  delta.x = delta.x * (imageResolution.x / max(imageResolution.y, 1.0));
  let radial = clamp(length(delta) * 2.0, 0.0, 1.0);
  let weight = pow(max(radial, 0.0), 1.65);
  let amt = amount * weight;
  let dir = normalize(delta + vec2f(1e-5));
  let rCh = textureSampleLevel(uMedia, uSampler, uv + dir * amt, 0.0).r;
  let center = textureSampleLevel(uMedia, uSampler, uv, 0.0);
  let bCh = textureSampleLevel(uMedia, uSampler, uv - dir * amt, 0.0).b;
  return vec4f(rCh, center.g, bCh, center.a);
}

// Reinhard soft-shaper — DIRECTION §3 HDR-boundary entry. Smoothly
// compresses (≥0) HDR input toward [0, 1.5] before LUT2 sampling, so
// highlight detail carried out of the primary grade survives the LUT2
// lookup instead of hard-clipping at 1.0. k = 0.5 fixed (DIRECTION §10
// Phase 2; no UI knob in v1.0).
fn softShape(x: vec3f) -> vec3f {
  let safe = max(x, vec3f(0.0));
  let k = 0.5;
  return safe / (safe + vec3f(k)) * (1.0 + k);
}

// Print stage final S-curve contrast — WebGL parity, clamp removed so the
// final swap/composite blit handles the display-range clamp per DIRECTION
// §2 "no clamp in intermediate stages".
fn applyPrintContrast(rgb: vec3f, amount: f32) -> vec3f {
  if (amount < 0.001) {
    return rgb;
  }
  let k = mix(1.0, 5.0, amount);
  let x = clamp(-k * (rgb - vec3f(0.5)), vec3f(-6.0), vec3f(6.0));
  let s = vec3f(1.0) / (vec3f(1.0) + exp(x));
  return mix(rgb, s, amount);
}

fn filmCompressionWarmProtect(chroma: vec3f, mag: f32) -> f32 {
  if (mag <= 0.000001) {
    return 0.0;
  }
  let dir = chroma / mag;
  let redWarm = smoothstep(0.32, 0.72, dir.r);
  let blueOpposed = 1.0 - smoothstep(-0.58, -0.20, dir.b);
  let greenModerate = 1.0 - smoothstep(0.18, 0.58, abs(dir.g));
  return clamp(redWarm * blueOpposed * greenModerate, 0.0, 1.0);
}

// Film Compression V3: existing luma shoulder plus hue-preserving chroma
// density rolloff around the post-shoulder neutral axis. Output remains
// unclamped so wider values survive into the HDR-boundary soft shaper.
fn applyFilmCompression(rgb: vec3f, amount: f32, range: f32) -> vec3f {
  if (amount < 0.001) {
    return rgb;
  }
  let r = clamp(range, 0.0, 1.0);
  let k = mix(5.15, 2.85, r);
  let rangeSoft = smoothstep(0.82, 1.0, r);
  let amt = amount * (1.0 - 0.18 * rangeSoft);
  let luma = dot(rgb, LUMA_R709);
  // Clamp only the sigmoid *input*, not the output, so ultra-bright
  // pixels still pass through with gentle roll-off.
  let x = clamp(k * (luma - 0.5), -5.5, 5.5);
  let s = 1.0 / (1.0 + exp(-x));
  // One-sided shoulder: only roll highlights down, never lift shadows.
  // Without the min(), the symmetric sigmoid lifts deep blacks and boosts
  // their chroma — the opposite of the filmic density target.
  let shoulderY = min(luma, mix(luma, s, amt));
  let lumaSafe = max(luma, 0.001);
  let lumaScale = select(1.0, shoulderY / lumaSafe, luma > 0.001);
  let lumaCompressed = rgb * lumaScale;
  let chroma = lumaCompressed - vec3f(shoulderY);
  let chromaMag = length(chroma);

  let shadowRelease = smoothstep(0.14, 0.30, shoulderY);
  let kneeStart = mix(0.62, 0.42, r);
  let kneeEnd = mix(0.96, 0.78, r);
  let highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY);
  let chromaStress = smoothstep(0.16, 0.70, chromaMag);
  let maxChannel = max(max(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
  let minChannel = min(min(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
  let highEdgeStress = smoothstep(0.82, 1.08, maxChannel);
  let lowEdgeStress = smoothstep(0.82, 1.08, -minChannel);
  let gamutStress = max(highEdgeStress, lowEdgeStress)
    * chromaStress
    * smoothstep(0.08, 0.24, shoulderY);
  let warmProtect = filmCompressionWarmProtect(chroma, chromaMag);

  let highlightCompression = 0.42 * highlightMask * shadowRelease * mix(0.55, 1.0, chromaStress);
  let guardCompression = 0.22 * gamutStress * shadowRelease;
  let protectedCompression = (highlightCompression + guardCompression) * (1.0 - 0.35 * warmProtect);
  let chromaScale = clamp(1.0 - amt * protectedCompression, 0.0, 1.0);
  let landedChroma = chroma * chromaScale;
  var out = vec3f(shoulderY) + landedChroma;
  let outMax = max(max(out.r, out.g), out.b);
  let landingChroma = smoothstep(0.18, 0.62, chromaMag);
  let landingMask = smoothstep(0.78, 0.98, outMax)
    * landingChroma
    * shadowRelease
    * (1.0 - 0.35 * warmProtect);
  if (outMax > 0.78 && outMax > shoulderY + 0.000001) {
    let over = outMax - 0.78;
    let headroom = 0.22;
    let softMax = 0.78 + (headroom * over) / (over + headroom);
    let landingScale = clamp((softMax - shoulderY) / (outMax - shoulderY), 0.0, 1.0);
    let landingBlend = clamp(amt * 0.88 * landingMask, 0.0, 1.0);
    let finalScale = mix(1.0, landingScale, landingBlend);
    out = vec3f(shoulderY) + landedChroma * finalScale;
  }
  return out;
}

fn applyShadowLatitude(rgb: vec3f, amount: f32) -> vec3f {
  let amt = clamp(amount, 0.0, 1.0);
  if (amt < 0.001) {
    return rgb;
  }
  let y = dot(rgb, LUMA_R709);
  let blackProtect = smoothstep(0.025, 0.055, y);
  let release = 1.0 - smoothstep(0.18, 0.30, y);
  let band = blackProtect * release;
  if (band <= 0.000001) {
    return rgb;
  }
  let toeShape = max(0.0, 1.0 - y / 0.30);
  let lumaLift = y * toeShape * 0.22 * amt * band;
  let outY = y + lumaLift;
  let chromaScale = 1.0 + 0.08 * amt * band;
  let outColor = vec3f(outY) + (rgb - vec3f(y)) * chromaScale;
  return clamp(outColor, vec3f(0.0), vec3f(1.0));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let resolution = uGrade.resolutionTime.xy;
  let imageResolution = uGrade.printContrastFit.zw;
  let fitMode = uGrade.printContrastFit.y;
  let fittedUv = fitUv(uv, resolution, imageResolution, fitMode);

  // 1. media sample (sRGB → linear via hw EOTF on rgba8unorm-srgb).
  // 2. optional radial RGB shift.
  let rgbShift = uGrade.temperatureTintFadeRgbShift.w;
  var color = select(
    textureSampleLevel(uMedia, uSampler, fittedUv, 0.0),
    rgbShiftRadial(fittedUv, rgbShift, imageResolution),
    rgbShift > 0.0,
  );

  // 3. LUT1 — Log → Linear Rec.709. Clamp-to-edge is configured on the
  // shared sampler (DIRECTION §10 Phase 2) so the 0..1 domain is safe.
  let lut1Intensity = uGrade.splitLut.y;
  let lut1Enabled = uGrade.splitLut.z;
  if (lut1Enabled > 0.5) {
    let lut1Coord = clamp(color.rgb, vec3f(0.0), vec3f(1.0));
    let lut1Sample = textureSampleLevel(uLUT1, uSampler, lut1Coord, 0.0).rgb;
    color = vec4f(mix(color.rgb, lut1Sample, lut1Intensity), color.a);
  }

  // 4. Exposure — exp2 is safer than pow(2.0, x) under negative inputs.
  let exposure = uGrade.exposureContrastSaturation.x;
  color = vec4f(color.rgb * exp2(exposure), color.a);

  // 5. Contrast.
  let contrast = uGrade.exposureContrastSaturation.y;
  color = vec4f((color.rgb - vec3f(0.5)) * contrast + vec3f(0.5), color.a);

  // 6. Saturation.
  let saturation = uGrade.exposureContrastSaturation.z;
  let lumaSat = dot(color.rgb, LUMA_R709);
  color = vec4f(mix(vec3f(lumaSat), color.rgb, saturation), color.a);

  // 7. Temperature.
  let temperature = uGrade.temperatureTintFadeRgbShift.x;
  color = vec4f(
    color.r + temperature * 0.1,
    color.g,
    color.b - temperature * 0.1,
    color.a,
  );

  // 8. Tint (green / magenta).
  let tint = uGrade.temperatureTintFadeRgbShift.y;
  color = vec4f(
    color.r + tint * 0.05,
    color.g - tint * 0.08,
    color.b + tint * 0.05,
    color.a,
  );

  // 9. Split toning.
  let lumST = dot(color.rgb, LUMA_R709);
  let shadowTint = uGrade.shadowTint.rgb;
  let highlightTint = uGrade.highlightTint.rgb;
  color = vec4f(
    color.rgb + shadowTint * (1.0 - lumST) * 0.18 + highlightTint * lumST * 0.18,
    color.a,
  );

  // 10. Fade (Lift).
  let fade = uGrade.temperatureTintFadeRgbShift.z;
  color = vec4f(color.rgb + fade * (vec3f(1.0) - color.rgb), color.a);

  // 11. Highlights / Shadows.
  let highlights = uGrade.highlightsShadowsComp.x;
  let shadows = uGrade.highlightsShadowsComp.y;
  let lumHS = dot(color.rgb, LUMA_R709);
  color = vec4f(
    color.rgb + shadows * (1.0 - lumHS) * 0.5 + highlights * lumHS * 0.5,
    color.a,
  );

  // 12. Film compression V3 — luma shoulder + chroma density, no output clamp.
  let compAmount = uGrade.highlightsShadowsComp.z;
  let compRange = uGrade.highlightsShadowsComp.w;
  color = vec4f(applyFilmCompression(color.rgb, compAmount, compRange), color.a);

  // 13. Shadow latitude — toe separation without lifting the black anchor.
  let shadowLatitude = uGrade.resolutionTime.w;
  color = vec4f(applyShadowLatitude(color.rgb, shadowLatitude), color.a);

  // --- HDR boundary ---
  // 14. LUT2 (Creative) — the soft-shaper above prepares the bounded input
  // so highlight >1 values fold gently into the lookup domain instead of
  // hard-clipping. LUT2 output mixes back against the pre-shaped color so
  // LUT intensity keeps its usual "how creative" meaning.
  let lut2Intensity = uGrade.splitLut.w;
  let lut2Enabled = uGrade.lut2PrintCmY.x;
  if (lut2Enabled > 0.5) {
    let shaped = softShape(color.rgb);
    let lut2Coord = clamp(shaped, vec3f(0.0), vec3f(1.0));
    let lut2Sample = textureSampleLevel(uLUT2, uSampler, lut2Coord, 0.0).rgb;
    color = vec4f(mix(color.rgb, lut2Sample, lut2Intensity), color.a);
  }

  // 15. Print CMY cast — C = -R, M = -G, Y = -B darkroom analog.
  let cyan = uGrade.lut2PrintCmY.y;
  let magenta = uGrade.lut2PrintCmY.z;
  let yellow = uGrade.lut2PrintCmY.w;
  let cmyScale = 0.15;
  color = vec4f(
    color.r - cyan * cmyScale,
    color.g - magenta * cmyScale,
    color.b - yellow * cmyScale,
    color.a,
  );

  // 16. Print contrast — final paper-hardness S-curve.
  let printContrast = uGrade.printContrastFit.x;
  color = vec4f(applyPrintContrast(color.rgb, printContrast), color.a);

  let mask = insideUv(fittedUv);
  // rgba16float output keeps values out-of-[0,1] alive; the final swap
  // blit (rgba8unorm-srgb hardware OETF) does the clamped display transform.
  return vec4f(color.rgb * mask, 1.0);
}
`;
