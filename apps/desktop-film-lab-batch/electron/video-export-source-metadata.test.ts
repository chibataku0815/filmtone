/**
 * @fileoverview ffprobe source metadata normalization tests.
 */
import { describe, expect, it } from "vitest";

import {
  classifySourceColorForExport,
  deriveSourceColorMetadataFromFfprobeStream,
  deriveVideoDisplayGeometryFromFfprobeStream,
} from "./video-export-source-metadata";

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

describe("source color metadata", () => {
  it("classifies explicit BT.709 metadata as SDR BT.709", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_range: "tv",
      color_space: "bt709",
      color_transfer: "bt709",
      color_primaries: "bt709",
    });

    expect(color).toEqual({
      colorRange: "tv",
      colorSpace: "bt709",
      colorTransfer: "bt709",
      colorPrimaries: "bt709",
      hasMasteringDisplayMetadata: false,
      hasContentLightMetadata: false,
    });
    expect(classifySourceColorForExport(color)).toBe("sdr-bt709");
  });

  it("classifies SMPTE 2084 transfer as HDR PQ", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_range: "tv",
      color_space: "bt2020nc",
      color_transfer: "smpte2084",
      color_primaries: "bt2020",
      side_data_list: [
        {
          side_data_type: "Mastering display metadata",
        },
        {
          side_data_type: "Content light level metadata",
        },
      ],
    });

    expect(color.hasMasteringDisplayMetadata).toBe(true);
    expect(color.hasContentLightMetadata).toBe(true);
    expect(classifySourceColorForExport(color)).toBe("hdr-pq");
  });

  it("classifies ARIB STD-B67 transfer as HDR HLG", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "arib-std-b67",
      color_primaries: "bt2020",
    });

    expect(classifySourceColorForExport(color)).toBe("hdr-hlg");
  });

  it("classifies BT.2020 without transfer metadata as wide-gamut unknown", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_primaries: "bt2020",
    });

    expect(classifySourceColorForExport(color)).toBe("wide-gamut-unknown");
  });

  it("classifies HDR side data without explicit transfer as wide-gamut unknown", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt709",
      color_transfer: "bt709",
      color_primaries: "bt709",
      side_data_list: [
        {
          side_data_type: "Mastering display metadata",
        },
      ],
    });

    expect(classifySourceColorForExport(color)).toBe("wide-gamut-unknown");
  });

  it("normalizes missing or unspecified color metadata to unknown", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_range: "unknown",
      color_space: "unspecified",
      color_transfer: "",
      color_primaries: "reserved",
    });

    expect(color).toEqual({
      colorRange: null,
      colorSpace: null,
      colorTransfer: null,
      colorPrimaries: null,
      hasMasteringDisplayMetadata: false,
      hasContentLightMetadata: false,
    });
    expect(classifySourceColorForExport(color)).toBe("unknown");
  });
});
