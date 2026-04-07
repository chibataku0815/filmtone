export const crossFilterPeakFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform float uSizeLimit;

in vec2 vUv;
out vec4 fragColor;

const int RING_SAMPLES = 16;
const float RING_RADIUS = 24.0;
const int NEIGHBOR_SAMPLES = 16;
const float NEIGHBOR_RADIUS = 8.0;
const float NEIGHBOR_THRESHOLD = 0.01;

void main() {
  vec4 center = texture(uSource, vUv);
  float centerLuma = dot(center.rgb, vec3(0.2126, 0.7152, 0.0722));

  float avgLuma = 0.0;
  for (int i = 0; i < RING_SAMPLES; i++) {
    float angle = float(i) * (6.28318 / float(RING_SAMPLES));
    vec2 offset = vec2(cos(angle), sin(angle)) * RING_RADIUS * uTexelSize;
    avgLuma += dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));
  }
  avgLuma /= float(RING_SAMPLES);

  float peakness = centerLuma - avgLuma;

  float neighborCount = 0.0;
  for (int i = 0; i < NEIGHBOR_SAMPLES; i++) {
    float angle = float(i) * (6.28318 / float(NEIGHBOR_SAMPLES));
    vec2 offset = vec2(cos(angle), sin(angle)) * NEIGHBOR_RADIUS * uTexelSize;
    float lum = dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));
    neighborCount += step(NEIGHBOR_THRESHOLD, lum);
  }

  float maxNeighbors = mix(float(NEIGHBOR_SAMPLES), 1.0, uSizeLimit);
  float densityFactor = 1.0 - smoothstep(maxNeighbors, maxNeighbors + 2.0, neighborCount);

  float factor = smoothstep(0.0, 0.2, peakness) * densityFactor;

  fragColor = center * factor;
}
`;
