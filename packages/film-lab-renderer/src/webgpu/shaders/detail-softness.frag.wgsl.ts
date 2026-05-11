export const detailSoftnessFragmentWgsl = /* wgsl */ `
struct DetailSoftnessUniforms {
  // x: effectiveDetailSoftness, y: kernelRadiusPx,
  // z: chromaAttenScale, w: edgeGuardLo
  p0: vec4f,
  // x: edgeGuardHi, y: highlightBias,
  // z: inverse width, w: inverse height
  p1: vec4f,
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
  let edgeGuardLo = uParams.p0.w;
  let edgeGuardHi = uParams.p1.x;
  let highlightBias = uParams.p1.y;
  let texel = vec2f(uParams.p1.z, uParams.p1.w) * r;
  let lumaWeights = vec3f(0.2126, 0.7152, 0.0722);

  let srcRGB = center.rgb;
  let nR = textureSampleLevel(uSource, uSampler, uv + vec2f(texel.x, 0.0), 0.0).rgb;
  let nL = textureSampleLevel(uSource, uSampler, uv - vec2f(texel.x, 0.0), 0.0).rgb;
  let nU = textureSampleLevel(uSource, uSampler, uv + vec2f(0.0, texel.y), 0.0).rgb;
  let nD = textureSampleLevel(uSource, uSampler, uv - vec2f(0.0, texel.y), 0.0).rgb;

  let localRef = (srcRGB + nR + nL + nU + nD) * 0.2;
  let detail = srcRGB - localRef;

  let lumaCenter = luma709(srcRGB);
  let lumaGrad =
    abs(luma709(nR) - luma709(nL)) * 0.5 +
    abs(luma709(nU) - luma709(nD)) * 0.5;
  let edgeGuard = 1.0 - smoothstep(edgeGuardLo, edgeGuardHi, lumaGrad);
  let highlightWeight = mix(1.0, highlightBias, smoothstep(0.6, 0.9, lumaCenter));

  let lumaAtten = effective * edgeGuard * highlightWeight;
  let chromaAtten = lumaAtten * chromaAttenScale;
  let detailLuma = dot(detail, lumaWeights);
  let detailLumaVec = detailLuma * lumaWeights;
  let detailChroma = detail - detailLumaVec;
  let softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);
  return vec4f(softened, center.a);
}
`;
