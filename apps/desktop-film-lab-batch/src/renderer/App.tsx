/**
 * Film Lab デスクトップ — 編集（Web 踏襲）とバッチの 2 モード
 *
 * @overview バッチの正はメモリ上の BatchGradeState。編集タブでプレビューし「バッチに反映」で同期する。
 * @limitations プレビュー上の LUT をバッチに自動複製はしない（JSON Import か .cube 再適用）。
 * シェルの色・段差は globals.css の Radix スケール準拠トークン（html.dark.dark-theme）に集約する。
 *
 * @description 編集タブのレイアウト（デスクトップ向け）
 * - 狭い画面では「上＝プレビュー＋ヒスト／下＝コントロール」の縦積み。
 * - `lg` 以上ではプレビュー領域を親いっぱい（absolute inset-0）にし、右パネルはその上に
 *   `translateX` でスライドインする。閉じたあともキャンバスはウィンドウ幅いっぱいを使う。
 * - 開閉は Phosphor Icons（CaretLeft / CaretRight）＋ aria-label。`prefers-reduced-motion` は Tailwind で短縮。
 */
import { CaretLeft, CaretRight } from "@phosphor-icons/react";
import { useCallback, useEffect, useRef, useState } from "react";
import { FilmLabCanvas, type FilmLabCanvasRef } from "@film-lab/components/FilmLabCanvas";
import { ControlPanel } from "@film-lab/components/ControlPanel";
import { Histogram } from "@film-lab/components/ui/Histogram";
import type { Viewport } from "@film-lab/core/Viewport";
import { PRESETS, type PresetName } from "film-lab-core";
import {
  batchGradeStateFromPreset,
  resolveGradeFromJsonText,
  runBatchPipeline,
  type BatchFormat,
  type BatchGradeState,
  type BatchPipelineProgressPayload,
  type BatchPipelineSummary,
} from "./batch-pipeline";
import { exportGradeJsonText } from "./grade-io";
import { viewportRecordToParams } from "./viewport-to-params";

type TabId = "edit" | "batch";

const PRESET_NAMES = Object.keys(PRESETS) as PresetName[];

