/**
 * @file film-lab-smart-look のユニットテスト（delta パース・マージ・アシスタント JSON）。
 */
import { describe, expect, test } from "bun:test";
import { PRESETS } from "film-lab-core";
import {
  applySmartLookDelta,
  computeSmartLookPresetBaseline,
  extractSmartLookDeltaFromAssistantJson,
  filmLabSmartLookRequestSchema,
  interpolateFilmLabPresetForSmartLook,
  parseAndClampSmartLookDelta,
  parseJsonObjectFromAssistantText,
  isFilmLabPresetIdForSmartLook,
  SMART_LOOK_CONSENT_VERSION,
} from "./index";

describe("parseAndClampSmartLookDelta", () => {
  test("クリップとキー省略", () => {
    const d = parseAndClampSmartLookDelta({
      exposure: 9,
      saturation: -0.05,
    });
    expect(d).not.toBeNull();
    expect(d!.exposure).toBe(0.4);
    expect(d!.saturation).toBe(-0.05);
  });

  test("不正な型は null", () => {
    expect(parseAndClampSmartLookDelta({ exposure: "x" })).toBeNull();
  });
});

describe("parseJsonObjectFromAssistantText", () => {
  test("フェンス付き JSON", () => {
    const r = parseJsonObjectFromAssistantText("```json\n{\"delta\":{\"exposure\":0.1}}\n```");
    expect(r.ok).toBe(true);
    if (r.ok) expect((r.value as { delta?: unknown }).delta).toEqual({ exposure: 0.1 });
  });

  test("説明文の後のブロック", () => {
    const r = parseJsonObjectFromAssistantText('here: {"delta":{"fade":0.01}} tail');
    expect(r.ok).toBe(true);
  });
});

describe("extractSmartLookDeltaFromAssistantJson", () => {
  test("ルートが delta", () => {
    const d = extractSmartLookDeltaFromAssistantJson({ delta: { exposure: 0.05 } });
    expect(d).not.toBeNull();
    expect(d!.exposure).toBe(0.05);
  });

  test("空オブジェクトは null", () => {
    expect(extractSmartLookDeltaFromAssistantJson({ delta: {} })).toBeNull();
  });
});

describe("applySmartLookDelta", () => {
  test("レンジ内に収まる", () => {
    const base = { ...PRESETS.cinematic };
    const next = applySmartLookDelta(base, { exposure: 0.1 });
    expect(next.exposure).toBeGreaterThan(base.exposure);
  });

  test("プリセット baseline へデルタ（目標ルック: 現スロットと別のときはフルプリセット起点）", () => {
    const baseline = computeSmartLookPresetBaseline({
      targetPresetId: "portra",
      slotBasePreset: "cinematic",
      slotIntensity: 1,
    });
    expect(baseline).toEqual(PRESETS.portra);
    const next = applySmartLookDelta(baseline, { exposure: 0.05 });
    expect(next.exposure).toBe(PRESETS.portra.exposure + 0.05);
  });
});

describe("computeSmartLookPresetBaseline", () => {
  test("スロットが目標プリセットに一致 → intensity で補間", () => {
    const half = computeSmartLookPresetBaseline({
      targetPresetId: "cinematic",
      slotBasePreset: "cinematic",
      slotIntensity: 0.5,
    });
    const expected = interpolateFilmLabPresetForSmartLook("cinematic", 0.5);
    expect(half).toEqual(expected);
  });

  test("手動スロット null → フル強度の目標プリセット", () => {
    const baseline = computeSmartLookPresetBaseline({
      targetPresetId: "cinematic",
      slotBasePreset: null,
      slotIntensity: 0.3,
    });
    expect(baseline).toEqual(PRESETS.cinematic);
  });
});

describe("interpolateFilmLabPresetForSmartLook", () => {
  test("0 で reset に近い", () => {
    const z = interpolateFilmLabPresetForSmartLook("cinematic", 0);
    expect(z).toEqual(PRESETS.reset);
  });
});

describe("isFilmLabPresetIdForSmartLook", () => {
  test("既知プリセット", () => {
    expect(isFilmLabPresetIdForSmartLook("cinematic")).toBe(true);
    expect(isFilmLabPresetIdForSmartLook("nope")).toBe(false);
  });
});

describe("filmLabSmartLookRequestSchema", () => {
  test("includeRasterCorrection 省略可・true 許可", () => {
    const base64 = "a".repeat(40);
    const minimal = {
      presetId: "cinematic",
      imageBase64: base64,
      mimeType: "image/jpeg" as const,
      consentVersion: SMART_LOOK_CONSENT_VERSION,
      consentAcknowledged: true as const,
    };
    expect(filmLabSmartLookRequestSchema.safeParse(minimal).success).toBe(true);
    expect(
      filmLabSmartLookRequestSchema.safeParse({ ...minimal, includeRasterCorrection: true })
        .success,
    ).toBe(true);
  });

  test("currentGrade・basePreset・intensity を任意付与できる", () => {
    const base64 = "a".repeat(40);
    const grade = { ...PRESETS.cinematic };
    const parsed = filmLabSmartLookRequestSchema.safeParse({
      presetId: "cinematic",
      imageBase64: base64,
      mimeType: "image/jpeg" as const,
      consentVersion: SMART_LOOK_CONSENT_VERSION,
      consentAcknowledged: true as const,
      currentGrade: grade,
      basePreset: "cinematic" as const,
      intensity: 0.75,
    });
    expect(parsed.success).toBe(true);
  });

  test("basePreset に null を許可（手動スロット）", () => {
    const base64 = "a".repeat(40);
    const parsed = filmLabSmartLookRequestSchema.safeParse({
      presetId: "portra",
      imageBase64: base64,
      mimeType: "image/jpeg" as const,
      consentVersion: SMART_LOOK_CONSENT_VERSION,
      consentAcknowledged: true as const,
      basePreset: null,
      currentGrade: { ...PRESETS.portra },
    });
    expect(parsed.success).toBe(true);
  });

  test("参照画像は base64 と mime のペアでのみ有効", () => {
    const base64 = "a".repeat(40);
    const ref = "b".repeat(40);
    const okBoth = filmLabSmartLookRequestSchema.safeParse({
      presetId: "cinematic",
      imageBase64: base64,
      mimeType: "image/jpeg" as const,
      consentVersion: SMART_LOOK_CONSENT_VERSION,
      consentAcknowledged: true as const,
      referenceImageBase64: ref,
      referenceMimeType: "image/jpeg" as const,
    });
    expect(okBoth.success).toBe(true);

    const missingMime = filmLabSmartLookRequestSchema.safeParse({
      presetId: "cinematic",
      imageBase64: base64,
      mimeType: "image/jpeg" as const,
      consentVersion: SMART_LOOK_CONSENT_VERSION,
      consentAcknowledged: true as const,
      referenceImageBase64: ref,
    });
    expect(missingMime.success).toBe(false);
  });
});
