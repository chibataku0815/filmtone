/**
 * @fileoverview ffprobe camera optics derivation tests.
 */
import { describe, expect, it } from "vitest";

import { deriveCameraOpticsFromFfprobeMeta } from "./video-export-camera-optics";

describe("video-export-camera-optics", () => {
  it("builds assumed centered intrinsics from 70 degree diagonal FOV", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(960);
    expect(optics.cyPx).toBe(540);
    expect(optics.fxPx).toBeCloseTo(optics.fyPx ?? 0, 5);
    expect(optics.fovXDeg).toBeCloseTo(62.8, 1);
    expect(optics.fovYDeg).toBeCloseTo(37.9, 1);
  });

  it("uses stream focal metadata before format metadata", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          "com.apple.quicktime.camera.focal_length.35mm_equivalent": "28 mm",
          "com.apple.quicktime.camera.lens_model": "Wide Camera",
        },
      },
      format: {
        tags: {
          "com.apple.quicktime.camera.focal_length.35mm_equivalent": "50 mm",
          "com.apple.quicktime.camera.make": "Apple",
          "com.apple.quicktime.camera.model": "iPhone",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.focalLength35mm).toBe(28);
    expect(optics.lensModel).toBe("Wide Camera");
    expect(optics.cameraMake).toBe("Apple");
    expect(optics.cameraModel).toBe("iPhone");
  });

  it("falls back to assumed optics when focal metadata is invalid", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          "camera.focal_length.35mm_equivalent": "unknown",
        },
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.focalLength35mm).toBeUndefined();
  });

  it("uses display-matrix rotation for display-space intrinsics", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: 90,
          },
        ],
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(540);
    expect(optics.cyPx).toBe(960);
    expect(optics.fovXDeg).toBeCloseTo(37.9, 1);
    expect(optics.fovYDeg).toBeCloseTo(62.8, 1);
  });

  it("uses negative display-matrix rotation for portrait display-space intrinsics", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: -90,
          },
        ],
      },
    });

    expect(optics.source).toBe("assumed");
    expect(optics.cxPx).toBe(540);
    expect(optics.cyPx).toBe(960);
    expect(optics.fovXDeg).toBeCloseTo(37.9, 1);
    expect(optics.fovYDeg).toBeCloseTo(62.8, 1);
  });

  it("derives metadata optics from a horizontal FOV tag", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        tags: {
          horizontal_field_of_view: "60",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBe(60);
    expect(optics.fovYDeg).toBeCloseTo(36, 0);
    expect(optics.fxPx).toBeCloseTo(1662.8, 1);
  });

  it("prefers rational side-data horizontal FOV over tag fallback", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Stereo 3D",
            horizontal_field_of_view: "62800/1000",
          },
        ],
        tags: {
          horizontal_field_of_view: "70",
        },
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBeCloseTo(62.8, 5);
    expect(optics.fxPx).toBeCloseTo(1572.7, 1);
  });

  it("accepts thousandths-degree side-data HFOV values", () => {
    const optics = deriveCameraOpticsFromFfprobeMeta({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Stereo 3D",
            hfov: 62800,
          },
        ],
      },
    });

    expect(optics.source).toBe("metadata");
    expect(optics.fovXDeg).toBeCloseTo(62.8, 5);
  });
});
