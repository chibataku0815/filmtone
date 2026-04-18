/**
 * WebGPUBackend — Phase 2 T2-1.
 *
 * Responsibilities:
 *   - `create(canvas)` factory bootstraps GpuContext, compiles all WGSL
 *     modules, and builds two render pipelines:
 *       1. filmlab → rtColorGraded (`rgba16float`) — primary grade +
 *          LUT1 sampling per DIRECTION §3 steps 1–12.
 *       2. blit → swap (`rgba8unorm-srgb`) — reads rtColorGraded and
 *          relies on hardware OETF for the final linear → sRGB transform.
 *   - `setParams(record)` merges grade params and writes them into the
 *     `GradeUniforms` buffer on the next render.
 *   - `setLUT1(data, size)` uploads a new 3D LUT (rgba16float). An
 *     identity LUT is pre-uploaded at construction so the filmlab bind
 *     group is always valid.
 *   - `setMediaFromBitmap` / `setImageResolution` / `setFitMode` /
 *     `setTime` feed the remaining frame state into the uniforms.
 *
 * Still pending (Phase 2 T2-2 → T2-4):
 *   - Soft-shaper + LUT2 + print stage in filmlab.wgsl.
 *   - Bloom / halation pyramid composition.
 *   - Motion blur ring buffer.
 *   - Cross-filter chain.
 */

import { GpuContext } from "./GpuContext";
import { MediaTexture } from "./MediaTexture";
import { OffscreenTargetPool } from "./OffscreenTargetPool";
import { Lut3DTexture } from "./Lut3DTexture";
import {
  fullscreenVertexWgsl,
  filmlabFragmentWgsl,
  blitFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  dustFragmentWgsl,
} from "./shaders";
import {
  GRADE_UNIFORM_BYTES,
  GRADE_UNIFORM_FLOATS,
  packGradeUniforms,
  type GradeFrameState,
} from "./gradeUniforms";
import type { RenderBackend, RenderBackendParams } from "./Backend";

const IDENTITY_LUT_SIZE = 33;

export interface WebGPUBackendCreateOptions {
  validation?: boolean;
}

interface ShaderModules {
  vert: GPUShaderModule;
  filmlab: GPUShaderModule;
  blit: GPUShaderModule;
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
  private readonly pool: OffscreenTargetPool;
  private readonly filmlabPipeline: GPURenderPipeline;
  private readonly blitPipeline: GPURenderPipeline;
  private readonly flagsBuffer: GPUBuffer;
  private readonly flagsBindGroup: GPUBindGroup;
  private readonly gradeBuffer: GPUBuffer;
  private readonly sampler: GPUSampler;
  private readonly gradeScratch = new Float32Array(GRADE_UNIFORM_FLOATS);

  private mediaTexture: GPUTexture | null = null;
  private lut1Texture: GPUTexture;
  private _width = 1;
  private _height = 1;
  private destroyed = false;
  private gradeDirty = true;
  private frameState: GradeFrameState;

  private constructor(
    ctx: GpuContext,
    modules: ShaderModules,
    pool: OffscreenTargetPool,
    filmlabPipeline: GPURenderPipeline,
    blitPipeline: GPURenderPipeline,
    flagsBuffer: GPUBuffer,
    flagsBindGroup: GPUBindGroup,
    gradeBuffer: GPUBuffer,
    sampler: GPUSampler,
    lut1Texture: GPUTexture,
  ) {
    this.ctx = ctx;
    this.modules = modules;
    this.pool = pool;
    this.filmlabPipeline = filmlabPipeline;
    this.blitPipeline = blitPipeline;
    this.flagsBuffer = flagsBuffer;
    this.flagsBindGroup = flagsBindGroup;
    this.gradeBuffer = gradeBuffer;
    this.sampler = sampler;
    this.lut1Texture = lut1Texture;
    this._width = Math.max(1, ctx.canvas.width);
    this._height = Math.max(1, ctx.canvas.height);
    this.frameState = {
      resolutionX: this._width,
      resolutionY: this._height,
      imgResX: this._width,
      imgResY: this._height,
      fitMode: 0,
      time: 0,
      splitPosition: -1,
      params: {},
      lut1Intensity: 1,
      lut1Enabled: false,
      lut2Intensity: 1,
      lut2Enabled: false,
    };
  }

