/**
 * Render backend contract shared by WebGL (legacy) and WebGPU (v1.0) paths.
 *
 * Phase 1 T1-1: interface skeleton only. Setter surface is intentionally a
 * subset — WebGL backend still exposes its full historical API; Phase 2
 * unifies the two once filmlab.wgsl lands.
 */

export interface RenderBackendResizeArgs {
  width: number;
  height: number;
}

export interface RenderBackend {
  /** Render the current frame to the canvas. */
  render(): void;

  /** Resize internal render targets. */
  setResolution(width: number, height: number): void;

  /** Free GPU resources. Idempotent. */
  destroy(): void;
}
