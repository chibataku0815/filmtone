import { z } from "zod";
import type { CubeLUT } from "./cube-parser";
import { PRESETS, type PresetName } from "./presets";
import {
  PHASE0_APPROX_SOURCE_LONG_EDGE_MAX,
  PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES,
  PHASE0_MAX_SOURCE_DURATION_SEC,
  PHASE0_OUTPUT_PROFILE,
  PHASE0_PARAM_KEYS,
  PHASE0_RGB_SHIFT_MAX,
  phase0ParamsSchema,
  pickPhase0Params,
  type Phase0ParamKey,
  type Phase0Params,
} from "./phase0-schema";

export const IOS_PHASE0_SCHEMA_VERSION = 2 as const;

export const IOS_PHASE0_PARAM_KEYS = PHASE0_PARAM_KEYS;

export type IosPhase0ParamKey = Phase0ParamKey;
export type IosPhase0Params = Phase0Params;

export const iosPhase0ParamsSchema = phase0ParamsSchema;

export const IOS_PHASE0_OUTPUT_CODEC = "h264-mp4" as const;
export const IOS_PHASE0_OUTPUT_LONG_EDGE = PHASE0_OUTPUT_PROFILE.longEdge;
export const IOS_PHASE0_OUTPUT_FPS = PHASE0_OUTPUT_PROFILE.fps;
export const IOS_PHASE0_SOURCE_DURATION_CAP_SEC = PHASE0_MAX_SOURCE_DURATION_SEC;
export const IOS_PHASE0_SOURCE_LONG_EDGE_CAP = PHASE0_APPROX_SOURCE_LONG_EDGE_MAX;
export const IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES = PHASE0_APPROX_SOURCE_SIZE_MAX_BYTES;
export const IOS_PHASE0_RGB_SHIFT_MAX = PHASE0_RGB_SHIFT_MAX;

export const IOS_PHASE0_SOURCE_CAPS = {
  durationSec: IOS_PHASE0_SOURCE_DURATION_CAP_SEC,
  longEdge: IOS_PHASE0_SOURCE_LONG_EDGE_CAP,
  fileSizeBytes: IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES,
} as const;

export const IOS_PHASE0_BENCHMARK_SLOTS = [
  "bench-short",
  "bench-mid",
  "bench-long",
] as const;

export type IosPhase0BenchmarkSlot =
  (typeof IOS_PHASE0_BENCHMARK_SLOTS)[number];

export const iosPhase0SourceKindSchema = z.enum(["image", "video"]);
export type IosPhase0SourceKind = z.infer<typeof iosPhase0SourceKindSchema>;

const iosPhase0Tuple3Schema = z.tuple([
  z.number().finite(),
  z.number().finite(),
  z.number().finite(),
]);

export const iosPhase0SerializableLutSchema = z.object({
  name: z.string().min(1),
  title: z.string().min(1).optional(),
  size: z.number().int().positive(),
  intensity: z.number().min(0).max(1).default(1),
  domainMin: iosPhase0Tuple3Schema.optional(),
  domainMax: iosPhase0Tuple3Schema.optional(),
  rgbaData: z
    .array(z.number().finite())
    .min(4)
    .refine((data) => data.length % 4 === 0, {
      message: "LUT rgbaData must contain RGBA quads",
    }),
});

export type IosPhase0SerializableLut = z.infer<
  typeof iosPhase0SerializableLutSchema
>;

export function createIosPhase0SerializableLut(input: {
  cube: CubeLUT;
  name: string;
  intensity?: number;
}): IosPhase0SerializableLut {
  const { cube, name, intensity = 1 } = input;
  return iosPhase0SerializableLutSchema.parse({
    name,
    title: cube.title || undefined,
    size: cube.size,
    intensity,
    domainMin: cube.domainMin,
    domainMax: cube.domainMax,
    rgbaData: Array.from(cube.data),
  });
}

export const iosPhase0PickedSourceSchema = z.object({
  uri: z.string().min(1),
  displayName: z.string().min(1),
  kind: iosPhase0SourceKindSchema.optional(),
});

export type IosPhase0PickedSource = z.infer<
  typeof iosPhase0PickedSourceSchema
>;

