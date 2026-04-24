/**
 * @fileoverview Film Lab デスクトップの「書き出し」タブ用パネル（glass 統一・2026-04-19 再設計）
 *
 * @description
 * 4 製品研究（Lightroom / Capture One / Apple Photos / DaVinci Deliver）の共通則から導出した
 * rulebook（apps/desktop-film-lab-batch/docs/ui-rulebook-glass-unified.md）に準拠。
 * - material: `.fl-card--frost` 1 種のみ、ソリッド黒系カード全廃
 * - preset strip: DaVinci 型、画面最上部の横 1 行タイル帯
 * - accordion: sources / look / output の 3 セクション（jobType は単独、run は footer 内）
 * - advanced disclosure: proxy cache / preview-export bridge を既定閉で格納
 * - primary accent: amber は実行 CTA 1 個のみ
 * - ⓘ icon: 17 → 最小（proxy cache のみ残存）
 */

import {
  CaretDown,
  CaretUp,
  CheckCircle,
  Circle,
  File,
  Sparkle,
  WarningCircle,
} from "@phosphor-icons/react";
import { useEffect, useMemo, useRef, useState, type ReactElement } from "react";
import { useLocale, useTranslations } from "next-intl";
import { PRESETS, PRESET_BUTTONS, type PresetName } from "film-lab-core";
import {
  pathsNotSucceeded,
  sessionHasRemainingWork,
  type FilmLabBatchSessionV1,
} from "../batch-session";
import type { BatchFormat } from "../batch-pipeline";
import {
  VIDEO_EXPORT_FALLBACK_FPS,
  VIDEO_IMPORT_MAX_DURATION_SEC,
} from "../video-export-constants";
import type {
  HdrPreparationPolicy,
  VideoPreviewProxyCacheInfo,
} from "../desktop-api";
import { HdrPolicyNotice } from "../HdrPolicyNotice";
import type {
  AppliedOpticalRecommendationMetadata,
  MetadataLookSource,
} from "../export-metadata-session";
import { PresetStrip } from "./PresetStrip";
import {
  AdvancedDisclosure,
  type PreviewBridgeLines,
} from "./AdvancedDisclosure";

/** @description 書き出しタブで扱うジョブの大分類 */
export type BatchJobMode = "images" | "video";

const PRESET_NAMES = Object.keys(PRESETS) as PresetName[];

function formatPresetChoiceLabel(presetName: PresetName): string {
  const presetButton = PRESET_BUTTONS.find((row) => row.name === presetName);
  return presetButton
    ? `${presetButton.label} / ${presetButton.subtitle}`
    : presetName;
}

/** @description 編集プレビューと書き出し入力の対応を追うための状態（life#83） */
export type DesktopInteractivePreviewState =
  | { kind: "sample" }
  | {
      kind: "file";
      fileName: string;
      absolutePath: string | null;
      smartLookDerived: boolean;
    };

/** @description パス比較用に区切りと大文字小文字をそろえる */
function normPathSegments(p: string): string {
  return p.replace(/\\/g, "/").toLowerCase();
}

function pathsEqualNormalized(a: string, b: string): boolean {
  return normPathSegments(a) === normPathSegments(b);
}

function isFileUnderInputDir(filePath: string, inputDir: string): boolean {
  const nf = normPathSegments(filePath);
  const nd = normPathSegments(inputDir).replace(/\/$/, "");
  return nf.startsWith(`${nd}/`) || nf === nd;
}

function isRasterFileName(name: string): boolean {
  return /\.(jpe?g|png|webp|gif)$/i.test(name);
}

function isVideoFileName(name: string): boolean {
  return /\.(mp4|webm)$/i.test(name);
}

function shouldAutoExpandSources(
  mode: BatchJobMode,
  inputDir: string | null,
  videoInputPath: string | null,
  preview: DesktopInteractivePreviewState | undefined,
): boolean {
  if (!isSourcesStepComplete(mode, inputDir, videoInputPath)) return true;
  if (!preview) return false;
  if (preview.kind === "sample") return true;
  if (preview.kind === "file") {
    if (preview.smartLookDerived) return true;
    if (!preview.absolutePath) return true;
    if (mode === "images") {
      if (isVideoFileName(preview.fileName) && !isRasterFileName(preview.fileName)) {
        return true;
      }
      if (!inputDir) return true;
      return !isFileUnderInputDir(preview.absolutePath, inputDir);
    }
    if (mode === "video") {
      if (isRasterFileName(preview.fileName) && !isVideoFileName(preview.fileName)) {
        return true;
      }
      if (!videoInputPath) return true;
      return !pathsEqualNormalized(preview.absolutePath, videoInputPath);
    }
  }
  return false;
}

