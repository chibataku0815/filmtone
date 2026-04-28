import { describe, expect, test } from "bun:test";
import { parseCube } from "./cube-parser";
import {
  assertPhase0SourceProbeWithinCaps,
  buildPhase0ExportRequest,
  getPhase0SourceCapViolations,
  serializeCubeLut,
} from "./native-bridge";
import { createPhase0ProjectState } from "./phase0-schema";

describe("native bridge DTOs", () => {
  test("serializes parsed cube data for native transport", () => {
    const lut = parseCube(`
TITLE "Warm"
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
`);
    const serialized = serializeCubeLut(lut, { intensity: 0.8 });
    expect(serialized.title).toBe("Warm");
    expect(serialized.size).toBe(2);
    expect(serialized.intensity).toBe(0.8);
    expect(serialized.data.length).toBe(32);
  });

  test("reports cap violations before export", () => {
    const violations = getPhase0SourceCapViolations({
      uri: "file:///clip.mov",
      filename: "clip.mov",
      kind: "video",
      width: 4097,
      height: 2160,
      durationSec: 301,
      fileSizeBytes: 9 * 1024 * 1024 * 1024,
    });
    expect(violations.length).toBe(2);
    expect(violations).not.toEqual(
      expect.arrayContaining([expect.stringContaining("Source size")]),
    );
  });

  test("throws on over-cap probe", () => {
    expect(() =>
      assertPhase0SourceProbeWithinCaps({
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
        durationSec: 301,
      }),
    ).toThrow(RangeError);
  });

  test("builds a fixed phase0 export payload", () => {
    const project = createPhase0ProjectState();
    const request = buildPhase0ExportRequest({
      source: {
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
      },
      probe: {
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
        width: 1920,
        height: 1080,
        durationSec: 60,
      },
      project,
    });
    expect(request.output.codec).toBe("h264");
    expect(request.output.container).toBe("mp4");
    expect(request.output.fps).toBe(24);
    expect(request.grade.presetName).toBe(project.presetName);
  });

  test("preserves ProRes Apple Log probe fields while keeping H.264 MP4 output", () => {
    const project = createPhase0ProjectState();
    const request = buildPhase0ExportRequest({
      source: {
        uri: "file:///apple-log.mov",
        filename: "apple-log.mov",
        kind: "video",
      },
      probe: {
        uri: "file:///apple-log.mov",
        filename: "apple-log.mov",
        kind: "video",
        width: 1920,
        height: 1080,
        durationSec: 30,
        codec: "apcn",
        codecFamily: "prores-422",
        logTransferFunction: "apple-log",
        inputTransformPolicy: {
          strategy: "apple-log-to-rec709",
          reason: "source-is-apple-log",
          requiresFixtureValidation: true,
          warning: null,
        },
      },
      project,
    });

    expect(request.sourceProbe?.codecFamily).toBe("prores-422");
    expect(request.sourceProbe?.logTransferFunction).toBe("apple-log");
    expect(request.sourceProbe?.inputTransformPolicy?.strategy).toBe(
      "apple-log-to-rec709",
    );
    expect(request.output.codec).toBe("h264");
    expect(request.output.container).toBe("mp4");
  });

  test("accepts legacy source probes without ProRes or Log DTO fields", () => {
    const project = createPhase0ProjectState();
    const request = buildPhase0ExportRequest({
      source: {
        uri: "file:///legacy.mp4",
        filename: "legacy.mp4",
        kind: "video",
      },
      probe: {
        uri: "file:///legacy.mp4",
        filename: "legacy.mp4",
        kind: "video",
        width: 1280,
        height: 720,
        durationSec: 10,
        codec: "h264",
      },
      project,
    });

    expect(request.sourceProbe?.codecFamily).toBeUndefined();
    expect(request.sourceProbe?.logTransferFunction).toBeUndefined();
    expect(request.sourceProbe?.inputTransformPolicy).toBeUndefined();
    expect(request.output.codec).toBe("h264");
    expect(request.output.container).toBe("mp4");
  });

  test("preserves source camera optics in export payload", () => {
    const project = createPhase0ProjectState();
    const request = buildPhase0ExportRequest({
      source: {
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
      },
      probe: {
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
        width: 1920,
        height: 1080,
        durationSec: 60,
        cameraOptics: {
          source: "assumed",
          fxPx: 1566.7,
          fyPx: 1566.7,
          cxPx: 960,
          cyPx: 540,
          fovXDeg: 63.0,
          fovYDeg: 38.0,
        },
      },
      project,
    });

    expect(request.sourceProbe?.cameraOptics).toEqual({
      source: "assumed",
      fxPx: 1566.7,
      fyPx: 1566.7,
      cxPx: 960,
      cyPx: 540,
      fovXDeg: 63.0,
      fovYDeg: 38.0,
    });
  });

  test("maps input and creative LUT slots independently", () => {
    const lut = parseCube(`
TITLE "Transport"
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
`);
    const inputLut = serializeCubeLut(lut, { title: "Input", intensity: 0.8 });
    const creativeLut = serializeCubeLut(lut, {
      title: "Creative",
      intensity: 0.45,
    });

    const request = buildPhase0ExportRequest({
      source: {
        uri: "file:///clip.mov",
        filename: "clip.mov",
        kind: "video",
      },
      project: {
        ...createPhase0ProjectState(),
        inputLut,
        creativeLut,
      },
    });

    expect(request.inputLut?.title).toBe("Input");
    expect(request.inputLut?.intensity).toBe(0.8);
    expect(request.creativeLut?.title).toBe("Creative");
    expect(request.creativeLut?.intensity).toBe(0.45);
  });
});
