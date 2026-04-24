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
  hdrPreparationPolicy?: HdrPreparationPolicy;
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
    | "source-color-unknown"
    | "ffmpeg-missing-hdr-filters";
  requiresFixtureValidation: boolean;
  warning: string | null;
  filterSelection?: HdrToSdrFilterSelection | null;
};

export type HdrTonemapEnginePreference =
  | "auto"
  | "zscale-tonemap"
  | "libplacebo";

export type HdrPreparationPolicyOptions = {
  enableHdrTonemap?: boolean;
  enginePreference?: HdrTonemapEnginePreference;
  ffmpegPath?: string | null;
};

type HdrToSdrFilterSelectionBase = {
  chainId:
    | "pq-zscale-hable-npl100"
    | "hlg-zscale-mobius-npl100"
    | "pq-libplacebo-bt2390"
    | "hlg-libplacebo-bt2390";
  enabledByEnv: true;
  ffmpegPath: string | null;
};

export type HdrToSdrFilterSelection =
  | (HdrToSdrFilterSelectionBase & {
      kind: "zscale-tonemap";
      source: "hdr-pq" | "hdr-hlg";
      transferIn: "smpte2084" | "arib-std-b67";
      tonemap: "hable" | "mobius";
      nominalPeakNits: 100;
      desat: 0;
      output: "bt709-sdr";
    })
  | (HdrToSdrFilterSelectionBase & {
      kind: "libplacebo";
      source: "hdr-pq" | "hdr-hlg";
      tonemapping: "bt.2390";
      gamutMode: "perceptual";
      output: "bt709-sdr";
    });

/**
 * @description local ffmpeg ビルドが持つ filter のうち、HDR→SDR 変換に関係するものだけを記録する。
 * 値は ffmpeg-capability-probe.ts が populate する。policy 判定は純粋にこの data を使う。
 */
export type FFmpegHdrCapabilities = {
  hasZscale: boolean;
  hasLibplacebo: boolean;
  hasTonemap: boolean;
  hasColorspace: boolean;
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

/**
 * @description PQ / HLG fixture が揃う前でも、ffmpeg が HDR 変換 filter を持たないビルドなら
 * policy を defer-unknown へ落とし、pixel 変更は一切行わない。
 */
function missingHdrFilterList(capabilities: FFmpegHdrCapabilities): string[] {
  const missing: string[] = [];
  if (!capabilities.hasZscale) missing.push("zscale");
  if (!capabilities.hasTonemap) missing.push("tonemap");
  if (!capabilities.hasLibplacebo) missing.push("libplacebo");
  return missing;
}

function ffmpegCapabilityBlocksHdrPrep(
  capabilities: FFmpegHdrCapabilities | null | undefined,
): boolean {
  if (!capabilities) return false;
  return (
    !(capabilities.hasZscale && capabilities.hasTonemap) &&
    !capabilities.hasLibplacebo
  );
}

function selectHdrToSdrFilter(
  colorClass: Extract<SourceColorClass, "hdr-pq" | "hdr-hlg">,
  capabilities: FFmpegHdrCapabilities | null | undefined,
  options: HdrPreparationPolicyOptions,
): HdrToSdrFilterSelection | null {
  if (options.enableHdrTonemap !== true) {
    return null;
  }
  if (!capabilities || ffmpegCapabilityBlocksHdrPrep(capabilities)) {
    return null;
  }

  const ffmpegPath = options.ffmpegPath ?? null;
  const enginePreference = options.enginePreference ?? "auto";

  const buildZscaleSelection = (): HdrToSdrFilterSelection => ({
    kind: "zscale-tonemap",
    source: colorClass,
    chainId:
      colorClass === "hdr-pq"
        ? "pq-zscale-hable-npl100"
        : "hlg-zscale-mobius-npl100",
    enabledByEnv: true,
    ffmpegPath,
    transferIn: colorClass === "hdr-pq" ? "smpte2084" : "arib-std-b67",
    tonemap: colorClass === "hdr-pq" ? "hable" : "mobius",
    nominalPeakNits: 100,
    desat: 0,
    output: "bt709-sdr",
  });

  const buildLibplaceboSelection = (): HdrToSdrFilterSelection => ({
    kind: "libplacebo",
    source: colorClass,
    chainId:
      colorClass === "hdr-pq"
        ? "pq-libplacebo-bt2390"
        : "hlg-libplacebo-bt2390",
    enabledByEnv: true,
    ffmpegPath,
    tonemapping: "bt.2390",
    gamutMode: "perceptual",
    output: "bt709-sdr",
  });

  if (
    (enginePreference === "auto" || enginePreference === "zscale-tonemap") &&
    capabilities.hasZscale &&
    capabilities.hasTonemap
  ) {
    return buildZscaleSelection();
  }

  if (enginePreference === "libplacebo" && capabilities.hasLibplacebo) {
    return buildLibplaceboSelection();
  }

  return null;
}

export function normalizeHdrToSdrFilterSelection(
  value: unknown,
): HdrToSdrFilterSelection | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }
  const input = value as Record<string, unknown>;
  const common =
    (input.source === "hdr-pq" || input.source === "hdr-hlg") &&
    input.enabledByEnv === true &&
    (input.ffmpegPath === null || typeof input.ffmpegPath === "string") &&
    typeof input.chainId === "string" &&
    input.output === "bt709-sdr";
  if (!common) {
    return null;
  }

  if (input.kind === "zscale-tonemap") {
    const expected =
      input.source === "hdr-pq"
        ? {
            chainId: "pq-zscale-hable-npl100",
            transferIn: "smpte2084",
            tonemap: "hable",
          }
        : {
            chainId: "hlg-zscale-mobius-npl100",
            transferIn: "arib-std-b67",
            tonemap: "mobius",
          };
    if (
      input.chainId === expected.chainId &&
      input.transferIn === expected.transferIn &&
      input.tonemap === expected.tonemap &&
      input.nominalPeakNits === 100 &&
      input.desat === 0
    ) {
      return input as HdrToSdrFilterSelection;
    }
    return null;
  }

  if (input.kind === "libplacebo") {
    const expectedChainId =
      input.source === "hdr-pq"
        ? "pq-libplacebo-bt2390"
        : "hlg-libplacebo-bt2390";
    if (
      input.chainId === expectedChainId &&
      input.tonemapping === "bt.2390" &&
      input.gamutMode === "perceptual"
    ) {
      return input as HdrToSdrFilterSelection;
    }
  }

  return null;
}

