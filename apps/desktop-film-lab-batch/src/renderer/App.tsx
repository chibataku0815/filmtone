/**
 * Film Lab デスクトップ — 編集・写真まとめ書き出し・動画 1 本書き出しの 3 トップタブ
 *
 * @overview 書き出し用ルックの正はメモリ上の BatchGradeState。編集タブでプレビューし「色を書き出しへ送る」で同期する。
 * 編集／各書き出しは **右パネルの中身を切り替え**、Canvas はアンマウントしない（WebGL Viewport を維持し「反映」を常に効かせる）。
 * @limitations プレビュー上の LUT を書き出しへ自動複製はしない（JSON Import か .cube 再適用）。
 * シェルの色・段差は globals.css の Radix スケール準拠トークン（html.dark.dark-theme）に集約する。
 *
 * @description 編集タブのレイアウト（デスクトップ向け）
 * - 狭い画面では「上＝プレビュー＋ヒスト／下＝コントロール」の縦積み。
 * - `lg` 以上ではプレビュー領域を親いっぱい（absolute inset-0）にし、右パネルはその上に
 *   `translateX` でスライドインする。閉じたあともキャンバスはウィンドウ幅いっぱいを使う。
 * - 開閉は Phosphor Icons の compact toggle＋ aria-label。`prefers-reduced-motion` は Tailwind で短縮。
 */
import {
  ArrowClockwise,
  CaretRight,
  CheckCircle,
  DownloadSimple,
  Export,
  FilmStrip,
  FolderOpen,
  Images,
  SidebarSimple,
  SlidersHorizontal,
} from "@phosphor-icons/react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useLocale, useTranslations } from "next-intl";
import {
  FILMTONE_DEFAULT_BASE_PRESET,
  buildOpticalParamPatch,
  createFilmtoneDefaultParams,
  type CameraOptics,
  type OpticalRecommendationV1,
  type Params,
  type PresetName,
} from "film-lab-core";
import {
  FilmLabCanvas,
  FilmLabWebglPanelBackdrop,
  VideoTransportControls,
  type FilmLabCanvasRef,
  type FilmLabCanvasPreprocessResult,
  type FilmLabCanvasPreviewStatus,
  type FilmLabInteractiveSourceInfo,
} from "film-lab-ui";
import { FilmLabControlPanelCore } from "film-lab-ui";
import { Histogram } from "film-lab-ui";
import { HelpHint } from "./batch-tab/HelpHint";
import type { HdrPreparationPolicy, SourceVideoMetadata } from "./desktop-api";
import { GradeSyncToast, type GradeSyncToastPayload } from "./GradeSyncToast";
import {
  OpticalFinishRecommendationPanel,
  type OpticalRecommendationDebugInfo,
  type OpticalFinishRecommendationPanelState,
} from "./OpticalFinishRecommendationPanel";
import { QualityBadge } from "./QualityBadge";
import type { Viewport, ViewportCapabilities } from "film-lab-renderer";
import {
  initialOutcomes,
  parseFilmLabBatchSessionV1,
  pathsNotSucceeded,
  sessionHasRemainingWork,
  type FilmLabBatchSessionV1,
} from "./batch-session";
import {
  batchGradeStateFromPreset,
  createDefaultBatchGradeState,
  resolveGradeFromJsonText,
  runBatchPipeline,
  sanitizeBatchFilenameSuffix,
  type BatchFormat,
  type BatchGradeState,
  type BatchPipelineProgressPayload,
  type BatchPipelineSummary,
} from "./batch-pipeline";
import {
  needsMezzanineTranscode,
  runVideoExportPipeline,
  type VideoExportProgress,
  type VideoExportPipelineUserMessages,
} from "./video-export-pipeline";
import { applyBatchGradeToViewport } from "./offscreen/apply-batch-grade-to-viewport";
import {
  assertVideoImportWithinCaps,
  computeExportFrameCount,
  computeVideoExportDimensions,
  VIDEO_EXPORT_FPS,
  VIDEO_IMPORT_MAX_DURATION_SEC,
} from "./video-export-constants";
import { exportGradeJsonText } from "./grade-io";
import {
  type AppliedOpticalRecommendationMetadata,
  buildFilmtoneExportSession,
  buildPhotoMetadataSidecarPath,
  buildVideoMetadataSidecarPath,
  createEmptyMetadataLutRefs,
  createMetadataLutRefFromRuntime,
  exportFilmtoneExportSessionJsonText,
  type MetadataLookSource,
  type MetadataLutRefs,
} from "./export-metadata-session";
import { resolveImportedMetadataJson } from "./metadata-json-runtime";
import {
  createSceneAnalysisCacheKey,
  DesktopOpticalAnalyzerService,
  type SampledAnalyzerFrame,
} from "./optical-scene-analysis";
import {
  BffAiScenePickProvider,
  type AiScenePickProvider,
  type AiScenePickResult,
} from "./ai-scene-pick";
import { buildAiRecommendation } from "./ai-recommendation-builder";
import { viewportRecordToParams } from "./viewport-to-params";
import {
  BatchTabCompactRunFooter,
  type BatchJobMode,
  type DesktopInteractivePreviewState,
} from "./batch-tab/BatchTabPanel";
import { PhotoExportPanel } from "./batch-tab/PhotoExportPanel";
import { VideoExportPanel } from "./batch-tab/VideoExportPanel";
import type {
  DesktopUpdateAvailablePayload,
  VideoPreviewProxyCacheInfo,
} from "./desktop-api";
import {
  useProgressiveLoad,
  type ProgressiveTextureSwapPayload,
} from "./use-progressive-load";
import { formatCameraOpticsForProbeLabel } from "./video-probe-label";

/** @description 右上ツールバーとホットキー Mod+1/2/3 の対象となるトップ面 */
type TabId = "edit" | "photoExport" | "videoExport";

/**
 * @description 編集キャンバスに「ユーザー動画」が載っているか。Space キーの割当（life#75）に使います。
 * @param state `onInteractiveSourceChange` から組み立てたプレビュー状態
 */
function desktopPreviewShowsUserVideo(state: DesktopInteractivePreviewState): boolean {
  if (state.kind !== "file" || state.smartLookDerived) {
    return false;
  }
  return /\.(mp4|webm|m4v|mov)$/i.test(state.fileName);
}

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

/** @description プレビューに載せたファイル名が静止画バッチ向けか（拡張子だけで判定） */
function isRasterExportFileName(fileName: string): boolean {
  return /\.(jpe?g|png|webp|gif)$/i.test(fileName);
}

/** @description プレビューに載せたファイル名が動画書き出し向けか */
function isVideoExportFileName(fileName: string): boolean {
  return /\.(mp4|webm)$/i.test(fileName);
}

type EditLutState = {
  lut1: { name: string; data: Float32Array; size: number; intensity: number } | null;
  lut2: { name: string; data: Float32Array; size: number; intensity: number } | null;
};

function buildEditLutStateFromBatchGrade(
  grade: BatchGradeState,
  lutRefs: MetadataLutRefs,
): EditLutState {
  return {
    lut1:
      grade.lut1Data && grade.lut1Size > 0
        ? {
            name: lutRefs.lut1.displayName ?? "",
            data: grade.lut1Data,
            size: grade.lut1Size,
            intensity: grade.lut1Intensity,
          }
        : null,
    lut2:
      grade.lutData && grade.lutSize > 0
        ? {
            name: lutRefs.lut2.displayName ?? "",
            data: grade.lutData,
            size: grade.lutSize,
            intensity: grade.lutIntensity,
          }
        : null,
  };
}

/**
 * @description セッションに保存した情報だけから BatchGradeState を組み立てる（再開直後のパイプライン用）
 */
