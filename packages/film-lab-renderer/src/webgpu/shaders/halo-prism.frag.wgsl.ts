/**
 * Halo Prism (WGSL).
 *
 * Full-res post-composite pass. It draws large annular, chromatic arcs from
 * a compact highlight source texture so the look behaves like an optical
 * Halo / Split Halo filter rather than a fixed rainbow overlay.
 */
export const haloPrismFragmentWgsl = /* wgsl */ `
struct Params {
  // (strength, radius, width, chromatic)
  controls: vec4f,
  // (sourceReactivity, split, angleRad, _)
  sourceSplit: vec4f,
  // (resolutionX, resolutionY, imageResX, imageResY)
  size: vec4f,
  // (fitMode, threshold, _, _)
  fitAndGate: vec4f,
  // (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
  optics: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: Params;
@group(1) @binding(1) var uScene: texture_2d<f32>;
@group(1) @binding(2) var uCompactSource: texture_2d<f32>;
@group(1) @binding(3) var uDepth: texture_2d<f32>;
@group(1) @binding(4) var uSampler: sampler;

const LUMA_709: vec3f = vec3f(0.2126, 0.7152, 0.0722);
const RAY_ANGLE_REFERENCE_TAN_HALF_HFOV: f32 = 0.6370702608; // tan(65deg / 2)
const HALO_CENTER: vec2f = vec2f(0.5, 0.66);

struct SourceStats {
  centroid: vec2f,
  gate: f32,
  spread: f32,
  peak: f32,
};

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

fn rotate(p: vec2f, angle: f32) -> vec2f {
  let s = sin(angle);
  let c = cos(angle);
  return vec2f(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn luma(rgb: vec3f) -> f32 {
  return dot(rgb, LUMA_709);
}

fn maxRgb(rgb: vec3f) -> f32 {
  return max(rgb.r, max(rgb.g, rgb.b));
}

fn rayAngleMask(
  imageUv: vec2f,
  imageResolution: vec2f,
  tanHalfFov: vec2f,
  innerThreshold: f32,
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
  return smoothstep(clamp(innerThreshold, 0.0, 0.8), 1.0, pow(normalized, 1.35));
}

fn ringMask(r: f32, radius: f32, width: f32) -> f32 {
  let safeWidth = max(width, 0.003);
  let d = abs(r - radius);
  let core = exp(-(d * d) / (2.0 * safeWidth * safeWidth));
  let shoulder = exp(-(d * d) / (2.0 * safeWidth * safeWidth * 7.5)) * 0.055;
  return clamp(core + shoulder, 0.0, 1.0);
}

fn lensRadius(point: vec2f, center: vec2f, aspect: f32) -> f32 {
  var q = point - center;
  q.x = q.x * aspect;
  return length(q);
}

fn chromaticRing(r: f32, radius: f32, width: f32, chromatic: f32) -> vec3f {
  let chromaOffset = width * mix(0.45, 1.65, chromatic);
  let red = ringMask(r, radius - chromaOffset, width * 0.88);
  let white = ringMask(r, radius, width * 0.52);
  let cyan = ringMask(r, radius + chromaOffset, width * 0.88);
  let warmCore = ringMask(r, radius, width * 0.24) * 0.2;
  return vec3f(
    red * 0.86 + white * 0.92,
    white * 0.82 + cyan * 0.54,
    cyan * 0.96 + white * 0.62,
  ) + vec3f(1.0, 0.78, 0.52) * warmCore;
}

fn sourceSample(uv: vec2f) -> f32 {
  let gate = insideUv(uv);
  let rgb = textureSampleLevel(uCompactSource, uSampler, clamp(uv, vec2f(0.0), vec2f(1.0)), 0.0).rgb;
  return maxRgb(rgb) * gate;
}

fn sceneHighlightSample(uv: vec2f) -> f32 {
  let gate = insideUv(uv);
  let rgb = textureSampleLevel(uScene, uSampler, clamp(uv, vec2f(0.0), vec2f(1.0)), 0.0).rgb;
  let threshold = clamp(uParams.fitAndGate.y, 0.0, 1.0);
  let sceneThreshold = mix(0.0015, 0.035, threshold);
  let maxGate = smoothstep(sceneThreshold, sceneThreshold + 0.035, maxRgb(rgb));
  let lumaGate = smoothstep(sceneThreshold * 0.35, sceneThreshold * 0.35 + 0.025, luma(rgb));
  return maxRgb(rgb) * maxGate * lumaGate * gate;
}

fn sourceProbe(uv: vec2f) -> f32 {
  let compact = sourceSample(uv);
  let highlight = sceneHighlightSample(uv);
  return max(compact * 2.4, highlight * 1.15);
}

fn sourceProbeArea(uv: vec2f) -> f32 {
  let dx = vec2f(0.034, 0.0);
  let dy = vec2f(0.0, 0.034);
  var energy = sourceProbe(uv);
  energy = max(energy, sourceProbe(uv + dx));
  energy = max(energy, sourceProbe(uv - dx));
  energy = max(energy, sourceProbe(uv + dy));
  energy = max(energy, sourceProbe(uv - dy));
  return energy;
}

fn compactSourceProbeArea(uv: vec2f) -> f32 {
  let dx = vec2f(0.034, 0.0);
  let dy = vec2f(0.0, 0.034);
  var energy = sourceSample(uv);
  energy = max(energy, sourceSample(uv + dx));
  energy = max(energy, sourceSample(uv - dx));
  energy = max(energy, sourceSample(uv + dy));
  energy = max(energy, sourceSample(uv - dy));
  return energy;
}

fn stableSourceEnergy() -> f32 {
  var sum = 0.0;
  var peak = 0.0;
  var weightSum = 0.0;
  let e0 = sourceProbeArea(vec2f(0.18, 0.34));
  sum = sum + e0 * 0.72; peak = max(peak, e0); weightSum = weightSum + 0.72;
  let e1 = sourceProbeArea(vec2f(0.34, 0.34));
  sum = sum + e1 * 0.9; peak = max(peak, e1); weightSum = weightSum + 0.9;
  let e2 = sourceProbeArea(vec2f(0.50, 0.34));
  sum = sum + e2 * 1.0; peak = max(peak, e2); weightSum = weightSum + 1.0;
  let e3 = sourceProbeArea(vec2f(0.66, 0.34));
  sum = sum + e3 * 0.9; peak = max(peak, e3); weightSum = weightSum + 0.9;
  let e4 = sourceProbeArea(vec2f(0.82, 0.34));
  sum = sum + e4 * 0.72; peak = max(peak, e4); weightSum = weightSum + 0.72;
  let e5 = sourceProbeArea(vec2f(0.24, 0.48));
  sum = sum + e5 * 0.82; peak = max(peak, e5); weightSum = weightSum + 0.82;
  let e6 = sourceProbeArea(vec2f(0.42, 0.48));
  sum = sum + e6 * 1.0; peak = max(peak, e6); weightSum = weightSum + 1.0;
  let e7 = sourceProbeArea(vec2f(0.58, 0.48));
  sum = sum + e7 * 1.0; peak = max(peak, e7); weightSum = weightSum + 1.0;
  let e8 = sourceProbeArea(vec2f(0.76, 0.48));
  sum = sum + e8 * 0.82; peak = max(peak, e8); weightSum = weightSum + 0.82;
  let e9 = sourceProbeArea(vec2f(0.30, 0.62));
  sum = sum + e9 * 0.58; peak = max(peak, e9); weightSum = weightSum + 0.58;
  let e10 = sourceProbeArea(vec2f(0.50, 0.62));
  sum = sum + e10 * 0.68; peak = max(peak, e10); weightSum = weightSum + 0.68;
  let e11 = sourceProbeArea(vec2f(0.70, 0.62));
  sum = sum + e11 * 0.58; peak = max(peak, e11); weightSum = weightSum + 0.58;
  let average = sum / max(weightSum, 1e-4);
  return clamp(peak * 1.15 + average * 0.72, 0.0, 1.0);
}

fn sourceStats() -> SourceStats {
  let probes = array<vec3f, 15>(
    vec3f(0.16, 0.28, 0.46),
    vec3f(0.32, 0.28, 0.58),
    vec3f(0.50, 0.28, 0.66),
    vec3f(0.68, 0.28, 0.58),
    vec3f(0.84, 0.28, 0.46),
    vec3f(0.18, 0.43, 0.62),
    vec3f(0.34, 0.43, 0.84),
    vec3f(0.50, 0.43, 1.0),
    vec3f(0.66, 0.43, 0.84),
    vec3f(0.82, 0.43, 0.62),
    vec3f(0.22, 0.58, 0.46),
    vec3f(0.38, 0.58, 0.68),
    vec3f(0.50, 0.58, 0.74),
    vec3f(0.62, 0.58, 0.68),
    vec3f(0.78, 0.58, 0.46),
  );

  var sum = 0.0;
  var weighted = vec2f(0.0);
  var peak = 0.0;
  var weightSum = 0.0;
  for (var i = 0u; i < 15u; i = i + 1u) {
    let probe = probes[i];
    let sample = compactSourceProbeArea(probe.xy);
    let energy = sample * probe.z;
    sum = sum + energy;
    weighted = weighted + probe.xy * energy;
    peak = max(peak, sample);
    weightSum = weightSum + probe.z;
  }

  var centroid = vec2f(0.5, 0.5);
  if (sum > 1e-5) {
    centroid = weighted / sum;
  }

  var spreadSum = 0.0;
  for (var i = 0u; i < 15u; i = i + 1u) {
    let probe = probes[i];
    let sample = compactSourceProbeArea(probe.xy);
    let energy = sample * probe.z;
    let delta = (probe.xy - centroid) * vec2f(1.35, 1.0);
    spreadSum = spreadSum + length(delta) * energy;
  }

  let average = sum / max(weightSum, 1e-4);
  let compactCombined = clamp(peak * 1.15 + average * 0.72, 0.0, 1.0);
  // Compact extraction can blink around tiny highlights. Use the broader
  // scene-backed probe as the presence gate, and keep compact stats for shape.
  let combined = max(stableSourceEnergy() * 0.92, compactCombined * 0.75);
  let gate = clamp(pow(clamp(combined * 28.0, 0.0, 1.0), 0.42), 0.0, 1.0);
  let spread = clamp((spreadSum / max(sum, 1e-4)) * 4.2, 0.0, 1.0);
  return SourceStats(centroid, gate, spread, peak);
}

fn glowShoulder(energy: vec3f) -> vec3f {
  return vec3f(1.0) - exp(-max(energy, vec3f(0.0)));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let scene = textureSampleLevel(uScene, uSampler, uv, 0.0);
  let strength = clamp(uParams.controls.x, 0.0, 1.0);
  if (strength <= 0.0) {
    return scene;
  }

  let resolution = max(uParams.size.xy, vec2f(1.0));
  let imageResolution = max(uParams.size.zw, vec2f(1.0));
  let aspect = resolution.x / resolution.y;
  let fitMode = uParams.fitAndGate.x;
  let imageUv = fitUv(uv, resolution, imageResolution, fitMode);
  let imageInside = insideUv(imageUv);

  let haloUv = vec2f(uv.x, 1.0 - uv.y);
  let lensUv = HALO_CENTER + rotate(haloUv - HALO_CENTER, -uParams.sourceSplit.z);

  let radius = mix(0.17, 0.36, clamp(uParams.controls.y, 0.0, 1.0));
  let width = mix(0.0035, 0.018, clamp(uParams.controls.z, 0.0, 1.0));
  let chromatic = clamp(uParams.controls.w, 0.0, 1.0);
  let sourceReactivity = clamp(uParams.sourceSplit.x, 0.0, 1.0);
  let split = clamp(uParams.sourceSplit.y, 0.0, 1.0);

  let pairOffset = mix(0.035, 0.11, split);
  let leftRadius = lensRadius(lensUv, HALO_CENTER + vec2f(-pairOffset, 0.0), aspect);
  let rightRadius = lensRadius(lensUv, HALO_CENTER + vec2f(pairOffset, 0.0), aspect);
  let centerRadius = lensRadius(lensUv, HALO_CENTER, aspect);
  let primary = (
    chromaticRing(leftRadius, radius, width, chromatic)
    + chromaticRing(rightRadius, radius, width, chromatic)
  ) * 0.54;
  let secondary = (
    chromaticRing(leftRadius, radius * 0.86 + 0.018, width * 0.5, chromatic)
    + chromaticRing(rightRadius, radius * 0.86 + 0.018, width * 0.5, chromatic)
  ) * 0.08;
  let centerEcho = chromaticRing(centerRadius, radius * 1.03, width * 0.52, chromatic) * 0.035;
  var arcColor = primary + secondary + centerEcho;

  let stats = sourceStats();
  let sourceGate = stats.gate;
  let centeredSource = 1.0 - smoothstep(0.07, 0.22, abs(stats.centroid.x - 0.5));
  let compactSource = 1.0 - smoothstep(0.1, 0.34, stats.spread);
  let singleCenterAttenuation = mix(1.0, 0.52, centeredSource * compactSource);
  let reactiveGate = clamp(
    sourceGate * mix(0.82, 1.08, sourceReactivity) * singleCenterAttenuation,
    0.0,
    1.0,
  );

  let lowerBand = smoothstep(0.45, 0.58, lensUv.y)
    * (1.0 - smoothstep(0.92, 1.08, lensUv.y));
  let sideLift = smoothstep(0.14, 0.34, abs(lensUv.x - 0.5));
  let centerGap = mix(1.0, 0.52 + 0.48 * smoothstep(0.06, 0.26, abs(lensUv.x - 0.5)), split);
  let screenLower = smoothstep(0.46, 0.62, haloUv.y)
    * (1.0 - smoothstep(0.94, 1.04, haloUv.y));
  let screenCenterGap = mix(
    1.0,
    0.38 + 0.62 * smoothstep(0.08, 0.24, abs(uv.x - 0.5)),
    split,
  );
  let splitWindow = lowerBand
    * screenLower
    * mix(0.72, 1.0, sideLift)
    * centerGap
    * screenCenterGap;

  var centerDelta = haloUv - vec2f(0.5);
  centerDelta.x = centerDelta.x * aspect;
  let centerProtect = smoothstep(0.2, 0.66, length(centerDelta) * 1.28);
  let fieldMask = mix(0.04, 1.0, centerProtect);
  let rayMask = rayAngleMask(
    imageUv,
    imageResolution,
    max(uParams.optics.xy, vec2f(1e-4)),
    uParams.optics.z,
  );
  let depthVal = textureSampleLevel(uDepth, uSampler, clamp(imageUv, vec2f(0.0), vec2f(1.0)), 0.0).r;
  let depthMask = mix(0.9, 1.08, depthVal);

  let baseLuma = luma(scene.rgb);
  let headroom = mix(
    0.38,
    1.0,
    smoothstep(0.04, 0.96, pow(clamp(1.0 - baseLuma, 0.0, 1.0), 0.72)),
  );
  let opticalMask = imageInside
    * insideUv(lensUv)
    * splitWindow
    * mix(0.62, 1.08, rayMask)
    * depthMask
    * fieldMask
    * headroom;

  arcColor = max(arcColor, vec3f(0.0));
  let overlay = arcColor * (strength * reactiveGate * opticalMask * 0.82);
  let shoulder = glowShoulder(overlay);
  let screenBlend = vec3f(1.0) - (vec3f(1.0) - clamp(scene.rgb, vec3f(0.0), vec3f(1.0))) * (vec3f(1.0) - shoulder);
  let softAdd = scene.rgb + overlay * 0.14;
  let result = mix(softAdd, screenBlend, 0.42);

  return vec4f(max(result, vec3f(0.0)), scene.a);
}
`;
