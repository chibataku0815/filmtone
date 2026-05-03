import {
  FILMTONE_DEFAULT_BASE_LOOK,
  buildSourceProfileLut,
  getSourceProfile,
  parseCube,
  type CameraOptics,
  type BaseLookName,
} from "film-lab-core";
import type { FilmLabBatchBridge } from "./desktop-api";
import {
  type AppliedOpticalFilterProfileMetadata,
  type AppliedOpticalRecommendationMetadata,
  type AppliedSourceProfileMetadata,
  createEmptyMetadataLutRefs,
  extractMetadataLutRefsFromGradeJsonText,
  inferBaseLookChoiceFromImportedJson,
  parseFilmtoneExportSessionV1,
  type FilmtoneExportSessionV1,
  type MetadataDepthTrackRef,
  type MetadataLookSource,
  type MetadataLutRefs,
} from "./export-metadata-session";
import type { BatchGradeState } from "./batch-pipeline";
import { loadBatchDepthTrackFromAbsolutePaths } from "./depth-track";
import { resolveGradeFromJsonText } from "./batch-pipeline";

export type ResolvedImportedMetadataJson = {
  batchGrade: BatchGradeState;
  batchLookChoice: BaseLookName;
  lookSource: MetadataLookSource;
  lutRefs: MetadataLutRefs;
  importedFilePath: string;
  syncedAtMs: number | null;
  appliedOpticalRecommendation: AppliedOpticalRecommendationMetadata | null;
  appliedOpticalFilterProfile: AppliedOpticalFilterProfileMetadata | null;
  cameraOptics: CameraOptics | null;
  sidecar: FilmtoneExportSessionV1 | null;
  warnings: string[];
};