async function resolveBatchGradeSnapshot(
  s: FilmLabBatchSessionV1,
): Promise<{
  grade: BatchGradeState;
  batchPresetChoice: PresetName;
  lookSource: MetadataLookSource;
  lutRefs: MetadataLutRefs;
  syncedAtMs: number | null;
  importedFilePath: string | null;
  appliedOpticalRecommendation: AppliedOpticalRecommendationMetadata | null;
  cameraOptics: CameraOptics | null;
}> {
  if (s.importedGradePath) {
    const text = await window.filmLabBatch.readFileUtf8(s.importedGradePath);
    const restored = await resolveImportedMetadataJson(
      window.filmLabBatch,
      s.importedGradePath,
      text,
    );
    return {
      grade: restored.batchGrade,
      batchPresetChoice: restored.batchPresetChoice,
      lookSource: restored.lookSource,
      lutRefs: restored.lutRefs,
      syncedAtMs: restored.syncedAtMs,
      importedFilePath: restored.importedFilePath,
      appliedOpticalRecommendation: restored.appliedOpticalRecommendation,
      cameraOptics: restored.cameraOptics,
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
      grade: {
        params: g.params,
        depthTrack: g.depthTrack,
        lut1Intensity: g.lut1Intensity,
        lut1Data: g.lut1Data,
        lut1Size: g.lut1Size,
        lutIntensity: g.lutIntensity,
        lutData: g.lutData,
        lutSize: g.lutSize,
      },
      batchPresetChoice: s.batchPresetChoice,
      lookSource: "preset",
      lutRefs: createEmptyMetadataLutRefs(),
      syncedAtMs: null,
      importedFilePath: null,
      appliedOpticalRecommendation: null,
      cameraOptics: null,
    };
  }
  return {
    grade: batchGradeStateFromPreset(s.batchPresetChoice),
    batchPresetChoice: s.batchPresetChoice,
    lookSource: "preset",
    lutRefs: createEmptyMetadataLutRefs(),
    syncedAtMs: null,
    importedFilePath: null,
    appliedOpticalRecommendation: null,
    cameraOptics: null,
  };
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

/**
 * @description Dev-only PoC toggle for AI scene pick. Flip via DevTools:
 * `localStorage.setItem('filmtone.scenePickDev','1')` + reload,
 * or reach the app with `?aiScenePick=1`. Read once at module load to keep
 * the side-path out of the heuristic flow when disabled.
 */
const AI_SCENE_PICK_DEV_ENABLED = (() => {
  if (typeof window === "undefined") return false;
  try {
    if (window.localStorage?.getItem("filmtone.scenePickDev") === "1") {
      return true;
    }
  } catch {
    // localStorage access can throw in sandboxed contexts.
  }
  try {
    const search =
      typeof window.location?.search === "string" ? window.location.search : "";
    return new URLSearchParams(search).get("aiScenePick") === "1";
  } catch {
    return false;
  }
})();

type AiScenePickPanelState =
  | { status: "idle" }
  | { status: "running" }
  | {
      status: "ready";
      result: AiScenePickResult;
      frames: SampledAnalyzerFrame[];
    }
  | { status: "error"; message: string };

export default function App() {
  const tApp = useTranslations("film-lab.desktop.app");
  const tFilmLab = useTranslations("film-lab");
  const tLogs = useTranslations("film-lab.desktop.logs");
  const locale = useLocale();
  const appVersion = String(
    import.meta.env.VITE_FILMTONE_DESKTOP_VERSION ?? "0.0.0",
  );

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

  /**
   * @description 途中の写真バッチがあって初回だけ `photoExport` タブを開いたか。
   *   ユーザーが他タブへ移動したあとに再度上書きしない。
   */
  const resumeTabAutoOpenedRef = useRef(false);

  /** @description スマートルックがキャンバス JPEG を取得するための ref（Web のフルページと同じ配線） */
  const filmLabCanvasRef = useRef<FilmLabCanvasRef | null>(null);
  /** @description Web 版 lg 展開と同じ WebGL 切り出しグラス用（FilmLabWebglPanelBackdrop） */
  const filmLabEditFrostPanelRef = useRef<HTMLElement | null>(null);
  const [tab, setTab] = useState<TabId>("edit");
  const [viewport, setViewport] = useState<Viewport | null>(null);
  const [viewportCapabilities, setViewportCapabilities] =
    useState<ViewportCapabilities | null>(null);
  const [previewStatus, setPreviewStatus] = useState<FilmLabCanvasPreviewStatus>({
    state: "starting",
    hasActiveVideo: false,
    canRecover: true,
  });
  const previewStatusRef = useRef(previewStatus);
  useEffect(() => {
    previewStatusRef.current = previewStatus;
  }, [previewStatus]);
  const [histogramVisible, setHistogramVisible] = useState(true);
  const [compareUi, setCompareUi] = useState<{
    compareMode: boolean;
    activeSlot: "A" | "B";
  }>({
    compareMode: false,
    activeSlot: "A",
  });
  /**
   * @description キャンバス・共有コントロール・書き出し同期が共通で参照する現在のプリセット名です。
   * 検索付きプリセットセレクトが更新し、キャンバスの既定ルックと書き出しタブの起点に使います。
   */
  const [canvasPreset, setCanvasPreset] = useState<PresetName>(
    FILMTONE_DEFAULT_BASE_PRESET,
  );
  const [canvasInitialGradeParams, setCanvasInitialGradeParams] =
    useState<Params | null>(() => createFilmtoneDefaultParams());

  const [batchGrade, setBatchGrade] = useState<BatchGradeState>(() =>
    createDefaultBatchGradeState(),
  );
  const [batchPresetChoice, setBatchPresetChoice] =
    useState<PresetName>(FILMTONE_DEFAULT_BASE_PRESET);
  const [batchLookSource, setBatchLookSource] =
    useState<MetadataLookSource>("preset");
  const [batchLutRefs, setBatchLutRefs] = useState<MetadataLutRefs>(
    createEmptyMetadataLutRefs,
  );
  const [appliedOpticalRecommendation, setAppliedOpticalRecommendation] =
    useState<AppliedOpticalRecommendationMetadata | null>(null);
  const [sourceCameraOptics, setSourceCameraOptics] =
    useState<CameraOptics | null>(null);
  /** @description 最後に import した JSON ファイル。session 復元にも使うため、表示上の look source とは分離する。 */
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
  /**
   * @description 編集キャンバスが「いま何を見せているか」。書き出し入力（フォルダ／動画）との関係を Batch 側で説明する（life#83）。
   */
  const [interactivePreviewSource, setInteractivePreviewSource] =
    useState<DesktopInteractivePreviewState>({ kind: "sample" });
  const [opticalRecommendationPanel, setOpticalRecommendationPanel] =
    useState<OpticalFinishRecommendationPanelState>({ state: "idle" });
  const [opticalRecommendationDebugInfo, setOpticalRecommendationDebugInfo] =
    useState<OpticalRecommendationDebugInfo | null>(null);
  const [opticalRecommendationEventLog, setOpticalRecommendationEventLog] =
    useState<string[]>([]);
  const [opticalAnalysisRetryNonce, setOpticalAnalysisRetryNonce] = useState(0);
  const opticalAnalyzerServiceRef = useRef<DesktopOpticalAnalyzerService | null>(
    null,
  );
  if (opticalAnalyzerServiceRef.current === null) {
    opticalAnalyzerServiceRef.current = new DesktopOpticalAnalyzerService();
  }
  const [aiScenePickPanel, setAiScenePickPanel] = useState<AiScenePickPanelState>(
    { status: "idle" },
  );
  const aiScenePickProviderRef = useRef<AiScenePickProvider | null>(null);
  if (AI_SCENE_PICK_DEV_ENABLED && aiScenePickProviderRef.current === null) {
    aiScenePickProviderRef.current = new BffAiScenePickProvider();
  }
  /**
   * @description AI pick は LLM 課金が発生するので cacheKey 単位でメモ化する。
   * heuristic analyzer 側は cache-hit で同じ Promise を返すが、そこから
   * 走る AI pick 側はキャッシュされていないため、同一クリップで useEffect が
   * 再実行される（preview ready の flip など）だけで毎回 LLM を叩いていた。
   */
  const aiScenePickResultCacheRef = useRef<Map<string, AiScenePickResult>>(
    new Map(),
  );
  const aiScenePickInflightRef = useRef<Set<string>>(new Set());
  const progressiveLoad = useProgressiveLoad();
  const canvasHasUserVideo = useMemo(
    () =>
      desktopPreviewShowsUserVideo(interactivePreviewSource) &&
      progressiveLoad.qualityLabel !== "thumbnail",
    [interactivePreviewSource, progressiveLoad.qualityLabel],
  );
  /** @description ffprobe 済みのメタ（UI 表示用） */
  const [videoProbeLabel, setVideoProbeLabel] = useState<string | null>(null);
  /**
   * @description 最後に probe した動画の HDR 準備ポリシー（S-4 capability probe 経由）。
   *   capability-gated defer のときだけ `<HdrPolicyNotice />` をソース行下に表示する（Stream D）。
   */
  const [videoHdrPolicy, setVideoHdrPolicy] =
    useState<HdrPreparationPolicy | null>(null);
  /**
   * @description 動画書き出し成功のたびに増やす。書き出しタブの「初回はウィザード→成功後は一覧」だけ検知する（BatchGradeState ではない）。
   */
  const [videoExportSuccessNonce, setVideoExportSuccessNonce] = useState(0);
  /**
   * @description 編集→書き出し同期の結果を画面下のガラス風トーストで出す（ログは書き出しタブ下部のため、編集だけ見ていると気づきにくい問題の対策）
   */
  const [gradeSyncNotice, setGradeSyncNotice] = useState<GradeSyncToastPayload | null>(
    null,
  );
  /**
   * @description 編集→書き出しへ同期が成功した時刻（ms）。null のときは JSON 由来でもプリセット起点でも「直近は編集同期ではない」。
   */
  const [editToExportSyncedAtMs, setEditToExportSyncedAtMs] = useState<
    number | null
  >(null);
  const [editLut, setEditLut] = useState<EditLutState>({
    lut1: null,
    lut2: null,
  });
  /**
   * @description metadata import 時だけ、編集パネルを imported params で再初期化して
   * プレビューと右パネルの数値状態を揃える。
   */
  const [importedPreviewParams, setImportedPreviewParams] = useState<
    BatchGradeState["params"] | null
  >(null);
  const [importedPreviewGrade, setImportedPreviewGrade] =
    useState<BatchGradeState | null>(null);
  const [importedPreviewPanelNonce, setImportedPreviewPanelNonce] = useState(0);
  const [paramsChangeNonce, setParamsChangeNonce] = useState(0);
  const [syncedAtNonce, setSyncedAtNonce] = useState(0);

  /**
   * @description 共有コントロールからのパラメータ変更を 1 箇所で受け、親の再レンダーで
   * コールバック参照が毎回変わらないようにします。
   */
  const handleEditParamsChange = useCallback(() => {
    setParamsChangeNonce((n) => n + 1);
  }, []);

  const formatOpticalAnalysisEvent = useCallback((message: string) => {
    return `${new Date().toISOString().slice(11, 23)} ${message}`;
  }, []);

  const replaceOpticalAnalysisEventLog = useCallback(
    (message: string) => {
      setOpticalRecommendationEventLog([formatOpticalAnalysisEvent(message)]);
    },
    [formatOpticalAnalysisEvent],
  );

  const appendOpticalAnalysisEvent = useCallback(
    (message: string) => {
      setOpticalRecommendationEventLog((current) => [
        ...current.slice(-11),
        formatOpticalAnalysisEvent(message),
      ]);
    },
    [formatOpticalAnalysisEvent],
  );

  /**
   * @description LUT 変更も同じく安定したコールバックにまとめ、子コンポーネント側の
   * effect 依存で無限再描画にならないようにします。
   */
  const handleEditLutChange = useCallback((nextLutState: EditLutState) => {
    setEditLut(nextLutState);
    setParamsChangeNonce((n) => n + 1);
  }, []);

  /**
   * @description ヒストグラムの表示切り替えを安定した参照で渡します。
   */
  const handleHistogramToggle = useCallback(() => {
    if (!viewportCapabilities?.supportsHistogram) {
      return;
    }
    setHistogramVisible((v) => !v);
  }, [viewportCapabilities?.supportsHistogram]);

  const previewSupportsHistogram = viewportCapabilities?.supportsHistogram ?? false;
  const previewSupportsBeforeAfter =
    viewportCapabilities?.supportsBeforeAfter ?? false;
  const previewSupportsABCompare =
    viewportCapabilities?.supportsABCompare ?? false;

  /**
   * @description main が公開 JSON を読んで送る「新しい版があります」バナー（案 C）
   */
  const [desktopUpdateBanner, setDesktopUpdateBanner] =
    useState<DesktopUpdateAvailablePayload | null>(null);
  const [proxyCacheInfo, setProxyCacheInfo] =
    useState<VideoPreviewProxyCacheInfo | null>(null);
  const [purgingProxyCache, setPurgingProxyCache] = useState(false);

  /**
   * @description 更新通知の購読。アンマウント時に解除する。
   *   bare Vite でレンダラだけ開いたときは `window.filmLabBatch` が無いので何もしない（Electron では preload が注入する）。
   */
  useEffect(() => {
    const api = window.filmLabBatch;
    if (!api?.subscribeDesktopUpdateAvailable) {
      return;
    }
    const unsubscribe = api.subscribeDesktopUpdateAvailable((payload) => {
      setDesktopUpdateBanner(payload);
    });
    return unsubscribe;
  }, []);

  const refreshProxyCacheInfo = useCallback(async (): Promise<void> => {
    const api = window.filmLabBatch;
    if (!api?.videoPreviewGetProxyCacheInfo) {
      return;
    }
    try {
      const info = await api.videoPreviewGetProxyCacheInfo();
      setProxyCacheInfo(info);
    } catch (error) {
      console.warn("refreshProxyCacheInfo failed", error);
    }
  }, []);

  useEffect(() => {
    void refreshProxyCacheInfo();
  }, [refreshProxyCacheInfo]);

  useEffect(() => {
    if (!progressiveLoad.proxyPath) {
      return;
    }
    void refreshProxyCacheInfo();
  }, [progressiveLoad.proxyPath, refreshProxyCacheInfo]);

  useEffect(() => {
    if (!viewport || !importedPreviewGrade) {
      return;
    }
    applyBatchGradeToViewport(viewport, importedPreviewGrade);
  }, [viewport, importedPreviewGrade]);

  /**
   * @description 写真バッチ／動画書き出し中は main 側で通知をキューに残す
   */
  useEffect(() => {
    const api = window.filmLabBatch;
    if (!api?.setExportBusyForUpdateCheck) {
      return;
    }
    void api.setExportBusyForUpdateCheck(running);
  }, [running]);

  /**
   * @description Phase 0 WebGPU 移行のゴールデン撮影用テストハーネス。
   *   `?__test=1` URL クエリが有ったときだけ `window.__filmtoneTest` を公開する。
   *   本番ビルド（`import.meta.env.PROD === true`）では更に `__test_prod_override=1` が必要で、
   *   配信ビルドで誤って API が露出しないようにする。
   *
   *   Viewport が attach されたあとに配線するため `viewport` を依存に含める。
   *   `filmLabCanvasRef` は React ref のため再レンダー契機にはならないが意図を示すため列挙する。
   */
  useEffect(() => {
    if (typeof window === "undefined") return;
    const search = new URLSearchParams(window.location.search);
    if (search.get("__test") !== "1") return;
    if (import.meta.env.PROD === true && search.get("__test_prod_override") !== "1") {
      return;
    }

    const harness = {
      getViewport: (): Viewport | null => viewport,
      getCanvasRef: (): FilmLabCanvasRef | null => filmLabCanvasRef.current,
      getCanvasEl: (): HTMLCanvasElement | null =>
        filmLabCanvasRef.current?.getWebGlCanvas() ?? null,
      setParams: (p: Record<string, number | string>): void => {
        viewport?.setParams(p);
      },
      setExportFlipY: (flip: boolean): void => {
        viewport?.setExportFlipY(flip);
      },
      loadImage: async (pngBase64Body: string): Promise<boolean> => {
        const ref = filmLabCanvasRef.current;
        if (!ref) return false;
        return ref.replaceSourceFromPngBase64Body(pngBase64Body);
      },
      setCanvasSize: (w: number, h: number): void => {
        const canvas = filmLabCanvasRef.current?.getWebGlCanvas() ?? null;
        if (canvas) {
          canvas.width = w;
          canvas.height = h;
          canvas.style.width = `${w}px`;
          canvas.style.height = `${h}px`;
        }
        viewport?.setResolution(w, h);
      },
      waitTwoFrames: (): Promise<void> =>
        new Promise<void>((resolve) => {
          requestAnimationFrame(() => {
            requestAnimationFrame(() => resolve());
          });
        }),
    };
    (window as any).__filmtoneTest = harness;
    return () => {
      if ((window as any).__filmtoneTest === harness) {
        delete (window as any).__filmtoneTest;
      }
    };
  }, [viewport, filmLabCanvasRef]);

  /**
   * @description 右スライドパネルを画面内に出すか。全幅で同じ挙動。パネルは DOM を維持し `translateX` のみ（内部状態を捨てない）。
   */
  const [editRightPaneExpanded, setEditRightPaneExpanded] = useState(true);
  /**
   * @description 右パネル展開中は filmstrip / transport だけを左レーンへ収める。
   */
  const editTransportClassName = editRightPaneExpanded
    ? "absolute bottom-0 left-0 z-[18] right-[min(clamp(320px,42vw,680px),calc(100%-1.5rem))]"
    : "absolute bottom-0 left-0 right-0 z-[18]";
  /** @description 写真／動画の書き出しタブへ入ったとき右パネルを自動展開（Canvas 横にインライン表示） */
  useEffect(() => {
    if (tab === "photoExport" || tab === "videoExport") {
      setEditRightPaneExpanded((expanded) => (expanded ? expanded : true));
    }
  }, [tab]);

  /**
   * @description トップタブと batch 内部モードを一致させる（⌘↩ の実行先とフッターの主ボタン用）。
   *   関数型更新で同一値なら再描画を避け、Maximum update depth を防ぐ。
   */
  useEffect(() => {
    if (tab === "photoExport") {
      setBatchJobMode((m) => (m === "images" ? m : "images"));
    } else if (tab === "videoExport") {
      setBatchJobMode((m) => (m === "video" ? m : "video"));
    }
  }, [tab]);

  /**
   * @description 起動時に userData のセッション JSON を読み、フォームへ反映する。
   */
  /**
   * @description 途中の写真バッチがあるときは画像モードに揃え、再開バナーがある写真タブへ初回だけ誘導する。
   */
  useEffect(() => {
    if (!persistedSession || !sessionHasRemainingWork(persistedSession)) {
      return;
    }
    setBatchJobMode((m) => (m === "images" ? m : "images"));
    if (!resumeTabAutoOpenedRef.current) {
      resumeTabAutoOpenedRef.current = true;
      setTab("photoExport");
    }
  }, [persistedSession]);

  useEffect(() => {
    void (async () => {
      const api = window.filmLabBatch;
      /**
       * @description bare Vite のように preload bridge が無い実行環境では、
       * Desktop 固有の永続化復元をスキップしてクラッシュを防ぐ。
       */
      if (!api?.readBatchSession || !api?.getDesktopPrefs) {
        return;
      }

      const raw = await api.readBatchSession();
      const parsed = raw ? parseFilmLabBatchSessionV1(raw) : null;
      if (parsed) {
        setPersistedSession(parsed);
        setInputDir(parsed.inputDir);
        setOutputDir(parsed.outputDir);
        setBatchFormat(parsed.format);
        setBatchOutputSuffix(parsed.outputFilenameSuffix);
        setBatchPresetChoice(parsed.batchPresetChoice);
        setBatchLookSource("preset");
        setBatchLutRefs(createEmptyMetadataLutRefs());
        setAppliedOpticalRecommendation(null);
        setSourceCameraOptics(null);
        setEditToExportSyncedAtMs(null);
        try {
          const snap = await resolveBatchGradeSnapshot(parsed);
          setBatchGrade(snap.grade);
          setBatchPresetChoice(snap.batchPresetChoice);
          setBatchLookSource(snap.lookSource);
          setBatchLutRefs(snap.lutRefs);
          setAppliedOpticalRecommendation(snap.appliedOpticalRecommendation);
          setSourceCameraOptics(snap.cameraOptics);
          setImportedGradeLabel(snap.importedFilePath);
          setEditToExportSyncedAtMs(snap.syncedAtMs);
        } catch {
          setBatchGrade(batchGradeStateFromPreset(parsed.batchPresetChoice));
          setBatchLookSource("preset");
          setBatchLutRefs(createEmptyMetadataLutRefs());
          setAppliedOpticalRecommendation(null);
          setSourceCameraOptics(null);
          setImportedGradeLabel(null);
        }
        return;
      }
      const prefs = await api.getDesktopPrefs();
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
    const fileName =
      pendingVideoProgress.phase === "mezzanine"
        ? tLogs("progressMezzanine")
        : tLogs("progressVideoFrames");
    setBatchProgress({
      current: pendingVideoProgress.currentFrame,
      total: pendingVideoProgress.totalFrames,
      fileName,
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

  /**
   * @description 動画の入力パスを state に載せ、ffprobe 由来のラベルを更新する。ピッカーとプレビューからの既定反映の共通処理。
   */
  const applyPickedVideoPath = useCallback(
    async (p: string, preferredCameraOptics: CameraOptics | null = null) => {
      setVideoInputPath(p);
      setSourceCameraOptics(preferredCameraOptics);
      setVideoHdrPolicy(null);
      try {
        const meta = await window.filmLabBatch.videoExportProbe(p);
        const displayCameraOptics = preferredCameraOptics ?? meta.cameraOptics;
        setSourceCameraOptics(displayCameraOptics);
        assertVideoImportWithinCaps(meta.width, meta.height, meta.durationSec);
        const { outW, outH } = computeVideoExportDimensions(
          meta.width,
          meta.height,
        );
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
            camera: formatCameraOpticsForProbeLabel(displayCameraOptics),
          }),
        );
        setVideoHdrPolicy(
          meta.sourceVideoMetadata?.hdrPreparationPolicy ?? null,
        );
      } catch (e) {
        const msg = e instanceof Error ? e.message : String(e);
        setSourceCameraOptics(preferredCameraOptics);
        setVideoProbeLabel(null);
        setVideoHdrPolicy(null);
        appendLog(tLogs("videoMetaLogPrefix", { msg }));
      }
    },
    [appendLog, tLogs],
  );

  const restoreImportedMetadataFromPath = useCallback(
    async (p: string) => {
      const text = await window.filmLabBatch.readFileUtf8(p);
      const restored = await resolveImportedMetadataJson(
        window.filmLabBatch,
        p,
        text,
      );
      const restoredEditLut = buildEditLutStateFromBatchGrade(
        restored.batchGrade,
        restored.lutRefs,
      );
      setBatchGrade(restored.batchGrade);
      setBatchPresetChoice(restored.batchPresetChoice);
      setBatchLookSource(restored.lookSource);
      setBatchLutRefs(restored.lutRefs);
      setAppliedOpticalRecommendation(restored.appliedOpticalRecommendation);
      setSourceCameraOptics(restored.cameraOptics);
      setImportedGradeLabel(restored.importedFilePath);
      setEditToExportSyncedAtMs(restored.syncedAtMs);
      setCanvasInitialGradeParams(null);
      setCanvasPreset(restored.batchPresetChoice);
      setEditLut(restoredEditLut);
      setImportedPreviewParams(restored.batchGrade.params);
      setImportedPreviewGrade({
        params: restored.batchGrade.params,
        depthTrack: restored.batchGrade.depthTrack,
        lut1Intensity: restored.batchGrade.lut1Intensity,
        lut1Data: restored.batchGrade.lut1Data,
        lut1Size: restored.batchGrade.lut1Size,
        lutIntensity: restored.batchGrade.lutIntensity,
        lutData: restored.batchGrade.lutData,
        lutSize: restored.batchGrade.lutSize,
      });
      setImportedPreviewPanelNonce((value) => value + 1);

      if (restored.sidecar) {
        const sidecar = restored.sidecar;
        const restoreImages = sidecar.job === "images";
        setBatchJobMode(restoreImages ? "images" : "video");
        setTab(restoreImages ? "photoExport" : "videoExport");
        setInputDir(restoreImages ? sidecar.input.inputDir : null);
        setOutputDir(sidecar.output.outputDir);
        if (restoreImages) {
          setBatchFormat(sidecar.output.imageFormat ?? "jpeg");
          setBatchOutputSuffix(sidecar.output.outputFilenameSuffix ?? "-graded");
          setVideoInputPath(null);
          setVideoProbeLabel(null);
          setVideoHdrPolicy(null);
          setSourceCameraOptics(null);
        } else {
          setBatchOutputSuffix(sidecar.output.outputFilenameSuffix ?? "-graded");
          if (sidecar.input.videoInputPath) {
            await applyPickedVideoPath(
              sidecar.input.videoInputPath,
              sidecar.input.cameraOptics ?? null,
            );
          } else {
            setVideoInputPath(null);
            setVideoProbeLabel(null);
            setVideoHdrPolicy(null);
            setSourceCameraOptics(sidecar.input.cameraOptics ?? null);
          }
        }
        appendLog(tLogs("metadataJsonLoaded", { path: p }));
      } else {
        appendLog(tLogs("gradeJsonLoaded", { path: p }));
      }
      for (const warning of restored.warnings) {
        appendLog(tLogs("metadataJsonLutWarning", { detail: warning }));
      }
    },
    [applyPickedVideoPath, appendLog, tLogs],
  );

  useEffect(() => {
    if (typeof window === "undefined") return;
    const harness = (window as any).__filmtoneTest as
      | {
          importMetadataJsonFromPath?: (filePath: string) => Promise<{
            ok: boolean;
            error?: string;
          }>;
        }
      | undefined;
    if (!harness) return;
    const importFromPath = async (filePath: string) => {
      try {
        await restoreImportedMetadataFromPath(filePath);
        return { ok: true };
      } catch (error) {
        return {
          ok: false,
          error: error instanceof Error ? error.message : String(error),
        };
      }
    };
    harness.importMetadataJsonFromPath = importFromPath;
    return () => {
      if (harness.importMetadataJsonFromPath === importFromPath) {
        delete harness.importMetadataJsonFromPath;
      }
    };
  }, [restoreImportedMetadataFromPath, viewport]);

  /**
   * @description キャンバスが載せ替わったらプレビュー状態を更新し、Electron でパスが取れるときだけ書き出し入力を寄せる（life#83）。
   */
  const handleInteractiveSourceChange = useCallback(
    (info: FilmLabInteractiveSourceInfo) => {
      if (info.kind === "sample") {
        setInteractivePreviewSource({ kind: "sample" });
        return;
      }
      const smartLookDerived = info.sourceRole === "smartLookDerived";
      const absolutePath =
        typeof info.absolutePath === "string" && info.absolutePath.length > 0
          ? info.absolutePath
          : null;
      setInteractivePreviewSource({
        kind: "file",
        fileName: info.fileName,
        absolutePath,
        smartLookDerived,
      });
      if (smartLookDerived || !absolutePath) return;
      if (isVideoExportFileName(info.fileName)) {
        void applyPickedVideoPath(absolutePath);
        return;
      }
      if (isRasterExportFileName(info.fileName)) {
        const sep = Math.max(
          absolutePath.lastIndexOf("/"),
          absolutePath.lastIndexOf("\\"),
        );
        if (sep > 0) {
          setInputDir(absolutePath.slice(0, sep));
        }
      }
    },
    [applyPickedVideoPath],
  );

  /**
   * @description `contextIsolation` 下では `File.path` が空のことが多い。preload が公開する `webUtils.getPathForFile` でプレビューと書き出し入力を同期する（life#83）。
   */
  const resolveCanvasFileAbsolutePath = useCallback((file: File): string | null => {
    try {
      return window.filmLabBatch.getPathForFile(file);
    } catch (err) {
      console.warn("resolveCanvasFileAbsolutePath: getPathForFile failed", {
        functionName: "resolveCanvasFileAbsolutePath",
        fileName: file.name,
        err,
      });
      return null;
    }
  }, []);

  /**
   * @description 背景で準備できた proxy / mezzanine を、現在のキャンバスへシームレスに差し替えます。
   */
  const handleProgressiveTextureSwap = useCallback(
    async (payload: ProgressiveTextureSwapPayload): Promise<void> => {
      const canvas = filmLabCanvasRef.current;
      if (!canvas) {
        throw new Error(
          `handleProgressiveTextureSwap: FilmLabCanvasRef が未初期化です stage=${payload.stage} fileName=${payload.fileName}`,
        );
      }
      const ok = await canvas.swapProgressiveTexture(
        payload.url,
        payload.fileName,
        payload.stage,
      );
      if (!ok) {
        throw new Error(
          `handleProgressiveTextureSwap: texture swap failed stage=${payload.stage} fileName=${payload.fileName}`,
        );
      }
    },
    [],
  );

  /**
   * @description ProRes 等 Chromium 非対応コーデックの動画を、thumbnail → proxy → mezzanine の順で progressive load します。
   * 対応コーデック（H.264 等）の場合は null を返し、MediaLoader がそのまま読み込みます。
   */
  const preprocessVideoFile = useCallback(async (file: File): Promise<FilmLabCanvasPreprocessResult | null> => {
    let absPath: string;
    try {
      absPath = window.filmLabBatch.getPathForFile(file);
    } catch {
      progressiveLoad.cancel();
      return null; // path resolution failed, let MediaLoader try directly
    }

    const probe = await window.filmLabBatch.videoExportProbe(absPath);

    if (!needsMezzanineTranscode({
      videoCodec: probe.videoCodec,
      fileSizeBytes: probe.fileSizeBytes,
      absPath,
    })) {
      progressiveLoad.cancel();
      return null; // codec is supported, no transcode needed
    }

    const result = await progressiveLoad.startProgressiveLoad(
      absPath,
      file.name,
      probe,
      handleProgressiveTextureSwap,
    );
    if (!result) {
      return null;
    }
    return {
      url: result.url,
      mediaKind: result.mediaKind,
      stage: result.stage,
    };
  }, [
    handleProgressiveTextureSwap,
    progressiveLoad.cancel,
    progressiveLoad.startProgressiveLoad,
  ]);

  /**
   * @description ほかのファイルへ切り替わったら、前の Progressive loading を止めます。
   * 画像へ切り替えたときも proxy / mezzanine が残らないようにするためです。
   */
  useEffect(() => {
    const activeSourcePath = progressiveLoad.activeSourcePath;
    if (!activeSourcePath) {
      return;
    }
    if (
      interactivePreviewSource.kind === "file" &&
      interactivePreviewSource.absolutePath !== activeSourcePath
    ) {
      progressiveLoad.cancel();
    }
  }, [
    interactivePreviewSource,
    progressiveLoad.cancel,
    progressiveLoad.activeSourcePath,
  ]);

  useEffect(() => {
    const service = opticalAnalyzerServiceRef.current;
    const activeVideoElement = filmLabCanvasRef.current?.getActiveVideoElement() ?? null;
    const currentSrc =
      typeof activeVideoElement?.currentSrc === "string" &&
      activeVideoElement.currentSrc.length > 0
        ? activeVideoElement.currentSrc
        : null;
    const durationSec =
      activeVideoElement && Number.isFinite(activeVideoElement.duration)
        ? Math.max(0, activeVideoElement.duration)
        : null;
    const resolvedSourcePath =
      interactivePreviewSource.kind === "file"
        ? interactivePreviewSource.absolutePath ?? currentSrc
        : null;
    const buildDebugInfo = (
      patch: Partial<OpticalRecommendationDebugInfo>,
    ): OpticalRecommendationDebugInfo => ({
      effectState: "idle",
      previewState: previewStatus.state,
      previewReason: previewStatus.reason,
      hasActiveVideo: previewStatus.hasActiveVideo,
      interactiveSourceKind: interactivePreviewSource.kind,
      smartLookDerived:
        interactivePreviewSource.kind === "file"
          ? interactivePreviewSource.smartLookDerived
          : false,
      absolutePath:
        interactivePreviewSource.kind === "file"
          ? interactivePreviewSource.absolutePath
          : null,
      sourcePath: resolvedSourcePath,
      currentSrc,
      activeSourcePath: progressiveLoad.activeSourcePath,
      durationSec,
      progressiveStage: progressiveLoad.stage,
      qualityLabel: progressiveLoad.qualityLabel,
      analyzerVersion: service?.analyzerVersion ?? "scene-aware-v1",
      updatedAtIso: new Date().toISOString(),
      ...patch,
    });

    if (AI_SCENE_PICK_DEV_ENABLED) {
      setAiScenePickPanel({ status: "idle" });
    }

    if (!service) {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("scene analysis service unavailable");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "error",
          reason: "service-unavailable",
          activity: "scene analysis service unavailable",
          lastError: "Scene analysis service is unavailable.",
        }),
      );
      return;
    }
    if (previewStatus.state !== "ready") {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("skipped: preview not ready");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "skipped",
          reason: "preview-not-ready",
          activity: "waiting for preview to become ready",
        }),
      );
      return;
    }
    if (!previewStatus.hasActiveVideo) {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("skipped: no active video");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "skipped",
          reason: "no-active-video",
          activity: "current preview is not an active video",
        }),
      );
      return;
    }
    if (interactivePreviewSource.kind !== "file") {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("skipped: sample preview");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "skipped",
          reason: "sample-preview",
          activity: "sample preview is excluded from scene analysis",
        }),
      );
      return;
    }
    if (interactivePreviewSource.smartLookDerived) {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("skipped: smart look derived");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "skipped",
          reason: "smart-look-derived",
          activity: "Smart Look derived preview is excluded from scene analysis",
        }),
      );
      return;
    }
    if (!resolvedSourcePath) {
      setOpticalRecommendationPanel({ state: "idle" });
      replaceOpticalAnalysisEventLog("skipped: missing source path");
      setOpticalRecommendationDebugInfo(
        buildDebugInfo({
          effectState: "skipped",
          reason: "missing-source-path",
          activity: "source path could not be resolved",
        }),
      );
      return;
    }

    const safeDurationSec = durationSec ?? 0;
    const cacheKey = createSceneAnalysisCacheKey({
      sourcePath: resolvedSourcePath,
      trimStartSec: 0,
      trimEndSec: safeDurationSec,
      sourceDurationSec: safeDurationSec,
      analyzerVersion: service.analyzerVersion,
    });

    let cancelled = false;
    setOpticalRecommendationPanel({ state: "analyzing" });
    replaceOpticalAnalysisEventLog("analysis requested");
    const storedScenePickFlag =
      typeof window !== "undefined"
        ? window.localStorage?.getItem("filmtone.scenePickDev") ?? "n/a"
        : "n/a";
    appendOpticalAnalysisEvent(
      `ai pick dev: module=${AI_SCENE_PICK_DEV_ENABLED} storage=${storedScenePickFlag}`,
    );
    setOpticalRecommendationDebugInfo(
      buildDebugInfo({
        effectState: "analyzing",
        sourcePath: resolvedSourcePath,
        cacheKey,
        activity: "analysis requested",
      }),
    );

    void service
      .analyze(
        {
          sourcePath: resolvedSourcePath,
          // Always forward currentSrc: when it's a mezzanine `film-lab-video://`
          // URL, the analyzer prefers it over re-deriving a URL from the raw
          // absolute path (which fails for codecs HTMLVideoElement can't decode).
          sourceUrl: currentSrc ?? undefined,
          trimStartSec: 0,
          trimEndSec: safeDurationSec,
          sourceDurationSec: safeDurationSec,
        },
        (progress) => {
          if (cancelled) return;
          appendOpticalAnalysisEvent(progress.message);
          setOpticalRecommendationDebugInfo(
            buildDebugInfo({
              effectState: "analyzing",
              sourcePath: resolvedSourcePath,
              cacheKey: progress.cacheKey,
              sourceUrlKind: progress.sourceUrlKind,
              activity: progress.message,
            }),
          );
        },
        AI_SCENE_PICK_DEV_ENABLED ? { captureFrameJpegs: true } : undefined,
      )
      .then((result) => {
        if (cancelled) return;
        if (
          (result.state === "ready" || result.state === "low-confidence") &&
          result.recommendation
        ) {
          appendOpticalAnalysisEvent(`analysis complete: ${result.state}`);
          setOpticalRecommendationPanel({
            state: result.state,
            recommendation: result.recommendation,
          });
          setOpticalRecommendationDebugInfo(
            buildDebugInfo({
              effectState: result.state,
              sourcePath: resolvedSourcePath,
              cacheKey: result.cacheKey,
              analyzerVersion: result.analyzerVersion,
              sourceUrlKind:
                interactivePreviewSource.absolutePath == null
                  ? "provided-url"
                  : "video-src",
              sampleCount:
                result.descriptor?.sampleCount ??
                result.recommendation.descriptor.sampleCount ??
                null,
              activity: `analysis complete: ${result.state}`,
            }),
          );

          if (
            AI_SCENE_PICK_DEV_ENABLED &&
            result.sampledFrames &&
            result.sampledFrames.length > 0 &&
            aiScenePickProviderRef.current
          ) {
            const frames = result.sampledFrames;
            const provider = aiScenePickProviderRef.current;
            const aiCacheKey = result.cacheKey;
            const cachedAi =
              aiScenePickResultCacheRef.current.get(aiCacheKey);
            if (cachedAi) {
              setAiScenePickPanel({
                status: "ready",
                result: cachedAi,
                frames,
              });
              appendOpticalAnalysisEvent(
                `ai pick: cached (${aiCacheKey.slice(-24)})`,
              );
            } else if (aiScenePickInflightRef.current.has(aiCacheKey)) {
              appendOpticalAnalysisEvent(
                `ai pick: skip in-flight (${aiCacheKey.slice(-24)})`,
              );
            } else {
              aiScenePickInflightRef.current.add(aiCacheKey);
              setAiScenePickPanel({ status: "running" });
              appendOpticalAnalysisEvent(
                `ai pick: running (${frames.length} frames)`,
              );
              void provider
                .pick({
                  sourcePath: resolvedSourcePath,
                  trimStartSec: 0,
                  trimEndSec: safeDurationSec,
                  frames,
                })
                .then((aiResult) => {
                  aiScenePickResultCacheRef.current.set(aiCacheKey, aiResult);
                  if (cancelled) return;
                  setAiScenePickPanel({
                    status: "ready",
                    result: aiResult,
                    frames,
                  });
                  const summary = aiResult.manualFallback
                    ? `fallback (${aiResult.reason || "no-reason"})`
                    : `${aiResult.family ?? "?"}/${aiResult.recipe ?? "clean"} conf=${aiResult.confidence} frame=${aiResult.bestFrameIndex ?? "?"}`;
                  appendOpticalAnalysisEvent(
                    `ai pick: ready ${summary} ${Math.round(aiResult.latencyMs)}ms`,
                  );
                  console.info("[ai-scene-pick] result", aiResult);
                })
                .catch((error) => {
                  if (cancelled) return;
                  const message =
                    error instanceof Error ? error.message : String(error);
                  setAiScenePickPanel({ status: "error", message });
                  appendOpticalAnalysisEvent(`ai pick: error ${message}`);
                })
                .finally(() => {
                  aiScenePickInflightRef.current.delete(aiCacheKey);
                });
            }
          }
          return;
        }
        if (result.state === "error") {
          appendOpticalAnalysisEvent(
            `analysis failed: ${result.errorMessage ?? "unknown error"}`,
          );
          setOpticalRecommendationPanel({
            state: "error",
            message: result.errorMessage,
          });
          setOpticalRecommendationDebugInfo(
            buildDebugInfo({
              effectState: "error",
              reason: "analysis-error",
              sourcePath: resolvedSourcePath,
              cacheKey: result.cacheKey,
              analyzerVersion: result.analyzerVersion,
              sourceUrlKind:
                interactivePreviewSource.absolutePath == null
                  ? "provided-url"
                  : "video-src",
              activity: "analysis failed",
              lastError: result.errorMessage,
            }),
          );
          return;
        }
        appendOpticalAnalysisEvent("analysis returned no result");
        setOpticalRecommendationPanel({ state: "idle" });
        setOpticalRecommendationDebugInfo(
          buildDebugInfo({
            effectState: "skipped",
            reason: "empty-result",
            sourcePath: resolvedSourcePath,
            cacheKey: result.cacheKey,
            analyzerVersion: result.analyzerVersion,
            sourceUrlKind:
              interactivePreviewSource.absolutePath == null
                ? "provided-url"
                : "video-src",
            activity: "analysis returned no result",
          }),
        );
      });

    return () => {
      cancelled = true;
    };
  }, [
    interactivePreviewSource,
    opticalAnalysisRetryNonce,
    appendOpticalAnalysisEvent,
    previewStatus.reason,
    previewStatus.hasActiveVideo,
    previewStatus.state,
    progressiveLoad.activeSourcePath,
    progressiveLoad.qualityLabel,
    progressiveLoad.stage,
    replaceOpticalAnalysisEventLog,
  ]);

  const commitOpticalRecommendationToBatch = useCallback(
    (recommendation: OpticalRecommendationV1, index: number) => {
      const selected =
        index === 0
          ? recommendation.primary
          : recommendation.alternates[index - 1];
      if (!selected) {
        return;
      }

      const patch = buildOpticalParamPatch({
        ...recommendation,
        primary: selected,
      });
      setBatchGrade((current) => ({
        ...current,
        params: {
          ...current.params,
          ...patch,
        },
      }));
      setBatchLookSource("analysisRecommendation");
      setImportedGradeLabel(null);
      setEditToExportSyncedAtMs(null);
      setAppliedOpticalRecommendation({
        family: selected.family,
        profile: selected.profile,
        recipe: selected.recipe,
        analyzerVersion:
          opticalAnalyzerServiceRef.current?.analyzerVersion ?? "scene-aware-v1",
        appliedAtIso: new Date().toISOString(),
      });
      return selected;
    },
    [],
  );

  const syncPreviewToBatch = useCallback(() => {
    if (!viewport) {
      appendLog(tLogs("syncNoViewport"));
      setGradeSyncNotice({
        message: tApp("syncGradeNoViewport"),
        variant: "info",
      });
      return;
    }
    try {
      const raw = viewport.getParams();
      const params = viewportRecordToParams(raw, batchGrade.params.halationHue);
      setBatchGrade({
        params,
        depthTrack: batchGrade.depthTrack,
        lut1Intensity: editLut.lut1?.intensity ?? 1,
        lut1Data: editLut.lut1?.data ?? null,
        lut1Size: editLut.lut1?.size ?? 0,
        lutIntensity: editLut.lut2?.intensity ?? 1,
        lutData: editLut.lut2?.data ?? null,
        lutSize: editLut.lut2?.size ?? 0,
      });
      setBatchLookSource("editSync");
      setBatchLutRefs({
        lut1: createMetadataLutRefFromRuntime(editLut.lut1),
        lut2: createMetadataLutRefFromRuntime(editLut.lut2),
      });
      setImportedGradeLabel(null);
      setBatchPresetChoice(canvasPreset);
      setEditToExportSyncedAtMs(Date.now());
      setSyncedAtNonce(paramsChangeNonce);
      appendLog(tLogs("syncCopied"));
      setGradeSyncNotice({
        message: tApp("syncGradeOk"),
        variant: "success",
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      appendLog(tLogs("syncException", { msg }));
      setGradeSyncNotice({
        message: tApp("syncGradeError", { msg }),
        variant: "error",
      });
    }
  }, [
    viewport,
    batchGrade.depthTrack,
    batchGrade.params.halationHue,
    canvasPreset,
    editLut,
    paramsChangeNonce,
    appendLog,
    tLogs,
    tApp,
  ]);

  const applyBatchPreset = (name: PresetName) => {
    setBatchPresetChoice(name);
    setBatchGrade(batchGradeStateFromPreset(name));
    setBatchLookSource("preset");
    setBatchLutRefs(createEmptyMetadataLutRefs());
    setAppliedOpticalRecommendation(null);
    setImportedGradeLabel(null);
    setEditToExportSyncedAtMs(null);
  };

  const handleControlPanelPresetChange = useCallback((name: PresetName) => {
    setCanvasInitialGradeParams(null);
    setCanvasPreset(name);
  }, []);

  const importGradeJson = async () => {
    const p = await window.filmLabBatch.pickMetadataJson();
    if (!p) return;
    try {
      await restoreImportedMetadataFromPath(p);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("gradeJsonError", { msg }));
    }
  };

  const exportGrade = () => {
    const blob = new Blob(
      [
        exportGradeJsonText(
          batchGrade.params,
          batchGrade.depthTrack?.source ?? null,
        ),
      ],
      {
        type: "application/json",
      },
    );
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "film-lab-grade.json";
    a.click();
    URL.revokeObjectURL(url);
    appendLog(tLogs("gradeJsonDownloaded"));
  };

  const buildMetadataSessionJsonText = useCallback(
    (payload: {
      job: "images" | "video";
      inputDir: string | null;
      videoInputPath: string | null;
      outputDir: string;
      imageFormat: BatchFormat | null;
      outputFilenameSuffix: string | null;
      outputFileName: string | null;
      grade?: BatchGradeState;
      batchPresetChoice?: PresetName;
      lookSource?: MetadataLookSource;
      lutRefs?: MetadataLutRefs;
      opticalRecommendation?: AppliedOpticalRecommendationMetadata | null;
      cameraOptics?: CameraOptics | null;
      sourceVideoMetadata?: SourceVideoMetadata | null;
    }) => {
      const exportedAtIso = new Date().toISOString();
      const cameraOptics =
        payload.cameraOptics ?? (payload.job === "video" ? sourceCameraOptics : null);
      const session = buildFilmtoneExportSession({
        exportedAtIso,
        appVersion,
        job: payload.job,
        inputDir: payload.inputDir,
        videoInputPath: payload.videoInputPath,
        outputDir: payload.outputDir,
        imageFormat: payload.imageFormat,
        outputFilenameSuffix: payload.outputFilenameSuffix,
        outputFileName: payload.outputFileName,
        batchPresetChoice: payload.batchPresetChoice ?? batchPresetChoice,
        lookSource: payload.lookSource ?? batchLookSource,
        gradeParams: (payload.grade ?? batchGrade).params,
        depthTrack: (payload.grade ?? batchGrade).depthTrack,
        lutRefs: payload.lutRefs ?? batchLutRefs,
        opticalRecommendation:
          payload.opticalRecommendation ?? appliedOpticalRecommendation,
        cameraOptics,
        sourceVideoMetadata: payload.sourceVideoMetadata ?? null,
      });
      return {
        exportedAtIso,
        jsonText: exportFilmtoneExportSessionJsonText(session),
      };
    },
    [
      appVersion,
      appliedOpticalRecommendation,
      batchGrade,
      batchLookSource,
      batchLutRefs,
      batchPresetChoice,
      sourceCameraOptics,
    ],
  );

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
        batchPresetChoice?: PresetName;
        lookSource?: MetadataLookSource;
        lutRefs?: MetadataLutRefs;
        opticalRecommendation?: AppliedOpticalRecommendationMetadata | null;
        importedGradePath?: string | null;
      },
    ) => {
      const effectiveInput = pathContext?.inputDir ?? inputDir;
      const effectiveOutput = pathContext?.outputDir ?? outputDir;
      const effectiveGrade = pathContext?.grade ?? batchGrade;
      const effectiveBatchPresetChoice =
        pathContext?.batchPresetChoice ?? batchPresetChoice;
      const effectiveLookSource = pathContext?.lookSource ?? batchLookSource;
      const effectiveLutRefs = pathContext?.lutRefs ?? batchLutRefs;
      const effectiveOpticalRecommendation =
        pathContext?.opticalRecommendation ?? appliedOpticalRecommendation;
      const effectiveImportedGradePath =
        pathContext?.importedGradePath ?? importedGradeLabel;
      if (!effectiveInput || !effectiveOutput) return;

      void window.filmLabBatch.setDesktopPrefs({
        lastInputDir: effectiveInput,
        lastOutputDir: effectiveOutput,
      });

      resetLogText();
      setLastBatchSummary(null);
      setLastFailedPaths([]);

      appendLog(tLogs("inputLabel", { path: effectiveInput }));
      appendLog(tLogs("outputLabel", { path: effectiveOutput }));
      const outputSuffixForPipeline =
        sessionMutable?.outputFilenameSuffix ?? batchOutputSuffix;
      const sanitizedOutputSuffix =
        sanitizeBatchFilenameSuffix(outputSuffixForPipeline);
      switch (effectiveLookSource) {
        case "importedJson":
          appendLog(
            tLogs("gradeImportedLine", {
              path: effectiveImportedGradePath ?? "",
            }),
          );
          break;
        case "editSync":
          appendLog(tLogs("gradeEditSyncLine"));
          break;
        case "analysisRecommendation":
          appendLog(tLogs("gradeRecommendationLine"));
          break;
        default:
          appendLog(
            tLogs("gradePresetLine", {
              preset: effectiveBatchPresetChoice,
            }),
          );
          break;
      }
      appendLog(tLogs("formatLabel", { format }));
      appendLog(
        tLogs("suffixLabel", {
          value: sanitizedOutputSuffix === "" ? tLogs("suffixNone") : sanitizedOutputSuffix,
        }),
      );
      appendLog(tLogs("runCountLabel", { count: imagePaths.length }));

      const photoSidecar = buildMetadataSessionJsonText({
        job: "images",
        inputDir: effectiveInput,
        videoInputPath: null,
        outputDir: effectiveOutput,
        imageFormat: format,
        outputFilenameSuffix: sanitizedOutputSuffix,
        outputFileName: null,
        grade: effectiveGrade,
        batchPresetChoice: effectiveBatchPresetChoice,
        lookSource: effectiveLookSource,
        lutRefs: effectiveLutRefs,
        opticalRecommendation: effectiveOpticalRecommendation,
      });
      const photoSidecarPath = buildPhotoMetadataSidecarPath(
        effectiveOutput,
        photoSidecar.exportedAtIso,
      );
      try {
        await window.filmLabBatch.writeFileUtf8({
          filePath: photoSidecarPath,
          text: photoSidecar.jsonText,
        });
        appendLog(tLogs("metadataJsonSaved", { path: photoSidecarPath }));
      } catch (error) {
        const msg = error instanceof Error ? error.message : String(error);
        appendLog(tLogs("metadataJsonSaveFailed", { msg }));
        return;
      }

      const abortController = new AbortController();
      batchAbortRef.current = abortController;
      activeBatchSessionRef.current = sessionMutable;

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
      appliedOpticalRecommendation,
      batchGrade,
      batchLookSource,
      batchLutRefs,
      batchPresetChoice,
      finalizeSessionAfterRun,
      buildMetadataSessionJsonText,
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
        : exportGradeJsonText(
            batchGrade.params,
            batchGrade.depthTrack?.source ?? null,
          ),
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
    let gradeSnap: Awaited<ReturnType<typeof resolveBatchGradeSnapshot>>;
    try {
      gradeSnap = await resolveBatchGradeSnapshot(s);
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      appendLog(tLogs("sessionRestoreFailed", { msg }));
      gradeSnap = {
        grade: batchGradeStateFromPreset(s.batchPresetChoice),
        batchPresetChoice: s.batchPresetChoice,
        lookSource: "preset",
        lutRefs: createEmptyMetadataLutRefs(),
        syncedAtMs: null,
        importedFilePath: s.importedGradePath,
        appliedOpticalRecommendation: null,
        cameraOptics: null,
      };
    }
    setBatchGrade(gradeSnap.grade);
    setBatchPresetChoice(gradeSnap.batchPresetChoice);
    setBatchLookSource(gradeSnap.lookSource);
    setBatchLutRefs(gradeSnap.lutRefs);
    setAppliedOpticalRecommendation(gradeSnap.appliedOpticalRecommendation);
    setSourceCameraOptics(gradeSnap.cameraOptics);
    setImportedGradeLabel(gradeSnap.importedFilePath);
    setEditToExportSyncedAtMs(gradeSnap.syncedAtMs);
    const todo = pathsNotSucceeded(s);
    if (todo.length === 0) return;
    await runBatchWithPaths(todo, s.format, s, {
      inputDir: s.inputDir,
      outputDir: s.outputDir,
      grade: gradeSnap.grade,
      batchPresetChoice: gradeSnap.batchPresetChoice,
      lookSource: gradeSnap.lookSource,
      lutRefs: gradeSnap.lutRefs,
      opticalRecommendation: gradeSnap.appliedOpticalRecommendation,
      importedGradePath: gradeSnap.importedFilePath,
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

  const purgeProxyCache = useCallback(async () => {
    const api = window.filmLabBatch;
    if (!api?.videoPreviewPurgeProxyCache) {
      return;
    }
    setPurgingProxyCache(true);
    try {
      const result = await api.videoPreviewPurgeProxyCache();
      appendLog(
        tLogs("proxyCachePurged", {
          entries: String(result.removedEntries),
          bytes: String(result.removedBytes),
        }),
      );
      await refreshProxyCacheInfo();
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      appendLog(`Proxy cache purge failed: ${msg}`);
    } finally {
      setPurgingProxyCache(false);
    }
  }, [appendLog, refreshProxyCacheInfo, tLogs]);

  const pickVideoFile = async () => {
    const p = await window.filmLabBatch.pickInputVideoFile();
    if (!p) return;
    await applyPickedVideoPath(p);
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
    let videoCameraOptics: CameraOptics | null = null;
    let videoSourceMetadata: SourceVideoMetadata | null = null;
    try {
      const meta = await window.filmLabBatch.videoExportProbe(videoInputPath);
      videoCameraOptics = sourceCameraOptics ?? meta.cameraOptics;
      videoSourceMetadata = meta.sourceVideoMetadata ?? null;
      setSourceCameraOptics(videoCameraOptics);
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

    const videoSidecar = buildMetadataSessionJsonText({
      job: "video",
      inputDir,
      videoInputPath,
      outputDir: effectiveOutputDir,
      imageFormat: null,
      outputFilenameSuffix: null,
      outputFileName: outName,
      cameraOptics: videoCameraOptics,
      sourceVideoMetadata: videoSourceMetadata,
    });
    const videoSidecarPath = buildVideoMetadataSidecarPath(
      effectiveOutputDir,
      outName,
    );
    try {
      await window.filmLabBatch.writeFileUtf8({
        filePath: videoSidecarPath,
        text: videoSidecar.jsonText,
      });
      appendLog(tLogs("metadataJsonSaved", { path: videoSidecarPath }));
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      appendLog(tLogs("metadataJsonSaveFailed", { msg }));
      return;
    }

    const previewBeforeExport = previewStatusRef.current;
    filmLabCanvasRef.current?.holdPreviewRendering(true);
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
        const reusableMezzanine =
          progressiveLoad.stage === "ready" &&
          progressiveLoad.activeSourcePath === videoInputPath
            ? progressiveLoad.mezzaninePath
            : null;
        const res = await runVideoExportPipeline({
          api: window.filmLabBatch,
          inputVideoPath: videoInputPath,
          outputDir: effectiveOutputDir,
          outputFileName: outName,
          grade: batchGrade,
          cameraOptics: videoCameraOptics,
          signal: abortController.signal,
          onProgress: (pr) => {
            scheduleVideoProgress(pr);
          },
          onLog: appendLog,
          userMessages: videoPipelineUserMessages,
          precomputedMezzaninePath: reusableMezzanine,
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
      await new Promise<void>((resolve) => {
        window.requestAnimationFrame(() => resolve());
      });
      const previewAfterExport = previewStatusRef.current;
      const previewRecoveryAlreadyRunning =
        previewAfterExport.state === "recovering";
      const shouldRecoverPreview =
        interactivePreviewSource.kind === "file" &&
        desktopPreviewShowsUserVideo(interactivePreviewSource) &&
        previewAfterExport.canRecover &&
        previewAfterExport.state === "lost";
      if (previewRecoveryAlreadyRunning) {
        appendLog("[動画] preview 復旧はすでに進行中です");
      } else if (shouldRecoverPreview) {
        appendLog(
          `[動画] export 後に preview runtime loss を検知したため、現在のソースを復旧します (${previewBeforeExport.state} → ${previewAfterExport.state})`,
        );
        const recovered = await filmLabCanvasRef.current?.recoverPreview();
        if (!recovered?.ok) {
          appendLog(
            `[動画] preview 復旧に失敗しました${recovered?.reason ? `: ${recovered.reason}` : ""}`,
          );
          filmLabCanvasRef.current?.holdPreviewRendering(false);
        }
      } else {
        filmLabCanvasRef.current?.holdPreviewRendering(false);
      }
    }
  };

  const batchCanRun = Boolean(inputDir && outputDir) && !running;
  /** @description 動画はソースさえあれば実行可。出力フォルダ未設定時はクリックでダイアログを開く */
  const videoCanExport =
    Boolean(videoInputPath) &&
    !running &&
    (
      progressiveLoad.activeSourcePath == null ||
      progressiveLoad.activeSourcePath !== videoInputPath ||
      progressiveLoad.stage === "ready"
    );
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
    batchCanRun: false,
    batchCanRetryFailed: false,
    batchCanResume: false,
    videoCanExport: false,
    running: false,
  });
  hotkeyUiRef.current = {
    tab,
    batchCanRun,
    batchCanRetryFailed,
    batchCanResume,
    videoCanExport,
    running,
  };

  /**
   * @description デスクトップ専用ショートカット（Web 共有コンポーネントには伝播しないよう window で処理）
   * - Mod+1 / Mod+2 / Mod+3: 編集・写真書き出し・動画書き出し（macOS は ⌘、Windows/Linux は Ctrl）
   * - Mod+Enter: 写真タブでバッチ実行／動画タブで動画書き出し（実行可のとき）
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
        setTab("photoExport");
        return;
      }
      if (mod && e.key === "3") {
        e.preventDefault();
        setTab("videoExport");
        return;
      }

      if (mod && e.key === "Enter") {
        if (e.shiftKey) {
          if (u.tab === "photoExport" && u.batchCanRetryFailed) {
            e.preventDefault();
            void act.retryFailedBatch();
          }
          return;
        }
        if (u.tab === "photoExport" && u.batchCanRun) {
          e.preventDefault();
          void act.runBatch();
          return;
        }
        if (u.tab === "videoExport" && u.videoCanExport) {
          e.preventDefault();
          void act.runVideoExport();
        }
        return;
      }

      if (mod && e.shiftKey && (e.key === "y" || e.key === "Y")) {
        if (u.tab === "photoExport" && u.batchCanResume) {
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
    <div className="film-lab-desktop-root film-lab-desktop-root--edit relative flex min-h-screen flex-col overflow-hidden">
      {/* macOS drag zone — traffic lights sit here */}
      <div className="fl-drag-zone" />

      <GradeSyncToast payload={gradeSyncNotice} />

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
      {/* 幅に関係なく Canvas 全面＋右スライドパネル（縦積みは使わない） */}
      <div className="relative z-10 flex min-h-0 flex-1 flex-col overflow-hidden fl-main fl-main--edge">
          <div className="relative min-h-0 flex-1 overflow-hidden">
            <section className="absolute inset-0 z-0 w-full min-w-0 overflow-hidden rounded-[1rem] bg-[#080808]">
              <FilmLabCanvas
                ref={filmLabCanvasRef}
                chromeLayout="stacked"
                stackedToolbarVisible={false}
                preset={canvasPreset}
                depthTrack={batchGrade.depthTrack}
                initialGradeParams={canvasInitialGradeParams}
                className="h-full min-h-0 w-full"
                fullScreen
                pauseVideoPreview={running}
                onViewportReady={setViewport}
                onViewportCapabilitiesChange={setViewportCapabilities}
                onPreviewStatusChange={setPreviewStatus}
                onInteractiveSourceChange={handleInteractiveSourceChange}
                getFileAbsolutePath={resolveCanvasFileAbsolutePath}
                preprocessVideoFile={preprocessVideoFile}
                compareHud={compareUi.compareMode ? { activeSlot: compareUi.activeSlot } : null}
              />
              <div
                className={`pointer-events-none absolute left-4 z-[24] ${canvasHasUserVideo ? "bottom-52" : "bottom-4"}`}
              >
                <Histogram
                  viewport={viewport}
                  visible={histogramVisible && previewSupportsHistogram}
                  variant="inline"
                />
              </div>
              <QualityBadge qualityLabel={progressiveLoad.qualityLabel} />
              <VideoTransportControls
                filmLabCanvasRef={filmLabCanvasRef}
                className={editTransportClassName}
              />
            </section>

            {!editRightPaneExpanded ? (
              <button
                type="button"
                className="fl-edit-pane-toggle-chip"
                aria-label={tApp("openParamsPanelAria")}
                aria-expanded={false}
                aria-controls="film-lab-edit-controls-pane"
                title={tApp("openParamsPanelAria")}
                onClick={() => setEditRightPaneExpanded(true)}
              >
                <SidebarSimple size={14} weight="regular" mirrored aria-hidden />
              </button>
            ) : null}

            <div
              id="film-lab-edit-controls-pane"
              role="complementary"
              aria-label={tApp("paramsPanelAria")}
              aria-hidden={!editRightPaneExpanded}
              className={`fl-edit-slide-panel-shell absolute inset-y-0 right-0 z-20 flex h-auto max-h-full min-h-0 w-[clamp(320px,42vw,680px)] max-w-[min(680px,calc(100%-1.5rem))] min-w-0 flex-none flex-col py-4 pr-4 transition-transform duration-300 ease-out motion-reduce:transition-none ${
                editRightPaneExpanded
                  ? "translate-x-0"
                  : "pointer-events-none translate-x-full"
              }`}
            >
              <section
                ref={filmLabEditFrostPanelRef}
                className="fl-card fl-card-muted fl-card--frost fl-card--frost-webgl-backdrop fl-edit-controls-pane flex h-full min-h-0 min-w-0 flex-1 flex-col rounded-xl border border-white/[0.08] p-0"
              >
                {/*
                 * 2026-04-18: backdrop を条件付き mount + class 条件付与にしていると、
                 * 開閉の slide animation (transition-transform 300ms) 中で video が
                 * unmount / remount され、一瞬 blur が外れた preview が透けて「前の状態」が
                 * flash する。常時 mount + 常時 class 適用にして、off-screen (translate-x-full)
                 * でも stream と CSS を維持することで visual consistency を担保する。
                 * captureStream は 30fps GPU capture、Apple Silicon では軽微。
                 */}
                <FilmLabWebglPanelBackdrop
                  filmLabCanvasRef={filmLabCanvasRef}
                  panelRef={filmLabEditFrostPanelRef}
                  enabled
                />
                {/*
                 * Web `FilmLabFullPage` と同型: `overflow-hidden` は内側ラッパーへ逃がし、
                 * 外周の frost / WebGL 背景のボケが section 角で切れにくくする。
                 */}
                <div className="relative z-10 flex min-h-0 min-w-0 flex-1 flex-col overflow-hidden rounded-[inherit]">
                {/* ブレークポイントで構成を変えない。狭い幅は横スクロールで収める（life#84） */}
                <div className="fl-edit-pane-toolbar fl-surface-frost flex min-w-0 flex-nowrap items-center overflow-x-auto">
                  {/* 左: パネル操作とメディア読み込み／保存（編集タブ時のみフォルダ・DL） */}
                  <div className="flex min-h-9 min-w-0 shrink-0 items-center gap-0.5">
                    <button
                      type="button"
                      className="fl-edit-pane-toolbar-btn"
                      aria-label={tApp("closeParamsPanelAria")}
                      aria-expanded={editRightPaneExpanded}
                      aria-controls="film-lab-edit-controls-pane"
                      onClick={() => {
                        // All tabs: toggle panel open/close (not navigate back)
                        setEditRightPaneExpanded(false);
                      }}
                    >
                      <CaretRight size={16} weight="bold" aria-hidden />
                    </button>
                    {tab === "edit" ? (
                      <>
                        <button
                          type="button"
                          className="fl-edit-pane-toolbar-btn"
                          aria-label={tFilmLab("toolbar.open")}
                          title={tFilmLab("toolbar.open")}
                          onClick={() => filmLabCanvasRef.current?.openMediaPicker()}
                        >
                          <FolderOpen size={15} weight="regular" aria-hidden />
                        </button>
                        <button
                          type="button"
                          className="fl-edit-pane-toolbar-btn"
                          aria-label={tFilmLab("toolbar.savePng")}
                          title={tFilmLab("toolbar.savePng")}
                          onClick={() => filmLabCanvasRef.current?.saveCurrentPng()}
                        >
                          <DownloadSimple size={15} weight="regular" aria-hidden />
                        </button>
                      </>
                    ) : null}
                  </div>
                  {/* 右: 編集／写真書き出し／動画書き出しのモードタブ（エクスポート面を含む切替はここに寄せる） */}
                  <div
                    className="flex min-h-9 min-w-0 flex-1 items-center justify-end gap-3 pr-1"
                    role="tablist"
                    aria-label={tApp("desktopTabStripAria")}
                  >
                    <button
                      type="button"
                      role="tab"
                      aria-selected={tab === "edit"}
                      aria-controls="film-lab-edit-tabpanel"
                      id="film-lab-tab-edit"
                      aria-label={tApp("tabEdit")}
                      title={tApp("tabEdit")}
                      className={`inline-flex min-h-9 min-w-9 shrink-0 items-center justify-center rounded-md p-1.5 transition-colors ${
                        tab === "edit"
                          ? "bg-[var(--amber-9)] text-[var(--amber-1)]"
                          : "text-[var(--fl-text-tertiary)] hover:text-[var(--fl-text-primary)] hover:bg-[var(--fl-bg-interactive)]"
                      }`}
                      onClick={() => setTab("edit")}
                    >
                      <SlidersHorizontal size={14} weight={tab === "edit" ? "fill" : "regular"} aria-hidden />
                    </button>
                    <button
                      type="button"
                      role="tab"
                      aria-selected={tab === "photoExport"}
                      aria-controls="film-lab-export-tabpanel"
                      id="film-lab-tab-photo"
                      aria-label={tApp("tabPhotoExportAria")}
                      title={tApp("tabPhotoExport")}
                      className={`inline-flex min-h-9 min-w-9 shrink-0 items-center justify-center rounded-md p-1.5 transition-colors ${
                        tab === "photoExport"
                          ? "bg-[var(--amber-9)] text-[var(--amber-1)]"
                          : "text-[var(--fl-text-tertiary)] hover:text-[var(--fl-text-primary)] hover:bg-[var(--fl-bg-interactive)]"
                      }`}
                      onClick={() => setTab("photoExport")}
                    >
                      <Images size={14} weight={tab === "photoExport" ? "fill" : "regular"} aria-hidden />
                    </button>
                    <button
                      type="button"
                      role="tab"
                      aria-selected={tab === "videoExport"}
                      aria-controls="film-lab-export-tabpanel"
                      id="film-lab-tab-video"
                      aria-label={tApp("tabVideoExportAria")}
                      title={tApp("tabVideoExport")}
                      className={`inline-flex min-h-9 min-w-9 shrink-0 items-center justify-center rounded-md p-1.5 transition-colors ${
                        tab === "videoExport"
                          ? "bg-[var(--amber-9)] text-[var(--amber-1)]"
                          : "text-[var(--fl-text-tertiary)] hover:text-[var(--fl-text-primary)] hover:bg-[var(--fl-bg-interactive)]"
                      }`}
                      onClick={() => setTab("videoExport")}
                    >
                      <FilmStrip size={14} weight={tab === "videoExport" ? "fill" : "regular"} aria-hidden />
                    </button>
                  </div>
                </div>
                {/*
                 * Edit タブと Export タブの **中身を常にマウント**し、表示だけ `hidden` で切り替える。
                 * 以前は `tab === "edit"` のときだけ FilmLabControlPanelCore を描画していたため、
                 * 写真／動画書き出しタブへ切り替えるたびにパネルがアンマウント→reducer が cinematic に初期化され、
                 * viewport.setParams が Process などをデフォルトへ戻していた（life#92 写真ギャップの主因候補）。
                 */}
                <div
                  className={`flex min-h-0 min-w-0 flex-1 flex-col ${tab === "edit" ? "" : "hidden"}`}
                  role="tabpanel"
                  id="film-lab-edit-tabpanel"
                  aria-labelledby="film-lab-tab-edit"
                  hidden={tab !== "edit"}
                >
                  <div className="fl-scroll-surface fl-right-panel-scroll min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3 pr-5 lg:pr-8">
                    <FilmLabControlPanelCore
                      key={importedPreviewPanelNonce}
                      viewport={viewport}
                      histogramVisible={histogramVisible && previewSupportsHistogram}
                      supportsHistogram={previewSupportsHistogram}
                      supportsBeforeAfter={previewSupportsBeforeAfter}
                      supportsABCompare={previewSupportsABCompare}
                      surface="bare"
                      initialSharedParams={importedPreviewParams}
                      onHistogramToggle={
                        previewSupportsHistogram ? handleHistogramToggle : undefined
                      }
                      onPresetChange={handleControlPanelPresetChange}
                      onLutChange={handleEditLutChange}
                      onParamsChange={handleEditParamsChange}
                      onCompareUiChange={setCompareUi}
                      deferSpaceKeyToVideoTransportWhenNoCompare={canvasHasUserVideo}
                      slots={{
                        renderBeforeFinishTools: (coreRenderContext) => (
                          <OpticalFinishRecommendationPanel
                            analysis={opticalRecommendationPanel}
                            appliedSelection={
                              appliedOpticalRecommendation
                                ? {
                                    family: appliedOpticalRecommendation.family,
                                    recipe: appliedOpticalRecommendation.recipe,
                                  }
                                : null
                            }
                            debugInfo={opticalRecommendationDebugInfo}
                            debugLog={opticalRecommendationEventLog}
                            aiDevEnabled={AI_SCENE_PICK_DEV_ENABLED}
                            aiScenePick={aiScenePickPanel}
                            onRetry={() => {
                              setOpticalAnalysisRetryNonce((value) => value + 1);
                            }}
                            onApply={(recommendation, index) => {
                              const selected =
                                index === 0
                                  ? recommendation.primary
                                  : recommendation.alternates[index - 1];
                              if (!selected) {
                                return;
                              }
                              const patch = buildOpticalParamPatch({
                                ...recommendation,
                                primary: selected,
                              });
                              coreRenderContext.dispatch({
                                type: "MERGE_PARAMS",
                                patch,
                              });
                              coreRenderContext.dispatch({ type: "COMMIT" });
                              const appliedSelection =
                                commitOpticalRecommendationToBatch(
                                recommendation,
                                index,
                              );
                              const appliedRecipe =
                                selected.recipe ?? selected.profile;
                              appendOpticalAnalysisEvent(
                                `apply clicked: ${selected.family}/${appliedRecipe}`,
                              );
                              setOpticalRecommendationDebugInfo((current) =>
                                current
                                  ? {
                                      ...current,
                                      activity: `applied ${selected.family}/${appliedRecipe}`,
                                      updatedAtIso: new Date().toISOString(),
                                    }
                                  : current,
                              );
                              console.info("[optical-analysis] apply clicked", {
                                family: selected.family,
                                recipe: selected.recipe,
                                index,
                                appliedSelection,
                              });
                            }}
                            onApplyAi={() => {
                              appendOpticalAnalysisEvent("ai apply: clicked");
                              try {
                                if (aiScenePickPanel.status !== "ready") {
                                  appendOpticalAnalysisEvent(
                                    `ai apply: skip status=${aiScenePickPanel.status}`,
                                  );
                                  return;
                                }
                                const descriptor =
                                  opticalRecommendationPanel.state === "ready" ||
                                  opticalRecommendationPanel.state === "low-confidence"
                                    ? opticalRecommendationPanel.recommendation
                                        .descriptor
                                    : null;
                                const aiRecommendation = buildAiRecommendation(
                                  aiScenePickPanel.result,
                                  descriptor,
                                );
                                if (!aiRecommendation) {
                                  appendOpticalAnalysisEvent(
                                    "ai apply: skip builder-null (fallback or missing family)",
                                  );
                                  return;
                                }
                                const patch = buildOpticalParamPatch(
                                  aiRecommendation,
                                );
                                const patchKeys = Object.keys(patch);
                                appendOpticalAnalysisEvent(
                                  `ai apply: patch keys=${patchKeys.length}`,
                                );
                                coreRenderContext.dispatch({
                                  type: "MERGE_PARAMS",
                                  patch,
                                });
                                coreRenderContext.dispatch({ type: "COMMIT" });
                                appendOpticalAnalysisEvent(
                                  "ai apply: core dispatched",
                                );
                                commitOpticalRecommendationToBatch(
                                  aiRecommendation,
                                  0,
                                );
                                const viewportInstance = viewport;
                                if (viewportInstance) {
                                  try {
                                    const current =
                                      viewportInstance.getParams();
                                    viewportInstance.setParams({
                                      ...current,
                                      ...patch,
                                    });
                                    appendOpticalAnalysisEvent(
                                      "ai apply: viewport.setParams ok",
                                    );
                                  } catch (vpErr) {
                                    appendOpticalAnalysisEvent(
                                      `ai apply: viewport.setParams error ${
                                        vpErr instanceof Error
                                          ? vpErr.message
                                          : String(vpErr)
                                      }`,
                                    );
                                  }
                                } else {
                                  appendOpticalAnalysisEvent(
                                    "ai apply: no viewport instance",
                                  );
                                }
                                const { family, recipe } =
                                  aiRecommendation.primary;
                                appendOpticalAnalysisEvent(
                                  `ai apply: done ${family}/${recipe ?? "clean"}`,
                                );
                                console.info("[ai-scene-pick] apply clicked", {
                                  family,
                                  recipe,
                                  bestFrameIndex:
                                    aiScenePickPanel.result.bestFrameIndex,
                                  confidence:
                                    aiScenePickPanel.result.confidence,
                                  patchKeys,
                                });
                              } catch (err) {
                                appendOpticalAnalysisEvent(
                                  `ai apply: error ${
                                    err instanceof Error
                                      ? err.message
                                      : String(err)
                                  }`,
                                );
                                throw err;
                              }
                            }}
                          />
                        ),
                      }}
                    />
                  </div>
                  <div className="fl-sticky-footer fl-surface-frost rounded-b-xl">
                    {(() => {
                      const syncState = editToExportSyncedAtMs === null
                        ? "unsynced"
                        : paramsChangeNonce !== syncedAtNonce
                          ? "stale"
                          : "synced";
                      return (
                        <button
                          type="button"
                          className={[
                            "inline-flex items-center justify-center min-h-[40px] w-full sm:w-auto sm:min-w-[220px]",
                            syncState === "synced"
                              ? "rounded-lg bg-[var(--slate-4)] px-4 py-2 text-sm font-medium text-[var(--slate-11)] transition-colors hover:bg-[var(--slate-5)]"
                              : "fl-btn-primary",
                            syncState === "stale"
                              ? "animate-[fl-pulse-soft_2s_ease-in-out_infinite]"
                              : "",
                          ].join(" ")}
                          onClick={syncPreviewToBatch}
                        >
                          <span className="inline-flex items-center gap-1.5">
                            {syncState === "synced" ? (
                              <><CheckCircle size={16} weight="fill" aria-hidden />{tApp("sendGradeToExportSynced", {
                                time: new Date(editToExportSyncedAtMs!).toLocaleTimeString(
                                  locale === "ja" ? "ja-JP" : "en-US",
                                  { hour: "2-digit", minute: "2-digit" },
                                ),
                              })}</>
                            ) : syncState === "stale" ? (
                              <><ArrowClockwise size={16} weight="bold" aria-hidden />{tApp("sendGradeToExportStale")}</>
                            ) : (
                              <><Export size={14} weight="bold" aria-hidden />{tApp("sendGradeToExport")}</>
                            )}
                          </span>
                        </button>
                      );
                    })()}
                    <div className="mt-2 flex flex-wrap items-center gap-1.5">
                      <p className="fl-caption">{tApp("sendGradeCaption")}</p>
                      <HelpHint
                        tip={tApp("sendGradeTip")}
                        assistiveLabel={tApp("sendGradeTipAria")}
                      />
                    </div>
                  </div>
                </div>
                <div
                  className={`flex min-h-0 min-w-0 flex-1 flex-col ${tab !== "edit" ? "" : "hidden"}`}
                  role="tabpanel"
                  id="film-lab-export-tabpanel"
                  aria-labelledby={
                    tab === "photoExport"
                      ? "film-lab-tab-photo"
                      : "film-lab-tab-video"
                  }
                  aria-label={
                    tab === "photoExport"
                      ? tApp("tabPhotoExportAria")
                      : tApp("tabVideoExportAria")
                  }
                  hidden={tab === "edit"}
                >
                  <div className="fl-scroll-surface fl-right-panel-scroll min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-3 pr-5 lg:pr-8">
                      {tab === "photoExport" ? (
                        <PhotoExportPanel
                          compact
                          batchJobMode={batchJobMode}
                          persistedSession={persistedSession}
                          batchCanResume={batchCanResume}
                          running={running}
                          onResumeBatch={resumeBatch}
                          onDiscardPersistedSession={discardPersistedSession}
                          proxyCacheInfo={proxyCacheInfo}
                          isPurgingProxyCache={purgingProxyCache}
                          onPurgeProxyCache={purgeProxyCache}
                          batchPresetChoice={batchPresetChoice}
                          batchLookSource={batchLookSource}
                          appliedOpticalRecommendation={appliedOpticalRecommendation}
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
                            batchAbortRef.current?.abort();
                          }}
                          batchProgress={batchProgress}
                          lastBatchSummary={lastBatchSummary}
                          videoInputPath={videoInputPath}
                          videoProbeLabel={videoProbeLabel}
                          videoHdrPolicy={videoHdrPolicy}
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
                          desktopInteractivePreview={interactivePreviewSource}
                        />
                      ) : (
                        <VideoExportPanel
                          compact
                          batchJobMode={batchJobMode}
                          persistedSession={persistedSession}
                          batchCanResume={batchCanResume}
                          running={running}
                          onResumeBatch={resumeBatch}
                          onDiscardPersistedSession={discardPersistedSession}
                          proxyCacheInfo={proxyCacheInfo}
                          isPurgingProxyCache={purgingProxyCache}
                          onPurgeProxyCache={purgeProxyCache}
                          batchPresetChoice={batchPresetChoice}
                          batchLookSource={batchLookSource}
                          appliedOpticalRecommendation={appliedOpticalRecommendation}
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
                            batchAbortRef.current?.abort();
                          }}
                          batchProgress={batchProgress}
                          lastBatchSummary={lastBatchSummary}
                          videoInputPath={videoInputPath}
                          videoProbeLabel={videoProbeLabel}
                          videoHdrPolicy={videoHdrPolicy}
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
                          desktopInteractivePreview={interactivePreviewSource}
                        />
                      )}
                      <details className="mt-2">
                        <summary className="fl-caption cursor-pointer text-[var(--fl-text-tertiary)] hover:text-[var(--fl-text-secondary)]">
                          {tApp("logToggle")}
                        </summary>
                        <pre className="fl-log mt-1 max-h-[120px]">{logText || tApp("logPlaceholder")}</pre>
                      </details>
                    </div>
                    <div className="fl-sticky-footer fl-surface-frost rounded-b-xl">
                      <BatchTabCompactRunFooter
                        batchJobMode={batchJobMode}
                        inputDir={inputDir}
                        outputDir={outputDir}
                        videoInputPath={videoInputPath}
                        running={running}
                        batchCanRun={batchCanRun}
                        batchCanRetryFailed={batchCanRetryFailed}
                        onRunBatch={runBatch}
                        onRetryFailedBatch={retryFailedBatch}
                        onAbortBatch={() => {
                          batchAbortRef.current?.abort();
                        }}
                        batchProgress={batchProgress}
                        lastBatchSummary={lastBatchSummary}
                        videoCanExport={videoCanExport}
                        onRunVideoExport={runVideoExport}
                      />
                    </div>
                </div>
                </div>
              </section>
            </div>
          </div>
      </div>

      </div>
    </div>
  );
}
