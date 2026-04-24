import { WebPlugin } from "@capacitor/core";
import type {
  Phase0ExportRequest,
  Phase0ExportResult,
  Phase0PreviewRenderResult,
  SourceInfo,
  SourceProbe,
} from "film-lab-core";
import type { FilmtoneMediaPlugin, PickedLutFile } from "./filmtoneMedia";

function pickFile(accept: string): Promise<File | null> {
  return new Promise((resolve) => {
    const input = document.createElement("input");
    input.type = "file";
    input.accept = accept;
    input.onchange = () => resolve(input.files?.[0] ?? null);
    input.click();
  });
}

function inferSourceKind(file: File): SourceInfo["kind"] {
  if (file.type.startsWith("image/")) return "image";
  return "video";
}

function loadImage(uri: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("Failed to load image preview"));
    image.src = uri;
  });
}

function loadVideoFrame(uri: string, timeSec: number): Promise<HTMLVideoElement> {
  return new Promise((resolve, reject) => {
    const video = document.createElement("video");
    video.preload = "auto";
    video.playsInline = true;
    video.muted = true;

    const cleanup = () => {
      video.onloadedmetadata = null;
      video.onseeked = null;
      video.onerror = null;
    };

    video.onerror = () => {
      cleanup();
      reject(new Error("Failed to load video preview"));
    };
    video.onloadedmetadata = () => {
      const boundedTime = Math.max(0, Math.min(timeSec, video.duration || 0));
      video.currentTime = Number.isFinite(boundedTime) ? boundedTime : 0;
    };
    video.onseeked = () => {
      cleanup();
      resolve(video);
    };

    video.src = uri;
  });
}

function renderFrameToDataUrl(
  width: number,
  height: number,
  draw: (context: CanvasRenderingContext2D, canvas: HTMLCanvasElement) => void,
): string {
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const context = canvas.getContext("2d");
  if (!context) {
    throw new Error("Canvas 2D preview context is unavailable");
  }
  draw(context, canvas);
  return canvas.toDataURL("image/jpeg", 0.92);
}

export class FilmtoneMediaWeb extends WebPlugin implements FilmtoneMediaPlugin {
  private readonly fileStore = new Map<string, File>();
  private exportTimer: number | null = null;

  private canShareUri(uri: string): boolean {
    try {
      const parsed = new URL(uri);
      return parsed.protocol === "https:" || parsed.protocol === "http:";
    } catch {
      return false;
    }
  }

  async pickSource(): Promise<SourceInfo | null> {
    const file = await pickFile("video/*,image/*");
    if (!file) return null;
    const uri = URL.createObjectURL(file);
    this.fileStore.set(uri, file);
    return {
      uri,
      filename: file.name,
      kind: inferSourceKind(file),
      mimeType: file.type || undefined,
    };
  }

  async pickLutFile(): Promise<PickedLutFile | null> {
    const file = await pickFile(".cube");
    if (!file) return null;
    return {
      filename: file.name,
      text: await file.text(),
    };
  }

  async probeSource(options: { uri: string }): Promise<SourceProbe> {
    const file = this.fileStore.get(options.uri);
    if (!file) {
      throw new Error(`No source file found for URI: ${options.uri}`);
    }

    const kind = inferSourceKind(file);
    const base: SourceProbe = {
      uri: options.uri,
      filename: file.name,
      kind,
      mimeType: file.type || undefined,
      fileSizeBytes: file.size,
    };

    if (kind === "image") {
      const image = await new Promise<HTMLImageElement>((resolve, reject) => {
        const node = new Image();
        node.onload = () => resolve(node);
        node.onerror = () => reject(new Error("Failed to load image metadata"));
        node.src = options.uri;
      });
      return {
        ...base,
        width: image.naturalWidth,
        height: image.naturalHeight,
      };
    }

    const video = await new Promise<HTMLVideoElement>((resolve, reject) => {
      const node = document.createElement("video");
      node.preload = "metadata";
      node.onloadedmetadata = () => resolve(node);
      node.onerror = () => reject(new Error("Failed to load video metadata"));
      node.src = options.uri;
    });

    return {
      ...base,
      width: video.videoWidth,
      height: video.videoHeight,
      durationSec: Number.isFinite(video.duration) ? video.duration : undefined,
    };
  }

