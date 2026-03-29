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
});
