import { describe, expect, it } from "vitest";
import {
  computeDecodeUpperBoundUs,
  estimateNominalFrameDurationUs,
  hasSatisfiedSelectionByBufferedFrames,
  isPrefetchBudgetDominatedByPendingDecodes,
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

  it("estimateNominalFrameDurationUs は probe から frame 時間の rough hint を作る", () => {
    expect(
      estimateNominalFrameDurationUs({
        durationSec: 10,
        nbSamples: 300,
      }),
    ).toBe(33333);

    expect(
      estimateNominalFrameDurationUs({
        durationSec: 0,
        nbSamples: 0,
      }),
    ).toBe(Math.round(1_000_000 / 30));
  });

  it("computeDecodeUpperBoundUs は warmup と平常時で future 側の幅を変える", () => {
    expect(
      computeDecodeUpperBoundUs({
        targetUs: 1_000_000,
        frameDurationUs: 40_000,
        hasSatisfiedSelection: false,
      }),
    ).toBe(1_000_000 + 40_000 * 30);

    expect(
      computeDecodeUpperBoundUs({
        targetUs: 1_000_000,
        frameDurationUs: 40_000,
        hasSatisfiedSelection: true,
      }),
    ).toBe(1_000_000 + 40_000 * 11);
  });

  it("hasSatisfiedSelectionByBufferedFrames は holder だけでは satisfied にしない", () => {
    expect(
      hasSatisfiedSelectionByBufferedFrames({
        targetUs: 0,
        holderUs: 0,
        nextOutputUs: null,
        flushCompleted: false,
      }),
    ).toBe(false);

    expect(
      hasSatisfiedSelectionByBufferedFrames({
        targetUs: 0,
        holderUs: 0,
        nextOutputUs: 33_367,
        flushCompleted: false,
      }),
    ).toBe(true);

    expect(
      hasSatisfiedSelectionByBufferedFrames({
        targetUs: 1_000_000,
        holderUs: 1_033_000,
        nextOutputUs: null,
        flushCompleted: false,
      }),
    ).toBe(true);
  });

  it("isPrefetchBudgetDominatedByPendingDecodes は usable output が薄い pending 主導だけを拾う", () => {
    expect(
      isPrefetchBudgetDominatedByPendingDecodes({
        bufferedFrameBudgetCount: 16,
        outputQueueLength: 1,
        pendingDecodes: 15,
        steadyLeadFrames: 11,
        resumeThresholdFrames: 6,
      }),
    ).toBe(true);

    expect(
      isPrefetchBudgetDominatedByPendingDecodes({
        bufferedFrameBudgetCount: 16,
        outputQueueLength: 6,
        pendingDecodes: 10,
        steadyLeadFrames: 11,
        resumeThresholdFrames: 6,
      }),
    ).toBe(false);

    expect(
      isPrefetchBudgetDominatedByPendingDecodes({
        bufferedFrameBudgetCount: 10,
        outputQueueLength: 1,
        pendingDecodes: 9,
        steadyLeadFrames: 11,
        resumeThresholdFrames: 6,
      }),
    ).toBe(false);
  });
});
