/**
 * @fileoverview ソースフレーム再利用判定の純関数テスト
 */
import { describe, expect, it } from "vitest";

import {
  computeTargetSourceFrameIndex,
  shouldReuseDecodedSourceFrame,
} from "./video-export-frame-reuse";

describe("video-export-frame-reuse", () => {
  it("returns null index when not trusted", () => {
    expect(
      computeTargetSourceFrameIndex(1 / 24, 24, false),
    ).toBeNull();
  });

  it("maps time to frame index when trusted", () => {
    expect(computeTargetSourceFrameIndex(0, 24, true)).toBe(0);
    expect(
      computeTargetSourceFrameIndex(3 / 24 - 1e-7, 24, true),
    ).toBe(2);
    expect(computeTargetSourceFrameIndex(1, 24, true)).toBe(24);
  });

  it("detects reuse when last and target match", () => {
    expect(shouldReuseDecodedSourceFrame(3, 3)).toBe(true);
    expect(shouldReuseDecodedSourceFrame(3, 4)).toBe(false);
    expect(shouldReuseDecodedSourceFrame(null, 0)).toBe(false);
  });
});
