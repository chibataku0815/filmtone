import type { CameraOptics, Params } from "film-lab-core";

/** @description メインプロセスから届く「新しい版があります」通知 */
export type DesktopUpdateAvailablePayload = {
  latestVersion: string;
  downloadPageUrl: string;
  releaseNotesUrl?: string;
};

/**
 * @description mezzanine 進捗の中身。画面のラベルは renderer が locale ごとに決める。
 */
export type VideoExportMezzanineProgressPayload = {
  /** @description 0 から 99 までの進み具合 */
  current: number;
  /** @description 分母。mezzanine は 100 固定 */
  total: number;
};

/**
 * @description Progressive loading のプロキシ進捗。mezzanine と同じ 0-99 / 100 形式で扱います。
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

export type SourceVideoMetadata = {
  display: SourceDisplayGeometry;
};

/**
 * @description mezzanine 変換に渡す入力。durationSec は進捗の割合を出すために使う。
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
 * @description Stage 1 の JPEG サムネイル抽出入力。
 * 元動画サイズを渡して、main 側で戻り値の width / height を安定して計算します。
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
 * @description Stage 2 の低解像度プロキシ生成入力。
 * durationSec は ffmpeg stderr の time= と割って進捗率を出すために使います。
 */
export type VideoPreviewGenerateProxyInput = {
  /** @description 元動画の絶対パス */
  filePath: string;
  /** @description 元動画の長さ（秒） */
  durationSec: number;
};

/**
 * @description Stage 1 の JPEG サムネイル抽出結果。
 */
export type VideoPreviewExtractThumbnailResult = {
  /** @description tmp に作ったサムネイル JPEG の絶対パス */
  thumbnailPath: string;
  /** @description プレビュー表示に使う横幅 */
  width: number;
  /** @description プレビュー表示に使う縦幅 */
  height: number;
};

/**
 * @description Stage 2 の低解像度プロキシ生成結果。
 */
export type VideoPreviewGenerateProxyResult = {
  /** @description tmp に作った proxy MP4 の絶対パス */
  proxyPath: string;
  /** @description proxy ファイルサイズ（バイト） */
  proxySizeBytes: number;
  /** @description persistent cache を再利用できたとき true */
  cacheHit: boolean;
};

export type VideoPreviewProxyCacheInfo = {
  entryCount: number;
  totalBytes: number;
  maxEntries: number;
  maxTotalBytes: number;
  maxAgeDays: number;
};

/**
 * window.filmLabBatch の型（preload と共有）
 */
