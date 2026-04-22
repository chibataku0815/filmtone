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
/** 0=極細/均一寄り、1=極粗/クランプ強め。low-end fine grain と high-end coarse grain の補間に使う */
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
uniform float uFitMode;
/** 1: グレーディングをスキップし、uSource(右) と uOriginalTexture(左) のスプリットのみ実行 */
uniform float uSplitOnly;

in vec2 vUv;
out vec4 fragColor;

vec2 fitUv(vec2 uv, vec2 resolution, vec2 imageResolution) {
  float screenAspect = resolution.x / resolution.y;
  float imageAspect = imageResolution.x / imageResolution.y;
  vec2 coverScale = screenAspect > imageAspect
    ? vec2(1.0, imageAspect / screenAspect)
    : vec2(screenAspect / imageAspect, 1.0);
  vec2 containScale = screenAspect > imageAspect
    ? vec2(screenAspect / imageAspect, 1.0)
    : vec2(1.0, imageAspect / screenAspect);
  vec2 scale = mix(coverScale, containScale, uFitMode);
  vec2 result = (uv - 0.5) * scale + 0.5;
  float narrowPortrait = step(2.0, scale.x) * uFitMode;
  result.x += 0.18 * scale.x * narrowPortrait;
  return result;
}

float insideUv(vec2 uv) {
  vec2 s = step(0.0, uv) * step(uv, vec2(1.0));
  return s.x * s.y;
}

// --- Film Grain: low-end fine grain + high-end clumped silver-halide hybrid ---

// Per-pixel hash: sharp, random, no grid artifacts — like actual silver halide crystals.
float grainPixelHash(vec2 p, float seed) {
  return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

// Low-frequency smooth noise for grain density modulation (clumping).
// Value noise is fine here because the scale is large (20-80px per cell) —
// grid artifacts are invisible at this frequency.
float grainClumpHash(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float grainClumpNoise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  float a = grainClumpHash(i);
  float b = grainClumpHash(i + vec2(1.0, 0.0));
  float c = grainClumpHash(i + vec2(0.0, 1.0));
  float d = grainClumpHash(i + vec2(1.0, 1.0));
  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 grainRotate(vec2 p, float angle) {
  float s = sin(angle);
  float c = cos(angle);
  return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float grainFineNoise(vec2 p, float fineScale, float seedA, float seedB) {
  vec2 q0 = grainRotate(p * fineScale + vec2(seedA * 0.37, seedB * 0.19), 0.61);
  vec2 q1 = grainRotate(
    p * (fineScale * 1.41) + vec2(seedB * 0.23 + 17.0, seedA * 0.41 + 9.0),
    -0.73
  );
  float n0 = grainClumpNoise(q0) - 0.5;
  float n1 = grainClumpNoise(q1) - 0.5;
  return mix(n0, n1, 0.42);
}

// Convert arbitrary glow energy into a bounded screen-blend opacity.
// Low values stay close to linear, while hot highlight cores compress softly
// so large radius / high strength can keep their spread without turning into
// flat white plates.
vec3 glowShoulder(vec3 energy) {
  return 1.0 - exp(-max(energy, vec3(0.0)));
}

float glowHeadroom(vec3 baseRgb, float floorValue) {
  float luma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));
  return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));
}

