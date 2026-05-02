import { describe, expect, it } from "vitest";

import { batchGradeStateFromPreset } from "./batch-pipeline";
import {
  buildFilmtoneExportSession,
  createEmptyMetadataLutRefs,
  exportFilmtoneExportSessionJsonText,
  parseFilmtoneExportSessionV1,
} from "./export-metadata-session";
import { resolveImportedMetadataJson } from "./metadata-json-runtime";
import type { FilmLabBatchBridge } from "./desktop-api";
import { exportGradeJsonText } from "./grade-io";

describe("metadata-json-runtime", () => {
  it("preserves sidecar camera optics through import and re-export build", async () => {
    const grade = batchGradeStateFromPreset("cinematic");
    const cameraOptics = {
      source: "manual" as const,
      fxPx: 1566.7,
      fyPx: 1566.7,
      cxPx: 960,
      cyPx: 540,
      fovXDeg: 63,
      fovYDeg: 38,
      focalLength35mm: 28,
      lensModel: "Wide Camera",
      cameraMake: "Filmtone",
      cameraModel: "RoundTrip",
    };
    const importedSession = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-20T12:34:56.000Z",
      appVersion: "1.2.3",
      job: "video",
      inputDir: null,
      videoInputPath: "/Users/tester/input/clip.mov",
      outputDir: "/Users/tester/output",
      imageFormat: null,
      outputFilenameSuffix: null,
      outputFileName: "clip-graded.mp4",
      batchPresetChoice: "cinematic",
      lookSource: "editSync",
      gradeParams: grade.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
      cameraOptics,
    });

    const resolved = await resolveImportedMetadataJson(
      {} as FilmLabBatchBridge,
      "/Users/tester/output/clip-graded.filmtone-session.json",
      exportFilmtoneExportSessionJsonText(importedSession),
    );

    expect(resolved.cameraOptics).toEqual(cameraOptics);

    const reExportedSession = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-20T12:45:00.000Z",
      appVersion: "1.2.4",
      job: "video",
      inputDir: null,
      videoInputPath: "/Users/tester/output/clip-graded.mp4",
      outputDir: "/Users/tester/output2",
      imageFormat: null,
      outputFilenameSuffix: null,
      outputFileName: "clip-graded-graded.mp4",
      batchPresetChoice: resolved.batchPresetChoice,
      lookSource: resolved.lookSource,
      gradeParams: resolved.batchGrade.params,
      depthTrack: resolved.batchGrade.depthTrack,
      lutRefs: resolved.lutRefs,
      opticalRecommendation: resolved.appliedOpticalRecommendation,
      cameraOptics: resolved.cameraOptics,
    });

    const parsed = parseFilmtoneExportSessionV1(reExportedSession);
    expect(parsed?.version).toBe(1);
    expect(parsed?.input.cameraOptics).toEqual(cameraOptics);
  });

  it("preserves core grade JSON camera optics on restore", async () => {
    const grade = batchGradeStateFromPreset("cinematic");
    const cameraOptics = {
      source: "metadata" as const,
      fovXDeg: 54.4,
      fovYDeg: 32.3,
      fxPx: 2400,
      fyPx: 2400,
    };

    const resolved = await resolveImportedMetadataJson(
      {} as FilmLabBatchBridge,
      "/Users/tester/output/film-lab-grade.json",
      exportGradeJsonText(grade.params, null, cameraOptics),
    );

    expect(resolved.cameraOptics).toEqual(cameraOptics);
  });

  it("regenerates lut1 from a built-in source-profile catalog id without reading any .cube file", async () => {
    const grade = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-05-02T13:00:00.000Z",
      appVersion: "1.4.0",
      job: "images",
      inputDir: "/Users/tester/input",
      videoInputPath: null,
      outputDir: "/Users/tester/output",
      imageFormat: "jpeg",
      outputFilenameSuffix: "-graded",
      outputFileName: null,
      batchPresetChoice: "cinematic",
      lookSource: "editSync",
      gradeParams: grade.params,
      depthTrack: null,
      lutRefs: {
        lut1: {
          enabled: true,
          intensity: 1,
          displayName: "V-Log",
          absolutePath: null,
        },
        lut2: createEmptyMetadataLutRefs().lut2,
      },
      sourceProfile: {
        selectionKind: "built-in",
        catalogId: "built-in:source-profile.panasonic-vlog",
        curve: "panasonic-vlog",
        impl: "synthesized",
        displayName: "V-Log",
        appliedAtIso: "2026-05-02T13:00:00.000Z",
      },
    });

    let readFileCalls = 0;
    const bridge = {
      readFileUtf8: async () => {
        readFileCalls += 1;
        return "";
      },
    } as unknown as FilmLabBatchBridge;

    const resolved = await resolveImportedMetadataJson(
      bridge,
      "/Users/tester/output/photo.filmtone-session.json",
      exportFilmtoneExportSessionJsonText(session),
    );

    expect(readFileCalls).toBe(0);
    expect(resolved.batchGrade.lut1Data).not.toBeNull();
    expect(resolved.batchGrade.lut1Size).toBe(33);
    expect(resolved.batchGrade.lut1Data?.length).toBe(33 * 33 * 33 * 4);
    expect(resolved.batchGrade.lut1SourceProfileId).toBe(
      "built-in:source-profile.panasonic-vlog",
    );
    expect(resolved.lutRefs.lut1).toEqual({
      enabled: true,
      intensity: 1,
      displayName: "V-Log",
      absolutePath: null,
    });
    expect(resolved.warnings).toEqual([]);
  });

  it("treats a built-in Rec.709 nilProfile as 'no LUT to apply' but records the selection", async () => {
    const grade = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-05-02T13:00:00.000Z",
      appVersion: "1.4.0",
      job: "images",
      inputDir: "/Users/tester/input",
      videoInputPath: null,
      outputDir: "/Users/tester/output",
      imageFormat: "jpeg",
      outputFilenameSuffix: "-graded",
      outputFileName: null,
      batchPresetChoice: "cinematic",
      lookSource: "editSync",
      gradeParams: grade.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
      sourceProfile: {
        selectionKind: "built-in",
        catalogId: "built-in:source-profile.rec709",
        curve: null,
        impl: "nil-profile",
        displayName: "Rec.709",
        appliedAtIso: "2026-05-02T13:00:00.000Z",
      },
    });

    const resolved = await resolveImportedMetadataJson(
      {} as FilmLabBatchBridge,
      "/Users/tester/output/photo.filmtone-session.json",
      exportFilmtoneExportSessionJsonText(session),
    );

    expect(resolved.batchGrade.lut1Data).toBeNull();
    expect(resolved.batchGrade.lut1Size).toBe(0);
    expect(resolved.batchGrade.lut1SourceProfileId).toBe(
      "built-in:source-profile.rec709",
    );
    expect(resolved.lutRefs.lut1.enabled).toBe(false);
    expect(resolved.lutRefs.lut1.displayName).toBe("Rec.709");
  });
});
