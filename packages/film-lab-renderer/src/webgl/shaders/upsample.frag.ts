export const upsampleFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform float uWeight;

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
  // 9-tap tent upsampling (3x3)
  vec2 d = uTexelSize;

  vec4 s  = sampleMirror(uSource, vUv);
  vec4 s0 = sampleMirror(uSource, vUv + vec2(-d.x,  d.y));
  vec4 s1 = sampleMirror(uSource, vUv + vec2( 0.0,  d.y));
  vec4 s2 = sampleMirror(uSource, vUv + vec2( d.x,  d.y));
  vec4 s3 = sampleMirror(uSource, vUv + vec2(-d.x,  0.0));
  vec4 s4 = sampleMirror(uSource, vUv + vec2( d.x,  0.0));
  vec4 s5 = sampleMirror(uSource, vUv + vec2(-d.x, -d.y));
  vec4 s6 = sampleMirror(uSource, vUv + vec2( 0.0, -d.y));
  vec4 s7 = sampleMirror(uSource, vUv + vec2( d.x, -d.y));

  vec4 upsampled = s * 4.0
                 + (s1 + s3 + s4 + s6) * 2.0
                 + (s0 + s2 + s5 + s7) * 1.0;
  upsampled /= 16.0;

  // Output weighted contribution only — GL additive blending accumulates with existing RT data
  fragColor = upsampled * uWeight;
}
`;
