import type { ReactElement } from "react";
import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";
import { NextIntlClientProvider } from "next-intl";

import jaMessages from "../../../messages/ja.json";
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
  batchPresetChoice: "cinematic",
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

describe("BatchTabPanel accordion layout", () => {
  it("renders all 5 sections without wizard navigation", () => {
    const html = renderBatchPanel(<BatchTabPanel {...baseProps} />);

    // ジョブ種別はアコーディオン外のセクション、手順は sources / look / output
    expect(html).toContain("export-job-selector-heading");
    expect(html).toContain("export-step-sources");
    expect(html).toContain("export-step-look");
    expect(html).toContain("export-step-output");

    // Run section always visible
    expect(html).toContain("export-run-heading");

    // No wizard artifacts
    expect(html).not.toContain("wizardBack");
    expect(html).not.toContain("wizardNext");
  });

  it("uses WebGL-only video copy with no fast-ffmpeg references", () => {
    const html = renderBatchPanel(<BatchTabPanel {...baseProps} />);

    expect(html).toContain("編集に近い見え方で MP4／手順内で保存先を設定");
    expect(html).toContain("動画は編集タブに近い見え方で書き出します。");
    expect(html).toContain(
      "1 フレームずつ処理するため、長いクリップは完了まで時間がかかることがあります。",
    );
    expect(html).not.toContain("高速 ffmpeg");
    expect(html).not.toContain("速く書き出す");
  });

  it("look section shows synced summary in collapsed header when editToExportSyncedAtMs is set", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        editToExportSyncedAtMs={1_700_000_000_000}
      />,
    );

    // Collapsed header shows the synced status title
    expect(html).toContain("ルック: 編集タブと一致");
    // Body is hidden when collapsed — preset select should not appear
    expect(html).not.toContain("data-testid=\"export-preset-select\"");
  });

  it("shows synced badge on look section when edit-synced", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        editToExportSyncedAtMs={1_700_000_000_000}
      />,
    );

    expect(html).toContain("synced");
  });

  it("collapses sources section when video input is already set", () => {
    const html = renderBatchPanel(
      <BatchTabPanel
        {...baseProps}
        videoInputPath="/tmp/input/clip.mov"
      />,
    );

    // Sources header should show collapsed summary (filename)
    expect(html).toContain("clip.mov");
    // The section body should not be expanded (aria-expanded=false)
    expect(html).toContain("aria-expanded=\"false\"");
  });
});
