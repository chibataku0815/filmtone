import {
  activeMotionBlurFramesForShutter,
  clampMotionShutterAngle,
  computeMotionBlurWeights,
  isShutterMotionActive
} from "./chunk-LWXP5MLO.js";

// src/webgl/WebGLBackend.ts
import * as THREE3 from "three";
import {
  chromaUnitFromHueDegrees,
  clampGrainIntensity,
  deriveDetailSoftnessUniforms,
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE
} from "film-lab-core";

// src/webgl/shaders/filmlab.vert.ts
var filmlabVertexShader = (
  /* glsl */
  `
uniform float uFlipY;
out vec2 vUv;

void main() {
  vUv = vec2(uv.x, mix(uv.y, 1.0 - uv.y, uFlipY));
  gl_Position = vec4(position, 1.0);
}
`
);

// src/webgl/shaders/bloom-prefilter.frag.ts
var bloomPrefilterFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform float uThreshold;
uniform float uKnee;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

  // Soft knee: quadratic ramp around threshold
  float knee = max(uKnee * uThreshold, 1e-4);
  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);
  float contribution = t * t * mix(knee, 1.0, t);

  // For pixels clearly above threshold, use full overshoot
  contribution = max(contribution, max(0.0, luma - uThreshold));

  fragColor = vec4(color.rgb * contribution, 1.0);
}
`
);

// src/webgl/shaders/halation-prefilter.frag.ts
var halationPrefilterFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform vec3 uHalationColor;
uniform float uThreshold;
uniform float uKnee;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

  float knee = max(uKnee * uThreshold, 1e-4);
  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);
  float contribution = t * t * mix(knee, 1.0, t);

  contribution = max(contribution, max(0.0, luma - uThreshold));

  vec3 halation = color.rgb * contribution * uHalationColor;
  fragColor = vec4(halation, 1.0);
}
`
);

// src/webgl/shaders/detail-softness.frag.ts
var detailSoftnessFragmentShader = (
  /* glsl */
  `
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
`
);

// src/webgl/shaders/downsample.frag.ts
var downsampleFragmentShader = (
  /* glsl */
  `
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
`
);

// src/webgl/shaders/upsample.frag.ts
var upsampleFragmentShader = (
  /* glsl */
  `
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

  // Output weighted contribution only \u2014 GL additive blending accumulates with existing RT data
  fragColor = upsampled * uWeight;
}
`
);

// src/webgl/shaders/composite.frag.ts
var compositeFragmentShader = (
  /* glsl */
  `
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
/** 0=\u5F84\u65B9\u5411\u30DE\u30B9\u30AF\u7121\u3057\uFF08\u4E00\u69D8\uFF09\u30011=\u30D5\u30EB\u5468\u8FBA\u5F37\u3081\u3002mix(1.0, grainRadialWeight, clamp(\u5024,0,1)) \u306B\u7528\u3044\u308B */
uniform float uGrainRadialMix;
/** 0=\u6975\u7D30/\u5747\u4E00\u5BC4\u308A\u30011=\u6975\u7C97/\u30AF\u30E9\u30F3\u30D7\u5F37\u3081\u3002low-end fine grain \u3068 high-end coarse grain \u306E\u88DC\u9593\u306B\u4F7F\u3046 */
uniform float uGrainSize;
uniform float uTime;

uniform float uSplitPosition;
/** 0: Before/After\uFF08\u5DE6\u306F\u539F\u753B\u3092 coverUv \u3067\u30B5\u30F3\u30D7\u30EB\uFF09 / 1: A/B \u6BD4\u8F03\uFF08\u5DE6\u306F uOriginalTexture \u3092 vUv \u3067\u30B5\u30F3\u30D7\u30EB\uFF1D\u30B9\u30ED\u30C3\u30C8 A \u306E\u5168\u30D1\u30B9\u7D50\u679C\uFF09 */
uniform float uAbCompare;
uniform vec2 uResolution;
uniform vec2 uImageResolution;
/** \u8272\u53CE\u5DEE\u30AA\u30F3\u6642\u306E\u5468\u8FBA\u306E\u307F\u30B7\u30E3\u30FC\u30D7\u3068\u5FAE\u30D6\u30E9\u30FC\u3092\u6DF7\u305C\u308B\u91CF\uFF080\u301C1\u3001JS \u5074\u3067 rgbShift \u306B\u6BD4\u4F8B\u3002\u5927\u304D\u3044\u307B\u3069\u30D6\u30E9\u30FC\u534A\u5F84\u3082\u5C11\u3057\u5E83\u3052\u308B\uFF09 */
uniform float uAberrationEdgeSoften;
/** \u30EC\u30F3\u30BA\u306E\u5468\u8FBA\u30BD\u30D5\u30C8\uFF080\u301C1\u3001Params.lensSoftness\u3002\u8272\u53CE\u5DEE\u5468\u8FBA\u30BD\u30D5\u30C8\u3068\u306F\u5225\u5165\u529B\u3067\u5408\u6210\u3059\u308B\uFF09 */
uniform float uLensSoftness;
uniform float uFitMode;
/** 1: \u30B0\u30EC\u30FC\u30C7\u30A3\u30F3\u30B0\u3092\u30B9\u30AD\u30C3\u30D7\u3057\u3001uSource(\u53F3) \u3068 uOriginalTexture(\u5DE6) \u306E\u30B9\u30D7\u30EA\u30C3\u30C8\u306E\u307F\u5B9F\u884C */
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

// Per-pixel hash: sharp, random, no grid artifacts \u2014 like actual silver halide crystals.
float grainPixelHash(vec2 p, float seed) {
  return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

// Low-frequency smooth noise for grain density modulation (clumping).
// Value noise is fine here because the scale is large (20-80px per cell) \u2014
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
  // Split-only \u30E2\u30FC\u30C9: post-composite chain\uFF08\u30E2\u30FC\u30B7\u30E7\u30F3\u30D6\u30E9\u30FC\u7B49\uFF09\u9069\u7528\u5F8C\u306B\u30B9\u30D7\u30EA\u30C3\u30C8\u3092\u884C\u3046\u3002
  // uSource \u306B\u306F\u30D6\u30E9\u30FC\u6E08\u307F\u30B0\u30EC\u30FC\u30C7\u30A3\u30F3\u30B0\u51FA\u529B\u3001uOriginalTexture \u306B\u306F\u539F\u753B\u304C\u5165\u308B\u3002
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

  // \u5468\u8FBA\u3060\u3051\u3054\u304F\u5F31\u3044\u30D6\u30E9\u30FC\uFF08\u8272\u53CE\u5DEE\u3068\u4F75\u305B\u305F\u30D5\u30A3\u30EB\u30E0\u7684\u5468\u8FBA\u67D4\u3089\u304B\u3055\uFF09\u3002
  // \u8272\u53CE\u5DEE\u304C\u5F37\u3044\u307B\u3069\u3001\u6DF7\u8272\u91CF\u306B\u52A0\u3048\u3066\u30B5\u30F3\u30D7\u30EB\u534A\u5F84\u3082\u5C11\u3057\u3060\u3051\u5E83\u3052\u308B\u3002
  vec2 edgeDelta = vUv - 0.5;
  edgeDelta.x *= uResolution.x / max(uResolution.y, 1.0);
  float edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);
  float edgeMask = smoothstep(0.25, 1.0, edgeR);
  vec3 sharpRgb = texture(uSource, vUv).rgb;
  // \u30EC\u30F3\u30BA\u67D4\u3089\u304B\u3055: \u5468\u8FBA\u307B\u3069\u52B9\u304F\u3002\u3079\u304D\u3092\u4E0B\u3052\u308B\u3068\u5185\u5BC4\u308A\u306B\u3082\u52B9\u304D\u3001\u30B9\u30E9\u30A4\u30C0\u30FC\u304C\u300C\u5F31\u3044\u300D\u3068\u8A00\u308F\u308C\u305F\u3068\u304D\u306E\u8996\u8A8D\u6027\u304C\u4E0A\u304C\u308B\u3002
  float lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);
  float lensW = pow(lensR, 1.52);
  // \u03B3 \u3092\u4E0B\u3052\u308B\u307B\u3069\u4E2D\u9593\u30B9\u30E9\u30A4\u30C0\u30FC\u3067\u3082\u5F37\u304F\u898B\u3048\u308B\uFF08\u6700\u5927 1.0 \u306F\u7DAD\u6301\uFF09\u3002
  float lensDrive = pow(clamp(uLensSoftness, 0.0, 1.0), 0.78);
  float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);
  float aberrAmt = clamp(uAberrationEdgeSoften, 0.0, 1.0);
  // 8 \u30BF\u30C3\u30D7\u306E\u307E\u307E\u534A\u5F84\u30FB\u6DF7\u8272\u3092\u4E0A\u3052\u308B\uFF08\u521D\u7248\u306E 4px \u5F35\u308A\u4ED8\u304D\u3088\u308A\u306F cap \u3042\u308A\uFF09\u3002
  float blurRadiusPx =
    mix(1.5, 2.75, aberrAmt) + lensWeight * 1.35;
  blurRadiusPx = min(blurRadiusPx, 4.2);
  vec2 px =
    vec2(1.0 / max(uResolution.x, 1.0), 1.0 / max(uResolution.y, 1.0)) *
    blurRadiusPx;
  // \u5341\u5B57 4 \u30BF\u30C3\u30D7\u3060\u3051\u3060\u3068 HV \u65B9\u5411\u306B\u632F\u308C\u3001\u7D30\u304B\u3044\u7E1E\u3084\u8449\u3067 X \u5B57\u3063\u307D\u3044\u30E2\u30A2\u30EC\u304C\u51FA\u3084\u3059\u3044\u3002
  // \u659C\u3081 4 \u70B9\u3092\u8DB3\u3057\u3066 8 \u65B9\u5411\u5E73\u5747\u306B\u3057\u3001\u7B49\u65B9\u6027\u3092\u4E0A\u3052\u308B\uFF08\u534A\u5F84\u306F 1/\u221A2 \u30B9\u30B1\u30FC\u30EB\u3067\u30AB\u30FC\u30C9\u30CA\u30EB\u3068\u63C3\u3048\u308B\uFF09\u3002
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
  // \u6DF7\u8272\u306F\u8272\u53CE\u5DEE\u3068\u540C\u3058\u304F edgeMask\u3002
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
  // Unlike bloom (highlights only), diffusion scatters ALL light \u2014 creating
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

  // Radial weight (unchanged logic \u2014 center weak, edge strong)
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

  // Before/After \u307E\u305F\u306F A/B \u6BD4\u8F03\u306E\u5206\u5272
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
`
);

// src/webgl/shaders/motionblur.frag.ts
var feedbackCopyFragmentShader = (
  /* glsl */
  `
precision highp float;
uniform sampler2D uSource;
uniform sampler2D uPrevSlot;
uniform float uTrail; // 0.0=clean copy, 0.0-0.95=feedback intensity
in vec2 vUv;
out vec4 fragColor;
void main() {
  vec4 src = texture(uSource, vUv);
  vec4 prev = texture(uPrevSlot, vUv);
  fragColor = mix(src, prev, uTrail);
}
`
);
var motionblurFragmentShader = (
  /* glsl */
  `
precision highp float;

// Ring buffer samplers: 0=newest, 7=oldest
uniform sampler2D uFrame0;
uniform sampler2D uFrame1;
uniform sampler2D uFrame2;
uniform sampler2D uFrame3;
uniform sampler2D uFrame4;
uniform sampler2D uFrame5;
uniform sampler2D uFrame6;
uniform sampler2D uFrame7;

// Pre-normalized weights from CPU (sum=1.0 for active slots)
uniform float uWeight0;
uniform float uWeight1;
uniform float uWeight2;
uniform float uWeight3;
uniform float uWeight4;
uniform float uWeight5;
uniform float uWeight6;
uniform float uWeight7;

uniform int uActiveFrames;      // 1..8
uniform float uMotionThreshold; // 0.0=disabled, 0.02-0.05=recommended

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec4 f0 = texture(uFrame0, vUv);
  vec4 f1 = texture(uFrame1, vUv);
  vec4 f2 = texture(uFrame2, vUv);
  vec4 f3 = texture(uFrame3, vUv);
  vec4 f4 = texture(uFrame4, vUv);
  vec4 f5 = texture(uFrame5, vUv);
  vec4 f6 = texture(uFrame6, vUv);
  vec4 f7 = texture(uFrame7, vUv);

  // Weighted average
  vec4 blurred =
    f0 * uWeight0 + f1 * uWeight1 + f2 * uWeight2 + f3 * uWeight3 +
    f4 * uWeight4 + f5 * uWeight5 + f6 * uWeight6 + f7 * uWeight7;

  // Inline motion detection: branchless oldest frame selection
  float af = float(uActiveFrames);
  vec4 oldest = f0;
  oldest = mix(oldest, f1, step(2.0, af));
  oldest = mix(oldest, f2, step(3.0, af));
  oldest = mix(oldest, f3, step(4.0, af));
  oldest = mix(oldest, f4, step(5.0, af));
  oldest = mix(oldest, f5, step(6.0, af));
  oldest = mix(oldest, f6, step(7.0, af));
  oldest = mix(oldest, f7, step(8.0, af));

  float lumaDelta = abs(luma709(f0.rgb) - luma709(oldest.rgb));
  float motionMask = (uMotionThreshold > 0.0)
    ? smoothstep(uMotionThreshold * 0.5, uMotionThreshold * 2.0, lumaDelta)
    : 1.0;

  fragColor = mix(f0, blurred, motionMask);
}
`
);

// src/webgl/shaders/dust.frag.ts
var dustFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uDustTexture;
uniform sampler2D uScratchTexture;
uniform float uDustAmount;
uniform float uScratchAmount;
uniform float uTime;
uniform vec2 uResolution;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 color = texture(uSource, vUv);

  if (uDustAmount > 0.0) {
    vec2 dustUv = vUv * 3.0 + vec2(uTime * 0.02, uTime * 0.015);
    float dust = texture(uDustTexture, dustUv).r;
    vec2 dustUv2 = vUv * 1.7 + vec2(-uTime * 0.013, uTime * 0.009);
    float dust2 = texture(uDustTexture, dustUv2).r;
    float dustCombined = max(dust, dust2 * 0.7);
    vec3 dustColor = vec3(dustCombined * uDustAmount);
    // Screen blend: 1 - (1 - base) * (1 - overlay)
    color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - dustColor);
  }

  if (uScratchAmount > 0.0) {
    float jitterPhase = floor(uTime * 4.0);
    vec2 scratchUv = vec2(vUv.x * 2.0, vUv.y * 0.5 + jitterPhase * 0.37);
    float scratch = texture(uScratchTexture, scratchUv).r;
    // Additive blend
    color.rgb += vec3(scratch * uScratchAmount * 0.6);
  }

  color.rgb = clamp(color.rgb, 0.0, 1.0);
  fragColor = color;
}
`
);

// src/webgl/textures/dust-texture.ts
import * as THREE from "three";
function createDustTexture() {
  const size = 512;
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, size, size);
  const particleCount = 100;
  for (let i = 0; i < particleCount; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 0.5 + Math.random() * 2;
    const opacity = 0.3 + Math.random() * 0.5;
    ctx.beginPath();
    ctx.arc(x, y, radius, 0, Math.PI * 2);
    ctx.fillStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.fill();
    const margin = 16;
    if (x < margin) drawMirror(ctx, x + size, y, radius, opacity);
    if (x > size - margin) drawMirror(ctx, x - size, y, radius, opacity);
    if (y < margin) drawMirror(ctx, x, y + size, radius, opacity);
    if (y > size - margin) drawMirror(ctx, x, y - size, radius, opacity);
  }
  for (let i = 0; i < 25; i++) {
    const x = Math.random() * size;
    const y = Math.random() * size;
    const radius = 2 + Math.random() * 4;
    const gradient = ctx.createRadialGradient(x, y, 0, x, y, radius);
    gradient.addColorStop(0, `rgba(255, 255, 255, ${0.2 + Math.random() * 0.3})`);
    gradient.addColorStop(1, "rgba(255, 255, 255, 0)");
    ctx.fillStyle = gradient;
    ctx.fillRect(x - radius, y - radius, radius * 2, radius * 2);
  }
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = THREE.RepeatWrapping;
  texture.wrapT = THREE.RepeatWrapping;
  texture.minFilter = THREE.LinearFilter;
  texture.magFilter = THREE.LinearFilter;
  return texture;
}
function drawMirror(ctx, x, y, radius, opacity) {
  ctx.beginPath();
  ctx.arc(x, y, radius, 0, Math.PI * 2);
  ctx.fillStyle = `rgba(255, 255, 255, ${opacity})`;
  ctx.fill();
}

// src/webgl/textures/scratch-texture.ts
import * as THREE2 from "three";
function createScratchTexture() {
  const width = 256;
  const height = 1024;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  ctx.clearRect(0, 0, width, height);
  for (let i = 0; i < 20; i++) {
    const x = Math.random() * width;
    const angle = (Math.random() - 0.5) * 0.15;
    const lineWidth = 0.5 + Math.random() * 1;
    const opacity = 0.2 + Math.random() * 0.4;
    ctx.save();
    ctx.translate(x, 0);
    ctx.rotate(angle);
    ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.lineWidth = lineWidth;
    ctx.beginPath();
    ctx.moveTo(0, -50);
    ctx.lineTo(0, height + 50);
    ctx.stroke();
    ctx.restore();
  }
  for (let i = 0; i < 8; i++) {
    const x = Math.random() * width;
    const angle = (0.3 + Math.random() * 0.3) * (Math.random() > 0.5 ? 1 : -1);
    const lineWidth = 0.3 + Math.random() * 0.8;
    const opacity = 0.1 + Math.random() * 0.25;
    const segmentLength = 200 + Math.random() * 400;
    const startY = Math.random() * height;
    ctx.save();
    ctx.translate(x, startY);
    ctx.rotate(angle);
    ctx.strokeStyle = `rgba(255, 255, 255, ${opacity})`;
    ctx.lineWidth = lineWidth;
    ctx.beginPath();
    ctx.moveTo(0, 0);
    ctx.lineTo(0, segmentLength);
    ctx.stroke();
    ctx.restore();
  }
  const texture = new THREE2.CanvasTexture(canvas);
  texture.wrapS = THREE2.RepeatWrapping;
  texture.wrapT = THREE2.RepeatWrapping;
  texture.minFilter = THREE2.LinearFilter;
  texture.magFilter = THREE2.LinearFilter;
  return texture;
}

// src/webgl/shaders/lightshafts.frag.ts
var lightshaftsFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uLightOrigin;
uniform float uDecay;
uniform float uDensity;
uniform float uExposure;

in vec2 vUv;
out vec4 fragColor;

const int NUM_SAMPLES = 64;
const float LUMINANCE_THRESHOLD = 0.65;

void main() {
  vec2 deltaUv = vUv - uLightOrigin;
  deltaUv *= 1.0 / float(NUM_SAMPLES) * uDensity;

  vec2 sampleUv = vUv;
  vec4 accum = vec4(0.0);
  float illuminationDecay = 1.0;

  for (int i = 0; i < NUM_SAMPLES; i++) {
    sampleUv -= deltaUv;
    vec4 s = texture(uSource, clamp(sampleUv, 0.0, 1.0));
    float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));
    float contribution = smoothstep(LUMINANCE_THRESHOLD - 0.05, LUMINANCE_THRESHOLD + 0.05, luma);
    s.rgb *= contribution;
    s *= illuminationDecay;
    accum += s;
    illuminationDecay *= uDecay;
  }

  accum /= float(NUM_SAMPLES);
  fragColor = vec4(accum.rgb * uExposure, 1.0);
}
`
);

