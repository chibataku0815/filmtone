/**
 * @fileoverview Film Lab デスクトップの「書き出し」タブ用パネル（内部コード名 batch と向き合わせない UI）
 *
 * @description
 * ユーザー向けには「バッチ」ではなく**書き出し・フォルダの写真をまとめて**など写真用語で説明する。
 * 手順は番号付きブロックと、任意の 1 ステップ表示の切替で整理する。
 * 状態（BatchGradeState / IPC）は持たず、親の App から渡されたコールバックだけを呼ぶ。
 *
 * @limitations
 * - キーボードショートカットは App 側。ジョブ種別は親 state と同期する。
 * - ステップ番号は UI ローカル。タブを切り替えてもリセットしない（必要なら親で key を付ける）。
 * - 手順の一覧/1画面は localStorage で覚える。初回は 1 画面ずつを既定にし、初回書き出し成功後は一覧へ寄せる。
 */

import { CheckCircle, Circle } from "@phosphor-icons/react";
import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ReactElement,
} from "react";
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

const BATCH_STEP_LABELS: Record<BatchStepId, string> = {
  jobType: "やること",
  sources: "読み込み元",
  look: "ルック",
  output: "保存先と形式",
  run: "実行",
};

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

/** @description ツールチップ用の長文（本文では短く済む） */
const TIP_EXPORT_TAB_INTRO =
  "パソコン上のフォルダに入っている写真を、Film Lab で整えた見え方のまま別フォルダへまとめて保存できます。動画を1本、同じ見え方でMP4にすることもできます。編集タブでスライダーを触ったあと、編集タブ右下の「色を書き出しへ送る」で数値をこちらに送れます。LUT（ルックアップテーブル）はJSONの読み込みなどで別途。";

const TIP_JOB_IMAGES =
  "選んだフォルダにある .jpg / .jpeg / .png すべてに、いまのルックを載せて JPEG か PNG で別フォルダに保存します。";

const TIP_JOB_VIDEO_FAST_OPTION =
  "既定は高速 ffmpeg 経由（FHD・Params は ffmpeg 近似・プレビューと一致しません）。プレビューに近くしたいときは手順の「保存先と形式」で WebGL 逐次をオンにできます（非常に遅い）。PATH に ffmpeg / ffprobe が必要です。";

const TIP_JOB_VIDEO_WEBGL_ONLY =
  "いまはプレビューに近い見え方で書き出す WebGL 逐次のみ（時間がかかります）。高速 ffmpeg 1 パスは製品準備中のため UI から隠しています。PATH に ffmpeg / ffprobe が必要です。";

const TIP_SOURCES_IMAGES_FOLDER =
  "そのフォルダ直下の .jpg / .jpeg / .png だけが対象です。動画ファイルの変換には使いません。";

const TIP_SOURCES_VIDEO_FILE = (maxSec: number) =>
  `読込上限は 4K・最大 ${maxSec} 秒です。PATH に ffmpeg / ffprobe が必要です。`;

const TIP_LOOK_JSON_DETAILS =
  "LUT を含むルックをファイルで渡したり保存したりする場合の手順です。ふだんは編集タブの「色を書き出しへ送る」かプリセットだけで足ります。";

const TIP_FILENAME_SUFFIX =
  "元ファイル名と拡張子の間に付きます。例: -graded → IMG0001-graded.jpg。空欄は接尾辞なし。元データを上書きしないよう別フォルダへ出すことを推奨します。";

const TIP_VIDEO_OUTPUT_NAMING = (fps: number) =>
  `ファイル名は元名に -graded.mp4 を付けます。出力は最大 FHD・${fps} fps です。`;

const TIP_WEBGL_ACCURATE =
  "オンにすると 1 フレームずつシークして readPixels でグレードします。非常に遅いですが、見た目は編集タブに近くなります。オフ（既定）なら ffmpeg の高速パスを使います（スライダーは未反映・.cube のみ一部反映など制限あり）。";

const TIP_KEYBOARD_SHORTCUTS = (imagesLabel: string) =>
  `⌘1 / ⌘2（Windows は Ctrl）でタブ切替。書き出しタブで ⌘↩ は「${imagesLabel}」または「動画を書き出す」。⇧⌘↩ は失敗した枚だけやり直し（写真のときのみ）。⇧⌘Y は前回の続き。Esc は中断。`;

