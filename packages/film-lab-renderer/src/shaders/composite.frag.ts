/**
 * @fileoverview Film Lab Pass8 用フラグメントシェーダ（bloom / halation / vignette / grain / 分割）。
 * @description グレインは画像の cover 空間で径方向マスクを掛け、色収差 Pass1（rgbShiftSampleRadial）と同じ 1.65 べきで中心弱・周辺強にする。
 * uGrainRadialMix で一様（0）とフル径方向（1）をブレンドできる（Params.grainRadialMix、既定1）。
 * 色収差オン時の周辺ソフトは、混色量だけでなくブラー半径も少しだけ連動して増やす。
 * Params.lensSoftness（uLensSoftness）で rgbShift と独立に周辺の等方ブラーを足せる（Pro）。
 * 強度は控えめ（スライダー 100% でも周辺が潰れすぎないよう半径・混色を分離して足す）。
 * @limitations 分割表示時も vUv ベースでノイズを振る（従来どおり）。Remotion は本文字列を import 共有する。
 */
export const compositeFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uBloomTexture;
uniform sampler2D uHalationTexture;
uniform sampler2D uDiffusionTexture;
uniform sampler2D uOriginalTexture;

uniform float uBloomStrength;
uniform float uHalationIntensity;
uniform float uDiffusion;

uniform float uVignette;
uniform float uGrainIntensity;
/** 0=径方向マスク無し（一様）、1=フル周辺強め。mix(1.0, grainRadialWeight, clamp(値,0,1)) に用いる */
uniform float uGrainRadialMix;
/** 0=極細(高周波), 1=極粗(低周波)。Value noise の周波数スケーリングに使用 */
uniform float uGrainSize;
uniform float uTime;

uniform float uSplitPosition;
/** 0: Before/After（左は原画を coverUv でサンプル） / 1: A/B 比較（左は uOriginalTexture を vUv でサンプル＝スロット A の全パス結果） */
uniform float uAbCompare;
uniform vec2 uResolution;
uniform vec2 uImageResolution;
/** 色収差オン時の周辺のみシャープと微ブラーを混ぜる量（0〜1、JS 側で rgbShift に比例。大きいほどブラー半径も少し広げる） */
uniform float uAberrationEdgeSoften;
/** レンズの周辺ソフト（0〜1、Params.lensSoftness。色収差周辺ソフトとは別入力で合成する） */
uniform float uLensSoftness;

in vec2 vUv;
out vec4 fragColor;

vec2 coverUv(vec2 uv, vec2 resolution, vec2 imageResolution) {
  float screenAspect = resolution.x / resolution.y;
  float imageAspect = imageResolution.x / imageResolution.y;
  vec2 scale = screenAspect > imageAspect
    ? vec2(1.0, imageAspect / screenAspect)
    : vec2(screenAspect / imageAspect, 1.0);
  return (uv - 0.5) * scale + 0.5;
}

// --- Film Grain: Value Noise + Chroma/Luma Separation ---
float grainHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float grainNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f); // smoothstep interpolation
  float a = grainHash(i);
  float b = grainHash(i + vec2(1.0, 0.0));
  float c = grainHash(i + vec2(0.0, 1.0));
  float d = grainHash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y) - 0.5;
}

