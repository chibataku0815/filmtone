import type { BaseLookName } from "film-lab-core";
import { getSourceProfile } from "film-lab-core";
import type { BatchGradeState } from "./batch-pipeline";
import type {
  AppliedSourceProfileMetadata,
  MetadataLookSource,
  MetadataLutRefs,
} from "./export-metadata-session";
import { createMetadataLutRefFromRuntime } from "./export-metadata-session";
import type { ExportRenderGeometry } from "./export-render-geometry";
import { viewportRecordToParams } from "./viewport-to-params";

export type ExportGradeLutSlot = {
  name: string;
  data: Float32Array;
  size: number;
  intensity: number;
  /**
   * Built-in source-profile catalog id when this slot was filled from a
   * Camera Profile (lut1 only). null/undefined for custom `.cube` or lut2.
   */
  sourceProfileId?: string | null;
} | null;

export type ExportGradeLutState = {
  lut1: ExportGradeLutSlot;
  lut2: ExportGradeLutSlot;
};

export type EffectiveExportGradeSource = "preview" | "batch";

export type EffectiveExportGradeSnapshot = {
  grade: BatchGradeState;
  batchLookChoice: BaseLookName;
  lookSource: MetadataLookSource;
  lutRefs: MetadataLutRefs;
  appliedSourceProfile: AppliedSourceProfileMetadata | null;
  source: EffectiveExportGradeSource;
  captureError: string | null;
  exportRenderGeometry: ExportRenderGeometry | null;
};

export type BuildEffectiveExportGradeSnapshotInput = {
  viewportParams: Record<string, number | string> | null;
  currentBatchGrade: BatchGradeState;
  editLut: ExportGradeLutState;
  canvasLook: BaseLookName;
  fallbackBatchLookChoice: BaseLookName;
  fallbackLookSource: MetadataLookSource;
  fallbackLutRefs: MetadataLutRefs;
  fallbackAppliedSourceProfile?: AppliedSourceProfileMetadata | null;
  captureError?: string | null;
  exportRenderGeometry?: ExportRenderGeometry | null;
  /**
   * Caller-supplied ISO timestamp for the source-profile metadata
   * `appliedAtIso` field. Defaults to the current wall-clock time when
   * omitted; tests should pass a fixed value for round-trip determinism.
   */
  appliedAtIso?: string;
};

/**
 * Build the `input.sourceProfile` metadata payload from a runtime
 * `EditLutSlot`. Returns null when the user has not made an explicit
 * source-profile selection — the sidecar should omit the field entirely
 * in that case so existing v1 round-trip semantics are preserved.
 */
export function buildAppliedSourceProfileMetadata(
  slot: ExportGradeLutSlot,
  appliedAtIso: string,
): AppliedSourceProfileMetadata | null {
  if (!slot) return null;
  const sourceProfileId = slot.sourceProfileId ?? null;
  if (sourceProfileId) {
    const entry = getSourceProfile(sourceProfileId);
    if (entry) {
      return {
        selectionKind: "built-in",
        catalogId: entry.id,
        curve: entry.curve,
        impl: entry.impl,
        displayName: entry.displayName,
        appliedAtIso,
      };
    }
    // Unknown id (older/newer sidecar) — record literally so round-trips
    // do not silently lose the user's intent.
    return {
      selectionKind: "built-in",
      catalogId: sourceProfileId,
      curve: null,
      impl: null,
      displayName: slot.name || sourceProfileId,
      appliedAtIso,
    };
  }
  // Custom .cube path — slot is populated but no catalog id.
  return {
    selectionKind: "custom",
    catalogId: null,
    curve: null,
    impl: null,
    displayName: slot.name || "custom .cube",
    appliedAtIso,
  };
}

