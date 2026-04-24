/**
 * @fileoverview ffmpeg filter list parser と HDR capability probe の pure tests。
 */
import { beforeEach, describe, expect, it } from "vitest";

import {
  __resetFfmpegHdrCapabilityCacheForTesting,
  parseFfmpegFilterList,
  probeFfmpegHdrCapabilities,
  summarizeMissingHdrFilters,
  supportsHdrToSdrPreparation,
} from "./ffmpeg-capability-probe";

const HOMEBREW_DEFAULT_FILTERS_SAMPLE = `
Filters:
  T.. = Timeline support
  .S. = Slice threading
  ..C = Command support
  A = Audio input/output
  V = Video input/output
  N = Dynamic number and/or type of input/output
  | = Source or sink filter
 TS. colorspace        V->V       Convert between colorspaces.
 .S. tonemap           V->V       Conversion to/from different dynamic ranges.
 ... format            V->V       Convert the input video to one of the specified pixel formats.
 ... scale             V->V       Scale the input video size and/or convert the image format.
`;

const ZIMG_ENABLED_FILTERS_SAMPLE = `
 TS. colorspace        V->V       Convert between colorspaces.
 .S. tonemap           V->V       Conversion to/from different dynamic ranges.
 ... zscale            V->V       Apply resizing, colorspace and bit depth conversion.
 ... format            V->V       Convert the input video to one of the specified pixel formats.
`;

const LIBPLACEBO_ENABLED_FILTERS_SAMPLE = `
 TS. colorspace        V->V       Convert between colorspaces.
 .S. tonemap           V->V       Conversion to/from different dynamic ranges.
 ..C libplacebo        N->N       GPU-accelerated video processing using libplacebo.
`;

describe("parseFfmpegFilterList", () => {
  it("detects only tonemap/colorspace on a Homebrew default build", () => {
    const caps = parseFfmpegFilterList(HOMEBREW_DEFAULT_FILTERS_SAMPLE);

    expect(caps).toEqual({
      hasZscale: false,
      hasLibplacebo: false,
      hasTonemap: true,
      hasColorspace: true,
    });
  });

  it("detects zscale when libzimg is linked", () => {
    const caps = parseFfmpegFilterList(ZIMG_ENABLED_FILTERS_SAMPLE);

    expect(caps.hasZscale).toBe(true);
    expect(caps.hasTonemap).toBe(true);
  });

  it("detects libplacebo when available", () => {
    const caps = parseFfmpegFilterList(LIBPLACEBO_ENABLED_FILTERS_SAMPLE);

    expect(caps.hasLibplacebo).toBe(true);
  });

  it("returns all-false when given empty output", () => {
    const caps = parseFfmpegFilterList("");
    expect(caps).toEqual({
      hasZscale: false,
      hasLibplacebo: false,
      hasTonemap: false,
      hasColorspace: false,
    });
  });
});

describe("supportsHdrToSdrPreparation", () => {
  it("returns false when only tonemap/colorspace are available", () => {
    expect(
      supportsHdrToSdrPreparation({
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      }),
    ).toBe(false);
  });

  it("returns true when zscale is available", () => {
    expect(
      supportsHdrToSdrPreparation({
        hasZscale: true,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      }),
    ).toBe(true);
  });

  it("returns true when libplacebo is available", () => {
    expect(
      supportsHdrToSdrPreparation({
        hasZscale: false,
        hasLibplacebo: true,
        hasTonemap: false,
        hasColorspace: true,
      }),
    ).toBe(true);
  });
});

describe("summarizeMissingHdrFilters", () => {
  it("lists both filters when neither is present", () => {
    expect(
      summarizeMissingHdrFilters({
        hasZscale: false,
        hasLibplacebo: false,
        hasTonemap: true,
        hasColorspace: true,
      }),
    ).toBe("zscale, libplacebo");
  });

  it("returns an empty string when both filters are present", () => {
    expect(
      summarizeMissingHdrFilters({
        hasZscale: true,
        hasLibplacebo: true,
        hasTonemap: true,
        hasColorspace: true,
      }),
    ).toBe("");
  });
});

describe("probeFfmpegHdrCapabilities", () => {
  beforeEach(() => {
    __resetFfmpegHdrCapabilityCacheForTesting();
  });

  it("runs ffmpeg -hide_banner -filters through the injected runner and parses stdout", async () => {
    const calls: Array<readonly string[]> = [];
    const caps = await probeFfmpegHdrCapabilities({
      commandPath: "/fake/ffmpeg",
      runner: async (_path, args) => {
        calls.push(args);
        return { stdout: ZIMG_ENABLED_FILTERS_SAMPLE };
      },
    });

    expect(calls).toEqual([["-hide_banner", "-filters"]]);
    expect(caps.hasZscale).toBe(true);
  });

  it("caches results per commandPath so repeat calls do not re-run ffmpeg", async () => {
    let runs = 0;
    const runner = async () => {
      runs += 1;
      return { stdout: HOMEBREW_DEFAULT_FILTERS_SAMPLE };
    };

    await probeFfmpegHdrCapabilities({
      commandPath: "/cached/ffmpeg",
      runner,
    });
    await probeFfmpegHdrCapabilities({
      commandPath: "/cached/ffmpeg",
      runner,
    });

    expect(runs).toBe(1);
  });

  it("returns an all-false capability on runner failure rather than throwing", async () => {
    const caps = await probeFfmpegHdrCapabilities({
      commandPath: "/broken/ffmpeg",
      runner: async () => {
        throw new Error("ENOENT");
      },
    });

    expect(caps).toEqual({
      hasZscale: false,
      hasLibplacebo: false,
      hasTonemap: false,
      hasColorspace: false,
    });
  });
});