type BatchStepId = "jobType" | "sources" | "look" | "output" | "run";
type AccordionStepId = Exclude<BatchStepId, "jobType" | "run">;

const ACCORDION_STEPS: AccordionStepId[] = ["sources", "look", "output"];

function createDefaultOpenSections(
  mode: BatchJobMode,
  inputDir: string | null,
  videoInputPath: string | null,
  batchLookSource: MetadataLookSource,
  desktopInteractivePreview: DesktopInteractivePreviewState | undefined,
): Record<AccordionStepId, boolean> {
  const expandSources = shouldAutoExpandSources(
    mode,
    inputDir,
    videoInputPath,
    desktopInteractivePreview,
  );
  return {
    sources: expandSources,
    look: batchLookSource === "preset",
    output: true,
  };
}

function lastPathSegment(p: string): string {
  const parts = p.replace(/\\/g, "/").split("/");
  return parts[parts.length - 1] || p;
}

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

function isSourcesStepComplete(
  mode: BatchJobMode,
  inputDir: string | null,
  videoInputPath: string | null,
): boolean {
  if (mode === "images") return Boolean(inputDir);
  return Boolean(videoInputPath);
}

/**
 * @description BatchTabPanel が親から受け取る props
 */
export type BatchTabPanelProps = {
  batchJobMode: BatchJobMode;
  onBatchJobModeChange: (mode: BatchJobMode) => void;
  exportSurface?: "images" | "video";

  persistedSession: FilmLabBatchSessionV1 | null;
  batchCanResume: boolean;
  running: boolean;
  onResumeBatch: () => void | Promise<void>;
  onDiscardPersistedSession: () => void | Promise<void>;
  proxyCacheInfo: VideoPreviewProxyCacheInfo | null;
  isPurgingProxyCache: boolean;
  onPurgeProxyCache: () => void | Promise<void>;

  batchPresetChoice: PresetName;
  batchLookSource: MetadataLookSource;
  appliedOpticalRecommendation?: AppliedOpticalRecommendationMetadata | null;
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
  /**
   * @description 最後に probe した動画の HDR 準備ポリシー。capability-gated defer のときだけ
   *   ソース行のすぐ下に `<HdrPolicyNotice />` を出す（S-4 capability probe / Stream D）。
   */
  videoHdrPolicy?: HdrPreparationPolicy | null;
  /** @description 「HDR フィクスチャ状況」ドキュメントを開くハンドラ。未指定ならリンクを出さない。 */
  onOpenHdrFixtureDoc?: () => void;
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

  desktopInteractivePreview?: DesktopInteractivePreviewState;
};

/**
 * @description 右パネル compact 用の実行フッターに必要な最小 props
 */
export type BatchTabCompactRunFooterProps = Pick<
  BatchTabPanelProps,
  | "batchJobMode"
  | "inputDir"
  | "outputDir"
  | "videoInputPath"
  | "running"
  | "batchCanRun"
  | "batchCanRetryFailed"
  | "onRunBatch"
  | "onRetryFailedBatch"
  | "onAbortBatch"
  | "batchProgress"
  | "lastBatchSummary"
  | "videoCanExport"
  | "onRunVideoExport"
>;

/**
 * @description 右パネル compact 専用の実行フッター（書き出しボタンを scroll の外へ出す）
 */
