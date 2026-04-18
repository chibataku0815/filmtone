/**
 * WebGPUBackend — Phase 2 T2-1 + T2-2 + T2-0b + T2-3 + T2-4.
 *
 * Full v1.0 render pipeline:
 *   1. filmlab → rt.colorGraded (`rgba16float`) — LUT1 → primary grade
 *      (DIRECTION §3 steps 1–12) → Reinhard soft-shaper → LUT2 → print
 *      CMY → print contrast.
 *   2. bloomPrefilter → bloom.L0; downsample chain → bloom.L[1..4];
 *      upsample chain with additive blend back to bloom.L0 (5 mips total,
 *      WebGL parity).
 *   3. halationPrefilter → halation.L0; downsample chain → halation.L[1..5];
 *      upsample chain with additive blend back to halation.L0 (6 mips).
 *   4. composite → rt.composited (`rgba16float`) — screen-blend glow
 *      shoulder, vignette, blue-noise grain (256² tile, DIRECTION §2).
 *   5. Post-chain:
 *      - Motion blur ON (`shutterAngle > 0`): feedback copy into the
 *        ring (`depthOrArrayLayers=8`, DIRECTION §4) → weighted blend of
 *        the last N slots → swap.
 *      - Motion blur OFF: blit rt.composited → swap.
 *
 *   The swap pass output is always `rgba8unorm-srgb` so the hardware OETF
 *   handles the final linear → sRGB transform.
 *
 * Consumer API:
 *   - `setParams(record)` merges the full grade + post params blob; the
 *     uniforms it feeds are split between `GradeUniforms` (filmlab) and
 *     `CompositeUniforms` (bloom strength / halation intensity / grain /
 *     vignette). Bloom + halation shaping params (threshold, knee, radius,
 *     color) and motion blur (`shutterAngle`, `trailIntensity`,
 *     `motionThreshold`) are consumed directly by the post-chain
 *     bookkeeping.
 *   - `setLUT1` / `setLUT2` upload 3D LUTs (identity pre-uploaded at
 *     construction so the filmlab bind group is always valid).
 *   - `setMediaFromBitmap` / `setImageResolution` / `setFitMode` /
 *     `setTime` feed the remaining frame state.
 *
 * Still pending (Phase 3):
 *   - Cross-filter chain (Hard Mode temporal deferred to v1.1 per D5),
 *     diffusion, split/A-B compare, dust.
 */

import {
  GpuContext,
  type GpuContextLossInfo,
  type GpuContextLossReason,
} from "./GpuContext";
import { MediaTexture } from "./MediaTexture";
import { OffscreenTargetPool } from "./OffscreenTargetPool";
import { Lut3DTexture } from "./Lut3DTexture";
import { BlueNoiseTile } from "./BlueNoiseTile";
import { RingBuffer, MOTION_BLUR_RING_SLOTS } from "./RingBuffer";
import {
  fullscreenVertexWgsl,
  filmlabFragmentWgsl,
  blitFragmentWgsl,
  compositeFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  dustFragmentWgsl,
  motionblurFeedbackFragmentWgsl,
  motionblurBlendFragmentWgsl,
  crossFilterPeakFragmentWgsl,
  crossFilterPeakSpacingMaxFragmentWgsl,
  crossFilterPeakSpacingFragmentWgsl,
  crossFilterStreakFragmentWgsl,
  crossFilterBlendFragmentWgsl,
} from "./shaders";
import {
  GRADE_UNIFORM_BYTES,
  GRADE_UNIFORM_FLOATS,
  packGradeUniforms,
  type GradeFrameState,
} from "./gradeUniforms";
import {
  COMPOSITE_UNIFORM_BYTES,
  COMPOSITE_UNIFORM_FLOATS,
  hexToRgbTriple,
  packCompositeUniforms,
  type CompositeFrameState,
} from "./compositeUniforms";
import type { RenderBackend, RenderBackendParams } from "./Backend";
import type { ViewportCapabilities } from "../RendererRuntime";

const IDENTITY_LUT_SIZE = 33;
const BLOOM_LEVELS = 5;
const HALATION_LEVELS = 6;
const BLOOM_PARAMS_BYTES = 16;
const HALATION_PARAMS_BYTES = 32;
const PYRAMID_LEVEL_UNIFORM_BYTES = 16;
const MOTIONBLUR_FEEDBACK_UNIFORM_BYTES = 16;
/** weights (2 vec4) + ring control (1 vec4) = 48 bytes. */
const MOTIONBLUR_BLEND_UNIFORM_BYTES = 48;
const MOTIONBLUR_BLEND_UNIFORM_FLOATS = MOTIONBLUR_BLEND_UNIFORM_BYTES / 4;

const DEFAULT_BLOOM_THRESHOLD = 0.8;
const DEFAULT_BLOOM_KNEE = 0.5;
const DEFAULT_BLOOM_RADIUS = 0.5;
const DEFAULT_HALATION_THRESHOLD = 0.6;
const DEFAULT_HALATION_KNEE = 0.5;
const DEFAULT_HALATION_RADIUS = 0.5;
const DEFAULT_HALATION_COLOR: [number, number, number] = [0.91, 0.063, 0.125];

export interface WebGPUBackendCreateOptions {
  validation?: boolean;
}

