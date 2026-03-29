import { describe, expect, it } from "vitest";
import { shouldRetryWithSeekAfterWebCodecsRuntimeFailure } from "./video-export-pipeline";

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
