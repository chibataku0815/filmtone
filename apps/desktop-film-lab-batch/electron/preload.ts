/**
 * Film Lab バッチ — preload（contextBridge）
 *
 * @overview レンダラから呼べる API だけを極小露出する。
 * @description 更新案内（案 C）は main が IPC で送り、ここで購読だけ暴露します。
 */
import { contextBridge, ipcRenderer } from "electron";

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

contextBridge.exposeInMainWorld("filmLabBatch", {
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
  pickGradeJson: (): Promise<string | null> =>
    ipcRenderer.invoke("pick-grade-json"),
  listImages: (dir: string): Promise<string[]> =>
    ipcRenderer.invoke("list-images", dir),
  readFileUtf8: (filePath: string): Promise<string> =>
    ipcRenderer.invoke("read-file-utf8", filePath),
  readFileBuffer: (filePath: string): Promise<Uint8Array> =>
    ipcRenderer.invoke("read-file-buffer", filePath),
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
  }> => ipcRenderer.invoke("video-export-probe", filePath),
  videoExportStart: (payload: {
    inputVideoPath: string;
    outputDir: string;
    outputFileName: string;
    width: number;
    height: number;
    fps: number;
    hasAudio: boolean;
  }): Promise<{ outputVideoPath: string }> =>
    ipcRenderer.invoke("video-export-start", payload),
  videoExportWriteFrame: (data: Uint8Array): Promise<void> =>
    ipcRenderer.invoke("video-export-write-frame", data),
  videoExportFinish: (): Promise<{
    code: number | null;
    stderrTail: string;
  }> => ipcRenderer.invoke("video-export-finish"),
  videoExportAbort: (): Promise<void> =>
    ipcRenderer.invoke("video-export-abort"),
  videoExportStageSource: (
    filePath: string,
  ): Promise<{ stagedPath: string }> =>
    ipcRenderer.invoke("video-export-stage-source", filePath),
  videoExportUnlinkStaged: (stagedPath: string): Promise<void> =>
    ipcRenderer.invoke("video-export-unlink-staged", stagedPath),

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