interface ShaderModules {
  vert: GPUShaderModule;
  filmlab: GPUShaderModule;
  blit: GPUShaderModule;
  composite: GPUShaderModule;
  bloomPrefilter: GPUShaderModule;
  halationPrefilter: GPUShaderModule;
  downsample: GPUShaderModule;
  upsample: GPUShaderModule;
  lightshafts: GPUShaderModule;
  lightshaftsBlend: GPUShaderModule;
  dust: GPUShaderModule;
  motionblurFeedback: GPUShaderModule;
  motionblurBlend: GPUShaderModule;
  crossFilterPeak: GPUShaderModule;
  crossFilterPeakSpacingMax: GPUShaderModule;
  crossFilterPeakSpacing: GPUShaderModule;
  crossFilterStreak: GPUShaderModule;
  crossFilterBlend: GPUShaderModule;
}

interface Pipelines {
  filmlab: GPURenderPipeline;
  bloomPrefilter: GPURenderPipeline;
  halationPrefilter: GPURenderPipeline;
  downsample: GPURenderPipeline;
  /** Same shader as `downsample` / `upsample`-compatible layout, additive blend. */
  upsampleAdd: GPURenderPipeline;
  composite: GPURenderPipeline;
  /** Final swap when motion blur is OFF — rgba16float → rgba8unorm-srgb hw OETF. */
  blit: GPURenderPipeline;
  /** Writes current composited frame into ring[newSlot], mixing ring[prevSlot] when trail > 0. */
  motionblurFeedback: GPURenderPipeline;
  /** N-slot weighted average → swap. */
  motionblurBlend: GPURenderPipeline;
}

interface PrefilterGroupLayouts {
  bloom: GPUBindGroupLayout;
  halation: GPUBindGroupLayout;
  pyramid: GPUBindGroupLayout;
  composite: GPUBindGroupLayout;
  blit: GPUBindGroupLayout;
  motionblurFeedback: GPUBindGroupLayout;
  motionblurBlend: GPUBindGroupLayout;
}

/**
 * Pre-allocated pyramid resources. Uniform buffers are sized up-front so a
 * single submit() never collides multiple `writeBuffer` calls on the same
 * buffer. Textures live in `OffscreenTargetPool` and are keyed by label so
 * resize swaps transparently.
 */
interface PyramidResources {
  readonly downsample: GPUBuffer[]; // length = levels - 1
  readonly upsample: GPUBuffer[]; // length = levels - 1
  readonly downsampleScratch: Float32Array[];
  readonly upsampleScratch: Float32Array[];
}

export class WebGPUBackend implements RenderBackend {
  private readonly ctx: GpuContext;
  readonly capabilities: ViewportCapabilities;
  private readonly modules: ShaderModules;
  private readonly pool: OffscreenTargetPool;
  private readonly pipelines: Pipelines;
  private readonly layouts: PrefilterGroupLayouts;
  private readonly flagsBuffer: GPUBuffer;
  private readonly flagsBindGroup: GPUBindGroup;
  private readonly gradeBuffer: GPUBuffer;
  private readonly compositeBuffer: GPUBuffer;
  private readonly bloomParamsBuffer: GPUBuffer;
  private readonly halationParamsBuffer: GPUBuffer;
  private readonly bloomPyramid: PyramidResources;
  private readonly halationPyramid: PyramidResources;
  private readonly motionblurFeedbackBuffer: GPUBuffer;
  private readonly motionblurBlendBuffer: GPUBuffer;
  private readonly sampler: GPUSampler;
  private readonly grainSampler: GPUSampler;
  private readonly grainTexture: GPUTexture;
  private readonly gradeScratch = new Float32Array(GRADE_UNIFORM_FLOATS);
  private readonly compositeScratch = new Float32Array(COMPOSITE_UNIFORM_FLOATS);
  private readonly bloomParamsScratch = new Float32Array(BLOOM_PARAMS_BYTES / 4);
  private readonly halationParamsScratch = new Float32Array(HALATION_PARAMS_BYTES / 4);
  private readonly motionblurFeedbackScratch = new Float32Array(4);
  private readonly motionblurBlendScratch = new Float32Array(MOTIONBLUR_BLEND_UNIFORM_FLOATS);

  private mediaTexture: GPUTexture | null = null;
  private placeholderTexture: GPUTexture | null = null;
  private liveVideoElement: HTMLVideoElement | null = null;
  private lut1Texture: GPUTexture;
  private lut2Texture: GPUTexture;
  private ringBuffer: RingBuffer;
  private _width = 1;
  private _height = 1;
  private destroyed = false;
  private gradeDirty = true;
  private frameState: GradeFrameState;

