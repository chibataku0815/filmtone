/**
 * @fileoverview ffprobe フレームレート文字列のパースと信任判定のテスト
 */
import { describe, expect, it } from "vitest";

import {
  deriveSourceFrameRateTrust,
  parseFfprobeFrameRateRate,
} from "./video-export-probe-framerate";

describe("video-export-probe-framerate", () => {
  it("parses rational NTSC rate", () => {
    expect(parseFfprobeFrameRateRate("30000/1001")).toBeCloseTo(30000 / 1001, 5);
  });

  it("parses integer fps string", () => {
    expect(parseFfprobeFrameRateRate("30/1")).toBe(30);
  });

  it("trusts when avg and r_frame_rate agree tightly", () => {
    const r = deriveSourceFrameRateTrust("24000/1001", "24000/1001");
    expect(r.sourceFrameRateTrusted).toBe(true);
    expect(r.sourceFrameRate).toBeCloseTo(24000 / 1001, 5);
  });

  it("does not trust when rates diverge beyond tolerance", () => {
    const r = deriveSourceFrameRateTrust("30/1", "24000/1001");
    expect(r.sourceFrameRateTrusted).toBe(false);
    expect(r.sourceFrameRate).toBeNull();
  });

  it("trusts when difference is within absolute 0.01 fps", () => {
    const r = deriveSourceFrameRateTrust("24.005", "24.000");
    expect(r.sourceFrameRateTrusted).toBe(true);
  });
});
