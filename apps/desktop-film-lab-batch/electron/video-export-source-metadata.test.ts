/**
 * @fileoverview ffprobe source metadata normalization tests.
 */
import { describe, expect, it } from "vitest";

import {
  classifySourceColorForExport,
  deriveDesktopHdrPreparationPolicy,
  deriveSourceColorMetadataFromFfprobeStream,
  deriveVideoDisplayGeometryFromFfprobeStream,
  type SourceColorMetadata,
  type SourceVideoMetadata,
} from "./video-export-source-metadata";

const testDisplay: SourceVideoMetadata["display"] = {
  rawWidth: 1920,
  rawHeight: 1080,
  displayWidth: 1920,
  displayHeight: 1080,
  rotationDeg: null,
  source: "raw",
};

function sourceMetadataForColor(color: SourceColorMetadata): SourceVideoMetadata {
  return {
    display: testDisplay,
    color,
    colorClass: classifySourceColorForExport(color),
  };
}

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

describe("desktop HDR preparation policy", () => {
  it("does not prepare explicit BT.709 SDR sources", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt709",
      color_transfer: "bt709",
      color_primaries: "bt709",
    });

    expect(
      deriveDesktopHdrPreparationPolicy(sourceMetadataForColor(color)),
    ).toEqual({
      strategy: "none",
      reason: "source-is-sdr-bt709",
      requiresFixtureValidation: false,
      warning: null,
    });
  });

  it("prepares HDR PQ sources as SDR mezzanine candidates with fixture validation required", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "smpte2084",
      color_primaries: "bt2020",
    });

    expect(
      deriveDesktopHdrPreparationPolicy(sourceMetadataForColor(color)),
    ).toEqual({
      strategy: "prepare-sdr-mezzanine",
      reason: "source-is-hdr-pq",
      requiresFixtureValidation: true,
      warning: null,
    });
  });

  it("prepares HDR HLG sources as SDR mezzanine candidates with fixture validation required", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "arib-std-b67",
      color_primaries: "bt2020",
    });

    expect(
      deriveDesktopHdrPreparationPolicy(sourceMetadataForColor(color)),
    ).toEqual({
      strategy: "prepare-sdr-mezzanine",
      reason: "source-is-hdr-hlg",
      requiresFixtureValidation: true,
      warning: null,
    });
  });

  it("defers wide-gamut sources without trusted transfer metadata", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
    );

    expect(policy.strategy).toBe("defer-unknown");
    expect(policy.reason).toBe("wide-gamut-transfer-unknown");
    expect(policy.requiresFixtureValidation).toBe(false);
    expect(policy.warning).toContain("leave pixels unchanged");
  });

  it("does not automatically change sources with unknown color metadata", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream(undefined);

    expect(
      deriveDesktopHdrPreparationPolicy(sourceMetadataForColor(color)),
    ).toEqual({
      strategy: "none",
      reason: "source-color-unknown",
      requiresFixtureValidation: false,
      warning: null,
    });
  });

  it("defers HDR PQ preparation when local ffmpeg lacks zscale and libplacebo", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "smpte2084",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
      {
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      },
    );

    expect(policy.strategy).toBe("defer-unknown");
    expect(policy.reason).toBe("ffmpeg-missing-hdr-filters");
    expect(policy.requiresFixtureValidation).toBe(true);
    expect(policy.filterSelection).toBeUndefined();
    expect(policy.warning).toContain("zscale");
    expect(policy.warning).toContain("libplacebo");
    expect(policy.warning).toContain("PQ");
  });

  it("defers HDR HLG preparation when local ffmpeg lacks zscale and libplacebo", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "arib-std-b67",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
      {
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      },
    );

    expect(policy.strategy).toBe("defer-unknown");
    expect(policy.reason).toBe("ffmpeg-missing-hdr-filters");
    expect(policy.filterSelection).toBeUndefined();
    expect(policy.warning).toContain("HLG");
  });

  it("keeps prepare-sdr-mezzanine for HDR PQ when zscale is available", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "smpte2084",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
      {
        hasZscale: true,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      },
    );

    expect(policy.strategy).toBe("prepare-sdr-mezzanine");
    expect(policy.reason).toBe("source-is-hdr-pq");
    expect(policy.warning).toBeNull();
    expect(policy.filterSelection).toEqual({
      kind: "zscale-tonemap",
      source: "hdr-pq",
      transferIn: "smpte2084",
      tonemap: "hable",
      nominalPeakNits: 100,
      desat: 0,
      output: "bt709-sdr",
    });
  });

  it("keeps prepare-sdr-mezzanine for HDR HLG when libplacebo is available", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "arib-std-b67",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
      {
        hasZscale: false,
        hasLibplacebo: true,
        hasTonemap: false,
        hasColorspace: true,
      },
    );

    expect(policy.strategy).toBe("prepare-sdr-mezzanine");
    expect(policy.reason).toBe("source-is-hdr-hlg");
    expect(policy.filterSelection).toEqual({
      kind: "libplacebo",
      source: "hdr-hlg",
      tonemapping: "bt.2390",
      gamutMode: "perceptual",
      output: "bt709-sdr",
    });
  });

  it("prefers zscale when both HDR filter paths are available", () => {
    const color = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt2020nc",
      color_transfer: "smpte2084",
      color_primaries: "bt2020",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(color),
      {
        hasZscale: true,
        hasLibplacebo: true,
        hasTonemap: true,
        hasColorspace: true,
      },
    );

    expect(policy.strategy).toBe("prepare-sdr-mezzanine");
    expect(policy.reason).toBe("source-is-hdr-pq");
    expect(policy.filterSelection).toEqual({
      kind: "zscale-tonemap",
      source: "hdr-pq",
      transferIn: "smpte2084",
      tonemap: "hable",
      nominalPeakNits: 100,
      desat: 0,
      output: "bt709-sdr",
    });
  });

  it("does not branch on capabilities for non-HDR color classes", () => {
    const sdrColor = deriveSourceColorMetadataFromFfprobeStream({
      color_space: "bt709",
      color_transfer: "bt709",
      color_primaries: "bt709",
    });

    const policy = deriveDesktopHdrPreparationPolicy(
      sourceMetadataForColor(sdrColor),
      {
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: false,
        hasColorspace: false,
      },
    );

    expect(policy.strategy).toBe("none");
    expect(policy.reason).toBe("source-is-sdr-bt709");
  });
});
