export const detailSoftnessFragmentWgsl = /* wgsl */ `
struct DetailSoftnessUniforms {
  // x: effectiveDetailSoftness, y: kernelRadiusPx,
  // z: chromaAttenScale,         w: highlightBias
  p0: vec4f,
  // x: rangeSigma, y: detailAmplitudeLo,
  // z: detailAmplitudeHi, w: (reserved)
  p1: vec4f,
  // x: invWidth, y: invHeight, z: (reserved), w: (reserved)
  p2: vec4f,
};

@group(1) @binding(0) var<uniform> uParams: DetailSoftnessUniforms;
@group(1) @binding(1) var uSource: texture_2d<f32>;
@group(1) @binding(2) var uSampler: sampler;

fn luma709(rgb: vec3f) -> f32 {
  return dot(rgb, vec3f(0.2126, 0.7152, 0.0722));
}

@fragment
fn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {
  let center = textureSampleLevel(uSource, uSampler, uv, 0.0);
  let effective = uParams.p0.x;
  if (effective < 0.0001) {
    return center;
  }

  let r = max(uParams.p0.y, 0.0001);
  let chromaAttenScale = uParams.p0.z;
  let highlightBias = uParams.p0.w;
  let rangeSigma = uParams.p1.x;
  let detailAmplitudeLo = uParams.p1.y;
  let detailAmplitudeHi = uParams.p1.z;
  let texel = vec2f(uParams.p2.x, uParams.p2.y);
  let rd = r * 0.70710678;
  let dx = vec2f(texel.x * r, 0.0);
  let dy = vec2f(0.0, texel.y * r);
  let dD1 = vec2f(texel.x * rd,  texel.y * rd);
  let dD2 = vec2f(texel.x * rd, -texel.y * rd);
  let lumaWeights = vec3f(0.2126, 0.7152, 0.0722);

  let srcRGB = center.rgb;
  let nE  = textureSampleLevel(uSource, uSampler, uv + dx, 0.0).rgb;
  let nW  = textureSampleLevel(uSource, uSampler, uv - dx, 0.0).rgb;
  let nN  = textureSampleLevel(uSource, uSampler, uv + dy, 0.0).rgb;
  let nS  = textureSampleLevel(uSource, uSampler, uv - dy, 0.0).rgb;
  let nNE = textureSampleLevel(uSource, uSampler, uv + dD1, 0.0).rgb;
  let nNW = textureSampleLevel(uSource, uSampler, uv - dD2, 0.0).rgb;
  let nSE = textureSampleLevel(uSource, uSampler, uv + dD2, 0.0).rgb;
  let nSW = textureSampleLevel(uSource, uSampler, uv - dD1, 0.0).rgb;

  let lumaC = luma709(srcRGB);
  let sigma2 = max(rangeSigma * rangeSigma, 1e-6);

  let dE  = luma709(nE)  - lumaC;
  let dW  = luma709(nW)  - lumaC;
  let dN  = luma709(nN)  - lumaC;
  let dS  = luma709(nS)  - lumaC;
  let dNE = luma709(nNE) - lumaC;
  let dNW = luma709(nNW) - lumaC;
  let dSE = luma709(nSE) - lumaC;
  let dSW = luma709(nSW) - lumaC;

  let wE  = exp(-(dE  * dE)  / sigma2);
  let wW  = exp(-(dW  * dW)  / sigma2);
  let wN  = exp(-(dN  * dN)  / sigma2);
  let wS  = exp(-(dS  * dS)  / sigma2);
  let wNE = exp(-(dNE * dNE) / sigma2);
  let wNW = exp(-(dNW * dNW) / sigma2);
  let wSE = exp(-(dSE * dSE) / sigma2);
  let wSW = exp(-(dSW * dSW) / sigma2);

  let sumRGB = srcRGB
    + nE  * wE  + nW  * wW  + nN  * wN  + nS  * wS
    + nNE * wNE + nNW * wNW + nSE * wSE + nSW * wSW;
  let sumW = 1.0
    + wE + wW + wN + wS
    + wNE + wNW + wSE + wSW;

  let ref = sumRGB / sumW;
  let detail = srcRGB - ref;
  let detailLuma = dot(detail, lumaWeights);
  let detailLumaVec = detailLuma * lumaWeights;
  let detailChroma = detail - detailLumaVec;

  let detailMag = abs(detailLuma);
  let gate = 1.0 - smoothstep(detailAmplitudeLo, detailAmplitudeHi, detailMag);
  let highlightWeight = mix(1.0, highlightBias, smoothstep(0.6, 0.9, lumaC));

  let lumaAtten   = effective * gate * highlightWeight;
  let chromaAtten = lumaAtten * chromaAttenScale;

  let softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);
  return vec4f(softened, center.a);
}
`;
