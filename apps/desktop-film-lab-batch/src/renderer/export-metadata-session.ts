import { z } from "zod";
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  PRESETS,
  filmLookGradeInputSchema,
  findMatchingPreset,
  lookIdForPreset,
  type BehaviorProfile,
  type CameraOptics,
  type OpticalFilterDensity,
  type OpticalFilterFamily,
  type OpticalFilterProfileId,
  type OpticalFamily,
  type OpticalRecipeId,
  type PresetName,
  type Params,
  type SourceProfileCurve,
  type SourceProfileImplKind,
} from "film-lab-core";
import type { BatchFormat } from "./batch-pipeline";
import type { BatchDepthTrack } from "./depth-track";
import type { SourceVideoMetadata } from "./desktop-api";
import { buildGradeJsonPayload } from "./grade-io";

export const METADATA_LOOK_SOURCES = [
  "preset",
  "editSync",
  "importedJson",
  "analysisRecommendation",
] as const;

export type MetadataLookSource = (typeof METADATA_LOOK_SOURCES)[number];

export type MetadataLutRef = {
  enabled: boolean;
  intensity: number;
  displayName: string | null;
  absolutePath: string | null;
};

export type MetadataLutRefs = {
  lut1: MetadataLutRef;
  lut2: MetadataLutRef;
};

export type MetadataDepthTrackRef = {
  enabled: boolean;
  fps: number;
  framePaths: string[];
};

export type AppliedOpticalRecommendationMetadata = {
  family: OpticalFamily;
  profile: BehaviorProfile;
  recipe: OpticalRecipeId | null;
  analyzerVersion: string;
  appliedAtIso: string;
};

export type AppliedOpticalFilterProfileMetadata = {
  id: OpticalFilterProfileId | string;
  family: OpticalFilterFamily;
  density: OpticalFilterDensity;
  displayName: string;
  appliedAtIso: string;
};

export type SourceProfileSelectionKind = "built-in" | "custom" | "none";

export type AppliedSourceProfileMetadata = {
  selectionKind: SourceProfileSelectionKind;
  catalogId: string | null;
  curve: SourceProfileCurve | null;
  impl: SourceProfileImplKind | null;
  displayName: string;
  appliedAtIso: string;
};

const [FIRST_PRESET_NAME, ...REST_PRESET_NAMES] = Object.keys(PRESETS) as [
  PresetName,
  ...PresetName[],
];

const presetNameSchema = z.enum([FIRST_PRESET_NAME, ...REST_PRESET_NAMES]);

const metadataLutRefSchema = z.object({
  enabled: z.boolean(),
  intensity: z.number().min(0).max(1),
  displayName: z.string().min(1).nullable(),
  absolutePath: z.string().min(1).nullable(),
});

