/**
 * Shared runtime contracts for backend capability and failure reporting.
 *
 * `Viewport` exposes these at the app-facing layer, while direct WebGPU
 * consumers (`GpuContext`, `WebGPUBackend`) reuse the same shape so callers
 * can feature-gate preview UI and react to fatal runtime issues without
 * knowing which concrete backend object they received.
 */

export interface ViewportCapabilities {
  backendKind: "webgl" | "webgpu";
  supportsCompare: boolean;
  supportsHistogram: boolean;
  supportsBeforeAfter: boolean;
  supportsABCompare: boolean;
  supportsLiveVideoTexture: boolean;
  maxTextureDimension2D: number;
}

export type ViewportContextLossReason =
  | "device-lost"
  | "render-failed"
  | "prewarm-failed";

export interface ViewportContextLossInfo {
  reason: ViewportContextLossReason;
  error?: unknown;
}

export type ViewportContextLossListener = (
  info: ViewportContextLossInfo,
) => void;
