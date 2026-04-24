import { Viewport } from "film-lab-renderer";
import type { CameraOptics } from "film-lab-core";
import type { BatchGradeState } from "../batch-pipeline";
import type { BatchDepthTrack } from "../depth-track";
import { applyBatchGradeToViewport } from "./apply-batch-grade-to-viewport";
import type {
  OffscreenRenderSource,
  OffscreenRenderSession,
} from "./offscreen-render-session";

type CreateWebGPUOffscreenRenderSessionOptions = {
  width: number;
  height: number;
};

const DEPTH_TEXTURE_WIDTH = 512;
const DEPTH_TEXTURE_HEIGHT = 288;

function closeImageBitmaps(bitmaps: ImageBitmap[]): void {
  for (const bitmap of bitmaps) {
    bitmap.close();
  }
}

async function createNeutralDepthBitmap(): Promise<ImageBitmap> {
  if (typeof document === "undefined") {
    throw new Error("document is required for WebGPU depth-track reset");
  }
  if (typeof createImageBitmap !== "function") {
    throw new Error("createImageBitmap is required for WebGPU depth-track reset");
  }

  const canvas = document.createElement("canvas");
  canvas.width = DEPTH_TEXTURE_WIDTH;
  canvas.height = DEPTH_TEXTURE_HEIGHT;
  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("2D canvas is required for WebGPU depth-track reset");
  }
  ctx.fillStyle = "rgba(128, 128, 128, 1)";
  ctx.fillRect(0, 0, DEPTH_TEXTURE_WIDTH, DEPTH_TEXTURE_HEIGHT);
  return createImageBitmap(canvas);
}

async function decodeDepthTrackFrame(frameUrl: string): Promise<ImageBitmap> {
  if (typeof fetch !== "function") {
    throw new Error("fetch is required for WebGPU depth-track decode");
  }
  if (typeof createImageBitmap !== "function") {
    throw new Error("createImageBitmap is required for WebGPU depth-track decode");
  }

  const response = await fetch(frameUrl);
  if (!response.ok) {
    throw new Error(`depth-track fetch failed: ${response.status}`);
  }
  const blob = await response.blob();
  return createImageBitmap(blob);
}

class WebGPUOffscreenRenderSessionImpl implements OffscreenRenderSession {
  readonly backendKind = "webgpu" as const;
  readonly maxTextureSize: number;
  private depthBitmaps: ImageBitmap[] = [];
  private depthTrackFps = 0;
  private depthFrameIndex = -1;
  private currentTimeSeconds = 0;
  private depthTrackToken = 0;

  constructor(
    private readonly canvas: HTMLCanvasElement,
    private readonly viewport: Viewport,
  ) {
    this.maxTextureSize = viewport.getCapabilities().maxTextureDimension2D;
    this.viewport.setReadbackEnabled(true);
  }

  setRenderSize(width: number, height: number): void {
    this.viewport.setResolution(width, height);
  }

  async setSource(source: OffscreenRenderSource): Promise<void> {
    const textureSource =
      (source.texture as { source?: { data?: unknown } }).source?.data ??
      (source.texture as { image?: unknown }).image;
    if (!textureSource) {
      return;
    }

    if (
      typeof HTMLVideoElement !== "undefined" &&
      textureSource instanceof HTMLVideoElement
    ) {
      this.viewport.setTexture(source.texture);
      return;
    }

    if (
      typeof ImageBitmap !== "undefined" &&
      textureSource instanceof ImageBitmap
    ) {
      this.viewport.setMediaFromBitmap(textureSource);
      return;
    }

    if (typeof createImageBitmap !== "function") {
      throw new Error("createImageBitmap is required for WebGPU offscreen upload");
    }

    const bitmap = await createImageBitmap(
      textureSource as CanvasImageSource,
    );
    try {
      this.viewport.setMediaFromBitmap(bitmap);
    } finally {
      bitmap.close();
    }
  }

  setGrade(grade: BatchGradeState): void {
    applyBatchGradeToViewport(this.viewport, grade);
  }

  setCameraOptics(cameraOptics: CameraOptics | null): void {
    this.viewport.setCameraOptics(cameraOptics);
  }

  async setDepthTrack(depthTrack: BatchDepthTrack | null): Promise<void> {
    const token = ++this.depthTrackToken;
    this.clearDecodedDepthTrack();
    await this.uploadNeutralDepth(token);
    if (!depthTrack || depthTrack.frameUrls.length === 0) {
      return;
    }

    const bitmaps = await Promise.all(
      depthTrack.frameUrls.map((frameUrl) => decodeDepthTrackFrame(frameUrl)),
    );
    if (token !== this.depthTrackToken) {
      closeImageBitmaps(bitmaps);
      return;
    }

    this.depthBitmaps = bitmaps;
    this.depthTrackFps = depthTrack.source.fps;
    this.depthFrameIndex = -1;
    this.applyDepthFrameForTime(this.currentTimeSeconds);
  }

  setTime(timeSeconds: number): void {
    this.currentTimeSeconds = timeSeconds;
    this.viewport.setTime(timeSeconds);
    this.applyDepthFrameForTime(timeSeconds);
  }

  resetMotionBlurHistory(): void {
    this.viewport.resetMotionBlurHistory();
  }

  render(): void {
    this.viewport.render();
  }

  readbackRgba8(): Promise<Uint8Array> {
    return this.viewport.readbackRgba8();
  }

  toDataURL(mimeType: string, quality?: number): string {
    return this.canvas.toDataURL(mimeType, quality as never);
  }

  dispose(): void {
    this.depthTrackToken += 1;
    this.clearDecodedDepthTrack();
    this.viewport.dispose();
    this.canvas.width = 1;
    this.canvas.height = 1;
  }

  private clearDecodedDepthTrack(): void {
    closeImageBitmaps(this.depthBitmaps);
    this.depthBitmaps = [];
    this.depthTrackFps = 0;
    this.depthFrameIndex = -1;
  }

  private applyDepthFrameForTime(timeSeconds: number): void {
    if (this.depthBitmaps.length === 0 || this.depthTrackFps <= 0) {
      return;
    }
    const rawIndex = Math.round(
      Math.max(0, timeSeconds) * Math.max(1, this.depthTrackFps),
    );
    const nextIndex = Math.max(
      0,
      Math.min(this.depthBitmaps.length - 1, rawIndex),
    );
    if (nextIndex === this.depthFrameIndex) {
      return;
    }
    this.depthFrameIndex = nextIndex;
    this.viewport.setDepthFromBitmap(this.depthBitmaps[nextIndex]!);
  }

  private async uploadNeutralDepth(token: number): Promise<void> {
    const bitmap = await createNeutralDepthBitmap();
    try {
      if (token === this.depthTrackToken) {
        this.viewport.setDepthFromBitmap(bitmap);
      }
    } finally {
      bitmap.close();
    }
  }
}

export async function createWebGPUOffscreenRenderSession(
  options: CreateWebGPUOffscreenRenderSessionOptions,
): Promise<OffscreenRenderSession> {
  const { width, height } = options;
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const viewport = await Viewport.create(canvas, {
    prefer: "webgpu",
    width,
    height,
  });
  if (viewport.backendKind !== "webgpu") {
    viewport.dispose();
    throw new Error(
      "createWebGPUOffscreenRenderSession: webgpu viewport の初期化に失敗しました",
    );
  }

  return new WebGPUOffscreenRenderSessionImpl(canvas, viewport);
}
