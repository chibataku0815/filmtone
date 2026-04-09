import { expect, test } from "bun:test";
import { parseCube } from "./cube-parser";
import {
  IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  createIosPhase0SerializableLut,
  getIosPhase0SourceCapViolations,
  iosPhase0ExportPayloadSchema,
} from "./ios-phase0";

test("createIosPhase0SerializableLut converts cube data to JSON-safe RGBA values", () => {
  const cube = parseCube(`
TITLE "Mini"
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

  const lut = createIosPhase0SerializableLut({
    cube,
    name: "mini.cube",
  });

  expect(lut.size).toBe(2);
  expect(lut.rgbaData).toHaveLength(32);
  expect(lut.rgbaData[3]).toBe(1);
});

test("iosPhase0ExportPayloadSchema accepts reduced params and export defaults", () => {
  const payload = iosPhase0ExportPayloadSchema.parse({
    projectId: "phase0-project",
    sourceUri: "file:///clip.mov",
    sourceDisplayName: "clip.mov",
    sourceKind: "video",
    presetId: "cinematic",
    params: {
      exposure: 0.1,
      contrast: 1.1,
      saturation: 0.9,
      temperature: 0,
      tint: 0,
      fade: 0.02,
      vignette: 0.2,
      grainIntensity: 0.1,
    },
  });

  expect(payload.exportSettings.outputFps).toBe(30);
});

test("getIosPhase0SourceCapViolations reports cap breaches", () => {
  const violations = getIosPhase0SourceCapViolations({
    width: 4096,
    height: 2160,
    durationSec: IOS_PHASE0_SOURCE_DURATION_CAP_SEC + 1,
    fileSizeBytes: 3 * 1024 * 1024 * 1024,
  });

  expect(violations).toContain("duration>300s");
  expect(violations).toContain("long-edge>3840");
});
