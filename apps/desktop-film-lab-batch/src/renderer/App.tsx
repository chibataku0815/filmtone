/**
 * Film Lab デスクトップ — 編集（Web 踏襲）と書き出し（フォルダ／動画）の 2 モード
 *
 * @overview 書き出し用ルックの正はメモリ上の BatchGradeState。編集タブでプレビューし「色を書き出しへ送る」で同期する。
 * 編集／書き出しは **タブで表示だけ切り替え**、編集ツリーはアンマウントしない（WebGL Viewport を維持し「反映」を常に効かせる）。
 * @limitations プレビュー上の LUT を書き出しへ自動複製はしない（JSON Import か .cube 再適用）。
 * シェルの色・段差は globals.css の Radix スケール準拠トークン（html.dark.dark-theme）に集約する。
 *
 * @description 編集タブのレイアウト（デスクトップ向け）
 * - 狭い画面では「上＝プレビュー＋ヒスト／下＝コントロール」の縦積み。
 * - `lg` 以上ではプレビュー領域を親いっぱい（absolute inset-0）にし、右パネルはその上に
 *   `translateX` でスライドインする。閉じたあともキャンバスはウィンドウ幅いっぱいを使う。
 * - 開閉は Phosphor Icons（CaretLeft / CaretRight）＋ aria-label。`prefers-reduced-motion` は Tailwind で短縮。
 */
import { CaretLeft, CaretRight } from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useTranslations } from "next-intl";
import { FilmLabCanvas, type FilmLabCanvasRef } from "@film-lab/components/FilmLabCanvas";
import { ControlPanel } from "@film-lab/components/ControlPanel";
import { Histogram } from "@film-lab/components/ui/Histogram";
import { HelpHint } from "./batch-tab/HelpHint";
import type { Viewport } from "@film-lab/core/Viewport";
import { PRESETS, type PresetName } from "film-lab-core";
import {
  initialOutcomes,
  parseFilmLabBatchSessionV1,
  pathsNotSucceeded,
  sessionHasRemainingWork,
  type FilmLabBatchSessionV1,
} from "./batch-session";
import {
  batchGradeStateFromPreset,
  resolveGradeFromJsonText,
  runBatchPipeline,
  sanitizeBatchFilenameSuffix,
  type BatchFormat,
  type BatchGradeState,
  type BatchPipelineProgressPayload,
  type BatchPipelineSummary,
} from "./batch-pipeline";
import {
  runVideoExportPipeline,
  type VideoExportProgress,
  type VideoExportPipelineUserMessages,
} from "./video-export-pipeline";
import {
  assertVideoImportWithinCaps,
  computeExportFrameCount,
  computeVideoExportDimensions,
  VIDEO_EXPORT_FPS,
  VIDEO_IMPORT_MAX_DURATION_SEC,
} from "./video-export-constants";
import { exportGradeJsonText } from "./grade-io";
import { viewportRecordToParams } from "./viewport-to-params";
import {
  BatchTabPanel,
  type BatchJobMode,
} from "./batch-tab/BatchTabPanel";
import type { DesktopUpdateAvailablePayload } from "./desktop-api";

type TabId = "edit" | "batch";

const PRESET_NAMES = Object.keys(PRESETS) as PresetName[];

/**
 * @description 非表示タブに `hidden`（display:none）を使わない。WebGL キャンバスの尺寸・コンテキストを維持し、重ね順と透明・pointer-events でだけ隠す。
 */
const DESKTOP_INACTIVE_TAB_CLASS =
  "pointer-events-none absolute inset-0 z-0 flex min-h-0 flex-col gap-4 overflow-hidden opacity-0";

/**
 * @description ログ欄の React state 更新をまとめる間隔（ms）。
 *   各フレームの `setState` 連打を避け、書き出し中の UI 負荷を下げる。
 */
const LOG_TEXT_FLUSH_INTERVAL_MS = 120;

/**
 * @description 動画書き出し中の progress 表示を更新する最短間隔（ms）。
 *   各フレームの `setState` を避け、React 再描画の負荷で後半が鈍らないようにする。
 */
const VIDEO_PROGRESS_FLUSH_INTERVAL_MS = 150;

/**
 * @description セッションに保存した情報だけから BatchGradeState を組み立てる（再開直後のパイプライン用）
 */
async function resolveBatchGradeSnapshot(
  s: FilmLabBatchSessionV1,
): Promise<BatchGradeState> {
  if (s.importedGradePath) {
    const text = await window.filmLabBatch.readFileUtf8(s.importedGradePath);
    const g = await resolveGradeFromJsonText(
      window.filmLabBatch,
      s.importedGradePath,
      text,
    );
    return {
      params: g.params,
      lutIntensity: g.lutIntensity,
      lutData: g.lutData,
      lutSize: g.lutSize,
    };
  }
  if (s.gradeParamsJson) {
    const refPath =
      s.imagePaths[0] ?? `${s.inputDir}/film-lab-grade.json`;
    const g = await resolveGradeFromJsonText(
      window.filmLabBatch,
      refPath,
      s.gradeParamsJson,
    );
    return {
      params: g.params,
      lutIntensity: g.lutIntensity,
      lutData: g.lutData,
      lutSize: g.lutSize,
    };
  }
  return batchGradeStateFromPreset(s.batchPresetChoice);
}

/**
 * @description 入力中はデスクトップショートカットを効かせない（テキスト・選択・contenteditable）
 */
function isTextInputTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") {
    return true;
  }
  if (target.isContentEditable) return true;
  return false;
}

