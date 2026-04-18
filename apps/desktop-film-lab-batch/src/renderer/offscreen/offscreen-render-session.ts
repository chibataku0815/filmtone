import type * as THREE from "three";
import type { BatchGradeState } from "../batch-pipeline";

export type OffscreenRenderBackendKind = "webgl" | "webgpu";

export type OffscreenRenderSource = {
  texture: THREE.Texture;
  imageWidth: number;
  imageHeight: number;
};

/**
 * @description Export pipeline が backend 固有の bootstrapping を知らずに扱う最小契約。
 * decode / mezzanine / ffmpeg はこの外に置き、render shell だけをここへ閉じ込める。
 */
export interface OffscreenRenderSession {
  readonly backendKind: OffscreenRenderBackendKind;
  readonly maxTextureSize: number;
  setRenderSize(width: number, height: number): void;
  setSource(source: OffscreenRenderSource): void;
  setGrade(grade: BatchGradeState): void;
  setTime(timeSeconds: number): void;
  resetMotionBlurHistory(): void;
  render(): void;
  toDataURL(mimeType: string, quality?: number): string;
  dispose(): void;
}

export interface WebGLOffscreenRenderSession extends OffscreenRenderSession {
  readonly backendKind: "webgl";
  readonly canvas: HTMLCanvasElement;
  readonly renderer: THREE.WebGLRenderer;
  getWebGLContext(): WebGL2RenderingContext;
}
