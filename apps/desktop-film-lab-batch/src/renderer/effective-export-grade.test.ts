import { describe, expect, it } from "vitest";
import { PRESETS } from "film-lab-core";
import { createDefaultBatchGradeState } from "./batch-pipeline";
import { createEmptyMetadataLutRefs } from "./export-metadata-session";
import {
  buildEffectiveExportGradeSnapshot,
  collectEffectiveExportGradeWarnings,
  formatEffectiveExportGradeSummary,
} from "./effective-export-grade";
import type { BatchDepthTrack } from "./depth-track";

describe("buildEffectiveExportGradeSnapshot", () => {
  it("uses current preview params as the export grade when viewport params exist", () => {
    const depthTrack: BatchDepthTrack = {
      source: {
        kind: "frameSequence",
        fps: 25,
        frameRelPaths: ["depth/0001.png"],
      },
      absolutePaths: ["/tmp/depth/0001.png"],
      frameUrls: ["blob:depth-0001"],
    };
    const currentBatchGrade = {
      ...createDefaultBatchGradeState(),
      depthTrack,
    };
    const lut1Data = new Float32Array([0, 0.5, 1]);
    const lut2Data = new Float32Array([1, 0.5, 0]);

    const snapshot = buildEffectiveExportGradeSnapshot({
      viewportParams: {
        bloomStrength: 0.91,
        halationIntensity: 0.37,
        diffusion: 0.28,
        grainIntensity: 0.08,
        rgbShift: 0.0024,
        lensSoftness: 0.62,
        depthMistGain: 0.45,
        depthGlowGain: 0.32,
        halationHue: 31,
      },
      currentBatchGrade,
      editLut: {
        lut1: {
          name: "log-to-rec709.cube",
          data: lut1Data,
          size: 2,
          intensity: 0.75,
        },
        lut2: {
          name: "print.cube",
          data: lut2Data,
          size: 2,
          intensity: 0.42,
        },
      },
      canvasPreset: "cinematic",
      fallbackBatchPresetChoice: "reset",
      fallbackLookSource: "preset",
      fallbackLutRefs: createEmptyMetadataLutRefs(),
    });

    expect(snapshot.source).toBe("preview");
    expect(snapshot.lookSource).toBe("editSync");
    expect(snapshot.batchPresetChoice).toBe("cinematic");
    expect(snapshot.grade.depthTrack).toBe(depthTrack);
    expect(snapshot.grade.params.bloomStrength).toBe(0.91);
    expect(snapshot.grade.params.halationIntensity).toBe(0.37);
    expect(snapshot.grade.params.diffusion).toBe(0.28);
    expect(snapshot.grade.params.grainIntensity).toBe(0.08);
    expect(snapshot.grade.params.rgbShift).toBe(0.0024);
    expect(snapshot.grade.params.lensSoftness).toBe(0.62);
    expect(snapshot.grade.params.depthMistGain).toBe(0.45);
    expect(snapshot.grade.params.depthGlowGain).toBe(0.32);
    expect(snapshot.grade.params.halationHue).toBe(31);
    expect(snapshot.grade.lut1Data).toBe(lut1Data);
    expect(snapshot.grade.lut1Size).toBe(2);
    expect(snapshot.grade.lut1Intensity).toBe(0.75);
    expect(snapshot.grade.lutData).toBe(lut2Data);
    expect(snapshot.grade.lutSize).toBe(2);
    expect(snapshot.grade.lutIntensity).toBe(0.42);
    expect(snapshot.lutRefs.lut1).toEqual({
      enabled: true,
      intensity: 0.75,
      displayName: "log-to-rec709.cube",
      absolutePath: null,
    });
    expect(snapshot.lutRefs.lut2).toEqual({
      enabled: true,
      intensity: 0.42,
      displayName: "print.cube",
      absolutePath: null,
    });
    expect(snapshot.exportRenderGeometry).toBeNull();
  });

  it("falls back to the current batch grade when preview params are unavailable", () => {
    const currentBatchGrade = createDefaultBatchGradeState();
    const fallbackLutRefs = createEmptyMetadataLutRefs();
    const snapshot = buildEffectiveExportGradeSnapshot({
      viewportParams: null,
      currentBatchGrade,
      editLut: { lut1: null, lut2: null },
      canvasPreset: "cinematic",
      fallbackBatchPresetChoice: "reset",
      fallbackLookSource: "preset",
      fallbackLutRefs,
      captureError: "lost context",
    });

    expect(snapshot.source).toBe("batch");
    expect(snapshot.grade).toBe(currentBatchGrade);
    expect(snapshot.batchPresetChoice).toBe("reset");
    expect(snapshot.lookSource).toBe("preset");
    expect(snapshot.lutRefs).toBe(fallbackLutRefs);
    expect(snapshot.captureError).toBe("lost context");
    expect(snapshot.exportRenderGeometry).toBeNull();
  });

  it("carries video export render geometry with the effective snapshot", () => {
    const currentBatchGrade = createDefaultBatchGradeState();
    const exportRenderGeometry = {
      renderWidth: 1920,
      renderHeight: 1080,
      sourceWidth: 1920,
      sourceHeight: 1080,
      sourceDisplayWidth: 1920,
      sourceDisplayHeight: 1080,
      fitMode: "cover" as const,
      fps: 25,
    };
    const snapshot = buildEffectiveExportGradeSnapshot({
      viewportParams: PRESETS.reset as unknown as Record<string, number | string>,
      currentBatchGrade,
      editLut: { lut1: null, lut2: null },
      canvasPreset: "reset",
      fallbackBatchPresetChoice: "reset",
      fallbackLookSource: "preset",
      fallbackLutRefs: createEmptyMetadataLutRefs(),
      exportRenderGeometry,
    });

    expect(snapshot.exportRenderGeometry).toBe(exportRenderGeometry);
    expect(formatEffectiveExportGradeSummary(snapshot)).toContain(
      "renderGeometry=1920x1080/cover",
    );
  });

  it("summarizes effect values and emits actionable export warnings", () => {
    const currentBatchGrade = createDefaultBatchGradeState();
    const snapshot = buildEffectiveExportGradeSnapshot({
      viewportParams: {
        ...PRESETS.reset,
        bloomStrength: 0.5,
        diffusion: 0.25,
        depthMistGain: 0.4,
        shaftIntensity: 0.3,
        dustAmount: 0.2,
        scratchAmount: 0.1,
      },
      currentBatchGrade,
      editLut: { lut1: null, lut2: null },
      canvasPreset: "reset",
      fallbackBatchPresetChoice: "reset",
      fallbackLookSource: "preset",
      fallbackLutRefs: createEmptyMetadataLutRefs(),
    });

    expect(formatEffectiveExportGradeSummary(snapshot)).toContain(
      "bloomStrength=0.5",
    );
    expect(formatEffectiveExportGradeSummary(snapshot)).toContain(
      "depthFrames=0",
    );
    expect(collectEffectiveExportGradeWarnings(snapshot)).toEqual([
      "depth-aware Mist/Glow requested, but no depth frames are attached; export will use neutral depth",
      "light shafts requested, but WebGPU only runs shafts when cross filter or motion blur is active",
      "dust/scratches are requested, but the current WebGPU export path intentionally defers those passes",
    ]);
  });
});
