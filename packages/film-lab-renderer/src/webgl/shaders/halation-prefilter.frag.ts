export const halationPrefilterFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec3 uHalationColor;
uniform float uThreshold;
uniform float uKnee;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

  float knee = max(uKnee * uThreshold, 1e-4);
  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);
  float contribution = t * t * mix(knee, 1.0, t);

  contribution = max(contribution, max(0.0, luma - uThreshold));

  vec3 halation = color.rgb * contribution * uHalationColor;
  fragColor = vec4(halation, 1.0);
}
`;