export function BatchTabCompactRunFooter(
  props: BatchTabCompactRunFooterProps,
) {
  const {
    batchJobMode,
    inputDir,
    outputDir,
    videoInputPath,
    running,
    batchCanRun,
    batchCanRetryFailed,
    onRunBatch,
    onRetryFailedBatch,
    onAbortBatch,
    batchProgress,
    lastBatchSummary,
    videoCanExport,
    onRunVideoExport,
  } = props;

  const t = useTranslations("film-lab.desktop.batch");
  const isImagesMode = batchJobMode === "images";

  const missingItems: { label: string }[] = [];
  if (!isSourcesStepComplete(batchJobMode, inputDir, videoInputPath)) {
    missingItems.push({
      label: isImagesMode ? t("pickImageFolderTitle") : t("pickVideoFileTitle"),
    });
  }
  if (isImagesMode && !outputDir) {
    missingItems.push({ label: t("outputImageTitle") });
  }

  return (
    <div className="flex flex-col gap-3">
      {isImagesMode ? (
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
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
            className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
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
                  Math.round(
                    (batchProgress.current / batchProgress.total) * 100,
                  ),
                )}%`,
              }}
            />
          </div>
          <p className="fl-caption">
            {batchProgress.current} / {batchProgress.total} ·{" "}
            {batchProgress.fileName}
          </p>
        </div>
      ) : null}

      {isImagesMode && lastBatchSummary && !running ? (
        <p className="fl-caption" aria-live="polite">
          {t("lastSummary", {
            ok: String(lastBatchSummary.ok),
            loadFail: String(lastBatchSummary.loadFail),
            writeFail: String(lastBatchSummary.writeFail),
          })}
        </p>
      ) : null}

      {missingItems.length > 0 && !running ? (
        <div className="flex flex-wrap items-center gap-x-3 gap-y-1 text-xs text-[var(--amber-11)]">
          {missingItems.map((item) => (
            <span key={item.label} className="inline-flex items-center gap-1.5">
              <WarningCircle size={14} weight="bold" aria-hidden />
              {item.label}
            </span>
          ))}
        </div>
      ) : null}
    </div>
  );
}

/**
 * @description 書き出しタブのメインパネル
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
    proxyCacheInfo,
    isPurgingProxyCache,
    onPurgeProxyCache,
    batchPresetChoice,
    batchLookSource,
    appliedOpticalRecommendation = null,
    onBatchPresetChoiceChange,
    importedGradeLabel,
    onImportGradeJson,
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
    videoHdrPolicy = null,
    onOpenHdrFixtureDoc,
    videoCanExport,
    onPickVideoFile,
    onRunVideoExport,
    canApplyEditGradeToBatch,
    onApplyEditGradeToBatch,
    editToExportSyncedAtMs,
    onReapplyBatchPresetBaseline,
    compact = false,
    exportSurface,
    desktopInteractivePreview,
  } = props;

  const t = useTranslations("film-lab.desktop.batch");
  const locale = useLocale();
  const effectiveMode: BatchJobMode = exportSurface ?? batchJobMode;
  const isImagesMode = effectiveMode === "images";

  const stepLabels = useMemo(
    (): Record<BatchStepId, string> => ({
      jobType: t("steps.jobType"),
      sources: isImagesMode ? t("stepSourcesImages") : t("stepSourcesVideo"),
      look: t("steps.look"),
      output: isImagesMode ? t("stepOutputImages") : t("stepOutputVideo"),
      run: isImagesMode ? t("stepRunImages") : t("stepRunVideo"),
    }),
    [isImagesMode, t],
  );

  const recommendationFamilyLabel = useMemo(
    () =>
      (family: AppliedOpticalRecommendationMetadata["family"]): string => {
        switch (family) {
          case "glow":
            return t("recommendationFamilyGlow");
          case "cross":
            return t("recommendationFamilyCross");
          case "lens":
            return t("recommendationFamilyLens");
          default:
            return t("recommendationFamilyMist");
        }
      },
    [t],
  );

  const recommendationRecipeLabel = useMemo(
    () =>
      (
        recipe: AppliedOpticalRecommendationMetadata["recipe"],
      ): string => {
        switch (recipe) {
          case "warmIndoor":
            return t("recommendationRecipeWarmIndoor");
          case "nightCity":
            return t("recommendationRecipeNightCity");
          case "skinCloseUp":
            return t("recommendationRecipeSkinCloseUp");
          case "nightSpot":
            return t("recommendationRecipeNightSpot");
          case "productEdge":
            return t("recommendationRecipeProductEdge");
          case "coverStillMatch":
            return t("recommendationRecipeCoverStillMatch");
          default:
            return t("recommendationRecipeClean");
        }
      },
    [t],
  );

  const lookStatusBanner = useMemo(() => {
    if (batchLookSource === "importedJson") {
      return {
        Icon: File,
        iconWeight: "duotone" as const,
        title: t("lookStatusJsonTitle"),
        body: t("lookStatusJsonBody", { path: importedGradeLabel ?? "" }),
        iconClass: "text-[var(--fl-text-secondary)]",
      };
    }
    if (batchLookSource === "editSync") {
      const time =
        editToExportSyncedAtMs != null
          ? new Date(editToExportSyncedAtMs).toLocaleTimeString(
              locale === "ja" ? "ja-JP" : locale,
              {
                hour: "2-digit",
                minute: "2-digit",
                second: "2-digit",
              },
            )
          : "";
      return {
        Icon: CheckCircle,
        iconWeight: "fill" as const,
        title: t("lookStatusEditTitle"),
        body: editToExportSyncedAtMs != null ? t("lookStatusEditBody", { time }) : "",
        iconClass: "text-[var(--fl-text-secondary)]",
      };
    }
    if (batchLookSource === "analysisRecommendation") {
      const familyLabel = appliedOpticalRecommendation
        ? recommendationFamilyLabel(appliedOpticalRecommendation.family)
        : t("recommendationFamilyMist");
      const recipeLabel = recommendationRecipeLabel(
        appliedOpticalRecommendation?.recipe ?? null,
      );
      return {
        Icon: Sparkle,
        iconWeight: "duotone" as const,
        title: t("lookStatusRecommendationTitle"),
        body: t("lookStatusRecommendationBody", {
          family: familyLabel,
          recipe: recipeLabel,
        }),
        iconClass: "text-[var(--amber-11)]",
      };
    }
    return {
      Icon: Circle,
      iconWeight: "duotone" as const,
      title: t("lookStatusPresetTitle", {
        preset: formatPresetChoiceLabel(batchPresetChoice),
      }),
      body: t("lookStatusPresetBody"),
      iconClass: "text-[var(--fl-text-tertiary)]",
    };
  }, [
    batchLookSource,
    importedGradeLabel,
    appliedOpticalRecommendation,
    editToExportSyncedAtMs,
    batchPresetChoice,
    locale,
    recommendationFamilyLabel,
    recommendationRecipeLabel,
    t,
  ]);

  /**
   * @description 編集プレビューと書き出し入力の関係（life#83、Advanced disclosure 内に降格）
   */
  const previewExportBridge = useMemo((): PreviewBridgeLines | null => {
    const s = desktopInteractivePreview;
    if (!s) return null;

    if (s.kind === "sample") {
      return {
        tone: "neutral",
        previewLine: t("previewBridgeSamplePreviewLine"),
        exportLine: t("previewBridgeSampleExportLine"),
      };
    }

    if (s.smartLookDerived) {
      return {
        tone: "caution",
        previewLine: t("previewBridgeSmartLookPreviewLine"),
        exportLine: t("previewBridgeSmartLookExportLine"),
      };
    }

    if (!s.absolutePath) {
      return {
        tone: "caution",
        previewLine: t("previewBridgeUnknownPathPreviewLine", { name: s.fileName }),
        exportLine: t("previewBridgeUnknownPathExportLine"),
      };
    }

    if (isImagesMode) {
      if (isVideoFileName(s.fileName)) {
        return {
          tone: "caution",
          previewLine: t("previewBridgeVideoPreviewInPhotoTabLine"),
          exportLine: t("previewBridgeVideoPreviewInPhotoTabExportLine"),
        };
      }
      if (!inputDir) {
        return {
          tone: "caution",
          previewLine: t("previewBridgeRasterPreviewLine", { name: s.fileName }),
          exportLine: t("previewBridgePhotoNoFolderLine"),
        };
      }
      if (isFileUnderInputDir(s.absolutePath, inputDir)) return null;
      return {
        tone: "caution",
        previewLine: t("previewBridgePhotoMismatchPreviewLine", { name: s.fileName }),
        exportLine: t("previewBridgePhotoMismatchExportLine", {
          folder: lastPathSegment(inputDir),
        }),
      };
    }

    if (isRasterFileName(s.fileName) && !isVideoFileName(s.fileName)) {
      return {
        tone: "caution",
        previewLine: t("previewBridgeRasterInVideoTabPreviewLine"),
        exportLine: t("previewBridgeRasterInVideoTabExportLine"),
      };
    }
    if (!videoInputPath) {
      return {
        tone: "caution",
        previewLine: t("previewBridgeVideoNamedPreviewLine", { name: s.fileName }),
        exportLine: t("previewBridgeVideoNoFileLine"),
      };
    }
    if (pathsEqualNormalized(s.absolutePath, videoInputPath)) return null;
    return {
      tone: "caution",
      previewLine: t("previewBridgeVideoMismatchPreviewLine", { name: s.fileName }),
      exportLine: t("previewBridgeVideoMismatchExportLine", {
        file: lastPathSegment(videoInputPath),
      }),
    };
  }, [desktopInteractivePreview, inputDir, isImagesMode, t, videoInputPath]);

  /* ── Accordion state ── */

  const sourcesComplete = isSourcesStepComplete(
    effectiveMode,
    inputDir,
    videoInputPath,
  );
  const { outputOk } = getSourceOutputStatus(
    effectiveMode,
    inputDir,
    outputDir,
    videoInputPath,
  );

  const [openSections, setOpenSections] = useState<
    Record<AccordionStepId, boolean>
  >(() =>
    createDefaultOpenSections(
      exportSurface ?? batchJobMode,
      inputDir,
      videoInputPath,
      batchLookSource,
      desktopInteractivePreview,
    ),
  );

  const prevNeedsSourcesAttentionRef = useRef(false);
  useEffect(() => {
    const next =
      desktopInteractivePreview != null &&
      shouldAutoExpandSources(
        effectiveMode,
        inputDir,
        videoInputPath,
        desktopInteractivePreview,
      );
    const prev = prevNeedsSourcesAttentionRef.current;
    if (next && !prev) {
      setOpenSections((s) => ({ ...s, sources: true }));
    }
    prevNeedsSourcesAttentionRef.current = next;
  }, [desktopInteractivePreview, effectiveMode, inputDir, videoInputPath]);

  const handleBatchJobModeChange = (nextMode: BatchJobMode) => {
    if (exportSurface) return;
    if (nextMode === batchJobMode) return;
    setOpenSections(
      createDefaultOpenSections(
        nextMode,
        inputDir,
        videoInputPath,
        batchLookSource,
        desktopInteractivePreview,
      ),
    );
    onBatchJobModeChange(nextMode);
  };

  const toggleSection = (id: AccordionStepId) => {
    setOpenSections((prev) => ({ ...prev, [id]: !prev[id] }));
  };

  const isSectionSynced = (id: AccordionStepId): boolean =>
    id === "look" && batchLookSource !== "preset";

  const isSectionComplete = (id: AccordionStepId): boolean => {
    switch (id) {
      case "sources":
        return sourcesComplete;
      case "look":
        return true;
      case "output":
        return isImagesMode ? Boolean(outputDir) : true;
    }
  };

  const getSectionSummary = (id: AccordionStepId): string | null => {
    switch (id) {
      case "sources":
        if (isImagesMode) {
          return inputDir ? lastPathSegment(inputDir) : null;
        }
        return videoInputPath ? lastPathSegment(videoInputPath) : null;
      case "look":
        return batchLookSource === "analysisRecommendation"
          ? lookStatusBanner.body || lookStatusBanner.title
          : lookStatusBanner.title;
      case "output":
        if (isImagesMode) {
          return outputDir
            ? `${batchFormat.toUpperCase()} → ${lastPathSegment(outputDir)}`
            : null;
        }
        return outputDir ? lastPathSegment(outputDir) : null;
    }
  };

  const missingItems: { label: string; section: AccordionStepId }[] = [];
  if (!sourcesComplete) {
    missingItems.push({
      label: isImagesMode ? t("pickImageFolderTitle") : t("pickVideoFileTitle"),
      section: "sources",
    });
  }
  if (isImagesMode && !outputDir) {
    missingItems.push({ label: t("outputImageTitle"), section: "output" });
  }

  /* ── Section renderers ── */

  const renderJobModeToggle = (): ReactElement => (
    <div
      className="fl-segment"
      role="radiogroup"
      aria-label={t("jobTypeQuestion")}
    >
      <button
        type="button"
        role="radio"
        aria-checked={isImagesMode}
        className={`fl-segment-option ${isImagesMode ? "fl-segment-option--active" : ""}`}
        onClick={() => handleBatchJobModeChange("images")}
      >
        {t("jobImagesTitle")}
      </button>
      <button
        type="button"
        role="radio"
        aria-checked={!isImagesMode}
        className={`fl-segment-option ${!isImagesMode ? "fl-segment-option--active" : ""}`}
        onClick={() => handleBatchJobModeChange("video")}
      >
        {t("jobVideoTitle")}
      </button>
    </div>
  );

  const renderSourcesSection = (): ReactElement => (
    <div className="flex flex-col gap-3">
      {isImagesMode ? (
        <>
          <p className="fl-field-label">{t("pickImageFolderTitle")}</p>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              onClick={() => void onPickInputDir()}
            >
              {t("pickInputFolderBtn")}
            </button>
            <span
              className="fl-caption min-w-0 flex-1 truncate"
              title={inputDir ?? undefined}
            >
              {inputDir ?? t("notSelected")}
            </span>
          </div>
        </>
      ) : (
        <>
          <p className="fl-field-label">{t("pickVideoFileTitle")}</p>
          <p className="fl-caption text-[var(--fl-text-tertiary)]">
            {t("videoSourceHint", { maxSec: String(VIDEO_IMPORT_MAX_DURATION_SEC) })}
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              disabled={running}
              onClick={() => void onPickVideoFile()}
            >
              {t("pickVideoBtn")}
            </button>
            <span
              className="fl-caption min-w-0 flex-1 truncate"
              title={videoInputPath ?? undefined}
            >
              {videoInputPath ?? t("notSelected")}
            </span>
          </div>
          {videoProbeLabel ? (
            <p className="fl-caption max-w-prose text-[var(--fl-text-secondary)]">
              {videoProbeLabel}
            </p>
          ) : null}
          <HdrPolicyNotice
            policy={videoHdrPolicy}
            onOpenFixtureDoc={onOpenHdrFixtureDoc}
          />
        </>
      )}
    </div>
  );

  const renderLookSection = (): ReactElement => {
    const LookStatusIcon = lookStatusBanner.Icon;
    return (
      <div className="flex flex-col gap-3">
        <div className="flex gap-2.5" role="status" aria-live="polite">
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
            {lookStatusBanner.body.trim().length > 0 ? (
              <p className="fl-caption mt-0.5 max-w-prose text-[var(--fl-text-secondary)]">
                {lookStatusBanner.body}
              </p>
            ) : null}
          </div>
        </div>

        <div className="flex flex-col gap-2 border-t border-white/10 pt-3">
          <button
            type="button"
            className="fl-btn-secondary self-start"
            disabled={running || !canApplyEditGradeToBatch}
            title={canApplyEditGradeToBatch ? undefined : t("applyEditWaitHint")}
            onClick={onApplyEditGradeToBatch}
          >
            {t("applyEditToExportBtn")}
          </button>
          <button
            type="button"
            className="fl-btn-secondary self-start"
            disabled={running}
            onClick={() => void onImportGradeJson()}
          >
            {t("loadMetadataJsonBtn")}
          </button>
        </div>

        {batchLookSource === "editSync" || batchLookSource === "analysisRecommendation" ? (
          <div className="flex max-w-md flex-col gap-2 border-t border-white/10 pt-3">
            <span className="fl-label">{t("presetQuickLabel")}</span>
            <p className="fl-caption max-w-prose text-[var(--fl-text-secondary)]">
              {batchLookSource === "editSync"
                ? t("lookPresetHiddenWhileSyncedBody", {
                    preset: formatPresetChoiceLabel(batchPresetChoice),
                  })
                : t("lookPresetHiddenWhileRecommendedBody", {
                    preset: formatPresetChoiceLabel(batchPresetChoice),
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
          <label className="flex max-w-md flex-col gap-1.5 border-t border-white/10 pt-3">
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
                  {formatPresetChoiceLabel(n)}
                </option>
              ))}
            </select>
          </label>
        )}
      </div>
    );
  };

  const renderOutputSection = (): ReactElement => (
    <div className="flex flex-col gap-3">
      {isImagesMode ? (
        <>
          <p className="fl-field-label">{t("outputImageTitle")}</p>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              onClick={() => void onPickOutputDir()}
            >
              {t("pickOutputFolderBtn")}
            </button>
            <span
              className="fl-caption min-w-0 flex-1 truncate"
              title={outputDir ?? undefined}
            >
              {outputDir ?? t("notSelected")}
            </span>
          </div>
          <label className="flex max-w-md flex-col gap-1.5">
            <span className="fl-label normal-case">
              {t("filenameSuffixLabel")}
            </span>
            <input
              type="text"
              className="fl-text-input w-full max-w-md"
              value={batchOutputSuffix}
              onChange={(e) => onBatchOutputSuffixChange(e.target.value)}
              autoComplete="off"
              spellCheck={false}
              placeholder={t("filenameSuffixPlaceholder")}
            />
          </label>
        </>
      ) : (
        <>
          <p className="fl-field-label">{t("videoOutputFolderTitle")}</p>
          <p className="fl-caption text-[var(--fl-text-tertiary)]">
            {t("videoOutputHint", { fps: String(VIDEO_EXPORT_FALLBACK_FPS) })}
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              onClick={() => void onPickOutputDir()}
            >
              {t("pickOutputFolderBtn")}
            </button>
            <span
              className="fl-caption min-w-0 flex-1 truncate"
              title={outputDir ?? undefined}
            >
              {outputDir ?? t("videoOutputDirUnset")}
            </span>
          </div>
        </>
      )}
    </div>
  );

  const accordionRenderers: Record<AccordionStepId, () => ReactElement> = {
    sources: renderSourcesSection,
    look: renderLookSection,
    output: renderOutputSection,
  };

  /* ── Footer (run) ── */

  const renderFooter = (): ReactElement => (
    <section
      className="fl-card fl-card--frost gap-3"
      aria-labelledby="export-run-heading"
    >
      <h3 id="export-run-heading" className="sr-only">
        {stepLabels.run}
      </h3>

      {isImagesMode ? (
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
            disabled={!batchCanRun}
            onClick={() => void onRunBatch()}
          >
            {running ? t("runAbort") : t("runImagesPrimary")}
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
            className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
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
                  Math.round(
                    (batchProgress.current / batchProgress.total) * 100,
                  ),
                )}%`,
              }}
            />
          </div>
          <p className="fl-caption">
            {batchProgress.current} / {batchProgress.total} ·{" "}
            {batchProgress.fileName}
          </p>
        </div>
      ) : null}

      {isImagesMode && lastBatchSummary && !running ? (
        <p className="fl-caption" aria-live="polite">
          {t("lastSummary", {
            ok: String(lastBatchSummary.ok),
            loadFail: String(lastBatchSummary.loadFail),
            writeFail: String(lastBatchSummary.writeFail),
          })}
        </p>
      ) : null}

      {missingItems.length > 0 && !running ? (
        <div className="flex flex-col gap-1.5">
          {missingItems.map((item) => (
            <button
              key={item.section}
              type="button"
              className="flex items-center gap-1.5 text-left text-xs text-[var(--amber-11)] hover:underline"
              onClick={() => {
                setOpenSections((prev) => ({ ...prev, [item.section]: true }));
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
  );

  /* ── JSX ── */

  return (
    <>
      {/* 画面タイトル — compact 時は省略（右パネル内で扱うため） */}
      {!compact ? (
        <header className="flex flex-col gap-1">
          <h2
            id="export-tab-intro-heading"
            className="text-lg font-semibold text-[var(--fl-text-primary)]"
          >
            {exportSurface === "images"
              ? t("photoExportPanelTitle")
              : exportSurface === "video"
                ? t("videoExportPanelTitle")
                : t("exportTitle")}
          </h2>
          <p className="fl-caption text-[var(--fl-text-secondary)]">
            {isImagesMode ? t("exportLeadImages") : t("exportLeadVideo")}
          </p>
        </header>
      ) : null}

      {/* Preset strip — DaVinci 型、画面最上部の横 1 行 */}
      <PresetStrip
        isImagesMode={isImagesMode}
        batchFormat={batchFormat}
        batchOutputSuffix={batchOutputSuffix}
        onBatchFormatChange={onBatchFormatChange}
        onBatchOutputSuffixChange={onBatchOutputSuffixChange}
        disabled={running}
      />

      {/* § 1 ジョブ — 単一「書き出し」タブのときだけ（トップで写真／動画が分かれているときは省略） */}
      {!exportSurface ? (
        <section
          className="fl-card fl-card--frost gap-2"
          aria-labelledby="export-job-selector-heading"
        >
          <p id="export-job-selector-heading" className="fl-field-label">
            {t("jobTypeQuestion")}
          </p>
          {renderJobModeToggle()}
        </section>
      ) : null}

      {/* Session resume — inline（前回未完了の写真バッチ復元用、banner ではなく 1 行＋ボタン） */}
      {isImagesMode && persistedSession && sessionHasRemainingWork(persistedSession) ? (
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-xs text-[var(--fl-text-secondary)]">
            {t("resumeLeadImages", {
              remaining: String(pathsNotSucceeded(persistedSession).length),
            })}
          </p>
          <button
            type="button"
            className="fl-btn-primary"
            disabled={!batchCanResume}
            onClick={() => void onResumeBatch()}
          >
            {t("resumeBtn")}
          </button>
          <button
            type="button"
            className="fl-btn-secondary"
            disabled={running}
            onClick={() => void onDiscardPersistedSession()}
          >
            {t("discardSessionBtn")}
          </button>
        </div>
      ) : null}

      {/* Accordion — sources / look / output の 3 セクション */}
      <div
        className={`flex flex-col divide-y divide-white/10 ${
          compact ? "mt-1 gap-0" : "fl-card fl-card--frost gap-0 p-0"
        }`}
      >
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
                className={`flex w-full items-center gap-2.5 text-left transition-colors hover:bg-white/[0.04] focus-visible:bg-white/[0.06] focus-visible:outline-none ${
                  compact ? "py-3 pl-4 pr-3" : "px-4 py-3"
                }`}
                onClick={() => toggleSection(id)}
                aria-expanded={isOpen}
                aria-controls={`export-step-body-${id}`}
              >
                {complete ? (
                  <CheckCircle
                    className="shrink-0 text-[var(--fl-text-secondary)]"
                    size={16}
                    weight="fill"
                    aria-hidden
                  />
                ) : needsAttention ? (
                  <WarningCircle
                    className="shrink-0 text-[var(--amber-11)]"
                    size={16}
                    weight="bold"
                    aria-hidden
                  />
                ) : (
                  <Circle
                    className="shrink-0 text-[var(--fl-text-tertiary)]"
                    size={16}
                    aria-hidden
                  />
                )}
                <span className="flex min-w-0 flex-1 items-center gap-2.5">
                  <span className="text-sm font-medium leading-snug text-[var(--fl-text-primary)]">
                    {stepLabels[id]}
                  </span>
                  {synced ? (
                    <span className="fl-badge-synced">
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
                  className="px-4 pb-4 pt-2"
                >
                  {accordionRenderers[id]()}
                </div>
              ) : null}
            </div>
          );
        })}
      </div>

      {/* Advanced disclosure — proxy cache / preview-export bridge（既定閉） */}
      <section
        className={compact ? "" : "fl-card fl-card--frost gap-2 py-3"}
        aria-label={t("advancedDisclosureTitle")}
      >
        <AdvancedDisclosure
          previewExportBridge={previewExportBridge}
          proxyCacheInfo={proxyCacheInfo}
          isPurgingProxyCache={isPurgingProxyCache}
          running={running}
          onPurgeProxyCache={onPurgeProxyCache}
        />
      </section>

      {/* Footer (run) — full page 時のみ panel 内。compact は App.tsx の sticky footer へ */}
      {!compact ? renderFooter() : null}
    </>
  );
}
