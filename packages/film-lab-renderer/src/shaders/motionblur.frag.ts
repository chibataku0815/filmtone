export const motionblurFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uCurrentFrame;
uniform sampler2D uPrevAccum;
uniform float uAmount;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 current = texture(uCurrentFrame, vUv);
  vec4 prev = texture(uPrevAccum, vUv);
  fragColor = mix(current, prev, uAmount);
}
`;
