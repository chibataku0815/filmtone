import { describe, expect, it, vi } from "vitest";
import { PRESETS, halationHueToHex } from "film-lab-core";
import type { BatchGradeState } from "../batch-pipeline";
import { applyBatchGradeToViewport } from "./apply-batch-grade-to-viewport";

function makeGrade(
  overrides: Partial<BatchGradeState> = {},
): BatchGradeState {
  const params = {
    ...Object.values(PRESETS)[0]!,
    halationHue: 24,
  };
  return {
    params,
    depthTrack: null,
    lut1Intensity: 0.7,
    lut1Data: new Float32Array([0, 0.5, 1]),
    lut1Size: 2,
    lutIntensity: 0.9,
    lutData: new Float32Array([1, 0.5, 0]),
    lutSize: 3,
    ...overrides,
  };
}

function makeViewportTarget() {
  return {
    setParams: vi.fn(),
    setLUT1: vi.fn(),
    setLUT1Intensity: vi.fn(),
    clearLUT1: vi.fn(),
    setLUT2: vi.fn(),
    setLUT2Intensity: vi.fn(),
    clearLUT2: vi.fn(),
  };
}

describe("applyBatchGradeToViewport", () => {
  it("applies params and both LUT stages when present", () => {
    const viewport = makeViewportTarget();
    const grade = makeGrade();

    applyBatchGradeToViewport(viewport, grade);

    expect(viewport.setParams).toHaveBeenCalledWith({
      ...grade.params,
      halationColor: halationHueToHex(grade.params.halationHue),
    });
    expect(viewport.setLUT1).toHaveBeenCalledWith(
      grade.lut1Data,
      grade.lut1Size,
    );
    expect(viewport.setLUT1Intensity).toHaveBeenCalledWith(
      grade.lut1Intensity,
    );
    expect(viewport.clearLUT1).not.toHaveBeenCalled();
    expect(viewport.setLUT2).toHaveBeenCalledWith(
      grade.lutData,
      grade.lutSize,
    );
    expect(viewport.setLUT2Intensity).toHaveBeenCalledWith(
      grade.lutIntensity,
    );
    expect(viewport.clearLUT2).not.toHaveBeenCalled();
  });

  it("clears missing LUT stages without touching stale textures", () => {
    const viewport = makeViewportTarget();
    const grade = makeGrade({
      lut1Data: null,
      lut1Size: 0,
      lutData: null,
      lutSize: 0,
    });

    applyBatchGradeToViewport(viewport, grade);

    expect(viewport.clearLUT1).toHaveBeenCalledTimes(1);
    expect(viewport.setLUT1).not.toHaveBeenCalled();
    expect(viewport.setLUT1Intensity).not.toHaveBeenCalled();
    expect(viewport.clearLUT2).toHaveBeenCalledTimes(1);
    expect(viewport.setLUT2).not.toHaveBeenCalled();
    expect(viewport.setLUT2Intensity).not.toHaveBeenCalled();
  });
});
