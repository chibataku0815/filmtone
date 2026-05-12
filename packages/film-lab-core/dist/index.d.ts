import { z } from 'zod';

/**
 * Film Lab のグレード数値パラメータ定義（ブラウザ・Remotion 共通の単一の真実）
 */
declare const PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "lensSoftness", "detailSoftness", "grainIntensity", "grainRadialMix", "grainSize", "vignette", "bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "depthMistGain", "depthGlowGain", "depthRayAngleGamma", "depthRayAngleInnerThreshold", "depthMistRayAngleGain", "depthBloomRayAngleGain", "depthHalationRayAngleGain", "depthMistFieldPsfGain", "depthBloomFieldPsfGain", "depthHalationFieldPsfGain", "depthMistFieldPsfRadiusPx", "depthBloomFieldPsfRadiusPx", "depthHalationFieldPsfRadiusPx", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "opticalDirectTransmission", "opticalBlackRetention", "opticalScatterStrength", "opticalHighlightReactivity", "opticalWarmScatter", "opticalSpectralTail", "fade", "highlights", "shadows", "shadowTone", "highlightTone", "shadowHue", "highlightHue", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow", "motionBlurAmount", "shutterAngle", "trailIntensity", "dustAmount", "scratchAmount", "shaftIntensity", "shaftDecay", "shaftOriginX", "shaftOriginY", "crossFilterStrength", "crossFilterSpikes", "crossFilterAngle", "crossFilterLength", "crossFilterThreshold", "crossFilterChromatic", "crossFilterSizeLimit", "crossFilterRandomness", "crossFilterHardMode", "crossFilterMinSpacing", "crossFilterDepthGain", "crossFilterAngleGain", "crossFilterAngleGamma", "crossFilterAngleInnerThreshold", "crossFilterEdgeLengthGain", "crossFilterEdgeStrengthGain", "haloPrismStrength", "haloPrismRadius", "haloPrismWidth", "haloPrismChromatic", "haloPrismThreshold", "haloPrismSplit", "haloPrismAngle", "haloPrismSourceReactivity"];
type ParamKey = (typeof PARAM_KEYS)[number];
declare const FILM_GRAIN_INTENSITY_MAX = 0.1;
declare function clampGrainIntensity(value: number): number;
interface Params {
    exposure: number;
    contrast: number;
    saturation: number;
    temperature: number;
    tint: number;
    rgbShift: number;
    /** レンズ周辺のソフトネス（0〜1）。色収差の周辺ソフトとは別 param。 */
    lensSoftness: number;
    /** ハードな微細ディテール（デジタル acutance）を弱める柔らかさ（0〜1）。lensSoftness とは別 param で、画面中心も対象。Phase 1 では neutral plumbing のみ。 */
    detailSoftness: number;
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
    /** Optical filter direct-light transmission（1=neutral）。 */
    opticalDirectTransmission: number;
    /** Optical filter black retention（1=preserve blacks）。 */
    opticalBlackRetention: number;
    /** Optical filter direct/scatter mix strength（0=legacy screen glow）。 */
    opticalScatterStrength: number;
    /** Optical filter highlight-reactive scatter emphasis（0=linear）。 */
    opticalHighlightReactivity: number;
    /** Optical filter warm scatter bias（0=neutral）。 */
    opticalWarmScatter: number;
    /** Optical filter RGB spectral tail split（0=neutral）。 */
    opticalSpectralTail: number;
    fade: number;
    highlights: number;
    shadows: number;
    shadowTone: number;
    highlightTone: number;
    /** シャドウスプリットトーンの色相（度 0〜360） */
    shadowHue: number;
    /** ハイライトスプリットトーンの色相（度 0〜360） */
    highlightHue: number;
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
    /** Halo Prism strength（0=off、1=max）。 */
    haloPrismStrength: number;
    /** Halo Prism ring radius（0=small、1=large）。 */
    haloPrismRadius: number;
    /** Halo Prism ring width（0=narrow、1=wide）。 */
    haloPrismWidth: number;
    /** Halo Prism chromatic edge separation（0=white、1=strong spectral edges）。 */
    haloPrismChromatic: number;
    /** Halo Prism compact-source threshold（0=easy trigger、1=bright points only）。 */
    haloPrismThreshold: number;
    /** Halo Prism partial-arc split amount（0=full ring、1=split/lower arcs）。 */
    haloPrismSplit: number;
    /** Halo Prism arc orientation in degrees。 */
    haloPrismAngle: number;
    /** Halo Prism source coupling（0=mostly procedural、1=source-reactive）。 */
    haloPrismSourceReactivity: number;
}
declare function cloneParams(params: Params): Params;

declare const PRESETS: {
    reset: Params;
    cinematic: Params;
    portra: Params;
    gold200: Params;
    pro400h: Params;
    bw: Params;
    ektar100: Params;
    superia400: Params;
    cinestill800t: Params;
    velvia50: Params;
};
type PresetName = keyof typeof PRESETS;
declare const FILMTONE_DEFAULT_BASE_PRESET = "reset";
declare const FILMTONE_SOFT_FINISH_PATCH: {
    bloomStrength: number;
    bloomThreshold: number;
    bloomRadius: number;
    diffusion: number;
    halationIntensity: number;
    halationSpread: number;
    halationRadius: number;
    halationHue: number;
};
declare function createFilmtoneDefaultParams(): Params;
/**
 * プリセットの数値が、今の Params と**全部同じ**かを調べる。
 *
 * 概要: URL 共有や保存データの Params から、どの組み込みプリセットに一致するかを逆引きする。
 * 仕様: `PARAM_KEYS` に並ぶキーを順番に比較し、完全一致した最初のプリセット名を返す。
 * 制限: 少しでも数値が違うと一致扱いにしない。近い値を「だいたい同じ」とは判定しない。
 *
 * @param params - 照合したい Film Lab のパラメータ
 */
declare function findMatchingPreset(params: Params): PresetName | null;
/**
 * プリセットバーに並べる表示用メタ情報。
 *
 * 概要: ボタンの見出し・短い説明文・カテゴリ分類・Print Medium ドキュメントをまとめ、
 *       Web / Desktop で同じ順番・同じ文言を使えるようにする。
 * 仕様: `name` は `PRESETS` のキーと一致し、UI はこの配列順で表示できる。
 * 制限: 見た目用の文言とメタ情報のみ。数値パラメータ自体は `PRESETS` を参照する。
 *
 * category:
 *   - "filmStock"  : 実フィルムのエミュレーション。Film Stock セレクターに表示する。
 *   - "look"       : フィルムではないスタイル（Teal & Orange 等）。Film Stock とは別枠。
 *   - "utility"    : reset など。セレクターの外側に配置する。
 *
 * printMedium (ドキュメント用・シリアライズしない):
 *   各プリセットが暗黙的に想定している印画媒体。UI に出さず、将来の Print Medium 独立 UI への橋渡し用。
 */
declare const PRESET_BUTTONS: {
    name: PresetName;
    label: string;
    subtitle: string;
    category: "filmStock" | "look" | "utility";
    printMedium?: "color_negative" | "silver_gelatin" | "tungsten_cinema" | "slide_positive";
}[];

/**
 * スキーマと JSON（共有 URL・Remotion）で使うプリセット定義のバージョンタグ。
 * 値を変えると Look ID が変わり互換に影響する。手順は `docs/PRESET_VERSIONING.md`。
 */
declare const PRESET_VERSION: "v1";
/**
 * 機械可読 Look ID（CD ストリームの命名規則）
 */
declare function lookIdForPreset(name: PresetName): string;
declare const LOOK_ID_BY_PRESET: Record<PresetName, string>;

/**
 * .cube LUT パーサ — Film Lab / Remotion で共有（テキスト → Float32Array）
 * 元: apps/web の cube-parser と同一仕様
 */
interface CubeLUT {
    title: string;
    size: number;
    domainMin: [number, number, number];
    domainMax: [number, number, number];
    data: Float32Array;
}
declare function parseCube(text: string): CubeLUT;

declare const PHASE0_RGB_SHIFT_MAX = 0.005;

declare const PHASE0_SCHEMA_VERSION: 2;
declare const PHASE0_PRESET_DEFAULT = "reset";
declare const PHASE0_PRESET_STRENGTH_DEFAULT = 1;
declare const PHASE0_PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "lensSoftness", "detailSoftness", "grainRadialMix", "grainSize", "bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow", "shutterAngle", "trailIntensity", "fade", "shadowTone", "highlightTone", "shadowHue", "highlightHue", "vignette", "grainIntensity"];
type Phase0ParamKey = (typeof PHASE0_PARAM_KEYS)[number];
type Phase0Params = Pick<Params, Phase0ParamKey>;
declare const PHASE0_MAX_SOURCE_DURATION_SEC: number;
declare const PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 4096;
declare const PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES: number;
declare const PHASE0_OUTPUT_PROFILE: {
    readonly longEdge: 1920;
    readonly fps: 24;
    readonly codec: "h264";
    readonly container: "mp4";
    readonly preserveAudio: true;
};
type Phase0OutputProfile = typeof PHASE0_OUTPUT_PROFILE;
declare const PHASE0_BENCHMARK_GATES: {
    readonly passRealtimeRatio: 2.5;
    readonly strongGoRealtimeRatio: 2;
    readonly noGoRealtimeRatio: 3;
};
declare const phase0ParamsSchema: z.ZodObject<{
    exposure: z.ZodDefault<z.ZodNumber>;
    contrast: z.ZodDefault<z.ZodNumber>;
    saturation: z.ZodDefault<z.ZodNumber>;
    temperature: z.ZodDefault<z.ZodNumber>;
    tint: z.ZodDefault<z.ZodNumber>;
    rgbShift: z.ZodDefault<z.ZodNumber>;
    lensSoftness: z.ZodDefault<z.ZodNumber>;
    detailSoftness: z.ZodDefault<z.ZodNumber>;
    grainRadialMix: z.ZodDefault<z.ZodNumber>;
    grainSize: z.ZodDefault<z.ZodNumber>;
    bloomThreshold: z.ZodDefault<z.ZodNumber>;
    bloomStrength: z.ZodDefault<z.ZodNumber>;
    bloomRadius: z.ZodDefault<z.ZodNumber>;
    diffusion: z.ZodDefault<z.ZodNumber>;
    halationIntensity: z.ZodDefault<z.ZodNumber>;
    halationSpread: z.ZodDefault<z.ZodNumber>;
    halationHue: z.ZodDefault<z.ZodNumber>;
    halationThreshold: z.ZodDefault<z.ZodNumber>;
    halationRadius: z.ZodDefault<z.ZodNumber>;
    bloomSoftKnee: z.ZodDefault<z.ZodNumber>;
    halationSoftKnee: z.ZodDefault<z.ZodNumber>;
    compressionAmount: z.ZodDefault<z.ZodNumber>;
    compressionRange: z.ZodDefault<z.ZodNumber>;
    printContrast: z.ZodDefault<z.ZodNumber>;
    cyan: z.ZodDefault<z.ZodNumber>;
    magenta: z.ZodDefault<z.ZodNumber>;
    yellow: z.ZodDefault<z.ZodNumber>;
    shutterAngle: z.ZodDefault<z.ZodNumber>;
    trailIntensity: z.ZodDefault<z.ZodNumber>;
    fade: z.ZodDefault<z.ZodNumber>;
    shadowTone: z.ZodDefault<z.ZodNumber>;
    highlightTone: z.ZodDefault<z.ZodNumber>;
    shadowHue: z.ZodDefault<z.ZodNumber>;
    highlightHue: z.ZodDefault<z.ZodNumber>;
    vignette: z.ZodDefault<z.ZodNumber>;
    grainIntensity: z.ZodDefault<z.ZodPipe<z.ZodNumber, z.ZodTransform<number, number>>>;
}, z.core.$strip>;
declare const phase0QuickStateSchema: z.ZodObject<{
    filmCharacter: z.ZodNumber;
    era: z.ZodNumber;
    dynamics: z.ZodNumber;
}, z.core.$strip>;
declare const phase0ProjectLutSchema: z.ZodObject<{
    title: z.ZodString;
    size: z.ZodNumber;
    data: z.ZodArray<z.ZodNumber>;
    intensity: z.ZodDefault<z.ZodNumber>;
}, z.core.$strip>;
declare const phase0ProjectSchema: z.ZodPipe<z.ZodObject<{
    schemaVersion: z.ZodLiteral<2>;
    projectId: z.ZodString;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
    presetName: z.ZodString;
    strength: z.ZodDefault<z.ZodNumber>;
    quickState: z.ZodDefault<z.ZodObject<{
        filmCharacter: z.ZodNumber;
        era: z.ZodNumber;
        dynamics: z.ZodNumber;
    }, z.core.$strip>>;
    params: z.ZodObject<{
        exposure: z.ZodOptional<z.ZodNumber>;
        contrast: z.ZodOptional<z.ZodNumber>;
        saturation: z.ZodOptional<z.ZodNumber>;
        temperature: z.ZodOptional<z.ZodNumber>;
        tint: z.ZodOptional<z.ZodNumber>;
        rgbShift: z.ZodOptional<z.ZodNumber>;
        lensSoftness: z.ZodOptional<z.ZodNumber>;
        detailSoftness: z.ZodOptional<z.ZodNumber>;
        grainRadialMix: z.ZodOptional<z.ZodNumber>;
        grainSize: z.ZodOptional<z.ZodNumber>;
        bloomThreshold: z.ZodOptional<z.ZodNumber>;
        bloomStrength: z.ZodOptional<z.ZodNumber>;
        bloomRadius: z.ZodOptional<z.ZodNumber>;
        diffusion: z.ZodOptional<z.ZodNumber>;
        halationIntensity: z.ZodOptional<z.ZodNumber>;
        halationSpread: z.ZodOptional<z.ZodNumber>;
        halationHue: z.ZodOptional<z.ZodNumber>;
        halationThreshold: z.ZodOptional<z.ZodNumber>;
        halationRadius: z.ZodOptional<z.ZodNumber>;
        bloomSoftKnee: z.ZodOptional<z.ZodNumber>;
        halationSoftKnee: z.ZodOptional<z.ZodNumber>;
        compressionAmount: z.ZodOptional<z.ZodNumber>;
        compressionRange: z.ZodOptional<z.ZodNumber>;
        printContrast: z.ZodOptional<z.ZodNumber>;
        cyan: z.ZodOptional<z.ZodNumber>;
        magenta: z.ZodOptional<z.ZodNumber>;
        yellow: z.ZodOptional<z.ZodNumber>;
        shutterAngle: z.ZodOptional<z.ZodNumber>;
        trailIntensity: z.ZodOptional<z.ZodNumber>;
        fade: z.ZodOptional<z.ZodNumber>;
        shadowTone: z.ZodOptional<z.ZodNumber>;
        highlightTone: z.ZodOptional<z.ZodNumber>;
        shadowHue: z.ZodOptional<z.ZodNumber>;
        highlightHue: z.ZodOptional<z.ZodNumber>;
        vignette: z.ZodOptional<z.ZodNumber>;
        grainIntensity: z.ZodOptional<z.ZodPipe<z.ZodNumber, z.ZodTransform<number, number>>>;
    }, z.core.$strip>;
    lut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        title: z.ZodString;
        size: z.ZodNumber;
        data: z.ZodArray<z.ZodNumber>;
        intensity: z.ZodDefault<z.ZodNumber>;
    }, z.core.$strip>>>;
    inputLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        title: z.ZodString;
        size: z.ZodNumber;
        data: z.ZodArray<z.ZodNumber>;
        intensity: z.ZodDefault<z.ZodNumber>;
    }, z.core.$strip>>>;
    creativeLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        title: z.ZodString;
        size: z.ZodNumber;
        data: z.ZodArray<z.ZodNumber>;
        intensity: z.ZodDefault<z.ZodNumber>;
    }, z.core.$strip>>>;
    output: z.ZodObject<{
        longEdge: z.ZodLiteral<1920>;
        fps: z.ZodLiteral<24>;
        codec: z.ZodLiteral<"h264">;
        container: z.ZodLiteral<"mp4">;
        preserveAudio: z.ZodDefault<z.ZodBoolean>;
    }, z.core.$strip>;
}, z.core.$strip>, z.ZodTransform<{
    presetName: "reset" | "cinematic" | "portra" | "gold200" | "pro400h" | "bw" | "ektar100" | "superia400" | "cinestill800t" | "velvia50";
    params: Phase0Params;
    inputLut: {
        title: string;
        size: number;
        data: number[];
        intensity: number;
    } | null;
    creativeLut: {
        title: string;
        size: number;
        data: number[];
        intensity: number;
    } | null;
    schemaVersion: 2;
    projectId: string;
    createdAt: string;
    updatedAt: string;
    strength: number;
    quickState: {
        filmCharacter: number;
        era: number;
        dynamics: number;
    };
    output: {
        longEdge: 1920;
        fps: 24;
        codec: "h264";
        container: "mp4";
        preserveAudio: boolean;
    };
}, {
    schemaVersion: 2;
    projectId: string;
    createdAt: string;
    updatedAt: string;
    presetName: string;
    strength: number;
    quickState: {
        filmCharacter: number;
        era: number;
        dynamics: number;
    };
    params: {
        exposure?: number | undefined;
        contrast?: number | undefined;
        saturation?: number | undefined;
        temperature?: number | undefined;
        tint?: number | undefined;
        rgbShift?: number | undefined;
        lensSoftness?: number | undefined;
        detailSoftness?: number | undefined;
        grainRadialMix?: number | undefined;
        grainSize?: number | undefined;
        bloomThreshold?: number | undefined;
        bloomStrength?: number | undefined;
        bloomRadius?: number | undefined;
        diffusion?: number | undefined;
        halationIntensity?: number | undefined;
        halationSpread?: number | undefined;
        halationHue?: number | undefined;
        halationThreshold?: number | undefined;
        halationRadius?: number | undefined;
        bloomSoftKnee?: number | undefined;
        halationSoftKnee?: number | undefined;
        compressionAmount?: number | undefined;
        compressionRange?: number | undefined;
        printContrast?: number | undefined;
        cyan?: number | undefined;
        magenta?: number | undefined;
        yellow?: number | undefined;
        shutterAngle?: number | undefined;
        trailIntensity?: number | undefined;
        fade?: number | undefined;
        shadowTone?: number | undefined;
        highlightTone?: number | undefined;
        shadowHue?: number | undefined;
        highlightHue?: number | undefined;
        vignette?: number | undefined;
        grainIntensity?: number | undefined;
    };
    output: {
        longEdge: 1920;
        fps: 24;
        codec: "h264";
        container: "mp4";
        preserveAudio: boolean;
    };
    lut?: {
        title: string;
        size: number;
        data: number[];
        intensity: number;
    } | null | undefined;
    inputLut?: {
        title: string;
        size: number;
        data: number[];
        intensity: number;
    } | null | undefined;
    creativeLut?: {
        title: string;
        size: number;
        data: number[];
        intensity: number;
    } | null | undefined;
}>>;
type Phase0ProjectLut = z.infer<typeof phase0ProjectLutSchema>;
type Phase0ProjectState = z.infer<typeof phase0ProjectSchema>;
declare function pickPhase0Params(params: Pick<Params, Phase0ParamKey>): Phase0Params;
declare function createFilmtoneDefaultPhase0Params(): Phase0Params;
declare function createDefaultPhase0Params(presetName?: PresetName): Phase0Params;
declare function interpolatePhase0PresetParams(presetName: PresetName, strength: number): Phase0Params;
declare function mergePhase0Params(base: Phase0Params, patch: Partial<Phase0Params>): Phase0Params;
declare function createPhase0ProjectState(presetName?: PresetName): Phase0ProjectState;

