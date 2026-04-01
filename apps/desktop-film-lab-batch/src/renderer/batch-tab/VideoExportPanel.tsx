/**
 * @fileoverview 動画 1 本書き出し専用パネル（トップタブ `videoExport` 用）
 *
 * @description `BatchTabPanel` に `exportSurface="video"` を固定して渡す薄いラッパー。
 *   写真フォルダ一括の説明や入力は出さない（life#84）。
 */

import { BatchTabPanel, type BatchTabPanelProps } from "./BatchTabPanel";

/** @description 動画面へ渡す props */
export type VideoExportPanelProps = Omit<
  BatchTabPanelProps,
  "exportSurface" | "onBatchJobModeChange"
>;

/**
 * @description 単一動画の書き出し UI。
 */
export function VideoExportPanel(props: VideoExportPanelProps) {
  return (
    <BatchTabPanel
      {...props}
      exportSurface="video"
      onBatchJobModeChange={() => {}}
    />
  );
}
