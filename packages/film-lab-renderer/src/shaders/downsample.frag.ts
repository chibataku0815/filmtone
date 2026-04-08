export const downsampleFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;

in vec2 vUv;
out vec4 fragColor;

vec2 mirrorUv(vec2 uv) {
  vec2 tiled = mod(uv, 2.0);
  return 1.0 - abs(tiled - 1.0);
}

vec4 sampleMirror(sampler2D tex, vec2 uv) {
  return texture(tex, mirrorUv(uv));
}

void main() {
  // 13-tap tent downsample (Jimenez, "Next Generation Post Processing in CoD:AW")
  vec2 d = uTexelSize;

  //  a . b . c
  //  . d . e .
  //  f . g . h
  //  . i . j .
  //  k . l . m

  vec4 a = sampleMirror(uSource, vUv + vec2(-2.0 * d.x,  2.0 * d.y));
  vec4 b = sampleMirror(uSource, vUv + vec2( 0.0,         2.0 * d.y));
  vec4 c = sampleMirror(uSource, vUv + vec2( 2.0 * d.x,  2.0 * d.y));

  vec4 dd = sampleMirror(uSource, vUv + vec2(-d.x,  d.y));
  vec4 e  = sampleMirror(uSource, vUv + vec2( d.x,  d.y));

  vec4 f = sampleMirror(uSource, vUv + vec2(-2.0 * d.x, 0.0));
  vec4 g = sampleMirror(uSource, vUv);
  vec4 h = sampleMirror(uSource, vUv + vec2( 2.0 * d.x, 0.0));

  vec4 ii = sampleMirror(uSource, vUv + vec2(-d.x, -d.y));
  vec4 j  = sampleMirror(uSource, vUv + vec2( d.x, -d.y));

  vec4 k = sampleMirror(uSource, vUv + vec2(-2.0 * d.x, -2.0 * d.y));
  vec4 l = sampleMirror(uSource, vUv + vec2( 0.0,        -2.0 * d.y));
  vec4 m = sampleMirror(uSource, vUv + vec2( 2.0 * d.x, -2.0 * d.y));

  // Weighted average: 5 quads of 4 bilinear taps
  fragColor = (dd + e + ii + j) * 0.125
            + g * 0.125
            + (a + c + k + m) * 0.03125
            + (b + f + h + l) * 0.0625;
}
`;
