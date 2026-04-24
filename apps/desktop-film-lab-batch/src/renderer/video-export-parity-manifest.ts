import type { FilmLabCanvasPreviewFrameCaptureResult } from "film-lab-ui";
import type { ExportRenderGeometry } from "./export-render-geometry";
import type { VideoExportDebugFrameSample } from "./video-export-pipeline";

export type VideoExportParityFrameRef = {
  label: "preview" | "pre-ffmpeg" | "decoded-mp4";
  format: "rgba8" | "png";
  width: number;
  height: number;
  timeSec: number | null;
  checksum: string;
};

export type VideoExportParityDiffMetrics = {
  meanAbs: number;
  p95Abs: number;
  changedRatio: number;
};

export type VideoExportParityManifest = {
  schema: "filmtone-video-export-parity-manifest";
  version: 1;
  createdAtIso: string;
  sourcePath: string;
  outputPath: string | null;
  decodeMode: "webcodecs" | "html-video" | "unknown";
  backendKind: "webgl" | "webgpu" | "unknown";
  renderGeometry: ExportRenderGeometry | null;
  frames: VideoExportParityFrameRef[];
  diffs: Array<{
    a: VideoExportParityFrameRef["label"];
    b: VideoExportParityFrameRef["label"];
    metrics: VideoExportParityDiffMetrics;
  }>;
};

export function checksumBytes(bytes: Uint8Array): string {
  let hash = 0x811c9dc5;
  for (const byte of bytes) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return `fnv1a32:${hash.toString(16).padStart(8, "0")}`;
}

export function diffRgba8(
  a: Uint8Array,
  b: Uint8Array,
): VideoExportParityDiffMetrics {
  if (a.byteLength !== b.byteLength) {
    throw new Error(
      `diffRgba8: byteLength mismatch ${a.byteLength} vs ${b.byteLength}`,
    );
  }
  const rgbDiffs: number[] = [];
  let totalAbs = 0;
  let changedPixels = 0;
  const pixels = Math.max(1, Math.floor(a.byteLength / 4));
  for (let i = 0; i < a.byteLength; i += 4) {
    const dr = Math.abs(a[i]! - b[i]!);
    const dg = Math.abs(a[i + 1]! - b[i + 1]!);
    const db = Math.abs(a[i + 2]! - b[i + 2]!);
    const sum = dr + dg + db;
    totalAbs += sum;
    rgbDiffs.push(dr, dg, db);
    if (sum >= 6) {
      changedPixels++;
    }
  }
  rgbDiffs.sort((x, y) => x - y);
  const p95Index = Math.min(
    rgbDiffs.length - 1,
    Math.max(0, Math.ceil(rgbDiffs.length * 0.95) - 1),
  );
  return {
    meanAbs: totalAbs / Math.max(1, pixels * 3),
    p95Abs: rgbDiffs[p95Index] ?? 0,
    changedRatio: changedPixels / pixels,
  };
}

export function previewCaptureToFrameRef(
  capture: FilmLabCanvasPreviewFrameCaptureResult,
): VideoExportParityFrameRef | null {
  if (!capture.ok) {
    return null;
  }
  const bytes =
    capture.format === "rgba8"
      ? capture.data
      : Uint8Array.from(atob(capture.pngBase64Body), (char) =>
          char.charCodeAt(0),
        );
  return {
    label: "preview",
    format: capture.format,
    width: capture.width,
    height: capture.height,
    timeSec: capture.timeSec,
    checksum: checksumBytes(bytes),
  };
}

export function preFfmpegSampleToFrameRef(
  sample: VideoExportDebugFrameSample,
): VideoExportParityFrameRef {
  return {
    label: "pre-ffmpeg",
    format: "rgba8",
    width: sample.width,
    height: sample.height,
    timeSec: sample.timeSec,
    checksum: checksumBytes(sample.rgba),
  };
}

export function buildVideoExportParityManifest(input: {
  sourcePath: string;
  outputPath?: string | null;
  decodeMode?: VideoExportParityManifest["decodeMode"];
  backendKind?: VideoExportParityManifest["backendKind"];
  renderGeometry?: ExportRenderGeometry | null;
  frames: VideoExportParityFrameRef[];
  diffs?: VideoExportParityManifest["diffs"];
  createdAtIso?: string;
}): VideoExportParityManifest {
  return {
    schema: "filmtone-video-export-parity-manifest",
    version: 1,
    createdAtIso: input.createdAtIso ?? new Date().toISOString(),
    sourcePath: input.sourcePath,
    outputPath: input.outputPath ?? null,
    decodeMode: input.decodeMode ?? "unknown",
    backendKind: input.backendKind ?? "unknown",
    renderGeometry: input.renderGeometry ?? null,
    frames: input.frames,
    diffs: input.diffs ?? [],
  };
}
