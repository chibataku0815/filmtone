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
      width: 4096,
      height: 2160,
      durationSec: 301,
      fileSizeBytes: 9 * 1024 * 1024 * 1024,
    });
    expect(violations.length).toBe(3);
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
    expect(request.output.fps).toBe(30);
    expect(request.grade.presetName).toBe(project.presetName);
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
