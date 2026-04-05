export const lightshaftsFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uLightOrigin;
uniform float uDecay;
uniform float uDensity;
uniform float uExposure;

in vec2 vUv;
out vec4 fragColor;

const int NUM_SAMPLES = 64;
const float LUMINANCE_THRESHOLD = 0.65;

void main() {
  vec2 deltaUv = vUv - uLightOrigin;
  deltaUv *= 1.0 / float(NUM_SAMPLES) * uDensity;

  vec2 sampleUv = vUv;
  vec4 accum = vec4(0.0);
  float illuminationDecay = 1.0;

  for (int i = 0; i < NUM_SAMPLES; i++) {
    sampleUv -= deltaUv;
    vec4 s = texture(uSource, clamp(sampleUv, 0.0, 1.0));
    float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
    float contribution = smoothstep(LUMINANCE_THRESHOLD - 0.05, LUMINANCE_THRESHOLD + 0.05, luma);
    s.rgb *= contribution;
    s *= illuminationDecay;
    accum += s;
    illuminationDecay *= uDecay;
  }

  accum /= float(NUM_SAMPLES);
  fragColor = vec4(accum.rgb * uExposure, 1.0);
}
`;
