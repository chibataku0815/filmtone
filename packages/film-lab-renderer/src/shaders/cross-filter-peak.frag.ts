export const crossFilterPeakFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;

in vec2 vUv;
out vec4 fragColor;

const int RING_SAMPLES = 16;
const float RING_RADIUS = 24.0;

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
  float factor = smoothstep(0.0, 0.2, peakness);

  fragColor = center * factor;
}
`;