async function loadBatchGradeFromLutRefs(
  api: FilmLabBatchBridge,
  params: BatchGradeState["params"],
  lutRefs: MetadataLutRefs,
  depthTrackRef: MetadataDepthTrackRef,
  sourceProfileMetadata?: AppliedSourceProfileMetadata,
): Promise<{
  batchGrade: BatchGradeState;
  resolvedLutRefs: MetadataLutRefs;
  warnings: string[];
}> {
  const warnings: string[] = [];
  const resolvedLutRefs: MetadataLutRefs = {
    lut1: { ...lutRefs.lut1 },
    lut2: { ...lutRefs.lut2 },
  };
  const batchGrade: BatchGradeState = {
    params,
    depthTrack: null,
    lut1Intensity: lutRefs.lut1.intensity,
    lut1Data: null,
    lut1Size: 0,
    lut1SourceProfileId: null,
    lutIntensity: lutRefs.lut2.intensity,
    lutData: null,
    lutSize: 0,
  };

  // Built-in source profile takes precedence over absolutePath for lut1.
  // Sidecars produced after v1.4 carry `input.sourceProfile` so the LUT
  // can be regenerated locally without an absolute `.cube` path.
  let lut1HandledByBuiltIn = false;
  if (
    sourceProfileMetadata &&
    sourceProfileMetadata.selectionKind === "built-in" &&
    sourceProfileMetadata.catalogId
  ) {
    const catalogId = sourceProfileMetadata.catalogId;
    const entry = getSourceProfile(catalogId);
    if (entry) {
      const built = buildSourceProfileLut(catalogId);
      if (built) {
        batchGrade.lut1Data = built.data;
        batchGrade.lut1Size = built.size;
        batchGrade.lut1SourceProfileId = catalogId;
        resolvedLutRefs.lut1 = {
          enabled: true,
          intensity: lutRefs.lut1.intensity,
          displayName: built.displayName,
          absolutePath: null,
        };
        lut1HandledByBuiltIn = true;
      } else {
        // nil-profile (Rec.709 passthrough) — record selection but apply nothing.
        batchGrade.lut1SourceProfileId = catalogId;
        resolvedLutRefs.lut1 = {
          enabled: false,
          intensity: lutRefs.lut1.intensity,
          displayName: entry.displayName,
          absolutePath: null,
        };
        lut1HandledByBuiltIn = true;
      }
    } else {
      warnings.push(
        `lut1: unknown source-profile catalogId "${catalogId}", falling back to absolutePath`,
      );
    }
  }

  const loadSlot = async (
    slotKey: "lut1" | "lut2",
  ): Promise<void> => {
    if (slotKey === "lut1" && lut1HandledByBuiltIn) {
      return;
    }
    const slot = resolvedLutRefs[slotKey];
    if (!slot.enabled) {
      return;
    }
    if (!slot.absolutePath) {
      warnings.push(`${slotKey}: path missing`);
      resolvedLutRefs[slotKey] = { ...slot, enabled: false };
      return;
    }
    try {
      const cubeText = await api.readFileUtf8(slot.absolutePath);
      const cube = parseCube(cubeText);
      if (slotKey === "lut1") {
        batchGrade.lut1Data = cube.data;
        batchGrade.lut1Size = cube.size;
      } else {
        batchGrade.lutData = cube.data;
        batchGrade.lutSize = cube.size;
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      warnings.push(`${slotKey}: ${msg}`);
      resolvedLutRefs[slotKey] = { ...slot, enabled: false };
    }
  };

  await loadSlot("lut1");
  await loadSlot("lut2");
  if (depthTrackRef.enabled) {
    if (depthTrackRef.framePaths.length === 0) {
      warnings.push("depthTrack: no frame paths");
    } else {
      try {
        batchGrade.depthTrack = await loadBatchDepthTrackFromAbsolutePaths(
          api,
          depthTrackRef.framePaths,
          depthTrackRef.fps,
        );
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        warnings.push(`depthTrack: ${msg}`);
      }
    }
  }
  return { batchGrade, resolvedLutRefs, warnings };
}

export async function resolveImportedMetadataJson(
  api: FilmLabBatchBridge,
  filePath: string,
  jsonText: string,
): Promise<ResolvedImportedMetadataJson> {
  let raw: unknown;
  try {
    raw = JSON.parse(jsonText) as unknown;
  } catch {
    raw = null;
  }

  const sidecar = parseFilmtoneExportSessionV1(raw);
  if (sidecar) {
    const loaded = await loadBatchGradeFromLutRefs(
      api,
      sidecar.look.grade.grade as unknown as BatchGradeState["params"],
      sidecar.lutRefs,
      sidecar.depthTrack,
      sidecar.input.sourceProfile,
    );
    const parsedSyncTime = Date.parse(sidecar.exportedAtIso);
    return {
      batchGrade: loaded.batchGrade,
      batchLookChoice: sidecar.look.batchLookChoice,
      lookSource: sidecar.look.source,
      lutRefs: loaded.resolvedLutRefs,
      importedFilePath: filePath,
      syncedAtMs:
        sidecar.look.source === "editSync" && Number.isFinite(parsedSyncTime)
          ? parsedSyncTime
          : null,
      appliedOpticalRecommendation: sidecar.look.opticalRecommendation ?? null,
      appliedOpticalFilterProfile: sidecar.look.opticalFilterProfile ?? null,
      cameraOptics: sidecar.input.cameraOptics ?? null,
      sidecar,
      warnings: loaded.warnings,
    };
  }

  const resolvedGrade = await resolveGradeFromJsonText(api, filePath, jsonText);
  return {
    batchGrade: {
      params: resolvedGrade.params,
      depthTrack: resolvedGrade.depthTrack,
      lut1Intensity: resolvedGrade.lut1Intensity,
      lut1Data: resolvedGrade.lut1Data,
      lut1Size: resolvedGrade.lut1Size,
      lut1SourceProfileId: resolvedGrade.lut1SourceProfileId,
      lutIntensity: resolvedGrade.lutIntensity,
      lutData: resolvedGrade.lutData,
      lutSize: resolvedGrade.lutSize,
    },
    batchLookChoice: inferBaseLookChoiceFromImportedJson(
      jsonText,
      resolvedGrade.params,
    ),
    lookSource: "importedJson",
    lutRefs: extractMetadataLutRefsFromGradeJsonText(filePath, jsonText),
    importedFilePath: filePath,
    syncedAtMs: null,
    appliedOpticalRecommendation: null,
    appliedOpticalFilterProfile: null,
    cameraOptics: resolvedGrade.cameraOptics,
    sidecar: null,
    warnings: [],
  };
}

export function emptyResolvedMetadataJson(filePath: string): ResolvedImportedMetadataJson {
  return {
    batchGrade: {
      params: {} as BatchGradeState["params"],
      depthTrack: null,
      lut1Intensity: 1,
      lut1Data: null,
      lut1Size: 0,
      lut1SourceProfileId: null,
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
    },
    batchLookChoice: FILMTONE_DEFAULT_BASE_LOOK,
    lookSource: "builtInLook",
    lutRefs: createEmptyMetadataLutRefs(),
    importedFilePath: filePath,
    syncedAtMs: null,
    appliedOpticalRecommendation: null,
    appliedOpticalFilterProfile: null,
    cameraOptics: null,
    sidecar: null,
    warnings: [],
  };
}
