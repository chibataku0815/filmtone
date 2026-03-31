/**
 * @fileoverview Film Lab デスクトップの「書き出し」タブ用パネル
 *
 * @description
 * 5 セクション（ジョブ種別 / 入力 / ルック / 出力 / 実行）をアコーディオン形式で配置。
 * 編集タブから同期済みのセクションは折りたたみ、ユーザーは必要なセクションだけ開いて設定する。
 * 実行セクションは常時表示で、未設定の項目があればバリデーションメッセージを表示する。
 */

import {
  CaretDown,
  CaretUp,
  CheckCircle,
  Circle,
  File,
  WarningCircle,
} from "@phosphor-icons/react";
import { useMemo, useState, type ReactElement } from "react";
import { useLocale, useTranslations } from "next-intl";
import { PRESETS, type PresetName } from "film-lab-core";
import {
  pathsNotSucceeded,
  sessionHasRemainingWork,
  type FilmLabBatchSessionV1,
} from "../batch-session";
import type { BatchFormat } from "../batch-pipeline";
import {
  VIDEO_EXPORT_FPS,
  VIDEO_IMPORT_MAX_DURATION_SEC,
} from "../video-export-constants";
import { HelpHint } from "./HelpHint";

/** @description 書き出しタブで扱うジョブの大分類（フォルダの写真まとめて vs 動画 1 本） */
export type BatchJobMode = "images" | "video";

const PRESET_NAMES = Object.keys(PRESETS) as PresetName[];

/** @description ステップ識別子 */
type BatchStepId = "jobType" | "sources" | "look" | "output" | "run";

/** @description アコーディオン内で折りたたみ可能な 4 セクション（run は常時表示） */
type AccordionStepId = Exclude<BatchStepId, "run">;

const ACCORDION_STEPS: AccordionStepId[] = [
  "jobType",
  "sources",
  "look",
  "output",
];

/**
 * @description パスの末尾セグメントを取得（折りたたみヘッダーのサマリ表示用）
 */
function lastPathSegment(p: string): string {
  const parts = p.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] || p;
}

/**
 * @description 入力・出力がステップの前提を満たしているか（ステータスチップ用）
 */
function getSourceOutputStatus(
  mode: BatchJobMode,
  inputDir: string | null,
  outputDir: string | null,
  videoInputPath: string | null,
): { sourceOk: boolean; outputOk: boolean } {
  if (mode === "images") {
    return { sourceOk: Boolean(inputDir), outputOk: Boolean(outputDir) };
  }
  return {
    sourceOk: Boolean(videoInputPath),
    outputOk: Boolean(outputDir),
  };
}

/**
 * @description ステップ 1（入力）が完了とみなせるか
 */
function isSourcesStepComplete(
  mode: BatchJobMode,
  inputDir: string | null,
  videoInputPath: string | null,
): boolean {
  if (mode === "images") return Boolean(inputDir);
  return Boolean(videoInputPath);
}

/**
 * @description ステップ 4（出力）が完了とみなせるか
 */
function isOutputStepComplete(
  mode: BatchJobMode,
  outputDir: string | null,
): boolean {
  if (mode === "images") return Boolean(outputDir);
  return true;
}

/**
 * @description BatchTabPanel が親から受け取る props（イベントはすべて App のハンドラに委譲）
 */
export type BatchTabPanelProps = {
  /** @description フォルダの写真まとめて / 動画 1 本のどちらを主導線にするか */
  batchJobMode: BatchJobMode;
  /** @description ジョブ種別変更時。種類が変わったらステップを先頭に戻す */
  onBatchJobModeChange: (mode: BatchJobMode) => void;

  persistedSession: FilmLabBatchSessionV1 | null;
  batchCanResume: boolean;
  running: boolean;
  onResumeBatch: () => void | Promise<void>;
  onDiscardPersistedSession: () => void | Promise<void>;

  batchPresetChoice: PresetName;
  onBatchPresetChoiceChange: (name: PresetName) => void;
  importedGradeLabel: string | null;
  onImportGradeJson: () => void | Promise<void>;
  onExportGradeJson: () => void;

  inputDir: string | null;
  outputDir: string | null;
  onPickInputDir: () => void | Promise<void>;
  onPickOutputDir: () => void | Promise<void>;

  batchFormat: BatchFormat;
  onBatchFormatChange: (format: BatchFormat) => void;
  batchOutputSuffix: string;
  onBatchOutputSuffixChange: (suffix: string) => void;

  batchCanRun: boolean;
  batchCanRetryFailed: boolean;
  onRunBatch: () => void | Promise<void>;
  onRetryFailedBatch: () => void | Promise<void>;
  onAbortBatch: () => void;

  batchProgress: {
    current: number;
    total: number;
    fileName: string;
  } | null;
  lastBatchSummary: {
    ok: number;
    loadFail: number;
    writeFail: number;
  } | null;

  videoInputPath: string | null;
  videoProbeLabel: string | null;
  videoCanExport: boolean;
  onPickVideoFile: () => void | Promise<void>;
  onRunVideoExport: () => void | Promise<void>;

  videoExportSuccessNonce: number;

  canApplyEditGradeToBatch: boolean;
  onApplyEditGradeToBatch: () => void;
  editToExportSyncedAtMs: number | null;
  onReapplyBatchPresetBaseline: () => void;
  /** @description true when rendered inside the right slide panel (compact layout) */
  compact?: boolean;
};