  private constructor(
    ctx: GpuContext,
    modules: ShaderModules,
    pool: OffscreenTargetPool,
    pipelines: Pipelines,
    layouts: PrefilterGroupLayouts,
    flagsBuffer: GPUBuffer,
    flagsBindGroup: GPUBindGroup,
    gradeBuffer: GPUBuffer,
    compositeBuffer: GPUBuffer,
    bloomParamsBuffer: GPUBuffer,
    halationParamsBuffer: GPUBuffer,
    bloomPyramid: PyramidResources,
    halationPyramid: PyramidResources,
    motionblurFeedbackBuffer: GPUBuffer,
    motionblurBlendBuffer: GPUBuffer,
    sampler: GPUSampler,
    grainSampler: GPUSampler,
    grainTexture: GPUTexture,
    lut1Texture: GPUTexture,
    lut2Texture: GPUTexture,
    ringBuffer: RingBuffer,
  ) {
    this.ctx = ctx;
    this.capabilities = ctx.capabilities;
    this.modules = modules;
    this.pool = pool;
    this.pipelines = pipelines;
    this.layouts = layouts;
    this.flagsBuffer = flagsBuffer;
    this.flagsBindGroup = flagsBindGroup;
    this.gradeBuffer = gradeBuffer;
    this.compositeBuffer = compositeBuffer;
    this.bloomParamsBuffer = bloomParamsBuffer;
    this.halationParamsBuffer = halationParamsBuffer;
    this.bloomPyramid = bloomPyramid;
    this.halationPyramid = halationPyramid;
    this.motionblurFeedbackBuffer = motionblurFeedbackBuffer;
    this.motionblurBlendBuffer = motionblurBlendBuffer;
    this.sampler = sampler;
    this.grainSampler = grainSampler;
    this.grainTexture = grainTexture;
    this.lut1Texture = lut1Texture;
    this.lut2Texture = lut2Texture;
    this.ringBuffer = ringBuffer;
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
      composite: await make("composite.frag", compositeFragmentWgsl),
      bloomPrefilter: await make("bloom-prefilter.frag", bloomPrefilterFragmentWgsl),
      halationPrefilter: await make("halation-prefilter.frag", halationPrefilterFragmentWgsl),
      downsample: await make("downsample.frag", downsampleFragmentWgsl),
      upsample: await make("upsample.frag", upsampleFragmentWgsl),
      lightshafts: await make("lightshafts.frag", lightshaftsFragmentWgsl),
      lightshaftsBlend: await make("lightshafts-blend.frag", lightshaftsBlendFragmentWgsl),
      dust: await make("dust.frag", dustFragmentWgsl),
      motionblurFeedback: await make("motionblur-feedback.frag", motionblurFeedbackFragmentWgsl),
      motionblurBlend: await make("motionblur-blend.frag", motionblurBlendFragmentWgsl),
      // Cross-filter chain (Phase 3 T3-1). Compile-validated here so
      // GPU-side WGSL correctness is guaranteed at backend init; runtime
      // render integration lives in `renderCrossFilter` (no-op when
      // crossFilterStrength === 0 — all 8 v1.0 presets ship with 0).
      crossFilterPeak: await make("cross-filter-peak.frag", crossFilterPeakFragmentWgsl),
      crossFilterPeakSpacingMax: await make(
        "cross-filter-peak-spacing-max.frag",
        crossFilterPeakSpacingMaxFragmentWgsl,
      ),
      crossFilterPeakSpacing: await make(
        "cross-filter-peak-spacing.frag",
        crossFilterPeakSpacingFragmentWgsl,
      ),
      crossFilterStreak: await make("cross-filter-streak.frag", crossFilterStreakFragmentWgsl),
      crossFilterBlend: await make("cross-filter-blend.frag", crossFilterBlendFragmentWgsl),
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
        {
          binding: 4,
          visibility: GPUShaderStage.FRAGMENT,
          texture: { sampleType: "float", viewDimension: "3d" },
        },
      ],
    });

    // Shared layout across bloom-prefilter / halation-prefilter /
    // downsample / upsample — all take `(params uniform, source texture,
    // sampler)` as group(1). Uniform-buffer contents differ per pass but
    // the binding shape is identical.
    const pyramidGroupLayout = device.createBindGroupLayout({
      label: "pyramid.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const compositeGroupLayout = device.createBindGroupLayout({
      label: "composite.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 4, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 5, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
        { binding: 6, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const blitGroupLayout = device.createBindGroupLayout({
      label: "blit.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const motionblurFeedbackGroupLayout = device.createBindGroupLayout({
      label: "motionblur.feedback.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const motionblurBlendGroupLayout = device.createBindGroupLayout({
      label: "motionblur.blend.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        {
          binding: 1,
          visibility: GPUShaderStage.FRAGMENT,
          texture: { sampleType: "float", viewDimension: "2d-array" },
        },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
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

    const pyramidPipelineLayout = device.createPipelineLayout({
      bindGroupLayouts: [flagsLayout, pyramidGroupLayout],
    });

    const bloomPrefilterPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "bloom.prefilter",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.bloomPrefilter,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const halationPrefilterPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "halation.prefilter",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.halationPrefilter,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const downsamplePipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "pyramid.downsample",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.downsample,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const upsampleAddPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "pyramid.upsample.add",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.upsample,
          entryPoint: "fs_main",
          targets: [
            {
              format: "rgba16float",
              blend: {
                color: { srcFactor: "one", dstFactor: "one", operation: "add" },
                alpha: { srcFactor: "one", dstFactor: "one", operation: "add" },
              },
            },
          ],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    // Composite now writes to an `rgba16float` intermediate so the
    // optional motion-blur post-chain can feed that output into the
    // ring. When motion blur is OFF the `blit` pipeline fans it out to
    // the swap unchanged.
    const compositePipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "composite.rt",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, compositeGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.composite,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

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

    const motionblurFeedbackPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "motionblur.feedback",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, motionblurFeedbackGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.motionblurFeedback,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const motionblurBlendPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "motionblur.blend.present",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, motionblurBlendGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.motionblurBlend,
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

    const compositeBuffer = device.createBuffer({
      label: "composite.uniforms",
      size: COMPOSITE_UNIFORM_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const bloomParamsBuffer = device.createBuffer({
      label: "bloom.prefilter.params",
      size: BLOOM_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const halationParamsBuffer = device.createBuffer({
      label: "halation.prefilter.params",
      size: HALATION_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const makePyramid = (label: string, levels: number): PyramidResources => {
      const downsample: GPUBuffer[] = [];
      const upsample: GPUBuffer[] = [];
      const downsampleScratch: Float32Array[] = [];
      const upsampleScratch: Float32Array[] = [];
      for (let i = 0; i < levels - 1; i++) {
        downsample.push(
          device.createBuffer({
            label: `${label}.downsample.${i}`,
            size: PYRAMID_LEVEL_UNIFORM_BYTES,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
          }),
        );
        upsample.push(
          device.createBuffer({
            label: `${label}.upsample.${i}`,
            size: PYRAMID_LEVEL_UNIFORM_BYTES,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
          }),
        );
        downsampleScratch.push(new Float32Array(4));
        upsampleScratch.push(new Float32Array(4));
      }
      return { downsample, upsample, downsampleScratch, upsampleScratch };
    };

    const bloomPyramid = makePyramid("bloom", BLOOM_LEVELS);
    const halationPyramid = makePyramid("halation", HALATION_LEVELS);

    const motionblurFeedbackBuffer = device.createBuffer({
      label: "motionblur.feedback.params",
      size: MOTIONBLUR_FEEDBACK_UNIFORM_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const motionblurBlendBuffer = device.createBuffer({
      label: "motionblur.blend.params",
      size: MOTIONBLUR_BLEND_UNIFORM_BYTES,
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

    const grainSampler = device.createSampler({
      label: "grain.repeat",
      addressModeU: "repeat",
      addressModeV: "repeat",
      magFilter: "linear",
      minFilter: "linear",
    });

    const grainTexture = BlueNoiseTile.load(device);

    const identityLut1 = Lut3DTexture.upload(
      device,
      Lut3DTexture.identity(IDENTITY_LUT_SIZE),
      IDENTITY_LUT_SIZE,
      { label: "lut1.identity" },
    );
    const identityLut2 = Lut3DTexture.upload(
      device,
      Lut3DTexture.identity(IDENTITY_LUT_SIZE),
      IDENTITY_LUT_SIZE,
      { label: "lut2.identity" },
    );

    const pool = new OffscreenTargetPool(device);

    const ringBuffer = new RingBuffer(device, {
      width: Math.max(1, canvas.width),
      height: Math.max(1, canvas.height),
      format: "rgba16float",
      label: "motion-blur.ring",
    });

    return new WebGPUBackend(
      ctx,
      modules,
      pool,
      {
        filmlab: filmlabPipeline,
        bloomPrefilter: bloomPrefilterPipeline,
        halationPrefilter: halationPrefilterPipeline,
        downsample: downsamplePipeline,
        upsampleAdd: upsampleAddPipeline,
        composite: compositePipeline,
        blit: blitPipeline,
        motionblurFeedback: motionblurFeedbackPipeline,
        motionblurBlend: motionblurBlendPipeline,
      },
      {
        bloom: pyramidGroupLayout,
        halation: pyramidGroupLayout,
        pyramid: pyramidGroupLayout,
        composite: compositeGroupLayout,
        blit: blitGroupLayout,
        motionblurFeedback: motionblurFeedbackGroupLayout,
        motionblurBlend: motionblurBlendGroupLayout,
      },
      flagsBuffer,
      flagsBindGroup,
      gradeBuffer,
      compositeBuffer,
      bloomParamsBuffer,
      halationParamsBuffer,
      bloomPyramid,
      halationPyramid,
      motionblurFeedbackBuffer,
      motionblurBlendBuffer,
      sampler,
      grainSampler,
      grainTexture,
      identityLut1,
      identityLut2,
      ringBuffer,
    );
  }

  setMediaFromBitmap(bitmap: ImageBitmap): void {
    this.liveVideoElement = null;
    if (this.mediaTexture) this.mediaTexture.destroy();
    this.mediaTexture = MediaTexture.fromImageBitmap(this.ctx.device, bitmap);
    this.setImageResolution(bitmap.width, bitmap.height);
  }

  setMediaFromVideoElement(video: HTMLVideoElement): void {
    this.liveVideoElement = video;
    this.refreshLiveVideoTexture();
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.setMediaFromVideoElement(video);
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

  getSplitPosition(): number {
    return this.frameState.splitPosition;
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

  setLUT2(data: Float32Array, size: number): void {
    this.lut2Texture.destroy();
    this.lut2Texture = Lut3DTexture.upload(this.ctx.device, data, size, {
      label: "lut2",
    });
    this.frameState.lut2Enabled = true;
    this.gradeDirty = true;
  }

  setLUT2Intensity(value: number): void {
    this.frameState.lut2Intensity = value;
    this.gradeDirty = true;
  }

  clearLUT2(): void {
    this.lut2Texture.destroy();
    this.lut2Texture = Lut3DTexture.upload(
      this.ctx.device,
      Lut3DTexture.identity(IDENTITY_LUT_SIZE),
      IDENTITY_LUT_SIZE,
      { label: "lut2.identity" },
    );
    this.frameState.lut2Enabled = false;
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

  getMaxTextureDimension2D(): number {
    return this.capabilities.maxTextureDimension2D;
  }

  isContextLost(): boolean {
    return this.ctx.isContextLost();
  }

  getContextLossInfo(): GpuContextLossInfo | null {
    return this.ctx.getContextLossInfo();
  }

  onContextLost(listener: (info: GpuContextLossInfo) => void): () => void {
    return this.ctx.onContextLost(listener);
  }

  reportFatalContextLoss(
    reason: Exclude<GpuContextLossReason, "device-lost">,
    error?: unknown,
  ): void {
    this.ctx.reportFatalLoss(reason, error);
  }

  prewarm(): void {
    this.renderInternal("prewarm-failed");
  }

  private refreshLiveVideoTexture(): void {
    const video = this.liveVideoElement;
    if (!video) return;
    const width = video.videoWidth || 0;
    const height = video.videoHeight || 0;
    const readyState =
      typeof video.readyState === "number" ? video.readyState : 0;
    if (width <= 0 || height <= 0 || readyState < 2) return;
    try {
      this.mediaTexture = MediaTexture.fromVideoElement(
        this.ctx.device,
        video,
        this.mediaTexture,
      );
      if (
        width !== this.frameState.imgResX ||
        height !== this.frameState.imgResY
      ) {
        this.setImageResolution(width, height);
      }
    } catch (error) {
      console.warn("[WebGPUBackend] live video upload failed", error);
    }
  }

  private getActiveMediaTexture(
    allowPlaceholder: boolean,
  ): GPUTexture | null {
    if (this.liveVideoElement) {
      this.refreshLiveVideoTexture();
    }
    if (this.mediaTexture) return this.mediaTexture;
    if (!allowPlaceholder) return null;
    if (!this.placeholderTexture) {
      this.placeholderTexture = MediaTexture.createPlaceholder(
        this.ctx.device,
        { label: "media.prewarm.placeholder" },
      );
    }
    return this.placeholderTexture;
  }

  private paramNumber(key: string, fallback: number): number {
    const v = this.frameState.params[key];
    return typeof v === "number" ? v : fallback;
  }

  private paramString(key: string, fallback: string): string {
    const v = this.frameState.params[key];
    return typeof v === "string" ? v : fallback;
  }

  private uploadFrameUniforms(): void {
    const { device } = this.ctx;

    // Grade uniforms — filmlab path.
    if (this.gradeDirty) {
      packGradeUniforms(this.frameState, this.gradeScratch);
      device.queue.writeBuffer(
        this.gradeBuffer,
        0,
        this.gradeScratch.buffer,
        this.gradeScratch.byteOffset,
        this.gradeScratch.byteLength,
      );
      this.gradeDirty = false;
    }

    // Composite uniforms — always refreshed because composite reads time,
    // which is pumped per-frame by the animation loop regardless of
    // dirty-flag bookkeeping.
    const compositeState: CompositeFrameState = {
      resolutionX: this.frameState.resolutionX,
      resolutionY: this.frameState.resolutionY,
      imgResX: this.frameState.imgResX,
      imgResY: this.frameState.imgResY,
      fitMode: this.frameState.fitMode,
      time: this.frameState.time,
      params: this.frameState.params,
    };
    packCompositeUniforms(compositeState, this.compositeScratch);
    device.queue.writeBuffer(
      this.compositeBuffer,
      0,
      this.compositeScratch.buffer,
      this.compositeScratch.byteOffset,
      this.compositeScratch.byteLength,
    );

    // Bloom prefilter params — (threshold, knee, _, _).
    const bloomThreshold = this.paramNumber("bloomThreshold", DEFAULT_BLOOM_THRESHOLD);
    const bloomKnee = this.paramNumber("bloomSoftKnee", DEFAULT_BLOOM_KNEE);
    this.bloomParamsScratch[0] = bloomThreshold;
    this.bloomParamsScratch[1] = bloomKnee;
    this.bloomParamsScratch[2] = 0;
    this.bloomParamsScratch[3] = 0;
    device.queue.writeBuffer(
      this.bloomParamsBuffer,
      0,
      this.bloomParamsScratch.buffer,
      this.bloomParamsScratch.byteOffset,
      this.bloomParamsScratch.byteLength,
    );

    // Halation prefilter params — (color.rgb, threshold) + (knee, _, _, _).
    const halationRawColor = this.paramString("halationColor", "");
    const halationColor =
      halationRawColor.length > 0 ? hexToRgbTriple(halationRawColor) : DEFAULT_HALATION_COLOR;
    const halationThreshold = this.paramNumber(
      "halationThreshold",
      DEFAULT_HALATION_THRESHOLD,
    );
    const halationKnee = this.paramNumber("halationSoftKnee", DEFAULT_HALATION_KNEE);
    this.halationParamsScratch[0] = halationColor[0];
    this.halationParamsScratch[1] = halationColor[1];
    this.halationParamsScratch[2] = halationColor[2];
    this.halationParamsScratch[3] = halationThreshold;
    this.halationParamsScratch[4] = halationKnee;
    this.halationParamsScratch[5] = 0;
    this.halationParamsScratch[6] = 0;
    this.halationParamsScratch[7] = 0;
    device.queue.writeBuffer(
      this.halationParamsBuffer,
      0,
      this.halationParamsScratch.buffer,
      this.halationParamsScratch.byteOffset,
      this.halationParamsScratch.byteLength,
    );
  }

  /**
   * Bloom / halation mip accumulation weights — WebGL parity formula.
   * Smaller `radius` biases energy toward the sharper mips; `radius=1`
   * spreads it outward to the low-freq tails.
   */
  private static computeMipWeights(radius: number, levels: number): number[] {
    const weights: number[] = [];
    for (let i = 0; i < levels; i++) {
      const t = i / Math.max(levels - 1, 1);
      const base = Math.exp(-3.0 * (1.0 - radius) * t);
      const wide = Math.exp(-0.5 * radius * (1.0 - t));
      weights.push(base * (1 - radius) + wide * radius);
    }
    return weights;
  }

  private ensurePyramidLevels(labelPrefix: string, levels: number): GPUTexture[] {
    const out: GPUTexture[] = [];
    for (let i = 0; i < levels; i++) {
      const divisor = 2 ** (i + 1);
      const w = Math.max(1, Math.floor(this._width / divisor));
      const h = Math.max(1, Math.floor(this._height / divisor));
      out.push(
        this.pool.get(`${labelPrefix}.${i}`, {
          width: w,
          height: h,
          format: "rgba16float",
        }),
      );
    }
    return out;
  }

  private renderPyramidChain(
    encoder: GPUCommandEncoder,
    label: string,
    prefilterPipeline: GPURenderPipeline,
    prefilterParamsBuffer: GPUBuffer,
    sourceView: GPUTextureView,
    levels: GPUTexture[],
    pyramid: PyramidResources,
    radius: number,
  ): GPUTexture {
    const { device } = this.ctx;
    const weights = WebGPUBackend.computeMipWeights(radius, levels.length);

    // Step 1 — prefilter: sourceView → levels[0] (clear load, no blend).
    {
      const bg = device.createBindGroup({
        label: `${label}.prefilter.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: prefilterParamsBuffer } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `${label}.prefilter`,
        colorAttachments: [
          {
            view: levels[0]!.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(prefilterPipeline);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 2 — progressive downsample: levels[i-1] → levels[i].
    for (let i = 1; i < levels.length; i++) {
      const src = levels[i - 1]!;
      const dst = levels[i]!;
      const scratch = pyramid.downsampleScratch[i - 1]!;
      scratch[0] = 1 / src.width;
      scratch[1] = 1 / src.height;
      scratch[2] = 0;
      scratch[3] = 0;
      device.queue.writeBuffer(
        pyramid.downsample[i - 1]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `${label}.downsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: pyramid.downsample[i - 1]! } },
          { binding: 1, resource: src.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `${label}.downsample.${i}`,
        colorAttachments: [
          {
            view: dst.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.downsample);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 3 — progressive upsample with additive blend: levels[i+1] into
    // levels[i] (preserve existing downsample contents via `loadOp:
    // "load"`, accumulate with `blend: add/one/one`).
    for (let i = levels.length - 2; i >= 0; i--) {
      const lowRes = levels[i + 1]!;
      const highRes = levels[i]!;
      const scratch = pyramid.upsampleScratch[i]!;
      scratch[0] = 1 / lowRes.width;
      scratch[1] = 1 / lowRes.height;
      scratch[2] = weights[i + 1]!;
      scratch[3] = 0;
      device.queue.writeBuffer(
        pyramid.upsample[i]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `${label}.upsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: pyramid.upsample[i]! } },
          { binding: 1, resource: lowRes.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `${label}.upsample.${i}`,
        colorAttachments: [
          {
            view: highRes.createView(),
            loadOp: "load",
            storeOp: "store",
          },
        ],
      });
      pass.setPipeline(this.pipelines.upsampleAdd);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return levels[0]!;
  }

  /**
   * `shutterAngle` (degrees, 0..720) → active slot count. Matches WebGL
   * `getActiveFrameCount`: 720° uses the full 8-slot ring, 360° = 4
   * slots, 180° = 2 slots.
   */
  private activeMotionBlurFrames(shutterAngle: number): number {
    if (shutterAngle <= 0) return 0;
    const normalized = Math.min(shutterAngle, 720) / 360;
    const raw = Math.round(normalized * (MOTION_BLUR_RING_SLOTS / 2));
    return Math.max(1, Math.min(MOTION_BLUR_RING_SLOTS, raw));
  }

  /**
   * Pre-normalized motion-blur weights (sum = 1 across active slots, 0
   * elsewhere). Triangle/box mix follows the WebGL path: shutterAngle ≤
   * 360° is pure triangle; > 360° smoothly flattens to box by 720°.
   */
  private computeMotionBlurWeights(
    shutterAngle: number,
    activeFrames: number,
    validSlots: number,
  ): Float32Array {
    const out = new Float32Array(MOTION_BLUR_RING_SLOTS);
    const effective = Math.min(activeFrames, validSlots);
    if (effective <= 0) return out;
    if (effective === 1) {
      out[0] = 1;
      return out;
    }
    const flatness = Math.min(1, Math.max(0, (shutterAngle - 360) / 360));
    let sum = 0;
    for (let i = 0; i < effective; i++) {
      const triangleW = effective - i;
      const boxW = 1;
      out[i] = triangleW * (1 - flatness) + boxW * flatness;
      sum += out[i]!;
    }
    if (sum > 0) {
      for (let i = 0; i < effective; i++) out[i]! /= sum;
    }
    return out;
  }

  render(): void {
    this.renderInternal("render-failed");
  }

  private renderInternal(
    reason: Extract<GpuContextLossReason, "render-failed" | "prewarm-failed">,
  ): void {
    if (this.destroyed || this.ctx.isContextLost()) return;
    try {
      this.renderFrame(reason === "prewarm-failed");
    } catch (error) {
      this.reportFatalContextLoss(reason, error);
      throw error;
    }
  }

  private renderFrame(allowPlaceholderMedia: boolean): void {
    const mediaTexture = this.getActiveMediaTexture(allowPlaceholderMedia);
    if (!mediaTexture) return;
    const { device } = this.ctx;
    this.uploadFrameUniforms();

    const rtColorGraded = this.pool.get("rt.colorGraded", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });
    const rtComposited = this.pool.get("rt.composited", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });
    const bloomLevels = this.ensurePyramidLevels("rt.bloom", BLOOM_LEVELS);
    const halationLevels = this.ensurePyramidLevels("rt.halation", HALATION_LEVELS);

    const encoder = device.createCommandEncoder({ label: "filmtone.frame" });

    // Pass 1 — primary grade into rgba16float offscreen.
    const filmlabBg = device.createBindGroup({
      label: "filmlab.bg",
      layout: this.pipelines.filmlab.getBindGroupLayout(1),
      entries: [
        { binding: 0, resource: { buffer: this.gradeBuffer } },
        { binding: 1, resource: mediaTexture.createView() },
        { binding: 2, resource: this.sampler },
        { binding: 3, resource: this.lut1Texture.createView({ dimension: "3d" }) },
        { binding: 4, resource: this.lut2Texture.createView({ dimension: "3d" }) },
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
      pass.setPipeline(this.pipelines.filmlab);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, filmlabBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    const colorGradedView = rtColorGraded.createView();

    // Pass 2 — bloom pyramid (prefilter → downsample → additive upsample).
    const bloomRadius = this.paramNumber("bloomRadius", DEFAULT_BLOOM_RADIUS);
    const bloomTop = this.renderPyramidChain(
      encoder,
      "bloom",
      this.pipelines.bloomPrefilter,
      this.bloomParamsBuffer,
      colorGradedView,
      bloomLevels,
      this.bloomPyramid,
      bloomRadius,
    );

    // Pass 3 — halation pyramid (same shape, tinted prefilter).
    const halationRadius = this.paramNumber("halationRadius", DEFAULT_HALATION_RADIUS);
    const halationTop = this.renderPyramidChain(
      encoder,
      "halation",
      this.pipelines.halationPrefilter,
      this.halationParamsBuffer,
      colorGradedView,
      halationLevels,
      this.halationPyramid,
      halationRadius,
    );

    // Pass 4 — composite into rgba16float intermediate. When motion blur
    // is OFF we blit this straight to swap; when ON, it feeds the ring.
    const compositeBg = device.createBindGroup({
      label: "composite.bg",
      layout: this.layouts.composite,
      entries: [
        { binding: 0, resource: { buffer: this.compositeBuffer } },
        { binding: 1, resource: colorGradedView },
        { binding: 2, resource: bloomTop.createView() },
        { binding: 3, resource: halationTop.createView() },
        { binding: 4, resource: this.grainTexture.createView() },
        { binding: 5, resource: this.sampler },
        { binding: 6, resource: this.grainSampler },
      ],
    });
    {
      const pass = encoder.beginRenderPass({
        label: "composite.pass",
        colorAttachments: [
          {
            view: rtComposited.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.composite);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, compositeBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Pass 5 — post-chain → swap.
    const swapView = this.ctx.getCurrentTextureView();
    const shutterAngle = this.paramNumber("shutterAngle", 0);
    const motionBlurOn = shutterAngle > 0;

    if (!motionBlurOn) {
      const blitBg = device.createBindGroup({
        label: "blit.bg",
        layout: this.layouts.blit,
        entries: [
          { binding: 0, resource: rtComposited.createView() },
          { binding: 1, resource: this.sampler },
        ],
      });
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
      pass.setPipeline(this.pipelines.blit);
      pass.setBindGroup(0, this.flagsBindGroup);
      pass.setBindGroup(1, blitBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    } else {
      // Motion blur ON — feedback copy + weighted blend.
      const prevSlot =
        (this.ringBuffer.validSlots > 0
          ? // Most recently written slot is `(writeIndex - 1 + N) % N`;
            // when the ring is empty we fall through to the new slot and
            // let hasPrev=0 zero out the trail contribution.
            undefined
          : undefined);
      const nextSlot = this.ringBuffer.nextSlot();
      const validSlots = this.ringBuffer.validSlots; // already incremented
      const hasPrev = validSlots > 1 ? 1 : 0;
      const prevSlotIndex =
        (nextSlot - 1 + MOTION_BLUR_RING_SLOTS) % MOTION_BLUR_RING_SLOTS;
      void prevSlot; // explicitly unused; kept for future trail tuning

      const trailIntensity = this.paramNumber("trailIntensity", 0);
      this.motionblurFeedbackScratch[0] = trailIntensity;
      this.motionblurFeedbackScratch[1] = hasPrev;
      this.motionblurFeedbackScratch[2] = 0;
      this.motionblurFeedbackScratch[3] = 0;
      device.queue.writeBuffer(
        this.motionblurFeedbackBuffer,
        0,
        this.motionblurFeedbackScratch.buffer,
        this.motionblurFeedbackScratch.byteOffset,
        this.motionblurFeedbackScratch.byteLength,
      );

      // Previous-slot view: on the very first frame there is no real
      // previous slot; we reuse the same `nextSlot` layer (hasPrev=0 in
      // the uniform zeroes out its contribution).
      const prevView = this.ringBuffer.viewForSlot(hasPrev === 1 ? prevSlotIndex : nextSlot);
      const nextView = this.ringBuffer.viewForSlot(nextSlot);

      const feedbackBg = device.createBindGroup({
        label: "motionblur.feedback.bg",
        layout: this.layouts.motionblurFeedback,
        entries: [
          { binding: 0, resource: { buffer: this.motionblurFeedbackBuffer } },
          { binding: 1, resource: rtComposited.createView() },
          { binding: 2, resource: prevView },
          { binding: 3, resource: this.sampler },
        ],
      });
      {
        const pass = encoder.beginRenderPass({
          label: "motionblur.feedback.pass",
          colorAttachments: [
            {
              view: nextView,
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        pass.setPipeline(this.pipelines.motionblurFeedback);
        pass.setBindGroup(0, this.flagsBindGroup);
        pass.setBindGroup(1, feedbackBg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }

      const activeFrames = Math.min(
        this.activeMotionBlurFrames(shutterAngle),
        validSlots,
      );
      const weights = this.computeMotionBlurWeights(
        shutterAngle,
        activeFrames,
        validSlots,
      );
      const oldestSlot =
        (nextSlot - (activeFrames - 1) + MOTION_BLUR_RING_SLOTS * 2) %
        MOTION_BLUR_RING_SLOTS;
      const motionThreshold = this.paramNumber("motionThreshold", 0);

      for (let i = 0; i < MOTION_BLUR_RING_SLOTS; i++) {
        this.motionblurBlendScratch[i] = weights[i] ?? 0;
      }
      this.motionblurBlendScratch[8] = nextSlot;
      this.motionblurBlendScratch[9] = oldestSlot;
      this.motionblurBlendScratch[10] = motionThreshold;
      this.motionblurBlendScratch[11] = 0;
      device.queue.writeBuffer(
        this.motionblurBlendBuffer,
        0,
        this.motionblurBlendScratch.buffer,
        this.motionblurBlendScratch.byteOffset,
        this.motionblurBlendScratch.byteLength,
      );

      const blendBg = device.createBindGroup({
        label: "motionblur.blend.bg",
        layout: this.layouts.motionblurBlend,
        entries: [
          { binding: 0, resource: { buffer: this.motionblurBlendBuffer } },
          { binding: 1, resource: this.ringBuffer.arrayView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      {
        const pass = encoder.beginRenderPass({
          label: "motionblur.blend.pass",
          colorAttachments: [
            {
              view: swapView,
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        pass.setPipeline(this.pipelines.motionblurBlend);
        pass.setBindGroup(0, this.flagsBindGroup);
        pass.setBindGroup(1, blendBg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }
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
    // RingBuffer resize re-allocates the 8-layer array texture and
    // resets validSlots → 0 so stale content can't bleed through the
    // weighted average after a viewport change.
    this.ringBuffer.resize(w, h);
  }

  destroy(): void {
    if (this.destroyed) return;
    this.destroyed = true;
    this.liveVideoElement = null;
    this.mediaTexture?.destroy();
    this.placeholderTexture?.destroy();
    this.lut1Texture.destroy();
    this.lut2Texture.destroy();
    this.grainTexture.destroy();
    this.flagsBuffer.destroy();
    this.gradeBuffer.destroy();
    this.compositeBuffer.destroy();
    this.bloomParamsBuffer.destroy();
    this.halationParamsBuffer.destroy();
    this.motionblurFeedbackBuffer.destroy();
    this.motionblurBlendBuffer.destroy();
    for (const buf of this.bloomPyramid.downsample) buf.destroy();
    for (const buf of this.bloomPyramid.upsample) buf.destroy();
    for (const buf of this.halationPyramid.downsample) buf.destroy();
    for (const buf of this.halationPyramid.upsample) buf.destroy();
    this.ringBuffer.destroy();
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