export default function App() {
  const tApp = useTranslations("film-lab.desktop.app");
  const tLogs = useTranslations("film-lab.desktop.logs");

  const videoPipelineUserMessages = useMemo(
    (): VideoExportPipelineUserMessages => ({
      webglUnavailable: tLogs("videoPipelineWebglUnavailable"),
      metadataFailed: (detail: string) =>
        tLogs("videoPipelineMetadataFailed", { msg: detail }),
      ffmpegStartFailed: (detail: string) =>
        tLogs("videoPipelineFfmpegStartFailed", { msg: detail }),
      userAborted: tLogs("videoPipelineAborted"),
      ffmpegFailed: (code: number) =>
        tLogs("videoPipelineFfmpegFailed", { code: String(code) }),
    }),
    [tLogs],
  );

  /** @description スマートルックがキャンバス JPEG を取得するための ref（Web のフルページと同じ配線） */
  const filmLabCanvasRef = useRef<FilmLabCanvasRef | null>(null);
  const [tab, setTab] = useState<TabId>("edit");
  const [viewport, setViewport] = useState<Viewport | null>(null);
  const [histogramVisible, setHistogramVisible] = useState(true);
  const [canvasPreset, setCanvasPreset] = useState<PresetName>("cinematic");

  const [batchGrade, setBatchGrade] = useState<BatchGradeState>(() =>
    batchGradeStateFromPreset("cinematic"),
  );
  const [batchPresetChoice, setBatchPresetChoice] =
    useState<PresetName>("cinematic");
  const [importedGradeLabel, setImportedGradeLabel] = useState<string | null>(
    null,
  );

  const [inputDir, setInputDir] = useState<string | null>(null);
  const [outputDir, setOutputDir] = useState<string | null>(null);
  const [logText, setLogText] = useState("");
  /** @description ログ欄へまだ反映していない追記分。一定時間ためてからまとめて描画する。 */
  const pendingLogTextRef = useRef("");
  /** @description 次回 flush のタイマー ID。null のときは未予約。 */
  const logFlushTimerRef = useRef<number | null>(null);
  /** @description 動画 progress の最新値。一定間隔ごとに UI へ反映する。 */
  const pendingVideoProgressRef = useRef<VideoExportProgress | null>(null);
  /** @description 動画 progress flush のタイマー ID。null のときは未予約。 */
  const videoProgressFlushTimerRef = useRef<number | null>(null);
  const [running, setRunning] = useState(false);
  /** @description 書き出し中断用。Run 開始時に差し替え、完了・エラーで null */
  const batchAbortRef = useRef<AbortController | null>(null);
  /** @description プログレスバー用。処理中のみセット */
  const [batchProgress, setBatchProgress] =
    useState<BatchPipelineProgressPayload | null>(null);
  /** @description 直近の正常終了したまとめて書き出しの集計（画面下に短く残す） */
  const [lastBatchSummary, setLastBatchSummary] =
    useState<BatchPipelineSummary | null>(null);
  /** @description 直近の実行で失敗した入力パス（失敗のみ再実行用） */
  const [lastFailedPaths, setLastFailedPaths] = useState<string[]>([]);
  /**
   * @description メインプロセスに保存した再開用セッション。実行中も outcomes を更新して同期する。
   */
  const [persistedSession, setPersistedSession] =
    useState<FilmLabBatchSessionV1 | null>(null);
  /** @description onFileOutcome から参照する実行中セッション（再開・フルラン共通） */
  const activeBatchSessionRef = useRef<FilmLabBatchSessionV1 | null>(null);
  const [batchFormat, setBatchFormat] = useState<BatchFormat>("jpeg");
  /**
   * @description 出力ファイル名の接尾辞（UI の生入力。パイプラインで sanitize する）。空ならベース名のみ。
   */
  const [batchOutputSuffix, setBatchOutputSuffix] = useState("-graded");
  /**
   * @description 書き出しタブの主ジョブ種別。⌘↩ の実行先と UI の出し分けに使う（状態は App が正）。
   */
  const [batchJobMode, setBatchJobMode] = useState<BatchJobMode>("images");
  /** @description 動画出力用のソースパス（1 本選ぶ） */
  const [videoInputPath, setVideoInputPath] = useState<string | null>(null);
  /** @description ffprobe 済みのメタ（UI 表示用） */
  const [videoProbeLabel, setVideoProbeLabel] = useState<string | null>(null);
  /**
   * @description 動画書き出し成功のたびに増やす。書き出しタブの「初回はウィザード→成功後は一覧」だけ検知する（BatchGradeState ではない）。
   */
  const [videoExportSuccessNonce, setVideoExportSuccessNonce] = useState(0);
  /**
   * @description 編集→書き出し同期の結果をヘッダー下に出す（ログは書き出しタブ下部のため、編集だけ見ていると気づきにくい問題の対策）
   */
  const [gradeSyncNotice, setGradeSyncNotice] = useState<string | null>(null);
  /**
   * @description 編集→書き出しへ同期が成功した時刻（ms）。null のときは JSON 由来でもプリセット起点でも「直近は編集同期ではない」。
   */
  const [editToExportSyncedAtMs, setEditToExportSyncedAtMs] = useState<
    number | null
  >(null);

  /**
   * @description main が公開 JSON を読んで送る「新しい版があります」バナー（案 C）
   */
  const [desktopUpdateBanner, setDesktopUpdateBanner] =
    useState<DesktopUpdateAvailablePayload | null>(null);

  /**
   * @description 更新通知の購読。アンマウント時に解除する。
   */
  useEffect(() => {
    const unsubscribe = window.filmLabBatch.subscribeDesktopUpdateAvailable(
      (payload) => {
        setDesktopUpdateBanner(payload);
      },
    );
    return unsubscribe;
  }, []);

  /**
   * @description 写真バッチ／動画書き出し中は main 側で通知をキューに残す
   */
  useEffect(() => {
    void window.filmLabBatch.setExportBusyForUpdateCheck(running);
  }, [running]);

  /**
   * @description 幅 lg 以上で右スライドパネルを表示するか。パネルは DOM を維持し `translateX` のみ（内部状態を捨てない）。
   */
  const [editRightPaneExpanded, setEditRightPaneExpanded] = useState(true);
  /**
   * @description ビューポートが Tailwind `lg` 以上か。SSR なし前提で初期値は同期読み取り。
   */
  const [isLgLayout, setIsLgLayout] = useState(() =>
    typeof window !== "undefined"
      ? window.matchMedia("(min-width: 1024px)").matches
      : false,
  );

  useEffect(() => {
    const mq = window.matchMedia("(min-width: 1024px)");
    const onChange = () => setIsLgLayout(mq.matches);
    onChange();
    mq.addEventListener("change", onChange);
    return () => mq.removeEventListener("change", onChange);
  }, []);

  /** @description 狭い幅に戻したときはパネルを必ず表示（縦積みで隠れないようにする） */
  useEffect(() => {
    if (!isLgLayout) {
      setEditRightPaneExpanded(true);
    }
  }, [isLgLayout]);

  /**
   * @description 起動時に userData のセッション JSON を読み、フォームへ反映する。
   */
  /**
   * @description 写真のまとめて書き出しが途中のセッションがあるときは UI を画像モードに揃え、再開導線と矛盾させない。
   */
  useEffect(() => {
    if (persistedSession && sessionHasRemainingWork(persistedSession)) {
      setBatchJobMode("images");
    }
  }, [persistedSession]);

  useEffect(() => {
    void (async () => {
      const raw = await window.filmLabBatch.readBatchSession();
      const parsed = raw ? parseFilmLabBatchSessionV1(raw) : null;
      if (parsed) {
        setPersistedSession(parsed);
        setInputDir(parsed.inputDir);
        setOutputDir(parsed.outputDir);
        setBatchFormat(parsed.format);
        setBatchOutputSuffix(parsed.outputFilenameSuffix);
        setBatchPresetChoice(parsed.batchPresetChoice);
        setEditToExportSyncedAtMs(null);
        try {
          const snap = await resolveBatchGradeSnapshot(parsed);
          setBatchGrade(snap);
          setImportedGradeLabel(parsed.importedGradePath);
        } catch {
          setBatchGrade(batchGradeStateFromPreset(parsed.batchPresetChoice));
          setImportedGradeLabel(null);
        }
        return;
      }
      const prefs = await window.filmLabBatch.getDesktopPrefs();
      if (prefs.lastInputDir) setInputDir(prefs.lastInputDir);
      if (prefs.lastOutputDir) setOutputDir(prefs.lastOutputDir);
    })();
  }, []);

  /**
   * @description 同期メッセージをしばらくしたら消す（画面のノイズを抑える）
   */
  useEffect(() => {
    if (!gradeSyncNotice) return;
    const id = window.setTimeout(() => {
      setGradeSyncNotice(null);
    }, 6000);
    return () => window.clearTimeout(id);
  }, [gradeSyncNotice]);

  /**
   * @description バッファ済みのログをまとめて state へ反映する。
   *   1 行ごとに React を再描画しないよう、UI 更新を間引く。
   */
  const flushBufferedLogText = useCallback(() => {
    if (logFlushTimerRef.current !== null) {
      window.clearTimeout(logFlushTimerRef.current);
      logFlushTimerRef.current = null;
    }
    const bufferedLogText = pendingLogTextRef.current;
    if (bufferedLogText.length === 0) return;
    pendingLogTextRef.current = "";
    setLogText((t) => `${t}${bufferedLogText}`);
  }, []);

  /**
   * @description 新しい実行を始める前に、保留中バッファごとログ欄を空に戻す。
   */
  const resetLogText = useCallback(() => {
    pendingLogTextRef.current = "";
    if (logFlushTimerRef.current !== null) {
      window.clearTimeout(logFlushTimerRef.current);
      logFlushTimerRef.current = null;
    }
    setLogText("");
  }, []);

  /**
   * @description 保留中の動画 progress を一度だけ UI へ反映する。
   *   書き出し中の大きな React 再描画を減らしつつ、進捗表示は十分追えるようにする。
   */
  const flushVideoProgress = useCallback(() => {
    if (videoProgressFlushTimerRef.current !== null) {
      window.clearTimeout(videoProgressFlushTimerRef.current);
      videoProgressFlushTimerRef.current = null;
    }
    const pendingVideoProgress = pendingVideoProgressRef.current;
    if (!pendingVideoProgress) return;
    pendingVideoProgressRef.current = null;
    setBatchProgress({
      current: pendingVideoProgress.currentFrame,
      total: pendingVideoProgress.totalFrames,
      fileName: tLogs("progressVideoFrames"),
    });
  }, [tLogs]);

  /**
   * @description 新しい動画書き出し開始前や終了時に、保留中 progress とタイマーを片付ける。
   */
  const resetVideoProgressBuffer = useCallback(() => {
    pendingVideoProgressRef.current = null;
    if (videoProgressFlushTimerRef.current !== null) {
      window.clearTimeout(videoProgressFlushTimerRef.current);
      videoProgressFlushTimerRef.current = null;
    }
  }, []);

  /**
   * @description 動画 progress は一定間隔でまとめて反映し、最終フレームだけ即時反映する。
   */
  const scheduleVideoProgress = useCallback(
    (progress: VideoExportProgress) => {
      pendingVideoProgressRef.current = progress;
      if (progress.currentFrame <= 1 || progress.currentFrame === progress.totalFrames) {
        flushVideoProgress();
        return;
      }
      if (videoProgressFlushTimerRef.current !== null) return;
      videoProgressFlushTimerRef.current = window.setTimeout(() => {
        flushVideoProgress();
      }, VIDEO_PROGRESS_FLUSH_INTERVAL_MS);
    },
    [flushVideoProgress],
  );

  useEffect(() => {
    return () => {
      if (logFlushTimerRef.current !== null) {
        window.clearTimeout(logFlushTimerRef.current);
        logFlushTimerRef.current = null;
      }
      if (videoProgressFlushTimerRef.current !== null) {
        window.clearTimeout(videoProgressFlushTimerRef.current);
        videoProgressFlushTimerRef.current = null;
      }
    };
  }, []);

  const appendLog = useCallback(
    (line: string) => {
      pendingLogTextRef.current += `${line}\n`;
      if (logFlushTimerRef.current !== null) return;
      logFlushTimerRef.current = window.setTimeout(() => {
        flushBufferedLogText();
      }, LOG_TEXT_FLUSH_INTERVAL_MS);
    },
    [flushBufferedLogText],
  );

  const syncPreviewToBatch = useCallback(() => {
    if (!viewport) {
      appendLog(tLogs("syncNoViewport"));
      setGradeSyncNotice(tApp("syncGradeNoViewport"));
      return;
    }
    try {
      const raw = viewport.getParams();
      const params = viewportRecordToParams(raw, batchGrade.params.halationHue);
      setBatchGrade({
        params,
        lutIntensity: 1,
        lutData: null,
        lutSize: 0,
      });
      setImportedGradeLabel(null);
      setBatchPresetChoice(canvasPreset);
      setEditToExportSyncedAtMs(Date.now());
      appendLog(tLogs("syncCopied"));
      setGradeSyncNotice(tApp("syncGradeOk"));
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      appendLog(tLogs("syncException", { msg }));
      setGradeSyncNotice(tApp("syncGradeError", { msg }));
    }
  }, [
    viewport,
    batchGrade.params.halationHue,
    canvasPreset,
    appendLog,
    tLogs,
    tApp,
  ]);

  const applyBatchPreset = (name: PresetName) => {
    setBatchPresetChoice(name);
    setBatchGrade(batchGradeStateFromPreset(name));
    setImportedGradeLabel(null);
    setEditToExportSyncedAtMs(null);
  };

  const importGradeJson = async () => {
    const p = await window.filmLabBatch.pickGradeJson();
    if (!p) return;
    try {
      const text = await window.filmLabBatch.readFileUtf8(p);
      const g = await resolveGradeFromJsonText(window.filmLabBatch, p, text);
      setBatchGrade({
        params: g.params,
        lutIntensity: g.lutIntensity,
        lutData: g.lutData,
        lutSize: g.lutSize,
      });
      setImportedGradeLabel(p);
      setEditToExportSyncedAtMs(null);
      appendLog(tLogs("gradeJsonLoaded", { path: p }));
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("gradeJsonError", { msg }));
    }
  };

  const exportGrade = () => {
    const blob = new Blob([exportGradeJsonText(batchGrade.params)], {
      type: "application/json",
    });
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "film-lab-grade.json";
    a.click();
    URL.revokeObjectURL(url);
    appendLog(tLogs("gradeJsonDownloaded"));
  };

  const finalizeSessionAfterRun = useCallback(
    async (
      summary: BatchPipelineSummary,
      sessionSnap: FilmLabBatchSessionV1 | null,
    ) => {
      if (!sessionSnap) return;
      if (!summary.aborted && sessionSnap.outcomes.every((o) => o === "ok")) {
        await window.filmLabBatch.clearBatchSession();
        activeBatchSessionRef.current = null;
        setPersistedSession(null);
        appendLog(tLogs("sessionClearedAllOk"));
      } else {
        setPersistedSession(sessionSnap);
      }
    },
    [appendLog, tLogs],
  );

  const runBatchWithPaths = useCallback(
    async (
      imagePaths: string[],
      format: BatchFormat,
      sessionMutable: FilmLabBatchSessionV1 | null,
      pathContext?: {
        inputDir: string;
        outputDir: string;
        /** @description 再開直後など、state よりこのスナップショットをパイプラインに渡す */
        grade?: BatchGradeState;
      },
    ) => {
      const effectiveInput = pathContext?.inputDir ?? inputDir;
      const effectiveOutput = pathContext?.outputDir ?? outputDir;
      const effectiveGrade = pathContext?.grade ?? batchGrade;
      if (!effectiveInput || !effectiveOutput) return;

      void window.filmLabBatch.setDesktopPrefs({
        lastInputDir: effectiveInput,
        lastOutputDir: effectiveOutput,
      });

      resetLogText();
      setLastBatchSummary(null);
      setLastFailedPaths([]);

      const abortController = new AbortController();
      batchAbortRef.current = abortController;
      activeBatchSessionRef.current = sessionMutable;

      appendLog(tLogs("inputLabel", { path: effectiveInput }));
      appendLog(tLogs("outputLabel", { path: effectiveOutput }));
      appendLog(
        importedGradeLabel
          ? tLogs("gradeImportedLine")
          : tLogs("gradeMemoryLine", { preset: batchPresetChoice }),
      );
      appendLog(tLogs("formatLabel", { format }));
      const outputSuffixForPipeline =
        sessionMutable?.outputFilenameSuffix ?? batchOutputSuffix;
      appendLog(
        tLogs("suffixLabel", {
          value:
            sanitizeBatchFilenameSuffix(outputSuffixForPipeline) === ""
              ? tLogs("suffixNone")
              : sanitizeBatchFilenameSuffix(outputSuffixForPipeline),
        }),
      );
      appendLog(tLogs("runCountLabel", { count: imagePaths.length }));

      setRunning(true);
      try {
        setBatchProgress({
          current: 0,
          total: imagePaths.length,
          fileName: tLogs("preparing"),
        });

        const pathToIndex =
          sessionMutable === null
            ? null
            : new Map(
                sessionMutable.imagePaths.map((p, i) => [p, i] as const),
              );

        const summary = await runBatchPipeline({
          api: window.filmLabBatch,
          grade: effectiveGrade,
          imagePaths,
          outputDir: effectiveOutput,
          format,
          outputFilenameSuffix: outputSuffixForPipeline,
          onLog: appendLog,
          signal: abortController.signal,
          onProgress: setBatchProgress,
          onFileOutcome:
            sessionMutable && pathToIndex
              ? ({ absolutePath, outcome }) => {
                  const idx = pathToIndex.get(absolutePath);
                  if (idx === undefined) return;
                  const nextOutcome =
                    outcome === "ok"
                      ? "ok"
                      : outcome === "loadFail"
                        ? "loadFail"
                        : "writeFail";
                  const base = activeBatchSessionRef.current;
                  if (!base) return;
                  const nextOutcomes = [...base.outcomes];
                  nextOutcomes[idx] = nextOutcome;
                  const next: FilmLabBatchSessionV1 = {
                    ...base,
                    outcomes: nextOutcomes,
                    updatedAtIso: new Date().toISOString(),
                  };
                  activeBatchSessionRef.current = next;
                  setPersistedSession(next);
                  void window.filmLabBatch.writeBatchSession(next);
                }
              : undefined,
        });

        setLastBatchSummary(summary);
        setLastFailedPaths(summary.failedPaths);
        const snap = activeBatchSessionRef.current;
        await finalizeSessionAfterRun(summary, snap);

        if (summary.aborted) {
          appendLog(tLogs("userAborted"));
        } else {
          appendLog(tLogs("done"));
        }
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        appendLog(tLogs("fatal", { msg }));
      } finally {
        batchAbortRef.current = null;
        setBatchProgress(null);
        setRunning(false);
        activeBatchSessionRef.current = null;
      }
    },
    [
      appendLog,
      batchGrade,
      batchPresetChoice,
      finalizeSessionAfterRun,
      importedGradeLabel,
      inputDir,
      outputDir,
      batchOutputSuffix,
      tLogs,
    ],
  );

  const runBatch = async () => {
    if (!inputDir || !outputDir) return;
    const images = await window.filmLabBatch.listImages(inputDir);
    if (images.length === 0) {
      appendLog(tLogs("noImages"));
      return;
    }
    const session: FilmLabBatchSessionV1 = {
      version: 1,
      updatedAtIso: new Date().toISOString(),
      inputDir,
      outputDir,
      format: batchFormat,
      imagePaths: images,
      outcomes: initialOutcomes(images.length),
      batchPresetChoice,
      importedGradePath: importedGradeLabel,
      gradeParamsJson: importedGradeLabel
        ? null
        : exportGradeJsonText(batchGrade.params),
      outputFilenameSuffix: sanitizeBatchFilenameSuffix(batchOutputSuffix),
    };
    await window.filmLabBatch.writeBatchSession(session);
    setPersistedSession(session);
    await runBatchWithPaths(images, batchFormat, session);
  };

  const resumeBatch = async () => {
    const s = persistedSession;
    if (!s || !sessionHasRemainingWork(s)) return;
    setInputDir(s.inputDir);
    setOutputDir(s.outputDir);
    setBatchFormat(s.format);
    setBatchOutputSuffix(s.outputFilenameSuffix);
    setBatchPresetChoice(s.batchPresetChoice);
    let gradeSnap: BatchGradeState;
    try {
      gradeSnap = await resolveBatchGradeSnapshot(s);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("sessionRestoreFailed", { msg }));
      gradeSnap = batchGradeStateFromPreset(s.batchPresetChoice);
    }
    setBatchGrade(gradeSnap);
    setImportedGradeLabel(s.importedGradePath);
    const todo = pathsNotSucceeded(s);
    if (todo.length === 0) return;
    await runBatchWithPaths(todo, s.format, s, {
      inputDir: s.inputDir,
      outputDir: s.outputDir,
      grade: gradeSnap,
    });
  };

  const retryFailedBatch = async () => {
    if (!inputDir || !outputDir || lastFailedPaths.length === 0) return;
    const aligned =
      persistedSession &&
      lastFailedPaths.every((p) => persistedSession.imagePaths.includes(p))
        ? persistedSession
        : null;
    await runBatchWithPaths(lastFailedPaths, batchFormat, aligned, {
      inputDir,
      outputDir,
    });
  };

  const discardPersistedSession = async () => {
    await window.filmLabBatch.clearBatchSession();
    activeBatchSessionRef.current = null;
    setPersistedSession(null);
    appendLog(tLogs("sessionDiscarded"));
  };

  const pickVideoFile = async () => {
    const p = await window.filmLabBatch.pickInputVideoFile();
    if (!p) return;
    setVideoInputPath(p);
    try {
      const meta = await window.filmLabBatch.videoExportProbe(p);
      assertVideoImportWithinCaps(meta.width, meta.height, meta.durationSec);
      const { outW, outH } = computeVideoExportDimensions(meta.width, meta.height);
      const frames = computeExportFrameCount(meta.durationSec);
      setVideoProbeLabel(
        tLogs("videoMetaLine", {
          w: String(meta.width),
          h: String(meta.height),
          sec: meta.durationSec.toFixed(1),
          codec: meta.videoCodec || "?",
          ow: String(outW),
          oh: String(outH),
          fps: String(VIDEO_EXPORT_FPS),
          frames: String(frames),
          maxSec: String(VIDEO_IMPORT_MAX_DURATION_SEC),
        }),
      );
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      setVideoProbeLabel(null);
      appendLog(tLogs("videoMetaLogPrefix", { msg }));
    }
  };

  const runVideoExport = async () => {
    if (!videoInputPath) {
      appendLog(tLogs("videoPickFirst"));
      return;
    }

    let effectiveOutputDir = outputDir;
    if (!effectiveOutputDir) {
      appendLog(tLogs("videoOutputUnset"));
      const picked = await window.filmLabBatch.pickOutputDir();
      if (!picked) {
        appendLog(tLogs("videoOutputCancel"));
        return;
      }
      effectiveOutputDir = picked;
      setOutputDir(picked);
    }

    const norm = videoInputPath.replace(/\\/g, "/");
    const base = norm.slice(norm.lastIndexOf("/") + 1) || "export";
    const dot = base.lastIndexOf(".");
    const stem = dot > 0 ? base.slice(0, dot) : base;
    const outName = `${stem}-graded.mp4`;

    void window.filmLabBatch.setDesktopPrefs({
      lastOutputDir: effectiveOutputDir,
    });

    let estimateFrames = 1;
    try {
      const meta = await window.filmLabBatch.videoExportProbe(videoInputPath);
      assertVideoImportWithinCaps(meta.width, meta.height, meta.durationSec);
      estimateFrames = computeExportFrameCount(meta.durationSec);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("videoValidateErr", { msg }));
      return;
    }

    resetLogText();
    resetVideoProgressBuffer();
    batchAbortRef.current = null;
    setRunning(true);

    try {
      {
        const abortController = new AbortController();
        batchAbortRef.current = abortController;
        setBatchProgress({
          current: 0,
          total: estimateFrames,
          fileName: tLogs("progressVideoFrames"),
        });
        const res = await runVideoExportPipeline({
          api: window.filmLabBatch,
          inputVideoPath: videoInputPath,
          outputDir: effectiveOutputDir,
          outputFileName: outName,
          grade: batchGrade,
          signal: abortController.signal,
          onProgress: (pr) => {
            scheduleVideoProgress(pr);
          },
          onLog: appendLog,
          userMessages: videoPipelineUserMessages,
        });
        if (!res.ok) {
          appendLog(tLogs("videoExportFail", { msg: res.message }));
        } else {
          appendLog(tLogs("videoExportDone"));
          setVideoExportSuccessNonce((n) => n + 1);
        }
      }
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("videoFatal", { msg }));
    } finally {
      flushVideoProgress();
      resetVideoProgressBuffer();
      batchAbortRef.current = null;
      setBatchProgress(null);
      setRunning(false);
    }
  };

  const batchCanRun = Boolean(inputDir && outputDir) && !running;
  /** @description 動画はソースさえあれば実行可。出力フォルダ未設定時はクリックでダイアログを開く */
  const videoCanExport = Boolean(videoInputPath) && !running;
  const batchCanResume =
    Boolean(persistedSession && sessionHasRemainingWork(persistedSession)) &&
    !running;
  const batchCanRetryFailed =
    Boolean(inputDir && outputDir) &&
    lastFailedPaths.length > 0 &&
    !running;

  /** @description キーボードハンドラ用。レンダーごとに最新の非同期処理を指す。 */
  const batchHotkeysRef = useRef({
    runBatch: async (): Promise<void> => {},
    runVideoExport: async (): Promise<void> => {},
    retryFailedBatch: async (): Promise<void> => {},
    resumeBatch: async (): Promise<void> => {},
  });
  batchHotkeysRef.current.runBatch = runBatch;
  batchHotkeysRef.current.runVideoExport = runVideoExport;
  batchHotkeysRef.current.retryFailedBatch = retryFailedBatch;
  batchHotkeysRef.current.resumeBatch = resumeBatch;

  /** @description キーボードハンドラ用の UI フラグ（常に最新） */
  const hotkeyUiRef = useRef({
    tab: "edit" as TabId,
    batchJobMode: "images" as BatchJobMode,
    batchCanRun: false,
    batchCanRetryFailed: false,
    batchCanResume: false,
    videoCanExport: false,
    running: false,
  });
  hotkeyUiRef.current = {
    tab,
    batchJobMode,
    batchCanRun,
    batchCanRetryFailed,
    batchCanResume,
    videoCanExport,
    running,
  };

  /**
   * @description デスクトップ専用ショートカット（Web 共有コンポーネントには伝播しないよう window で処理）
   * - Mod+1 / Mod+2: タブ（macOS は ⌘、Windows/Linux は Ctrl）
   * - Mod+Enter: 書き出し実行（書き出しタブかつ実行可のとき）
   * - Mod+Shift+Enter: 失敗のみ再実行
   * - Mod+Shift+Y: セッション再開（再開可能なとき）
   * - Escape: 書き出し中断
   */
  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (isTextInputTarget(e.target)) return;
      const mod = e.metaKey || e.ctrlKey;
      const u = hotkeyUiRef.current;
      const act = batchHotkeysRef.current;

      if (mod && e.key === "1") {
        e.preventDefault();
        setTab("edit");
        return;
      }
      if (mod && e.key === "2") {
        e.preventDefault();
        setTab("batch");
        return;
      }

      if (mod && e.key === "Enter") {
        if (u.tab !== "batch") return;
        if (e.shiftKey) {
          if (u.batchCanRetryFailed) {
            e.preventDefault();
            void act.retryFailedBatch();
          }
        } else if (u.batchJobMode === "images" && u.batchCanRun) {
          e.preventDefault();
          void act.runBatch();
        } else if (u.batchJobMode === "video" && u.videoCanExport) {
          e.preventDefault();
          void act.runVideoExport();
        }
        return;
      }

      if (mod && e.shiftKey && (e.key === "y" || e.key === "Y")) {
        if (u.tab === "batch" && u.batchCanResume) {
          e.preventDefault();
          void act.resumeBatch();
        }
        return;
      }

      if (e.key === "Escape" && u.running) {
        e.preventDefault();
        batchAbortRef.current?.abort();
      }
    };
    window.addEventListener("keydown", onKeyDown);
    return () => window.removeEventListener("keydown", onKeyDown);
  }, []);

  return (
    <div className="film-lab-desktop-root flex min-h-screen flex-col">
      <header className="fl-app-header fl-surface-frost">
        <span className="fl-app-title">Filmtone</span>
        <span className="fl-app-subtitle">{tApp("subtitle")}</span>
        <div className="fl-tabs ml-auto">
          <button
            type="button"
            data-state={tab === "edit" ? "active" : "inactive"}
            className="fl-tab"
            onClick={() => setTab("edit")}
          >
            {tApp("tabEdit")}
          </button>
          <button
            type="button"
            data-state={tab === "batch" ? "active" : "inactive"}
            className="fl-tab"
            onClick={() => setTab("batch")}
            aria-label={tApp("tabBatchAria")}
          >
            {tApp("tabBatch")}
          </button>
        </div>
      </header>

      {gradeSyncNotice ? (
        <div
          className="border-b border-[var(--amber-9)] bg-[var(--fl-bg-subtle)] px-4 py-2 text-xs leading-snug text-[var(--fl-text-primary)] shadow-[inset_0_2px_0_0_var(--amber-9)]"
          role="status"
          aria-live="polite"
        >
          {gradeSyncNotice}
        </div>
      ) : null}

      {desktopUpdateBanner ? (
        <div
          className="border-b border-[var(--amber-9)] bg-[var(--fl-bg-subtle)] px-4 py-3 text-xs leading-snug text-[var(--fl-text-primary)] shadow-[inset_0_2px_0_0_var(--amber-9)]"
          role="alert"
        >
          <p className="mb-2">
            {tApp("updateBannerBody", {
              version: desktopUpdateBanner.latestVersion,
            })}
          </p>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              className="fl-btn-primary text-xs"
              onClick={() => {
                void window.filmLabBatch.openExternalUrl(
                  desktopUpdateBanner.downloadPageUrl,
                );
              }}
            >
              {tApp("updateBannerOpen")}
            </button>
            {desktopUpdateBanner.releaseNotesUrl ? (
              <button
                type="button"
                className="fl-btn-secondary text-xs"
                onClick={() => {
                  void window.filmLabBatch.openExternalUrl(
                    desktopUpdateBanner.releaseNotesUrl!,
                  );
                }}
              >
                {tApp("updateBannerNotes")}
              </button>
            ) : null}
            <button
              type="button"
              className="fl-btn-secondary text-xs"
              onClick={() => {
                const v = desktopUpdateBanner.latestVersion;
                void window.filmLabBatch.dismissDesktopUpdate(v);
                setDesktopUpdateBanner(null);
              }}
            >
              {tApp("updateBannerLater")}
            </button>
          </div>
        </div>
      ) : null}

      <div className="relative flex min-h-0 flex-1 flex-col">
      <div
        className={
          tab === "edit"
            ? "relative z-10 flex min-h-0 flex-1 flex-col gap-4 overflow-hidden fl-main"
            : DESKTOP_INACTIVE_TAB_CLASS
        }
        aria-hidden={tab !== "edit"}
      >
          <div className="relative flex min-h-0 flex-1 flex-col gap-4 lg:min-h-0 lg:overflow-hidden">
            <section className="fl-card fl-scroll-surface relative z-0 flex min-h-0 w-full min-w-0 flex-col gap-3 overflow-y-auto max-lg:flex-none lg:absolute lg:inset-0 lg:z-0">
              <div className="fl-card-header">
                <div className="flex min-w-[140px] flex-1 flex-col gap-1.5">
                  <span className="fl-label">{tApp("presetWhenOpenLabel")}</span>
                  <select
                    value={canvasPreset}
                    onChange={(e) =>
                      setCanvasPreset(e.target.value as PresetName)
                    }
                    className="w-full max-w-xs"
                  >
                    {PRESET_NAMES.map((n) => (
                      <option key={n} value={n}>
                        {n}
                      </option>
                    ))}
                  </select>
                </div>
              </div>
              <FilmLabCanvas
                ref={filmLabCanvasRef}
                chromeLayout="stacked"
                preset={canvasPreset}
                className="w-full max-w-full self-stretch lg:max-w-none"
                fullScreen={false}
                onViewportReady={setViewport}
              />
              <hr className="fl-divider" />
              <div className="w-full max-w-full self-stretch">
                <div className="mb-2 flex items-center justify-between gap-2">
                  <span className="fl-label normal-case tracking-normal">
                    {tApp("rgbHistogram")}
                  </span>
                </div>
                <Histogram
                  viewport={viewport}
                  visible={histogramVisible}
                  variant="inline"
                />
              </div>
            </section>

            {isLgLayout && !editRightPaneExpanded ? (
              <button
                type="button"
                className="fl-edit-pane-reveal-rail"
                aria-label={tApp("openParamsPanelAria")}
                aria-expanded={false}
                aria-controls="film-lab-edit-controls-pane"
                onClick={() => setEditRightPaneExpanded(true)}
              >
                <CaretLeft size={22} weight="bold" aria-hidden />
              </button>
            ) : null}

            <div
              id="film-lab-edit-controls-pane"
              role="complementary"
              aria-label={tApp("paramsPanelAria")}
              aria-hidden={Boolean(
                isLgLayout && !editRightPaneExpanded,
              )}
              className={`fl-edit-slide-panel-shell flex min-h-0 w-full min-w-0 flex-1 flex-col max-lg:relative lg:absolute lg:inset-y-0 lg:right-0 lg:z-20 lg:h-auto lg:max-h-full lg:w-[clamp(320px,42vw,680px)] lg:max-w-[min(680px,calc(100%-1.5rem))] lg:min-w-0 lg:flex-none lg:transition-transform lg:duration-300 lg:ease-out motion-reduce:lg:transition-none ${
                editRightPaneExpanded
                  ? "lg:translate-x-0"
                  : "lg:pointer-events-none lg:translate-x-full"
              }`}
            >
              <section className="fl-card fl-card-muted fl-card--frost fl-edit-controls-pane flex h-full min-h-0 min-w-0 flex-1 flex-col overflow-hidden p-0 lg:rounded-r-none lg:rounded-l-xl">
                <div className="fl-edit-pane-toolbar fl-surface-frost hidden lg:flex">
                  <button
                    type="button"
                    className="fl-edit-pane-toolbar-btn"
                    aria-label={tApp("closeParamsPanelAria")}
                    aria-expanded={editRightPaneExpanded}
                    aria-controls="film-lab-edit-controls-pane"
                    onClick={() => setEditRightPaneExpanded(false)}
                  >
                    <CaretRight size={20} weight="bold" aria-hidden />
                  </button>
                </div>
                <div className="fl-scroll-surface min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-3 sm:px-4">
                  <ControlPanel
                    viewport={viewport}
                    histogramVisible={histogramVisible}
                    onHistogramToggle={() =>
                      setHistogramVisible((v) => !v)
                    }
                    filmLabCanvasRef={filmLabCanvasRef}
                    smartLookApiBaseUrl={
                      import.meta.env.VITE_FILM_LAB_API_ORIGIN
                    }
                    serverVerifiedSupporter={
                      import.meta.env.VITE_FILM_LAB_ASSUME_SUPPORTER ===
                      "true"
                    }
                    autoRestoreStoredSession={false}
                  />
                </div>
                <div className="fl-sticky-footer fl-surface-frost rounded-b-xl lg:rounded-bl-xl">
                  <button
                    type="button"
                    className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
                    onClick={syncPreviewToBatch}
                  >
                    {tApp("sendGradeToExport")}
                  </button>
                  <div className="mt-2 flex flex-wrap items-center gap-1.5">
                    <p className="fl-caption">{tApp("sendGradeCaption")}</p>
                    <HelpHint
                      tip={tApp("sendGradeTip")}
                      assistiveLabel={tApp("sendGradeTipAria")}
                    />
                  </div>
                </div>
              </section>
            </div>
          </div>
      </div>

      <div
        className={
          tab === "batch"
            ? "relative z-10 fl-main fl-main-batch fl-scroll-surface flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto"
            : DESKTOP_INACTIVE_TAB_CLASS
        }
        aria-hidden={tab !== "batch"}
      >
          <BatchTabPanel
            batchJobMode={batchJobMode}
            onBatchJobModeChange={setBatchJobMode}
            persistedSession={persistedSession}
            batchCanResume={batchCanResume}
            running={running}
            onResumeBatch={resumeBatch}
            onDiscardPersistedSession={discardPersistedSession}
            batchPresetChoice={batchPresetChoice}
            onBatchPresetChoiceChange={applyBatchPreset}
            importedGradeLabel={importedGradeLabel}
            onImportGradeJson={importGradeJson}
            onExportGradeJson={exportGrade}
            inputDir={inputDir}
            outputDir={outputDir}
            onPickInputDir={async () => {
              const p = await window.filmLabBatch.pickInputDir();
              setInputDir(p);
            }}
            onPickOutputDir={async () => {
              const p = await window.filmLabBatch.pickOutputDir();
              setOutputDir(p);
            }}
            batchFormat={batchFormat}
            onBatchFormatChange={setBatchFormat}
            batchOutputSuffix={batchOutputSuffix}
            onBatchOutputSuffixChange={setBatchOutputSuffix}
            batchCanRun={batchCanRun}
            batchCanRetryFailed={batchCanRetryFailed}
            onRunBatch={runBatch}
            onRetryFailedBatch={retryFailedBatch}
            onAbortBatch={() => {
              void window.filmLabBatch.videoExportAbort().catch(() => {});
              batchAbortRef.current?.abort();
            }}
            batchProgress={batchProgress}
            lastBatchSummary={lastBatchSummary}
            videoInputPath={videoInputPath}
            videoProbeLabel={videoProbeLabel}
            videoCanExport={videoCanExport}
            onPickVideoFile={pickVideoFile}
            onRunVideoExport={runVideoExport}
            videoExportSuccessNonce={videoExportSuccessNonce}
            canApplyEditGradeToBatch={Boolean(viewport)}
            onApplyEditGradeToBatch={syncPreviewToBatch}
            editToExportSyncedAtMs={editToExportSyncedAtMs}
            onReapplyBatchPresetBaseline={() => {
              applyBatchPreset(batchPresetChoice);
            }}
          />

          <pre className="fl-log">{logText || tApp("logPlaceholder")}</pre>
      </div>
      </div>
    </div>
  );
}
