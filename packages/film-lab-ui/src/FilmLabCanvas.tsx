"use client";

import {
  useRef,
  useEffect,
  useCallback,
  useState,
  forwardRef,
  useImperativeHandle,
} from "react";
import { useTranslations } from "next-intl";
import * as THREE from "three";
import { parseCube, PRESETS, halationHueToHex, type PresetName } from "film-lab-core";
import {
  isWebGL2Supported,
  isWebGPUSupported,
  getOptimalPixelRatio,
  Viewport,
  MediaLoader,
  MediaLoadError,
  LIKELY_VIDEO_EXTENSION,
  type LoadResult,
  type ViewportCapabilities,
  type ViewportBackendPreference,
  type ViewportContextLossInfo,
  type ViewportContextLossReason,
} from "film-lab-renderer";
import type { Params } from "film-lab-core";
import { FILM_LAB_NEXT_INTL_NAMESPACE } from "./filmLabUiContract";
import type { VideoPlaybackRate, VideoPlaybackState } from "./videoPlaybackContract";

/**
 * @description プレビューに載っているメディアの種類を親へ伝えるための最小ペイロード。
 * デスクトップでは親の `getFileAbsolutePath`（例: Electron `webUtils.getPathForFile`）か `File.path` で `absolutePath` を渡します。
 * スマートルック差し替えの合成 PNG は `sourceRole: "smartLookDerived"` とし、書き出しの正本にしないでください。
 */
export type FilmLabInteractiveSourceInfo =
  | { kind: "sample" }
  | {
      kind: "file";
      fileName: string;
      /** Electron などで `File` に絶対パスが付いているときだけ。Web の通常のファイル入力では多くの場合 undefined */
      absolutePath?: string | null;
      /** 省略時はユーザーが選んだ／ドロップしたメディアとみなす */
      sourceRole?: "userMedia" | "smartLookDerived";
    };

/**
 * @description Progressive loading で返す前処理結果です。
 * 初回は JPEG サムネイル、失敗時は proxy / mezzanine がそのまま返ることがあります。
 */
export type FilmLabCanvasPreprocessResult = {
  /** @description 読み込む URL */
  url: string;
  /** @description 画像か動画か。MediaLoader の呼び分けに使います */
  mediaKind: "image" | "video";
  /** @description 初回に返った品質ステージ */
  stage: "thumbnail" | "proxy" | "mezzanine";
};

type ReloadablePreviewSource =
  | { kind: "sample" }
  | { kind: "userMedia"; file: File }
  | { kind: "smartLookDerived"; pngBase64Body: string };

export type FilmLabCanvasPreviewHealth = {
  hasRenderer: boolean;
  contextLost: boolean;
  activeSourceKind: ReloadablePreviewSource["kind"];
  hasActiveVideo: boolean;
  mediaOverlayKind: "idle" | "loading" | "error";
};

export type FilmLabCanvasPreviewStatusReason =
  | "webgl2-missing"
  | "webgpu-missing"
  | "init-failed"
  | ViewportContextLossReason;

export type FilmLabCanvasPreviewStatus = {
  state: "starting" | "ready" | "unsupported" | "lost" | "recovering" | "error";
  reason?: FilmLabCanvasPreviewStatusReason;
  hasActiveVideo: boolean;
  canRecover: boolean;
};

/**
 * @description 背景で swap する対象ステージです。
 */
export type ProgressiveTextureStage = "proxy" | "mezzanine";

export interface FilmLabCanvasProps {
  preset: PresetName;
  className?: string;
  fullScreen?: boolean;
  onViewportReady?: (viewport: Viewport | null) => void;
  onViewportCapabilitiesChange?: (capabilities: ViewportCapabilities | null) => void;
  onPreviewStatusChange?: (status: FilmLabCanvasPreviewStatus) => void;
  /**
   * @description 最初に出す sample asset を親が明示したいときの URL です。
   * Web の `/film-lab` では canonical sample asset を直接渡し、Desktop では共有の既定解決に戻せます。
   */
  defaultSampleAssetUrl?: string;
  /**
   * @description true の間は、プレビューに読み込んだ動画の再生を止め、**WebGL の毎フレーム描画も止めます**。
   * 共有 `VideoTexture` へのシークが別処理（Web 動画書き出し等）と走ると画面が追従するため、
   * RAF 内で `render` / `setTime` をスキップして最後に出したフレームで固定します。
   * 静止画では主にフィルム粒など時間系だけ止まります。
   */
  pauseVideoPreview?: boolean;
  stackedToolbarVisible?: boolean;
  /**
   * @description デスクトップ等でツールバーを画像の上に重ねないときに `stacked`。
   * `overlay`（既定）は Web 本番どおり左上オーバーレイ。
   */
  chromeLayout?: "overlay" | "stacked";
  /**
   * URL 共有で復元した grade。指定時はプリセット prop による上書きを止め、
   * デフォルト画像読み込み後の setParams もこの値に合わせる（ControlPanel と競合しないようにする）。
   */
  initialGradeParams?: Params | null;
  /**
   * 比較モード中のみ渡す。プレビュー上に「左/右」ラベル・編集中チップ・境界ドラッグのヒントを重ねる。
   * pointer-events-none でスプリット操作と干渉しない（解除ボタンのみ pointer-events-auto）。
   */
  compareHud?: { activeSlot: "A" | "B"; onDismiss?: () => void } | null;
  /** ドロップ／ファイル選択で .cube が適用できたとき（寄付ナッジ用） */
  onCubeLutLoaded?: () => void;
  /**
   * Web LP など親が「いまキャンバスに載っている元画像」を表示したいときの任意通知。
   * `.cube` のみ読んだ場合は画像ソースが変わらないため呼ばない。
   */
  onInteractiveSourceChange?: (info: FilmLabInteractiveSourceInfo) => void;
  /**
   * @description デスクトップ（Electron `webUtils.getPathForFile` 等）で `File` から絶対パスを取る。未指定時はレガシーの `File.path` のみ試す。
   */
  getFileAbsolutePath?: (file: File) => string | null;
  /**
   * @description Desktop でドロップされた動画が Chromium 非対応コーデック（ProRes 等）の場合、
   * Progressive loading の最初の見せ方を返します。null を返した場合はそのまま MediaLoader に渡します。
   */
  preprocessVideoFile?: (file: File) => Promise<FilmLabCanvasPreprocessResult | null>;
}

/**
 * @description 親の解決関数、または `File.path`（古い Electron）でローカル絶対パスを得る。
 */
function resolveLocalFileAbsolutePath(
  file: File,
  getPath?: (f: File) => string | null,
): string | null {
  try {
    const fromHook = getPath?.(file);
    if (typeof fromHook === "string" && fromHook.trim().length > 0) {
      return fromHook.trim();
    }
  } catch {
    // getPathForFile 等は不正な File で例外になりうる
  }
  const raw = (file as File & { path?: string }).path;
  return typeof raw === "string" && raw.trim().length > 0 ? raw.trim() : null;
}

/**
 * @description 親からキャプチャ用に呼び出す ref。スマートルック API 用に縮小 JPEG を base64 で返す。
 */
