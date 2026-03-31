export const bloomFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform float uBloomThreshold;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  float contribution = max(0.0, luma - uBloomThreshold);
  float knee = 0.1;
  contribution = smoothstep(0.0, knee, contribution);
  fragColor = vec4(color.rgb * contribution, 1.0);
}
`;
