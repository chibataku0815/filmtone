/**
 * @fileoverview ffprobe の動画 stream metadata から、export 判断に使う source metadata を正規化する。
 */

type FfprobeRecord = Record<string, unknown>;

export type SourceDisplayGeometry = {
  rawWidth: number;
  rawHeight: number;
  displayWidth: number;
  displayHeight: number;
  rotationDeg: 0 | 90 | 180 | 270 | null;
  source: "ffprobe-side-data" | "ffprobe-tags" | "raw";
};

export type SourceVideoMetadata = {
  display: SourceDisplayGeometry;
};

export type FfprobeDisplayGeometryInput = {
  rawWidth: number;
  rawHeight: number;
  stream?: FfprobeRecord;
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
  const rational = value
    .trim()
    .match(/^(-?\d+(?:\.\d+)?)\s*\/\s*(-?\d+(?:\.\d+)?)/);
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

function signedNumberFromValue(value: unknown): number | null {
  if (typeof value === "number") return finiteNumber(value);
  if (typeof value !== "string") return null;
  return rationalOrNumberFromString(value);
}

function normalizeRotationDeg(value: unknown): 0 | 90 | 180 | 270 | null {
  const raw = signedNumberFromValue(value);
  if (raw === null) return null;
  const normalized = ((Math.round(raw / 90) * 90) % 360 + 360) % 360;
  if (
    normalized === 0 ||
    normalized === 90 ||
    normalized === 180 ||
    normalized === 270
  ) {
    return normalized;
  }
  return null;
}

function tagsFrom(container: FfprobeRecord | undefined): FfprobeRecord {
  return isRecord(container?.tags) ? container.tags : {};
}

function displayDimensions(
  rawWidth: number,
  rawHeight: number,
  rotationDeg: SourceDisplayGeometry["rotationDeg"],
): { width: number; height: number } {
  if (rotationDeg === 90 || rotationDeg === 270) {
    return { width: rawHeight, height: rawWidth };
  }
  return { width: rawWidth, height: rawHeight };
}

function rotationFromSideData(
  stream: FfprobeRecord | undefined,
): SourceDisplayGeometry["rotationDeg"] | null {
  const sideData = Array.isArray(stream?.side_data_list)
    ? stream.side_data_list
    : [];
  for (const item of sideData) {
    if (!isRecord(item)) continue;
    if (item.side_data_type !== "Display Matrix") continue;
    const rotation = normalizeRotationDeg(item.rotation);
    if (rotation !== null) return rotation;
  }
  return null;
}

function rotationFromTags(
  stream: FfprobeRecord | undefined,
): SourceDisplayGeometry["rotationDeg"] | null {
  const tags = tagsFrom(stream);
  for (const key of ["rotate", "rotation"]) {
    const rotation = normalizeRotationDeg(tags[key]);
    if (rotation !== null) return rotation;
  }
  for (const key of ["rotate", "rotation"]) {
    const rotation = normalizeRotationDeg(stream?.[key]);
    if (rotation !== null) return rotation;
  }
  return null;
}

export function deriveVideoDisplayGeometryFromFfprobeStream(
  input: FfprobeDisplayGeometryInput,
): SourceDisplayGeometry {
  const rawWidth = finitePositive(input.rawWidth) ?? 1920;
  const rawHeight = finitePositive(input.rawHeight) ?? 1080;
  const sideDataRotation = rotationFromSideData(input.stream);
  const tagRotation =
    sideDataRotation === null ? rotationFromTags(input.stream) : null;
  const rotationDeg = sideDataRotation ?? tagRotation;
  const source =
    sideDataRotation !== null
      ? "ffprobe-side-data"
      : tagRotation !== null
        ? "ffprobe-tags"
        : "raw";
  const display = displayDimensions(rawWidth, rawHeight, rotationDeg);
  return {
    rawWidth,
    rawHeight,
    displayWidth: display.width,
    displayHeight: display.height,
    rotationDeg,
    source,
  };
}