export type FilmLabCanvasRef = {
  getJpegBase64ForAi: (maxSide: number) => string | null;
  replaceSourceFromPngBase64Body: (pngBase64Body: string) => Promise<boolean>;
  /**
   * @description Progressive loading の背景ステージ完了後に、今のテクスチャをシームレスに差し替えます。
   * proxy → mezzanine のときは再生位置もそろえます。
   */
  swapProgressiveTexture: (
    url: string,
    fileName: string,
    stage: ProgressiveTextureStage,
  ) => Promise<boolean>;
  openMediaPicker: () => void;
  saveCurrentPng: () => void;
  /**
   * @description Web 動画書き出し用。ユーザー動画を Texture に載せているときだけその `<video>` を返す。
   * 静止画・sample のときは null。
   */
  getActiveVideoElement: () => HTMLVideoElement | null;
  /**
   * @description 動画トランスポート UI 用。`HTMLVideoElement` から読み取れる範囲のスナップショット。
   */
  getVideoPlaybackState: () => VideoPlaybackState;
  /**
   * @description 書き出し中や `holdPreviewRendering` 中は再生操作を無効にするためのフラグ。
   */
  isVideoPlaybackSuppressed: () => boolean;
  /**
   * @description ユーザーの再生意図。ビジー明けの自動再開は「ユーザーが明示停止していない」ときだけ行います。
   */
  videoPlaybackPlay: () => void;
  videoPlaybackPause: () => void;
  videoPlaybackTogglePlayPause: () => void;
  /**
   * @param time シーク先の秒。`duration` が分かっているときは 0〜duration に丸めます。
   */
  videoPlaybackSeek: (time: number) => void;
  /**
   * @description 再生速度を 1x / 2x / 3x で切り替えます。停止中・再生中・シーク後いずれも保持されます。
   */
  videoPlaybackSetRate: (rate: VideoPlaybackRate) => void;
  /**
   * @description `pauseVideoPreview` と独立に、**親が同期で**プレビュー RAF（`viewport.render`）を止める。
   * Next.js `dynamic()` や effect 順序で props が遅れるときでも、エンコード開始の同一コールスタックで効かせる。
   * @param held true で描画ループをスキップし、false で解除。
   */
  holdPreviewRendering: (held: boolean) => void;
  /**
   * @description Web デモのパネル背後ぼかし PoC 用。Three.js の描画先（`preserveDrawingBuffer: true`）。
   */
  getWebGlCanvas: () => HTMLCanvasElement | null;
  /**
   * @description Export 前後の診断用。renderer の context 状態と現在 source の大分類だけを返します。
   */
  getPreviewHealth: () => FilmLabCanvasPreviewHealth;
  getPreviewStatus: () => FilmLabCanvasPreviewStatus;
  /**
   * @description 現在の sample / user media / smart-look source を新しい renderer へ読み直します。
   * context loss 後の黒画面から復帰させるため、親は必要時だけこれを呼びます。
   */
  reloadCurrentSource: () => Promise<boolean>;
  recoverPreview: () => Promise<{ ok: boolean; reason?: string }>;
};

/** ファイルピッカー用: HEIC を選びにくくしつつ、一般的な形式はそのまま選べる */
const FILM_LAB_FILE_ACCEPT =
  "image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png,.webp,.gif,video/mp4,video/webm,video/quicktime,.mp4,.webm,.mov,.m4v,.cube,application/octet-stream";

const FILM_LAB_DEFAULT_SAMPLE_ASSET_PATH = "images/film-lab/default.jpg";

/**
 * @description `apps/web/public` 直下からの相対パス（先頭スラッシュなし推奨）を、Vite の `base` に合わせた URL にする。
 */
