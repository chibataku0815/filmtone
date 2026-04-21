import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import {
  BffAiScenePickProvider,
  parseAiScenePickPayload,
  type AiScenePickInput,
} from "./ai-scene-pick";

const SAMPLE_INPUT: AiScenePickInput = {
  sourcePath: "/clips/demo.mov",
  trimStartSec: 0,
  trimEndSec: 6,
  frames: [
    { index: 0, timeSec: 0, jpegDataUrl: "data:image/jpeg;base64,AAA" },
    { index: 1, timeSec: 3, jpegDataUrl: "data:image/jpeg;base64,BBB" },
    { index: 2, timeSec: 6, jpegDataUrl: "data:image/jpeg;base64,CCC" },
  ],
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

describe("parseAiScenePickPayload", () => {
  it("accepts a valid payload", () => {
    const result = parseAiScenePickPayload(
      {
        bestFrameIndex: 1,
        family: "glow",
        recipe: "warmIndoor",
        confidence: "high",
        manualFallback: false,
        reason: "warm practical lights",
      },
      3,
      123,
    );

    expect(result.manualFallback).toBe(false);
    expect(result.bestFrameIndex).toBe(1);
    expect(result.family).toBe("glow");
    expect(result.recipe).toBe("warmIndoor");
    expect(result.confidence).toBe("high");
    expect(result.latencyMs).toBe(123);
  });

  it("forces fallback when manualFallback is true", () => {
    const result = parseAiScenePickPayload(
      {
        bestFrameIndex: 0,
        family: "mist",
        recipe: null,
        confidence: "low",
        manualFallback: true,
        reason: "mixed scenes",
      },
      3,
      42,
    );

    expect(result.manualFallback).toBe(true);
    expect(result.confidence).toBe("low");
    expect(result.reason).toBe("mixed scenes");
  });

  it("rejects out-of-vocabulary family", () => {
    const result = parseAiScenePickPayload(
      {
        bestFrameIndex: 1,
        family: "bloom",
        recipe: "warmIndoor",
        confidence: "high",
        manualFallback: false,
        reason: "",
      },
      3,
      0,
    );

    expect(result.manualFallback).toBe(true);
    expect(result.family).toBe(null);
  });

  it("rejects out-of-range frame index", () => {
    const result = parseAiScenePickPayload(
      {
        bestFrameIndex: 99,
        family: "glow",
        recipe: "warmIndoor",
        confidence: "high",
        manualFallback: false,
        reason: "",
      },
      3,
      0,
    );

    expect(result.manualFallback).toBe(true);
    expect(result.bestFrameIndex).toBe(null);
  });

  it("degrades invalid shapes to fallback", () => {
    expect(parseAiScenePickPayload(null, 3, 0).manualFallback).toBe(true);
    expect(parseAiScenePickPayload("not-json", 3, 0).manualFallback).toBe(true);
    expect(parseAiScenePickPayload({}, 3, 0).manualFallback).toBe(true);
  });

  it("coerces unknown confidence to low without forcing fallback", () => {
    const result = parseAiScenePickPayload(
      {
        bestFrameIndex: 0,
        family: "mist",
        recipe: "skinCloseUp",
        confidence: "super-high",
        manualFallback: false,
        reason: "",
      },
      3,
      0,
    );

    expect(result.confidence).toBe("low");
    expect(result.manualFallback).toBe(false);
    expect(result.family).toBe("mist");
  });
});

describe("BffAiScenePickProvider", () => {
  const fetchMock = vi.fn<typeof fetch>();

  beforeEach(() => {
    fetchMock.mockReset();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("returns a parsed pick on happy path", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({
        ok: true,
        pick: {
          bestFrameIndex: 2,
          family: "cross",
          recipe: "nightSpot",
          confidence: "high",
          manualFallback: false,
          reason: "sharp point lights",
        },
        model: "google/gemini-2.5-pro",
      }),
    );

    const provider = new BffAiScenePickProvider("http://localhost:3000");
    const result = await provider.pick(SAMPLE_INPUT);

    expect(result.manualFallback).toBe(false);
    expect(result.family).toBe("cross");
    expect(result.recipe).toBe("nightSpot");
    expect(result.bestFrameIndex).toBe(2);
    expect(result.latencyMs).toBeGreaterThanOrEqual(0);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe("http://localhost:3000/api/film-lab/ai/scene-pick");
    expect((init as RequestInit).method).toBe("POST");
  });

  it("falls back when BFF returns ok=false", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({ ok: false, code: "provider_error" }, 502),
    );

    const provider = new BffAiScenePickProvider();
    const result = await provider.pick(SAMPLE_INPUT);

    expect(result.manualFallback).toBe(true);
    expect(result.reason).toMatch(/http-502/);
  });

  it("falls back when fetch throws", async () => {
    fetchMock.mockRejectedValueOnce(new Error("ECONNREFUSED"));

    const provider = new BffAiScenePickProvider();
    const result = await provider.pick(SAMPLE_INPUT);

    expect(result.manualFallback).toBe(true);
    expect(result.reason).toMatch(/fetch-failed/);
  });

  it("falls back when response body is not JSON", async () => {
    fetchMock.mockResolvedValueOnce(
      new Response("not json at all", {
        status: 200,
        headers: { "Content-Type": "text/plain" },
      }),
    );

    const provider = new BffAiScenePickProvider();
    const result = await provider.pick(SAMPLE_INPUT);

    expect(result.manualFallback).toBe(true);
    expect(result.reason).toMatch(/parse-failed/);
    expect(result.rawJson).toBe("not json at all");
  });

  it("returns no-frames fallback when frames array is empty", async () => {
    const provider = new BffAiScenePickProvider();
    const result = await provider.pick({ ...SAMPLE_INPUT, frames: [] });

    expect(result.manualFallback).toBe(true);
    expect(result.reason).toBe("no-frames");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("propagates bff-not-ok code", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({ ok: false, code: "forbidden" }, 200),
    );

    const provider = new BffAiScenePickProvider();
    const result = await provider.pick(SAMPLE_INPUT);

    expect(result.manualFallback).toBe(true);
    expect(result.reason).toMatch(/bff-not-ok: forbidden/);
  });
});
