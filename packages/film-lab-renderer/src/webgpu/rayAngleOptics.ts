import type { CameraOptics, CameraOpticsSource } from "film-lab-core";

export type RayAngleOpticsSource = CameraOpticsSource | "fallback65";

export interface ResolvedRayAngleOptics {
  tanHalfFovX: number;
  tanHalfFovY: number;
  source: RayAngleOpticsSource;
}

export const RAY_ANGLE_FALLBACK_HFOV_DEG = 65;
export const RAY_ANGLE_FOV_MIN_DEG = 1;
export const RAY_ANGLE_FOV_MAX_DEG = 178;
export const RAY_ANGLE_REFERENCE_TAN_HALF_HFOV = Math.tan(
  (RAY_ANGLE_FALLBACK_HFOV_DEG * Math.PI) / 360,
);
export const DEFAULT_RAY_ANGLE_INNER_THRESHOLD = 0.1;

function finitePositive(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function sourceAspectY(width: number, height: number): number {
  const w = finitePositive(width) ? width : 1;
  const h = finitePositive(height) ? height : w;
  return h / Math.max(w, 1);
}

function tanHalfFovFromDeg(fovDeg: unknown): number | null {
  if (
    typeof fovDeg !== "number" ||
    !Number.isFinite(fovDeg) ||
    fovDeg < RAY_ANGLE_FOV_MIN_DEG ||
    fovDeg > RAY_ANGLE_FOV_MAX_DEG
  ) {
    return null;
  }
  return Math.tan((fovDeg * Math.PI) / 360);
}

function tanHalfFovFromFocalPx(
  focalPx: unknown,
  imageExtentPx: number,
): number | null {
  if (!finitePositive(focalPx) || !finitePositive(imageExtentPx)) {
    return null;
  }
  return (imageExtentPx * 0.5) / focalPx;
}

export function resolveRayAngleOptics(
  optics: CameraOptics | null | undefined,
  imageWidth: number,
  imageHeight: number,
): ResolvedRayAngleOptics {
  const aspectY = sourceAspectY(imageWidth, imageHeight);
  const aspectX = 1 / Math.max(aspectY, 1e-6);
  let tanHalfFovX =
    tanHalfFovFromDeg(optics?.fovXDeg) ??
    tanHalfFovFromFocalPx(optics?.fxPx, imageWidth);
  let tanHalfFovY =
    tanHalfFovFromDeg(optics?.fovYDeg) ??
    tanHalfFovFromFocalPx(optics?.fyPx, imageHeight);

  if (tanHalfFovX === null && tanHalfFovY !== null) {
    tanHalfFovX = tanHalfFovY * aspectX;
  }
  if (tanHalfFovY === null && tanHalfFovX !== null) {
    tanHalfFovY = tanHalfFovX * aspectY;
  }

  if (tanHalfFovX === null || tanHalfFovY === null) {
    return {
      tanHalfFovX: RAY_ANGLE_REFERENCE_TAN_HALF_HFOV,
      tanHalfFovY: RAY_ANGLE_REFERENCE_TAN_HALF_HFOV * aspectY,
      source: "fallback65",
    };
  }

  return {
    tanHalfFovX,
    tanHalfFovY,
    source: optics?.source ?? "assumed",
  };
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function smoothstep(edge0: number, edge1: number, value: number): number {
  const t = clamp01((value - edge0) / Math.max(edge1 - edge0, 1e-6));
  return t * t * (3 - 2 * t);
}

export function rayAngleMaskValue(options: {
  imageUvX: number;
  imageUvY: number;
  imageWidth: number;
  imageHeight: number;
  optics?: CameraOptics | ResolvedRayAngleOptics | null;
  gamma?: number;
  innerThreshold?: number;
}): number {
  const resolved =
    options.optics && "tanHalfFovX" in options.optics
      ? options.optics
      : resolveRayAngleOptics(
          options.optics ?? null,
          options.imageWidth,
          options.imageHeight,
        );
  const sensorX = (options.imageUvX - 0.5) * 2;
  const sensorY = (options.imageUvY - 0.5) * 2;
  const rayX = sensorX * resolved.tanHalfFovX;
  const rayY = sensorY * resolved.tanHalfFovY;
  const viewZ = 1 / Math.sqrt(rayX * rayX + rayY * rayY + 1);
  const incidence = 1 - viewZ;
  const aspectY = sourceAspectY(options.imageWidth, options.imageHeight);
  const referenceRayX = RAY_ANGLE_REFERENCE_TAN_HALF_HFOV;
  const referenceRayY = RAY_ANGLE_REFERENCE_TAN_HALF_HFOV * aspectY;
  const referenceIncidence =
    1 -
    1 /
      Math.sqrt(
        referenceRayX * referenceRayX + referenceRayY * referenceRayY + 1,
      );
  const normalized = clamp01(incidence / Math.max(referenceIncidence, 1e-5));
  const gamma = Math.max(options.gamma ?? 1.4, 0.001);
  const innerThreshold = Math.min(
    0.8,
    Math.max(0, options.innerThreshold ?? DEFAULT_RAY_ANGLE_INNER_THRESHOLD),
  );
  return smoothstep(innerThreshold, 1, Math.pow(normalized, gamma));
}
