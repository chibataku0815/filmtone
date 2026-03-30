/**
 * @fileoverview Film Lab デスクトップの「書き出し」タブ用パネル（内部コード名 batch と向き合わせない UI）
 *
 * @description
 * ユーザー向けには「バッチ」ではなく**書き出し・フォルダの写真をまとめて**など写真用語で説明する。
 * 「次」の案内は**手順ナビを主**にし、上部は展開時は複数行＋移動、**折りたたみ時は一行チップ**にできる（`localStorage` で記憶、**未設定時は展開**）。
 * 手順は番号付きブロックと、任意の 1 ステップ表示の切替で整理する。
 * 状態（BatchGradeState / IPC）は持たず、親の App から渡されたコールバックだけを呼ぶ。
 * ルック段の「編集のスライダーを書き出しに反映」は編集フッターと同じ同期処理（viewport 準備済みのときだけ活性）。
 *
 * @limitations
 * - キーボードショートカットは App 側。ジョブ種別は親 state と同期する。
 * - ステップ番号は UI ローカル。タブを切り替えてもリセットしない（必要なら親で key を付ける）。
 * - 手順の一覧/1画面は localStorage で覚える。初回は 1 画面ずつを既定にし、初回書き出し成功後は一覧へ寄せる。
 */

import {
  CaretDown,
  CaretUp,
  CheckCircle,
  Circle,
  File,
} from "@phosphor-icons/react";
import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactElement,
} from "react";
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

/** @description ウィザード風のステップ識別子（表示順と対応） */
type BatchStepId = "jobType" | "sources" | "look" | "output" | "run";

const BATCH_STEP_ORDER: BatchStepId[] = [
  "jobType",
  "sources",
  "look",
  "output",
  "run",
];

/**
 * @description 手順を「一覧」か「1画面ずつ」かのユーザー選択（初回は未設定でよい）
 * @limitations 読めない環境では既定のウィザード表示にフォールバックする
 */
const LS_EXPORT_STEP_LAYOUT = "filmLab.export.stepLayoutPref";

/**
 * @description 初めて書き出しに成功したあと 1 を入れ、以降は初回ウィザード既定を使わない印
 */
const LS_EXPORT_FIRST_SUCCESS = "filmLab.export.firstExportDone";

/**
 * @description 「次にやること」帯を展開するか。`1` = 展開、`0` = 折りたたみ。**キーが無いときは展開**（初回のみ広い案内を見せる）
 */
const LS_EXPORT_NEXT_STRIP_EXPANDED = "filmLab.export.nextStripExpanded";

/**
 * @description 手順表示の初期値。localStorage に明示がなければ 1 画面ずつ（ウィザード）を既定にする。
 * @returns {boolean} true なら全手順一覧、false なら 1 画面ずつ
 */
function readInitialShowAllSteps(): boolean {
  try {
    if (typeof localStorage === "undefined") return false;
    const pref = localStorage.getItem(LS_EXPORT_STEP_LAYOUT);
    if (pref === "list") return true;
    if (pref === "wizard") return false;
    return false;
  } catch {
    return false;
  }
}

/**
 * @description チェックボックスで一覧/ウィザードを切り替えたときに保存する（次回起動も覚える）
 * @param showAllSteps - true なら全手順を一覧表示
 */
function persistStepLayoutPref(showAllSteps: boolean): void {
  try {
    localStorage.setItem(LS_EXPORT_STEP_LAYOUT, showAllSteps ? "list" : "wizard");
  } catch {
    /* ストレージ無効時は握りつぶす */
  }
}

/**
 * @description 初回の書き出し成功後に一覧表示へ切り替え、フラグを保存する（2回目以降は何もしない）
 * @param setShowAllSteps - React の setter（一覧表示 true を渡す）
 */
