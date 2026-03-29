/**
 * @file Film Lab「スマートルック」— クラウド解析用のデルタ JSON とマージ（Web／Desktop 共用パッケージ）。
 * @description API 契約・クライアント適用の共通。OpenAI や Next は含めず、純粋な検証・パース・マージだけを置く。
 * @limitations デルタは少数キーに限定。localStorage を触れる関数はブラウザ専用（SSR では no-op または false）。`referenceImageBase64` があるとき BFF は 2 枚 Vision（参照スタイル優先）。`currentGrade` で preset baseline セマンティクスを揃える。
 */

import { z } from "zod";
import {
  PARAM_KEYS,
  PRESETS,
  filmLabParamsSchema,
  type Params,
  type PresetName,
} from "film-lab-core";

/** @description 同意文の版。API と localStorage で一致させる。 */
export const SMART_LOOK_CONSENT_VERSION = 1 as const;

/**
 * @description BFF が返す `code` 文字列（API 契約）。クライアントの表示分岐と計測で共通利用する。
 * @limitations 値は snake_case のまま JSON で送る（既存の `forbidden_not_supporter` 等と揃える）。
 */
export const FILM_LAB_SMART_LOOK_ERROR_CODES = {
  notConfigured: "not_configured",
  forbiddenNotSupporter: "forbidden_not_supporter",
  badJson: "bad_json",
  invalidBody: "invalid_body",
  consentRequired: "consent_required",
  invalidPreset: "invalid_preset",
  providerError: "provider_error",
  smartLookInvalidResponse: "smart_look_invalid_response",
  rateLimitExceeded: "rate_limit_exceeded",
} as const;

/** @description `FILM_LAB_SMART_LOOK_ERROR_CODES` の値だけを集めた型。 */
export type FilmLabSmartLookApiErrorCode =
  (typeof FILM_LAB_SMART_LOOK_ERROR_CODES)[keyof typeof FILM_LAB_SMART_LOOK_ERROR_CODES];

const deltaValueSchema = z.number().finite();

/**
 * @description モデル／mock が返す加算デルタ（キー省略可）。
 */
export const filmLabSmartLookDeltaSchema = z
  .object({
    exposure: deltaValueSchema.optional(),
    temperature: deltaValueSchema.optional(),
    tint: deltaValueSchema.optional(),
    saturation: deltaValueSchema.optional(),
    highlights: deltaValueSchema.optional(),
    shadows: deltaValueSchema.optional(),
    fade: deltaValueSchema.optional(),
  })
  .strict();

export type FilmLabSmartLookDelta = z.infer<typeof filmLabSmartLookDeltaSchema>;

/** @description `PRESETS` のキーだけを許す Zod（`basePreset` 用）。 */
const filmLabPresetNameSchema = z.enum(
  Object.keys(PRESETS) as [PresetName, ...PresetName[]],
);

/**
 * @description POST ボディ。画像はクライアントで長辺 1024 前後に縮小済みを推奨。
 */
export const filmLabSmartLookRequestSchema = z.object({
  presetId: z.string().min(1).max(64),
  imageBase64: z.string().min(32).max(2_200_000),
  mimeType: z.enum(["image/jpeg", "image/png", "image/webp"]),
  consentVersion: z.literal(SMART_LOOK_CONSENT_VERSION),
  consentAcknowledged: z.literal(true),
  /**
   * @description `true` のとき、BFF はデルタに基づく **補正済みラスタ**（PNG base64）も返す（製品意図の画像レベル MVP）。省略・false は従来どおりデルタ JSON のみ。
   */
  includeRasterCorrection: z.boolean().optional(),
  /**
   * @description 現スロットのグレード全文。あるとき BFF は「**プリセット baseline + delta**」セマンティクスで LLM に指示する（省略時はレガシー: デルタは現グレードへの加算という説明）。
   */
  currentGrade: filmLabParamsSchema.optional(),
  /**
   * @description スロットの `basePreset`（手動調整なら `null`）。baseline 計算に使う。
   */
  basePreset: filmLabPresetNameSchema.nullable().optional(),
  /**
   * @description プリセット強さ 0〜1。`basePreset === presetId` のときだけ baseline 補間に使う。省略時は 1。
   */
  intensity: z.number().min(0).max(1).optional(),
  /**
   * @description **スタイル参照**用の縮小画像（base64 本文のみ）。`referenceMimeType` とセット。省略時は従来どおりプリセット基準の 1 枚 Vision。
   */
  referenceImageBase64: z.string().min(32).max(2_200_000).optional(),
  /**
   * @description 参照画像の MIME。`referenceImageBase64` とセット。
   */
  referenceMimeType: z.enum(["image/jpeg", "image/png", "image/webp"]).optional(),
})
  .superRefine((data, ctx) => {
    const hasB64 = data.referenceImageBase64 != null;
    const hasMime = data.referenceMimeType != null;
    if (hasB64 !== hasMime) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: "referenceImageBase64 and referenceMimeType must both be set or both omitted",
        path: hasB64 ? ["referenceMimeType"] : ["referenceImageBase64"],
      });
    }
  });

