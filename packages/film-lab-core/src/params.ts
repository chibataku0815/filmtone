/**
 * Film Lab のグレード数値パラメータ定義（ブラウザ・Remotion 共通の単一の真実）
 */
export const PARAM_KEYS = [
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
  "crossFilterEdgeStrengthGain",
] as const;

export type ParamKey = (typeof PARAM_KEYS)[number];

export interface Params {
  exposure: number;
  contrast: number;
  saturation: number;
  temperature: number;
  tint: number;
  rgbShift: number;
  /** レンズ周辺のソフトネス（0〜1）。色収差の周辺ソフトとは別 param。 */
  lensSoftness: number;
  grainIntensity: number;
  /** グレインの周辺比重（0〜1）。0 で径方向マスクなし、1 で現行の周辺強め。 */
  grainRadialMix: number;
  /** グレイン粒子の粗さ（0=極細/均一寄り、1=極粗/クランプ強め）。各プリセットで固有のフィルム感を表現。 */
  grainSize: number;
  vignette: number;
  bloomThreshold: number;
  bloomStrength: number;
  bloomRadius: number;
  /** Pro-Mist 的な全画面光拡散（0=オフ、1=最大ヘイズ）。Bloom/Halation とは独立。 */
  diffusion: number;
  /** Depth-aware Mist weighting（0=uniform、1=full depth weighting）。 */
  depthMistGain: number;
  /** Depth-aware Glow weighting（0=uniform、1=full depth weighting）。Bloom + Halation に適用。 */
  depthGlowGain: number;
  /** Depth ray-angle mask gamma。 */
  depthRayAngleGamma: number;
  /** Depth ray-angle mask の中心保護しきい値。 */
  depthRayAngleInnerThreshold: number;
  /** Mist source ray-angle weighting（0=off、1=max edge source boost）。 */
  depthMistRayAngleGain: number;
  /** Bloom source ray-angle weighting（0=off、1=max edge source boost）。 */
  depthBloomRayAngleGain: number;
  /** Halation source ray-angle weighting（0=off、1=max edge source boost）。 */
  depthHalationRayAngleGain: number;
  /** Mist field PSF gain（0=off、1=max field blur mix）。 */
  depthMistFieldPsfGain: number;
  /** Bloom field PSF gain（0=off、1=max field blur mix）。 */
  depthBloomFieldPsfGain: number;
  /** Halation field PSF gain（0=off、1=max field blur mix）。 */
  depthHalationFieldPsfGain: number;
  /** Mist field PSF radius in pixels。 */
  depthMistFieldPsfRadiusPx: number;
  /** Bloom field PSF radius in pixels。 */
  depthBloomFieldPsfRadiusPx: number;
  /** Halation field PSF radius in pixels。 */
  depthHalationFieldPsfRadiusPx: number;
  halationIntensity: number;
  halationSpread: number;
  halationHue: number;
  /** ハレーション発火の輝度閾値（0〜1） */
  halationThreshold: number;
  /** ハレーションのミップウェイト分布（0〜1。halationSpread の後継） */
  halationRadius: number;
  /** ブルーム閾値のソフトニー幅（0〜1） */
  bloomSoftKnee: number;
  /** ハレーション閾値のソフトニー幅（0〜1） */
  halationSoftKnee: number;
  fade: number;
  highlights: number;
  shadows: number;
  shadowTone: number;
  highlightTone: number;
  /** シャドウスプリットトーンの色相（度 0〜360） */
  shadowHue: number;
  /** ハイライトスプリットトーンの色相（度 0〜360） */
  highlightHue: number;
  // === 0.4.0 新規: Film Process ===
  /** フィルム latitude 圧縮量（0=なし、1=フル圧縮）。negative ステージに適用。 */
  compressionAmount: number;
  /** 圧縮の shoulder/toe 幅（0=急峻、1=緩やか）。compressionAmount > 0 のとき有効。 */
  compressionRange: number;
  /** 印画紙コントラスト（0=no effect、1=最大硬調）。print ステージに適用。 */
  printContrast: number;
  /** CMY enlarger color head: Cyan filter（-1〜1、0=ニュートラル）。print ステージ。 */
  cyan: number;
  /** CMY enlarger color head: Magenta filter（-1〜1、0=ニュートラル）。print ステージ。 */
  magenta: number;
  /** CMY enlarger color head: Yellow filter（-1〜1、0=ニュートラル）。print ステージ。 */
  yellow: number;
  /** @deprecated Ghost Param for URL backward compat. Use shutterAngle. */
  motionBlurAmount: number;
  /** Camera shutter angle (0=off, 180=cinema standard, 360=1F, 720=2F). Range: 0-720. */
  shutterAngle: number;
  /** Trail feedback intensity (0=none, 0.95=max). Extends afterimage beyond ring buffer depth. */
  trailIntensity: number;
  /** ダスト（埃）オーバーレイ強度（0=オフ、1=最大）。post-composite chain に適用。 */
  dustAmount: number;
  /** スクラッチ（傷）オーバーレイ強度（0=オフ、1=最大）。post-composite chain に適用。 */
  scratchAmount: number;
  /** ライトシャフト強度（0=オフ、1=最大）。post-composite chain に適用。 */
  shaftIntensity: number;
  /** ライトシャフト減衰（0=短い光線、1=長い光線）。内部で 0.92–0.995 にマップ。 */
  shaftDecay: number;
  /** ライトシャフト光源 X 位置（0=左端、1=右端）。 */
  shaftOriginX: number;
  /** ライトシャフト光源 Y 位置（0=上端、1=下端）。 */
  shaftOriginY: number;
  crossFilterStrength: number;
  crossFilterSpikes: number;
  crossFilterAngle: number;
  crossFilterLength: number;
  crossFilterThreshold: number;
  crossFilterChromatic: number;
  crossFilterSizeLimit: number;
  crossFilterRandomness: number;
  /** Hard Mode toggle (0=Soft / 1=Hard)。1 のとき中心 bloom + 強化 streak の stylized rendering。 */
  crossFilterHardMode: number;
  /** 光芒の密集回避。現行プロダクトでは 1 が下限で、1–2 の範囲で扱う。古い下位値は 1 へ正規化する。 */
  crossFilterMinSpacing: number;
  /** Cross filter source depth weighting（0=uniform、1=full depth weighting）。 */
  crossFilterDepthGain: number;
  /** Cross filter source ray-angle weighting（0=off、1=max edge source boost）。 */
  crossFilterAngleGain: number;
  /** Cross filter ray-angle mask gamma。65deg hfov の斜入射近似に適用。 */
  crossFilterAngleGamma: number;
  /** Cross filter ray-angle mask の中心保護しきい値。 */
  crossFilterAngleInnerThreshold: number;
  /** Cross filter streak length field modulation（0=uniform、1=max edge length boost）。 */
  crossFilterEdgeLengthGain: number;
  /** Cross filter streak strength field modulation（0=uniform、1=max edge strength boost）。 */
  crossFilterEdgeStrengthGain: number;
}

export function cloneParams(params: Params): Params {
  return { ...params };
}
