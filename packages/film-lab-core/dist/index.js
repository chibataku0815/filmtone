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
  /** ハードな微細ディテール（デジタル acutance）を弱める柔らかさ（0〜1）。lensSoftness とは別 param で、画面中心も対象。Phase 1 では neutral plumbing のみで renderer は未参照。 */
  "detailSoftness",
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
  /** Optical filter direct-light transmission（1=neutral, lower values redistribute light into scatter）。 */
  "opticalDirectTransmission",
  /** Optical filter black retention（1=preserve blacks, 0=mist floor lifts shadows）。 */
  "opticalBlackRetention",
  /** Optical filter direct/scatter mix strength（0=legacy screen glow, 1=full direct+scatter model）。 */
  "opticalScatterStrength",
  /** Optical filter highlight-reactive scatter emphasis（0=linear, 1=strong highlight response）。 */
  "opticalHighlightReactivity",
  /** Optical filter warm scatter bias（0=neutral, 1=warm practical glow）。 */
  "opticalWarmScatter",
  /** Optical filter RGB spectral tail split（0=neutral, 1=strong red-tail / blue-core separation）。 */
  "opticalSpectralTail",
  "fade",
  "highlights",
  "shadows",
  "shadowTone",
  /** Toe separation amount（0=off、1=max）。Deep black anchor is preserved. */
  "shadowLatitude",
  /** 黒の床位置（-1=深黒 Baselight Flare、0=neutral、+1=milky lift）。bi-directional。
   *  正方向は shadow-masked additive lift（最大 +0.18）。負方向は Baselight Base
   *  Grade Flare 型 `y = x²(1+f)/(x+f)`（0 anchor smooth、x=1 不変、負値リスクなし）。
   *  baseGradeV2 内 fade 直前で適用。range: -1..+1 */
  "blackPoint",
  /** 黒 anchor 近傍 (0..0.15) の局所 power-curve（0=off、1=max）。0 を anchor 保持で
   *  「黒の硬さ」を増やす。Baselight Black Soft Clip / Color Finale Toe 系。
   *  baseGradeV2 内、blackPoint より前で適用（blackPoint=+1 と toe=1 を独立に
   *  操作可能にするため）。range: 0..1 */
  "toeContrast",
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
  /** Film Breath amount（0=off、1=max）。動画時のみ露出・コントラスト・色を時間方向に微変調する。range: 0–1 */
  "filmBreathAmount",
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
  "crossFilterEdgeStrengthGain",
  /** Halo Prism strength（0=off、1=max）。 */
  "haloPrismStrength",
  /** Halo Prism ring radius（0=small、1=large）。 */
  "haloPrismRadius",
  /** Halo Prism ring width（0=narrow、1=wide）。 */
  "haloPrismWidth",
  /** Halo Prism chromatic edge separation（0=white、1=strong spectral edges）。 */
  "haloPrismChromatic",
  /** Halo Prism compact-source threshold（0=easy trigger、1=bright points only）。 */
  "haloPrismThreshold",
  /** Halo Prism partial-arc split amount（0=full ring、1=split/lower arcs）。 */
  "haloPrismSplit",
  /** Halo Prism arc orientation in degrees。 */
  "haloPrismAngle",
  /** Halo Prism source coupling（0=mostly procedural、1=source-reactive）。 */
  "haloPrismSourceReactivity"
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

