import path from "node:path";
import type { CameraOptics, CameraOpticsSource } from "film-lab-core";
import type { HdrToSdrFilterSelection } from "./video-export-source-metadata";

const CAMERA_OPTICS_SOURCES = new Set<CameraOpticsSource>([
  "metadata",
  "assumed",
  "manual",
]);

const CAMERA_OPTICS_NUMBER_FIELDS = [
  "fxPx",
  "fyPx",
  "cxPx",
  "cyPx",
  "fovXDeg",
  "fovYDeg",
  "focalLength35mm",
] as const;

const CAMERA_OPTICS_STRING_FIELDS = [
  "lensModel",
  "cameraMake",
  "cameraModel",
] as const;

type CameraOpticsNumberField = (typeof CAMERA_OPTICS_NUMBER_FIELDS)[number];
type CameraOpticsStringField = (typeof CAMERA_OPTICS_STRING_FIELDS)[number];

export type FfmpegRawvideoExportArgsOptions = {
  width: number;
  height: number;
  fps: number;
  hasAudio: boolean;
  inputVideoPath: string;
  outputVideoPath: string;
  dropFirstFrame: boolean;
  cameraOptics?: CameraOptics | null;
  platform?: NodeJS.Platform;
};

/**
 * @description プラットフォーム別のビデオコーデック引数（スループット優先）
 */
export function ffmpegVideoCodecArgs(
  platform: NodeJS.Platform = process.platform,
): string[] {
  if (platform === "darwin") {
    return ["-c:v", "h264_videotoolbox", "-b:v", "12M", "-allow_sw", "1"];
  }
  return ["-c:v", "libx264", "-preset", "veryfast", "-crf", "21"];
}

function finiteNumber(value: unknown): number | undefined {
  return typeof value === "number" && Number.isFinite(value) ? value : undefined;
}

function trimmedString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

export function normalizeCameraOptics(value: unknown): CameraOptics | null {
  if (typeof value !== "object" || value === null) {
    return null;
  }

  const source = (value as { source?: unknown }).source;
  if (typeof source !== "string" || !CAMERA_OPTICS_SOURCES.has(source as CameraOpticsSource)) {
    return null;
  }

  const input = value as Partial<Record<CameraOpticsNumberField | CameraOpticsStringField, unknown>>;
  const normalized: CameraOptics = { source: source as CameraOpticsSource };

  for (const field of CAMERA_OPTICS_NUMBER_FIELDS) {
    const numberValue = finiteNumber(input[field]);
    if (numberValue !== undefined) {
      normalized[field] = numberValue;
    }
  }
  for (const field of CAMERA_OPTICS_STRING_FIELDS) {
    const stringValue = trimmedString(input[field]);
    if (stringValue !== undefined) {
      normalized[field] = stringValue;
    }
  }

  return normalized;
}

function supportsQuickTimeMetadataTags(outputVideoPath: string): boolean {
  const ext = path.extname(outputVideoPath).toLowerCase();
  return ext === ".mp4" || ext === ".m4v" || ext === ".mov";
}

function metadataNumber(value: number | undefined, positive = false): string | null {
  if (value === undefined || !Number.isFinite(value)) {
    return null;
  }
  if (positive && value <= 0) {
    return null;
  }
  return String(Number(value.toFixed(6)));
}

function metadataString(value: string | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed && trimmed.length > 0 ? trimmed : null;
}

export function buildCameraOpticsMetadataArgs(opts: {
  cameraOptics?: CameraOptics | null;
  outputVideoPath: string;
}): string[] {
  if (!supportsQuickTimeMetadataTags(opts.outputVideoPath)) {
    return [];
  }

  const cameraOptics = normalizeCameraOptics(opts.cameraOptics);
  if (!cameraOptics) {
    return [];
  }

  const entries: Array<[string, string]> = [
    ["filmtone.camera_optics.source", cameraOptics.source],
  ];
  const cameraMake = metadataString(cameraOptics.cameraMake);
  if (cameraMake) entries.push(["camera.make", cameraMake]);
  const cameraModel = metadataString(cameraOptics.cameraModel);
  if (cameraModel) entries.push(["camera.model", cameraModel]);
  const lensModel = metadataString(cameraOptics.lensModel);
  if (lensModel) entries.push(["camera.lens_model", lensModel]);
  const focalLength35mm = metadataNumber(cameraOptics.focalLength35mm, true);
  if (focalLength35mm) {
    entries.push(["camera.focal_length.35mm_equivalent", focalLength35mm]);
  }
  const fovXDeg = metadataNumber(cameraOptics.fovXDeg, true);
  if (fovXDeg) {
    entries.push(["camera.horizontal_field_of_view", fovXDeg]);
  }

  return [
    "-movflags",
    "use_metadata_tags",
    ...entries.flatMap(([key, value]) => ["-metadata", `${key}=${value}`]),
  ];
}

