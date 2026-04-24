// src/params.ts
var PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "rgbShift",
  /** 周辺ほど等方ブラーを足すレンズの柔らかさ（0〜1、Pro）。中心固定。 */
  "lensSoftness",
  "grainIntensity",
  // 0=一様、1=周辺強め（既定1で後方互換）
  "grainRadialMix",
  /** グレイン粒子の粗さ（0=極細、1=極粗）。低域は fine grain、高域は clumped grain に寄せる。range: 0–1 */
  "grainSize",
  "vignette",
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  /** Pro-Mist 的な全画面光拡散（0=オフ、1=最大ヘイズ）。range: 0–1 */
  "diffusion",
  /** Depth-aware Mist weighting（0=uniform、1=full depth weighting）。shared contract では 0–1。 */
  "depthMistGain",
  /** Depth-aware Glow weighting（0=uniform、1=full depth weighting）。Bloom + Halation に適用。 */
  "depthGlowGain",
  /** Depth ray-angle mask gamma。renderer-only fallback を避ける共有契約。 */
  "depthRayAngleGamma",
  /** Depth ray-angle mask の中心保護しきい値。 */
  "depthRayAngleInnerThreshold",
  /** Mist source ray-angle weighting（0=off、1=max edge source boost）。 */
  "depthMistRayAngleGain",
  /** Bloom source ray-angle weighting（0=off、1=max edge source boost）。 */
  "depthBloomRayAngleGain",
  /** Halation source ray-angle weighting（0=off、1=max edge source boost）。 */
  "depthHalationRayAngleGain",
  /** Mist field PSF gain（0=off、1=max field blur mix）。 */
  "depthMistFieldPsfGain",
  /** Bloom field PSF gain（0=off、1=max field blur mix）。 */
  "depthBloomFieldPsfGain",
  /** Halation field PSF gain（0=off、1=max field blur mix）。 */
  "depthHalationFieldPsfGain",
  /** Mist field PSF radius in pixels。 */
  "depthMistFieldPsfRadiusPx",
  /** Bloom field PSF radius in pixels。 */
  "depthBloomFieldPsfRadiusPx",
  /** Halation field PSF radius in pixels。 */
  "depthHalationFieldPsfRadiusPx",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  /** ハレーション発火の輝度閾値（0〜1、旧ハードコード 0.6 を可変化） */
  "halationThreshold",
  /** ハレーションのミップウェイト分布（0=狭い、1=広い。halationSpread の後継） */
  "halationRadius",
  /** ブルーム閾値のソフトニー幅（0=ハード、1=最大ソフト） */
  "bloomSoftKnee",
  /** ハレーション閾値のソフトニー幅（0=ハード、1=最大ソフト） */
  "halationSoftKnee",
  "fade",
  "highlights",
  "shadows",
  "shadowTone",
  "highlightTone",
  "shadowHue",
  "highlightHue",
  // === 0.4.0 新規: Film Process (Negative Stage / Print Stage) ===
  /** フィルム latitude 圧縮量（0=なし、1=フル圧縮）。range: 0–1 */
  "compressionAmount",
  /** 圧縮の shoulder/toe 幅（0=急峻、1=緩やか）。range: 0–1 */
  "compressionRange",
  /** 印画紙コントラスト（0=no effect、1=最大硬調）。range: 0–1 */
  "printContrast",
  /** CMY enlarger color head: Cyan filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "cyan",
  /** CMY enlarger color head: Magenta filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "magenta",
  /** CMY enlarger color head: Yellow filter（-1〜1、0=ニュートラル）。range: -1–1 */
  "yellow",
  /** @deprecated Ghost Param for URL backward compat. Use shutterAngle. */
  "motionBlurAmount",
  /** Camera shutter angle (0=off, 180=cinema standard, 360=1F, 720=2F). Range: 0-720. */
  "shutterAngle",
  /** 残像フィードバック強度（0=なし、0.95=最大）。リングバッファに前フレームを畳み込んで長い残像を生成。range: 0–0.95 */
  "trailIntensity",
  /** ダスト（埃）オーバーレイ強度（0=オフ、1=最大）。range: 0–1 */
  "dustAmount",
  /** スクラッチ（傷）オーバーレイ強度（0=オフ、1=最大）。range: 0–1 */
  "scratchAmount",
  /** ライトシャフト強度（0=オフ、1=最大）。range: 0–1 */
  "shaftIntensity",
  /** ライトシャフト減衰（0=短い光線、1=長い光線）。range: 0–1。内部で 0.92–0.995 にマップ */
  "shaftDecay",
  /** ライトシャフト光源 X 位置（0=左端、1=右端）。range: 0–1 */
  "shaftOriginX",
  /** ライトシャフト光源 Y 位置（0=上端、1=下端）。range: 0–1 */
  "shaftOriginY",
  "crossFilterStrength",
  "crossFilterSpikes",
  "crossFilterAngle",
  "crossFilterLength",
  "crossFilterThreshold",
  "crossFilterChromatic",
  "crossFilterSizeLimit",
  "crossFilterRandomness",
  /** Hard Mode toggle (0=Soft 自然な光学再現 / 1=Hard 物理超え stylized 光芒)。boolean 用途の number。 */
  "crossFilterHardMode",
  /** 光芒の密集回避。現行プロダクトでは 1 が下限で、1–2 の範囲で扱う。古い下位値は 1 へ正規化する。 */
  "crossFilterMinSpacing",
  /** Cross filter source depth weighting（0=uniform、1=full depth weighting）。 */
  "crossFilterDepthGain",
  /** Cross filter source ray-angle weighting（0=off、1=max edge source boost）。 */
  "crossFilterAngleGain",
  /** Cross filter ray-angle mask gamma。65deg hfov の斜入射近似に適用。 */
  "crossFilterAngleGamma",
  /** Cross filter ray-angle mask の中心保護しきい値。 */
  "crossFilterAngleInnerThreshold",
  /** Cross filter streak length field modulation（0=uniform、1=max edge length boost）。 */
  "crossFilterEdgeLengthGain",
  /** Cross filter streak strength field modulation（0=uniform、1=max edge strength boost）。 */
  "crossFilterEdgeStrengthGain"
];
var FILM_GRAIN_INTENSITY_MAX = 0.1;
function clampGrainIntensity(value) {
  if (!Number.isFinite(value)) {
    return 0;
  }
  return Math.min(FILM_GRAIN_INTENSITY_MAX, Math.max(0, value));
}
function cloneParams(params) {
  return { ...params };
}

// src/split-tone-default-hues.ts
var LEGACY_SHADOW_DIR = [0.12, 0.18, 0.42];
var LEGACY_HIGHLIGHT_DIR = [0.38, 0.16, 0.06];
function hslToRgb01(hDegrees, s, l) {
  const hNorm = (hDegrees % 360 + 360) % 360 / 360;
  if (s <= 0) {
    return { r: l, g: l, b: l };
  }
  const hue2rgb = (p2, q2, t) => {
    let tt = t;
    if (tt < 0) tt += 1;
    if (tt > 1) tt -= 1;
    if (tt < 1 / 6) return p2 + (q2 - p2) * 6 * tt;
    if (tt < 1 / 2) return q2;
    if (tt < 2 / 3) return p2 + (q2 - p2) * (2 / 3 - tt) * 6;
    return p2;
  };
  const q = l < 0.5 ? l * (1 + s) : l + s - l * s;
  const p = 2 * l - q;
  const r = hue2rgb(p, q, hNorm + 1 / 3);
  const g = hue2rgb(p, q, hNorm);
  const b = hue2rgb(p, q, hNorm - 1 / 3);
  return { r, g, b };
}
function chromaUnitFromHueDegrees(hueDegrees) {
  const { r, g, b } = hslToRgb01(hueDegrees, 1, 0.5);
  let x = r - 0.5;
  let y = g - 0.5;
  let z5 = b - 0.5;
  const len = Math.hypot(x, y, z5);
  if (len < 1e-9) {
    return [0, 0, 1];
  }
  const inv = 1 / len;
  return [x * inv, y * inv, z5 * inv];
}
function nearestHueDegreesToDirection(dir) {
  const [dx0, dy0, dz0] = dir;
  const len = Math.hypot(dx0, dy0, dz0);
  if (len < 1e-12) {
    return 0;
  }
  const dx = dx0 / len;
  const dy = dy0 / len;
  const dz = dz0 / len;
  let bestHue = 0;
  let bestDot = -2;
  for (let h = 0; h < 360; h += 1) {
    const [ux, uy, uz] = chromaUnitFromHueDegrees(h);
    const dot = ux * dx + uy * dy + uz * dz;
    if (dot > bestDot) {
      bestDot = dot;
      bestHue = h;
    }
  }
  return bestHue;
}
var FILM_LAB_DEFAULT_SHADOW_HUE = nearestHueDegreesToDirection(LEGACY_SHADOW_DIR);
var FILM_LAB_DEFAULT_HIGHLIGHT_HUE = nearestHueDegreesToDirection(LEGACY_HIGHLIGHT_DIR);
var LEGACY_SHADOW_TONE_MAGNITUDE = Math.hypot(...LEGACY_SHADOW_DIR);
var LEGACY_HIGHLIGHT_TONE_MAGNITUDE = Math.hypot(...LEGACY_HIGHLIGHT_DIR);
function halationHueToHex(hue) {
  const t = Math.max(0, Math.min(1, hue / 100));
  const r = Math.round(232 + (200 - 232) * t);
  const g = Math.round(16 + (96 - 16) * t);
  const b = Math.round(32 + (16 - 32) * t);
  return `#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`;
}

