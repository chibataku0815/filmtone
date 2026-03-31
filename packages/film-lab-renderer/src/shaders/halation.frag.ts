export const halationFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec3 uHalationColor;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  float contribution = smoothstep(0.0, 0.2, max(0.0, luma - 0.6));
  vec3 halation = color.rgb * contribution * uHalationColor;
  fragColor = vec4(halation, 1.0);
}
`;
