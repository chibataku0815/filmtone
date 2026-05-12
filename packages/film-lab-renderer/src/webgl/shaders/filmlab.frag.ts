/**
 * @fileOverview Film Lab メインカラーグレード用 GLSL3 フラグメントシェーダー文字列。
 * @description 露出・コントラスト・0.4.0 Process（圧縮／プリント）・LUT などを 1 パスで適用する。
 * @limitations 解像度や LUT は JS（Viewport）側の uniform で供給する。このファイル単体では描画しない。
 */
export const filmlabFragmentShader = /* glsl */ `
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
// シャドウ／ハイライトの vec3 は JS 側で色相（HSL 彩度方向）× 強度 × レガシー長さから合成（軸 E 色相拡張）
uniform vec3 uShadowTint;
uniform vec3 uHighlightTint;

uniform float uSplitPosition;

// Input Transform LUT (applied before color grading — Log→Rec709)
uniform highp sampler3D uLUT1;
uniform float uLUT1Intensity;
uniform float uLUT1Enabled;

// Creative LUT (applied after color grading — film look)
uniform highp sampler3D uLUT2;
uniform float uLUT2Intensity;
uniform float uLUT2Enabled;

// 0.4.0 の現像段で使う数値 uniform。
uniform float uCompressionAmount;  // 0〜1、0 で無効
uniform float uCompressionRange;   // 0〜1、0.5 が既定
uniform float uShadowLatitude;      // 0〜1、toe separation

// 0.4.0 のプリント段で使う数値 uniform。
uniform float uCyan;               // -1〜1、0 で無効
uniform float uMagenta;            // -1〜1、0 で無効
uniform float uYellow;              // -1〜1、0 で無効
uniform float uPrintContrast;      // 0〜1、0 で無効

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
 * レンズ周辺の色収差に近い見え方: 画像中心ではゼロ、フレーム端ほど R/B を放射方向にずらす。
 * amount はスライダ上限（周辺で最大に近い量）。アスペクト補正で距離マスクを円形に揃える。
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

float filmCompressionWarmProtect(vec3 chroma, float mag) {
  if (mag <= 0.000001) return 0.0;
  vec3 dir = chroma / mag;
  float redWarm = smoothstep(0.32, 0.72, dir.r);
  float blueOpposed = 1.0 - smoothstep(-0.58, -0.20, dir.b);
  float greenModerate = 1.0 - smoothstep(0.18, 0.58, abs(dir.g));
  return clamp(redWarm * blueOpposed * greenModerate, 0.0, 1.0);
}

// Film Compression V3: existing luma shoulder plus hue-preserving chroma
// density rolloff around the post-shoulder neutral axis.
vec3 applyFilmCompression(vec3 rgb, float amount, float range) {
  if (amount < 0.001) return rgb;
  float r = clamp(range, 0.0, 1.0);
  float k = mix(5.15, 2.85, r);
  float rangeSoft = smoothstep(0.82, 1.0, r);
  float amt = amount * (1.0 - 0.18 * rangeSoft);
  float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
  float x = clamp(k * (luma - 0.5), -5.5, 5.5);
  float s = 1.0 / (1.0 + exp(-x));
  // One-sided shoulder: only roll highlights down, never lift shadows.
  // A symmetric sigmoid centered at 0.5 would push deep blacks upward
  // and boost shadow chroma — the opposite of the filmic density target.
  float shoulderY = min(luma, mix(luma, s, amt));
  float lumaScale = luma > 0.001 ? shoulderY / luma : 1.0;
  vec3 lumaCompressed = rgb * lumaScale;
  vec3 chroma = lumaCompressed - vec3(shoulderY);
  float chromaMag = length(chroma);

  float shadowRelease = smoothstep(0.14, 0.30, shoulderY);
  float kneeStart = mix(0.62, 0.42, r);
  float kneeEnd = mix(0.96, 0.78, r);
  float highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY);
  float chromaStress = smoothstep(0.16, 0.70, chromaMag);
  float maxChannel = max(max(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
  float minChannel = min(min(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);
  float highEdgeStress = smoothstep(0.82, 1.08, maxChannel);
  float lowEdgeStress = smoothstep(0.82, 1.08, -minChannel);
  float gamutStress = max(highEdgeStress, lowEdgeStress)
    * chromaStress
    * smoothstep(0.08, 0.24, shoulderY);
  float warmProtect = filmCompressionWarmProtect(chroma, chromaMag);

  float highlightCompression = 0.42 * highlightMask * shadowRelease * mix(0.55, 1.0, chromaStress);
  float guardCompression = 0.22 * gamutStress * shadowRelease;
  float protectedCompression = (highlightCompression + guardCompression) * (1.0 - 0.35 * warmProtect);
  float chromaScale = clamp(1.0 - amt * protectedCompression, 0.0, 1.0);
  vec3 landedChroma = chroma * chromaScale;
  vec3 outColor = vec3(shoulderY) + landedChroma;
  float outMax = max(max(outColor.r, outColor.g), outColor.b);
  float landingChroma = smoothstep(0.18, 0.62, chromaMag);
  float landingMask = smoothstep(0.78, 0.98, outMax)
    * landingChroma
    * shadowRelease
    * (1.0 - 0.35 * warmProtect);
  if (outMax > 0.78 && outMax > shoulderY + 0.000001) {
    float over = outMax - 0.78;
    float headroom = 0.22;
    float softMax = 0.78 + (headroom * over) / (over + headroom);
    float landingScale = clamp((softMax - shoulderY) / (outMax - shoulderY), 0.0, 1.0);
    float landingBlend = clamp(amt * 0.88 * landingMask, 0.0, 1.0);
    float finalScale = mix(1.0, landingScale, landingBlend);
    outColor = vec3(shoulderY) + landedChroma * finalScale;
  }
  return clamp(outColor, 0.0, 1.0);
}

vec3 applyShadowLatitude(vec3 rgb, float amount) {
  float amt = clamp(amount, 0.0, 1.0);
  if (amt < 0.001) return rgb;
  float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
  float blackProtect = smoothstep(0.025, 0.055, y);
  float release = 1.0 - smoothstep(0.18, 0.30, y);
  float band = blackProtect * release;
  if (band <= 0.000001) return rgb;
  float toeShape = max(0.0, 1.0 - y / 0.30);
  float lumaLift = y * toeShape * 0.22 * amt * band;
  float outY = y + lumaLift;
  float chromaScale = 1.0 + 0.08 * amt * band;
  vec3 outColor = vec3(outY) + (rgb - vec3(y)) * chromaScale;
  return clamp(outColor, 0.0, 1.0);
}

// プリント段の最終コントラストを S カーブで持ち上げる。
// amount=0 なら何もしない。
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

  // Fade (Lift — フィルムの「浮いた黒」)
  color.rgb = color.rgb + uFade * (1.0 - color.rgb);

  // Highlights / Shadows
  float lumHS = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
  color.rgb += uShadows * (1.0 - lumHS) * 0.5;
  color.rgb += uHighlights * lumHS * 0.5;

  // Film Compression V3. Apply before LUT2 and downstream optical stages.
  color.rgb = applyFilmCompression(color.rgb, uCompressionAmount, uCompressionRange);

  // Shadow Latitude / toe separation. Apply before LUT2.
  color.rgb = applyShadowLatitude(color.rgb, uShadowLatitude);

  // === Creative LUT (LUT2) === after color grading
  if (uLUT2Enabled > 0.5) {
    vec3 lut2Coord = clamp(color.rgb, 0.0, 1.0);
    color.rgb = mix(color.rgb, texture(uLUT2, lut2Coord).rgb, uLUT2Intensity);
  }

  // 0.4.0 のプリント段。CMY の色かぶりを足す。
  // C = -R, M = -G, Y = -B の暗室の考え方に合わせる。
  float cmyScale = 0.15;  // 1.0 でおよそ 0.15 の RGB 変化にする
  color.r -= uCyan    * cmyScale;
  color.g -= uMagenta * cmyScale;
  color.b -= uYellow  * cmyScale;

  // 0.4.0 のプリント段。最後に紙の硬さを足す。
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
`;
