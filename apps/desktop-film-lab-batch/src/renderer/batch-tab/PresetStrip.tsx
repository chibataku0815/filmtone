/**
 * @fileoverview Export preset strip（画面最上部の横 1 行タイル帯）
 *
 * @description
 * 4 製品研究（Lightroom / Capture One / Apple Photos / DaVinci Deliver）の共通則から、
 * DaVinci Deliver 型の preset strip を採用。1 クリックで典型ケースを終わらせる入り口。
 * v1 スコープでは photo 形式（JPEG / PNG）と suffix のみを preset 化。
 * video は現状 preset 化できるパラメータが無いため「標準」タイルのみ（将来の codec / bitrate 拡張用スロット）。
 *
 * @limitations
 * - amber は active タイルに使わない（rulebook R4.1、primary CTA 専用）
 * - アクティブ表現は background + border 濃度のみ
 */

import { useTranslations } from "next-intl";
import type { BatchFormat } from "../batch-pipeline";

/** @description photo preset の定義（format + suffix の組） */
type PhotoPreset = {
  id: string;
  labelKey: string;
  format: BatchFormat;
  suffix: string;
};

const PHOTO_PRESETS: PhotoPreset[] = [
  { id: "web-jpeg", labelKey: "presetPhotoWebJpeg", format: "jpeg", suffix: "-web" },
  { id: "master-jpeg", labelKey: "presetPhotoMasterJpeg", format: "jpeg", suffix: "-graded" },
  { id: "archive-png", labelKey: "presetPhotoArchivePng", format: "png", suffix: "-graded" },
];

export type PresetStripProps = {
  /** @description photo / video どちらの面か */
  isImagesMode: boolean;
  /** @description 現在の photo 出力形式 */
  batchFormat: BatchFormat;
  /** @description 現在の photo 出力接尾辞 */
  batchOutputSuffix: string;
  /** @description photo 形式切替ハンドラ */
  onBatchFormatChange: (format: BatchFormat) => void;
  /** @description photo 接尾辞切替ハンドラ */
  onBatchOutputSuffixChange: (suffix: string) => void;
  /** @description true なら実行中（クリック無効） */
  disabled: boolean;
};

/**
 * @description 画面最上部に 1 行で並ぶ preset タイル帯。
 * photo はタイル 3 つ + Custom、video は「標準」単独（v2 で codec 拡張）。
 */
export function PresetStrip(props: PresetStripProps) {
  const {
    isImagesMode,
    batchFormat,
    batchOutputSuffix,
    onBatchFormatChange,
    onBatchOutputSuffixChange,
    disabled,
  } = props;
  const t = useTranslations("film-lab.desktop.batch");

  if (!isImagesMode) {
    /* 動画面は preset 化できるパラメータが現状無いので 1 タイルのみ（v2 拡張 slot） */
    return (
      <div
        className="flex items-center gap-2 overflow-x-auto"
        role="group"
        aria-label={t("presetStripAria")}
      >
        <div className="fl-preset-tile fl-preset-tile--active" aria-current="true">
          <span className="fl-preset-tile-label">{t("presetVideoDefault")}</span>
        </div>
      </div>
    );
  }

  /* photo 面 — タイル 3 つ + Custom */
  const activePreset = PHOTO_PRESETS.find(
    (p) => p.format === batchFormat && p.suffix === batchOutputSuffix,
  );
  const isCustom = activePreset == null;

  const onTileClick = (preset: PhotoPreset) => {
    if (disabled) return;
    onBatchFormatChange(preset.format);
    onBatchOutputSuffixChange(preset.suffix);
  };

  return (
    <div
      className="flex items-center gap-2 overflow-x-auto"
      role="group"
      aria-label={t("presetStripAria")}
    >
      {PHOTO_PRESETS.map((preset) => {
        const isActive = activePreset?.id === preset.id;
        return (
          <button
            key={preset.id}
            type="button"
            className={`fl-preset-tile ${isActive ? "fl-preset-tile--active" : ""}`}
            aria-current={isActive ? "true" : undefined}
            disabled={disabled}
            onClick={() => onTileClick(preset)}
          >
            <span className="fl-preset-tile-label">{t(preset.labelKey)}</span>
          </button>
        );
      })}
      <div
        className={`fl-preset-tile ${isCustom ? "fl-preset-tile--active" : "fl-preset-tile--passive"}`}
        aria-current={isCustom ? "true" : undefined}
      >
        <span className="fl-preset-tile-label">{t("presetCustom")}</span>
      </div>
    </div>
  );
}