// src/webgl/shaders/lightshafts-blend.frag.ts
var lightshaftsBlendFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uShaftTexture;
uniform float uIntensity;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec3 scene = texture(uSource, vUv).rgb;
  vec3 shafts = texture(uShaftTexture, vUv).rgb;
  vec3 result = scene + shafts * uIntensity;
  fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);
}
`
);

// src/webgl/shaders/cross-filter-streak.frag.ts
var crossFilterStreakFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uDirection;
uniform vec2 uTexelSize;
uniform float uLength;
uniform float uChromatic;
uniform float uBrightnessMul;
uniform float uRandomness;
uniform float uHardMode;

in vec2 vUv;
out vec4 fragColor;

const int MAX_STREAK_PX = 64;
const float FALLOFF_K_SOFT  = 4.0;
const float FALLOFF_K_HARD  = 2.0;
const float STREAK_GAIN_SOFT = 2.5;
const float STREAK_GAIN_HARD = 6.0;
const float PEAK_THRESHOLD_SOFT = 0.01;
const float PEAK_THRESHOLD_HARD = 0.005;
const float CHROMA_HARD_FLOOR = 0.7;

// Wavelength dispersion spectrum.
// t = 0.0 -> near peak (warm: red/orange)  \u2014 matches reference "\u8D64->\u6A59->\u9EC4->\u7DD1->\u9752"
// t = 0.5 -> mid streak (green/yellow)
// t = 1.0 -> far tip (cool: blue/violet)
// uChromatic = 0: white streak, uChromatic = 1: full rainbow
vec3 wavelengthToRGB(float t) {
  vec3 c;
  c.r = clamp(1.0 - t * 2.0, 0.0, 1.0);
  c.g = clamp(1.0 - abs(t - 0.45) * 3.2, 0.0, 1.0);
  c.b = clamp((t - 0.45) * 3.0, 0.0, 1.0);
  float maxC = max(c.r, max(c.g, c.b));
  return c / max(maxC, 1e-4);
}

void main() {
  // Phase 6: Hard Mode interpolated constants. uHardMode is always 0.0 (Soft) or 1.0 (Hard).
  // mix(softVal, hardVal, 0.0) = softVal \u2192 byte-for-byte Phase 5 backward compat.
  // MAX_STREAK_PX is restored to Phase 5 value (64) so Soft Mode behavior is bit-identical.
  // Hard Mode's "more dramatic" character comes from gain/falloff/threshold/bloom/tone-mapping
  // changes \u2014 NOT from longer streak marches (which would cause UV wrap on smaller images).
  float falloffK    = mix(FALLOFF_K_SOFT, FALLOFF_K_HARD, uHardMode);
  float streakGain  = mix(STREAK_GAIN_SOFT, STREAK_GAIN_HARD, uHardMode);
  float peakThresh  = mix(PEAK_THRESHOLD_SOFT, PEAK_THRESHOLD_HARD, uHardMode);
  float chromaEffective = mix(uChromatic, max(uChromatic, CHROMA_HARD_FLOOR), uHardMode);

  int maxSteps = int(uLength * float(MAX_STREAK_PX));
  maxSteps = clamp(maxSteps, 1, MAX_STREAK_PX);

  // Forward: march in -uDirection to find peaks that cast a streak through this pixel
  vec3 resultFwd = vec3(0.0);
  for (int i = 1; i <= MAX_STREAK_PX; i++) {
    if (i > maxSteps) break;
    vec2 sampleUV = vUv - uDirection * uTexelSize * float(i);
    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));
    if (peakLuma > peakThresh) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * falloffK / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);
      resultFwd = peakLuma * tint * falloff;
      break;
    }
  }

  // Backward: march in +uDirection to find peaks that cast a streak through this pixel
  vec3 resultBwd = vec3(0.0);
  for (int i = 1; i <= MAX_STREAK_PX; i++) {
    if (i > maxSteps) break;
    vec2 sampleUV = vUv + uDirection * uTexelSize * float(i);
    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));
    if (peakLuma > peakThresh) {
      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);
      if (peakHash > uRandomness) break;
      float t = float(i) / float(maxSteps);
      float falloff = exp(-float(i) * falloffK / float(maxSteps));
      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);
      resultBwd = peakLuma * tint * falloff;
      break;
    }
  }

  vec3 result = resultFwd + resultBwd;
  // Soft: Reinhard rolloff (= original Phase 5 behavior).
  // Hard: linear amplification \u2192 blown-out centers.
  vec3 toneSoft = 1.0 - exp(-result * streakGain * uBrightnessMul);
  vec3 toneHard = result * streakGain * uBrightnessMul;
  result = mix(toneSoft, toneHard, uHardMode);
  fragColor = vec4(result, 1.0);
}
`
);

// src/webgl/shaders/cross-filter-blend.frag.ts
var crossFilterBlendFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uStreak0;
uniform sampler2D uStreak1;
uniform sampler2D uStreak2;
uniform sampler2D uStreak3;
uniform sampler2D uCentralBloom;
uniform int uStreakCount;
uniform float uIntensity;
uniform float uHardMode;

in vec2 vUv;
out vec4 fragColor;

void main() {
  vec4 original = texture(uSource, vUv);
  vec3 streaks = texture(uStreak0, vUv).rgb + texture(uStreak1, vUv).rgb;
  if (uStreakCount > 2) streaks += texture(uStreak2, vUv).rgb;
  if (uStreakCount > 3) streaks += texture(uStreak3, vUv).rgb;
  streaks /= float(uStreakCount);

  // Phase 6: Hard Mode central bloom contribution.
  // uHardMode = 0.0 \u2192 bloom term is exactly vec3(0.0) \u2192 byte-for-byte Phase 5 backward compat.
  // uHardMode = 1.0 \u2192 adds blurred peak halo for the "thick base, soft glow" reference look.
  vec3 bloom = texture(uCentralBloom, vUv).rgb * uHardMode * 1.5;

  // Phase 7: Highlight Protection Mask (Hard Mode only).
  // Bright pixels in the original (light source centers) get the streak/bloom overlay attenuated
  // to prevent double-bright blow-out. uHardMode=0 \u2192 centerProtect=1.0 \u2192 Phase 6 unchanged.
  float origLuma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));
  float centerProtect = mix(1.0, 1.0 - smoothstep(0.65, 0.95, origLuma), uHardMode);

  vec3 overlay = (streaks + bloom) * uIntensity * centerProtect;

  // Additive blend: preserves dark areas exactly (no shadow lifting).
  // Soft Reinhard rolloff on excess prevents harsh highlight clipping.
  vec3 combined = original.rgb + overlay;
  vec3 excess = max(combined - 1.0, vec3(0.0));
  vec3 result = combined - excess + excess / (1.0 + excess * 2.0);

  fragColor = vec4(result, original.a);
}
`
);

// src/webgl/shaders/cross-filter-peak.frag.ts
var crossFilterPeakFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform float uSizeLimit;

in vec2 vUv;
out vec4 fragColor;

const int RING_SAMPLES = 16;
const float RING_RADIUS = 24.0;
const int NEIGHBOR_SAMPLES = 16;
const float NEIGHBOR_RADIUS = 8.0;
const float NEIGHBOR_THRESHOLD = 0.01;

void main() {
  vec4 center = texture(uSource, vUv);
  float centerLuma = dot(center.rgb, vec3(0.2126, 0.7152, 0.0722));

  float avgLuma = 0.0;
  for (int i = 0; i < RING_SAMPLES; i++) {
    float angle = float(i) * (6.28318 / float(RING_SAMPLES));
    vec2 offset = vec2(cos(angle), sin(angle)) * RING_RADIUS * uTexelSize;
    avgLuma += dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));
  }
  avgLuma /= float(RING_SAMPLES);

  float peakness = centerLuma - avgLuma;

  float neighborCount = 0.0;
  for (int i = 0; i < NEIGHBOR_SAMPLES; i++) {
    float angle = float(i) * (6.28318 / float(NEIGHBOR_SAMPLES));
    vec2 offset = vec2(cos(angle), sin(angle)) * NEIGHBOR_RADIUS * uTexelSize;
    float lum = dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));
    neighborCount += step(NEIGHBOR_THRESHOLD, lum);
  }

  float maxNeighbors = mix(float(NEIGHBOR_SAMPLES), 1.0, uSizeLimit);
  float densityFactor = 1.0 - smoothstep(maxNeighbors, maxNeighbors + 2.0, neighborCount);

  float factor = smoothstep(0.0, 0.2, peakness) * densityFactor;

  fragColor = center * factor;
}
`
);

// src/webgl/shaders/cross-filter-peak-spacing.frag.ts
var crossFilterPeakSpacingFragmentShader = (
  /* glsl */
  `
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
`
);

// src/webgl/shaders/cross-filter-peak-spacing-max.frag.ts
var crossFilterPeakSpacingMaxFragmentShader = (
  /* glsl */
  `
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
`
);

