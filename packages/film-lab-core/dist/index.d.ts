import { z } from 'zod';

/**
 * Film Lab のグレード数値パラメータ定義（ブラウザ・Remotion 共通の単一の真実）
 */
declare const PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "lensSoftness", "grainIntensity", "grainRadialMix", "grainSize", "vignette", "bloomThreshold", "bloomStrength", "bloomRadius", "diffusion", "halationIntensity", "halationSpread", "halationHue", "halationThreshold", "halationRadius", "bloomSoftKnee", "halationSoftKnee", "fade", "highlights", "shadows", "shadowTone", "highlightTone", "shadowHue", "highlightHue", "compressionAmount", "compressionRange", "printContrast", "cyan", "magenta", "yellow", "motionBlurAmount", "shutterAngle", "trailIntensity", "dustAmount", "scratchAmount", "shaftIntensity", "shaftDecay", "shaftOriginX", "shaftOriginY", "crossFilterStrength", "crossFilterSpikes", "crossFilterAngle", "crossFilterLength", "crossFilterThreshold", "crossFilterChromatic", "crossFilterSizeLimit", "crossFilterRandomness", "crossFilterHardMode", "crossFilterMinSpacing"];
type ParamKey = (typeof PARAM_KEYS)[number];
interface Params {
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
    /** グレイン粒子の粗さ（0=極細/高周波、1=極粗/低周波）。各プリセットで固有のフィルム感を表現。 */
    grainSize: number;
    vignette: number;
    bloomThreshold: number;
    bloomStrength: number;
    bloomRadius: number;
    /** Pro-Mist 的な全画面光拡散（0=オフ、1=最大ヘイズ）。Bloom/Halation とは独立。 */
    diffusion: number;
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
}
declare function cloneParams(params: Params): Params;

/**
 * 組み込みプリセット（Next Film Lab と同一数値）
 *
 * grainIntensity は composite で径方向マスク（中心弱・周辺強）が掛かるため、
 * グレインを使うプリセットのみ体感が薄くならないようわずかに上げている（2026-03-30）。
 * grainRadialMix は Pro で 0〜1 調整可。プリセット既定は 1（周辺比重オン）。
 */
declare const PRESETS: {
    reset: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    /**
     * cinematic プリセット（v2・2026-03-31）
     * @description 初見のフィルター感とシアン肌を抑えつつ Teal & Orange の意図は維持。変更理由はリポ外ドキュメントに記載可。
     */
    cinematic: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    portra: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    gold200: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    pro400h: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    bw: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    ektar100: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    superia400: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    cinestill800t: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
    /**
     * Velvia 50 プリセット（v1・2026-04-02）
     * @description Fujifilm Velvia 50 スライドポジフィルム。高彩度・高コントラスト・極細粒・ハレーションなし。
     * fade=0 でポジらしい黒沈みを表現。saturation/contrast は Velvia の代名詞の鮮烈さに合わせた。
     */
    velvia50: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        lensSoftness: number;
        grainIntensity: number;
        grainRadialMix: number;
        grainSize: number;
        vignette: number;
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
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
        compressionAmount: number;
        compressionRange: number;
        printContrast: number;
        cyan: number;
        magenta: number;
        yellow: number;
        motionBlurAmount: number;
        shutterAngle: number;
        trailIntensity: number;
        dustAmount: number;
        scratchAmount: number;
        shaftIntensity: number;
        shaftDecay: number;
        shaftOriginX: number;
        shaftOriginY: number;
        crossFilterStrength: number;
        crossFilterSpikes: number;
        crossFilterAngle: number;
        crossFilterLength: number;
        crossFilterThreshold: number;
        crossFilterChromatic: number;
        crossFilterSizeLimit: number;
        crossFilterRandomness: number;
        crossFilterHardMode: number;
        crossFilterMinSpacing: number;
    };
};
type PresetName = keyof typeof PRESETS;
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
 * 単体のグレードパラメータ（Film Lab の Params と同一形）
 */
declare const filmLabParamsSchema: z.ZodObject<{
    [x: string]: z.core.$ZodType<unknown, unknown, z.core.$ZodTypeInternals<unknown, unknown>>;
}, z.core.$strip>;
type FilmLabParamsValidated = z.infer<typeof filmLabParamsSchema>;
/**
 * Remotion Composition 向け: ルック ID + バージョン + 数値グレード
 */
