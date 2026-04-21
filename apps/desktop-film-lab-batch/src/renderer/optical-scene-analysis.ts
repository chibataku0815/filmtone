import {
  recommendOpticalFinish,
  type OpticalAnalyzerProvider,
  type OpticalRecommendationV1,
  type SceneAnalysisState,
  type SceneDescriptorV1,
} from "film-lab-core";
import { absolutePathToVideoSrcUrl } from "../../electron/video-src-protocol";

export const OPTICAL_ANALYZER_VERSION = "scene-aware-v1";

const MAX_ANALYSIS_FRAMES = 12;
const MAX_ANALYSIS_EDGE = 256;
const SHOT_BOUNDARY_THRESHOLD = 0.26;
const HIDDEN_VIDEO_LOAD_TIMEOUT_MS = 6000;
const REQUEST_VIDEO_FRAME_TIMEOUT_MS = 200;

type SceneAnalysisCacheKeyInput = {
  sourcePath: string;
  trimStartSec: number;
  trimEndSec: number;
  sourceDurationSec: number;
  analyzerVersion?: string;
};

type AnalyzerInput = Parameters<OpticalAnalyzerProvider["analyze"]>[0];

export type DesktopSceneAnalysisProgress = {
  stage:
    | "resolve-source"
    | "load-video"
    | "metadata-ready"
    | "sample-frame"
    | "face-detect"
    | "recommend"
    | "complete"
    | "cache-hit";
  message: string;
  cacheKey: string;
  sourcePath: string;
  sourceUrl: string;
  sourceUrlKind: "video-src" | "provided-url" | "source-path";
  frameIndex?: number;
  frameCount?: number;
  timeSec?: number;
};

type Histogram = Float32Array;

type FrameSummary = {
  timeSec: number;
  medianLuma: number;
  highlightCoverage: number;
  specularIslands: number;
  pointLightScore: number;
  globalContrast: number;
  warmthScore: number;
  portraitFallback: number;
  nightScore: number;
  sceneComplexity: number;
  edgeDensity: number;
  hsvHistogram: Histogram;
};

export type SampledAnalyzerFrame = {
  index: number;
  timeSec: number;
  jpegDataUrl: string;
};

export type DesktopSceneAnalysisResult = {
  state: SceneAnalysisState;
  descriptor: SceneDescriptorV1 | null;
  recommendation: OpticalRecommendationV1 | null;
  analyzerVersion: string;
  cacheKey: string;
  errorMessage?: string;
  sampledFrames?: SampledAnalyzerFrame[];
};

export type DesktopSceneAnalysisOptions = {
  captureFrameJpegs?: boolean;
};

type DesktopSceneAnalysisProgressListener = (
  progress: DesktopSceneAnalysisProgress,
) => void;

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  if (value <= 0) return 0;
  if (value >= 1) return 1;
  return value;
}

function formatKeyNumber(value: number): string {
  if (!Number.isFinite(value)) return "0.000";
  return value.toFixed(3);
}

export function createSceneAnalysisCacheKey(
  input: SceneAnalysisCacheKeyInput,
): string {
  const analyzerVersion = input.analyzerVersion ?? OPTICAL_ANALYZER_VERSION;
  return [
    input.sourcePath,
    formatKeyNumber(input.trimStartSec),
    formatKeyNumber(input.trimEndSec),
    formatKeyNumber(input.sourceDurationSec),
    analyzerVersion,
  ].join("::");
}

function isLikelyAbsoluteFilePath(value: string): boolean {
  return value.startsWith("/") || /^[A-Za-z]:[\\/]/.test(value);
}

