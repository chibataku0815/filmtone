/**
 * filmlab.frag (WGSL) — Phase 2 T2-1 + T2-2.
 *
 * Full v1.0 filmlab pipeline in Linear Rec.709 + rgba16float, following
 * DIRECTION §3 pipeline order: primary grade (exposure → film compression)
 * → Reinhard soft-shaper → LUT2 (Creative) → print CMY cast → print
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
  // (resolutionX, resolutionY, time, _pad)
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

// Luma-preserving sigmoid compression — DIRECTION §3 step 11/12. The
// WebGL original clamps the output to [0,1]; we drop that here because a
// wider range survives through T2-2 soft-shaper before LUT2.
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
  let lumaSafe = max(luma, 0.001);
  let lumaScale = select(1.0, mix(luma, s, amt) / lumaSafe, luma > 0.001);
  return rgb * lumaScale;
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

  // 12. Film compression — lumaScale only, no output clamp.
  let compAmount = uGrade.highlightsShadowsComp.z;
  let compRange = uGrade.highlightsShadowsComp.w;
  color = vec4f(applyFilmCompression(color.rgb, compAmount, compRange), color.a);

  // --- HDR boundary ---
  // 13. LUT2 (Creative) — the soft-shaper above prepares the bounded input
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

  // 14. Print CMY cast — C = -R, M = -G, Y = -B darkroom analog.
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

  // 15. Print contrast — final paper-hardness S-curve.
  let printContrast = uGrade.printContrastFit.x;
  color = vec4f(applyPrintContrast(color.rgb, printContrast), color.a);

  let mask = insideUv(fittedUv);
  // rgba16float output keeps values out-of-[0,1] alive; the final swap
  // blit (rgba8unorm-srgb hardware OETF) does the clamped display transform.
  return vec4f(color.rgb * mask, 1.0);
}
`;
