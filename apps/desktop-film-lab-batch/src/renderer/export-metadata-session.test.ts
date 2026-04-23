import { describe, expect, it } from "vitest";
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  PRESETS,
  createFilmtoneDefaultParams,
  type PresetName,
} from "film-lab-core";
import { batchGradeStateFromPreset } from "./batch-pipeline";
import { buildGradeJsonPayload } from "./grade-io";
import {
  buildFilmtoneExportSession,
  buildPhotoMetadataSidecarFileName,
  buildVideoMetadataSidecarFileName,
  createEmptyMetadataLutRefs,
  exportFilmtoneExportSessionJsonText,
  extractMetadataLutRefsFromGradeJsonText,
  inferPresetChoiceFromImportedJson,
  parseFilmtoneExportSessionV1,
} from "./export-metadata-session";

function anotherPreset(except: PresetName): PresetName {
  const found = (Object.keys(PRESETS) as PresetName[]).find(
    (presetName) => presetName !== except,
  );
  if (!found) {
    throw new Error("anotherPreset: expected more than one preset");
  }
  return found;
}

describe("export metadata session", () => {
  it("builds and parses a public sidecar round-trip", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-19T12:34:56.000Z",
      appVersion: "1.2.3",
      job: "images",
      inputDir: "/Users/tester/input",
      videoInputPath: null,
      outputDir: "/Users/tester/output",
      imageFormat: "jpeg",
      outputFilenameSuffix: "-graded",
      outputFileName: null,
      batchPresetChoice: "cinematic",
      lookSource: "preset",
      gradeParams: cinematic.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
    });

    const parsed = parseFilmtoneExportSessionV1(
      JSON.parse(exportFilmtoneExportSessionJsonText(session)) as unknown,
    );

    expect(parsed).toEqual(session);
  });

  it("forces video sidecars to omit image-batch inputDir state", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-19T12:34:56.000Z",
      appVersion: "1.2.3",
      job: "video",
      inputDir: "/Users/tester/stale-image-folder",
      videoInputPath: "/Users/tester/input/clip.mov",
      outputDir: "/Users/tester/output",
      imageFormat: null,
      outputFilenameSuffix: null,
      outputFileName: "clip-graded.mp4",
      batchPresetChoice: "cinematic",
      lookSource: "editSync",
      gradeParams: cinematic.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
    });

    expect(session.input).toEqual({
      inputDir: null,
      videoInputPath: "/Users/tester/input/clip.mov",
    });
  });

  it("forces image sidecars to omit video input state", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-19T12:34:56.000Z",
      appVersion: "1.2.3",
      job: "images",
      inputDir: "/Users/tester/input",
      videoInputPath: "/Users/tester/input/clip.mov",
      outputDir: "/Users/tester/output",
      imageFormat: "jpeg",
      outputFilenameSuffix: "-graded",
      outputFileName: null,
      batchPresetChoice: "cinematic",
      lookSource: "preset",
      gradeParams: cinematic.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
    });

    expect(session.input).toEqual({
      inputDir: "/Users/tester/input",
      videoInputPath: null,
    });
  });

  it("includes optional optical recommendation metadata only when provided", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const session = buildFilmtoneExportSession({
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
      lookSource: "analysisRecommendation",
      gradeParams: cinematic.params,
      depthTrack: null,
      lutRefs: createEmptyMetadataLutRefs(),
      opticalRecommendation: {
        family: "glow",
        profile: "warm",
        recipe: "warmIndoor",
        analyzerVersion: "scene-aware-v1",
        appliedAtIso: "2026-04-20T12:00:00.000Z",
      },
    });

    expect(session.look.opticalRecommendation).toEqual({
      family: "glow",
      profile: "warm",
      recipe: "warmIndoor",
      analyzerVersion: "scene-aware-v1",
      appliedAtIso: "2026-04-20T12:00:00.000Z",
    });
  });

  it("serializes depth-track metadata in both wrapper and sidecar roots", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const depthTrack = {
      source: {
        kind: "frameSequence" as const,
        fps: 25,
        frameRelPaths: ["depth/0001.png", "depth/0002.png"],
      },
      absolutePaths: [
        "/Users/tester/output/depth/0001.png",
        "/Users/tester/output/depth/0002.png",
      ],
      frameUrls: ["blob:depth-1", "blob:depth-2"],
    };
    const session = buildFilmtoneExportSession({
      exportedAtIso: "2026-04-20T12:34:56.000Z",
      appVersion: "1.2.3",
      job: "images",
      inputDir: "/Users/tester/input",
      videoInputPath: null,
      outputDir: "/Users/tester/output",
      imageFormat: "png",
      outputFilenameSuffix: "-graded",
      outputFileName: null,
      batchPresetChoice: "cinematic",
      lookSource: "importedJson",
      gradeParams: cinematic.params,
      depthTrack,
      lutRefs: createEmptyMetadataLutRefs(),
    });

    expect(
      (session.look.grade as { depthTrack?: unknown }).depthTrack,
    ).toEqual(depthTrack.source);
    expect(session.depthTrack).toEqual({
      enabled: true,
      fps: 25,
      framePaths: depthTrack.absolutePaths,
    });
  });

  it("creates timestamped photo sidecar filenames", () => {
    expect(
      buildPhotoMetadataSidecarFileName("2026-04-19T12:34:56.789Z"),
    ).toBe("filmtone-export-session-20260419T123456Z.json");
  });

  it("creates companion video sidecar filenames", () => {
    expect(buildVideoMetadataSidecarFileName("clip-graded.mp4")).toBe(
      "clip-graded.filmtone-session.json",
    );
  });

  it("extracts LUT path references from legacy grade JSON", () => {
    const cinematic = batchGradeStateFromPreset("cinematic");
    const gradeJson = {
      ...buildGradeJsonPayload(cinematic.params),
      lut1CubeRelPath: "../luts/print.cube",
      lut1Enabled: true,
      lut1Intensity: 0.65,
      lutCubeRelPath: "./show.cube",
      lutEnabled: true,
      lutIntensity: 0.4,
    };

    const refs = extractMetadataLutRefsFromGradeJsonText(
      "/Users/tester/projects/look/grade.json",
      JSON.stringify(gradeJson),
    );

    expect(refs).toEqual({
      lut1: {
        enabled: true,
        intensity: 0.65,
        displayName: "print.cube",
        absolutePath: "/Users/tester/projects/luts/print.cube",
      },
      lut2: {
        enabled: true,
        intensity: 0.4,
        displayName: "show.cube",
        absolutePath: "/Users/tester/projects/look/show.cube",
      },
    });
  });

  it("prefers explicit preset identity from imported JSON over resolved params", () => {
    const explicitPreset = "cinematic" as const;
    const fallbackPreset = anotherPreset(explicitPreset);
    const explicitJson = JSON.stringify(
      buildGradeJsonPayload(batchGradeStateFromPreset(explicitPreset).params),
    );

    const inferred = inferPresetChoiceFromImportedJson(
      explicitJson,
      batchGradeStateFromPreset(fallbackPreset).params,
    );

    expect(inferred).toBe(explicitPreset);
  });

  it("falls back unmatched grade JSON exports to the neutral reset look id", () => {
    const payload = buildGradeJsonPayload(createFilmtoneDefaultParams());

    expect(payload.lookPresetId).toBe("look:mp:reset:v1");
  });

  it("infers reset instead of cinematic for malformed unmatched imports", () => {
    const inferred = inferPresetChoiceFromImportedJson(
      "{not-json",
      createFilmtoneDefaultParams(),
    );

    expect(inferred).toBe(FILMTONE_DEFAULT_BASE_PRESET);
  });
});