function markFirstExportSuccessAndPreferList(
  setShowAllSteps: (showAll: boolean) => void,
): void {
  try {
    if (typeof localStorage === "undefined") {
      setShowAllSteps(true);
      return;
    }
    if (localStorage.getItem(LS_EXPORT_FIRST_SUCCESS) === "1") return;
    localStorage.setItem(LS_EXPORT_FIRST_SUCCESS, "1");
    localStorage.setItem(LS_EXPORT_STEP_LAYOUT, "list");
    setShowAllSteps(true);
  } catch {
    setShowAllSteps(true);
  }
}

/**
 * @description 「次にやること」帯の展開初期値。保存が無い・読めないときは **展開（true）**。
 * @returns {boolean} true ならフル帯、false なら一行チップ
 */
function readInitialNextStripExpanded(): boolean {
  try {
    if (typeof localStorage === "undefined") return true;
    return localStorage.getItem(LS_EXPORT_NEXT_STRIP_EXPANDED) !== "0";
  } catch {
    return true;
  }
}

/**
 * @description 帯の開閉を次回起動まで覚える（`0` / `1` で保存）
 * @param expanded - true でフル表示、false で一行チップ
 */
function persistNextStripExpanded(expanded: boolean): void {
  try {
    if (typeof localStorage === "undefined") return;
    localStorage.setItem(LS_EXPORT_NEXT_STRIP_EXPANDED, expanded ? "1" : "0");
  } catch {
    /* プライベートモード等では無視 */
  }
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

  /**
   * @description 動画書き出しが成功するたびに App が 1 増やす番号。初回成功で一覧表示へ誘導するためだけに使う。
   */
  videoExportSuccessNonce: number;

  /**
   * @description 編集タブの Viewport が使えるとき true。false のとき「編集のスライダーを反映」は押せない。
   */
  canApplyEditGradeToBatch: boolean;
  /**
   * @description 編集タブのプレビューから BatchGradeState へ数値をコピー（App の syncPreviewToBatch と同一）。
   */
  onApplyEditGradeToBatch: () => void;
  /**
   * @description 直近の「編集→反映」成功時刻（ms）。null なら表示上は JSON またはプリセット起点扱い。
   */
  editToExportSyncedAtMs: number | null;
  /**
   * @description いまの `batchPresetChoice` を film-lab-core の初期値で焼き直し、編集同期をやめる（App の applyBatchPreset と同系）。
   */
  onReapplyBatchPresetBaseline: () => void;
};

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
    // 動画は未設定でも実行時にダイアログで選べるため「推奨」のみ
    outputOk: Boolean(outputDir),
  };
}

/**
 * @description ステップ 1（入力）が完了とみなせるか（「次へ」の活性に使う）
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
  // 動画は出力未指定でも実行可能（実行時ピック）
  return true;
}

/**
 * @description 単一ステップの中身を描画する内部ブロック用のインデックス
 */
function batchStepIndex(id: BatchStepId): number {
  return BATCH_STEP_ORDER.indexOf(id);
}

/**
 * @description 手順ナビ用：各ステップが「済」か（実行以外）。ルックは読み込み元が済みなら済扱い（プリセット既定あり）。
 */
function isNavStepComplete(
  stepId: BatchStepId,
  batchJobMode: BatchJobMode,
  sourcesComplete: boolean,
  outputDir: string | null,
): boolean {
  switch (stepId) {
    case "jobType":
      return true;
    case "sources":
      return sourcesComplete;
    case "look":
      return sourcesComplete;
    case "output":
      return batchJobMode === "images" ? Boolean(outputDir) : true;
    case "run":
      return false;
    default:
      return false;
  }
}

/**
 * @description いまユーザーが進めるべき主な手順のインデックス（1=読み込み元, 3=保存先, 4=実行）。
 * ルック（2）は必須ブロックにしないが、ナビでは読み込み後にチェック表示する。
 */