export function resolveSceneAnalysisSourceUrl(input: AnalyzerInput): {
  sourceUrl: string;
  sourceUrlKind: "video-src" | "provided-url" | "source-path";
} {
  // Prefer an already-playing `film-lab-video://` URL (mezzanine served by the
  // main process). The raw source path can be a codec HTMLVideoElement cannot
  // decode (ProRes, DNxHD, 10-bit 4K H.265, etc.); the preview already proved
  // this URL works, so reuse it for hidden analysis.
  if (
    typeof input.sourceUrl === "string" &&
    input.sourceUrl.startsWith("film-lab-video://")
  ) {
    return {
      sourceUrl: input.sourceUrl,
      sourceUrlKind: "provided-url",
    };
  }
  if (isLikelyAbsoluteFilePath(input.sourcePath)) {
    return {
      sourceUrl: absolutePathToVideoSrcUrl(input.sourcePath),
      sourceUrlKind: "video-src",
    };
  }
  if (typeof input.sourceUrl === "string" && input.sourceUrl.length > 0) {
    return {
      sourceUrl: input.sourceUrl,
      sourceUrlKind: "provided-url",
    };
  }
  return {
    sourceUrl: input.sourcePath,
    sourceUrlKind: "source-path",
  };
}

function emitSceneAnalysisProgress(
  listener: DesktopSceneAnalysisProgressListener | undefined,
  progress: DesktopSceneAnalysisProgress,
): void {
  console.info("[optical-analysis]", progress.message, {
    stage: progress.stage,
    cacheKey: progress.cacheKey,
    sourcePath: progress.sourcePath,
    sourceUrlKind: progress.sourceUrlKind,
    frameIndex: progress.frameIndex,
    frameCount: progress.frameCount,
    timeSec: progress.timeSec,
  });
  listener?.(progress);
}

export function buildAnalysisSampleTimes(
  trimStartSec: number,
  trimEndSec: number,
): number[] {
  const start = Math.max(0, trimStartSec);
  const end = Math.max(start, trimEndSec);
  const span = end - start;
  if (span <= 0.001) {
    return [start];
  }

  const positions: number[] = [0];
  for (let index = 1; index < MAX_ANALYSIS_FRAMES - 1; index += 1) {
    positions.push(index / (MAX_ANALYSIS_FRAMES - 1));
  }
  positions.push(1);

  let closestToMiddleIndex = 0;
  let closestToMiddleDistance = Number.POSITIVE_INFINITY;
  for (let index = 1; index < positions.length - 1; index += 1) {
    const distance = Math.abs(positions[index] - 0.5);
    if (distance < closestToMiddleDistance) {
      closestToMiddleDistance = distance;
      closestToMiddleIndex = index;
    }
  }
  positions[closestToMiddleIndex] = 0.5;

  return Array.from(
    new Set(
      positions.map((position) =>
        Number((start + span * position).toFixed(3)),
      ),
    ),
  ).sort((left, right) => left - right);
}

function percentileFromHistogram(histogram: Uint32Array, percentile: number): number {
  const total = histogram.reduce((sum, value) => sum + value, 0);
  if (total <= 0) return 0;
  const target = total * clamp01(percentile);
  let cumulative = 0;
  for (let index = 0; index < histogram.length; index += 1) {
    cumulative += histogram[index] ?? 0;
    if (cumulative >= target) {
      return index / (histogram.length - 1);
    }
  }
  return 1;
}

function normalizedEntropy(histogram: Histogram): number {
  let entropy = 0;
  let total = 0;
  for (let index = 0; index < histogram.length; index += 1) {
    total += histogram[index] ?? 0;
  }
  if (total <= 0) return 0;
  for (let index = 0; index < histogram.length; index += 1) {
    const probability = (histogram[index] ?? 0) / total;
    if (probability <= 0) continue;
    entropy -= probability * Math.log2(probability);
  }
  const maxEntropy = Math.log2(histogram.length);
  return maxEntropy > 0 ? clamp01(entropy / maxEntropy) : 0;
}

function hsvFromRgb(r: number, g: number, b: number): [number, number, number] {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  let hue = 0;
  if (delta > 0) {
    if (max === r) {
      hue = ((g - b) / delta) % 6;
    } else if (max === g) {
      hue = (b - r) / delta + 2;
    } else {
      hue = (r - g) / delta + 4;
    }
    hue *= 60;
    if (hue < 0) hue += 360;
  }
  const saturation = max <= 0 ? 0 : delta / max;
  return [hue, saturation, max];
}

