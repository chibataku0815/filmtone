import { describe, expect, it } from "vitest";

import {
  computeExportFrameCount,
  formatVideoExportFps,
  sanitizeVideoExportFps,
  selectVideoExportFps,
  VIDEO_EXPORT_FALLBACK_FPS,
} from "./video-export-constants";

describe("video-export-constants", () => {
  it("keeps trusted source fps for frame count", () => {
    const fps = selectVideoExportFps({
      sourceFrameRate: 25,
      sourceFrameRateTrusted: true,
    });

    expect(fps).toBe(25);
    expect(computeExportFrameCount(20.36, fps)).toBe(509);
  });

  it("falls back to 24fps when source fps is not trusted", () => {
    const fps = selectVideoExportFps({
      sourceFrameRate: 25,
      sourceFrameRateTrusted: false,
    });

    expect(fps).toBe(VIDEO_EXPORT_FALLBACK_FPS);
    expect(computeExportFrameCount(20.36, fps)).toBe(488);
  });

  it("rejects invalid fps values", () => {
    expect(sanitizeVideoExportFps(null)).toBeNull();
    expect(sanitizeVideoExportFps(Number.NaN)).toBeNull();
    expect(sanitizeVideoExportFps(0.5)).toBeNull();
    expect(sanitizeVideoExportFps(240)).toBeNull();
  });

  it("formats integer and fractional fps for UI/logs", () => {
    expect(formatVideoExportFps(25)).toBe("25");
    expect(formatVideoExportFps(29.97002997)).toBe("29.97");
  });
});