void main() {
  // Split-only モード: post-composite chain（モーションブラー等）適用後にスプリットを行う。
  // uSource にはブラー済みグレーディング出力、uOriginalTexture には原画が入る。
  if (uSplitOnly > 0.5) {
    vec2 origUv = fitUv(vUv, uResolution, uImageResolution);
    float splitMask = insideUv(origUv);
    vec4 leftSample = texture(uOriginalTexture, origUv);
    vec4 rightSample = texture(uSource, vUv);
    float lineWidth = 2.0 / uResolution.x;

    if (vUv.x < uSplitPosition - lineWidth) {
      fragColor = mix(rightSample, leftSample, splitMask);
    } else if (vUv.x < uSplitPosition + lineWidth) {
      fragColor = vec4(vec3(1.0), rightSample.a) * splitMask + rightSample * (1.0 - splitMask);
    } else {
      fragColor = rightSample;
    }
    return;
  }

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
  vec3 baseRgb = color.rgb;

  // Bloom + Halation screen blend with a soft shoulder.
  // This preserves wide glow tails at high radius while compressing hot cores.
  vec3 bloom = texture(uBloomTexture, vUv).rgb * uBloomStrength;
  vec3 halation = texture(uHalationTexture, vUv).rgb * uHalationIntensity;
  vec3 glow = glowShoulder(bloom + halation) * glowHeadroom(baseRgb, 0.82);
  color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - glow);

  // --- Diffusion: Pro-Mist / Cinebloom full-image light scattering ---
  // Screen blend of blurred full image at controllable opacity.
  // The 0.45 multiplier prevents over-brightening at diffusion=1.0.
  // Unlike bloom (highlights only), diffusion scatters ALL light — creating
  // a soft haze that reduces contrast while preserving sharpness.
  if (uDiffusion > 0.0) {
    vec3 diffused = texture(uDiffusionTexture, vUv).rgb;
    vec3 diffOpacity = glowShoulder(diffused * uDiffusion * 0.29) * glowHeadroom(baseRgb, 0.88);
    vec3 diffScreen = 1.0 - (1.0 - color.rgb) * (1.0 - diffOpacity);
    color.rgb = diffScreen;
  }

  // Vignette in image space (follows image frame, not screen edges)
  vec2 vigUv = fitUv(vUv, uResolution, uImageResolution);
  float vigMask = insideUv(vigUv);
  float dist = length((vigUv - 0.5)) * 1.414;
  float vig = 1.0 - uVignette * dist * dist;
  color.rgb *= mix(1.0, clamp(vig, 0.0, 1.0), vigMask);

  // Radial weight (unchanged logic — center weak, edge strong)
  vec2 grainCenterUv = fitUv(vUv, uResolution, uImageResolution);
  float grainBoundaryMask = insideUv(grainCenterUv);
  vec2 grainDelta = grainCenterUv - 0.5;
  grainDelta.x *= uImageResolution.x / max(uImageResolution.y, 1.0);
  float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);
  float grainRadialWeight = pow(grainRadial, 1.65);
  float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(uGrainRadialMix, 0.0, 1.0));

  float grainSizeClamped = clamp(uGrainSize, 0.0, 1.0);
  float coarseBlend = smoothstep(0.08, 0.28, grainSizeClamped);

  // Temporal stepping stays deterministic for preview/export parity. Fine grain
  // holds slightly longer than coarse grain so the low end reads calmer.
  float grainFrame = floor(uTime * mix(2.0, 3.0, coarseBlend));

  vec2 pixCoord = vUv * uResolution;
  vec2 fineWarp = vec2(
    grainClumpNoise(pixCoord / 96.0 + vec2(11.7, grainFrame * 0.07 + 3.1)),
    grainClumpNoise(pixCoord / 96.0 + vec2(grainFrame * 0.09 + 5.3, 23.4))
  ) - 0.5;
  vec2 fineCoord = pixCoord + fineWarp * 1.45;
  float fineScale = mix(1.75, 1.05, smoothstep(0.0, 0.25, grainSizeClamped));
  float fineLuma = grainFineNoise(
    fineCoord,
    fineScale,
    grainFrame * 1.13 + 7.0,
    grainFrame * 1.71 + 19.0
  );
  float fineChromaStrength = mix(0.035, 0.16, smoothstep(0.02, 0.24, grainSizeClamped));
  float fineChromaR = grainFineNoise(
    fineCoord + vec2(17.0, 0.0),
    fineScale * 1.07,
    grainFrame * 1.37 + 41.0,
    grainFrame * 1.91 + 67.0
  ) * fineChromaStrength;
  float fineChromaB = grainFineNoise(
    fineCoord + vec2(0.0, 19.0),
    fineScale * 1.11,
    grainFrame * 1.53 + 83.0,
    grainFrame * 2.07 + 109.0
  ) * fineChromaStrength;

  // Coarse path preserves the existing sharp per-pixel silver-halide character.
  float coarseLuma = grainPixelHash(pixCoord, grainFrame * 1.7);
  float coarseChromaR = grainPixelHash(pixCoord, grainFrame * 2.3 + 500.0) * 0.3;
  float coarseChromaB = grainPixelHash(pixCoord, grainFrame * 3.1 + 1000.0) * 0.3;

  // Low-end grain now changes actual frequency/distribution instead of only
  // clump density. High-end stays on the existing cluster-driven path.
  float fineDensity = mix(
    0.92,
    1.08,
    grainClumpNoise(pixCoord / 180.0 + vec2(grainFrame * 0.11, 31.0))
  );
  float clumpScale = mix(80.0, 20.0, grainSizeClamped);
  float coarseClump = grainClumpNoise(pixCoord / clumpScale + vec2(grainFrame * 0.5));
  float coarseDensity = mix(1.0, 0.3 + coarseClump * 1.4, grainSizeClamped * 0.7);
  float densityMod = mix(fineDensity, coarseDensity, coarseBlend);

  float lumaGrain = mix(fineLuma, coarseLuma, coarseBlend);
  float chromaR = mix(fineChromaR, coarseChromaR, coarseBlend);
  float chromaB = mix(fineChromaB, coarseChromaB, coarseBlend);
  float lowEndPresence = mix(1.06, 1.0, coarseBlend);

  float w = uGrainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask * lowEndPresence;
  color.r += (lumaGrain + chromaR) * w * densityMod;
  color.g += lumaGrain * w * densityMod;
  color.b += (lumaGrain + chromaB) * w * densityMod;
  color.rgb = clamp(color.rgb, 0.0, 1.0);

  // Before/After または A/B 比較の分割
  vec2 origUv = fitUv(vUv, uResolution, uImageResolution);
  float splitMask = insideUv(origUv);
  vec4 leftSample = uAbCompare > 0.5
    ? texture(uOriginalTexture, vUv)
    : texture(uOriginalTexture, origUv);
  float lineWidth = 2.0 / uResolution.x;

  if (vUv.x < uSplitPosition - lineWidth) {
    // Letterbox area: use graded output (which has blurred background)
    fragColor = mix(color, leftSample, splitMask);
  } else if (vUv.x < uSplitPosition + lineWidth) {
    // Split line: only show inside image area
    fragColor = vec4(vec3(1.0), color.a) * splitMask + color * (1.0 - splitMask);
  } else {
    fragColor = color;
  }
}
`;
