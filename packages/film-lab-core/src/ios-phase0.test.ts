import { expect, test } from "bun:test";
import { parseCube } from "./cube-parser";
import {
  PHASE0_HALATION_HUE_MAX,
  PHASE0_HALATION_HUE_MIN,
  PHASE0_RGB_SHIFT_MAX,
} from "./phase0-schema";
import { buildFilmtoneIosSwiftPayload } from "./ios-swift-payload";
import {
  IOS_PHASE0_OUTPUT_CODEC,
  IOS_PHASE0_RGB_SHIFT_MAX,
  IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  createIosPhase0SerializableLut,
  getIosPhase0SourceCapViolations,
  iosPhase0ExportPayloadSchema,
  iosPhase0SourceInfoSchema,
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

test("iosPhase0ExportPayloadSchema accepts widened optical params and export defaults", () => {
  const payload = iosPhase0ExportPayloadSchema.parse({
    projectId: "phase0-project",
    sourceUri: "file:///clip.mov",
    sourceDisplayName: "clip.mov",
    sourceKind: "video",
    presetId: "iphone",
    params: {
      exposure: 0.1,
      contrast: 1.1,
      saturation: 0.9,
      temperature: 0,
      tint: 0,
      rgbShift: PHASE0_RGB_SHIFT_MAX,
      lensSoftness: 0.1,
      grainRadialMix: 1,
      grainSize: 0.3,
      bloomThreshold: 0.76,
      bloomStrength: 0.24,
      bloomRadius: 0.5,
      diffusion: 0.08,
      halationIntensity: 0.06,
      halationSpread: 20,
      halationHue: 18,
      halationThreshold: 0.6,
      halationRadius: 0.4,
      bloomSoftKnee: 0.5,
      halationSoftKnee: 0.3,
      compressionAmount: 0.12,
      compressionRange: 0.5,
      printContrast: 0.35,
      cyan: -0.2,
      magenta: 0.1,
      yellow: -0.05,
      fade: 0.02,
      vignette: 0.2,
      grainIntensity: 0.1,
    },
  });

  expect(payload.exportSettings.outputFps).toBe(24);
  expect(payload.params.rgbShift).toBe(PHASE0_RGB_SHIFT_MAX);
  expect(payload.params.bloomStrength).toBe(0.24);
  expect(payload.params.compressionAmount).toBe(0.12);
  expect(payload.params.printContrast).toBe(0.35);
  expect(payload.params.cyan).toBe(-0.2);
  expect(payload.params.magenta).toBe(0.1);
  expect(payload.params.yellow).toBe(-0.05);
});

test("iosPhase0ExportPayloadSchema rejects rgbShift above the shared phase0 max", () => {
  expect(() =>
    iosPhase0ExportPayloadSchema.parse({
      projectId: "phase0-project",
      sourceUri: "file:///clip.mov",
      sourceDisplayName: "clip.mov",
      sourceKind: "video",
      presetId: "iphone",
      params: {
        exposure: 0.1,
        contrast: 1.1,
        saturation: 0.9,
        temperature: 0,
        tint: 0,
        rgbShift: PHASE0_RGB_SHIFT_MAX + 0.0001,
        lensSoftness: 0.1,
        grainRadialMix: 1,
        grainSize: 0.3,
        bloomThreshold: 0.76,
        bloomStrength: 0.24,
        bloomRadius: 0.5,
        diffusion: 0.08,
        halationIntensity: 0.06,
        halationSpread: 20,
        halationHue: 18,
        halationThreshold: 0.6,
        halationRadius: 0.4,
        bloomSoftKnee: 0.5,
        halationSoftKnee: 0.3,
        compressionAmount: 0.12,
        compressionRange: 0.5,
        fade: 0.02,
        vignette: 0.2,
        grainIntensity: 0.1,
      },
    }),
  ).toThrow();
});

test("iosPhase0ExportPayloadSchema rejects halationHue outside the slider range", () => {
  expect(() =>
    iosPhase0ExportPayloadSchema.parse({
      projectId: "phase0-project",
      sourceUri: "file:///clip.mov",
      sourceDisplayName: "clip.mov",
      sourceKind: "video",
      presetId: "iphone",
      params: {
        exposure: 0.1,
        contrast: 1.1,
        saturation: 0.9,
        temperature: 0,
        tint: 0,
        rgbShift: 0.002,
        lensSoftness: 0.1,
        grainRadialMix: 1,
        grainSize: 0.3,
        bloomThreshold: 0.76,
        bloomStrength: 0.24,
        bloomRadius: 0.5,
        diffusion: 0.08,
        halationIntensity: 0.06,
        halationSpread: 20,
        halationHue: PHASE0_HALATION_HUE_MAX + 1,
        halationThreshold: 0.6,
        halationRadius: 0.4,
        bloomSoftKnee: 0.5,
        halationSoftKnee: 0.3,
        compressionAmount: 0.12,
        compressionRange: 0.5,
        fade: 0.02,
        vignette: 0.2,
        grainIntensity: 0.1,
      },
    }),
  ).toThrow();

  expect(() =>
    iosPhase0ExportPayloadSchema.parse({
      projectId: "phase0-project",
      sourceUri: "file:///clip.mov",
      sourceDisplayName: "clip.mov",
      sourceKind: "video",
      presetId: "iphone",
      params: {
        exposure: 0.1,
        contrast: 1.1,
        saturation: 0.9,
        temperature: 0,
        tint: 0,
        rgbShift: 0.002,
        lensSoftness: 0.1,
        grainRadialMix: 1,
        grainSize: 0.3,
        bloomThreshold: 0.76,
        bloomStrength: 0.24,
        bloomRadius: 0.5,
        diffusion: 0.08,
        halationIntensity: 0.06,
        halationSpread: 20,
        halationHue: PHASE0_HALATION_HUE_MIN - 1,
        halationThreshold: 0.6,
        halationRadius: 0.4,
        bloomSoftKnee: 0.5,
        halationSoftKnee: 0.3,
        compressionAmount: 0.12,
        compressionRange: 0.5,
        fade: 0.02,
        vignette: 0.2,
        grainIntensity: 0.1,
      },
    }),
  ).toThrow();
});

test("getIosPhase0SourceCapViolations reports cap breaches", () => {
  const violations = getIosPhase0SourceCapViolations({
    width: 4097,
    height: 2160,
    durationSec: IOS_PHASE0_SOURCE_DURATION_CAP_SEC + 1,
    fileSizeBytes: 9 * 1024 * 1024 * 1024,
  });

  expect(violations).toContain("duration>300s");
  expect(violations).toContain("long-edge>4096");
  expect(violations.some((violation) => violation.startsWith("file-size>")))
    .toBe(false);
});

test("iosPhase0SourceInfoSchema accepts ProRes Apple Log source fields", () => {
  const source = iosPhase0SourceInfoSchema.parse({
    uri: "file:///apple-log.mov",
    displayName: "apple-log.mov",
    kind: "video",
    width: 1920,
    height: 1080,
    durationSec: 30,
    videoCodec: "ap4h",
    codecFamily: "prores-4444",
    logTransferFunction: "apple-log",
    inputTransformPolicy: {
      strategy: "apple-log-to-rec709",
      reason: "source-is-apple-log",
      requiresFixtureValidation: true,
      warning: null,
    },
    frameRate: 30,
    hasAudio: true,
  });

  expect(source.codecFamily).toBe("prores-4444");
  expect(source.logTransferFunction).toBe("apple-log");
  expect(source.inputTransformPolicy?.strategy).toBe("apple-log-to-rec709");
});

test("iosPhase0SourceInfoSchema accepts legacy source info without new fields", () => {
  const source = iosPhase0SourceInfoSchema.parse({
    uri: "file:///legacy.mp4",
    displayName: "legacy.mp4",
    kind: "video",
    videoCodec: "h264",
  });

  expect(source.codecFamily).toBeUndefined();
  expect(source.logTransferFunction).toBeUndefined();
  expect(source.inputTransformPolicy).toBeUndefined();
});

const DUAL_LUT_CUBE_TEXT = `
TITLE "DualSlot"
LUT_3D_SIZE 2
0 0 0
1 0 0
0 1 0
1 1 0
0 0 1
1 0 1
0 1 1
1 1 1
`;

const DUAL_LUT_BASE_PAYLOAD = {
  projectId: "phase0-project",
  sourceUri: "file:///clip.mov",
  sourceDisplayName: "clip.mov",
  sourceKind: "video" as const,
  presetId: "iphone" as const,
  params: {
    exposure: 0,
    contrast: 1,
    saturation: 1,
    temperature: 0,
    tint: 0,
    fade: 0,
    vignette: 0,
    grainIntensity: 0,
  },
};

test("iosPhase0ExportPayloadSchema accepts inputLut only", () => {
  const cube = parseCube(DUAL_LUT_CUBE_TEXT);
  const inputLut = createIosPhase0SerializableLut({
    cube,
    name: "input.cube",
  });

  const payload = iosPhase0ExportPayloadSchema.parse({
    ...DUAL_LUT_BASE_PAYLOAD,
    inputLut,
  });

  expect(payload.inputLut?.name).toBe("input.cube");
  expect(payload.creativeLut ?? null).toBeNull();
});

test("iosPhase0ExportPayloadSchema accepts creativeLut only", () => {
  const cube = parseCube(DUAL_LUT_CUBE_TEXT);
  const creativeLut = createIosPhase0SerializableLut({
    cube,
    name: "creative.cube",
  });

  const payload = iosPhase0ExportPayloadSchema.parse({
    ...DUAL_LUT_BASE_PAYLOAD,
    creativeLut,
  });

  expect(payload.creativeLut?.name).toBe("creative.cube");
  expect(payload.inputLut ?? null).toBeNull();
});

test("iosPhase0ExportPayloadSchema accepts both inputLut and creativeLut", () => {
  const cube = parseCube(DUAL_LUT_CUBE_TEXT);
  const inputLut = createIosPhase0SerializableLut({
    cube,
    name: "input.cube",
    intensity: 0.7,
  });
  const creativeLut = createIosPhase0SerializableLut({
    cube,
    name: "creative.cube",
    intensity: 0.5,
  });

  const payload = iosPhase0ExportPayloadSchema.parse({
    ...DUAL_LUT_BASE_PAYLOAD,
    inputLut,
    creativeLut,
  });

  expect(payload.inputLut?.intensity).toBe(0.7);
  expect(payload.creativeLut?.intensity).toBe(0.5);
});

test("iosPhase0ExportPayloadSchema accepts both LUT slots null", () => {
  const payload = iosPhase0ExportPayloadSchema.parse({
    ...DUAL_LUT_BASE_PAYLOAD,
    inputLut: null,
    creativeLut: null,
  });

  expect(payload.inputLut).toBeNull();
  expect(payload.creativeLut).toBeNull();
});

test("iosPhase0ExportPayloadSchema keeps output fixed to H.264 MP4 defaults", () => {
  const payload = iosPhase0ExportPayloadSchema.parse({
    ...DUAL_LUT_BASE_PAYLOAD,
  });

  expect(payload.exportSettings.codec).toBe(IOS_PHASE0_OUTPUT_CODEC);
  expect(payload.exportSettings.outputFps).toBe(24);
  expect(payload.exportSettings.outputLongEdge).toBe(1920);
});

test("swift payload generation exposes the shared rgbShift max", () => {
  const payload = buildFilmtoneIosSwiftPayload();

  expect(IOS_PHASE0_RGB_SHIFT_MAX).toBe(PHASE0_RGB_SHIFT_MAX);
  expect(payload.rgbShiftMax).toBe(PHASE0_RGB_SHIFT_MAX);
});
