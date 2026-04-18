export const crossFilterStreakDensityFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform vec2 uDirection;
uniform float uMinSpacing;

in vec2 vUv;
out vec4 fragColor;

const int DENSITY_SAMPLES = 32;
const float DENSITY_RADIUS_MAX = 96.0;  // texels at half-res
const float SELF_GAP = 2.0;
const int TANGENT_HALF_WIDTH = 2;
const float CROWD_GAIN = 8.0;

float sampleBandMax(sampler2D tex, vec2 uv, vec2 tangentStep) {
  float bandMax = 0.0;
  for (int j = -TANGENT_HALF_WIDTH; j <= TANGENT_HALF_WIDTH; j++) {
    vec2 sampleUv = uv + tangentStep * float(j);
    float lum = dot(texture(tex, sampleUv).rgb, vec3(0.2126, 0.7152, 0.0722));
    bandMax = max(bandMax, lum);
  }
  return bandMax;
}

void main() {
  vec3 center = texture(uSource, vUv).rgb;
  float centerLuma = dot(center, vec3(0.2126, 0.7152, 0.0722));
  if (centerLuma <= 1e-4) {
    fragColor = vec4(center, 1.0);
    return;
  }

  vec2 tangent = normalize(uDirection);
  vec2 normal = normalize(vec2(-uDirection.y, uDirection.x));
  vec2 tangentStep = tangent * uTexelSize;
  float radius = max(SELF_GAP, uMinSpacing * DENSITY_RADIUS_MAX);

  float neighborMax = 0.0;
  for (int i = 0; i < DENSITY_SAMPLES; i++) {
    float t = (float(i) + 0.5) / float(DENSITY_SAMPLES);
    float d = mix(SELF_GAP, radius, t);
    vec2 offset = normal * d * uTexelSize;
    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv + offset, tangentStep));
    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv - offset, tangentStep));
  }

  float crowd = neighborMax / centerLuma;
  float keep = 1.0 / (1.0 + crowd * CROWD_GAIN);
  float factor = mix(1.0, keep, step(0.001, uMinSpacing));

  fragColor = vec4(center * factor, 1.0);
}
`;