// src/film-breath.ts
var FILM_BREATH_ZERO_OFFSETS = {
  exposure: 0,
  contrast: 0,
  temperature: 0,
  tint: 0
};
var FILM_BREATH_LIMITS = {
  exposure: 0.5,
  contrast: 0.15,
  temperature: 0.22,
  tint: 0.12
};
function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}
function clamp01(value) {
  return clamp(value, 0, 1);
}
function smoothstep(t) {
  const x = clamp01(t);
  return x * x * (3 - 2 * x);
}
function normalizeSeed(sourceSeed) {
  if (!Number.isFinite(sourceSeed)) {
    return 0;
  }
  return Math.trunc(Math.abs(sourceSeed)) >>> 0;
}
function hashUnit(seed, lattice, salt) {
  let x = seed >>> 0;
  x ^= Math.imul((lattice | 0) >>> 0, 2654435761) >>> 0;
  x ^= Math.imul(salt >>> 0, 2246822507) >>> 0;
  x ^= x >>> 16;
  x = Math.imul(x, 2146121005) >>> 0;
  x ^= x >>> 15;
  x = Math.imul(x, 2221713035) >>> 0;
  x ^= x >>> 16;
  return (x >>> 0) / 4294967295;
}
function valueNoise(timeSeconds, seed, salt, periodSeconds) {
  const phase = hashUnit(seed, 0, salt ^ 2769414579) * 8;
  const position = timeSeconds / periodSeconds + phase;
  const lattice = Math.floor(position);
  const fraction = position - lattice;
  const a = hashUnit(seed, lattice, salt) * 2 - 1;
  const b = hashUnit(seed, lattice + 1, salt) * 2 - 1;
  return a + (b - a) * smoothstep(fraction);
}
function breathNoise(timeSeconds, seed, salt) {
  const fast = valueNoise(timeSeconds, seed, salt ^ 1386723780, 1.8);
  const medium = valueNoise(timeSeconds, seed, salt, 4.8);
  const slow = valueNoise(timeSeconds, seed, salt ^ 1831565813, 8.6);
  const long = valueNoise(timeSeconds, seed, salt ^ 461845907, 15.5);
  const weighted = fast * 0.15 + medium * 0.55 + slow * 0.2 + long * 0.1;
  return clamp(weighted * 2.5, -1, 1);
}
function deriveFilmBreathOffsets(amount, timeSeconds, sourceSeed) {
  const clampedAmount = clamp01(amount);
  if (clampedAmount <= 0 || !Number.isFinite(timeSeconds) || timeSeconds <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }
  const drive = Math.pow(clampedAmount, 1.35);
  const envelope = smoothstep(timeSeconds / 1.25);
  const scale = drive * envelope;
  if (scale <= 0) {
    return FILM_BREATH_ZERO_OFFSETS;
  }
  const seed = normalizeSeed(sourceSeed);
  return {
    exposure: breathNoise(timeSeconds, seed, 1327217884) * FILM_BREATH_LIMITS.exposure * scale,
    contrast: breathNoise(timeSeconds, seed, 2653711215) * FILM_BREATH_LIMITS.contrast * scale,
    temperature: breathNoise(timeSeconds, seed, 668265263) * FILM_BREATH_LIMITS.temperature * scale,
    tint: breathNoise(timeSeconds, seed, 374761393) * FILM_BREATH_LIMITS.tint * scale
  };
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
  let z6 = b - 0.5;
  const len = Math.hypot(x, y, z6);
  if (len < 1e-9) {
    return [0, 0, 1];
  }
  const inv = 1 / len;
  return [x * inv, y * inv, z6 * inv];
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
  crossFilterEdgeStrengthGain: 0.25,
  haloPrismStrength: 0,
  haloPrismRadius: 0.62,
  haloPrismWidth: 0.22,
  haloPrismChromatic: 0.65,
  haloPrismThreshold: 0.9,
  haloPrismSplit: 0.7,
  haloPrismAngle: 0,
  haloPrismSourceReactivity: 0.85,
  opticalDirectTransmission: 1,
  opticalBlackRetention: 1,
  opticalScatterStrength: 0,
  opticalHighlightReactivity: 0,
  opticalWarmScatter: 0,
  opticalSpectralTail: 0
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
   * Vision3 500T Blue Hour プリセット（v1・2026-05-12）
   * @description タングステン 500T をブルーアワーで暖め戻しきらない方向。深いコバルト中間調、16mm 粒状、抑えた Kodak negative 系ハレーション。
   */
  vision3500t: {
    exposure: -0.04,
    contrast: 1.22,
    saturation: 1.02,
    temperature: -0.4,
    tint: 0.04,
    rgbShift: 15e-4,
    lensSoftness: 0.12,
    detailSoftness: 0.18,
    grainIntensity: 0.1,
    grainRadialMix: 1,
    grainSize: 0.52,
    vignette: 0.36,
    bloomThreshold: 0.72,
    bloomStrength: 0.16,
    bloomRadius: 0.56,
    diffusion: 0.12,
    halationIntensity: 0.06,
    halationSpread: 24,
    halationHue: 16,
    halationThreshold: 0.72,
    halationRadius: 0.44,
    bloomSoftKnee: 0.62,
    halationSoftKnee: 0.42,
    fade: 0.012,
    highlights: -0.12,
    shadows: -0.16,
    shadowTone: 0.18,
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
    highlightTone: 0.12,
    shadowHue: 225,
    highlightHue: 214,
    compressionAmount: 0.34,
    compressionRange: 0.62,
    printContrast: 0.16,
    cyan: 0.06,
    magenta: 0.04,
    yellow: -0.08,
    motionBlurAmount: 0,
    shutterAngle: 0,
    trailIntensity: 0,
    filmBreathAmount: 0,
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
    detailSoftness: 0,
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
    shadowLatitude: 0,
    blackPoint: 0,
    toeContrast: 0,
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
    filmBreathAmount: 0,
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
  { name: "vision3500t", label: "Vision3 500T", subtitle: "Blue Hour", category: "filmStock", printMedium: "tungsten_cinema" },
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
  vision3500t: lookIdForPreset("vision3500t"),
  velvia50: lookIdForPreset("velvia50")
};

// src/schema.ts
import { z } from "zod";
function schemaForParamKey(key) {
  return key === "grainIntensity" ? z.number().min(0).transform(clampGrainIntensity) : key === "grainRadialMix" ? z.number().min(0).max(1).default(1) : key === "grainSize" ? z.number().min(0).max(1).default(0.3) : key === "diffusion" ? z.number().min(0).max(1).default(0) : key === "depthMistGain" || key === "depthGlowGain" ? z.number().min(0).max(1).default(0) : key === "depthRayAngleGamma" ? z.number().min(0.1).max(4).default(1.4) : key === "depthRayAngleInnerThreshold" ? z.number().min(0).max(0.8).default(0.1) : key === "depthMistRayAngleGain" ? z.number().min(0).max(1).default(0.35) : key === "depthBloomRayAngleGain" ? z.number().min(0).max(1).default(0.25) : key === "depthHalationRayAngleGain" ? z.number().min(0).max(1).default(0.18) : key === "depthMistFieldPsfGain" || key === "depthBloomFieldPsfGain" || key === "depthHalationFieldPsfGain" ? z.number().min(0).max(1).default(1) : key === "depthMistFieldPsfRadiusPx" ? z.number().min(0).max(64).default(18) : key === "depthBloomFieldPsfRadiusPx" ? z.number().min(0).max(64).default(9) : key === "depthHalationFieldPsfRadiusPx" ? z.number().min(0).max(64).default(12) : key === "lensSoftness" ? z.number().min(0).max(1).default(0) : key === "detailSoftness" || key === "shadowLatitude" ? z.number().min(0).max(1).default(0) : key === "blackPoint" ? z.number().min(-1).max(1).default(0) : key === "toeContrast" ? z.number().min(0).max(1).default(0) : key === "opticalDirectTransmission" ? z.number().min(0).max(1).default(1) : key === "opticalBlackRetention" ? z.number().min(0).max(1).default(1) : key === "opticalScatterStrength" || key === "opticalHighlightReactivity" || key === "opticalWarmScatter" || key === "opticalSpectralTail" ? z.number().min(0).max(1).default(0) : key === "compressionRange" ? z.number().min(0).max(1).default(0.5) : key === "compressionAmount" || key === "printContrast" ? z.number().min(0).max(1).default(0) : key === "cyan" || key === "magenta" || key === "yellow" ? z.number().min(-1).max(1).default(0) : key === "shutterAngle" ? z.number().min(0).max(720).default(0) : key === "trailIntensity" ? z.number().min(0).max(0.95).default(0) : key === "filmBreathAmount" || key === "motionBlurAmount" || key === "dustAmount" || key === "scratchAmount" ? z.number().min(0).max(1).default(0) : key === "shaftIntensity" ? z.number().min(0).max(1).default(0) : key === "shaftDecay" ? z.number().min(0).max(1).default(0.5) : key === "shaftOriginX" ? z.number().min(0).max(1).default(0.5) : key === "shaftOriginY" ? z.number().min(0).max(1).default(0.15) : key === "crossFilterStrength" ? z.number().min(0).max(1).default(0) : key === "crossFilterSpikes" ? z.number().min(4).max(8).default(4) : key === "crossFilterAngle" ? z.number().min(0).max(360).default(0) : key === "crossFilterLength" ? z.number().min(0).max(1).default(0.4) : key === "crossFilterThreshold" ? z.number().min(0).max(1).default(0.92) : key === "crossFilterChromatic" ? z.number().min(0).max(1).default(0.3) : key === "crossFilterSizeLimit" ? z.number().min(0).max(1).default(0) : key === "crossFilterRandomness" ? z.number().min(0).max(1).default(1) : key === "crossFilterHardMode" ? z.number().min(0).max(1).default(1) : key === "crossFilterMinSpacing" ? z.number().min(0).max(2).default(1) : key === "crossFilterDepthGain" ? z.number().min(0).max(1).default(0.25) : key === "crossFilterAngleGain" ? z.number().min(0).max(1).default(0.35) : key === "crossFilterAngleGamma" ? z.number().min(0.1).max(4).default(1.4) : key === "crossFilterAngleInnerThreshold" ? z.number().min(0).max(0.8).default(0.1) : key === "crossFilterEdgeLengthGain" ? z.number().min(0).max(1).default(0.45) : key === "crossFilterEdgeStrengthGain" ? z.number().min(0).max(1).default(0.25) : key === "haloPrismStrength" ? z.number().min(0).max(1).default(0) : key === "haloPrismRadius" ? z.number().min(0).max(1).default(0.62) : key === "haloPrismWidth" ? z.number().min(0).max(1).default(0.22) : key === "haloPrismChromatic" ? z.number().min(0).max(1).default(0.65) : key === "haloPrismThreshold" ? z.number().min(0).max(1).default(0.9) : key === "haloPrismSplit" ? z.number().min(0).max(1).default(0.7) : key === "haloPrismAngle" ? z.number().min(0).max(360).default(0) : key === "haloPrismSourceReactivity" ? z.number().min(0).max(1).default(0.85) : z.number();
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
    contrast: -0.08
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
    contrast: -0.08
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
    case "detailSoftness":
    case "shadowLatitude":
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
  "detailSoftness",
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
  "shutterAngle",
  "trailIntensity",
  "filmBreathAmount",
  "fade",
  "shadowTone",
  "shadowLatitude",
  "blackPoint",
  "toeContrast",
  "highlightTone",
  "shadowHue",
  "highlightHue",
  "vignette",
  "grainIntensity"
];
var PHASE0_MAX_SOURCE_DURATION_SEC = 60 * 5;
var PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 4096;
var PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES = 8 * 1024 * 1024 * 1024;
var PHASE0_OUTPUT_PROFILE = {
  longEdge: 1920,
  fps: 24,
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
  detailSoftness: z3.number().min(0).max(1).default(PRESETS.reset.detailSoftness),
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
  shutterAngle: z3.number().min(0).max(720).default(PRESETS.reset.shutterAngle),
  trailIntensity: z3.number().min(0).max(0.95).default(PRESETS.reset.trailIntensity),
  filmBreathAmount: z3.number().min(0).max(1).default(PRESETS.reset.filmBreathAmount),
  fade: z3.number().min(0).max(1).default(PRESETS.reset.fade),
  shadowTone: z3.number().min(0).max(1).default(PRESETS.reset.shadowTone),
  shadowLatitude: z3.number().min(0).max(1).default(PRESETS.reset.shadowLatitude),
  blackPoint: z3.number().min(-1).max(1).default(PRESETS.reset.blackPoint),
  toeContrast: z3.number().min(0).max(1).default(PRESETS.reset.toeContrast),
  highlightTone: z3.number().min(0).max(1).default(PRESETS.reset.highlightTone),
  shadowHue: z3.number().min(0).max(360).default(PRESETS.reset.shadowHue),
  highlightHue: z3.number().min(0).max(360).default(PRESETS.reset.highlightHue),
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
  detailSoftness: z3.number().min(0).max(1).optional(),
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
  shutterAngle: z3.number().min(0).max(720).optional(),
  trailIntensity: z3.number().min(0).max(0.95).optional(),
  filmBreathAmount: z3.number().min(0).max(1).optional(),
  fade: z3.number().min(0).max(1).optional(),
  shadowTone: z3.number().min(0).max(1).optional(),
  shadowLatitude: z3.number().min(0).max(1).optional(),
  blackPoint: z3.number().min(-1).max(1).optional(),
  toeContrast: z3.number().min(0).max(1).optional(),
  highlightTone: z3.number().min(0).max(1).optional(),
  shadowHue: z3.number().min(0).max(360).optional(),
  highlightHue: z3.number().min(0).max(360).optional(),
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
  const out = {
    title: options?.title ?? lut.title ?? "Custom LUT",
    size: lut.size,
    data: Array.from(lut.data),
    intensity: options?.intensity ?? 1
  };
  if (options?.bundledSlug !== void 0) {
    out.bundledSlug = options.bundledSlug;
  }
  if (options?.bundledPackId !== void 0) {
    out.bundledPackId = options.bundledPackId;
  }
  return out;
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
  const toTransportLut = (lut) => {
    if (!lut) return null;
    const out = {
      title: lut.title,
      size: lut.size,
      data: lut.data,
      intensity: lut.intensity
    };
    if (lut.bundledSlug !== void 0) {
      out.bundledSlug = lut.bundledSlug;
    }
    if (lut.bundledPackId !== void 0) {
      out.bundledPackId = lut.bundledPackId;
    }
    return out;
  };
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
var MEZZANINE_PROFILE_VARIANTS = /* @__PURE__ */ new Set([
  "sdr",
  "hdr",
  "qualitySDR",
  "qualityHDR"
]);
var ROW_HEADER = "| date | device | iOS | clip_id | input_resolution | output_resolution | realtime_ratio | file_size_mb | thermal | memory_warnings | save | visual | error | duration_sec | mode | mezz_variant |";
var ROW_DIVIDER = "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |";
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
    durationSec: typeof benchmark.sourceDurationSec === "number" ? benchmark.sourceDurationSec : null,
    renderMode: benchmark.renderMode ?? "quality",
    mezzanineProfileVariant: benchmark.mezzanineProfileVariant ?? null
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
    `mode=${row.renderMode}`,
    `mezz=${row.mezzanineProfileVariant ?? "\u2014"}`,
    ""
  ].join(" | ").trim();
}
function benchmarkMarkdownTableHeader() {
  return `${ROW_HEADER}
${ROW_DIVIDER}`;
}
var ROW_PATTERN = /^\|\s*(?<date>[^|]+?)\s*\|\s*(?<device>[^|]+?)\s*\|\s*(?<iosVersion>[^|]+?)\s*\|\s*(?<clipId>[^|]+?)\s*\|\s*(?<inputRes>[^|]+?)\s*\|\s*(?<outputRes>[^|]+?)\s*\|\s*(?<realtime>[^|]+?)\s*\|\s*(?<fileSize>[^|]+?)\s*\|\s*thermal=(?<thermal>[^|]+?)\s*\|\s*mem_warn=(?<mem>[^|]+?)\s*\|\s*save=(?<save>[^|]+?)\s*\|\s*visual=(?<visual>[^|]+?)\s*\|\s*err=(?<err>[^|]+?)\s*\|\s*(?<durationSec>[^|]+?)\s*\|\s*mode=(?<mode>[^|]+?)\s*\|\s*mezz=(?<mezz>[^|]+?)\s*\|\s*$/;
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
  const modeRaw = g.mode.trim();
  const renderMode = modeRaw === "speed" ? "speed" : "quality";
  const mezzRaw = g.mezz.trim();
  const mezzanineProfileVariant = MEZZANINE_PROFILE_VARIANTS.has(
    mezzRaw
  ) ? mezzRaw : null;
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
    durationSec: durationSec != null && Number.isFinite(durationSec) ? durationSec : null,
    renderMode,
    mezzanineProfileVariant
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
  "haloPrismStrength",
  "haloPrismRadius",
  "haloPrismWidth",
  "haloPrismChromatic",
  "haloPrismThreshold",
  "haloPrismSplit",
  "haloPrismAngle",
  "haloPrismSourceReactivity",
  "rgbShift",
  "lensSoftness",
  "opticalDirectTransmission",
  "opticalBlackRetention",
  "opticalScatterStrength",
  "opticalHighlightReactivity",
  "opticalWarmScatter",
  "opticalSpectralTail"
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
function clamp012(value) {
  if (!Number.isFinite(value)) return 0;
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}
function normalizeDescriptor(descriptor) {
  return {
    medianLuma: clamp012(descriptor.medianLuma),
    highlightCoverage: clamp012(descriptor.highlightCoverage),
    specularIslands: clamp012(descriptor.specularIslands),
    pointLightScore: clamp012(descriptor.pointLightScore),
    globalContrast: clamp012(descriptor.globalContrast),
    warmthScore: clamp012(descriptor.warmthScore),
    portraitLikelihood: clamp012(descriptor.portraitLikelihood),
    nightScore: clamp012(descriptor.nightScore),
    sceneComplexity: clamp012(descriptor.sceneComplexity),
    dominantShotCoverage: clamp012(descriptor.dominantShotCoverage),
    sampleCount: typeof descriptor.sampleCount === "number" && descriptor.sampleCount > 0 ? Math.round(descriptor.sampleCount) : void 0
  };
}
function buildScores(descriptor) {
  const glowScore = clamp012(
    descriptor.highlightCoverage * 1.4 + descriptor.specularIslands * 0.22 + descriptor.warmthScore * 0.26 + descriptor.globalContrast * 0.18 + descriptor.pointLightScore * 0.08 + (1 - descriptor.sceneComplexity) * 0.12
  );
  const crossScore = clamp012(
    descriptor.pointLightScore * 0.56 + descriptor.specularIslands * 0.16 + descriptor.nightScore * 0.16 + descriptor.globalContrast * 0.08 + descriptor.sceneComplexity * 0.04
  );
  const mistScore = clamp012(
    descriptor.portraitLikelihood * 0.44 + (1 - descriptor.highlightCoverage) * 0.16 + (1 - descriptor.pointLightScore) * 0.18 + descriptor.medianLuma * 0.08 + descriptor.warmthScore * 0.06 + (1 - descriptor.sceneComplexity) * 0.08
  );
  const lensScore = clamp012(
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

// src/optical-filter-profiles.ts
var OPTICAL_FILTER_PARAM_KEYS = [
  "bloomThreshold",
  "bloomStrength",
  "bloomRadius",
  "diffusion",
  "depthMistGain",
  "depthGlowGain",
  "depthRayAngleGamma",
  "depthRayAngleInnerThreshold",
  "depthMistRayAngleGain",
  "depthBloomRayAngleGain",
  "depthHalationRayAngleGain",
  "depthMistFieldPsfGain",
  "depthBloomFieldPsfGain",
  "depthHalationFieldPsfGain",
  "depthMistFieldPsfRadiusPx",
  "depthBloomFieldPsfRadiusPx",
  "depthHalationFieldPsfRadiusPx",
  "halationIntensity",
  "halationSpread",
  "halationHue",
  "halationThreshold",
  "halationRadius",
  "bloomSoftKnee",
  "halationSoftKnee",
  "rgbShift",
  "lensSoftness",
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
  "crossFilterAngleInnerThreshold",
  "crossFilterEdgeLengthGain",
  "crossFilterEdgeStrengthGain",
  "haloPrismStrength",
  "haloPrismRadius",
  "haloPrismWidth",
  "haloPrismChromatic",
  "haloPrismThreshold",
  "haloPrismSplit",
  "haloPrismAngle",
  "haloPrismSourceReactivity",
  "opticalDirectTransmission",
  "opticalBlackRetention",
  "opticalScatterStrength",
  "opticalHighlightReactivity",
  "opticalWarmScatter",
  "opticalSpectralTail"
];
var OPTICAL_FILTER_BASE_PATCH = Object.fromEntries(
  OPTICAL_FILTER_PARAM_KEYS.map((key) => [key, PRESETS.reset[key]])
);
function behavior(patch) {
  return {
    blackRetention: 1,
    directTransmission: 1,
    scatterStrength: 0,
    scatterCore: 0.35,
    scatterTail: 0.35,
    highlightReactivity: 0,
    warmth: 0,
    spectralTail: 0,
    depthResponse: 0,
    rayAngleResponse: 0,
    fieldPsfScale: 1,
    ...patch
  };
}
var OPTICAL_FILTER_DISCLAIMER = "Inspired by common diffusion-filter families. Not a manufacturer-certified emulation.";
var OPTICAL_FILTER_PROFILES = [
  {
    id: "blackMist-1-8",
    family: "blackMist",
    density: "1/8",
    displayName: "Black Mist 1/8",
    shortLabel: "1/8",
    description: "Controlled highlight bloom with strong black retention.",
    params: {
      bloomThreshold: 0.8,
      bloomStrength: 0.1,
      bloomRadius: 0.42,
      diffusion: 0.06,
      halationIntensity: 0.035,
      halationSpread: 16,
      halationHue: 18,
      halationThreshold: 0.66,
      halationRadius: 0.34,
      bloomSoftKnee: 0.58,
      halationSoftKnee: 0.34,
      lensSoftness: 0.035,
      opticalDirectTransmission: 0.965,
      opticalBlackRetention: 0.92,
      opticalScatterStrength: 0.18,
      opticalHighlightReactivity: 0.42,
      opticalWarmScatter: 0.08,
      opticalSpectralTail: 0.04
    },
    behavior: behavior({
      blackRetention: 0.92,
      directTransmission: 0.965,
      scatterStrength: 0.18,
      scatterCore: 0.42,
      scatterTail: 0.3,
      highlightReactivity: 0.42,
      warmth: 0.08,
      spectralTail: 0.04
    })
  },
  {
    id: "blackMist-1-4",
    family: "blackMist",
    density: "1/4",
    displayName: "Black Mist 1/4",
    shortLabel: "1/4",
    description: "Visible halation and highlight roll with protected shadows.",
    params: {
      bloomThreshold: 0.76,
      bloomStrength: 0.18,
      bloomRadius: 0.52,
      diffusion: 0.1,
      depthMistGain: 0.22,
      depthGlowGain: 0.18,
      depthMistRayAngleGain: 0.42,
      depthBloomRayAngleGain: 0.32,
      depthHalationRayAngleGain: 0.24,
      halationIntensity: 0.07,
      halationSpread: 20,
      halationHue: 20,
      halationThreshold: 0.62,
      halationRadius: 0.42,
      bloomSoftKnee: 0.64,
      halationSoftKnee: 0.42,
      lensSoftness: 0.055,
      opticalDirectTransmission: 0.93,
      opticalBlackRetention: 0.86,
      opticalScatterStrength: 0.34,
      opticalHighlightReactivity: 0.58,
      opticalWarmScatter: 0.12,
      opticalSpectralTail: 0.06
    },
    behavior: behavior({
      blackRetention: 0.86,
      directTransmission: 0.93,
      scatterStrength: 0.34,
      scatterCore: 0.48,
      scatterTail: 0.42,
      highlightReactivity: 0.58,
      warmth: 0.12,
      spectralTail: 0.06,
      depthResponse: 0.2,
      rayAngleResponse: 0.32,
      fieldPsfScale: 1.1
    })
  },
  {
    id: "blackMist-1-2",
    family: "blackMist",
    density: "1/2",
    displayName: "Black Mist 1/2",
    shortLabel: "1/2",
    description: "Dense highlight bloom with a broad low-frequency tail.",
    params: {
      bloomThreshold: 0.7,
      bloomStrength: 0.28,
      bloomRadius: 0.64,
      diffusion: 0.16,
      depthMistGain: 0.32,
      depthGlowGain: 0.28,
      depthMistRayAngleGain: 0.48,
      depthBloomRayAngleGain: 0.38,
      depthHalationRayAngleGain: 0.28,
      depthMistFieldPsfRadiusPx: 22,
      depthBloomFieldPsfRadiusPx: 12,
      depthHalationFieldPsfRadiusPx: 15,
      halationIntensity: 0.12,
      halationSpread: 26,
      halationHue: 21,
      halationThreshold: 0.58,
      halationRadius: 0.54,
      bloomSoftKnee: 0.72,
      halationSoftKnee: 0.5,
      lensSoftness: 0.08,
      opticalDirectTransmission: 0.88,
      opticalBlackRetention: 0.78,
      opticalScatterStrength: 0.52,
      opticalHighlightReactivity: 0.72,
      opticalWarmScatter: 0.16,
      opticalSpectralTail: 0.08
    },
    behavior: behavior({
      blackRetention: 0.78,
      directTransmission: 0.88,
      scatterStrength: 0.52,
      scatterCore: 0.52,
      scatterTail: 0.58,
      highlightReactivity: 0.72,
      warmth: 0.16,
      spectralTail: 0.08,
      depthResponse: 0.3,
      rayAngleResponse: 0.4,
      fieldPsfScale: 1.25
    })
  },
  {
    id: "cineBloom-5",
    family: "cineBloom",
    density: "5%",
    displayName: "Cine Bloom 5%",
    shortLabel: "5%",
    description: "Soft digital-edge bloom with a clean haze floor.",
    params: {
      bloomThreshold: 0.78,
      bloomStrength: 0.14,
      bloomRadius: 0.5,
      diffusion: 0.08,
      halationIntensity: 0.03,
      halationSpread: 16,
      halationHue: 16,
      halationRadius: 0.34,
      bloomSoftKnee: 0.62,
      lensSoftness: 0.045
    },
    behavior: behavior({ scatterTail: 0.44, highlightReactivity: 0.28 })
  },
  {
    id: "cineBloom-10",
    family: "cineBloom",
    density: "10%",
    displayName: "Cine Bloom 10%",
    shortLabel: "10%",
    description: "Dreamier broad bloom for practicals and skin.",
    params: {
      bloomThreshold: 0.72,
      bloomStrength: 0.24,
      bloomRadius: 0.62,
      diffusion: 0.13,
      halationIntensity: 0.06,
      halationSpread: 22,
      halationHue: 18,
      halationRadius: 0.46,
      bloomSoftKnee: 0.7,
      halationSoftKnee: 0.4,
      lensSoftness: 0.065
    },
    behavior: behavior({ scatterTail: 0.6, highlightReactivity: 0.38 })
  },
  {
    id: "cineBloom-20",
    family: "cineBloom",
    density: "20%",
    displayName: "Cine Bloom 20%",
    shortLabel: "20%",
    description: "Heavy broad glow for an intentionally dreamy finish.",
    params: {
      bloomThreshold: 0.64,
      bloomStrength: 0.42,
      bloomRadius: 0.74,
      diffusion: 0.22,
      halationIntensity: 0.1,
      halationSpread: 28,
      halationHue: 18,
      halationRadius: 0.6,
      bloomSoftKnee: 0.78,
      halationSoftKnee: 0.48,
      lensSoftness: 0.1
    },
    behavior: behavior({ scatterTail: 0.78, highlightReactivity: 0.5 })
  },
  {
    id: "warmMist-1-8",
    family: "warmMist",
    density: "1/8",
    displayName: "Warm Mist 1/8",
    shortLabel: "1/8",
    description: "Warm practical-light bloom with restrained softness.",
    params: {
      bloomThreshold: 0.76,
      bloomStrength: 0.16,
      bloomRadius: 0.48,
      diffusion: 0.07,
      halationIntensity: 0.08,
      halationSpread: 20,
      halationHue: 28,
      halationThreshold: 0.6,
      halationRadius: 0.4,
      bloomSoftKnee: 0.62,
      halationSoftKnee: 0.42,
      lensSoftness: 0.04,
      opticalWarmScatter: 0.18,
      opticalSpectralTail: 0.04
    },
    behavior: behavior({ warmth: 0.18, spectralTail: 0.04, highlightReactivity: 0.35 })
  },
  {
    id: "warmMist-1-4",
    family: "warmMist",
    density: "1/4",
    displayName: "Warm Mist 1/4",
    shortLabel: "1/4",
    description: "Tasteful amber halation for night ambience.",
    params: {
      bloomThreshold: 0.7,
      bloomStrength: 0.24,
      bloomRadius: 0.58,
      diffusion: 0.11,
      depthGlowGain: 0.16,
      halationIntensity: 0.14,
      halationSpread: 26,
      halationHue: 30,
      halationThreshold: 0.56,
      halationRadius: 0.5,
      bloomSoftKnee: 0.68,
      halationSoftKnee: 0.5,
      lensSoftness: 0.06,
      opticalWarmScatter: 0.28,
      opticalSpectralTail: 0.06
    },
    behavior: behavior({
      warmth: 0.28,
      spectralTail: 0.06,
      highlightReactivity: 0.45,
      depthResponse: 0.1
    })
  },
  {
    id: "pearlGlow-subtle",
    family: "pearlGlow",
    density: "subtle",
    displayName: "Pearl Glow Subtle",
    shortLabel: "Subtle",
    description: "Polished skin softness with minimal halo.",
    params: {
      bloomThreshold: 0.84,
      bloomStrength: 0.06,
      bloomRadius: 0.34,
      diffusion: 0.045,
      halationIntensity: 0.015,
      halationSpread: 14,
      halationRadius: 0.26,
      bloomSoftKnee: 0.58,
      lensSoftness: 0.055
    },
    behavior: behavior({ scatterCore: 0.45, scatterTail: 0.24 })
  },
  {
    id: "pearlGlow-1-4",
    family: "pearlGlow",
    density: "1/4",
    displayName: "Pearl Glow 1/4",
    shortLabel: "1/4",
    description: "Beauty-forward diffusion with clean highlights.",
    params: {
      bloomThreshold: 0.8,
      bloomStrength: 0.1,
      bloomRadius: 0.42,
      diffusion: 0.085,
      halationIntensity: 0.025,
      halationSpread: 16,
      halationRadius: 0.3,
      bloomSoftKnee: 0.64,
      lensSoftness: 0.08
    },
    behavior: behavior({ scatterCore: 0.5, scatterTail: 0.32 })
  },
  {
    id: "cleanSoft-subtle",
    family: "cleanSoft",
    density: "subtle",
    displayName: "Clean Soft Subtle",
    shortLabel: "Subtle",
    description: "Less clinical sharpness without obvious filter glow.",
    params: {
      bloomThreshold: 0.9,
      bloomStrength: 0.035,
      bloomRadius: 0.28,
      diffusion: 0.02,
      halationIntensity: 0,
      lensSoftness: 0.075,
      rgbShift: 6e-4
    },
    behavior: behavior({ scatterCore: 0.32, scatterTail: 0.16 })
  },
  {
    id: "backlightVeil-1-8",
    family: "backlightVeil",
    density: "1/8",
    displayName: "Backlight Veil 1/8",
    shortLabel: "1/8",
    description: "Subtle source-reactive haze for outdoor backlight while protecting shadows.",
    params: {
      bloomThreshold: 0.66,
      bloomStrength: 0.2,
      bloomRadius: 0.7,
      bloomSoftKnee: 0.7,
      diffusion: 0.12,
      depthMistGain: 0.2,
      depthGlowGain: 0.16,
      depthMistRayAngleGain: 0.34,
      depthBloomRayAngleGain: 0.24,
      depthHalationRayAngleGain: 0.2,
      depthMistFieldPsfGain: 1,
      depthBloomFieldPsfGain: 1,
      depthHalationFieldPsfGain: 1,
      depthMistFieldPsfRadiusPx: 18,
      depthBloomFieldPsfRadiusPx: 10,
      depthHalationFieldPsfRadiusPx: 14,
      halationIntensity: 0.07,
      halationThreshold: 0.58,
      halationRadius: 0.52,
      halationHue: 22,
      halationSoftKnee: 0.48,
      lensSoftness: 0.06,
      rgbShift: 5e-4,
      opticalDirectTransmission: 0.92,
      opticalBlackRetention: 0.78,
      opticalScatterStrength: 0.42,
      opticalHighlightReactivity: 0.62,
      opticalWarmScatter: 0.1,
      opticalSpectralTail: 0.04
    },
    behavior: behavior({
      blackRetention: 0.78,
      directTransmission: 0.92,
      scatterStrength: 0.42,
      scatterCore: 0.42,
      scatterTail: 0.5,
      highlightReactivity: 0.62,
      warmth: 0.1,
      spectralTail: 0.04,
      depthResponse: 0.32,
      rayAngleResponse: 0.32,
      fieldPsfScale: 1
    })
  },
  {
    id: "backlightVeil-1-4",
    family: "backlightVeil",
    density: "1/4",
    displayName: "Backlight Veil 1/4",
    shortLabel: "1/4",
    description: "Mid-strength veil for window and sun backlight with stable shadow retention.",
    params: {
      bloomThreshold: 0.56,
      bloomStrength: 0.38,
      bloomRadius: 0.8,
      bloomSoftKnee: 0.76,
      diffusion: 0.24,
      depthMistGain: 0.34,
      depthGlowGain: 0.27,
      depthMistRayAngleGain: 0.5,
      depthBloomRayAngleGain: 0.38,
      depthHalationRayAngleGain: 0.3,
      depthMistFieldPsfGain: 1.06,
      depthBloomFieldPsfGain: 1.04,
      depthHalationFieldPsfGain: 1.03,
      depthMistFieldPsfRadiusPx: 25,
      depthBloomFieldPsfRadiusPx: 14,
      depthHalationFieldPsfRadiusPx: 18,
      halationIntensity: 0.14,
      halationThreshold: 0.52,
      halationRadius: 0.62,
      halationHue: 22,
      halationSoftKnee: 0.56,
      lensSoftness: 0.08,
      rgbShift: 7e-4,
      opticalDirectTransmission: 0.81,
      opticalBlackRetention: 0.56,
      opticalScatterStrength: 0.66,
      opticalHighlightReactivity: 0.78,
      opticalWarmScatter: 0.17,
      opticalSpectralTail: 0.07
    },
    behavior: behavior({
      blackRetention: 0.56,
      directTransmission: 0.81,
      scatterStrength: 0.66,
      scatterCore: 0.56,
      scatterTail: 0.68,
      highlightReactivity: 0.78,
      warmth: 0.17,
      spectralTail: 0.07,
      depthResponse: 0.5,
      rayAngleResponse: 0.5,
      fieldPsfScale: 1.05
    })
  },
  {
    id: "backlightVeil-1-2",
    family: "backlightVeil",
    density: "1/2",
    displayName: "Backlight Veil 1/2",
    shortLabel: "1/2",
    description: "Strong but stable veiling glare for window and sun backlight.",
    params: {
      bloomThreshold: 0.5,
      bloomStrength: 0.6,
      bloomRadius: 0.88,
      bloomSoftKnee: 0.82,
      diffusion: 0.38,
      depthMistGain: 0.5,
      depthGlowGain: 0.4,
      depthMistRayAngleGain: 0.66,
      depthBloomRayAngleGain: 0.52,
      depthHalationRayAngleGain: 0.4,
      depthMistFieldPsfGain: 1.12,
      depthBloomFieldPsfGain: 1.08,
      depthHalationFieldPsfGain: 1.06,
      depthMistFieldPsfRadiusPx: 32,
      depthBloomFieldPsfRadiusPx: 18,
      depthHalationFieldPsfRadiusPx: 22,
      halationIntensity: 0.22,
      halationThreshold: 0.46,
      halationRadius: 0.74,
      halationHue: 22,
      halationSoftKnee: 0.64,
      lensSoftness: 0.1,
      rgbShift: 9e-4,
      opticalDirectTransmission: 0.7,
      opticalBlackRetention: 0.36,
      opticalScatterStrength: 0.9,
      opticalHighlightReactivity: 0.95,
      opticalWarmScatter: 0.24,
      opticalSpectralTail: 0.1
    },
    behavior: behavior({
      blackRetention: 0.36,
      directTransmission: 0.7,
      scatterStrength: 0.9,
      scatterCore: 0.7,
      scatterTail: 0.86,
      highlightReactivity: 0.95,
      warmth: 0.24,
      spectralTail: 0.1,
      depthResponse: 0.66,
      rayAngleResponse: 0.66,
      fieldPsfScale: 1.1
    })
  }
];
function getOpticalFilterProfile(id) {
  return OPTICAL_FILTER_PROFILES.find((profile) => profile.id === id) ?? null;
}
function buildOpticalFilterParamPatch(id) {
  const profile = getOpticalFilterProfile(id);
  if (!profile) {
    throw new Error(`Unknown optical filter profile: ${id}`);
  }
  return {
    ...OPTICAL_FILTER_BASE_PATCH,
    ...profile.params
  };
}

// src/ios-phase0.ts
import { z as z4 } from "zod";

// src/ios-preset-overrides.ts
var FILMTONE_IOS_PRESET_NAMES = [
  "reset",
  "iphone",
  "softBlue",
  "amberGlow"
];

// src/ios-phase0.ts
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
var IOS_PHASE0_CODEC_FAMILIES = [
  "h264",
  "hevc",
  "prores-422",
  "prores-4444",
  "prores-raw",
  "other",
  "unknown"
];
var IOS_PHASE0_LOG_TRANSFER_FUNCTIONS = [
  "apple-log",
  "apple-log2"
];
var IOS_PHASE0_INPUT_TRANSFORM_STRATEGIES = [
  "none",
  "apple-log-to-rec709",
  "apple-log2-to-rec709",
  "core-image-tone-map-sdr",
  "defer-visible-warning",
  "unsupported"
];
var iosPhase0CodecFamilySchema = z4.enum(IOS_PHASE0_CODEC_FAMILIES);
var iosPhase0LogTransferFunctionSchema = z4.enum(
  IOS_PHASE0_LOG_TRANSFER_FUNCTIONS
);
var iosPhase0InputTransformStrategySchema = z4.enum(
  IOS_PHASE0_INPUT_TRANSFORM_STRATEGIES
);
var iosPhase0InputTransformPolicySchema = z4.object({
  strategy: iosPhase0InputTransformStrategySchema,
  reason: z4.string().min(1),
  requiresFixtureValidation: z4.boolean(),
  warning: z4.string().nullable().optional()
});
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
  }),
  // v1.4 Creative LUT Pack 01: optional provenance fields. Pre-v1.4
  // payloads omit them; the V1 bridge contract treats unknown keys as
  // ignored, so adding optional fields stays back-compat.
  bundledSlug: z4.string().min(1).optional(),
  bundledPackId: z4.string().min(1).optional()
});
function createIosPhase0SerializableLut(input) {
  const { cube, name, intensity = 1, bundledSlug, bundledPackId } = input;
  return iosPhase0SerializableLutSchema.parse({
    name,
    title: cube.title || void 0,
    size: cube.size,
    intensity,
    domainMin: cube.domainMin,
    domainMax: cube.domainMax,
    rgbaData: Array.from(cube.data),
    bundledSlug,
    bundledPackId
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
  codecFamily: iosPhase0CodecFamilySchema.optional(),
  logTransferFunction: iosPhase0LogTransferFunctionSchema.optional(),
  inputTransformPolicy: iosPhase0InputTransformPolicySchema.optional(),
  audioCodec: z4.string().min(1).optional(),
  frameRate: z4.number().positive().optional(),
  hasAudio: z4.boolean().optional()
});
var IOS_PHASE0_PRESET_IDS = FILMTONE_IOS_PRESET_NAMES;
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
  return violations;
}