const metadataLookSourceSchema = z.enum(METADATA_LOOK_SOURCES);
const metadataDepthTrackRefSchema = z.object({
  enabled: z.boolean(),
  fps: z.number().positive().max(120),
  framePaths: z.array(z.string().min(1)),
});
const cameraOpticsSchema = z.object({
  source: z.enum(["metadata", "assumed", "manual"]),
  fxPx: z.number().optional(),
  fyPx: z.number().optional(),
  cxPx: z.number().optional(),
  cyPx: z.number().optional(),
  fovXDeg: z.number().optional(),
  fovYDeg: z.number().optional(),
  focalLength35mm: z.number().optional(),
  lensModel: z.string().min(1).optional(),
  cameraMake: z.string().min(1).optional(),
  cameraModel: z.string().min(1).optional(),
});
const sourceDisplayGeometrySchema = z.object({
  rawWidth: z.number().positive(),
  rawHeight: z.number().positive(),
  displayWidth: z.number().positive(),
  displayHeight: z.number().positive(),
  rotationDeg: z.union([
    z.literal(0),
    z.literal(90),
    z.literal(180),
    z.literal(270),
  ]).nullable(),
  source: z.enum(["ffprobe-side-data", "ffprobe-tags", "raw"]),
});
const sourceColorMetadataSchema = z.object({
  colorRange: z.string().min(1).nullable(),
  colorSpace: z.string().min(1).nullable(),
  colorTransfer: z.string().min(1).nullable(),
  colorPrimaries: z.string().min(1).nullable(),
  hasMasteringDisplayMetadata: z.boolean(),
  hasContentLightMetadata: z.boolean(),
});
const sourceVideoTimingMetadataSchema = z.object({
  avgFrameRate: z.string().min(1).nullable(),
  rFrameRate: z.string().min(1).nullable(),
  avgFrameRateParsed: z.number().positive().nullable(),
  rFrameRateParsed: z.number().positive().nullable(),
  sourceFrameRate: z.number().positive().nullable(),
  sourceFrameRateTrusted: z.boolean(),
  trustReason: z.enum([
    "missing-or-invalid-rate",
    "rates-diverged",
    "within-absolute-tolerance",
    "within-relative-tolerance",
  ]),
});
const hdrToSdrFilterSelectionSchema = z.discriminatedUnion("kind", [
  z.object({
    kind: z.literal("zscale-tonemap"),
    source: z.enum(["hdr-pq", "hdr-hlg"]),
    chainId: z.enum(["pq-zscale-hable-npl100", "hlg-zscale-mobius-npl100"]),
    enabledByEnv: z.literal(true),
    ffmpegPath: z.string().min(1).nullable(),
    transferIn: z.enum(["smpte2084", "arib-std-b67"]),
    tonemap: z.enum(["hable", "mobius"]),
    nominalPeakNits: z.literal(100),
    desat: z.literal(0),
    output: z.literal("bt709-sdr"),
  }),
  z.object({
    kind: z.literal("libplacebo"),
    source: z.enum(["hdr-pq", "hdr-hlg"]),
    chainId: z.enum(["pq-libplacebo-bt2390", "hlg-libplacebo-bt2390"]),
    enabledByEnv: z.literal(true),
    ffmpegPath: z.string().min(1).nullable(),
    tonemapping: z.literal("bt.2390"),
    gamutMode: z.literal("perceptual"),
    output: z.literal("bt709-sdr"),
  }),
]);
const hdrPreparationPolicySchema = z.object({
  strategy: z.enum(["none", "prepare-sdr-mezzanine", "defer-unknown"]),
  reason: z.enum([
    "source-is-sdr-bt709",
    "source-is-hdr-pq",
    "source-is-hdr-hlg",
    "wide-gamut-transfer-unknown",
    "source-color-unknown",
    "ffmpeg-missing-hdr-filters",
  ]),
  requiresFixtureValidation: z.boolean(),
  warning: z.string().min(1).nullable(),
  filterSelection: hdrToSdrFilterSelectionSchema.nullable().optional(),
});
const sourceVideoMetadataSchema = z.object({
  display: sourceDisplayGeometrySchema,
  color: sourceColorMetadataSchema,
  colorClass: z.enum([
    "sdr-bt709",
    "hdr-pq",
    "hdr-hlg",
    "wide-gamut-unknown",
    "unknown",
  ]),
  hdrPreparationPolicy: hdrPreparationPolicySchema.optional(),
  timing: sourceVideoTimingMetadataSchema.optional(),
});

const opticalFamilySchema = z.enum(["mist", "glow", "cross", "lens"]);
const behaviorProfileSchema = z.enum([
  "clean",
  "warm",
  "night",
  "portrait",
  "spotlight",
  "product",
  "stillMatch",
]);
const opticalRecipeIdSchema = z.enum([
  "warmIndoor",
  "nightCity",
  "skinCloseUp",
  "nightSpot",
  "productEdge",
  "coverStillMatch",
]);
const opticalRecommendationMetadataSchema = z.object({
  family: opticalFamilySchema,
  profile: behaviorProfileSchema,
  recipe: opticalRecipeIdSchema.nullable(),
  analyzerVersion: z.string().min(1),
  appliedAtIso: z.string().min(1),
});
const opticalFilterFamilySchema = z.enum([
  "blackMist",
  "cineBloom",
  "pearlGlow",
  "warmMist",
  "cleanSoft",
  "streak",
  "prismHalo",
]);
const opticalFilterDensitySchema = z.enum([
  "subtle",
  "1/8",
  "1/4",
  "1/2",
  "5%",
  "10%",
  "20%",
  "heavy",
]);
const opticalFilterProfileMetadataSchema = z.object({
  id: z.string().min(1),
  family: opticalFilterFamilySchema,
  density: opticalFilterDensitySchema,
  displayName: z.string().min(1),
  appliedAtIso: z.string().min(1),
});

