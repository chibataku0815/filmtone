import type { PresetName } from "film-lab-core";
import type { BatchGradeState } from "./batch-pipeline";
import type {
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
} | null;

export type ExportGradeLutState = {
  lut1: ExportGradeLutSlot;
  lut2: ExportGradeLutSlot;
};

export type EffectiveExportGradeSource = "preview" | "batch";

export type EffectiveExportGradeSnapshot = {
  grade: BatchGradeState;
  batchPresetChoice: PresetName;
  lookSource: MetadataLookSource;
  lutRefs: MetadataLutRefs;
  source: EffectiveExportGradeSource;
  captureError: string | null;
  exportRenderGeometry: ExportRenderGeometry | null;
};

export type BuildEffectiveExportGradeSnapshotInput = {
  viewportParams: Record<string, number | string> | null;
  currentBatchGrade: BatchGradeState;
  editLut: ExportGradeLutState;
  canvasPreset: PresetName;
  fallbackBatchPresetChoice: PresetName;
  fallbackLookSource: MetadataLookSource;
  fallbackLutRefs: MetadataLutRefs;
  captureError?: string | null;
  exportRenderGeometry?: ExportRenderGeometry | null;
};

export function buildEffectiveExportGradeSnapshot({
  viewportParams,
  currentBatchGrade,
  editLut,
  canvasPreset,
  fallbackBatchPresetChoice,
  fallbackLookSource,
  fallbackLutRefs,
  captureError = null,
  exportRenderGeometry = null,
}: BuildEffectiveExportGradeSnapshotInput): EffectiveExportGradeSnapshot {
  if (!viewportParams) {
    return {
      grade: currentBatchGrade,
      batchPresetChoice: fallbackBatchPresetChoice,
      lookSource: fallbackLookSource,
      lutRefs: fallbackLutRefs,
      source: "batch",
      captureError,
      exportRenderGeometry,
    };
  }

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
      lutIntensity: editLut.lut2?.intensity ?? 1,
      lutData: editLut.lut2?.data ?? null,
      lutSize: editLut.lut2?.size ?? 0,
    },
    batchPresetChoice: canvasPreset,
    lookSource: "editSync",
    lutRefs: {
      lut1: createMetadataLutRefFromRuntime(editLut.lut1),
      lut2: createMetadataLutRefFromRuntime(editLut.lut2),
    },
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
    `preset=${snapshot.batchPresetChoice}`,
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
