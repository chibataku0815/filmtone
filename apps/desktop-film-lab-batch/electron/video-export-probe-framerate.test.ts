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
    expect(r.avgFrameRate).toBe("24000/1001");
    expect(r.rFrameRate).toBe("24000/1001");
    expect(r.avgFrameRateParsed).toBeCloseTo(24000 / 1001, 5);
    expect(r.rFrameRateParsed).toBeCloseTo(24000 / 1001, 5);
    expect(r.trustReason).toBe("within-absolute-tolerance");
  });

  it("does not trust when rates diverge beyond tolerance", () => {
    const r = deriveSourceFrameRateTrust("30/1", "24000/1001");
    expect(r.sourceFrameRateTrusted).toBe(false);
    expect(r.sourceFrameRate).toBeNull();
    expect(r.avgFrameRateParsed).toBe(30);
    expect(r.rFrameRateParsed).toBeCloseTo(24000 / 1001, 5);
    expect(r.trustReason).toBe("rates-diverged");
  });

  it("trusts when difference is within absolute 0.01 fps", () => {
    const r = deriveSourceFrameRateTrust("24.005", "24.000");
    expect(r.sourceFrameRateTrusted).toBe(true);
    expect(r.trustReason).toBe("within-absolute-tolerance");
  });

  it("trusts when difference is within relative tolerance", () => {
    const r = deriveSourceFrameRateTrust("120/1", "119.5");
    expect(r.sourceFrameRateTrusted).toBe(true);
    expect(r.trustReason).toBe("within-relative-tolerance");
  });

  it("keeps invalid raw rates for diagnostics", () => {
    const r = deriveSourceFrameRateTrust("0/0", "not-a-rate");
    expect(r.sourceFrameRateTrusted).toBe(false);
    expect(r.sourceFrameRate).toBeNull();
    expect(r.avgFrameRate).toBe("0/0");
    expect(r.rFrameRate).toBe("not-a-rate");
    expect(r.avgFrameRateParsed).toBeNull();
    expect(r.rFrameRateParsed).toBeNull();
    expect(r.trustReason).toBe("missing-or-invalid-rate");
  });
});
