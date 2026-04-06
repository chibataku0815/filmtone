export const crossFilterBlendFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uStreak0;
uniform sampler2D uStreak1;
uniform sampler2D uStreak2;
uniform sampler2D uStreak3;
uniform int uStreakCount;
uniform float uIntensity;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 original = texture(uSource, vUv);
  vec3 streaks = texture(uStreak0, vUv).rgb + texture(uStreak1, vUv).rgb;
  if (uStreakCount > 2) streaks += texture(uStreak2, vUv).rgb;
  if (uStreakCount > 3) streaks += texture(uStreak3, vUv).rgb;
  streaks /= float(uStreakCount);
  vec3 overlay = streaks * uIntensity;
  vec3 result = 1.0 - (1.0 - original.rgb) * (1.0 - overlay);
  fragColor = vec4(result, original.a);
}
`;
