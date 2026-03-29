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
  editToExportSyncedAtMs: null,
  onReapplyBatchPresetBaseline: () => {},
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

/**
 * @description 一覧レイアウトに加え、「次にやること」帯の localStorage を上書きしてテストする
 * @param nextStripExpanded - false なら一行チップ（折りたたみ）の既定を再現
 */
function withListLayoutAndNextStripExpanded<T>(
  nextStripExpanded: boolean,
  fn: () => T,
): T {
  const original = globalThis.localStorage;
  const localStorageMock = {
    getItem: (key: string) => {
      if (key === "filmLab.export.stepLayoutPref") return "list";
      if (key === "filmLab.export.nextStripExpanded") {
        return nextStripExpanded ? "1" : "0";
      }
      return null;
    },
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
  it("uses WebGL-only video copy and no fast-ffmpeg checkbox when fast export is disabled", () => {
    const html = withListLayout(() =>
      renderBatchPanel(
        <BatchTabPanel {...baseProps} showFastFfmpegVideoExportOption={false} />,
      ),
    );

    expect(html).toContain("編集に近い見え方で MP4／手順内で保存先を設定");
    expect(html).toContain("動画は編集タブに近い見え方で書き出します。");
    expect(html).toContain(
      "1 フレームずつ処理するため、長いクリップは完了まで時間がかかることがあります。",
    );
    expect(html).not.toContain("高速 ffmpeg");
    expect(html).not.toContain("速く書き出す");
  });

  it("next-step strip is expanded by default and offers collapse control", () => {
    const html = withListLayout(() => renderBatchPanel(<BatchTabPanel {...baseProps} />));

    expect(html).toContain("たたむ");
  });

  it("next-step strip reads collapsed preference from localStorage (one-line chip + expand)", () => {
    const html = withListLayoutAndNextStripExpanded(false, () =>
      renderBatchPanel(<BatchTabPanel {...baseProps} />),
    );

    expect(html).toContain("開く");
    expect(html).not.toContain("たたむ");
    expect(html).toContain("実行で動画を書き出す");
  });

  it("look step shows edit-synced banner when editToExportSyncedAtMs is set", () => {
    const html = withListLayout(() =>
      renderBatchPanel(
        <BatchTabPanel
          {...baseProps}
          editToExportSyncedAtMs={1_700_000_000_000}
        />,
      ),
    );

    expect(html).toContain("編集タブのスライダーどおり（反映済み）");
    expect(html).toContain("に編集から取り込みました");
    expect(html).toContain("プリセットの数値に戻す");
    expect(html).not.toContain("data-testid=\"export-preset-select\"");
  });
});
