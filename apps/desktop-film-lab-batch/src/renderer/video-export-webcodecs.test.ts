import { describe, expect, it } from "vitest";
import {
  WEBCODECS_ACC_EXPORT_MAX_FILE_BYTES,
  isMp4LikeContainerForWebCodecs,
  shouldAttemptWebCodecsAccurateExport,
} from "./video-export-webcodecs";

describe("video-export-webcodecs", () => {
  it("isMp4LikeContainerForWebCodecs は mp4/m4v/mov を認める", () => {
    expect(isMp4LikeContainerForWebCodecs("/a/B.MP4")).toBe(true);
    expect(isMp4LikeContainerForWebCodecs("C:\\x\\y.m4v")).toBe(true);
    expect(isMp4LikeContainerForWebCodecs("/z/foo.mov")).toBe(true);
    expect(isMp4LikeContainerForWebCodecs("/nope.mkv")).toBe(false);
  });

  it("shouldAttemptWebCodecsAccurateExport は拡張子・codec・サイズを見る", () => {
    const base = {
      videoCodec: "h264",
      fileSizeBytes: 1024,
      absPath: "/tmp/a.mp4",
    };
    expect(shouldAttemptWebCodecsAccurateExport(base)).toBe(
      typeof VideoDecoder === "function",
    );

    expect(
      shouldAttemptWebCodecsAccurateExport({
        ...base,
        absPath: "/tmp/a.mkv",
      }),
    ).toBe(false);

    expect(
      shouldAttemptWebCodecsAccurateExport({
        ...base,
        fileSizeBytes: WEBCODECS_ACC_EXPORT_MAX_FILE_BYTES + 1,
      }),
    ).toBe(false);

    expect(
      shouldAttemptWebCodecsAccurateExport({
        ...base,
        videoCodec: "hevc",
      }),
    ).toBe(false);
  });
});