declare const QUICK_AXIS_IDS: readonly ["filmCharacter", "era", "dynamics"];
type QuickAxisId = (typeof QUICK_AXIS_IDS)[number];
type QuickState = Record<QuickAxisId, number>;
interface Phase0QuickTarget {
    exposure: number;
    contrast: number;
    saturation: number;
    temperature: number;
    tint: number;
    rgbShift: number;
    lensSoftness: number;
    detailSoftness: number;
    fade: number;
    vignette: number;
    grainIntensity: number;
    grainRadialMix: number;
    grainSize: number;
    bloomThreshold: number;
    bloomStrength: number;
    bloomRadius: number;
    diffusion: number;
    halationIntensity: number;
    halationSpread: number;
    halationHue: number;
    halationThreshold: number;
    halationRadius: number;
    bloomSoftKnee: number;
    halationSoftKnee: number;
    compressionAmount: number;
    compressionRange: number;
}
declare const QUICK_AXIS_DEFAULT_RANGE: {
    readonly min: -1;
    readonly max: 1;
    readonly step: 0.01;
};
declare const DEFAULT_QUICK_STATE: QuickState;
declare const quickStateSchema: z.ZodObject<{
    [x: string]: z.core.$ZodType<unknown, unknown, z.core.$ZodTypeInternals<unknown, unknown>>;
}, z.core.$strip>;
declare function coerceQuickState(input: Partial<Record<QuickAxisId, number>> | null | undefined): QuickState;
declare function applyQuickStateToParams(base: Params, state: QuickState): Params;
declare function applyQuickStateToPhase0Params<T extends Phase0QuickTarget>(base: T, state: QuickState): T;

type SourceKind = "image" | "video";
interface SourceInfo {
    uri: string;
    filename: string;
    kind: SourceKind;
    mimeType?: string;
    /**
     * True if asset has a depth source (HEIC aux depth OR AVDepthDataTrack on
     * video). Phase A (v1.3) covered HEIC stills; Phase B (v1.3, Stream D)
     * extended detection to video AVAssets carrying an AVDepthDataTrack.
     */
    hasDepth?: boolean;
}
type SourceCodecFamily = "h264" | "hevc" | "prores-422" | "prores-4444" | "prores-raw" | "other" | "unknown";
type SourceLogTransferFunction = "apple-log" | "apple-log2";
type SourceInputTransformStrategy = "none" | "apple-log-to-rec709" | "apple-log2-to-rec709" | "core-image-tone-map-sdr" | "defer-visible-warning" | "unsupported";
interface SourceInputTransformPolicy {
    strategy: SourceInputTransformStrategy;
    reason: string;
    requiresFixtureValidation: boolean;
    warning: string | null;
}
type CameraOpticsSource = "metadata" | "assumed" | "manual";
interface CameraOptics {
    source: CameraOpticsSource;
    fxPx?: number;
    fyPx?: number;
    cxPx?: number;
    cyPx?: number;
    fovXDeg?: number;
    fovYDeg?: number;
    focalLength35mm?: number;
    lensModel?: string;
    cameraMake?: string;
    cameraModel?: string;
}
interface SourceProbe extends SourceInfo {
    width?: number;
    height?: number;
    durationSec?: number;
    fileSizeBytes?: number;
    codec?: string;
    codecFamily?: SourceCodecFamily;
    logTransferFunction?: SourceLogTransferFunction;
    inputTransformPolicy?: SourceInputTransformPolicy;
    frameRate?: number;
    cameraOptics?: CameraOptics;
    sourceVideoMetadata?: SourceVideoMetadata;
    sourceToneDescriptor?: SourceToneDescriptor;
}
interface SourceToneDescriptor {
    lumaP05: number;
    lumaP50: number;
    lumaP95: number;
    lumaRangeP05P95: number;
    shadowCoverage: number;
    highlightCoverage: number;
    lowMidCoverage: number;
    saturationMean: number;
}
type SourceColorClass = "sdr-bt709" | "hdr-pq" | "hdr-hlg" | "apple-log" | "apple-log2" | "wide-gamut-unknown" | "unsupported" | "unknown";
type IosHdrPreparationStrategy = "none" | "core-image-tone-map-sdr" | "defer-visible-warning";
interface IosHdrPreparationPolicy {
    strategy: IosHdrPreparationStrategy;
    reason: string;
    requiresFixtureValidation: boolean;
    warning: string | null;
}
interface SourceColorMetadata {
    colorRange: string | null;
    colorSpace: string | null;
    colorTransfer: string | null;
    colorPrimaries: string | null;
    logTransferFunction?: SourceLogTransferFunction | null;
    hasMasteringDisplayMetadata: boolean;
    hasContentLightMetadata: boolean;
}
interface SourceDisplayGeometry {
    rawWidth: number;
    rawHeight: number;
    displayWidth: number;
    displayHeight: number;
    rotationDeg: 0 | 90 | 180 | 270 | null;
    source: "preferred-transform" | "raw";
}
interface SourceVideoTimingMetadata {
    nominalFrameRate: number | null;
    estimatedFrameRate: number | null;
    sourceFrameRateTrusted: boolean;
    trustReason: string;
}
interface SourceVideoMetadata {
    display: SourceDisplayGeometry;
    color: SourceColorMetadata;
    colorClass: SourceColorClass;
    hdrPreparationPolicy?: IosHdrPreparationPolicy;
    timing?: SourceVideoTimingMetadata;
    codecFamily?: SourceCodecFamily;
    logTransferFunction?: SourceLogTransferFunction | null;
    inputTransformPolicy?: SourceInputTransformPolicy;
}
interface ParsedCubeLut {
    title: string;
    size: number;
    data: number[];
    intensity: number;
    /**
     * v1.4 Creative LUT Pack: stable namespace slug for built-in cubes shipped
     * with the app bundle (e.g. `"filmtone-creative-pack-01-warm-print"`). nil
     * for user-imported / library-resolved cubes. Sidecar emits this so
     * downstream readers (Filmtone Connect for DaVinci) can recognize bundled
     * Looks across renames and app updates.
     */
    bundledSlug?: string;
    /**
     * v1.4 Creative LUT Pack: pack identifier for the bundled cube (e.g.
     * `"creative-pack-01"`). Companions `bundledSlug` so a single pack rev
     * is identifiable end-to-end.
     */
    bundledPackId?: string;
}
interface PickedLutFile {
    filename: string;
    text: string;
    uri?: string;
}
type Phase0ExportStage = "preflight" | "reading" | "rendering" | "writing" | "completed";
type Phase0RenderMode = "quality" | "speed";
type Phase0MezzanineProfileVariant = "sdr" | "hdr" | "qualitySDR" | "qualityHDR";
/**
 * v1.3 (iOS, D3.1): depth prefilter renderer selector. Encoded as a plain
 * string on the wire for forward-compat — Phase B may add `metal` only on a
 * subset of devices. Native side defaults to `"ci"` when nil/absent.
 */
type Phase0DepthRenderer = "ci" | "metal";
interface Phase0ExportRequest {
    sourceUri: string;
    sourceKind: SourceKind;
    sourceProbe?: SourceProbe;
    output: Phase0OutputProfile;
    grade: {
        presetName: PresetName | string;
        presetVersion: typeof PRESET_VERSION;
        quickState: QuickState;
        params: Phase0Params;
    };
    inputLut: ParsedCubeLut | null;
    creativeLut: ParsedCubeLut | null;
    /** v1.2 (iOS): opt-in to Speed mode. Absent or "quality" behaves as Quality default. */
    renderMode?: Phase0RenderMode;
    /**
     * v1.3 (iOS, D3.1): opt-in flag for the AVDepthData × ray-angle prefilter on
     * the glow trio (mist/bloom/halation). Absent / false → byte-identical to
     * v1.2 output. Only honored for still HEIC sources with depth aux data;
     * video sources are rejected on the native side
     * (`feedback_no_fallback_bug_hotbed`).
     */
    depthEnabled?: boolean;
    /**
     * v1.3 (iOS, D3.1): depth prefilter renderer selector. Phase A ships only
     * `"ci"` (Core Image multi-image kernel); `"metal"` is reserved for Phase B.
     */
    depthRenderer?: Phase0DepthRenderer;
    /**
     * v1.4 (iOS): opt-in to writing the Filmtone Connect package companions
     * (sidecar + cubes + DCTL + reference-after.jpg + a copy of the source
     * media) next to the rendered output. Absent / false → only the rendered
     * mp4 + sidecar are emitted, avoiding the multi-GB source-media copy on
     * normal save-to-Photos / share-sheet flows. The user-facing
     * "Share as Connect package" entry point is the only caller that should
     * pass `true`.
     */
    connectPackage?: boolean;
}
interface Phase0PreviewRenderResult {
    originalUri: string;
    gradedUri: string;
    width: number;
    height: number;
    posterTimeSec?: number;
}
interface Phase0ExportProgress {
    stage: Phase0ExportStage;
    progress: number;
    currentFrame?: number;
    totalFrames?: number;
    message?: string;
}
interface Phase0ExportResult {
    outputUri: string;
    elapsedMs: number;
    outputWidth: number;
    outputHeight: number;
    outputFps: number;
    fileSizeBytes?: number;
    realtimeRatio?: number;
    audioPreserved?: boolean;
    benchmarkRecord?: Phase0ExportBenchmarkRecord;
    sidecarUri?: string;
    packageFileUris?: string[];
}
interface Phase0ExportBenchmarkRecord {
    appVersion: string;
    buildNumber: string;
    deviceModel: string;
    iosVersion: string;
    sourceCodec?: string;
    sourceResolution?: string;
    sourceDurationSec?: number;
    outputFileSizeBytes?: number;
    elapsedMs: number;
    realtimeRatio?: number;
    thermalState?: string;
    memoryWarningCount?: number;
    permissionResult?: string;
    saveToPhotosOk?: boolean;
    errorDomain?: string;
    errorCode?: string;
    /** v1.1: whether this export consumed an existing mezzanine instead of decoding from source. */
    exportUsedMezzanine?: boolean;
    /** v1.1: ms spent generating a fresh mezzanine ahead of this export, if any. */
    mezzanineGenerationMs?: number;
    /** v1.2: render mode actually used ("quality" | "speed"). */
    renderMode?: Phase0RenderMode;
    /** v1.2+: mezzanine variant the export consumed, absent if no mezzanine used. */
    mezzanineProfileVariant?: Phase0MezzanineProfileVariant;
    /** v1.3 (D3.4): whether the depth × ray-angle prefilter ran for this export. */
    depthUsed?: boolean;
    /** v1.3 (D3.4): depth aux source ("avDepthData"), absent when depth not used. */
    depthSource?: string;
    /** v1.3 (D3.4): renderer that executed the prefilter ("ci" | "metal"), absent when depth not used. */
    depthRenderer?: Phase0DepthRenderer;
    /** v1.3 (D3.4): wall-clock ms across the three depth prefilter stages, absent when depth not used. */
    depthPrefilterMs?: number;
}
declare function serializeCubeLut(lut: CubeLUT, options?: {
    title?: string;
    intensity?: number;
    bundledSlug?: string;
    bundledPackId?: string;
}): ParsedCubeLut;
declare function deserializeCubeLutData(lut: ParsedCubeLut): Float32Array;
declare function getPhase0SourceCapViolations(probe: SourceProbe): string[];
declare function assertPhase0SourceProbeWithinCaps(probe: SourceProbe): void;
declare function buildPhase0ExportRequest(options: {
    source: SourceInfo;
    probe?: SourceProbe | null;
    project: Pick<Phase0ProjectState, "presetName" | "quickState" | "params" | "inputLut" | "creativeLut">;
    output?: Partial<Phase0OutputProfile>;
}): Phase0ExportRequest;

