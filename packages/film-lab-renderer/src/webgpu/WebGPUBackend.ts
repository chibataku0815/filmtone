/**
 * WebGPUBackend — Phase 2 T2-1 + T2-2 + T2-0b + T2-3 + T2-4 + Phase 3
 * (Hard Mode temporal + central bloom + diffusion suppression + shafts).
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
 *   4. diffusion → diffusion.L0; 3-level full-image downsample/upsample
 *      chain from rt.colorGraded, reusing the composite's legacy grain
 *      texture slot for the top mip. Skipped entirely when Hard-mode
 *      cross-filter is active (WebGL parity).
 *   5. composite → rt.composited (`rgba16float`) — screen-blend glow
 *      shoulder, vignette, hybrid fine/coarse grain.
 *      Composite's diffusion uniform is forced to 0 when Hard-mode
 *      cross-filter is active, independently of user's `diffusion` field.
 *   6. Post-chain (active when `crossFilterStrength > 0` or
 *      `shutterAngle > 0`):
 *      - Cross-filter: threshold → peak → optional spacing gate →
 *        (Hard-mode only) active WebGPU intentionally bypasses the
 *        legacy temporal hold so the 4-level central-bloom chain and
 *        directional streaks read current peaks directly, while the
 *        preserved temporal infrastructure remains available for future
 *        tuning → blend with center-protection.
 *      - Light Shafts (when `shaftIntensity > 0` and post chain active):
 *        radial 64-tap occlusion at ¼ res → additive full-res blend.
 *      - Motion blur (`shutterAngle > 0`): feedback copy into the ring
 *        (`depthOrArrayLayers=8`, DIRECTION §4) → weighted blend of the
 *        last N slots → swap.
 *      - Motion blur OFF: blit the post-composite source → swap.
 *
 *   Active WebGPU post tail: `CrossFilter → Shafts → MotionBlur`.
 *
 *   The swap pass output is always `rgba8unorm-srgb` so the hardware OETF
 *   handles the final linear → sRGB transform.
 *
 * Consumer API:
 *   - `setParams(record)` merges the full grade + post params blob; the
 *     uniforms it feeds are split between `GradeUniforms` (filmlab) and
 *     `CompositeUniforms` (bloom strength / halation intensity / grain /
 *     vignette). Bloom + halation shaping params (threshold, knee, radius,
 *     color), motion blur (`shutterAngle`, `trailIntensity`,
 *     `motionThreshold`), cross-filter (Hard Mode / temporal / spacing
 *     state), and light shafts (`shaftIntensity`, `shaftDecay`,
 *     `shaftOriginX`, `shaftOriginY`) are consumed directly by the
 *     post-chain bookkeeping via `paramNumber(...)`.
 *   - `setLUT1` / `setLUT2` upload 3D LUTs (identity pre-uploaded at
 *     construction so the filmlab bind group is always valid).
 *   - `setMediaFromBitmap` / `setImageResolution` / `setFitMode` /
 *     `setTime` feed the remaining frame state.
 *
 * Explicit defers (v1 migration scope):
 *   - Split / A-B compare (capability-gated off on WebGPU).
 *   - Dust / Scratches (intentionally deferred beyond v1).
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
  compareSourceFragmentWgsl,
  compositeFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  diffusionDepthPrefilterFragmentWgsl,
  bloomDepthPrefilterFragmentWgsl,
  halationDepthPrefilterFragmentWgsl,
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
  crossFilterTemporalFragmentWgsl,
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
import {
  CROSS_FILTER_TEMPORAL_REFERENCE_FPS,
  computeCrossFilterTemporalDecay,
  effectiveDiffusionAmount,
  isCrossFilterHardModeActive,
  shouldResetCrossFilterHistory,
} from "./crossFilterState";
import type { RenderBackend, RenderBackendParams } from "./Backend";
import type { ViewportCapabilities } from "../RendererRuntime";

const IDENTITY_LUT_SIZE = 33;
const BLOOM_LEVELS = 5;
const HALATION_LEVELS = 6;
const DIFFUSION_LEVELS = 3;
const BLOOM_PARAMS_BYTES = 16;
const HALATION_PARAMS_BYTES = 32;
const PYRAMID_LEVEL_UNIFORM_BYTES = 16;
const MOTIONBLUR_FEEDBACK_UNIFORM_BYTES = 16;
/** weights (2 vec4) + ring control (1 vec4) = 48 bytes. */
const MOTIONBLUR_BLEND_UNIFORM_BYTES = 48;
const MOTIONBLUR_BLEND_UNIFORM_FLOATS = MOTIONBLUR_BLEND_UNIFORM_BYTES / 4;
const CROSS_FILTER_PARAMS_BYTES = 16;
const CROSS_FILTER_SPACING_MAX_BYTES = 32;
const CROSS_FILTER_STREAK_BYTES = 48;
const CROSS_FILTER_MAX_STREAKS = 4;
const CROSS_FILTER_SPACING_RADIUS_MAX_PX = 48.0;
const CROSS_FILTER_SPACING_RADIUS_STEP_PX = 24.0;
const CROSS_FILTER_THRESHOLD_HARD_BASELINE = 0.7;
const CROSS_FILTER_THRESHOLD_CONTROL_BASELINE = 0.92;
const CROSS_FILTER_MIN_SPACING_MIN = 1.0;
const CROSS_FILTER_MIN_SPACING_MAX = 10.0;
/** Number of cross-filter peak history ring slots (2 = ping-pong). */
const CROSS_FILTER_HISTORY_SLOTS = 2;
/**
 * Product divergence from WebGL parity: active WebGPU Hard Mode bypasses
 * the legacy temporal hold to remove the user-reported cross-filter trail.
 * The preserved history path stays compiled so its resources/state contract
 * and the elapsed-time normalization work remain intact for future tuning.
 */
const WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED = false;
/** Hard-mode central bloom pyramid depth (WebGL parity). */
const CENTRAL_BLOOM_LEVELS = 4;
/** Central bloom upsample radius (fixed, WebGL parity). */
const CENTRAL_BLOOM_RADIUS = 0.5;
/** Light shafts quarter-resolution divisor (WebGL parity). */
const LIGHTSHAFTS_RES_DIVISOR = 4;
/** Light shafts radial sampling defaults (WebGL parity). */
const LIGHTSHAFTS_DENSITY = 0.98;
const LIGHTSHAFTS_EXPOSURE = 0.38;
/** Light shafts uniform layouts. */
const LIGHTSHAFTS_PARAMS_BYTES = 32;
const LIGHTSHAFTS_BLEND_PARAMS_BYTES = 16;

function smoothstep01(value: number): number {
  const clamped = Math.min(1, Math.max(0, value));
  return clamped * clamped * (3 - 2 * clamped);
}

function computeCrossFilterEffectiveThreshold(threshold: number, hardModeActive: boolean): number {
  if (!hardModeActive) {
    return threshold;
  }
  return Math.min(
    1,
    Math.max(
      0,
      threshold -
        (CROSS_FILTER_THRESHOLD_CONTROL_BASELINE - CROSS_FILTER_THRESHOLD_HARD_BASELINE),
    ),
  );
}

function computeCrossFilterSpacingRadiusPx(minSpacing: number): number {
  const clamped = Math.min(
    CROSS_FILTER_MIN_SPACING_MAX,
    Math.max(CROSS_FILTER_MIN_SPACING_MIN, minSpacing),
  );
  let extraRadius = 0;
  for (
    let stepStart = CROSS_FILTER_MIN_SPACING_MIN;
    stepStart < CROSS_FILTER_MIN_SPACING_MAX;
    stepStart += 1
  ) {
    extraRadius +=
      CROSS_FILTER_SPACING_RADIUS_STEP_PX * smoothstep01(clamped - stepStart);
  }
  return Math.round(CROSS_FILTER_SPACING_RADIUS_MAX_PX + extraRadius);
}

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
  compareSource: GPUShaderModule;
  composite: GPUShaderModule;
  bloomPrefilter: GPUShaderModule;
  halationPrefilter: GPUShaderModule;
  diffusionDepthPrefilter: GPUShaderModule;
  bloomDepthPrefilter: GPUShaderModule;
  halationDepthPrefilter: GPUShaderModule;
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
  crossFilterTemporal: GPUShaderModule;
  crossFilterBlend: GPUShaderModule;
}

interface Pipelines {
  filmlab: GPURenderPipeline;
  bloomPrefilter: GPURenderPipeline;
  halationPrefilter: GPURenderPipeline;
  /** Dev-only: depth-weighted source mask feeding into the diffusion pyramid. */
  diffusionDepthPrefilter: GPURenderPipeline;
  /** Dev-only: depth-weighted source mask feeding into the bloom pyramid. */
  bloomDepthPrefilter: GPURenderPipeline;
  /** Dev-only: depth-weighted source mask feeding into the halation pyramid. */
  halationDepthPrefilter: GPURenderPipeline;
  downsample: GPURenderPipeline;
  /** Same shader as `downsample` / `upsample`-compatible layout, additive blend. */
  upsampleAdd: GPURenderPipeline;
  composite: GPURenderPipeline;
  /** Final swap when motion blur is OFF — rgba16float → rgba8unorm-srgb hw OETF. */
  blit: GPURenderPipeline;
  /**
   * Compare present pass: mixes raw `mediaTexture` and graded post-composite
   * output by `splitPosition`, then draws a divider line. Replaces the blit /
   * motion-blur present pass when `frameState.compareEnabled` is true.
   */
  compareSource: GPURenderPipeline;
  /** Writes current composited frame into ring[newSlot], mixing ring[prevSlot] when trail > 0. */
  motionblurFeedback: GPURenderPipeline;
  /** N-slot weighted average → swap. */
  motionblurBlend: GPURenderPipeline;
  crossFilterPeak: GPURenderPipeline;
  crossFilterPeakSpacingMax: GPURenderPipeline;
  crossFilterPeakSpacing: GPURenderPipeline;
  crossFilterStreak: GPURenderPipeline;
  crossFilterTemporal: GPURenderPipeline;
  crossFilterBlend: GPURenderPipeline;
  /** Hard-mode central bloom reuses the generic `downsample` / `upsampleAdd` pipelines. */
  lightshafts: GPURenderPipeline;
  lightshaftsBlend: GPURenderPipeline;
}

