import { describe, expect, it } from "vitest";
import {
  shouldRetryWithSeekAfterWebCodecsRuntimeFailure,
  needsDesktopPreviewTranscode,
  needsMezzanineTranscode,
} from "./video-export-pipeline";

describe("video-export-pipeline", () => {
  it("shouldRetryWithSeekAfterWebCodecsRuntimeFailure は WebCodecs 由来の実行時失敗だけを拾う", () => {
    expect(
      shouldRetryWithSeekAfterWebCodecsRuntimeFailure(
        "WebCodecsMp4ExportSession.ensureDecoderFedForTarget: デコーダが応答しません",
      ),
    ).toBe(true);
    expect(
      shouldRetryWithSeekAfterWebCodecsRuntimeFailure(
        "VideoDecoder.decode 失敗: codec error",
      ),
    ).toBe(true);
    expect(
      shouldRetryWithSeekAfterWebCodecsRuntimeFailure(
        "drawHolderToCanvas: VideoFrame がありません（デコード不足）",
      ),
    ).toBe(true);
    expect(
      shouldRetryWithSeekAfterWebCodecsRuntimeFailure("ffmpeg 失敗 code=1"),
    ).toBe(false);
    expect(
      shouldRetryWithSeekAfterWebCodecsRuntimeFailure(
        "video-export-write-frame: stdin write/drain 失敗",
      ),
    ).toBe(false);
  });
});

describe("needsMezzanineTranscode", () => {
  const opts = (codec: string, size = 200 * 1024 * 1024) => ({
    videoCodec: codec,
    fileSizeBytes: size,
    absPath: "/tmp/test.mov",
  });

  it("H.264 → false (WebCodecs が処理)", () => {
    expect(needsMezzanineTranscode(opts("h264"))).toBe(false);
  });

  it("AVC → false", () => {
    expect(needsMezzanineTranscode(opts("avc"))).toBe(false);
  });

  it("ProRes → true (Chromium は ProRes デコード不可)", () => {
    expect(needsMezzanineTranscode(opts("prores"))).toBe(true);
  });

  it("HEVC → true", () => {
    expect(needsMezzanineTranscode(opts("hevc"))).toBe(true);
  });

  it("VP9 → true", () => {
    expect(needsMezzanineTranscode(opts("vp9"))).toBe(true);
  });

  it("AV1 → true", () => {
    expect(needsMezzanineTranscode(opts("av1"))).toBe(true);
  });

  it("unknown codec → true", () => {
    expect(needsMezzanineTranscode(opts("rawvideo"))).toBe(true);
  });
});

describe("needsDesktopPreviewTranscode", () => {
  const opts = (codec: string, absPath: string) => ({
    videoCodec: codec,
    fileSizeBytes: 200 * 1024 * 1024,
    absPath,
  });

  it("H.264 MP4 はブラウザ直読みのままにする", () => {
    expect(needsDesktopPreviewTranscode(opts("h264", "/tmp/test.mp4"))).toBe(
      false,
    );
  });

  it("H.264 MOV は Chromium preview の失敗を避けるため progressive load に回す", () => {
    expect(needsDesktopPreviewTranscode(opts("h264", "/tmp/test.mov"))).toBe(
      true,
    );
  });

  it("AVC QuickTime と H.264 Matroska も progressive load に回す", () => {
    expect(needsDesktopPreviewTranscode(opts("avc", "/tmp/test.qt"))).toBe(true);
    expect(needsDesktopPreviewTranscode(opts("h264", "/tmp/test.mkv"))).toBe(
      true,
    );
  });

  it("非対応 codec は container に関係なく progressive load に回す", () => {
    expect(needsDesktopPreviewTranscode(opts("hevc", "/tmp/test.mp4"))).toBe(
      true,
    );
  });
});