function computeHistogramDelta(left: Histogram, right: Histogram): number {
  const length = Math.min(left.length, right.length);
  let delta = 0;
  for (let index = 0; index < length; index += 1) {
    delta += Math.abs((left[index] ?? 0) - (right[index] ?? 0));
  }
  return clamp01(delta * 0.5);
}

function dominantShotCoverage(frames: FrameSummary[]): {
  coverage: number;
  dominantIndices: number[];
} {
  if (frames.length <= 1) {
    return {
      coverage: 1,
      dominantIndices: frames.length === 0 ? [] : [0],
    };
  }

  const boundaries = new Set<number>();
  for (let index = 1; index < frames.length; index += 1) {
    const previous = frames[index - 1];
    const current = frames[index];
    const histogramDelta = computeHistogramDelta(
      previous.hsvHistogram,
      current.hsvHistogram,
    );
    const edgeDelta = Math.abs(previous.edgeDensity - current.edgeDensity);
    const delta = histogramDelta + edgeDelta;
    if (delta >= SHOT_BOUNDARY_THRESHOLD) {
      boundaries.add(index);
    }
  }

  let bestStart = 0;
  let bestEnd = 0;
  let currentStart = 0;
  for (let index = 1; index <= frames.length; index += 1) {
    const isBoundary = index === frames.length || boundaries.has(index);
    if (!isBoundary) continue;
    if (index - currentStart > bestEnd - bestStart) {
      bestStart = currentStart;
      bestEnd = index;
    }
    currentStart = index;
  }

  const dominantIndices: number[] = [];
  for (let index = bestStart; index < bestEnd; index += 1) {
    dominantIndices.push(index);
  }

  return {
    coverage:
      frames.length > 0 ? dominantIndices.length / frames.length : 0,
    dominantIndices,
  };
}

function aggregateDescriptor(
  frames: FrameSummary[],
  dominantIndices: number[],
  dominantCoverage: number,
  faceBoost: number,
): SceneDescriptorV1 {
  const indices = dominantIndices.length > 0
    ? dominantIndices
    : frames.map((_, index) => index);
  const totals = {
    medianLuma: 0,
    highlightCoverage: 0,
    specularIslands: 0,
    pointLightScore: 0,
    globalContrast: 0,
    warmthScore: 0,
    portraitFallback: 0,
    nightScore: 0,
    sceneComplexity: 0,
  };
  for (const index of indices) {
    const frame = frames[index];
    totals.medianLuma += frame.medianLuma;
    totals.highlightCoverage += frame.highlightCoverage;
    totals.specularIslands += frame.specularIslands;
    totals.pointLightScore += frame.pointLightScore;
    totals.globalContrast += frame.globalContrast;
    totals.warmthScore += frame.warmthScore;
    totals.portraitFallback += frame.portraitFallback;
    totals.nightScore += frame.nightScore;
    totals.sceneComplexity += frame.sceneComplexity;
  }

  const count = Math.max(1, indices.length);
  const portraitFallback = totals.portraitFallback / count;
  return {
    medianLuma: clamp01(totals.medianLuma / count),
    highlightCoverage: clamp01(totals.highlightCoverage / count),
    specularIslands: clamp01(totals.specularIslands / count),
    pointLightScore: clamp01(totals.pointLightScore / count),
    globalContrast: clamp01(totals.globalContrast / count),
    warmthScore: clamp01(totals.warmthScore / count),
    portraitLikelihood: clamp01(portraitFallback * 0.72 + faceBoost * 0.28),
    nightScore: clamp01(totals.nightScore / count),
    sceneComplexity: clamp01(totals.sceneComplexity / count),
    dominantShotCoverage: clamp01(dominantCoverage),
    sampleCount: frames.length,
  };
}

function ensureDocumentCanvas(): HTMLCanvasElement {
  if (typeof document === "undefined") {
    throw new Error("Scene analysis requires a browser document.");
  }
  return document.createElement("canvas");
}

