import { describe, expect, it } from "vitest";

import { formatCameraOpticsForProbeLabel } from "./video-probe-label";

describe("video-probe-label", () => {
  it("formats camera optics so pre/post edit display metadata can match", () => {
    expect(
      formatCameraOpticsForProbeLabel({
        source: "manual",
        fovXDeg: 62.8,
        focalLength35mm: 28,
        lensModel: "Desktop E2E Wide",
        cameraMake: "Filmtone",
        cameraModel: "Desktop RoundTrip",
      }),
    ).toBe(
      "Filmtone Desktop RoundTrip · Desktop E2E Wide · 28mm eq · HFOV 62.8deg · manual",
    );
  });

  it("keeps assumed optics visibly distinct from metadata-derived optics", () => {
    expect(
      formatCameraOpticsForProbeLabel({
        source: "assumed",
        fovXDeg: 62.79007757067723,
      }),
    ).toBe("HFOV 62.8deg · assumed");
  });
});