/**
 * 単体のグレードパラメータ（Film Lab の Params と同一形）
 */
declare const filmLabParamsSchema: z.ZodObject<{
    exposure: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    contrast: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    saturation: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    temperature: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    tint: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    rgbShift: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    lensSoftness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    detailSoftness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    grainIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    grainRadialMix: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    grainSize: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    vignette: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    bloomThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    bloomStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    bloomRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    diffusion: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthMistGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthGlowGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthRayAngleGamma: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthRayAngleInnerThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthMistRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthBloomRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthHalationRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthMistFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthBloomFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthHalationFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthMistFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthBloomFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    depthHalationFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationSpread: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    bloomSoftKnee: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    halationSoftKnee: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalDirectTransmission: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalBlackRetention: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalScatterStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalHighlightReactivity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalWarmScatter: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    opticalSpectralTail: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    fade: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    highlights: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shadows: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shadowTone: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    highlightTone: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shadowHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    highlightHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    compressionAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    compressionRange: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    printContrast: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    cyan: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    magenta: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    yellow: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    motionBlurAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shutterAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    trailIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    dustAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    scratchAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shaftIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shaftDecay: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shaftOriginX: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    shaftOriginY: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterSpikes: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterLength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterChromatic: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterSizeLimit: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterRandomness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterHardMode: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterMinSpacing: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterDepthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterAngleGamma: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterAngleInnerThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterEdgeLengthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    crossFilterEdgeStrengthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismWidth: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismChromatic: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismSplit: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    haloPrismSourceReactivity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
}, z.core.$strip>;
type FilmLabParamsValidated = z.infer<typeof filmLabParamsSchema>;
/**
 * Shared depth-track contract.
 *
 * `frameRelPaths` are resolved relative to the imported grade JSON so the
 * same look can round-trip through preview, export, and saved-session
 * surfaces without falling back to renderer-only state.
 */
