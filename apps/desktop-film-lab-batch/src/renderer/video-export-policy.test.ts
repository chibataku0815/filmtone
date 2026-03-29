import { describe, expect, it } from "vitest";

import {
  defaultVideoExportWebglAccurate,
  shouldUseFastVideoExport,
} from "./video-export-policy";

describe("video-export-policy", () => {
  it("defaults to preview-accurate WebGL export until the user opts into fast ffmpeg", () => {
    expect(defaultVideoExportWebglAccurate()).toBe(true);
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
