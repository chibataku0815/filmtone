import { halationHueToHex } from "film-lab-core";
import type { BatchGradeState } from "../batch-pipeline";

export interface ViewportGradeTarget {
  setParams(params: Record<string, number | string | boolean>): void;
  setLUT1(data: Float32Array, size: number): void;
  setLUT1Intensity(value: number): void;
  clearLUT1(): void;
  setLUT2(data: Float32Array, size: number): void;
  setLUT2Intensity(value: number): void;
  clearLUT2(): void;
}

/**
 * @description バッチ / 動画書き出しで共有する grade + LUT 適用順。
 * WebGL / WebGPU どちらでも「viewport-like」な target へ同じ blob を流せるように保つ。
 */
export function applyBatchGradeToViewport(
  viewport: ViewportGradeTarget,
  grade: BatchGradeState,
): void {
  viewport.setParams({
    ...grade.params,
    halationColor: halationHueToHex(grade.params.halationHue),
  });

  if (grade.lut1Data && grade.lut1Size > 0) {
    viewport.setLUT1(grade.lut1Data, grade.lut1Size);
    viewport.setLUT1Intensity(grade.lut1Intensity);
  } else {
    viewport.clearLUT1();
  }

  if (grade.lutData && grade.lutSize > 0) {
    viewport.setLUT2(grade.lutData, grade.lutSize);
    viewport.setLUT2Intensity(grade.lutIntensity);
  } else {
    viewport.clearLUT2();
  }
}