  static async create(
    canvas: HTMLCanvasElement,
    opts: WebGPUBackendCreateOptions = {},
  ): Promise<WebGPUBackend> {
    const ctx = await GpuContext.create(canvas, { validation: opts.validation });
    const { device } = ctx;

    const make = async (label: string, code: string): Promise<GPUShaderModule> =>
      ctx.withValidationScope(() => device.createShaderModule({ label, code }));

    const modules: ShaderModules = {
      vert: await make("fullscreen.vert", fullscreenVertexWgsl),
      filmlab: await make("filmlab.frag", filmlabFragmentWgsl),
      blit: await make("blit.frag", blitFragmentWgsl),
      bloomPrefilter: await make("bloom-prefilter.frag", bloomPrefilterFragmentWgsl),
      halationPrefilter: await make("halation-prefilter.frag", halationPrefilterFragmentWgsl),
      downsample: await make("downsample.frag", downsampleFragmentWgsl),
      upsample: await make("upsample.frag", upsampleFragmentWgsl),
      lightshafts: await make("lightshafts.frag", lightshaftsFragmentWgsl),
      lightshaftsBlend: await make("lightshafts-blend.frag", lightshaftsBlendFragmentWgsl),
      dust: await make("dust.frag", dustFragmentWgsl),
    };

    const flagsLayout = device.createBindGroupLayout({
      label: "group0.flags",
      entries: [
        { binding: 0, visibility: GPUShaderStage.VERTEX, buffer: { type: "uniform" } },
      ],
    });

    const filmlabGroupLayout = device.createBindGroupLayout({
      label: "filmlab.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
        {
          binding: 3,
          visibility: GPUShaderStage.FRAGMENT,
          texture: { sampleType: "float", viewDimension: "3d" },
        },
      ],
    });