// src/film-compression-v3.ts
var FILM_COMPRESSION_V3_CONSTANTS = {
  lumaKMin: 2.85,
  lumaKMax: 5.15,
  rangeSoftStart: 0.82,
  rangeSoftEnd: 1,
  rangeAmountTrim: 0.18,
  chromaCompressionMax: 0.42,
  problemColorGuardMax: 0.22,
  shadowReleaseStart: 0.14,
  shadowReleaseEnd: 0.3,
  highlightKneeStartLowRange: 0.62,
  highlightKneeStartHighRange: 0.42,
  highlightKneeEndLowRange: 0.96,
  highlightKneeEndHighRange: 0.78,
  chromaStressStart: 0.16,
  chromaStressEnd: 0.7,
  gamutStressStart: 0.82,
  gamutStressEnd: 1.08,
  warmProtectStrength: 0.35,
  highlightDensityLandingStart: 0.78,
  highlightDensityLandingStrength: 0.88,
  highlightDensityLandingChromaStart: 0.18,
  highlightDensityLandingChromaEnd: 0.62,
  highlightDensityLandingWarmProtect: 0.35
};
function clamp013(x) {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}
function clampRange(x, lo, hi) {
  if (x < lo) return lo;
  if (x > hi) return hi;
  return x;
}
function mix(a, b, t) {
  return a + (b - a) * t;
}
function smoothstep2(edge0, edge1, x) {
  const t = clamp013((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}
function filmCompressionLuma(rgb) {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}
function filmCompressionChromaMagnitude(rgb) {
  const y = filmCompressionLuma(rgb);
  const cr = rgb.r - y;
  const cg = rgb.g - y;
  const cb = rgb.b - y;
  return Math.sqrt(cr * cr + cg * cg + cb * cb);
}
function max3(a, b, c) {
  return Math.max(a, Math.max(b, c));
}
function min3(a, b, c) {
  return Math.min(a, Math.min(b, c));
}
function warmHueProtect(cr, cg, cb, mag) {
  if (mag <= 1e-6) {
    return 0;
  }
  const dr = cr / mag;
  const dg = cg / mag;
  const db = cb / mag;
  const redWarm = smoothstep2(0.32, 0.72, dr);
  const blueOpposed = 1 - smoothstep2(-0.58, -0.2, db);
  const greenModerate = 1 - smoothstep2(0.18, 0.58, Math.abs(dg));
  return clamp013(redWarm * blueOpposed * greenModerate);
}
function applyFilmCompressionV3Sample(rgb, amount, range, options = {}) {
  if (amount < 1e-3) {
    return rgb;
  }
  const c = FILM_COMPRESSION_V3_CONSTANTS;
  const r = clamp013(range);
  const k = mix(c.lumaKMax, c.lumaKMin, r);
  const rangeSoft = smoothstep2(c.rangeSoftStart, c.rangeSoftEnd, r);
  const amt = amount * (1 - c.rangeAmountTrim * rangeSoft);
  const y = filmCompressionLuma(rgb);
  const x = clampRange(k * (y - 0.5), -5.5, 5.5);
  const sigmoid = 1 / (1 + Math.exp(-x));
  const shoulderY = Math.min(y, mix(y, sigmoid, amt));
  const lumaScale = y > 1e-3 ? shoulderY / y : 1;
  const lr = rgb.r * lumaScale;
  const lg = rgb.g * lumaScale;
  const lb = rgb.b * lumaScale;
  const cr = lr - shoulderY;
  const cg = lg - shoulderY;
  const cb = lb - shoulderY;
  const chromaMag = Math.sqrt(cr * cr + cg * cg + cb * cb);
  const shadowRelease = smoothstep2(
    c.shadowReleaseStart,
    c.shadowReleaseEnd,
    shoulderY
  );
  const kneeStart = mix(
    c.highlightKneeStartLowRange,
    c.highlightKneeStartHighRange,
    r
  );
  const kneeEnd = mix(
    c.highlightKneeEndLowRange,
    c.highlightKneeEndHighRange,
    r
  );
  const highlightMask = smoothstep2(kneeStart, kneeEnd, shoulderY);
  const chromaStress = smoothstep2(
    c.chromaStressStart,
    c.chromaStressEnd,
    chromaMag
  );
  const maxChannel = max3(lr, lg, lb);
  const minChannel = min3(lr, lg, lb);
  const highEdgeStress = smoothstep2(
    c.gamutStressStart,
    c.gamutStressEnd,
    maxChannel
  );
  const lowEdgeStress = smoothstep2(
    c.gamutStressStart,
    c.gamutStressEnd,
    -minChannel
  );
  const gamutStress = Math.max(highEdgeStress, lowEdgeStress) * chromaStress * smoothstep2(0.08, 0.24, shoulderY);
  const warmProtect = warmHueProtect(cr, cg, cb, chromaMag);
  const highlightCompression = c.chromaCompressionMax * highlightMask * shadowRelease * mix(0.55, 1, chromaStress);
  const guardCompression = c.problemColorGuardMax * gamutStress * shadowRelease;
  const protectedCompression = (highlightCompression + guardCompression) * (1 - c.warmProtectStrength * warmProtect);
  const chromaScale = clamp013(1 - amt * protectedCompression);
  const landedCr = cr * chromaScale;
  const landedCg = cg * chromaScale;
  const landedCb = cb * chromaScale;
  const out = {
    r: shoulderY + landedCr,
    g: shoulderY + landedCg,
    b: shoulderY + landedCb
  };
  const outMax = max3(out.r, out.g, out.b);
  const landingChroma = smoothstep2(
    c.highlightDensityLandingChromaStart,
    c.highlightDensityLandingChromaEnd,
    chromaMag
  );
  const landingMask = smoothstep2(c.highlightDensityLandingStart, 0.98, outMax) * landingChroma * shadowRelease * (1 - c.highlightDensityLandingWarmProtect * warmProtect);
  if (outMax > c.highlightDensityLandingStart && outMax > shoulderY + 1e-6) {
    const over = outMax - c.highlightDensityLandingStart;
    const headroom = 1 - c.highlightDensityLandingStart;
    const softMax = c.highlightDensityLandingStart + headroom * over / (over + headroom);
    const landingScale = clamp013((softMax - shoulderY) / (outMax - shoulderY));
    const landingBlend = clamp013(
      amt * c.highlightDensityLandingStrength * landingMask
    );
    const finalScale = mix(1, landingScale, landingBlend);
    out.r = shoulderY + landedCr * finalScale;
    out.g = shoulderY + landedCg * finalScale;
    out.b = shoulderY + landedCb * finalScale;
  }
  if (options.clampOutput) {
    return {
      r: clamp013(out.r),
      g: clamp013(out.g),
      b: clamp013(out.b)
    };
  }
  return out;
}

// src/bake-color-only.ts
function mix2(a, b, t) {
  return a + (b - a) * t;
}
function clamp014(x) {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}
function smoothstep3(edge0, edge1, x) {
  const t = clamp014((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}
function clampedRGB(rgb) {
  return { r: clamp014(rgb.r), g: clamp014(rgb.g), b: clamp014(rgb.b) };
}
var BAKE_COLOR_PARAM_KEYS = [
  "exposure",
  "contrast",
  "saturation",
  "temperature",
  "tint",
  "toeContrast",
  "blackPoint",
  "fade",
  "compressionAmount",
  "compressionRange",
  "printContrast",
  "cyan",
  "magenta",
  "yellow"
];
var BAKE_COLOR_IDENTITY = {
  exposure: 0,
  contrast: 1,
  saturation: 1,
  temperature: 0,
  tint: 0,
  toeContrast: 0,
  blackPoint: 0,
  fade: 0,
  compressionAmount: 0,
  compressionRange: 0.5,
  printContrast: 0,
  cyan: 0,
  magenta: 0,
  yellow: 0
};
function pickBakeColorParams(params) {
  return {
    exposure: params.exposure,
    contrast: params.contrast,
    saturation: params.saturation,
    temperature: params.temperature,
    tint: params.tint,
    toeContrast: params.toeContrast,
    blackPoint: params.blackPoint,
    fade: params.fade,
    compressionAmount: params.compressionAmount,
    compressionRange: params.compressionRange,
    printContrast: params.printContrast,
    cyan: params.cyan,
    magenta: params.magenta,
    yellow: params.yellow
  };
}
function applyBaseGrade(rgb, params) {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;
  const exposureScale = Math.pow(2, params.exposure);
  r *= exposureScale;
  g *= exposureScale;
  b *= exposureScale;
  r = (r - 0.5) * params.contrast + 0.5;
  g = (g - 0.5) * params.contrast + 0.5;
  b = (b - 0.5) * params.contrast + 0.5;
  const lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  r = mix2(lum, r, params.saturation);
  g = mix2(lum, g, params.saturation);
  b = mix2(lum, b, params.saturation);
  r += params.temperature * 0.1;
  b -= params.temperature * 0.1;
  r += params.tint * 0.05;
  g -= params.tint * 0.08;
  b += params.tint * 0.05;
  const lumaTB = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  if (params.toeContrast > 1e-4) {
    const toeMaskAmt = (1 - smoothstep3(0, 0.15, lumaTB)) * params.toeContrast;
    if (toeMaskAmt > 0) {
      const exponent = 1 + toeMaskAmt * 1.5;
      const tR = Math.pow(Math.max(r, 0), exponent);
      const tG = Math.pow(Math.max(g, 0), exponent);
      const tB = Math.pow(Math.max(b, 0), exponent);
      r = mix2(r, tR, toeMaskAmt);
      g = mix2(g, tG, toeMaskAmt);
      b = mix2(b, tB, toeMaskAmt);
    }
  }
  const bpPos = Math.max(params.blackPoint, 0);
  const bpNeg = Math.max(-params.blackPoint, 0);
  if (bpPos > 1e-4) {
    const luma2 = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    const shadowMaskBp = 1 - smoothstep3(0, 0.35, luma2);
    const lift = bpPos * 0.18 * shadowMaskBp;
    r += lift;
    g += lift;
    b += lift;
  }
  if (bpNeg > 1e-4) {
    const f = bpNeg * 0.15;
    const xR = Math.max(r, 0);
    const xG = Math.max(g, 0);
    const xB = Math.max(b, 0);
    r = xR * xR * (1 + f) / (xR + f);
    g = xG * xG * (1 + f) / (xG + f);
    b = xB * xB * (1 + f) / (xB + f);
  }
  r = r + params.fade * (1 - r);
  g = g + params.fade * (1 - g);
  b = b + params.fade * (1 - b);
  return { r, g, b };
}
function applyFilmCompression(rgb, params) {
  return applyFilmCompressionV3Sample(
    rgb,
    params.compressionAmount,
    params.compressionRange,
    { clampOutput: true }
  );
}
function applyPrintStage(rgb, params) {
  let r = rgb.r;
  let g = rgb.g;
  let b = rgb.b;
  const cmyScale = 0.15;
  r -= params.cyan * cmyScale;
  g -= params.magenta * cmyScale;
  b -= params.yellow * cmyScale;
  if (params.printContrast >= 1e-3) {
    const k = mix2(1, 5, params.printContrast);
    const sR = 1 / (1 + Math.exp(-k * (r - 0.5)));
    const sG = 1 / (1 + Math.exp(-k * (g - 0.5)));
    const sB = 1 / (1 + Math.exp(-k * (b - 0.5)));
    r = mix2(r, sR, params.printContrast);
    g = mix2(g, sG, params.printContrast);
    b = mix2(b, sB, params.printContrast);
  }
  return clampedRGB({ r, g, b });
}
function bakeColorOnly(rgb, params) {
  const stage2 = applyBaseGrade(rgb, params);
  const stage3 = applyFilmCompression(stage2, params);
  const stage9 = applyPrintStage(stage3, params);
  return stage9;
}

// src/creative-cube.ts
var CREATIVE_CUBE_DEFAULT_SIZE = 33;
function makeCreativeCube(input) {
  const size = input.size ?? CREATIVE_CUBE_DEFAULT_SIZE;
  if (!Number.isInteger(size) || size < 2) {
    throw new RangeError(`Cube size must be an integer \u2265 2, got ${size}`);
  }
  const transform = input.transform ?? bakeColorOnly;
  const data = new Float32Array(size * size * size * 3);
  const denom = size - 1;
  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const out = transform({ r, g, b }, input.params);
        const idx = (bi * size * size + gi * size + ri) * 3;
        data[idx + 0] = out.r;
        data[idx + 1] = out.g;
        data[idx + 2] = out.b;
      }
    }
  }
  return { size, data };
}
function makeIdentityCube(size = CREATIVE_CUBE_DEFAULT_SIZE) {
  return makeCreativeCube({ params: BAKE_COLOR_IDENTITY, size });
}
function diagonalMaxDelta(cube) {
  const { size, data } = cube;
  const denom = size - 1;
  let max = 0;
  for (let i = 0; i < size; i++) {
    const t = i / denom;
    const idx = (i * size * size + i * size + i) * 3;
    const dr = Math.abs(data[idx + 0] - t);
    const dg = Math.abs(data[idx + 1] - t);
    const db = Math.abs(data[idx + 2] - t);
    if (dr > max) max = dr;
    if (dg > max) max = dg;
    if (db > max) max = db;
  }
  return max;
}

// src/creative-cube-serialize.ts
var DEFAULT_PRECISION = 6;
function formatFloat(value, precision) {
  const cleaned = Object.is(value, -0) ? 0 : value;
  return cleaned.toFixed(precision);
}
function serializeCreativeCubeToText(cube, options) {
  const precision = options.precision ?? DEFAULT_PRECISION;
  const lines = [];
  lines.push(`TITLE "${options.title.replace(/"/g, "")}"`);
  if (options.comments && options.comments.length > 0) {
    for (const comment of options.comments) {
      lines.push(`# ${comment}`);
    }
  }
  lines.push(`LUT_3D_SIZE ${cube.size}`);
  lines.push("DOMAIN_MIN 0.0 0.0 0.0");
  lines.push("DOMAIN_MAX 1.0 1.0 1.0");
  lines.push("");
  const total = cube.size * cube.size * cube.size;
  for (let i = 0; i < total; i++) {
    const idx = i * 3;
    const r = formatFloat(cube.data[idx + 0], precision);
    const g = formatFloat(cube.data[idx + 1], precision);
    const b = formatFloat(cube.data[idx + 2], precision);
    lines.push(`${r} ${g} ${b}`);
  }
  lines.push("");
  return lines.join("\n");
}

// src/imported-grade-look.ts
import { z as z5 } from "zod";
var IMPORTED_GRADE_SCHEMA_ID = "filmtone-imported-grade-v1";
var IMPORTED_GRADE_SCHEMA_VERSION = 1;
var importedGradeControlSlotSchema = z5.enum(["preLut", "postLut"]);
var importedGradeControlSchema = z5.object({
  id: z5.string().min(1),
  slot: importedGradeControlSlotSchema,
  operation: z5.string().min(1),
  paramKey: z5.string().min(1).nullable().default(null),
  label: z5.string().min(1),
  defaultValue: z5.number().finite(),
  min: z5.number().finite(),
  max: z5.number().finite()
}).superRefine((control, ctx) => {
  if (control.min > control.max) {
    ctx.addIssue({
      code: "custom",
      path: ["min"],
      message: "min must be <= max"
    });
  }
  if (control.defaultValue < control.min || control.defaultValue > control.max) {
    ctx.addIssue({
      code: "custom",
      path: ["defaultValue"],
      message: "defaultValue must be inside min/max"
    });
  }
});
var importedGradeBaseLookSchema = z5.discriminatedUnion("kind", [
  z5.object({ kind: z5.literal("none") }),
  z5.object({
    kind: z5.literal("cube"),
    path: z5.string().min(1),
    size: z5.number().int().positive(),
    intensity: z5.number().finite().min(0).max(1).default(1),
    sourceHash: z5.string().min(1).nullable().default(null)
  })
]);
var importedGradeSourceSchema = z5.discriminatedUnion("kind", [
  z5.object({
    kind: z5.literal("davinci-powergrade-package"),
    packagePath: z5.string().min(1).nullable().default(null)
  }),
  z5.object({
    kind: z5.literal("davinci-drx"),
    drxPath: z5.string().min(1).nullable().default(null)
  }),
  z5.object({
    kind: z5.literal("cube-only"),
    packagePath: z5.string().min(1).nullable().default(null)
  })
]);
var drxGraphTripletSchema = z5.object({
  parameterId: z5.number().int().nonnegative(),
  values: z5.array(z5.number().finite()).default([])
});
var drxGraphWheelBlockSchema = z5.object({
  path: z5.array(z5.number().int().nonnegative()),
  floatValues: z5.array(z5.number().finite()).default([])
});
var importedGradeSourceGraphNodeSchema = z5.object({
  index: z5.number().int().nonnegative(),
  protobufPath: z5.array(z5.number().int().nonnegative()).default([]),
  recognizedOps: z5.array(z5.string()).default([]),
  unsupportedPayloadBase64: z5.string().nullable().default(null),
  approximateInnerFieldCount: z5.number().int().nonnegative().default(0)
});
var importedGradeSourceGraphSchema = z5.object({
  format: z5.literal("davinci-drx"),
  decoded: z5.boolean().default(false),
  bodyVersionFlag: z5.number().int().nonnegative().nullable().default(null),
  rawTriplets: z5.array(drxGraphTripletSchema).default([]),
  wheelAdjustmentBlocks: z5.array(drxGraphWheelBlockSchema).default([]),
  nodes: z5.array(importedGradeSourceGraphNodeSchema).default([]),
  approximateNodeCount: z5.number().int().nonnegative().default(0),
  unsupportedNotes: z5.array(z5.string()).default([])
});
var importedGradeLookSchema = z5.object({
  schemaId: z5.literal(IMPORTED_GRADE_SCHEMA_ID),
  schemaVersion: z5.literal(IMPORTED_GRADE_SCHEMA_VERSION),
  id: z5.string().uuid(),
  title: z5.string().min(1),
  source: importedGradeSourceSchema,
  baseLook: importedGradeBaseLookSchema.default({ kind: "none" }),
  preLutControls: z5.array(importedGradeControlSchema).default([]),
  postLutControls: z5.array(importedGradeControlSchema).default([]),
  sourceGraph: importedGradeSourceGraphSchema.nullable().default(null),
  unsupportedMetadata: z5.array(z5.string()).default([])
}).superRefine((look, ctx) => {
  const ids = /* @__PURE__ */ new Set();
  for (const [slot, controls] of [
    ["preLutControls", look.preLutControls],
    ["postLutControls", look.postLutControls]
  ]) {
    for (const control of controls) {
      if (control.slot !== (slot === "preLutControls" ? "preLut" : "postLut")) {
        ctx.addIssue({
          code: "custom",
          path: [slot, control.id, "slot"],
          message: `control is in ${slot} but declares ${control.slot}`
        });
      }
      if (ids.has(control.id)) {
        ctx.addIssue({
          code: "custom",
          path: [slot, control.id],
          message: `duplicate control id ${control.id}`
        });
      }
      ids.add(control.id);
    }
  }
});
function buildImportedGradeLookFromDrxImport(input) {
  return importedGradeLookSchema.parse({
    schemaId: IMPORTED_GRADE_SCHEMA_ID,
    schemaVersion: IMPORTED_GRADE_SCHEMA_VERSION,
    id: input.id,
    title: input.title,
    source: {
      kind: "davinci-drx",
      drxPath: input.drxPath ?? null
    },
    baseLook: { kind: "none" },
    preLutControls: input.preLutControls ?? [],
    postLutControls: [],
    sourceGraph: input.sourceGraph,
    unsupportedMetadata: input.unsupportedMetadata ?? []
  });
}

// src/creative-pack-01-generator.ts
var CREATIVE_PACK_01_STONE_TRANSFORM = "filmtone-stone-dlogm-palermo-display-v2";
var CREATIVE_PACK_01_URBAN_TRANSFORM = "filmtone-urban-palermo-green-density-v1";
function clamp015(x) {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}
function smoothstep4(edge0, edge1, x) {
  const t = clamp015((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}
function luma(r, g, b) {
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}
function mix3(a, b, t) {
  return a + (b - a) * t;
}
function rec709Decode(encoded) {
  const v = clamp015(encoded);
  if (v < 0.081) return v / 4.5;
  return Math.pow((v + 0.099) / 1.099, 1 / 0.45);
}
function inverseFilmtoneSdrShoulder(shouldered) {
  const y = clamp015(shouldered);
  const exposed = y <= 0.18 ? y : 0.9244 * y / (1 - 0.42 * y);
  return exposed / 1.18;
}
function dlogMEncode(linear) {
  const cut = 0.1113510236;
  const linearOffset = 12e-9;
  const linearSlope = 7.5547639793;
  const logA = 1.538947658;
  const logB = -1.8459129538;
  const logC = 0.0165823994;
  const logD = 0.3103580873;
  const linearCut = (cut - linearOffset) / linearSlope;
  const value = Math.max(0, linear);
  if (value <= linearCut) {
    return clamp015(value * linearSlope + linearOffset);
  }
  return clamp015((Math.log10(value * logD + logC) - logB) / logA);
}
function rec709DisplayToDlogMCode(r, g, b) {
  const rr = inverseFilmtoneSdrShoulder(rec709Decode(r));
  const rg = inverseFilmtoneSdrShoulder(rec709Decode(g));
  const rb = inverseFilmtoneSdrShoulder(rec709Decode(b));
  const dR = 0.7134498128 * rr + 0.271008975 * rg + 0.0155412122 * rb;
  const dG = 0.0489651885 * rr + 0.8951909448 * rg + 0.0558438666 * rb;
  const dB = 0.0406336115 * rr + 0.1954332565 * rg + 0.763933132 * rb;
  return [dlogMEncode(dR), dlogMEncode(dG), dlogMEncode(dB)];
}
function sampleCube(sourceCube, r, g, b) {
  const n = sourceCube.size - 1;
  const x = clamp015(r) * n;
  const y = clamp015(g) * n;
  const z6 = clamp015(b) * n;
  const x0 = Math.floor(x);
  const y0 = Math.floor(y);
  const z0 = Math.floor(z6);
  const x1 = Math.min(n, x0 + 1);
  const y1 = Math.min(n, y0 + 1);
  const z1 = Math.min(n, z0 + 1);
  const fx = x - x0;
  const fy = y - y0;
  const fz = z6 - z0;
  let outR = 0;
  let outG = 0;
  let outB = 0;
  for (let dz = 0; dz < 2; dz++) {
    for (let dy = 0; dy < 2; dy++) {
      for (let dx = 0; dx < 2; dx++) {
        const ix = dx ? x1 : x0;
        const iy = dy ? y1 : y0;
        const iz = dz ? z1 : z0;
        const weight = (dx ? fx : 1 - fx) * (dy ? fy : 1 - fy) * (dz ? fz : 1 - fz);
        const index = (iz * sourceCube.size * sourceCube.size + iy * sourceCube.size + ix) * 3;
        outR += sourceCube.data[index + 0] * weight;
        outG += sourceCube.data[index + 1] * weight;
        outB += sourceCube.data[index + 2] * weight;
      }
    }
  }
  return [outR, outG, outB];
}
function protectShadowFloor(input, output) {
  const inputLuma = luma(input[0], input[1], input[2]);
  const outputLuma = luma(output[0], output[1], output[2]);
  if (inputLuma >= 0.26 || outputLuma <= 1e-4) return output;
  const shadowMask = 1 - smoothstep4(0.08, 0.26, inputLuma);
  const maxLift = 4e-3 + inputLuma * (1.05 + 0.18 * (1 - shadowMask));
  if (outputLuma <= maxLift) return output;
  const scale = mix3(1, maxLift / outputLuma, shadowMask);
  return [
    clamp015(output[0] * scale),
    clamp015(output[1] * scale),
    clamp015(output[2] * scale)
  ];
}
function dominantGreenMask(r, g, b, inputLuma) {
  const dominance = g - Math.max(r, b);
  const lumaGate = smoothstep4(0.12, 0.32, inputLuma) * (1 - smoothstep4(0.68, 0.9, inputLuma));
  return smoothstep4(0.035, 0.22, dominance) * lumaGate;
}
function cyanSkyMask(r, g, b, inputLuma) {
  const blueDominance = b - r;
  const cyanBody = Math.min(b - g * 0.72, g - r * 0.58);
  const lumaGate = smoothstep4(0.22, 0.42, inputLuma) * (1 - smoothstep4(0.88, 1, inputLuma));
  return smoothstep4(0.08, 0.36, blueDominance) * smoothstep4(0.06, 0.28, cyanBody) * lumaGate;
}
function warmSkinMask(r, g, b, inputLuma) {
  const warmOrder = smoothstep4(0.035, 0.18, r - g) * smoothstep4(0.025, 0.16, g - b);
  const lumaGate = smoothstep4(0.2, 0.42, inputLuma) * (1 - smoothstep4(0.76, 0.94, inputLuma));
  const saturationGuard = 1 - smoothstep4(0.52, 0.9, Math.max(r, g, b) - Math.min(r, g, b));
  return warmOrder * lumaGate * saturationGuard;
}
function applyStonePalermoSignature(input, output) {
  const inputLuma = luma(input[0], input[1], input[2]);
  const inputChroma = Math.max(input[0], input[1], input[2]) - Math.min(input[0], input[1], input[2]);
  const neutralMask = (1 - smoothstep4(0.025, 0.2, inputChroma)) * smoothstep4(0.12, 0.42, inputLuma) * (1 - smoothstep4(0.88, 1, inputLuma));
  const skinMask = warmSkinMask(input[0], input[1], input[2], inputLuma);
  const skyMask = cyanSkyMask(input[0], input[1], input[2], inputLuma);
  const greenMask = dominantGreenMask(input[0], input[1], input[2], inputLuma);
  let r = output[0];
  let g = output[1];
  let b = output[2];
  r *= 1 + 0.012 * neutralMask;
  g *= 1 + 4e-3 * neutralMask;
  b *= 1 - 0.055 * neutralMask;
  r *= 1 + 0.03 * skinMask;
  g *= 1 - 0.03 * skinMask;
  b *= 1 - 0.235 * skinMask;
  r *= 1 - 0.46 * skyMask;
  g *= 1 + 0.018 * skyMask;
  b *= 1 + 0.03 * skyMask;
  r *= 1 - 0.05 * greenMask;
  g *= 1 - 0.045 * greenMask;
  b *= 1 - 0.02 * greenMask;
  return [clamp015(r), clamp015(g), clamp015(b)];
}
function applyStoneDisplayPalermoTransform(sourceCube) {
  const { size } = sourceCube;
  const data = new Float32Array(sourceCube.data.length);
  const denom = size - 1;
  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const input = [r, g, b];
        const sourceInput = rec709DisplayToDlogMCode(r, g, b);
        const palermo = sampleCube(sourceCube, sourceInput[0], sourceInput[1], sourceInput[2]);
        const signedPalermo = applyStonePalermoSignature(input, palermo);
        const safePalermo = protectShadowFloor(input, signedPalermo);
        const inputLuma = luma(r, g, b);
        const strength = smoothstep4(0.025, 0.12, inputLuma);
        data[idx + 0] = clamp015(mix3(r, safePalermo[0], strength));
        data[idx + 1] = clamp015(mix3(g, safePalermo[1], strength));
        data[idx + 2] = clamp015(mix3(b, safePalermo[2], strength));
      }
    }
  }
  return { size, data };
}
function applyStoneFingerprintTransform(sourceCube) {
  const { size } = sourceCube;
  const data = new Float32Array(sourceCube.data.length);
  const denom = size - 1;
  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const sourceR = sourceCube.data[idx + 0];
        const sourceG = sourceCube.data[idx + 1];
        const sourceB = sourceCube.data[idx + 2];
        const inputLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        const inputChroma = Math.max(r, g, b) - Math.min(r, g, b);
        const neutralWeight = 1 - smoothstep4(0.025, 0.18, inputChroma);
        const shadowWeight = 1 - smoothstep4(0.1, 0.42, inputLuma);
        const midWeight = smoothstep4(0.18, 0.62, inputLuma) * (1 - smoothstep4(0.72, 0.95, inputLuma));
        const highlightProtect = 1 - smoothstep4(0.76, 0.98, inputLuma);
        const cool = neutralWeight * highlightProtect;
        data[idx + 0] = clamp015(sourceR * (1 - 0.012 * cool) - 2e-3 * shadowWeight);
        data[idx + 1] = clamp015(sourceG * (1 + 3e-3 * cool * midWeight));
        data[idx + 2] = clamp015(sourceB * (1 + 0.014 * cool * midWeight));
      }
    }
  }
  return { size, data };
}
function applyUrbanCoolDensityTransform(sourceCube) {
  const { size } = sourceCube;
  const data = new Float32Array(sourceCube.data.length);
  const denom = size - 1;
  for (let bi = 0; bi < size; bi++) {
    const b = bi / denom;
    for (let gi = 0; gi < size; gi++) {
      const g = gi / denom;
      for (let ri = 0; ri < size; ri++) {
        const r = ri / denom;
        const idx = (bi * size * size + gi * size + ri) * 3;
        const sourceR = sourceCube.data[idx + 0];
        const sourceG = sourceCube.data[idx + 1];
        const sourceB = sourceCube.data[idx + 2];
        const inputLuma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        const inputChroma = Math.max(r, g, b) - Math.min(r, g, b);
        const shadowWeight = 1 - smoothstep4(0.05, 0.45, inputLuma);
        const midWeight = smoothstep4(0.18, 0.5, inputLuma) * (1 - smoothstep4(0.65, 0.92, inputLuma));
        const highlightWeight = smoothstep4(0.78, 0.96, inputLuma);
        const neutralMask = 1 - smoothstep4(0.02, 0.22, inputChroma);
        const coolStrength = shadowWeight * 0.12 + midWeight * neutralMask * 0.075;
        const greenCastStrength = midWeight * neutralMask * 0.035;
        const shadowLift = shadowWeight * 0.028;
        const highlightCool = highlightWeight * neutralMask * 8e-3;
        const newR = sourceR * (1 - coolStrength * 1.05 - highlightCool) + shadowLift * 0.7;
        const newG = sourceG * (1 + greenCastStrength) + shadowLift;
        const newB = sourceB * (1 + coolStrength * 1.3 + highlightCool * 0.5) + shadowLift * 1.1;
        data[idx + 0] = clamp015(newR);
        data[idx + 1] = clamp015(newG);
        data[idx + 2] = clamp015(newB);
      }
    }
  }
  return { size, data };
}
function applyCreativePack01SourceTransform(sourceCube, transformName) {
  switch (transformName) {
    case CREATIVE_PACK_01_STONE_TRANSFORM:
      return applyStoneDisplayPalermoTransform(sourceCube);
    case CREATIVE_PACK_01_URBAN_TRANSFORM:
      return applyUrbanCoolDensityTransform(sourceCube);
  }
}