interface PrefilterGroupLayouts {
  bloom: GPUBindGroupLayout;
  halation: GPUBindGroupLayout;
  pyramid: GPUBindGroupLayout;
  diffusionDepthPrefilter: GPUBindGroupLayout;
  composite: GPUBindGroupLayout;
  blit: GPUBindGroupLayout;
  compareSource: GPUBindGroupLayout;
  motionblurFeedback: GPUBindGroupLayout;
  motionblurBlend: GPUBindGroupLayout;
  crossFilterPeakSpacing: GPUBindGroupLayout;
  crossFilterTemporal: GPUBindGroupLayout;
  crossFilterBlend: GPUBindGroupLayout;
  lightshafts: GPUBindGroupLayout;
  lightshaftsBlend: GPUBindGroupLayout;
}

/**
 * Pre-allocated pyramid resources. Uniform buffers are sized up-front so a
 * single submit() never collides multiple `writeBuffer` calls on the same
 * buffer. Textures live in `OffscreenTargetPool` and are keyed by label so
 * resize swaps transparently.
 */
interface PyramidResources {
  readonly downsample: GPUBuffer[]; // length = levels
  readonly upsample: GPUBuffer[]; // length = levels - 1
  readonly downsampleScratch: Float32Array[];
  readonly upsampleScratch: Float32Array[];
}

interface CrossFilterResources {
  readonly thresholdBuffer: GPUBuffer;
  readonly peakBuffer: GPUBuffer;
  readonly spacingMaxBuffers: GPUBuffer[];
  readonly spacingBuffer: GPUBuffer;
  readonly streakBuffers: GPUBuffer[];
  readonly temporalBuffer: GPUBuffer;
  readonly blendBuffer: GPUBuffer;
  readonly blackTexture: GPUTexture;
  readonly thresholdScratch: Float32Array;
  readonly peakScratch: Float32Array;
  readonly spacingMaxScratch: Float32Array[];
  readonly spacingScratch: Float32Array;
  readonly streakScratch: Float32Array[];
  readonly temporalScratch: Float32Array;
  readonly blendScratch: Float32Array;
}

interface LightShaftsResources {
  readonly paramsBuffer: GPUBuffer;
  readonly blendParamsBuffer: GPUBuffer;
  readonly paramsScratch: Float32Array;
  readonly blendParamsScratch: Float32Array;
}

export class WebGPUBackend implements RenderBackend {
  private readonly ctx: GpuContext;
  readonly capabilities: ViewportCapabilities;
  private readonly modules: ShaderModules;
  private readonly pool: OffscreenTargetPool;
  private readonly pipelines: Pipelines;
  private readonly layouts: PrefilterGroupLayouts;
  private readonly displayFlagsBuffer: GPUBuffer;
  private readonly offscreenFlagsBuffer: GPUBuffer;
  private readonly crossFilterFlagsBuffer: GPUBuffer;
  private readonly displayFlagsBindGroup: GPUBindGroup;
  private readonly offscreenFlagsBindGroup: GPUBindGroup;
  private readonly crossFilterFlagsBindGroup: GPUBindGroup;
  private readonly gradeBuffer: GPUBuffer;
  private readonly compositeBuffer: GPUBuffer;
  private readonly bloomParamsBuffer: GPUBuffer;
  private readonly halationParamsBuffer: GPUBuffer;
  private readonly diffusionDepthPrefilterBuffer: GPUBuffer;
  private readonly diffusionDepthPrefilterScratch: Float32Array;
  private readonly bloomDepthPrefilterBuffer: GPUBuffer;
  private readonly bloomDepthPrefilterScratch: Float32Array;
  private readonly halationDepthPrefilterBuffer: GPUBuffer;
  private readonly halationDepthPrefilterScratch: Float32Array;
  private readonly bloomPyramid: PyramidResources;
  private readonly halationPyramid: PyramidResources;
  private readonly diffusionPyramid: PyramidResources;
  private readonly centralBloomPyramid: PyramidResources;
  private readonly motionblurFeedbackBuffer: GPUBuffer;
  private readonly motionblurBlendBuffer: GPUBuffer;
  private readonly crossFilter: CrossFilterResources;
  private readonly lightShafts: LightShaftsResources;
  private readonly sampler: GPUSampler;
  private readonly grainSampler: GPUSampler;
  private readonly grainTexture: GPUTexture;
  /**
   * Shared depth texture for depth-aware Mist / Glow.
   * Runtime depth tracks and the internal `?depthProbe=1|2` debug fallback
   * both upload into this surface.
   */
  private readonly depthTexture: GPUTexture;
  private readonly gradeScratch = new Float32Array(GRADE_UNIFORM_FLOATS);
  private readonly compositeScratch = new Float32Array(COMPOSITE_UNIFORM_FLOATS);
  private readonly bloomParamsScratch = new Float32Array(BLOOM_PARAMS_BYTES / 4);
  private readonly halationParamsScratch = new Float32Array(HALATION_PARAMS_BYTES / 4);
  private readonly motionblurFeedbackScratch = new Float32Array(4);
  private readonly motionblurBlendScratch = new Float32Array(MOTIONBLUR_BLEND_UNIFORM_FLOATS);
  /** Compare present uniform: 2 vec4 = 8 floats = 32 B. */
  private readonly compareSourceBuffer: GPUBuffer;
  private readonly compareSourceScratch = new Float32Array(8);

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
  private readbackEnabled = false;
  private readbackBuffer: GPUBuffer | null = null;
  private readbackBufferSize = 0;
  private hasReadableFrame = false;
  private frameState: GradeFrameState;
  /**
   * Preserved temporal-hold bookkeeping.
   *
   * WebGL and the dormant WebGPU temporal path use two half-resolution
   * history textures managed by `OffscreenTargetPool` under dedicated
   * labels (`rt.crossfilter.peak-history.{0,1}`). They persist as long as
   * the resolution is unchanged, so the ping-pong remains valid across
   * frames whenever the hold is re-enabled. The counters below get reset
   * whenever the history should be treated as empty — resolution changes,
   * `crossFilterStrength` transitions to 0, `crossFilterHardMode` flips,
   * or `crossFilterMinSpacing` crosses an epsilon. We also track the last
   * history timestamp so temporal decay can stay normalized to elapsed
   * time instead of render count.
   */
  private crossFilterPeakHistoryWriteIndex = 0;
  private crossFilterPeakHistoryFilledFrames = 0;
  private lastCrossFilterHistoryTime: number | null = null;
  private lastCrossFilterStrength = 0;
  private lastCrossFilterHardMode: 0 | 1 = 0;
  private lastCrossFilterMinSpacing = 0;

