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
});
