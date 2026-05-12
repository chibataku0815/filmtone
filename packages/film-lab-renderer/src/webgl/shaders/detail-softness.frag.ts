export const detailSoftnessFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform float uEffectiveDetailSoftness;
uniform float uKernelRadiusPx;
uniform float uRangeSigma;
uniform float uDetailAmplitudeLo;
uniform float uDetailAmplitudeHi;
uniform float uChromaAttenScale;
uniform float uHighlightBias;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 center = texture(uSource, vUv);
  if (uEffectiveDetailSoftness < 0.0001) {
    fragColor = center;
    return;
  }

  float r = max(uKernelRadiusPx, 0.0001);
  float rd = r * 0.70710678;
  vec2 dx = vec2(uTexelSize.x * r, 0.0);
  vec2 dy = vec2(0.0, uTexelSize.y * r);
  vec2 dD1 = vec2(uTexelSize.x * rd,  uTexelSize.y * rd);
  vec2 dD2 = vec2(uTexelSize.x * rd, -uTexelSize.y * rd);

  vec3 srcRGB = center.rgb;
  vec3 nE  = texture(uSource, vUv + dx).rgb;
  vec3 nW  = texture(uSource, vUv - dx).rgb;
  vec3 nN  = texture(uSource, vUv + dy).rgb;
  vec3 nS  = texture(uSource, vUv - dy).rgb;
  vec3 nNE = texture(uSource, vUv + dD1).rgb;
  vec3 nNW = texture(uSource, vUv - dD2).rgb;
  vec3 nSE = texture(uSource, vUv + dD2).rgb;
  vec3 nSW = texture(uSource, vUv - dD1).rgb;

  vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);
  float lumaC  = dot(srcRGB, lumaWeights);
  float sigma2 = max(uRangeSigma * uRangeSigma, 1e-6);

  float dE  = dot(nE,  lumaWeights) - lumaC;
  float dW  = dot(nW,  lumaWeights) - lumaC;
  float dN  = dot(nN,  lumaWeights) - lumaC;
  float dS  = dot(nS,  lumaWeights) - lumaC;
  float dNE = dot(nNE, lumaWeights) - lumaC;
  float dNW = dot(nNW, lumaWeights) - lumaC;
  float dSE = dot(nSE, lumaWeights) - lumaC;
  float dSW = dot(nSW, lumaWeights) - lumaC;

  float wE  = exp(-(dE  * dE)  / sigma2);
  float wW  = exp(-(dW  * dW)  / sigma2);
  float wN  = exp(-(dN  * dN)  / sigma2);
  float wS  = exp(-(dS  * dS)  / sigma2);
  float wNE = exp(-(dNE * dNE) / sigma2);
  float wNW = exp(-(dNW * dNW) / sigma2);
  float wSE = exp(-(dSE * dSE) / sigma2);
  float wSW = exp(-(dSW * dSW) / sigma2);

  vec3 sumRGB = srcRGB
    + nE  * wE  + nW  * wW  + nN  * wN  + nS  * wS
    + nNE * wNE + nNW * wNW + nSE * wSE + nSW * wSW;
  float sumW = 1.0
    + wE + wW + wN + wS
    + wNE + wNW + wSE + wSW;

  vec3 ref = sumRGB / sumW;
  vec3 detail = srcRGB - ref;

  float detailLuma = dot(detail, lumaWeights);
  vec3 detailLumaVec = detailLuma * lumaWeights;
  vec3 detailChroma = detail - detailLumaVec;

  float detailMag = abs(detailLuma);
  float gate = 1.0 - smoothstep(uDetailAmplitudeLo, uDetailAmplitudeHi, detailMag);
  float highlightWeight = mix(1.0, uHighlightBias, smoothstep(0.6, 0.9, lumaC));

  float lumaAtten   = uEffectiveDetailSoftness * gate * highlightWeight;
  float chromaAtten = lumaAtten * uChromaAttenScale;

  vec3 softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);
  fragColor = vec4(softened, center.a);
}
`;
