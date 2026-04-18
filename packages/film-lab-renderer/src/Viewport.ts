/**
 * Viewport — single-entry renderer wrapper (Phase 3 T3-3).
 *
 * Master plan D3 calls for a single `Viewport` class that switches backends
 * internally via `RenderBackend`. T3-3 lands the composition refactor:
 *   - `Viewport` no longer extends `WebGLBackend`; it composes one of
 *     { `WebGLBackend`, `WebGPUBackend` } and forwards the public surface.
 *   - `backendKind` / `mesh?` are read-only introspection fields.
 *   - `Viewport.create(canvas, { prefer: 'webgpu' })` routes to the WebGPU
 *     backend when `isWebGPUSupported()` returns true AND the canvas does
 *     not already own a WebGL2 context (consumer-side responsibility). No
 *     silent fallback — if WebGPU is requested and unavailable, or the
 *     backend bootstrap throws, the exception propagates. Callers decide
 *     how to surface that to the user (e.g. explicit "WebGPU required" UI).
 *     Rationale: silent degradation multiplies code paths and masks
 *     premise-breaking bugs (e.g. a WebGPU-owned canvas that can no longer
 *     accept a WebGL2 context).
 *
 * Consumer surface preserved by delegation:
 *   render / setResolution / setTexture / setMediaFromBitmap /
 *   setImageResolution / setFitMode / setTime / setParams / getParams /
 *   setLUT1(+Intensity,+clear) / setLUT2(+Intensity,+clear) /
 *   setLUT/setLUTIntensity/clearLUT (deprecated aliases) /
 *   setSplitPosition / getSplitPosition / setExportFlipY /
 *   resetMotionBlurHistory / bindThree / setComparePair /
 *   getHistogramPixels / dispose / destroy / prewarm.
 *
 * Granular WebGL setters (setExposure, setCrossFilterXxx, etc.) are no
 * longer on the Viewport public type. v1.0 consumers drive the renderer via
 * `setParams(record)` — verified by `grep viewport\.set…` across packages.
 */

import type * as THREE from "three";
import { WebGLBackend, type ViewportOptions } from "./webgl/WebGLBackend";
import { filmlabVertexShader } from "./webgl/shaders/filmlab.vert";
import { filmlabFragmentShader } from "./webgl/shaders/filmlab.frag";
import { isWebGPUSupported } from "./support";
import type { RenderBackendParams } from "./webgpu/Backend";
// Type-only import: keeps `WebGPUBackend` out of the web bundle. The actual
// module is pulled in dynamically inside `Viewport.create` when the caller
// asks for `prefer: 'webgpu'` AND WebGPU is supported. See DIRECTION §10
// Phase 3 web-bundle rule — web builds set `prefer: 'webgl'` explicitly, so
// the dynamic import is never executed and the `webgpu/*` chunk is tree-
// shaken from the entry bundle.
import type { WebGPUBackend } from "./webgpu/WebGPUBackend";

export type ViewportBackendPreference = "webgpu" | "webgl";

export interface ViewportCreateOptions {
  /**
   * Desired backend. Defaults to `'webgpu'` so desktop paths flip
   * automatically. Web builds pass `'webgl'` explicitly (or rely on the
   * build flag). WebGPU requires a canvas without a prior WebGL2 context —
   * callers must pass a fresh canvas when `prefer === 'webgpu'`.
   */
  prefer?: ViewportBackendPreference;
  /** Override the derived render width. */
  width?: number;
  /** Override the derived render height. */
  height?: number;
}

export class Viewport {
  private readonly webglBackend: WebGLBackend | null;
  private readonly webgpuBackend: WebGPUBackend | null;
  readonly backendKind: ViewportBackendPreference;

  /**
   * WebGL-only handle to the fullscreen `THREE.Mesh`. `undefined` on the
   * WebGPU path — consumer code that does `scene.add(viewport.mesh)` MUST
   * gate on `viewport.backendKind === 'webgl'` first.
   */
  readonly mesh?: THREE.Mesh;

  private webgpuSetTextureGen = 0;

  private constructor(
    webgl: WebGLBackend | null,
    webgpu: WebGPUBackend | null,
  ) {
    this.webglBackend = webgl;
    this.webgpuBackend = webgpu;
    this.backendKind = webgpu !== null ? "webgpu" : "webgl";
    if (webgl) this.mesh = webgl.mesh;
  }

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
    const prefer: ViewportBackendPreference = opts.prefer ?? "webgpu";

