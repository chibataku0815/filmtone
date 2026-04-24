/**
 * @fileoverview ffprobe source metadata normalization tests.
 */
import { describe, expect, it } from "vitest";

import { deriveVideoDisplayGeometryFromFfprobeStream } from "./video-export-source-metadata";

describe("video-export-source-metadata", () => {
  it("keeps raw dimensions when no rotation metadata is present", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: 1920,
      rawHeight: 1080,
    });

    expect(display).toEqual({
      rawWidth: 1920,
      rawHeight: 1080,
      displayWidth: 1920,
      displayHeight: 1080,
      rotationDeg: null,
      source: "raw",
    });
  });

  it("swaps display dimensions for a 90 degree Display Matrix", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
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

    expect(display.displayWidth).toBe(1080);
    expect(display.displayHeight).toBe(1920);
    expect(display.rotationDeg).toBe(90);
    expect(display.source).toBe("ffprobe-side-data");
  });

  it("normalizes negative Display Matrix rotation to 270 degrees", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: 1920,
      rawHeight: 1080,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: "-90.000000",
          },
        ],
      },
    });

    expect(display.displayWidth).toBe(1080);
    expect(display.displayHeight).toBe(1920);
    expect(display.rotationDeg).toBe(270);
    expect(display.source).toBe("ffprobe-side-data");
  });

  it("falls back to rotate tags when Display Matrix is missing", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: 3840,
      rawHeight: 2160,
      stream: {
        tags: {
          rotate: "90",
        },
      },
    });

    expect(display.displayWidth).toBe(2160);
    expect(display.displayHeight).toBe(3840);
    expect(display.rotationDeg).toBe(90);
    expect(display.source).toBe("ffprobe-tags");
  });

  it("keeps dimensions for 180 degree rotation", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: 1280,
      rawHeight: 720,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: 180,
          },
        ],
      },
    });

    expect(display.displayWidth).toBe(1280);
    expect(display.displayHeight).toBe(720);
    expect(display.rotationDeg).toBe(180);
    expect(display.source).toBe("ffprobe-side-data");
  });

  it("ignores malformed rotation metadata", () => {
    const display = deriveVideoDisplayGeometryFromFfprobeStream({
      rawWidth: 1000,
      rawHeight: 1000,
      stream: {
        side_data_list: [
          {
            side_data_type: "Display Matrix",
            rotation: "not-a-number",
          },
        ],
        tags: {
          rotate: "also-invalid",
        },
      },
    });

    expect(display.displayWidth).toBe(1000);
    expect(display.displayHeight).toBe(1000);
    expect(display.rotationDeg).toBeNull();
    expect(display.source).toBe("raw");
  });
});