  async renderPreviewFrame(
    request: Phase0ExportRequest,
  ): Promise<Phase0PreviewRenderResult> {
    if (request.sourceKind === "image") {
      const image = await loadImage(request.sourceUri);
      return {
        originalUri: request.sourceUri,
        gradedUri: request.sourceUri,
        width: image.naturalWidth,
        height: image.naturalHeight,
      };
    }

    const posterTimeSec =
      typeof request.sourceProbe?.durationSec === "number" && request.sourceProbe.durationSec > 0
        ? request.sourceProbe.durationSec * 0.25
        : 0;
    const video = await loadVideoFrame(request.sourceUri, posterTimeSec);
    const width = Math.max(video.videoWidth, 1);
    const height = Math.max(video.videoHeight, 1);
    const frameUri = renderFrameToDataUrl(width, height, (context) => {
      context.drawImage(video, 0, 0, width, height);
    });

    return {
      originalUri: frameUri,
      gradedUri: frameUri,
      width,
      height,
      posterTimeSec,
    };
  }

  async runExport(request: Phase0ExportRequest): Promise<Phase0ExportResult> {
    const start = performance.now();
    const sourceFile = this.fileStore.get(request.sourceUri);
    if (!sourceFile) {
      throw new Error("Web export stub requires a picked source file");
    }

    await this.notifyProgress({
      stage: "preflight",
      progress: 0.05,
      message: "Preparing export stub",
    });

    await this.stepProgress("reading", 0.25);
    await this.stepProgress("rendering", 0.65);
    await this.stepProgress("writing", 0.95);

    const outputUri = URL.createObjectURL(sourceFile);
    const elapsedMs = Math.round(performance.now() - start);
    const durationSec = request.sourceProbe?.durationSec;

    await this.notifyProgress({
      stage: "completed",
      progress: 1,
      message: "Export stub complete",
    });

    return {
      outputUri,
      elapsedMs,
      outputWidth: request.sourceProbe?.width ?? request.output.longEdge,
      outputHeight: request.sourceProbe?.height ?? request.output.longEdge,
      outputFps: request.output.fps,
      fileSizeBytes: sourceFile.size,
      realtimeRatio:
        typeof durationSec === "number" && durationSec > 0
          ? elapsedMs / (durationSec * 1000)
          : undefined,
      audioPreserved: request.sourceKind === "video",
    };
  }

  async saveToPhotos(options: { uri: string }): Promise<void> {
    const anchor = document.createElement("a");
    anchor.href = options.uri;
    anchor.download = "filmtone-ios-output";
    anchor.click();
  }

  async shareOutput(options: { uri: string }): Promise<void> {
    if (navigator.share && this.canShareUri(options.uri)) {
      try {
        await navigator.share({ url: options.uri });
        return;
      } catch (error) {
        if (error instanceof DOMException && error.name === "AbortError") {
          return;
        }
      }
    }
    await this.saveToPhotos(options);
  }

  async cancelExport(): Promise<void> {
    if (this.exportTimer != null) {
      window.clearTimeout(this.exportTimer);
      this.exportTimer = null;
    }
  }

  private async stepProgress(
    stage: "reading" | "rendering" | "writing",
    progress: number,
  ) {
    await new Promise<void>((resolve) => {
      this.exportTimer = window.setTimeout(async () => {
        await this.notifyProgress({ stage, progress });
        resolve();
      }, 180);
    });
  }

  private async notifyProgress(progress: {
    stage: "preflight" | "reading" | "rendering" | "writing" | "completed";
    progress: number;
    message?: string;
  }) {
    this.notifyListeners("exportProgress", progress);
  }
}