export const iosPhase0PickedLutFileSchema = z.object({
  uri: z.string().min(1),
  displayName: z.string().min(1),
  text: z.string().min(1),
});

export type IosPhase0PickedLutFile = z.infer<
  typeof iosPhase0PickedLutFileSchema
>;

export const iosPhase0SourceInfoSchema = z.object({
  uri: z.string().min(1),
  displayName: z.string().min(1),
  kind: iosPhase0SourceKindSchema,
  width: z.number().int().positive().optional(),
  height: z.number().int().positive().optional(),
  durationSec: z.number().positive().optional(),
  fileSizeBytes: z.number().int().nonnegative().optional(),
  videoCodec: z.string().min(1).optional(),
  audioCodec: z.string().min(1).optional(),
  frameRate: z.number().positive().optional(),
  hasAudio: z.boolean().optional(),
});

export type IosPhase0SourceInfo = z.infer<typeof iosPhase0SourceInfoSchema>;

const IOS_PHASE0_PRESET_IDS = Object.keys(PRESETS) as [
  PresetName,
  ...PresetName[],
];

export const iosPhase0PresetIdSchema = z.enum(IOS_PHASE0_PRESET_IDS);

export const iosPhase0ExportSettingsSchema = z.object({
  codec: z.literal(IOS_PHASE0_OUTPUT_CODEC).default(IOS_PHASE0_OUTPUT_CODEC),
  outputLongEdge: z
    .number()
    .int()
    .positive()
    .max(IOS_PHASE0_OUTPUT_LONG_EDGE)
    .default(IOS_PHASE0_OUTPUT_LONG_EDGE),
  outputFps: z.literal(IOS_PHASE0_OUTPUT_FPS).default(IOS_PHASE0_OUTPUT_FPS),
});

export type IosPhase0ExportSettings = z.infer<
  typeof iosPhase0ExportSettingsSchema
>;

export const iosPhase0ExportPayloadSchema = z.object({
  projectId: z.string().min(1),
  sourceUri: z.string().min(1),
  sourceDisplayName: z.string().min(1),
  sourceKind: iosPhase0SourceKindSchema,
  presetId: iosPhase0PresetIdSchema,
  params: iosPhase0ParamsSchema,
  inputLut: iosPhase0SerializableLutSchema.nullable().optional(),
  creativeLut: iosPhase0SerializableLutSchema.nullable().optional(),
  benchmarkSlot: z.enum(IOS_PHASE0_BENCHMARK_SLOTS).optional(),
  benchmarkRecipeId: z.string().min(1).optional(),
  includeAudio: z.boolean().optional(),
  exportSettings: iosPhase0ExportSettingsSchema.default({
    codec: IOS_PHASE0_OUTPUT_CODEC,
    outputLongEdge: IOS_PHASE0_OUTPUT_LONG_EDGE,
    outputFps: IOS_PHASE0_OUTPUT_FPS,
  }),
});

export type IosPhase0ExportPayload = z.infer<
  typeof iosPhase0ExportPayloadSchema
>;

export const iosPhase0ExportResultSchema = z.object({
  outputUri: z.string().min(1),
  outputDisplayName: z.string().min(1),
  outputWidth: z.number().int().positive(),
  outputHeight: z.number().int().positive(),
  outputFps: z.number().positive(),
  elapsedMs: z.number().nonnegative(),
  realtimeRatio: z.number().positive().optional(),
  fileSizeBytes: z.number().int().nonnegative().optional(),
  benchmarkRecordUri: z.string().min(1).optional(),
});

export type IosPhase0ExportResult = z.infer<
  typeof iosPhase0ExportResultSchema
>;

export const iosPhase0PermissionStateSchema = z.enum([
  "granted",
  "denied",
  "limited",
  "not-required",
  "unknown",
]);

export const iosPhase0ThermalStateSchema = z.enum([
  "nominal",
  "fair",
  "serious",
  "critical",
  "unknown",
]);

