import { z } from 'zod';
import { Params, PresetName } from 'film-lab-core';

/**
 * @file Film Lab「スマートルック」— クラウド解析用のデルタ JSON とマージ（Web／Desktop 共用パッケージ）。
 * @description API 契約・クライアント適用の共通。OpenAI や Next は含めず、純粋な検証・パース・マージだけを置く。
 * @limitations デルタは少数キーに限定。localStorage を触れる関数はブラウザ専用（SSR では no-op または false）。`referenceImageBase64` があるとき BFF は 2 枚 Vision（参照スタイル優先）。`currentGrade` で preset baseline セマンティクスを揃える。
 */

/** @description 同意文の版。API と localStorage で一致させる。 */
declare const SMART_LOOK_CONSENT_VERSION: 1;
/**
 * @description BFF が返す `code` 文字列（API 契約）。クライアントの表示分岐と計測で共通利用する。
 * @limitations 値は snake_case のまま JSON で送る（既存の `forbidden_not_supporter` 等と揃える）。
 */
declare const FILM_LAB_SMART_LOOK_ERROR_CODES: {
    readonly notConfigured: "not_configured";
    readonly forbiddenNotSupporter: "forbidden_not_supporter";
    readonly badJson: "bad_json";
    readonly invalidBody: "invalid_body";
    readonly consentRequired: "consent_required";
    readonly invalidPreset: "invalid_preset";
    readonly providerError: "provider_error";
    readonly smartLookInvalidResponse: "smart_look_invalid_response";
    readonly rateLimitExceeded: "rate_limit_exceeded";
};
/** @description `FILM_LAB_SMART_LOOK_ERROR_CODES` の値だけを集めた型。 */
type FilmLabSmartLookApiErrorCode = (typeof FILM_LAB_SMART_LOOK_ERROR_CODES)[keyof typeof FILM_LAB_SMART_LOOK_ERROR_CODES];
/**
 * @description モデル／mock が返す加算デルタ（キー省略可）。
 */
declare const filmLabSmartLookDeltaSchema: z.ZodObject<{
    exposure: z.ZodOptional<z.ZodNumber>;
    temperature: z.ZodOptional<z.ZodNumber>;
    tint: z.ZodOptional<z.ZodNumber>;
    saturation: z.ZodOptional<z.ZodNumber>;
    highlights: z.ZodOptional<z.ZodNumber>;
    shadows: z.ZodOptional<z.ZodNumber>;
    fade: z.ZodOptional<z.ZodNumber>;
}, z.core.$strict>;
type FilmLabSmartLookDelta = z.infer<typeof filmLabSmartLookDeltaSchema>;
/**
 * @description POST ボディ。画像はクライアントで長辺 1024 前後に縮小済みを推奨。
 */
declare const filmLabSmartLookRequestSchema: z.ZodObject<{
    presetId: z.ZodString;
    imageBase64: z.ZodString;
    mimeType: z.ZodEnum<{
        "image/jpeg": "image/jpeg";
        "image/png": "image/png";
        "image/webp": "image/webp";
    }>;
    consentVersion: z.ZodLiteral<1>;
    consentAcknowledged: z.ZodLiteral<true>;
    includeRasterCorrection: z.ZodOptional<z.ZodBoolean>;
    currentGrade: z.ZodOptional<z.ZodObject<{
        exposure: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        contrast: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        saturation: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        temperature: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        tint: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        rgbShift: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
        lensSoftness: z.ZodType<number, unknown, z.core.$ZodTypeInternals<number, unknown>>;
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
    }, z.core.$strip>>;
    basePreset: z.ZodOptional<z.ZodNullable<z.ZodEnum<{
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
    }>>>;
    intensity: z.ZodOptional<z.ZodNumber>;
    referenceImageBase64: z.ZodOptional<z.ZodString>;
    referenceMimeType: z.ZodOptional<z.ZodEnum<{
        "image/jpeg": "image/jpeg";
        "image/png": "image/png";
        "image/webp": "image/webp";
    }>>;
}, z.core.$strip>;
type FilmLabSmartLookRequest = z.infer<typeof filmLabSmartLookRequestSchema>;
/**
 * @description 生のデルタをスキーマ検証し、ステップ上限でクリップする（サーバーでもクライアントでも使える）。
 * @param raw - API 応答の `delta` オブジェクト
 */
