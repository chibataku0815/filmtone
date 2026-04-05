export const downsampleFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;

in vec2 vUv;
out vec4 fragColor;

void main() {
  // 13-tap tent downsample (Jimenez, "Next Generation Post Processing in CoD:AW")
  vec2 d = uTexelSize;

  //  a . b . c
  //  . d . e .
  //  f . g . h
  //  . i . j .
  //  k . l . m

  vec4 a = texture(uSource, vUv + vec2(-2.0 * d.x,  2.0 * d.y));
  vec4 b = texture(uSource, vUv + vec2( 0.0,         2.0 * d.y));
  vec4 c = texture(uSource, vUv + vec2( 2.0 * d.x,  2.0 * d.y));

  vec4 dd = texture(uSource, vUv + vec2(-d.x,  d.y));
  vec4 e  = texture(uSource, vUv + vec2( d.x,  d.y));

  vec4 f = texture(uSource, vUv + vec2(-2.0 * d.x, 0.0));
  vec4 g = texture(uSource, vUv);
  vec4 h = texture(uSource, vUv + vec2( 2.0 * d.x, 0.0));

  vec4 ii = texture(uSource, vUv + vec2(-d.x, -d.y));
  vec4 j  = texture(uSource, vUv + vec2( d.x, -d.y));

  vec4 k = texture(uSource, vUv + vec2(-2.0 * d.x, -2.0 * d.y));
  vec4 l = texture(uSource, vUv + vec2( 0.0,        -2.0 * d.y));
  vec4 m = texture(uSource, vUv + vec2( 2.0 * d.x, -2.0 * d.y));

  // Weighted average: 5 quads of 4 bilinear taps
  fragColor = (dd + e + ii + j) * 0.125
            + g * 0.125
            + (a + c + k + m) * 0.03125
            + (b + f + h + l) * 0.0625;
}
`;