export function buildEffectiveExportGradeSnapshot({
  viewportParams,
  currentBatchGrade,
  editLut,
  canvasLook,
  fallbackBatchLookChoice,
  fallbackLookSource,
  fallbackLutRefs,
  fallbackAppliedSourceProfile = null,
  captureError = null,
  exportRenderGeometry = null,
  appliedAtIso,
}: BuildEffectiveExportGradeSnapshotInput): EffectiveExportGradeSnapshot {
  if (!viewportParams) {
    return {
      grade: currentBatchGrade,
      batchLookChoice: fallbackBatchLookChoice,
      lookSource: fallbackLookSource,
      lutRefs: fallbackLutRefs,
      appliedSourceProfile: fallbackAppliedSourceProfile,
      source: "batch",
      captureError,
      exportRenderGeometry,
    };
  }

  const nowIso = appliedAtIso ?? new Date().toISOString();

  return {
    grade: {
      params: viewportRecordToParams(
        viewportParams,
        currentBatchGrade.params.halationHue,
      ),
      depthTrack: currentBatchGrade.depthTrack,
      lut1Intensity: editLut.lut1?.intensity ?? 1,
      lut1Data: editLut.lut1?.data ?? null,
      lut1Size: editLut.lut1?.size ?? 0,
      lut1SourceProfileId: editLut.lut1?.sourceProfileId ?? null,
      lutIntensity: editLut.lut2?.intensity ?? 1,
      lutData: editLut.lut2?.data ?? null,
      lutSize: editLut.lut2?.size ?? 0,
    },
    batchLookChoice: canvasLook,
    lookSource: "editSync",
    lutRefs: {
      lut1: createMetadataLutRefFromRuntime(editLut.lut1),
      lut2: createMetadataLutRefFromRuntime(editLut.lut2),
    },
    appliedSourceProfile: buildAppliedSourceProfileMetadata(
      editLut.lut1,
      nowIso,
    ),
    source: "preview",
    captureError,
    exportRenderGeometry,
  };
}

function formatNumber(value: number): string {
  if (Number.isInteger(value)) return String(value);
  return Number(value.toFixed(6)).toString();
}

export function formatEffectiveExportGradeSummary(
  snapshot: EffectiveExportGradeSnapshot,
): string {
  const p = snapshot.grade.params;
  const depthFrames = snapshot.grade.depthTrack?.absolutePaths.length ?? 0;
  return [
    `source=${snapshot.source}`,
    `look.source=${snapshot.lookSource}`,
    `baseLook=${snapshot.batchLookChoice}`,
    `bloomStrength=${formatNumber(p.bloomStrength)}`,
    `halationIntensity=${formatNumber(p.halationIntensity)}`,
    `diffusion=${formatNumber(p.diffusion)}`,
    `grainIntensity=${formatNumber(p.grainIntensity)}`,
    `rgbShift=${formatNumber(p.rgbShift)}`,
    `lensSoftness=${formatNumber(p.lensSoftness)}`,
    `depthMistGain=${formatNumber(p.depthMistGain)}`,
    `depthGlowGain=${formatNumber(p.depthGlowGain)}`,
    `depthFrames=${depthFrames}`,
    `dustAmount=${formatNumber(p.dustAmount)}`,
    `scratchAmount=${formatNumber(p.scratchAmount)}`,
    `shaftIntensity=${formatNumber(p.shaftIntensity)}`,
    `crossFilterStrength=${formatNumber(p.crossFilterStrength)}`,
    snapshot.exportRenderGeometry
      ? `renderGeometry=${snapshot.exportRenderGeometry.renderWidth}x${snapshot.exportRenderGeometry.renderHeight}/${snapshot.exportRenderGeometry.fitMode}`
      : null,
  ].filter((part): part is string => part !== null).join(" ");
}

export function collectEffectiveExportGradeWarnings(
  snapshot: EffectiveExportGradeSnapshot,
): string[] {
  const warnings: string[] = [];
  const p = snapshot.grade.params;
  const depthFrames = snapshot.grade.depthTrack?.absolutePaths.length ?? 0;
  if (snapshot.captureError) {
    warnings.push(
      `preview params capture failed; falling back to ${snapshot.source} grade: ${snapshot.captureError}`,
    );
  }
  if ((p.depthMistGain > 0 || p.depthGlowGain > 0) && depthFrames === 0) {
    warnings.push(
      "depth-aware Mist/Glow requested, but no depth frames are attached; export will use neutral depth",
    );
  }
  if (p.shaftIntensity > 0 && p.crossFilterStrength <= 0 && p.shutterAngle <= 180) {
    warnings.push(
      "light shafts requested, but WebGPU only runs shafts when cross filter or motion blur is active",
    );
  }
  if (p.dustAmount > 0 || p.scratchAmount > 0) {
    warnings.push(
      "dust/scratches are requested, but the current WebGPU export path intentionally defers those passes",
    );
  }
  return warnings;
}
