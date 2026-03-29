import { describe, expect, it } from "vitest";

import {
  defaultVideoExportWebglAccurate,
  shouldUseFastVideoExport,
} from "./video-export-policy";

describe("video-export-policy", () => {
  it("defaults to fast ffmpeg (WebGL off) when the user has not chosen preview-accurate export", () => {
    expect(defaultVideoExportWebglAccurate()).toBe(false);
  });

  it("uses the fast path only when the flag is enabled and accurate mode is explicitly disabled", () => {
    expect(
      shouldUseFastVideoExport({
        fastVideoExportEnabled: false,
        videoExportWebglAccurate: false,
      }),
    ).toBe(false);
    expect(
      shouldUseFastVideoExport({
        fastVideoExportEnabled: true,
        videoExportWebglAccurate: true,
      }),
    ).toBe(false);
    expect(
      shouldUseFastVideoExport({
        fastVideoExportEnabled: true,
        videoExportWebglAccurate: false,
      }),
    ).toBe(true);
  });
});