function createCanvasPair(): {
  canvas: HTMLCanvasElement;
  context: CanvasRenderingContext2D;
} {
  const canvas = ensureDocumentCanvas();
  const context = canvas.getContext("2d", {
    willReadFrequently: true,
    alpha: false,
  });
  if (!context) {
    throw new Error("Failed to acquire 2D context for scene analysis.");
  }
  return { canvas, context };
}

function scaledFrameSize(
  width: number,
  height: number,
): { width: number; height: number } {
  const longEdge = Math.max(width, height);
  if (!Number.isFinite(width) || !Number.isFinite(height) || longEdge <= 0) {
    return { width: 1, height: 1 };
  }
  const scale = Math.min(1, MAX_ANALYSIS_EDGE / longEdge);
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

function analyzeCanvasFrame(
  canvas: HTMLCanvasElement,
  context: CanvasRenderingContext2D,
  timeSec: number,
): FrameSummary {
  const { width, height } = canvas;
  const imageData = context.getImageData(0, 0, width, height);
  const rgba = imageData.data;
  const totalPixels = Math.max(1, width * height);
  const lumaValues = new Float32Array(totalPixels);
  const lumaHistogram = new Uint32Array(256);
  const hsvHistogram = new Float32Array(108);
  const hotspotGrid = new Uint16Array(64);
  const gridWidth = 8;
  const gridHeight = 8;

  let highlightPixels = 0;
  let darkPixels = 0;
  let warmMass = 0;
  let colorMass = 0;
  let skinPixels = 0;
  let skinCentralPixels = 0;
  let centralPixels = 0;

  for (let pixelIndex = 0; pixelIndex < totalPixels; pixelIndex += 1) {
    const rgbaIndex = pixelIndex * 4;
    const r = (rgba[rgbaIndex] ?? 0) / 255;
    const g = (rgba[rgbaIndex + 1] ?? 0) / 255;
    const b = (rgba[rgbaIndex + 2] ?? 0) / 255;
    const luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    lumaValues[pixelIndex] = luma;
    lumaHistogram[Math.min(255, Math.max(0, Math.round(luma * 255)))] += 1;

    const [hue, saturation, value] = hsvFromRgb(r, g, b);
    const hueBin = Math.min(11, Math.floor(hue / 30));
    const saturationBin = Math.min(2, Math.floor(saturation * 3));
    const valueBin = Math.min(2, Math.floor(value * 3));
    hsvHistogram[hueBin * 9 + saturationBin * 3 + valueBin] += 1;

    if (luma >= 0.82) highlightPixels += 1;
    if (luma <= 0.24) darkPixels += 1;
    if (hue >= 12 && hue <= 68 && saturation >= 0.18 && value >= 0.18) {
      warmMass += saturation * value;
    }
    colorMass += saturation * value;

    const x = pixelIndex % width;
    const y = Math.floor(pixelIndex / width);
    const normalizedX = width > 1 ? x / (width - 1) : 0.5;
    const normalizedY = height > 1 ? y / (height - 1) : 0.5;
    const centeredX = Math.abs(normalizedX - 0.5);
    const centeredY = Math.abs(normalizedY - 0.5);
    const isCentral = centeredX <= 0.26 && centeredY <= 0.26;
    if (isCentral) {
      centralPixels += 1;
    }

    const maxChannel = Math.max(r, g, b);
    const minChannel = Math.min(r, g, b);
    const chroma = maxChannel - minChannel;
    const looksLikeSkin =
      r > 0.28 &&
      g > 0.18 &&
      b > 0.08 &&
      r > g &&
      g > b * 0.85 &&
      chroma > 0.06 &&
      hue >= 5 &&
      hue <= 55;
    if (looksLikeSkin) {
      skinPixels += 1;
      if (isCentral) {
        skinCentralPixels += 1;
      }
    }

    if (luma >= 0.88 && saturation <= 0.55) {
      const gridX = Math.min(gridWidth - 1, Math.floor((x / width) * gridWidth));
      const gridY = Math.min(
        gridHeight - 1,
        Math.floor((y / height) * gridHeight),
      );
      hotspotGrid[gridY * gridWidth + gridX] += 1;
    }
  }

  let edgePixels = 0;
  const edgeThreshold = 0.1;
  for (let y = 0; y < height - 1; y += 1) {
    for (let x = 0; x < width - 1; x += 1) {
      const index = y * width + x;
      const luma = lumaValues[index] ?? 0;
      const right = lumaValues[index + 1] ?? 0;
      const down = lumaValues[index + width] ?? 0;
      if (
        Math.abs(luma - right) >= edgeThreshold ||
        Math.abs(luma - down) >= edgeThreshold
      ) {
        edgePixels += 1;
      }
    }
  }

  const edgeDensity = clamp01(
    edgePixels / Math.max(1, (width - 1) * (height - 1)),
  );
  const highlightCoverage = clamp01(highlightPixels / totalPixels);
  const darkCoverage = clamp01(darkPixels / totalPixels);
  const p10 = percentileFromHistogram(lumaHistogram, 0.1);
  const medianLuma = percentileFromHistogram(lumaHistogram, 0.5);
  const p90 = percentileFromHistogram(lumaHistogram, 0.9);
  const globalContrast = clamp01((p90 - p10) / 0.85);

  let hotspotCells = 0;
  const cellPixelCount = totalPixels / hotspotGrid.length;
  for (let index = 0; index < hotspotGrid.length; index += 1) {
    const coverage = (hotspotGrid[index] ?? 0) / Math.max(1, cellPixelCount);
    if (coverage >= 0.015) {
      hotspotCells += 1;
    }
  }
  const specularIslands = clamp01(hotspotCells / 10);
  const pointLightScore = clamp01(
    clamp01((0.18 - highlightCoverage) / 0.18) * 0.42 +
      specularIslands * 0.34 +
      clamp01((0.52 - medianLuma) / 0.52) * 0.24,
  );

  const skinShare = clamp01(skinPixels / totalPixels);
  const skinCentralShare =
    centralPixels > 0 ? clamp01(skinCentralPixels / centralPixels) : 0;
  const skinConcentration =
    skinPixels > 0 ? clamp01(skinCentralPixels / skinPixels) : 0;
  const portraitFallback = clamp01(
    skinShare * 4.5 + skinCentralShare * 0.38 + skinConcentration * 0.22,
  );

  const warmthScore =
    colorMass > 0 ? clamp01(warmMass / colorMass) : 0;
  const colorEntropy = normalizedEntropy(hsvHistogram);
  const sceneComplexity = clamp01(edgeDensity * 0.62 + colorEntropy * 0.38);
  const nightScore = clamp01(
    darkCoverage * 0.55 +
      pointLightScore * 0.2 +
      globalContrast * 0.1 +
      clamp01((0.5 - medianLuma) / 0.5) * 0.15,
  );

  const histogramTotal = hsvHistogram.reduce((sum, value) => sum + value, 0) || 1;
  for (let index = 0; index < hsvHistogram.length; index += 1) {
    hsvHistogram[index] = (hsvHistogram[index] ?? 0) / histogramTotal;
  }

  return {
    timeSec,
    medianLuma,
    highlightCoverage,
    specularIslands,
    pointLightScore,
    globalContrast,
    warmthScore,
    portraitFallback,
    nightScore,
    sceneComplexity,
    edgeDensity,
    hsvHistogram,
  };
}

function loadHiddenVideo(sourceUrl: string): Promise<HTMLVideoElement> {
  if (typeof document === "undefined") {
    return Promise.reject(
      new Error("Scene analysis requires a browser document."),
    );
  }
  return new Promise((resolve, reject) => {
    const video = document.createElement("video");
    let settled = false;
    const timeoutId = globalThis.setTimeout(() => {
      fail(
        new Error(
          `Timed out while loading video metadata for scene analysis: ${sourceUrl}`,
        ),
      );
    }, HIDDEN_VIDEO_LOAD_TIMEOUT_MS);
    const cleanup = () => {
      globalThis.clearTimeout(timeoutId);
      video.removeEventListener("loadedmetadata", handleLoadedMetadata);
      video.removeEventListener("error", handleError);
    };
    const finish = (value: HTMLVideoElement) => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve(value);
    };
    const fail = (reason: unknown) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(
        reason instanceof Error
          ? reason
          : new Error("Failed to load video for scene analysis."),
      );
    };
    const handleLoadedMetadata = () => finish(video);
    const handleError = () => {
      fail(
        new Error(
          `Failed to load video for scene analysis: ${sourceUrl}`,
        ),
      );
    };

    video.muted = true;
    video.preload = "auto";
    video.playsInline = true;
    video.crossOrigin = "anonymous";
    video.addEventListener("loadedmetadata", handleLoadedMetadata, {
      once: true,
    });
    video.addEventListener("error", handleError, { once: true });
    video.src = sourceUrl;
    video.load();
  });
}

