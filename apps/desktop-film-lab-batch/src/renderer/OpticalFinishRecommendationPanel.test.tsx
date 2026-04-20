import type { ReactElement } from "react";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import jaMessages from "../../messages/ja.json";
import { OpticalFinishRecommendationPanel } from "./OpticalFinishRecommendationPanel";

function renderPanel(ui: ReactElement) {
  return renderToStaticMarkup(
    <NextIntlClientProvider
      locale="ja"
      messages={jaMessages}
      timeZone="Asia/Tokyo"
    >
      {ui}
    </NextIntlClientProvider>,
  );
}

describe("OpticalFinishRecommendationPanel", () => {
  it("renders analyzing state", () => {
    const html = renderPanel(
      <OpticalFinishRecommendationPanel
        analysis={{ state: "analyzing" }}
        onApply={() => {}}
        onRetry={() => {}}
      />,
    );

    expect(html).toContain("このクリップに合うおすすめ");
    expect(html).toContain("おすすめの仕上げを準備しています");
  });

  it("renders ready state with primary and alternates", () => {
    const html = renderPanel(
      <OpticalFinishRecommendationPanel
        analysis={{
          state: "ready",
          recommendation: {
            state: "ready",
            descriptor: {
              medianLuma: 0.4,
              highlightCoverage: 0.12,
              specularIslands: 0.5,
              pointLightScore: 0.2,
              globalContrast: 0.5,
              warmthScore: 0.7,
              portraitLikelihood: 0.2,
              nightScore: 0.2,
              sceneComplexity: 0.4,
              dominantShotCoverage: 0.9,
            },
            primary: {
              family: "glow",
              profile: "warm",
              recipe: "warmIndoor",
              confidence: "high",
              rationale: ["practicalLights"],
            },
            alternates: [
              {
                family: "mist",
                profile: "clean",
                recipe: null,
                confidence: "medium",
                rationale: ["portraitSafe"],
              },
            ],
          },
        }}
        appliedSelection={{
          family: "glow",
          recipe: "warmIndoor",
        }}
        onApply={() => {}}
        onRetry={() => {}}
      />,
    );

    expect(html).toContain("Glow");
    expect(html).toContain("室内のあたたかい光");
    expect(html).toContain("Mist");
    expect(html).toContain("適用済み");
  });

  it("renders low-confidence copy", () => {
    const html = renderPanel(
      <OpticalFinishRecommendationPanel
        analysis={{
          state: "low-confidence",
          recommendation: {
            state: "low-confidence",
            descriptor: {
              medianLuma: 0.3,
              highlightCoverage: 0.12,
              specularIslands: 0.6,
              pointLightScore: 0.8,
              globalContrast: 0.6,
              warmthScore: 0.4,
              portraitLikelihood: 0.2,
              nightScore: 0.6,
              sceneComplexity: 0.8,
              dominantShotCoverage: 0.3,
            },
            primary: {
              family: "mist",
              profile: "clean",
              recipe: null,
              confidence: "low",
              rationale: ["mixedScenes"],
            },
            alternates: [],
          },
        }}
        onApply={() => {}}
        onRetry={() => {}}
      />,
    );

    expect(html).toContain("迷ったときの出発点");
    expect(html).toContain("シーンが混在");
  });

  it("renders error state with retry action", () => {
    const html = renderPanel(
      <OpticalFinishRecommendationPanel
        analysis={{ state: "error", message: "decode failed" }}
        onApply={() => {}}
        onRetry={() => {}}
      />,
    );

    expect(html).toContain("おすすめを作れませんでした");
    expect(html).toContain("再試行");
    expect(html).toContain("decode failed");
  });

  it("renders debug info when provided", () => {
    const html = renderPanel(
      <OpticalFinishRecommendationPanel
        analysis={{ state: "analyzing" }}
        debugLog={["13:21:22 analysis requested"]}
        debugInfo={{
          effectState: "skipped",
          reason: "preview-not-ready",
          previewState: "starting",
          hasActiveVideo: false,
          interactiveSourceKind: "sample",
          smartLookDerived: false,
          absolutePath: null,
          sourcePath: null,
          currentSrc: null,
          activeSourcePath: null,
          durationSec: null,
          progressiveStage: "thumbnail",
          qualityLabel: "thumbnail",
          sourceUrlKind: "video-src",
          cacheKey: "sample::0.000::0.000::0.000::scene-aware-v1",
          analyzerVersion: "scene-aware-v1",
          activity: "waiting for preview to become ready",
          sampleCount: null,
          updatedAtIso: "2026-04-20T12:00:00.000Z",
        }}
        onApply={() => {}}
        onRetry={() => {}}
      />,
    );

    expect(html).toContain("状態を確認する");
    expect(html).toContain("preview-not-ready");
    expect(html).toContain("scene-aware-v1");
    expect(html).toContain("現在:");
    expect(html).toContain("イベント履歴");
  });
});
