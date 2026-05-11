export const detailSoftnessFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform float uEffectiveDetailSoftness;
uniform float uKernelRadiusPx;
uniform float uChromaAttenScale;
uniform float uEdgeGuardLo;
uniform float uEdgeGuardHi;
uniform float uHighlightBias;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 rgb) {
  return dot(rgb, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec4 center = texture(uSource, vUv);
  if (uEffectiveDetailSoftness < 0.0001) {
    fragColor = center;
    return;
  }

  float r = max(uKernelRadiusPx, 0.0001);
  vec2 d = uTexelSize * r;
  vec3 srcRGB = center.rgb;
  vec3 nR = texture(uSource, vUv + vec2( d.x, 0.0)).rgb;
  vec3 nL = texture(uSource, vUv + vec2(-d.x, 0.0)).rgb;
  vec3 nU = texture(uSource, vUv + vec2(0.0,  d.y)).rgb;
  vec3 nD = texture(uSource, vUv + vec2(0.0, -d.y)).rgb;

  vec3 localRef = (srcRGB + nR + nL + nU + nD) * 0.2;
  vec3 detail = srcRGB - localRef;

  vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);
  float lumaCenter = luma709(srcRGB);
  float lumaGrad =
    abs(luma709(nR) - luma709(nL)) * 0.5 +
    abs(luma709(nU) - luma709(nD)) * 0.5;
  float edgeGuard = 1.0 - smoothstep(uEdgeGuardLo, uEdgeGuardHi, lumaGrad);
  float highlightWeight = mix(1.0, uHighlightBias, smoothstep(0.6, 0.9, lumaCenter));

  float lumaAtten = uEffectiveDetailSoftness * edgeGuard * highlightWeight;
  float chromaAtten = lumaAtten * uChromaAttenScale;
  float detailLuma = dot(detail, lumaWeights);
  vec3 detailLumaVec = detailLuma * lumaWeights;
  vec3 detailChroma = detail - detailLumaVec;
  vec3 softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);
  fragColor = vec4(softened, center.a);
}
`;
