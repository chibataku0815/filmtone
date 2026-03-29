/**
 * @file film-lab-smart-look のユニットテスト（delta パース・マージ・アシスタント JSON）。
 */
import { describe, expect, test } from "bun:test";
import { PRESETS } from "film-lab-core";
import {
  applySmartLookDelta,
  extractSmartLookDeltaFromAssistantJson,
  parseAndClampSmartLookDelta,
  parseJsonObjectFromAssistantText,
  isFilmLabPresetIdForSmartLook,
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
});

describe("isFilmLabPresetIdForSmartLook", () => {
  test("既知プリセット", () => {
    expect(isFilmLabPresetIdForSmartLook("cinematic")).toBe(true);
    expect(isFilmLabPresetIdForSmartLook("nope")).toBe(false);
  });
});
