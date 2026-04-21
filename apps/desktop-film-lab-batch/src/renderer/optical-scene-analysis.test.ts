import { describe, expect, it } from "vitest";

import {
  OPTICAL_ANALYZER_VERSION,
  createSceneAnalysisCacheKey,
  resolveSceneAnalysisSourceUrl,
} from "./optical-scene-analysis";

describe("createSceneAnalysisCacheKey", () => {
  it("invalidates on source swap, trim change, and analyzer version bump", () => {
    const base = createSceneAnalysisCacheKey({
      sourcePath: "/clips/a.mov",
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
      analyzerVersion: OPTICAL_ANALYZER_VERSION,
    });

    const sourceSwap = createSceneAnalysisCacheKey({
      sourcePath: "/clips/b.mov",
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
      analyzerVersion: OPTICAL_ANALYZER_VERSION,
    });
    const trimChange = createSceneAnalysisCacheKey({
      sourcePath: "/clips/a.mov",
      trimStartSec: 1,
      trimEndSec: 12,
      sourceDurationSec: 24,
      analyzerVersion: OPTICAL_ANALYZER_VERSION,
    });
    const versionBump = createSceneAnalysisCacheKey({
      sourcePath: "/clips/a.mov",
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
      analyzerVersion: `${OPTICAL_ANALYZER_VERSION}-next`,
    });

    expect(sourceSwap).not.toBe(base);
    expect(trimChange).not.toBe(base);
    expect(versionBump).not.toBe(base);
  });
});

describe("resolveSceneAnalysisSourceUrl", () => {
  it("prefers a film-lab-video:// sourceUrl (mezzanine) over an absolute source path", () => {
    const mezzanineUrl =
      "film-lab-video://local/?path=%2Fvar%2Ffolders%2Ft3%2Ffilm-lab-mezzanine-abc.mp4";
    const result = resolveSceneAnalysisSourceUrl({
      sourcePath: "/Users/me/Downloads/raw.mov",
      sourceUrl: mezzanineUrl,
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
    });

    expect(result.sourceUrlKind).toBe("provided-url");
    expect(result.sourceUrl).toBe(mezzanineUrl);
  });

  it("falls back to the desktop video protocol derived from the absolute path when no mezzanine URL is provided", () => {
    const result = resolveSceneAnalysisSourceUrl({
      sourcePath: "/clips/a.mov",
      sourceUrl: "blob:http://127.0.0.1:5173/example",
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
    });

    expect(result.sourceUrlKind).toBe("video-src");
    expect(result.sourceUrl.startsWith("film-lab-video://")).toBe(true);
  });

  it("falls back to the provided preview URL for non-file source paths", () => {
    const result = resolveSceneAnalysisSourceUrl({
      sourcePath: "blob:http://127.0.0.1:5173/example",
      sourceUrl: "blob:http://127.0.0.1:5173/example",
      trimStartSec: 0,
      trimEndSec: 12,
      sourceDurationSec: 24,
    });

    expect(result.sourceUrlKind).toBe("provided-url");
    expect(result.sourceUrl).toBe("blob:http://127.0.0.1:5173/example");
  });
});