function releaseVideo(video: HTMLVideoElement): void {
  video.pause();
  video.removeAttribute("src");
  video.load();
}

async function waitForVideoFrameReady(video: HTMLVideoElement): Promise<void> {
  const frameApi = video as HTMLVideoElement & {
    requestVideoFrameCallback?: (callback: () => void) => number;
    cancelVideoFrameCallback?: (handle: number) => void;
  };
  if (typeof frameApi.requestVideoFrameCallback !== "function") {
    return;
  }
  await new Promise<void>((resolve) => {
    let settled = false;
    let callbackHandle: number | null = null;
    const finish = () => {
      if (settled) return;
      settled = true;
      globalThis.clearTimeout(timeoutId);
      if (
        callbackHandle != null &&
        typeof frameApi.cancelVideoFrameCallback === "function"
      ) {
        frameApi.cancelVideoFrameCallback.call(video, callbackHandle);
      }
      resolve();
    };
    const timeoutId = globalThis.setTimeout(
      finish,
      REQUEST_VIDEO_FRAME_TIMEOUT_MS,
    );
    callbackHandle = frameApi.requestVideoFrameCallback.call(video, finish);
  });
}

function seekVideo(video: HTMLVideoElement, timeSec: number): Promise<void> {
  return new Promise((resolve, reject) => {
    let settled = false;
    const cleanup = () => {
      video.removeEventListener("seeked", handleSeeked);
      video.removeEventListener("error", handleError);
    };
    const finish = () => {
      if (settled) return;
      settled = true;
      cleanup();
      resolve();
    };
    const fail = (reason: unknown) => {
      if (settled) return;
      settled = true;
      cleanup();
      reject(
        reason instanceof Error
          ? reason
          : new Error("Video seek failed during scene analysis."),
      );
    };
    const handleSeeked = async () => {
      try {
        await waitForVideoFrameReady(video);
        finish();
      } catch (error) {
        fail(error);
      }
    };
    const handleError = () => fail(new Error("Video error during scene analysis."));

    const duration = Number.isFinite(video.duration) ? video.duration : timeSec;
    const clampedTime = Math.max(0, Math.min(timeSec, Math.max(0, duration - 0.001)));
    if (Math.abs(video.currentTime - clampedTime) <= 0.001 && video.readyState >= 2) {
      void handleSeeked();
      return;
    }
    video.addEventListener("seeked", handleSeeked, { once: true });
    video.addEventListener("error", handleError, { once: true });
    video.currentTime = clampedTime;
  });
}

