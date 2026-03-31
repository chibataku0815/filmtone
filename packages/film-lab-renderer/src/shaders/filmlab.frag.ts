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
  float rCh = texture(tex, uv + dir * amt).r;
  float gCh = texture(tex, uv).g;
  float bCh = texture(tex, uv - dir * amt).b;
  float aCh = texture(tex, uv).a;
  return vec4(rCh, gCh, bCh, aCh);
}

float grain(vec2 uv, float time) {
  return fract(sin(dot(uv * time, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

void main() {
  vec2 uv = coverUv(vUv, uResolution, uImageResolution);

  vec4 color = uRGBShift > 0.0
    ? rgbShiftSampleRadial(uTexture, uv, uRGBShift, uImageResolution)
    : texture(uTexture, uv);

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

  // === Creative LUT (LUT2) === after color grading
  if (uLUT2Enabled > 0.5) {
    vec3 lut2Coord = clamp(color.rgb, 0.0, 1.0);
    color.rgb = mix(color.rgb, texture(uLUT2, lut2Coord).rgb, uLUT2Intensity);
  }

  color.rgb = clamp(color.rgb, 0.0, 1.0);
  fragColor = color;
}
`;