export default function App() {
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
  const [running, setRunning] = useState(false);
  /** @description バッチ中断用。Run 開始時に差し替え、完了・エラーで null */
  const batchAbortRef = useRef<AbortController | null>(null);
  /** @description プログレスバー用。処理中のみセット */
  const [batchProgress, setBatchProgress] =
    useState<BatchPipelineProgressPayload | null>(null);
  /** @description 直近の正常終了したバッチの集計（画面下に短く残す） */
  const [lastBatchSummary, setLastBatchSummary] =
    useState<BatchPipelineSummary | null>(null);
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

  const appendLog = useCallback((line: string) => {
    setLogText((t) => `${t}${line}\n`);
  }, []);

  const syncPreviewToBatch = useCallback(() => {
    if (!viewport) {
      appendLog("（編集）Viewport 未準備のため同期できません");
      return;
    }
    const raw = viewport.getParams();
    const params = viewportRecordToParams(raw, batchGrade.params.halationHue);
    setBatchGrade({
      params,
      lutIntensity: 1,
      lutData: null,
      lutSize: 0,
    });
    setImportedGradeLabel(null);
    appendLog("（バッチ用ルック）プレビューから数値パラメータを反映しました（LUT は含みません）");
  }, [viewport, batchGrade.params.halationHue, appendLog]);

  const applyBatchPreset = (name: PresetName) => {
    setBatchPresetChoice(name);
    setBatchGrade(batchGradeStateFromPreset(name));
    setImportedGradeLabel(null);
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
      appendLog(`Grade JSON を読み込み: ${p}`);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(`Grade JSON エラー: ${msg}`);
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
    appendLog("Grade JSON をダウンロードしました（film-lab-grade.json）");
  };

  const runBatch = async () => {
    if (!inputDir || !outputDir) return;
    const formatSel = document.getElementById(
      "batch-format-sel",
    ) as HTMLSelectElement | null;
    const format = (formatSel?.value ?? "jpeg") as BatchFormat;

    setLogText("");
    setLastBatchSummary(null);
    const abortController = new AbortController();
    batchAbortRef.current = abortController;

    appendLog(`Input: ${inputDir}`);
    appendLog(`Output: ${outputDir}`);
    appendLog(
      importedGradeLabel
        ? `Grade: imported JSON + メモリ上の Params`
        : `Grade: メモリ（プリセット ${batchPresetChoice} またはプレビュー同期）`,
    );
    appendLog(`Format: ${format}`);

    setRunning(true);
    try {
      const images = await window.filmLabBatch.listImages(inputDir);
      appendLog(`Images: ${images.length}`);
      if (images.length === 0) {
        appendLog("画像がありません（.jpg / .jpeg / .png）");
        return;
      }
      setBatchProgress({
        current: 0,
        total: images.length,
        fileName: "準備中…",
      });
      const summary = await runBatchPipeline({
        api: window.filmLabBatch,
        grade: batchGrade,
        imagePaths: images,
        outputDir,
        format,
        onLog: appendLog,
        signal: abortController.signal,
        onProgress: setBatchProgress,
      });
      setLastBatchSummary(summary);
      appendLog("Done.");
    } catch (e) {
      if (e instanceof DOMException && e.name === "AbortError") {
        appendLog("ユーザーにより中断されました。");
      } else {
        const msg = e instanceof Error ? e.message : String(e);
        appendLog(`FATAL: ${msg}`);
      }
    } finally {
      batchAbortRef.current = null;
      setBatchProgress(null);
      setRunning(false);
    }
  };

  const batchCanRun = Boolean(inputDir && outputDir) && !running;

  return (
    <div className="film-lab-desktop-root flex min-h-screen flex-col">
      <header className="fl-app-header">
        <span className="fl-app-title">Film Lab</span>
        <span className="fl-app-subtitle">Desktop（ローカルバッチ）</span>
        <div className="fl-tabs ml-auto">
          <button
            type="button"
            data-state={tab === "edit" ? "active" : "inactive"}
            className="fl-tab"
            onClick={() => setTab("edit")}
          >
            編集
          </button>
          <button
            type="button"
            data-state={tab === "batch" ? "active" : "inactive"}
            className="fl-tab"
            onClick={() => setTab("batch")}
          >
            バッチ
          </button>
        </div>
      </header>

      {tab === "edit" ? (
        <div className="fl-main flex min-h-0 flex-1 flex-col gap-4 overflow-hidden">
          <div className="relative flex min-h-0 flex-1 flex-col gap-4 lg:min-h-0 lg:overflow-hidden">
            <section className="fl-card relative z-0 flex min-h-0 w-full min-w-0 flex-col gap-3 overflow-y-auto max-lg:flex-none lg:absolute lg:inset-0 lg:z-0">
              <div className="fl-card-header">
                <div className="flex min-w-[140px] flex-1 flex-col gap-1.5">
                  <span className="fl-label">
                    キャンバス用プリセット（初期読み込み）
                  </span>
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
                    RGB ヒストグラム
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
                aria-label="パラメータパネルを開く"
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
              aria-label="Film Lab パラメータ"
              aria-hidden={Boolean(
                isLgLayout && !editRightPaneExpanded,
              )}
              className={`fl-edit-slide-panel-shell flex min-h-0 w-full min-w-0 flex-1 flex-col max-lg:relative lg:absolute lg:inset-y-0 lg:right-0 lg:z-20 lg:h-auto lg:max-h-full lg:w-[clamp(320px,42vw,680px)] lg:max-w-[min(680px,calc(100%-1.5rem))] lg:min-w-0 lg:flex-none lg:transition-transform lg:duration-300 lg:ease-out motion-reduce:lg:transition-none ${
                editRightPaneExpanded
                  ? "lg:translate-x-0"
                  : "lg:pointer-events-none lg:translate-x-full"
              }`}
            >
              <section className="fl-card fl-card-muted fl-edit-controls-pane flex h-full min-h-0 min-w-0 flex-1 flex-col overflow-hidden p-0 lg:rounded-r-none lg:rounded-l-xl">
                <div className="fl-edit-pane-toolbar hidden lg:flex">
                  <button
                    type="button"
                    className="fl-edit-pane-toolbar-btn"
                    aria-label="パラメータパネルを閉じる"
                    aria-expanded={editRightPaneExpanded}
                    aria-controls="film-lab-edit-controls-pane"
                    onClick={() => setEditRightPaneExpanded(false)}
                  >
                    <CaretRight size={20} weight="bold" aria-hidden />
                  </button>
                </div>
                <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-3 py-3 sm:px-4">
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
                <div className="fl-sticky-footer rounded-b-xl lg:rounded-bl-xl">
                  <button
                    type="button"
                    className="fl-btn-primary w-full sm:w-auto sm:min-w-[220px]"
                    onClick={syncPreviewToBatch}
                  >
                    バッチ用ルックに反映（数値パラメータ）
                  </button>
                  <p className="fl-caption mt-2 max-w-prose">
                    出力フォルダで使うルックを、いまのプレビューからコピーします。LUT
                    はバッチタブで JSON 読込するか、後続で .cube 連携してください。
                  </p>
                </div>
              </section>
            </div>
          </div>
        </div>
      ) : (
        <div className="fl-main flex flex-1 flex-col gap-4">
          <div
            className="rounded-lg border px-3 py-2.5 text-xs leading-relaxed"
            style={{
              borderColor: "var(--amber-6)",
              background: "var(--amber-2)",
              color: "var(--amber-12)",
            }}
          >
            上書き防止のため、出力フォルダは入力フォルダと別にしてください。
          </div>

          <section className="fl-card">
            <div className="grid gap-4 text-sm md:grid-cols-2">
              <label className="flex flex-col gap-1.5">
                <span className="fl-label">バッチ用プリセット（クイック）</span>
                <select
                  value={batchPresetChoice}
                  onChange={(e) =>
                    applyBatchPreset(e.target.value as PresetName)
                  }
                  className="w-full max-w-md"
                >
                  {PRESET_NAMES.map((n) => (
                    <option key={n} value={n}>
                      {n}
                    </option>
                  ))}
                </select>
              </label>
              <div className="flex flex-col gap-1">
                <span className="fl-label">現在のバッチルック</span>
                <span
                  className="text-xs leading-snug"
                  style={{ color: "var(--fl-text-primary)" }}
                >
                  {importedGradeLabel
                    ? `JSON: ${importedGradeLabel}`
                    : `メモリ（${batchPresetChoice} または編集タブから同期）`}
                </span>
              </div>
            </div>

            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                className="fl-btn-secondary"
                onClick={importGradeJson}
              >
                Import grade JSON（任意）
              </button>
              <button
                type="button"
                className="fl-btn-secondary"
                onClick={exportGrade}
              >
                Export grade JSON
              </button>
            </div>

            <div className="grid gap-3 md:grid-cols-2">
              <div className="flex flex-wrap items-center gap-2">
                <span className="w-14 shrink-0 fl-label normal-case">Input</span>
                <button
                  type="button"
                  className="fl-btn-secondary"
                  onClick={async () => {
                    const p = await window.filmLabBatch.pickInputDir();
                    setInputDir(p);
                  }}
                >
                  Choose folder
                </button>
                <span className="fl-caption min-w-0 flex-1 truncate">
                  {inputDir ?? "—"}
                </span>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                <span className="w-14 shrink-0 fl-label normal-case">Output</span>
                <button
                  type="button"
                  className="fl-btn-secondary"
                  onClick={async () => {
                    const p = await window.filmLabBatch.pickOutputDir();
                    setOutputDir(p);
                  }}
                >
                  Choose folder
                </button>
                <span className="fl-caption min-w-0 flex-1 truncate">
                  {outputDir ?? "—"}
                </span>
              </div>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <span className="fl-label normal-case">Format</span>
              <select
                id="batch-format-sel"
                className="min-w-[6.5rem]"
                defaultValue="jpeg"
              >
                <option value="jpeg">JPEG</option>
                <option value="png">PNG</option>
              </select>
            </div>

            <div className="flex flex-wrap items-center gap-2">
              <button
                type="button"
                className="fl-btn-primary max-w-xs"
                disabled={!batchCanRun}
                onClick={() => void runBatch()}
              >
                Run batch
              </button>
              <button
                type="button"
                className="fl-btn-secondary"
                disabled={!running}
                aria-label="実行中のバッチ処理を中断する"
                onClick={() => batchAbortRef.current?.abort()}
              >
                中断
              </button>
            </div>

            {running && batchProgress && batchProgress.total > 0 ? (
              <div
                className="fl-batch-progress"
                aria-live="polite"
                aria-busy="true"
              >
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

            {lastBatchSummary && !running ? (
              <p className="fl-caption" aria-live="polite">
                直近の結果: 成功 {lastBatchSummary.ok} 枚 · 読込エラー{" "}
                {lastBatchSummary.loadFail} · 書込エラー{" "}
                {lastBatchSummary.writeFail}
              </p>
            ) : null}
          </section>

          <pre className="fl-log">{logText || "ログはここに表示されます。"}</pre>
        </div>
      )}
    </div>
  );
}
