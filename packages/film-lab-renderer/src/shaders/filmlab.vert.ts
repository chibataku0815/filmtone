export const filmlabVertexShader = /* glsl */ `
uniform float uFlipY;
out vec2 vUv;

void main() {
  vUv = vec2(uv.x, mix(uv.y, 1.0 - uv.y, uFlipY));
  gl_Position = vec4(position, 1.0);
}
`;