const TIP_DESKTOP_PREFS_PERSIST =
  "入出力フォルダは次回以降のダイアログの既定の場所になります（存在するパスのみ）。ウィンドウの位置とサイズも終了時に保存されます。";

const TIP_RESUME_SESSION =
  "保存されている入出力フォルダとルック（色味）で、残りの枚数だけ続きから処理します。破棄すると記録だけ消え、すでに書き出したファイルは削除されません。";

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

  /** @description true なら WebGL 逐次（低速・プレビュー寄り）。false が既定（ffmpeg 1 パス） */
  videoExportWebglAccurate: boolean;
  onVideoExportWebglAccurateChange: (value: boolean) => void;
  /**
   * @description false のとき高速 ffmpeg のチェックボックスを出さない（常に WebGL のみ）。実装は別フラグで再有効化する。
   */
  showFastFfmpegVideoExportOption: boolean;
  /**
   * @description 動画書き出しが成功するたびに App が 1 増やす番号。初回成功で一覧表示へ誘導するためだけに使う。
   */
  videoExportSuccessNonce: number;
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
 * @description 「次にやること」バナー用の短い文言（ブロッキング手順だけを指す）
 */
function getNextBlockingBannerText(
  nextId: BatchStepId,
  batchJobMode: BatchJobMode,
): string {
  switch (nextId) {
    case "sources":
      return batchJobMode === "images"
        ? "下の「2. 読み込み元」で、写真が入ったフォルダを選んでください。"
        : "下の「2. 読み込み元」で、書き出す動画ファイルを選んでください。";
    case "output":
      return "下の「4. 保存先と形式」で、書き出し先フォルダを選んでください。写真は元フォルダと別にします。";
    case "run":
      return batchJobMode === "images"
        ? "下の「5. 実行」で「まとめて書き出す」を押します。色味はその上の「3. ルック」で変えられます。"
        : "下の「5. 実行」で「動画を書き出す」を押してください。";
    default:
      return "下の手順番号に沿って進めてください。";
  }
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
    videoExportWebglAccurate,
    onVideoExportWebglAccurateChange,
    showFastFfmpegVideoExportOption,
    videoExportSuccessNonce,
  } = props;

  /** @description 現在のステップ（0 始まり）。ジョブ種別が変わったら 0 に戻す */
  const [activeStep, setActiveStep] = useState(0);
  /**
   * @description true のときは手順を最初から縦に並べて表示。false のときは 1 ステップずつ（ウィザード）。
   * 初回は localStorage に偏好がなければ false（ウィザード既定）。一覧チェックまたは初回書き出し成功後は一覧へ寄せる。
   */
  const [showAllSteps, setShowAllSteps] = useState(() => readInitialShowAllSteps());
  /** @description ルックの「JSON / ファイル」詳細（デフォルト閉じる） */
  const [lookAdvancedOpen, setLookAdvancedOpen] = useState(false);

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
            ? "border-[var(--amber-10)] bg-[var(--amber-4)] font-semibold text-[var(--amber-12)] shadow-[inset_0_0_0_1px_var(--amber-8)]"
            : isWizardPage
              ? "border-[var(--amber-8)] bg-[var(--amber-3)] text-[var(--amber-12)]"
              : "border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] text-[var(--fl-text-secondary)] hover:bg-[var(--fl-bg-interactive)]"
        }`}
        aria-current={isWizardPage ? "step" : undefined}
        title={
          isNext
            ? "いま主に進める手順です"
            : stepDone
              ? "この段は設定済みです"
              : "クリックでこの段を表示"
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
          {BATCH_STEP_LABELS[stepId]}
          {isNext ? (
            <span className="ml-1 text-[0.6rem] font-bold text-[var(--amber-12)]">←次</span>
          ) : null}
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
        何を書き出しますか？
      </p>
      <div className="grid gap-3 sm:grid-cols-2">
        <button
          type="button"
          className={`flex cursor-pointer flex-col rounded-xl border-2 p-3 text-left transition-all ${
            batchJobMode === "images"
              ? "border-[var(--amber-10)] bg-[var(--amber-3)] shadow-[inset_0_0_0_1px_var(--amber-7)] ring-2 ring-[var(--amber-9)] ring-offset-2 ring-offset-[var(--fl-bg-app)]"
              : "border-[var(--fl-border-subtle)] border-dashed bg-[var(--fl-bg-subtle)] opacity-90 hover:border-[var(--fl-border-default)] hover:opacity-100"
          }`}
          onClick={() => onBatchJobModeChange("images")}
          aria-pressed={batchJobMode === "images"}
        >
          <div className="flex items-start justify-between gap-2">
            <span className="text-sm font-semibold text-[var(--fl-text-primary)]">
              フォルダの写真をまとめて
            </span>
            <HelpHint tip={TIP_JOB_IMAGES} assistiveLabel="フォルダの写真まとめて書き出しの説明" />
          </div>
          {batchJobMode === "images" ? (
            <span className="mt-2 inline-flex w-fit items-center gap-1 rounded-full bg-[var(--amber-9)] px-2 py-0.5 text-[0.65rem] font-bold text-[var(--fl-on-accent)]">
              <CheckCircle size={14} weight="bold" aria-hidden />
              いま選んでいる
            </span>
          ) : (
            <span className="fl-caption mt-2 text-[var(--fl-text-tertiary)]">クリックでこのモードに切替</span>
          )}
          <p className="fl-caption mt-1 text-[var(--fl-text-secondary)]">
            JPEG / PNG · 別フォルダへ保存
          </p>
        </button>
        <button
          type="button"
          className={`flex cursor-pointer flex-col rounded-xl border-2 p-3 text-left transition-all ${
            batchJobMode === "video"
              ? "border-[var(--amber-10)] bg-[var(--amber-3)] shadow-[inset_0_0_0_1px_var(--amber-7)] ring-2 ring-[var(--amber-9)] ring-offset-2 ring-offset-[var(--fl-bg-app)]"
              : "border-[var(--fl-border-subtle)] border-dashed bg-[var(--fl-bg-subtle)] opacity-90 hover:border-[var(--fl-border-default)] hover:opacity-100"
          }`}
          onClick={() => onBatchJobModeChange("video")}
          aria-pressed={batchJobMode === "video"}
        >
          <div className="flex items-start justify-between gap-2">
            <span className="text-sm font-semibold text-[var(--fl-text-primary)]">
              動画 1 本（MP4）
            </span>
            <HelpHint
              tip={
                showFastFfmpegVideoExportOption
                  ? TIP_JOB_VIDEO_FAST_OPTION
                  : TIP_JOB_VIDEO_WEBGL_ONLY
              }
              assistiveLabel="動画書き出しの説明"
            />
          </div>
          {batchJobMode === "video" ? (
            <span className="mt-2 inline-flex w-fit items-center gap-1 rounded-full bg-[var(--amber-9)] px-2 py-0.5 text-[0.65rem] font-bold text-[var(--fl-on-accent)]">
              <CheckCircle size={14} weight="bold" aria-hidden />
              いま選んでいる
            </span>
          ) : (
            <span className="fl-caption mt-2 text-[var(--fl-text-tertiary)]">クリックでこのモードに切替</span>
          )}
          <p className="fl-caption mt-1 text-[var(--fl-text-secondary)]">
            {showFastFfmpegVideoExportOption
              ? "高速書き出し（既定）／詳細は手順内"
              : "WebGL 書き出しのみ（低速）／詳細は手順内"}
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
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">画像フォルダを選ぶ</p>
            <HelpHint tip={TIP_SOURCES_IMAGES_FOLDER} assistiveLabel="対象となる画像形式の説明" />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickInputDir()}>
              入力フォルダを選ぶ
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={inputDir ?? undefined}>
              {inputDir ?? "未選択"}
            </span>
          </div>
        </>
      ) : (
        <>
          <div className="flex flex-wrap items-center gap-1.5">
            <p className="text-sm font-medium text-[var(--fl-text-primary)]">動画ファイルを選ぶ</p>
            <HelpHint
              tip={TIP_SOURCES_VIDEO_FILE(VIDEO_IMPORT_MAX_DURATION_SEC)}
              assistiveLabel="動画の読込上限と必要ツール"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button
              type="button"
              className="fl-btn-secondary"
              disabled={running}
              onClick={() => void onPickVideoFile()}
            >
              動画ファイルを選ぶ
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={videoInputPath ?? undefined}>
              {videoInputPath ?? "未選択"}
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
  const renderStepLook = () => (
    <div className="flex flex-col gap-3">
      <p className="text-sm font-medium text-[var(--fl-text-primary)]">
        保存するときにかかるルック（色味）を決める
      </p>
      <label className="flex max-w-md flex-col gap-1.5">
        <span className="fl-label">プリセット（クイック）</span>
        <select
          value={batchPresetChoice}
          onChange={(e) => onBatchPresetChoiceChange(e.target.value as PresetName)}
          className="w-full max-w-md"
          aria-label="書き出しに使う Film Lab プリセット"
        >
          {PRESET_NAMES.map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
      </label>
      <div className="flex flex-col gap-1">
        <span className="fl-label">いまの書き出し用ルック</span>
        <span className="text-xs leading-snug text-[var(--fl-text-primary)]">
          {importedGradeLabel
            ? `JSON ファイル: ${importedGradeLabel}`
            : `プリセット「${batchPresetChoice}」または編集タブの「色を書き出しへ送る」`}
        </span>
      </div>

      <div className="flex items-start gap-1.5 rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2">
        <details
          className="min-w-0 flex-1"
          open={lookAdvancedOpen}
          onToggle={(e) => setLookAdvancedOpen(e.currentTarget.open)}
        >
          <summary className="cursor-pointer text-xs font-semibold text-[var(--fl-text-secondary)]">
            詳細: Grade JSON の読み込み・書き出し（任意）
          </summary>
          <div className="mt-2 flex flex-wrap gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onImportGradeJson()}>
              JSON を読み込む
            </button>
            <button type="button" className="fl-btn-secondary" onClick={onExportGradeJson}>
              JSON を書き出す
            </button>
          </div>
        </details>
        <HelpHint tip={TIP_LOOK_JSON_DETAILS} assistiveLabel="Grade JSON の用途" />
      </div>
    </div>
  );

  /**
   * @description ステップ 3: 出力先・形式
   */
  const renderStepOutput = () => (
    <div className="flex flex-col gap-3">
      {batchJobMode === "images" ? (
        <>
          <p className="text-sm font-medium text-[var(--fl-text-primary)]">
            保存先フォルダと画像の形式
          </p>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickOutputDir()}>
              出力フォルダを選ぶ
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={outputDir ?? undefined}>
              {outputDir ?? "未選択"}
            </span>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <label htmlFor="batch-format-sel-panel" className="fl-label normal-case">
              出力形式
            </label>
            <select
              id="batch-format-sel-panel"
              className="min-w-[6.5rem]"
              value={batchFormat}
              onChange={(e) => onBatchFormatChange(e.target.value as BatchFormat)}
              aria-label="まとめて書き出す画像の形式（JPEG または PNG）"
            >
              <option value="jpeg">JPEG</option>
              <option value="png">PNG</option>
            </select>
          </div>
          <label className="flex max-w-md flex-col gap-1.5">
            <span className="fl-label normal-case flex items-center gap-1">
              ファイル名の接尾辞
              <HelpHint tip={TIP_FILENAME_SUFFIX} assistiveLabel="ファイル名の接尾辞の付け方" />
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
              動画の保存先フォルダ（任意・実行時にも選べます）
            </p>
            <HelpHint
              tip={TIP_VIDEO_OUTPUT_NAMING(VIDEO_EXPORT_FPS)}
              assistiveLabel="動画ファイル名と解像度の説明"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <button type="button" className="fl-btn-secondary" onClick={() => void onPickOutputDir()}>
              出力フォルダを選ぶ
            </button>
            <span className="fl-caption min-w-0 flex-1 truncate" title={outputDir ?? undefined}>
              {outputDir ?? "未設定（実行時にダイアログ）"}
            </span>
          </div>
          {showFastFfmpegVideoExportOption ? (
            <label className="flex max-w-prose cursor-pointer items-start gap-2">
              <input
                type="checkbox"
                className="mt-0.5"
                checked={videoExportWebglAccurate}
                onChange={(e) =>
                  onVideoExportWebglAccurateChange(e.target.checked)
                }
                aria-label="プレビューと一致させる低速 WebGL 書き出しを使う"
              />
              <span className="flex flex-1 items-start gap-1 text-xs leading-snug text-[var(--fl-text-secondary)]">
                <strong className="text-[var(--fl-text-primary)]">プレビュー一致（WebGL・低速）</strong>
                <HelpHint tip={TIP_WEBGL_ACCURATE} assistiveLabel="WebGL 逐次書き出しの説明" />
              </span>
            </label>
          ) : (
            <p className="max-w-prose text-xs leading-snug text-[var(--fl-text-secondary)]">
              動画は編集タブに近い見え方で書き出します（フレームごとの WebGL
              処理のため時間がかかります）。高速トランスコードは準備中です。
            </p>
          )}
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
        <p className="text-sm font-medium text-[var(--fl-text-primary)]">実行・中断・結果</p>
        <HelpHint
          tip={TIP_KEYBOARD_SHORTCUTS(
            batchJobMode === "images"
              ? "フォルダの写真をまとめて書き出す"
              : "動画を書き出す",
          )}
          assistiveLabel="キーボードショートカット一覧"
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
            まとめて書き出す（実行）
          </button>
          <button
            type="button"
            className="fl-btn-secondary max-w-xs"
            disabled={!batchCanRetryFailed}
            onClick={() => void onRetryFailedBatch()}
          >
            失敗のみ再実行
          </button>
          <button
            type="button"
            className="fl-btn-secondary"
            disabled={!running}
            aria-label="実行中の書き出しを中断する"
            onClick={onAbortBatch}
          >
            中断
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
            動画を書き出す
          </button>
          <button
            type="button"
            className="fl-btn-secondary"
            disabled={!running}
            aria-label="実行中の書き出しを中断する"
            onClick={onAbortBatch}
          >
            中断
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
            aria-valuetext={`${batchProgress.current} / ${batchProgress.total} ${batchProgress.fileName}`}
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
          直近の結果: 成功 {lastBatchSummary.ok} 枚 · 読込エラー {lastBatchSummary.loadFail} · 書込エラー{" "}
          {lastBatchSummary.writeFail}
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
            ? "scroll-mt-4 rounded-lg bg-[var(--amber-4)] px-3 py-3 ring-2 ring-[var(--amber-9)] ring-offset-2 ring-offset-[var(--fl-bg-app)]"
            : ""
        }`}
        aria-labelledby={`batch-step-h-${stepId}`}
      >
        <h3 id={`batch-step-h-${stepId}`} className="fl-label normal-case tracking-normal">
          {idx + 1}. {BATCH_STEP_LABELS[stepId]}
          {isHighlight ? (
            <span className="ml-2 rounded bg-[var(--amber-9)] px-1.5 py-px text-[0.6rem] font-bold normal-case text-[var(--fl-on-accent)]">
              次はここ
            </span>
          ) : null}
        </h3>
        {stepRenderers[stepId]()}
      </section>
    );
  };

  return (
    <>
      <section
        className="fl-card fl-card-muted gap-2 border-[var(--fl-border-default)]"
        aria-labelledby="export-tab-intro-heading"
      >
        <div className="flex items-start gap-2">
          <h2
            id="export-tab-intro-heading"
            className="text-sm font-semibold text-[var(--fl-text-primary)]"
          >
            書き出し
          </h2>
          <HelpHint tip={TIP_EXPORT_TAB_INTRO} assistiveLabel="書き出しタブの説明" />
        </div>
        <p className="fl-caption text-[var(--fl-text-secondary)]">
          フォルダの写真を別フォルダへまとめ保存、または動画を1本MP4へ。
        </p>
      </section>

      <div
        className="self-start rounded-lg border px-3 py-2.5 text-xs leading-relaxed"
        style={{
          borderColor: "var(--amber-6)",
          background: "var(--amber-2)",
          color: "var(--amber-12)",
        }}
      >
        写真をまとめて書き出すときは、元データが消えないよう<strong>保存先フォルダは別</strong>にしてください。
      </div>

      {persistedSession && sessionHasRemainingWork(persistedSession) ? (
        <div
          className="rounded-lg border px-3 py-2.5 text-xs leading-relaxed"
          style={{
            borderColor: "var(--blue-6)",
            background: "var(--blue-2)",
            color: "var(--blue-12)",
          }}
        >
          <div className="mb-2 flex flex-wrap items-start gap-1.5">
            <p>
              前回のまとめ書き出しが途中です（残り {pathsNotSucceeded(persistedSession).length} 枚）。
            </p>
            <HelpHint tip={TIP_RESUME_SESSION} assistiveLabel="再開と破棄の説明" />
          </div>
          <div className="flex flex-wrap gap-2">
            <button type="button" className="fl-btn-primary" disabled={!batchCanResume} onClick={() => void onResumeBatch()}>
              続きから再開
            </button>
            <button type="button" className="fl-btn-secondary" disabled={running} onClick={() => void onDiscardPersistedSession()}>
              途中の記録を消す
            </button>
          </div>
        </div>
      ) : null}

      {!running ? (
        <div
          className="flex flex-col gap-2 rounded-xl border-2 border-[var(--amber-9)] bg-[var(--amber-3)] px-3 py-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between"
          role="status"
          aria-live="polite"
        >
          <div className="min-w-0 flex-1">
            <div className="flex flex-wrap items-center gap-2">
              <span className="text-xs font-bold uppercase tracking-wide text-[var(--amber-11)]">
                次にやること
              </span>
              <span className="rounded-md bg-[var(--amber-9)] px-2 py-0.5 text-xs font-bold text-[var(--fl-on-accent)]">
                {nextBlockingIdx + 1}. {BATCH_STEP_LABELS[nextBlockingStepId]}
              </span>
            </div>
            <p className="mt-1 text-sm font-medium leading-snug text-[var(--amber-12)]">
              {getNextBlockingBannerText(nextBlockingStepId, batchJobMode)}
            </p>
          </div>
          <button
            type="button"
            className="fl-btn-primary shrink-0 text-xs sm:min-w-[11rem]"
            onClick={() => focusExportStep(nextBlockingStepId)}
          >
            この手順へジャンプ
          </button>
        </div>
      ) : (
        <p className="rounded-lg border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-3 py-2 text-xs text-[var(--fl-text-secondary)]">
          書き出し処理中です。終わるまでお待ちください。中断は「実行」段のボタンから。
        </p>
      )}

      <section className="fl-card gap-4">
        <div className="flex flex-col gap-2 sm:flex-row sm:flex-wrap sm:items-center sm:justify-between">
          <p className="text-sm font-medium text-[var(--fl-text-primary)]">
            手順（番号は上の「次にやること」と対応）
          </p>
          <div className="flex flex-wrap gap-1.5" role="tablist" aria-label="書き出しの手順ジャンプ">
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
            入力: {sourceOk ? "OK" : "未"}
          </span>
          <span className="rounded-full border border-[var(--fl-border-subtle)] bg-[var(--fl-bg-subtle)] px-2 py-0.5 text-[var(--fl-text-tertiary)]">
            ルック: 設定済
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
            出力:{" "}
            {batchJobMode === "video"
              ? outputOk
                ? "OK"
                : "任意"
              : outputOk
                ? "OK"
                : "未"}
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
          手順を一覧で表示する（オフにすると 1 画面ずつ）
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
                ? "ring-2 ring-[var(--amber-9)] ring-offset-2 ring-offset-[var(--fl-bg-app)]"
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
              戻る
            </button>
            <button type="button" className="fl-btn-primary" disabled={!canGoNext} onClick={goNext}>
              次へ
            </button>
          </div>
        ) : null}
      </section>

      <div className="flex flex-wrap items-center gap-1.5">
        <p className="fl-caption">フォルダの既定・ウィンドウ位置は次回に引き継がれます。</p>
        <HelpHint tip={TIP_DESKTOP_PREFS_PERSIST} assistiveLabel="保存される設定の詳細" />
      </div>
    </>
  );
}