// src/presets.ts
var CONTRACT_DEFAULTS = {
  depthMistGain: 0,
  depthGlowGain: 0,
  depthRayAngleGamma: 1.4,
  depthRayAngleInnerThreshold: 0.1,
  depthMistRayAngleGain: 0.35,
  depthBloomRayAngleGain: 0.25,
  depthHalationRayAngleGain: 0.18,
  depthMistFieldPsfGain: 1,
  depthBloomFieldPsfGain: 1,
  depthHalationFieldPsfGain: 1,
  depthMistFieldPsfRadiusPx: 18,
  depthBloomFieldPsfRadiusPx: 9,
  depthHalationFieldPsfRadiusPx: 12,
  crossFilterDepthGain: 0.25,
  crossFilterAngleGain: 0.35,
  crossFilterAngleGamma: 1.4,
  crossFilterAngleInnerThreshold: 0.1,
  crossFilterEdgeLengthGain: 0.45,
  crossFilterEdgeStrengthGain: 0.25
};
function withContractDefaults(presets) {
  return Object.fromEntries(
    Object.entries(presets).map(([name, preset]) => [
      name,
      {
        ...preset,
        ...CONTRACT_DEFAULTS
      }
    ])
  );
}
var RAW_PRESETS = {
  reset: {
    exposure: 0,
    contrast: 1,
    saturation: 1,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0,
    grainRadialMix: 1,
    grainSize: 0.3,
    vignette: 0,
    bloomThreshold: 0.8,
    bloomStrength: 0,
    bloomRadius: 0.4,
    diffusion: 0,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    halationThreshold: 0.6,
    halationRadius: 0.6,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0,
    highlights: 0,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  /**
   * cinematic プリセット（v2・2026-03-31）
   * @description 初見のフィルター感とシアン肌を抑えつつ Teal & Orange の意図は維持。変更理由はリポ外ドキュメントに記載可。
   */
  cinematic: {
    exposure: 0.09,
    contrast: 1.24,
    saturation: 0.87,
    temperature: -0.11,
    tint: 0,
    rgbShift: 2e-3,
    lensSoftness: 0,
    grainIntensity: 0.05,
    grainRadialMix: 1,
    grainSize: 0.32,
    vignette: 0.32,
    bloomThreshold: 0.76,
    bloomStrength: 0.26,
    bloomRadius: 0.5,
    diffusion: 0.1,
    halationIntensity: 0.06,
    halationSpread: 20,
    halationHue: 18,
    halationThreshold: 0.6,
    halationRadius: 0.4,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.025,
    highlights: -0.08,
    shadows: -0.11,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  portra: {
    exposure: 0.2,
    contrast: 1.1,
    saturation: 0.9,
    temperature: 0.1,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.08,
    grainRadialMix: 1,
    grainSize: 0.32,
    vignette: 0.2,
    bloomThreshold: 0.78,
    bloomStrength: 0.14,
    bloomRadius: 0.38,
    diffusion: 0.05,
    halationIntensity: 0.18,
    halationSpread: 20,
    halationHue: 28,
    halationThreshold: 0.6,
    halationRadius: 0.44,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.05,
    highlights: 0,
    shadows: 0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  gold200: {
    exposure: 0.15,
    contrast: 1.2,
    saturation: 1.15,
    temperature: 0.18,
    tint: 0,
    rgbShift: 12e-4,
    lensSoftness: 0,
    grainIntensity: 0.07,
    grainRadialMix: 1,
    grainSize: 0.28,
    vignette: 0.25,
    bloomThreshold: 0.8,
    bloomStrength: 0.16,
    bloomRadius: 0.35,
    diffusion: 0.04,
    halationIntensity: 0.12,
    halationSpread: 18,
    halationHue: 32,
    halationThreshold: 0.6,
    halationRadius: 0.4,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.03,
    highlights: 0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  pro400h: {
    exposure: 0.25,
    contrast: 1.05,
    saturation: 0.85,
    temperature: -0.1,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.04,
    grainRadialMix: 1,
    grainSize: 0.25,
    vignette: 0.15,
    bloomThreshold: 0.84,
    bloomStrength: 0.06,
    bloomRadius: 0.42,
    diffusion: 0,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    halationThreshold: 0.6,
    halationRadius: 0.3,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.08,
    highlights: 0.05,
    shadows: 0.15,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  bw: {
    exposure: 0.1,
    contrast: 1.4,
    saturation: 0,
    temperature: 0,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.1,
    grainRadialMix: 1,
    grainSize: 0.43,
    vignette: 0.5,
    bloomThreshold: 0.8,
    bloomStrength: 0.16,
    bloomRadius: 0.52,
    diffusion: 0.04,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    halationThreshold: 0.6,
    halationRadius: 0.3,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.02,
    highlights: -0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  ektar100: {
    exposure: 0.05,
    contrast: 1.25,
    saturation: 1.3,
    temperature: 0.02,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.03,
    grainRadialMix: 1,
    grainSize: 0.12,
    vignette: 0.15,
    bloomThreshold: 0.86,
    bloomStrength: 0.08,
    bloomRadius: 0.28,
    diffusion: 0,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    halationThreshold: 0.6,
    halationRadius: 0.3,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0,
    highlights: 0.1,
    shadows: -0.1,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  superia400: {
    exposure: 0.1,
    contrast: 1.18,
    saturation: 1.08,
    temperature: -0.08,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.065,
    grainRadialMix: 1,
    grainSize: 0.4,
    vignette: 0.2,
    bloomThreshold: 0.8,
    bloomStrength: 0.08,
    bloomRadius: 0.32,
    diffusion: 0,
    halationIntensity: 0.08,
    halationSpread: 15,
    halationHue: 14,
    halationThreshold: 0.6,
    halationRadius: 0.32,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.04,
    highlights: 0,
    shadows: 0.05,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  cinestill800t: {
    exposure: 0.15,
    contrast: 1.15,
    saturation: 0.95,
    temperature: -0.3,
    tint: 0,
    rgbShift: 115e-5,
    lensSoftness: 0,
    grainIntensity: 0.08,
    grainRadialMix: 1,
    grainSize: 0.58,
    vignette: 0.3,
    bloomThreshold: 0.64,
    bloomStrength: 0.4,
    bloomRadius: 0.6,
    diffusion: 0.16,
    halationIntensity: 0.14,
    halationSpread: 28,
    halationHue: 20,
    halationThreshold: 0.6,
    halationRadius: 0.56,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0.03,
    highlights: -0.05,
    shadows: 0,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  },
  /**
   * Velvia 50 プリセット（v1・2026-04-02）
   * @description Fujifilm Velvia 50 スライドポジフィルム。高彩度・高コントラスト・極細粒・ハレーションなし。
   * fade=0 でポジらしい黒沈みを表現。saturation/contrast は Velvia の代名詞の鮮烈さに合わせた。
   */
  velvia50: {
    exposure: 0,
    contrast: 1.35,
    saturation: 1.45,
    temperature: 0.04,
    tint: 0,
    rgbShift: 0,
    lensSoftness: 0,
    grainIntensity: 0.01,
    grainRadialMix: 1,
    grainSize: 0.08,
    vignette: 0.1,
    bloomThreshold: 0.9,
    bloomStrength: 0.04,
    bloomRadius: 0.28,
    diffusion: 0,
    halationIntensity: 0,
    halationSpread: 15,
    halationHue: 0,
    halationThreshold: 0.6,
    halationRadius: 0.3,
    bloomSoftKnee: 0.5,
    halationSoftKnee: 0.3,
    fade: 0,
    highlights: 0.05,
    shadows: -0.05,
    shadowTone: 0,
    highlightTone: 0,
    shadowHue: FILM_LAB_DEFAULT_SHADOW_HUE,
    highlightHue: FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
    compressionAmount: 0,
    compressionRange: 0.5,
    printContrast: 0,
    cyan: 0,
    magenta: 0,
    yellow: 0,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    dustAmount: 0,
    scratchAmount: 0,
    shaftIntensity: 0,
    shaftDecay: 0.5,
    shaftOriginX: 0.5,
    shaftOriginY: 0.15,
    crossFilterStrength: 0,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.3,
    crossFilterSizeLimit: 0,
    crossFilterRandomness: 1,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1
  }
};
var PRESETS = withContractDefaults(RAW_PRESETS);
var FILMTONE_DEFAULT_BASE_PRESET = "reset";
var FILMTONE_SOFT_FINISH_PATCH = {
  bloomStrength: 0.22,
  bloomThreshold: 0.72,
  bloomRadius: 0.52,
  diffusion: 0.08,
  halationIntensity: 0.1,
  halationSpread: 22,
  halationRadius: 0.44,
  halationHue: 20
};
function createFilmtoneDefaultParams() {
  return Object.assign(
    cloneParams(PRESETS[FILMTONE_DEFAULT_BASE_PRESET]),
    FILMTONE_SOFT_FINISH_PATCH
  );
}
function findMatchingPreset(params) {
  for (const [name, preset] of Object.entries(PRESETS)) {
    if (PARAM_KEYS.every((key) => preset[key] === params[key])) {
      return name;
    }
  }
  return null;
}
var PRESET_BUTTONS = [
  { name: "reset", label: "Neutral", subtitle: "Clean Base", category: "utility" },
  { name: "portra", label: "Portra 400", subtitle: "Warm Pastel", category: "filmStock", printMedium: "color_negative" },
  { name: "gold200", label: "Gold 200", subtitle: "Saturated Warm", category: "filmStock", printMedium: "color_negative" },
  { name: "pro400h", label: "Pro 400H", subtitle: "Cool Soft", category: "filmStock", printMedium: "color_negative" },
  { name: "ektar100", label: "Ektar 100", subtitle: "Vivid Sharp", category: "filmStock", printMedium: "color_negative" },
  { name: "superia400", label: "Superia 400", subtitle: "Cool Green", category: "filmStock", printMedium: "color_negative" },
  { name: "cinestill800t", label: "CineStill 800T", subtitle: "Tungsten Glow", category: "filmStock", printMedium: "tungsten_cinema" },
  { name: "bw", label: "B&W", subtitle: "Classic Mono", category: "filmStock", printMedium: "silver_gelatin" },
  { name: "velvia50", label: "Velvia 50", subtitle: "Vivid Slide", category: "filmStock", printMedium: "slide_positive" },
  { name: "cinematic", label: "Cinematic", subtitle: "Teal & Orange", category: "look" }
];

// src/look-ids.ts
var PRESET_VERSION = "v1";
function lookIdForPreset(name) {
  return `look:mp:${String(name)}:${PRESET_VERSION}`;
}
var LOOK_ID_BY_PRESET = {
  reset: lookIdForPreset("reset"),
  cinematic: lookIdForPreset("cinematic"),
  portra: lookIdForPreset("portra"),
  gold200: lookIdForPreset("gold200"),
  pro400h: lookIdForPreset("pro400h"),
  bw: lookIdForPreset("bw"),
  ektar100: lookIdForPreset("ektar100"),
  superia400: lookIdForPreset("superia400"),
  cinestill800t: lookIdForPreset("cinestill800t"),
  velvia50: lookIdForPreset("velvia50")
};

// src/schema.ts
import { z } from "zod";
function schemaForParamKey(key) {
  return key === "grainIntensity" ? z.number().min(0).transform(clampGrainIntensity) : key === "grainRadialMix" ? z.number().min(0).max(1).default(1) : key === "grainSize" ? z.number().min(0).max(1).default(0.3) : key === "diffusion" ? z.number().min(0).max(1).default(0) : key === "depthMistGain" || key === "depthGlowGain" ? z.number().min(0).max(1).default(0) : key === "depthRayAngleGamma" ? z.number().min(0.1).max(4).default(1.4) : key === "depthRayAngleInnerThreshold" ? z.number().min(0).max(0.8).default(0.1) : key === "depthMistRayAngleGain" ? z.number().min(0).max(1).default(0.35) : key === "depthBloomRayAngleGain" ? z.number().min(0).max(1).default(0.25) : key === "depthHalationRayAngleGain" ? z.number().min(0).max(1).default(0.18) : key === "depthMistFieldPsfGain" || key === "depthBloomFieldPsfGain" || key === "depthHalationFieldPsfGain" ? z.number().min(0).max(1).default(1) : key === "depthMistFieldPsfRadiusPx" ? z.number().min(0).max(64).default(18) : key === "depthBloomFieldPsfRadiusPx" ? z.number().min(0).max(64).default(9) : key === "depthHalationFieldPsfRadiusPx" ? z.number().min(0).max(64).default(12) : key === "lensSoftness" ? z.number().min(0).max(1).default(0) : key === "compressionRange" ? z.number().min(0).max(1).default(0.5) : key === "compressionAmount" || key === "printContrast" ? z.number().min(0).max(1).default(0) : key === "cyan" || key === "magenta" || key === "yellow" ? z.number().min(-1).max(1).default(0) : key === "shutterAngle" ? z.number().min(0).max(720).default(0) : key === "trailIntensity" ? z.number().min(0).max(0.95).default(0) : key === "motionBlurAmount" || key === "dustAmount" || key === "scratchAmount" ? z.number().min(0).max(1).default(0) : key === "shaftIntensity" ? z.number().min(0).max(1).default(0) : key === "shaftDecay" ? z.number().min(0).max(1).default(0.5) : key === "shaftOriginX" ? z.number().min(0).max(1).default(0.5) : key === "shaftOriginY" ? z.number().min(0).max(1).default(0.15) : key === "crossFilterStrength" ? z.number().min(0).max(1).default(0) : key === "crossFilterSpikes" ? z.number().min(4).max(8).default(4) : key === "crossFilterAngle" ? z.number().min(0).max(360).default(0) : key === "crossFilterLength" ? z.number().min(0).max(1).default(0.4) : key === "crossFilterThreshold" ? z.number().min(0).max(1).default(0.92) : key === "crossFilterChromatic" ? z.number().min(0).max(1).default(0.3) : key === "crossFilterSizeLimit" ? z.number().min(0).max(1).default(0) : key === "crossFilterRandomness" ? z.number().min(0).max(1).default(1) : key === "crossFilterHardMode" ? z.number().min(0).max(1).default(1) : key === "crossFilterMinSpacing" ? z.number().min(0).max(2).default(1) : key === "crossFilterDepthGain" ? z.number().min(0).max(1).default(0.25) : key === "crossFilterAngleGain" ? z.number().min(0).max(1).default(0.35) : key === "crossFilterAngleGamma" ? z.number().min(0.1).max(4).default(1.4) : key === "crossFilterAngleInnerThreshold" ? z.number().min(0).max(0.8).default(0.1) : key === "crossFilterEdgeLengthGain" ? z.number().min(0).max(1).default(0.45) : key === "crossFilterEdgeStrengthGain" ? z.number().min(0).max(1).default(0.25) : z.number();
}
var paramShape = Object.fromEntries(
  PARAM_KEYS.map((key) => [key, schemaForParamKey(key)])
);
var filmLabParamsSchema = z.object(paramShape);
var filmLabDepthTrackSchema = z.object({
  kind: z.literal("frameSequence"),
  fps: z.number().positive().max(120).default(25),
  frameRelPaths: z.array(z.string().min(1)).min(1)
});
var cameraOpticsSchema = z.object({
  source: z.enum(["metadata", "assumed", "manual"]),
  fxPx: z.number().positive().optional(),
  fyPx: z.number().positive().optional(),
  cxPx: z.number().optional(),
  cyPx: z.number().optional(),
  fovXDeg: z.number().min(1).max(178).optional(),
  fovYDeg: z.number().min(1).max(178).optional(),
  focalLength35mm: z.number().positive().optional(),
  lensModel: z.string().min(1).optional(),
  cameraMake: z.string().min(1).optional(),
  cameraModel: z.string().min(1).optional()
});
var filmLookGradeInputSchema = z.object({
  lookPresetId: z.string().min(1),
  presetVersion: z.literal(PRESET_VERSION),
  grade: filmLabParamsSchema,
  /** Optional depth track that drives depth-aware Mist / Glow across preview and export. */
  depthTrack: filmLabDepthTrackSchema.optional(),
  /** Optional source camera optics for ray-angle masks. */
  cameraOptics: cameraOpticsSchema.nullable().optional(),
  /**
   * Input Transform LUT（グレーディング前 — Log→Rec709 等）。
   * 未指定のときは Input Transform をかけない。
   */
  lut1CubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lut1CubeRelPath` があっても LUT1 を無効化する。未指定は `true` 扱い。 */
  lut1Enabled: z.boolean().optional(),
  /** Input Transform の適用強度（0〜1）。未指定は `1`。 */
  lut1Intensity: z.number().min(0).max(1).optional(),
  /**
   * Creative LUT（グレーディング後 — フィルムルック等）。
   * Remotion `public/` からの相対パス（例: `luts/warm-cinematic.cube`）。
   * 未指定のときは Creative LUT をかけない。
   */
  lutCubeRelPath: z.string().min(1).optional(),
  /** `false` のとき `lutCubeRelPath` があっても Creative LUT を無効化する。未指定は `true` 扱い。 */
  lutEnabled: z.boolean().optional(),
  /** Creative LUT の適用強度（0〜1）。未指定は `1`。 */
  lutIntensity: z.number().min(0).max(1).optional(),
  /**
   * Remotion `public/` 内の動画（.mov / .mp4 等）。
   * 指定時は `film-lab-default.jpg` の代わりにフレームをテクスチャに焼く（`@remotion/media`）。
   */
  gradeSourceVideoRelPath: z.string().min(1).optional(),
  /** 動画の実ピクセル幅（アスペクト・cover 用）。未指定は 3840（4K 横想定）。 */
  gradeSourceVideoWidth: z.number().int().positive().max(7680).optional(),
  /** 動画の実ピクセル高さ。未指定は 2160。 */
  gradeSourceVideoHeight: z.number().int().positive().max(4320).optional()
});
var filmLookSpikeInputSchema = z.object({
  title: z.string().min(1)
});
function gradeMatchesPreset(presetName, grade) {
  const expected = PRESETS[presetName];
  return PARAM_KEYS.every((key) => grade[key] === expected[key]);
}

// src/cube-parser.ts
function parseCube(text) {
  const lines = text.split("\n");
  let title = "";
  let size = 0;
  let domainMin = [0, 0, 0];
  let domainMax = [1, 1, 1];
  const values = [];
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed === "" || trimmed.startsWith("#")) continue;
    if (trimmed.startsWith("TITLE")) {
      title = trimmed.replace(/^TITLE\s+"?/, "").replace(/"$/, "");
    } else if (trimmed.startsWith("LUT_3D_SIZE")) {
      size = parseInt(trimmed.split(/\s+/)[1] ?? "0", 10);
    } else if (trimmed.startsWith("DOMAIN_MIN")) {
      const p = trimmed.split(/\s+/);
      domainMin = [
        parseFloat(p[1] ?? "0"),
        parseFloat(p[2] ?? "0"),
        parseFloat(p[3] ?? "0")
      ];
    } else if (trimmed.startsWith("DOMAIN_MAX")) {
      const p = trimmed.split(/\s+/);
      domainMax = [
        parseFloat(p[1] ?? "1"),
        parseFloat(p[2] ?? "1"),
        parseFloat(p[3] ?? "1")
      ];
    } else {
      const p = trimmed.split(/\s+/);
      if (p.length >= 3) {
        values.push(
          parseFloat(p[0] ?? "0"),
          parseFloat(p[1] ?? "0"),
          parseFloat(p[2] ?? "0")
        );
      }
    }
  }
  const total = size * size * size;
  const data = new Float32Array(total * 4);
  for (let i = 0; i < total; i++) {
    data[i * 4 + 0] = values[i * 3 + 0] ?? 0;
    data[i * 4 + 1] = values[i * 3 + 1] ?? 0;
    data[i * 4 + 2] = values[i * 3 + 2] ?? 0;
    data[i * 4 + 3] = 1;
  }
  return { title, size, domainMin, domainMax, data };
}

// src/lut-pack-2d.ts
function packCubeLutToFloatRgbaGrid(lut) {
  const n = lut.size;
  const width = n * n;
  const height = n;
  const data = new Float32Array(width * height * 4);
  const src = lut.data;
  for (let b = 0; b < n; b++) {
    for (let g = 0; g < n; g++) {
      for (let r = 0; r < n; r++) {
        const idx = r + n * g + n * n * b;
        const sx = idx * 4;
        const x = r + g * n;
        const y = b;
        const dst = (y * width + x) * 4;
        data[dst] = src[sx] ?? 0;
        data[dst + 1] = src[sx + 1] ?? 0;
        data[dst + 2] = src[sx + 2] ?? 0;
        data[dst + 3] = src[sx + 3] ?? 1;
      }
    }
  }
  return { width, height, size: n, data };
}

// src/defaults.ts
var filmLookSpikeDefaultProps = {
  title: "Filmtone \xD7 Remotion"
};
function createDefaultFilmLookGradeProps() {
  const grade = cloneParams(PRESETS.cinematic);
  return {
    lookPresetId: LOOK_ID_BY_PRESET.cinematic,
    presetVersion: PRESET_VERSION,
    grade
  };
}
var filmLookGradeDefaultProps = createDefaultFilmLookGradeProps();

// src/quick-semantics.ts
import { z as z2 } from "zod";

// src/phase0-constants.ts
var PHASE0_RGB_SHIFT_MAX = 5e-3;

// src/quick-semantics.ts
var QUICK_AXIS_IDS = [
  "filmCharacter",
  "era",
  "dynamics"
];
var QUICK_AXIS_DEFAULT_RANGE = {
  min: -1,
  max: 1,
  step: 0.01
};
var DEFAULT_QUICK_STATE = {
  filmCharacter: 0,
  era: 0,
  dynamics: 0
};
var quickStateShape = Object.fromEntries(
  QUICK_AXIS_IDS.map((axis) => [
    axis,
    z2.number().min(QUICK_AXIS_DEFAULT_RANGE.min).max(QUICK_AXIS_DEFAULT_RANGE.max)
  ])
);
var quickStateSchema = z2.object(quickStateShape);
var QUICK_FULL_AXIS_WEIGHTS = {
  filmCharacter: {
    saturation: 0.24,
    temperature: 0.16,
    tint: -0.06,
    grainIntensity: 0.1,
    vignette: 0.12
  },
  era: {
    fade: 0.18,
    saturation: -0.14,
    contrast: -0.08,
    halationIntensity: 0.16,
    halationSpread: 6
  },
  dynamics: {
    exposure: 0.24,
    contrast: 0.18,
    bloomStrength: 0.16,
    bloomThreshold: -0.06,
    bloomRadius: 0.12
  }
};
var QUICK_PHASE0_AXIS_WEIGHTS = {
  filmCharacter: {
    saturation: 0.24,
    temperature: 0.16,
    tint: -0.06,
    grainIntensity: 0.1,
    vignette: 0.12
  },
  era: {
    fade: 0.18,
    saturation: -0.14,
    contrast: -0.08,
    halationIntensity: 0.16,
    halationSpread: 6
  },
  dynamics: {
    exposure: 0.24,
    contrast: 0.18,
    bloomStrength: 0.16,
    bloomThreshold: -0.06,
    bloomRadius: 0.12
  }
};
function clampAxisValue(value) {
  return Math.max(
    QUICK_AXIS_DEFAULT_RANGE.min,
    Math.min(QUICK_AXIS_DEFAULT_RANGE.max, value)
  );
}
function clampParamValue(key, value) {
  switch (key) {
    case "exposure":
      return Math.max(-2, Math.min(2, value));
    case "contrast":
    case "saturation":
      return Math.max(0, Math.min(2, value));
    case "temperature":
    case "tint":
      return Math.max(-1, Math.min(1, value));
    case "rgbShift":
      return Math.max(0, Math.min(PHASE0_RGB_SHIFT_MAX, value));
    case "grainIntensity":
      return clampGrainIntensity(value);
    case "vignette":
    case "fade":
    case "lensSoftness":
    case "grainRadialMix":
    case "grainSize":
    case "halationIntensity":
    case "halationThreshold":
    case "halationRadius":
    case "bloomStrength":
    case "bloomThreshold":
    case "bloomRadius":
    case "diffusion":
    case "bloomSoftKnee":
    case "halationSoftKnee":
    case "compressionAmount":
    case "compressionRange":
      return Math.max(0, Math.min(1, value));
    case "halationSpread":
      return Math.max(0, Math.min(40, value));
    default:
      return value;
  }
}
function applyWeightedPatch(base, state, weights) {
  const next = { ...base };
  for (const axis of QUICK_AXIS_IDS) {
    const axisValue = clampAxisValue(state[axis]);
    for (const [key, weight] of Object.entries(weights[axis])) {
      if (typeof weight !== "number") continue;
      next[key] = clampParamValue(key, next[key] + axisValue * weight);
    }
  }
  return next;
}
function coerceQuickState(input) {
  return {
    filmCharacter: clampAxisValue(input?.filmCharacter ?? 0),
    era: clampAxisValue(input?.era ?? 0),
    dynamics: clampAxisValue(input?.dynamics ?? 0)
  };
}
function applyQuickStateToParams(base, state) {
  return applyWeightedPatch(
    base,
    state,
    QUICK_FULL_AXIS_WEIGHTS
  );
}
function applyQuickStateToPhase0Params(base, state) {
  return applyWeightedPatch(
    base,
    state,
    QUICK_PHASE0_AXIS_WEIGHTS
  );
}

// src/phase0-schema.ts
import { z as z3 } from "zod";
var PHASE0_SCHEMA_VERSION = 2;
var PHASE0_PRESET_DEFAULT = "reset";
var PHASE0_PRESET_STRENGTH_DEFAULT = 1;
var PHASE0_HALATION_HUE_MIN = 0;
var PHASE0_HALATION_HUE_MAX = 100;
var PHASE0_PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "rgbShift",
  "lensSoftness",
  "grainRadialMix",
  "grainSize",
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
  "compressionAmount",
  "compressionRange",
  "printContrast",
  "cyan",
  "magenta",
  "yellow",
  "fade",
  "vignette",
  "grainIntensity"
];
var PHASE0_MAX_SOURCE_DURATION_SEC = 60 * 5;
var PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 3840;
var PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES = 8 * 1024 * 1024 * 1024;
var PHASE0_OUTPUT_PROFILE = {
  longEdge: 1920,
  fps: 30,
  codec: "h264",
  container: "mp4",
  preserveAudio: true
};
var PHASE0_BENCHMARK_GATES = {
  passRealtimeRatio: 2.5,
  strongGoRealtimeRatio: 2,
  noGoRealtimeRatio: 3
};
var phase0HalationHueSchema = z3.number().min(PHASE0_HALATION_HUE_MIN).max(PHASE0_HALATION_HUE_MAX);
var phase0RgbShiftSchema = z3.number().min(0).max(PHASE0_RGB_SHIFT_MAX);
var phase0ParamsSchema = z3.object({
  exposure: z3.number().min(-2).max(2).default(PRESETS.reset.exposure),
  contrast: z3.number().min(0).max(2).default(PRESETS.reset.contrast),
  saturation: z3.number().min(0).max(2).default(PRESETS.reset.saturation),
  temperature: z3.number().min(-1).max(1).default(PRESETS.reset.temperature),
  tint: z3.number().min(-1).max(1).default(PRESETS.reset.tint),
  rgbShift: phase0RgbShiftSchema.default(PRESETS.reset.rgbShift),
  lensSoftness: z3.number().min(0).max(1).default(PRESETS.reset.lensSoftness),
  grainRadialMix: z3.number().min(0).max(1).default(PRESETS.reset.grainRadialMix),
  grainSize: z3.number().min(0).max(1).default(PRESETS.reset.grainSize),
  bloomThreshold: z3.number().min(0).max(1).default(PRESETS.reset.bloomThreshold),
  bloomStrength: z3.number().min(0).max(1).default(PRESETS.reset.bloomStrength),
  bloomRadius: z3.number().min(0).max(1).default(PRESETS.reset.bloomRadius),
  diffusion: z3.number().min(0).max(1).default(PRESETS.reset.diffusion),
  halationIntensity: z3.number().min(0).max(1).default(PRESETS.reset.halationIntensity),
  halationSpread: z3.number().min(0).max(40).default(PRESETS.reset.halationSpread),
  halationHue: phase0HalationHueSchema.default(PRESETS.reset.halationHue),
  halationThreshold: z3.number().min(0).max(1).default(PRESETS.reset.halationThreshold),
  halationRadius: z3.number().min(0).max(1).default(PRESETS.reset.halationRadius),
  bloomSoftKnee: z3.number().min(0).max(1).default(PRESETS.reset.bloomSoftKnee),
  halationSoftKnee: z3.number().min(0).max(1).default(PRESETS.reset.halationSoftKnee),
  compressionAmount: z3.number().min(0).max(1).default(PRESETS.reset.compressionAmount),
  compressionRange: z3.number().min(0).max(1).default(PRESETS.reset.compressionRange),
  printContrast: z3.number().min(0).max(1).default(PRESETS.reset.printContrast),
  cyan: z3.number().min(-1).max(1).default(PRESETS.reset.cyan),
  magenta: z3.number().min(-1).max(1).default(PRESETS.reset.magenta),
  yellow: z3.number().min(-1).max(1).default(PRESETS.reset.yellow),
  fade: z3.number().min(0).max(1).default(PRESETS.reset.fade),
  vignette: z3.number().min(0).max(1).default(PRESETS.reset.vignette),
  grainIntensity: z3.number().min(0).transform(clampGrainIntensity).default(PRESETS.reset.grainIntensity)
});
var phase0ParamsPatchSchema = z3.object({
  exposure: z3.number().min(-2).max(2).optional(),
  contrast: z3.number().min(0).max(2).optional(),
  saturation: z3.number().min(0).max(2).optional(),
  temperature: z3.number().min(-1).max(1).optional(),
  tint: z3.number().min(-1).max(1).optional(),
  rgbShift: phase0RgbShiftSchema.optional(),
  lensSoftness: z3.number().min(0).max(1).optional(),
  grainRadialMix: z3.number().min(0).max(1).optional(),
  grainSize: z3.number().min(0).max(1).optional(),
  bloomThreshold: z3.number().min(0).max(1).optional(),
  bloomStrength: z3.number().min(0).max(1).optional(),
  bloomRadius: z3.number().min(0).max(1).optional(),
  diffusion: z3.number().min(0).max(1).optional(),
  halationIntensity: z3.number().min(0).max(1).optional(),
  halationSpread: z3.number().min(0).max(40).optional(),
  halationHue: phase0HalationHueSchema.optional(),
  halationThreshold: z3.number().min(0).max(1).optional(),
  halationRadius: z3.number().min(0).max(1).optional(),
  bloomSoftKnee: z3.number().min(0).max(1).optional(),
  halationSoftKnee: z3.number().min(0).max(1).optional(),
  compressionAmount: z3.number().min(0).max(1).optional(),
  compressionRange: z3.number().min(0).max(1).optional(),
  printContrast: z3.number().min(0).max(1).optional(),
  cyan: z3.number().min(-1).max(1).optional(),
  magenta: z3.number().min(-1).max(1).optional(),
  yellow: z3.number().min(-1).max(1).optional(),
  fade: z3.number().min(0).max(1).optional(),
  vignette: z3.number().min(0).max(1).optional(),
  grainIntensity: z3.number().min(0).transform(clampGrainIntensity).optional()
});
var phase0QuickStateSchema = z3.object(
  {
    [QUICK_AXIS_IDS[0]]: z3.number().min(-1).max(1),
    [QUICK_AXIS_IDS[1]]: z3.number().min(-1).max(1),
    [QUICK_AXIS_IDS[2]]: z3.number().min(-1).max(1)
  }
);
var phase0ProjectLutSchema = z3.object({
  title: z3.string().min(1),
  size: z3.number().int().positive(),
  data: z3.array(z3.number()),
  intensity: z3.number().min(0).max(1).default(1)
});
var phase0ProjectSchemaInput = z3.object({
  schemaVersion: z3.literal(PHASE0_SCHEMA_VERSION),
  projectId: z3.string().min(1),
  createdAt: z3.string().min(1),
  updatedAt: z3.string().min(1),
  presetName: z3.string().min(1),
  strength: z3.number().min(0).max(1).default(PHASE0_PRESET_STRENGTH_DEFAULT),
  quickState: phase0QuickStateSchema.default(DEFAULT_QUICK_STATE),
  params: phase0ParamsPatchSchema,
  // Legacy creative LUT slot. Keep parse-compatible so older saved projects
  // normalize into the current dual-LUT shape on load.
  lut: phase0ProjectLutSchema.nullable().optional(),
  inputLut: phase0ProjectLutSchema.nullable().optional(),
  creativeLut: phase0ProjectLutSchema.nullable().optional(),
  output: z3.object({
    longEdge: z3.literal(PHASE0_OUTPUT_PROFILE.longEdge),
    fps: z3.literal(PHASE0_OUTPUT_PROFILE.fps),
    codec: z3.literal(PHASE0_OUTPUT_PROFILE.codec),
    container: z3.literal(PHASE0_OUTPUT_PROFILE.container),
    preserveAudio: z3.boolean().default(PHASE0_OUTPUT_PROFILE.preserveAudio)
  })
});
var phase0ProjectSchema = phase0ProjectSchemaInput.transform(
  ({ lut, inputLut, creativeLut, ...project }) => {
    const safePresetName = Object.prototype.hasOwnProperty.call(PRESETS, project.presetName) ? project.presetName : PHASE0_PRESET_DEFAULT;
    const derivedParams = applyQuickStateToPhase0Params(
      interpolatePhase0PresetParams(safePresetName, project.strength),
      project.quickState
    );
    return {
      ...project,
      presetName: safePresetName,
      params: mergePhase0Params(derivedParams, project.params),
      inputLut: inputLut ?? null,
      creativeLut: creativeLut ?? lut ?? null
    };
  }
);
function pickPhase0Params(params) {
  const next = {};
  for (const key of PHASE0_PARAM_KEYS) {
    next[key] = params[key];
  }
  return phase0ParamsSchema.parse(next);
}
function createFilmtoneDefaultPhase0Params() {
  return pickPhase0Params(createFilmtoneDefaultParams());
}
function phase0PresetTargetParams(presetName) {
  if (presetName === PHASE0_PRESET_DEFAULT) {
    return createFilmtoneDefaultPhase0Params();
  }
  return pickPhase0Params(PRESETS[presetName]);
}
function createDefaultPhase0Params(presetName = PHASE0_PRESET_DEFAULT) {
  return phase0PresetTargetParams(presetName);
}
function interpolatePhase0PresetParams(presetName, strength) {
  const clamped = Math.max(0, Math.min(1, strength));
  const reset = pickPhase0Params(PRESETS.reset);
  const target = phase0PresetTargetParams(presetName);
  const params = { ...reset };
  for (const key of PHASE0_PARAM_KEYS) {
    params[key] = reset[key] + (target[key] - reset[key]) * clamped;
  }
  return phase0ParamsSchema.parse(params);
}
function mergePhase0Params(base, patch) {
  return phase0ParamsSchema.parse({ ...base, ...patch });
}
function makeProjectId() {
  const fromCrypto = globalThis.crypto?.randomUUID?.();
  if (typeof fromCrypto === "string" && fromCrypto.length > 0) {
    return fromCrypto;
  }
  return `phase0-${Date.now().toString(36)}`;
}
function createPhase0ProjectState(presetName = PHASE0_PRESET_DEFAULT) {
  const now = (/* @__PURE__ */ new Date()).toISOString();
  return phase0ProjectSchema.parse({
    schemaVersion: PHASE0_SCHEMA_VERSION,
    projectId: makeProjectId(),
    createdAt: now,
    updatedAt: now,
    presetName,
    strength: PHASE0_PRESET_STRENGTH_DEFAULT,
    quickState: DEFAULT_QUICK_STATE,
    params: createDefaultPhase0Params(presetName),
    inputLut: null,
    creativeLut: null,
    output: PHASE0_OUTPUT_PROFILE
  });
}

// src/native-bridge.ts
function serializeCubeLut(lut, options) {
  return {
    title: options?.title ?? lut.title ?? "Custom LUT",
    size: lut.size,
    data: Array.from(lut.data),
    intensity: options?.intensity ?? 1
  };
}
function deserializeCubeLutData(lut) {
  return Float32Array.from(lut.data);
}
function getPhase0SourceCapViolations(probe) {
  const violations = [];
  const longEdge = typeof probe.width === "number" && typeof probe.height === "number" ? Math.max(probe.width, probe.height) : void 0;
  if (probe.kind === "video" && typeof probe.durationSec === "number" && probe.durationSec > PHASE0_MAX_SOURCE_DURATION_SEC) {
    violations.push(
      `Source duration ${probe.durationSec.toFixed(1)}s exceeds ${PHASE0_MAX_SOURCE_DURATION_SEC}s`
    );
  }
  if (typeof longEdge === "number" && longEdge > PHASE0_APPROX_SOURCE_LONG_EDGE_MAX) {
    violations.push(
      `Source long edge ${longEdge}px exceeds ${PHASE0_APPROX_SOURCE_LONG_EDGE_MAX}px`
    );
  }
  if (typeof probe.fileSizeBytes === "number" && probe.fileSizeBytes > PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES) {
    violations.push(
      `Source size ${probe.fileSizeBytes} bytes exceeds ${PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES} bytes`
    );
  }
  return violations;
}
function assertPhase0SourceProbeWithinCaps(probe) {
  const violations = getPhase0SourceCapViolations(probe);
  if (violations.length > 0) {
    throw new RangeError(violations.join("; "));
  }
}
function buildPhase0ExportRequest(options) {
  const probe = options.probe ?? void 0;
  if (probe) {
    assertPhase0SourceProbeWithinCaps(probe);
  }
  const toTransportLut = (lut) => lut ? {
    title: lut.title,
    size: lut.size,
    data: lut.data,
    intensity: lut.intensity
  } : null;
  return {
    sourceUri: options.source.uri,
    sourceKind: options.source.kind,
    sourceProbe: probe,
    output: {
      ...PHASE0_OUTPUT_PROFILE,
      ...options.output
    },
    grade: {
      presetName: options.project.presetName,
      presetVersion: PRESET_VERSION,
      quickState: options.project.quickState,
      params: options.project.params
    },
    inputLut: toTransportLut(options.project.inputLut),
    creativeLut: toTransportLut(options.project.creativeLut)
  };
}

// src/benchmark-row.ts
var ROW_HEADER = "| date | device | iOS | clip_id | input_resolution | output_resolution | realtime_ratio | file_size_mb | thermal | memory_warnings | save | visual | error | duration_sec |";
var ROW_DIVIDER = "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |";
function buildBenchmarkRow(input) {
  const { result, benchmark, probe, clipId, visualFloor, saveResult } = input;
  const date = (input.date ?? /* @__PURE__ */ new Date()).toISOString().slice(0, 10);
  const inputResolution = benchmark.sourceResolution ?? (probe?.width && probe?.height ? `${probe.width}x${probe.height}` : "unknown");
  const outputResolution = `${result.outputWidth}x${result.outputHeight}@${result.outputFps}`;
  const fileSizeMb = typeof result.fileSizeBytes === "number" ? Math.round(result.fileSizeBytes / (1024 * 1024) * 10) / 10 : null;
  return {
    date,
    deviceModel: benchmark.deviceModel,
    iosVersion: benchmark.iosVersion,
    clipId,
    inputResolution,
    outputResolution,
    realtimeRatio: typeof result.realtimeRatio === "number" ? Math.round(result.realtimeRatio * 100) / 100 : null,
    fileSizeMb,
    thermalState: benchmark.thermalState ?? "unknown",
    memoryWarningCount: typeof benchmark.memoryWarningCount === "number" ? benchmark.memoryWarningCount : 0,
    saveResult,
    visualFloor,
    errorDomain: benchmark.errorDomain ?? null,
    errorCode: benchmark.errorCode ?? null,
    durationSec: typeof benchmark.sourceDurationSec === "number" ? benchmark.sourceDurationSec : null
  };
}
function formatBenchmarkRow(row) {
  const realtime = row.realtimeRatio != null ? `${row.realtimeRatio}x` : "\u2014";
  const fileSize = row.fileSizeMb != null ? `${row.fileSizeMb}MB` : "\u2014";
  const errorCell = row.errorDomain || row.errorCode ? `${row.errorDomain ?? "\u2014"}:${row.errorCode ?? "\u2014"}` : "none";
  const durationCell = row.durationSec != null ? row.durationSec.toFixed(1) : "\u2014";
  return [
    "",
    row.date,
    row.deviceModel,
    row.iosVersion,
    row.clipId,
    row.inputResolution,
    row.outputResolution,
    realtime,
    fileSize,
    `thermal=${row.thermalState}`,
    `mem_warn=${row.memoryWarningCount}`,
    `save=${row.saveResult}`,
    `visual=${row.visualFloor}`,
    `err=${errorCell}`,
    durationCell,
    ""
  ].join(" | ").trim();
}
function benchmarkMarkdownTableHeader() {
  return `${ROW_HEADER}
${ROW_DIVIDER}`;
}
var ROW_PATTERN = /^\|\s*(?<date>[^|]+?)\s*\|\s*(?<device>[^|]+?)\s*\|\s*(?<iosVersion>[^|]+?)\s*\|\s*(?<clipId>[^|]+?)\s*\|\s*(?<inputRes>[^|]+?)\s*\|\s*(?<outputRes>[^|]+?)\s*\|\s*(?<realtime>[^|]+?)\s*\|\s*(?<fileSize>[^|]+?)\s*\|\s*thermal=(?<thermal>[^|]+?)\s*\|\s*mem_warn=(?<mem>[^|]+?)\s*\|\s*save=(?<save>[^|]+?)\s*\|\s*visual=(?<visual>[^|]+?)\s*\|\s*err=(?<err>[^|]+?)\s*\|\s*(?<durationSec>[^|]+?)\s*\|\s*$/;
function parseBenchmarkRow(line) {
  const trimmed = line.trim();
  if (!trimmed.startsWith("|")) return null;
  if (trimmed.startsWith("| date |") || trimmed.startsWith("| --- |")) return null;
  const match = trimmed.match(ROW_PATTERN);
  if (!match || !match.groups) return null;
  const g = match.groups;
  const realtimeRaw = g.realtime.trim().replace(/x$/, "");
  const realtimeRatio = realtimeRaw === "\u2014" ? null : Number.parseFloat(realtimeRaw);
  const fileRaw = g.fileSize.trim().replace(/MB$/, "");
  const fileSizeMb = fileRaw === "\u2014" ? null : Number.parseFloat(fileRaw);
  const errorRaw = g.err.trim();
  let errorDomain = null;
  let errorCode = null;
  if (errorRaw && errorRaw !== "none") {
    const [domain, code] = errorRaw.split(":");
    errorDomain = domain && domain !== "\u2014" ? domain : null;
    errorCode = code && code !== "\u2014" ? code : null;
  }
  const durationRaw = g.durationSec.trim();
  const durationSec = durationRaw === "\u2014" ? null : Number.parseFloat(durationRaw);
  return {
    raw: trimmed,
    date: g.date.trim(),
    deviceModel: g.device.trim(),
    iosVersion: g.iosVersion.trim(),
    clipId: g.clipId.trim(),
    inputResolution: g.inputRes.trim(),
    outputResolution: g.outputRes.trim(),
    realtimeRatio: realtimeRatio != null && Number.isFinite(realtimeRatio) ? realtimeRatio : null,
    fileSizeMb: fileSizeMb != null && Number.isFinite(fileSizeMb) ? fileSizeMb : null,
    thermalState: g.thermal.trim(),
    memoryWarningCount: Number.parseInt(g.mem.trim(), 10) || 0,
    saveResult: g.save.trim() ?? "not-run",
    visualFloor: g.visual.trim() ?? "not-checked",
    errorDomain,
    errorCode,
    durationSec: durationSec != null && Number.isFinite(durationSec) ? durationSec : null
  };
}

// src/optical-recommendation.ts
var OPTICAL_PARAM_KEYS = [
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
  "crossFilterStrength",
  "crossFilterSpikes",
  "crossFilterAngle",
  "crossFilterLength",
  "crossFilterThreshold",
  "crossFilterChromatic",
  "crossFilterSizeLimit",
  "crossFilterRandomness",
  "crossFilterHardMode",
  "crossFilterMinSpacing",
  "crossFilterDepthGain",
  "crossFilterAngleGain",
  "crossFilterAngleGamma",
  "crossFilterEdgeLengthGain",
  "crossFilterEdgeStrengthGain",
  "rgbShift",
  "lensSoftness"
];
var OPTICAL_BASE_PATCH = Object.fromEntries(
  OPTICAL_PARAM_KEYS.map((key) => [key, PRESETS.reset[key]])
);
var OPTICAL_RECIPE_PATCHES = {
  "mist:clean": {
    diffusion: 0.08,
    bloomStrength: 0.06,
    bloomThreshold: 0.84,
    bloomRadius: 0.36,
    halationIntensity: 0.03,
    halationSpread: 15,
    halationRadius: 0.28,
    halationHue: 18
  },
  "glow:clean": {
    bloomStrength: 0.22,
    bloomThreshold: 0.72,
    bloomRadius: 0.52,
    diffusion: 0.08,
    halationIntensity: 0.1,
    halationSpread: 22,
    halationRadius: 0.44,
    halationHue: 20
  },
  "cross:clean": {
    crossFilterStrength: 0.28,
    crossFilterSpikes: 4,
    crossFilterAngle: 0,
    crossFilterLength: 0.4,
    crossFilterThreshold: 0.92,
    crossFilterChromatic: 0.2,
    crossFilterSizeLimit: 0.12,
    crossFilterRandomness: 0.9,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1,
    crossFilterDepthGain: 0.25,
    crossFilterAngleGain: 0.35,
    crossFilterAngleGamma: 1.4,
    crossFilterEdgeLengthGain: 0.45,
    crossFilterEdgeStrengthGain: 0.25
  },
  "lens:clean": {
    rgbShift: 8e-4,
    lensSoftness: 0.08
  },
  warmIndoor: {
    bloomStrength: 0.28,
    bloomThreshold: 0.7,
    bloomRadius: 0.54,
    diffusion: 0.1,
    halationIntensity: 0.12,
    halationSpread: 24,
    halationRadius: 0.46,
    halationHue: 24
  },
  nightCity: {
    bloomStrength: 0.34,
    bloomThreshold: 0.68,
    bloomRadius: 0.62,
    diffusion: 0.1,
    halationIntensity: 0.16,
    halationSpread: 28,
    halationRadius: 0.58,
    halationHue: 18
  },
  skinCloseUp: {
    diffusion: 0.14,
    bloomStrength: 0.1,
    bloomThreshold: 0.82,
    bloomRadius: 0.38,
    halationIntensity: 0.05,
    halationSpread: 18,
    halationRadius: 0.32,
    halationHue: 20
  },
  nightSpot: {
    crossFilterStrength: 0.56,
    crossFilterSpikes: 6,
    crossFilterAngle: 12,
    crossFilterLength: 0.66,
    crossFilterThreshold: 0.9,
    crossFilterChromatic: 0.38,
    crossFilterSizeLimit: 0.2,
    crossFilterRandomness: 0.72,
    crossFilterHardMode: 1,
    crossFilterMinSpacing: 1.2
  },
  productEdge: {
    rgbShift: 15e-4,
    lensSoftness: 0.18
  },
  coverStillMatch: {
    rgbShift: 8e-4,
    lensSoftness: 0.12
  }
};
function clamp01(value) {
  if (!Number.isFinite(value)) return 0;
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}
function normalizeDescriptor(descriptor) {
  return {
    medianLuma: clamp01(descriptor.medianLuma),
    highlightCoverage: clamp01(descriptor.highlightCoverage),
    specularIslands: clamp01(descriptor.specularIslands),
    pointLightScore: clamp01(descriptor.pointLightScore),
    globalContrast: clamp01(descriptor.globalContrast),
    warmthScore: clamp01(descriptor.warmthScore),
    portraitLikelihood: clamp01(descriptor.portraitLikelihood),
    nightScore: clamp01(descriptor.nightScore),
    sceneComplexity: clamp01(descriptor.sceneComplexity),
    dominantShotCoverage: clamp01(descriptor.dominantShotCoverage),
    sampleCount: typeof descriptor.sampleCount === "number" && descriptor.sampleCount > 0 ? Math.round(descriptor.sampleCount) : void 0
  };
}
function buildScores(descriptor) {
  const glowScore = clamp01(
    descriptor.highlightCoverage * 1.4 + descriptor.specularIslands * 0.22 + descriptor.warmthScore * 0.26 + descriptor.globalContrast * 0.18 + descriptor.pointLightScore * 0.08 + (1 - descriptor.sceneComplexity) * 0.12
  );
  const crossScore = clamp01(
    descriptor.pointLightScore * 0.56 + descriptor.specularIslands * 0.16 + descriptor.nightScore * 0.16 + descriptor.globalContrast * 0.08 + descriptor.sceneComplexity * 0.04
  );
  const mistScore = clamp01(
    descriptor.portraitLikelihood * 0.44 + (1 - descriptor.highlightCoverage) * 0.16 + (1 - descriptor.pointLightScore) * 0.18 + descriptor.medianLuma * 0.08 + descriptor.warmthScore * 0.06 + (1 - descriptor.sceneComplexity) * 0.08
  );
  const lensScore = clamp01(
    descriptor.globalContrast * 0.24 + (1 - descriptor.sceneComplexity) * 0.18 + descriptor.specularIslands * 0.12
  );
  return {
    mist: mistScore,
    glow: glowScore,
    cross: crossScore,
    lens: lensScore
  };
}
function entryConfidence(familyScore, lowConfidence) {
  if (lowConfidence) return "low";
  if (familyScore >= 0.78) return "high";
  if (familyScore >= 0.58) return "medium";
  return "low";
}
function pickProfileAndRecipe(family, descriptor) {
  if (family === "glow") {
    if (descriptor.warmthScore >= 0.58 && descriptor.warmthScore >= descriptor.nightScore) {
      return { profile: "warm", recipe: "warmIndoor" };
    }
    if (descriptor.nightScore >= 0.55) {
      return { profile: "night", recipe: "nightCity" };
    }
  }
  if (family === "mist" && descriptor.portraitLikelihood >= 0.55) {
    return { profile: "portrait", recipe: "skinCloseUp" };
  }
  if (family === "cross") {
    return { profile: "spotlight", recipe: "nightSpot" };
  }
  if (family === "lens") {
    if (descriptor.globalContrast >= 0.72) {
      return { profile: "product", recipe: "productEdge" };
    }
    return { profile: "stillMatch", recipe: "coverStillMatch" };
  }
  return { profile: "clean", recipe: null };
}
function dedupeRationale(tags) {
  return Array.from(new Set(tags));
}
function buildRationale(family, descriptor, lowConfidence) {
  const tags = [];
  if (family === "glow") {
    if (descriptor.highlightCoverage >= 0.08 || descriptor.warmthScore >= 0.58) {
      tags.push("practicalLights");
    }
  }
  if (family === "mist" && descriptor.portraitLikelihood >= 0.55) {
    tags.push("portraitSafe");
  }
  if (family === "cross" || descriptor.pointLightScore >= 0.6) {
    tags.push("pointLights");
  }
  if (lowConfidence || descriptor.dominantShotCoverage < 0.45) {
    tags.push("mixedScenes");
  }
  if (tags.length === 0 && family === "mist") {
    tags.push("portraitSafe");
  }
  if (tags.length === 0) {
    tags.push("practicalLights");
  }
  return dedupeRationale(tags);
}
function createEntry(family, descriptor, familyScore, lowConfidence) {
  const recipeInfo = pickProfileAndRecipe(family, descriptor);
  return {
    family,
    profile: recipeInfo.profile,
    recipe: recipeInfo.recipe,
    confidence: entryConfidence(familyScore, lowConfidence),
    rationale: buildRationale(family, descriptor, lowConfidence)
  };
}
function recommendOpticalFinish(descriptor) {
  const normalizedDescriptor = normalizeDescriptor(descriptor);
  const scores = buildScores(normalizedDescriptor);
  const lowConfidence = normalizedDescriptor.dominantShotCoverage < 0.45;
  const crossEligible = normalizedDescriptor.pointLightScore >= 0.6 && scores.cross >= 0.72;
  const glowEligible = normalizedDescriptor.highlightCoverage >= 0.08 && scores.glow >= 0.62;
  let primaryFamily = "mist";
  if (!lowConfidence) {
    if (crossEligible && scores.cross >= scores.glow) {
      primaryFamily = "cross";
    } else if (glowEligible) {
      primaryFamily = "glow";
    }
  }
  const rankedFamilies = ["mist", "glow", "cross"].filter((family) => family !== primaryFamily).sort((left, right) => scores[right] - scores[left]);
  const alternates = rankedFamilies.slice(0, 2).map(
    (family) => createEntry(family, normalizedDescriptor, scores[family], lowConfidence)
  );
  return {
    state: lowConfidence ? "low-confidence" : "ready",
    descriptor: normalizedDescriptor,
    primary: createEntry(
      primaryFamily,
      normalizedDescriptor,
      scores[primaryFamily],
      lowConfidence
    ),
    alternates
  };
}
function buildOpticalParamPatch(recommendation) {
  const primary = recommendation.primary;
  const recipeKey = primary.recipe ?? `${primary.family}:clean`;
  const recipePatch = OPTICAL_RECIPE_PATCHES[recipeKey];
  return {
    ...OPTICAL_BASE_PATCH,
    ...recipePatch
  };
}

// src/ios-phase0.ts
import { z as z4 } from "zod";
var IOS_PHASE0_SCHEMA_VERSION = 2;
var IOS_PHASE0_PARAM_KEYS = PHASE0_PARAM_KEYS;
var iosPhase0ParamsSchema = phase0ParamsSchema;
var IOS_PHASE0_OUTPUT_CODEC = "h264-mp4";
var IOS_PHASE0_OUTPUT_LONG_EDGE = PHASE0_OUTPUT_PROFILE.longEdge;
var IOS_PHASE0_OUTPUT_FPS = PHASE0_OUTPUT_PROFILE.fps;
var IOS_PHASE0_SOURCE_DURATION_CAP_SEC = PHASE0_MAX_SOURCE_DURATION_SEC;
var IOS_PHASE0_SOURCE_LONG_EDGE_CAP = PHASE0_APPROX_SOURCE_LONG_EDGE_MAX;
var IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES = PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES;
var IOS_PHASE0_SOURCE_CAPS = {
  durationSec: IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  longEdge: IOS_PHASE0_SOURCE_LONG_EDGE_CAP,
  fileSizeBytes: IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES
};
var IOS_PHASE0_BENCHMARK_SLOTS = [
  "bench-short",
  "bench-mid",
  "bench-long"
];
var iosPhase0SourceKindSchema = z4.enum(["image", "video"]);
var iosPhase0Tuple3Schema = z4.tuple([
  z4.number().finite(),
  z4.number().finite(),
  z4.number().finite()
]);
var iosPhase0SerializableLutSchema = z4.object({
  name: z4.string().min(1),
  title: z4.string().min(1).optional(),
  size: z4.number().int().positive(),
  intensity: z4.number().min(0).max(1).default(1),
  domainMin: iosPhase0Tuple3Schema.optional(),
  domainMax: iosPhase0Tuple3Schema.optional(),
  rgbaData: z4.array(z4.number().finite()).min(4).refine((data) => data.length % 4 === 0, {
    message: "LUT rgbaData must contain RGBA quads"
  })
});
function createIosPhase0SerializableLut(input) {
  const { cube, name, intensity = 1 } = input;
  return iosPhase0SerializableLutSchema.parse({
    name,
    title: cube.title || void 0,
    size: cube.size,
    intensity,
    domainMin: cube.domainMin,
    domainMax: cube.domainMax,
    rgbaData: Array.from(cube.data)
  });
}
var iosPhase0PickedSourceSchema = z4.object({
  uri: z4.string().min(1),
  displayName: z4.string().min(1),
  kind: iosPhase0SourceKindSchema.optional()
});
var iosPhase0PickedLutFileSchema = z4.object({
  uri: z4.string().min(1),
  displayName: z4.string().min(1),
  text: z4.string().min(1)
});
var iosPhase0SourceInfoSchema = z4.object({
  uri: z4.string().min(1),
  displayName: z4.string().min(1),
  kind: iosPhase0SourceKindSchema,
  width: z4.number().int().positive().optional(),
  height: z4.number().int().positive().optional(),
  durationSec: z4.number().positive().optional(),
  fileSizeBytes: z4.number().int().nonnegative().optional(),
  videoCodec: z4.string().min(1).optional(),
  audioCodec: z4.string().min(1).optional(),
  frameRate: z4.number().positive().optional(),
  hasAudio: z4.boolean().optional()
});
var IOS_PHASE0_PRESET_IDS = Object.keys(PRESETS);
var iosPhase0PresetIdSchema = z4.enum(IOS_PHASE0_PRESET_IDS);
var iosPhase0ExportSettingsSchema = z4.object({
  codec: z4.literal(IOS_PHASE0_OUTPUT_CODEC).default(IOS_PHASE0_OUTPUT_CODEC),
  outputLongEdge: z4.number().int().positive().max(IOS_PHASE0_OUTPUT_LONG_EDGE).default(IOS_PHASE0_OUTPUT_LONG_EDGE),
  outputFps: z4.literal(IOS_PHASE0_OUTPUT_FPS).default(IOS_PHASE0_OUTPUT_FPS)
});
var iosPhase0ExportPayloadSchema = z4.object({
  projectId: z4.string().min(1),
  sourceUri: z4.string().min(1),
  sourceDisplayName: z4.string().min(1),
  sourceKind: iosPhase0SourceKindSchema,
  presetId: iosPhase0PresetIdSchema,
  params: iosPhase0ParamsSchema,
  inputLut: iosPhase0SerializableLutSchema.nullable().optional(),
  creativeLut: iosPhase0SerializableLutSchema.nullable().optional(),
  benchmarkSlot: z4.enum(IOS_PHASE0_BENCHMARK_SLOTS).optional(),
  benchmarkRecipeId: z4.string().min(1).optional(),
  includeAudio: z4.boolean().optional(),
  exportSettings: iosPhase0ExportSettingsSchema.default({
    codec: IOS_PHASE0_OUTPUT_CODEC,
    outputLongEdge: IOS_PHASE0_OUTPUT_LONG_EDGE,
    outputFps: IOS_PHASE0_OUTPUT_FPS
  })
});
var iosPhase0ExportResultSchema = z4.object({
  outputUri: z4.string().min(1),
  outputDisplayName: z4.string().min(1),
  outputWidth: z4.number().int().positive(),
  outputHeight: z4.number().int().positive(),
  outputFps: z4.number().positive(),
  elapsedMs: z4.number().nonnegative(),
  realtimeRatio: z4.number().positive().optional(),
  fileSizeBytes: z4.number().int().nonnegative().optional(),
  benchmarkRecordUri: z4.string().min(1).optional()
});
var iosPhase0PermissionStateSchema = z4.enum([
  "granted",
  "denied",
  "limited",
  "not-required",
  "unknown"
]);
var iosPhase0ThermalStateSchema = z4.enum([
  "nominal",
  "fair",
  "serious",
  "critical",
  "unknown"
]);
var iosPhase0BenchmarkRecordSchema = z4.object({
  schemaVersion: z4.literal(IOS_PHASE0_SCHEMA_VERSION),
  recordedAt: z4.string().min(1),
  slot: z4.enum(IOS_PHASE0_BENCHMARK_SLOTS),
  runIndex: z4.number().int().positive(),
  appVersion: z4.string().min(1),
  buildNumber: z4.string().min(1),
  deviceModel: z4.string().min(1),
  iosVersion: z4.string().min(1),
  source: iosPhase0SourceInfoSchema,
  output: iosPhase0ExportResultSchema,
  elapsedMs: z4.number().nonnegative(),
  realtimeRatio: z4.number().positive(),
  thermalStateStart: iosPhase0ThermalStateSchema,
  thermalStateEnd: iosPhase0ThermalStateSchema,
  memoryWarningCount: z4.number().int().nonnegative(),
  permissionResults: z4.object({
    mediaLibrary: iosPhase0PermissionStateSchema,
    fileImport: iosPhase0PermissionStateSchema,
    sharing: iosPhase0PermissionStateSchema
  }),
  failureDomain: z4.string().min(1).optional(),
  failureCode: z4.string().min(1).optional(),
  failureMessage: z4.string().min(1).optional(),
  previewArtifacts: z4.object({
    firstFrameUri: z4.string().min(1).optional(),
    midFrameUri: z4.string().min(1).optional(),
    lastFrameUri: z4.string().min(1).optional()
  })
});
var iosPhase0AssetRefSchema = z4.object({
  uri: z4.string().min(1),
  displayName: z4.string().min(1),
  assetKind: z4.enum(["source", "lut", "derived-output", "benchmark-record"]),
  createdAt: z4.string().min(1),
  byteSize: z4.number().int().nonnegative().optional()
});
var iosPhase0LocalProjectSchema = z4.object({
  schemaVersion: z4.literal(IOS_PHASE0_SCHEMA_VERSION),
  projectId: z4.string().min(1),
  createdAt: z4.string().min(1),
  updatedAt: z4.string().min(1),
  presetId: iosPhase0PresetIdSchema,
  params: iosPhase0ParamsSchema,
  source: iosPhase0SourceInfoSchema.nullable(),
  sourceAssetRef: iosPhase0AssetRefSchema.nullable(),
  lutAssetRef: iosPhase0AssetRefSchema.nullable(),
  exportSettings: iosPhase0ExportSettingsSchema,
  derivedData: z4.object({
    lastOutput: iosPhase0AssetRefSchema.nullable().default(null),
    lastExportResult: iosPhase0ExportResultSchema.nullable().default(null),
    benchmarkRecords: z4.array(iosPhase0AssetRefSchema).default([])
  }),
  cacheMetadata: z4.object({
    workingDirectoryUri: z4.string().min(1).optional(),
    derivedOutputUris: z4.array(z4.string().min(1)).default([]),
    lastPurgeAt: z4.string().min(1).optional()
  })
});
function pickIosPhase0Params(params) {
  return pickPhase0Params(params);
}
function getIosPhase0SourceCapViolations(source) {
  const violations = [];
  const longEdge = typeof source.width === "number" && typeof source.height === "number" ? Math.max(source.width, source.height) : null;
  if (typeof source.durationSec === "number" && source.durationSec > IOS_PHASE0_SOURCE_DURATION_CAP_SEC) {
    violations.push(
      `duration>${IOS_PHASE0_SOURCE_DURATION_CAP_SEC}s`
    );
  }
  if (typeof longEdge === "number" && longEdge > IOS_PHASE0_SOURCE_LONG_EDGE_CAP) {
    violations.push(`long-edge>${IOS_PHASE0_SOURCE_LONG_EDGE_CAP}`);
  }
  if (typeof source.fileSizeBytes === "number" && source.fileSizeBytes > IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES) {
    violations.push(
      `file-size>${IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES}`
    );
  }
  return violations;
}
export {
  DEFAULT_QUICK_STATE,
  FILMTONE_DEFAULT_BASE_PRESET,
  FILMTONE_SOFT_FINISH_PATCH,
  FILM_GRAIN_INTENSITY_MAX,
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  IOS_PHASE0_BENCHMARK_SLOTS,
  IOS_PHASE0_OUTPUT_CODEC,
  IOS_PHASE0_OUTPUT_FPS,
  IOS_PHASE0_OUTPUT_LONG_EDGE,
  IOS_PHASE0_PARAM_KEYS,
  IOS_PHASE0_SCHEMA_VERSION,
  IOS_PHASE0_SOURCE_CAPS,
  IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES,
  IOS_PHASE0_SOURCE_LONG_EDGE_CAP,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE,
  LOOK_ID_BY_PRESET,
  PARAM_KEYS,
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
  PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
  PHASE0_BENCHMARK_GATES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_PARAM_KEYS,
  PHASE0_PRESET_DEFAULT,
  PHASE0_PRESET_STRENGTH_DEFAULT,
  PHASE0_RGB_SHIFT_MAX,
  PHASE0_SCHEMA_VERSION,
  PRESETS,
  PRESET_BUTTONS,
  PRESET_VERSION,
  QUICK_AXIS_DEFAULT_RANGE,
  QUICK_AXIS_IDS,
  applyQuickStateToParams,
  applyQuickStateToPhase0Params,
  assertPhase0SourceProbeWithinCaps,
  benchmarkMarkdownTableHeader,
  buildBenchmarkRow,
  buildOpticalParamPatch,
  buildPhase0ExportRequest,
  cameraOpticsSchema,
  chromaUnitFromHueDegrees,
  clampGrainIntensity,
  cloneParams,
  coerceQuickState,
  createDefaultFilmLookGradeProps,
  createDefaultPhase0Params,
  createFilmtoneDefaultParams,
  createFilmtoneDefaultPhase0Params,
  createIosPhase0SerializableLut,
  createPhase0ProjectState,
  deserializeCubeLutData,
  filmLabDepthTrackSchema,
  filmLabParamsSchema,
  filmLookGradeDefaultProps,
  filmLookGradeInputSchema,
  filmLookSpikeDefaultProps,
  filmLookSpikeInputSchema,
  findMatchingPreset,
  formatBenchmarkRow,
  getIosPhase0SourceCapViolations,
  getPhase0SourceCapViolations,
  gradeMatchesPreset,
  halationHueToHex,
  hslToRgb01,
  interpolatePhase0PresetParams,
  iosPhase0AssetRefSchema,
  iosPhase0BenchmarkRecordSchema,
  iosPhase0ExportPayloadSchema,
  iosPhase0ExportResultSchema,
  iosPhase0ExportSettingsSchema,
  iosPhase0LocalProjectSchema,
  iosPhase0ParamsSchema,
  iosPhase0PickedLutFileSchema,
  iosPhase0PickedSourceSchema,
  iosPhase0PresetIdSchema,
  iosPhase0SerializableLutSchema,
  iosPhase0SourceInfoSchema,
  iosPhase0SourceKindSchema,
  iosPhase0ThermalStateSchema,
  lookIdForPreset,
  mergePhase0Params,
  nearestHueDegreesToDirection,
  packCubeLutToFloatRgbaGrid,
  parseBenchmarkRow,
  parseCube,
  phase0ParamsSchema,
  phase0ProjectLutSchema,
  phase0ProjectSchema,
  phase0QuickStateSchema,
  pickIosPhase0Params,
  pickPhase0Params,
  quickStateSchema,
  recommendOpticalFinish,
  serializeCubeLut
};
