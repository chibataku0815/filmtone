/**
 * WebGPUBackend — Phase 1 scaffold.
 *
 * Responsibilities this phase actually lands:
 *   - `create(canvas)` factory bootstraps GpuContext, compiles all 9 Simple
 *     shader modules, and creates the identity filmlab pipeline end-to-end.
 *     Validation scope is wrapped around every `createShaderModule` /
 *     `createRenderPipeline` call (DIRECTION §4 dev guard).
 *   - `setMediaFromBitmap` uploads an ImageBitmap through `MediaTexture`.
 *   - `render()` runs the media → identity filmlab → swapchain render pass,
 *     producing a visible frame so Phase 1 golden harness can capture.
 *
 * Intentionally NOT implemented here (deferred to later phases):
 *   - Full bloom / halation pyramid composition (requires per-level bind
 *     groups and blend states — Phase 2 filmlab.wgsl integration lands it).
 *   - Motion blur, cross-filter, color grade uniforms.
 *
 * `RenderBackend` is satisfied structurally so callers that migrate to the
 * interface contract in a later phase inherit the contract automatically.
 */

import { GpuContext } from "./GpuContext";
import { MediaTexture } from "./MediaTexture";
import {
  fullscreenVertexWgsl,
  filmlabFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  dustFragmentWgsl,
} from "./shaders";
import type { RenderBackend } from "./Backend";

export interface WebGPUBackendCreateOptions {
  validation?: boolean;
}

interface ShaderModules {
  vert: GPUShaderModule;
  filmlab: GPUShaderModule;
  bloomPrefilter: GPUShaderModule;
  halationPrefilter: GPUShaderModule;
  downsample: GPUShaderModule;
  upsample: GPUShaderModule;
  lightshafts: GPUShaderModule;
  lightshaftsBlend: GPUShaderModule;
  dust: GPUShaderModule;
}

export class WebGPUBackend implements RenderBackend {
  private readonly ctx: GpuContext;
  private readonly modules: ShaderModules;
  private readonly filmlabPipeline: GPURenderPipeline;
  private readonly flagsBuffer: GPUBuffer;
  private readonly flagsBindGroup: GPUBindGroup;
  private readonly sampler: GPUSampler;
  private mediaTexture: GPUTexture | null = null;
  private _width = 1;
  private _height = 1;
  private destroyed = false;

  private constructor(
    ctx: GpuContext,
    modules: ShaderModules,
    filmlabPipeline: GPURenderPipeline,
    flagsBuffer: GPUBuffer,
    flagsBindGroup: GPUBindGroup,
    sampler: GPUSampler,
  ) {
    this.ctx = ctx;
    this.modules = modules;
    this.filmlabPipeline = filmlabPipeline;
    this.flagsBuffer = flagsBuffer;
    this.flagsBindGroup = flagsBindGroup;
    this.sampler = sampler;
    this._width = ctx.canvas.width;
    this._height = ctx.canvas.height;
  }

  static async create(
    canvas: HTMLCanvasElement,
    opts: WebGPUBackendCreateOptions = {},
  ): Promise<WebGPUBackend> {
    const ctx = await GpuContext.create(canvas, { validation: opts.validation });
    const { device } = ctx;

    const make = async (label: string, code: string): Promise<GPUShaderModule> => {
      return ctx.withValidationScope(() =>
        device.createShaderModule({ label, code }),
      );
    };

    const modules: ShaderModules = {
      vert: await make("fullscreen.vert", fullscreenVertexWgsl),
      filmlab: await make("filmlab.identity.frag", filmlabFragmentWgsl),
      bloomPrefilter: await make("bloom-prefilter.frag", bloomPrefilterFragmentWgsl),
      halationPrefilter: await make("halation-prefilter.frag", halationPrefilterFragmentWgsl),
      downsample: await make("downsample.frag", downsampleFragmentWgsl),
      upsample: await make("upsample.frag", upsampleFragmentWgsl),
      lightshafts: await make("lightshafts.frag", lightshaftsFragmentWgsl),
      lightshaftsBlend: await make("lightshafts-blend.frag", lightshaftsBlendFragmentWgsl),
      dust: await make("dust.frag", dustFragmentWgsl),
    };

    // Group 0 = per-frame flags (shared by all pipelines via the vertex
    // shader). Group 1 = per-pass textures / params — filmlab identity uses
    // one texture + sampler.
    const flagsLayout = device.createBindGroupLayout({
      label: "group0.flags",
      entries: [
        { binding: 0, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } },
      ],
    });
    const filmlabTexLayout = device.createBindGroupLayout({
      label: "filmlab.tex",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });
    const filmlabPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "filmlab.identity",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, filmlabTexLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.filmlab,
          entryPoint: "fs_main",
          targets: [{ format: ctx.canvasFormat }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const flagsBuffer = device.createBuffer({
      label: "frame.flags",
      size: 16,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(flagsBuffer, 0, new Float32Array([0, 0, 0, 0]));
    const flagsBindGroup = device.createBindGroup({
      label: "frame.flags.bg",
      layout: flagsLayout,
      entries: [{ binding: 0, resource: { buffer: flagsBuffer } }],
    });

    const sampler = device.createSampler({
      label: "filtering",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
      magFilter: "linear",
      minFilter: "linear",
      mipmapFilter: "nearest",
    });

    return new WebGPUBackend(
      ctx,
      modules,
      filmlabPipeline,
      flagsBuffer,
      flagsBindGroup,
      sampler,
    );
  }

  setMediaFromBitmap(bitmap: ImageBitmap): void {
    if (this.mediaTexture) this.mediaTexture.destroy();
    this.mediaTexture = MediaTexture.fromImageBitmap(this.ctx.device, bitmap);
  }

  setFlipY(flip: boolean): void {
    this.ctx.device.queue.writeBuffer(
      this.flagsBuffer,
      0,
      new Float32Array([flip ? 1 : 0, 0, 0, 0]),
    );
  }

  render(): void {
    if (this.destroyed || !this.mediaTexture) return;
    const { device } = this.ctx;
    const encoder = device.createCommandEncoder({ label: "filmtone.frame" });
    const view = this.ctx.getCurrentTextureView();

    const texBg = device.createBindGroup({
      label: "filmlab.tex.bg",
      layout: this.filmlabPipeline.getBindGroupLayout(1),
      entries: [
        { binding: 0, resource: this.mediaTexture.createView() },
        { binding: 1, resource: this.sampler },
      ],
    });

    const pass = encoder.beginRenderPass({
      label: "filmlab.pass",
      colorAttachments: [
        {
          view,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(this.filmlabPipeline);
    pass.setBindGroup(0, this.flagsBindGroup);
    pass.setBindGroup(1, texBg);
    pass.draw(3, 1, 0, 0);
    pass.end();
    device.queue.submit([encoder.finish()]);
  }

  setResolution(width: number, height: number): void {
    const w = Math.max(1, Math.floor(width));
    const h = Math.max(1, Math.floor(height));
    if (w === this._width && h === this._height) return;
    this.ctx.canvas.width = w;
    this.ctx.canvas.height = h;
    this._width = w;
    this._height = h;
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.mediaTexture?.destroy();
    this.flagsBuffer.destroy();
    this.ctx.destroy();
  }

  get width(): number {
    return this._width;
  }
  get height(): number {
    return this._height;
  }
}