// src/creative-pack-01.ts
var CREATIVE_PACK_01_ID = "creative-pack-01";
var CREATIVE_PACK_01_BAKER_VERSION = "1.5.0-stone-palermo-signature";
var CREATIVE_PACK_01_CUBE_SIZE = 65;
var CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE = "display-rec709-normalized";
function buildLookParamOverrides(spatial) {
  const out = { ...spatial };
  for (const key of BAKE_COLOR_PARAM_KEYS) {
    out[key] = BAKE_COLOR_IDENTITY[key];
  }
  out.shadowTone = 0;
  out.highlightTone = 0;
  return out;
}
var CREATIVE_PACK_01_LOOKS = [
  {
    slug: "filmtone-creative-pack-01-stone",
    englishName: "Stone",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000006",
    expectedProcessSpace: CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
    rec709SafeIntensityCeiling: 0.86,
    basePreset: "reset",
    colorParams: {
      exposure: 0,
      contrast: 1,
      saturation: 1,
      temperature: 0,
      tint: 0,
      toeContrast: 0,
      blackPoint: 0,
      fade: 0,
      compressionAmount: 0,
      compressionRange: 0.5,
      printContrast: 0,
      cyan: 0,
      magenta: 0,
      yellow: 0
    },
    paramOverrides: buildLookParamOverrides({
      rgbShift: 21e-4,
      bloomThreshold: 0.72,
      bloomStrength: 0.135,
      bloomRadius: 0.6,
      halationIntensity: 0.065,
      halationHue: 24,
      diffusion: 0.015,
      lensSoftness: 0.082,
      grainIntensity: 0.013,
      grainSize: 0.16,
      vignette: 0.1
    }),
    strength: 1,
    sourceCubeTransform: CREATIVE_PACK_01_STONE_TRANSFORM
  },
  {
    slug: "filmtone-creative-pack-01-urban",
    englishName: "Urban",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000007",
    expectedProcessSpace: CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
    rec709SafeIntensityCeiling: 0.84,
    basePreset: "reset",
    colorParams: {
      exposure: 0,
      contrast: 1,
      saturation: 1,
      temperature: 0,
      tint: 0,
      toeContrast: 0,
      blackPoint: 0,
      fade: 0,
      compressionAmount: 0,
      compressionRange: 0.5,
      printContrast: 0,
      cyan: 0,
      magenta: 0,
      yellow: 0
    },
    paramOverrides: buildLookParamOverrides({
      rgbShift: 28e-4,
      bloomThreshold: 0.66,
      bloomStrength: 0.18,
      bloomRadius: 0.58,
      halationIntensity: 0.055,
      halationHue: 20,
      diffusion: 0.065,
      lensSoftness: 0.11,
      grainIntensity: 75e-4,
      grainSize: 0.13,
      vignette: 0.075
    }),
    strength: 1,
    sourceCubeTransform: CREATIVE_PACK_01_URBAN_TRANSFORM
  },
  {
    slug: "filmtone-creative-pack-01-noir",
    englishName: "Noir",
    canonicalUUID: "FB1A0001-0000-4000-8000-000000000010",
    expectedProcessSpace: CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
    rec709SafeIntensityCeiling: 0.92,
    basePreset: "reset",
    colorParams: {
      exposure: -0.24,
      contrast: 1.9,
      saturation: 0.012,
      temperature: 0.015,
      tint: -0.055,
      toeContrast: 0,
      blackPoint: 0,
      fade: 0.022,
      compressionAmount: 0.38,
      compressionRange: 0.56,
      printContrast: 0.86,
      cyan: 0.075,
      magenta: -0.052,
      yellow: 0.3
    },
    paramOverrides: buildLookParamOverrides({
      rgbShift: 0,
      bloomThreshold: 0.56,
      bloomStrength: 0.2,
      bloomRadius: 0.64,
      halationIntensity: 0.028,
      halationHue: 36,
      diffusion: 0.13,
      lensSoftness: 0.16,
      grainRadialMix: 0.9,
      grainIntensity: 0.075,
      grainSize: 0.48,
      vignette: 0.16
    }),
    strength: 1
  }
];
function findCreativePack01Look(slug) {
  return CREATIVE_PACK_01_LOOKS.find((look) => look.slug === slug);
}

