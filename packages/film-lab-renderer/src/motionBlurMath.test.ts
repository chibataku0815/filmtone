import { expect, test } from "bun:test";
import {
  additionalMotionExposureFrames,
  activeMotionBlurFramesForShutter,
  computeMotionBlurWeights,
  isShutterMotionActive,
} from "./motionBlurMath";

function expectCloseArray(actual: Float32Array, expected: number[]) {
  expect(actual.length).toBe(8);
  for (let i = 0; i < expected.length; i++) {
    expect(actual[i]!).toBeCloseTo(expected[i]!, 6);
  }
}

test("0 and 180 degrees are the no-added-blur baseline", () => {
  for (const shutterAngle of [0, 180]) {
    expect(isShutterMotionActive(shutterAngle)).toBe(false);
    expect(activeMotionBlurFramesForShutter(shutterAngle)).toBe(1);
    expectCloseArray(
      computeMotionBlurWeights(shutterAngle, 1, 8),
      [1, 0, 0, 0, 0, 0, 0, 0],
    );
  }
});

test("shutter angle maps to target exposure above the 180 degree source baseline", () => {
  expect(additionalMotionExposureFrames(0)).toBe(0);
  expect(additionalMotionExposureFrames(180)).toBe(0);
  expect(additionalMotionExposureFrames(360)).toBeCloseTo(0.5, 6);
  expect(additionalMotionExposureFrames(540)).toBeCloseTo(1, 6);
  expect(additionalMotionExposureFrames(720)).toBeCloseTo(1.5, 6);
});

test("360 degrees adds a two-frame triangle blend", () => {
  const activeFrames = activeMotionBlurFramesForShutter(360);
  expect(isShutterMotionActive(360)).toBe(true);
  expect(activeFrames).toBe(2);
  expectCloseArray(
    computeMotionBlurWeights(360, activeFrames, 8),
    [2 / 3, 1 / 3, 0, 0, 0, 0, 0, 0],
  );
});

test("540 degrees keeps the short two-frame exposure window", () => {
  expect(isShutterMotionActive(540)).toBe(true);
  expect(activeMotionBlurFramesForShutter(540)).toBe(2);
});

test("720 degrees uses the slow-shutter extension with flattened weights", () => {
  const activeFrames = activeMotionBlurFramesForShutter(720);
  expect(isShutterMotionActive(720)).toBe(true);
  expect(activeFrames).toBe(3);
  expectCloseArray(
    computeMotionBlurWeights(720, activeFrames, 8),
    [1 / 3, 1 / 3, 1 / 3, 0, 0, 0, 0, 0],
  );
});
