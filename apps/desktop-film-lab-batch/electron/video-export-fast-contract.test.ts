import { describe, expect, it } from "vitest";
import { PRESETS } from "film-lab-core";

import {
  FILM_LAB_VIDEO_PROTOCOL,
  absolutePathToVideoSrcUrl,
  buildFfmpegFastTranscodeArgs,
  parseFastTranscodeRequest,
} from "./video-export-fast-contract";

describe("video-export-fast-contract", () => {
  it("uses the custom film-lab-video protocol for renderer video URLs", () => {
    expect(absolutePathToVideoSrcUrl("/tmp/input/clip.mov")).toBe(
      `${FILM_LAB_VIDEO_PROTOCOL}://local/?path=%2Ftmp%2Finput%2Fclip.mov`,
    );
  });

  it("schema-validates gradeParams before building the fast contract", () => {
    const parsed = parseFastTranscodeRequest({
      inputVideoPath: "/tmp/input/clip.mov",
      outputDir: "/tmp/out",
      outputFileName: "clip-graded.mp4",
      width: 1920,
      height: 1080,
      fps: 24,
      hasAudio: true,
      lutCubeAbsPath: " /tmp/looks/demo.cube ",
      gradeParams: PRESETS.cinematic,
    });

    expect(parsed.gradeParams).toEqual(PRESETS.cinematic);
    expect(parsed.lutCubeAbsPath).toBe("/tmp/looks/demo.cube");
  });

  it("threads validated gradeParams and LUT data into ffmpeg args", () => {
    const parsed = parseFastTranscodeRequest({
      inputVideoPath: "/tmp/input/clip.mov",
      outputDir: "/tmp/out",
      outputFileName: "clip-graded.mp4",
      width: 1920,
      height: 1080,
      fps: 24,
      hasAudio: true,
      lutCubeAbsPath: "/tmp/looks/demo.cube",
      gradeParams: PRESETS.cinematic,
    });

    const args = buildFfmpegFastTranscodeArgs({
      inputVideoPath: parsed.inputVideoPath,
      outputVideoPath: "/tmp/out/clip-graded.mp4",
      width: parsed.width,
      height: parsed.height,
      fps: parsed.fps,
      hasAudio: parsed.hasAudio,
      lutCubeAbsPath: parsed.lutCubeAbsPath,
      gradeParams: parsed.gradeParams,
      videoCodecArgs: ["-c:v", "libx264"],
    });

    expect(args).toContain("-vf");
    expect(args.join(" ")).toContain("eq=");
    expect(args.join(" ")).toContain("lut3d=file='/tmp/looks/demo.cube':interp=tetrahedral");
  });
});
