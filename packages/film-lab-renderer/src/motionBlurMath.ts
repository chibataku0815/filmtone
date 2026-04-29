export const MOTION_BLUR_BASELINE_SHUTTER_ANGLE = 180;
export const MOTION_BLUR_MAX_SHUTTER_ANGLE = 720;
export const MOTION_BLUR_DEFAULT_RING_SLOTS = 8;

export type MotionBlurWeightCurve = "triangle" | "box" | "exponential";

export function clampMotionShutterAngle(shutterAngle: number): number {
  if (!Number.isFinite(shutterAngle)) return 0;
  return Math.min(
    MOTION_BLUR_MAX_SHUTTER_ANGLE,
    Math.max(0, shutterAngle),
  );
}

export function additionalMotionShutterAngle(shutterAngle: number): number {
  return clampMotionShutterAngle(shutterAngle) - MOTION_BLUR_BASELINE_SHUTTER_ANGLE;
}

export function isShutterMotionActive(shutterAngle: number): boolean {
  return additionalMotionShutterAngle(shutterAngle) > 0;
}

export function activeMotionBlurFramesForShutter(
  shutterAngle: number,
  ringSlots: number = MOTION_BLUR_DEFAULT_RING_SLOTS,
): number {
  const additionalAngle = additionalMotionShutterAngle(shutterAngle);
  if (additionalAngle <= 0) return 1;
  const slots = Math.max(1, Math.round(ringSlots));
  const raw = Math.round((additionalAngle / 360) * (slots / 2));
  return Math.max(2, Math.min(slots, raw));
}

export function computeMotionBlurWeights(
  shutterAngle: number,
  activeFrames: number,
  validSlots: number,
  ringSlots: number = MOTION_BLUR_DEFAULT_RING_SLOTS,
  weightCurve: MotionBlurWeightCurve = "triangle",
): Float32Array {
  const slots = Math.max(1, Math.round(ringSlots));
  const weights = new Float32Array(slots);
  const effective = Math.min(
    Math.max(0, Math.round(activeFrames)),
    Math.max(0, Math.round(validSlots)),
    slots,
  );
  if (effective <= 0) return weights;
  if (effective === 1) {
    weights[0] = 1;
    return weights;
  }

  const clampedShutterAngle = clampMotionShutterAngle(shutterAngle);
  const flatness = Math.min(
    1,
    Math.max(0, (clampedShutterAngle - 360) / 360),
  );
  let sum = 0;
  for (let i = 0; i < effective; i++) {
    const triangleW = effective - i;
    const boxW = 1;
    switch (weightCurve) {
      case "box":
        weights[i] = boxW;
        break;
      case "exponential":
        weights[i] = Math.exp(-1.5 * i) * (1 - flatness) + boxW * flatness;
        break;
      case "triangle":
      default:
        weights[i] = triangleW * (1 - flatness) + boxW * flatness;
        break;
    }
    sum += weights[i]!;
  }
  if (sum > 0) {
    for (let i = 0; i < effective; i++) weights[i]! /= sum;
  }
  return weights;
}
