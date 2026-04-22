import type * as THREE from "three";
import type { BatchGradeState } from "../batch-pipeline";
import type { BatchDepthTrack } from "../depth-track";

export type OffscreenRenderBackendKind = "webgl" | "webgpu";
export type OffscreenRenderSessionPreference = "webgl" | "webgpu";

export type OffscreenRenderSource = {
  texture: THREE.Texture;
  imageWidth: number;
  imageHeight: number;
};

export interface CreateOffscreenRenderSessionOptions {
  width: number;
  height: number;
  prefer?: OffscreenRenderSessionPreference;
  powerPreference?: WebGLPowerPreference;
}

/**
 * @description Export pipeline が backend 固有の bootstrapping を知らずに扱う最小契約。
 * decode / mezzanine / ffmpeg はこの外に置き、render shell だけをここへ閉じ込める。
 */
export interface OffscreenRenderSession {
  readonly backendKind: OffscreenRenderBackendKind;
  readonly maxTextureSize: number;
  setRenderSize(width: number, height: number): void;
  setSource(source: OffscreenRenderSource): void | Promise<void>;
  setGrade(grade: BatchGradeState): void;
  setDepthTrack(depthTrack: BatchDepthTrack | null): void | Promise<void>;
  setTime(timeSeconds: number): void;
  resetMotionBlurHistory(): void;
  render(): void;
  // Matches the existing video-export contract: full-range RGBA8 in bottom-up row order.
  readbackRgba8(): Uint8Array | Promise<Uint8Array>;
  toDataURL(mimeType: string, quality?: number): string;
  dispose(): void;
}

export interface WebGLOffscreenRenderSession extends OffscreenRenderSession {
  readonly backendKind: "webgl";
  readonly canvas: HTMLCanvasElement;
  readonly renderer: THREE.WebGLRenderer;
  getWebGLContext(): WebGL2RenderingContext;
}
