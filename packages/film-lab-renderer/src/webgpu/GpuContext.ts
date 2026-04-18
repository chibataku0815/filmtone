/**
 * GpuContext — adapter / device / canvas-surface bootstrap.
 *
 * Phase 1 T1-2. Backed by DIRECTION §2 canvas config:
 *   configure format=rgba8unorm (spec-compliant — sRGB variants are not
 *   valid canvas formats), viewFormats=[rgba8unorm-srgb] so views / pipeline
 *   colorAttachments can target the sRGB encoding and the hardware OETF
 *   performs the final linear → sRGB transform, colorSpace=srgb, alphaMode=opaque.
 */

export interface GpuContextCreateOptions {
  /** Dev-mode validation scope is pushed around pipeline creation. */
  validation?: boolean;
}

export class GpuContextCreationError extends Error {
  readonly cause?: unknown;
  constructor(message: string, cause?: unknown) {
    super(message);
    this.name = "GpuContextCreationError";
    this.cause = cause;
  }
}

export class GpuContext {
  readonly adapter: GPUAdapter;
  readonly device: GPUDevice;
  readonly canvas: HTMLCanvasElement;
  readonly context: GPUCanvasContext;
  /**
   * View / pipeline-attachment format.
   *
   * The swapchain is configured with the spec-legal `rgba8unorm`, but every
   * pass that writes to the canvas takes a view in `rgba8unorm-srgb` so the
   * hardware OETF performs the final linear → sRGB transform. Pipelines
   * declare `colorAttachments[].format = ctx.canvasFormat`.
   */
  readonly canvasFormat: GPUTextureFormat = "rgba8unorm-srgb";
  readonly validation: boolean;
  private lost = false;

  private constructor(
    adapter: GPUAdapter,
    device: GPUDevice,
    canvas: HTMLCanvasElement,
    context: GPUCanvasContext,
    validation: boolean,
  ) {
    this.adapter = adapter;
    this.device = device;
    this.canvas = canvas;
    this.context = context;
    this.validation = validation;
    device.lost.then((info) => {
      this.lost = true;
      console.warn("[GpuContext] device lost:", info.reason, info.message);
    });
  }

  static async create(
    canvas: HTMLCanvasElement,
    opts: GpuContextCreateOptions = {},
  ): Promise<GpuContext> {
    const nav = typeof navigator !== "undefined" ? navigator : undefined;
    const gpu = nav ? (nav as Navigator & { gpu?: GPU }).gpu : undefined;
    if (!gpu) {
      throw new GpuContextCreationError("navigator.gpu is not available");
    }
    const adapter = await gpu.requestAdapter();
    if (!adapter) {
      throw new GpuContextCreationError("requestAdapter returned null");
    }
    let device: GPUDevice;
    try {
      device = await adapter.requestDevice();
    } catch (err) {
      throw new GpuContextCreationError("requestDevice failed", err);
    }
    const context = canvas.getContext("webgpu") as GPUCanvasContext | null;
    if (!context) {
      throw new GpuContextCreationError("getContext('webgpu') returned null");
    }
    context.configure({
      device,
      format: "rgba8unorm",
      viewFormats: ["rgba8unorm-srgb"],
      alphaMode: "opaque",
      colorSpace: "srgb",
      usage:
        GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
    });
    return new GpuContext(adapter, device, canvas, context, opts.validation ?? false);
  }

  /** Wrap a pipeline-creating callback with validation error scope. */
  async withValidationScope<T>(fn: () => T | Promise<T>): Promise<T> {
    if (!this.validation) return await fn();
    this.device.pushErrorScope("validation");
    const result = await fn();
    const err = await this.device.popErrorScope();
    if (err) {
      throw new Error(`[GpuContext] validation error: ${err.message}`);
    }
    return result;
  }

  isLost(): boolean {
    return this.lost;
  }

  getCurrentTextureView(): GPUTextureView {
    return this.context
      .getCurrentTexture()
      .createView({ format: "rgba8unorm-srgb" });
  }

  destroy(): void {
    this.context.unconfigure();
    this.device.destroy();
  }
}