const sourceProfileCurveSchema = z.enum([
  "apple-log",
  "apple-log-2",
  "dji-dlog",
  "dji-dlog-m",
  "canon-clog",
  "canon-log3-cinema-gamut",
  "panasonic-vlog",
  "sony-slog3",
]);
const sourceProfileImplKindSchema = z.enum([
  "nil-profile",
  "native-policy",
  "synthesized",
]);
const sourceProfileSelectionKindSchema = z.enum([
  "built-in",
  "custom",
  "none",
]);
const appliedSourceProfileMetadataSchema = z.object({
  selectionKind: sourceProfileSelectionKindSchema,
  catalogId: z.string().min(1).nullable(),
  curve: sourceProfileCurveSchema.nullable(),
  impl: sourceProfileImplKindSchema.nullable(),
  displayName: z.string().min(1),
  appliedAtIso: z.string().min(1),
});

const filmtoneExportSessionSchema = z.object({
  kind: z.literal("filmtone-export-session"),
  version: z.literal(1),
  exportedAtIso: z.string().min(1),
  appVersion: z.string().min(1),
  job: z.enum(["images", "video"]),
  input: z.object({
    inputDir: z.string().min(1).nullable(),
    videoInputPath: z.string().min(1).nullable(),
    cameraOptics: cameraOpticsSchema.optional(),
    sourceVideoMetadata: sourceVideoMetadataSchema.optional(),
    sourceProfile: appliedSourceProfileMetadataSchema.optional(),
  }),
  output: z.object({
    outputDir: z.string().min(1),
    imageFormat: z.enum(["jpeg", "png"]).nullable(),
    outputFilenameSuffix: z.string().max(128).nullable(),
    outputFileName: z.string().min(1).nullable(),
  }),
  look: z.object({
    batchPresetChoice: presetNameSchema,
    source: metadataLookSourceSchema,
    grade: filmLookGradeInputSchema,
    opticalRecommendation: opticalRecommendationMetadataSchema.optional(),
    opticalFilterProfile: opticalFilterProfileMetadataSchema.optional(),
  }),
  lutRefs: z.object({
    lut1: metadataLutRefSchema,
    lut2: metadataLutRefSchema,
  }),
  depthTrack: metadataDepthTrackRefSchema,
});

export type FilmtoneExportSessionV1 = z.infer<
  typeof filmtoneExportSessionSchema
>;

function basename(filePath: string): string {
  const normalized = filePath.replace(/\\/g, "/");
  const index = normalized.lastIndexOf("/");
  return index >= 0 ? normalized.slice(index + 1) : normalized;
}

function dirname(filePath: string): string {
  const normalized = filePath.replace(/\\/g, "/");
  const index = normalized.lastIndexOf("/");
  return index >= 0 ? normalized.slice(0, index) : "";
}

function joinPath(dir: string, fileName: string): string {
  if (dir.length === 0) return fileName;
  const separator = dir.includes("\\") && !dir.includes("/") ? "\\" : "/";
  const trimmed = dir.replace(/[\\/]+$/, "");
  return `${trimmed}${separator}${fileName}`;
}

function filePathToUrl(filePath: string): URL {
  const normalized = filePath.replace(/\\/g, "/");
  const prefixed = normalized.startsWith("/") ? normalized : `/${normalized}`;
  const encoded = prefixed
    .split("/")
    .map((segment, index) => (index === 0 ? segment : encodeURIComponent(segment)))
    .join("/");
  return new URL(`file://${encoded}`);
}

export function resolveAbsolutePathRelativeToFile(
  baseFilePath: string,
  relPath: string,
): string {
  const resolved = new URL(relPath, filePathToUrl(baseFilePath));
  const decodedPath = decodeURIComponent(resolved.pathname);
  return /^\/[A-Za-z]:\//.test(decodedPath)
    ? decodedPath.slice(1)
    : decodedPath;
}

