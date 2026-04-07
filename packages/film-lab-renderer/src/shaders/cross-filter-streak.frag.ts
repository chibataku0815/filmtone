export const crossFilterStreakFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uDirection;
uniform vec2 uTexelSize;
uniform float uLength;
uniform float uChromatic;
uniform float uBrightnessMul;
uniform float uRandomness;
uniform float uHardMode;

in vec2 vUv;
out vec4 fragColor;

const int MAX_STREAK_PX = 64;
const float FALLOFF_K_SOFT  = 4.0;
const float FALLOFF_K_HARD  = 2.0;
const float STREAK_GAIN_SOFT = 2.5;
const float STREAK_GAIN_HARD = 6.0;
const float PEAK_THRESHOLD_SOFT = 0.01;
const float PEAK_THRESHOLD_HARD = 0.005;
const float CHROMA_HARD_FLOOR = 0.7;

// Wavelength dispersion spectrum.
// t = 0.0 -> near peak (warm: red/orange)  — matches reference "赤->橙->黄->緑->青"
// t = 0.5 -> mid streak (green/yellow)
// t = 1.0 -> far tip (cool: blue/violet)
// uChromatic = 0: white streak, uChromatic = 1: full rainbow
vec3 wavelengthToRGB(float t) {
  vec3 c;
  c.r = clamp(1.0 - t * 2.0, 0.0, 1.0);
  c.g = clamp(1.0 - abs(t - 0.45) * 3.2, 0.0, 1.0);
  c.b = clamp((t - 0.45) * 3.0, 0.0, 1.0);
  float maxC = max(c.r, max(c.g, c.b));
  return c / max(maxC, 1e-4);
}

void main() {
  // Phase 6: Hard Mode interpolated constants. uHardMode is always 0.0 (Soft) or 1.0 (Hard).
  // mix(softVal, hardVal, 0.0) = softVal → byte-for-byte Phase 5 backward compat.
  // MAX_STREAK_PX is restored to Phase 5 value (64) so Soft Mode behavior is bit-identical.
  // Hard Mode's "more dramatic" character comes from gain/falloff/threshold/bloom/tone-mapping
  // changes — NOT from longer streak marches (which would cause UV wrap on smaller images).
  float falloffK    = mix(FALLOFF_K_SOFT, FALLOFF_K_HARD, uHardMode);
  float streakGain  = mix(STREAK_GAIN_SOFT, STREAK_GAIN_HARD, uHardMode);
  float peakThresh  = mix(PEAK_THRESHOLD_SOFT, PEAK_THRESHOLD_HARD, uHardMode);
  float chromaEffective = mix(uChromatic, max(uChromatic, CHROMA_HARD_FLOOR), uHardMode);

  int maxSteps = int(uLength * float(MAX_STREAK_PX));
  maxSteps = clamp(maxSteps, 1, MAX_STREAK_PX);

  // Forward: march in -uDirection to find peaks that cast a streak through this pixel
  vec3 resultFwd = vec3(0.0);
  for (int i = 1; i <= MAX_STREAK_PX; i++) {
    if (i > maxSteps) break;
    vec2 sampleUV = vUv - uDirection * uTexelSize * float(i);
    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));
    if (peakLuma > peakThresh) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * falloffK / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);
      resultFwd = peakLuma * tint * falloff;
      break;
    }
  }

  // Backward: march in +uDirection to find peaks that cast a streak through this pixel
  vec3 resultBwd = vec3(0.0);
  for (int i = 1; i <= MAX_STREAK_PX; i++) {
    if (i > maxSteps) break;
    vec2 sampleUV = vUv + uDirection * uTexelSize * float(i);
    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));
    if (peakLuma > peakThresh) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * falloffK / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);
      resultBwd = peakLuma * tint * falloff;
      break;
    }
  }

  vec3 result = resultFwd + resultBwd;
  // Soft: Reinhard rolloff (= original Phase 5 behavior).
  // Hard: linear amplification → blown-out centers.
  vec3 toneSoft = 1.0 - exp(-result * streakGain * uBrightnessMul);
  vec3 toneHard = result * streakGain * uBrightnessMul;
  result = mix(toneSoft, toneHard, uHardMode);
  fragColor = vec4(result, 1.0);
}
`;
