/**
 * window.filmLabBatch の型（preload と共有）
 */
export type FilmLabBatchBridge = {
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
};

declare global {
  interface Window {
    filmLabBatch: FilmLabBatchBridge;
  }
}

export {};
