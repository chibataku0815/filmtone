export const crossFilterTemporalFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uPrev;
uniform float uDecay;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec3 current = texture(uSource, vUv).rgb;
  vec3 prev = texture(uPrev, vUv).rgb;

  // Hard Mode should pick up new peaks immediately, but let them fade over a
  // few frames instead of hard-switching at the detection threshold.
  float prevMask = smoothstep(0.002, 0.03, luma709(prev));
  vec3 held = prev * (uDecay * prevMask);
  vec3 stabilized = max(current, held);

  fragColor = vec4(stabilized, 1.0);
}
`;
