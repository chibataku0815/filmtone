import { z } from "zod";
import {
  PRESETS,
  filmLookGradeInputSchema,
  findMatchingPreset,
  lookIdForPreset,
  type PresetName,
  type Params,
} from "film-lab-core";
import type { BatchFormat } from "./batch-pipeline";
import { buildGradeJsonPayload } from "./grade-io";

export const METADATA_LOOK_SOURCES = [
  "preset",
  "editSync",
  "importedJson",
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

const filmtoneExportSessionSchema = z.object({
  kind: z.literal("filmtone-export-session"),
  version: z.literal(1),
  exportedAtIso: z.string().min(1),
  appVersion: z.string().min(1),
  job: z.enum(["images", "video"]),
  input: z.object({
    inputDir: z.string().min(1).nullable(),
    videoInputPath: z.string().min(1).nullable(),
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
  }),
  lutRefs: z.object({
    lut1: metadataLutRefSchema,
    lut2: metadataLutRefSchema,
  }),
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
  lutRefs: MetadataLutRefs;
}): FilmtoneExportSessionV1 {
  return {
    kind: "filmtone-export-session",
    version: 1,
    exportedAtIso: params.exportedAtIso,
    appVersion: params.appVersion,
    job: params.job,
    input: {
      inputDir: params.inputDir,
      videoInputPath: params.videoInputPath,
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
        buildGradeJsonPayload(params.gradeParams) as unknown as FilmtoneExportSessionV1["look"]["grade"],
    },
    lutRefs: params.lutRefs,
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
    return findMatchingPreset(resolvedParams) ?? "cinematic";
  }

  if (!raw || typeof raw !== "object") {
    return findMatchingPreset(resolvedParams) ?? "cinematic";
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

  return findMatchingPreset(resolvedParams) ?? "cinematic";
}

export function describeMetadataJsonPath(filePath: string): string {
  const dir = dirname(filePath);
  return dir.length > 0 ? joinPath(dir, basename(filePath)) : basename(filePath);
}
