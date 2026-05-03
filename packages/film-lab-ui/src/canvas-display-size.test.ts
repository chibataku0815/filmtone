import { describe, expect, it } from "vitest";

import { computeContainedCanvasDisplaySize } from "./canvas-display-size";

describe("computeContainedCanvasDisplaySize", () => {
  it("keeps landscape canvas undistorted inside a square host", () => {
    expect(
      computeContainedCanvasDisplaySize({
        containerWidth: 1000,
        containerHeight: 1000,
        contentWidth: 1920,
        contentHeight: 1080,
      }),
    ).toEqual({
      width: 1000,
      height: 562.5,
    });
  });

  it("keeps portrait canvas undistorted inside a wide host", () => {
    expect(
      computeContainedCanvasDisplaySize({
        containerWidth: 1200,
        containerHeight: 700,
        contentWidth: 608,
        contentHeight: 1080,
      }),
    ).toEqual({
      width: 394.0740740740741,
      height: 700,
    });
  });

  it("fills the host when content and host share the same aspect", () => {
    expect(
      computeContainedCanvasDisplaySize({
        containerWidth: 1600,
        containerHeight: 900,
        contentWidth: 1920,
        contentHeight: 1080,
      }),
    ).toEqual({
      width: 1600,
      height: 900,
    });
  });
});