    const filmlabPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "filmlab.primary",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, filmlabGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.filmlab,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const blitGroupLayout = device.createBindGroupLayout({
      label: "blit.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const blitPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "blit.present",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, blitGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.blit,
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

    const gradeBuffer = device.createBuffer({
      label: "grade.uniforms",
      size: GRADE_UNIFORM_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const sampler = device.createSampler({
      label: "filtering",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
      addressModeW: "clamp-to-edge",
      magFilter: "linear",
      minFilter: "linear",
      mipmapFilter: "nearest",
    });

    const identityLut = Lut3DTexture.upload(
      device,
      Lut3DTexture.identity(IDENTITY_LUT_SIZE),
      IDENTITY_LUT_SIZE,
      { label: "lut1.identity" },
    );

    const pool = new OffscreenTargetPool(device);

    return new WebGPUBackend(
      ctx,
      modules,
      pool,
      filmlabPipeline,
      blitPipeline,
      flagsBuffer,
      flagsBindGroup,
      gradeBuffer,
      sampler,
      identityLut,
    );
  }

  setMediaFromBitmap(bitmap: ImageBitmap): void {
    if (this.mediaTexture) this.mediaTexture.destroy();
    this.mediaTexture = MediaTexture.fromImageBitmap(this.ctx.device, bitmap);
    this.setImageResolution(bitmap.width, bitmap.height);
  }

  setImageResolution(width: number, height: number): void {
    this.frameState.imgResX = Math.max(1, width);
    this.frameState.imgResY = Math.max(1, height);
    this.gradeDirty = true;
  }

  setFitMode(mode: "cover" | "contain"): void {
    this.frameState.fitMode = mode === "contain" ? 1 : 0;
    this.gradeDirty = true;
  }

  setTime(time: number): void {
    this.frameState.time = time;
    this.gradeDirty = true;
  }

  setSplitPosition(position: number): void {
    this.frameState.splitPosition = position;
    this.gradeDirty = true;
  }

  setLUT1(data: Float32Array, size: number): void {
    this.lut1Texture.destroy();
    this.lut1Texture = Lut3DTexture.upload(this.ctx.device, data, size, {
      label: "lut1",
    });
    this.frameState.lut1Enabled = true;
    this.gradeDirty = true;
  }

  setLUT1Intensity(value: number): void {
    this.frameState.lut1Intensity = value;
    this.gradeDirty = true;
  }

  clearLUT1(): void {
    this.lut1Texture.destroy();
    this.lut1Texture = Lut3DTexture.upload(
      this.ctx.device,
      Lut3DTexture.identity(IDENTITY_LUT_SIZE),
      IDENTITY_LUT_SIZE,
      { label: "lut1.identity" },
    );
    this.frameState.lut1Enabled = false;
    this.gradeDirty = true;
  }

  setParams(params: RenderBackendParams): void {
    this.frameState.params = { ...this.frameState.params, ...params };
    this.gradeDirty = true;
  }

  setFlipY(flip: boolean): void {
    this.ctx.device.queue.writeBuffer(
      this.flagsBuffer,
      0,
      new Float32Array([flip ? 1 : 0, 0, 0, 0]),
    );
  }

  getPendingParams(): Readonly<RenderBackendParams> {
    return this.frameState.params;
  }

  private uploadGradeIfDirty(): void {
    if (!this.gradeDirty) return;
    packGradeUniforms(this.frameState, this.gradeScratch);
    this.ctx.device.queue.writeBuffer(
      this.gradeBuffer,
      0,
      this.gradeScratch.buffer,
      this.gradeScratch.byteOffset,
      this.gradeScratch.byteLength,
    );
    this.gradeDirty = false;
  }

  render(): void {
    if (this.destroyed || !this.mediaTexture) return;
    const { device } = this.ctx;
    this.uploadGradeIfDirty();

    const rtColorGraded = this.pool.get("rt.colorGraded", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });

    const encoder = device.createCommandEncoder({ label: "filmtone.frame" });

    // Pass 1 — primary grade into rgba16float offscreen.
    const filmlabBg = device.createBindGroup({
      label: "filmlab.bg",
      layout: this.filmlabPipeline.getBindGroupLayout(1),
      entries: [
        { binding: 0, resource: { buffer: this.gradeBuffer } },
        { binding: 1, resource: this.mediaTexture.createView() },
        { binding: 2, resource: this.sampler },
        {
          binding: 3,
          resource: this.lut1Texture.createView({ dimension: "3d" }),
        },
      ],
    });
    {
      const pass = encoder.beginRenderPass({
        label: "filmlab.pass",
        colorAttachments: [
          {
            view: rtColorGraded.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.filmlabPipeline);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, filmlabBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Pass 2 — blit rgba16float → swap (hw sRGB OETF).
    const swapView = this.ctx.getCurrentTextureView();
    const blitBg = device.createBindGroup({
      label: "blit.bg",
      layout: this.blitPipeline.getBindGroupLayout(1),
      entries: [
        { binding: 0, resource: rtColorGraded.createView() },
        { binding: 1, resource: this.sampler },
      ],
    });
    {
      const pass = encoder.beginRenderPass({
        label: "blit.pass",
        colorAttachments: [
          {
            view: swapView,
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.blitPipeline);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, blitBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

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
    this.frameState.resolutionX = w;
    this.frameState.resolutionY = h;
    this.gradeDirty = true;
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.mediaTexture?.destroy();
    this.lut1Texture.destroy();
    this.flagsBuffer.destroy();
    this.gradeBuffer.destroy();
    this.pool.destroy();
    this.ctx.destroy();
  }

  get width(): number {
    return this._width;
  }
  get height(): number {
    return this._height;
  }
}
