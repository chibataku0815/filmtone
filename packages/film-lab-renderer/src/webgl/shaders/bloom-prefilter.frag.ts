export const bloomPrefilterFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform float uThreshold;
uniform float uKnee;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

  // Soft knee: quadratic ramp around threshold
  float knee = max(uKnee * uThreshold, 1e-4);
  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);
  float contribution = t * t * mix(knee, 1.0, t);

  // For pixels clearly above threshold, use full overshoot
  contribution = max(contribution, max(0.0, luma - uThreshold));

  fragColor = vec4(color.rgb * contribution, 1.0);
}
`;
