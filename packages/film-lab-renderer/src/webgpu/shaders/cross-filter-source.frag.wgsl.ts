/**
 * Cross-filter compact source extraction (WGSL).
 *
 * This pass replaces the old luma-only bloom prefilter for Cross Filter. It
 * keeps the existing user-facing threshold control, but only forwards compact
 * point lights / small specular highlights into the later peak and streak
 * chain. Broad windows, white walls, skin, and flame bodies are suppressed
 * before depth and ray-angle modulation are applied in the streak pass.
 */
export const crossFilterSourceFragmentWgsl = /* wgsl */ `
struct Params {
  // (lumaThreshold, knee, hardMode, _pad)
  thresholdAndMode: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);
const TAU: f32 = 6.283185307;
const LOCAL_PEAK_SAMPLES: i32 = 8;
const LOCAL_PEAK_RADIUS_PX: f32 = 3.0;
const LOCAL_PEAK_TOLERANCE: f32 = 0.035;
const DOG_SMALL_SAMPLES: i32 = 8;
const DOG_SMALL_RADIUS_PX: f32 = 2.0;
const DOG_LARGE_SAMPLES: i32 = 16;
const DOG_LARGE_RADIUS_PX: f32 = 12.0;
const DOG_LOW: f32 = 0.035;
const DOG_HIGH: f32 = 0.34;
const BROAD_SAMPLES: i32 = 16;
const BROAD_RADIUS_PX: f32 = 20.0;
const BROAD_LOW: f32 = 0.18;
const BROAD_HIGH: f32 = 0.58;
const BROAD_SUPPRESSION: f32 = 0.82;
const SOURCE_GAMMA: f32 = 1.15;

fn luma(rgb: vec3f) -> f32 {
  return dot(rgb, LUMA_709);
}

fn maxRgb(rgb: vec3f) -> f32 {
  return max(rgb.r, max(rgb.g, rgb.b));
}

fn sampleColor(uv: vec2f) -> vec3f {
  return textureSampleLevel(uSource, uSampler, uv, 0.0).rgb;
}

fn thresholdGateForColor(rgb: vec3f, threshold: f32, knee: f32, maxRgbThreshold: f32) -> f32 {
  let safeKnee = max(knee, 1e-4);
  let lumaGate = smoothstep(threshold, threshold + safeKnee, luma(rgb));
  let maxGate = smoothstep(maxRgbThreshold, maxRgbThreshold + safeKnee * 0.75, maxRgb(rgb));
  return max(lumaGate, maxGate);
}

fn ringAverageMaxRgb(uv: vec2f, texelSize: vec2f, radiusPx: f32, samples: i32) -> f32 {
  var sum: f32 = 0.0;
  for (var i: i32 = 0; i < 32; i = i + 1) {
    if (i >= samples) { break; }
    let angle = f32(i) * (TAU / f32(samples));
    let offset = vec2f(cos(angle), sin(angle)) * radiusPx * texelSize;
    sum = sum + maxRgb(sampleColor(uv + offset));
  }
  return sum / max(f32(samples), 1.0);
}

fn localMaxRgb(uv: vec2f, texelSize: vec2f, centerMax: f32) -> f32 {
  var localMax = centerMax;
  for (var i: i32 = 0; i < LOCAL_PEAK_SAMPLES; i = i + 1) {
    let angle = f32(i) * (TAU / f32(LOCAL_PEAK_SAMPLES));
    let offset = vec2f(cos(angle), sin(angle)) * LOCAL_PEAK_RADIUS_PX * texelSize;
    localMax = max(localMax, maxRgb(sampleColor(uv + offset)));
  }
  return localMax;
}

fn broadThresholdCoverage(
  uv: vec2f,
  texelSize: vec2f,
  threshold: f32,
  knee: f32,
  maxRgbThreshold: f32,
  centerGate: f32,
) -> f32 {
  var sum = centerGate;
  for (var i: i32 = 0; i < BROAD_SAMPLES; i = i + 1) {
    let angle = f32(i) * (TAU / f32(BROAD_SAMPLES));
    let offset = vec2f(cos(angle), sin(angle)) * BROAD_RADIUS_PX * texelSize;
    sum = sum + thresholdGateForColor(
      sampleColor(uv + offset),
      threshold,
      knee,
      maxRgbThreshold,
    );
  }
  return sum / f32(BROAD_SAMPLES + 1);
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let sourceSize = textureDimensions(uSource);
  let dims = vec2f(f32(sourceSize.x), f32(sourceSize.y));
  let texelSize = vec2f(1.0) / max(dims, vec2f(1.0));

  let threshold = clamp(uParams.thresholdAndMode.x, 0.0, 1.0);
  let knee = max(uParams.thresholdAndMode.y, 1e-4);
  let hardMode = clamp(uParams.thresholdAndMode.z, 0.0, 1.0);
  let maxRgbThreshold = min(0.98, threshold + mix(0.08, 0.04, hardMode));

  let center = sampleColor(uv);
  let centerMax = maxRgb(center);
  let thresholdGate = thresholdGateForColor(center, threshold, knee, maxRgbThreshold);

  let peakRatio = centerMax / max(localMaxRgb(uv, texelSize, centerMax), 1e-5);
  let peakGate = smoothstep(1.0 - LOCAL_PEAK_TOLERANCE, 1.0, peakRatio);

  let small = ringAverageMaxRgb(uv, texelSize, DOG_SMALL_RADIUS_PX, DOG_SMALL_SAMPLES);
  let large = ringAverageMaxRgb(uv, texelSize, DOG_LARGE_RADIUS_PX, DOG_LARGE_SAMPLES);
  let dogRatio = clamp((small - large) / max(small, 1e-5), 0.0, 1.0);
  let compactGate = smoothstep(DOG_LOW, DOG_HIGH, dogRatio);

  let broadArea = broadThresholdCoverage(
    uv,
    texelSize,
    threshold,
    knee,
    maxRgbThreshold,
    thresholdGate,
  );
  let broadPenalty = smoothstep(BROAD_LOW, BROAD_HIGH, broadArea);
  let broadSuppress = clamp(1.0 - BROAD_SUPPRESSION * broadPenalty, 0.0, 1.0);

  let mask = pow(
    clamp(thresholdGate * peakGate * compactGate * broadSuppress, 0.0, 1.0),
    SOURCE_GAMMA,
  );
  return vec4f(center * mask, 1.0);
}
`;
