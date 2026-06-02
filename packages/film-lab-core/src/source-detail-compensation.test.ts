import { describe, expect, test } from "bun:test";
import { DETAIL_SOFTNESS_EFFECTIVE_MAX } from "./detail-softness";
import {
  resolveSourceDetailCompensation,
  type SourceDetailProfile,
} from "./source-detail-compensation";

const expectBiasIn = (profile: SourceDetailProfile, lo: number, hi: number) => {
  expect(profile.recommendedBias).toBeGreaterThanOrEqual(lo);
  expect(profile.recommendedBias).toBeLessThanOrEqual(hi);
};

describe("resolveSourceDetailCompensation — tuning table", () => {
  test("iPhone SDR / HEVC produces a modest positive bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Apple",
      cameraModel: "iPhone 17 Pro",
      codecFamily: "hevc",
      colorClass: "sdr-bt709",
    });
    expect(profile.id).toBe("iphone-sdr-hevc");
    expect(profile.transferClass).toBe("rec709-consumer");
    expect(profile.confidence).toBe("high");
    expect(profile.recommendedBias).toBe(0.1);
  });

  test("iPhone identified by cameraModel only still resolves", () => {
    const profile = resolveSourceDetailCompensation({
      cameraModel: "iPhone 15",
      codecFamily: "hevc",
    });
    expect(profile.id).toBe("iphone-sdr-hevc");
    expect(profile.recommendedBias).toBe(0.1);
  });

  test("Apple Log via logTransferFunction yields smaller positive bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Apple",
      cameraModel: "iPhone 17 Pro",
      codecFamily: "prores-422",
      logTransferFunction: "apple-log",
      colorClass: "apple-log",
    });
    expect(profile.id).toBe("apple-log");
    expect(profile.transferClass).toBe("log-consumer");
    expect(profile.confidence).toBe("high");
    expect(profile.recommendedBias).toBe(0.06);
  });

  test("Apple Log via input-transform policy alone matches even without cameraMake", () => {
    const profile = resolveSourceDetailCompensation({
      inputTransformPolicy: {
        strategy: "apple-log-to-rec709",
        reason: "source-is-apple-log",
        requiresFixtureValidation: false,
        warning: null,
      },
    });
    expect(profile.id).toBe("apple-log");
    expect(profile.recommendedBias).toBe(0.06);
  });

  test("Apple Log 2 via source-profile id matches", () => {
    const profile = resolveSourceDetailCompensation({
      sourceProfileId: "built-in:source-profile.apple-log-2",
    });
    expect(profile.id).toBe("apple-log");
    expect(profile.recommendedBias).toBe(0.06);
  });

  test("ARRI LogC3 via source-profile id produces log-cinema near-zero bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Panasonic",
      cameraModel: "LUMIX S1II",
      sourceProfileId: "built-in:source-profile.arri-logc3",
    });
    expect(profile.id).toBe("arri-logc3");
    expect(profile.transferClass).toBe("log-cinema");
    expect(profile.confidence).toBe("high");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("DJI metadata produces positive bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "DJI",
      cameraModel: "Osmo Action 4",
      codecFamily: "h264",
    });
    expect(profile.id).toBe("dji-action");
    expect(profile.transferClass).toBe("rec709-consumer");
    expect(profile.recommendedBias).toBe(0.08);
  });

  test("DJI D-Log selected via built-in source profile id matches DJI class", () => {
    const profile = resolveSourceDetailCompensation({
      sourceProfileId: "built-in:source-profile.dji-dlog",
    });
    expect(profile.id).toBe("dji-action");
    expect(profile.confidence).toBe("high");
    expect(profile.recommendedBias).toBe(0.08);
  });

  test("GoPro style metadata produces positive bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "GoPro",
      cameraModel: "HERO12 Black",
      codecFamily: "hevc",
    });
    expect(profile.id).toBe("gopro-action");
    expect(profile.recommendedBias).toBe(0.08);
  });

  test("Sony S-Log3 metadata produces near-zero bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Sony",
      cameraModel: "ILCE-7SM3",
      sourceProfileId: "built-in:source-profile.sony-slog3",
    });
    expect(profile.id).toBe("sony-slog3");
    expect(profile.transferClass).toBe("log-cinema");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("Canon C-Log via source-profile id resolves to canon-clog", () => {
    const profile = resolveSourceDetailCompensation({
      sourceProfileId: "built-in:source-profile.canon-log3-cinema-gamut",
    });
    expect(profile.id).toBe("canon-clog");
    expect(profile.transferClass).toBe("log-cinema");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("Panasonic V-Log via cameraMake produces near-zero bias", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Panasonic",
    });
    expect(profile.id).toBe("panasonic-vlog");
    expect(profile.transferClass).toBe("log-cinema");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("unknown Rec.709 (codec-family-only) yields a tiny positive bias", () => {
    const profile = resolveSourceDetailCompensation({
      codecFamily: "h264",
    });
    expect(profile.id).toBe("rec709-unknown");
    expect(profile.transferClass).toBe("rec709-consumer");
    expect(profile.confidence).toBe("low");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("explicit Rec.709 source-profile id matches the rec709-unknown class", () => {
    const profile = resolveSourceDetailCompensation({
      sourceProfileId: "built-in:source-profile.rec709",
    });
    expect(profile.id).toBe("rec709-unknown");
    expect(profile.recommendedBias).toBe(0.02);
  });

  test("unknown log transfer (no make + only transfer signal) returns zero bias", () => {
    const profile = resolveSourceDetailCompensation({
      inputTransformPolicy: {
        strategy: "core-image-tone-map-sdr",
        reason: "source-is-hdr-pq",
        requiresFixtureValidation: false,
        warning: null,
      },
    });
    expect(profile.id).toBe("log-unknown");
    expect(profile.transferClass).toBe("unknown");
    expect(profile.recommendedBias).toBe(0);
  });

  test("completely missing metadata returns zero bias", () => {
    const profile = resolveSourceDetailCompensation({});
    expect(profile.id).toBe("metadata-missing");
    expect(profile.confidence).toBe("none");
    expect(profile.recommendedBias).toBe(0);
  });

  test("explicit undefined input also returns zero bias", () => {
    const profile = resolveSourceDetailCompensation();
    expect(profile.id).toBe("metadata-missing");
    expect(profile.recommendedBias).toBe(0);
  });
});

describe("resolveSourceDetailCompensation — invariants", () => {
  test("recommendedBias is always within [0, DETAIL_SOFTNESS_EFFECTIVE_MAX]", () => {
    const cases = [
      { cameraMake: "Apple", codecFamily: "hevc" as const },
      { sourceProfileId: "built-in:source-profile.arri-logc3" },
      { cameraMake: "DJI" },
      { cameraMake: "GoPro" },
      { cameraMake: "Sony" },
      { cameraMake: "Canon" },
      { cameraMake: "Panasonic" },
      { codecFamily: "h264" as const },
      { logTransferFunction: "apple-log" as const },
      {},
    ];
    for (const input of cases) {
      const profile = resolveSourceDetailCompensation(input);
      expectBiasIn(profile, 0, DETAIL_SOFTNESS_EFFECTIVE_MAX);
    }
  });

  test("effectiveMax always mirrors the renderer constant", () => {
    const profile = resolveSourceDetailCompensation({ cameraMake: "Apple" });
    expect(profile.effectiveMax).toBe(DETAIL_SOFTNESS_EFFECTIVE_MAX);
  });

  test("camera-make matching is case-insensitive and whitespace-tolerant", () => {
    const upper = resolveSourceDetailCompensation({ cameraMake: "  SONY  " });
    expect(upper.id).toBe("sony-slog3");
    const mixed = resolveSourceDetailCompensation({ cameraMake: "Apple" });
    expect(mixed.id).toBe("iphone-sdr-hevc");
  });

  test("Apple Log signal overrides iPhone Rec.709 path when both present", () => {
    const profile = resolveSourceDetailCompensation({
      cameraMake: "Apple",
      cameraModel: "iPhone 17 Pro",
      logTransferFunction: "apple-log2",
    });
    expect(profile.id).toBe("apple-log");
    expect(profile.recommendedBias).toBe(0.06);
  });

  test("inputTransformPolicy.strategy === 'none' does not trigger log-unknown", () => {
    const profile = resolveSourceDetailCompensation({
      inputTransformPolicy: {
        strategy: "none",
        reason: "passthrough",
        requiresFixtureValidation: false,
        warning: null,
      },
    });
    expect(profile.id).toBe("metadata-missing");
    expect(profile.recommendedBias).toBe(0);
  });
});
