import { Viewport } from "film-lab-renderer";
import type { BatchGradeState } from "../batch-pipeline";
import { applyBatchGradeToViewport } from "./apply-batch-grade-to-viewport";
import type {
  OffscreenRenderSource,
  OffscreenRenderSession,
} from "./offscreen-render-session";

type CreateWebGPUOffscreenRenderSessionOptions = {
  width: number;
  height: number;
};

class WebGPUOffscreenRenderSessionImpl implements OffscreenRenderSession {
  readonly backendKind = "webgpu" as const;
  readonly maxTextureSize: number;

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

  setTime(timeSeconds: number): void {
    this.viewport.setTime(timeSeconds);
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
    this.viewport.dispose();
    this.canvas.width = 1;
    this.canvas.height = 1;
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
