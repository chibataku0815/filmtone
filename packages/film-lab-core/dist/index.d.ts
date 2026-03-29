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

/** スキーマと JSON で共有するプリセット定義バージョン */
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

export { type CubeLUT, FILM_LAB_DEFAULT_HIGHLIGHT_HUE, FILM_LAB_DEFAULT_SHADOW_HUE, type FilmLabParamsValidated, type FilmLookGradeInputProps, type FilmLookSpikeInputProps, LEGACY_HIGHLIGHT_TONE_MAGNITUDE, LEGACY_SHADOW_TONE_MAGNITUDE, LOOK_ID_BY_PRESET, PARAM_KEYS, PRESETS, PRESET_VERSION, type ParamKey, type Params, type PresetName, chromaUnitFromHueDegrees, cloneParams, createDefaultFilmLookGradeProps, filmLabParamsSchema, filmLookGradeDefaultProps, filmLookGradeInputSchema, filmLookSpikeDefaultProps, filmLookSpikeInputSchema, gradeMatchesPreset, hslToRgb01, lookIdForPreset, nearestHueDegreesToDirection, parseCube };