export function deriveDesktopHdrPreparationPolicy(
  sourceVideoMetadata: SourceVideoMetadata,
  capabilities?: FFmpegHdrCapabilities | null,
  options: HdrPreparationPolicyOptions = {},
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
      if (ffmpegCapabilityBlocksHdrPrep(capabilities)) {
        return {
          strategy: "defer-unknown",
          reason: "ffmpeg-missing-hdr-filters",
          requiresFixtureValidation: true,
          warning: `Local ffmpeg build lacks HDR transfer filters (${missingHdrFilterList(capabilities!).join(", ")}); leaving HDR PQ source unchanged until a zscale- or libplacebo-capable ffmpeg is available.`,
        };
      }
      {
        const filterSelection = selectHdrToSdrFilter(
          "hdr-pq",
          capabilities,
          options,
        );
        return {
          strategy: "prepare-sdr-mezzanine",
          reason: "source-is-hdr-pq",
          requiresFixtureValidation: true,
          warning: null,
          ...(filterSelection ? { filterSelection } : {}),
        };
      }
    case "hdr-hlg":
      if (ffmpegCapabilityBlocksHdrPrep(capabilities)) {
        return {
          strategy: "defer-unknown",
          reason: "ffmpeg-missing-hdr-filters",
          requiresFixtureValidation: true,
          warning: `Local ffmpeg build lacks HDR transfer filters (${missingHdrFilterList(capabilities!).join(", ")}); leaving HDR HLG source unchanged until a zscale- or libplacebo-capable ffmpeg is available.`,
        };
      }
      {
        const filterSelection = selectHdrToSdrFilter(
          "hdr-hlg",
          capabilities,
          options,
        );
        return {
          strategy: "prepare-sdr-mezzanine",
          reason: "source-is-hdr-hlg",
          requiresFixtureValidation: true,
          warning: null,
          ...(filterSelection ? { filterSelection } : {}),
        };
      }
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
