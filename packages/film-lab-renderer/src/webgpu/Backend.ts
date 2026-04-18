/**
 * Render backend contract shared by WebGL (legacy) and WebGPU (v1.0) paths.
 *
 * Phase 2 T2-0a: `setParams` added as the unified grade/params entry point.
 * WebGL `WebGLBackend` already owns a `setParams(record)` consumer surface
 * (see `viewport-to-params` helpers in desktop-film-lab-batch); WebGPU
 * implements it structurally — uniforms are packed in Phase 2 T2-1 once the
 * 31-field `GradeUniforms` struct lands.
 */

export type RenderBackendParamValue = number | string | boolean;
export type RenderBackendParams = Record<string, RenderBackendParamValue>;

export interface RenderBackend {
  /** Render the current frame to the canvas. */
  render(): void;

  /** Resize internal render targets. */
  setResolution(width: number, height: number): void;

  /**
   * Apply a bulk params record. Only recognized keys mutate state; unknown
   * keys are silently ignored so consumers can pass the full grade blob.
   * Phase 2 T2-1 wires this into `GradeUniforms` on the WebGPU side.
   */
  setParams(params: RenderBackendParams): void;

  /** Free GPU resources. Idempotent. */
  destroy(): void;
}
