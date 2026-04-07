export const crossFilterStreakFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uDirection;
uniform vec2 uTexelSize;
uniform float uLength;
uniform float uChromatic;
uniform float uBrightnessMul;
uniform float uRandomness;

in vec2 vUv;
out vec4 fragColor;

const int MAX_STREAK_PX = 64;
const float FALLOFF_K    = 4.0;
const float STREAK_GAIN  = 2.5;
const float PEAK_THRESHOLD = 0.01;

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
  int maxSteps = int(uLength * float(MAX_STREAK_PX));
  maxSteps = clamp(maxSteps, 1, MAX_STREAK_PX);

  // Forward: march in -uDirection to find peaks that cast a streak through this pixel
  vec3 resultFwd = vec3(0.0);
  for (int i = 1; i <= MAX_STREAK_PX; i++) {
    if (i > maxSteps) break;
    vec2 sampleUV = vUv - uDirection * uTexelSize * float(i);
    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));
    if (peakLuma > PEAK_THRESHOLD) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * FALLOFF_K / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), uChromatic);
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
    if (peakLuma > PEAK_THRESHOLD) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * FALLOFF_K / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), uChromatic);
      resultBwd = peakLuma * tint * falloff;
      break;
    }
  }

  vec3 result = resultFwd + resultBwd;
  result = 1.0 - exp(-result * STREAK_GAIN * uBrightnessMul);
  fragColor = vec4(result, 1.0);
}
`;