async function drawVideoFrame(
  video: HTMLVideoElement,
  timeSec: number,
  canvas: HTMLCanvasElement,
  context: CanvasRenderingContext2D,
): Promise<void> {
  await seekVideo(video, timeSec);
  const size = scaledFrameSize(video.videoWidth, video.videoHeight);
  canvas.width = size.width;
  canvas.height = size.height;
  context.clearRect(0, 0, canvas.width, canvas.height);
  context.drawImage(video, 0, 0, canvas.width, canvas.height);
}

async function detectFaceBoost(
  canvas: HTMLCanvasElement,
): Promise<number> {
  const faceDetectorCtor = (
    globalThis as typeof globalThis & {
      FaceDetector?: new (...args: unknown[]) => {
        detect: (
          input: HTMLCanvasElement,
        ) => Promise<Array<{ boundingBox?: { width?: number; height?: number } }>>;
      };
    }
  ).FaceDetector;
  if (typeof faceDetectorCtor !== "function") {
    return 0;
  }
  try {
    const detector = new faceDetectorCtor();
    const faces = await detector.detect(canvas);
    if (!Array.isArray(faces) || faces.length === 0) {
      return 0;
    }
    const canvasArea = Math.max(1, canvas.width * canvas.height);
    const largestFaceArea = faces.reduce((largest, face) => {
      const width = face.boundingBox?.width ?? 0;
      const height = face.boundingBox?.height ?? 0;
      return Math.max(largest, width * height);
    }, 0);
    return clamp01(faces.length * 0.18 + (largestFaceArea / canvasArea) * 2.8);
  } catch {
    return 0;
  }
}