export type FilmLabSmartLookRequest = z.infer<typeof filmLabSmartLookRequestSchema>;

const DELTA_KEYS = [
  "exposure",
  "temperature",
  "tint",
  "saturation",
  "highlights",
  "shadows",
  "fade",
] as const;

type DeltaKey = (typeof DELTA_KEYS)[number];

/** @description 1 リクエストあたりの加算上限（暴れ防止）。 */
const MAX_ABS_STEP: Record<DeltaKey, number> = {
  exposure: 0.4,
  temperature: 0.15,
  tint: 0.12,
  saturation: 0.2,
  highlights: 0.18,
  shadows: 0.18,
  fade: 0.06,
};

/** @description マージ後の Params 絶対レンジ。 */
const PARAM_RANGE: Record<DeltaKey, readonly [number, number]> = {
  exposure: [-3, 3],
  temperature: [-1, 1],
  tint: [-1, 1],
  saturation: [0, 3],
  highlights: [-1, 1],
  shadows: [-1, 1],
  fade: [0, 0.3],
};

/**
 * @description 生のデルタをスキーマ検証し、ステップ上限でクリップする（サーバーでもクライアントでも使える）。
 * @param raw - API 応答の `delta` オブジェクト
 */
export function parseAndClampSmartLookDelta(raw: unknown): FilmLabSmartLookDelta | null {
  const parsed = filmLabSmartLookDeltaSchema.safeParse(raw);
  if (!parsed.success) return null;
  const out: FilmLabSmartLookDelta = {};
  for (const key of DELTA_KEYS) {
    const v = parsed.data[key];
    if (v === undefined) continue;
    const cap = MAX_ABS_STEP[key];
    const stepped = Math.sign(v) * Math.min(Math.abs(v), cap);
    out[key] = stepped;
  }
  return out;
}

/**
 * @description 文字列の先頭から、文字列リテラル内を無視しながら対応する `{`〜`}` ブロックを 1 つ切り出す。
 * @param source - モデル出力やその一部
 */