// src/source-profile-conversion.ts
var SOURCE_PROFILE_CATALOG = [
  {
    id: "built-in:source-profile.rec709",
    displayName: "Rec.709",
    curve: null,
    impl: "nil-profile",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.apple-log",
    displayName: "Apple Log",
    curve: "apple-log",
    impl: "native-policy",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.apple-log-2",
    displayName: "Apple Log 2",
    curve: "apple-log-2",
    impl: "native-policy",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.dji-dlog",
    displayName: "DJI D-Log",
    curve: "dji-dlog",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.dji-dlog-m",
    displayName: "DJI D-Log M",
    curve: "dji-dlog-m",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.canon-clog",
    displayName: "Canon C-Log",
    curve: "canon-clog",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.canon-log3-cinema-gamut",
    displayName: "Canon Log 3 / Cinema Gamut",
    curve: "canon-log3-cinema-gamut",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.panasonic-vlog",
    displayName: "V-Log",
    curve: "panasonic-vlog",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  },
  {
    id: "built-in:source-profile.sony-slog3",
    displayName: "S-Log3",
    curve: "sony-slog3",
    impl: "synthesized",
    builtIn: true,
    immutable: true
  }
];
var CATALOG_BY_ID = new Map(
  SOURCE_PROFILE_CATALOG.map((entry) => [entry.id, entry])
);
function getSourceProfile(id) {
  return CATALOG_BY_ID.get(id) ?? null;
}
var LUT_CACHE = /* @__PURE__ */ new Map();
function buildSourceProfileLut(id, size = 33) {
  const entry = getSourceProfile(id);
  if (!entry) return null;
  if (entry.impl === "nil-profile") return null;
  if (size < 2 || !Number.isInteger(size)) {
    throw new Error(`source-profile cube size must be an integer \u2265 2 (got ${size})`);
  }
  const cacheKey = `${entry.id}|${size}`;
  const cached = LUT_CACHE.get(cacheKey);
  if (cached) {
    return {
      id: entry.id,
      displayName: entry.displayName,
      data: cached,
      size
    };
  }
  const data = generateCubeForEntry(entry, size);
  LUT_CACHE.set(cacheKey, data);
  return {
    id: entry.id,
    displayName: entry.displayName,
    data,
    size
  };
}
function generateCubeForEntry(entry, size) {
  switch (entry.curve) {
    case "apple-log":
      return makeAppleLogToRec709Cube(size, false);
    case "apple-log-2":
      return makeAppleLogToRec709Cube(size, true);
    case "dji-dlog":
      return makeDlogToRec709Cube(size);
    case "dji-dlog-m":
      return makeDlogMToRec709Cube(size);
    case "canon-clog":
      return makeCanonClogToRec709Cube(size);
    case "canon-log3-cinema-gamut":
      return makeCanonLog3CineGamutToRec709Cube(size);
    case "panasonic-vlog":
      return makeVlogToRec709Cube(size);
    case "sony-slog3":
      return makeSlog3ToRec709Cube(size);
    case null:
      throw new Error(`source-profile ${entry.id} has no curve; cannot build a cube`);
    default: {
      const exhaustive = entry.curve;
      throw new Error(`Unhandled source-profile curve: ${String(exhaustive)}`);
    }
  }
}
function clamp016(v) {
  return Math.min(Math.max(v, 0), 1);
}
function filmtoneSdrShoulder(linear) {
  const exposed = Math.max(0, linear * 1.18);
  const shoulder = exposed / (1 + Math.max(exposed - 0.18, 0) * 0.42);
  return clamp016(shoulder);
}
function rec709Encode(linear) {
  const value = clamp016(linear);
  if (value < 0.018) {
    return value * 4.5;
  }
  return 1.099 * Math.pow(value, 0.45) - 0.099;
}
function appleLogDecode(encoded) {
  const r0 = -0.05641088;
  const rt = 0.01;
  const sigma = 47.28711236;
  const beta = 964052e-8;
  const gamma = 0.08550479;
  const delta = 0.69336945;
  const pt = sigma * Math.pow(rt - r0, 2);
  if (encoded >= pt) {
    return Math.pow(2, (encoded - delta) / gamma) - beta;
  }
  if (encoded >= 0) {
    return Math.sqrt(Math.max(encoded / sigma, 0)) + r0;
  }
  return r0;
}
function appleLogPixelToRec709(red, green, blue, rec2020GamutMap) {
  let lr = appleLogDecode(red);
  let lg = appleLogDecode(green);
  let lb = appleLogDecode(blue);
  if (rec2020GamutMap) {
    const mapped = rec2020ToRec709(lr, lg, lb);
    lr = mapped[0];
    lg = mapped[1];
    lb = mapped[2];
  }
  return [
    rec709Encode(filmtoneSdrShoulder(lr)),
    rec709Encode(filmtoneSdrShoulder(lg)),
    rec709Encode(filmtoneSdrShoulder(lb))
  ];
}
function dlogDecode(encoded) {
  if (encoded <= 0.14) {
    return (encoded - 0.0929) / 6.025;
  }
  return (Math.pow(10, 3.89616 * encoded - 2.27752) - 0.0108) / 0.9892;
}
function dgamutToRec709(red, green, blue) {
  return [
    1.6746 * red - 0.5797 * green - 0.0949 * blue,
    -0.0981 * red + 1.334 * green - 0.2359 * blue,
    -0.041 * red - 0.243 * green + 1.284 * blue
  ];
}
function dlogPixelToRec709(red, green, blue) {
  const lr = dlogDecode(red);
  const lg = dlogDecode(green);
  const lb = dlogDecode(blue);
  const m = dgamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2]))
  ];
}
function dlogMDecode(encoded) {
  const cut = 0.1113510236;
  const linearOffset = 12e-9;
  const linearSlope = 7.5547639793;
  const logA = 1.538947658;
  const logB = -1.8459129538;
  const logC = 0.0165823994;
  const logD = 0.3103580873;
  if (encoded <= cut) {
    return (encoded - linearOffset) / linearSlope;
  }
  return (Math.pow(10, logA * encoded + logB) - logC) / logD;
}
function dgamutMToRec709(red, green, blue) {
  return [
    1.4312693292 * red - 0.4338679939 * green + 0.0025986647 * blue,
    -0.0747311522 * red + 1.1578502353 * green - 0.083119083 * blue,
    -0.0570111279 * red - 0.2731296886 * green + 1.3301408164 * blue
  ];
}
function dlogMPixelToRec709(red, green, blue) {
  const lr = dlogMDecode(red);
  const lg = dlogMDecode(green);
  const lb = dlogMDecode(blue);
  const m = dgamutMToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2]))
  ];
}
function canonLogDecode(encoded) {
  const pivot = 0.0730597;
  const scale = 0.529136;
  const gain = 10.1596;
  let linear;
  if (encoded < pivot) {
    linear = -(Math.pow(10, (pivot - encoded) / scale) - 1) / gain;
  } else {
    linear = (Math.pow(10, (encoded - pivot) / scale) - 1) / gain;
  }
  return linear * 0.9;
}
function canonClogPixelToRec709(red, green, blue) {
  const lr = canonLogDecode(red);
  const lg = canonLogDecode(green);
  const lb = canonLogDecode(blue);
  return [
    rec709Encode(filmtoneSdrShoulder(lr)),
    rec709Encode(filmtoneSdrShoulder(lg)),
    rec709Encode(filmtoneSdrShoulder(lb))
  ];
}
function canonLog3Decode(encoded) {
  const lowBreak = 0.097465473;
  const highBreak = 0.15277891;
  const logScale = 0.36726845;
  const logGain = 14.98325;
  const linearSlope = 1.9754798;
  const linearOffset = 0.12512219;
  const lowOffset = 0.12783901;
  const highOffset = 0.12240537;
  let scene;
  if (encoded < lowBreak) {
    scene = -(Math.pow(10, (lowOffset - encoded) / logScale) - 1) / logGain;
  } else if (encoded <= highBreak) {
    scene = (encoded - linearOffset) / linearSlope;
  } else {
    scene = (Math.pow(10, (encoded - highOffset) / logScale) - 1) / logGain;
  }
  return scene * 0.9;
}
function cineGamutToRec709(red, green, blue) {
  return [
    1.92355517 * red - 0.79863353 * green - 0.12508072 * blue,
    -0.20431556 * red + 1.49593305 * green - 0.2915944 * blue,
    -0.02369073 * red - 0.42022784 * green + 1.44415855 * blue
  ];
}
function canonLog3CineGamutPixelToRec709(red, green, blue) {
  const lr = canonLog3Decode(red);
  const lg = canonLog3Decode(green);
  const lb = canonLog3Decode(blue);
  const m = cineGamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2]))
  ];
}
function vlogDecode(encoded) {
  const cut2 = 0.181;
  const b = 873e-5;
  const c = 0.241514;
  const d = 0.598206;
  if (encoded < cut2) {
    return (encoded - 0.125) / 5.6;
  }
  return Math.pow(10, (encoded - d) / c) - b;
}
function vgamutToRec709(red, green, blue) {
  return [
    1.7398 * red - 0.6727 * green - 0.0671 * blue,
    -0.1956 * red + 1.2473 * green - 0.0518 * blue,
    -0.0114 * red - 0.044 * green + 1.0554 * blue
  ];
}
function vlogPixelToRec709(red, green, blue) {
  const lr = vlogDecode(red);
  const lg = vlogDecode(green);
  const lb = vlogDecode(blue);
  const m = vgamutToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2]))
  ];
}
function slog3Decode(encoded) {
  const threshold = 171.2102946929 / 1023;
  if (encoded < threshold) {
    return (encoded * 1023 - 95) * 0.01125 / (171.2102946929 - 95);
  }
  return Math.pow(10, (encoded * 1023 - 420) / 261.5) * (0.18 + 0.01) - 0.01;
}
function sgamut3CineToRec709(red, green, blue) {
  return [
    1.6269 * red - 0.5365 * green - 0.0904 * blue,
    -0.1078 * red + 1.1628 * green - 0.055 * blue,
    -0.014 * red - 0.024 * green + 1.0379 * blue
  ];
}
function slog3PixelToRec709(red, green, blue) {
  const lr = slog3Decode(red);
  const lg = slog3Decode(green);
  const lb = slog3Decode(blue);
  const m = sgamut3CineToRec709(lr, lg, lb);
  return [
    rec709Encode(filmtoneSdrShoulder(m[0])),
    rec709Encode(filmtoneSdrShoulder(m[1])),
    rec709Encode(filmtoneSdrShoulder(m[2]))
  ];
}
function rec2020ToRec709(red, green, blue) {
  return [
    1.6605 * red - 0.5876 * green - 0.0728 * blue,
    -0.1246 * red + 1.1329 * green - 83e-4 * blue,
    -0.0182 * red - 0.1006 * green + 1.1187 * blue
  ];
}
function buildCubeRgba(size, pixel) {
  const denom = size - 1;
  const data = new Float32Array(size * size * size * 4);
  let i = 0;
  for (let bIdx = 0; bIdx < size; bIdx++) {
    const blueIn = bIdx / denom;
    for (let gIdx = 0; gIdx < size; gIdx++) {
      const greenIn = gIdx / denom;
      for (let rIdx = 0; rIdx < size; rIdx++) {
        const redIn = rIdx / denom;
        const out = pixel(redIn, greenIn, blueIn);
        data[i] = out[0];
        data[i + 1] = out[1];
        data[i + 2] = out[2];
        data[i + 3] = 1;
        i += 4;
      }
    }
  }
  return data;
}
function makeAppleLogToRec709Cube(size = 33, rec2020GamutMap = false) {
  return buildCubeRgba(
    size,
    (r, g, b) => appleLogPixelToRec709(r, g, b, rec2020GamutMap)
  );
}
function makeDlogToRec709Cube(size = 33) {
  return buildCubeRgba(size, dlogPixelToRec709);
}
function makeDlogMToRec709Cube(size = 33) {
  return buildCubeRgba(size, dlogMPixelToRec709);
}
function makeCanonClogToRec709Cube(size = 33) {
  return buildCubeRgba(size, canonClogPixelToRec709);
}
function makeCanonLog3CineGamutToRec709Cube(size = 33) {
  return buildCubeRgba(size, canonLog3CineGamutPixelToRec709);
}
function makeVlogToRec709Cube(size = 33) {
  return buildCubeRgba(size, vlogPixelToRec709);
}
function makeSlog3ToRec709Cube(size = 33) {
  return buildCubeRgba(size, slog3PixelToRec709);
}

