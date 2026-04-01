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
  getOptimalPixelRatio,
  Viewport,
  MediaLoader,
  MediaLoadError,
  filmlabVertexShader,
  filmlabFragmentShader,
} from "film-lab-renderer";
import type { Params } from "film-lab-core";

interface FilmLabCanvasProps {
  preset: PresetName;
  className?: string;
  fullScreen?: boolean;
  onViewportReady?: (viewport: Viewport | null) => void;
  /**
   * @description 最初に出す sample asset を親が明示したいときの URL です。
   * Web の `/film-lab` では canonical sample asset を直接渡し、Desktop では共有の既定解決に戻せます。
   */
  defaultSampleAssetUrl?: string;
  /**
   * @description true の間は、プレビューに読み込んだ動画の再生を止めます。
   * 画像プレビューには影響しません。書き出し中に preview 側の decoder / GPU 競合を
   * 減らしたいデスクトップアプリから使う前提です。
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
   * pointer-events-none でスプリット操作と干渉しない。
   */
  compareHud?: { activeSlot: "A" | "B" } | null;
  /** ドロップ／ファイル選択で .cube が適用できたとき（寄付ナッジ用） */
  onCubeLutLoaded?: () => void;
  /**
   * Web LP など親が「いまキャンバスに載っている元画像」を表示したいときの任意通知。
   * `.cube` のみ読んだ場合は画像ソースが変わらないため呼ばない。
   */
  onInteractiveSourceChange?: (
    info: { kind: "sample" } | { kind: "file"; fileName: string },
  ) => void;
}

/**
 * @description 親からキャプチャ用に呼び出す ref。スマートルック API 用に縮小 JPEG を base64 で返す。
 */
export type FilmLabCanvasRef = {
  getJpegBase64ForAi: (maxSide: number) => string | null;
  replaceSourceFromPngBase64Body: (pngBase64Body: string) => Promise<boolean>;
  openMediaPicker: () => void;
  saveCurrentPng: () => void;
};

