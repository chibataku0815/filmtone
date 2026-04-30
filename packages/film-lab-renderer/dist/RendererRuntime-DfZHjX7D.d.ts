/**
 * Render backend contract shared by WebGL (legacy) and WebGPU (v1.0) paths.
 *
 * Phase 2 T2-0a: `setParams` added as the unified grade/params entry point.
 * WebGL `WebGLBackend` already owns a `setParams(record)` consumer surface
 * (see `viewport-to-params` helpers in desktop-film-lab-batch); WebGPU
 * implements it structurally — uniforms are packed in Phase 2 T2-1 once the
 * 31-field `GradeUniforms` struct lands.
 */
type RenderBackendParamValue = number | string | boolean;
type RenderBackendParams = Record<string, RenderBackendParamValue>;
interface RenderBackend {
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

/**
 * Shared runtime contracts for backend capability and failure reporting.
 *
 * `Viewport` exposes these at the app-facing layer, while direct WebGPU
 * consumers (`GpuContext`, `WebGPUBackend`) reuse the same shape so callers
 * can feature-gate preview UI and react to fatal runtime issues without
 * knowing which concrete backend object they received.
 */
interface ViewportCapabilities {
    backendKind: "webgl" | "webgpu";
    supportsCompare: boolean;
    supportsHistogram: boolean;
    supportsBeforeAfter: boolean;
    supportsABCompare: boolean;
    supportsLiveVideoTexture: boolean;
    maxTextureDimension2D: number;
}
type ViewportContextLossReason = "device-lost" | "render-failed" | "prewarm-failed";
interface ViewportContextLossInfo {
    reason: ViewportContextLossReason;
    error?: unknown;
}
type ViewportContextLossListener = (info: ViewportContextLossInfo) => void;

export type { RenderBackend as R, ViewportCapabilities as V, ViewportContextLossInfo as a, RenderBackendParamValue as b, RenderBackendParams as c, ViewportContextLossReason as d, ViewportContextLossListener as e };
