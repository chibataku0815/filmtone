export const crossFilterStreakFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uDirection;
uniform vec2 uTexelSize;
uniform float uLength;
uniform float uChromatic;
uniform float uBrightnessMul;

in vec2 vUv;
out vec4 fragColor;

const int HALF_SAMPLES = 32;
const float MAX_STREAK_PX = 80.0;
const float FALLOFF_K = 8.0;
const float STREAK_GAIN = 4.0;

void main() {
  vec3 sum = vec3(0.0);
  vec2 stepUV = uDirection * uTexelSize * (uLength * MAX_STREAK_PX / float(HALF_SAMPLES));

  for (int i = -HALF_SAMPLES; i <= HALF_SAMPLES; i++) {
    float fi = float(i);
    float w = exp(-abs(fi) * FALLOFF_K / float(HALF_SAMPLES));
    float chromShift = fi * uChromatic * 0.18;
    vec2 baseOffset = stepUV * fi;

    float r = texture(uSource, vUv + baseOffset + stepUV * chromShift).r;
    float g = texture(uSource, vUv + baseOffset).g;
    float b = texture(uSource, vUv + baseOffset - stepUV * chromShift).b;

    sum += vec3(r, g, b) * w;
  }

  // Boost saturation — bright highlights are near-white in source,
  // amplify subtle color differences to reveal source tint
  float sumLuma = dot(sum, vec3(0.2126, 0.7152, 0.0722));
  sum = mix(vec3(sumLuma), sum, 5.0);
  sum = max(sum, vec3(0.0));

  sum = 1.0 - exp(-sum * STREAK_GAIN * uBrightnessMul);
  fragColor = vec4(sum, 1.0);
}
`;