declare const filmLookGradeInputSchema: z.ZodObject<{
    lookPresetId: z.ZodString;
    presetVersion: z.ZodLiteral<"v1">;
    grade: z.ZodObject<{
        [x: string]: z.core.$ZodType<unknown, unknown, z.core.$ZodTypeInternals<unknown, unknown>>;
    }, z.core.$strip>;
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

declare const QUICK_AXIS_IDS: readonly ["filmCharacter", "era", "dynamics"];
type QuickAxisId = (typeof QUICK_AXIS_IDS)[number];
type QuickState = Record<QuickAxisId, number>;
interface Phase0QuickTarget {
    exposure: number;
    contrast: number;
    saturation: number;
    temperature: number;
    tint: number;
    fade: number;
    vignette: number;
    grainIntensity: number;
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

declare const PHASE0_SCHEMA_VERSION: 1;
declare const PHASE0_PRESET_DEFAULT = "cinematic";
declare const PHASE0_PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "fade", "vignette", "grainIntensity"];
type Phase0ParamKey = (typeof PHASE0_PARAM_KEYS)[number];
type Phase0Params = Pick<Params, Phase0ParamKey>;
declare const PHASE0_MAX_SOURCE_DURATION_SEC: number;
declare const PHASE0_APPROX_SOURCE_LONG_EDGE_MAX = 3840;
declare const PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES: number;
declare const PHASE0_OUTPUT_PROFILE: {
    readonly longEdge: 1920;
    readonly fps: 30;
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
    fade: z.ZodDefault<z.ZodNumber>;
    vignette: z.ZodDefault<z.ZodNumber>;
    grainIntensity: z.ZodDefault<z.ZodNumber>;
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
declare const phase0ProjectSchema: z.ZodObject<{
    schemaVersion: z.ZodLiteral<1>;
    projectId: z.ZodString;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
    presetName: z.ZodString;
    quickState: z.ZodDefault<z.ZodObject<{
        filmCharacter: z.ZodNumber;
        era: z.ZodNumber;
        dynamics: z.ZodNumber;
    }, z.core.$strip>>;
    params: z.ZodObject<{
        exposure: z.ZodDefault<z.ZodNumber>;
        contrast: z.ZodDefault<z.ZodNumber>;
        saturation: z.ZodDefault<z.ZodNumber>;
        temperature: z.ZodDefault<z.ZodNumber>;
        tint: z.ZodDefault<z.ZodNumber>;
        fade: z.ZodDefault<z.ZodNumber>;
        vignette: z.ZodDefault<z.ZodNumber>;
        grainIntensity: z.ZodDefault<z.ZodNumber>;
    }, z.core.$strip>;
    lut: z.ZodDefault<z.ZodNullable<z.ZodObject<{
        title: z.ZodString;
        size: z.ZodNumber;
        data: z.ZodArray<z.ZodNumber>;
        intensity: z.ZodDefault<z.ZodNumber>;
    }, z.core.$strip>>>;
    output: z.ZodObject<{
        longEdge: z.ZodLiteral<1920>;
        fps: z.ZodLiteral<30>;
        codec: z.ZodLiteral<"h264">;
        container: z.ZodLiteral<"mp4">;
        preserveAudio: z.ZodDefault<z.ZodBoolean>;
    }, z.core.$strip>;
}, z.core.$strip>;
type Phase0ProjectLut = z.infer<typeof phase0ProjectLutSchema>;
type Phase0ProjectState = z.infer<typeof phase0ProjectSchema>;
declare function pickPhase0Params(params: Params): Phase0Params;
declare function createDefaultPhase0Params(presetName?: PresetName): Phase0Params;
declare function mergePhase0Params(base: Phase0Params, patch: Partial<Phase0Params>): Phase0Params;
declare function createPhase0ProjectState(presetName?: PresetName): Phase0ProjectState;

type SourceKind = "image" | "video";
interface SourceInfo {
    uri: string;
    filename: string;
    kind: SourceKind;
    mimeType?: string;
}
interface SourceProbe extends SourceInfo {
    width?: number;
    height?: number;
    durationSec?: number;
    fileSizeBytes?: number;
    codec?: string;
    frameRate?: number;
}
interface ParsedCubeLut {
    title: string;
    size: number;
    data: number[];
    intensity: number;
}
interface PickedLutFile {
    filename: string;
    text: string;
    uri?: string;
}
type Phase0ExportStage = "preflight" | "reading" | "rendering" | "writing" | "completed";
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
}
declare function serializeCubeLut(lut: CubeLUT, options?: {
    title?: string;
    intensity?: number;
}): ParsedCubeLut;
declare function deserializeCubeLutData(lut: ParsedCubeLut): Float32Array;
declare function getPhase0SourceCapViolations(probe: SourceProbe): string[];
declare function assertPhase0SourceProbeWithinCaps(probe: SourceProbe): void;
declare function buildPhase0ExportRequest(options: {
    source: SourceInfo;
    probe?: SourceProbe | null;
    project: Pick<Phase0ProjectState, "presetName" | "quickState" | "params" | "lut">;
    output?: Partial<Phase0OutputProfile>;
}): Phase0ExportRequest;

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

declare const IOS_PHASE0_SCHEMA_VERSION: 1;
declare const IOS_PHASE0_PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "fade", "vignette", "grainIntensity"];
type IosPhase0ParamKey = (typeof IOS_PHASE0_PARAM_KEYS)[number];
type IosPhase0Params = Pick<Params, IosPhase0ParamKey>;
declare const iosPhase0ParamsSchema: z.ZodType<IosPhase0Params>;
declare const IOS_PHASE0_OUTPUT_CODEC: "h264-mp4";
declare const IOS_PHASE0_OUTPUT_LONG_EDGE = 1920;
declare const IOS_PHASE0_OUTPUT_FPS = 30;
declare const IOS_PHASE0_SOURCE_DURATION_CAP_SEC: number;
declare const IOS_PHASE0_SOURCE_LONG_EDGE_CAP = 3840;
declare const IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES: number;
declare const IOS_PHASE0_SOURCE_CAPS: {
    readonly durationSec: number;
    readonly longEdge: 3840;
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
}, z.core.$strip>;
type IosPhase0SerializableLut = z.infer<typeof iosPhase0SerializableLutSchema>;
declare function createIosPhase0SerializableLut(input: {
    cube: CubeLUT;
    name: string;
    intensity?: number;
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
    audioCodec: z.ZodOptional<z.ZodString>;
    frameRate: z.ZodOptional<z.ZodNumber>;
    hasAudio: z.ZodOptional<z.ZodBoolean>;
}, z.core.$strip>;
type IosPhase0SourceInfo = z.infer<typeof iosPhase0SourceInfoSchema>;
declare const iosPhase0PresetIdSchema: z.ZodEnum<{
    reset: "reset";
    cinematic: "cinematic";
    portra: "portra";
    gold200: "gold200";
    pro400h: "pro400h";
    bw: "bw";
    ektar100: "ektar100";
    superia400: "superia400";
    cinestill800t: "cinestill800t";
    velvia50: "velvia50";
}>;
declare const iosPhase0ExportSettingsSchema: z.ZodObject<{
    codec: z.ZodDefault<z.ZodLiteral<"h264-mp4">>;
    outputLongEdge: z.ZodDefault<z.ZodNumber>;
    outputFps: z.ZodDefault<z.ZodLiteral<30>>;
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
        cinematic: "cinematic";
        portra: "portra";
        gold200: "gold200";
        pro400h: "pro400h";
        bw: "bw";
        ektar100: "ektar100";
        superia400: "superia400";
        cinestill800t: "cinestill800t";
        velvia50: "velvia50";
    }>;
    params: z.ZodType<IosPhase0Params, unknown, z.core.$ZodTypeInternals<IosPhase0Params, unknown>>;
    inputLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        name: z.ZodString;
        title: z.ZodOptional<z.ZodString>;
        size: z.ZodNumber;
        intensity: z.ZodDefault<z.ZodNumber>;
        domainMin: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        domainMax: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        rgbaData: z.ZodArray<z.ZodNumber>;
    }, z.core.$strip>>>;
    creativeLut: z.ZodOptional<z.ZodNullable<z.ZodObject<{
        name: z.ZodString;
        title: z.ZodOptional<z.ZodString>;
        size: z.ZodNumber;
        intensity: z.ZodDefault<z.ZodNumber>;
        domainMin: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        domainMax: z.ZodOptional<z.ZodTuple<[z.ZodNumber, z.ZodNumber, z.ZodNumber], null>>;
        rgbaData: z.ZodArray<z.ZodNumber>;
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
        outputFps: z.ZodDefault<z.ZodLiteral<30>>;
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
    schemaVersion: z.ZodLiteral<1>;
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
    schemaVersion: z.ZodLiteral<1>;
    projectId: z.ZodString;
    createdAt: z.ZodString;
    updatedAt: z.ZodString;
    presetId: z.ZodEnum<{
        reset: "reset";
        cinematic: "cinematic";
        portra: "portra";
        gold200: "gold200";
        pro400h: "pro400h";
        bw: "bw";
        ektar100: "ektar100";
        superia400: "superia400";
        cinestill800t: "cinestill800t";
        velvia50: "velvia50";
    }>;
    params: z.ZodType<IosPhase0Params, unknown, z.core.$ZodTypeInternals<IosPhase0Params, unknown>>;
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
        outputFps: z.ZodDefault<z.ZodLiteral<30>>;
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
declare function pickIosPhase0Params(params: Params): IosPhase0Params;
declare function getIosPhase0SourceCapViolations(source: Pick<IosPhase0SourceInfo, "width" | "height" | "durationSec" | "fileSizeBytes">): string[];

export { type BenchmarkRow, type BenchmarkRowInput, type BenchmarkSaveResult, type BenchmarkVisualFloor, type CubeLUT, DEFAULT_QUICK_STATE, FILM_LAB_DEFAULT_HIGHLIGHT_HUE, FILM_LAB_DEFAULT_SHADOW_HUE, type FilmLabParamsValidated, type FilmLookGradeInputProps, type FilmLookSpikeInputProps, IOS_PHASE0_BENCHMARK_SLOTS, IOS_PHASE0_OUTPUT_CODEC, IOS_PHASE0_OUTPUT_FPS, IOS_PHASE0_OUTPUT_LONG_EDGE, IOS_PHASE0_PARAM_KEYS, IOS_PHASE0_SCHEMA_VERSION, IOS_PHASE0_SOURCE_CAPS, IOS_PHASE0_SOURCE_DURATION_CAP_SEC, IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES, IOS_PHASE0_SOURCE_LONG_EDGE_CAP, type IosPhase0AssetRef, type IosPhase0BenchmarkRecord, type IosPhase0BenchmarkSlot, type IosPhase0ExportPayload, type IosPhase0ExportResult, type IosPhase0ExportSettings, type IosPhase0LocalProject, type IosPhase0ParamKey, type IosPhase0Params, type IosPhase0PickedLutFile, type IosPhase0PickedSource, type IosPhase0SerializableLut, type IosPhase0SourceInfo, type IosPhase0SourceKind, LEGACY_HIGHLIGHT_TONE_MAGNITUDE, LEGACY_SHADOW_TONE_MAGNITUDE, LOOK_ID_BY_PRESET, PARAM_KEYS, PHASE0_APPROX_SOURCE_LONG_EDGE_MAX, PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES, PHASE0_BENCHMARK_GATES, PHASE0_MAX_SOURCE_DURATION_SEC, PHASE0_OUTPUT_PROFILE, PHASE0_PARAM_KEYS, PHASE0_PRESET_DEFAULT, PHASE0_SCHEMA_VERSION, PRESETS, PRESET_BUTTONS, PRESET_VERSION, type PackedCubeLut2D, type ParamKey, type Params, type ParsedBenchmarkRow, type ParsedCubeLut, type Phase0ExportBenchmarkRecord, type Phase0ExportProgress, type Phase0ExportRequest, type Phase0ExportResult, type Phase0ExportStage, type Phase0OutputProfile, type Phase0ParamKey, type Phase0Params, type Phase0ProjectLut, type Phase0ProjectState, type Phase0QuickTarget, type PickedLutFile, type PresetName, QUICK_AXIS_DEFAULT_RANGE, QUICK_AXIS_IDS, type QuickAxisId, type QuickState, type SourceInfo, type SourceKind, type SourceProbe, applyQuickStateToParams, applyQuickStateToPhase0Params, assertPhase0SourceProbeWithinCaps, benchmarkMarkdownTableHeader, buildBenchmarkRow, buildPhase0ExportRequest, chromaUnitFromHueDegrees, cloneParams, coerceQuickState, createDefaultFilmLookGradeProps, createDefaultPhase0Params, createIosPhase0SerializableLut, createPhase0ProjectState, deserializeCubeLutData, filmLabParamsSchema, filmLookGradeDefaultProps, filmLookGradeInputSchema, filmLookSpikeDefaultProps, filmLookSpikeInputSchema, findMatchingPreset, formatBenchmarkRow, getIosPhase0SourceCapViolations, getPhase0SourceCapViolations, gradeMatchesPreset, halationHueToHex, hslToRgb01, iosPhase0AssetRefSchema, iosPhase0BenchmarkRecordSchema, iosPhase0ExportPayloadSchema, iosPhase0ExportResultSchema, iosPhase0ExportSettingsSchema, iosPhase0LocalProjectSchema, iosPhase0ParamsSchema, iosPhase0PickedLutFileSchema, iosPhase0PickedSourceSchema, iosPhase0PresetIdSchema, iosPhase0SerializableLutSchema, iosPhase0SourceInfoSchema, iosPhase0SourceKindSchema, iosPhase0ThermalStateSchema, lookIdForPreset, mergePhase0Params, nearestHueDegreesToDirection, packCubeLutToFloatRgbaGrid, parseBenchmarkRow, parseCube, phase0ParamsSchema, phase0ProjectLutSchema, phase0ProjectSchema, phase0QuickStateSchema, pickIosPhase0Params, pickPhase0Params, quickStateSchema, serializeCubeLut };