export type FilmLabBatchBridge = {
  /**
   * @description ファイルピッカー／ドロップで得た `File` のディスク上の絶対パス（プレビューと書き出し入力の同期用）
   */
  getPathForFile: (file: File) => string;

  /** @description electron-store の最終入出力フォルダ（存在確認済み） */
  getDesktopPrefs: () => Promise<{
    lastInputDir: string | null;
    lastOutputDir: string | null;
  }>;
  setDesktopPrefs: (payload: {
    lastInputDir?: string;
    lastOutputDir?: string;
  }) => Promise<void>;
  pickInputDir: () => Promise<string | null>;
  pickOutputDir: () => Promise<string | null>;
  pickMetadataJson: () => Promise<string | null>;
  pickGradeJson: () => Promise<string | null>;
  listImages: (dir: string) => Promise<string[]>;
  readFileUtf8: (filePath: string) => Promise<string>;
  readFileBuffer: (filePath: string) => Promise<Uint8Array>;
  writeFileUtf8: (payload: {
    filePath: string;
    text: string;
  }) => Promise<void>;
  readCubeRelativeToGrade: (
    gradeJsonPath: string,
    relPath: string,
  ) => Promise<string>;
  writeOutputFile: (payload: {
    outputDir: string;
    fileName: string;
    data: Uint8Array;
  }) => Promise<string>;
  /** @description userData に保存したバッチ再開セッションを読む。無ければ null */
  readBatchSession: () => Promise<unknown | null>;
  /** @description バッチ再開セッションを上書き保存する */
  writeBatchSession: (payload: unknown) => Promise<void>;
  /** @description セッションファイルを削除する */
  clearBatchSession: () => Promise<void>;

  /** @description 動画デコード用 URL（`film-lab-video://`… Vite dev では file:// 直は Chromium に拒否される） */
  pathToFileURL: (absolutePath: string) => Promise<string>;
  /** @description 1 本の動画ファイルを選択 */
  pickInputVideoFile: () => Promise<string | null>;
  /** @description ffprobe で解像度・長尺・音声の有無・ソース FPS メタを取得 */
  videoExportProbe: (absolutePath: string) => Promise<{
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
  }>;
  /** @description ffmpeg を rawvideo stdin で起動（1 セッションのみ） */
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
  }) => Promise<{ outputVideoPath: string; sessionId: string }>;
  videoExportWriteFrame: (payload: {
    sessionId: string;
    data: Uint8Array;
  }) => Promise<void>;
  videoExportFinish: (sessionId: string) => Promise<{
    code: number | null;
    stderrTail: string;
  }>;
  videoExportAbort: (sessionId?: string | null) => Promise<void>;
  /** @description Photos 等の一時パス対策: 実ファイルを tmp にコピーしてパスを返す */
  videoExportStageSource: (
    absolutePath: string,
  ) => Promise<{ stagedPath: string }>;
  /** @description videoExportStageSource で作った tmp を削除 */
  videoExportUnlinkStaged: (stagedPath: string) => Promise<void>;
  /** @description Stage 1: グレード前提の 1280px JPEG サムネイルを作る */
  videoPreviewExtractThumbnail: (
    payload: VideoPreviewExtractThumbnailInput,
  ) => Promise<VideoPreviewExtractThumbnailResult>;
  /** @description Stage 2: 低解像度 H.264 proxy を作る */
  videoPreviewGenerateProxy: (
    payload: VideoPreviewGenerateProxyInput,
  ) => Promise<VideoPreviewGenerateProxyResult>;
  /** @description proxy cache の件数と容量を返す */
  videoPreviewGetProxyCacheInfo: () => Promise<VideoPreviewProxyCacheInfo>;
  /** @description persistent proxy cache を空にする */
  videoPreviewPurgeProxyCache: () => Promise<{
    removedEntries: number;
    removedBytes: number;
  }>;
  /** @description Stage 2 の proxy 生成を中断 */
  videoPreviewAbortProxy: () => Promise<void>;
  /** @description Stage 2 の proxy 進捗を main から受け取る。戻り値は購読解除。 */
  subscribeProxyProgress: (
    callback: (payload: VideoPreviewProxyProgressPayload) => void,
  ) => () => void;
  /** @description HEVC 等の重い素材を H.264 mezzanine に事前変換 */
  videoExportTranscodeMezzanine: (
    payload: VideoExportTranscodeMezzanineInput,
  ) => Promise<{ mezzaninePath: string; mezzanineSizeBytes: number }>;
  /** @description mezzanine 変換を中断 */
  videoExportAbortMezzanine: () => Promise<void>;
  /**
   * @description mezzanine 進捗を main から受け取る。戻り値は購読解除。
   */
  subscribeMezzanineProgress: (
    callback: (payload: VideoExportMezzanineProgressPayload) => void,
  ) => () => void;

  /** @description 長い書き出し中は更新通知を遅らせる（main と同期） */
  setExportBusyForUpdateCheck: (busy: boolean) => Promise<void>;
  /** @description 更新バナーを閉じ、同じ版はしばらく再通知しない */
  dismissDesktopUpdate: (latestVersion: string) => Promise<void>;
  /** @description ダウンロードページなどを既定ブラウザで開く */
  openExternalUrl: (url: string) => Promise<void>;
  /** @description 新しい版の通知を購読。戻り値で解除 */
  subscribeDesktopUpdateAvailable: (
    callback: (payload: DesktopUpdateAvailablePayload) => void,
  ) => () => void;
};

declare global {
  interface Window {
    filmLabBatch: FilmLabBatchBridge;
  }
}

export {};
