export const crossFilterBlendFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uStreak0;
uniform sampler2D uStreak1;
uniform sampler2D uStreak2;
uniform sampler2D uStreak3;
uniform sampler2D uCentralBloom;
uniform int uStreakCount;
uniform float uIntensity;
uniform float uHardMode;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 original = texture(uSource, vUv);
  vec3 streaks = texture(uStreak0, vUv).rgb + texture(uStreak1, vUv).rgb;
  if (uStreakCount > 2) streaks += texture(uStreak2, vUv).rgb;
  if (uStreakCount > 3) streaks += texture(uStreak3, vUv).rgb;
  streaks /= float(uStreakCount);

  // Phase 6: Hard Mode central bloom contribution.
  // uHardMode = 0.0 → bloom term is exactly vec3(0.0) → byte-for-byte Phase 5 backward compat.
  // uHardMode = 1.0 → adds blurred peak halo for the "thick base, soft glow" reference look.
  vec3 bloom = texture(uCentralBloom, vUv).rgb * uHardMode * 1.5;

  // Phase 7: Highlight Protection Mask (Hard Mode only).
  // Bright pixels in the original (light source centers) get the streak/bloom overlay attenuated
  // to prevent double-bright blow-out. uHardMode=0 → centerProtect=1.0 → Phase 6 unchanged.
  float origLuma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
  float centerProtect = mix(1.0, 1.0 - smoothstep(0.65, 0.95, origLuma), uHardMode);

  vec3 overlay = (streaks + bloom) * uIntensity * centerProtect;

  // Additive blend: preserves dark areas exactly (no shadow lifting).
  // Soft Reinhard rolloff on excess prevents harsh highlight clipping.
  vec3 combined = original.rgb + overlay;
  vec3 excess = max(combined - 1.0, vec3(0.0));
  vec3 result = combined - excess + excess / (1.0 + excess * 2.0);

  fragColor = vec4(result, original.a);
}
`;