export function buildHdrToSdrFilterChain(
  selection: HdrToSdrFilterSelection | null | undefined,
  opts: { scaleWidth?: number } = {},
): string | null {
  if (!selection) {
    return null;
  }

  const scaleWidth =
    typeof opts.scaleWidth === "number" &&
    Number.isFinite(opts.scaleWidth) &&
    opts.scaleWidth > 0
      ? Math.round(opts.scaleWidth)
      : null;
  const outputFilters =
    scaleWidth === null
      ? ["format=yuv420p"]
      : [`scale=${scaleWidth}:-2`, "format=yuv420p"];

  if (selection.kind === "libplacebo") {
    const filter = [
      "libplacebo=colorspace=bt709",
      "color_primaries=bt709",
      "color_trc=bt709",
      "range=tv",
      `tonemapping=${selection.tonemapping}`,
      `gamut_mode=${selection.gamutMode}`,
    ].join(":");
    return [filter, ...outputFilters].join(",");
  }

  return [
    `zscale=tin=${selection.transferIn}:pin=2020:min=2020_ncl:rin=tv:t=linear:npl=${selection.nominalPeakNits}`,
    "format=gbrpf32le",
    "zscale=p=709",
    `tonemap=tonemap=${selection.tonemap}:desat=${selection.desat}`,
    "zscale=t=709:m=709:r=tv",
    ...outputFilters,
  ].join(",");
}

export function buildFfmpegMezzanineVideoFilter(opts: {
  outW: number;
  hdrFilterSelection?: HdrToSdrFilterSelection | null;
}): string {
  const outW =
    Number.isFinite(opts.outW) && opts.outW > 0 ? Math.round(opts.outW) : 1920;
  const hdrFilter = buildHdrToSdrFilterChain(opts.hdrFilterSelection, {
    scaleWidth: outW,
  });
  if (hdrFilter) {
    return hdrFilter;
  }
  return `colorspace=iall=bt709:all=bt709,scale=${outW}:-2,format=yuv420p`;
}

export function buildFfmpegRawvideoExportArgs(
  opts: FfmpegRawvideoExportArgsOptions,
): string[] {
  const {
    width,
    height,
    fps,
    hasAudio,
    inputVideoPath,
    outputVideoPath,
    dropFirstFrame,
    cameraOptics,
    platform,
  } = opts;
  const videoCodec = ffmpegVideoCodecArgs(platform);
  const head: string[] = [
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-f",
    "rawvideo",
    "-pix_fmt",
    "rgba",
    "-s",
    `${width}x${height}`,
    "-r",
    String(fps),
    "-i",
    "pipe:0",
  ];
  if (hasAudio) {
    head.push(
      "-i",
      inputVideoPath,
      "-map",
      "0:v:0",
      "-map",
      "1:a:0",
      "-shortest",
    );
  } else {
    head.push("-an");
  }
  // Color management: WebGL readPixels emits full-range sRGB (0-255) in bottom-up row order.
  // vflip restores top-down order (zero-copy row pointer swap in ffmpeg).
  // scale converts full range to limited range (16-235) for H.264 standard compliance,
  // and BT.709 color metadata tags ensure correct player interpretation.
  // See: .claude/knowledge/patterns/2026-03-03-ffmpeg-encoder-pitfalls-pattern.md §4
  //
  // WebGL raw readback can emit a stale frame 0 on some Metal / ANGLE paths.
  // Keep the drop only for that backend; WebGPU exports should preserve frame 0.
  const colorFilterChain = dropFirstFrame
    ? "vflip,scale=in_range=full:out_range=limited,select=gte(n\\,1),setpts=N/FRAME_RATE/TB"
    : "vflip,scale=in_range=full:out_range=limited";
  head.push(
    "-vf",
    colorFilterChain,
    "-color_range",
    "tv",
    "-colorspace",
    "bt709",
    "-color_trc",
    "bt709",
    "-color_primaries",
    "bt709",
  );
  head.push(...videoCodec);
  if (hasAudio) {
    head.push("-c:a", "copy");
  }
  head.push(
    ...buildCameraOpticsMetadataArgs({
      cameraOptics,
      outputVideoPath,
    }),
  );
  head.push(outputVideoPath);
  return head;
}
