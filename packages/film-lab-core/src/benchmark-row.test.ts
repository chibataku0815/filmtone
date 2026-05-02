import { describe, expect, test } from "bun:test";
import {
  buildBenchmarkRow,
  formatBenchmarkRow,
  parseBenchmarkRow,
} from "./benchmark-row";
import type {
  Phase0ExportBenchmarkRecord,
  Phase0ExportResult,
  Phase0MezzanineProfileVariant,
} from "./native-bridge";

const baseBenchmark: Phase0ExportBenchmarkRecord = {
  appVersion: "0.1.0",
  buildNumber: "42",
  deviceModel: "iPhone15,3",
  iosVersion: "18.1",
  sourceCodec: "h264",
  sourceResolution: "1920x1080",
  sourceDurationSec: 60,
  outputFileSizeBytes: 32_000_000,
  elapsedMs: 102_000,
  realtimeRatio: 1.7,
  thermalState: "nominal->nominal",
  memoryWarningCount: 0,
  permissionResult: "granted",
  saveToPhotosOk: true,
  errorDomain: undefined,
  errorCode: undefined,
};

const baseResult: Phase0ExportResult = {
  outputUri: "file:///tmp/out.mp4",
  elapsedMs: 102_000,
  outputWidth: 1920,
  outputHeight: 1080,
  outputFps: 30,
  fileSizeBytes: 32_000_000,
  realtimeRatio: 1.7,
  audioPreserved: true,
  benchmarkRecord: baseBenchmark,
};

describe("benchmark row roundtrip", () => {
  test("formats and parses a success row", () => {
    const row = buildBenchmarkRow({
      result: baseResult,
      benchmark: baseBenchmark,
      probe: null,
      clipId: "clip-60s.mov",
      visualFloor: "pass",
      saveResult: "ok",
      date: new Date("2026-04-18T08:00:00.000Z"),
    });
    const formatted = formatBenchmarkRow(row);
    expect(formatted).toContain("iPhone15,3");
    expect(formatted).toContain("clip-60s.mov");
    expect(formatted).toContain("1.7x");
    expect(formatted).toContain("save=ok");
    expect(formatted).toContain("visual=pass");
    expect(formatted).toContain("err=none");

    const parsed = parseBenchmarkRow(formatted);
    expect(parsed).not.toBeNull();
    expect(parsed?.deviceModel).toBe("iPhone15,3");
    expect(parsed?.realtimeRatio).toBe(1.7);
    expect(parsed?.fileSizeMb).toBeGreaterThan(0);
    expect(parsed?.saveResult).toBe("ok");
    expect(parsed?.visualFloor).toBe("pass");
    expect(parsed?.errorDomain).toBeNull();
    expect(parsed?.errorCode).toBeNull();
    expect(parsed?.durationSec).toBe(60);
  });

  test("ignores header and divider rows", () => {
    expect(parseBenchmarkRow("| date | device | iOS | clip_id |")).toBeNull();
    expect(parseBenchmarkRow("| --- | --- | --- | --- |")).toBeNull();
  });

  test("captures error domain and code on failure rows", () => {
    const failBenchmark: Phase0ExportBenchmarkRecord = {
      ...baseBenchmark,
      errorDomain: "FilmtoneMediaError",
      errorCode: "EXPORT_FAILED",
      saveToPhotosOk: undefined,
    };
    const row = buildBenchmarkRow({
      result: { ...baseResult, benchmarkRecord: failBenchmark },
      benchmark: failBenchmark,
      probe: null,
      clipId: "clip-60s.mov",
      visualFloor: "fail",
      saveResult: "fail",
      date: new Date("2026-04-18T08:00:00.000Z"),
    });
    const formatted = formatBenchmarkRow(row);
    const parsed = parseBenchmarkRow(formatted);
    expect(parsed?.errorDomain).toBe("FilmtoneMediaError");
    expect(parsed?.errorCode).toBe("EXPORT_FAILED");
    expect(parsed?.visualFloor).toBe("fail");
    expect(parsed?.saveResult).toBe("fail");
  });

  test("roundtrips all mezzanine profile variants", () => {
    const variants: Phase0MezzanineProfileVariant[] = [
      "sdr",
      "hdr",
      "qualitySDR",
      "qualityHDR",
    ];

    for (const variant of variants) {
      const benchmark: Phase0ExportBenchmarkRecord = {
        ...baseBenchmark,
        renderMode: variant.startsWith("quality") ? "quality" : "speed",
        exportUsedMezzanine: true,
        mezzanineProfileVariant: variant,
      };
      const row = buildBenchmarkRow({
        result: { ...baseResult, benchmarkRecord: benchmark },
        benchmark,
        probe: null,
        clipId: `${variant}.mov`,
        visualFloor: "pass",
        saveResult: "ok",
        date: new Date("2026-05-02T08:00:00.000Z"),
      });
      const formatted = formatBenchmarkRow(row);

      expect(formatted).toContain(`mezz=${variant}`);
      expect(parseBenchmarkRow(formatted)?.mezzanineProfileVariant).toBe(variant);
    }
  });

  test("parses unknown mezzanine profile variants as null", () => {
    const row =
      "| 2026-05-02 | iPhone15,3 | 18.1 | future.mov | 3840x2160 | 3840x2160@30 | 1.2x | 100MB | thermal=nominal | mem_warn=0 | save=ok | visual=pass | err=none | 60.0 | mode=quality | mezz=futureVariant |";

    expect(parseBenchmarkRow(row)?.mezzanineProfileVariant).toBeNull();
  });
});
