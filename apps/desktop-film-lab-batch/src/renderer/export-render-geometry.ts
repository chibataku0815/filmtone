import {
  sanitizeVideoExportFps,
  VIDEO_EXPORT_MAX_HEIGHT,
  VIDEO_EXPORT_MAX_WIDTH,
} from "./video-export-constants";

export type ExportRenderFitMode = "cover" | "contain";

export type ExportRenderGeometryInput = {
  sourceWidth: number | null | undefined;
  sourceHeight: number | null | undefined;
  sourceDisplayWidth?: number | null | undefined;
  sourceDisplayHeight?: number | null | undefined;
  fps?: number | null | undefined;
  fitMode?: ExportRenderFitMode | null | undefined;
  defaultFitMode?: ExportRenderFitMode | null | undefined;
};

export type ExportRenderGeometry = {
  renderWidth: number;
  renderHeight: number;
  sourceWidth: number;
  sourceHeight: number;
  sourceDisplayWidth: number;
  sourceDisplayHeight: number;
  fitMode: ExportRenderFitMode;
  fps?: number;
};

type DimensionPair = {
  width: number;
  height: number;
};

const FALLBACK_SOURCE_DIMENSIONS: DimensionPair = {
  width: VIDEO_EXPORT_MAX_WIDTH,
  height: VIDEO_EXPORT_MAX_HEIGHT,
};

function sanitizeDimensionPair(
  width: number | null | undefined,
  height: number | null | undefined,
): DimensionPair | null {
  if (
    typeof width !== "number" ||
    typeof height !== "number" ||
    !Number.isFinite(width) ||
    !Number.isFinite(height) ||
    width <= 0 ||
    height <= 0
  ) {
    return null;
  }
  return {
    width: Math.max(1, Math.round(width)),
    height: Math.max(1, Math.round(height)),
  };
}

function computeCappedRenderDimensions(source: DimensionPair): DimensionPair {
  const scale = Math.min(
    VIDEO_EXPORT_MAX_WIDTH / source.width,
    VIDEO_EXPORT_MAX_HEIGHT / source.height,
    1,
  );
  return {
    width: Math.max(1, Math.round(source.width * scale)),
    height: Math.max(1, Math.round(source.height * scale)),
  };
}

function inferFitMode(source: DimensionPair): ExportRenderFitMode {
  return source.height > source.width ? "contain" : "cover";
}

/**
 * Computes the shared preview/export render geometry for a source video.
 *
 * Raw dimensions identify the decoded source, while display dimensions account
 * for rotation / display-matrix metadata and drive the render aspect.
 */
export function computeExportRenderGeometry(
  input: ExportRenderGeometryInput,
): ExportRenderGeometry {
  const rawSource =
    sanitizeDimensionPair(input.sourceWidth, input.sourceHeight) ??
    sanitizeDimensionPair(input.sourceDisplayWidth, input.sourceDisplayHeight) ??
    FALLBACK_SOURCE_DIMENSIONS;
  const displaySource =
    sanitizeDimensionPair(input.sourceDisplayWidth, input.sourceDisplayHeight) ??
    rawSource;
  const render = computeCappedRenderDimensions(displaySource);
  const fps = sanitizeVideoExportFps(input.fps);
  const fitMode =
    input.fitMode ?? input.defaultFitMode ?? inferFitMode(displaySource);
  const geometry: ExportRenderGeometry = {
    renderWidth: render.width,
    renderHeight: render.height,
    sourceWidth: rawSource.width,
    sourceHeight: rawSource.height,
    sourceDisplayWidth: displaySource.width,
    sourceDisplayHeight: displaySource.height,
    fitMode,
  };

  if (fps !== null) {
    geometry.fps = fps;
  }

  return geometry;
}
