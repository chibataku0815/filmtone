export const crossFilterPeakSpacingFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uLocalMax;
uniform vec2 uTexelSize;
uniform float uMinSpacing;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec2 pixelCoord = floor(vUv / uTexelSize + 0.5);
  vec2 centerUv = (pixelCoord + 0.5) * uTexelSize;
  vec4 center = texture(uSource, centerUv);
  float centerLuma = luma709(center.rgb);
  if (centerLuma <= 1e-4 || uMinSpacing <= 1e-4) {
    fragColor = vec4(center.rgb, 1.0);
    return;
  }

  vec4 localMax = texture(uLocalMax, centerUv);
  vec2 winnerCoord = floor(localMax.xy + 0.5);
  bool keep =
    localMax.a > 0.0 &&
    abs(winnerCoord.x - pixelCoord.x) <= 0.25 &&
    abs(winnerCoord.y - pixelCoord.y) <= 0.25;

  fragColor = keep ? vec4(center.rgb, 1.0) : vec4(0.0, 0.0, 0.0, 1.0);
}
`;
