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
};

declare global {
  interface Window {
    filmLabBatch: FilmLabBatchBridge;
  }
}

export {};
