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
  color: SourceColorMetadata;
  colorClass: SourceColorClass;
  timing?: SourceVideoTimingMetadata;
};

export type SourceColorMetadata = {
  colorRange: string | null;
  colorSpace: string | null;
  colorTransfer: string | null;
  colorPrimaries: string | null;
  hasMasteringDisplayMetadata: boolean;
  hasContentLightMetadata: boolean;
};

export type SourceColorClass =
  | "sdr-bt709"
  | "hdr-pq"
  | "hdr-hlg"
  | "wide-gamut-unknown"
  | "unknown";

export type HdrPreparationPolicy = {
  strategy: "none" | "prepare-sdr-mezzanine" | "defer-unknown";
  reason:
    | "source-is-sdr-bt709"
    | "source-is-hdr-pq"
    | "source-is-hdr-hlg"
    | "wide-gamut-transfer-unknown"
    | "source-color-unknown";
  requiresFixtureValidation: boolean;
  warning: string | null;
};

export type SourceVideoTimingMetadata = {
  avgFrameRate: string | null;
  rFrameRate: string | null;
  avgFrameRateParsed: number | null;
  rFrameRateParsed: number | null;
  sourceFrameRate: number | null;
  sourceFrameRateTrusted: boolean;
  trustReason:
    | "missing-or-invalid-rate"
    | "rates-diverged"
    | "within-absolute-tolerance"
    | "within-relative-tolerance";
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

function normalizedString(value: unknown): string | null {
  if (typeof value !== "string" && typeof value !== "number") return null;
  const text = String(value).trim().toLowerCase();
  if (
    text.length === 0 ||
    text === "unknown" ||
    text === "unspecified" ||
    text === "reserved"
  ) {
    return null;
  }
  return text;
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

function hasSideDataType(
  stream: FfprobeRecord | undefined,
  sideDataTypes: readonly string[],
): boolean {
  const wanted = new Set(sideDataTypes.map((value) => value.toLowerCase()));
  const sideData = Array.isArray(stream?.side_data_list)
    ? stream.side_data_list
    : [];
  for (const item of sideData) {
    if (!isRecord(item)) continue;
    const sideDataType = normalizedString(item.side_data_type);
    if (sideDataType !== null && wanted.has(sideDataType)) {
      return true;
    }
  }
  return false;
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

export function deriveSourceColorMetadataFromFfprobeStream(
  stream: FfprobeRecord | undefined,
): SourceColorMetadata {
  return {
    colorRange: normalizedString(stream?.color_range),
    colorSpace: normalizedString(stream?.color_space),
    colorTransfer: normalizedString(stream?.color_transfer),
    colorPrimaries: normalizedString(stream?.color_primaries),
    hasMasteringDisplayMetadata: hasSideDataType(stream, [
      "Mastering display metadata",
    ]),
    hasContentLightMetadata: hasSideDataType(stream, [
      "Content light level metadata",
    ]),
  };
}

export function classifySourceColorForExport(
  metadata: SourceColorMetadata,
): SourceColorClass {
  if (metadata.colorTransfer === "smpte2084") {
    return "hdr-pq";
  }
  if (metadata.colorTransfer === "arib-std-b67") {
    return "hdr-hlg";
  }

  const hasBt2020 =
    metadata.colorPrimaries === "bt2020" ||
    metadata.colorSpace === "bt2020" ||
    metadata.colorSpace === "bt2020nc" ||
    metadata.colorSpace === "bt2020c";
  if (
    hasBt2020 ||
    metadata.hasMasteringDisplayMetadata ||
    metadata.hasContentLightMetadata
  ) {
    return "wide-gamut-unknown";
  }

  const isBt709 =
    metadata.colorPrimaries === "bt709" &&
    (metadata.colorSpace === "bt709" || metadata.colorSpace === null) &&
    (metadata.colorTransfer === "bt709" || metadata.colorTransfer === null);
  if (isBt709) {
    return "sdr-bt709";
  }

  return "unknown";
}

export function deriveDesktopHdrPreparationPolicy(
  sourceVideoMetadata: SourceVideoMetadata,
): HdrPreparationPolicy {
  switch (sourceVideoMetadata.colorClass) {
    case "sdr-bt709":
      return {
        strategy: "none",
        reason: "source-is-sdr-bt709",
        requiresFixtureValidation: false,
        warning: null,
      };
    case "hdr-pq":
      return {
        strategy: "prepare-sdr-mezzanine",
        reason: "source-is-hdr-pq",
        requiresFixtureValidation: true,
        warning: null,
      };
    case "hdr-hlg":
      return {
        strategy: "prepare-sdr-mezzanine",
        reason: "source-is-hdr-hlg",
        requiresFixtureValidation: true,
        warning: null,
      };
    case "wide-gamut-unknown":
      return {
        strategy: "defer-unknown",
        reason: "wide-gamut-transfer-unknown",
        requiresFixtureValidation: false,
        warning:
          "Source has wide-gamut or HDR-adjacent metadata without a trusted HDR transfer; leave pixels unchanged until fixture-backed policy exists.",
      };
    case "unknown":
      return {
        strategy: "none",
        reason: "source-color-unknown",
        requiresFixtureValidation: false,
        warning: null,
      };
  }

  const exhaustive: never = sourceVideoMetadata.colorClass;
  return exhaustive;
}
