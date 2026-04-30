// src/index.ts
import { z } from "zod";
import {
  PARAM_KEYS,
  PRESETS,
  filmLabParamsSchema
} from "film-lab-core";
var SMART_LOOK_CONSENT_VERSION = 1;
var FILM_LAB_SMART_LOOK_ERROR_CODES = {
  notConfigured: "not_configured",
  forbiddenNotSupporter: "forbidden_not_supporter",
  badJson: "bad_json",
  invalidBody: "invalid_body",
  consentRequired: "consent_required",
  invalidPreset: "invalid_preset",
  providerError: "provider_error",
  smartLookInvalidResponse: "smart_look_invalid_response",
  rateLimitExceeded: "rate_limit_exceeded"
};
var deltaValueSchema = z.number().finite();
var filmLabSmartLookDeltaSchema = z.object({
  exposure: deltaValueSchema.optional(),
  temperature: deltaValueSchema.optional(),
  tint: deltaValueSchema.optional(),
  saturation: deltaValueSchema.optional(),
  highlights: deltaValueSchema.optional(),
  shadows: deltaValueSchema.optional(),
  fade: deltaValueSchema.optional()
}).strict();
var filmLabPresetNameSchema = z.enum(
  Object.keys(PRESETS)
);
var filmLabSmartLookRequestSchema = z.object({
  presetId: z.string().min(1).max(64),
  imageBase64: z.string().min(32).max(22e5),
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
  referenceImageBase64: z.string().min(32).max(22e5).optional(),
  /**
   * @description 参照画像の MIME。`referenceImageBase64` とセット。
   */
  referenceMimeType: z.enum(["image/jpeg", "image/png", "image/webp"]).optional()
}).superRefine((data, ctx) => {
  const hasB64 = data.referenceImageBase64 != null;
  const hasMime = data.referenceMimeType != null;
  if (hasB64 !== hasMime) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: "referenceImageBase64 and referenceMimeType must both be set or both omitted",
      path: hasB64 ? ["referenceMimeType"] : ["referenceImageBase64"]
    });
  }
});
var DELTA_KEYS = [
  "exposure",
  "temperature",
  "tint",
  "saturation",
  "highlights",
  "shadows",
  "fade"
];
var MAX_ABS_STEP = {
  exposure: 0.4,
  temperature: 0.15,
  tint: 0.12,
  saturation: 0.2,
  highlights: 0.18,
  shadows: 0.18,
  fade: 0.06
};
var PARAM_RANGE = {
  exposure: [-3, 3],
  temperature: [-1, 1],
  tint: [-1, 1],
  saturation: [0, 3],
  highlights: [-1, 1],
  shadows: [-1, 1],
  fade: [0, 0.3]
};
function parseAndClampSmartLookDelta(raw) {
  const parsed = filmLabSmartLookDeltaSchema.safeParse(raw);
  if (!parsed.success) return null;
  const out = {};
  for (const key of DELTA_KEYS) {
    const v = parsed.data[key];
    if (v === void 0) continue;
    const cap = MAX_ABS_STEP[key];
    const stepped = Math.sign(v) * Math.min(Math.abs(v), cap);
    out[key] = stepped;
  }
  return out;
}
function extractFirstBalancedJsonObject(source) {
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
function parseJsonObjectFromAssistantText(raw) {
  const trimmed = raw.trim();
  let body = trimmed;
  const openFence = /^```(?:json)?\s*\r?\n/;
  const closeFence = /\r?\n```\s*$/;
  if (openFence.test(body) && closeFence.test(body)) {
    body = body.replace(openFence, "").replace(closeFence, "").trim();
  }
  const tryParse = (s) => {
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
function extractSmartLookDeltaFromAssistantJson(parsed) {
  if (parsed == null || typeof parsed !== "object") return null;
  const root = parsed;
  const deltaRaw = "delta" in root ? root.delta : parsed;
  const clamped = parseAndClampSmartLookDelta(deltaRaw);
  if (clamped == null) return null;
  if (Object.keys(clamped).length === 0) return null;
  return clamped;
}
function applySmartLookDelta(base, delta) {
  const next = { ...base };
  for (const key of DELTA_KEYS) {
    const d = delta[key];
    if (d === void 0) continue;
    const [lo, hi] = PARAM_RANGE[key];
    const sum = base[key] + d;
    next[key] = Math.min(hi, Math.max(lo, sum));
  }
  return next;
}
function interpolateFilmLabPresetForSmartLook(presetName, intensity) {
  const clamped = Math.max(0, Math.min(1, intensity));
  const params = { ...PRESETS.reset };
  const preset = PRESETS[presetName];
  for (const key of PARAM_KEYS) {
    params[key] = PRESETS.reset[key] + (preset[key] - PRESETS.reset[key]) * clamped;
  }
  return params;
}
function computeSmartLookPresetBaseline(args) {
  const { targetPresetId, slotBasePreset, slotIntensity } = args;
  const aligned = slotBasePreset != null && slotBasePreset === targetPresetId;
  if (aligned) {
    return interpolateFilmLabPresetForSmartLook(targetPresetId, slotIntensity);
  }
  return { ...PRESETS[targetPresetId] };
}
function isFilmLabPresetIdForSmartLook(id) {
  return id in PRESETS;
}
var FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY = "filmLabAiCloudConsentV1";
function filmLabReadSmartLookConsent() {
  if (typeof window === "undefined") return false;
  try {
    const raw = localStorage.getItem(FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY);
    if (!raw) return false;
    const o = JSON.parse(raw);
    return o.version === SMART_LOOK_CONSENT_VERSION && typeof o.acceptedAt === "string";
  } catch {
    return false;
  }
}
function filmLabWriteSmartLookConsent() {
  if (typeof window === "undefined") return;
  const rec = {
    version: SMART_LOOK_CONSENT_VERSION,
    acceptedAt: (/* @__PURE__ */ new Date()).toISOString()
  };
  try {
    localStorage.setItem(FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY, JSON.stringify(rec));
  } catch {
  }
}
export {
  FILM_LAB_SMART_LOOK_CONSENT_STORAGE_KEY,
  FILM_LAB_SMART_LOOK_ERROR_CODES,
  SMART_LOOK_CONSENT_VERSION,
  applySmartLookDelta,
  computeSmartLookPresetBaseline,
  extractSmartLookDeltaFromAssistantJson,
  filmLabReadSmartLookConsent,
  filmLabSmartLookDeltaSchema,
  filmLabSmartLookRequestSchema,
  filmLabWriteSmartLookConsent,
  interpolateFilmLabPresetForSmartLook,
  isFilmLabPresetIdForSmartLook,
  parseAndClampSmartLookDelta,
  parseJsonObjectFromAssistantText
};