export function createEmptyMetadataLutRef(): MetadataLutRef {
  return {
    enabled: false,
    intensity: 1,
    displayName: null,
    absolutePath: null,
  };
}

export function createEmptyMetadataLutRefs(): MetadataLutRefs {
  return {
    lut1: createEmptyMetadataLutRef(),
    lut2: createEmptyMetadataLutRef(),
  };
}

export function createEmptyMetadataDepthTrackRef(): MetadataDepthTrackRef {
  return {
    enabled: false,
    fps: 25,
    framePaths: [],
  };
}

export function createMetadataDepthTrackRefFromRuntime(
  depthTrack: BatchDepthTrack | null | undefined,
): MetadataDepthTrackRef {
  if (!depthTrack) {
    return createEmptyMetadataDepthTrackRef();
  }
  return {
    enabled: depthTrack.absolutePaths.length > 0,
    fps: depthTrack.source.fps,
    framePaths: [...depthTrack.absolutePaths],
  };
}

export function createMetadataLutRefFromRuntime(
  slot:
    | {
        name: string;
        intensity: number;
      }
    | null
    | undefined,
  absolutePath: string | null = null,
): MetadataLutRef {
  if (!slot) {
    return createEmptyMetadataLutRef();
  }
  return {
    enabled: true,
    intensity: slot.intensity,
    displayName: slot.name || null,
    absolutePath,
  };
}

function exportedAtToken(exportedAtIso: string): string {
  const parsed = new Date(exportedAtIso);
  const iso = Number.isNaN(parsed.getTime())
    ? new Date().toISOString()
    : parsed.toISOString();
  return iso.replace(/[-:]/g, "").replace(/\.\d{3}Z$/, "Z");
}

export function buildPhotoMetadataSidecarFileName(
  exportedAtIso: string,
): string {
  return `filmtone-export-session-${exportedAtToken(exportedAtIso)}.json`;
}

export function buildPhotoMetadataSidecarPath(
  outputDir: string,
  exportedAtIso: string,
): string {
  return joinPath(outputDir, buildPhotoMetadataSidecarFileName(exportedAtIso));
}

export function buildVideoMetadataSidecarFileName(
  outputFileName: string,
): string {
  const base = basename(outputFileName);
  const dot = base.lastIndexOf(".");
  const stem = dot > 0 ? base.slice(0, dot) : base;
  return `${stem}.filmtone-session.json`;
}

export function buildVideoMetadataSidecarPath(
  outputDir: string,
  outputFileName: string,
): string {
  return joinPath(outputDir, buildVideoMetadataSidecarFileName(outputFileName));
}

export function buildFilmtoneExportSession(params: {
  exportedAtIso: string;
  appVersion: string;
  job: "images" | "video";
  inputDir: string | null;
  videoInputPath: string | null;
  outputDir: string;
  imageFormat: BatchFormat | null;
  outputFilenameSuffix: string | null;
  outputFileName: string | null;
  batchPresetChoice: PresetName;
  lookSource: MetadataLookSource;
  gradeParams: Params;
  depthTrack: BatchDepthTrack | null;
  lutRefs: MetadataLutRefs;
  opticalRecommendation?: AppliedOpticalRecommendationMetadata | null;
  opticalFilterProfile?: AppliedOpticalFilterProfileMetadata | null;
  sourceProfile?: AppliedSourceProfileMetadata | null;
  cameraOptics?: CameraOptics | null;
  sourceVideoMetadata?: SourceVideoMetadata | null;
}): FilmtoneExportSessionV1 {
  const normalizedInputDir = params.job === "images" ? params.inputDir : null;
  const normalizedVideoInputPath =
    params.job === "video" ? params.videoInputPath : null;

  return {
    kind: "filmtone-export-session",
    version: 1,
    exportedAtIso: params.exportedAtIso,
    appVersion: params.appVersion,
    job: params.job,
    input: {
      inputDir: normalizedInputDir,
      videoInputPath: normalizedVideoInputPath,
      ...(params.cameraOptics ? { cameraOptics: params.cameraOptics } : {}),
      ...(params.job === "video" && params.sourceVideoMetadata
        ? { sourceVideoMetadata: params.sourceVideoMetadata }
        : {}),
      ...(params.sourceProfile ? { sourceProfile: params.sourceProfile } : {}),
    },
    output: {
      outputDir: params.outputDir,
      imageFormat: params.imageFormat,
      outputFilenameSuffix: params.outputFilenameSuffix,
      outputFileName: params.outputFileName,
    },
    look: {
      batchPresetChoice: params.batchPresetChoice,
      source: params.lookSource,
      grade:
        buildGradeJsonPayload(
          params.gradeParams,
          params.depthTrack?.source ?? null,
        ) as unknown as FilmtoneExportSessionV1["look"]["grade"],
      ...(params.opticalRecommendation
        ? { opticalRecommendation: params.opticalRecommendation }
        : {}),
      ...(params.opticalFilterProfile
        ? { opticalFilterProfile: params.opticalFilterProfile }
        : {}),
    },
    lutRefs: params.lutRefs,
    depthTrack: createMetadataDepthTrackRefFromRuntime(params.depthTrack),
  };
}