/** ファイルピッカー用: HEIC を選びにくくしつつ、一般的な形式はそのまま選べる */
const FILM_LAB_FILE_ACCEPT =
  "image/jpeg,image/png,image/webp,image/gif,.jpg,.jpeg,.png,.webp,.gif,video/mp4,video/webm,.mp4,.webm,.cube,application/octet-stream";

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
      defaultSampleAssetUrl,
      pauseVideoPreview = false,
      stackedToolbarVisible = true,
      initialGradeParams = null,
      onCubeLutLoaded,
      onInteractiveSourceChange,
      compareHud = null,
      chromeLayout = "overlay",
    },
    ref,
  ) {
  const tFilmLab = useTranslations("film-lab");
  const onInteractiveSourceChangeRef = useRef(onInteractiveSourceChange);
  useEffect(() => {
    onInteractiveSourceChangeRef.current = onInteractiveSourceChange;
  });
  const onViewportReadyRef = useRef(onViewportReady);
  useEffect(() => {
    onViewportReadyRef.current = onViewportReady;
  }, [onViewportReady]);
  const containerRef = useRef<HTMLDivElement>(null);
  const viewportRef = useRef<Viewport | null>(null);
  const mediaLoaderRef = useRef<MediaLoader | null>(null);
  const rendererRef = useRef<THREE.WebGLRenderer | null>(null);
  const sceneRef = useRef<THREE.Scene | null>(null);
  const cameraRef = useRef<THREE.OrthographicCamera | null>(null);
  /** @description 現在のプレビュー動画要素。画像のときは null。 */
  const previewVideoElementRef = useRef<HTMLVideoElement | null>(null);
  /** @description busy に入る直前に再生中だった動画だけ、busy 明けで再開します。 */
  const previewVideoShouldResumeRef = useRef(false);
  /** @description 現在の pause が busy 制御由来かどうかを覚えます。 */
  const previewVideoPausedByBusyRef = useRef(false);
  const [isDragging, setIsDragging] = useState(false);
  const [isSplitDragging, setIsSplitDragging] = useState(false);
  const [supported, setSupported] = useState(true);
  const [mediaOverlay, setMediaOverlay] = useState<MediaOverlayState>({ kind: "idle" });
  const initialPresetRef = useRef(preset);
  const initialResolvedGradeRef = useRef<Params>(
    initialGradeParams ?? PRESETS[preset],
  );
  const defaultSampleAssetUrlRef = useRef(
    resolveDefaultSampleAssetUrl(defaultSampleAssetUrl),
  );

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
      if (shouldResume && videoElement.paused) {
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

  useEffect(() => {
    applyResolvedGradeToViewport();
  }, [applyResolvedGradeToViewport]);

  // Three.js setup
  useEffect(() => {
    const container = containerRef.current;
    if (!container) return;

    if (!isWebGL2Supported()) {
      setSupported(false);
      return;
    }

    const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0.1, 10);
    camera.position.z = 1;

    let width = Math.max(1, container.clientWidth);
    let height = Math.max(1, container.clientHeight);

    const renderer = new THREE.WebGLRenderer({
      antialias: false,
      alpha: false,
      preserveDrawingBuffer: true,
    });
    renderer.setSize(width, height);
    renderer.setPixelRatio(getOptimalPixelRatio(1.5));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    rendererRef.current = renderer;
    container.appendChild(renderer.domElement);

    const scene = new THREE.Scene();
    scene.background = new THREE.Color(0x0a0a0a);
    sceneRef.current = scene;
    cameraRef.current = camera;

    const viewport = new Viewport({
      vertexShader: filmlabVertexShader,
      fragmentShader: filmlabFragmentShader,
      width,
      height,
    });
    scene.add(viewport.mesh);
    viewportRef.current = viewport;
    onViewportReadyRef.current?.(viewport);
    viewport.setParams(buildViewportParams(initialResolvedGradeRef.current));

    const mediaLoader = new MediaLoader();
    mediaLoaderRef.current = mediaLoader;
    const defaultSampleUrl = defaultSampleAssetUrlRef.current;

    mediaLoader
      .loadURL(defaultSampleUrl)
      .then((result) => {
        viewport.setTexture(result.texture);
        viewport.setImageResolution(result.width, result.height);
        previewVideoElementRef.current = null;
        previewVideoShouldResumeRef.current = false;
        previewVideoPausedByBusyRef.current = false;
        onInteractiveSourceChangeRef.current?.({ kind: "sample" });
      })
      .catch((err) => {
        const message = `FilmLabCanvas.loadDefaultSample("${defaultSampleUrl}") failed. Open a file manually or verify that the canonical sample asset is reachable.`;
        console.error(message, {
          sampleAssetUrl: defaultSampleUrl,
          preset: initialPresetRef.current,
          initialResolvedGrade: initialResolvedGradeRef.current,
          err,
        });
        setMediaOverlay({
          kind: "error",
          message,
        });
      });

    /**
     * @description `window.resize` だけでは、右ペイン開閉や absolute layout の再計測を取りこぼします。
     * そのため container 自体を観測し、0 サイズから実サイズへ立ち上がった瞬間も拾います。
     */
    const syncViewportSize = () => {
      const nextWidth = Math.max(1, container.clientWidth);
      const nextHeight = Math.max(1, container.clientHeight);
      if (nextWidth === width && nextHeight === height) {
        return;
      }

      width = nextWidth;
      height = nextHeight;
      renderer.setSize(width, height);
      viewport.setResolution(width, height);
    };
    syncViewportSize();

    const resizeObserver =
      typeof ResizeObserver !== "undefined"
        ? new ResizeObserver(() => {
            syncViewportSize();
          })
        : null;
    resizeObserver?.observe(container);

    const resizeRafId = window.requestAnimationFrame(() => {
      syncViewportSize();
    });
    window.addEventListener("resize", syncViewportSize);

    const clock = new THREE.Clock();
    let animationId: number;
    const animate = () => {
      animationId = requestAnimationFrame(animate);
      viewport.setTime(clock.getElapsedTime());
      viewport.render(renderer, scene, camera);
    };
    animate();

    return () => {
      cancelAnimationFrame(animationId);
      window.cancelAnimationFrame(resizeRafId);
      resizeObserver?.disconnect();
      window.removeEventListener("resize", syncViewportSize);
      viewport.dispose();
      renderer.dispose();
      previewVideoElementRef.current = null;
      previewVideoShouldResumeRef.current = false;
      previewVideoPausedByBusyRef.current = false;
      if (container.contains(renderer.domElement)) {
        container.removeChild(renderer.domElement);
      }
      viewportRef.current = null;
      mediaLoaderRef.current = null;
      rendererRef.current = null;
      sceneRef.current = null;
      cameraRef.current = null;
      onViewportReadyRef.current?.(null);
    };
  }, []);

  const getMaxTextureSize = useCallback((): number => {
    return rendererRef.current?.capabilities.maxTextureSize ?? 8192;
  }, []);

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

        const maxTex = getMaxTextureSize();
        const result = await mediaLoaderRef.current.loadFile(file, {
          maxTextureSize: maxTex,
        });
        const nextPreviewVideo =
          result.type === "video" &&
          result.texture.image instanceof HTMLVideoElement
            ? result.texture.image
            : null;
        previewVideoElementRef.current = nextPreviewVideo;
        previewVideoShouldResumeRef.current = false;
        previewVideoPausedByBusyRef.current = false;
        viewportRef.current.setTexture(result.texture);
        viewportRef.current.setImageResolution(result.width, result.height);
        syncPreviewVideoBusyState(nextPreviewVideo);
        onInteractiveSourceChangeRef.current?.({ kind: "file", fileName: file.name });
        setMediaOverlay({ kind: "idle" });
      } catch (err) {
        const message =
          err instanceof MediaLoadError
            ? err.message
            : err instanceof Error
              ? `FilmLabCanvas.loadUserMediaFile("${file.name}", "${file.type || "unknown"}") failed: ${err.message}`
              : `FilmLabCanvas.loadUserMediaFile("${file.name}", "${file.type || "unknown"}") failed: Could not load this file.`;
        setMediaOverlay({ kind: "error", message });
        console.error("FilmLabCanvas.loadUserMediaFile failed", {
          fileName: file.name,
          fileType: file.type,
          err,
        });
      }
    },
    [getMaxTextureSize, onCubeLutLoaded, syncPreviewVideoBusyState],
  );

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
    const renderer = rendererRef.current;
    const scene = sceneRef.current;
    const camera = cameraRef.current;
    if (!viewport || !renderer || !scene || !camera) return;

    const splitBefore = viewport.getSplitPosition();
    viewport.setSplitPosition(-1.0);
    viewport.render(renderer, scene, camera);

    const url = renderer.domElement.toDataURL("image/png");
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
        const renderer = rendererRef.current;
        if (!renderer || !supported) return null;
        const src = renderer.domElement;
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
        const viewport = viewportRef.current;
        const mediaLoader = mediaLoaderRef.current;
        const renderer = rendererRef.current;
        if (!viewport || !mediaLoader || !renderer || !supported) return false;
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
          const maxTex = renderer.capabilities.maxTextureSize;
          const result = await mediaLoader.loadFile(file, {
            maxTextureSize: maxTex,
          });
          previewVideoElementRef.current = null;
          previewVideoShouldResumeRef.current = false;
          previewVideoPausedByBusyRef.current = false;
          viewport.setTexture(result.texture);
          viewport.setImageResolution(result.width, result.height);
          onInteractiveSourceChangeRef.current?.({
            kind: "file",
            fileName: "smart-look-corrected.png",
          });
          return true;
        } catch (err) {
          console.error("FilmLabCanvas.replaceSourceFromPngBase64Body failed", err);
          return false;
        }
      },
      openMediaPicker: () => handleFileClick(),
      saveCurrentPng: () => handleDownload(),
    }),
    [handleDownload, handleFileClick, supported],
  );

  if (!supported) {
    return (
      <div
        className={`relative flex ${fullScreen ? "h-full" : "aspect-[4/3] sm:aspect-[16/9]"} w-full items-center justify-center rounded-lg bg-[#0a0a0a] ${className ?? ""}`}
      >
        <span className="text-sm text-[var(--text-muted)]">
          {tFilmLab("canvas.webgl2Required")}
        </span>
      </div>
    );
  }

  const viewportHostClassName = `relative ${fullScreen ? "h-full min-h-0" : "aspect-[4/3] sm:aspect-[16/9]"} w-full touch-none cursor-col-resize overflow-hidden rounded-lg bg-[#0a0a0a] ${chromeLayout === "stacked" ? "min-h-[200px] sm:min-h-[240px]" : ""}`;

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

      {compareHud != null && (
        <>
          <div className="pointer-events-none absolute left-0 right-0 top-16 z-[6] flex justify-center px-3 sm:top-[4.5rem]">
            <span className="rounded-full bg-black/55 px-2.5 py-1 text-[10px] font-medium text-white/80 ring-1 ring-white/15 backdrop-blur-sm">
              {tFilmLab("compare.dragSplitHint")}
            </span>
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
          <span className="rounded-lg bg-black/70 px-4 py-3 text-sm text-white/90">
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

  const viewportPointerAndDragProps = {
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