/**
 * @description 書き出しタブのメインパネル（アコーディオン直接アクセス方式）
 */
export function BatchTabPanel(props: BatchTabPanelProps) {
  const {
    batchJobMode,
    onBatchJobModeChange,
    persistedSession,
    batchCanResume,
    running,
    onResumeBatch,
    onDiscardPersistedSession,
    batchPresetChoice,
    onBatchPresetChoiceChange,
    importedGradeLabel,
    onImportGradeJson,
    onExportGradeJson,
    inputDir,
    outputDir,
    onPickInputDir,
    onPickOutputDir,
    batchFormat,
    onBatchFormatChange,
    batchOutputSuffix,
    onBatchOutputSuffixChange,
    batchCanRun,
    batchCanRetryFailed,
    onRunBatch,
    onRetryFailedBatch,
    onAbortBatch,
    batchProgress,
    lastBatchSummary,
    videoInputPath,
    videoProbeLabel,
    videoCanExport,
    onPickVideoFile,
    onRunVideoExport,
    // videoExportSuccessNonce — no longer consumed after wizard removal
    canApplyEditGradeToBatch,
    onApplyEditGradeToBatch,
    editToExportSyncedAtMs,
    onReapplyBatchPresetBaseline,
    compact = false,
  } = props;

  const t = useTranslations("film-lab.desktop.batch");
  const locale = useLocale();
  const stepLabels = useMemo(
    (): Record<BatchStepId, string> => ({
      jobType: t("steps.jobType"),
      sources: t("steps.sources"),
      look: t("steps.look"),
      output: t("steps.output"),
      run: t("steps.run"),
    }),
    [t],
  );

  /**
   * @description 書き出しルックの「正」を 1 枚に圧縮して表示（JSON / 編集同期 / プリセットの三択）
   */
  const lookStatusBanner = useMemo(() => {
    if (importedGradeLabel) {
      return {
        Icon: File,
        iconWeight: "duotone" as const,
        title: t("lookStatusJsonTitle"),
        body: t("lookStatusJsonBody", { path: importedGradeLabel }),
        accent: "shadow-[inset_3px_0_0_0_var(--blue-9)]",
        iconClass: "text-[var(--blue-11)]",
      };
    }
    if (editToExportSyncedAtMs != null) {
      const time = new Date(editToExportSyncedAtMs).toLocaleTimeString(
        locale === "ja" ? "ja-JP" : locale,
        {
          hour: "2-digit",
          minute: "2-digit",
          second: "2-digit",
        },
      );
      return {
        Icon: CheckCircle,
        iconWeight: "fill" as const,
        title: t("lookStatusEditTitle"),
        body: t("lookStatusEditBody", { time }),
        accent: "shadow-[inset_3px_0_0_0_rgb(52_211_153)]",
        iconClass: "text-[rgb(52_211_153)]",
      };
    }
    return {
      Icon: Circle,
      iconWeight: "duotone" as const,
      title: t("lookStatusPresetTitle", { preset: batchPresetChoice }),
      body: t("lookStatusPresetBody"),
      accent: "shadow-[inset_3px_0_0_0_var(--amber-9)]",
      iconClass: "text-[var(--fl-text-secondary)]",
    };
  }, [
    importedGradeLabel,
    editToExportSyncedAtMs,
    batchPresetChoice,
    locale,
    t,
  ]);

  /** @description ルックの「JSON / ファイル」詳細（デフォルト閉じる） */
  const [lookAdvancedOpen, setLookAdvancedOpen] = useState(false);

  /* ── Accordion state ── */

  const sourcesComplete = isSourcesStepComplete(
    batchJobMode,
    inputDir,
    videoInputPath,
  );
  const { sourceOk, outputOk } = getSourceOutputStatus(
    batchJobMode,
    inputDir,
    outputDir,
    videoInputPath,
  );

  /**
   * @description 各アコーディオンセクションの開閉状態。
   * 同期済み or 設定済みのセクションは初期状態で折りたたむ。
   */
  const [openSections, setOpenSections] = useState<
    Record<AccordionStepId, boolean>
  >(() => ({
    jobType: true,
    sources: !isSourcesStepComplete(batchJobMode, inputDir, videoInputPath),
    look: editToExportSyncedAtMs == null && importedGradeLabel == null,
    output: true,
  }));

  const toggleSection = (id: AccordionStepId) => {
    setOpenSections((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  /**
   * @description セクションが編集タブから同期済みかどうか
   */
  const isSectionSynced = (id: AccordionStepId): boolean => {
    switch (id) {
      case "look":
        return editToExportSyncedAtMs != null || importedGradeLabel != null;
      default:
        return false;
    }
  };

  /**
   * @description セクションが設定完了しているかどうか（ヘッダーにチェック表示）
   */
  const isSectionComplete = (id: AccordionStepId): boolean => {
    switch (id) {
      case "jobType":
        return true;
      case "sources":
        return sourcesComplete;
      case "look":
        return true;
      case "output":
        return batchJobMode === "images" ? Boolean(outputDir) : true;
    }
  };

  /**
   * @description 折りたたみヘッダーに表示するサマリテキスト
   */
  const getSectionSummary = (id: AccordionStepId): string | null => {
    switch (id) {
      case "jobType":
        return batchJobMode === "images"
          ? t("jobImagesTitle")
          : t("jobVideoTitle");
      case "sources":
        if (batchJobMode === "images") {
          return inputDir ? lastPathSegment(inputDir) : null;
        }
        return videoInputPath ? lastPathSegment(videoInputPath) : null;
      case "look":
        return lookStatusBanner.title;
      case "output":
        if (batchJobMode === "images") {
          return outputDir
            ? `${batchFormat.toUpperCase()} → ${lastPathSegment(outputDir)}`
            : null;
        }
        return outputDir ? lastPathSegment(outputDir) : null;
    }
  };

  /**
   * @description Export ボタン付近に表示するバリデーションメッセージ
   */
  const missingItems: { label: string; section: AccordionStepId }[] = [];
  if (!sourcesComplete) {
    missingItems.push({
      label:
        batchJobMode === "images"
          ? t("pickImageFolderTitle")
          : t("pickVideoFileTitle"),
      section: "sources",
    });
  }
  if (batchJobMode === "images" && !outputDir) {
    missingItems.push({ label: t("outputImageTitle"), section: "output" });
  }

  /* ── Step renderers (unchanged) ── */

  const renderStepJobType = () => (
    <div className="flex flex-col gap-3" role="group" aria-labelledby="batch-step-job-type-title">
      {!compact && (
        <p id="batch-step-job-type-title" className="text-sm font-medium text-[var(--fl-text-primary)]">
          {t("jobTypeQuestion")}
        </p>
      )}
      {compact ? (
        <div className="flex rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] p-0.5" role="radiogroup" aria-label={t("jobTypeQuestion")}>
          <button
            type="button"
            role="radio"
            aria-checked={batchJobMode === "images"}
            className={`flex-1 rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
              batchJobMode === "images"
                ? "bg-[var(--amber-9)] text-[var(--amber-1)] shadow-sm"
                : "text-[var(--fl-text-secondary)] hover:text-[var(--fl-text-primary)]"
            }`}
            onClick={() => onBatchJobModeChange("images")}
          >
            {t("jobImagesTitle")}
          </button>
          <button
            type="button"
            role="radio"
            aria-checked={batchJobMode === "video"}
            className={`flex-1 rounded-md px-3 py-1.5 text-xs font-medium transition-colors ${
              batchJobMode === "video"
                ? "bg-[var(--amber-9)] text-[var(--amber-1)] shadow-sm"
                : "text-[var(--fl-text-secondary)] hover:text-[var(--fl-text-primary)]"
            }`}
            onClick={() => onBatchJobModeChange("video")}
          >
            {t("jobVideoTitle")}
          </button>
        </div>
      ) : (
        <div className="grid gap-3 sm:grid-cols-2">
          <button
            type="button"
            className={`flex cursor-pointer flex-col rounded-xl border-2 p-3 text-left transition-all ${
              batchJobMode === "images"
                ? "border-[var(--amber-9)] bg-[var(--fl-bg-subtle)] shadow-[inset_3px_0_0_0_var(--amber-9)]"
                : "border-[var(--fl-border-subtle)] border-dashed bg-[var(--fl-bg-subtle)] opacity-90 hover:border-[var(--fl-border-default)] hover:opacity-100"
            }`}
            onClick={() => onBatchJobModeChange("images")}
            aria-pressed={batchJobMode === "images"}
          >
            <div className="flex items-start justify-between gap-2">
              <span className="text-sm font-semibold text-[var(--fl-text-primary)]">
                {t("jobImagesTitle")}
              </span>
              <HelpHint tip={t("tipJobImages")} assistiveLabel={t("jobImagesHintAria")} />
            </div>
            {batchJobMode === "images" ? (
              <span className="mt-2 inline-flex w-fit items-center gap-1 text-[0.65rem] font-medium text-[var(--amber-11)]">
                <CheckCircle size={14} weight="bold" aria-hidden />
                {t("selected")}
              </span>
            ) : (
              <span className="fl-caption mt-2 text-[var(--fl-text-tertiary)]">
                {t("clickToSwitch")}
              </span>
            )}
            <p className="fl-caption mt-1 text-[var(--fl-text-secondary)]">
              {t("jobImagesSub")}
            </p>
          </button>
          <button
            type="button"
            className={`flex cursor-pointer flex-col rounded-xl border-2 p-3 text-left transition-all ${
              batchJobMode === "video"
                ? "border-[var(--amber-9)] bg-[var(--fl-bg-subtle)] shadow-[inset_3px_0_0_0_var(--amber-9)]"
                : "border-[var(--fl-border-subtle)] border-dashed bg-[var(--fl-bg-subtle)] opacity-90 hover:border-[var(--fl-border-default)] hover:opacity-100"
            }`}
            onClick={() => onBatchJobModeChange("video")}
            aria-pressed={batchJobMode === "video"}
          >
            <div className="flex items-start justify-between gap-2">
              <span className="text-sm font-semibold text-[var(--fl-text-primary)]">
                {t("jobVideoTitle")}
              </span>
              <HelpHint
                tip={t("tipJobVideoWebGlOnly")}
                assistiveLabel={t("jobVideoHintAria")}
              />
            </div>
            {batchJobMode === "video" ? (
              <span className="mt-2 inline-flex w-fit items-center gap-1 text-[0.65rem] font-medium text-[var(--amber-11)]">
                <CheckCircle size={14} weight="bold" aria-hidden />
                {t("selected")}
              </span>
            ) : (
              <span className="fl-caption mt-2 text-[var(--fl-text-tertiary)]">
                {t("clickToSwitch")}
              </span>
            )}
            <p className="fl-caption mt-1 text-[var(--fl-text-secondary)]">
              {t("jobVideoSubWebGlOnly")}
            </p>
          </button>
        </div>
      )}
    </div>
  );

  const renderStepSources = () => (
    <div className="flex flex-col gap-3">
      {batchJobMode === "images" ? (
        <>
          <div className="flex flex-wrap items-center gap-1.5">
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">
              {t("pickImageFolderTitle")}
            </p>
            <HelpHint
              tip={t("tipSourcesImagesFolder")}
              assistiveLabel={t("pickImageFolderHintAria")}
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickInputDir()}>
              {t("pickInputFolderBtn")}
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={inputDir ?? undefined}>
              {inputDir ?? t("notSelected")}
            </span>
          </div>
        </>
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-1.5">
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">
              {t("pickVideoFileTitle")}
            </p>
            <HelpHint
              tip={t("tipSourcesVideoFile", {
                maxSec: String(VIDEO_IMPORT_MAX_DURATION_SEC),
              })}
              assistiveLabel={t("pickVideoFileHintAria")}
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              disabled={running}
              onClick={() => void onPickVideoFile()}
            >
              {t("pickVideoBtn")}
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={videoInputPath ?? undefined}>
              {videoInputPath ?? t("notSelected")}
            </span>
          </div>
          {videoProbeLabel ? (
            <p className="fl-caption max-w-prose text-[var(--fl-text-secondary)]">{videoProbeLabel}</p>
          ) : null}
        </>
      )}
    </div>
  );

  const renderStepLook = () => {
    const LookStatusIcon = lookStatusBanner.Icon;
    return (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-[var(--fl-text-primary)]">
        {t("lookSectionLead")}
      </p>
      <p className="fl-caption max-w-prose text-[var(--fl-text-secondary)]">
        {t("lookSectionIntro")}
      </p>

      <div
        className={`flex gap-2.5 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2.5 ${lookStatusBanner.accent}`}
        role="status"
        aria-live="polite"
        aria-label={lookStatusBanner.title}
      >
        <LookStatusIcon
          size={16}
          weight={lookStatusBanner.iconWeight}
          className={`mt-0.5 shrink-0 ${lookStatusBanner.iconClass}`}
          aria-hidden
        />
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold text-[var(--fl-text-primary)]">
            {lookStatusBanner.title}
          </p>
          <p className="fl-caption mt-0.5 max-w-prose text-[var(--fl-text-secondary)]">
            {lookStatusBanner.body}
          </p>
        </div>
      </div>

      <div className="flex flex-col gap-2 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-raised)] px-3 py-3">
        <p className="text-xs font-semibold uppercase tracking-wide text-[var(--fl-text-secondary)]">
          {t("lookFromEditHeading")}
        </p>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className={
              running || !canApplyEditGradeToBatch
                ? "fl-btn-secondary max-w-full sm:max-w-none"
                : "fl-btn-primary max-w-full sm:max-w-none"
            }
            disabled={running || !canApplyEditGradeToBatch}
            title={
              canApplyEditGradeToBatch ? undefined : t("applyEditWaitHint")
            }
            onClick={onApplyEditGradeToBatch}
          >
            {t("applyEditToExportBtn")}
          </button>
          <HelpHint
            tip={t("tipApplyEditGradeToBatch")}
            assistiveLabel={t("applyEditHintAria")}
          />
        </div>
        <p className="fl-caption text-[var(--fl-text-secondary)]">
          {t("sameAsFooterSend")}
        </p>
      </div>

      {importedGradeLabel == null &&
      editToExportSyncedAtMs != null ? (
        <div className="flex max-w-md flex-col gap-2 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2.5">
          <span className="fl-label">{t("presetQuickLabel")}</span>
          <p className="fl-caption max-w-prose text-[var(--fl-text-secondary)]">
            {t("lookPresetHiddenWhileSyncedBody", {
              preset: batchPresetChoice,
            })}
          </p>
          <button
            type="button"
            className="fl-btn-secondary self-start"
            disabled={running}
            onClick={onReapplyBatchPresetBaseline}
          >
            {t("lookRevertToPresetOnlyBtn")}
          </button>
        </div>
      ) : (
        <label className="flex max-w-md flex-col gap-1.5">
          <span className="fl-label">{t("presetQuickLabel")}</span>
          <select
            data-testid="export-preset-select"
            value={batchPresetChoice}
            onChange={(e) =>
              onBatchPresetChoiceChange(e.target.value as PresetName)
            }
            className="w-full max-w-md"
            aria-label={t("presetSelectAria")}
          >
            {PRESET_NAMES.map((n) => (
              <option key={n} value={n}>
                {n}
              </option>
            ))}
          </select>
        </label>
      )}

      <div className="flex items-start gap-1.5 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2">
        <details
          className="min-w-0 flex-1"
          open={lookAdvancedOpen}
          onToggle={(e) => setLookAdvancedOpen(e.currentTarget.open)}
        >
          <summary className="cursor-pointer text-xs font-semibold text-[var(--fl-text-secondary)]">
            {t("advancedGradeJsonSummary")}
          </summary>
          <div className="mt-2 flex flex-wrap gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onImportGradeJson()}>
              {t("importJsonBtn")}
            </button>
            <button type="button" className="fl-btn-secondary" onClick={onExportGradeJson}>
              {t("exportJsonBtn")}
            </button>
          </div>
        </details>
        <HelpHint tip={t("tipLookJsonDetails")} assistiveLabel={t("advancedGradeJsonAria")} />
      </div>
    </div>
    );
  };

  const renderStepOutput = () => (
    <div className="flex flex-col gap-3">
      {batchJobMode === "images" ? (
        <>
          <p className="text-sm font-medium text-[var(--fl-text-primary)]">
            {t("outputImageTitle")}
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickOutputDir()}>
              {t("pickOutputFolderBtn")}
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={outputDir ?? undefined}>
              {outputDir ?? t("notSelected")}
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <label htmlFor="batch-format-sel-panel" className="fl-label normal-case">
              {t("outputFormatLabel")}
            </label>
            <select
              id="batch-format-sel-panel"
              className="min-w-[6.5rem]"
              value={batchFormat}
              onChange={(e) => onBatchFormatChange(e.target.value as BatchFormat)}
              aria-label={t("formatSelectAria")}
            >
              <option value="jpeg">JPEG</option>
              <option value="png">PNG</option>
            </select>
          </div>
          <label className="flex max-w-md flex-col gap-1.5">
            <span className="fl-label normal-case flex items-center gap-1">
              {t("filenameSuffixLabel")}
              <HelpHint tip={t("tipFilenameSuffix")} assistiveLabel={t("filenameSuffixAria")} />
            </span>
            <input
              type="text"
              className="fl-text-input w-full max-w-md"
              value={batchOutputSuffix}
              onChange={(e) => onBatchOutputSuffixChange(e.target.value)}
              autoComplete="off"
              spellCheck={false}
            />
          </label>
        </>
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-1.5">
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">
              {t("videoOutputFolderTitle")}
            </p>
            <HelpHint
              tip={t("tipVideoOutputNaming", { fps: String(VIDEO_EXPORT_FPS) })}
              assistiveLabel={t("videoOutputNamingAria")}
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickOutputDir()}>
              {t("pickOutputFolderBtn")}
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={outputDir ?? undefined}>
              {outputDir ?? t("videoOutputDirUnset")}
            </span>
          </div>
          <p className="max-w-prose text-xs leading-snug text-[var(--fl-text-secondary)]">
            {t("videoWebglOnlyFootnote")}
          </p>
        </>
      )}
    </div>
  );

  const renderStepRun = () => (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center gap-1.5">
        <p className="text-sm font-medium text-[var(--fl-text-primary)]">
          {t("runSectionTitle")}
        </p>
        <HelpHint
          tip={t("tipKeyboardShortcuts", {
            imagesLabel:
              batchJobMode === "images" ? t("runImagesPrimary") : t("runVideoExport"),
          })}
          assistiveLabel={t("runKeyboardHintsAria")}
        />
      </div>
      {batchJobMode === "images" ? (
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="fl-btn-primary max-w-xs"
            disabled={!batchCanRun}
            onClick={() => void onRunBatch()}
          >
            {t("runImagesPrimary")}
          </button>
          <button
            type="button"
            className="fl-btn-secondary max-w-xs"
            disabled={!batchCanRetryFailed}
            onClick={() => void onRetryFailedBatch()}
          >
            {t("runRetryFailed")}
          </button>
          <button
            type="button"
            className="fl-btn-secondary"
            disabled={!running}
            aria-label={t("runAbortAria")}
            onClick={onAbortBatch}
          >
            {t("runAbort")}
          </button>
        </div>
      ) : (
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="fl-btn-primary max-w-xs"
            disabled={!videoCanExport}
            onClick={() => void onRunVideoExport()}
          >
            {t("runVideoExport")}
          </button>
          <button
            type="button"
            className="fl-btn-secondary"
            disabled={!running}
            aria-label={t("runAbortAria")}
            onClick={onAbortBatch}
          >
            {t("runAbort")}
          </button>
        </div>
      )}

      {running && batchProgress && batchProgress.total > 0 ? (
        <div className="fl-batch-progress" aria-live="polite" aria-busy="true">
          <div
            className="fl-progress"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={batchProgress.total}
            aria-valuenow={batchProgress.current}
            aria-valuetext={t("batchProgressAriaText", {
              current: String(batchProgress.current),
              total: String(batchProgress.total),
              file: batchProgress.fileName,
            })}
          >
            <div
              className="fl-progress-fill"
              style={{
                width: `${Math.min(
                  100,
                  Math.round((batchProgress.current / batchProgress.total) * 100),
                )}%`,
              }}
            />
          </div>
          <p className="fl-caption">
            {batchProgress.current} / {batchProgress.total} · {batchProgress.fileName}
          </p>
        </div>
      ) : null}

      {batchJobMode === "images" && lastBatchSummary && !running ? (
        <p className="fl-caption" aria-live="polite">
          {t("lastSummary", {
            ok: String(lastBatchSummary.ok),
            loadFail: String(lastBatchSummary.loadFail),
            writeFail: String(lastBatchSummary.writeFail),
          })}
        </p>
      ) : null}
    </div>
  );

  /* ── Accordion renderers map ── */

  const accordionRenderers: Record<AccordionStepId, () => ReactElement> = {
    jobType: renderStepJobType,
    sources: renderStepSources,
    look: renderStepLook,
    output: renderStepOutput,
  };

  /* ── JSX ── */

  return (
    <>
      {/* Intro */}
      {!compact && (
        <section
          className="fl-card fl-card-muted fl-card--frost gap-2 border-[var(--fl-border-default)]"
          aria-labelledby="export-tab-intro-heading"
        >
          <div className="flex items-start gap-2">
            <h2
              id="export-tab-intro-heading"
              className="text-sm font-semibold text-[var(--fl-text-primary)]"
            >
              {t("exportTitle")}
            </h2>
            <HelpHint tip={t("tipExportTabIntro")} assistiveLabel={t("exportTitleHintAria")} />
          </div>
          <p className="fl-caption text-[var(--fl-text-secondary)]">{t("exportLead")}</p>
        </section>
      )}

      {!compact && (
        <div className="self-start rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2 text-xs leading-relaxed text-[var(--fl-text-secondary)] shadow-[inset_3px_0_0_0_var(--amber-9)]">
          {t("differentFolderWarning")}
        </div>
      )}

      {/* Session resume */}
      {persistedSession && sessionHasRemainingWork(persistedSession) ? (
        <div className="rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2.5 text-xs leading-relaxed shadow-[inset_3px_0_0_0_var(--blue-9)]">
          <div className="mb-2 flex flex-wrap items-start gap-1.5">
            <p className="text-[var(--fl-text-primary)]">
              {t("resumeLead", {
                remaining: String(pathsNotSucceeded(persistedSession).length),
              })}
            </p>
            <HelpHint tip={t("tipResumeSession")} assistiveLabel={t("resumeHintAria")} />
          </div>
          <div className="flex flex-wrap gap-2">
            <button type="button" className="fl-btn-primary" disabled={!batchCanResume} onClick={() => void onResumeBatch()}>
              {t("resumeBtn")}
            </button>
            <button type="button" className="fl-btn-secondary" disabled={running} onClick={() => void onDiscardPersistedSession()}>
              {t("discardSessionBtn")}
            </button>
          </div>
        </div>
      ) : null}

      {/* Status chips */}
      <div className={`flex flex-wrap ${compact ? "gap-1 py-2.5 text-[0.6rem]" : "gap-2 text-[0.65rem]"}`}>
        <span
          className={`rounded-full border px-2 py-0.5 ${
            sourceOk
              ? "border-[var(--amber-8)] bg-[var(--amber-3)] text-[var(--amber-12)]"
              : "border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] text-[var(--fl-text-tertiary)]"
          }`}
        >
          {t("chipInput")}: {sourceOk ? t("chipInputOk") : t("chipInputPending")}
        </span>
        <span className="rounded-full border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-2 py-0.5 text-[var(--fl-text-tertiary)]">
          {t("chipLook")}: {t("chipLookReady")}
        </span>
        <span
          className={`rounded-full border px-2 py-0.5 ${
            outputOk || batchJobMode === "video"
              ? outputOk
                ? "border-[var(--amber-8)] bg-[var(--amber-3)] text-[var(--amber-12)]"
                : "border-[var(--amber-7)] bg-[var(--amber-4)] text-[var(--amber-12)]"
              : "border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] text-[var(--fl-text-tertiary)]"
          }`}
        >
          {t("chipOutput")}:{" "}
          {batchJobMode === "video"
            ? outputOk
              ? t("chipOutputOk")
              : t("chipOutputOptional")
            : outputOk
              ? t("chipOutputOk")
              : t("chipOutputPending")}
        </span>
      </div>

      {/* Accordion sections */}
      <div className={`fl-card fl-card--frost flex flex-col divide-y divide-[var(--fl-border-subtle)] ${compact ? "gap-0 p-0" : ""}`}>
        {ACCORDION_STEPS.map((id, idx) => {
          const isOpen = openSections[id];
          const synced = isSectionSynced(id);
          const complete = isSectionComplete(id);
          const summary = getSectionSummary(id);
          const needsAttention =
            !running && missingItems.some((m) => m.section === id);

          return (
            <div key={id} id={`export-step-${id}`}>
              <button
                type="button"
                className={`flex w-full items-center gap-2 ${compact ? "px-2.5 py-2" : "px-3 py-2.5"} text-left transition-colors hover:bg-[var(--fl-bg-interactive)] ${
                  needsAttention
                    ? "shadow-[inset_3px_0_0_0_var(--amber-9)]"
                    : ""
                }`}
                onClick={() => toggleSection(id)}
                aria-expanded={isOpen}
                aria-controls={`export-step-body-${id}`}
              >
                {complete ? (
                  <CheckCircle
                    className="shrink-0 text-[var(--amber-11)]"
                    size={16}
                    weight="fill"
                    aria-hidden
                  />
                ) : (
                  <Circle
                    className="shrink-0 text-[var(--fl-text-tertiary)]"
                    size={16}
                    aria-hidden
                  />
                )}
                <span className="flex min-w-0 flex-1 items-center gap-2">
                  <span className="tabular-nums text-[0.65rem] text-[var(--fl-text-tertiary)]">
                    {idx + 1}
                  </span>
                  <span className="text-sm font-medium text-[var(--fl-text-primary)]">
                    {stepLabels[id]}
                  </span>
                  {synced ? (
                    <span className="inline-flex items-center gap-0.5 rounded-full border border-emerald-700/30 bg-emerald-900/20 px-1.5 py-0.5 text-[0.6rem] font-medium text-emerald-400">
                      <CheckCircle size={10} weight="fill" aria-hidden />
                      synced
                    </span>
                  ) : null}
                  {!isOpen && summary ? (
                    <span className="min-w-0 truncate text-xs text-[var(--fl-text-tertiary)]">
                      {summary}
                    </span>
                  ) : null}
                </span>
                {isOpen ? (
                  <CaretUp
                    className="shrink-0 text-[var(--fl-text-tertiary)]"
                    size={14}
                    aria-hidden
                  />
                ) : (
                  <CaretDown
                    className="shrink-0 text-[var(--fl-text-tertiary)]"
                    size={14}
                    aria-hidden
                  />
                )}
              </button>
              {isOpen ? (
                <div
                  id={`export-step-body-${id}`}
                  className={compact ? "px-2.5 pb-3 pt-1" : "px-3 pb-4 pt-1"}
                >
                  {accordionRenderers[id]()}
                </div>
              ) : null}
            </div>
          );
        })}
      </div>

      {/* Export / Run — always visible */}
      <section
        className={`fl-card fl-card--frost gap-3 ${compact ? "sticky bottom-0 z-10 rounded-t-xl shadow-[0_-4px_12px_rgba(0,0,0,0.3)]" : ""}`}
        aria-labelledby="export-run-heading"
      >
        <h3
          id="export-run-heading"
          className="sr-only"
        >
          {stepLabels.run}
        </h3>
        {renderStepRun()}

        {/* Validation messages */}
        {missingItems.length > 0 && !running ? (
          <div className="flex flex-col gap-1.5 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2">
            {missingItems.map((item) => (
              <button
                key={item.section}
                type="button"
                className="flex items-center gap-1.5 text-left text-xs text-[var(--amber-11)] hover:underline"
                onClick={() => {
                  setOpenSections((prev) => ({
                    ...prev,
                    [item.section]: true,
                  }));
                  requestAnimationFrame(() => {
                    document
                      .getElementById(`export-step-${item.section}`)
                      ?.scrollIntoView({ behavior: "smooth", block: "center" });
                  });
                }}
              >
                <WarningCircle size={14} weight="bold" aria-hidden />
                {item.label}
              </button>
            ))}
          </div>
        ) : null}
      </section>

      {!compact && (
        <div className="flex flex-wrap items-center gap-1.5">
          <p className="fl-caption">{t("prefsFootnote")}</p>
          <HelpHint tip={t("tipDesktopPrefsPersist")} assistiveLabel={t("prefsFootnoteAria")} />
        </div>
      )}
    </>
  );
}