  private constructor(
    ctx: GpuContext,
    modules: ShaderModules,
    pool: OffscreenTargetPool,
    pipelines: Pipelines,
    layouts: PrefilterGroupLayouts,
    displayFlagsBuffer: GPUBuffer,
    offscreenFlagsBuffer: GPUBuffer,
    crossFilterFlagsBuffer: GPUBuffer,
    displayFlagsBindGroup: GPUBindGroup,
    offscreenFlagsBindGroup: GPUBindGroup,
    crossFilterFlagsBindGroup: GPUBindGroup,
    gradeBuffer: GPUBuffer,
    compositeBuffer: GPUBuffer,
    bloomParamsBuffer: GPUBuffer,
    halationParamsBuffer: GPUBuffer,
    bloomPyramid: PyramidResources,
    halationPyramid: PyramidResources,
    diffusionPyramid: PyramidResources,
    centralBloomPyramid: PyramidResources,
    motionblurFeedbackBuffer: GPUBuffer,
    motionblurBlendBuffer: GPUBuffer,
    crossFilter: CrossFilterResources,
    lightShafts: LightShaftsResources,
    sampler: GPUSampler,
    grainSampler: GPUSampler,
    grainTexture: GPUTexture,
    lut1Texture: GPUTexture,
    lut2Texture: GPUTexture,
    ringBuffer: RingBuffer,
    compareSourceBuffer: GPUBuffer,
  ) {
    this.ctx = ctx;
    this.capabilities = ctx.capabilities;
    this.modules = modules;
    this.pool = pool;
    this.pipelines = pipelines;
    this.layouts = layouts;
    this.displayFlagsBuffer = displayFlagsBuffer;
    this.offscreenFlagsBuffer = offscreenFlagsBuffer;
    this.crossFilterFlagsBuffer = crossFilterFlagsBuffer;
    this.displayFlagsBindGroup = displayFlagsBindGroup;
    this.offscreenFlagsBindGroup = offscreenFlagsBindGroup;
    this.crossFilterFlagsBindGroup = crossFilterFlagsBindGroup;
    this.gradeBuffer = gradeBuffer;
    this.compositeBuffer = compositeBuffer;
    this.bloomParamsBuffer = bloomParamsBuffer;
    this.halationParamsBuffer = halationParamsBuffer;
    this.bloomPyramid = bloomPyramid;
    this.halationPyramid = halationPyramid;
    this.diffusionPyramid = diffusionPyramid;
    this.centralBloomPyramid = centralBloomPyramid;
    this.motionblurFeedbackBuffer = motionblurFeedbackBuffer;
    this.motionblurBlendBuffer = motionblurBlendBuffer;
    this.crossFilter = crossFilter;
    this.lightShafts = lightShafts;
    this.sampler = sampler;
    this.grainSampler = grainSampler;
    this.grainTexture = grainTexture;

    // Shared depth texture for depth-aware Mist / Glow. Keep it neutral 0.5
    // so depth-off (depthMistGain=0 / depthGlowGain=0) leaves the optical
    // finish unchanged until a runtime depth frame is uploaded.
    {
      const DEPTH_W = 512;
      const DEPTH_H = 288;
      this.depthTexture = ctx.device.createTexture({
        label: "depth.probe",
        size: { width: DEPTH_W, height: DEPTH_H, depthOrArrayLayers: 1 },
        format: "rgba8unorm",
        usage:
          GPUTextureUsage.TEXTURE_BINDING |
          GPUTextureUsage.COPY_DST |
          GPUTextureUsage.RENDER_ATTACHMENT,
      });
      const neutral = new Uint8Array(DEPTH_W * DEPTH_H * 4);
      for (let i = 0; i < DEPTH_W * DEPTH_H; i++) {
        neutral[i * 4] = 128;
        neutral[i * 4 + 1] = 128;
        neutral[i * 4 + 2] = 128;
        neutral[i * 4 + 3] = 255;
      }
      ctx.device.queue.writeTexture(
        { texture: this.depthTexture },
        neutral,
        { bytesPerRow: DEPTH_W * 4 },
        { width: DEPTH_W, height: DEPTH_H, depthOrArrayLayers: 1 },
      );
    }

    this.lut1Texture = lut1Texture;
    this.lut2Texture = lut2Texture;
    this.ringBuffer = ringBuffer;
    this.compareSourceBuffer = compareSourceBuffer;

    // Diffusion depth prefilter params — 2 vec4 = 32 bytes.
    //   misc: (depthMistGain, fitMode, _, _)
    //   size: (resolutionX, resolutionY, imageResX, imageResY)
    this.diffusionDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "diffusion-depth-prefilter.params",
      size: 32,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.diffusionDepthPrefilterScratch = new Float32Array(8);
    // Separate uniform buffers per pyramid: a single buffer shared across
    // all three pillars would silently overwrite in submit order (last
    // writeBuffer wins) — see feedback_webgpu_writebuffer_per_layer.md.
    this.bloomDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "bloom-depth-prefilter.params",
      size: 32,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.bloomDepthPrefilterScratch = new Float32Array(8);
    this.halationDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "halation-depth-prefilter.params",
      size: 32,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.halationDepthPrefilterScratch = new Float32Array(8);
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
      compareEnabled: false,
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
      compareSource: await make("compare-source.frag", compareSourceFragmentWgsl),
      composite: await make("composite.frag", compositeFragmentWgsl),
      bloomPrefilter: await make("bloom-prefilter.frag", bloomPrefilterFragmentWgsl),
      halationPrefilter: await make("halation-prefilter.frag", halationPrefilterFragmentWgsl),
      diffusionDepthPrefilter: await make(
        "diffusion-depth-prefilter.frag",
        diffusionDepthPrefilterFragmentWgsl,
      ),
      bloomDepthPrefilter: await make(
        "bloom-depth-prefilter.frag",
        bloomDepthPrefilterFragmentWgsl,
      ),
      halationDepthPrefilter: await make(
        "halation-depth-prefilter.frag",
        halationDepthPrefilterFragmentWgsl,
      ),
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
      crossFilterTemporal: await make(
        "cross-filter-temporal.frag",
        crossFilterTemporalFragmentWgsl,
      ),
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

    // Dev-only: diffusion depth prefilter — `(uniform, uSource, uDepth, uSampler)`.
    // Runs before the diffusion pyramid so the pyramid input is already
    // depth-weighted. See `shaders/diffusion-depth-prefilter.frag.wgsl.ts`.
    const diffusionDepthPrefilterGroupLayout = device.createBindGroupLayout({
      label: "diffusion-depth-prefilter.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
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
        { binding: 7, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
      ],
    });

    const blitGroupLayout = device.createBindGroupLayout({
      label: "blit.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    // Compare present pass — `(uniform, mediaTex, gradedTex, sampler)`.
    // Binding count cross-checked with WGSL `@binding(0..3)` in
    // `shaders/compare-source.frag.wgsl.ts` (4 entries, 4 declarations).
    const compareSourceGroupLayout = device.createBindGroupLayout({
      label: "compare-source.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
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

    const crossFilterPeakSpacingGroupLayout = device.createBindGroupLayout({
      label: "crossfilter.spacing.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    const crossFilterBlendGroupLayout = device.createBindGroupLayout({
      label: "crossfilter.blend.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 4, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 5, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 6, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 7, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    // Hard-mode temporal hold: `(uniform, uSource, uPrev, uSampler)`.
    const crossFilterTemporalGroupLayout = device.createBindGroupLayout({
      label: "crossfilter.temporal.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    // Light shafts 9a (radial blur): `(uniform, uSource, uSampler)`.
    const lightshaftsGroupLayout = device.createBindGroupLayout({
      label: "lightshafts.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
      ],
    });

    // Light shafts 9b (additive blend): `(uniform, uScene, uShafts, uSampler)`.
    const lightshaftsBlendGroupLayout = device.createBindGroupLayout({
      label: "lightshafts.blend.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
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

    // Dev-only: depth-weighted source prefilter for the diffusion pyramid.
    const diffusionDepthPrefilterPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "diffusion-depth.prefilter",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, diffusionDepthPrefilterGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.diffusionDepthPrefilter,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    // Dev-only: depth-weighted source prefilter for the bloom pyramid.
    // Reuses the Mist prefilter's bind group layout (uniform, source,
    // depth, sampler) — only the near/far coefficients differ, and those
    // live inside the WGSL constant.
    const bloomDepthPrefilterPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "bloom-depth.prefilter",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, diffusionDepthPrefilterGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.bloomDepthPrefilter,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    // Dev-only: depth-weighted source prefilter for the halation pyramid.
    const halationDepthPrefilterPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "halation-depth.prefilter",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, diffusionDepthPrefilterGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.halationDepthPrefilter,
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

    const compareSourcePipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "compare-source.present",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, compareSourceGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.compareSource,
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

    const crossFilterPeakPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.peak",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterPeak,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const crossFilterPeakSpacingMaxPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.spacing-max",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterPeakSpacingMax,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const crossFilterPeakSpacingPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.spacing",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, crossFilterPeakSpacingGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterPeakSpacing,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const crossFilterStreakPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.streak",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterStreak,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const crossFilterBlendPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.blend",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, crossFilterBlendGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterBlend,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const crossFilterTemporalPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.temporal",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, crossFilterTemporalGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterTemporal,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const lightshaftsPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "lightshafts.radial",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, lightshaftsGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.lightshafts,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const lightshaftsBlendPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "lightshafts.blend",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, lightshaftsBlendGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.lightshaftsBlend,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
        },
        primitive: { topology: "triangle-list" },
      }),
    );

    const displayFlagsBuffer = device.createBuffer({
      label: "frame.flags.display",
      size: 16,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(displayFlagsBuffer, 0, new Float32Array([0, 0, 0, 0]));
    const displayFlagsBindGroup = device.createBindGroup({
      label: "frame.flags.display.bg",
      layout: flagsLayout,
      entries: [{ binding: 0, resource: { buffer: displayFlagsBuffer } }],
    });
    const offscreenFlagsBuffer = device.createBuffer({
      label: "frame.flags.offscreen",
      size: 16,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(offscreenFlagsBuffer, 0, new Float32Array([0, 0, 0, 0]));
    const offscreenFlagsBindGroup = device.createBindGroup({
      label: "frame.flags.offscreen.bg",
      layout: flagsLayout,
      entries: [{ binding: 0, resource: { buffer: offscreenFlagsBuffer } }],
    });
    const crossFilterFlagsBuffer = device.createBuffer({
      label: "frame.flags.crossfilter",
      size: 16,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    device.queue.writeBuffer(crossFilterFlagsBuffer, 0, new Float32Array([1, 0, 0, 0]));
    const crossFilterFlagsBindGroup = device.createBindGroup({
      label: "frame.flags.crossfilter.bg",
      layout: flagsLayout,
      entries: [{ binding: 0, resource: { buffer: crossFilterFlagsBuffer } }],
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
      for (let i = 0; i < levels; i++) {
        downsample.push(
          device.createBuffer({
            label: `${label}.downsample.${i}`,
            size: PYRAMID_LEVEL_UNIFORM_BYTES,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
          }),
        );
        downsampleScratch.push(new Float32Array(4));
        if (i >= levels - 1) continue;
        upsample.push(
          device.createBuffer({
            label: `${label}.upsample.${i}`,
            size: PYRAMID_LEVEL_UNIFORM_BYTES,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
          }),
        );
        upsampleScratch.push(new Float32Array(4));
      }
      return { downsample, upsample, downsampleScratch, upsampleScratch };
    };

    const bloomPyramid = makePyramid("bloom", BLOOM_LEVELS);
    const halationPyramid = makePyramid("halation", HALATION_LEVELS);
    const diffusionPyramid = makePyramid("diffusion", DIFFUSION_LEVELS);
    const centralBloomPyramid = makePyramid("centralBloom", CENTRAL_BLOOM_LEVELS);

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

    const crossFilterThresholdBuffer = device.createBuffer({
      label: "crossfilter.threshold.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const crossFilterPeakBuffer = device.createBuffer({
      label: "crossfilter.peak.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const crossFilterSpacingMaxBuffers = Array.from(
      { length: 2 },
      (_, index) =>
        device.createBuffer({
          label: `crossfilter.spacing-max.${index}.params`,
          size: CROSS_FILTER_SPACING_MAX_BYTES,
          usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        }),
    );

    const crossFilterSpacingBuffer = device.createBuffer({
      label: "crossfilter.spacing.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const crossFilterStreakBuffers = Array.from(
      { length: CROSS_FILTER_MAX_STREAKS },
      (_, index) =>
        device.createBuffer({
          label: `crossfilter.streak.${index}.params`,
          size: CROSS_FILTER_STREAK_BYTES,
          usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        }),
    );

    const crossFilterBlendBuffer = device.createBuffer({
      label: "crossfilter.blend.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const crossFilterTemporalBuffer = device.createBuffer({
      label: "crossfilter.temporal.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const lightshaftsBuffer = device.createBuffer({
      label: "lightshafts.params",
      size: LIGHTSHAFTS_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const lightshaftsBlendBuffer = device.createBuffer({
      label: "lightshafts.blend.params",
      size: LIGHTSHAFTS_BLEND_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    // Compare present uniform: 2 vec4 = 8 floats = 32 B.
    const compareSourceBuffer = device.createBuffer({
      label: "compare-source.params",
      size: 32,
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
    const crossFilterBlackTexture = device.createTexture({
      label: "crossfilter.black",
      size: { width: 1, height: 1, depthOrArrayLayers: 1 },
      format: "rgba16float",
      usage: GPUTextureUsage.TEXTURE_BINDING | GPUTextureUsage.COPY_DST,
    });
    device.queue.writeTexture(
      { texture: crossFilterBlackTexture },
      new Uint16Array([0, 0, 0, 0]),
      { bytesPerRow: 8 },
      { width: 1, height: 1, depthOrArrayLayers: 1 },
    );

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
        diffusionDepthPrefilter: diffusionDepthPrefilterPipeline,
        bloomDepthPrefilter: bloomDepthPrefilterPipeline,
        halationDepthPrefilter: halationDepthPrefilterPipeline,
        downsample: downsamplePipeline,
        upsampleAdd: upsampleAddPipeline,
        composite: compositePipeline,
        blit: blitPipeline,
        compareSource: compareSourcePipeline,
        motionblurFeedback: motionblurFeedbackPipeline,
        motionblurBlend: motionblurBlendPipeline,
        crossFilterPeak: crossFilterPeakPipeline,
        crossFilterPeakSpacingMax: crossFilterPeakSpacingMaxPipeline,
        crossFilterPeakSpacing: crossFilterPeakSpacingPipeline,
        crossFilterStreak: crossFilterStreakPipeline,
        crossFilterTemporal: crossFilterTemporalPipeline,
        crossFilterBlend: crossFilterBlendPipeline,
        lightshafts: lightshaftsPipeline,
        lightshaftsBlend: lightshaftsBlendPipeline,
      },
      {
        bloom: pyramidGroupLayout,
        halation: pyramidGroupLayout,
        pyramid: pyramidGroupLayout,
        diffusionDepthPrefilter: diffusionDepthPrefilterGroupLayout,
        composite: compositeGroupLayout,
        blit: blitGroupLayout,
        compareSource: compareSourceGroupLayout,
        motionblurFeedback: motionblurFeedbackGroupLayout,
        motionblurBlend: motionblurBlendGroupLayout,
        crossFilterPeakSpacing: crossFilterPeakSpacingGroupLayout,
        crossFilterTemporal: crossFilterTemporalGroupLayout,
        crossFilterBlend: crossFilterBlendGroupLayout,
        lightshafts: lightshaftsGroupLayout,
        lightshaftsBlend: lightshaftsBlendGroupLayout,
      },
      displayFlagsBuffer,
      offscreenFlagsBuffer,
      crossFilterFlagsBuffer,
      displayFlagsBindGroup,
      offscreenFlagsBindGroup,
      crossFilterFlagsBindGroup,
      gradeBuffer,
      compositeBuffer,
      bloomParamsBuffer,
      halationParamsBuffer,
      bloomPyramid,
      halationPyramid,
      diffusionPyramid,
      centralBloomPyramid,
      motionblurFeedbackBuffer,
      motionblurBlendBuffer,
      {
        thresholdBuffer: crossFilterThresholdBuffer,
        peakBuffer: crossFilterPeakBuffer,
        spacingMaxBuffers: crossFilterSpacingMaxBuffers,
        spacingBuffer: crossFilterSpacingBuffer,
        streakBuffers: crossFilterStreakBuffers,
        temporalBuffer: crossFilterTemporalBuffer,
        blendBuffer: crossFilterBlendBuffer,
        blackTexture: crossFilterBlackTexture,
        thresholdScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
        peakScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
        spacingMaxScratch: Array.from(
          { length: 2 },
          () => new Float32Array(CROSS_FILTER_SPACING_MAX_BYTES / 4),
        ),
        spacingScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
        streakScratch: Array.from(
          { length: CROSS_FILTER_MAX_STREAKS },
          () => new Float32Array(CROSS_FILTER_STREAK_BYTES / 4),
        ),
        temporalScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
        blendScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
      },
      {
        paramsBuffer: lightshaftsBuffer,
        blendParamsBuffer: lightshaftsBlendBuffer,
        paramsScratch: new Float32Array(LIGHTSHAFTS_PARAMS_BYTES / 4),
        blendParamsScratch: new Float32Array(LIGHTSHAFTS_BLEND_PARAMS_BYTES / 4),
      },
      sampler,
      grainSampler,
      grainTexture,
      identityLut1,
      identityLut2,
      ringBuffer,
      compareSourceBuffer,
    );
  }

  /**
   * Upload a 512x288 depth frame (red channel = depth, 0 = near, 255 = far)
   * for the shared depth-aware Mist / Glow path.
   */
  setDepthFromBitmap(bitmap: ImageBitmap): void {
    this.ctx.device.queue.copyExternalImageToTexture(
      { source: bitmap, flipY: false },
      { texture: this.depthTexture },
      { width: 512, height: 288, depthOrArrayLayers: 1 },
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

  /**
   * Compare API. WebGPU backend still only honors the `enabled` flag —
   * when true, the present pass is replaced by the `compare-source`
   * pipeline that mixes raw `mediaTexture` and graded output by the
   * current `splitPosition`. Slot params (`paramsA` / `paramsB`) are
   * intentionally ignored on WebGPU v1; the WebGL dual-slot
   * simultaneous A/B render parity stays deferred. The active slot's
   * params still drive the normal grade pipeline (via `setParams` from
   * the control panel), so toggling Tab in compare mode updates the
   * graded side as expected.
   */
  setComparePair(
    enabled: boolean,
    _paramsA: Record<string, number | string> | null,
    _paramsB: Record<string, number | string> | null,
  ): void {
    this.frameState.compareEnabled = enabled;
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
      this.displayFlagsBuffer,
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

  setReadbackEnabled(enabled: boolean): void {
    this.readbackEnabled = enabled;
    this.hasReadableFrame = false;
  }

  async readbackRgba8(): Promise<Uint8Array> {
    if (!this.readbackEnabled) {
      throw new Error("[WebGPUBackend] readback requested before readback was enabled");
    }
    if (this.destroyed) {
      throw new Error("[WebGPUBackend] readback requested after destroy");
    }
    const lossInfo = this.ctx.getContextLossInfo();
    if (lossInfo) {
      throw new Error(
        `[WebGPUBackend] readback unavailable after context loss: ${lossInfo.reason}`,
      );
    }
    if (!this.hasReadableFrame) {
      throw new Error("[WebGPUBackend] readback requested before any frame was rendered");
    }

    const width = this._width;
    const height = this._height;
    const bytesPerRow = width * 4;
    const alignedBytesPerRow = Math.ceil(bytesPerRow / 256) * 256;
    const readbackTexture = this.pool.get("rt.present.readback", {
      width,
      height,
      format: this.ctx.canvasFormat,
      usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
    });
    const readbackBuffer = this.ensureReadbackBuffer(
      alignedBytesPerRow * height,
    );
    const encoder = this.ctx.device.createCommandEncoder({
      label: "filmtone.readback",
    });
    encoder.copyTextureToBuffer(
      { texture: readbackTexture },
      {
        buffer: readbackBuffer,
        bytesPerRow: alignedBytesPerRow,
        rowsPerImage: height,
      },
      { width, height, depthOrArrayLayers: 1 },
    );
    this.ctx.device.queue.submit([encoder.finish()]);

    await readbackBuffer.mapAsync(GPUMapMode.READ);
    const mapped = new Uint8Array(readbackBuffer.getMappedRange());
    const out = new Uint8Array(bytesPerRow * height);
    for (let y = 0; y < height; y++) {
      const srcOffset = y * alignedBytesPerRow;
      const dstOffset = (height - 1 - y) * bytesPerRow;
      out.set(mapped.subarray(srcOffset, srcOffset + bytesPerRow), dstOffset);
    }
    readbackBuffer.unmap();
    return out;
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

  private uploadFrameUniforms(suppressDiffusion: boolean): void {
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
    // Hard-mode cross-filter suppresses global diffusion at the
    // composite-input level (WebGL parity). The user's `diffusion` field
    // stays untouched in `frameState.params`; we simply zero the packed
    // uniform slot for this frame so `composite.wgsl` sees `diffusion=0`.
    if (suppressDiffusion) {
      this.compositeScratch[14] = 0;
    }
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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return levels[0]!;
  }

  /**
   * Shared depth-aware Mist path — produce a depth-weighted source mask feeding
   * the diffusion pyramid. Output goes to `rt.diffusion.prefiltered`
   * (full-res rgba16float), which the caller then passes to
   * `renderDiffusionPyramid` in place of the raw colorGraded view.
   *
   * Physical model: Pro-Mist scatters light at the source, so weighting the
   * source by depth *before* the pyramid is built is the physically correct
   * location. Post-composite modulation (the prior approach) re-cut an
   * already-bled halo with a sharp depth mask, which read as a ghost / double
   * image along silhouette edges.
   */
  private renderDiffusionDepthPrefilter(
    encoder: GPUCommandEncoder,
    sourceView: GPUTextureView,
    depthMistGain: number,
  ): GPUTextureView {
    const { device } = this.ctx;
    const scratchRT = this.pool.get("rt.diffusion.prefiltered", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });
    const scratchView = scratchRT.createView();

    const s = this.diffusionDepthPrefilterScratch;
    s[0] = depthMistGain;
    s[1] = this.frameState.fitMode;
    s[2] = 0;
    s[3] = 0;
    s[4] = this._width;
    s[5] = this._height;
    s[6] = this.frameState.imgResX;
    s[7] = this.frameState.imgResY;
    device.queue.writeBuffer(
      this.diffusionDepthPrefilterBuffer,
      0,
      s.buffer,
      s.byteOffset,
      s.byteLength,
    );

    const bg = device.createBindGroup({
      label: "diffusion-depth-prefilter.bg",
      layout: this.layouts.diffusionDepthPrefilter,
      entries: [
        { binding: 0, resource: { buffer: this.diffusionDepthPrefilterBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: this.depthTexture.createView() },
        { binding: 3, resource: this.sampler },
      ],
    });

    const pass = encoder.beginRenderPass({
      label: "diffusion-depth-prefilter.pass",
      colorAttachments: [
        {
          view: scratchView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(this.pipelines.diffusionDepthPrefilter);
    pass.setBindGroup(0, this.offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();

    return scratchView;
  }

  /**
   * Shared depth-aware Glow path — depth-weighted source mask feeding the
   * bloom pyramid. Output goes to `rt.bloom.depth-prefiltered` (full-res
   * rgba16float), which the caller passes to `renderPyramidChain` as the
   * `sourceView`; the existing bloom luma-gate prefilter then reads from
   * this intermediate. Near/far coefficients live in the WGSL constant
   * (`bloom-depth-prefilter.frag.wgsl.ts`).
   */
  private renderBloomDepthPrefilter(
    encoder: GPUCommandEncoder,
    sourceView: GPUTextureView,
    gain: number,
  ): GPUTextureView {
    const { device } = this.ctx;
    const scratchRT = this.pool.get("rt.bloom.depth-prefiltered", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });
    const scratchView = scratchRT.createView();

    const s = this.bloomDepthPrefilterScratch;
    s[0] = gain;
    s[1] = this.frameState.fitMode;
    s[2] = 0;
    s[3] = 0;
    s[4] = this._width;
    s[5] = this._height;
    s[6] = this.frameState.imgResX;
    s[7] = this.frameState.imgResY;
    device.queue.writeBuffer(
      this.bloomDepthPrefilterBuffer,
      0,
      s.buffer,
      s.byteOffset,
      s.byteLength,
    );

    const bg = device.createBindGroup({
      label: "bloom-depth-prefilter.bg",
      layout: this.layouts.diffusionDepthPrefilter,
      entries: [
        { binding: 0, resource: { buffer: this.bloomDepthPrefilterBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: this.depthTexture.createView() },
        { binding: 3, resource: this.sampler },
      ],
    });

    const pass = encoder.beginRenderPass({
      label: "bloom-depth-prefilter.pass",
      colorAttachments: [
        {
          view: scratchView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(this.pipelines.bloomDepthPrefilter);
    pass.setBindGroup(0, this.offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();

    return scratchView;
  }

  /**
   * Shared depth-aware Glow path — depth-weighted source mask feeding the
   * halation pyramid. Mirrors `renderBloomDepthPrefilter`; only the
   * scratch RT label and uniform buffer differ (separate buffers per
   * pyramid to avoid writeBuffer aliasing).
   */
  private renderHalationDepthPrefilter(
    encoder: GPUCommandEncoder,
    sourceView: GPUTextureView,
    gain: number,
  ): GPUTextureView {
    const { device } = this.ctx;
    const scratchRT = this.pool.get("rt.halation.depth-prefiltered", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });
    const scratchView = scratchRT.createView();

    const s = this.halationDepthPrefilterScratch;
    s[0] = gain;
    s[1] = this.frameState.fitMode;
    s[2] = 0;
    s[3] = 0;
    s[4] = this._width;
    s[5] = this._height;
    s[6] = this.frameState.imgResX;
    s[7] = this.frameState.imgResY;
    device.queue.writeBuffer(
      this.halationDepthPrefilterBuffer,
      0,
      s.buffer,
      s.byteOffset,
      s.byteLength,
    );

    const bg = device.createBindGroup({
      label: "halation-depth-prefilter.bg",
      layout: this.layouts.diffusionDepthPrefilter,
      entries: [
        { binding: 0, resource: { buffer: this.halationDepthPrefilterBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: this.depthTexture.createView() },
        { binding: 3, resource: this.sampler },
      ],
    });

    const pass = encoder.beginRenderPass({
      label: "halation-depth-prefilter.pass",
      colorAttachments: [
        {
          view: scratchView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(this.pipelines.halationDepthPrefilter);
    pass.setBindGroup(0, this.offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();

    return scratchView;
  }

  private renderDiffusionPyramid(
    encoder: GPUCommandEncoder,
    sourceView: GPUTextureView,
    levels: GPUTexture[],
  ): GPUTexture {
    const { device } = this.ctx;
    const weights = WebGPUBackend.computeMipWeights(0.7, levels.length);

    // Step 1 — full-image first downsample: rt.colorGraded → levels[0].
    {
      const scratch = this.diffusionPyramid.downsampleScratch[0]!;
      scratch[0] = 1 / Math.max(this._width, 1);
      scratch[1] = 1 / Math.max(this._height, 1);
      scratch[2] = 0;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.diffusionPyramid.downsample[0]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: "diffusion.downsample.0.bg",
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.diffusionPyramid.downsample[0]! } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "diffusion.downsample.0",
        colorAttachments: [
          {
            view: levels[0]!.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.downsample);
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 2 — progressive downsample.
    for (let i = 1; i < levels.length; i++) {
      const src = levels[i - 1]!;
      const dst = levels[i]!;
      const scratch = this.diffusionPyramid.downsampleScratch[i]!;
      scratch[0] = 1 / src.width;
      scratch[1] = 1 / src.height;
      scratch[2] = 0;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.diffusionPyramid.downsample[i]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `diffusion.downsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.diffusionPyramid.downsample[i]! } },
          { binding: 1, resource: src.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `diffusion.downsample.${i}`,
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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 3 — additive upsample with the fixed wide diffusion radius.
    for (let i = levels.length - 2; i >= 0; i--) {
      const lowRes = levels[i + 1]!;
      const highRes = levels[i]!;
      const scratch = this.diffusionPyramid.upsampleScratch[i]!;
      scratch[0] = 1 / lowRes.width;
      scratch[1] = 1 / lowRes.height;
      scratch[2] = weights[i + 1]!;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.diffusionPyramid.upsample[i]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `diffusion.upsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.diffusionPyramid.upsample[i]! } },
          { binding: 1, resource: lowRes.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `diffusion.upsample.${i}`,
        colorAttachments: [
          {
            view: highRes.createView(),
            loadOp: "load",
            storeOp: "store",
          },
        ],
      });
      pass.setPipeline(this.pipelines.upsampleAdd);
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return levels[0]!;
  }

  /**
   * WebGL and the preserved dormant WebGPU temporal path use a 2-slot
   * half-resolution history for temporal hold. That history is reset under
   * four conditions:
   *   1. resolution change (handled in `setResolution`)
   *   2. `crossFilterStrength` transitions to 0
   *   3. `crossFilterHardMode` flip (0 ↔ 1)
   *   4. `crossFilterMinSpacing` crosses a small epsilon
   *
   * The latter three are detected here by snapshotting last-frame values.
   */
  private maybeResetCrossFilterHistory(
    strength: number,
    hardMode: 0 | 1,
    minSpacing: number,
  ): void {
    const reset = shouldResetCrossFilterHistory(
      {
        strength: this.lastCrossFilterStrength,
        hardMode: this.lastCrossFilterHardMode,
        minSpacing: this.lastCrossFilterMinSpacing,
      },
      { strength, hardMode, minSpacing },
    );
    if (reset) {
      this.crossFilterPeakHistoryWriteIndex = 0;
      this.crossFilterPeakHistoryFilledFrames = 0;
      this.lastCrossFilterHistoryTime = null;
    }
    this.lastCrossFilterStrength = strength;
    this.lastCrossFilterHardMode = hardMode;
    this.lastCrossFilterMinSpacing = minSpacing;
  }

  /**
   * Hard-mode central bloom, 4-level pyramid.
   *   1. seed mip 0 by downsampling the active peak mask (WebGL used held
   *      peaks; active WebGPU currently passes current peaks because the
   *      temporal hold is intentionally bypassed).
   *   2. progressive downsample mip 0 → mip 3.
   *   3. additive upsample back to mip 0 with fixed radius 0.5.
   *
   * Returns mip 0 so the caller can feed it to the cross-filter blend
   * shader's `uCentralBloom` binding. Mip 0 runs at quarter-resolution of
   * the full output (the peak texture is half-res, then we halve again on
   * seed).
   */
  private renderCentralBloom(
    encoder: GPUCommandEncoder,
    heldPeakTexture: GPUTexture,
  ): GPUTexture {
    const { device } = this.ctx;
    const halfWidth = Math.max(1, Math.floor(this._width / 2));
    const halfHeight = Math.max(1, Math.floor(this._height / 2));
    const levels: GPUTexture[] = [];
    for (let i = 0; i < CENTRAL_BLOOM_LEVELS; i++) {
      const divisor = 2 ** (i + 1);
      const w = Math.max(1, Math.floor(halfWidth / divisor));
      const h = Math.max(1, Math.floor(halfHeight / divisor));
      levels.push(
        this.pool.get(`rt.crossfilter.central-bloom.${i}`, {
          width: w,
          height: h,
          format: "rgba16float",
        }),
      );
    }
    const weights = WebGPUBackend.computeMipWeights(
      CENTRAL_BLOOM_RADIUS,
      levels.length,
    );

    const sourceView = heldPeakTexture.createView();

    // Step 1 — seed mip 0 via `downsample` pipeline (not prefilter):
    // heldPeak (half-res) → mip 0 (half-res / 2).
    {
      const scratch = this.centralBloomPyramid.downsampleScratch[0]!;
      scratch[0] = 1 / heldPeakTexture.width;
      scratch[1] = 1 / heldPeakTexture.height;
      scratch[2] = 0;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.centralBloomPyramid.downsample[0]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: "centralBloom.seed.bg",
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.centralBloomPyramid.downsample[0]! } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "centralBloom.seed",
        colorAttachments: [
          {
            view: levels[0]!.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.downsample);
      // Central bloom rides on the cross-filter (no-flip) contract for
      // every pass — mip 0 is sampled by `crossfilter.blend` alongside
      // the streak textures, which are themselves written under the
      // cross-filter contract. The generic bloom/halation pyramids use
      // the offscreen contract because they feed composite (which runs
      // under offscreen flags); this pyramid must NOT inherit that.
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 2 — progressive downsample mip[i-1] → mip[i].
    for (let i = 1; i < levels.length; i++) {
      const src = levels[i - 1]!;
      const dst = levels[i]!;
      const scratch = this.centralBloomPyramid.downsampleScratch[i]!;
      scratch[0] = 1 / src.width;
      scratch[1] = 1 / src.height;
      scratch[2] = 0;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.centralBloomPyramid.downsample[i]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `centralBloom.downsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.centralBloomPyramid.downsample[i]! } },
          { binding: 1, resource: src.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `centralBloom.downsample.${i}`,
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
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    // Step 3 — additive upsample back to mip 0.
    for (let i = levels.length - 2; i >= 0; i--) {
      const lowRes = levels[i + 1]!;
      const highRes = levels[i]!;
      const scratch = this.centralBloomPyramid.upsampleScratch[i]!;
      scratch[0] = 1 / lowRes.width;
      scratch[1] = 1 / lowRes.height;
      scratch[2] = weights[i + 1]!;
      scratch[3] = 0;
      device.queue.writeBuffer(
        this.centralBloomPyramid.upsample[i]!,
        0,
        scratch.buffer,
        scratch.byteOffset,
        scratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `centralBloom.upsample.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.centralBloomPyramid.upsample[i]! } },
          { binding: 1, resource: lowRes.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `centralBloom.upsample.${i}`,
        colorAttachments: [
          {
            view: highRes.createView(),
            loadOp: "load",
            storeOp: "store",
          },
        ],
      });
      pass.setPipeline(this.pipelines.upsampleAdd);
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return levels[0]!;
  }

  /**
   * Light shafts two-sub-pass rendering (WebGL parity):
   *   9a: radial blur at 1/4 resolution (64 taps, luminance threshold).
   *   9b: additive blend at full resolution.
   *
   * Returns a full-resolution texture the caller can feed to the next post
   * stage (motion blur / blit). Preserves WebGL activation semantics — the
   * caller is responsible for the `shaftIntensity > 0 && (crossFilter ||
   * motionBlur) active` gate.
   */
  private renderLightShafts(
    encoder: GPUCommandEncoder,
    sourceTexture: GPUTexture,
  ): GPUTexture {
    const { device } = this.ctx;
    const shaftWidth = Math.max(1, Math.floor(this._width / LIGHTSHAFTS_RES_DIVISOR));
    const shaftHeight = Math.max(1, Math.floor(this._height / LIGHTSHAFTS_RES_DIVISOR));
    const shaftTexture = this.pool.get("rt.lightshafts.quarter", {
      width: shaftWidth,
      height: shaftHeight,
      format: "rgba16float",
    });
    const blendOutput = this.pool.get("rt.lightshafts.output", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });

    const originX = Math.min(1, Math.max(0, this.paramNumber("shaftOriginX", 0.5)));
    const originYParam = Math.min(1, Math.max(0, this.paramNumber("shaftOriginY", 0.85)));
    const shaftDecay = Math.min(1, Math.max(0, this.paramNumber("shaftDecay", 0)));
    const shaftIntensity = Math.min(
      1,
      Math.max(0, this.paramNumber("shaftIntensity", 0)),
    );
    const decay = 0.92 + shaftDecay * 0.075;

    // Pack shaft shader params: (originX, 1-originY, decay, density), (exposure, _, _, _).
    const paramsScratch = this.lightShafts.paramsScratch;
    paramsScratch[0] = originX;
    paramsScratch[1] = 1 - originYParam;
    paramsScratch[2] = decay;
    paramsScratch[3] = LIGHTSHAFTS_DENSITY;
    paramsScratch[4] = LIGHTSHAFTS_EXPOSURE;
    paramsScratch[5] = 0;
    paramsScratch[6] = 0;
    paramsScratch[7] = 0;
    device.queue.writeBuffer(
      this.lightShafts.paramsBuffer,
      0,
      paramsScratch.buffer,
      paramsScratch.byteOffset,
      paramsScratch.byteLength,
    );

    const sourceView = sourceTexture.createView();
    {
      const bg = device.createBindGroup({
        label: "lightshafts.radial.bg",
        layout: this.layouts.lightshafts,
        entries: [
          { binding: 0, resource: { buffer: this.lightShafts.paramsBuffer } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "lightshafts.radial",
        colorAttachments: [
          {
            view: shaftTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.lightshafts);
      // Light shafts must stay on the no-flip (cross-filter) contract for
      // both subpasses. The blend pass samples uScene (post-composite,
      // upright) and uShafts at the same UV; inheriting the offscreen
      // (flipY=0 → flips) contract here would invert the shaft RT
      // relative to the scene input and desync origin / decay.
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    const blendParamsScratch = this.lightShafts.blendParamsScratch;
    blendParamsScratch[0] = shaftIntensity;
    blendParamsScratch[1] = 0;
    blendParamsScratch[2] = 0;
    blendParamsScratch[3] = 0;
    device.queue.writeBuffer(
      this.lightShafts.blendParamsBuffer,
      0,
      blendParamsScratch.buffer,
      blendParamsScratch.byteOffset,
      blendParamsScratch.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "lightshafts.blend.bg",
        layout: this.layouts.lightshaftsBlend,
        entries: [
          { binding: 0, resource: { buffer: this.lightShafts.blendParamsBuffer } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: shaftTexture.createView() },
          { binding: 3, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "lightshafts.blend",
        colorAttachments: [
          {
            view: blendOutput.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.lightshaftsBlend);
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return blendOutput;
  }

  private renderCrossFilter(
    encoder: GPUCommandEncoder,
    sourceTexture: GPUTexture,
  ): GPUTexture {
    const { device } = this.ctx;
    const strength = Math.min(1, Math.max(0, this.paramNumber("crossFilterStrength", 0)));
    if (strength <= 0) {
      return sourceTexture;
    }

    const halfWidth = Math.max(1, Math.floor(this._width / 2));
    const halfHeight = Math.max(1, Math.floor(this._height / 2));
    const thresholdTexture = this.pool.get("rt.crossfilter.threshold", {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    });
    const peakTexture = this.pool.get("rt.crossfilter.peak", {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    });
    const spacingWorkTexture = this.pool.get("rt.crossfilter.spacing-work", {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    });
    const spacingMaxTexture = this.pool.get("rt.crossfilter.spacing-max", {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    });
    const spacingTexture = this.pool.get("rt.crossfilter.spacing", {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    });
    const streakTextures = Array.from({ length: CROSS_FILTER_MAX_STREAKS }, (_, index) =>
      this.pool.get(`rt.crossfilter.streak.${index}`, {
        width: halfWidth,
        height: halfHeight,
        format: "rgba16float",
      }),
    );
    const outputTexture = this.pool.get("rt.crossfilter.output", {
      width: this._width,
      height: this._height,
      format: "rgba16float",
    });

    const hardModeActive = this.paramNumber("crossFilterHardMode", 0) >= 0.5;
    const hardModeUniform = hardModeActive ? 1 : 0;
    const threshold = Math.min(1, Math.max(0, this.paramNumber("crossFilterThreshold", 0.8)));
    const sizeLimit = Math.min(1, Math.max(0, this.paramNumber("crossFilterSizeLimit", 0)));
    const randomness = Math.min(1, Math.max(0, this.paramNumber("crossFilterRandomness", 1)));
    const length = Math.min(1, Math.max(0, this.paramNumber("crossFilterLength", 0.5)));
    const chromatic = Math.min(1, Math.max(0, this.paramNumber("crossFilterChromatic", 0.3)));
    const minSpacing = Math.min(
      CROSS_FILTER_MIN_SPACING_MAX,
      Math.max(CROSS_FILTER_MIN_SPACING_MIN, this.paramNumber("crossFilterMinSpacing", 1)),
    );
    const rawSpikes = Math.max(2, Math.round(this.paramNumber("crossFilterSpikes", 4)));
    const spikeCount = rawSpikes % 2 === 0 ? rawSpikes : rawSpikes + 1;
    const dirCount = Math.max(
      1,
      Math.min(CROSS_FILTER_MAX_STREAKS, Math.floor(spikeCount / 2)),
    );
    const angleRad = (this.paramNumber("crossFilterAngle", 0) * Math.PI) / 180;
    const effectiveThreshold = computeCrossFilterEffectiveThreshold(
      threshold,
      hardModeActive,
    );
    const effectiveSizeLimit = hardModeActive ? 1.0 : sizeLimit;
    const effectiveRandomness = hardModeActive ? 1.0 : randomness;

    const sourceView = sourceTexture.createView();
    const blackView = this.crossFilter.blackTexture.createView();

    this.crossFilter.thresholdScratch[0] = effectiveThreshold;
    this.crossFilter.thresholdScratch[1] = 0.1;
    this.crossFilter.thresholdScratch[2] = 0;
    this.crossFilter.thresholdScratch[3] = 0;
    device.queue.writeBuffer(
      this.crossFilter.thresholdBuffer,
      0,
      this.crossFilter.thresholdScratch.buffer,
      this.crossFilter.thresholdScratch.byteOffset,
      this.crossFilter.thresholdScratch.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "crossfilter.threshold.bg",
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.crossFilter.thresholdBuffer } },
          { binding: 1, resource: sourceView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.threshold",
        colorAttachments: [
          {
            view: thresholdTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.bloomPrefilter);
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    this.crossFilter.peakScratch[0] = 1 / halfWidth;
    this.crossFilter.peakScratch[1] = 1 / halfHeight;
    this.crossFilter.peakScratch[2] = effectiveSizeLimit;
    this.crossFilter.peakScratch[3] = 0;
    device.queue.writeBuffer(
      this.crossFilter.peakBuffer,
      0,
      this.crossFilter.peakScratch.buffer,
      this.crossFilter.peakScratch.byteOffset,
      this.crossFilter.peakScratch.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "crossfilter.peak.bg",
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.crossFilter.peakBuffer } },
          { binding: 1, resource: thresholdTexture.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.peak",
        colorAttachments: [
          {
            view: peakTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.crossFilterPeak);
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    let currentPeakTexture = peakTexture;
    if (minSpacing >= 0.001) {
      const radiusPx = computeCrossFilterSpacingRadiusPx(minSpacing);

      const spacingMaxScratchX = this.crossFilter.spacingMaxScratch[0]!;
      spacingMaxScratchX[0] = 1 / halfWidth;
      spacingMaxScratchX[1] = 1 / halfHeight;
      spacingMaxScratchX[2] = 1;
      spacingMaxScratchX[3] = 0;
      spacingMaxScratchX[4] = radiusPx;
      spacingMaxScratchX[5] = 0;
      spacingMaxScratchX[6] = 0;
      spacingMaxScratchX[7] = 0;
      device.queue.writeBuffer(
        this.crossFilter.spacingMaxBuffers[0]!,
        0,
        spacingMaxScratchX.buffer,
        spacingMaxScratchX.byteOffset,
        spacingMaxScratchX.byteLength,
      );
      {
        const bg = device.createBindGroup({
          label: "crossfilter.spacing-max-x.bg",
          layout: this.layouts.pyramid,
          entries: [
            { binding: 0, resource: { buffer: this.crossFilter.spacingMaxBuffers[0]! } },
            { binding: 1, resource: peakTexture.createView() },
            { binding: 2, resource: this.sampler },
          ],
        });
        const pass = encoder.beginRenderPass({
          label: "crossfilter.spacing-max-x",
          colorAttachments: [
            {
              view: spacingWorkTexture.createView(),
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        pass.setPipeline(this.pipelines.crossFilterPeakSpacingMax);
        pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
        pass.setBindGroup(1, bg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }

      const spacingMaxScratchY = this.crossFilter.spacingMaxScratch[1]!;
      spacingMaxScratchY[0] = 1 / halfWidth;
      spacingMaxScratchY[1] = 1 / halfHeight;
      spacingMaxScratchY[2] = 0;
      spacingMaxScratchY[3] = 1;
      spacingMaxScratchY[4] = radiusPx;
      spacingMaxScratchY[5] = 1;
      spacingMaxScratchY[6] = 0;
      spacingMaxScratchY[7] = 0;
      device.queue.writeBuffer(
        this.crossFilter.spacingMaxBuffers[1]!,
        0,
        spacingMaxScratchY.buffer,
        spacingMaxScratchY.byteOffset,
        spacingMaxScratchY.byteLength,
      );
      {
        const bg = device.createBindGroup({
          label: "crossfilter.spacing-max-y.bg",
          layout: this.layouts.pyramid,
          entries: [
            { binding: 0, resource: { buffer: this.crossFilter.spacingMaxBuffers[1]! } },
            { binding: 1, resource: spacingWorkTexture.createView() },
            { binding: 2, resource: this.sampler },
          ],
        });
        const pass = encoder.beginRenderPass({
          label: "crossfilter.spacing-max-y",
          colorAttachments: [
            {
              view: spacingMaxTexture.createView(),
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        pass.setPipeline(this.pipelines.crossFilterPeakSpacingMax);
        pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
        pass.setBindGroup(1, bg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }

      this.crossFilter.spacingScratch[0] = 1 / halfWidth;
      this.crossFilter.spacingScratch[1] = 1 / halfHeight;
      this.crossFilter.spacingScratch[2] = minSpacing;
      this.crossFilter.spacingScratch[3] = 0;
      device.queue.writeBuffer(
        this.crossFilter.spacingBuffer,
        0,
        this.crossFilter.spacingScratch.buffer,
        this.crossFilter.spacingScratch.byteOffset,
        this.crossFilter.spacingScratch.byteLength,
      );
      {
        const bg = device.createBindGroup({
          label: "crossfilter.spacing.bg",
          layout: this.layouts.crossFilterPeakSpacing,
          entries: [
            { binding: 0, resource: { buffer: this.crossFilter.spacingBuffer } },
            { binding: 1, resource: peakTexture.createView() },
            { binding: 2, resource: spacingMaxTexture.createView() },
            { binding: 3, resource: this.sampler },
          ],
        });
        const pass = encoder.beginRenderPass({
          label: "crossfilter.spacing",
          colorAttachments: [
            {
              view: spacingTexture.createView(),
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        pass.setPipeline(this.pipelines.crossFilterPeakSpacing);
        pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
        pass.setBindGroup(1, bg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }

      currentPeakTexture = spacingTexture;
    }

    // Active WebGPU Hard Mode intentionally bypasses the legacy temporal
    // hold so current peaks feed both central bloom and the streak march
    // directly. Keep the dormant temporal path behind a feature flag so
    // the preserved history resources/state and elapsed-time normalization
    // work remain intact without affecting the live product behavior.
    let heldPeakTexture = currentPeakTexture;
    if (hardModeActive && WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED) {
      const historyTextures = [
        this.pool.get("rt.crossfilter.peak-history.0", {
          width: halfWidth,
          height: halfHeight,
          format: "rgba16float",
        }),
        this.pool.get("rt.crossfilter.peak-history.1", {
          width: halfWidth,
          height: halfHeight,
          format: "rgba16float",
        }),
      ];
      const writeIndex =
        this.crossFilterPeakHistoryWriteIndex % CROSS_FILTER_HISTORY_SLOTS;
      const prevIndex =
        (writeIndex + CROSS_FILTER_HISTORY_SLOTS - 1) % CROSS_FILTER_HISTORY_SLOTS;
      const prevTexture =
        this.crossFilterPeakHistoryFilledFrames > 0
          ? historyTextures[prevIndex]!
          : this.crossFilter.blackTexture;
      const writeTexture = historyTextures[writeIndex]!;
      const temporalDeltaSeconds =
        this.lastCrossFilterHistoryTime === null
          ? 1 / CROSS_FILTER_TEMPORAL_REFERENCE_FPS
          : this.frameState.time - this.lastCrossFilterHistoryTime;
      const temporalDecay = computeCrossFilterTemporalDecay(temporalDeltaSeconds);

      this.crossFilter.temporalScratch[0] = temporalDecay;
      this.crossFilter.temporalScratch[1] = 0;
      this.crossFilter.temporalScratch[2] = 0;
      this.crossFilter.temporalScratch[3] = 0;
      device.queue.writeBuffer(
        this.crossFilter.temporalBuffer,
        0,
        this.crossFilter.temporalScratch.buffer,
        this.crossFilter.temporalScratch.byteOffset,
        this.crossFilter.temporalScratch.byteLength,
      );
      const temporalBg = device.createBindGroup({
        label: "crossfilter.temporal.bg",
        layout: this.layouts.crossFilterTemporal,
        entries: [
          { binding: 0, resource: { buffer: this.crossFilter.temporalBuffer } },
          { binding: 1, resource: currentPeakTexture.createView() },
          { binding: 2, resource: prevTexture.createView() },
          { binding: 3, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.temporal",
        colorAttachments: [
          {
            view: writeTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.crossFilterTemporal);
      // Stay on the cross-filter (no-flip) contract so heldPeakTexture
      // shares the upright row order with the rest of the post-peak
      // subchain (spacing → streak → blend). Using the offscreen contract
      // here would inject an asymmetric Y flip and mirror the held peak
      // mask relative to the source frame.
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, temporalBg);
      pass.draw(3, 1, 0, 0);
      pass.end();

      heldPeakTexture = writeTexture;
      this.crossFilterPeakHistoryWriteIndex =
        (writeIndex + 1) % CROSS_FILTER_HISTORY_SLOTS;
      this.crossFilterPeakHistoryFilledFrames = Math.min(
        this.crossFilterPeakHistoryFilledFrames + 1,
        CROSS_FILTER_HISTORY_SLOTS,
      );
      this.lastCrossFilterHistoryTime = this.frameState.time;
    }

    // Hard-mode central bloom (skipped entirely in Soft Mode; the blend
    // shader multiplies the bloom term by `uHardMode` so a black texture
    // would zero it out, but building the pyramid anyway wastes GPU time).
    let centralBloomTexture: GPUTexture | null = null;
    if (hardModeActive) {
      centralBloomTexture = this.renderCentralBloom(encoder, heldPeakTexture);
    }

    const hash = (seed: number): number => {
      const value = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
      return value - Math.floor(value);
    };

    for (let i = 0; i < dirCount; i++) {
      const seed = i * 17 + 7;
      const angleJitter = (hash(seed) - 0.5) * 2 * (5 * Math.PI / 180);
      const lengthMul = 1.0 + (hash(seed + 1) - 0.5) * 0.5;
      const brightMul = 1.0 + (hash(seed + 2) - 0.5) * 0.4;
      const dirAngle = angleRad + (i * Math.PI) / dirCount + angleJitter;
      const streakScratch = this.crossFilter.streakScratch[i]!;
      streakScratch[0] = Math.cos(dirAngle);
      streakScratch[1] = Math.sin(dirAngle);
      streakScratch[2] = 1 / heldPeakTexture.width;
      streakScratch[3] = 1 / heldPeakTexture.height;
      streakScratch[4] = length * lengthMul;
      streakScratch[5] = chromatic;
      streakScratch[6] = brightMul;
      streakScratch[7] = effectiveRandomness;
      streakScratch[8] = hardModeUniform;
      streakScratch[9] = 0;
      streakScratch[10] = 0;
      streakScratch[11] = 0;
      device.queue.writeBuffer(
        this.crossFilter.streakBuffers[i]!,
        0,
        streakScratch.buffer,
        streakScratch.byteOffset,
        streakScratch.byteLength,
      );
      const bg = device.createBindGroup({
        label: `crossfilter.streak.${i}.bg`,
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.crossFilter.streakBuffers[i]! } },
          { binding: 1, resource: heldPeakTexture.createView() },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: `crossfilter.streak.${i}`,
        colorAttachments: [
          {
            view: streakTextures[i]!.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.crossFilterStreak);
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    this.crossFilter.blendScratch[0] = dirCount;
    this.crossFilter.blendScratch[1] = strength;
    this.crossFilter.blendScratch[2] = hardModeUniform;
    this.crossFilter.blendScratch[3] = 0;
    device.queue.writeBuffer(
      this.crossFilter.blendBuffer,
      0,
      this.crossFilter.blendScratch.buffer,
      this.crossFilter.blendScratch.byteOffset,
      this.crossFilter.blendScratch.byteLength,
    );
    {
      const centralBloomView = centralBloomTexture
        ? centralBloomTexture.createView()
        : blackView;
      const blendEntries: GPUBindGroupEntry[] = [
        { binding: 0, resource: { buffer: this.crossFilter.blendBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: dirCount >= 1 ? streakTextures[0]!.createView() : blackView },
        { binding: 3, resource: dirCount >= 2 ? streakTextures[1]!.createView() : blackView },
        { binding: 4, resource: dirCount >= 3 ? streakTextures[2]!.createView() : blackView },
        { binding: 5, resource: dirCount >= 4 ? streakTextures[3]!.createView() : blackView },
        { binding: 6, resource: centralBloomView },
        { binding: 7, resource: this.sampler },
      ];
      const bg = device.createBindGroup({
        label: "crossfilter.blend.bg",
        layout: this.layouts.crossFilterBlend,
        entries: blendEntries,
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.blend",
        colorAttachments: [
          {
            view: outputTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.crossFilterBlend);
      pass.setBindGroup(0, this.crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    return outputTexture;
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

    // Cross-filter hard-mode gate is needed before uniform upload because
    // the composite uniform zeroes its diffusion slot when hard mode is
    // active. It also drives the temporal-history reset heuristic.
    const crossFilterStrength = Math.min(
      1,
      Math.max(0, this.paramNumber("crossFilterStrength", 0)),
    );
    const crossFilterHardModeRaw = this.paramNumber("crossFilterHardMode", 0);
    const crossFilterHardMode = crossFilterHardModeRaw >= 0.5 ? 1 : 0;
    const crossFilterMinSpacing = Math.min(
      CROSS_FILTER_MIN_SPACING_MAX,
      Math.max(CROSS_FILTER_MIN_SPACING_MIN, this.paramNumber("crossFilterMinSpacing", 1)),
    );
    this.maybeResetCrossFilterHistory(
      crossFilterStrength,
      crossFilterHardMode,
      crossFilterMinSpacing,
    );
    const hardModeActive = isCrossFilterHardModeActive(
      crossFilterStrength,
      crossFilterHardMode,
    );

    this.uploadFrameUniforms(hardModeActive);

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
    // Hard-mode suppresses the diffusion pyramid build (parity with
    // WebGL's `renderBasePipeline`). The composite-input uniform is
    // independently zeroed inside `uploadFrameUniforms`.
    const diffusionAmount = effectiveDiffusionAmount(
      this.paramNumber("diffusion", 0),
      hardModeActive,
    );

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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, filmlabBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    const colorGradedView = rtColorGraded.createView();

    // Shared depth-aware Mist / Glow controls.
    //   - `depthMistGain` drives the diffusion (Mist) pyramid prefilter and
    //     the composite `>= 1.5` debug view.
    //   - `depthGlowGain` drives the bloom + halation pyramid prefilters.
    // Both live in `(0, 1.5)` when active; values >= 1.5 on `depthMistGain`
    // switch composite into the raw-depth debug view and skip prefiltering.
    // Splitting the two gains lets the shared contract modulate Mist and
    // Glow independently. Lens and Cross pillars are out of scope by design — see
    // `docs/guides/2026-04-20-filmtone-optical-finish-pack-master-plan.md` §2.3.
    const depthMistGain = this.paramNumber("depthMistGain", 0);
    const depthGlowGain = this.paramNumber("depthGlowGain", 0);
    const depthMistActive = depthMistGain > 0 && depthMistGain < 1.5;
    const depthGlowActive = depthGlowGain > 0 && depthGlowGain < 1.5;

    // Pass 2 — bloom pyramid (prefilter → downsample → additive upsample).
    const bloomRadius = this.paramNumber("bloomRadius", DEFAULT_BLOOM_RADIUS);
    const bloomSourceView = depthGlowActive
      ? this.renderBloomDepthPrefilter(encoder, colorGradedView, depthGlowGain)
      : colorGradedView;
    const bloomTop = this.renderPyramidChain(
      encoder,
      "bloom",
      this.pipelines.bloomPrefilter,
      this.bloomParamsBuffer,
      bloomSourceView,
      bloomLevels,
      this.bloomPyramid,
      bloomRadius,
    );

    // Pass 3 — halation pyramid (same shape, tinted prefilter).
    const halationRadius = this.paramNumber("halationRadius", DEFAULT_HALATION_RADIUS);
    const halationSourceView = depthGlowActive
      ? this.renderHalationDepthPrefilter(encoder, colorGradedView, depthGlowGain)
      : colorGradedView;
    const halationTop = this.renderPyramidChain(
      encoder,
      "halation",
      this.pipelines.halationPrefilter,
      this.halationParamsBuffer,
      halationSourceView,
      halationLevels,
      this.halationPyramid,
      halationRadius,
    );

    let diffusionView = this.grainTexture.createView();
    if (diffusionAmount > 0) {
      const diffusionLevels = this.ensurePyramidLevels("rt.diffusion", DIFFUSION_LEVELS);
      // Shared depth-aware Mist path: build the diffusion pyramid from a
      // depth-weighted source mask instead of the raw colorGraded view.
      // The composite no longer modulates the halo by depth (see
      // `composite.frag.wgsl.ts`), so all depth shaping is baked into the
      // pyramid input. Values >= 1.5 on `depthMistGain` are reserved for
      // the composite debug view and should bypass prefiltering —
      // `depthMistActive` gates this above.
      const pyramidInputView = depthMistActive
        ? this.renderDiffusionDepthPrefilter(encoder, colorGradedView, depthMistGain)
        : colorGradedView;
      diffusionView = this.renderDiffusionPyramid(
        encoder,
        pyramidInputView,
        diffusionLevels,
      ).createView();
    }

    // Pass 5 — composite into rgba16float intermediate. When motion blur
    // is OFF we blit this straight to swap; when ON, it feeds the ring.
    const compositeBg = device.createBindGroup({
      label: "composite.bg",
      layout: this.layouts.composite,
      entries: [
        { binding: 0, resource: { buffer: this.compositeBuffer } },
        { binding: 1, resource: colorGradedView },
        { binding: 2, resource: bloomTop.createView() },
        { binding: 3, resource: halationTop.createView() },
        { binding: 4, resource: diffusionView },
        { binding: 5, resource: this.sampler },
        { binding: 6, resource: this.grainSampler },
        { binding: 7, resource: this.depthTexture.createView() },
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
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, compositeBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    let postCompositeTexture = this.renderCrossFilter(encoder, rtComposited);

    // Pass 6 — post-chain → swap.
    const swapView = this.ctx.getCurrentTextureView();
    const readbackView = this.readbackEnabled
      ? this.pool
          .get("rt.present.readback", {
            width: this._width,
            height: this._height,
            format: this.ctx.canvasFormat,
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.COPY_SRC,
          })
          .createView()
      : null;
    const shutterAngle = this.paramNumber("shutterAngle", 0);
    const motionBlurOn = shutterAngle > 0;

    // Light shafts (WebGL parity): run after cross-filter, before motion
    // blur. Activation matches WebGL: the post chain must be active via
    // cross-filter or motion blur, and `shaftIntensity > 0`. Dust /
    // Scratches stays deferred on WebGPU in v1.
    const shaftIntensity = Math.min(
      1,
      Math.max(0, this.paramNumber("shaftIntensity", 0)),
    );
    const postChainActive = crossFilterStrength > 0 || motionBlurOn;
    if (shaftIntensity > 0 && postChainActive) {
      postCompositeTexture = this.renderLightShafts(
        encoder,
        postCompositeTexture,
      );
    }
    const postCompositeView = postCompositeTexture.createView();

    // Compare branch: when toggled, replace both the blit and the
    // motion-blur present passes with a split compare pass
    // (`left = raw source`, `right = graded output`, divider line).
    // Motion blur is skipped while compare is on (`compare > motion blur`).
    if (this.frameState.compareEnabled) {
      this.compareSourceScratch[0] = this._width;
      this.compareSourceScratch[1] = this._height;
      this.compareSourceScratch[2] = this.frameState.imgResX;
      this.compareSourceScratch[3] = this.frameState.imgResY;
      this.compareSourceScratch[4] = this.frameState.fitMode;
      this.compareSourceScratch[5] = this.frameState.splitPosition >= 0
        ? this.frameState.splitPosition
        : 0.5;
      this.compareSourceScratch[6] = 2.0;
      this.compareSourceScratch[7] = 0;
      device.queue.writeBuffer(
        this.compareSourceBuffer,
        0,
        this.compareSourceScratch.buffer,
        this.compareSourceScratch.byteOffset,
        this.compareSourceScratch.byteLength,
      );
      const compareBg = device.createBindGroup({
        label: "compare-source.bg",
        layout: this.layouts.compareSource,
        entries: [
          { binding: 0, resource: { buffer: this.compareSourceBuffer } },
          { binding: 1, resource: mediaTexture.createView() },
          { binding: 2, resource: postCompositeView },
          { binding: 3, resource: this.sampler },
        ],
      });
      if (readbackView) {
        const readbackPass = encoder.beginRenderPass({
          label: "compare-source.readback.pass",
          colorAttachments: [
            {
              view: readbackView,
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        readbackPass.setPipeline(this.pipelines.compareSource);
        readbackPass.setBindGroup(0, this.displayFlagsBindGroup);
        readbackPass.setBindGroup(1, compareBg);
        readbackPass.draw(3, 1, 0, 0);
        readbackPass.end();
      }
      const pass = encoder.beginRenderPass({
        label: "compare-source.present.pass",
        colorAttachments: [
          {
            view: swapView,
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.compareSource);
      pass.setBindGroup(0, this.displayFlagsBindGroup);
      pass.setBindGroup(1, compareBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    } else if (!motionBlurOn) {
      const blitBg = device.createBindGroup({
        label: "blit.bg",
        layout: this.layouts.blit,
        entries: [
          { binding: 0, resource: postCompositeView },
          { binding: 1, resource: this.sampler },
        ],
      });
      if (readbackView) {
        const readbackPass = encoder.beginRenderPass({
          label: "blit.readback.pass",
          colorAttachments: [
            {
              view: readbackView,
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        readbackPass.setPipeline(this.pipelines.blit);
        readbackPass.setBindGroup(0, this.displayFlagsBindGroup);
        readbackPass.setBindGroup(1, blitBg);
        readbackPass.draw(3, 1, 0, 0);
        readbackPass.end();
      }
      const pass = encoder.beginRenderPass({
        label: "blit.present.pass",
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
      pass.setBindGroup(0, this.displayFlagsBindGroup);
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
          { binding: 1, resource: postCompositeView },
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
        pass.setBindGroup(0, this.offscreenFlagsBindGroup);
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
      if (readbackView) {
        const readbackPass = encoder.beginRenderPass({
          label: "motionblur.blend.readback.pass",
          colorAttachments: [
            {
              view: readbackView,
              loadOp: "clear",
              storeOp: "store",
              clearValue: { r: 0, g: 0, b: 0, a: 1 },
            },
          ],
        });
        readbackPass.setPipeline(this.pipelines.motionblurBlend);
        readbackPass.setBindGroup(0, this.displayFlagsBindGroup);
        readbackPass.setBindGroup(1, blendBg);
        readbackPass.draw(3, 1, 0, 0);
        readbackPass.end();
      }
      {
        const pass = encoder.beginRenderPass({
          label: "motionblur.blend.present.pass",
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
        pass.setBindGroup(0, this.displayFlagsBindGroup);
        pass.setBindGroup(1, blendBg);
        pass.draw(3, 1, 0, 0);
        pass.end();
      }
    }

    device.queue.submit([encoder.finish()]);
    this.hasReadableFrame = this.readbackEnabled;
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
    this.hasReadableFrame = false;
    // RingBuffer resize re-allocates the 8-layer array texture and
    // resets validSlots → 0 so stale content can't bleed through the
    // weighted average after a viewport change.
    this.ringBuffer.resize(w, h);
    // Cross-filter temporal history lives in the pool under labeled
    // half-resolution textures; those are destroyed + recreated on the
    // next `pool.get` when dimensions change. We still drop the filled
    // counter here so the first post-resize frame reads the black
    // fallback, not the undefined contents of the freshly allocated
    // textures.
    this.crossFilterPeakHistoryWriteIndex = 0;
    this.crossFilterPeakHistoryFilledFrames = 0;
    this.lastCrossFilterHistoryTime = null;
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
    this.displayFlagsBuffer.destroy();
    this.offscreenFlagsBuffer.destroy();
    this.crossFilterFlagsBuffer.destroy();
    this.gradeBuffer.destroy();
    this.compositeBuffer.destroy();
    this.bloomParamsBuffer.destroy();
    this.halationParamsBuffer.destroy();
    this.motionblurFeedbackBuffer.destroy();
    this.motionblurBlendBuffer.destroy();
    this.crossFilter.thresholdBuffer.destroy();
    this.crossFilter.peakBuffer.destroy();
    this.crossFilter.spacingBuffer.destroy();
    this.crossFilter.temporalBuffer.destroy();
    this.crossFilter.blendBuffer.destroy();
    for (const buf of this.crossFilter.spacingMaxBuffers) buf.destroy();
    for (const buf of this.crossFilter.streakBuffers) buf.destroy();
    this.crossFilter.blackTexture.destroy();
    this.lightShafts.paramsBuffer.destroy();
    this.lightShafts.blendParamsBuffer.destroy();
    this.readbackBuffer?.destroy();
    for (const buf of this.bloomPyramid.downsample) buf.destroy();
    for (const buf of this.bloomPyramid.upsample) buf.destroy();
    for (const buf of this.halationPyramid.downsample) buf.destroy();
    for (const buf of this.halationPyramid.upsample) buf.destroy();
    for (const buf of this.diffusionPyramid.downsample) buf.destroy();
    for (const buf of this.diffusionPyramid.upsample) buf.destroy();
    for (const buf of this.centralBloomPyramid.downsample) buf.destroy();
    for (const buf of this.centralBloomPyramid.upsample) buf.destroy();
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

  private ensureReadbackBuffer(size: number): GPUBuffer {
    if (this.readbackBuffer && this.readbackBufferSize === size) {
      return this.readbackBuffer;
    }
    this.readbackBuffer?.destroy();
    this.readbackBuffer = this.ctx.device.createBuffer({
      label: "filmtone.readback.buffer",
      size,
      usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ,
    });
    this.readbackBufferSize = size;
    return this.readbackBuffer;
  }
}
