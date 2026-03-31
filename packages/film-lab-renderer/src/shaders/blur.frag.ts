export const blurFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uDirection;
uniform vec2 uResolution;
uniform float uRadius;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec2 texelSize = 1.0 / uResolution;
  float sigma = max(uRadius * 20.0, 1.0);

  vec4 result = vec4(0.0);
  float totalWeight = 0.0;

  for (int i = -4; i <= 4; i++) {
    float offset = float(i);
    float weight = exp(-0.5 * (offset * offset) / (sigma * sigma));
    vec2 sampleUv = vUv + uDirection * texelSize * offset * sigma * 0.5;
    result += texture(uSource, clamp(sampleUv, 0.0, 1.0)) * weight;
    totalWeight += weight;
  }

  fragColor = result / totalWeight;
}
`;