async function analyzeSource(
  input: AnalyzerInput,
  onProgress?: DesktopSceneAnalysisProgressListener,
  options?: DesktopSceneAnalysisOptions,
): Promise<DesktopSceneAnalysisResult> {
  const trimStartSec = Math.max(0, input.trimStartSec);
  const trimEndSec = Math.max(trimStartSec, input.trimEndSec);
  const sourceDurationSec = Math.max(trimEndSec, input.sourceDurationSec);
  const cacheKey = createSceneAnalysisCacheKey({
    sourcePath: input.sourcePath,
    trimStartSec,
    trimEndSec,
    sourceDurationSec,
  });

  const { sourceUrl, sourceUrlKind } = resolveSceneAnalysisSourceUrl(input);
  emitSceneAnalysisProgress(onProgress, {
    stage: "resolve-source",
    message:
      sourceUrlKind === "video-src"
        ? "absolute file path resolved for hidden analyzer"
        : "using current preview URL for hidden analyzer",
    cacheKey,
    sourcePath: input.sourcePath,
    sourceUrl,
    sourceUrlKind,
  });

  emitSceneAnalysisProgress(onProgress, {
    stage: "load-video",
    message: "loading hidden video for scene analysis",
    cacheKey,
    sourcePath: input.sourcePath,
    sourceUrl,
    sourceUrlKind,
  });
  const video = await loadHiddenVideo(sourceUrl);
  emitSceneAnalysisProgress(onProgress, {
    stage: "metadata-ready",
    message: "hidden video metadata ready",
    cacheKey,
    sourcePath: input.sourcePath,
    sourceUrl,
    sourceUrlKind,
  });
  const { canvas, context } = createCanvasPair();
  try {
    const effectiveDuration =
      Number.isFinite(video.duration) && video.duration > 0
        ? video.duration
        : sourceDurationSec;
    const effectiveTrimEnd =
      trimEndSec > trimStartSec ? trimEndSec : effectiveDuration;
    const sampleTimes = buildAnalysisSampleTimes(
      trimStartSec,
      effectiveTrimEnd,
    );
    const frames: FrameSummary[] = [];
    const captureFrameJpegs = options?.captureFrameJpegs === true;
    const sampledFrames: SampledAnalyzerFrame[] | undefined = captureFrameJpegs
      ? []
      : undefined;

    for (const [index, timeSec] of sampleTimes.entries()) {
      emitSceneAnalysisProgress(onProgress, {
        stage: "sample-frame",
        message: `sampling frame ${index + 1}/${sampleTimes.length}`,
        cacheKey,
        sourcePath: input.sourcePath,
        sourceUrl,
        sourceUrlKind,
        frameIndex: index + 1,
        frameCount: sampleTimes.length,
        timeSec,
      });
      await drawVideoFrame(video, timeSec, canvas, context);
      if (sampledFrames) {
        sampledFrames.push({
          index,
          timeSec,
          jpegDataUrl: canvas.toDataURL("image/jpeg", 0.75),
        });
      }
      frames.push(analyzeCanvasFrame(canvas, context, timeSec));
    }

    const dominantShot = dominantShotCoverage(frames);
    const representativeIndex =
      dominantShot.dominantIndices[
        Math.floor(dominantShot.dominantIndices.length / 2)
      ] ?? Math.floor(frames.length / 2);
    const representativeTime =
      frames[representativeIndex]?.timeSec ?? sampleTimes[Math.floor(sampleTimes.length / 2)] ?? 0;

    emitSceneAnalysisProgress(onProgress, {
      stage: "face-detect",
      message: "sampling representative frame for face assist",
      cacheKey,
      sourcePath: input.sourcePath,
      sourceUrl,
      sourceUrlKind,
      timeSec: representativeTime,
    });
    await drawVideoFrame(video, representativeTime, canvas, context);
    const faceBoost = await detectFaceBoost(canvas);

    const descriptor = aggregateDescriptor(
      frames,
      dominantShot.dominantIndices,
      dominantShot.coverage,
      faceBoost,
    );
    const recommendation = recommendOpticalFinish(descriptor);

    emitSceneAnalysisProgress(onProgress, {
      stage: "recommend",
      message: "building optical recommendation",
      cacheKey,
      sourcePath: input.sourcePath,
      sourceUrl,
      sourceUrlKind,
    });

    emitSceneAnalysisProgress(onProgress, {
      stage: "complete",
      message: `analysis complete: ${recommendation.state}`,
      cacheKey,
      sourcePath: input.sourcePath,
      sourceUrl,
      sourceUrlKind,
      frameCount: sampleTimes.length,
    });

    return {
      state: recommendation.state,
      descriptor,
      recommendation,
      analyzerVersion: OPTICAL_ANALYZER_VERSION,
      cacheKey,
      ...(sampledFrames ? { sampledFrames } : {}),
    };
  } finally {
    releaseVideo(video);
  }
}

