import { describe, expect, it, vi } from "vitest";
import {
  PRESETS,
  createDefaultFilmLookGradeProps,
} from "film-lab-core";

import type { FilmLabBatchBridge } from "./desktop-api";
import {
  resolveLutCubeAbsPathForFastExport,
  runVideoExportFfmpegFast,
} from "./video-export-ffmpeg-fast";

describe("video-export-ffmpeg-fast", () => {
  it("resolves a JSON-derived .cube path for LUT-first fast export", async () => {
    const grade = {
      ...createDefaultFilmLookGradeProps(),
      lutEnabled: true,
      lutIntensity: 1,
      lutCubeRelPath: "luts/demo.cube",
    };
    const api = {
      readFileUtf8: vi.fn().mockResolvedValue(JSON.stringify(grade)),
    } as unknown as FilmLabBatchBridge;

    await expect(
      resolveLutCubeAbsPathForFastExport(api, "/tmp/look/grade.json"),
    ).resolves.toBe("/tmp/look/luts/demo.cube");
  });

  it("passes gradeParams through to the fast IPC contract", async () => {
    const videoExportTranscodeFast = vi.fn().mockResolvedValue({
      code: 0,
      stderrTail: "",
      outputVideoPath: "/tmp/out/clip-graded.mp4",
    });
    const api = {
      videoExportProbe: vi.fn().mockResolvedValue({
        sourceFrameRate: null,
        sourceFrameRateTrusted: false,
        width: 1280,
        height: 720,
        durationSec: 3,
        hasAudio: true,
        videoCodec: "h264",
        fileSizeBytes: 1024,
      }),
      videoExportTranscodeFast,
    } as unknown as FilmLabBatchBridge;

    const result = await runVideoExportFfmpegFast({
      api,
      inputVideoPath: "/tmp/input/clip.mov",
      outputDir: "/tmp/out",
      outputFileName: "clip-graded.mp4",
      lutCubeAbsPath: "/tmp/looks/demo.cube",
      gradeParams: PRESETS.cinematic,
      onLog: () => {},
    });

    expect(result).toEqual({ ok: true });
    expect(videoExportTranscodeFast).toHaveBeenCalledTimes(1);
    expect(videoExportTranscodeFast).toHaveBeenCalledWith(
      expect.objectContaining({
        gradeParams: PRESETS.cinematic,
        lutCubeAbsPath: "/tmp/looks/demo.cube",
      }),
    );
  });
});