// src/detail-softness.ts
var DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.65;
var DETAIL_SOFTNESS_KERNEL_RADIUS_MIN = 1;
var DETAIL_SOFTNESS_KERNEL_RADIUS_MAX = 2.5;
var DETAIL_SOFTNESS_RANGE_SIGMA = 0.07;
var DETAIL_SOFTNESS_DETAIL_AMPLITUDE_LO = 0;
var DETAIL_SOFTNESS_DETAIL_AMPLITUDE_HI = 0.05;
var DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE = 0.7;
var DETAIL_SOFTNESS_HIGHLIGHT_BIAS = 1.18;
function deriveDetailSoftnessUniforms(detailSoftness, opts = {}) {
  const bias = opts.sourceDetailBias ?? 0;
  const combined = detailSoftness + bias;
  const effective = Math.max(
    0,
    Math.min(DETAIL_SOFTNESS_EFFECTIVE_MAX, combined)
  );
  const t = effective / DETAIL_SOFTNESS_EFFECTIVE_MAX;
  const kernelRadiusPx = DETAIL_SOFTNESS_KERNEL_RADIUS_MIN + t * (DETAIL_SOFTNESS_KERNEL_RADIUS_MAX - DETAIL_SOFTNESS_KERNEL_RADIUS_MIN);
  return {
    effectiveDetailSoftness: effective,
    kernelRadiusPx,
    rangeSigma: DETAIL_SOFTNESS_RANGE_SIGMA,
    detailAmplitudeLo: DETAIL_SOFTNESS_DETAIL_AMPLITUDE_LO,
    detailAmplitudeHi: DETAIL_SOFTNESS_DETAIL_AMPLITUDE_HI,
    chromaAttenScale: DETAIL_SOFTNESS_CHROMA_ATTEN_SCALE,
    highlightBias: DETAIL_SOFTNESS_HIGHLIGHT_BIAS
  };
}