export function exportFilmtoneExportSessionJsonText(
  session: FilmtoneExportSessionV1,
): string {
  return `${JSON.stringify(session, null, 2)}\n`;
}

export function parseFilmtoneExportSessionV1(
  raw: unknown,
): FilmtoneExportSessionV1 | null {
  const parsed = filmtoneExportSessionSchema.safeParse(raw);
  return parsed.success ? parsed.data : null;
}

export function extractMetadataLutRefsFromGradeJsonText(
  gradeJsonPath: string,
  jsonText: string,
): MetadataLutRefs {
  let raw: unknown;
  try {
    raw = JSON.parse(jsonText) as unknown;
  } catch {
    return createEmptyMetadataLutRefs();
  }

  const parsed = filmLookGradeInputSchema.safeParse(raw);
  if (!parsed.success) {
    return createEmptyMetadataLutRefs();
  }

  const grade = parsed.data;
  return {
    lut1: {
      enabled:
        typeof grade.lut1CubeRelPath === "string" && grade.lut1Enabled !== false,
      intensity: grade.lut1Intensity ?? 1,
      displayName: grade.lut1CubeRelPath
        ? basename(grade.lut1CubeRelPath)
        : null,
      absolutePath: grade.lut1CubeRelPath
        ? resolveAbsolutePathRelativeToFile(
            gradeJsonPath,
            grade.lut1CubeRelPath,
          )
        : null,
    },
    lut2: {
      enabled:
        typeof grade.lutCubeRelPath === "string" && grade.lutEnabled !== false,
      intensity: grade.lutIntensity ?? 1,
      displayName: grade.lutCubeRelPath
        ? basename(grade.lutCubeRelPath)
        : null,
      absolutePath: grade.lutCubeRelPath
        ? resolveAbsolutePathRelativeToFile(gradeJsonPath, grade.lutCubeRelPath)
        : null,
    },
  };
}

export function inferPresetChoiceFromImportedJson(
  jsonText: string,
  resolvedParams: Params,
): PresetName {
  let raw: unknown;
  try {
    raw = JSON.parse(jsonText) as unknown;
  } catch {
    return findMatchingPreset(resolvedParams) ?? FILMTONE_DEFAULT_BASE_PRESET;
  }

  if (!raw || typeof raw !== "object") {
    return findMatchingPreset(resolvedParams) ?? FILMTONE_DEFAULT_BASE_PRESET;
  }

  const record = raw as Record<string, unknown>;
  if (
    typeof record.preset === "string" &&
    Object.prototype.hasOwnProperty.call(PRESETS, record.preset)
  ) {
    return record.preset as PresetName;
  }

  if (typeof record.lookPresetId === "string") {
    for (const presetName of Object.keys(PRESETS) as PresetName[]) {
      if (lookIdForPreset(presetName) === record.lookPresetId) {
        return presetName;
      }
    }
  }

  return findMatchingPreset(resolvedParams) ?? FILMTONE_DEFAULT_BASE_PRESET;
}

export function describeMetadataJsonPath(filePath: string): string {
  const dir = dirname(filePath);
  return dir.length > 0 ? joinPath(dir, basename(filePath)) : basename(filePath);
}
