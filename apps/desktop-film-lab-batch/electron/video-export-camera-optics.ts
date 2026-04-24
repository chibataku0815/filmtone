/**
 * @fileoverview ffprobe の動画 metadata から、保存済み素材用の仮想カメラ intrinsics を作る。
 */
import type { CameraOptics } from "film-lab-core";

import { deriveVideoDisplayGeometryFromFfprobeStream } from "./video-export-source-metadata";

const ASSUMED_DIAGONAL_FOV_DEG = 70;
const FULL_FRAME_WIDTH_MM = 36;
const FULL_FRAME_HEIGHT_MM = 24;

type FfprobeRecord = Record<string, unknown>;

export type FfprobeCameraOpticsInput = {
  rawWidth: number;
  rawHeight: number;
  stream?: FfprobeRecord;
  format?: FfprobeRecord;
};

function isRecord(value: unknown): value is FfprobeRecord {
  return typeof value === "object" && value !== null;
}

function finitePositive(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? n : null;
}

function finiteNumber(value: unknown): number | null {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

function rationalOrNumberFromString(value: string): number | null {
  const rational = value.trim().match(/^(-?\d+(?:\.\d+)?)\s*\/\s*(-?\d+(?:\.\d+)?)/);
  if (rational) {
    const num = Number(rational[1]);
    const den = Number(rational[2]);
    if (Number.isFinite(num) && Number.isFinite(den) && den !== 0) {
      return num / den;
    }
  }
  const match = value.match(/-?\d+(?:\.\d+)?/);
  return match ? finiteNumber(match[0]) : null;
}

function numberFromTagValue(value: unknown): number | null {
  if (typeof value === "number") return finitePositive(value);
  if (typeof value !== "string") return null;
  return finitePositive(rationalOrNumberFromString(value));
}

function signedNumberFromValue(value: unknown): number | null {
  if (typeof value === "number") return finiteNumber(value);
  if (typeof value !== "string") return null;
  return rationalOrNumberFromString(value);
}

function fovDegFromValue(value: unknown): number | null {
  const raw = signedNumberFromValue(value);
  if (raw === null || raw <= 0) return null;
  const deg = raw > 179 && raw <= 179000 ? raw / 1000 : raw;
  return deg > 0 && deg < 179 ? deg : null;
}

function stringFromTagValue(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function tagsFrom(container: FfprobeRecord | undefined): FfprobeRecord {
  return isRecord(container?.tags) ? container.tags : {};
}

function tagValue(
  streamTags: FfprobeRecord,
  formatTags: FfprobeRecord,
  keys: readonly string[],
): unknown {
  const normalized = new Map<string, unknown>();
  for (const tags of [formatTags, streamTags]) {
    for (const [key, value] of Object.entries(tags)) {
      normalized.set(key.toLowerCase(), value);
    }
  }
  for (const key of keys) {
    const found = normalized.get(key.toLowerCase());
    if (found !== undefined) return found;
  }
  return undefined;
}

function firstTagNumber(
  streamTags: FfprobeRecord,
  formatTags: FfprobeRecord,
  keys: readonly string[],
): number | null {
  return numberFromTagValue(tagValue(streamTags, formatTags, keys));
}

function firstTagString(
  streamTags: FfprobeRecord,
  formatTags: FfprobeRecord,
  keys: readonly string[],
): string | undefined {
  return stringFromTagValue(tagValue(streamTags, formatTags, keys));
}

function firstTagOpticsSource(
  streamTags: FfprobeRecord,
  formatTags: FfprobeRecord,
): CameraOptics["source"] | null {
  const value = firstTagString(streamTags, formatTags, [
    "filmtone.camera_optics.source",
  ]);
  return value === "metadata" || value === "assumed" || value === "manual"
    ? value
    : null;
}

function degToRad(deg: number): number {
  return (deg * Math.PI) / 180;
}

function radToDeg(rad: number): number {
  return (rad * 180) / Math.PI;
}

function fovFromFocalPx(sizePx: number, focalPx: number): number {
  return radToDeg(2 * Math.atan(sizePx / (2 * focalPx)));
}

function focalPxFromFov(sizePx: number, fovDeg: number): number {
  return sizePx / (2 * Math.tan(degToRad(fovDeg) / 2));
}

function diagonalFovFrom35mmFocal(focalLength35mm: number): number {
  const diagMm = Math.hypot(FULL_FRAME_WIDTH_MM, FULL_FRAME_HEIGHT_MM);
  return fovFromFocalPx(diagMm, focalLength35mm);
}

function normalizedKey(key: string): string {
  return key.replace(/[^a-z0-9]/gi, "").toLowerCase();
}

function horizontalFovFromSideData(stream: FfprobeRecord | undefined): number | null {
  const sideData = Array.isArray(stream?.side_data_list)
    ? stream.side_data_list
    : [];
  for (const item of sideData) {
    if (!isRecord(item)) continue;
    for (const [key, value] of Object.entries(item)) {
      const normalized = normalizedKey(key);
      if (normalized !== "horizontalfieldofview" && normalized !== "hfov") {
        continue;
      }
      const fov = fovDegFromValue(value);
      if (fov !== null) return fov;
    }
  }
  return null;
}

function opticsFromDiagonalFov(
  source: CameraOptics["source"],
  width: number,
  height: number,
  diagonalFovDeg: number,
  extra: Omit<CameraOptics, "source" | "fxPx" | "fyPx" | "cxPx" | "cyPx" | "fovXDeg" | "fovYDeg"> = {},
): CameraOptics {
  const focalPx = focalPxFromFov(Math.hypot(width, height), diagonalFovDeg);
  return {
    source,
    fxPx: focalPx,
    fyPx: focalPx,
    cxPx: width / 2,
    cyPx: height / 2,
    fovXDeg: fovFromFocalPx(width, focalPx),
    fovYDeg: fovFromFocalPx(height, focalPx),
    ...extra,
  };
}

function compactOptics(optics: CameraOptics): CameraOptics {
  return Object.fromEntries(
    Object.entries(optics).filter(([, value]) => value !== undefined),
  ) as CameraOptics;
}

export function deriveCameraOpticsFromFfprobeMeta(
  input: FfprobeCameraOpticsInput,
): CameraOptics {
  const rawWidth = finitePositive(input.rawWidth) ?? 1920;
  const rawHeight = finitePositive(input.rawHeight) ?? 1080;
  const streamTags = tagsFrom(input.stream);
  const formatTags = tagsFrom(input.format);
  const display = deriveVideoDisplayGeometryFromFfprobeStream({
    rawWidth,
    rawHeight,
    stream: input.stream,
  });
  const taggedOpticsSource = firstTagOpticsSource(streamTags, formatTags);
  const cameraMake = firstTagString(streamTags, formatTags, [
    "camera.make",
    "com.apple.quicktime.camera.make",
    "com.apple.quicktime.make",
    "make",
    "manufacturer",
  ]);
  const cameraModel = firstTagString(streamTags, formatTags, [
    "camera.model",
    "com.apple.quicktime.camera.model",
    "com.apple.quicktime.model",
    "model",
  ]);
  const lensModel = firstTagString(streamTags, formatTags, [
    "camera.lens_model",
    "com.apple.quicktime.camera.lens_model",
    "lens_model",
    "lens",
  ]);
  const focalLength35mm = firstTagNumber(streamTags, formatTags, [
    "camera.focal_length.35mm_equivalent",
    "com.apple.quicktime.camera.focal_length.35mm_equivalent",
    "focal_length_35mm_equivalent",
    "focal_length_35mm",
    "focallengthin35mmformat",
  ]);
  const fovXDeg =
    horizontalFovFromSideData(input.stream) ??
    fovDegFromValue(
      tagValue(streamTags, formatTags, [
        "camera.horizontal_field_of_view",
        "horizontal_field_of_view",
        "field_of_view",
        "fov",
        "hfov",
      ]),
    );

  const extra = {
    focalLength35mm: focalLength35mm ?? undefined,
    lensModel,
    cameraMake,
    cameraModel,
  };

  if (fovXDeg !== null && fovXDeg > 0 && fovXDeg < 179) {
    const focalPx = focalPxFromFov(display.displayWidth, fovXDeg);
    return compactOptics({
      source: taggedOpticsSource ?? "metadata",
      fxPx: focalPx,
      fyPx: focalPx,
      cxPx: display.displayWidth / 2,
      cyPx: display.displayHeight / 2,
      fovXDeg,
      fovYDeg: fovFromFocalPx(display.displayHeight, focalPx),
      ...extra,
    });
  }

  if (focalLength35mm !== null) {
    return compactOptics(
      opticsFromDiagonalFov(
        taggedOpticsSource ?? "metadata",
        display.displayWidth,
        display.displayHeight,
        diagonalFovFrom35mmFocal(focalLength35mm),
        extra,
      ),
    );
  }

  return compactOptics(
    opticsFromDiagonalFov(
      "assumed",
      display.displayWidth,
      display.displayHeight,
      ASSUMED_DIAGONAL_FOV_DEG,
      extra,
    ),
  );
}