declare const filmLabDepthTrackSchema: z.ZodObject<{
    kind: z.ZodLiteral<"frameSequence">;
    fps: z.ZodDefault<z.ZodNumber>;
    frameRelPaths: z.ZodArray<z.ZodString>;
}, z.core.$strip>;
type FilmLabDepthTrackInput = z.infer<typeof filmLabDepthTrackSchema>;
declare const cameraOpticsSchema: z.ZodObject<{
    source: z.ZodEnum<{
        metadata: "metadata";
        assumed: "assumed";
        manual: "manual";
    }>;
    fxPx: z.ZodOptional<z.ZodNumber>;
    fyPx: z.ZodOptional<z.ZodNumber>;
    cxPx: z.ZodOptional<z.ZodNumber>;
    cyPx: z.ZodOptional<z.ZodNumber>;
    fovXDeg: z.ZodOptional<z.ZodNumber>;
    fovYDeg: z.ZodOptional<z.ZodNumber>;
    focalLength35mm: z.ZodOptional<z.ZodNumber>;
    lensModel: z.ZodOptional<z.ZodString>;
    cameraMake: z.ZodOptional<z.ZodString>;
    cameraModel: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
/**
 * Remotion Composition 向け: ルック ID + バージョン + 数値グレード
 */
declare const filmLookGradeInputSchema: z.ZodObject<{
    lookPresetId: z.ZodString;
    presetVersion: z.ZodLiteral<"v1">;
    grade: z.ZodObject<{
        exposure: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        contrast: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        saturation: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        temperature: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        tint: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        rgbShift: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        lensSoftness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        detailSoftness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        grainIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        grainRadialMix: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        grainSize: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        vignette: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        bloomThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        bloomStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        bloomRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        diffusion: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthMistGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthGlowGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthRayAngleGamma: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthRayAngleInnerThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthMistRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthBloomRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthHalationRayAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthMistFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthBloomFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthHalationFieldPsfGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthMistFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthBloomFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        depthHalationFieldPsfRadiusPx: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationSpread: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        bloomSoftKnee: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        halationSoftKnee: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalDirectTransmission: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalBlackRetention: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalScatterStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalHighlightReactivity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalWarmScatter: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        opticalSpectralTail: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        fade: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        highlights: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shadows: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shadowTone: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        highlightTone: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shadowHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        highlightHue: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        compressionAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        compressionRange: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        printContrast: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        cyan: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        magenta: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        yellow: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        motionBlurAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shutterAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        trailIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        dustAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        scratchAmount: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shaftIntensity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shaftDecay: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shaftOriginX: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        shaftOriginY: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterSpikes: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterLength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterChromatic: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterSizeLimit: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterRandomness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterHardMode: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterMinSpacing: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterDepthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterAngleGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterAngleGamma: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterAngleInnerThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterEdgeLengthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        crossFilterEdgeStrengthGain: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismStrength: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismRadius: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismWidth: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismChromatic: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismThreshold: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismSplit: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismAngle: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        haloPrismSourceReactivity: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
    }, z.core.$strip>;
    depthTrack: z.ZodOptional<z.ZodObject<{
        kind: z.ZodLiteral<"frameSequence">;
        fps: z.ZodDefault<z.ZodNumber>;
        frameRelPaths: z.ZodArray<z.ZodString>;
    }, z.core.$strip>>;
    cameraOptics: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        source: z.ZodEnum<{
            metadata: "metadata";
            assumed: "assumed";
            manual: "manual";
        }>;
        fxPx: z.ZodOptional<z.ZodNumber>;
        fyPx: z.ZodOptional<z.ZodNumber>;
        cxPx: z.ZodOptional<z.ZodNumber>;
        cyPx: z.ZodOptional<z.ZodNumber>;
        fovXDeg: z.ZodOptional<z.ZodNumber>;
        fovYDeg: z.ZodOptional<z.ZodNumber>;
        focalLength35mm: z.ZodOptional<z.ZodNumber>;
        lensModel: z.ZodOptional<z.ZodString>;
        cameraMake: z.ZodOptional<z.ZodString>;
        cameraModel: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>>>;
    lut1CubeRelPath: z.ZodOptional<z.ZodString>;
    lut1Enabled: z.ZodOptional<z.ZodBoolean>;
    lut1Intensity: z.ZodOptional<z.ZodNumber>;
    lutCubeRelPath: z.ZodOptional<z.ZodString>;
    lutEnabled: z.ZodOptional<z.ZodBoolean>;
    lutIntensity: z.ZodOptional<z.ZodNumber>;
    gradeSourceVideoRelPath: z.ZodOptional<z.ZodString>;
    gradeSourceVideoWidth: z.ZodOptional<z.ZodNumber>;
    gradeSourceVideoHeight: z.ZodOptional<z.ZodNumber>;
}, z.core.$strip>;
/** z.object(ZodRawShape) 経由だと grade が Record に寛容になるため、Params で上書き */
type FilmLookGradeInputProps = Omit<z.infer<typeof filmLookGradeInputSchema>, "grade"> & {
    grade: Params;
    cameraOptics?: CameraOptics | null;
};
/**
 * Phase 0 スパイク用（ルックと無関係なテキストのみ）
 */
declare const filmLookSpikeInputSchema: z.ZodObject<{
    title: z.ZodString;
}, z.core.$strip>;
type FilmLookSpikeInputProps = z.infer<typeof filmLookSpikeInputSchema>;
/**
 * プリセット名と grade が PRESETS と一致するか（厳密一致）
 */
declare function gradeMatchesPreset(presetName: PresetName, grade: Params): boolean;

/**
 * @fileoverview .cube（3D LUT）を WebGL1 / GLSL100 向けの **2D テクスチャ**に並べ替える。
 *
 * 主な仕様:
 * - `parseCube` が返す `data` は「赤が最も速く動く」標準 .cube 順（index = r + N·g + N²·b）とみなす。
 * - 出力は幅 N²・高さ N のグリッド。ピクセル (x,y) = (r + g·N, b) に lut(r,g,b) を置く。
 * - Remotion のヘッドレス環境では `sampler3D` が使えないことが多いため、このパック＋シェーダ側トリリニアで代替する。
 *
 * 制限事項:
 * - DOMAIN_MIN / DOMAIN_MAX が 0〜1 以外の .cube は、シェーダ側で別途リマップが必要（現状は 0〜1 前提）。
 */

/**
 * 2D テクスチャ用の RGBA Float32 グリッド（Three.js `DataTexture` にそのまま渡せる）。
 */
interface PackedCubeLut2D {
    /** テクスチャ幅（= N²） */
    width: number;
    /** テクスチャ高さ（= N） */
    height: number;
    /** 1 次元 LUT サイズ N（例: 17） */
    size: number;
    /** 長さ width·height·4 の RGBA 浮動小数点データ */
    data: Float32Array;
}
/**
 * 3D LUT を 2D にパックする（WebGL1 互換の LUT サンプリング用）。
 *
 * @param {CubeLUT} lut - `parseCube` の結果
 * @returns {PackedCubeLut2D} RGBAFloat のグリッド
 */
declare function packCubeLutToFloatRgbaGrid(lut: CubeLUT): PackedCubeLut2D;

/** Remotion FilmLookSpike の defaultProps */
declare const filmLookSpikeDefaultProps: FilmLookSpikeInputProps;
/** Remotion FilmLookGrade の defaultProps（cinematic 基準） */
declare function createDefaultFilmLookGradeProps(): FilmLookGradeInputProps;
declare const filmLookGradeDefaultProps: FilmLookGradeInputProps;

type BenchmarkVisualFloor = "pass" | "fail" | "not-checked";
type BenchmarkSaveResult = "ok" | "fail" | "not-run";
interface BenchmarkRow {
    date: string;
    deviceModel: string;
    iosVersion: string;
    clipId: string;
    inputResolution: string;
    outputResolution: string;
    realtimeRatio: number | null;
    fileSizeMb: number | null;
    thermalState: string;
    memoryWarningCount: number;
    saveResult: BenchmarkSaveResult;
    visualFloor: BenchmarkVisualFloor;
    errorDomain: string | null;
    errorCode: string | null;
    durationSec: number | null;
    /** v1.2: render mode the export ran under. Absent native field → "quality" default. */
    renderMode: "quality" | "speed";
    /** v1.2+: mezzanine variant the export consumed, null when source-direct. */
    mezzanineProfileVariant: Phase0MezzanineProfileVariant | null;
}
interface BenchmarkRowInput {
    result: Phase0ExportResult;
    benchmark: Phase0ExportBenchmarkRecord;
    probe?: SourceProbe | null;
    clipId: string;
    visualFloor: BenchmarkVisualFloor;
    saveResult: BenchmarkSaveResult;
    date?: Date;
}
declare function buildBenchmarkRow(input: BenchmarkRowInput): BenchmarkRow;
declare function formatBenchmarkRow(row: BenchmarkRow): string;
declare function benchmarkMarkdownTableHeader(): string;
interface ParsedBenchmarkRow extends BenchmarkRow {
    raw: string;
}
declare function parseBenchmarkRow(line: string): ParsedBenchmarkRow | null;

/**
 * スプリットトーンの既定色相（度）とレガシー強度スケール
 *
 * 概要: Next Film Lab 以前は固定 RGB 方向 × スカラーだった。色相 UI 追加後も URL 互換のため、
 *       旧固定ベクトルに最も近い HSL 彩度方向の角度を既定値とする。
 * 仕様: HSL→RGB は CSS / Three.js と同系の標準アルゴリズム（S=1, L=0.5）。
 * 制限: 彩度円上の方向と旧ベクトルは完全一致しない（ドット積最大の角度を採用）。
 */
/**
 * HSL（h は度、S/L は 0〜1）から sRGB 線形 0〜1 を返す
 * @param hDegrees - 色相（度）
 * @param s - 彩度 0〜1
 * @param l - 明度 0〜1
 */
declare function hslToRgb01(hDegrees: number, s: number, l: number): {
    r: number;
    g: number;
    b: number;
};
/**
 * 色相（度）に対応する灰色中心の彩度単位ベクトル（長さ 1）
 * @param hueDegrees - 0〜360
 */
declare function chromaUnitFromHueDegrees(hueDegrees: number): [number, number, number];
/**
 * 方向ベクトルに最も近い彩度単位の色相（度）を返す
 * @param dir - 非ゼロの 3 成分
 */
declare function nearestHueDegreesToDirection(dir: readonly [number, number, number]): number;
/** 旧シャドウ方向に揃えた既定色相（`PRESETS` / 欠損キー埋めに使用） */
declare const FILM_LAB_DEFAULT_SHADOW_HUE: number;
/** 旧ハイライト方向に揃えた既定色相 */
declare const FILM_LAB_DEFAULT_HIGHLIGHT_HUE: number;
/** 旧 `uShadowTint` のスケール（固定ベクトルのノルム） */
declare const LEGACY_SHADOW_TONE_MAGNITUDE: number;
/** 旧ハイライト側のノルム */
declare const LEGACY_HIGHLIGHT_TONE_MAGNITUDE: number;
/**
 * Halation の色相スライダー値（0〜100）を UI 用 16 進カラーへ変換する。
 *
 * 概要: Film Lab の Halation は Dehancer 風に「深い赤 → オレンジ寄り」の帯だけを使う。
 * 仕様: 0 未満は 0、100 超は 100 として扱い、その範囲を赤・緑・青それぞれ線形補間して返す。
 * 制限: UI プレビュー用の近似色であり、シェーダ内の物理的な発光色そのものではない。
 *
 * @param hue - Halation の色相スライダー値
 */
declare function halationHueToHex(hue: number): string;

type OpticalFamily = "mist" | "glow" | "cross" | "lens";
type BehaviorProfile = "clean" | "warm" | "night" | "portrait" | "spotlight" | "product" | "stillMatch";
type OpticalRecipeId = "warmIndoor" | "nightCity" | "skinCloseUp" | "nightSpot" | "productEdge" | "coverStillMatch";
type SceneAnalysisState = "idle" | "analyzing" | "ready" | "low-confidence" | "error";
interface SceneDescriptorV1 {
    medianLuma: number;
    highlightCoverage: number;
    specularIslands: number;
    pointLightScore: number;
    globalContrast: number;
    warmthScore: number;
    portraitLikelihood: number;
    nightScore: number;
    sceneComplexity: number;
    dominantShotCoverage: number;
    sampleCount?: number;
}
type RecommendationConfidence = "low" | "medium" | "high";
type RationaleTag = "practicalLights" | "portraitSafe" | "pointLights" | "mixedScenes";
type OpticalRecommendationEntry = {
    family: OpticalFamily;
    profile: BehaviorProfile;
    recipe: OpticalRecipeId | null;
    confidence: RecommendationConfidence;
    rationale: RationaleTag[];
};
interface OpticalRecommendationV1 {
    state: Extract<SceneAnalysisState, "ready" | "low-confidence">;
    descriptor: SceneDescriptorV1;
    primary: OpticalRecommendationEntry;
    alternates: OpticalRecommendationEntry[];
}
interface OpticalAnalyzerProvider {
    readonly analyzerVersion: string;
    analyze(input: {
        sourcePath: string;
        sourceUrl?: string | null;
        trimStartSec: number;
        trimEndSec: number;
        sourceDurationSec: number;
    }): Promise<{
        state: SceneAnalysisState;
        descriptor: SceneDescriptorV1 | null;
        recommendation: OpticalRecommendationV1 | null;
    }>;
}
declare function recommendOpticalFinish(descriptor: SceneDescriptorV1): OpticalRecommendationV1;
declare function buildOpticalParamPatch(recommendation: OpticalRecommendationV1): Partial<Params>;

type OpticalFilterFamily = "blackMist" | "cineBloom" | "pearlGlow" | "warmMist" | "cleanSoft" | "backlightVeil" | "streak" | "prismHalo";
type OpticalFilterDensity = "subtle" | "1/8" | "1/4" | "1/2" | "5%" | "10%" | "20%" | "heavy";
type OpticalFilterParamKey = "bloomThreshold" | "bloomStrength" | "bloomRadius" | "diffusion" | "depthMistGain" | "depthGlowGain" | "depthRayAngleGamma" | "depthRayAngleInnerThreshold" | "depthMistRayAngleGain" | "depthBloomRayAngleGain" | "depthHalationRayAngleGain" | "depthMistFieldPsfGain" | "depthBloomFieldPsfGain" | "depthHalationFieldPsfGain" | "depthMistFieldPsfRadiusPx" | "depthBloomFieldPsfRadiusPx" | "depthHalationFieldPsfRadiusPx" | "halationIntensity" | "halationSpread" | "halationHue" | "halationThreshold" | "halationRadius" | "bloomSoftKnee" | "halationSoftKnee" | "rgbShift" | "lensSoftness" | "crossFilterStrength" | "crossFilterSpikes" | "crossFilterAngle" | "crossFilterLength" | "crossFilterThreshold" | "crossFilterChromatic" | "crossFilterSizeLimit" | "crossFilterRandomness" | "crossFilterHardMode" | "crossFilterMinSpacing" | "crossFilterDepthGain" | "crossFilterAngleGain" | "crossFilterAngleGamma" | "crossFilterAngleInnerThreshold" | "crossFilterEdgeLengthGain" | "crossFilterEdgeStrengthGain" | "haloPrismStrength" | "haloPrismRadius" | "haloPrismWidth" | "haloPrismChromatic" | "haloPrismThreshold" | "haloPrismSplit" | "haloPrismAngle" | "haloPrismSourceReactivity" | "opticalDirectTransmission" | "opticalBlackRetention" | "opticalScatterStrength" | "opticalHighlightReactivity" | "opticalWarmScatter" | "opticalSpectralTail";
type OpticalFilterParamPatch = Pick<Params, OpticalFilterParamKey>;
interface OpticalFilterBehavior {
    readonly blackRetention: number;
    readonly directTransmission: number;
    readonly scatterStrength: number;
    readonly scatterCore: number;
    readonly scatterTail: number;
    readonly highlightReactivity: number;
    readonly warmth: number;
    readonly spectralTail: number;
    readonly depthResponse: number;
    readonly rayAngleResponse: number;
    readonly fieldPsfScale: number;
}
interface OpticalFilterProfile {
    readonly id: string;
    readonly family: OpticalFilterFamily;
    readonly density: OpticalFilterDensity;
    readonly displayName: string;
    readonly shortLabel: string;
    readonly description: string;
    readonly params: Partial<OpticalFilterParamPatch>;
    readonly behavior: OpticalFilterBehavior;
}
declare const OPTICAL_FILTER_PARAM_KEYS: readonly ["bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "depthMistGain", "depthGlowGain", "depthRayAngleGamma", "depthRayAngleInnerThreshold", "depthMistRayAngleGain", "depthBloomRayAngleGain", "depthHalationRayAngleGain", "depthMistFieldPsfGain", "depthBloomFieldPsfGain", "depthHalationFieldPsfGain", "depthMistFieldPsfRadiusPx", "depthBloomFieldPsfRadiusPx", "depthHalationFieldPsfRadiusPx", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "rgbShift", "lensSoftness", "crossFilterStrength", "crossFilterSpikes", "crossFilterAngle", "crossFilterLength", "crossFilterThreshold", "crossFilterChromatic", "crossFilterSizeLimit", "crossFilterRandomness", "crossFilterHardMode", "crossFilterMinSpacing", "crossFilterDepthGain", "crossFilterAngleGain", "crossFilterAngleGamma", "crossFilterAngleInnerThreshold", "crossFilterEdgeLengthGain", "crossFilterEdgeStrengthGain", "haloPrismStrength", "haloPrismRadius", "haloPrismWidth", "haloPrismChromatic", "haloPrismThreshold", "haloPrismSplit", "haloPrismAngle", "haloPrismSourceReactivity", "opticalDirectTransmission", "opticalBlackRetention", "opticalScatterStrength", "opticalHighlightReactivity", "opticalWarmScatter", "opticalSpectralTail"];
declare const OPTICAL_FILTER_DISCLAIMER = "Inspired by common diffusion-filter families. Not a manufacturer-certified emulation.";
declare const OPTICAL_FILTER_PROFILES: readonly [{
    readonly id: "blackMist-1-8";
    readonly family: "blackMist";
    readonly density: "1/8";
    readonly displayName: "Black Mist 1/8";
    readonly shortLabel: "1/8";
    readonly description: "Controlled highlight bloom with strong black retention.";
    readonly params: {
        readonly bloomThreshold: 0.8;
        readonly bloomStrength: 0.1;
        readonly bloomRadius: 0.42;
        readonly diffusion: 0.06;
        readonly halationIntensity: 0.035;
        readonly halationSpread: 16;
        readonly halationHue: 18;
        readonly halationThreshold: 0.66;
        readonly halationRadius: 0.34;
        readonly bloomSoftKnee: 0.58;
        readonly halationSoftKnee: 0.34;
        readonly lensSoftness: 0.035;
        readonly opticalDirectTransmission: 0.965;
        readonly opticalBlackRetention: 0.92;
        readonly opticalScatterStrength: 0.18;
        readonly opticalHighlightReactivity: 0.42;
        readonly opticalWarmScatter: 0.08;
        readonly opticalSpectralTail: 0.04;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "blackMist-1-4";
    readonly family: "blackMist";
    readonly density: "1/4";
    readonly displayName: "Black Mist 1/4";
    readonly shortLabel: "1/4";
    readonly description: "Visible halation and highlight roll with protected shadows.";
    readonly params: {
        readonly bloomThreshold: 0.76;
        readonly bloomStrength: 0.18;
        readonly bloomRadius: 0.52;
        readonly diffusion: 0.1;
        readonly depthMistGain: 0.22;
        readonly depthGlowGain: 0.18;
        readonly depthMistRayAngleGain: 0.42;
        readonly depthBloomRayAngleGain: 0.32;
        readonly depthHalationRayAngleGain: 0.24;
        readonly halationIntensity: 0.07;
        readonly halationSpread: 20;
        readonly halationHue: 20;
        readonly halationThreshold: 0.62;
        readonly halationRadius: 0.42;
        readonly bloomSoftKnee: 0.64;
        readonly halationSoftKnee: 0.42;
        readonly lensSoftness: 0.055;
        readonly opticalDirectTransmission: 0.93;
        readonly opticalBlackRetention: 0.86;
        readonly opticalScatterStrength: 0.34;
        readonly opticalHighlightReactivity: 0.58;
        readonly opticalWarmScatter: 0.12;
        readonly opticalSpectralTail: 0.06;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "blackMist-1-2";
    readonly family: "blackMist";
    readonly density: "1/2";
    readonly displayName: "Black Mist 1/2";
    readonly shortLabel: "1/2";
    readonly description: "Dense highlight bloom with a broad low-frequency tail.";
    readonly params: {
        readonly bloomThreshold: 0.7;
        readonly bloomStrength: 0.28;
        readonly bloomRadius: 0.64;
        readonly diffusion: 0.16;
        readonly depthMistGain: 0.32;
        readonly depthGlowGain: 0.28;
        readonly depthMistRayAngleGain: 0.48;
        readonly depthBloomRayAngleGain: 0.38;
        readonly depthHalationRayAngleGain: 0.28;
        readonly depthMistFieldPsfRadiusPx: 22;
        readonly depthBloomFieldPsfRadiusPx: 12;
        readonly depthHalationFieldPsfRadiusPx: 15;
        readonly halationIntensity: 0.12;
        readonly halationSpread: 26;
        readonly halationHue: 21;
        readonly halationThreshold: 0.58;
        readonly halationRadius: 0.54;
        readonly bloomSoftKnee: 0.72;
        readonly halationSoftKnee: 0.5;
        readonly lensSoftness: 0.08;
        readonly opticalDirectTransmission: 0.88;
        readonly opticalBlackRetention: 0.78;
        readonly opticalScatterStrength: 0.52;
        readonly opticalHighlightReactivity: 0.72;
        readonly opticalWarmScatter: 0.16;
        readonly opticalSpectralTail: 0.08;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "cineBloom-5";
    readonly family: "cineBloom";
    readonly density: "5%";
    readonly displayName: "Cine Bloom 5%";
    readonly shortLabel: "5%";
    readonly description: "Soft digital-edge bloom with a clean haze floor.";
    readonly params: {
        readonly bloomThreshold: 0.78;
        readonly bloomStrength: 0.14;
        readonly bloomRadius: 0.5;
        readonly diffusion: 0.08;
        readonly halationIntensity: 0.03;
        readonly halationSpread: 16;
        readonly halationHue: 16;
        readonly halationRadius: 0.34;
        readonly bloomSoftKnee: 0.62;
        readonly lensSoftness: 0.045;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "cineBloom-10";
    readonly family: "cineBloom";
    readonly density: "10%";
    readonly displayName: "Cine Bloom 10%";
    readonly shortLabel: "10%";
    readonly description: "Dreamier broad bloom for practicals and skin.";
    readonly params: {
        readonly bloomThreshold: 0.72;
        readonly bloomStrength: 0.24;
        readonly bloomRadius: 0.62;
        readonly diffusion: 0.13;
        readonly halationIntensity: 0.06;
        readonly halationSpread: 22;
        readonly halationHue: 18;
        readonly halationRadius: 0.46;
        readonly bloomSoftKnee: 0.7;
        readonly halationSoftKnee: 0.4;
        readonly lensSoftness: 0.065;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "cineBloom-20";
    readonly family: "cineBloom";
    readonly density: "20%";
    readonly displayName: "Cine Bloom 20%";
    readonly shortLabel: "20%";
    readonly description: "Heavy broad glow for an intentionally dreamy finish.";
    readonly params: {
        readonly bloomThreshold: 0.64;
        readonly bloomStrength: 0.42;
        readonly bloomRadius: 0.74;
        readonly diffusion: 0.22;
        readonly halationIntensity: 0.1;
        readonly halationSpread: 28;
        readonly halationHue: 18;
        readonly halationRadius: 0.6;
        readonly bloomSoftKnee: 0.78;
        readonly halationSoftKnee: 0.48;
        readonly lensSoftness: 0.1;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "warmMist-1-8";
    readonly family: "warmMist";
    readonly density: "1/8";
    readonly displayName: "Warm Mist 1/8";
    readonly shortLabel: "1/8";
    readonly description: "Warm practical-light bloom with restrained softness.";
    readonly params: {
        readonly bloomThreshold: 0.76;
        readonly bloomStrength: 0.16;
        readonly bloomRadius: 0.48;
        readonly diffusion: 0.07;
        readonly halationIntensity: 0.08;
        readonly halationSpread: 20;
        readonly halationHue: 28;
        readonly halationThreshold: 0.6;
        readonly halationRadius: 0.4;
        readonly bloomSoftKnee: 0.62;
        readonly halationSoftKnee: 0.42;
        readonly lensSoftness: 0.04;
        readonly opticalWarmScatter: 0.18;
        readonly opticalSpectralTail: 0.04;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "warmMist-1-4";
    readonly family: "warmMist";
    readonly density: "1/4";
    readonly displayName: "Warm Mist 1/4";
    readonly shortLabel: "1/4";
    readonly description: "Tasteful amber halation for night ambience.";
    readonly params: {
        readonly bloomThreshold: 0.7;
        readonly bloomStrength: 0.24;
        readonly bloomRadius: 0.58;
        readonly diffusion: 0.11;
        readonly depthGlowGain: 0.16;
        readonly halationIntensity: 0.14;
        readonly halationSpread: 26;
        readonly halationHue: 30;
        readonly halationThreshold: 0.56;
        readonly halationRadius: 0.5;
        readonly bloomSoftKnee: 0.68;
        readonly halationSoftKnee: 0.5;
        readonly lensSoftness: 0.06;
        readonly opticalWarmScatter: 0.28;
        readonly opticalSpectralTail: 0.06;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "pearlGlow-subtle";
    readonly family: "pearlGlow";
    readonly density: "subtle";
    readonly displayName: "Pearl Glow Subtle";
    readonly shortLabel: "Subtle";
    readonly description: "Polished skin softness with minimal halo.";
    readonly params: {
        readonly bloomThreshold: 0.84;
        readonly bloomStrength: 0.06;
        readonly bloomRadius: 0.34;
        readonly diffusion: 0.045;
        readonly halationIntensity: 0.015;
        readonly halationSpread: 14;
        readonly halationRadius: 0.26;
        readonly bloomSoftKnee: 0.58;
        readonly lensSoftness: 0.055;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "pearlGlow-1-4";
    readonly family: "pearlGlow";
    readonly density: "1/4";
    readonly displayName: "Pearl Glow 1/4";
    readonly shortLabel: "1/4";
    readonly description: "Beauty-forward diffusion with clean highlights.";
    readonly params: {
        readonly bloomThreshold: 0.8;
        readonly bloomStrength: 0.1;
        readonly bloomRadius: 0.42;
        readonly diffusion: 0.085;
        readonly halationIntensity: 0.025;
        readonly halationSpread: 16;
        readonly halationRadius: 0.3;
        readonly bloomSoftKnee: 0.64;
        readonly lensSoftness: 0.08;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "cleanSoft-subtle";
    readonly family: "cleanSoft";
    readonly density: "subtle";
    readonly displayName: "Clean Soft Subtle";
    readonly shortLabel: "Subtle";
    readonly description: "Less clinical sharpness without obvious filter glow.";
    readonly params: {
        readonly bloomThreshold: 0.9;
        readonly bloomStrength: 0.035;
        readonly bloomRadius: 0.28;
        readonly diffusion: 0.02;
        readonly halationIntensity: 0;
        readonly lensSoftness: 0.075;
        readonly rgbShift: 0.0006;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "backlightVeil-1-8";
    readonly family: "backlightVeil";
    readonly density: "1/8";
    readonly displayName: "Backlight Veil 1/8";
    readonly shortLabel: "1/8";
    readonly description: "Subtle source-reactive haze for outdoor backlight while protecting shadows.";
    readonly params: {
        readonly bloomThreshold: 0.66;
        readonly bloomStrength: 0.2;
        readonly bloomRadius: 0.7;
        readonly bloomSoftKnee: 0.7;
        readonly diffusion: 0.12;
        readonly depthMistGain: 0.2;
        readonly depthGlowGain: 0.16;
        readonly depthMistRayAngleGain: 0.34;
        readonly depthBloomRayAngleGain: 0.24;
        readonly depthHalationRayAngleGain: 0.2;
        readonly depthMistFieldPsfGain: 1;
        readonly depthBloomFieldPsfGain: 1;
        readonly depthHalationFieldPsfGain: 1;
        readonly depthMistFieldPsfRadiusPx: 18;
        readonly depthBloomFieldPsfRadiusPx: 10;
        readonly depthHalationFieldPsfRadiusPx: 14;
        readonly halationIntensity: 0.07;
        readonly halationThreshold: 0.58;
        readonly halationRadius: 0.52;
        readonly halationHue: 22;
        readonly halationSoftKnee: 0.48;
        readonly lensSoftness: 0.06;
        readonly rgbShift: 0.0005;
        readonly opticalDirectTransmission: 0.92;
        readonly opticalBlackRetention: 0.78;
        readonly opticalScatterStrength: 0.42;
        readonly opticalHighlightReactivity: 0.62;
        readonly opticalWarmScatter: 0.1;
        readonly opticalSpectralTail: 0.04;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "backlightVeil-1-4";
    readonly family: "backlightVeil";
    readonly density: "1/4";
    readonly displayName: "Backlight Veil 1/4";
    readonly shortLabel: "1/4";
    readonly description: "Mid-strength veil for window and sun backlight with stable shadow retention.";
    readonly params: {
        readonly bloomThreshold: 0.56;
        readonly bloomStrength: 0.38;
        readonly bloomRadius: 0.8;
        readonly bloomSoftKnee: 0.76;
        readonly diffusion: 0.24;
        readonly depthMistGain: 0.34;
        readonly depthGlowGain: 0.27;
        readonly depthMistRayAngleGain: 0.5;
        readonly depthBloomRayAngleGain: 0.38;
        readonly depthHalationRayAngleGain: 0.3;
        readonly depthMistFieldPsfGain: 1.06;
        readonly depthBloomFieldPsfGain: 1.04;
        readonly depthHalationFieldPsfGain: 1.03;
        readonly depthMistFieldPsfRadiusPx: 25;
        readonly depthBloomFieldPsfRadiusPx: 14;
        readonly depthHalationFieldPsfRadiusPx: 18;
        readonly halationIntensity: 0.14;
        readonly halationThreshold: 0.52;
        readonly halationRadius: 0.62;
        readonly halationHue: 22;
        readonly halationSoftKnee: 0.56;
        readonly lensSoftness: 0.08;
        readonly rgbShift: 0.0007;
        readonly opticalDirectTransmission: 0.81;
        readonly opticalBlackRetention: 0.56;
        readonly opticalScatterStrength: 0.66;
        readonly opticalHighlightReactivity: 0.78;
        readonly opticalWarmScatter: 0.17;
        readonly opticalSpectralTail: 0.07;
    };
    readonly behavior: OpticalFilterBehavior;
}, {
    readonly id: "backlightVeil-1-2";
    readonly family: "backlightVeil";
    readonly density: "1/2";
    readonly displayName: "Backlight Veil 1/2";
    readonly shortLabel: "1/2";
    readonly description: "Strong but stable veiling glare for window and sun backlight.";
    readonly params: {
        readonly bloomThreshold: 0.5;
        readonly bloomStrength: 0.6;
        readonly bloomRadius: 0.88;
        readonly bloomSoftKnee: 0.82;
        readonly diffusion: 0.38;
        readonly depthMistGain: 0.5;
        readonly depthGlowGain: 0.4;
        readonly depthMistRayAngleGain: 0.66;
        readonly depthBloomRayAngleGain: 0.52;
        readonly depthHalationRayAngleGain: 0.4;
        readonly depthMistFieldPsfGain: 1.12;
        readonly depthBloomFieldPsfGain: 1.08;
        readonly depthHalationFieldPsfGain: 1.06;
        readonly depthMistFieldPsfRadiusPx: 32;
        readonly depthBloomFieldPsfRadiusPx: 18;
        readonly depthHalationFieldPsfRadiusPx: 22;
        readonly halationIntensity: 0.22;
        readonly halationThreshold: 0.46;
        readonly halationRadius: 0.74;
        readonly halationHue: 22;
        readonly halationSoftKnee: 0.64;
        readonly lensSoftness: 0.1;
        readonly rgbShift: 0.0009;
        readonly opticalDirectTransmission: 0.7;
        readonly opticalBlackRetention: 0.36;
        readonly opticalScatterStrength: 0.9;
        readonly opticalHighlightReactivity: 0.95;
        readonly opticalWarmScatter: 0.24;
        readonly opticalSpectralTail: 0.1;
    };
    readonly behavior: OpticalFilterBehavior;
}];
type OpticalFilterProfileId = (typeof OPTICAL_FILTER_PROFILES)[number]["id"];
declare function getOpticalFilterProfile(id: OpticalFilterProfileId | string): OpticalFilterProfile | null;
declare function buildOpticalFilterParamPatch(id: OpticalFilterProfileId | string): Partial<Params>;

/**
 * iOS Phase 0 ships with a deliberately small preset set.
 *
 * Shared PRESETS remain the canonical Desktop/Web defaults. iOS uses these
 * mobile-specific patches over Filmtone's soft default base so the phone app
 * has fewer, clearer choices without changing other product surfaces.
 *
 * v1.4 Look V2 — values re-derived against CD reference frames:
 *   - Filmtone Signature ↔ warmglow-4s/6.5s (warm cozy candle, portra-like)
 *   - Soft Blue        ↔ guasha-1s/3s/5s (cool window highlight + warm
 *                         interior shadow — split-tone via new shadowHue/
 *                         highlightHue/shadowTone/highlightTone fields)
 *   - Amber Glow       ↔ warmglow-1.5s (dramatic warm flame, gold200-like)
 *
 * Each value carries a reason (which reference / which desktop stock pulled
 * it). handoff §3.7 — no arbitrary bumps.
 */
declare const FILMTONE_IOS_PRESET_NAMES: readonly ["reset", "iphone", "softBlue", "amberGlow"];
type FilmtoneIosPresetName = (typeof FILMTONE_IOS_PRESET_NAMES)[number];

declare const IOS_PHASE0_SCHEMA_VERSION: 2;
declare const IOS_PHASE0_PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "lensSoftness", "detailSoftness", "grainRadialMix", "grainSize", "bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow", "shutterAngle", "trailIntensity", "fade", "shadowTone", "highlightTone", "shadowHue", "highlightHue", "vignette", "grainIntensity"];
type IosPhase0ParamKey = Phase0ParamKey;
type IosPhase0Params = Phase0Params;
declare const iosPhase0ParamsSchema: z.ZodObject<{
    exposure: z.ZodDefault<z.ZodNumber>;
    contrast: z.ZodDefault<z.ZodNumber>;
    saturation: z.ZodDefault<z.ZodNumber>;
    temperature: z.ZodDefault<z.ZodNumber>;
    tint: z.ZodDefault<z.ZodNumber>;
    rgbShift: z.ZodDefault<z.ZodNumber>;
    lensSoftness: z.ZodDefault<z.ZodNumber>;
    detailSoftness: z.ZodDefault<z.ZodNumber>;
    grainRadialMix: z.ZodDefault<z.ZodNumber>;
    grainSize: z.ZodDefault<z.ZodNumber>;
    bloomThreshold: z.ZodDefault<z.ZodNumber>;
    bloomStrength: z.ZodDefault<z.ZodNumber>;
    bloomRadius: z.ZodDefault<z.ZodNumber>;
    diffusion: z.ZodDefault<z.ZodNumber>;
    halationIntensity: z.ZodDefault<z.ZodNumber>;
    halationSpread: z.ZodDefault<z.ZodNumber>;
    halationHue: z.ZodDefault<z.ZodNumber>;
    halationThreshold: z.ZodDefault<z.ZodNumber>;
    halationRadius: z.ZodDefault<z.ZodNumber>;
    bloomSoftKnee: z.ZodDefault<z.ZodNumber>;
    halationSoftKnee: z.ZodDefault<z.ZodNumber>;
    compressionAmount: z.ZodDefault<z.ZodNumber>;
    compressionRange: z.ZodDefault<z.ZodNumber>;
    printContrast: z.ZodDefault<z.ZodNumber>;
    cyan: z.ZodDefault<z.ZodNumber>;
    magenta: z.ZodDefault<z.ZodNumber>;
    yellow: z.ZodDefault<z.ZodNumber>;
    shutterAngle: z.ZodDefault<z.ZodNumber>;
    trailIntensity: z.ZodDefault<z.ZodNumber>;
    fade: z.ZodDefault<z.ZodNumber>;
    shadowTone: z.ZodDefault<z.ZodNumber>;
    highlightTone: z.ZodDefault<z.ZodNumber>;
    shadowHue: z.ZodDefault<z.ZodNumber>;
    highlightHue: z.ZodDefault<z.ZodNumber>;
    vignette: z.ZodDefault<z.ZodNumber>;
    grainIntensity: z.ZodDefault<z.ZodPipe<z.ZodNumber, z.ZodTransform<number, number>>>;
}, z.core.$strip>;
declare const IOS_PHASE0_OUTPUT_CODEC: "h264-mp4";
declare const IOS_PHASE0_OUTPUT_LONG_EDGE: 1920;
declare const IOS_PHASE0_OUTPUT_FPS: 24;
declare const IOS_PHASE0_SOURCE_DURATION_CAP_SEC: number;
declare const IOS_PHASE0_SOURCE_LONG_EDGE_CAP = 4096;
declare const IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES: number;
declare const IOS_PHASE0_SOURCE_CAPS: {
    readonly durationSec: number;
    readonly longEdge: 4096;
    readonly fileSizeBytes: number;
};
declare const IOS_PHASE0_BENCHMARK_SLOTS: readonly ["bench-short", "bench-mid", "bench-long"];
type IosPhase0BenchmarkSlot = (typeof IOS_PHASE0_BENCHMARK_SLOTS)[number];
declare const iosPhase0SourceKindSchema: z.ZodEnum<{
    image: "image";
    video: "video";
}>;
type IosPhase0SourceKind = z.infer<typeof iosPhase0SourceKindSchema>;
declare const iosPhase0SerializableLutSchema: z.ZodObject<{
    name: z.ZodString;
    title: z.ZodOptional<z.ZodString>;
    size: z.ZodNumber;
    intensity: z.ZodDefault<z.ZodNumber>;
    domainMin: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
    domainMax: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
    rgbaData: z.ZodArray<z.ZodNumber>;
    bundledSlug: z.ZodOptional<z.ZodString>;
    bundledPackId: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
type IosPhase0SerializableLut = z.infer<typeof iosPhase0SerializableLutSchema>;
declare function createIosPhase0SerializableLut(input: {
    cube: CubeLUT;
    name: string;
    intensity?: number;
    bundledSlug?: string;
    bundledPackId?: string;
}): IosPhase0SerializableLut;
declare const iosPhase0PickedSourceSchema: z.ZodObject<{
    uri: z.ZodString;
    displayName: z.ZodString;
    kind: z.ZodOptional<z.ZodEnum<{
        image: "image";
        video: "video";
    }>>;
}, z.core.$strip>;
type IosPhase0PickedSource = z.infer<typeof iosPhase0PickedSourceSchema>;
declare const iosPhase0PickedLutFileSchema: z.ZodObject<{
    uri: z.ZodString;
    displayName: z.ZodString;
    text: z.ZodString;
}, z.core.$strip>;
type IosPhase0PickedLutFile = z.infer<typeof iosPhase0PickedLutFileSchema>;
declare const iosPhase0SourceInfoSchema: z.ZodObject<{
    uri: z.ZodString;
    displayName: z.ZodString;
    kind: z.ZodEnum<{
        image: "image";
        video: "video";
    }>;
    width: z.ZodOptional<z.ZodNumber>;
    height: z.ZodOptional<z.ZodNumber>;
    durationSec: z.ZodOptional<z.ZodNumber>;
    fileSizeBytes: z.ZodOptional<z.ZodNumber>;
    videoCodec: z.ZodOptional<z.ZodString>;
    codecFamily: z.ZodOptional<z.ZodEnum<{
        unknown: "unknown";
        h264: "h264";
        hevc: "hevc";
        "prores-422": "prores-422";
        "prores-4444": "prores-4444";
        "prores-raw": "prores-raw";
        other: "other";
    }>>;
    logTransferFunction: z.ZodOptional<z.ZodEnum<{
        "apple-log": "apple-log";
        "apple-log2": "apple-log2";
    }>>;
    inputTransformPolicy: z.ZodOptional<z.ZodObject<{
        strategy: z.ZodEnum<{
            none: "none";
            "apple-log-to-rec709": "apple-log-to-rec709";
            "apple-log2-to-rec709": "apple-log2-to-rec709";
            "core-image-tone-map-sdr": "core-image-tone-map-sdr";
            "defer-visible-warning": "defer-visible-warning";
            unsupported: "unsupported";
        }>;
        reason: z.ZodString;
        requiresFixtureValidation: z.ZodBoolean;
        warning: z.ZodOptional<z.ZodNullable<z.ZodString>>;
    }, z.core.$strip>>;
    audioCodec: z.ZodOptional<z.ZodString>;
    frameRate: z.ZodOptional<z.ZodNumber>;
    hasAudio: z.ZodOptional<z.ZodBoolean>;
}, z.core.$strip>;
type IosPhase0SourceInfo = z.infer<typeof iosPhase0SourceInfoSchema>;
declare const IOS_PHASE0_PRESET_IDS: readonly [FilmtoneIosPresetName, ...FilmtoneIosPresetName[]];
declare const iosPhase0PresetIdSchema: z.ZodEnum<{
    reset: "reset";
    iphone: "iphone";
    softBlue: "softBlue";
    amberGlow: "amberGlow";
}>;
declare const iosPhase0ExportSettingsSchema: z.ZodObject<{
    codec: z.ZodDefault<z.ZodLiteral<"h264-mp4">>;
    outputLongEdge: z.ZodDefault<z.ZodNumber>;
    outputFps: z.ZodDefault<z.ZodLiteral<24>>;
}, z.core.$strip>;
type IosPhase0ExportSettings = z.infer<typeof iosPhase0ExportSettingsSchema>;
declare const iosPhase0ExportPayloadSchema: z.ZodObject<{
    projectId: z.ZodString;
    sourceUri: z.ZodString;
    sourceDisplayName: z.ZodString;
    sourceKind: z.ZodEnum<{
        image: "image";
        video: "video";
    }>;
    presetId: z.ZodEnum<{
        reset: "reset";
        iphone: "iphone";
        softBlue: "softBlue";
        amberGlow: "amberGlow";
    }>;
    params: z.ZodObject<{
        exposure: z.ZodDefault<z.ZodNumber>;
        contrast: z.ZodDefault<z.ZodNumber>;
        saturation: z.ZodDefault<z.ZodNumber>;
        temperature: z.ZodDefault<z.ZodNumber>;
        tint: z.ZodDefault<z.ZodNumber>;
        rgbShift: z.ZodDefault<z.ZodNumber>;
        lensSoftness: z.ZodDefault<z.ZodNumber>;
        detailSoftness: z.ZodDefault<z.ZodNumber>;
        grainRadialMix: z.ZodDefault<z.ZodNumber>;
        grainSize: z.ZodDefault<z.ZodNumber>;
        bloomThreshold: z.ZodDefault<z.ZodNumber>;
        bloomStrength: z.ZodDefault<z.ZodNumber>;
        bloomRadius: z.ZodDefault<z.ZodNumber>;
        diffusion: z.ZodDefault<z.ZodNumber>;
        halationIntensity: z.ZodDefault<z.ZodNumber>;
        halationSpread: z.ZodDefault<z.ZodNumber>;
        halationHue: z.ZodDefault<z.ZodNumber>;
        halationThreshold: z.ZodDefault<z.ZodNumber>;
        halationRadius: z.ZodDefault<z.ZodNumber>;
        bloomSoftKnee: z.ZodDefault<z.ZodNumber>;
        halationSoftKnee: z.ZodDefault<z.ZodNumber>;
        compressionAmount: z.ZodDefault<z.ZodNumber>;
        compressionRange: z.ZodDefault<z.ZodNumber>;
        printContrast: z.ZodDefault<z.ZodNumber>;
        cyan: z.ZodDefault<z.ZodNumber>;
        magenta: z.ZodDefault<z.ZodNumber>;
        yellow: z.ZodDefault<z.ZodNumber>;
        shutterAngle: z.ZodDefault<z.ZodNumber>;
        trailIntensity: z.ZodDefault<z.ZodNumber>;
        fade: z.ZodDefault<z.ZodNumber>;
        shadowTone: z.ZodDefault<z.ZodNumber>;
        highlightTone: z.ZodDefault<z.ZodNumber>;
        shadowHue: z.ZodDefault<z.ZodNumber>;
        highlightHue: z.ZodDefault<z.ZodNumber>;
        vignette: z.ZodDefault<z.ZodNumber>;
        grainIntensity: z.ZodDefault<z.ZodPipe<z.ZodNumber, z.ZodTransform<number, number>>>;
    }, z.core.$strip>;
    inputLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        name: z.ZodString;
        title: z.ZodOptional<z.ZodString>;
        size: z.ZodNumber;
        intensity: z.ZodDefault<z.ZodNumber>;
        domainMin: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        domainMax: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        rgbaData: z.ZodArray<z.ZodNumber>;
        bundledSlug: z.ZodOptional<z.ZodString>;
        bundledPackId: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>>>;
    creativeLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        name: z.ZodString;
        title: z.ZodOptional<z.ZodString>;
        size: z.ZodNumber;
        intensity: z.ZodDefault<z.ZodNumber>;
        domainMin: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        domainMax: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        rgbaData: z.ZodArray<z.ZodNumber>;
        bundledSlug: z.ZodOptional<z.ZodString>;
        bundledPackId: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>>>;
    benchmarkSlot: z.ZodOptional<z.ZodEnum<{
        "bench-short": "bench-short";
        "bench-mid": "bench-mid";
        "bench-long": "bench-long";
    }>>;
    benchmarkRecipeId: z.ZodOptional<z.ZodString>;
    includeAudio: z.ZodOptional<z.ZodBoolean>;
    exportSettings: z.ZodDefault<z.ZodObject<{
        codec: z.ZodDefault<z.ZodLiteral<"h264-mp4">>;
        outputLongEdge: z.ZodDefault<z.ZodNumber>;
        outputFps: z.ZodDefault<z.ZodLiteral<24>>;
    }, z.core.$strip>>;
}, z.core.$strip>;
type IosPhase0ExportPayload = z.infer<typeof iosPhase0ExportPayloadSchema>;
declare const iosPhase0ExportResultSchema: z.ZodObject<{
    outputUri: z.ZodString;
    outputDisplayName: z.ZodString;
    outputWidth: z.ZodNumber;
    outputHeight: z.ZodNumber;
    outputFps: z.ZodNumber;
    elapsedMs: z.ZodNumber;
    realtimeRatio: z.ZodOptional<z.ZodNumber>;
    fileSizeBytes: z.ZodOptional<z.ZodNumber>;
    benchmarkRecordUri: z.ZodOptional<z.ZodString>;
}, z.core.$strip>;
type IosPhase0ExportResult = z.infer<typeof iosPhase0ExportResultSchema>;
declare const iosPhase0ThermalStateSchema: z.ZodEnum<{
    unknown: "unknown";
    nominal: "nominal";
    fair: "fair";
    serious: "serious";
    critical: "critical";
}>;
declare const iosPhase0BenchmarkRecordSchema: z.ZodObject<{
    schemaVersion: z.ZodLiteral<2>;
    recordedAt: z.ZodString;
    slot: z.ZodEnum<{
        "bench-short": "bench-short";
        "bench-mid": "bench-mid";
        "bench-long": "bench-long";
    }>;
    runIndex: z.ZodNumber;
    appVersion: z.ZodString;
    buildNumber: z.ZodString;
    deviceModel: z.ZodString;
    iosVersion: z.ZodString;
    source: z.ZodObject<{
        uri: z.ZodString;
        displayName: z.ZodString;
        kind: z.ZodEnum<{
            image: "image";
            video: "video";
        }>;
        width: z.ZodOptional<z.ZodNumber>;
        height: z.ZodOptional<z.ZodNumber>;
        durationSec: z.ZodOptional<z.ZodNumber>;
        fileSizeBytes: z.ZodOptional<z.ZodNumber>;
        videoCodec: z.ZodOptional<z.ZodString>;
        codecFamily: z.ZodOptional<z.ZodEnum<{
            unknown: "unknown";
            h264: "h264";
            hevc: "hevc";
            "prores-422": "prores-422";
            "prores-4444": "prores-4444";
            "prores-raw": "prores-raw";
            other: "other";
        }>>;
        logTransferFunction: z.ZodOptional<z.ZodEnum<{
            "apple-log": "apple-log";
            "apple-log2": "apple-log2";
        }>>;
        inputTransformPolicy: z.ZodOptional<z.ZodObject<{
            strategy: z.ZodEnum<{
                none: "none";
                "apple-log-to-rec709": "apple-log-to-rec709";
                "apple-log2-to-rec709": "apple-log2-to-rec709";
                "core-image-tone-map-sdr": "core-image-tone-map-sdr";
                "defer-visible-warning": "defer-visible-warning";
                unsupported: "unsupported";
            }>;
            reason: z.ZodString;
            requiresFixtureValidation: z.ZodBoolean;
            warning: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        }, z.core.$strip>>;
        audioCodec: z.ZodOptional<z.ZodString>;
        frameRate: z.ZodOptional<z.ZodNumber>;
        hasAudio: z.ZodOptional<z.ZodBoolean>;
    }, z.core.$strip>;
    output: z.ZodObject<{
        outputUri: z.ZodString;
        outputDisplayName: z.ZodString;
        outputWidth: z.ZodNumber;
        outputHeight: z.ZodNumber;
        outputFps: z.ZodNumber;
        elapsedMs: z.ZodNumber;
        realtimeRatio: z.ZodOptional<z.ZodNumber>;
        fileSizeBytes: z.ZodOptional<z.ZodNumber>;
        benchmarkRecordUri: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>;
    elapsedMs: z.ZodNumber;
    realtimeRatio: z.ZodNumber;
    thermalStateStart: z.ZodEnum<{
        unknown: "unknown";
        nominal: "nominal";
        fair: "fair";
        serious: "serious";
        critical: "critical";
    }>;
    thermalStateEnd: z.ZodEnum<{
        unknown: "unknown";
        nominal: "nominal";
        fair: "fair";
        serious: "serious";
        critical: "critical";
    }>;
    memoryWarningCount: z.ZodNumber;
    permissionResults: z.ZodObject<{
        mediaLibrary: z.ZodEnum<{
            unknown: "unknown";
            granted: "granted";
            denied: "denied";
            limited: "limited";
            "not-required": "not-required";
        }>;
        fileImport: z.ZodEnum<{
            unknown: "unknown";
            granted: "granted";
            denied: "denied";
            limited: "limited";
            "not-required": "not-required";
        }>;
        sharing: z.ZodEnum<{
            unknown: "unknown";
            granted: "granted";
            denied: "denied";
            limited: "limited";
            "not-required": "not-required";
        }>;
    }, z.core.$strip>;
    failureDomain: z.ZodOptional<z.ZodString>;
    failureCode: z.ZodOptional<z.ZodString>;
    failureMessage: z.ZodOptional<z.ZodString>;
    previewArtifacts: z.ZodObject<{
        firstFrameUri: z.ZodOptional<z.ZodString>;
        midFrameUri: z.ZodOptional<z.ZodString>;
        lastFrameUri: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>;
}, z.core.$strip>;
type IosPhase0BenchmarkRecord = z.infer<typeof iosPhase0BenchmarkRecordSchema>;
declare const iosPhase0AssetRefSchema: z.ZodObject<{
    uri: z.ZodString;
    displayName: z.ZodString;
    assetKind: z.ZodEnum<{
        lut: "lut";
        source: "source";
        "derived-output": "derived-output";
        "benchmark-record": "benchmark-record";
    }>;
    createdAt: z.ZodString;
    byteSize: z.ZodOptional<z.ZodNumber>;
}, z.core.$strip>;
type IosPhase0AssetRef = z.infer<typeof iosPhase0AssetRefSchema>;
declare const iosPhase0LocalProjectSchema: z.ZodObject<{
    schemaVersion: z.ZodLiteral<2>;
    projectId: z.ZodString;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
    presetId: z.ZodEnum<{
        reset: "reset";
        iphone: "iphone";
        softBlue: "softBlue";
        amberGlow: "amberGlow";
    }>;
    params: z.ZodObject<{
        exposure: z.ZodDefault<z.ZodNumber>;
        contrast: z.ZodDefault<z.ZodNumber>;
        saturation: z.ZodDefault<z.ZodNumber>;
        temperature: z.ZodDefault<z.ZodNumber>;
        tint: z.ZodDefault<z.ZodNumber>;
        rgbShift: z.ZodDefault<z.ZodNumber>;
        lensSoftness: z.ZodDefault<z.ZodNumber>;
        detailSoftness: z.ZodDefault<z.ZodNumber>;
        grainRadialMix: z.ZodDefault<z.ZodNumber>;
        grainSize: z.ZodDefault<z.ZodNumber>;
        bloomThreshold: z.ZodDefault<z.ZodNumber>;
        bloomStrength: z.ZodDefault<z.ZodNumber>;
        bloomRadius: z.ZodDefault<z.ZodNumber>;
        diffusion: z.ZodDefault<z.ZodNumber>;
        halationIntensity: z.ZodDefault<z.ZodNumber>;
        halationSpread: z.ZodDefault<z.ZodNumber>;
        halationHue: z.ZodDefault<z.ZodNumber>;
        halationThreshold: z.ZodDefault<z.ZodNumber>;
        halationRadius: z.ZodDefault<z.ZodNumber>;
        bloomSoftKnee: z.ZodDefault<z.ZodNumber>;
        halationSoftKnee: z.ZodDefault<z.ZodNumber>;
        compressionAmount: z.ZodDefault<z.ZodNumber>;
        compressionRange: z.ZodDefault<z.ZodNumber>;
        printContrast: z.ZodDefault<z.ZodNumber>;
        cyan: z.ZodDefault<z.ZodNumber>;
        magenta: z.ZodDefault<z.ZodNumber>;
        yellow: z.ZodDefault<z.ZodNumber>;
        shutterAngle: z.ZodDefault<z.ZodNumber>;
        trailIntensity: z.ZodDefault<z.ZodNumber>;
        fade: z.ZodDefault<z.ZodNumber>;
        shadowTone: z.ZodDefault<z.ZodNumber>;
        highlightTone: z.ZodDefault<z.ZodNumber>;
        shadowHue: z.ZodDefault<z.ZodNumber>;
        highlightHue: z.ZodDefault<z.ZodNumber>;
        vignette: z.ZodDefault<z.ZodNumber>;
        grainIntensity: z.ZodDefault<z.ZodPipe<z.ZodNumber, z.ZodTransform<number, number>>>;
    }, z.core.$strip>;
    source: z.ZodNullable<z.ZodObject<{
        uri: z.ZodString;
        displayName: z.ZodString;
        kind: z.ZodEnum<{
            image: "image";
            video: "video";
        }>;
        width: z.ZodOptional<z.ZodNumber>;
        height: z.ZodOptional<z.ZodNumber>;
        durationSec: z.ZodOptional<z.ZodNumber>;
        fileSizeBytes: z.ZodOptional<z.ZodNumber>;
        videoCodec: z.ZodOptional<z.ZodString>;
        codecFamily: z.ZodOptional<z.ZodEnum<{
            unknown: "unknown";
            h264: "h264";
            hevc: "hevc";
            "prores-422": "prores-422";
            "prores-4444": "prores-4444";
            "prores-raw": "prores-raw";
            other: "other";
        }>>;
        logTransferFunction: z.ZodOptional<z.ZodEnum<{
            "apple-log": "apple-log";
            "apple-log2": "apple-log2";
        }>>;
        inputTransformPolicy: z.ZodOptional<z.ZodObject<{
            strategy: z.ZodEnum<{
                none: "none";
                "apple-log-to-rec709": "apple-log-to-rec709";
                "apple-log2-to-rec709": "apple-log2-to-rec709";
                "core-image-tone-map-sdr": "core-image-tone-map-sdr";
                "defer-visible-warning": "defer-visible-warning";
                unsupported: "unsupported";
            }>;
            reason: z.ZodString;
            requiresFixtureValidation: z.ZodBoolean;
            warning: z.ZodOptional<z.ZodNullable<z.ZodString>>;
        }, z.core.$strip>>;
        audioCodec: z.ZodOptional<z.ZodString>;
        frameRate: z.ZodOptional<z.ZodNumber>;
        hasAudio: z.ZodOptional<z.ZodBoolean>;
    }, z.core.$strip>>;
    sourceAssetRef: z.ZodNullable<z.ZodObject<{
        uri: z.ZodString;
        displayName: z.ZodString;
        assetKind: z.ZodEnum<{
            lut: "lut";
            source: "source";
            "derived-output": "derived-output";
            "benchmark-record": "benchmark-record";
        }>;
        createdAt: z.ZodString;
        byteSize: z.ZodOptional<z.ZodNumber>;
    }, z.core.$strip>>;
    lutAssetRef: z.ZodNullable<z.ZodObject<{
        uri: z.ZodString;
        displayName: z.ZodString;
        assetKind: z.ZodEnum<{
            lut: "lut";
            source: "source";
            "derived-output": "derived-output";
            "benchmark-record": "benchmark-record";
        }>;
        createdAt: z.ZodString;
        byteSize: z.ZodOptional<z.ZodNumber>;
    }, z.core.$strip>>;
    exportSettings: z.ZodObject<{
        codec: z.ZodDefault<z.ZodLiteral<"h264-mp4">>;
        outputLongEdge: z.ZodDefault<z.ZodNumber>;
        outputFps: z.ZodDefault<z.ZodLiteral<24>>;
    }, z.core.$strip>;
    derivedData: z.ZodObject<{
        lastOutput: z.ZodDefault<z.ZodNullable<z.ZodObject<{
            uri: z.ZodString;
            displayName: z.ZodString;
            assetKind: z.ZodEnum<{
                lut: "lut";
                source: "source";
                "derived-output": "derived-output";
                "benchmark-record": "benchmark-record";
            }>;
            createdAt: z.ZodString;
            byteSize: z.ZodOptional<z.ZodNumber>;
        }, z.core.$strip>>>;
        lastExportResult: z.ZodDefault<z.ZodNullable<z.ZodObject<{
            outputUri: z.ZodString;
            outputDisplayName: z.ZodString;
            outputWidth: z.ZodNumber;
            outputHeight: z.ZodNumber;
            outputFps: z.ZodNumber;
            elapsedMs: z.ZodNumber;
            realtimeRatio: z.ZodOptional<z.ZodNumber>;
            fileSizeBytes: z.ZodOptional<z.ZodNumber>;
            benchmarkRecordUri: z.ZodOptional<z.ZodString>;
        }, z.core.$strip>>>;
        benchmarkRecords: z.ZodDefault<z.ZodArray<z.ZodObject<{
            uri: z.ZodString;
            displayName: z.ZodString;
            assetKind: z.ZodEnum<{
                lut: "lut";
                source: "source";
                "derived-output": "derived-output";
                "benchmark-record": "benchmark-record";
            }>;
            createdAt: z.ZodString;
            byteSize: z.ZodOptional<z.ZodNumber>;
        }, z.core.$strip>>>;
    }, z.core.$strip>;
    cacheMetadata: z.ZodObject<{
        workingDirectoryUri: z.ZodOptional<z.ZodString>;
        derivedOutputUris: z.ZodDefault<z.ZodArray<z.ZodString>>;
        lastPurgeAt: z.ZodOptional<z.ZodString>;
    }, z.core.$strip>;
}, z.core.$strip>;
type IosPhase0LocalProject = z.infer<typeof iosPhase0LocalProjectSchema>;
declare function pickIosPhase0Params(params: IosPhase0Params): IosPhase0Params;
declare function getIosPhase0SourceCapViolations(source: Pick<IosPhase0SourceInfo, "width" | "height" | "durationSec" | "fileSizeBytes">): string[];

/**
 * Color-only baker for Filmtone iOS Creative LUT Pack v1.4.
 *
 * Implements Stages 2 (baseGrade), 3 (filmCompression), and 9 (printStage) of
 * the Filmtone iOS export pipeline as a pure function on a single Rec.709 RGB
 * triple. 12 color-only ops total: exposure / contrast / saturation /
 * temperature / tint / fade / compressionAmount / compressionRange /
 * printContrast / cyan / magenta / yellow.
 *
 * This TS implementation is the canonical reference for the Swift port shipped
 * via the v1.4 in-app "Look → .cube export" lane. Both must produce
 * byte-identical output at Float32 precision; that contract is enforced by
 * Tier 1 fixtures in Phase 2 PR.
 *
 * Direct float64 port of:
 *   apps/capacitor-film-lab-ios/ios/App/App/FilmtoneExportSidecarBuilder.swift
 *     applyBaseGrade / applyFilmCompression / applyPrintStage
 * which is itself the CPU equivalent of the GPU stages in
 * `FilmtoneExportSession.swift`. Keeping this file aligned with the Swift
 * sidecar baker is the SSOT contract.
 */

/** RGB triple. All channels in linear-display Rec.709 [0, 1] domain. */
interface RGB {
    r: number;
    g: number;
    b: number;
}
/**
 * Pull only the 12 color-only fields from a full `Phase0Params`. Used to make
 * the baker contract independent from spatial fields (halation / bloom /
 * grain / vignette) that cannot be expressed in a 3D color cube.
 */
interface BakeColorParams {
    exposure: number;
    contrast: number;
    saturation: number;
    temperature: number;
    tint: number;
    fade: number;
    compressionAmount: number;
    compressionRange: number;
    printContrast: number;
    cyan: number;
    magenta: number;
    yellow: number;
}
declare const BAKE_COLOR_PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "fade", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow"];
/**
 * Neutral (identity) color params. Baking with these yields the identity cube
 * within float64 precision. Used by Phase 1 placeholder cubes and as the test
 * baseline.
 */
declare const BAKE_COLOR_IDENTITY: BakeColorParams;
declare function pickBakeColorParams(params: Pick<Phase0Params, keyof BakeColorParams>): BakeColorParams;
/**
 * Compose Stages 2 → 3 → 9 on a single Rec.709 RGB triple. Output stays in
 * Rec.709 [0, 1].
 *
 * Note: the iOS pipeline runs Stage 9 (printStage) AFTER the creative LUT
 * stage at runtime. To represent the entire color expression in a single
 * cube, the baker composes all three stages here. When a baked cube is
 * applied as a creative LUT at runtime, the host preset's 12 color params
 * MUST be neutralized via paramOverrides so the look does not double-apply.
 * That neutralization contract is enforced by `creative-pack-01.ts` per Look
 * (and validated by Phase 2 fixture comparisons).
 */
declare function bakeColorOnly(rgb: RGB, params: BakeColorParams): RGB;

/**
 * 3D LUT cube grid walker. Generates a `size³` cube by sampling the input
 * domain `[0, 1]³` on a uniform grid and running each sample through a
 * pure transform function (typically `bakeColorOnly`).
 *
 * Layout matches the Adobe `.cube` standard and `cube-parser.ts`:
 *   index `i = b * size² + g * size + r` for grid coordinate `(r, g, b)`,
 *   i.e. R varies fastest, then G, then B.
 */

declare const CREATIVE_CUBE_DEFAULT_SIZE: 33;
interface CreativeCube {
    size: number;
    /** RGB triples packed `[r0, g0, b0, r1, g1, b1, ...]`, length = `size³ × 3`. */
    data: Float32Array;
}
/**
 * Run the baker over a `size × size × size` grid in Rec.709 [0, 1] and
 * return the resulting cube. R varies fastest in the output index.
 *
 * `transform` defaults to `bakeColorOnly` so the baker is the conventional
 * call-site; pass an alternate function only for tests / experiments.
 */
declare function makeCreativeCube(input: {
    params: BakeColorParams;
    size?: number;
    transform?: (rgb: RGB, params: BakeColorParams) => RGB;
}): CreativeCube;
/** Convenience: identity cube (no transform). Used for Phase 1 placeholders. */
declare function makeIdentityCube(size?: number): CreativeCube;
/**
 * Maximum |output - input| along the grid diagonal (R = G = B). Cheap
 * pre-screen for "is this cube near identity?" used by tests and the
 * orchestrator's Lipschitz pre-check.
 */
declare function diagonalMaxDelta(cube: CreativeCube): number;

/**
 * Adobe `.cube` text serializer. Produces output that round-trips through
 * `cube-parser.ts` byte-identically (modulo float text precision). Used by
 * the v1.4 Creative LUT Pack baker to emit bundled cube assets.
 *
 * Format reference: Adobe Cube LUT Specification 1.0 (2013).
 */

interface SerializeCubeOptions {
    /** Single-line title comment emitted as `TITLE "<value>"`. */
    title: string;
    /** Decimal places per channel value. Default 6 (matches IWLTBAP / Lattice). */
    precision?: number;
    /** Trailing comment lines emitted before the data (each prefixed by `# `). */
    comments?: string[];
}
/**
 * Serialize a `CreativeCube` to Adobe `.cube` text. Emits the header
 * (TITLE / LUT_3D_SIZE / DOMAIN_MIN / DOMAIN_MAX) followed by R-fastest
 * RGB triples, one per line. Trailing newline included.
 */
declare function serializeCreativeCubeToText(cube: CreativeCube, options: SerializeCubeOptions): string;

declare const CREATIVE_PACK_01_STONE_TRANSFORM: "filmtone-stone-palermo-reference-v1";
declare const CREATIVE_PACK_01_URBAN_TRANSFORM: "filmtone-urban-palermo-green-density-v1";
type CreativePack01SourceTransform = typeof CREATIVE_PACK_01_STONE_TRANSFORM | typeof CREATIVE_PACK_01_URBAN_TRANSFORM;
/**
 * Stone — fingerprint-only transform applied to the Palermo Reference source.
 * Intentionally tiny: produces a non-byte-identical cube that stays within
 * 0.006 / channel of source. Stone's role is the faithful Palermo Reference
 * base; per-Look character lives in the bundled cube selection, not here.
 */
declare function applyStoneFingerprintTransform(sourceCube: CreativeCube): CreativeCube;
/**
 * Urban — Filmtone "cool urban density" character applied on top of the
 * Palermo Green Density source. The source already carries Palermo's color
 * density; this transform layers Filmtone's signature urban personality:
 *
 *   - Cool shadow tilt with a slight black-point lift so shadows stay
 *     readable rather than crushed.
 *   - Gray/green concrete cast on neutral midtones (gated by chroma so
 *     saturated colors — red signage, skin — keep their hue).
 *   - Highlights left mostly intact (clean Palermo brights).
 *
 * Magnitudes are tuned so neutrals shift by ~0.02–0.03 / channel — a clearly
 * perceptible change in the everyday photo path that previously read as
 * byte-identical with Reference, while saturated regions remain restrained
 * to avoid the "feels cheap" outcome the user flagged in earlier iterations.
 */
declare function applyUrbanCoolDensityTransform(sourceCube: CreativeCube): CreativeCube;
declare function applyCreativePack01SourceTransform(sourceCube: CreativeCube, transformName: CreativePack01SourceTransform): CreativeCube;

/**
 * Filmtone iOS Creative LUT Pack 01 — definitions.
 *
 * Each Look in this pack consists of:
 *   - `slug`: stable filename slug (kebab-case). Used as both the bundled
 *     resource filename stem and the `bundledSlug` in sidecar provenance.
 *   - `englishName`: catalog default; iOS localizes via `FilmtoneStrings`.
 *   - `canonicalUUID`: stable UUID v4 in the `FB1A0001-0000-4000-8000-...`
 *     namespace. Mirrors the Swift `BuiltInLookUUID` enum so a single id is
 *     shared across TS / Swift / sidecar.
 *   - `basePreset`: one of the 4 locked iOS preset names. The Look chip's
 *     non-color expression (halation / bloom / grain / vignette / glow trio)
 *     comes from this preset's spatial fields at runtime. Locked to the iOS
 *     preset whitelist so this pack does not require regenerating
 *     `FilmtonePhase0Generated.swift`.
 *   - `colorParams`: 12-op color parameters baked INTO the cube at build
 *     time. These are intentionally NOT applied at runtime — `paramOverrides`
 *     neutralizes them plus the runtime v2 split-tone fields so the cube
 *     carries the entire color expression. (See `bake-color-only.ts` doc on
 *     the non-double-apply contract.)
 *   - `paramOverrides`: spatial / glow overrides applied AT RUNTIME on top
 *     of `basePreset`. The 12 color-op fields and v2 split-tone strengths
 *     here are pinned to neutral so the runtime path leaves color to the cube.
 *   - `strength`: default LUT intensity for `applyCreativeLutStage` — the
 *     user can still adjust via the existing strength slider.
 *
 * The bundled cubes carry color expression; runtime `paramOverrides` carry
 * Filmtone's optical expression while keeping the color-only fields neutral.
 */

declare const CREATIVE_PACK_01_ID: "creative-pack-01";
declare const CREATIVE_PACK_01_BAKER_VERSION: "1.4.0-stone-urban-distinct";
declare const CREATIVE_PACK_01_CUBE_SIZE: 65;
interface CreativePackLook {
    readonly slug: string;
    readonly englishName: string;
    readonly canonicalUUID: string;
    readonly basePreset: FilmtoneIosPresetName;
    readonly colorParams: BakeColorParams;
    readonly paramOverrides: Partial<Record<Phase0ParamKey, number>>;
    readonly strength: number;
    readonly sourceCubeTransform?: CreativePack01SourceTransform;
}
/**
 * Build the runtime `paramOverrides` patch for a Look. Pins all 12 baked
 * color-op fields plus the v2 split-tone strengths to neutral to honor the
 * non-double-apply contract; merges any spatial overrides (halation / bloom /
 * grain / etc) the Look declares.
 */
declare function buildLookParamOverrides(spatial: Partial<Record<Phase0ParamKey, number>>): Partial<Record<Phase0ParamKey, number>>;
/**
 * Pack 01 Look catalog. Stone is the Palermo Reference base; Urban is the
 * Palermo Green Density derivative; Noir is Filmtone's toned print
 * monochrome recipe. External reference cubes are build-only inputs; the
 * exported product catalog carries the generated Filmtone recipe and never
 * direct reference cube paths.
 *
 * `colorParams` is baked into the generated 65³ cube. Runtime
 * `paramOverrides` still neutralizes the host color ops so the bundled cube is
 * the sole color expression, while Filmtone's optical controls carry the
 * product signature.
 */
declare const CREATIVE_PACK_01_LOOKS: readonly CreativePackLook[];
declare function findCreativePack01Look(slug: string): CreativePackLook | undefined;

/**
 * Source profile conversion (Camera Profiles for Log → Rec.709 SDR).
 *
 * Catalog + math ported from `FilmtoneSourceProfileMath.swift` /
 * `FilmtoneSourceProfileCatalog.swift` so Filmtone Desktop's Log Conversion
 * lane (lut1) gets the same built-in input transforms iOS ships in v1.4:
 * Apple Log / Apple Log 2 / DJI D-Log / DJI D-Log M / Canon C-Log /
 * Canon Log 3 + Cinema Gamut / Panasonic V-Log / Sony S-Log3, plus
 * Rec.709 passthrough.
 *
 * Math constants are copied verbatim from the Swift SSOT. Drift between
 * Swift and TS is a hard product-quality bug — fixture parity tests in
 * `source-profile-conversion.test.ts` read the iOS reference fixtures
 * (`apps/capacitor-film-lab-ios/Tests/Fixtures/source-profile/<curve>/`)
 * to lock TS output against Swift output.
 *
 * `buildSourceProfileLut` returns a Float32Array in the same RGBA layout
 * `parseCube` produces (size³ × 4 floats, alpha = 1, sample-major with R
 * fastest), so `viewport.setLUT1` / WebGPU `Lut3DTexture.upload` accept
 * built-in and custom `.cube` data interchangeably.
 */
type SourceProfileCurve = "apple-log" | "apple-log-2" | "dji-dlog" | "dji-dlog-m" | "canon-clog" | "canon-log3-cinema-gamut" | "panasonic-vlog" | "sony-slog3";
type SourceProfileImplKind = "nil-profile" | "native-policy" | "synthesized";
type SourceProfileId = "built-in:source-profile.rec709" | "built-in:source-profile.apple-log" | "built-in:source-profile.apple-log-2" | "built-in:source-profile.dji-dlog" | "built-in:source-profile.dji-dlog-m" | "built-in:source-profile.canon-clog" | "built-in:source-profile.canon-log3-cinema-gamut" | "built-in:source-profile.panasonic-vlog" | "built-in:source-profile.sony-slog3";
interface SourceProfileCatalogEntry {
    readonly id: SourceProfileId;
    readonly displayName: string;
    readonly curve: SourceProfileCurve | null;
    readonly impl: SourceProfileImplKind;
    readonly builtIn: true;
    readonly immutable: true;
}
declare const SOURCE_PROFILE_CATALOG: readonly SourceProfileCatalogEntry[];
declare function getSourceProfile(id: string): SourceProfileCatalogEntry | null;
interface BuiltSourceProfileLut {
    readonly id: SourceProfileId;
    readonly displayName: string;
    readonly data: Float32Array;
    readonly size: number;
}
/**
 * Generate the built-in conversion LUT for the given catalog entry.
 *
 * Returns null for the Rec.709 nil-profile (= passthrough; callers should
 * `viewport.clearLUT1()` instead of uploading an identity cube) and for
 * unknown ids.
 */
declare function buildSourceProfileLut(id: string, size?: number): BuiltSourceProfileLut | null;

declare const DETAIL_SOFTNESS_EFFECTIVE_MAX = 0.34;
interface DetailSoftnessUniforms {
    effectiveDetailSoftness: number;
    kernelRadiusPx: number;
    chromaAttenScale: number;
    edgeGuardLo: number;
    edgeGuardHi: number;
    highlightBias: number;
}
interface DetailSoftnessOptions {
    sourceDetailBias?: number;
}
declare function deriveDetailSoftnessUniforms(detailSoftness: number, opts?: DetailSoftnessOptions): DetailSoftnessUniforms;

type SourceDetailConfidence = "high" | "medium" | "low" | "none";
type SourceDetailTransferClass = "rec709-consumer" | "rec709-cinema" | "log-consumer" | "log-cinema" | "unknown";
interface SourceDetailProfile {
    /**
     * Stable diagnostic id for the resolved source class. Safe to log /
     * surface in developer sidecar; not a user-facing label.
     */
    readonly id: "iphone-sdr-hevc" | "apple-log" | "dji-action" | "gopro-action" | "sony-slog3" | "canon-clog" | "panasonic-vlog" | "rec709-unknown" | "log-unknown" | "metadata-missing";
    readonly confidence: SourceDetailConfidence;
    readonly transferClass: SourceDetailTransferClass;
    /**
     * Recommended additive softness bias. `0 ≤ recommendedBias ≤
     * DETAIL_SOFTNESS_EFFECTIVE_MAX`. Pass to
     * `deriveDetailSoftnessUniforms(detailSoftness, { sourceDetailBias })`.
     */
    readonly recommendedBias: number;
    /**
     * Mirror of `DETAIL_SOFTNESS_EFFECTIVE_MAX` so callers do not have to
     * import the renderer constant alongside the resolver result.
     */
    readonly effectiveMax: number;
    /**
     * Short, stable reason string. Suitable for diagnostic logging and
     * sidecar inspection. Not localized.
     */
    readonly reason: string;
}
interface SourceDetailCompensationInput {
    readonly cameraMake?: string | null;
    readonly cameraModel?: string | null;
    readonly logTransferFunction?: SourceLogTransferFunction | null;
    readonly inputTransformPolicy?: SourceInputTransformPolicy | null;
    readonly codecFamily?: SourceCodecFamily | null;
    readonly colorClass?: SourceColorClass | null;
    readonly sourceProfileId?: SourceProfileId | string | null;
}
/**
 * Resolve a `SourceDetailProfile` for the given metadata bundle. Pure,
 * deterministic, and side-effect free.
 *
 * The resolver intentionally treats unknown / partial metadata as a
 * conservative passthrough. The only way to coax a positive bias is for at
 * least one explicit signal (camera make, log transfer, or
 * built-in source-profile id) to match a known class.
 */
declare function resolveSourceDetailCompensation(input?: SourceDetailCompensationInput): SourceDetailProfile;

export { BAKE_COLOR_IDENTITY, BAKE_COLOR_PARAM_KEYS, type BakeColorParams, type BehaviorProfile, type BenchmarkRow, type BenchmarkRowInput, type BenchmarkSaveResult, type BenchmarkVisualFloor, type BuiltSourceProfileLut, CREATIVE_CUBE_DEFAULT_SIZE, CREATIVE_PACK_01_BAKER_VERSION, CREATIVE_PACK_01_CUBE_SIZE, CREATIVE_PACK_01_ID, CREATIVE_PACK_01_LOOKS, CREATIVE_PACK_01_STONE_TRANSFORM, CREATIVE_PACK_01_URBAN_TRANSFORM, type CameraOptics, type CameraOpticsSource, type CreativeCube, type CreativePack01SourceTransform, type CreativePackLook, type CubeLUT, DEFAULT_QUICK_STATE, DETAIL_SOFTNESS_EFFECTIVE_MAX, type DetailSoftnessOptions, type DetailSoftnessUniforms, FILMTONE_DEFAULT_BASE_PRESET, FILMTONE_SOFT_FINISH_PATCH, FILM_GRAIN_INTENSITY_MAX, FILM_LAB_DEFAULT_HIGHLIGHT_HUE, FILM_LAB_DEFAULT_SHADOW_HUE, type FilmLabDepthTrackInput, type FilmLabParamsValidated, type FilmLookGradeInputProps, type FilmLookSpikeInputProps, IOS_PHASE0_BENCHMARK_SLOTS, IOS_PHASE0_OUTPUT_CODEC, IOS_PHASE0_OUTPUT_FPS, IOS_PHASE0_OUTPUT_LONG_EDGE, IOS_PHASE0_PARAM_KEYS, IOS_PHASE0_PRESET_IDS, IOS_PHASE0_SCHEMA_VERSION, IOS_PHASE0_SOURCE_CAPS, IOS_PHASE0_SOURCE_DURATION_CAP_SEC, IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES, IOS_PHASE0_SOURCE_LONG_EDGE_CAP, type IosHdrPreparationPolicy, type IosHdrPreparationStrategy, type IosPhase0AssetRef, type IosPhase0BenchmarkRecord, type IosPhase0BenchmarkSlot, type IosPhase0ExportPayload, type IosPhase0ExportResult, type IosPhase0ExportSettings, type IosPhase0LocalProject, type IosPhase0ParamKey, type IosPhase0Params, type IosPhase0PickedLutFile, type IosPhase0PickedSource, type IosPhase0SerializableLut, type IosPhase0SourceInfo, type IosPhase0SourceKind, LEGACY_HIGHLIGHT_TONE_MAGNITUDE, LEGACY_SHADOW_TONE_MAGNITUDE, LOOK_ID_BY_PRESET, OPTICAL_FILTER_DISCLAIMER, OPTICAL_FILTER_PARAM_KEYS, OPTICAL_FILTER_PROFILES, type OpticalAnalyzerProvider, type OpticalFamily, type OpticalFilterBehavior, type OpticalFilterDensity, type OpticalFilterFamily, type OpticalFilterParamKey, type OpticalFilterParamPatch, type OpticalFilterProfile, type OpticalFilterProfileId, type OpticalRecipeId, type OpticalRecommendationV1, PARAM_KEYS, PHASE0_APPROX_SOURCE_LONG_EDGE_MAX, PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES, PHASE0_BENCHMARK_GATES, PHASE0_MAX_SOURCE_DURATION_SEC, PHASE0_OUTPUT_PROFILE, PHASE0_PARAM_KEYS, PHASE0_PRESET_DEFAULT, PHASE0_PRESET_STRENGTH_DEFAULT, PHASE0_RGB_SHIFT_MAX, PHASE0_SCHEMA_VERSION, PRESETS, PRESET_BUTTONS, PRESET_VERSION, type PackedCubeLut2D, type ParamKey, type Params, type ParsedBenchmarkRow, type ParsedCubeLut, type Phase0ExportBenchmarkRecord, type Phase0ExportProgress, type Phase0ExportRequest, type Phase0ExportResult, type Phase0ExportStage, type Phase0MezzanineProfileVariant, type Phase0OutputProfile, type Phase0ParamKey, type Phase0Params, type Phase0PreviewRenderResult, type Phase0ProjectLut, type Phase0ProjectState, type Phase0QuickTarget, type Phase0RenderMode, type PickedLutFile, type PresetName, QUICK_AXIS_DEFAULT_RANGE, QUICK_AXIS_IDS, type QuickAxisId, type QuickState, type RGB, SOURCE_PROFILE_CATALOG, type SceneAnalysisState, type SceneDescriptorV1, type SerializeCubeOptions, type SourceColorClass, type SourceColorMetadata, type SourceDetailCompensationInput, type SourceDetailConfidence, type SourceDetailProfile, type SourceDetailTransferClass, type SourceDisplayGeometry, type SourceInfo, type SourceKind, type SourceProbe, type SourceProfileCatalogEntry, type SourceProfileCurve, type SourceProfileId, type SourceProfileImplKind, type SourceVideoMetadata, type SourceVideoTimingMetadata, applyCreativePack01SourceTransform, applyQuickStateToParams, applyQuickStateToPhase0Params, applyStoneFingerprintTransform, applyUrbanCoolDensityTransform, assertPhase0SourceProbeWithinCaps, bakeColorOnly, benchmarkMarkdownTableHeader, buildBenchmarkRow, buildLookParamOverrides, buildOpticalFilterParamPatch, buildOpticalParamPatch, buildPhase0ExportRequest, buildSourceProfileLut, cameraOpticsSchema, chromaUnitFromHueDegrees, clampGrainIntensity, cloneParams, coerceQuickState, createDefaultFilmLookGradeProps, createDefaultPhase0Params, createFilmtoneDefaultParams, createFilmtoneDefaultPhase0Params, createIosPhase0SerializableLut, createPhase0ProjectState, deriveDetailSoftnessUniforms, deserializeCubeLutData, diagonalMaxDelta, filmLabDepthTrackSchema, filmLabParamsSchema, filmLookGradeDefaultProps, filmLookGradeInputSchema, filmLookSpikeDefaultProps, filmLookSpikeInputSchema, findCreativePack01Look, findMatchingPreset, formatBenchmarkRow, getIosPhase0SourceCapViolations, getOpticalFilterProfile, getPhase0SourceCapViolations, getSourceProfile, gradeMatchesPreset, halationHueToHex, hslToRgb01, interpolatePhase0PresetParams, iosPhase0AssetRefSchema, iosPhase0BenchmarkRecordSchema, iosPhase0ExportPayloadSchema, iosPhase0ExportResultSchema, iosPhase0ExportSettingsSchema, iosPhase0LocalProjectSchema, iosPhase0ParamsSchema, iosPhase0PickedLutFileSchema, iosPhase0PickedSourceSchema, iosPhase0PresetIdSchema, iosPhase0SerializableLutSchema, iosPhase0SourceInfoSchema, iosPhase0SourceKindSchema, iosPhase0ThermalStateSchema, lookIdForPreset, makeCreativeCube, makeIdentityCube, mergePhase0Params, nearestHueDegreesToDirection, packCubeLutToFloatRgbaGrid, parseBenchmarkRow, parseCube, phase0ParamsSchema, phase0ProjectLutSchema, phase0ProjectSchema, phase0QuickStateSchema, pickBakeColorParams, pickIosPhase0Params, pickPhase0Params, quickStateSchema, recommendOpticalFinish, resolveSourceDetailCompensation, serializeCreativeCubeToText, serializeCubeLut };
