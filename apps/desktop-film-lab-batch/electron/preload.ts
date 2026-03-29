/**
 * Film Lab バッチ — preload（contextBridge）
 *
 * @overview レンダラから呼べる API だけを極小露出する。
 */
import { contextBridge, ipcRenderer } from "electron";

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
  videoExportTranscodeFast: (payload: {
    inputVideoPath: string;
    outputDir: string;
    outputFileName: string;
    width: number;
    height: number;
    fps: number;
    hasAudio: boolean;
    lutCubeAbsPath: string;
    gradeParams: Record<string, unknown>;
  }): Promise<{
    code: number | null;
    stderrTail: string;
    outputVideoPath: string;
  }> => ipcRenderer.invoke("video-export-transcode-fast", payload),
  videoExportStageSource: (
    filePath: string,
  ): Promise<{ stagedPath: string }> =>
    ipcRenderer.invoke("video-export-stage-source", filePath),
  videoExportUnlinkStaged: (stagedPath: string): Promise<void> =>
    ipcRenderer.invoke("video-export-unlink-staged", stagedPath),
});