function extractFirstBalancedJsonObject(source: string): string | null {
  const start = source.indexOf("{");
  if (start === -1) return null;
  let depth = 0;
  let inString = false;
  let escaped = false;
  for (let i = start; i < source.length; i++) {
    const ch = source[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (inString) {
      if (ch === "\\") {
        escaped = true;
        continue;
      }
      if (ch === '"') {
        inString = false;
      }
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === "{") depth++;
    else if (ch === "}") {
      depth--;
      if (depth === 0) return source.slice(start, i + 1);
    }
  }
  return null;
}

/**
 * @description Vision モデルが返す本文から JSON オブジェクトを読み取る。markdown のコードフェンスや前後の説明文に強くする。
 * @param raw - `choices[0].message.content` 相当
 */
export function parseJsonObjectFromAssistantText(
  raw: string,
): { ok: true; value: unknown } | { ok: false } {
  const trimmed = raw.trim();
  let body = trimmed;
  const openFence = /^```(?:json)?\s*\r?\n/;
  const closeFence = /\r?\n```\s*$/;
  if (openFence.test(body) && closeFence.test(body)) {
    body = body.replace(openFence, "").replace(closeFence, "").trim();
  }

  const tryParse = (s: string): unknown | null => {
    try {
      return JSON.parse(s);
    } catch {
      return null;
    }
  };

  const direct = tryParse(body);
  if (direct !== null && typeof direct === "object" && !Array.isArray(direct)) {
    return { ok: true, value: direct };
  }

  const slice = extractFirstBalancedJsonObject(body);
  if (slice != null) {
    const nested = tryParse(slice);
    if (nested !== null && typeof nested === "object" && !Array.isArray(nested)) {
      return { ok: true, value: nested };
    }
  }

  return { ok: false };
}

/**
 * @description アシスタント JSON のルートまたは `delta` プロパティから、検証＋クリップ済みデルタを得る。
 * @param parsed - `parseJsonObjectFromAssistantText` の `value`
 */
export function extractSmartLookDeltaFromAssistantJson(parsed: unknown): FilmLabSmartLookDelta | null {
  if (parsed == null || typeof parsed !== "object") return null;
  const root = parsed as Record<string, unknown>;
  const deltaRaw = "delta" in root ? root.delta : parsed;
  const clamped = parseAndClampSmartLookDelta(deltaRaw);
  if (clamped == null) return null;
  if (Object.keys(clamped).length === 0) return null;
  return clamped;
}

/**
 * @description `base` にデルタを加え、デルタ対象キーだけ絶対レンジ内に収める（それ以外のキーは `base` のコピー）。
 * @param base - 足し算の基準。レガシーでは現スロット Params。目標ルックセマンティクスでは `computeSmartLookPresetBaseline` の戻り値。
 * @param delta - `parseAndClampSmartLookDelta` 済み
 */
export function applySmartLookDelta(base: Params, delta: FilmLabSmartLookDelta): Params {
  const next: Params = { ...base };
  for (const key of DELTA_KEYS) {
    const d = delta[key];
    if (d === undefined) continue;
    const [lo, hi] = PARAM_RANGE[key];
    const sum = base[key] + d;
    next[key] = Math.min(hi, Math.max(lo, sum)) as Params[typeof key];
  }
  return next;
}

/**
 * @description `reset` から指定プリセットへ、強さ `intensity`（0〜1）で線形補間したグレード（Film Lab reducer の `interpolatePreset` と同じ式）。
 * @param presetName - 目標プリセット
 * @param intensity - 0 で reset に近い、1 でプリセット完全一致
 */
export function interpolateFilmLabPresetForSmartLook(
  presetName: PresetName,
  intensity: number,
): Params {
  const clamped = Math.max(0, Math.min(1, intensity));
  const params: Params = { ...PRESETS.reset };
  const preset = PRESETS[presetName];
  for (const key of PARAM_KEYS) {
    params[key] = PRESETS.reset[key] + (preset[key] - PRESETS.reset[key]) * clamped;
  }
  return params;
}

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
export function computeSmartLookPresetBaseline(args: {
  targetPresetId: PresetName;
  slotBasePreset: PresetName | null;
  slotIntensity: number;
}): Params {
  const { targetPresetId, slotBasePreset, slotIntensity } = args;
  const aligned = slotBasePreset != null && slotBasePreset === targetPresetId;
  if (aligned) {
    return interpolateFilmLabPresetForSmartLook(targetPresetId, slotIntensity);
  }
  return { ...PRESETS[targetPresetId] };
}

/**
 * @description プリセット ID が既知か（API 検証用）。
 * @param id - クライアントから送られた文字列
 */
export function isFilmLabPresetIdForSmartLook(id: string): id is PresetName {
  return id in PRESETS;
}

/** @description localStorage キー（同意記録）。 */
export const FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY = "filmLabAiCloudConsentV1" as const;

export type FilmLabSmartLookConsentRecord = {
  version: typeof SMART_LOOK_CONSENT_VERSION;
  acceptedAt: string;
};

/**
 * @description 同意済みか（クライアントのみ。Electron の renderer でも localStorage があれば動く）。
 */
export function filmLabReadSmartLookConsent(): boolean {
  if (typeof window === "undefined") return false;
  try {
    const raw = localStorage.getItem(FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY);
    if (!raw) return false;
    const o = JSON.parse(raw) as FilmLabSmartLookConsentRecord;
    return o.version === SMART_LOOK_CONSENT_VERSION && typeof o.acceptedAt === "string";
  } catch {
    return false;
  }
}

/**
 * @description 同意を保存する。
 */
export function filmLabWriteSmartLookConsent(): void {
  if (typeof window === "undefined") return;
  const rec: FilmLabSmartLookConsentRecord = {
    version: SMART_LOOK_CONSENT_VERSION,
    acceptedAt: new Date().toISOString(),
  };
  try {
    localStorage.setItem(FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY, JSON.stringify(rec));
  } catch {
    /* private mode 等は無視 */
  }
}