// src/webgl/shaders/cross-filter-temporal.frag.ts
var crossFilterTemporalFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform sampler2D uPrev;
uniform float uDecay;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
  vec3 current = texture(uSource, vUv).rgb;
  vec3 prev = texture(uPrev, vUv).rgb;

  // Hard Mode should pick up new peaks immediately, but let them fade over a
  // few frames instead of hard-switching at the detection threshold.
  float prevMask = smoothstep(0.002, 0.03, luma709(prev));
  vec3 held = prev * (uDecay * prevMask);
  vec3 stabilized = max(current, held);

  fragColor = vec4(stabilized, 1.0);
}
`
);

// src/webgl/WebGLBackend.ts
var _blackTexture = null;
function getBlackTexture() {
  if (!_blackTexture) {
    _blackTexture = new THREE3.DataTexture(
      new Uint8Array([0, 0, 0, 255]),
      1,
      1,
      THREE3.RGBAFormat
    );
    _blackTexture.needsUpdate = true;
  }
  return _blackTexture;
}
var RT_OPTIONS = {
  minFilter: THREE3.LinearFilter,
  magFilter: THREE3.LinearFilter,
  format: THREE3.RGBAFormat,
  type: THREE3.HalfFloatType
};
var CROSS_FILTER_SPACING_RADIUS_MAX_PX = 48;
var CROSS_FILTER_SPACING_RADIUS_EXTRA_MAX_PX = 24;
var crossFilterDebugFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform float uGain;
uniform float uFalseColor;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 heat(float t) {
  return clamp(
    vec3(
      smoothstep(0.00, 0.30, t),
      smoothstep(0.18, 0.72, t),
      smoothstep(0.55, 1.00, t)
    ),
    0.0,
    1.0
  );
}

void main() {
  vec3 src = texture(uSource, vUv).rgb;
  float lum = luma709(src);
  float boosted = clamp(lum * uGain, 0.0, 1.0);
  vec3 display = mix(clamp(src * uGain, 0.0, 1.0), heat(boosted), step(0.5, uFalseColor));
  fragColor = vec4(display, 1.0);
}
`
);
var ABERRATION_EDGE_SOFTEN_SCALE = 32;
function hexToVec3(hex) {
  const c = new THREE3.Color(hex);
  return new THREE3.Vector3(c.r, c.g, c.b);
}
var WebGLBackend = class _WebGLBackend {
  mesh;
  material;
  geometry;
  boundRenderer = null;
  boundScene = null;
  boundCamera = null;
  // Post-processing scene (shared quad, swap material per pass)
  postScene;
  postCamera;
  postGeometry;
  postMesh;
  // Post-processing materials
  bloomPrefilterMaterial;
  halationPrefilterMaterial;
  detailSoftnessMaterial;
  downsampleMaterial;
  upsampleMaterial;
  compositeMaterial;
  // RenderTargets (lazy)
  rtColorGraded = null;
  rtDetailSoftened = null;
  static BLOOM_MIP_LEVELS = 5;
  static HALATION_MIP_LEVELS = 6;
  static DIFFUSION_MIP_LEVELS = 3;
  rtBloomMips = [];
  rtHalationMips = [];
  /** A/B 比較: スロット A の最終合成（分割なし）を書き込む */
  rtCompareComposite = null;
  /** #98 で確保する将来の post-composite 用フル解像度 RT（左側） */
  rtPostComposite0 = null;
  /** #98 で確保する将来の post-composite 用フル解像度 RT（右側） */
  rtPostComposite1 = null;
  /** true のとき render() でスロット A→RT、続けてスロット B を画面に分割表示 */
  abCompareEnabled = false;
  compareParamsA = {};
  compareParamsB = {};
  // Bloom/Halation params (stored here, not on color grade material)
  bloomThreshold = 0.8;
  bloomStrength = 0;
  bloomRadius = 0.4;
  halationIntensity = 0;
  halationSpread = 15;
  halationColor = new THREE3.Vector3(0.91, 0.063, 0.125);
  halationThreshold = 0.6;
  halationRadius = 0.6;
  bloomSoftKnee = 0.5;
  halationSoftKnee = 0.3;
  // --- Diffusion (Pro-Mist / Cinebloom) ---
  diffusion = 0;
  rtDiffusionMips = [];
  /**
   * composite の径方向グレイン混色（0=一様、1=周辺強め）。カラーパスには無く合成パスのみ。
   */
  grainRadialMix = 1;
  detailSoftness = 0;
  // --- Motion Blur: N-frame Ring Buffer (Post-composite #97) ---
  static MOTION_BLUR_RING_SIZE = 8;
  shutterAngle = 0;
  frameRepeat = 1;
  // renderer-internal, not in PARAM_KEYS
  ringWriteIndex = 0;
  ringFilledFrames = 0;
  weightCurve = "triangle";
  motionThreshold = 0;
  trailIntensity = 0;
  // 0=no feedback, 0-0.95=longer trails
  ringCopyMaterial = null;
  ringBlendMaterial = null;
  rtRingBuffer = [];
  // --- Dust & Scratches (Post-composite #99) ---
  dustAmount = 0;
  scratchAmount = 0;
  dustMaterial = null;
  dustTexture = null;
  scratchTexture = null;
  // --- Light Shafts (Post-composite #100) ---
  shaftIntensity = 0;
  shaftDecay = 0.5;
  shaftOriginX = 0.5;
  shaftOriginY = 0.15;
  shaftMaterial = null;
  shaftBlendMaterial = null;
  rtShaft = null;
  // --- Cross Filter (Post-composite) ---
  crossFilterStrength = 0;
  crossFilterSpikes = 4;
  crossFilterAngle = 0;
  crossFilterLength = 0.5;
  crossFilterThreshold = 0.8;
  crossFilterChromatic = 0.3;
  crossFilterSizeLimit = 0;
  crossFilterRandomness = 1;
  /** Phase 6: Hard Mode toggle (0=Soft, 1=Hard). Render-time uniform overrides for stylized look. */
  crossFilterHardMode = 0;
  /** Peak-level spacing control — prefers separated highlight sources before streak generation. */
  crossFilterMinSpacing = 1;
  crossFilterStreakMaterial = null;
  crossFilterBlendMaterial = null;
  rtCrossThreshold = null;
  rtCrossPeak = null;
  rtCrossPeakSpacingWork = null;
  rtCrossPeakSpacingMax = null;
  rtCrossPeakSpaced = null;
  rtCrossStreak = [];
  crossFilterPeakMaterial = null;
  crossFilterPeakSpacingMaxMaterial = null;
  crossFilterPeakSpacingMaterial = null;
  crossFilterTemporalMaterial = null;
  crossFilterDebugMaterial = null;
  rtCrossPeakHistory = [];
  crossFilterPeakHistoryWriteIndex = 0;
  crossFilterPeakHistoryFilledFrames = 0;
  crossFilterDebugView = "off";
  lastCrossPeakSpacedTarget = null;
  lastCrossPeakHeldTarget = null;
  lastCrossTemporalHoldActive = false;
  lastCrossStreakCount = 0;
  /** Phase 6: Hard Mode central bloom mip chain (lazy alloc, only when Hard Mode first becomes active). */
  rtCentralBloomMips = [];
  compareRenderActive = false;
  /**
   * composite のレンズ周辺ソフト（0〜1）。色収差周辺ソフトとは別（Params.lensSoftness）。
   */
  lensSoftness = 0;
  /**
   * シャドウ／ハイライトの色相は GPU から一意に逆算できないため、最後に `setParams` で適用した値を保持する。
   * `getParams` と「色相だけ更新」のときの強度維持に使う。
   */
  splitShadowHueDeg = FILM_LAB_DEFAULT_SHADOW_HUE;
  splitHighlightHueDeg = FILM_LAB_DEFAULT_HIGHLIGHT_HUE;
  width;
  height;
  renderer = null;
  histogramBuffer = null;
  /** HalfFloat RT 読み戻し用（readPixels は RGBA + HALF_FLOAT + Uint16 が正系） */
  histogramHalfBuffer = null;
  constructor(options) {
    this.width = options.width;
    this.height = options.height;
    this.material = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: options.vertexShader,
      fragmentShader: options.fragmentShader,
      uniforms: {
        uTexture: { value: null },
        uResolution: {
          value: new THREE3.Vector2(options.width, options.height)
        },
        uImageResolution: { value: new THREE3.Vector2(1280, 720) },
        uTime: { value: 0 },
        uExposure: { value: 0 },
        uContrast: { value: 1 },
        uSaturation: { value: 1 },
        uTemperature: { value: 0 },
        uTint: { value: 0 },
        uShadowTint: { value: new THREE3.Vector3(0, 0, 0) },
        uHighlightTint: { value: new THREE3.Vector3(0, 0, 0) },
        uRGBShift: { value: 0 },
        uGrainIntensity: { value: 0 },
        uVignette: { value: 0 },
        uFade: { value: 0 },
        uHighlights: { value: 0 },
        uShadows: { value: 0 },
        /** -1 で分割オフ（全面がグレード後）。0〜1 で Before/After または A/B の境界 */
        uSplitPosition: { value: -1 },
        uLUT1: { value: null },
        uLUT1Intensity: { value: 1 },
        uLUT1Enabled: { value: 0 },
        uLUT2: { value: null },
        uLUT2Intensity: { value: 1 },
        uLUT2Enabled: { value: 0 },
        // 0.4.0 の現像段・プリント段で使う数値 uniform。
        uCompressionAmount: { value: 0 },
        uCompressionRange: { value: 0.5 },
        uPrintContrast: { value: 0 },
        uCyan: { value: 0 },
        uMagenta: { value: 0 },
        uYellow: { value: 0 },
        uFlipY: { value: 0 },
        uFitMode: { value: 0 }
      }
    });
    this.geometry = new THREE3.PlaneGeometry(2, 2);
    this.mesh = new THREE3.Mesh(this.geometry, this.material);
    this.postScene = new THREE3.Scene();
    this.postCamera = new THREE3.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.postGeometry = new THREE3.PlaneGeometry(2, 2);
    this.postMesh = new THREE3.Mesh(this.postGeometry);
    this.postScene.add(this.postMesh);
    this.bloomPrefilterMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: bloomPrefilterFragmentShader,
      uniforms: {
        uSource: { value: null },
        uThreshold: { value: 0.8 },
        uKnee: { value: 0.5 },
        uFlipY: { value: 0 }
      }
    });
    this.halationPrefilterMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: halationPrefilterFragmentShader,
      uniforms: {
        uSource: { value: null },
        uHalationColor: { value: new THREE3.Vector3(0.91, 0.063, 0.125) },
        uThreshold: { value: 0.6 },
        uKnee: { value: 0.3 },
        uFlipY: { value: 0 }
      }
    });
    this.detailSoftnessMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: detailSoftnessFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uEffectiveDetailSoftness: { value: 0 },
        uKernelRadiusPx: { value: 0.55 },
        uChromaAttenScale: { value: 0.85 },
        uEdgeGuardLo: { value: 0.04 },
        uEdgeGuardHi: { value: 0.2 },
        uHighlightBias: { value: 1.18 }
      }
    });
    this.downsampleMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: downsampleFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uFlipY: { value: 0 }
      }
    });
    this.upsampleMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: upsampleFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uWeight: { value: 1 },
        uFlipY: { value: 0 }
      },
      blending: THREE3.AdditiveBlending,
      depthTest: false,
      depthWrite: false
    });
    this.compositeMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: compositeFragmentShader,
      uniforms: {
        uSource: { value: null },
        uBloomTexture: { value: null },
        uHalationTexture: { value: null },
        uDiffusionTexture: { value: null },
        uOriginalTexture: { value: null },
        uBloomStrength: { value: 0 },
        uHalationIntensity: { value: 0 },
        uDiffusion: { value: 0 },
        uVignette: { value: 0 },
        uGrainIntensity: { value: 0 },
        uGrainRadialMix: { value: 1 },
        uGrainSize: { value: 0.3 },
        uTime: { value: 0 },
        uSplitPosition: { value: -1 },
        uAbCompare: { value: 0 },
        uResolution: {
          value: new THREE3.Vector2(options.width, options.height)
        },
        uImageResolution: { value: new THREE3.Vector2(1280, 720) },
        uAberrationEdgeSoften: { value: 0 },
        uLensSoftness: { value: 0 },
        uFlipY: { value: 0 },
        uFitMode: { value: 0 },
        uSplitOnly: { value: 0 }
      }
    });
  }
  // ===== RenderTarget management =====
  /**
   * @description 0x0 の RenderTarget は WebGL warning の原因になります。
   * 画面の幅と高さが両方そろったときだけ GPU リソースを作ります。
   */
  hasRenderableResolution() {
    return this.width > 0 && this.height > 0;
  }
  ensureRenderTargets() {
    if (this.rtColorGraded) return;
    if (!this.hasRenderableResolution()) return;
    const w = this.width;
    const h = this.height;
    this.rtColorGraded = new THREE3.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtDetailSoftened = new THREE3.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtCompareComposite = new THREE3.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtBloomMips = [];
    for (let i = 0; i < _WebGLBackend.BLOOM_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtBloomMips.push(new THREE3.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
    this.rtHalationMips = [];
    for (let i = 0; i < _WebGLBackend.HALATION_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtHalationMips.push(new THREE3.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }
  resizeRenderTargets(w, h) {
    if (!this.rtColorGraded) return;
    if (w <= 0 || h <= 0) return;
    this.rtColorGraded.setSize(w, h);
    this.rtDetailSoftened?.setSize(w, h);
    this.rtCompareComposite?.setSize(w, h);
    for (let i = 0; i < this.rtBloomMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtBloomMips[i].setSize(mw, mh);
    }
    for (let i = 0; i < this.rtHalationMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtHalationMips[i].setSize(mw, mh);
    }
    for (let i = 0; i < this.rtDiffusionMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtDiffusionMips[i].setSize(mw, mh);
    }
    this.resizePostCompositeRenderTargets(w, h);
  }
  /**
   * Diffusion 用 mip chain を lazy 確保。diffusion=0 のときは GPU コストゼロ。
   */
  ensureDiffusionResources() {
    if (this.rtDiffusionMips.length > 0) return;
    if (!this.hasRenderableResolution()) return;
    const w = this.width;
    const h = this.height;
    for (let i = 0; i < _WebGLBackend.DIFFUSION_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtDiffusionMips.push(new THREE3.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }
  /**
   * #98 の post-composite seam が有効になったときだけ、中間 RT を作る。
   * 無効時は呼ばれないので、Pass 8 だけの現在挙動に余計なコストを足さない。
   */
  ensurePostCompositeRenderTargets() {
    if (this.rtPostComposite0) return;
    if (!this.hasRenderableResolution()) return;
    const w = this.width;
    const h = this.height;
    this.rtPostComposite0 = new THREE3.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtPostComposite1 = new THREE3.WebGLRenderTarget(w, h, RT_OPTIONS);
  }
  /**
   * Motion blur 用の ShaderMaterial と N-frame ring buffer RT を遅延生成する。
   * shutterAngle > 180 になるまで GPU リソースを消費しない。
   */
  ensureMotionBlurResources() {
    if (this.ringCopyMaterial) return;
    this.ringCopyMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: feedbackCopyFragmentShader,
      uniforms: {
        uSource: { value: null },
        uPrevSlot: { value: null },
        uTrail: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.ringBlendMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: motionblurFragmentShader,
      uniforms: {
        uFrame0: { value: null },
        uFrame1: { value: null },
        uFrame2: { value: null },
        uFrame3: { value: null },
        uFrame4: { value: null },
        uFrame5: { value: null },
        uFrame6: { value: null },
        uFrame7: { value: null },
        uWeight0: { value: 1 },
        uWeight1: { value: 0 },
        uWeight2: { value: 0 },
        uWeight3: { value: 0 },
        uWeight4: { value: 0 },
        uWeight5: { value: 0 },
        uWeight6: { value: 0 },
        uWeight7: { value: 0 },
        uActiveFrames: { value: 1 },
        uMotionThreshold: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.rtRingBuffer = [];
    for (let i = 0; i < _WebGLBackend.MOTION_BLUR_RING_SIZE; i++) {
      this.rtRingBuffer.push(
        new THREE3.WebGLRenderTarget(this.width, this.height, RT_OPTIONS)
      );
    }
  }
  /**
   * shutterAngle から有効フレーム数を算出する。
   * 180° 以下は通常素材の基準として temporal blend なし。
   */
  getActiveFrameCount() {
    return activeMotionBlurFramesForShutter(
      this.shutterAngle,
      _WebGLBackend.MOTION_BLUR_RING_SIZE
    );
  }
  /**
   * weightCurve に応じた正規化済みブレンドウェイトを計算する。
   * index 0 = newest, index N-1 = oldest。
   * shutterAngle は短い追加露光窓を決め、長い残像は trailIntensity が担当する。
   * shutterAngle > 360° では triangle → box へ自動的にフラット化する。
   */
  computeBlendWeights(activeFrames) {
    return computeMotionBlurWeights(
      this.shutterAngle,
      activeFrames,
      this.ringFilledFrames,
      _WebGLBackend.MOTION_BLUR_RING_SIZE,
      this.weightCurve
    );
  }
  /**
   * Dust & Scratches 用の ShaderMaterial とテクスチャを遅延生成する。
   * dustAmount > 0 || scratchAmount > 0 になるまで GPU リソースを消費しない。
   */
  ensureDustResources() {
    if (this.dustMaterial) return;
    this.dustTexture = createDustTexture();
    this.scratchTexture = createScratchTexture();
    this.dustMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: dustFragmentShader,
      uniforms: {
        uSource: { value: null },
        uDustTexture: { value: this.dustTexture },
        uScratchTexture: { value: this.scratchTexture },
        uDustAmount: { value: 0 },
        uScratchAmount: { value: 0 },
        uTime: { value: 0 },
        uResolution: { value: new THREE3.Vector2() },
        uFlipY: { value: 0 }
      }
    });
  }
  /**
   * Light shafts 用の ShaderMaterial と 1/4 解像度 RT を遅延生成する。
   * shaftIntensity > 0 になるまで GPU リソースを消費しない。
   */
  ensureShaftResources() {
    if (this.shaftMaterial) return;
    this.shaftMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: lightshaftsFragmentShader,
      uniforms: {
        uSource: { value: null },
        uLightOrigin: { value: new THREE3.Vector2(0.5, 0.85) },
        uDecay: { value: 0.96 },
        uDensity: { value: 0.98 },
        uExposure: { value: 0.38 },
        uFlipY: { value: 0 }
      }
    });
    this.shaftBlendMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: lightshaftsBlendFragmentShader,
      uniforms: {
        uSource: { value: null },
        uShaftTexture: { value: null },
        uIntensity: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    const qw = Math.max(1, Math.floor(this.width / 4));
    const qh = Math.max(1, Math.floor(this.height / 4));
    this.rtShaft = new THREE3.WebGLRenderTarget(qw, qh, RT_OPTIONS);
  }
  ensureCrossFilterResources() {
    if (this.crossFilterStreakMaterial) return;
    this.crossFilterStreakMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterStreakFragmentShader,
      uniforms: {
        uSource: { value: null },
        uDirection: { value: new THREE3.Vector2(1, 0) },
        uTexelSize: { value: new THREE3.Vector2() },
        uLength: { value: 0.5 },
        uChromatic: { value: 0 },
        uBrightnessMul: { value: 1 },
        uRandomness: { value: 1 },
        // Phase 6: Hard Mode toggle. uHardMode=0 → Phase 5 byte-for-byte identical.
        // No length multiplier — Hard Mode uses the same maxSteps range as Soft Mode
        // to avoid UV wrap artifacts on smaller images.
        uHardMode: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.crossFilterBlendMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterBlendFragmentShader,
      uniforms: {
        uSource: { value: null },
        uStreak0: { value: null },
        uStreak1: { value: null },
        uStreak2: { value: null },
        uStreak3: { value: null },
        // Phase 6: Hard Mode central bloom texture (default black → no contribution when Soft).
        uCentralBloom: { value: getBlackTexture() },
        uStreakCount: { value: 2 },
        uIntensity: { value: 0 },
        uHardMode: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.crossFilterPeakSpacingMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakSpacingFragmentShader,
      uniforms: {
        uSource: { value: null },
        uLocalMax: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uMinSpacing: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.crossFilterPeakSpacingMaxMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakSpacingMaxFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uAxis: { value: new THREE3.Vector2(1, 0) },
        uRadiusPx: { value: 0 },
        uReadMetadata: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    const hw = Math.max(1, Math.floor(this.width / 2));
    const hh = Math.max(1, Math.floor(this.height / 2));
    this.rtCrossThreshold = new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeak = new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpacingWork = new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpacingMax = new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpaced = new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossStreak = [];
    for (let i = 0; i < 4; i++) {
      this.rtCrossStreak.push(new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS));
    }
    this.crossFilterPeakMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE3.Vector2() },
        uSizeLimit: { value: 0 },
        uFlipY: { value: 0 }
      }
    });
    this.crossFilterTemporalMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterTemporalFragmentShader,
      uniforms: {
        uSource: { value: null },
        uPrev: { value: getBlackTexture() },
        uDecay: { value: 0.82 },
        uFlipY: { value: 0 }
      }
    });
    this.crossFilterDebugMaterial = new THREE3.ShaderMaterial({
      glslVersion: THREE3.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterDebugFragmentShader,
      uniforms: {
        uSource: { value: getBlackTexture() },
        uGain: { value: 1 },
        uFalseColor: { value: 1 }
      }
    });
    for (let i = 0; i < 2; i++) {
      this.rtCrossPeakHistory.push(new THREE3.WebGLRenderTarget(hw, hh, RT_OPTIONS));
    }
  }
  /**
   * Phase 6: Hard Mode central bloom mip chain (lazy alloc, 4 levels at 1/4..1/32 of source).
   * Allocated only when Hard Mode first becomes active to keep VRAM cost off Soft-only sessions.
   */
  ensureCentralBloomResources() {
    if (this.rtCentralBloomMips.length > 0) return;
    if (this.width <= 0 || this.height <= 0) return;
    const hw = Math.max(1, Math.floor(this.width / 2));
    const hh = Math.max(1, Math.floor(this.height / 2));
    for (let i = 0; i < 4; i++) {
      const mw = Math.max(1, Math.floor(hw / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(hh / Math.pow(2, i + 1)));
      this.rtCentralBloomMips.push(new THREE3.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }
  /**
   * Phase 6: Renders the central halo around peak light sources for Hard Mode.
   * Reuses bloom downsample/upsample materials on the rtCrossPeak texture (the
   * point-source-only output from the cross filter peak detection pass).
   *
   * Pattern mirrors renderBloom():
   *   1. Seed mip 0 by downsampling rtCrossPeak.
   *   2. Downsample chain (mip 1 → 3).
   *   3. Upsample chain back to mip 0 with autoClear=false (additive blend) — CRITICAL.
   */
  renderCentralBloom(renderer, sourceTexture, sourceWidth, sourceHeight) {
    const mips = this.rtCentralBloomMips;
    if (mips.length === 0) return;
    const ds = this.downsampleMaterial.uniforms;
    ds.uSource.value = sourceTexture;
    ds.uTexelSize.value.set(1 / sourceWidth, 1 / sourceHeight);
    this.postMesh.material = this.downsampleMaterial;
    renderer.setRenderTarget(mips[0]);
    renderer.render(this.postScene, this.postCamera);
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1];
      ds.uSource.value = src.texture;
      ds.uTexelSize.value.set(1 / src.width, 1 / src.height);
      renderer.setRenderTarget(mips[i]);
      renderer.render(this.postScene, this.postCamera);
    }
    const us = this.upsampleMaterial.uniforms;
    const weights = _WebGLBackend.computeMipWeights(0.5, mips.length);
    this.postMesh.material = this.upsampleMaterial;
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    for (let i = mips.length - 2; i >= 0; i--) {
      const src = mips[i + 1];
      us.uSource.value = src.texture;
      us.uTexelSize.value.set(1 / src.width, 1 / src.height);
      us.uWeight.value = weights[i + 1];
      renderer.setRenderTarget(mips[i]);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
  }
  /**
   * #98 の post-composite seam で使う RT を、画面サイズに合わせて広げ直す。
   *
   * @param w 幅
   * @param h 高さ
   */
  resizePostCompositeRenderTargets(w, h) {
    if (!this.rtPostComposite0 || !this.rtPostComposite1) return;
    if (w <= 0 || h <= 0) return;
    this.rtPostComposite0.setSize(w, h);
    this.rtPostComposite1.setSize(w, h);
  }
  // ===== Multi-pass render =====
  /**
   * 合成パス用ユニフォームをカラーグレード側（＋ Bloom/Halation 強度）に合わせる。
   */
  syncCompositeUniformsFromMaterial() {
    const cu = this.compositeMaterial.uniforms;
    const mu = this.material.uniforms;
    cu.uVignette.value = mu.uVignette.value;
    cu.uGrainIntensity.value = mu.uGrainIntensity.value;
    cu.uGrainRadialMix.value = this.grainRadialMix;
    cu.uTime.value = mu.uTime.value;
    cu.uResolution.value.copy(mu.uResolution.value);
    cu.uImageResolution.value.copy(
      mu.uImageResolution.value
    );
    cu.uBloomStrength.value = this.bloomStrength;
    cu.uHalationIntensity.value = this.halationIntensity;
    const rgbShift = mu.uRGBShift.value;
    cu.uAberrationEdgeSoften.value = Math.min(
      1,
      Math.max(0, rgbShift * ABERRATION_EDGE_SOFTEN_SCALE)
    );
    cu.uLensSoftness.value = this.lensSoftness;
    cu.uFitMode.value = mu.uFitMode.value;
  }
  /**
   * post-composite chain が必要かどうか。A/B 比較中は R9 対策として Slot A はブラーをスキップ。
   * Slot B（abCompareEnabled=false）のみブラーを適用。
   */
  hasPostCompositeChain() {
    if (this.abCompareEnabled) return false;
    return isShutterMotionActive(this.shutterAngle) || this.crossFilterStrength > 0;
  }
  /**
   * Pass 1〜7 をまとめて実行する。
   * ここではまだ composite へは行かず、Pass 8 の入力を作るだけにする。
   *
   * @param renderer 描画先
   * @param scene 元シーン
   * @param camera 元カメラ
   */
  renderBasePipeline(renderer, scene, camera) {
    renderer.setRenderTarget(this.rtColorGraded);
    renderer.render(scene, camera);
    this.renderDetailSoftness(renderer);
    const bloomOn = this.bloomStrength > 0;
    const halationOn = this.halationIntensity > 0;
    const hardModeActive = this.crossFilterStrength > 0 && this.crossFilterHardMode >= 0.5;
    const diffusionOn = this.diffusion > 0 && !hardModeActive;
    if (bloomOn) {
      this.renderBloom(renderer);
    }
    if (halationOn) {
      this.renderHalation(renderer);
    }
    if (diffusionOn) {
      this.renderDiffusion(renderer);
    }
  }
  opticalSourceTexture() {
    const uniforms = deriveDetailSoftnessUniforms(this.detailSoftness);
    return uniforms.effectiveDetailSoftness > 1e-4 && this.rtDetailSoftened ? this.rtDetailSoftened.texture : this.rtColorGraded.texture;
  }
  renderDetailSoftness(renderer) {
    if (!this.rtDetailSoftened || !this.rtColorGraded) return;
    const uniforms = deriveDetailSoftnessUniforms(this.detailSoftness);
    if (uniforms.effectiveDetailSoftness < 1e-4) return;
    const du = this.detailSoftnessMaterial.uniforms;
    du.uSource.value = this.rtColorGraded.texture;
    du.uTexelSize.value.set(
      1 / this.rtColorGraded.width,
      1 / this.rtColorGraded.height
    );
    du.uEffectiveDetailSoftness.value = uniforms.effectiveDetailSoftness;
    du.uKernelRadiusPx.value = uniforms.kernelRadiusPx;
    du.uChromaAttenScale.value = uniforms.chromaAttenScale;
    du.uEdgeGuardLo.value = uniforms.edgeGuardLo;
    du.uEdgeGuardHi.value = uniforms.edgeGuardHi;
    du.uHighlightBias.value = uniforms.highlightBias;
    this.postMesh.material = this.detailSoftnessMaterial;
    renderer.setRenderTarget(this.rtDetailSoftened);
    renderer.render(this.postScene, this.postCamera);
  }
  /**
   * Pass 8 の合成を 1 箇所へまとめる。
   *
   * @param renderer 描画先
   * @param target 出力先 RT。`null` なら画面に出す。
   * @param splitPosition 分割線の位置
   * @param abCompare A/B 比較かどうか
   * @param originalTexture 左側に見せる元画像
   */
  renderCompositeFrame(renderer, target, splitPosition, abCompare, originalTexture) {
    const cu = this.compositeMaterial.uniforms;
    this.syncCompositeUniformsFromMaterial();
    cu.uSplitPosition.value = splitPosition;
    cu.uAbCompare.value = abCompare;
    cu.uOriginalTexture.value = originalTexture;
    const black = getBlackTexture();
    const bloomOn = this.bloomStrength > 0;
    const halationOn = this.halationIntensity > 0;
    const hardModeActive = this.crossFilterStrength > 0 && this.crossFilterHardMode >= 0.5;
    const diffusionOn = this.diffusion > 0 && !hardModeActive;
    cu.uSource.value = this.opticalSourceTexture();
    cu.uBloomTexture.value = bloomOn ? this.rtBloomMips[0].texture : black;
    cu.uHalationTexture.value = halationOn ? this.rtHalationMips[0].texture : black;
    cu.uDiffusionTexture.value = diffusionOn && this.rtDiffusionMips.length > 0 ? this.rtDiffusionMips[0].texture : black;
    cu.uDiffusion.value = diffusionOn ? this.diffusion : 0;
    this.postMesh.material = this.compositeMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }
  /**
   * 最終出力の入口。
   * #98 では post-composite chain が無い限り、Pass 8 をそのまま target に出す。
   * chain が有効になったときだけ、中間 RT を使って後段へ渡す。
   *
   * @param renderer 描画先
   * @param target 出力先 RT。`null` なら画面に出す。
   * @param originalTexture 左側に見せる元画像
   * @param splitPosition 分割線の位置
   * @param abCompare A/B 比較かどうか
   */
  renderFinalFrame(renderer, target, originalTexture, splitPosition, abCompare) {
    if (!this.hasPostCompositeChain()) {
      this.renderCompositeFrame(
        renderer,
        target,
        splitPosition,
        abCompare,
        originalTexture
      );
      return;
    }
    this.ensurePostCompositeRenderTargets();
    if (!this.rtPostComposite0 || !this.rtPostComposite1) {
      this.renderCompositeFrame(
        renderer,
        target,
        splitPosition,
        abCompare,
        originalTexture
      );
      return;
    }
    if (splitPosition > 0 && abCompare < 0.5) {
      this.renderCompositeFrame(renderer, this.rtPostComposite0, -1, 0, originalTexture);
      this.renderPostCompositeChain(renderer, this.rtPostComposite0.texture, this.rtCompareComposite);
      this.renderSplitOnlyComposite(renderer, target, originalTexture, this.rtCompareComposite.texture, splitPosition);
      return;
    }
    this.renderCompositeFrame(
      renderer,
      this.rtPostComposite0,
      splitPosition,
      abCompare,
      originalTexture
    );
    this.renderPostCompositeChain(
      renderer,
      this.rtPostComposite0.texture,
      target
    );
  }
  /**
   * Split-only パス。グレーディングをスキップし、左=原画 / 右=ブラー済み出力 のスプリットのみ。
   * Before/After モード + post-composite chain 有効時に使用。
   */
  renderSplitOnlyComposite(renderer, target, originalTexture, blurredTexture, splitPosition) {
    const cu = this.compositeMaterial.uniforms;
    cu.uSplitOnly.value = 1;
    cu.uSource.value = blurredTexture;
    cu.uOriginalTexture.value = originalTexture;
    cu.uSplitPosition.value = splitPosition;
    this.syncCompositeUniformsFromMaterial();
    this.postMesh.material = this.compositeMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
    cu.uSplitOnly.value = 0;
  }
  /**
   * Dust & Scratches パス。Screen blend で埃、Additive で傷をオーバーレイする。
   *
   * @param renderer 描画先
   * @param sourceTexture 直前の post-composite 出力
   * @param target 出力先（null = 画面）
   */
  renderDust(renderer, sourceTexture, target) {
    this.ensureDustResources();
    if (!this.dustMaterial) return;
    const du = this.dustMaterial.uniforms;
    du.uSource.value = sourceTexture;
    du.uDustAmount.value = this.dustAmount;
    du.uScratchAmount.value = this.scratchAmount;
    du.uTime.value = this.material.uniforms.uTime.value;
    du.uResolution.value.set(this.width, this.height);
    this.postMesh.material = this.dustMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }
  /**
   * N-frame ring buffer motion blur.
   * Draw 1: Copy sourceTexture → rtRingBuffer[ringWriteIndex]
   * Draw 2: Weighted blend of ring slots (newest first) → target
   *
   * @param renderer 描画先
   * @param sourceTexture composite 出力テクスチャ
   * @param target 最終出力先（null = 画面）
   */
  renderMotionBlur(renderer, sourceTexture, target) {
    this.ensureMotionBlurResources();
    if (!this.ringCopyMaterial || !this.ringBlendMaterial || this.rtRingBuffer.length === 0) return;
    const N = _WebGLBackend.MOTION_BLUR_RING_SIZE;
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    const cu = this.ringCopyMaterial.uniforms;
    cu.uSource.value = sourceTexture;
    const prevSlotIdx = (this.ringWriteIndex - 1 + N) % N;
    cu.uPrevSlot.value = this.ringFilledFrames > 0 ? this.rtRingBuffer[prevSlotIdx].texture : getBlackTexture();
    cu.uTrail.value = this.ringFilledFrames > 0 ? this.trailIntensity : 0;
    this.postMesh.material = this.ringCopyMaterial;
    renderer.setRenderTarget(this.rtRingBuffer[this.ringWriteIndex]);
    renderer.render(this.postScene, this.postCamera);
    this.ringWriteIndex = (this.ringWriteIndex + 1) % N;
    this.ringFilledFrames = Math.min(this.ringFilledFrames + 1, N);
    const activeFrames = this.getActiveFrameCount();
    const weights = this.computeBlendWeights(activeFrames);
    const bu = this.ringBlendMaterial.uniforms;
    const black = getBlackTexture();
    for (let i = 0; i < N; i++) {
      const slotIndex = (this.ringWriteIndex - 1 - i + N * 2) % N;
      const filled = i < this.ringFilledFrames;
      bu[`uFrame${i}`].value = filled ? this.rtRingBuffer[slotIndex].texture : black;
      bu[`uWeight${i}`].value = weights[i];
    }
    bu.uActiveFrames.value = Math.min(activeFrames, this.ringFilledFrames);
    bu.uMotionThreshold.value = this.motionThreshold;
    this.postMesh.material = this.ringBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
    renderer.autoClear = prevAutoClear;
  }
  /**
   * Light shafts two-sub-pass rendering.
   * 9a: Radial blur at 1/4 resolution (64 samples, luminance threshold).
   * 9b: Additive blend at full resolution.
   *
   * @param renderer 描画先
   * @param sourceTexture composite 出力テクスチャ
   * @param target 最終出力先（null = 画面）
   */
  renderLightShafts(renderer, sourceTexture, target) {
    this.ensureShaftResources();
    if (!this.shaftMaterial || !this.shaftBlendMaterial || !this.rtShaft) return;
    const su = this.shaftMaterial.uniforms;
    su.uSource.value = sourceTexture;
    su.uLightOrigin.value.set(this.shaftOriginX, 1 - this.shaftOriginY);
    su.uDecay.value = 0.92 + this.shaftDecay * 0.075;
    this.postMesh.material = this.shaftMaterial;
    renderer.setRenderTarget(this.rtShaft);
    renderer.render(this.postScene, this.postCamera);
    const bu = this.shaftBlendMaterial.uniforms;
    bu.uSource.value = sourceTexture;
    bu.uShaftTexture.value = this.rtShaft.texture;
    bu.uIntensity.value = this.shaftIntensity;
    this.postMesh.material = this.shaftBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }
  resolveCrossFilterDebugSource(view, currentPeakTarget, peakTarget) {
    switch (view) {
      case "threshold":
        return this.rtCrossThreshold ? { texture: this.rtCrossThreshold.texture, gain: 8, falseColor: true } : null;
      case "peak":
        return this.rtCrossPeak ? { texture: this.rtCrossPeak.texture, gain: 16, falseColor: true } : null;
      case "peakSpaced":
        return { texture: currentPeakTarget.texture, gain: 16, falseColor: true };
      case "peakHeld":
        return { texture: peakTarget.texture, gain: 16, falseColor: true };
      case "streak0":
      case "streak1":
      case "streak2":
      case "streak3": {
        const index = Number(view.slice(-1));
        const rt = this.rtCrossStreak[index];
        return rt ? { texture: rt.texture, gain: 3, falseColor: false } : null;
      }
      default:
        return null;
    }
  }
  renderCrossFilterDebug(renderer, target, currentPeakTarget, peakTarget) {
    if (!this.crossFilterDebugMaterial || this.crossFilterDebugView === "off") {
      return false;
    }
    const debugSource = this.resolveCrossFilterDebugSource(
      this.crossFilterDebugView,
      currentPeakTarget,
      peakTarget
    );
    if (!debugSource) {
      return false;
    }
    const du = this.crossFilterDebugMaterial.uniforms;
    du.uSource.value = debugSource.texture;
    du.uGain.value = debugSource.gain;
    du.uFalseColor.value = debugSource.falseColor ? 1 : 0;
    this.postMesh.material = this.crossFilterDebugMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
    return true;
  }
  renderCrossFilter(renderer, sourceTexture, target) {
    this.ensureCrossFilterResources();
    if (!this.crossFilterStreakMaterial || !this.crossFilterPeakSpacingMaterial || !this.crossFilterPeakSpacingMaxMaterial || !this.crossFilterBlendMaterial || !this.crossFilterPeakMaterial || !this.crossFilterTemporalMaterial || !this.rtCrossThreshold || !this.rtCrossPeak || !this.rtCrossPeakSpacingWork || !this.rtCrossPeakSpacingMax || !this.rtCrossPeakSpaced || this.rtCrossPeakHistory.length < 2 || this.rtCrossStreak.length === 0) return;
    const dirCount = Math.floor(this.crossFilterSpikes / 2);
    const angleRad = this.crossFilterAngle * Math.PI / 180;
    const isHard = this.crossFilterHardMode >= 0.5;
    const effectiveThreshold = isHard ? 0.7 : this.crossFilterThreshold;
    const effectiveSizeLimit = isHard ? 1 : this.crossFilterSizeLimit;
    const effectiveRandomness = isHard ? 1 : this.crossFilterRandomness;
    const hardModeUniform = isHard ? 1 : 0;
    const pu = this.bloomPrefilterMaterial.uniforms;
    const savedThreshold = pu.uThreshold.value;
    const savedKnee = pu.uKnee.value;
    pu.uSource.value = sourceTexture;
    pu.uThreshold.value = effectiveThreshold;
    pu.uKnee.value = 0.1;
    this.postMesh.material = this.bloomPrefilterMaterial;
    renderer.setRenderTarget(this.rtCrossThreshold);
    renderer.render(this.postScene, this.postCamera);
    pu.uThreshold.value = savedThreshold;
    pu.uKnee.value = savedKnee;
    const pk = this.crossFilterPeakMaterial.uniforms;
    pk.uSource.value = this.rtCrossThreshold.texture;
    pk.uTexelSize.value.set(1 / this.rtCrossThreshold.width, 1 / this.rtCrossThreshold.height);
    pk.uSizeLimit.value = effectiveSizeLimit;
    this.postMesh.material = this.crossFilterPeakMaterial;
    renderer.setRenderTarget(this.rtCrossPeak);
    renderer.render(this.postScene, this.postCamera);
    let currentPeakTarget = this.rtCrossPeak;
    if (this.crossFilterMinSpacing >= 1e-3) {
      const spacingBoost = Math.min(1, Math.max(0, this.crossFilterMinSpacing - 1));
      const radiusPx = Math.round(
        CROSS_FILTER_SPACING_RADIUS_MAX_PX + CROSS_FILTER_SPACING_RADIUS_EXTRA_MAX_PX * THREE3.MathUtils.smoothstep(spacingBoost, 0, 1)
      );
      const smu = this.crossFilterPeakSpacingMaxMaterial.uniforms;
      smu.uSource.value = this.rtCrossPeak.texture;
      smu.uTexelSize.value.set(1 / this.rtCrossPeak.width, 1 / this.rtCrossPeak.height);
      smu.uAxis.value.set(1, 0);
      smu.uRadiusPx.value = radiusPx;
      smu.uReadMetadata.value = 0;
      this.postMesh.material = this.crossFilterPeakSpacingMaxMaterial;
      renderer.setRenderTarget(this.rtCrossPeakSpacingWork);
      renderer.render(this.postScene, this.postCamera);
      smu.uSource.value = this.rtCrossPeakSpacingWork.texture;
      smu.uAxis.value.set(0, 1);
      smu.uReadMetadata.value = 1;
      this.postMesh.material = this.crossFilterPeakSpacingMaxMaterial;
      renderer.setRenderTarget(this.rtCrossPeakSpacingMax);
      renderer.render(this.postScene, this.postCamera);
      const spu = this.crossFilterPeakSpacingMaterial.uniforms;
      spu.uSource.value = this.rtCrossPeak.texture;
      spu.uLocalMax.value = this.rtCrossPeakSpacingMax.texture;
      spu.uTexelSize.value.set(1 / this.rtCrossPeak.width, 1 / this.rtCrossPeak.height);
      spu.uMinSpacing.value = this.crossFilterMinSpacing;
      this.postMesh.material = this.crossFilterPeakSpacingMaterial;
      currentPeakTarget = this.rtCrossPeakSpaced;
      renderer.setRenderTarget(currentPeakTarget);
      renderer.render(this.postScene, this.postCamera);
    }
    const temporalHoldActive = isHard && !this.compareRenderActive;
    let peakTarget = currentPeakTarget;
    if (temporalHoldActive) {
      const writeIndex = this.crossFilterPeakHistoryWriteIndex;
      const prevIndex = (writeIndex + this.rtCrossPeakHistory.length - 1) % this.rtCrossPeakHistory.length;
      const tu = this.crossFilterTemporalMaterial.uniforms;
      tu.uSource.value = currentPeakTarget.texture;
      tu.uPrev.value = this.crossFilterPeakHistoryFilledFrames > 0 ? this.rtCrossPeakHistory[prevIndex].texture : getBlackTexture();
      this.postMesh.material = this.crossFilterTemporalMaterial;
      peakTarget = this.rtCrossPeakHistory[writeIndex];
      renderer.setRenderTarget(peakTarget);
      renderer.render(this.postScene, this.postCamera);
      this.crossFilterPeakHistoryWriteIndex = (writeIndex + 1) % this.rtCrossPeakHistory.length;
      this.crossFilterPeakHistoryFilledFrames = Math.min(
        this.crossFilterPeakHistoryFilledFrames + 1,
        this.rtCrossPeakHistory.length
      );
    }
    this.lastCrossPeakSpacedTarget = currentPeakTarget;
    this.lastCrossPeakHeldTarget = peakTarget;
    this.lastCrossTemporalHoldActive = temporalHoldActive;
    if (isHard) {
      this.ensureCentralBloomResources();
      this.renderCentralBloom(renderer, peakTarget.texture, peakTarget.width, peakTarget.height);
    }
    const su = this.crossFilterStreakMaterial.uniforms;
    const qw = peakTarget.width;
    const qh = peakTarget.height;
    su.uSource.value = peakTarget.texture;
    su.uTexelSize.value.set(1 / qw, 1 / qh);
    su.uChromatic.value = this.crossFilterChromatic;
    su.uRandomness.value = effectiveRandomness;
    su.uHardMode.value = hardModeUniform;
    const hash = (n) => {
      const s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
      return s - Math.floor(s);
    };
    for (let i = 0; i < dirCount; i++) {
      const seed = i * 17 + 7;
      const angleJitter = (hash(seed) - 0.5) * 2 * (5 * Math.PI / 180);
      const lengthMul = 1 + (hash(seed + 1) - 0.5) * 0.5;
      const brightMul = 1 + (hash(seed + 2) - 0.5) * 0.4;
      const dirAngle = angleRad + i * Math.PI / dirCount + angleJitter;
      su.uDirection.value.set(Math.cos(dirAngle), Math.sin(dirAngle));
      su.uLength.value = this.crossFilterLength * lengthMul;
      su.uBrightnessMul.value = brightMul;
      this.postMesh.material = this.crossFilterStreakMaterial;
      renderer.setRenderTarget(this.rtCrossStreak[i]);
      renderer.render(this.postScene, this.postCamera);
    }
    this.lastCrossStreakCount = dirCount;
    su.uLength.value = this.crossFilterLength;
    if (this.renderCrossFilterDebug(renderer, target, currentPeakTarget, peakTarget)) {
      return;
    }
    const black = getBlackTexture();
    const bu = this.crossFilterBlendMaterial.uniforms;
    bu.uSource.value = sourceTexture;
    bu.uStreak0.value = dirCount >= 1 ? this.rtCrossStreak[0].texture : black;
    bu.uStreak1.value = dirCount >= 2 ? this.rtCrossStreak[1].texture : black;
    bu.uStreak2.value = dirCount >= 3 ? this.rtCrossStreak[2].texture : black;
    bu.uStreak3.value = dirCount >= 4 ? this.rtCrossStreak[3].texture : black;
    bu.uCentralBloom.value = isHard && this.rtCentralBloomMips[0] ? this.rtCentralBloomMips[0].texture : black;
    bu.uStreakCount.value = dirCount;
    bu.uIntensity.value = this.crossFilterStrength;
    bu.uHardMode.value = hardModeUniform;
    this.postMesh.material = this.crossFilterBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }
  /**
   * Pass 9+ の受け皿。
   * Pass order: CrossFilter -> Shafts(9) -> Dust(10) -> MotionBlur(11)
   *
   * @param renderer 描画先
   * @param sourceTexture 直前の post-composite 出力
   * @param target 最終出力先
   */
  renderPostCompositeChain(renderer, sourceTexture, target) {
    const crossFilterOn = this.crossFilterStrength > 0;
    const shaftOn = this.shaftIntensity > 0;
    const dustOn = this.dustAmount > 0 || this.scratchAmount > 0;
    const motionBlurOn = isShutterMotionActive(this.shutterAngle);
    if (!motionBlurOn && this.ringFilledFrames > 0) {
      this.resetMotionBlurHistory();
    }
    const passes = [];
    if (crossFilterOn) passes.push("crossFilter");
    if (shaftOn) passes.push("shaft");
    if (dustOn) passes.push("dust");
    if (motionBlurOn) passes.push("motionBlur");
    if (passes.length === 0) return;
    let currentSource = sourceTexture;
    for (let i = 0; i < passes.length; i++) {
      const isLast = i === passes.length - 1;
      const passTarget = isLast ? target : this.rtPostComposite1;
      switch (passes[i]) {
        case "crossFilter":
          this.renderCrossFilter(renderer, currentSource, passTarget);
          if (this.crossFilterDebugView !== "off") return;
          break;
        case "shaft":
          this.renderLightShafts(renderer, currentSource, passTarget);
          break;
        case "dust":
          this.renderDust(renderer, currentSource, passTarget);
          break;
        case "motionBlur":
          this.renderMotionBlur(renderer, currentSource, passTarget);
          break;
      }
      if (!isLast) {
        currentSource = this.rtPostComposite1.texture;
      }
    }
  }
  /**
   * A/B ルック比較のオンオフと両スロットのパラメータ（setParams と同形のレコード）。
   * オフ時は render が従来どおりアクティブ側のみ（setParams で渡した値）を使う。
   */
  setComparePair(enabled, paramsA, paramsB) {
    const wasEnabled = this.abCompareEnabled;
    this.abCompareEnabled = enabled;
    if (paramsA) this.compareParamsA = { ...paramsA };
    if (paramsB) this.compareParamsB = { ...paramsB };
    if (enabled && !wasEnabled) {
      this.resetMotionBlurHistory();
    }
    if (enabled !== wasEnabled) {
      this.resetCrossFilterHistory();
    }
  }
  /**
   * T2-0c: `RenderBackend.render()` is zero-arg. WebGL still needs the
   * Three.js renderer/scene/camera; callers that migrated to the backend
   * interface must first `bindThree(renderer, scene, camera)` once (typically
   * during setup), after which subsequent `render()` calls use the stored
   * bindings. Legacy 3-arg callers continue to pass them per-frame.
   */
  bindThree(renderer, scene, camera) {
    this.boundRenderer = renderer;
    this.boundScene = scene;
    this.boundCamera = camera;
  }
  render(renderer, scene, camera) {
    const r = renderer ?? this.boundRenderer;
    const s = scene ?? this.boundScene;
    const c = camera ?? this.boundCamera;
    if (!r || !s || !c) return;
    if (!this.hasRenderableResolution()) return;
    this.ensureRenderTargets();
    if (!this.rtColorGraded) return;
    this.renderer = r;
    if (this.abCompareEnabled) {
      this.renderComparePair(r, s, c);
      return;
    }
    const mu = this.material.uniforms;
    this.renderBasePipeline(r, s, c);
    this.renderFinalFrame(
      r,
      null,
      mu.uTexture.value,
      mu.uSplitPosition.value,
      0
    );
  }
  /**
   * スロット A を全パスで RT に書き、続けてスロット B を画面に分割合成する。
   */
  renderComparePair(renderer, scene, camera) {
    this.compareRenderActive = true;
    try {
      const mu = this.material.uniforms;
      const originalTexture = mu.uTexture.value;
      this.setParams(this.compareParamsA);
      this.renderBasePipeline(renderer, scene, camera);
      this.renderFinalFrame(renderer, this.rtCompareComposite, originalTexture, -1, 0);
      const savedShutterAngle = this.shutterAngle;
      const savedCrossFilterStrength = this.crossFilterStrength;
      const savedCrossFilterHardMode = this.crossFilterHardMode;
      this.setParams(this.compareParamsB);
      this.renderBasePipeline(renderer, scene, camera);
      const savedAbCompareEnabled = this.abCompareEnabled;
      this.abCompareEnabled = false;
      this.renderFinalFrame(
        renderer,
        null,
        this.rtCompareComposite.texture,
        mu.uSplitPosition.value,
        1
      );
      this.abCompareEnabled = savedAbCompareEnabled;
      this.shutterAngle = savedShutterAngle;
      this.crossFilterStrength = savedCrossFilterStrength;
      this.crossFilterHardMode = savedCrossFilterHardMode;
    } finally {
      this.compareRenderActive = false;
    }
  }
  /**
   * Compute per-mip-level weights for the upsample accumulation.
   * radius=0 → tight bloom (only first mips). radius=1 → diffuse wide haze.
   */
  static computeMipWeights(radius, levels) {
    const weights = [];
    for (let i = 0; i < levels; i++) {
      const t = i / Math.max(levels - 1, 1);
      const base = Math.exp(-3 * (1 - radius) * t);
      const wide = Math.exp(-0.5 * radius * (1 - t));
      weights.push(base * (1 - radius) + wide * radius);
    }
    return weights;
  }
  renderBloom(renderer) {
    const mips = this.rtBloomMips;
    const bu = this.bloomPrefilterMaterial.uniforms;
    bu.uSource.value = this.opticalSourceTexture();
    bu.uThreshold.value = this.bloomThreshold;
    bu.uKnee.value = this.bloomSoftKnee;
    this.postMesh.material = this.bloomPrefilterMaterial;
    renderer.setRenderTarget(mips[0]);
    renderer.render(this.postScene, this.postCamera);
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1];
      const dst = mips[i];
      const du = this.downsampleMaterial.uniforms;
      du.uSource.value = src.texture;
      du.uTexelSize.value.set(1 / src.width, 1 / src.height);
      this.postMesh.material = this.downsampleMaterial;
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    const weights = _WebGLBackend.computeMipWeights(this.bloomRadius, mips.length);
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1];
      const highRes = mips[i];
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource.value = lowRes.texture;
      uu.uTexelSize.value.set(1 / lowRes.width, 1 / lowRes.height);
      uu.uWeight.value = weights[i + 1];
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
  }
  renderHalation(renderer) {
    const mips = this.rtHalationMips;
    const hu = this.halationPrefilterMaterial.uniforms;
    hu.uSource.value = this.opticalSourceTexture();
    hu.uHalationColor.value.copy(this.halationColor);
    hu.uThreshold.value = this.halationThreshold;
    hu.uKnee.value = this.halationSoftKnee;
    this.postMesh.material = this.halationPrefilterMaterial;
    renderer.setRenderTarget(mips[0]);
    renderer.render(this.postScene, this.postCamera);
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1];
      const dst = mips[i];
      const du = this.downsampleMaterial.uniforms;
      du.uSource.value = src.texture;
      du.uTexelSize.value.set(1 / src.width, 1 / src.height);
      this.postMesh.material = this.downsampleMaterial;
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }
    const prevAutoClear2 = renderer.autoClear;
    renderer.autoClear = false;
    const weights = _WebGLBackend.computeMipWeights(this.halationRadius, mips.length);
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1];
      const highRes = mips[i];
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource.value = lowRes.texture;
      uu.uTexelSize.value.set(1 / lowRes.width, 1 / lowRes.height);
      uu.uWeight.value = weights[i + 1];
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear2;
  }
  /**
   * Diffusion (Pro-Mist): Full-image mip pyramid blur (no threshold prefilter).
   * Reuses downsample/upsample materials shared with bloom/halation.
   */
  renderDiffusion(renderer) {
    this.ensureDiffusionResources();
    const mips = this.rtDiffusionMips;
    if (mips.length === 0) return;
    const du = this.downsampleMaterial.uniforms;
    du.uSource.value = this.opticalSourceTexture();
    du.uTexelSize.value.set(
      1 / this.rtColorGraded.width,
      1 / this.rtColorGraded.height
    );
    this.postMesh.material = this.downsampleMaterial;
    renderer.setRenderTarget(mips[0]);
    renderer.render(this.postScene, this.postCamera);
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1];
      const dst = mips[i];
      du.uSource.value = src.texture;
      du.uTexelSize.value.set(1 / src.width, 1 / src.height);
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    const weights = _WebGLBackend.computeMipWeights(0.7, mips.length);
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1];
      const highRes = mips[i];
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource.value = lowRes.texture;
      uu.uTexelSize.value.set(1 / lowRes.width, 1 / lowRes.height);
      uu.uWeight.value = weights[i + 1];
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
  }
  // ===== Texture =====
  setTexture(texture) {
    this.material.uniforms.uTexture.value = texture;
  }
  // ===== Resolution =====
  setResolution(width, height) {
    this.width = width;
    this.height = height;
    this.material.uniforms.uResolution.value.set(width, height);
    this.compositeMaterial.uniforms.uResolution.value.set(width, height);
    this.resizeRenderTargets(width, height);
    for (const rt of this.rtRingBuffer) rt.setSize(width, height);
    if (this.dustMaterial) {
      this.dustMaterial.uniforms.uResolution.value.set(width, height);
    }
    if (this.rtShaft) {
      const qw = Math.max(1, Math.floor(width / 4));
      const qh = Math.max(1, Math.floor(height / 4));
      this.rtShaft.setSize(qw, qh);
    }
    if (this.rtCrossThreshold) {
      const hw = Math.max(1, Math.floor(width / 2));
      const hh = Math.max(1, Math.floor(height / 2));
      this.rtCrossThreshold.setSize(hw, hh);
      this.rtCrossPeak?.setSize(hw, hh);
      this.rtCrossPeakSpacingWork?.setSize(hw, hh);
      this.rtCrossPeakSpacingMax?.setSize(hw, hh);
      this.rtCrossPeakSpaced?.setSize(hw, hh);
      for (const rt of this.rtCrossPeakHistory) rt.setSize(hw, hh);
      for (const rt of this.rtCrossStreak) rt.setSize(hw, hh);
    }
    if (this.rtCentralBloomMips.length > 0) {
      const hw2 = Math.max(1, Math.floor(width / 2));
      const hh2 = Math.max(1, Math.floor(height / 2));
      for (let i = 0; i < this.rtCentralBloomMips.length; i++) {
        const mw = Math.max(1, Math.floor(hw2 / Math.pow(2, i + 1)));
        const mh = Math.max(1, Math.floor(hh2 / Math.pow(2, i + 1)));
        this.rtCentralBloomMips[i].setSize(mw, mh);
      }
    }
    this.resetMotionBlurHistory();
    this.resetCrossFilterHistory();
  }
  setImageResolution(width, height) {
    this.material.uniforms.uImageResolution.value.set(width, height);
  }
  setFitMode(mode) {
    const value = mode === "contain" ? 1 : 0;
    this.material.uniforms.uFitMode.value = value;
    this.compositeMaterial.uniforms.uFitMode.value = value;
  }
  // ===== Time =====
  setTime(time) {
    this.material.uniforms.uTime.value = time;
  }
  // ===== Color Grading Setters =====
  setExposure(value) {
    this.material.uniforms.uExposure.value = value;
  }
  setContrast(value) {
    this.material.uniforms.uContrast.value = value;
  }
  setSaturation(value) {
    this.material.uniforms.uSaturation.value = value;
  }
  setTemperature(value) {
    this.material.uniforms.uTemperature.value = value;
  }
  /**
   * グリーン／マゼンタ軸の色かぶり（シェーダー `uTint`）。
   * @param value -1〜1 程度（プリセットと `types.Params.tint` に対応）
   */
  setTint(value) {
    this.material.uniforms.uTint.value = value;
  }
  setFade(value) {
    this.material.uniforms.uFade.value = value;
  }
  setHighlights(value) {
    this.material.uniforms.uHighlights.value = value;
  }
  setShadows(value) {
    this.material.uniforms.uShadows.value = value;
  }
  // ===== Effects Setters =====
  setRGBShift(value) {
    this.material.uniforms.uRGBShift.value = value;
  }
  setGrainIntensity(value) {
    this.material.uniforms.uGrainIntensity.value = clampGrainIntensity(value);
  }
  /**
   * @description Params.grainRadialMix を合成シェーダへ。0〜1 に丸める。
   */
  setGrainRadialMix(value) {
    const v = Math.min(1, Math.max(0, value));
    this.grainRadialMix = v;
    this.compositeMaterial.uniforms.uGrainRadialMix.value = v;
  }
  setGrainSize(value) {
    const v = Math.min(1, Math.max(0, value));
    this.compositeMaterial.uniforms.uGrainSize.value = v;
  }
  /**
   * @description Params.lensSoftness を合成シェーダへ。0〜1 に丸める。
   */
  setLensSoftness(value) {
    const v = Math.min(1, Math.max(0, value));
    this.lensSoftness = v;
    this.compositeMaterial.uniforms.uLensSoftness.value = v;
  }
  setVignette(value) {
    this.material.uniforms.uVignette.value = value;
  }
  // ===== Bloom Setters =====
  setBloomThreshold(value) {
    this.bloomThreshold = value;
  }
  setBloomStrength(value) {
    this.bloomStrength = value;
  }
  setBloomRadius(value) {
    this.bloomRadius = value;
  }
  // ===== Diffusion Setter =====
  setDiffusion(value) {
    this.diffusion = Math.min(1, Math.max(0, value));
  }
  // ===== Halation Setters =====
  setHalationIntensity(value) {
    this.halationIntensity = value;
  }
  setHalationSpread(value) {
    this.halationSpread = value;
  }
  setHalationColor(hex) {
    this.halationColor = hexToVec3(hex);
  }
  setHalationThreshold(value) {
    this.halationThreshold = value;
  }
  setHalationRadius(value) {
    this.halationRadius = value;
  }
  setBloomSoftKnee(value) {
    this.bloomSoftKnee = value;
  }
  setHalationSoftKnee(value) {
    this.halationSoftKnee = value;
  }
  // ===== Motion Blur =====
  setShutterAngle(degrees) {
    const wasActive = isShutterMotionActive(this.shutterAngle);
    this.shutterAngle = clampMotionShutterAngle(degrees);
    const isActive = isShutterMotionActive(this.shutterAngle);
    if (wasActive !== isActive || !isActive) this.resetMotionBlurHistory();
  }
  setMotionBlurAmount(value) {
    this.setShutterAngle(Math.min(1, Math.max(0, value)) * 360);
  }
  setTrailIntensity(value) {
    this.trailIntensity = Math.min(0.95, Math.max(0, value));
  }
  setFrameRepeat(value) {
    this.frameRepeat = Math.min(8, Math.max(1, Math.round(value)));
  }
  resetMotionBlurHistory() {
    this.ringWriteIndex = 0;
    this.ringFilledFrames = 0;
  }
  // ===== Dust & Scratches =====
  setDustAmount(value) {
    this.dustAmount = Math.min(1, Math.max(0, value));
  }
  setScratchAmount(value) {
    this.scratchAmount = Math.min(1, Math.max(0, value));
  }
  // ===== Light Shafts =====
  setShaftIntensity(value) {
    this.shaftIntensity = Math.min(1, Math.max(0, value));
  }
  setShaftDecay(value) {
    this.shaftDecay = Math.min(1, Math.max(0, value));
  }
  setShaftOriginX(value) {
    this.shaftOriginX = Math.min(1, Math.max(0, value));
  }
  setShaftOriginY(value) {
    this.shaftOriginY = Math.min(1, Math.max(0, value));
  }
  // ===== Cross Filter =====
  setCrossFilterStrength(v) {
    this.crossFilterStrength = Math.min(1, Math.max(0, v));
    if (this.crossFilterStrength === 0) this.resetCrossFilterHistory();
  }
  setCrossFilterSpikes(v) {
    const c = Math.min(8, Math.max(4, Math.round(v)));
    this.crossFilterSpikes = c % 2 === 0 ? c : c + 1;
  }
  setCrossFilterAngle(v) {
    this.crossFilterAngle = (v % 360 + 360) % 360;
  }
  setCrossFilterLength(v) {
    this.crossFilterLength = Math.min(1, Math.max(0, v));
  }
  setCrossFilterThreshold(v) {
    this.crossFilterThreshold = Math.min(1, Math.max(0, v));
  }
  setCrossFilterChromatic(v) {
    this.crossFilterChromatic = Math.min(1, Math.max(0, v));
  }
  setCrossFilterSizeLimit(v) {
    this.crossFilterSizeLimit = Math.min(1, Math.max(0, v));
  }
  setCrossFilterRandomness(v) {
    this.crossFilterRandomness = Math.min(1, Math.max(0, v));
  }
  setCrossFilterHardMode(v) {
    const next = v >= 0.5 ? 1 : 0;
    if (next !== this.crossFilterHardMode) this.resetCrossFilterHistory();
    this.crossFilterHardMode = next;
  }
  setCrossFilterMinSpacing(v) {
    const next = Math.min(2, Math.max(1, v));
    if (Math.abs(next - this.crossFilterMinSpacing) >= 1e-4) {
      this.resetCrossFilterHistory();
    }
    this.crossFilterMinSpacing = next;
  }
  resetCrossFilterHistory() {
    this.crossFilterPeakHistoryWriteIndex = 0;
    this.crossFilterPeakHistoryFilledFrames = 0;
  }
  setCrossFilterDebugView(view) {
    this.crossFilterDebugView = view ?? "off";
  }
  getCrossFilterDebugView() {
    return this.crossFilterDebugView;
  }
  getRenderTargetLumaStats(rt) {
    if (!rt || !this.renderer) return null;
    const w = rt.width;
    const h = rt.height;
    if (w <= 0 || h <= 0) return null;
    const size = w * h * 4;
    if (!this.histogramHalfBuffer || this.histogramHalfBuffer.length !== size) {
      this.histogramHalfBuffer = new Uint16Array(size);
    }
    this.renderer.readRenderTargetPixels(rt, 0, 0, w, h, this.histogramHalfBuffer);
    let activePixels = 0;
    let sumLuma = 0;
    let maxLuma = 0;
    const ACTIVE_THRESHOLD = 1e-3;
    for (let i = 0; i < size; i += 4) {
      const r = THREE3.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i]);
      const g = THREE3.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i + 1]);
      const b = THREE3.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i + 2]);
      const luma = r * 0.2126 + g * 0.7152 + b * 0.0722;
      sumLuma += luma;
      if (luma > maxLuma) maxLuma = luma;
      if (luma > ACTIVE_THRESHOLD) activePixels += 1;
    }
    const totalPixels = w * h;
    return {
      width: w,
      height: h,
      totalPixels,
      activePixels,
      activeFraction: totalPixels > 0 ? activePixels / totalPixels : 0,
      sumLuma,
      maxLuma
    };
  }
  getCrossFilterDebugMetrics() {
    if (!this.rtCrossThreshold || !this.rtCrossPeak) return null;
    const streaks = [];
    for (let i = 0; i < this.lastCrossStreakCount; i++) {
      streaks.push(this.getRenderTargetLumaStats(this.rtCrossStreak[i] ?? null));
    }
    return {
      spacing: this.crossFilterMinSpacing,
      hardMode: this.crossFilterHardMode >= 0.5,
      temporalHoldActive: this.lastCrossTemporalHoldActive,
      threshold: this.getRenderTargetLumaStats(this.rtCrossThreshold),
      peak: this.getRenderTargetLumaStats(this.rtCrossPeak),
      peakSpaced: this.getRenderTargetLumaStats(this.lastCrossPeakSpacedTarget),
      peakHeld: this.getRenderTargetLumaStats(this.lastCrossPeakHeldTarget),
      streaks
    };
  }
  // ===== LUT =====
  /** Retained for sync (e.g. edit→batch transfer). Not used for rendering. */
  lut1RawData = null;
  lut1RawSize = 0;
  lut2RawData = null;
  lut2RawSize = 0;
  createLUT3DTexture(data, size) {
    const texture = new THREE3.Data3DTexture(data, size, size, size);
    texture.format = THREE3.RGBAFormat;
    texture.type = THREE3.FloatType;
    texture.minFilter = THREE3.LinearFilter;
    texture.magFilter = THREE3.LinearFilter;
    texture.wrapS = THREE3.ClampToEdgeWrapping;
    texture.wrapT = THREE3.ClampToEdgeWrapping;
    texture.wrapR = THREE3.ClampToEdgeWrapping;
    texture.needsUpdate = true;
    return texture;
  }
  // --- LUT1: Input Transform (before color grading — Log→Rec709) ---
  setLUT1(data, size) {
    const prev = this.material.uniforms.uLUT1?.value;
    if (prev) prev.dispose();
    this.material.uniforms.uLUT1.value = this.createLUT3DTexture(data, size);
    this.material.uniforms.uLUT1Enabled.value = 1;
    this.lut1RawData = data;
    this.lut1RawSize = size;
  }
  clearLUT1() {
    const tex = this.material.uniforms.uLUT1?.value;
    if (tex) tex.dispose();
    this.material.uniforms.uLUT1.value = null;
    this.material.uniforms.uLUT1Enabled.value = 0;
    this.lut1RawData = null;
    this.lut1RawSize = 0;
  }
  setLUT1Intensity(value) {
    this.material.uniforms.uLUT1Intensity.value = value;
  }
  // --- LUT2: Creative (after color grading — film look) ---
  setLUT2(data, size) {
    const prev = this.material.uniforms.uLUT2?.value;
    if (prev) prev.dispose();
    this.material.uniforms.uLUT2.value = this.createLUT3DTexture(data, size);
    this.material.uniforms.uLUT2Enabled.value = 1;
    this.lut2RawData = data;
    this.lut2RawSize = size;
  }
  clearLUT2() {
    const tex = this.material.uniforms.uLUT2?.value;
    if (tex) tex.dispose();
    this.material.uniforms.uLUT2.value = null;
    this.material.uniforms.uLUT2Enabled.value = 0;
    this.lut2RawData = null;
    this.lut2RawSize = 0;
  }
  setLUT2Intensity(value) {
    this.material.uniforms.uLUT2Intensity.value = value;
  }
  // --- Backward-compatible aliases (delegate to LUT2 / Creative) ---
  /** @deprecated Use setLUT2() */
  setLUT(data, size) {
    this.setLUT2(data, size);
  }
  /** @deprecated Use clearLUT2() */
  clearLUT() {
    this.clearLUT2();
  }
  /** @deprecated Use setLUT2Intensity() */
  setLUTIntensity(value) {
    this.setLUT2Intensity(value);
  }
  // --- LUT data getters (for edit→batch sync) ---
  getLUT1Snapshot() {
    if (!this.lut1RawData) return null;
    return {
      data: this.lut1RawData,
      size: this.lut1RawSize,
      intensity: this.material.uniforms.uLUT1Intensity.value
    };
  }
  getLUT2Snapshot() {
    if (!this.lut2RawData) return null;
    return {
      data: this.lut2RawData,
      size: this.lut2RawSize,
      intensity: this.material.uniforms.uLUT2Intensity.value
    };
  }
  // ===== Export Y-flip =====
  /**
   * @description エクスポート時の Y 反転。composite パスのみ反転し、中間 RT は通常方向を維持。
   * readPixels 後の CPU flip を不要にする。
   */
  setExportFlipY(flip) {
    this.compositeMaterial.uniforms.uFlipY.value = flip ? 1 : 0;
  }
  // ===== Before/After =====
  setSplitPosition(value) {
    this.material.uniforms.uSplitPosition.value = value;
  }
  /**
   * @description 合成パスが参照する分割位置（FilmLabCanvas の保存後復帰など）
   */
  getSplitPosition() {
    return this.material.uniforms.uSplitPosition.value;
  }
  // ===== Bulk Params (for presets) =====
  getParams() {
    return {
      exposure: this.material.uniforms.uExposure.value,
      contrast: this.material.uniforms.uContrast.value,
      saturation: this.material.uniforms.uSaturation.value,
      temperature: this.material.uniforms.uTemperature.value,
      tint: this.material.uniforms.uTint.value,
      shadowHue: this.splitShadowHueDeg,
      highlightHue: this.splitHighlightHueDeg,
      shadowTone: (() => {
        const u = this.material.uniforms.uShadowTint.value;
        const [ux, uy, uz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
        return (u.x * ux + u.y * uy + u.z * uz) / LEGACY_SHADOW_TONE_MAGNITUDE;
      })(),
      highlightTone: (() => {
        const u = this.material.uniforms.uHighlightTint.value;
        const [ux, uy, uz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
        return (u.x * ux + u.y * uy + u.z * uz) / LEGACY_HIGHLIGHT_TONE_MAGNITUDE;
      })(),
      rgbShift: this.material.uniforms.uRGBShift.value,
      grainIntensity: this.material.uniforms.uGrainIntensity.value,
      grainRadialMix: this.grainRadialMix,
      grainSize: this.material.uniforms.uGrainSize.value,
      lensSoftness: this.lensSoftness,
      vignette: this.material.uniforms.uVignette.value,
      fade: this.material.uniforms.uFade.value,
      highlights: this.material.uniforms.uHighlights.value,
      shadows: this.material.uniforms.uShadows.value,
      bloomThreshold: this.bloomThreshold,
      bloomStrength: this.bloomStrength,
      bloomRadius: this.bloomRadius,
      diffusion: this.diffusion,
      halationIntensity: this.halationIntensity,
      halationSpread: this.halationSpread,
      halationThreshold: this.halationThreshold,
      halationRadius: this.halationRadius,
      bloomSoftKnee: this.bloomSoftKnee,
      halationSoftKnee: this.halationSoftKnee,
      halationColor: `#${new THREE3.Color(this.halationColor.x, this.halationColor.y, this.halationColor.z).getHexString()}`,
      compressionAmount: this.material.uniforms.uCompressionAmount.value,
      compressionRange: this.material.uniforms.uCompressionRange.value,
      cyan: this.material.uniforms.uCyan.value,
      magenta: this.material.uniforms.uMagenta.value,
      yellow: this.material.uniforms.uYellow.value,
      printContrast: this.material.uniforms.uPrintContrast.value,
      shutterAngle: this.shutterAngle,
      trailIntensity: this.trailIntensity,
      motionBlurAmount: this.shutterAngle / 360,
      dustAmount: this.dustAmount,
      scratchAmount: this.scratchAmount,
      shaftIntensity: this.shaftIntensity,
      shaftDecay: this.shaftDecay,
      shaftOriginX: this.shaftOriginX,
      shaftOriginY: this.shaftOriginY,
      crossFilterStrength: this.crossFilterStrength,
      crossFilterSpikes: this.crossFilterSpikes,
      crossFilterAngle: this.crossFilterAngle,
      crossFilterLength: this.crossFilterLength,
      crossFilterThreshold: this.crossFilterThreshold,
      crossFilterChromatic: this.crossFilterChromatic,
      crossFilterSizeLimit: this.crossFilterSizeLimit,
      crossFilterRandomness: this.crossFilterRandomness,
      crossFilterHardMode: this.crossFilterHardMode,
      crossFilterMinSpacing: this.crossFilterMinSpacing
    };
  }
  setParams(params) {
    if (params.exposure !== void 0)
      this.setExposure(params.exposure);
    if (params.contrast !== void 0)
      this.setContrast(params.contrast);
    if (params.saturation !== void 0)
      this.setSaturation(params.saturation);
    if (params.temperature !== void 0)
      this.setTemperature(params.temperature);
    if (params.tint !== void 0) this.setTint(params.tint);
    if (params.shadowHue !== void 0 || params.shadowTone !== void 0) {
      let tone;
      if (params.shadowTone !== void 0) {
        tone = params.shadowTone;
        if (params.shadowHue !== void 0) {
          this.splitShadowHueDeg = params.shadowHue;
        }
      } else {
        const u = this.material.uniforms.uShadowTint.value;
        const [ox, oy, oz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
        tone = (u.x * ox + u.y * oy + u.z * oz) / LEGACY_SHADOW_TONE_MAGNITUDE;
        this.splitShadowHueDeg = params.shadowHue;
      }
      const [cx, cy, cz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
      this.material.uniforms.uShadowTint.value.set(cx, cy, cz).multiplyScalar(tone * LEGACY_SHADOW_TONE_MAGNITUDE);
    }
    if (params.highlightHue !== void 0 || params.highlightTone !== void 0) {
      let tone;
      if (params.highlightTone !== void 0) {
        tone = params.highlightTone;
        if (params.highlightHue !== void 0) {
          this.splitHighlightHueDeg = params.highlightHue;
        }
      } else {
        const u = this.material.uniforms.uHighlightTint.value;
        const [ox, oy, oz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
        tone = (u.x * ox + u.y * oy + u.z * oz) / LEGACY_HIGHLIGHT_TONE_MAGNITUDE;
        this.splitHighlightHueDeg = params.highlightHue;
      }
      const [cx, cy, cz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
      this.material.uniforms.uHighlightTint.value.set(cx, cy, cz).multiplyScalar(tone * LEGACY_HIGHLIGHT_TONE_MAGNITUDE);
    }
    if (params.rgbShift !== void 0)
      this.setRGBShift(params.rgbShift);
    if (params.grainIntensity !== void 0)
      this.setGrainIntensity(params.grainIntensity);
    if (params.grainRadialMix !== void 0)
      this.setGrainRadialMix(params.grainRadialMix);
    if (params.grainSize !== void 0)
      this.setGrainSize(params.grainSize);
    if (params.lensSoftness !== void 0)
      this.setLensSoftness(params.lensSoftness);
    if (params.detailSoftness !== void 0)
      this.detailSoftness = params.detailSoftness;
    if (params.vignette !== void 0)
      this.setVignette(params.vignette);
    if (params.fade !== void 0) this.setFade(params.fade);
    if (params.highlights !== void 0) this.setHighlights(params.highlights);
    if (params.shadows !== void 0) this.setShadows(params.shadows);
    if (params.bloomThreshold !== void 0)
      this.setBloomThreshold(params.bloomThreshold);
    if (params.bloomStrength !== void 0)
      this.setBloomStrength(params.bloomStrength);
    if (params.bloomRadius !== void 0)
      this.setBloomRadius(params.bloomRadius);
    if (params.diffusion !== void 0)
      this.setDiffusion(params.diffusion);
    if (params.halationIntensity !== void 0)
      this.setHalationIntensity(params.halationIntensity);
    if (params.halationSpread !== void 0)
      this.setHalationSpread(params.halationSpread);
    if (params.halationColor !== void 0)
      this.setHalationColor(params.halationColor);
    if (params.halationThreshold !== void 0)
      this.setHalationThreshold(params.halationThreshold);
    if (params.halationRadius !== void 0)
      this.setHalationRadius(params.halationRadius);
    else if (params.halationSpread !== void 0)
      this.setHalationRadius(Math.min(1, Math.max(0, params.halationSpread / 50)));
    if (params.bloomSoftKnee !== void 0)
      this.setBloomSoftKnee(params.bloomSoftKnee);
    if (params.halationSoftKnee !== void 0)
      this.setHalationSoftKnee(params.halationSoftKnee);
    if (params.compressionAmount !== void 0)
      this.material.uniforms.uCompressionAmount.value = params.compressionAmount;
    if (params.compressionRange !== void 0)
      this.material.uniforms.uCompressionRange.value = params.compressionRange;
    if (params.cyan !== void 0)
      this.material.uniforms.uCyan.value = params.cyan;
    if (params.magenta !== void 0)
      this.material.uniforms.uMagenta.value = params.magenta;
    if (params.yellow !== void 0)
      this.material.uniforms.uYellow.value = params.yellow;
    if (params.printContrast !== void 0)
      this.material.uniforms.uPrintContrast.value = params.printContrast;
    if (params.shutterAngle !== void 0) {
      this.setShutterAngle(params.shutterAngle);
    } else if (params.motionBlurAmount !== void 0) {
      this.setMotionBlurAmount(params.motionBlurAmount);
    }
    if (params.trailIntensity !== void 0)
      this.setTrailIntensity(params.trailIntensity);
    if (params.dustAmount !== void 0)
      this.setDustAmount(params.dustAmount);
    if (params.scratchAmount !== void 0)
      this.setScratchAmount(params.scratchAmount);
    if (params.shaftIntensity !== void 0)
      this.setShaftIntensity(params.shaftIntensity);
    if (params.shaftDecay !== void 0)
      this.setShaftDecay(params.shaftDecay);
    if (params.shaftOriginX !== void 0)
      this.setShaftOriginX(params.shaftOriginX);
    if (params.shaftOriginY !== void 0)
      this.setShaftOriginY(params.shaftOriginY);
    if (params.crossFilterStrength !== void 0)
      this.setCrossFilterStrength(params.crossFilterStrength);
    if (params.crossFilterSpikes !== void 0)
      this.setCrossFilterSpikes(params.crossFilterSpikes);
    if (params.crossFilterAngle !== void 0)
      this.setCrossFilterAngle(params.crossFilterAngle);
    if (params.crossFilterLength !== void 0)
      this.setCrossFilterLength(params.crossFilterLength);
    if (params.crossFilterThreshold !== void 0)
      this.setCrossFilterThreshold(params.crossFilterThreshold);
    if (params.crossFilterChromatic !== void 0)
      this.setCrossFilterChromatic(params.crossFilterChromatic);
    if (params.crossFilterSizeLimit !== void 0)
      this.setCrossFilterSizeLimit(params.crossFilterSizeLimit);
    if (params.crossFilterRandomness !== void 0)
      this.setCrossFilterRandomness(params.crossFilterRandomness);
    if (params.crossFilterHardMode !== void 0)
      this.setCrossFilterHardMode(params.crossFilterHardMode);
    if (params.crossFilterMinSpacing !== void 0)
      this.setCrossFilterMinSpacing(params.crossFilterMinSpacing);
  }
  // ===== Histogram readback =====
  /** カラーグレード済みRTからピクセルデータを取得（ヒストグラム用） */
  getHistogramPixels() {
    if (!this.rtColorGraded || !this.renderer) return null;
    const rt = this.rtColorGraded;
    const w = rt.width;
    const h = rt.height;
    if (w <= 0 || h <= 0) return null;
    const size = w * h * 4;
    if (!this.histogramHalfBuffer || this.histogramHalfBuffer.length !== size) {
      this.histogramHalfBuffer = new Uint16Array(size);
    }
    if (!this.histogramBuffer || this.histogramBuffer.length !== size) {
      this.histogramBuffer = new Float32Array(size);
    }
    this.renderer.readRenderTargetPixels(rt, 0, 0, w, h, this.histogramHalfBuffer);
    const half = this.histogramHalfBuffer;
    const out = this.histogramBuffer;
    for (let i = 0; i < size; i++) {
      out[i] = THREE3.DataUtils.fromHalfFloat(half[i]);
    }
    return { pixels: out, width: w, height: h };
  }
  // ===== Dispose =====
  /** `RenderBackend.destroy()` — alias for legacy `dispose()`. */
  destroy() {
    this.dispose();
  }
  dispose() {
    this.geometry.dispose();
    this.material.dispose();
    this.postGeometry.dispose();
    this.bloomPrefilterMaterial.dispose();
    this.halationPrefilterMaterial.dispose();
    this.detailSoftnessMaterial.dispose();
    this.downsampleMaterial.dispose();
    this.upsampleMaterial.dispose();
    this.compositeMaterial.dispose();
    this.rtColorGraded?.dispose();
    this.rtDetailSoftened?.dispose();
    for (const rt of this.rtBloomMips) rt.dispose();
    for (const rt of this.rtHalationMips) rt.dispose();
    for (const rt of this.rtDiffusionMips) rt.dispose();
    this.rtDiffusionMips = [];
    this.rtCompareComposite?.dispose();
    this.rtPostComposite0?.dispose();
    this.rtPostComposite1?.dispose();
    this.ringCopyMaterial?.dispose();
    this.ringBlendMaterial?.dispose();
    for (const rt of this.rtRingBuffer) rt.dispose();
    this.rtRingBuffer = [];
    this.dustMaterial?.dispose();
    this.dustTexture?.dispose();
    this.scratchTexture?.dispose();
    this.shaftMaterial?.dispose();
    this.shaftBlendMaterial?.dispose();
    this.rtShaft?.dispose();
    this.crossFilterStreakMaterial?.dispose();
    this.crossFilterPeakSpacingMaxMaterial?.dispose();
    this.crossFilterPeakSpacingMaterial?.dispose();
    this.crossFilterBlendMaterial?.dispose();
    this.crossFilterPeakMaterial?.dispose();
    this.crossFilterTemporalMaterial?.dispose();
    this.crossFilterDebugMaterial?.dispose();
    this.rtCrossThreshold?.dispose();
    this.rtCrossPeak?.dispose();
    this.rtCrossPeakSpacingWork?.dispose();
    this.rtCrossPeakSpacingMax?.dispose();
    this.rtCrossPeakSpaced?.dispose();
    for (const rt of this.rtCrossPeakHistory) rt.dispose();
    this.rtCrossPeakHistory = [];
    for (const rt of this.rtCrossStreak) rt.dispose();
    this.rtCrossStreak = [];
    for (const rt of this.rtCentralBloomMips) rt.dispose();
    this.rtCentralBloomMips = [];
    const lut1Texture = this.material.uniforms.uLUT1?.value;
    if (lut1Texture) lut1Texture.dispose();
    const lut2Texture = this.material.uniforms.uLUT2?.value;
    if (lut2Texture) lut2Texture.dispose();
    const mediaTexture = this.material.uniforms.uTexture?.value;
    if (mediaTexture) mediaTexture.dispose();
    this.histogramBuffer = null;
    this.histogramHalfBuffer = null;
    this.renderer = null;
  }
};

// src/webgl/shaders/filmlab.frag.ts
var filmlabFragmentShader = (
  /* glsl */
  `
precision highp float;
precision highp sampler3D;

uniform sampler2D uTexture;
uniform vec2 uResolution;
uniform vec2 uImageResolution;
uniform float uTime;

uniform float uExposure;
uniform float uContrast;
uniform float uSaturation;
uniform float uTemperature;
uniform float uTint;

uniform float uRGBShift;
uniform float uGrainIntensity;
uniform float uVignette;

uniform float uFade;
uniform float uHighlights;
uniform float uShadows;
// \u30B7\u30E3\u30C9\u30A6\uFF0F\u30CF\u30A4\u30E9\u30A4\u30C8\u306E vec3 \u306F JS \u5074\u3067\u8272\u76F8\uFF08HSL \u5F69\u5EA6\u65B9\u5411\uFF09\xD7 \u5F37\u5EA6 \xD7 \u30EC\u30AC\u30B7\u30FC\u9577\u3055\u304B\u3089\u5408\u6210\uFF08\u8EF8 E \u8272\u76F8\u62E1\u5F35\uFF09
uniform vec3 uShadowTint;
uniform vec3 uHighlightTint;

uniform float uSplitPosition;

// Input Transform LUT (applied before color grading \u2014 Log\u2192Rec709)
uniform highp sampler3D uLUT1;
uniform float uLUT1Intensity;
uniform float uLUT1Enabled;

// Creative LUT (applied after color grading \u2014 film look)
uniform highp sampler3D uLUT2;
uniform float uLUT2Intensity;
uniform float uLUT2Enabled;

// 0.4.0 \u306E\u73FE\u50CF\u6BB5\u3067\u4F7F\u3046\u6570\u5024 uniform\u3002
uniform float uCompressionAmount;  // 0\u301C1\u30010 \u3067\u7121\u52B9
uniform float uCompressionRange;   // 0\u301C1\u30010.5 \u304C\u65E2\u5B9A

// 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3067\u4F7F\u3046\u6570\u5024 uniform\u3002
uniform float uCyan;               // -1\u301C1\u30010 \u3067\u7121\u52B9
uniform float uMagenta;            // -1\u301C1\u30010 \u3067\u7121\u52B9
uniform float uYellow;              // -1\u301C1\u30010 \u3067\u7121\u52B9
uniform float uPrintContrast;      // 0\u301C1\u30010 \u3067\u7121\u52B9

uniform float uFitMode; // 0.0 = cover (crop), 1.0 = contain (letterbox)

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
  // Contain: center narrow portraits in the left half (x=25%)
  // Applies when image occupies < 50% of screen width (scale.x > 2.0)
  float narrowPortrait = step(2.0, scale.x) * uFitMode;
  result.x += 0.18 * scale.x * narrowPortrait;
  return result;
}

float insideUv(vec2 uv) {
  vec2 s = step(0.0, uv) * step(uv, vec2(1.0));
  return s.x * s.y;
}

// Cover UV: zoom video to fill entire screen (for blurred background)
vec2 bgCoverUv(vec2 uv, vec2 resolution, vec2 imageResolution) {
  float screenAspect = resolution.x / resolution.y;
  float imageAspect = imageResolution.x / imageResolution.y;
  vec2 scale = screenAspect > imageAspect
    ? vec2(1.0, imageAspect / screenAspect)
    : vec2(screenAspect / imageAspect, 1.0);
  return (uv - 0.5) * scale + 0.5;
}

// Feathered mask for soft edge between sharp image and blurred background
float softMask(vec2 uv, float feather) {
  vec2 d = smoothstep(vec2(0.0), vec2(feather), uv)
         * smoothstep(vec2(0.0), vec2(feather), 1.0 - uv);
  return d.x * d.y;
}

/**
 * \u30EC\u30F3\u30BA\u5468\u8FBA\u306E\u8272\u53CE\u5DEE\u306B\u8FD1\u3044\u898B\u3048\u65B9: \u753B\u50CF\u4E2D\u5FC3\u3067\u306F\u30BC\u30ED\u3001\u30D5\u30EC\u30FC\u30E0\u7AEF\u307B\u3069 R/B \u3092\u653E\u5C04\u65B9\u5411\u306B\u305A\u3089\u3059\u3002
 * amount \u306F\u30B9\u30E9\u30A4\u30C0\u4E0A\u9650\uFF08\u5468\u8FBA\u3067\u6700\u5927\u306B\u8FD1\u3044\u91CF\uFF09\u3002\u30A2\u30B9\u30DA\u30AF\u30C8\u88DC\u6B63\u3067\u8DDD\u96E2\u30DE\u30B9\u30AF\u3092\u5186\u5F62\u306B\u63C3\u3048\u308B\u3002
 */
vec4 rgbShiftSampleRadial(sampler2D tex, vec2 uv, float amount, vec2 imageResolution) {
  vec2 delta = uv - 0.5;
  delta.x *= imageResolution.x / max(imageResolution.y, 1.0);
  float radial = clamp(length(delta) * 2.0, 0.0, 1.0);
  float weight = pow(radial, 1.65);
  float amt = amount * weight;
  vec2 dir = normalize(delta + vec2(1e-5));
  float rCh = textureLod(tex, uv + dir * amt, 0.0).r;
  float gCh = textureLod(tex, uv, 0.0).g;
  float bCh = textureLod(tex, uv - dir * amt, 0.0).b;
  float aCh = textureLod(tex, uv, 0.0).a;
  return vec4(rCh, gCh, bCh, aCh);
}

float grain(vec2 uv, float time) {
  return fract(sin(dot(uv * time, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

// \u30EB\u30DF\u30CA\u30F3\u30B9\u3092\u4FDD\u3063\u305F\u307E\u307E S \u30AB\u30FC\u30D6\u3067\u5727\u7E2E\u3059\u308B\uFF080.4.0\uFF09\u3002
// amount=0 \u306A\u3089\u4F55\u3082\u3057\u306A\u3044\u3002range \u306F\u80A9\uFF0F\u8DB3\u306E\u5E83\u3055\u3002\u9AD8 range\uFF0B\u9AD8 amount \u3067\u8F2A\u90ED\u306B\u6BB5\u5DEE\u304C\u51FA\u3084\u3059\u3044\u305F\u3081
// k \u306E\u632F\u308C\u5E45\u3092\u3084\u3084\u6291\u3048\u3001sigmoid \u5165\u529B\u3092 clamp \u3057\u3001range \u304C\u6975\u7AEF\u306B\u9AD8\u3044\u3068\u304D\u3060\u3051 amount \u3092\u8EFD\u304F\u6E1B\u8870\u3059\u308B\u3002
vec3 applyFilmCompression(vec3 rgb, float amount, float range) {
  if (amount < 0.001) return rgb;
  float r = clamp(range, 0.0, 1.0);
  float k = mix(5.15, 2.85, r);
  float rangeSoft = smoothstep(0.82, 1.0, r);
  float amt = amount * (1.0 - 0.18 * rangeSoft);
  float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
  float x = clamp(k * (luma - 0.5), -5.5, 5.5);
  float s = 1.0 / (1.0 + exp(-x));
  float lumaScale = luma > 0.001 ? mix(luma, s, amt) / luma : 1.0;
  return clamp(rgb * lumaScale, 0.0, 1.0);
}

// \u30D7\u30EA\u30F3\u30C8\u6BB5\u306E\u6700\u7D42\u30B3\u30F3\u30C8\u30E9\u30B9\u30C8\u3092 S \u30AB\u30FC\u30D6\u3067\u6301\u3061\u4E0A\u3052\u308B\u3002
// amount=0 \u306A\u3089\u4F55\u3082\u3057\u306A\u3044\u3002
vec3 applyPrintContrast(vec3 rgb, float amount) {
  if (amount < 0.001) return rgb;
  float k = mix(1.0, 5.0, amount);
  vec3 s = 1.0 / (1.0 + exp(-k * (rgb - 0.5)));
  return clamp(mix(rgb, s, amount), 0.0, 1.0);
}

void main() {
  vec2 uv = fitUv(vUv, uResolution, uImageResolution);
  float mask = insideUv(uv);

  vec4 color = uRGBShift > 0.0
    ? rgbShiftSampleRadial(uTexture, uv, uRGBShift, uImageResolution)
    : textureLod(uTexture, uv, 0.0);

  // === Input Transform LUT (LUT1) === before color grading
  if (uLUT1Enabled > 0.5) {
    vec3 lut1Coord = clamp(color.rgb, 0.0, 1.0);
    color.rgb = mix(color.rgb, texture(uLUT1, lut1Coord).rgb, uLUT1Intensity);
  }

  // Exposure
  color.rgb *= pow(2.0, uExposure);

  // Contrast
  color.rgb = (color.rgb - 0.5) * uContrast + 0.5;

  // Saturation
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  color.rgb = mix(vec3(luma), color.rgb, uSaturation);

  // Temperature
  color.r += uTemperature * 0.1;
  color.b -= uTemperature * 0.1;

  // Tint (green / magenta axis)
  color.r += uTint * 0.05;
  color.g -= uTint * 0.08;
  color.b += uTint * 0.05;

  // Split toning
  float lumST = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  color.rgb += uShadowTint * (1.0 - lumST) * 0.18;
  color.rgb += uHighlightTint * lumST * 0.18;

  // Fade (Lift \u2014 \u30D5\u30A3\u30EB\u30E0\u306E\u300C\u6D6E\u3044\u305F\u9ED2\u300D)
  color.rgb = color.rgb + uFade * (1.0 - color.rgb);

  // Highlights / Shadows
  float lumHS = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  color.rgb += uShadows * (1.0 - lumHS) * 0.5;
  color.rgb += uHighlights * lumHS * 0.5;

  // 0.4.0 \u306E\u30CD\u30AC\u5727\u7E2E\u3002LUT2 \u306E\u524D\u3067\u52B9\u304B\u305B\u308B\u3002
  color.rgb = applyFilmCompression(color.rgb, uCompressionAmount, uCompressionRange);

  // === Creative LUT (LUT2) === after color grading
  if (uLUT2Enabled > 0.5) {
    vec3 lut2Coord = clamp(color.rgb, 0.0, 1.0);
    color.rgb = mix(color.rgb, texture(uLUT2, lut2Coord).rgb, uLUT2Intensity);
  }

  // 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3002CMY \u306E\u8272\u304B\u3076\u308A\u3092\u8DB3\u3059\u3002
  // C = -R, M = -G, Y = -B \u306E\u6697\u5BA4\u306E\u8003\u3048\u65B9\u306B\u5408\u308F\u305B\u308B\u3002
  float cmyScale = 0.15;  // 1.0 \u3067\u304A\u3088\u305D 0.15 \u306E RGB \u5909\u5316\u306B\u3059\u308B
  color.r -= uCyan    * cmyScale;
  color.g -= uMagenta * cmyScale;
  color.b -= uYellow  * cmyScale;

  // 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3002\u6700\u5F8C\u306B\u7D19\u306E\u786C\u3055\u3092\u8DB3\u3059\u3002
  color.rgb = applyPrintContrast(color.rgb, uPrintContrast);

  color.rgb = clamp(color.rgb, 0.0, 1.0);

  if (uFitMode > 0.5) {
    // Frosted glass background for letterbox areas (contain mode)
    vec2 bgUv = bgCoverUv(vUv, uResolution, uImageResolution);
    vec3 bgSample = textureLod(uTexture, bgUv, 3.0).rgb * 0.6
                  + textureLod(uTexture, bgUv, 4.0).rgb * 0.4;

    // Desaturate
    float bgLuma = dot(bgSample, vec3(0.2126, 0.7152, 0.0722));
    vec3 bgColor = mix(vec3(bgLuma), bgSample, 0.60);

    // Brightness
    bgColor *= 0.45;

    // Minimum luminance floor (prevent pure black in dark scenes)
    bgColor = max(bgColor, vec3(0.02));

    // Background vignette (darken corners ~15%)
    float bgDist = length(vUv - 0.5);
    float bgVig = 1.0 - smoothstep(0.3, 0.85, bgDist);
    bgColor *= mix(0.55, 1.0, bgVig);

    // Blend: sharp image inside bounds, blurred background outside
    fragColor = vec4(mix(bgColor, color.rgb, mask), 1.0);
  } else {
    fragColor = vec4(color.rgb, 1.0);
  }
}
`
);

// src/support.ts
function isWebGL2Supported() {
  if (typeof document === "undefined") return false;
  const canvas = document.createElement("canvas");
  return canvas.getContext("webgl2") !== null;
}
function getOptimalPixelRatio(maxRatio = 1.5) {
  if (typeof window === "undefined") return 1;
  return Math.min(window.devicePixelRatio, maxRatio);
}
var _webgpuSupportCache = null;
var _webgpuSupportInflight = null;
async function isWebGPUSupported() {
  if (_webgpuSupportCache !== null) return _webgpuSupportCache;
  if (_webgpuSupportInflight) return _webgpuSupportInflight;
  _webgpuSupportInflight = (async () => {
    if (typeof navigator === "undefined") return false;
    const gpu = navigator.gpu;
    if (!gpu) return false;
    try {
      const adapter = await gpu.requestAdapter();
      return adapter !== null;
    } catch {
      return false;
    }
  })();
  const result = await _webgpuSupportInflight;
  _webgpuSupportCache = result;
  _webgpuSupportInflight = null;
  return result;
}

// src/Viewport.ts
var WEBGL_VIEWPORT_CAPABILITIES = Object.freeze({
  backendKind: "webgl",
  supportsCompare: true,
  supportsHistogram: true,
  supportsBeforeAfter: true,
  supportsABCompare: true,
  supportsLiveVideoTexture: true,
  maxTextureDimension2D: 8192
});
var Viewport = class _Viewport {
  webglBackend;
  webgpuBackend;
  backendKind;
  capabilities;
  /**
   * WebGL-only handle to the fullscreen `THREE.Mesh`. `undefined` on the
   * WebGPU path — consumer code that does `scene.add(viewport.mesh)` MUST
   * gate on `viewport.backendKind === 'webgl'` first.
   */
  mesh;
  webgpuSetTextureGen = 0;
  constructor(webgl, webgpu) {
    this.webglBackend = webgl;
    this.webgpuBackend = webgpu;
    this.backendKind = webgpu !== null ? "webgpu" : "webgl";
    this.capabilities = webgpu?.capabilities ?? WEBGL_VIEWPORT_CAPABILITIES;
    if (webgl) this.mesh = webgl.mesh;
  }
  static async create(canvas, opts = {}) {
    const width = Math.max(
      1,
      Math.floor(opts.width ?? canvas.clientWidth ?? canvas.width ?? 1)
    );
    const height = Math.max(
      1,
      Math.floor(opts.height ?? canvas.clientHeight ?? canvas.height ?? 1)
    );
    const prefer = opts.prefer ?? "webgpu";
    if (prefer === "webgpu") {
      if (!await isWebGPUSupported()) {
        throw new Error(
          "[Viewport] WebGPU is required but not supported in this environment"
        );
      }
      const { WebGPUBackend } = await import("./WebGPUBackend-ZWXPWBXF.js");
      const backend = await WebGPUBackend.create(canvas);
      backend.setResolution(width, height);
      return new _Viewport(null, backend);
    }
    const webgl = new WebGLBackend({
      vertexShader: filmlabVertexShader,
      fragmentShader: filmlabFragmentShader,
      width,
      height
    });
    return new _Viewport(webgl, null);
  }
  // === Core delegation ===
  render(renderer, scene, camera) {
    if (this.webgpuBackend) {
      this.webgpuBackend.render();
      return;
    }
    this.webglBackend.render(renderer, scene, camera);
  }
  setResolution(width, height) {
    if (this.webgpuBackend) this.webgpuBackend.setResolution(width, height);
    else this.webglBackend.setResolution(width, height);
  }
  /**
   * WebGL: sets the `THREE.Texture` uniform directly.
   * WebGPU: extracts the texture's source (`HTMLImageElement`,
   * `HTMLVideoElement`, `ImageBitmap`, etc.) and uploads via
   * `createImageBitmap` + `setMediaFromBitmap`. The conversion is async and
   * fire-and-forget; callers can continue rendering — the new image appears
   * on the next frame after the bitmap is ready. Generation counter drops
   * stale results if `setTexture` is called multiple times in flight.
   */
  setTexture(texture) {
    if (this.webglBackend) {
      this.webglBackend.setTexture(texture);
      return;
    }
    if (this.webgpuBackend) {
      void this.queueSetTextureWebGPU(texture);
    }
  }
  /** WebGPU-native path; WebGL consumers should call `setTexture` instead. */
  setMediaFromBitmap(bitmap) {
    this.webgpuBackend?.setMediaFromBitmap(bitmap);
  }
  /** WebGPU-native path for reusable Canvas / VideoFrame-style uploads. */
  setMediaFromExternalImageSource(source, width, height) {
    this.webgpuBackend?.setMediaFromExternalImageSource(source, width, height);
  }
  /**
   * Upload a shared depth map for depth-aware Mist / Glow. No-op on WebGL.
   * `depthMistGain` / `depthGlowGain` stay in the shared grade contract; the
   * WebGPU renderer consumes the uploaded depth texture when those gains are > 0.
   */
  setDepthFromBitmap(bitmap) {
    this.webgpuBackend?.setDepthFromBitmap(bitmap);
  }
  /**
   * Camera optics are consumed by the WebGPU ray-angle model. WebGL keeps
   * legacy behavior and ignores the value.
   */
  setCameraOptics(optics) {
    this.webgpuBackend?.setCameraOptics(optics);
  }
  setImageResolution(width, height) {
    if (this.webgpuBackend) this.webgpuBackend.setImageResolution(width, height);
    else this.webglBackend.setImageResolution(width, height);
  }
  setFitMode(mode) {
    if (this.webgpuBackend) this.webgpuBackend.setFitMode(mode);
    else this.webglBackend.setFitMode(mode);
  }
  setTime(time) {
    if (this.webgpuBackend) this.webgpuBackend.setTime(time);
    else this.webglBackend.setTime(time);
  }
  setParams(params) {
    if (this.webgpuBackend) {
      this.webgpuBackend.setParams(params);
      return;
    }
    this.webglBackend.setParams(params);
  }
  getParams() {
    if (this.webglBackend) return this.webglBackend.getParams();
    const pending = this.webgpuBackend?.getPendingParams() ?? {};
    return pending;
  }
  getCapabilities() {
    return this.capabilities;
  }
  isContextLost() {
    return this.webgpuBackend?.isContextLost() ?? false;
  }
  getContextLossInfo() {
    return this.webgpuBackend?.getContextLossInfo() ?? null;
  }
  onContextLost(listener) {
    return this.webgpuBackend?.onContextLost(listener) ?? (() => {
    });
  }
  // === LUTs ===
  setLUT1(data, size) {
    if (this.webgpuBackend) this.webgpuBackend.setLUT1(data, size);
    else this.webglBackend.setLUT1(data, size);
  }
  setLUT1Intensity(value) {
    if (this.webgpuBackend) this.webgpuBackend.setLUT1Intensity(value);
    else this.webglBackend.setLUT1Intensity(value);
  }
  clearLUT1() {
    if (this.webgpuBackend) this.webgpuBackend.clearLUT1();
    else this.webglBackend.clearLUT1();
  }
  setLUT2(data, size) {
    if (this.webgpuBackend) this.webgpuBackend.setLUT2(data, size);
    else this.webglBackend.setLUT2(data, size);
  }
  setLUT2Intensity(value) {
    if (this.webgpuBackend) this.webgpuBackend.setLUT2Intensity(value);
    else this.webglBackend.setLUT2Intensity(value);
  }
  clearLUT2() {
    if (this.webgpuBackend) this.webgpuBackend.clearLUT2();
    else this.webglBackend.clearLUT2();
  }
  /**
   * WebGL-only snapshot for edit→batch sync and video export. WebGPU path
   * returns `null` in v1.0 — consumers must gate on `backendKind === 'webgl'`
   * or accept the no-op fallback.
   */
  getLUT1Snapshot() {
    return this.webglBackend?.getLUT1Snapshot() ?? null;
  }
  getLUT2Snapshot() {
    return this.webglBackend?.getLUT2Snapshot() ?? null;
  }
  /** @deprecated Use setLUT2() — kept for legacy apps/webgl-study debug-gui. */
  setLUT(data, size) {
    this.setLUT2(data, size);
  }
  /** @deprecated Use clearLUT2() */
  clearLUT() {
    this.clearLUT2();
  }
  /** @deprecated Use setLUT2Intensity() */
  setLUTIntensity(value) {
    this.setLUT2Intensity(value);
  }
  // === Split / flipY ===
  setSplitPosition(value) {
    if (this.webgpuBackend) this.webgpuBackend.setSplitPosition(value);
    else this.webglBackend.setSplitPosition(value);
  }
  getSplitPosition() {
    if (this.webglBackend) return this.webglBackend.getSplitPosition();
    return this.webgpuBackend?.getSplitPosition() ?? -1;
  }
  setExportFlipY(flip) {
    if (this.webgpuBackend) this.webgpuBackend.setFlipY(flip);
    else this.webglBackend.setExportFlipY(flip);
  }
  // === Motion blur ===
  resetMotionBlurHistory() {
    this.webglBackend?.resetMotionBlurHistory();
    this.webgpuBackend?.resetMotionBlurHistory();
  }
  // === Compare ===
  /**
   * v1 compare-bar: WebGPU honors `enabled` only and renders a full-screen
   * "ungraded source" present pass when active (slot params ignored —
   * dual-slot simultaneous A/B parity stays deferred). WebGL retains full
   * dual-grade behavior.
   */
  setComparePair(enabled, paramsA, paramsB) {
    if (this.webgpuBackend) {
      this.webgpuBackend.setComparePair(enabled, paramsA, paramsB);
      return;
    }
    this.webglBackend?.setComparePair(enabled, paramsA, paramsB);
  }
  // === WebGL-only (no-op on WebGPU in v1.0) ===
  bindThree(renderer, scene, camera) {
    this.webglBackend?.bindThree(renderer, scene, camera);
  }
  getHistogramPixels() {
    return this.webglBackend?.getHistogramPixels() ?? null;
  }
  // === WebGPU-only ===
  /**
   * Phase 3 T3-3: prewarm WebGPU pipeline JIT.
   *
   * Issues a single render at current resolution so first real frame does
   * not stutter on pipeline compile. Caller should run inside
   * `requestIdleCallback` — DIRECTION §10 Phase 3 UX budget is 150 ms
   * silent / 300 ms overlay fadeout.
   *
   * No-op on WebGL (no JIT cost there).
   */
  async prewarm() {
    if (!this.webgpuBackend) return;
    this.webgpuBackend.prewarm();
  }
  setReadbackEnabled(enabled) {
    this.webgpuBackend?.setReadbackEnabled(enabled);
  }
  async readbackRgba8() {
    if (!this.webgpuBackend) {
      throw new Error("[Viewport] readbackRgba8 is only available on the WebGPU backend");
    }
    return this.webgpuBackend.readbackRgba8();
  }
  // === Disposal ===
  dispose() {
    this.webglBackend?.dispose();
    this.webgpuBackend?.destroy();
  }
  /** RenderBackend interface alias. */
  destroy() {
    this.dispose();
  }
  // === Internal ===
  async queueSetTextureWebGPU(texture) {
    if (!this.webgpuBackend) return;
    const generation = ++this.webgpuSetTextureGen;
    const source = texture.source?.data ?? texture.image;
    if (!source) return;
    if (typeof HTMLVideoElement !== "undefined" && source instanceof HTMLVideoElement) {
      this.webgpuBackend.setMediaFromVideoElement(source);
      return;
    }
    try {
      let bitmap;
      let ownsBitmap = false;
      if (source instanceof ImageBitmap) {
        bitmap = source;
      } else if (typeof createImageBitmap === "function") {
        bitmap = await createImageBitmap(
          source
        );
        ownsBitmap = true;
      } else {
        return;
      }
      if (generation !== this.webgpuSetTextureGen) {
        if (ownsBitmap) {
          bitmap.close?.();
        }
        return;
      }
      if (this.webgpuBackend) {
        this.webgpuBackend.setMediaFromBitmap(bitmap);
      }
      if (ownsBitmap) {
        bitmap.close?.();
      }
    } catch (err) {
      console.warn("[Viewport] setTexture \u2192 ImageBitmap failed", err);
    }
  }
};

// src/MediaLoader.ts
import * as THREE4 from "three";
var MediaLoadError = class extends Error {
  constructor(message, code) {
    super(message);
    this.code = code;
    this.name = "MediaLoadError";
  }
};
var HEIC_MIME = /heic|heif/i;
var LIKELY_VIDEO_EXTENSION = /\.(mp4|m4v|mov|webm|ogv|mkv)$/i;
function isFilmLabMediaDebugEnabled() {
  if (typeof window === "undefined") return false;
  try {
    return new URLSearchParams(window.location.search).get("filmLabDebugMedia") === "1";
  } catch {
    return false;
  }
}
function isLikelyHeicFile(file) {
  if (file.type && HEIC_MIME.test(file.type)) return true;
  return /\.(heic|heif)$/i.test(file.name);
}
function getDrawableSize(source) {
  if (source instanceof HTMLCanvasElement) {
    return { w: source.width, h: source.height };
  }
  return { w: source.naturalWidth, h: source.naturalHeight };
}
function scaleSourceToMaxDimension(source, maxDim) {
  const { w, h } = getDrawableSize(source);
  if (!w || !h) return source;
  const longEdge = Math.max(w, h);
  if (longEdge <= maxDim) return source;
  const scale = maxDim / longEdge;
  const nw = Math.max(1, Math.floor(w * scale));
  const nh = Math.max(1, Math.floor(h * scale));
  const canvas = document.createElement("canvas");
  canvas.width = nw;
  canvas.height = nh;
  const ctx = canvas.getContext("2d");
  if (!ctx) return source;
  ctx.drawImage(source, 0, 0, nw, nh);
  return canvas;
}
function textureFromDrawable(drawable, maxTextureSize) {
  const maxDim = maxTextureSize ?? Number.POSITIVE_INFINITY;
  const scaled = scaleSourceToMaxDimension(drawable, maxDim);
  const { w, h } = getDrawableSize(scaled);
  const texture = new THREE4.Texture(scaled);
  texture.colorSpace = THREE4.SRGBColorSpace;
  texture.minFilter = THREE4.LinearFilter;
  texture.magFilter = THREE4.LinearFilter;
  texture.needsUpdate = true;
  return {
    texture,
    width: w,
    height: h,
    type: "image"
  };
}
async function decodeViaCreateImageBitmap(blob, maxTextureSize, debug, label) {
  if (typeof createImageBitmap !== "function") {
    throw new Error("createImageBitmap is not available");
  }
  let bitmap = null;
  try {
    bitmap = await createImageBitmap(blob);
    if (debug) {
      console.info(`[FilmLab MediaLoader] createImageBitmap OK (${label})`, {
        width: bitmap.width,
        height: bitmap.height
      });
    }
    const canvas = document.createElement("canvas");
    canvas.width = bitmap.width;
    canvas.height = bitmap.height;
    const ctx = canvas.getContext("2d");
    if (!ctx) {
      throw new Error("Could not get 2d context for ImageBitmap transfer");
    }
    ctx.drawImage(bitmap, 0, 0);
    bitmap.close();
    bitmap = null;
    return textureFromDrawable(canvas, maxTextureSize);
  } catch (err) {
    if (bitmap) {
      try {
        bitmap.close();
      } catch {
      }
    }
    if (debug) {
      console.warn(`[FilmLab MediaLoader] createImageBitmap failed (${label})`, err);
    }
    throw err;
  }
}
function decodeViaImageElement(file, maxTextureSize) {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const img = new Image();
    const cleanupUrl = () => {
      try {
        URL.revokeObjectURL(url);
      } catch {
      }
    };
    img.onload = () => {
      try {
        const result = textureFromDrawable(img, maxTextureSize);
        cleanupUrl();
        resolve(result);
      } catch (err) {
        cleanupUrl();
        const message = err instanceof Error ? err.message : String(err);
        reject(
          new MediaLoadError(
            `Could not build texture from image (${message}). Try JPEG or PNG.`,
            "IMAGE_DECODE_FAILED"
          )
        );
      }
    };
    img.onerror = () => {
      cleanupUrl();
      reject(new Error("HTMLImageElement failed to decode (onerror)"));
    };
    img.src = url;
  });
}
var MediaLoader = class {
  async loadFile(file, options = {}) {
    if (isLikelyHeicFile(file)) {
      throw new MediaLoadError(
        "HEIC/HEIF is not supported in the browser. Export as JPEG in Photos, then try again.",
        "HEIC_UNSUPPORTED"
      );
    }
    if (file.type.startsWith("video/") || LIKELY_VIDEO_EXTENSION.test(file.name)) {
      return this.loadVideo(file);
    }
    return this.loadImage(file, options.maxTextureSize);
  }
  /**
   * 画像をデコードしてテクスチャにする。
   * Safari 等で Image 経路が落ちた場合は createImageBitmap を順に試す。
   */
  async loadImage(file, maxTextureSize) {
    const debug = isFilmLabMediaDebugEnabled();
    const meta = {
      name: file.name,
      type: file.type || "(empty)",
      size: file.size,
      ua: typeof navigator !== "undefined" ? navigator.userAgent : ""
    };
    if (debug) {
      console.info("[FilmLab MediaLoader] loadImage start", meta);
    }
    let imageElementError;
    try {
      return await decodeViaImageElement(file, maxTextureSize);
    } catch (err) {
      imageElementError = err;
      if (debug) {
        console.warn("[FilmLab MediaLoader] Image() + blob URL path failed", err);
      }
    }
    const safariHint = typeof navigator !== "undefined" && /Safari/i.test(navigator.userAgent) && !/Chrome|Chromium|CriOS/i.test(navigator.userAgent) ? " Safari \u3067\u306F\u3001\u30C7\u30A3\u30B9\u30D7\u30EC\u30A4\u30D7\u30ED\u30D5\u30A1\u30A4\u30EB\u4ED8\u304D\u306E PNG \u30B9\u30AF\u30EA\u30FC\u30F3\u30B7\u30E7\u30C3\u30C8\u304C Image \u30C7\u30B3\u30FC\u30C9\u306B\u5931\u6557\u3059\u308B\u3053\u3068\u304C\u3042\u308A\u307E\u3059\u3002" : "";
    try {
      return await decodeViaCreateImageBitmap(file, maxTextureSize, debug, "from File");
    } catch (err2) {
      if (debug) {
        console.warn("[FilmLab MediaLoader] createImageBitmap(File) failed", err2);
      }
      const mime = file.type && file.type.startsWith("image/") ? file.type : "image/png";
      try {
        const blob = new Blob([await file.arrayBuffer()], { type: mime });
        return await decodeViaCreateImageBitmap(blob, maxTextureSize, debug, `from Blob(${mime})`);
      } catch (err3) {
        if (debug) {
          console.warn("[FilmLab MediaLoader] createImageBitmap(retyped Blob) failed", err3);
        }
        const detail = debug ? ` Debug: ImageError=${String(imageElementError)}; Bitmap1=${String(err2)}; Bitmap2=${String(err3)}` : "";
        throw new MediaLoadError(
          `Could not decode this image. Try JPEG, PNG, or WebP.${safariHint} If it still fails, re-export without an embedded display profile (e.g. Preview \u2192 Export).${detail}`,
          "IMAGE_DECODE_FAILED"
        );
      }
    }
  }
  async loadVideo(file) {
    return new Promise((resolve, reject) => {
      const url = URL.createObjectURL(file);
      const video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      video.src = url;
      const rejectVideoLoad = (eventName, extra) => {
        try {
          URL.revokeObjectURL(url);
        } catch {
        }
        reject(
          new MediaLoadError(
            `MediaLoader.loadVideo("${file.name}", "${file.type || "unknown"}") failed at ${eventName}. Try MP4 (H.264), WebM, or a MOV codec your browser can decode.`,
            "VIDEO_DECODE_FAILED"
          )
        );
        if (extra != null) {
          console.error("MediaLoader.loadVideo detailed failure", {
            fileName: file.name,
            fileType: file.type,
            eventName,
            extra
          });
        }
      };
      video.onloadeddata = () => {
        const texture = new THREE4.VideoTexture(video);
        texture.colorSpace = THREE4.SRGBColorSpace;
        texture.minFilter = THREE4.LinearMipmapLinearFilter;
        texture.magFilter = THREE4.LinearFilter;
        texture.generateMipmaps = true;
        video.play().catch((err) => {
          console.warn("MediaLoader.loadVideo: autoplay blocked", err);
        });
        resolve({
          texture,
          width: video.videoWidth,
          height: video.videoHeight,
          type: "video"
        });
      };
      video.onerror = () => {
        rejectVideoLoad("error", video.error);
      };
      video.onabort = () => {
        rejectVideoLoad("abort");
      };
      video.load();
    });
  }
  /**
   * @description URL から直接動画を読み込む。Desktop の mezzanine 変換後パス（`film-lab-video://…`）等、
   * blob URL を経由しない動画ソース向け。`loadVideo(file)` とほぼ同じだが `createObjectURL` / `revokeObjectURL` を使わない。
   * @param url 動画の URL（`film-lab-video://…` や `file://…` 等）
   * @param label エラーメッセージに表示する任意のラベル（元ファイル名等）
   */
  async loadVideoFromURL(url, label) {
    return new Promise((resolve, reject) => {
      const video = document.createElement("video");
      video.muted = true;
      video.loop = true;
      video.playsInline = true;
      video.preload = "auto";
      video.src = url;
      const displayLabel = label ?? url;
      const rejectVideoLoad = (eventName, extra) => {
        reject(
          new MediaLoadError(
            `MediaLoader.loadVideoFromURL("${displayLabel}") failed at ${eventName}. Try MP4 (H.264), WebM, or a MOV codec your browser can decode.`,
            "VIDEO_DECODE_FAILED"
          )
        );
        if (extra != null) {
          console.error("MediaLoader.loadVideoFromURL detailed failure", {
            url,
            label: displayLabel,
            eventName,
            extra
          });
        }
      };
      video.onloadeddata = () => {
        const texture = new THREE4.VideoTexture(video);
        texture.colorSpace = THREE4.SRGBColorSpace;
        texture.minFilter = THREE4.LinearMipmapLinearFilter;
        texture.magFilter = THREE4.LinearFilter;
        texture.generateMipmaps = true;
        video.play().catch((err) => {
          console.warn("MediaLoader.loadVideoFromURL: autoplay blocked", err);
        });
        resolve({
          texture,
          width: video.videoWidth,
          height: video.videoHeight,
          type: "video"
        });
      };
      video.onerror = () => {
        rejectVideoLoad("error", video.error);
      };
      video.onabort = () => {
        rejectVideoLoad("abort");
      };
      video.load();
    });
  }
  async loadURL(url) {
    return new Promise((resolve, reject) => {
      const loader = new THREE4.TextureLoader();
      loader.load(
        url,
        (texture) => {
          texture.colorSpace = THREE4.SRGBColorSpace;
          texture.minFilter = THREE4.LinearFilter;
          texture.magFilter = THREE4.LinearFilter;
          resolve({
            texture,
            width: texture.image.width,
            height: texture.image.height,
            type: "image"
          });
        },
        void 0,
        (err) => {
          reject(
            err instanceof Error ? new MediaLoadError(err.message, "IMAGE_DECODE_FAILED") : new MediaLoadError(String(err), "UNKNOWN")
          );
        }
      );
    });
  }
};

// src/webgl/shaders/cross-filter-streak-density.frag.ts
var crossFilterStreakDensityFragmentShader = (
  /* glsl */
  `
precision highp float;

uniform sampler2D uSource;
uniform vec2 uTexelSize;
uniform vec2 uDirection;
uniform float uMinSpacing;

in vec2 vUv;
out vec4 fragColor;

const int DENSITY_SAMPLES = 32;
const float DENSITY_RADIUS_MAX = 96.0;  // texels at half-res
const float SELF_GAP = 2.0;
const int TANGENT_HALF_WIDTH = 2;
const float CROWD_GAIN = 8.0;

float sampleBandMax(sampler2D tex, vec2 uv, vec2 tangentStep) {
  float bandMax = 0.0;
  for (int j = -TANGENT_HALF_WIDTH; j <= TANGENT_HALF_WIDTH; j++) {
    vec2 sampleUv = uv + tangentStep * float(j);
    float lum = dot(texture(tex, sampleUv).rgb, vec3(0.2126, 0.7152, 0.0722));
    bandMax = max(bandMax, lum);
  }
  return bandMax;
}

void main() {
  vec3 center = texture(uSource, vUv).rgb;
  float centerLuma = dot(center, vec3(0.2126, 0.7152, 0.0722));
  if (centerLuma <= 1e-4) {
    fragColor = vec4(center, 1.0);
    return;
  }

  vec2 tangent = normalize(uDirection);
  vec2 normal = normalize(vec2(-uDirection.y, uDirection.x));
  vec2 tangentStep = tangent * uTexelSize;
  float radius = max(SELF_GAP, uMinSpacing * DENSITY_RADIUS_MAX);

  float neighborMax = 0.0;
  for (int i = 0; i < DENSITY_SAMPLES; i++) {
    float t = (float(i) + 0.5) / float(DENSITY_SAMPLES);
    float d = mix(SELF_GAP, radius, t);
    vec2 offset = normal * d * uTexelSize;
    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv + offset, tangentStep));
    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv - offset, tangentStep));
  }

  float crowd = neighborMax / centerLuma;
  float keep = 1.0 / (1.0 + crowd * CROWD_GAIN);
  float factor = mix(1.0, keep, step(0.001, uMinSpacing));

  fragColor = vec4(center * factor, 1.0);
}
`
);
export {
  LIKELY_VIDEO_EXTENSION,
  MediaLoadError,
  MediaLoader,
  Viewport,
  WebGLBackend,
  bloomPrefilterFragmentShader,
  compositeFragmentShader,
  crossFilterBlendFragmentShader,
  crossFilterPeakFragmentShader,
  crossFilterStreakDensityFragmentShader,
  crossFilterStreakFragmentShader,
  detailSoftnessFragmentShader,
  downsampleFragmentShader,
  dustFragmentShader,
  filmlabFragmentShader,
  filmlabVertexShader,
  getOptimalPixelRatio,
  halationPrefilterFragmentShader,
  isFilmLabMediaDebugEnabled,
  isLikelyHeicFile,
  isWebGL2Supported,
  isWebGPUSupported,
  lightshaftsBlendFragmentShader,
  lightshaftsFragmentShader,
  motionblurFragmentShader,
  upsampleFragmentShader
};
