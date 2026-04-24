import { describe, expect, test } from "bun:test";
import type { CameraOptics } from "film-lab-core";
import {
  RAY_ANGLE_REFERENCE_TAN_HALF_HFOV,
  rayAngleMaskValue,
  resolveRayAngleOptics,
} from "./rayAngleOptics";

function fovXDegFromFullFrameEquivalent(focalLengthMm: number): number {
  return (2 * Math.atan(36 / (2 * focalLengthMm)) * 180) / Math.PI;
}

function opticsForFullFrameEquivalent(focalLengthMm: number): CameraOptics {
  return {
    source: "metadata",
    fovXDeg: fovXDegFromFullFrameEquivalent(focalLengthMm),
  };
}

describe("resolveRayAngleOptics", () => {
  test("resolves explicit FOV and derives the missing axis from source aspect", () => {
    const resolved = resolveRayAngleOptics(
      { source: "metadata", fovXDeg: 54.432 },
      3840,
      2160,
    );
    expect(resolved.source).toBe("metadata");
    expect(resolved.tanHalfFovX).toBeCloseTo(Math.tan((54.432 * Math.PI) / 360), 6);
    expect(resolved.tanHalfFovY).toBeCloseTo(resolved.tanHalfFovX * (2160 / 3840), 6);
  });

  test("resolves focal pixels independently on X and Y", () => {
    const resolved = resolveRayAngleOptics(
      { source: "manual", fxPx: 2400, fyPx: 1800 },
      3840,
      2160,
    );
    expect(resolved.source).toBe("manual");
    expect(resolved.tanHalfFovX).toBeCloseTo(0.8, 6);
    expect(resolved.tanHalfFovY).toBeCloseTo(0.6, 6);
  });

  test("fallback65 reproduces the previous baseline shape", () => {
    const resolved = resolveRayAngleOptics(null, 3840, 2160);
    expect(resolved.source).toBe("fallback65");
    expect(resolved.tanHalfFovX).toBeCloseTo(RAY_ANGLE_REFERENCE_TAN_HALF_HFOV, 10);
    expect(resolved.tanHalfFovY).toBeCloseTo(
      RAY_ANGLE_REFERENCE_TAN_HALF_HFOV * (2160 / 3840),
      10,
    );
    expect(
      rayAngleMaskValue({
        imageUvX: 1,
        imageUvY: 1,
        imageWidth: 3840,
        imageHeight: 2160,
        optics: resolved,
        gamma: 1,
        innerThreshold: 0,
      }),
    ).toBeCloseTo(1, 6);
  });

  test("rejects invalid FOV and falls back to 65-degree horizontal FOV", () => {
    const resolved = resolveRayAngleOptics(
      { source: "metadata", fovXDeg: 179 },
      3840,
      2160,
    );
    expect(resolved.source).toBe("fallback65");
    expect(resolved.tanHalfFovX).toBeCloseTo(RAY_ANGLE_REFERENCE_TAN_HALF_HFOV, 10);
  });
});

describe("rayAngleMaskValue", () => {
  test("24/35/50/85/100mm full-frame equivalents produce distinct edge strengths", () => {
    const focalLengths = [24, 35, 50, 85, 100];
    const edgeStrengths = focalLengths.map((focalLength) =>
      rayAngleMaskValue({
        imageUvX: 1,
        imageUvY: 1,
        imageWidth: 3840,
        imageHeight: 2160,
        optics: opticsForFullFrameEquivalent(focalLength),
        gamma: 1.4,
        innerThreshold: 0,
      }),
    );
    for (let i = 1; i < edgeStrengths.length; i += 1) {
      expect(edgeStrengths[i - 1]!).toBeGreaterThan(edgeStrengths[i]!);
    }
    expect(new Set(edgeStrengths.map((v) => v.toFixed(4))).size).toBe(
      edgeStrengths.length,
    );
  });

  test("portrait 9:16 uses explicit tanHalfFovY instead of horizontal-FOV reuse", () => {
    const explicitPortrait = resolveRayAngleOptics(
      { source: "manual", fovXDeg: 40, fovYDeg: 80 },
      1080,
      1920,
    );
    const horizontalOnly = resolveRayAngleOptics(
      { source: "manual", fovXDeg: 40 },
      1080,
      1920,
    );
    expect(explicitPortrait.tanHalfFovY).not.toBeCloseTo(
      horizontalOnly.tanHalfFovY,
      4,
    );
    expect(
      rayAngleMaskValue({
        imageUvX: 0.5,
        imageUvY: 1,
        imageWidth: 1080,
        imageHeight: 1920,
        optics: explicitPortrait,
        gamma: 1,
        innerThreshold: 0,
      }),
    ).toBeGreaterThan(
      rayAngleMaskValue({
        imageUvX: 0.5,
        imageUvY: 1,
        imageWidth: 1080,
        imageHeight: 1920,
        optics: horizontalOnly,
        gamma: 1,
        innerThreshold: 0,
      }),
    );
  });
});
