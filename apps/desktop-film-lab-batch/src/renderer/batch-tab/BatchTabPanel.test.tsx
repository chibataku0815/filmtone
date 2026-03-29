import { describe, expect, it } from "vitest";
import { renderToStaticMarkup } from "react-dom/server";

import { BatchTabPanel, type BatchTabPanelProps } from "./BatchTabPanel";

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
      renderToStaticMarkup(
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

  it("keeps the future fast copy approximate-only and leaves accurate as the default", () => {
    const html = withListLayout(() =>
      renderToStaticMarkup(
        <BatchTabPanel
          {...baseProps}
          showFastFfmpegVideoExportOption
        />,
      ),
    );

    expect(html).toContain("高速・近似オプションあり／詳細は手順内");
    expect(html).toContain("プレビュー一致（WebGL・低速・既定）");
    expect(html).not.toContain("高速書き出し（既定）");
  });
});