declare function parseAndClampSmartLookDelta(raw: unknown): FilmLabSmartLookDelta | null;
/**
 * @description Vision モデルが返す本文から JSON オブジェクトを読み取る。markdown のコードフェンスや前後の説明文に強くする。
 * @param raw - `choices[0].message.content` 相当
 */
declare function parseJsonObjectFromAssistantText(raw: string): {
    ok: true;
    value: unknown;
} | {
    ok: false;
};
/**
 * @description アシスタント JSON のルートまたは `delta` プロパティから、検証＋クリップ済みデルタを得る。
 * @param parsed - `parseJsonObjectFromAssistantText` の `value`
 */
declare function extractSmartLookDeltaFromAssistantJson(parsed: unknown): FilmLabSmartLookDelta | null;
/**
 * @description `base` にデルタを加え、デルタ対象キーだけ絶対レンジ内に収める（それ以外のキーは `base` のコピー）。
 * @param base - 足し算の基準。レガシーでは現スロット Params。目標ルックセマンティクスでは `computeSmartLookPresetBaseline` の戻り値。
 * @param delta - `parseAndClampSmartLookDelta` 済み
 */
declare function applySmartLookDelta(base: Params, delta: FilmLabSmartLookDelta): Params;
/**
 * @description `reset` から指定プリセットへ、強さ `intensity`（0〜1）で線形補間したグレード（Film Lab reducer の `interpolatePreset` と同じ式）。
 * @param presetName - 目標プリセット
 * @param intensity - 0 で reset に近い、1 でプリセット完全一致
 */
declare function interpolateFilmLabPresetForSmartLook(presetName: PresetName, intensity: number): Params;
/**
 * @description スマートルックのデルタを足すときの **基準 Params**（POST 本文の `presetId` = 目標ルック）。
 *
 * **ルール（Photo+Eng で固定）**
 * - スロットの `basePreset` が `targetPresetId` と **一致**するとき → `intensity` で補間した baseline（そのプリセット「帯」で編集中とみなす）。
 * - **手動**（`slotBasePreset == null`）または **別プリセットから UI で切り替えた**（`slotBasePreset !== targetPresetId`）→ `PRESETS[targetPresetId]` の **フル強度**を baseline とする（新しく選んだルックへ寄せる）。
 *
 * @limitations baseline は数値のみ。プレビュー JPEG は `currentGrade` で焼かれており一致しないときがある → BFF は画像を主、`currentGrade` を補助として渡す。
 * @param args.targetPresetId - UI で選ばれている目標プリセット（`presetId` 本文と同じ）
 * @param args.slotBasePreset - スロットの `basePreset`（手動なら null）
 * @param args.slotIntensity - スロットの intensity（0〜1）
 */
declare function computeSmartLookPresetBaseline(args: {
    targetPresetId: PresetName;
    slotBasePreset: PresetName | null;
    slotIntensity: number;
}): Params;
/**
 * @description プリセット ID が既知か（API 検証用）。
 * @param id - クライアントから送られた文字列
 */
declare function isFilmLabPresetIdForSmartLook(id: string): id is PresetName;
/** @description localStorage キー（同意記録）。 */
declare const FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY: "filmLabAiCloudConsentV1";
type FilmLabSmartLookConsentRecord = {
    version: typeof SMART_LOOK_CONSENT_VERSION;
    acceptedAt: string;
};
/**
 * @description 同意済みか（クライアントのみ。Electron の renderer でも localStorage があれば動く）。
 */
declare function filmLabReadSmartLookConsent(): boolean;
/**
 * @description 同意を保存する。
 */
declare function filmLabWriteSmartLookConsent(): void;

export { FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY, FILM_LAB_SMART_LOOK_ERROR_CODES, type FilmLabSmartLookApiErrorCode, type FilmLabSmartLookConsentRecord, type FilmLabSmartLookDelta, type FilmLabSmartLookRequest, SMART_LOOK_CONSENT_VERSION, applySmartLookDelta, computeSmartLookPresetBaseline, extractSmartLookDeltaFromAssistantJson, filmLabReadSmartLookConsent, filmLabSmartLookDeltaSchema, filmLabSmartLookRequestSchema, filmLabWriteSmartLookConsent, interpolateFilmLabPresetForSmartLook, isFilmLabPresetIdForSmartLook, parseAndClampSmartLookDelta, parseJsonObjectFromAssistantText };
