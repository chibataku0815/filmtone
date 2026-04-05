export const lightshaftsBlendFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uShaftTexture;
uniform float uIntensity;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec3 scene = texture(uSource, vUv).rgb;
  vec3 shafts = texture(uShaftTexture, vUv).rgb;
  vec3 result = scene + shafts * uIntensity;
  fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
`;