    if (prefer === "webgpu") {
      if (!(await isWebGPUSupported())) {
        throw new Error(
          "[Viewport] WebGPU is required but not supported in this environment",
        );
      }
      const { WebGPUBackend } = await import("./webgpu/WebGPUBackend");
      const backend = await WebGPUBackend.create(canvas);
      backend.setResolution(width, height);
      return new Viewport(null, backend);
    }

    const webgl = new WebGLBackend({
      vertexShader: filmlabVertexShader,
      fragmentShader: filmlabFragmentShader,
      width,
      height,
    });
    return new Viewport(webgl, null);
  }

  // === Core delegation ===

  render(
    renderer?: THREE.WebGLRenderer,
    scene?: THREE.Scene,
    camera?: THREE.Camera,
  ): void {
    if (this.webgpuBackend) {
      this.webgpuBackend.render();
      return;
    }
    this.webglBackend!.render(renderer, scene, camera);
  }

  setResolution(width: number, height: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setResolution(width, height);
    else this.webglBackend!.setResolution(width, height);
  }

  /**
   * WebGL: sets the `THREE.Texture` uniform directly.
   * WebGPU: extracts the texture's source (`HTMLImageElement`,
   * `HTMLVideoElement`, `ImageBitmap`, etc.) and uploads via
   * `createImageBitmap` + `setMediaFromBitmap`. The conversion is async and
   * fire-and-forget; callers can continue rendering — the new image appears
   * on the next frame after the bitmap is ready. Generation counter drops
   * stale results if `setTexture` is called multiple times in flight.
   */
  setTexture(texture: THREE.Texture): void {
    if (this.webglBackend) {
      this.webglBackend.setTexture(texture);
      return;
    }
    if (this.webgpuBackend) {
      void this.queueSetTextureWebGPU(texture);
    }
  }

  /** WebGPU-native path; WebGL consumers should call `setTexture` instead. */
  setMediaFromBitmap(bitmap: ImageBitmap): void {
    this.webgpuBackend?.setMediaFromBitmap(bitmap);
  }

  setImageResolution(width: number, height: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setImageResolution(width, height);
    else this.webglBackend!.setImageResolution(width, height);
  }

  setFitMode(mode: "cover" | "contain"): void {
    if (this.webgpuBackend) this.webgpuBackend.setFitMode(mode);
    else this.webglBackend!.setFitMode(mode);
  }

  setTime(time: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setTime(time);
    else this.webglBackend!.setTime(time);
  }

  setParams(params: Record<string, number | string | boolean>): void {
    if (this.webgpuBackend) {
      this.webgpuBackend.setParams(params as RenderBackendParams);
      return;
    }
    this.webglBackend!.setParams(params);
  }

  getParams(): Record<string, number | string> {
    if (this.webglBackend) return this.webglBackend.getParams();
    // WebGPU path has no structured getter yet — return the pending params
    // blob so callers that round-trip through `getParams → setParams`
    // (e.g. App.tsx preset capture at L847) don't silently lose state.
    const pending = this.webgpuBackend?.getPendingParams() ?? {};
    return pending as Record<string, number | string>;
  }

  // === LUTs ===

  setLUT1(data: Float32Array, size: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setLUT1(data, size);
    else this.webglBackend!.setLUT1(data, size);
  }

  setLUT1Intensity(value: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setLUT1Intensity(value);
    else this.webglBackend!.setLUT1Intensity(value);
  }

  clearLUT1(): void {
    if (this.webgpuBackend) this.webgpuBackend.clearLUT1();
    else this.webglBackend!.clearLUT1();
  }

  setLUT2(data: Float32Array, size: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setLUT2(data, size);
    else this.webglBackend!.setLUT2(data, size);
  }

  setLUT2Intensity(value: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setLUT2Intensity(value);
    else this.webglBackend!.setLUT2Intensity(value);
  }

  clearLUT2(): void {
    if (this.webgpuBackend) this.webgpuBackend.clearLUT2();
    else this.webglBackend!.clearLUT2();
  }

  /**
   * WebGL-only snapshot for edit→batch sync and video export. WebGPU path
   * returns `null` in v1.0 — consumers must gate on `backendKind === 'webgl'`
   * or accept the no-op fallback.
   */
  getLUT1Snapshot(): { data: Float32Array; size: number; intensity: number } | null {
    return this.webglBackend?.getLUT1Snapshot() ?? null;
  }

  getLUT2Snapshot(): { data: Float32Array; size: number; intensity: number } | null {
    return this.webglBackend?.getLUT2Snapshot() ?? null;
  }

  /** @deprecated Use setLUT2() — kept for legacy apps/webgl-study debug-gui. */
  setLUT(data: Float32Array, size: number): void {
    this.setLUT2(data, size);
  }

  /** @deprecated Use clearLUT2() */
  clearLUT(): void {
    this.clearLUT2();
  }

  /** @deprecated Use setLUT2Intensity() */
  setLUTIntensity(value: number): void {
    this.setLUT2Intensity(value);
  }

  // === Split / flipY ===

  setSplitPosition(value: number): void {
    if (this.webgpuBackend) this.webgpuBackend.setSplitPosition(value);
    else this.webglBackend!.setSplitPosition(value);
  }

  getSplitPosition(): number {
    if (this.webglBackend) return this.webglBackend.getSplitPosition();
    const pending = this.webgpuBackend?.getPendingParams() ?? {};
    const v = (pending as Record<string, unknown>)["splitPosition"];
    return typeof v === "number" ? v : -1;
  }

  setExportFlipY(flip: boolean): void {
    if (this.webgpuBackend) this.webgpuBackend.setFlipY(flip);
    else this.webglBackend!.setExportFlipY(flip);
  }

  // === Motion blur ===

  resetMotionBlurHistory(): void {
    this.webglBackend?.resetMotionBlurHistory();
    // WebGPU ring resets on setResolution; no explicit reset API in v1.0.
    // Phase 3 T3-2 GpuRenderer extract will expose one if needed.
  }

  // === WebGL-only (no-op on WebGPU in v1.0) ===

  bindThree(
    renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    camera: THREE.Camera,
  ): void {
    this.webglBackend?.bindThree(renderer, scene, camera);
  }

  setComparePair(
    enabled: boolean,
    paramsA: Record<string, number | string> | null,
    paramsB: Record<string, number | string> | null,
  ): void {
    this.webglBackend?.setComparePair(enabled, paramsA, paramsB);
  }

  getHistogramPixels():
    | { pixels: Float32Array; width: number; height: number }
    | null {
    return this.webglBackend?.getHistogramPixels() ?? null;
  }

  // === WebGPU-only ===

  /**
   * Phase 3 T3-3: prewarm WebGPU pipeline JIT.
   *
   * Issues a single render at current resolution so first real frame does
   * not stutter on pipeline compile. Caller should run inside
   * `requestIdleCallback` — DIRECTION §10 Phase 3 UX budget is 150 ms
   * silent / 300 ms overlay fadeout.
   *
   * No-op on WebGL (no JIT cost there).
   */
  async prewarm(): Promise<void> {
    if (!this.webgpuBackend) return;
    this.webgpuBackend.render();
  }

  // === Disposal ===

  dispose(): void {
    this.webglBackend?.dispose();
    this.webgpuBackend?.destroy();
  }

  /** RenderBackend interface alias. */
  destroy(): void {
    this.dispose();
  }

  // === Internal ===

  private async queueSetTextureWebGPU(texture: THREE.Texture): Promise<void> {
    if (!this.webgpuBackend) return;
    const generation = ++this.webgpuSetTextureGen;
    const source =
      (texture as { source?: { data?: unknown } }).source?.data ??
      (texture as { image?: unknown }).image;
    if (!source) return;
    try {
      let bitmap: ImageBitmap;
      if (source instanceof ImageBitmap) {
        bitmap = source;
      } else if (typeof createImageBitmap === "function") {
        bitmap = await createImageBitmap(
          source as ImageBitmapSource,
        );
      } else {
        return;
      }
      if (generation !== this.webgpuSetTextureGen) {
        bitmap.close?.();
        return;
      }
      if (this.webgpuBackend) {
        this.webgpuBackend.setMediaFromBitmap(bitmap);
      }
    } catch (err) {
      console.warn("[Viewport] setTexture → ImageBitmap failed", err);
    }
  }
}

export type { ViewportOptions };