function publicAssetUrlFromWebPublic(pathFromPublicRoot: string): string {
  const rawBase =
    typeof import.meta.env?.BASE_URL === "string"
      ? import.meta.env.BASE_URL
      : "/";
  const base = rawBase.endsWith("/") ? rawBase : `${rawBase}/`;
  const rel = pathFromPublicRoot.replace(/^\//, "");
  return `${base}${rel}`;
}

/**
 * @description 親が canonical sample asset を明示したらそれを優先し、未指定なら共有既定の URL 解決を使います。
 * @param defaultSampleAssetUrl 親が渡す sample asset URL
 * @returns 最初に読む sample asset URL
 */
function resolveDefaultSampleAssetUrl(defaultSampleAssetUrl?: string): string {
  if (
    typeof defaultSampleAssetUrl === "string" &&
    defaultSampleAssetUrl.trim().length > 0
  ) {
    return defaultSampleAssetUrl.trim();
  }

  return publicAssetUrlFromWebPublic(FILM_LAB_DEFAULT_SAMPLE_ASSET_PATH);
}

function isRendererContextLost(
  renderer: THREE.WebGLRenderer | null,
): boolean {
  if (!renderer) {
    return false;
  }
  try {
    return renderer.getContext().isContextLost();
  } catch {
    return false;
  }
}

/**
 * @description Viewport が理解できる shape に grade params をそろえます。
 * `halationHue` は shader 側が直接読まないため、色コードへ変換して渡します。
 * @param source 現在の grade params
 * @returns Viewport 用の params レコード
 */
function buildViewportParams(source: Params): Record<string, number | string> {
  return {
    ...source,
    halationColor: halationHueToHex(source.halationHue),
  };
}

/** キャンバス左上ツールバー: 44px 級タップ／sm でコンパクト／pointer: coarse ではタブレットでも高さ維持 */
const FILM_LAB_TOOLBAR_BUTTON_CLASS =
  "inline-flex min-h-[44px] items-center gap-1.5 rounded-lg border border-white/8 bg-black/30 px-3 py-2 text-xs text-white/72 backdrop-blur-sm transition-colors hover:border-white/12 hover:bg-black/42 hover:text-white sm:min-h-0 sm:px-2.5 sm:py-1.5 sm:text-[11px] [@media(pointer:coarse)]:min-h-[44px] [@media(pointer:coarse)]:py-2";

type MediaOverlayState =
  | { kind: "idle" }
  | { kind: "loading" }
  | { kind: "error"; message: string };

export const FilmLabCanvas = forwardRef<FilmLabCanvasRef | null, FilmLabCanvasProps>(
  function FilmLabCanvas(
    {
      preset,
      className,
      fullScreen,
      onViewportReady,
      onViewportCapabilitiesChange,
      onPreviewStatusChange,
      defaultSampleAssetUrl,
      pauseVideoPreview = false,
      stackedToolbarVisible = true,
      initialGradeParams = null,
      onCubeLutLoaded,
      onInteractiveSourceChange,
      getFileAbsolutePath,
      preprocessVideoFile,
      compareHud = null,
      chromeLayout = "overlay",
    },
    ref,
  ) {
  const tFilmLab = useTranslations(FILM_LAB_NEXT_INTL_NAMESPACE);
  const onInteractiveSourceChangeRef = useRef(onInteractiveSourceChange);
  useEffect(() => {
    onInteractiveSourceChangeRef.current = onInteractiveSourceChange;
  });
  const getFileAbsolutePathRef = useRef(getFileAbsolutePath);
  useEffect(() => {
    getFileAbsolutePathRef.current = getFileAbsolutePath;
  });
  const preprocessVideoFileRef = useRef(preprocessVideoFile);
  useEffect(() => {
    preprocessVideoFileRef.current = preprocessVideoFile;
  });
  const onViewportReadyRef = useRef(onViewportReady);
  useEffect(() => {
    onViewportReadyRef.current = onViewportReady;
  }, [onViewportReady]);
  const onViewportCapabilitiesChangeRef = useRef(onViewportCapabilitiesChange);
  useEffect(() => {
    onViewportCapabilitiesChangeRef.current = onViewportCapabilitiesChange;
  }, [onViewportCapabilitiesChange]);
  const onPreviewStatusChangeRef = useRef(onPreviewStatusChange);
  useEffect(() => {
    onPreviewStatusChangeRef.current = onPreviewStatusChange;
  }, [onPreviewStatusChange]);
  const containerRef = useRef<HTMLDivElement>(null);
  const [viewportCapabilities, setViewportCapabilities] =
    useState<ViewportCapabilities | null>(null);
  const viewportRef = useRef<Viewport | null>(null);
  const mediaLoaderRef = useRef<MediaLoader | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.OrthographicCamera | null>(null);
  /**
   * @description バックエンドに依らず描画の最終出力先となる canvas 要素。
   * WebGL 経路では `THREE.WebGLRenderer` が `canvas:` オプションで掴み、
   * WebGPU 経路では `Viewport.create` 内部で `canvas.getContext('webgpu')` が張る。
   * 共通化することで `handleDownload` / `getJpegBase64ForAi` / `getWebGlCanvas` が
   * backend を気にせずこの 1 本を参照できる。
   */
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  /** @description 現在 viewport に渡している Texture。本体差し替え時の dispose 用です。 */
  const activeTextureRef = useRef<THREE.Texture | null>(null);
  /** @description 現在のプレビュー動画要素。画像のときは null。 */
  const previewVideoElementRef = useRef<HTMLVideoElement | null>(null);
  /** @description busy に入る直前に再生中だった動画だけ、busy 明けで再開します。 */
  const previewVideoShouldResumeRef = useRef(false);
  /** @description 現在の pause が busy 制御由来かどうかを覚えます。 */
  const previewVideoPausedByBusyRef = useRef(false);
  /**
   * @description ユーザーがトランスポートで止めたとき true。ビジー明けの `play()` で上書きされないようにします。
   */
  const previewVideoUserPausedIntentRef = useRef(false);
  const reloadableSourceRef = useRef<ReloadablePreviewSource>({ kind: "sample" });
  const previewContextLostRef = useRef(false);
  const reloadInFlightRef = useRef(false);
  /**
   * @description Three 初期化 effect がdeps [] のため、RAF の `animate` は props を直接読めない。
   * 最新の `pauseVideoPreview` を毎レンダーで渡す。
   */
  const pauseVideoPreviewRef = useRef(pauseVideoPreview);
  pauseVideoPreviewRef.current = pauseVideoPreview;
  /**
   * @description 親（例: Web 書き出し）が ref 経由で同期セット。`dynamic()` 越しでも再レンダーを待たない。
   */
  const previewRenderingHoldRef = useRef(false);
  const previewStatusRef = useRef<FilmLabCanvasPreviewStatus>({
    state: "starting",
    hasActiveVideo: false,
    canRecover: true,
  });
  const pendingRecoveryResolveRef = useRef<((value: { ok: boolean; reason?: string }) => void) | null>(
    null,
  );
  const [isDragging, setIsDragging] = useState(false);
  const [isSplitDragging, setIsSplitDragging] = useState(false);
  /**
   * @description WebGL2 / WebGPU support state. `'ok'` は起動経路が成立している状態。
   * WebGPU 要求ビルドで WebGPU が使えない、あるいは WebGL2 要求ビルドで WebGL2 が使えない、
   * または Viewport 初期化が throw した場合は該当する理由を保持し、起動を中断して explicit
   * error UI を出す(silent fallback は作らない、feedback_no_fallback_bug_hotbed.md)。
   */
  const [supported, setSupported] = useState<
    "ok" | "webgl2-missing" | "webgpu-missing" | "init-failed"
  >("ok");
  const supportedRef = useRef<typeof supported>("ok");
  useEffect(() => {
    supportedRef.current = supported;
  }, [supported]);
  const [mediaOverlay, setMediaOverlay] = useState<MediaOverlayState>({ kind: "idle" });
  const mediaOverlayKindRef = useRef<MediaOverlayState["kind"]>("idle");
  useEffect(() => {
    mediaOverlayKindRef.current = mediaOverlay.kind;
  }, [mediaOverlay]);
  const initialPresetRef = useRef(preset);
  const initialResolvedGradeRef = useRef<Params>(
    initialGradeParams ?? PRESETS[preset],
  );
  const defaultSampleAssetUrlRef = useRef(
    resolveDefaultSampleAssetUrl(defaultSampleAssetUrl),
  );
  const [canvasRuntimeNonce, setCanvasRuntimeNonce] = useState(0);

  const publishPreviewStatus = useCallback((status: FilmLabCanvasPreviewStatus) => {
    previewStatusRef.current = status;
    onPreviewStatusChangeRef.current?.(status);
  }, []);

  const settleRecovery = useCallback((result: { ok: boolean; reason?: string }) => {
    const resolve = pendingRecoveryResolveRef.current;
    pendingRecoveryResolveRef.current = null;
    resolve?.(result);
  }, []);

  const setReadyPreviewStatus = useCallback(
    (videoElement: HTMLVideoElement | null = previewVideoElementRef.current) => {
      publishPreviewStatus({
        state: "ready",
        hasActiveVideo: videoElement != null,
        canRecover: supportedRef.current === "ok",
      });
    },
    [publishPreviewStatus],
  );

  const setErrorPreviewStatus = useCallback(
    (reason?: FilmLabCanvasPreviewStatusReason) => {
      publishPreviewStatus({
        state: "error",
        reason,
        hasActiveVideo: previewVideoElementRef.current != null,
        canRecover: supportedRef.current === "ok",
      });
    },
    [publishPreviewStatus],
  );

  const markPreviewLost = useCallback(
    (reason: ViewportContextLossReason) => {
      previewContextLostRef.current = true;
      previewRenderingHoldRef.current = true;
      publishPreviewStatus({
        state: "lost",
        reason,
        hasActiveVideo: previewVideoElementRef.current != null,
        canRecover: supportedRef.current === "ok",
      });
      setMediaOverlay({ kind: "loading" });
    },
    [publishPreviewStatus],
  );

  useEffect(() => {
    if (supported === "webgl2-missing" || supported === "webgpu-missing") {
      setViewportCapabilities(null);
      publishPreviewStatus({
        state: "unsupported",
        reason: supported,
        hasActiveVideo: false,
        canRecover: false,
      });
      return;
    }
    if (supported === "init-failed") {
      setErrorPreviewStatus("init-failed");
    }
  }, [publishPreviewStatus, setErrorPreviewStatus, supported]);

  /**
   * @description `preset` / 共有 URL 復元のどちらが来ても、現在の Viewport に同じ形で反映します。
   * sample 画像の非同期読み込み完了後に古い preset で上書きしないため、反映ポイントを 1 箇所に寄せます。
   */
  const applyResolvedGradeToViewport = useCallback(() => {
    const viewport = viewportRef.current;
    if (!viewport) {
      return;
    }

    const source = initialGradeParams ?? PRESETS[preset];
    viewport.setParams(buildViewportParams(source));
  }, [initialGradeParams, preset]);

  /**
   * @description export などで busy の間は preview 動画を止め、終わったら必要なときだけ再開します。
   */
  const syncPreviewVideoBusyState = useCallback(
    (videoElement: HTMLVideoElement | null = previewVideoElementRef.current) => {
      if (!videoElement) {
        previewVideoShouldResumeRef.current = false;
        previewVideoPausedByBusyRef.current = false;
        return;
      }

      if (pauseVideoPreview) {
        if (!previewVideoPausedByBusyRef.current) {
          previewVideoShouldResumeRef.current =
            !videoElement.paused && !videoElement.ended;
          previewVideoPausedByBusyRef.current = true;
        }
        if (!videoElement.paused) {
          videoElement.pause();
        }
        return;
      }

      const shouldResume =
        previewVideoPausedByBusyRef.current &&
        previewVideoShouldResumeRef.current;
      previewVideoPausedByBusyRef.current = false;
      previewVideoShouldResumeRef.current = false;
      if (
        shouldResume &&
        videoElement.paused &&
        !previewVideoUserPausedIntentRef.current
      ) {
        videoElement.play().catch((err) => {
          console.warn("FilmLabCanvas.syncPreviewVideoBusyState resume failed", err);
        });
      }
    },
    [pauseVideoPreview],
  );

  useEffect(() => {
    syncPreviewVideoBusyState();
  }, [syncPreviewVideoBusyState]);

  /**
   * @description 使い終わった `<video>` を止めて参照を切ります。
   * macOS / Chromium では `src=""` と `load()` までやるとデコーダ解放が早いです。
   */
  const disposePreviewVideoElement = useCallback((videoElement: HTMLVideoElement | null) => {
    if (!videoElement) {
      return;
    }
    try {
      videoElement.pause();
    } catch {
      /* ignore */
    }
    try {
      videoElement.removeAttribute("src");
      videoElement.load();
    } catch {
      /* ignore */
    }
  }, []);

  /**
   * @description 新しい Texture を viewport へ原子的に差し替え、古い Texture / Video を後片付けします。
   * 動画と静止画の分岐を 1 箇所へ寄せ、通常ロードと progressive swap の両方で再利用します。
   */
  const applyLoadedTextureResult = useCallback(
    (result: LoadResult): void => {
      const viewport = viewportRef.current;
      if (!viewport) {
        return;
      }
      const nextPreviewVideo =
        result.type === "video" &&
        result.texture.image instanceof HTMLVideoElement
          ? result.texture.image
          : null;
      const previousTexture = activeTextureRef.current;
      const previousVideo = previewVideoElementRef.current;
      activeTextureRef.current = result.texture;
      previewVideoElementRef.current = nextPreviewVideo;
      previewVideoShouldResumeRef.current = false;
      previewVideoPausedByBusyRef.current = false;
      previewVideoUserPausedIntentRef.current = false;
      viewport.setTexture(result.texture);
      viewport.setImageResolution(result.width, result.height);
      // Portrait (height > width) → contain with glass bg; landscape/square → cover
      viewport.setFitMode(result.height > result.width ? "contain" : "cover");
      syncPreviewVideoBusyState(nextPreviewVideo);
      window.setTimeout(() => {
        if (previousTexture && previousTexture !== activeTextureRef.current) {
          previousTexture.dispose();
        }
        if (previousVideo && previousVideo !== nextPreviewVideo) {
          disposePreviewVideoElement(previousVideo);
        }
      }, 0);
    },
    [disposePreviewVideoElement, syncPreviewVideoBusyState],
  );

  /**
   * @description すでに読み込み済みの Video 要素を指定秒へシークします。
   * progressive swap で currentTime を合わせるために使います。
   */
  const seekLoadedVideoElement = useCallback(
    async (videoElement: HTMLVideoElement, time: number): Promise<void> => {
      const duration = videoElement.duration;
      const safeTime =
        Number.isFinite(duration) && duration > 0
          ? Math.max(0, Math.min(duration, time))
          : Math.max(0, time);
      if (!Number.isFinite(safeTime)) {
        return;
      }
      if (Math.abs(videoElement.currentTime - safeTime) < 0.033) {
        return;
      }
      await new Promise<void>((resolve, reject) => {
        const cleanup = () => {
          videoElement.removeEventListener("seeked", handleSeeked);
          videoElement.removeEventListener("error", handleError);
        };
        const handleSeeked = () => {
          cleanup();
          resolve();
        };
        const handleError = () => {
          cleanup();
          reject(new Error("FilmLabCanvas.seekLoadedVideoElement: seek error"));
        };
        videoElement.addEventListener("seeked", handleSeeked, { once: true });
        videoElement.addEventListener("error", handleError, { once: true });
        try {
          videoElement.currentTime = safeTime;
        } catch (err) {
          cleanup();
          reject(
            err instanceof Error
              ? err
              : new Error(String(err)),
          );
        }
      });
    },
    [],
  );

  useEffect(() => {
    applyResolvedGradeToViewport();
  }, [applyResolvedGradeToViewport]);

  const getMaxTextureSize = useCallback((): number => {
    return (
      viewportRef.current?.getCapabilities().maxTextureDimension2D ??
      rendererRef.current?.capabilities.maxTextureSize ??
      8192
    );
  }, []);

  const loadDefaultSampleIntoCanvas = useCallback(async (): Promise<boolean> => {
    const mediaLoader = mediaLoaderRef.current;
    if (!mediaLoader) {
      return false;
    }
    const defaultSampleUrl = defaultSampleAssetUrlRef.current;
    try {
      const result = await mediaLoader.loadURL(defaultSampleUrl);
      applyLoadedTextureResult(result);
      reloadableSourceRef.current = { kind: "sample" };
      previewContextLostRef.current = false;
      reloadInFlightRef.current = false;
      previewRenderingHoldRef.current = false;
      onInteractiveSourceChangeRef.current?.({ kind: "sample" });
      setMediaOverlay({ kind: "idle" });
      setReadyPreviewStatus();
      settleRecovery({ ok: true });
      return true;
    } catch (err) {
      const message = `FilmLabCanvas.loadDefaultSample("${defaultSampleUrl}") failed. Open a file manually or verify that the canonical sample asset is reachable.`;
      console.error(message, {
        sampleAssetUrl: defaultSampleUrl,
        preset: initialPresetRef.current,
        initialResolvedGrade: initialResolvedGradeRef.current,
        err,
      });
      reloadInFlightRef.current = false;
      previewRenderingHoldRef.current = false;
      setMediaOverlay({
        kind: "error",
        message,
      });
      setErrorPreviewStatus();
      settleRecovery({ ok: false, reason: "sample-load-failed" });
      return false;
    }
  }, [applyLoadedTextureResult, setErrorPreviewStatus, setReadyPreviewStatus, settleRecovery]);

  const loadUserMediaFile = useCallback(
    async (file: File) => {
      if (!viewportRef.current || !mediaLoaderRef.current) return;

      setMediaOverlay({ kind: "loading" });

      try {
        if (file.name.toLowerCase().endsWith(".cube")) {
          const text = await file.text();
          const lut = parseCube(text);
          viewportRef.current.setLUT(lut.data, lut.size);
          setMediaOverlay({ kind: "idle" });
          onCubeLutLoaded?.();
          return;
        }

        // --- Desktop mezzanine pre-processing for unsupported codecs (ProRes etc.) ---
        const isVideo = file.type.startsWith("video/") || LIKELY_VIDEO_EXTENSION.test(file.name);
        if (isVideo && preprocessVideoFileRef.current) {
          try {
            const preprocessResult = await preprocessVideoFileRef.current(file);
            if (preprocessResult) {
              const result =
                preprocessResult.mediaKind === "image"
                  ? await mediaLoaderRef.current.loadURL(preprocessResult.url)
                  : await mediaLoaderRef.current.loadVideoFromURL(
                      preprocessResult.url,
                      file.name,
                    );
              applyLoadedTextureResult(result);
              reloadableSourceRef.current = { kind: "userMedia", file };
              previewContextLostRef.current = false;
              reloadInFlightRef.current = false;
              previewRenderingHoldRef.current = false;
              onInteractiveSourceChangeRef.current?.({
                kind: "file",
                fileName: file.name,
                absolutePath: resolveLocalFileAbsolutePath(
                  file,
                  getFileAbsolutePathRef.current,
                ),
                sourceRole: "userMedia",
              });
              setMediaOverlay({ kind: "idle" });
              setReadyPreviewStatus(
                result.type === "video" && result.texture.image instanceof HTMLVideoElement
                  ? result.texture.image
                  : null,
              );
              settleRecovery({ ok: true });
              return;
            }
          } catch (preprocessErr) {
            console.warn("FilmLabCanvas: preprocessVideoFile failed, falling through to direct load", preprocessErr);
            // Fall through to normal MediaLoader path
          }
        }

        const maxTex = getMaxTextureSize();
        const result = await mediaLoaderRef.current.loadFile(file, {
          maxTextureSize: maxTex,
        });
        applyLoadedTextureResult(result);
        reloadableSourceRef.current = { kind: "userMedia", file };
        previewContextLostRef.current = false;
        reloadInFlightRef.current = false;
        previewRenderingHoldRef.current = false;
        onInteractiveSourceChangeRef.current?.({
          kind: "file",
          fileName: file.name,
          absolutePath: resolveLocalFileAbsolutePath(
            file,
            getFileAbsolutePathRef.current,
          ),
          sourceRole: "userMedia",
        });
        setMediaOverlay({ kind: "idle" });
        setReadyPreviewStatus(
          result.type === "video" && result.texture.image instanceof HTMLVideoElement
            ? result.texture.image
            : null,
        );
        settleRecovery({ ok: true });
      } catch (err) {
        const message =
          err instanceof MediaLoadError
            ? err.message
            : err instanceof Error
              ? `FilmLabCanvas.loadUserMediaFile("${file.name}", "${file.type || "unknown"}") failed: ${err.message}`
              : `FilmLabCanvas.loadUserMediaFile("${file.name}", "${file.type || "unknown"}") failed: Could not load this file.`;
        reloadInFlightRef.current = false;
        previewRenderingHoldRef.current = false;
        setMediaOverlay({ kind: "error", message });
        setErrorPreviewStatus();
        settleRecovery({ ok: false, reason: "media-load-failed" });
        console.error("FilmLabCanvas.loadUserMediaFile failed", {
          fileName: file.name,
          fileType: file.type,
          err,
        });
      }
    },
    [
      applyLoadedTextureResult,
      getMaxTextureSize,
      onCubeLutLoaded,
      setErrorPreviewStatus,
      setReadyPreviewStatus,
      settleRecovery,
    ],
  );

  const restoreCurrentSource = useCallback(async (): Promise<boolean> => {
    const source = reloadableSourceRef.current;
    if (source.kind === "sample") {
      return loadDefaultSampleIntoCanvas();
    }
    if (source.kind === "smartLookDerived") {
      const mediaLoader = mediaLoaderRef.current;
      if (!mediaLoader || supported !== "ok") {
        reloadInFlightRef.current = false;
        previewRenderingHoldRef.current = false;
        return false;
      }
      try {
        const binary = atob(source.pngBase64Body);
        const len = binary.length;
        const bytes = new Uint8Array(len);
        for (let i = 0; i < len; i++) {
          bytes[i] = binary.charCodeAt(i);
        }
        const blob = new Blob([bytes], { type: "image/png" });
        const file = new File([blob], "smart-look-corrected.png", {
          type: "image/png",
        });
        const maxTex = getMaxTextureSize();
        const result = await mediaLoader.loadFile(file, {
          maxTextureSize: maxTex,
        });
        applyLoadedTextureResult(result);
        previewContextLostRef.current = false;
        reloadInFlightRef.current = false;
        previewRenderingHoldRef.current = false;
        onInteractiveSourceChangeRef.current?.({
          kind: "file",
          fileName: "smart-look-corrected.png",
          absolutePath: null,
          sourceRole: "smartLookDerived",
        });
        setMediaOverlay({ kind: "idle" });
        setReadyPreviewStatus();
        settleRecovery({ ok: true });
        return true;
      } catch (err) {
        console.error("FilmLabCanvas.restoreCurrentSource smart look failed", err);
        reloadInFlightRef.current = false;
        previewRenderingHoldRef.current = false;
        setMediaOverlay({
          kind: "error",
          message: "Could not restore the current preview.",
        });
        setErrorPreviewStatus();
        settleRecovery({ ok: false, reason: "restore-smart-look-failed" });
        return false;
      }
    }
    await loadUserMediaFile(source.file);
    return true;
  }, [
    applyLoadedTextureResult,
    getMaxTextureSize,
    loadDefaultSampleIntoCanvas,
    loadUserMediaFile,
    setErrorPreviewStatus,
    setReadyPreviewStatus,
    settleRecovery,
    supported,
  ]);

  // Renderer setup (WebGL or WebGPU, Phase 3 T3-3)
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;
      publishPreviewStatus({
        state: reloadInFlightRef.current ? "recovering" : "starting",
        hasActiveVideo: previewVideoElementRef.current != null,
        canRecover: supportedRef.current === "ok",
      });

    /**
     * Backend preference: desktop defaults to WebGPU per Vite build flag
     * (`FILMTONE_BACKEND=webgpu`). Web bundles set `webgl` explicitly so the
     * WebGPU chunk is never fetched. Unknown / missing env falls back to
     * WebGL for safety.
     */
    const envRecord = (import.meta.env ?? {}) as unknown as Record<
      string,
      unknown
    >;
    const envBackendRaw = envRecord.FILMTONE_BACKEND;
    const envPref: ViewportBackendPreference =
      envBackendRaw === "webgpu" ? "webgpu" : "webgl";

    // WebGL2 path needs a synchronous gate; the WebGPU gate runs async inside
    // the IIFE below (feature probe + adapter request). Callers commit to the
    // env-selected backend with no silent downgrade — if the requested
    // backend isn't available we surface an explicit error UI.
    if (envPref === "webgl" && !isWebGL2Supported()) {
      setSupported("webgl2-missing");
      return;
    }

    let width = Math.max(1, container.clientWidth);
    let height = Math.max(1, container.clientHeight);

    // Fresh canvas — NOT attached to any rendering context yet. WebGPU
    // requires `canvas.getContext('webgpu')` on a canvas that has never held
    // a WebGL2 context, so we must NOT let THREE.WebGLRenderer create its
    // own canvas first. We decide backend → then either WebGPU attaches
    // (inside Viewport.create) or THREE.WebGLRenderer attaches WebGL2 via
    // the `canvas:` option.
    const canvas = document.createElement("canvas");
    canvas.style.display = "block";
    canvas.style.width = "100%";
    canvas.style.height = "100%";
    container.appendChild(canvas);
    canvasRef.current = canvas;

    const mediaLoader = new MediaLoader();
    mediaLoaderRef.current = mediaLoader;

    let renderer: THREE.WebGLRenderer | null = null;
    let scene: THREE.Scene | null = null;
    let camera: THREE.OrthographicCamera | null = null;
    let viewport: Viewport | null = null;
    let animationId = 0;
    let resizeObserver: ResizeObserver | null = null;
    let resizeRafId = 0;
    let cancelled = false;
      let webglContextLostHandler: ((event: Event) => void) | null = null;
      let detachViewportContextLost: (() => void) | null = null;

    const syncViewportSize = () => {
      if (!viewport) return;
      const nextWidth = Math.max(1, container.clientWidth);
      const nextHeight = Math.max(1, container.clientHeight);
      if (nextWidth === width && nextHeight === height) {
        return;
      }
      width = nextWidth;
      height = nextHeight;
      if (renderer) {
        renderer.setSize(width, height);
      }
      viewport.setResolution(width, height);
    };
    window.addEventListener("resize", syncViewportSize);

    void (async () => {
      // No silent downgrade: commit to the env-selected backend. If WebGPU
      // is requested but the browser lacks support, surface an explicit
      // error instead of falling back. Rationale: a WebGPU-bootstrapped
      // canvas can no longer accept a WebGL2 context, so a silent fallback
      // would require a fresh canvas — multiplying code paths and masking
      // broken premises. See DIRECTION §1 D1 (Pure WebGPU) + life feedback
      // memory feedback_no_fallback_bug_hotbed.md.
      if (envPref === "webgpu") {
        const webgpuOk = await isWebGPUSupported();
        if (!webgpuOk) {
          if (!cancelled) setSupported("webgpu-missing");
          return;
        }
      }

      let vp: Viewport;
      try {
        vp = await Viewport.create(canvas, {
          prefer: envPref,
          width,
          height,
        });
      } catch (err) {
        if (!cancelled) {
          console.error("[FilmLabCanvas] Viewport.create failed", err);
          setSupported("init-failed");
        }
        return;
      }
      if (cancelled) {
        vp.dispose();
        return;
      }
      viewport = vp;
      detachViewportContextLost = vp.onContextLost((info: ViewportContextLossInfo) => {
        markPreviewLost(info.reason);
      });
      const capabilities = vp.getCapabilities();
      setViewportCapabilities(capabilities);
      onViewportCapabilitiesChangeRef.current?.(capabilities);

      if (vp.backendKind === "webgl") {
        // WebGL path: wire THREE.js renderer/scene/camera to the same canvas
        // so consumer hooks (split-compare, download, smart-look capture)
        // keep working exactly as before.
        renderer = new THREE.WebGLRenderer({
          canvas,
          antialias: false,
          alpha: false,
          preserveDrawingBuffer: true,
        });
        renderer.setSize(width, height);
        renderer.setPixelRatio(getOptimalPixelRatio(1.5));
        renderer.outputColorSpace = THREE.SRGBColorSpace;
        rendererRef.current = renderer;

        scene = new THREE.Scene();
        scene.background = new THREE.Color(0x0a0a0a);
        camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
        camera.position.z = 1;
        sceneRef.current = scene;
        cameraRef.current = camera;
        if (vp.mesh) scene.add(vp.mesh);

        webglContextLostHandler = (event: Event) => {
          event.preventDefault();
          markPreviewLost("render-failed");
        };
        canvas.addEventListener(
          "webglcontextlost",
          webglContextLostHandler as EventListener,
          false,
        );
      } else {
        // WebGPU path: no THREE.js renderer, no scene, no camera. The
        // backend drives the swapchain directly via `viewport.render()`.
        rendererRef.current = null;
        sceneRef.current = null;
        cameraRef.current = null;
        // Pre-warm pipeline JIT (DIRECTION §10 Phase 3). Fire-and-forget —
        // Electron bootstrap is < 100 ms in Phase 0 Case A, so the
        // 150 ms-silent UX budget is covered without an explicit overlay.
        try {
          await vp.prewarm();
        } catch (err) {
          if (!cancelled) {
            console.error("[FilmLabCanvas] viewport.prewarm failed", err);
            setErrorPreviewStatus("prewarm-failed");
          }
          return;
        }
      }

      viewportRef.current = viewport;
      onViewportReadyRef.current?.(viewport);
      viewport.setParams(buildViewportParams(initialResolvedGradeRef.current));
      void restoreCurrentSource();

      /**
       * @description `window.resize` だけでは、右ペイン開閉や absolute layout の再計測を取りこぼします。
       * そのため container 自体を観測し、0 サイズから実サイズへ立ち上がった瞬間も拾います。
       */
      syncViewportSize();
      resizeObserver =
        typeof ResizeObserver !== "undefined"
          ? new ResizeObserver(() => {
              syncViewportSize();
            })
          : null;
      resizeObserver?.observe(container);
      resizeRafId = window.requestAnimationFrame(() => {
        syncViewportSize();
      });

      const clock = new THREE.Clock();
      const animate = () => {
        animationId = requestAnimationFrame(animate);
        if (
          !viewport ||
          previewContextLostRef.current ||
          (renderer && isRendererContextLost(renderer)) ||
          pauseVideoPreviewRef.current ||
          previewRenderingHoldRef.current
        ) {
          return;
        }
        viewport.setTime(clock.getElapsedTime());
        try {
          if (renderer && scene && camera) {
            viewport.render(renderer, scene, camera);
          } else {
            viewport.render();
          }
        } catch (err) {
          console.error("[FilmLabCanvas] viewport.render failed", err);
          markPreviewLost("render-failed");
        }
      };
      animate();
    })();

    return () => {
      cancelled = true;
      if (animationId) cancelAnimationFrame(animationId);
      if (resizeRafId) window.cancelAnimationFrame(resizeRafId);
      resizeObserver?.disconnect();
      detachViewportContextLost?.();
      window.removeEventListener("resize", syncViewportSize);
      if (webglContextLostHandler) {
        canvas.removeEventListener(
          "webglcontextlost",
          webglContextLostHandler as EventListener,
          false,
        );
      }
      activeTextureRef.current?.dispose();
      activeTextureRef.current = null;
      disposePreviewVideoElement(previewVideoElementRef.current);
      viewport?.dispose();
      if (renderer) {
        try {
          renderer.forceContextLoss();
        } catch {
          /* ignore */
        }
        renderer.dispose();
      }
      previewVideoElementRef.current = null;
      previewVideoShouldResumeRef.current = false;
      previewVideoPausedByBusyRef.current = false;
      if (container.contains(canvas)) {
        container.removeChild(canvas);
      }
      canvasRef.current = null;
      viewportRef.current = null;
      mediaLoaderRef.current = null;
      rendererRef.current = null;
      sceneRef.current = null;
      cameraRef.current = null;
      setViewportCapabilities(null);
      onViewportCapabilitiesChangeRef.current?.(null);
      onViewportReadyRef.current?.(null);
    };
  }, [
    applyLoadedTextureResult,
    disposePreviewVideoElement,
    markPreviewLost,
    publishPreviewStatus,
    restoreCurrentSource,
    canvasRuntimeNonce,
    setErrorPreviewStatus,
  ]);

  const previewSupportsCompare =
    viewportCapabilities?.supportsBeforeAfter === true &&
    viewportCapabilities?.supportsABCompare === true;

  const handleDrop = useCallback(
    async (e: React.DragEvent) => {
      e.preventDefault();
      setIsDragging(false);
      const file = e.dataTransfer.files[0];
      if (!file) return;
      await loadUserMediaFile(file);
    },
    [loadUserMediaFile],
  );

  const handleDownload = useCallback(() => {
    const viewport = viewportRef.current;
    const canvas = canvasRef.current;
    if (!viewport || !canvas) return;

    const splitBefore = viewport.getSplitPosition();
    viewport.setSplitPosition(-1.0);
    // Backend-agnostic render: WebGL path needs renderer/scene/camera,
    // WebGPU path drives its own swapchain.
    const renderer = rendererRef.current;
    const scene = sceneRef.current;
    const camera = cameraRef.current;
    if (renderer && scene && camera) {
      viewport.render(renderer, scene, camera);
    } else {
      viewport.render();
    }

    const url = canvas.toDataURL("image/png");
    const a = document.createElement("a");
    a.href = url;
    a.download = `film-lab-${Date.now()}.png`;
    a.click();

    viewport.setSplitPosition(splitBefore);
  }, []);

  const handleFileClick = useCallback(() => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = FILM_LAB_FILE_ACCEPT;
    input.onchange = () => {
      const file = input.files?.[0];
      if (!file) return;
      void loadUserMediaFile(file);
    };
    input.click();
  }, [loadUserMediaFile]);

  const handlePointerDown = useCallback((e: React.PointerEvent) => {
    setIsSplitDragging(true);
    (e.currentTarget as HTMLElement).setPointerCapture(e.pointerId);
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    viewportRef.current?.setSplitPosition(Math.max(0, Math.min(1, x)));
  }, []);

  const handlePointerUp = useCallback((e: React.PointerEvent) => {
    setIsSplitDragging(false);
    (e.currentTarget as HTMLElement).releasePointerCapture(e.pointerId);
  }, []);

  const handlePointerMove = useCallback((e: React.PointerEvent) => {
    if (!isSplitDragging) return;
    const rect = (e.currentTarget as HTMLElement).getBoundingClientRect();
    const x = (e.clientX - rect.left) / rect.width;
    viewportRef.current?.setSplitPosition(Math.max(0, Math.min(1, x)));
  }, [isSplitDragging]);

  const handleLostPointerCapture = useCallback(() => {
    setIsSplitDragging(false);
  }, []);

  useImperativeHandle(
    ref,
    () => ({
      getJpegBase64ForAi: (maxSide: number) => {
        const src = canvasRef.current;
        if (!src || supported !== "ok") return null;
        const w = src.width;
        const h = src.height;
        if (w <= 0 || h <= 0) return null;
        const scale = Math.min(1, maxSide / Math.max(w, h));
        const tw = Math.max(1, Math.floor(w * scale));
        const th = Math.max(1, Math.floor(h * scale));
        const oc = document.createElement("canvas");
        oc.width = tw;
        oc.height = th;
        const ctx = oc.getContext("2d");
        if (!ctx) return null;
        ctx.drawImage(src, 0, 0, tw, th);
        try {
          const dataUrl = oc.toDataURL("image/jpeg", 0.82);
          const comma = dataUrl.indexOf(",");
          if (comma < 0) return null;
          return dataUrl.slice(comma + 1);
        } catch {
          return null;
        }
      },
      replaceSourceFromPngBase64Body: async (pngBase64Body: string) => {
        const mediaLoader = mediaLoaderRef.current;
        if (!mediaLoader || supported !== "ok") return false;
        try {
          const binary = atob(pngBase64Body);
          const len = binary.length;
          const bytes = new Uint8Array(len);
          for (let i = 0; i < len; i++) {
            bytes[i] = binary.charCodeAt(i);
          }
          const blob = new Blob([bytes], { type: "image/png" });
          const file = new File([blob], "smart-look-corrected.png", {
            type: "image/png",
          });
          // WebGL: use THREE's maxTextureSize cap. WebGPU: GPUDevice.limits
          // is accessed via the backend when it scales later; use a sensible
          // conservative ceiling here so the loader doesn't reject large files.
          const renderer = rendererRef.current;
          const maxTex = renderer?.capabilities.maxTextureSize ?? 8192;
          const result = await mediaLoader.loadFile(file, {
            maxTextureSize: maxTex,
          });
          applyLoadedTextureResult(result);
          reloadableSourceRef.current = {
            kind: "smartLookDerived",
            pngBase64Body,
          };
          previewContextLostRef.current = false;
          reloadInFlightRef.current = false;
          previewRenderingHoldRef.current = false;
          onInteractiveSourceChangeRef.current?.({
            kind: "file",
            fileName: "smart-look-corrected.png",
            absolutePath: null,
            sourceRole: "smartLookDerived",
          });
          return true;
        } catch (err) {
          console.error("FilmLabCanvas.replaceSourceFromPngBase64Body failed", err);
          return false;
        }
      },
      swapProgressiveTexture: async (
        url: string,
        fileName: string,
        stage: ProgressiveTextureStage,
      ) => {
        const mediaLoader = mediaLoaderRef.current;
        if (!mediaLoader || supported !== "ok") {
          console.warn("[progressive-canvas] swapProgressiveTexture: mediaLoader or supported missing");
          return false;
        }
        try {
          const previousVideo = previewVideoElementRef.current;
          const previousTime =
            previousVideo && Number.isFinite(previousVideo.currentTime)
              ? previousVideo.currentTime
              : 0;
          const wasPlaying =
            previousVideo != null && !previousVideo.paused && !previousVideo.ended;
          const result = await mediaLoader.loadVideoFromURL(url, fileName);
          if (
            stage === "mezzanine" &&
            result.texture.image instanceof HTMLVideoElement
          ) {
            const nextVideo = result.texture.image;
            nextVideo.pause();
            await seekLoadedVideoElement(nextVideo, previousTime);
            applyLoadedTextureResult(result);
            if (wasPlaying && !pauseVideoPreviewRef.current && !previewRenderingHoldRef.current) {
              nextVideo.play().catch((err) => {
                console.warn("FilmLabCanvas.swapProgressiveTexture play failed", {
                  functionName: "swapProgressiveTexture",
                  stage,
                  fileName,
                  err,
                });
              });
            }
            return true;
          }
          applyLoadedTextureResult(result);
          return true;
        } catch (err) {
          console.error("FilmLabCanvas.swapProgressiveTexture failed", {
            functionName: "swapProgressiveTexture",
            url,
            fileName,
            stage,
            err,
          });
          return false;
        }
      },
      openMediaPicker: () => handleFileClick(),
      saveCurrentPng: () => handleDownload(),
      getActiveVideoElement: () => {
        const v = previewVideoElementRef.current;
        return v ?? null;
      },
      getVideoPlaybackState: (): VideoPlaybackState => {
        const v = previewVideoElementRef.current;
        if (!v) {
          return {
            hasVideo: false,
            isPlaying: false,
            currentTime: 0,
            duration: 0,
            playbackRate: 1,
          };
        }
        const dur = v.duration;
        const rawRate = v.playbackRate;
        const playbackRate: VideoPlaybackRate =
          rawRate >= 3 ? 3 : rawRate >= 2 ? 2 : 1;
        return {
          hasVideo: true,
          isPlaying: !v.paused && !v.ended,
          currentTime: v.currentTime,
          duration: Number.isFinite(dur) ? dur : 0,
          playbackRate,
        };
      },
      isVideoPlaybackSuppressed: () =>
        pauseVideoPreviewRef.current || previewRenderingHoldRef.current,
      videoPlaybackPlay: () => {
        if (pauseVideoPreviewRef.current || previewRenderingHoldRef.current) {
          return;
        }
        const v = previewVideoElementRef.current;
        if (!v) {
          return;
        }
        previewVideoUserPausedIntentRef.current = false;
        v.play().catch((err) => {
          console.warn("FilmLabCanvas.videoPlaybackPlay failed", {
            functionName: "videoPlaybackPlay",
            err,
          });
        });
      },
      videoPlaybackPause: () => {
        const v = previewVideoElementRef.current;
        if (!v) {
          return;
        }
        previewVideoUserPausedIntentRef.current = true;
        v.pause();
      },
      videoPlaybackTogglePlayPause: () => {
        if (pauseVideoPreviewRef.current || previewRenderingHoldRef.current) {
          return;
        }
        const v = previewVideoElementRef.current;
        if (!v) {
          return;
        }
        if (v.paused || v.ended) {
          previewVideoUserPausedIntentRef.current = false;
          v.play().catch((err) => {
            console.warn("FilmLabCanvas.videoPlaybackTogglePlayPause play failed", {
              functionName: "videoPlaybackTogglePlayPause",
              err,
            });
          });
        } else {
          previewVideoUserPausedIntentRef.current = true;
          v.pause();
        }
      },
      videoPlaybackSeek: (time: number) => {
        const v = previewVideoElementRef.current;
        if (!v) {
          return;
        }
        const dur = v.duration;
        let clamped = time;
        if (Number.isFinite(dur) && dur > 0) {
          clamped = Math.max(0, Math.min(dur, time));
        } else if (!Number.isFinite(time) || time < 0) {
          clamped = 0;
        }
        try {
          v.currentTime = clamped;
        } catch (err) {
          console.warn("FilmLabCanvas.videoPlaybackSeek failed", {
            functionName: "videoPlaybackSeek",
            requestedTime: time,
            clampedTime: clamped,
            err,
          });
        }
      },
      videoPlaybackSetRate: (rate: VideoPlaybackRate) => {
        const v = previewVideoElementRef.current;
        if (!v) {
          return;
        }
        v.playbackRate = rate;
      },
      holdPreviewRendering: (held: boolean) => {
        previewRenderingHoldRef.current = held;
      },
      getWebGlCanvas: () => canvasRef.current,
      getPreviewHealth: (): FilmLabCanvasPreviewHealth => ({
        hasRenderer:
          viewportRef.current != null &&
          canvasRef.current != null &&
          !previewContextLostRef.current &&
          !(viewportRef.current?.isContextLost() ?? false),
        contextLost:
          previewContextLostRef.current ||
          isRendererContextLost(rendererRef.current) ||
          (viewportRef.current?.isContextLost() ?? false),
        activeSourceKind: reloadableSourceRef.current.kind,
        hasActiveVideo: previewVideoElementRef.current != null,
        mediaOverlayKind: mediaOverlayKindRef.current,
      }),
      getPreviewStatus: () => previewStatusRef.current,
      reloadCurrentSource: async () => {
        const result = await (async () => {
          if (reloadInFlightRef.current) {
            return { ok: false, reason: "already-recovering" };
          }
          reloadInFlightRef.current = true;
          previewContextLostRef.current = false;
          previewRenderingHoldRef.current = true;
          setMediaOverlay({ kind: "loading" });
          publishPreviewStatus({
            state: "recovering",
            hasActiveVideo: previewVideoElementRef.current != null,
            canRecover: supportedRef.current === "ok",
          });
          const recovery = new Promise<{ ok: boolean; reason?: string }>((resolve) => {
            pendingRecoveryResolveRef.current = resolve;
          });
          setCanvasRuntimeNonce((value) => value + 1);
          return recovery;
        })();
        return result.ok;
      },
      recoverPreview: async () => {
        if (reloadInFlightRef.current) {
          return { ok: false, reason: "already-recovering" };
        }
        reloadInFlightRef.current = true;
        previewContextLostRef.current = false;
        previewRenderingHoldRef.current = true;
        setMediaOverlay({ kind: "loading" });
        publishPreviewStatus({
          state: "recovering",
          hasActiveVideo: previewVideoElementRef.current != null,
          canRecover: supportedRef.current === "ok",
        });
        const recovery = new Promise<{ ok: boolean; reason?: string }>((resolve) => {
          pendingRecoveryResolveRef.current = resolve;
        });
        setCanvasRuntimeNonce((value) => value + 1);
        return recovery;
      },
    }),
    [
      applyLoadedTextureResult,
      handleDownload,
      handleFileClick,
      publishPreviewStatus,
      seekLoadedVideoElement,
      supported,
    ],
  );

  if (supported !== "ok") {
    const messageKey =
      supported === "webgl2-missing"
        ? "canvas.webgl2Required"
        : supported === "webgpu-missing"
          ? "canvas.webgpuRequired"
          : "canvas.webgpuInitFailed";
    return (
      <div
        className={`relative flex ${fullScreen ? "h-full" : "aspect-[4/3] sm:aspect-[16/9]"} w-full items-center justify-center rounded-lg bg-[#0a0a0a] ${className ?? ""}`}
        role="alert"
      >
        <span className="max-w-md px-6 text-center text-sm leading-relaxed text-[var(--text-muted)]">
          {tFilmLab(messageKey)}
        </span>
      </div>
    );
  }

  const viewportHostClassName = `relative ${fullScreen ? "h-full min-h-0" : "aspect-[4/3] sm:aspect-[16/9]"} w-full touch-none ${previewSupportsCompare ? "cursor-col-resize" : "cursor-auto"} overflow-hidden rounded-lg bg-[#0a0a0a] ${chromeLayout === "stacked" ? "min-h-[200px] sm:min-h-[240px]" : ""}`;

  const toolbarClassName =
    chromeLayout === "stacked"
      ? "z-10 flex shrink-0 flex-wrap items-center gap-2"
      : "absolute left-3 top-3 z-10 flex gap-1.5";

  const toolbar = (
    <div
      className={toolbarClassName}
      onPointerDown={(e) => e.stopPropagation()}
      onPointerMove={(e) => e.stopPropagation()}
      onPointerUp={(e) => e.stopPropagation()}
      onPointerCancel={(e) => e.stopPropagation()}
    >
      {chromeLayout === "stacked" ? (
        <>
          <button
            type="button"
            data-testid="film-lab-open"
            onClick={handleFileClick}
            className={FILM_LAB_TOOLBAR_BUTTON_CLASS}
          >
            <OpenMediaIcon />
            {tFilmLab("toolbar.open")}
          </button>
          <button
            type="button"
            onClick={handleDownload}
            className={FILM_LAB_TOOLBAR_BUTTON_CLASS}
          >
            <SavePngIcon />
            {tFilmLab("toolbar.savePng")}
          </button>
        </>
      ) : (
        <>
          <button
            type="button"
            data-testid="film-lab-open"
            onClick={handleFileClick}
            className={FILM_LAB_TOOLBAR_BUTTON_CLASS}
          >
            <OpenMediaIcon />
            {tFilmLab("toolbar.open")}
          </button>
          <button
            type="button"
            onClick={handleDownload}
            className={FILM_LAB_TOOLBAR_BUTTON_CLASS}
          >
            <SavePngIcon />
            {tFilmLab("toolbar.savePng")}
          </button>
        </>
      )}
    </div>
  );

  const viewportBody = (
    <>
      {chromeLayout === "overlay" ? toolbar : null}

      {compareHud != null && previewSupportsCompare && (
        <>
          <div className="pointer-events-none absolute left-0 right-0 top-16 z-[6] flex items-center justify-center gap-2 px-3 sm:top-[4.5rem]">
            <span className="rounded-full bg-black/55 px-2.5 py-1 text-[10px] font-medium text-white/80 ring-1 ring-white/15 backdrop-blur-sm">
              {tFilmLab("compare.dragSplitHint")}
            </span>
            {compareHud.onDismiss != null && (
              <button
                type="button"
                className="pointer-events-auto rounded-full bg-white/10 px-2.5 py-1 text-[10px] font-medium text-white/80 ring-1 ring-white/20 backdrop-blur-sm transition-colors hover:bg-white/20 hover:text-white"
                onClick={compareHud.onDismiss}
                aria-label={tFilmLab("compare.dismissButton")}
              >
                {tFilmLab("compare.dismissButton")}
              </button>
            )}
          </div>
          <div className="pointer-events-none absolute bottom-10 left-0 right-0 z-[6] flex justify-center px-3 sm:bottom-11">
            <span className="rounded-full bg-[var(--accent-amber1)]/95 px-3 py-1 text-[10px] font-semibold text-black shadow-lg ring-1 ring-black/20 backdrop-blur-sm">
              {compareHud.activeSlot === "A"
                ? tFilmLab("compare.editingLeftChip")
                : tFilmLab("compare.editingRightChip")}
            </span>
          </div>
          <div
            className="pointer-events-none absolute bottom-2 left-0 right-0 z-[5] flex justify-between gap-2 px-3 sm:bottom-3"
            aria-hidden
          >
            <span
              className={`max-w-[42%] truncate text-[9px] font-medium sm:text-[10px] ${
                compareHud.activeSlot === "A" ? "text-[var(--accent-amber1)]" : "text-white/40"
              }`}
            >
              {tFilmLab("compare.canvasLeft")}
            </span>
            <span
              className={`max-w-[42%] truncate text-right text-[9px] font-medium sm:text-[10px] ${
                compareHud.activeSlot === "B" ? "text-[var(--accent-amber1)]" : "text-white/40"
              }`}
            >
              {tFilmLab("compare.canvasRight")}
            </span>
          </div>
        </>
      )}

      {isDragging && (
        <div className="absolute inset-0 z-10 flex items-center justify-center rounded-lg border-2 border-dashed border-white/30 bg-black/60">
          <span className="text-sm text-white/70">{tFilmLab("canvas.dropHint")}</span>
        </div>
      )}

      {mediaOverlay.kind === "loading" && (
        <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center rounded-lg bg-black/55 backdrop-blur-[2px]">
          <span
            className="rounded-lg bg-black/70 px-4 py-3 text-sm font-medium tracking-[0.01em] text-white/90 shadow-[0_10px_24px_rgba(0,0,0,0.24)]"
            style={{ fontFamily: "var(--font-family-sans)" }}
          >
            {tFilmLab("canvas.loadingMedia")}
          </span>
        </div>
      )}
      {mediaOverlay.kind === "error" && (
        <div
          className="absolute inset-0 z-20 flex items-center justify-center rounded-lg bg-black/70 p-4 backdrop-blur-sm"
          role="alert"
        >
          <div className="max-w-sm rounded-xl border border-white/15 bg-[#141414] p-4 shadow-xl">
            <p className="text-sm leading-relaxed text-white/85">{mediaOverlay.message}</p>
            <button
              type="button"
              onClick={() => setMediaOverlay({ kind: "idle" })}
              className="mt-4 w-full rounded-lg bg-white/10 py-2.5 text-xs font-medium text-white/90 transition-colors hover:bg-white/15"
            >
              {tFilmLab("canvas.dismissError")}
            </button>
          </div>
        </div>
      )}
    </>
  );

  const viewportPointerAndDragProps = previewSupportsCompare
    ? {
        onDragOver: (e: React.DragEvent) => {
          e.preventDefault();
          setIsDragging(true);
        },
        onDragLeave: () => setIsDragging(false),
        onDrop: handleDrop,
        onPointerDown: handlePointerDown,
        onPointerMove: handlePointerMove,
        onPointerUp: handlePointerUp,
        onPointerCancel: handlePointerUp,
        onLostPointerCapture: handleLostPointerCapture,
      }
    : {
        onDragOver: (e: React.DragEvent) => {
          e.preventDefault();
          setIsDragging(true);
        },
        onDragLeave: () => setIsDragging(false),
        onDrop: handleDrop,
      };

  if (chromeLayout === "stacked") {
    return (
      <div className={`flex w-full flex-col gap-2 ${className ?? ""}`}>
        {stackedToolbarVisible ? toolbar : null}
        <div
          ref={containerRef}
          data-testid="film-lab-viewport"
          className={viewportHostClassName}
          {...viewportPointerAndDragProps}
        >
          {viewportBody}
        </div>
      </div>
    );
  }

  return (
    <div
      ref={containerRef}
      data-testid="film-lab-viewport"
      className={`${viewportHostClassName} ${className ?? ""}`}
      {...viewportPointerAndDragProps}
    >
      {viewportBody}
    </div>
  );
});

FilmLabCanvas.displayName = "FilmLabCanvas";

function OpenMediaIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden className="shrink-0 opacity-90">
      <path
        d="M4 7.5A2.5 2.5 0 0 1 6.5 5H10l2 2H17.5A2.5 2.5 0 0 1 20 9.5v7A2.5 2.5 0 0 1 17.5 19h-11A2.5 2.5 0 0 1 4 16.5v-9Z"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinejoin="round"
      />
      <path d="M12 10.25v5.5M9.25 13h5.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}

function SavePngIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" aria-hidden className="shrink-0 opacity-90">
      <path
        d="M6.5 19h11A1.5 1.5 0 0 0 19 17.5v-11A1.5 1.5 0 0 0 17.5 5h-11A1.5 1.5 0 0 0 5 6.5v11A1.5 1.5 0 0 0 6.5 19Z"
        stroke="currentColor"
        strokeWidth="1.7"
      />
      <path
        d="M12 7.25v7M9.25 11.5 12 14.25 14.75 11.5"
        stroke="currentColor"
        strokeWidth="1.7"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <path d="M8.75 17h6.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
    </svg>
  );
}
