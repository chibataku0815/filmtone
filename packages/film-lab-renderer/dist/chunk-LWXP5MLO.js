// src/motionBlurMath.ts
var MOTION_BLUR_BASELINE_SHUTTER_ANGLE = 180;
var MOTION_BLUR_MAX_SHUTTER_ANGLE = 720;
var MOTION_BLUR_DEFAULT_RING_SLOTS = 8;
var MOTION_BLUR_BASELINE_EXPOSURE_FRAMES = MOTION_BLUR_BASELINE_SHUTTER_ANGLE / 360;
function clampMotionShutterAngle(shutterAngle) {
  if (!Number.isFinite(shutterAngle)) return 0;
  return Math.min(
    MOTION_BLUR_MAX_SHUTTER_ANGLE,
    Math.max(0, shutterAngle)
  );
}
function targetMotionExposureFrames(shutterAngle) {
  return clampMotionShutterAngle(shutterAngle) / 360;
}
function additionalMotionExposureFrames(shutterAngle) {
  return Math.max(
    0,
    targetMotionExposureFrames(shutterAngle) - MOTION_BLUR_BASELINE_EXPOSURE_FRAMES
  );
}
function isShutterMotionActive(shutterAngle) {
  return additionalMotionExposureFrames(shutterAngle) > 0;
}
function activeMotionBlurFramesForShutter(shutterAngle, ringSlots = MOTION_BLUR_DEFAULT_RING_SLOTS) {
  const additionalExposureFrames = additionalMotionExposureFrames(shutterAngle);
  if (additionalExposureFrames <= 0) return 1;
  const slots = Math.max(1, Math.round(ringSlots));
  const raw = 1 + Math.ceil(additionalExposureFrames);
  return Math.max(2, Math.min(slots, raw));
}
function computeMotionBlurWeights(shutterAngle, activeFrames, validSlots, ringSlots = MOTION_BLUR_DEFAULT_RING_SLOTS, weightCurve = "triangle") {
  const slots = Math.max(1, Math.round(ringSlots));
  const weights = new Float32Array(slots);
  const effective = Math.min(
    Math.max(0, Math.round(activeFrames)),
    Math.max(0, Math.round(validSlots)),
    slots
  );
  if (effective <= 0) return weights;
  if (effective === 1) {
    weights[0] = 1;
    return weights;
  }
  const clampedShutterAngle = clampMotionShutterAngle(shutterAngle);
  const flatness = Math.min(
    1,
    Math.max(0, (clampedShutterAngle - 360) / 360)
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
    sum += weights[i];
  }
  if (sum > 0) {
    for (let i = 0; i < effective; i++) weights[i] /= sum;
  }
  return weights;
}

export {
  clampMotionShutterAngle,
  isShutterMotionActive,
  activeMotionBlurFramesForShutter,
  computeMotionBlurWeights
};