// src/shadow-latitude.ts
var SHADOW_LATITUDE_CONSTANTS = {
  blackAnchor: 0.025,
  mainBandStart: 0.055,
  mainBandEnd: 0.18,
  releaseEnd: 0.3,
  lumaGainMax: 0.22,
  chromaRetentionMax: 0.08
};
function clamp017(x) {
  if (x < 0) return 0;
  if (x > 1) return 1;
  return x;
}
function smoothstep5(edge0, edge1, x) {
  const t = clamp017((x - edge0) / (edge1 - edge0));
  return t * t * (3 - 2 * t);
}
function shadowLatitudeLuma(rgb) {
  return 0.2126 * rgb.r + 0.7152 * rgb.g + 0.0722 * rgb.b;
}
function applyShadowLatitudeSample(rgb, amount, options = {}) {
  const amt = clamp017(amount);
  if (amt < 1e-3) {
    return rgb;
  }
  const c = SHADOW_LATITUDE_CONSTANTS;
  const y = shadowLatitudeLuma(rgb);
  const blackProtect = smoothstep5(c.blackAnchor, c.mainBandStart, y);
  const release = 1 - smoothstep5(c.mainBandEnd, c.releaseEnd, y);
  const band = blackProtect * release;
  if (band <= 1e-6) {
    return options.clampOutput ? { r: clamp017(rgb.r), g: clamp017(rgb.g), b: clamp017(rgb.b) } : rgb;
  }
  const toeShape = Math.max(0, 1 - y / c.releaseEnd);
  const lumaLift = y * toeShape * c.lumaGainMax * amt * band;
  const outY = y + lumaLift;
  const chromaScale = 1 + c.chromaRetentionMax * amt * band;
  const out = {
    r: outY + (rgb.r - y) * chromaScale,
    g: outY + (rgb.g - y) * chromaScale,
    b: outY + (rgb.b - y) * chromaScale
  };
  return options.clampOutput ? { r: clamp017(out.r), g: clamp017(out.g), b: clamp017(out.b) } : out;
}

