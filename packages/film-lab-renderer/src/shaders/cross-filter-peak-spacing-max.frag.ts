export const crossFilterPeakSpacingMaxFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform vec2 uAxis;
uniform float uRadiusPx;
uniform float uReadMetadata;

in vec2 vUv;
out vec4 fragColor;

const int MAX_RADIUS = 48;
const float RANK_LUMA_SCALE = 64.0;
const float RANK_TIE_BIAS = 0.1;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

float hash12(vec2 p) {
  vec2 ip = floor(p);
  float h = sin(dot(ip, vec2(127.1, 311.7))) * 43758.5453;
  return fract(h);
}

float rankPeak(vec3 color, vec2 pixelCoord) {
  float luma = luma709(color);
  if (luma <= 1e-4) return 0.0;
  return luma * RANK_LUMA_SCALE + hash12(pixelCoord) * RANK_TIE_BIAS;
}

void main() {
  vec2 pixelCoord = floor(vUv / uTexelSize + 0.5);
  vec2 maxCoord = max(vec2(0.0), floor(vec2(1.0) / uTexelSize) - 1.0);
  vec2 bestCoord = vec2(0.0);
  float bestRank = 0.0;

  for (int i = -MAX_RADIUS; i <= MAX_RADIUS; i++) {
    float fi = float(i);
    if (abs(fi) > uRadiusPx) continue;

    vec2 sampleCoord = clamp(pixelCoord + uAxis * fi, vec2(0.0), maxCoord);
    vec2 sampleUv = (sampleCoord + 0.5) * uTexelSize;
    vec4 sampleValue = texture(uSource, sampleUv);
    float sampleRank = 0.0;
    vec2 sampleWinnerCoord = vec2(0.0);
    if (uReadMetadata >= 0.5) {
      sampleWinnerCoord = floor(sampleValue.xy + 0.5);
      sampleRank = sampleValue.a;
    } else {
      sampleWinnerCoord = sampleCoord;
      sampleRank = rankPeak(sampleValue.rgb, sampleCoord);
    }

    if (sampleRank > bestRank) {
      bestRank = sampleRank;
      bestCoord = sampleWinnerCoord;
    }
  }

  fragColor = vec4(bestCoord, 0.0, bestRank);
}
`;
