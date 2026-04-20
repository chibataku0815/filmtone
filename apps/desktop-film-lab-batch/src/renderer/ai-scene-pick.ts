/**
 * @file Dev-only PoC: AI scene pick provider.
 * @description Sends sampled frame JPEGs to the BFF `/api/film-lab/ai/scene-pick`
 * endpoint and returns a constrained structured decision. Never throws — any
 * network, parse, or schema failure degrades to a `manualFallback: true` result
 * so the heuristic path is always authoritative. Not shipped; gated by
 * localStorage flag `filmtone.scenePickDev = "1"`.
 */

import type {
  OpticalFamily,
  OpticalRecipeId,
} from "film-lab-core";

export type AiScenePickConfidence = "low" | "medium" | "high";

export type AiScenePickResult = {
  bestFrameIndex: number | null;
  family: OpticalFamily | null;
  recipe: OpticalRecipeId | null;
  confidence: AiScenePickConfidence;
  manualFallback: boolean;
  reason: string;
  latencyMs: number;
  rawJson?: string;
};

export type AiScenePickFrame = {
  index: number;
  timeSec: number;
  jpegDataUrl: string;
};

export type AiScenePickInput = {
  sourcePath: string;
  trimStartSec: number;
  trimEndSec: number;
  frames: AiScenePickFrame[];
  signal?: AbortSignal;
};

export interface AiScenePickProvider {
  pick(input: AiScenePickInput): Promise<AiScenePickResult>;
}

const VALID_FAMILIES: ReadonlySet<OpticalFamily> = new Set([
  "mist",
  "glow",
  "cross",
  "lens",
]);

const VALID_RECIPES: ReadonlySet<OpticalRecipeId> = new Set([
  "warmIndoor",
  "nightCity",
  "skinCloseUp",
  "nightSpot",
  "productEdge",
  "coverStillMatch",
]);

const VALID_CONFIDENCE: ReadonlySet<AiScenePickConfidence> = new Set([
  "low",
  "medium",
  "high",
]);

function fallbackResult(reason: string, latencyMs: number): AiScenePickResult {
  return {
    bestFrameIndex: null,
    family: null,
    recipe: null,
    confidence: "low",
    manualFallback: true,
    reason,
    latencyMs,
  };
}

function coerceFrameIndex(
  raw: unknown,
  frameCount: number,
): number | null {
  if (typeof raw !== "number" || !Number.isFinite(raw)) return null;
  const rounded = Math.round(raw);
  if (rounded < 0 || rounded >= frameCount) return null;
  return rounded;
}

export function parseAiScenePickPayload(
  raw: unknown,
  frameCount: number,
  latencyMs: number,
  rawJson?: string,
): AiScenePickResult {
  if (raw == null || typeof raw !== "object") {
    return fallbackResult("invalid-response-shape", latencyMs);
  }
  const record = raw as Record<string, unknown>;

  const manualFallback = record.manualFallback === true;
  const confidenceRaw =
    typeof record.confidence === "string" ? record.confidence : "low";
  const confidence: AiScenePickConfidence = VALID_CONFIDENCE.has(
    confidenceRaw as AiScenePickConfidence,
  )
    ? (confidenceRaw as AiScenePickConfidence)
    : "low";

  const reasonRaw = typeof record.reason === "string" ? record.reason : "";
  const reason = reasonRaw.trim().slice(0, 500);

  const familyRaw = record.family;
  const family: OpticalFamily | null =
    typeof familyRaw === "string" && VALID_FAMILIES.has(familyRaw as OpticalFamily)
      ? (familyRaw as OpticalFamily)
      : null;

  const recipeRaw = record.recipe;
  const recipe: OpticalRecipeId | null =
    typeof recipeRaw === "string" && VALID_RECIPES.has(recipeRaw as OpticalRecipeId)
      ? (recipeRaw as OpticalRecipeId)
      : null;

  const bestFrameIndex = coerceFrameIndex(record.bestFrameIndex, frameCount);

  const mustFallback =
    manualFallback ||
    family == null ||
    bestFrameIndex == null ||
    (typeof familyRaw === "string" && family == null) ||
    (typeof recipeRaw === "string" && recipe == null);

  if (mustFallback) {
    return {
      bestFrameIndex,
      family,
      recipe,
      confidence: "low",
      manualFallback: true,
      reason: reason || "manual-fallback",
      latencyMs,
      rawJson,
    };
  }

  return {
    bestFrameIndex,
    family,
    recipe,
    confidence,
    manualFallback: false,
    reason,
    latencyMs,
    rawJson,
  };
}

export class BffAiScenePickProvider implements AiScenePickProvider {
  constructor(private readonly baseUrl: string = "http://localhost:3000") {}

  async pick(input: AiScenePickInput): Promise<AiScenePickResult> {
    if (input.frames.length === 0) {
      return fallbackResult("no-frames", 0);
    }

    const startedAt = performance.now();
    const payload = {
      sourcePath: input.sourcePath,
      trimStartSec: input.trimStartSec,
      trimEndSec: input.trimEndSec,
      frames: input.frames.map((frame) => ({
        index: frame.index,
        timeSec: frame.timeSec,
        jpegDataUrl: frame.jpegDataUrl,
      })),
    };

    const url = `${this.baseUrl.replace(/\/$/, "")}/api/film-lab/ai/scene-pick`;

    let response: Response;
    try {
      response = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(payload),
        credentials: "include",
        signal: input.signal,
      });
    } catch (error) {
      const latencyMs = performance.now() - startedAt;
      return fallbackResult(
        `fetch-failed: ${error instanceof Error ? error.message : String(error)}`,
        latencyMs,
      );
    }

    const latencyMs = performance.now() - startedAt;

    if (!response.ok) {
      return fallbackResult(
        `http-${response.status}`,
        latencyMs,
      );
    }

    let body: unknown;
    let rawText: string | undefined;
    try {
      rawText = await response.text();
      body = JSON.parse(rawText) as unknown;
    } catch (error) {
      return {
        ...fallbackResult(
          `parse-failed: ${error instanceof Error ? error.message : String(error)}`,
          latencyMs,
        ),
        rawJson: rawText,
      };
    }

    if (body == null || typeof body !== "object") {
      return {
        ...fallbackResult("invalid-response-shape", latencyMs),
        rawJson: rawText,
      };
    }

    const envelope = body as { ok?: unknown; pick?: unknown; code?: unknown };
    if (envelope.ok !== true) {
      const code =
        typeof envelope.code === "string" ? envelope.code : "provider-error";
      return {
        ...fallbackResult(`bff-not-ok: ${code}`, latencyMs),
        rawJson: rawText,
      };
    }

    return parseAiScenePickPayload(
      envelope.pick,
      input.frames.length,
      latencyMs,
      rawText,
    );
  }
}