// src/source-detail-compensation.ts
var APPLE_LOG_INPUT_STRATEGIES = /* @__PURE__ */ new Set([
  "apple-log-to-rec709",
  "apple-log2-to-rec709"
]);
var APPLE_LOG_SOURCE_PROFILE_IDS = /* @__PURE__ */ new Set([
  "built-in:source-profile.apple-log",
  "built-in:source-profile.apple-log-2"
]);
var DJI_SOURCE_PROFILE_IDS = /* @__PURE__ */ new Set([
  "built-in:source-profile.dji-dlog",
  "built-in:source-profile.dji-dlog-m"
]);
var CANON_LOG_SOURCE_PROFILE_IDS = /* @__PURE__ */ new Set([
  "built-in:source-profile.canon-clog",
  "built-in:source-profile.canon-log3-cinema-gamut"
]);
var PANASONIC_LOG_SOURCE_PROFILE_IDS = /* @__PURE__ */ new Set([
  "built-in:source-profile.panasonic-vlog"
]);
var SONY_LOG_SOURCE_PROFILE_IDS = /* @__PURE__ */ new Set([
  "built-in:source-profile.sony-slog3"
]);
var APPLE_COLOR_CLASSES = /* @__PURE__ */ new Set([
  "apple-log",
  "apple-log2"
]);
var REC709_COLOR_CLASSES = /* @__PURE__ */ new Set(["sdr-bt709"]);
function clampBias(value) {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return Math.min(value, DETAIL_SOFTNESS_EFFECTIVE_MAX);
}
function normalizeMake(make) {
  if (!make) return "";
  return make.trim().toLowerCase();
}
function normalizeModel(model) {
  if (!model) return "";
  return model.trim().toLowerCase();
}
function makeProfile(id, confidence, transferClass, bias, reason) {
  return {
    id,
    confidence,
    transferClass,
    recommendedBias: clampBias(bias),
    effectiveMax: DETAIL_SOFTNESS_EFFECTIVE_MAX,
    reason
  };
}
function resolveSourceDetailCompensation(input = {}) {
  const make = normalizeMake(input.cameraMake);
  const model = normalizeModel(input.cameraModel);
  const profileId = (input.sourceProfileId ?? "").toString();
  const transferStrategy = input.inputTransformPolicy?.strategy ?? null;
  const appleLogTransfer = input.logTransferFunction === "apple-log" || input.logTransferFunction === "apple-log2";
  const appleLogColorClass = input.colorClass ? APPLE_COLOR_CLASSES.has(input.colorClass) : false;
  const appleLogStrategy = transferStrategy ? APPLE_LOG_INPUT_STRATEGIES.has(transferStrategy) : false;
  const appleLogProfile = APPLE_LOG_SOURCE_PROFILE_IDS.has(profileId);
  if (appleLogTransfer || appleLogColorClass || appleLogStrategy || appleLogProfile) {
    const matchedSignals = Number(appleLogTransfer) + Number(appleLogColorClass) + Number(appleLogStrategy) + Number(appleLogProfile);
    const confidence = matchedSignals >= 2 ? "high" : "medium";
    return makeProfile(
      "apple-log",
      confidence,
      "log-consumer",
      0.06,
      "apple-log-smaller-positive"
    );
  }
  if (SONY_LOG_SOURCE_PROFILE_IDS.has(profileId) || make === "sony") {
    return makeProfile(
      "sony-slog3",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "sony-log-near-zero"
    );
  }
  if (CANON_LOG_SOURCE_PROFILE_IDS.has(profileId) || make === "canon") {
    return makeProfile(
      "canon-clog",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "canon-log-near-zero"
    );
  }
  if (PANASONIC_LOG_SOURCE_PROFILE_IDS.has(profileId) || make === "panasonic") {
    return makeProfile(
      "panasonic-vlog",
      profileId ? "high" : "medium",
      "log-cinema",
      0.02,
      "panasonic-log-near-zero"
    );
  }
  if (DJI_SOURCE_PROFILE_IDS.has(profileId) || make === "dji") {
    return makeProfile(
      "dji-action",
      profileId ? "high" : "medium",
      "rec709-consumer",
      0.08,
      "dji-action-positive"
    );
  }
  if (make === "gopro") {
    return makeProfile(
      "gopro-action",
      "medium",
      "rec709-consumer",
      0.08,
      "gopro-action-positive"
    );
  }
  if (make === "apple" || model.startsWith("iphone")) {
    const codec = input.codecFamily ?? null;
    const isProRes = codec === "prores-422" || codec === "prores-4444";
    const isHevc = codec === "hevc";
    const reasonCodec = isProRes ? "iphone-prores" : isHevc ? "iphone-hevc" : "iphone-sdr";
    return makeProfile(
      "iphone-sdr-hevc",
      "high",
      "rec709-consumer",
      0.1,
      `${reasonCodec}-modest-positive`
    );
  }
  if (input.logTransferFunction != null || transferStrategy != null && transferStrategy !== "none") {
    return makeProfile(
      "log-unknown",
      "low",
      "unknown",
      0,
      "unknown-log-zero"
    );
  }
  if (profileId === "built-in:source-profile.rec709" || (input.colorClass ? REC709_COLOR_CLASSES.has(input.colorClass) : false) || input.codecFamily != null) {
    return makeProfile(
      "rec709-unknown",
      "low",
      "rec709-consumer",
      0.02,
      "unknown-rec709-tiny"
    );
  }
  return makeProfile(
    "metadata-missing",
    "none",
    "unknown",
    0,
    "metadata-missing-zero"
  );
}
export {
  BAKE_COLOR_IDENTITY,
  BAKE_COLOR_PARAM_KEYS,
  CREATIVE_CUBE_DEFAULT_SIZE,
  CREATIVE_PACK_01_BAKER_VERSION,
  CREATIVE_PACK_01_CUBE_SIZE,
  CREATIVE_PACK_01_EXPECTED_PROCESS_SPACE,
  CREATIVE_PACK_01_ID,
  CREATIVE_PACK_01_LOOKS,
  CREATIVE_PACK_01_STONE_TRANSFORM,
  CREATIVE_PACK_01_URBAN_TRANSFORM,
  DEFAULT_QUICK_STATE,
  DETAIL_SOFTNESS_EFFECTIVE_MAX,
  FILMTONE_DEFAULT_BASE_PRESET,
  FILMTONE_SOFT_FINISH_PATCH,
  FILM_BREATH_ZERO_OFFSETS,
  FILM_COMPRESSION_V3_CONSTANTS,
  FILM_GRAIN_INTENSITY_MAX,
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  IMPORTED_GRADE_SCHEMA_ID,
  IMPORTED_GRADE_SCHEMA_VERSION,
  IOS_PHASE0_BENCHMARK_SLOTS,
  IOS_PHASE0_OUTPUT_CODEC,
  IOS_PHASE0_OUTPUT_FPS,
  IOS_PHASE0_OUTPUT_LONG_EDGE,
  IOS_PHASE0_PARAM_KEYS,
  IOS_PHASE0_PRESET_IDS,
  IOS_PHASE0_SCHEMA_VERSION,
  IOS_PHASE0_SOURCE_CAPS,
  IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES,
  IOS_PHASE0_SOURCE_LONG_EDGE_CAP,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE,
  LOOK_ID_BY_PRESET,
  OPTICAL_FILTER_DISCLAIMER,
  OPTICAL_FILTER_PARAM_KEYS,
  OPTICAL_FILTER_PROFILES,
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
  SHADOW_LATITUDE_CONSTANTS,
  SOURCE_PROFILE_CATALOG,
  applyCreativePack01SourceTransform,
  applyFilmCompressionV3Sample,
  applyQuickStateToParams,
  applyQuickStateToPhase0Params,
  applyShadowLatitudeSample,
  applyStoneDisplayPalermoTransform,
  applyStoneFingerprintTransform,
  applyUrbanCoolDensityTransform,
  assertPhase0SourceProbeWithinCaps,
  bakeColorOnly,
  benchmarkMarkdownTableHeader,
  buildBenchmarkRow,
  buildImportedGradeLookFromDrxImport,
  buildLookParamOverrides,
  buildOpticalFilterParamPatch,
  buildOpticalParamPatch,
  buildPhase0ExportRequest,
  buildSourceProfileLut,
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
  deriveDetailSoftnessUniforms,
  deriveFilmBreathOffsets,
  deserializeCubeLutData,
  diagonalMaxDelta,
  filmCompressionChromaMagnitude,
  filmCompressionLuma,
  filmLabDepthTrackSchema,
  filmLabParamsSchema,
  filmLookGradeDefaultProps,
  filmLookGradeInputSchema,
  filmLookSpikeDefaultProps,
  filmLookSpikeInputSchema,
  findCreativePack01Look,
  findMatchingPreset,
  formatBenchmarkRow,
  getIosPhase0SourceCapViolations,
  getOpticalFilterProfile,
  getPhase0SourceCapViolations,
  getSourceProfile,
  gradeMatchesPreset,
  halationHueToHex,
  hslToRgb01,
  importedGradeBaseLookSchema,
  importedGradeControlSchema,
  importedGradeLookSchema,
  importedGradeSourceGraphSchema,
  importedGradeSourceSchema,
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
  makeCreativeCube,
  makeIdentityCube,
  mergePhase0Params,
  nearestHueDegreesToDirection,
  packCubeLutToFloatRgbaGrid,
  parseBenchmarkRow,
  parseCube,
  phase0ParamsSchema,
  phase0ProjectLutSchema,
  phase0ProjectSchema,
  phase0QuickStateSchema,
  pickBakeColorParams,
  pickIosPhase0Params,
  pickPhase0Params,
  quickStateSchema,
  recommendOpticalFinish,
  resolveSourceDetailCompensation,
  serializeCreativeCubeToText,
  serializeCubeLut,
  shadowLatitudeLuma
};