export const iosPhase0BenchmarkRecordSchema = z.object({
  schemaVersion: z.literal(IOS_PHASE0_SCHEMA_VERSION),
  recordedAt: z.string().min(1),
  slot: z.enum(IOS_PHASE0_BENCHMARK_SLOTS),
  runIndex: z.number().int().positive(),
  appVersion: z.string().min(1),
  buildNumber: z.string().min(1),
  deviceModel: z.string().min(1),
  iosVersion: z.string().min(1),
  source: iosPhase0SourceInfoSchema,
  output: iosPhase0ExportResultSchema,
  elapsedMs: z.number().nonnegative(),
  realtimeRatio: z.number().positive(),
  thermalStateStart: iosPhase0ThermalStateSchema,
  thermalStateEnd: iosPhase0ThermalStateSchema,
  memoryWarningCount: z.number().int().nonnegative(),
  permissionResults: z.object({
    mediaLibrary: iosPhase0PermissionStateSchema,
    fileImport: iosPhase0PermissionStateSchema,
    sharing: iosPhase0PermissionStateSchema,
  }),
  failureDomain: z.string().min(1).optional(),
  failureCode: z.string().min(1).optional(),
  failureMessage: z.string().min(1).optional(),
  previewArtifacts: z.object({
    firstFrameUri: z.string().min(1).optional(),
    midFrameUri: z.string().min(1).optional(),
    lastFrameUri: z.string().min(1).optional(),
  }),
});

export type IosPhase0BenchmarkRecord = z.infer<
  typeof iosPhase0BenchmarkRecordSchema
>;

export const iosPhase0AssetRefSchema = z.object({
  uri: z.string().min(1),
  displayName: z.string().min(1),
  assetKind: z.enum(["source", "lut", "derived-output", "benchmark-record"]),
  createdAt: z.string().min(1),
  byteSize: z.number().int().nonnegative().optional(),
});

export type IosPhase0AssetRef = z.infer<typeof iosPhase0AssetRefSchema>;

export const iosPhase0LocalProjectSchema = z.object({
  schemaVersion: z.literal(IOS_PHASE0_SCHEMA_VERSION),
  projectId: z.string().min(1),
  createdAt: z.string().min(1),
  updatedAt: z.string().min(1),
  presetId: iosPhase0PresetIdSchema,
  params: iosPhase0ParamsSchema,
  source: iosPhase0SourceInfoSchema.nullable(),
  sourceAssetRef: iosPhase0AssetRefSchema.nullable(),
  lutAssetRef: iosPhase0AssetRefSchema.nullable(),
  exportSettings: iosPhase0ExportSettingsSchema,
  derivedData: z.object({
    lastOutput: iosPhase0AssetRefSchema.nullable().default(null),
    lastExportResult: iosPhase0ExportResultSchema.nullable().default(null),
    benchmarkRecords: z.array(iosPhase0AssetRefSchema).default([]),
  }),
  cacheMetadata: z.object({
    workingDirectoryUri: z.string().min(1).optional(),
    derivedOutputUris: z.array(z.string().min(1)).default([]),
    lastPurgeAt: z.string().min(1).optional(),
  }),
});

export type IosPhase0LocalProject = z.infer<
  typeof iosPhase0LocalProjectSchema
>;

export function pickIosPhase0Params(params: IosPhase0Params): IosPhase0Params {
  return pickPhase0Params(params);
}

export function getIosPhase0SourceCapViolations(
  source: Pick<IosPhase0SourceInfo, "width" | "height" | "durationSec" | "fileSizeBytes">,
): string[] {
  const violations: string[] = [];
  const longEdge =
    typeof source.width === "number" && typeof source.height === "number"
      ? Math.max(source.width, source.height)
      : null;

  if (
    typeof source.durationSec === "number" &&
    source.durationSec > IOS_PHASE0_SOURCE_DURATION_CAP_SEC
  ) {
    violations.push(
      `duration>${IOS_PHASE0_SOURCE_DURATION_CAP_SEC}s`,
    );
  }

  if (
    typeof longEdge === "number" &&
    longEdge > IOS_PHASE0_SOURCE_LONG_EDGE_CAP
  ) {
    violations.push(`long-edge>${IOS_PHASE0_SOURCE_LONG_EDGE_CAP}`);
  }

  if (
    typeof source.fileSizeBytes === "number" &&
    source.fileSizeBytes > IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES
  ) {
    violations.push(
      `file-size>${IOS_PHASE0_SOURCE_FILE_SIZE_CAP_BYTES}`,
    );
  }

  return violations;
}
