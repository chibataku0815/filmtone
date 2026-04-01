/**
 * @fileoverview 写真まとめて書き出し専用パネル（トップタブ `photoExport` 用）
 *
 * @description `BatchTabPanel` に `exportSurface="images"` を固定して渡す薄いラッパー。
 *   ジョブ種別の二択 UI は出さず、フォルダ一括の流れだけを見せる（life#84）。
 */

import { BatchTabPanel, type BatchTabPanelProps } from "./BatchTabPanel";

/** @description 写真面へ渡す props（内部でジョブ種別変更は無効化する） */
export type PhotoExportPanelProps = Omit<
  BatchTabPanelProps,
  "exportSurface" | "onBatchJobModeChange"
>;

/**
 * @description 写真バッチ書き出し UI。`exportSurface` で動画向け入力を隠す。
 */
export function PhotoExportPanel(props: PhotoExportPanelProps) {
  return (
    <BatchTabPanel
      {...props}
      exportSurface="images"
      onBatchJobModeChange={() => {}}
    />
  );
}
