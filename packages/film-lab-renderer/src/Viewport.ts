/**
 * Viewport — entry point for the film-lab renderer (Phase 2 T2-0c).
 *
 * Master plan D3 calls for a single `Viewport` class that switches backends
 * internally via a `RenderBackend` interface. T2-0c lands the class rename
 * and async factory; the actual WebGPU routing flips on in T2-1+ once
 * `WebGPUBackend` implements the full grade/LUT/composite surface.
 *
 * Today:
 *   - `Viewport extends WebGLBackend` so the ~60 WebGL setters remain on
 *     the public surface (no consumer churn beyond the 4 constructors we
 *     migrate to `Viewport.create`).
 *   - `Viewport.create(canvas, { prefer })` is the preferred async factory.
 *     Width/height derive from `canvas.clientWidth/Height` with fallbacks.
 *   - `prefer: 'webgpu'` is accepted but still returns a WebGL-backed
 *     Viewport until Phase 2 T2-1 lands `filmlab.wgsl` primary grade.
 */

import { WebGLBackend, type ViewportOptions } from "./webgl/WebGLBackend";
import { filmlabVertexShader } from "./webgl/shaders/filmlab.vert";
import { filmlabFragmentShader } from "./webgl/shaders/filmlab.frag";

export type ViewportBackendPreference = "webgpu" | "webgl";

export interface ViewportCreateOptions {
  /**
   * Desired backend. Defaults to `'webgpu'` so desktop builds flip to the
   * WebGPU implementation automatically as Phase 2 T2-1+ matures.
   * Web builds pass `'webgl'` explicitly (or rely on the build flag).
   */
  prefer?: ViewportBackendPreference;
  /** Override the derived render width. */
  width?: number;
  /** Override the derived render height. */
  height?: number;
}

export class Viewport extends WebGLBackend {
  /**
   * Async factory for the new consumer contract. Legacy
   * `new Viewport({vertexShader, fragmentShader, width, height})`
   * continues to work via inheritance — existing call sites that have not
   * yet migrated keep rendering without change.
   */
  static async create(
    canvas: HTMLCanvasElement,
    opts: ViewportCreateOptions = {},
  ): Promise<Viewport> {
    const width = Math.max(
      1,
      Math.floor(opts.width ?? canvas.clientWidth ?? canvas.width ?? 1),
    );
    const height = Math.max(
      1,
      Math.floor(opts.height ?? canvas.clientHeight ?? canvas.height ?? 1),
    );
    // T2-0c: `prefer` is accepted for forward-compat; real routing lands T2-1+.
    void opts.prefer;
    return new Viewport({
      vertexShader: filmlabVertexShader,
      fragmentShader: filmlabFragmentShader,
      width,
      height,
    });
  }
}

export type { ViewportOptions };