void main() {
  // 周辺だけごく弱いブラー（色収差と併せたフィルム的周辺柔らかさ）。
  // 色収差が強いほど、混色量に加えてサンプル半径も少しだけ広げる。
  vec2 edgeDelta = vUv - 0.5;
  edgeDelta.x *= uResolution.x / max(uResolution.y, 1.0);
  float edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);
  float edgeMask = smoothstep(0.25, 1.0, edgeR);
  vec3 sharpRgb = texture(uSource, vUv).rgb;
  // レンズ柔らかさ: 周辺ほど効く。べきを下げると内寄りにも効き、スライダーが「弱い」と言われたときの視認性が上がる。
  float lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);
  float lensW = pow(lensR, 1.52);
  // γ を下げるほど中間スライダーでも強く見える（最大 1.0 は維持）。
  float lensDrive = pow(clamp(uLensSoftness, 0.0, 1.0), 0.78);
  float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
  float aberrAmt = clamp(uAberrationEdgeSoften, 0.0, 1.0);
  // 8 タップのまま半径・混色を上げる（初版の 4px 張り付きよりは cap あり）。
  float blurRadiusPx =
    mix(1.5, 2.75, aberrAmt) + lensWeight * 1.35;
  blurRadiusPx = min(blurRadiusPx, 4.2);
  vec2 px =
    vec2(1.0 / max(uResolution.x, 1.0), 1.0 / max(uResolution.y, 1.0)) *
    blurRadiusPx;
  // 十字 4 タップだけだと HV 方向に振れ、細かい縞や葉で X 字っぽいモアレが出やすい。
  // 斜め 4 点を足して 8 方向平均にし、等方性を上げる（半径は 1/√2 スケールでカードナルと揃える）。
  vec2 d = px * 0.70710678;
  vec3 blurRgb =
    (texture(uSource, vUv + vec2(px.x, 0.0)).rgb +
     texture(uSource, vUv - vec2(px.x, 0.0)).rgb +
     texture(uSource, vUv + vec2(0.0, px.y)).rgb +
     texture(uSource, vUv - vec2(0.0, px.y)).rgb +
     texture(uSource, vUv + vec2(d.x, d.y)).rgb +
     texture(uSource, vUv + vec2(d.x, -d.y)).rgb +
     texture(uSource, vUv + vec2(-d.x, d.y)).rgb +
     texture(uSource, vUv + vec2(-d.x, -d.y)).rgb) *
    0.125;
  // 混色は色収差と同じく edgeMask。
  float lensMix = lensWeight * 0.72;
  float softenAmt = clamp(uAberrationEdgeSoften * edgeMask + lensMix * edgeMask, 0.0, 1.0);
  vec4 color = vec4(mix(sharpRgb, blurRgb, softenAmt), texture(uSource, vUv).a);

  // Bloom + Halation screen blend (no branching — strength=0 naturally zeros out)
  vec3 bloom = texture(uBloomTexture, vUv).rgb * uBloomStrength;
  vec3 halation = texture(uHalationTexture, vUv).rgb * uHalationIntensity;
  vec3 glow = bloom + halation;
  color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - glow);

  // --- Diffusion: Pro-Mist / Cinebloom full-image light scattering ---
  // Screen blend of blurred full image at controllable opacity.
  // The 0.45 multiplier prevents over-brightening at diffusion=1.0.
  // Unlike bloom (highlights only), diffusion scatters ALL light — creating
  // a soft haze that reduces contrast while preserving sharpness.
  if (uDiffusion > 0.0) {
    vec3 diffused = texture(uDiffusionTexture, vUv).rgb;
    vec3 diffScreen = 1.0 - (1.0 - color.rgb) * (1.0 - diffused * uDiffusion * 0.45);
    color.rgb = diffScreen;
  }

  // Vignette
  float dist = length(vUv - 0.5) * 1.414;
  float vig = 1.0 - uVignette * dist * dist;
  color.rgb *= clamp(vig, 0.0, 1.0);

  // Radial weight (unchanged logic — center weak, edge strong)
  vec2 grainCenterUv = coverUv(vUv, uResolution, uImageResolution);
  vec2 grainDelta = grainCenterUv - 0.5;
  grainDelta.x *= uImageResolution.x / max(uImageResolution.y, 1.0);
  float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
  float grainRadialWeight = pow(grainRadial, 1.65);
  float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(uGrainRadialMix, 0.0, 1.0));

  // Grain frequency from grainSize: 0=fine(high freq), 1=coarse(low freq)
  float lumaFreq = mix(500.0, 100.0, clamp(uGrainSize, 0.0, 1.0));
  float chromaFreq = lumaFreq * 0.7; // chroma crystals slightly larger
  float seed = floor(uTime * 24.0); // per-frame temporal variation

  // Pixel coordinate in noise space
  float pixelScale = max(uResolution.x, 1.0);
  vec2 lumaCoord = vUv * pixelScale / lumaFreq + seed * 7.13;
  vec2 chromaCoordR = vUv * pixelScale / chromaFreq + seed * 13.37 + 100.0;
  vec2 chromaCoordB = vUv * pixelScale / chromaFreq + seed * 23.71 + 200.0;

  // Luma grain (shared across RGB) + independent chroma grain (R, B only)
  float lumaGrain = grainNoise(lumaCoord);
  float chromaR = grainNoise(chromaCoordR) * 0.3; // chroma weight: 30%
  float chromaB = grainNoise(chromaCoordB) * 0.3;

  float w = uGrainIntensity * grainRadialEffective;
  color.r += (lumaGrain + chromaR) * w;
  color.g += lumaGrain * w;               // Green: luma only (eye most sensitive)
  color.b += (lumaGrain + chromaB) * w;
  color.rgb = clamp(color.rgb, 0.0, 1.0);

  // Before/After または A/B 比較の分割
  vec2 origUv = coverUv(vUv, uResolution, uImageResolution);
  vec4 leftSample = uAbCompare > 0.5
    ? texture(uOriginalTexture, vUv)
    : texture(uOriginalTexture, origUv);
  float lineWidth = 2.0 / uResolution.x;

  if (vUv.x < uSplitPosition - lineWidth) {
    fragColor = leftSample;
  } else if (vUv.x < uSplitPosition + lineWidth) {
    fragColor = vec4(1.0);
  } else {
    fragColor = color;
  }
}
`;
