import { z } from 'zod';

/**
 * Film Lab のグレード数値パラメータ定義（ブラウザ・Remotion 共通の単一の真実）
 */
declare const PARAM_KEYS: readonly ["exposure", "contrast", "saturation", "temperature", "tint", "rgbShift", "grainIntensity", "vignette", "bloomThreshold", "bloomStrength", "bloomRadius", "halationIntensity", "halationSpread", "halationHue", "fade", "highlights", "shadows", "shadowTone", "highlightTone", "shadowHue", "highlightHue"];
type ParamKey = (typeof PARAM_KEYS)[number];
interface Params {
    exposure: number;
    contrast: number;
    saturation: number;
    temperature: number;
    tint: number;
    rgbShift: number;
    grainIntensity: number;
    vignette: number;
    bloomThreshold: number;
    bloomStrength: number;
    bloomRadius: number;
    halationIntensity: number;
    halationSpread: number;
    halationHue: number;
    fade: number;
    highlights: number;
    shadows: number;
    shadowTone: number;
    highlightTone: number;
    /** シャドウスプリットトーンの色相（度 0〜360） */
    shadowHue: number;
    /** ハイライトスプリットトーンの色相（度 0〜360） */
    highlightHue: number;
}
declare function cloneParams(params: Params): Params;

/**
 * 組み込みプリセット（Next Film Lab と同一数値）
 */
declare const PRESETS: {
    reset: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
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
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    portra: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    gold200: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    pro400h: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    bw: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    ektar100: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    superia400: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
    cinestill800t: {
        exposure: number;
        contrast: number;
        saturation: number;
        temperature: number;
        tint: number;
        rgbShift: number;
        grainIntensity: number;
        vignette: number;
        bloomThreshold: number;
        bloomStrength: number;
        bloomRadius: number;
        halationIntensity: number;
        halationSpread: number;
        halationHue: number;
        fade: number;
        highlights: number;
        shadows: number;
        shadowTone: number;
        highlightTone: number;
        shadowHue: number;
        highlightHue: number;
    };
};
type PresetName = keyof typeof PRESETS;

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
    exposure: z.ZodNumber;
    contrast: z.ZodNumber;
    saturation: z.ZodNumber;
    temperature: z.ZodNumber;
    tint: z.ZodNumber;
    rgbShift: z.ZodNumber;
    grainIntensity: z.ZodNumber;
    vignette: z.ZodNumber;
    bloomThreshold: z.ZodNumber;
    bloomStrength: z.ZodNumber;
    bloomRadius: z.ZodNumber;
    halationIntensity: z.ZodNumber;
    halationSpread: z.ZodNumber;
    halationHue: z.ZodNumber;
    fade: z.ZodNumber;
    highlights: z.ZodNumber;
    shadows: z.ZodNumber;
    shadowTone: z.ZodNumber;
    highlightTone: z.ZodNumber;
    shadowHue: z.ZodNumber;
    highlightHue: z.ZodNumber;
}, z.core.$strip>;
type FilmLabParamsValidated = z.infer<typeof filmLabParamsSchema>;
/**
 * Remotion Composition 向け: ルック ID + バージョン + 数値グレード
 */
declare const filmLookGradeInputSchema: z.ZodObject<{
    lookPresetId: z.ZodString;
    presetVersion: z.ZodLiteral<"v1">;
    grade: z.ZodObject<{
        exposure: z.ZodNumber;
        contrast: z.ZodNumber;
        saturation: z.ZodNumber;
        temperature: z.ZodNumber;
        tint: z.ZodNumber;
        rgbShift: z.ZodNumber;
        grainIntensity: z.ZodNumber;
        vignette: z.ZodNumber;
        bloomThreshold: z.ZodNumber;
        bloomStrength: z.ZodNumber;
        bloomRadius: z.ZodNumber;
        halationIntensity: z.ZodNumber;
        halationSpread: z.ZodNumber;
        halationHue: z.ZodNumber;
        fade: z.ZodNumber;
        highlights: z.ZodNumber;
        shadows: z.ZodNumber;
        shadowTone: z.ZodNumber;
        highlightTone: z.ZodNumber;
        shadowHue: z.ZodNumber;
        highlightHue: z.ZodNumber;
    }, z.core.$strip>;
    lutCubeRelPath: z.ZodOptional<z.ZodString>;
    lutEnabled: z.ZodOptional<z.ZodBoolean>;
    lutIntensity: z.ZodOptional<z.ZodNumber>;
    gradeSourceVideoRelPath: z.ZodOptional<z.ZodString>;
    gradeSourceVideoWidth: z.ZodOptional<z.ZodNumber>;
    gradeSourceVideoHeight: z.ZodOptional<z.ZodNumber>;
}, z.core.$strip>;
type FilmLookGradeInputProps = z.infer<typeof filmLookGradeInputSchema>;
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

export { type CubeLUT, FILM_LAB_DEFAULT_HIGHLIGHT_HUE, FILM_LAB_DEFAULT_SHADOW_HUE, type FilmLabParamsValidated, type FilmLookGradeInputProps, type FilmLookSpikeInputProps, LEGACY_HIGHLIGHT_TONE_MAGNITUDE, LEGACY_SHADOW_TONE_MAGNITUDE, LOOK_ID_BY_PRESET, PARAM_KEYS, PRESETS, PRESET_VERSION, type PackedCubeLut2D, type ParamKey, type Params, type PresetName, chromaUnitFromHueDegrees, cloneParams, createDefaultFilmLookGradeProps, filmLabParamsSchema, filmLookGradeDefaultProps, filmLookGradeInputSchema, filmLookSpikeDefaultProps, filmLookSpikeInputSchema, gradeMatchesPreset, hslToRgb01, lookIdForPreset, nearestHueDegreesToDirection, packCubeLutToFloatRgbaGrid, parseCube };