function getNextBlockingStepIndex(
  batchJobMode: BatchJobMode,
  sourcesComplete: boolean,
  outputDir: string | null,
): number {
  if (!sourcesComplete) return batchStepIndex("sources");
  if (batchJobMode === "images" && !outputDir) {
    return batchStepIndex("output");
  }
  return batchStepIndex("run");
}

/**
 * @description 書き出しタブのメインパネル（説明・警告・セッション・手順 UI・ログ前まで）
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
    videoExportSuccessNonce,
    canApplyEditGradeToBatch,
    onApplyEditGradeToBatch,
    editToExportSyncedAtMs,
    onReapplyBatchPresetBaseline,
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

  /**
   * @description 「次にやること」バナー用の長めの説明（title 属性）
   */
  const nextBlockingBannerText = useCallback(
    (nextId: BatchStepId, mode: BatchJobMode) => {
      switch (nextId) {
        case "sources":
          return mode === "images"
            ? t("nextBannerSourcesImages")
            : t("nextBannerSourcesVideo");
        case "output":
          return t("nextBannerOutput");
        case "run":
          return mode === "images"
            ? t("nextBannerRunImages")
            : t("nextBannerRunVideo");
        default:
          return t("nextBannerDefault");
      }
    },
    [t],
  );

  /**
   * @description 帯に並べる短い「次の一手」
   */
  const nextBlockingInlineHint = useCallback(
    (nextId: BatchStepId, mode: BatchJobMode) => {
      switch (nextId) {
        case "sources":
          return mode === "images"
            ? t("nextInlineSourcesImages")
            : t("nextInlineSourcesVideo");
        case "output":
          return t("nextInlineOutput");
        case "run":
          return mode === "images"
            ? t("nextInlineRunImages")
            : t("nextInlineRunVideo");
        default:
          return t("nextInlineDefault");
      }
    },
    [t],
  );

  /** @description 現在のステップ（0 始まり）。ジョブ種別が変わったら 0 に戻す */
  const [activeStep, setActiveStep] = useState(0);
  /**
   * @description true のときは手順を最初から縦に並べて表示。false のときは 1 ステップずつ（ウィザード）。
   * 初回は localStorage に偏好がなければ false（ウィザード既定）。一覧チェックまたは初回書き出し成功後は一覧へ寄せる。
   */
  const [showAllSteps, setShowAllSteps] = useState(() => readInitialShowAllSteps());
  /** @description ルックの「JSON / ファイル」詳細（デフォルト閉じる） */
  const [lookAdvancedOpen, setLookAdvancedOpen] = useState(false);
  /**
   * @description 上部「次にやること」帯。初回・未保存時は展開、折りたたみ時は一行チップ＋開く操作。
   */
  const [nextStripExpanded, setNextStripExpanded] = useState(() =>
    readInitialNextStripExpanded(),
  );

  useEffect(() => {
    setActiveStep(0);
  }, [batchJobMode]);

  /**
   * @description 写真のまとめて書き出しが初めて成功したら一覧表示へ切り替え（中断・全失敗は除外）
   */
  useEffect(() => {
    if (running) return;
    const s = lastBatchSummary;
    if (!s || s.aborted || s.ok < 1) return;
    markFirstExportSuccessAndPreferList(setShowAllSteps);
  }, [lastBatchSummary, running]);

  /** @description 動画書き出し成功のたびに nonce が増えるので、初回成功時は写真と同じく一覧へ誘導する */
  const prevVideoSuccessNonceRef = useRef(videoExportSuccessNonce);
  useEffect(() => {
    if (videoExportSuccessNonce <= prevVideoSuccessNonceRef.current) return;
    prevVideoSuccessNonceRef.current = videoExportSuccessNonce;
    markFirstExportSuccessAndPreferList(setShowAllSteps);
  }, [videoExportSuccessNonce]);

  const { sourceOk, outputOk } = getSourceOutputStatus(
    batchJobMode,
    inputDir,
    outputDir,
    videoInputPath,
  );
  const sourcesComplete = isSourcesStepComplete(
    batchJobMode,
    inputDir,
    videoInputPath,
  );
  const outputComplete = isOutputStepComplete(batchJobMode, outputDir);

  const canGoNext =
    activeStep < BATCH_STEP_ORDER.length - 1 &&
    (activeStep !== batchStepIndex("sources") || sourcesComplete) &&
    (activeStep !== batchStepIndex("output") || outputComplete);

  const goNext = () => {
    if (!canGoNext) return;
    setActiveStep((s) => Math.min(s + 1, BATCH_STEP_ORDER.length - 1));
  };

  const goPrev = () => {
    setActiveStep((s) => Math.max(0, s - 1));
  };

  const jumpStep = (idx: number) => {
    setActiveStep(Math.max(0, Math.min(idx, BATCH_STEP_ORDER.length - 1)));
  };

  /** @description 一覧表示時に手順ブロックへ scroll するための参照 */
  const sectionElRefs = useRef<Partial<Record<BatchStepId, HTMLElement | null>>>(
    {},
  );

  const nextBlockingIdx = getNextBlockingStepIndex(
    batchJobMode,
    sourcesComplete,
    outputDir,
  );
  const nextBlockingStepId = BATCH_STEP_ORDER[nextBlockingIdx];

  /**
   * @description 1 手順ブロックへスクロールし、1 画面モードならその段に切り替える
   */
  const focusExportStep = useCallback(
    (stepId: BatchStepId) => {
      const idx = batchStepIndex(stepId);
      if (!showAllSteps) setActiveStep(idx);
      requestAnimationFrame(() => {
        sectionElRefs.current[stepId]?.scrollIntoView({
          behavior: "smooth",
          block: "center",
        });
      });
    },
    [showAllSteps],
  );

  /**
   * @description 手順ナビ 1 ボタン分（チェック・次へのハイライトつき）
   */
  const renderStepNavButton = (stepId: BatchStepId, idx: number) => {
    const stepDone = isNavStepComplete(
      stepId,
      batchJobMode,
      sourcesComplete,
      outputDir,
    );
    const isNext = !running && idx === nextBlockingIdx;
    const isWizardPage = !showAllSteps && activeStep === idx;
    return (
      <button
        key={stepId}
        type="button"
        className={`fl-batch-step-nav-btn flex items-center gap-1 rounded-md border px-2 py-1.5 text-left text-xs font-medium transition-colors ${
          isNext
            ? "border-[var(--amber-9)] bg-[var(--fl-bg-subtle)] font-semibold text-[var(--fl-text-primary)] shadow-[inset_3px_0_0_0_var(--amber-9)]"
            : isWizardPage
              ? "border-[var(--amber-8)] bg-[var(--amber-3)] text-[var(--amber-12)]"
              : "border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] text-[var(--fl-text-secondary)] hover:bg-[var(--fl-bg-interactive)]"
        }`}
        aria-current={isWizardPage ? "step" : undefined}
        title={
          isNext
            ? t("stepNavTitleNext")
            : stepDone
              ? t("stepNavTitleDone")
              : t("stepNavTitleGoto")
        }
        onClick={() => {
          jumpStep(idx);
          focusExportStep(stepId);
        }}
      >
        {stepDone ? (
          <CheckCircle className="shrink-0 text-[var(--amber-11)]" size={16} weight="fill" aria-hidden />
        ) : (
          <Circle className="shrink-0 text-[var(--fl-text-tertiary)]" size={16} aria-hidden />
        )}
        <span>
          <span className="tabular-nums text-[0.65rem] text-[var(--fl-text-tertiary)]">
            {idx + 1}
          </span>{" "}
          {stepLabels[stepId]}
        </span>
      </button>
    );
  };

  /**
   * @description ステップ 0: ジョブの種類
   */
  const renderStepJobType = () => (
    <div className="flex flex-col gap-3" role="group" aria-labelledby="batch-step-job-type-title">
      <p id="batch-step-job-type-title" className="text-sm font-medium text-[var(--fl-text-primary)]">
        {t("jobTypeQuestion")}
      </p>
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
    </div>
  );

  /**
   * @description ステップ 1: 入力（画像はフォルダ、動画はファイル）
   */
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

  /**
   * @description ステップ 2: ルック（プリセット＋詳細アコーディオン）
   */
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
          size={22}
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

  /**
   * @description ステップ 3: 出力先・形式
   */
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

  /**
   * @description ステップ 4: 実行・進捗
   */
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

  const stepRenderers: Record<BatchStepId, () => ReactElement> = {
    jobType: renderStepJobType,
    sources: renderStepSources,
    look: renderStepLook,
    output: renderStepOutput,
    run: renderStepRun,
  };

  /**
   * @description 1 ステップ分をカード風に包む（一覧表示用）
   */
  const renderStepSection = (stepId: BatchStepId, idx: number) => {
    const isHighlight = !running && stepId === nextBlockingStepId;
    return (
      <section
        key={stepId}
        ref={(el) => {
          sectionElRefs.current[stepId] = el;
        }}
        id={`export-step-${stepId}`}
        className={`flex flex-col gap-3 border-b border-[var(--fl-border-subtle)] pb-4 last:border-b-0 last:pb-0 ${
          isHighlight
            ? "scroll-mt-4 rounded-md border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] py-2 pl-3 pr-2 shadow-[inset_3px_0_0_0_var(--amber-9)]"
            : ""
        }`}
        aria-labelledby={`batch-step-h-${stepId}`}
      >
        <h3 id={`batch-step-h-${stepId}`} className="fl-label normal-case tracking-normal">
          {idx + 1}. {stepLabels[stepId]}
        </h3>
        {stepRenderers[stepId]()}
      </section>
    );
  };

  return (
    <>
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

      <div className="self-start rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2 text-xs leading-relaxed text-[var(--fl-text-secondary)] shadow-[inset_3px_0_0_0_var(--amber-9)]">
        {t("differentFolderWarning")}
      </div>

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

      {!running ? (
        nextStripExpanded ? (
          <div
            className="fl-export-next-strip flex flex-wrap items-center gap-x-3 gap-y-2 px-3 py-2"
            role="region"
            aria-label={t("nextStripRegionAria")}
            aria-live="polite"
            title={nextBlockingBannerText(nextBlockingStepId, batchJobMode)}
          >
            <span className="tabular-nums text-xs font-semibold text-[var(--fl-text-primary)]">
              {nextBlockingIdx + 1}. {stepLabels[nextBlockingStepId]}
            </span>
            <span className="min-w-0 flex-1 basis-[14rem] text-xs leading-snug text-[var(--fl-text-secondary)]">
              {nextBlockingInlineHint(nextBlockingStepId, batchJobMode)}
            </span>
            <div className="flex shrink-0 flex-wrap items-center gap-1.5">
              <button
                type="button"
                className="fl-btn-secondary px-2.5 py-1 text-[0.65rem]"
                onClick={() => focusExportStep(nextBlockingStepId)}
              >
                {t("nextStripGo")}
              </button>
              <button
                type="button"
                className="fl-btn-secondary inline-flex items-center gap-0.5 px-2 py-1 text-[0.65rem]"
                aria-expanded="true"
                onClick={() => {
                  setNextStripExpanded(false);
                  persistNextStripExpanded(false);
                }}
              >
                <CaretUp className="h-3.5 w-3.5 shrink-0" aria-hidden />
                {t("nextStripCollapse")}
              </button>
            </div>
          </div>
        ) : (
          <div
            className="fl-export-next-strip flex flex-nowrap items-center gap-2 px-2.5 py-1.5"
            role="region"
            aria-label={t("nextStripRegionAria")}
            aria-live="polite"
            title={nextBlockingBannerText(nextBlockingStepId, batchJobMode)}
          >
            <span className="min-w-0 flex-1 truncate text-xs leading-snug text-[var(--fl-text-secondary)]">
              <span className="font-semibold tabular-nums text-[var(--fl-text-primary)]">
                {nextBlockingIdx + 1}. {stepLabels[nextBlockingStepId]}
              </span>
              <span className="text-[var(--fl-text-tertiary)]"> · </span>
              {nextBlockingInlineHint(nextBlockingStepId, batchJobMode)}
            </span>
            <button
              type="button"
              className="fl-btn-secondary shrink-0 px-2 py-1 text-[0.65rem]"
              onClick={() => focusExportStep(nextBlockingStepId)}
            >
              {t("nextStripGo")}
            </button>
            <button
              type="button"
              className="fl-btn-secondary inline-flex shrink-0 items-center gap-0.5 px-2 py-1 text-[0.65rem]"
              aria-expanded="false"
              onClick={() => {
                setNextStripExpanded(true);
                persistNextStripExpanded(true);
              }}
            >
              <CaretDown className="h-3.5 w-3.5 shrink-0" aria-hidden />
              {t("nextStripExpand")}
            </button>
          </div>
        )
      ) : (
        <p className="rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2 text-xs text-[var(--fl-text-secondary)]">
          {t("runningNotice")}
        </p>
      )}

      <section className="fl-card fl-card--frost gap-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between">
          <p className="text-sm font-medium text-[var(--fl-text-primary)]">
            {t("workflowNavCaption")}
          </p>
          <div className="flex flex-wrap gap-1.5" role="tablist" aria-label={t("workflowNavAria")}>
            {BATCH_STEP_ORDER.map((id, idx) => renderStepNavButton(id, idx))}
          </div>
        </div>

        <div className="flex flex-wrap gap-2 text-[0.65rem]">
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

        <label className="flex cursor-pointer items-center gap-2 text-xs text-[var(--fl-text-secondary)]">
          <input
            type="checkbox"
            checked={showAllSteps}
            onChange={(e) => {
              const next = e.target.checked;
              setShowAllSteps(next);
              persistStepLayoutPref(next);
            }}
            className="h-3.5 w-3.5 rounded border-[var(--fl-border-default)]"
          />
          {t("showAllStepsLabel")}
        </label>

        {!showAllSteps ? (
          <div
            ref={(el) => {
              const id = BATCH_STEP_ORDER[activeStep];
              sectionElRefs.current[id] = el;
            }}
            id={`export-step-${BATCH_STEP_ORDER[activeStep]}`}
            className={`min-h-[12rem] rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] p-4 ${
              !running && BATCH_STEP_ORDER[activeStep] === nextBlockingStepId
                ? "shadow-[inset_3px_0_0_0_var(--amber-9)]"
                : ""
            }`}
          >
            {stepRenderers[BATCH_STEP_ORDER[activeStep]]()}
          </div>
        ) : (
          <div className="flex flex-col gap-6">
            {BATCH_STEP_ORDER.map((id, idx) => renderStepSection(id, idx))}
          </div>
        )}

        {!showAllSteps ? (
          <div className="flex flex-wrap items-center justify-between gap-2 border-t border-[var(--fl-border-subtle)] pt-3">
            <button
              type="button"
              className="fl-btn-secondary"
              disabled={activeStep <= 0}
              onClick={goPrev}
            >
              {t("wizardBack")}
            </button>
            <button type="button" className="fl-btn-primary" disabled={!canGoNext} onClick={goNext}>
              {t("wizardNext")}
            </button>
          </div>
        ) : null}
      </section>

      <div className="flex flex-wrap items-center gap-1.5">
        <p className="fl-caption">{t("prefsFootnote")}</p>
        <HelpHint tip={t("tipDesktopPrefsPersist")} assistiveLabel={t("prefsFootnoteAria")} />
      </div>
    </>
  );
}