export class DesktopOpticalAnalyzerService implements OpticalAnalyzerProvider {
  readonly analyzerVersion = OPTICAL_ANALYZER_VERSION;

  private readonly cache = new Map<string, Promise<DesktopSceneAnalysisResult>>();

  analyze(
    input: AnalyzerInput,
    onProgress?: DesktopSceneAnalysisProgressListener,
    options?: DesktopSceneAnalysisOptions,
  ): Promise<DesktopSceneAnalysisResult> {
    const baseCacheKey = createSceneAnalysisCacheKey({
      sourcePath: input.sourcePath,
      trimStartSec: input.trimStartSec,
      trimEndSec: input.trimEndSec,
      sourceDurationSec: input.sourceDurationSec,
      analyzerVersion: this.analyzerVersion,
    });
    const captureFrameJpegs = options?.captureFrameJpegs === true;
    const cacheKey = captureFrameJpegs
      ? `${baseCacheKey}::withJpegs`
      : baseCacheKey;
    const cached = this.cache.get(cacheKey);
    if (cached) {
      const { sourceUrl, sourceUrlKind } = resolveSceneAnalysisSourceUrl(input);
      emitSceneAnalysisProgress(onProgress, {
        stage: "cache-hit",
        message: "reusing cached analysis request",
        cacheKey,
        sourcePath: input.sourcePath,
        sourceUrl,
        sourceUrlKind,
      });
      return cached;
    }

    const run = analyzeSource(input, onProgress, options).catch((error) => {
      console.error("[optical-analysis] analysis failed", {
        cacheKey,
        sourcePath: input.sourcePath,
        error,
      });
      this.cache.delete(cacheKey);
      return {
        state: "error" as const,
        descriptor: null,
        recommendation: null,
        analyzerVersion: this.analyzerVersion,
        cacheKey,
        errorMessage: error instanceof Error ? error.message : String(error),
      };
    });
    this.cache.set(cacheKey, run);
    return run;
  }
}
