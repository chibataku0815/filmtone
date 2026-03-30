import type { Params } from "film-lab-core";

/** @description メインプロセスから届く「新しい版があります」通知 */
export type DesktopUpdateAvailablePayload = {
  latestVersion: string;
  downloadPageUrl: string;
  releaseNotesUrl?: string;
};

/**
 * window.filmLabBatch の型（preload と共有）
 */
export type FilmLabBatchBridge = {
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
  pickGradeJson: () => Promise<string | null>;
  listImages: (dir: string) => Promise<string[]>;
  readFileUtf8: (filePath: string) => Promise<string>;
  readFileBuffer: (filePath: string) => Promise<Uint8Array>;
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
  }) => Promise<{ outputVideoPath: string }>;
  videoExportWriteFrame: (data: Uint8Array) => Promise<void>;
  videoExportFinish: () => Promise<{
    code: number | null;
    stderrTail: string;
  }>;
  videoExportAbort: () => Promise<void>;
  /** @description Photos 等の一時パス対策: 実ファイルを tmp にコピーしてパスを返す */
  videoExportStageSource: (
    absolutePath: string,
  ) => Promise<{ stagedPath: string }>;
  /** @description videoExportStageSource で作った tmp を削除 */
  videoExportUnlinkStaged: (stagedPath: string) => Promise<void>;

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
