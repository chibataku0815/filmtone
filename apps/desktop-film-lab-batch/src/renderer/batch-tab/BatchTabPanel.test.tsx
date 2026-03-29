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
  videoExportWebglAccurate: true,
  onVideoExportWebglAccurateChange: () => {},
  showFastFfmpegVideoExportOption: false,
  videoExportSuccessNonce: 0,
  canApplyEditGradeToBatch: false,
  onApplyEditGradeToBatch: () => {},
};

function withListLayout<T>(fn: () => T): T {
  const original = globalThis.localStorage;
  const localStorageMock = {
    getItem: (key: string) =>
      key === "filmLab.export.stepLayoutPref" ? "list" : null,
    setItem: () => {},
  } as Storage;
  Object.defineProperty(globalThis, "localStorage", {
    configurable: true,
    value: localStorageMock,
  });
  try {
    return fn();
  } finally {
    Object.defineProperty(globalThis, "localStorage", {
      configurable: true,
      value: original,
    });
  }
}

describe("BatchTabPanel video export copy", () => {
  it("shows WebGL-only copy and hides the fast checkbox when fast export is disabled", () => {
    const html = withListLayout(() =>
      renderBatchPanel(
        <BatchTabPanel
          {...baseProps}
          showFastFfmpegVideoExportOption={false}
        />,
      ),
    );

    expect(html).toContain("WebGL 書き出しのみ（低速）／詳細は手順内");
    expect(html).toContain("高速トランスコードは準備中です。");
    expect(html).not.toContain("プレビュー一致（WebGL・低速・既定）");
  });

  it("when fast export is enabled, summarizes fast-as-default and optional WebGL accurate", () => {
    const html = withListLayout(() =>
      renderBatchPanel(
        <BatchTabPanel
          {...baseProps}
          showFastFfmpegVideoExportOption
        />,
      ),
    );

    expect(html).toContain("既定は高速 ffmpeg（近似）／プレビュー一致はオプション");
    expect(html).toContain("プレビュー一致（WebGL・低速）");
    expect(html).toContain("高速 ffmpeg（既定・近似）");
  });
});
