import { describe, expect, it } from "vitest";

import { computeExportRenderGeometry } from "./export-render-geometry";

describe("computeExportRenderGeometry", () => {
  it("keeps 1920x1080 sources at native export size", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 1920,
        sourceHeight: 1080,
        fps: 29.97002997,
      }),
    ).toEqual({
      renderWidth: 1920,
      renderHeight: 1080,
      sourceWidth: 1920,
      sourceHeight: 1080,
      sourceDisplayWidth: 1920,
      sourceDisplayHeight: 1080,
      fitMode: "cover",
      fps: 29.97002997,
    });
  });

  it("downscales 4K landscape sources to FHD", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 3840,
        sourceHeight: 2160,
      }),
    ).toMatchObject({
      renderWidth: 1920,
      renderHeight: 1080,
      sourceWidth: 3840,
      sourceHeight: 2160,
      sourceDisplayWidth: 3840,
      sourceDisplayHeight: 2160,
      fitMode: "cover",
    });
  });

  it("preserves portrait aspect inside the FHD cap", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 2160,
        sourceHeight: 3840,
      }),
    ).toMatchObject({
      renderWidth: 608,
      renderHeight: 1080,
      sourceWidth: 2160,
      sourceHeight: 3840,
      sourceDisplayWidth: 2160,
      sourceDisplayHeight: 3840,
      fitMode: "contain",
    });
  });

  it("does not upscale small sources", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 1280,
        sourceHeight: 720,
      }),
    ).toMatchObject({
      renderWidth: 1280,
      renderHeight: 720,
      sourceWidth: 1280,
      sourceHeight: 720,
      sourceDisplayWidth: 1280,
      sourceDisplayHeight: 720,
      fitMode: "cover",
    });
  });

  it("falls back to positive FHD geometry for bad dimensions", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 0,
        sourceHeight: Number.NaN,
      }),
    ).toEqual({
      renderWidth: 1920,
      renderHeight: 1080,
      sourceWidth: 1920,
      sourceHeight: 1080,
      sourceDisplayWidth: 1920,
      sourceDisplayHeight: 1080,
      fitMode: "cover",
    });
  });

  it("uses display dimensions for rotated source geometry", () => {
    expect(
      computeExportRenderGeometry({
        sourceWidth: 3840,
        sourceHeight: 2160,
        sourceDisplayWidth: 2160,
        sourceDisplayHeight: 3840,
        fitMode: "cover",
      }),
    ).toMatchObject({
      renderWidth: 608,
      renderHeight: 1080,
      sourceWidth: 3840,
      sourceHeight: 2160,
      sourceDisplayWidth: 2160,
      sourceDisplayHeight: 3840,
      fitMode: "cover",
    });
  });
});
