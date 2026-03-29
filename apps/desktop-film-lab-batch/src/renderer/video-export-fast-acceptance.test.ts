import { describe, expect, it } from "vitest";

import { FAST_VIDEO_EXPORT_INTERNAL_ACCEPTANCE_CASES } from "./video-export-fast-acceptance";

describe("video-export-fast-acceptance", () => {
  it("tracks the minimum internal parity matrix required before fast re-enable", () => {
    expect(
      FAST_VIDEO_EXPORT_INTERNAL_ACCEPTANCE_CASES.map((item) => item.id),
    ).toEqual([
      "preset-only",
      "preview-sync-slider-only",
      "imported-json-with-lut",
      "imported-json-without-lut",
      "audio-present",
      "audio-absent",
    ]);
  });
});
