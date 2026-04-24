/**
 * Film Lab バッチ — preload（contextBridge）
 *
 * @overview レンダラから呼べる API だけを極小露出する。
 * @description 更新案内（案 C）は main が IPC で送り、ここで購読だけ暴露します。
 */
import { contextBridge, ipcRenderer, webUtils } from "electron";
import type { CameraOptics } from "film-lab-core";

/** @description main から届く「新しい版があります」通知の中身 */
export type DesktopUpdateAvailablePayload = {
  latestVersion: string;
  downloadPageUrl: string;
  releaseNotesUrl?: string;
};

export type OutputPayload = {
  outputDir: string;
  fileName: string;
  data: Uint8Array;
};

/**
 * @description main から届く mezzanine 進捗。current は 0-99、total は 100 固定。
 */
export type VideoExportMezzanineProgressPayload = {
  /** @description 0 から 99 までの進み具合 */
  current: number;
  /** @description 分母。mezzanine は 100 固定 */
  total: number;
};

/**
 * @description Progressive loading の proxy 進捗。current は 0-99、total は 100 固定です。
 */
export type VideoPreviewProxyProgressPayload = {
  /** @description 0 から 99 までの進み具合 */
  current: number;
  /** @description 分母。proxy は 100 固定 */
  total: number;
};

export type SourceDisplayGeometry = {
  rawWidth: number;
  rawHeight: number;
  displayWidth: number;
  displayHeight: number;
  rotationDeg: 0 | 90 | 180 | 270 | null;
  source: "ffprobe-side-data" | "ffprobe-tags" | "raw";
};

export type SourceColorMetadata = {
  colorRange: string | null;
  colorSpace: string | null;
  colorTransfer: string | null;
  colorPrimaries: string | null;
  hasMasteringDisplayMetadata: boolean;
  hasContentLightMetadata: boolean;
};

export type SourceColorClass =
  | "sdr-bt709"
  | "hdr-pq"
  | "hdr-hlg"
  | "wide-gamut-unknown"
  | "unknown";

export type HdrPreparationPolicy = {
  strategy: "none" | "prepare-sdr-mezzanine" | "defer-unknown";
  reason:
    | "source-is-sdr-bt709"
    | "source-is-hdr-pq"
    | "source-is-hdr-hlg"
    | "wide-gamut-transfer-unknown"
    | "source-color-unknown";
  requiresFixtureValidation: boolean;
  warning: string | null;
};

export type SourceVideoTimingMetadata = {
  avgFrameRate: string | null;
  rFrameRate: string | null;
  avgFrameRateParsed: number | null;
  rFrameRateParsed: number | null;
  sourceFrameRate: number | null;
  sourceFrameRateTrusted: boolean;
  trustReason:
    | "missing-or-invalid-rate"
    | "rates-diverged"
    | "within-absolute-tolerance"
    | "within-relative-tolerance";
};

export type SourceVideoMetadata = {
  display: SourceDisplayGeometry;
  color: SourceColorMetadata;
  colorClass: SourceColorClass;
  hdrPreparationPolicy?: HdrPreparationPolicy;
  timing?: SourceVideoTimingMetadata;
};

/**
 * @description mezzanine 変換へ渡す入力。durationSec は進捗の割合を出すために使う。
 */
export type VideoExportTranscodeMezzanineInput = {
  /** @description 元動画の絶対パス */
  filePath: string;
  /** @description 元動画の長さ（秒） */
  durationSec: number;
  /** @description 書き出し幅（mezzanine を FHD にダウンスケールする） */
  outW: number;
  /** @description 書き出し高さ */
  outH: number;
};

/**
 * @description Stage 1 の JPEG サムネイル抽出入力です。
 */
export type VideoPreviewExtractThumbnailInput = {
  /** @description 元動画の絶対パス */
  filePath: string;
  /** @description 元動画の横幅 */
  sourceWidth: number;
  /** @description 元動画の縦幅 */
  sourceHeight: number;
};

/**
 * @description Stage 2 の proxy 生成入力です。
 */
export type VideoPreviewGenerateProxyInput = {
  /** @description 元動画の絶対パス */
  filePath: string;
  /** @description 元動画の長さ（秒） */
  durationSec: number;
};

