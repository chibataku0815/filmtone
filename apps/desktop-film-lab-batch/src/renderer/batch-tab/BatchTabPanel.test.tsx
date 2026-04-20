import type { ReactElement } from "react";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import jaMessages from "../../../messages/ja.json";
import enMessages from "../../../messages/en.json";
import { BatchTabPanel, type BatchTabPanelProps } from "./BatchTabPanel";

function renderBatchPanel(ui: ReactElement) {
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

const baseProps: BatchTabPanelProps = {
  batchJobMode: "video",
  onBatchJobModeChange: () => {},
  persistedSession: null,
  batchCanResume: false,
  running: false,
  onResumeBatch: async () => {},
  onDiscardPersistedSession: async () => {},
  proxyCacheInfo: {
    entryCount: 2,
    totalBytes: 3145728,
    maxEntries: 8,
    maxTotalBytes: 2147483648,
    maxAgeDays: 14,
  },
  isPurgingProxyCache: false,
  onPurgeProxyCache: async () => {},
  batchPresetChoice: "cinematic",
  batchLookSource: "preset",
  appliedOpticalRecommendation: null,
  onBatchPresetChoiceChange: () => {},
  importedGradeLabel: null,
  onImportGradeJson: async () => {},
  onExportGradeJson: () => {},
  inputDir: null,
  outputDir: null,
  onPickInputDir: async () => {},
  onPickOutputDir: async () => {},
  batchFormat: "jpeg",
  onBatchFormatChange: () => {},
  batchOutputSuffix: "-graded",
  onBatchOutputSuffixChange: () => {},
  batchCanRun: false,
  batchCanRetryFailed: false,
  onRunBatch: async () => {},
  onRetryFailedBatch: async () => {},
  onAbortBatch: () => {},
  batchProgress: null,
  lastBatchSummary: null,
  videoInputPath: "/tmp/input/clip.mov",
  videoProbeLabel: "1280x720 / 3.0s",
  videoCanExport: true,
  onPickVideoFile: async () => {},
  onRunVideoExport: async () => {},
  videoExportSuccessNonce: 0,
  canApplyEditGradeToBatch: false,
  onApplyEditGradeToBatch: () => {},
  editToExportSyncedAtMs: null,
  onReapplyBatchPresetBaseline: () => {},
};

describe("BatchTabPanel glass-unified layout (2026-04-19)", () => {
  it("renders accordion section ids without wizard navigation", () => {
    const html = renderBatchPanel(<BatchTabPanel {...baseProps} />);

    // job selector + accordion の 3 セクション + run フッター
    expect(html).toContain("export-job-selector-heading");
    expect(html).toContain("export-step-sources");
    expect(html).toContain("export-step-look");
    expect(html).toContain("export-step-output");
    expect(html).toContain("export-run-heading");

    // wizard は存在しない（前仕様を踏襲）
    expect(html).not.toContain("wizardBack");
    expect(html).not.toContain("wizardNext");
  });

  it("keeps WebGL-only video copy and drops fast-ffmpeg references", () => {
    const html = renderBatchPanel(<BatchTabPanel {...baseProps} />);

    // 新 IA: header の exportLeadVideo で「編集タブに近い見え方の MP4」が出る
    expect(html).toContain("編集タブに近い見え方の MP4");
    // 旧高速経路 UI は残っていない
    expect(html).not.toContain("高速 ffmpeg");
    expect(html).not.toContain("速く書き出す");
  });

  it("look section shows synced summary in collapsed header when editToExportSyncedAtMs is set", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchLookSource="editSync"
        editToExportSyncedAtMs={1_700_000_000_000}
      />,
    );

    // collapsed header に synced status title が出る
    expect(html).toContain("ルック: 編集タブと一致");
    // body が閉じているので preset select は出ない
    expect(html).not.toContain("data-testid=\"export-preset-select\"");
  });

  it("shows synced badge on look section when edit-synced", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchLookSource="editSync"
        editToExportSyncedAtMs={1_700_000_000_000}
      />,
    );

    expect(html).toContain("synced");
  });

  it("shows recommendation summary and hides preset select when analysis recommendation is active", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchLookSource="analysisRecommendation"
        appliedOpticalRecommendation={{
          family: "glow",
          profile: "warm",
          recipe: "warmIndoor",
          analyzerVersion: "scene-aware-v1",
          appliedAtIso: "2026-04-20T09:00:00.000Z",
        }}
      />,
    );

    expect(html).toContain("Glow");
    expect(html).toContain("室内のあたたかい光");
    expect(html).not.toContain("data-testid=\"export-preset-select\"");
  });

  it("renders the visible Metadata JSON restore action inside look section", () => {
    const html = renderBatchPanel(<BatchTabPanel {...baseProps} />);

    expect(html).toContain("Metadata JSON を読み込む");
  });

  it("shows preset look status for preset-based metadata restores", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        importedGradeLabel="/tmp/filmtone-export-session.json"
        batchLookSource="preset"
      />,
    );

    expect(html).toContain("ルック: プリセット「cinematic」");
    expect(html).not.toContain("ルック: JSON");
  });

  it("collapses sources section when video input is already set", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        videoInputPath="/tmp/input/clip.mov"
      />,
    );

    // sources header に折りたたみ summary (filename) が出る
    expect(html).toContain("clip.mov");
    // 閉じているので accordion の aria-expanded=false が少なくとも 1 つ存在
    expect(html).toContain("aria-expanded=\"false\"");
  });

  it("places proxy cache inside Advanced disclosure (glass-unified: no solid black card at top level)", () => {
    const videoHtml = renderBatchPanel(<BatchTabPanel {...baseProps} />);
    const imageHtml = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchJobMode="images"
        inputDir="/tmp/input"
        outputDir="/tmp/output"
        videoInputPath={null}
      />,
    );

    // Advanced disclosure（詳細設定）が両モードで存在
    expect(videoHtml).toContain("詳細設定");
    expect(imageHtml).toContain("詳細設定");
    // proxy cache テキストは native <details> 内に残る（renderToStaticMarkup は DOM を含むため可視性とは独立）
    expect(videoHtml).toContain("プロキシキャッシュ");
    expect(videoHtml).toContain("プロキシキャッシュを消す");
    expect(videoHtml).toContain("2 件");
    expect(imageHtml).toContain("プロキシキャッシュ");
    expect(imageHtml).toContain("プロキシキャッシュを消す");
  });

  it("renders a preset strip at the top (DaVinci-type)", () => {
    const imageHtml = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchJobMode="images"
        videoInputPath={null}
      />,
    );

    // 写真面には preset tile が 3 つ + Custom が並ぶ
    expect(imageHtml).toContain("Web JPEG");
    expect(imageHtml).toContain("Master JPEG");
    expect(imageHtml).toContain("Archive PNG");
    expect(imageHtml).toContain("カスタム");
  });

  it("eliminates solid black card inline styles (rulebook R1.4)", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        batchJobMode="images"
        videoInputPath={null}
      />,
    );

    // 旧 solid black 左アクセント（amber/blue inset shadow）は撤廃
    expect(html).not.toContain("shadow-[inset_3px_0_0_0_var(--amber-9)]");
    expect(html).not.toContain("shadow-[inset_3px_0_0_0_var(--blue-9)]");
  });

  it("keeps ja.json and en.json key sets in sync", () => {
    const flatten = (
      obj: Record<string, unknown>,
      prefix = "",
    ): Set<string> => {
      const out = new Set<string>();
      for (const [key, value] of Object.entries(obj)) {
        const path = prefix ? `${prefix}.${key}` : key;
        if (
          value != null &&
          typeof value === "object" &&
          !Array.isArray(value)
        ) {
          for (const inner of flatten(value as Record<string, unknown>, path)) {
            out.add(inner);
          }
        } else {
          out.add(path);
        }
      }
      return out;
    };

    const jaKeys = flatten(jaMessages as Record<string, unknown>);
    const enKeys = flatten(enMessages as Record<string, unknown>);

    const onlyInJa = [...jaKeys].filter((k) => !enKeys.has(k)).sort();
    const onlyInEn = [...enKeys].filter((k) => !jaKeys.has(k)).sort();

    expect(onlyInJa).toEqual([]);
    expect(onlyInEn).toEqual([]);
  });
});