export type VideoPreviewProxyCacheInfo = {
  entryCount: number;
  totalBytes: number;
  maxEntries: number;
  maxTotalBytes: number;
  maxAgeDays: number;
};

contextBridge.exposeInMainWorld("filmLabBatch", {
  /**
   * @description `contextIsolation` では `File.path` が使えないため、Chromium が許可する `File` から絶対パスを返す（Electron 公式 API）。
   */
  getPathForFile: (file: File): string => webUtils.getPathForFile(file),

  getDesktopPrefs: (): Promise<{
    lastInputDir: string | null;
    lastOutputDir: string | null;
  }> => ipcRenderer.invoke("desktop-prefs-get"),
  setDesktopPrefs: (payload: {
    lastInputDir?: string;
    lastOutputDir?: string;
  }): Promise<void> => ipcRenderer.invoke("desktop-prefs-set", payload),
  pickInputDir: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-input-dir"),
  pickOutputDir: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-output-dir"),
  pickMetadataJson: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-metadata-json"),
  pickGradeJson: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-grade-json"),
  listImages: (dir: string): Promise<string[]> =>
    ipcRenderer.invoke("list-images", dir),
  readFileUtf8: (filePath: string): Promise<string> =>
    ipcRenderer.invoke("read-file-utf8", filePath),
  readFileBuffer: (filePath: string): Promise<Uint8Array> =>
    ipcRenderer.invoke("read-file-buffer", filePath),
  writeFileUtf8: (payload: {
    filePath: string;
    text: string;
  }): Promise<void> => ipcRenderer.invoke("write-file-utf8", payload),
  readCubeRelativeToGrade: (
    gradeJsonPath: string,
    relPath: string,
  ): Promise<string> =>
    ipcRenderer.invoke(
      "read-cube-relative-to-grade",
      gradeJsonPath,
      relPath,
    ),
  writeOutputFile: (payload: OutputPayload): Promise<string> =>
    ipcRenderer.invoke("write-output-file", payload),
  readBatchSession: (): Promise<unknown | null> =>
    ipcRenderer.invoke("batch-session-read"),
  writeBatchSession: (payload: unknown): Promise<void> =>
    ipcRenderer.invoke("batch-session-write", payload),
  clearBatchSession: (): Promise<void> =>
    ipcRenderer.invoke("batch-session-clear"),
  pathToFileURL: (filePath: string): Promise<string> =>
    ipcRenderer.invoke("path-to-file-url", filePath),
  pickInputVideoFile: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-input-video-file"),
  videoExportProbe: (
    filePath: string,
  ): Promise<{
    width: number;
    height: number;
    durationSec: number;
    hasAudio: boolean;
    videoCodec: string;
    sourceFrameRate: number | null;
    sourceFrameRateTrusted: boolean;
    fileSizeBytes: number;
    cameraOptics: CameraOptics;
    sourceVideoMetadata?: SourceVideoMetadata;
  }> => ipcRenderer.invoke("video-export-probe", filePath),
  videoExportStart: (payload: {
    inputVideoPath: string;
    outputDir: string;
    outputFileName: string;
    width: number;
    height: number;
    fps: number;
    hasAudio: boolean;
    dropFirstFrame: boolean;
    cameraOptics?: CameraOptics | null;
  }): Promise<{ outputVideoPath: string; sessionId: string }> =>
    ipcRenderer.invoke("video-export-start", payload),
  videoExportWriteFrame: (payload: {
    sessionId: string;
    data: Uint8Array;
  }): Promise<void> =>
    ipcRenderer.invoke("video-export-write-frame", payload),
  videoExportFinish: (sessionId: string): Promise<{
    code: number | null;
    stderrTail: string;
  }> => ipcRenderer.invoke("video-export-finish", sessionId),
  videoExportAbort: (sessionId?: string | null): Promise<void> =>
    ipcRenderer.invoke("video-export-abort", sessionId ?? null),
  videoExportStageSource: (
    filePath: string,
  ): Promise<{ stagedPath: string }> =>
    ipcRenderer.invoke("video-export-stage-source", filePath),
  videoExportUnlinkStaged: (stagedPath: string): Promise<void> =>
    ipcRenderer.invoke("video-export-unlink-staged", stagedPath),
  videoPreviewExtractThumbnail: (
    payload: VideoPreviewExtractThumbnailInput,
  ): Promise<{ thumbnailPath: string; width: number; height: number }> =>
    ipcRenderer.invoke("video-preview-extract-thumbnail", payload),
  videoPreviewGenerateProxy: (
    payload: VideoPreviewGenerateProxyInput,
  ): Promise<{ proxyPath: string; proxySizeBytes: number; cacheHit: boolean }> =>
    ipcRenderer.invoke("video-preview-generate-proxy", payload),
  videoPreviewGetProxyCacheInfo: (): Promise<VideoPreviewProxyCacheInfo> =>
    ipcRenderer.invoke("video-preview-get-proxy-cache-info"),
  videoPreviewPurgeProxyCache: (): Promise<{
    removedEntries: number;
    removedBytes: number;
  }> => ipcRenderer.invoke("video-preview-purge-proxy-cache"),
  videoPreviewAbortProxy: (): Promise<void> =>
    ipcRenderer.invoke("video-preview-abort-proxy"),
  /**
   * @description main からの proxy 進捗を受け取る。戻り値で購読解除。
   */
  subscribeProxyProgress: (
    callback: (payload: VideoPreviewProxyProgressPayload) => void,
  ): (() => void) => {
    const channel = "film-lab-preview-proxy-progress";
    const handler = (
      _event: Electron.IpcRendererEvent,
      payload: VideoPreviewProxyProgressPayload,
    ): void => {
      callback(payload);
    };
    ipcRenderer.on(channel, handler);
    return () => {
      ipcRenderer.removeListener(channel, handler);
    };
  },
  videoExportTranscodeMezzanine: (
    payload: VideoExportTranscodeMezzanineInput,
  ): Promise<{ mezzaninePath: string; mezzanineSizeBytes: number }> =>
    ipcRenderer.invoke("video-export-transcode-mezzanine", payload),
  videoExportAbortMezzanine: (): Promise<void> =>
    ipcRenderer.invoke("video-export-abort-mezzanine"),
  /**
   * @description main からの mezzanine 進捗を受け取る。戻り値で購読解除。
   */
  subscribeMezzanineProgress: (
    callback: (payload: VideoExportMezzanineProgressPayload) => void,
  ): (() => void) => {
    const channel = "film-lab-video-export-mezzanine-progress";
    const handler = (
      _event: Electron.IpcRendererEvent,
      payload: VideoExportMezzanineProgressPayload,
    ): void => {
      callback(payload);
    };
    ipcRenderer.on(channel, handler);
    return () => {
      ipcRenderer.removeListener(channel, handler);
    };
  },

  /**
   * @description まとめて書き出し中は更新バナーを出さないよう main に伝える
   */
  setExportBusyForUpdateCheck: (busy: boolean): Promise<void> =>
    ipcRenderer.invoke("desktop-update-set-export-busy", busy),

  /**
   * @description バナーの「後で」。同じ版はしばらく再通知しない
   */
  dismissDesktopUpdate: (latestVersion: string): Promise<void> =>
    ipcRenderer.invoke("desktop-update-dismiss", latestVersion),

  /**
   * @description 既定ブラウザで URL を開く（ダウンロードページなど）
   */
  openExternalUrl: (url: string): Promise<void> =>
    ipcRenderer.invoke("desktop-update-open-external", url),

  /**
   * @description main から更新通知を受け取る。戻り値で購読解除
   */
  subscribeDesktopUpdateAvailable: (
    callback: (payload: DesktopUpdateAvailablePayload) => void,
  ): (() => void) => {
    const channel = "film-lab-desktop-update-available";
    const handler = (
      _event: Electron.IpcRendererEvent,
      payload: DesktopUpdateAvailablePayload,
    ): void => {
      callback(payload);
    };
    ipcRenderer.on(channel, handler);
    return () => {
      ipcRenderer.removeListener(channel, handler);
    };
  },
});
