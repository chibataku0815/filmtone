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
 *   6. Post-chain (active when `crossFilterStrength > 0`,
 *      `haloPrismStrength > 0`, or `shutterAngle > 180`):
 *      - Cross-filter: compact source gate → peak → optional spacing gate →
 *        (Hard-mode only) active WebGPU intentionally bypasses the
 *        legacy temporal hold so the 4-level central-bloom chain and
 *        directional streaks read current peaks directly, while the
 *        preserved temporal infrastructure remains available for future
 *        tuning → blend with center-protection.
 *      - Halo Prism (when `haloPrismStrength > 0`): compact source gate
 *        from the pre-Halo composite → chromatic annular arcs.
 *      - Light Shafts (when `shaftIntensity > 0` and post chain active):
 *        radial 64-tap occlusion at ¼ res → additive full-res blend.
 *      - Motion blur (`shutterAngle > 180`): feedback copy into the ring
 *        (`depthOrArrayLayers=8`, DIRECTION §4) → weighted blend of the
 *        last N slots → swap.
 *      - Motion blur OFF: blit the post-composite source → swap.
 *
 *   Active WebGPU post tail: `CrossFilter → HaloPrism → Shafts → MotionBlur`.
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
 *     state), Halo Prism (`haloPrismStrength`, radius / width / chroma /
 *     source coupling), and light shafts (`shaftIntensity`, `shaftDecay`,
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
import {
  deriveDetailSoftnessUniforms,
  type CameraOptics,
} from "film-lab-core";
import { MediaTexture } from "./MediaTexture";
import { OffscreenTargetPool } from "./OffscreenTargetPool";
import { Lut3DTexture } from "./Lut3DTexture";
import { BlueNoiseTile } from "./BlueNoiseTile";
import { RingBuffer } from "./RingBuffer";
import { isShutterMotionActive } from "../motionBlurMath";
import {
  fullscreenVertexWgsl,
  filmlabFragmentWgsl,
  blitFragmentWgsl,
  compareSourceFragmentWgsl,
  compositeFragmentWgsl,
  detailSoftnessFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  diffusionDepthPrefilterFragmentWgsl,
  bloomDepthPrefilterFragmentWgsl,
  halationDepthPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  haloPrismFragmentWgsl,
  dustFragmentWgsl,
  motionblurFeedbackFragmentWgsl,
  motionblurBlendFragmentWgsl,
  crossFilterSourceFragmentWgsl,
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
import {
  DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
  resolveRayAngleOptics,
  type ResolvedRayAngleOptics,
} from "./rayAngleOptics";
import type { RenderBackend, RenderBackendParams } from "./Backend";
import type { ViewportCapabilities } from "../RendererRuntime";
import type {
  ShaderModules,
  Pipelines,
  PrefilterGroupLayouts,
  PyramidResources,
  CrossFilterResources,
  LightShaftsResources,
  HaloPrismResources,
} from "./passes/types";
import {
  computeMipWeights as computeMipWeightsPass,
  ensurePyramidLevels as ensurePyramidLevelsPass,
  renderPyramidChain as renderPyramidChainPass,
} from "./passes/pyramid";
import { renderBloomDepthPrefilter as renderBloomDepthPrefilterPass } from "./passes/bloom";
import { renderHalationDepthPrefilter as renderHalationDepthPrefilterPass } from "./passes/halation";
import {
  renderDiffusionDepthPrefilter as renderDiffusionDepthPrefilterPass,
  renderDiffusionPyramid as renderDiffusionPyramidPass,
} from "./passes/diffusion";
import { renderLightShafts as renderLightShaftsPass } from "./passes/lightShafts";
import { renderHaloPrism as renderHaloPrismPass } from "./passes/haloPrism";
import { renderCrossFilter as renderCrossFilterPass } from "./passes/crossFilter";
import { renderMotionBlurChain as renderMotionBlurChainPass } from "./passes/motionBlur";

const IDENTITY_LUT_SIZE = 33;
const BLOOM_LEVELS = 5;
const HALATION_LEVELS = 6;
const DIFFUSION_LEVELS = 3;
const BLOOM_PARAMS_BYTES = 16;
const HALATION_PARAMS_BYTES = 32;
const DETAIL_SOFTNESS_PARAMS_BYTES = 48;
const PYRAMID_LEVEL_UNIFORM_BYTES = 16;
const MOTIONBLUR_FEEDBACK_UNIFORM_BYTES = 16;
/** weights (2 vec4) + ring control (1 vec4) = 48 bytes. */
const MOTIONBLUR_BLEND_UNIFORM_BYTES = 48;
const MOTIONBLUR_BLEND_UNIFORM_FLOATS = MOTIONBLUR_BLEND_UNIFORM_BYTES / 4;
const CROSS_FILTER_PARAMS_BYTES = 16;
const CROSS_FILTER_SPACING_MAX_BYTES = 32;
const CROSS_FILTER_STREAK_BYTES = 96;
const CROSS_FILTER_MAX_STREAKS = 4;
// CROSS_FILTER_SPACING_RADIUS_MAX_PX / STEP_PX, CROSS_FILTER_THRESHOLD_HARD_/
// CONTROL_BASELINE, CROSS_FILTER_HISTORY_SLOTS,
// WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED, CENTRAL_BLOOM_RADIUS,
// smoothstep01, computeCrossFilterEffectiveThreshold,
// computeCrossFilterSpacingRadiusPx, and the DEFAULT_CROSS_FILTER_* gains
// moved to `./passes/crossFilter` (sole consumer was `renderCrossFilter` /
// `renderCentralBloom`).
/** Exported: also read directly by `renderFrame` and `./passes/crossFilter`. */
export const CROSS_FILTER_MIN_SPACING_MIN = 1.0;
export const CROSS_FILTER_MIN_SPACING_MAX = 10.0;
/** Hard-mode central bloom pyramid depth (WebGL parity). */
const CENTRAL_BLOOM_LEVELS = 4;
// LIGHTSHAFTS_RES_DIVISOR / LIGHTSHAFTS_DENSITY / LIGHTSHAFTS_EXPOSURE moved
// to `./passes/lightShafts` (sole consumer was `renderLightShafts`).
/** Light shafts uniform layouts. */
const LIGHTSHAFTS_PARAMS_BYTES = 32;
const LIGHTSHAFTS_BLEND_PARAMS_BYTES = 16;
/** Halo Prism uniforms: 5 vec4 = 80 bytes. */
const HALO_PRISM_PARAMS_BYTES = 80;
const HALO_PRISM_PARAMS_FLOATS = HALO_PRISM_PARAMS_BYTES / 4;

const DEFAULT_BLOOM_THRESHOLD = 0.8;
const DEFAULT_BLOOM_KNEE = 0.5;
const DEFAULT_BLOOM_RADIUS = 0.5;
const DEFAULT_HALATION_THRESHOLD = 0.6;
const DEFAULT_HALATION_KNEE = 0.5;
const DEFAULT_HALATION_RADIUS = 0.5;
const DEFAULT_HALATION_COLOR: [number, number, number] = [0.91, 0.063, 0.125];
/** Exported: also read directly by `./passes/crossFilter`. */
export const DEFAULT_DEPTH_RAY_ANGLE_GAMMA = 1.4;
const DEFAULT_DEPTH_MIST_RAY_ANGLE_GAIN = 0.35;
const DEFAULT_DEPTH_BLOOM_RAY_ANGLE_GAIN = 0.25;
const DEFAULT_DEPTH_HALATION_RAY_ANGLE_GAIN = 0.18;
const DEFAULT_DEPTH_MIST_FIELD_PSF_GAIN = 1.0;
const DEFAULT_DEPTH_BLOOM_FIELD_PSF_GAIN = 1.0;
const DEFAULT_DEPTH_HALATION_FIELD_PSF_GAIN = 1.0;
const DEFAULT_DEPTH_MIST_FIELD_PSF_RADIUS_PX = 18.0;
const DEFAULT_DEPTH_BLOOM_FIELD_PSF_RADIUS_PX = 9.0;
const DEFAULT_DEPTH_HALATION_FIELD_PSF_RADIUS_PX = 12.0;
const DEFAULT_CROSS_FILTER_EDGE_STRENGTH_GAIN = 0.25;

export interface WebGPUBackendCreateOptions {
  validation?: boolean;
}

// Shared type declarations (ShaderModules, Pipelines, PrefilterGroupLayouts,
// PyramidResources, CrossFilterResources, LightShaftsResources,
// HaloPrismResources) live in `./passes/types` so per-effect pass modules
// under `./passes/` can import them without an import cycle back into this
// file (pure type relocation — see that file for the originals).

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
  private readonly detailSoftnessBuffer: GPUBuffer;
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
  private readonly haloPrism: HaloPrismResources;
  private readonly sampler: GPUSampler;
  private readonly grainSampler: GPUSampler;
  private readonly grainTexture: GPUTexture;
  /**
   * Shared depth texture for depth-aware Mist / Glow / Cross.
   * Runtime depth tracks and the internal `?depthProbe=1|2` debug fallback
   * both upload into this surface.
   */
  private readonly depthTexture: GPUTexture;
  private readonly gradeScratch = new Float32Array(GRADE_UNIFORM_FLOATS);
  private readonly compositeScratch = new Float32Array(COMPOSITE_UNIFORM_FLOATS);
  private readonly detailSoftnessScratch = new Float32Array(DETAIL_SOFTNESS_PARAMS_BYTES / 4);
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
  private cameraOptics: CameraOptics | null = null;
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
    detailSoftnessBuffer: GPUBuffer,
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
    haloPrism: HaloPrismResources,
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
    this.detailSoftnessBuffer = detailSoftnessBuffer;
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
    this.haloPrism = haloPrism;
    this.sampler = sampler;
    this.grainSampler = grainSampler;
    this.grainTexture = grainTexture;

    // Shared depth texture for depth-aware Mist / Glow / Cross. Keep it neutral 0.5
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

    // Diffusion depth prefilter params — 4 vec4 = 64 bytes.
    //   misc: (depthMistGain, fitMode, rayAngleGain, rayAngleGamma)
    //   size: (resolutionX, resolutionY, imageResX, imageResY)
    //   psf:  (fieldPsfGain, fieldPsfRadiusPx, _, _)
    //   optics: (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
    this.diffusionDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "diffusion-depth-prefilter.params",
      size: 64,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.diffusionDepthPrefilterScratch = new Float32Array(16);
    // Separate uniform buffers per pyramid: a single buffer shared across
    // all three pillars would silently overwrite in submit order (last
    // writeBuffer wins) — see feedback_webgpu_writebuffer_per_layer.md.
    this.bloomDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "bloom-depth-prefilter.params",
      size: 64,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.bloomDepthPrefilterScratch = new Float32Array(16);
    this.halationDepthPrefilterBuffer = ctx.device.createBuffer({
      label: "halation-depth-prefilter.params",
      size: 64,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    this.halationDepthPrefilterScratch = new Float32Array(16);
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
      detailSoftness: await make("detail-softness.frag", detailSoftnessFragmentWgsl),
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
      haloPrism: await make("halo-prism.frag", haloPrismFragmentWgsl),
      dust: await make("dust.frag", dustFragmentWgsl),
      motionblurFeedback: await make("motionblur-feedback.frag", motionblurFeedbackFragmentWgsl),
      motionblurBlend: await make("motionblur-blend.frag", motionblurBlendFragmentWgsl),
      // Cross-filter chain (Phase 3 T3-1). Compile-validated here so
      // GPU-side WGSL correctness is guaranteed at backend init; runtime
      // render integration lives in `renderCrossFilter` (no-op when
      // crossFilterStrength === 0 — all 8 v1.0 presets ship with 0).
      crossFilterSource: await make("cross-filter-source.frag", crossFilterSourceFragmentWgsl),
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

    const crossFilterStreakGroupLayout = device.createBindGroupLayout({
      label: "crossfilter.streak.group1",
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

    // Halo Prism: `(uniform, uScene, uCompactSource, uDepth, uSampler)`.
    const haloPrismGroupLayout = device.createBindGroupLayout({
      label: "halo-prism.group1",
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: "float" } },
        { binding: 4, visibility: GPUShaderStage.FRAGMENT, sampler: { type: "filtering" } },
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

    const detailSoftnessPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "detail-softness.fullres",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.detailSoftness,
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

    const crossFilterSourcePipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "crossfilter.source",
        layout: pyramidPipelineLayout,
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.crossFilterSource,
          entryPoint: "fs_main",
          targets: [{ format: "rgba16float" }],
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
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, crossFilterStreakGroupLayout],
        }),
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

    const haloPrismPipeline = await ctx.withValidationScope(() =>
      device.createRenderPipeline({
        label: "halo-prism.blend",
        layout: device.createPipelineLayout({
          bindGroupLayouts: [flagsLayout, haloPrismGroupLayout],
        }),
        vertex: { module: modules.vert, entryPoint: "vs_main" },
        fragment: {
          module: modules.haloPrism,
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
    const detailSoftnessBuffer = device.createBuffer({
      label: "detail-softness.uniforms",
      size: DETAIL_SOFTNESS_PARAMS_BYTES,
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

    const haloPrismSourceParamsBuffer = device.createBuffer({
      label: "halo-prism.source.params",
      size: CROSS_FILTER_PARAMS_BYTES,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });

    const haloPrismParamsBuffer = device.createBuffer({
      label: "halo-prism.params",
      size: HALO_PRISM_PARAMS_BYTES,
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
        detailSoftness: detailSoftnessPipeline,
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
        crossFilterSource: crossFilterSourcePipeline,
        crossFilterPeak: crossFilterPeakPipeline,
        crossFilterPeakSpacingMax: crossFilterPeakSpacingMaxPipeline,
        crossFilterPeakSpacing: crossFilterPeakSpacingPipeline,
        crossFilterStreak: crossFilterStreakPipeline,
        crossFilterTemporal: crossFilterTemporalPipeline,
        crossFilterBlend: crossFilterBlendPipeline,
        lightshafts: lightshaftsPipeline,
        lightshaftsBlend: lightshaftsBlendPipeline,
        haloPrism: haloPrismPipeline,
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
        crossFilterStreak: crossFilterStreakGroupLayout,
        crossFilterTemporal: crossFilterTemporalGroupLayout,
        crossFilterBlend: crossFilterBlendGroupLayout,
        lightshafts: lightshaftsGroupLayout,
        lightshaftsBlend: lightshaftsBlendGroupLayout,
        haloPrism: haloPrismGroupLayout,
      },
      displayFlagsBuffer,
      offscreenFlagsBuffer,
      crossFilterFlagsBuffer,
      displayFlagsBindGroup,
      offscreenFlagsBindGroup,
      crossFilterFlagsBindGroup,
      gradeBuffer,
      compositeBuffer,
      detailSoftnessBuffer,
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
      {
        sourceParamsBuffer: haloPrismSourceParamsBuffer,
        paramsBuffer: haloPrismParamsBuffer,
        sourceParamsScratch: new Float32Array(CROSS_FILTER_PARAMS_BYTES / 4),
        paramsScratch: new Float32Array(HALO_PRISM_PARAMS_FLOATS),
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

  setMediaFromExternalImageSource(
    source: ImageBitmapSource,
    width: number,
    height: number,
  ): void {
    this.liveVideoElement = null;
    this.mediaTexture = MediaTexture.fromExternalImageSource(
      this.ctx.device,
      source,
      width,
      height,
      this.mediaTexture,
    );
    this.setImageResolution(width, height);
  }

  setVideoElement(video: HTMLVideoElement): void {
    this.setMediaFromVideoElement(video);
  }

  setImageResolution(width: number, height: number): void {
    this.frameState.imgResX = Math.max(1, width);
    this.frameState.imgResY = Math.max(1, height);
    this.gradeDirty = true;
  }

  setCameraOptics(optics: CameraOptics | null): void {
    this.cameraOptics = optics;
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
    const prevShutterAngle = this.paramNumber("shutterAngle", 0);
    const hasShutterAngle = Object.prototype.hasOwnProperty.call(
      params,
      "shutterAngle",
    );
    this.frameState.params = { ...this.frameState.params, ...params };
    this.gradeDirty = true;
    if (hasShutterAngle) {
      const nextShutterAngle = this.paramNumber("shutterAngle", 0);
      const wasActive = isShutterMotionActive(prevShutterAngle);
      const isActive = isShutterMotionActive(nextShutterAngle);
      if (wasActive !== isActive || !isActive) this.resetMotionBlurHistory();
    }
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

  private resolveCurrentRayAngleOptics(): ResolvedRayAngleOptics {
    return resolveRayAngleOptics(
      this.cameraOptics,
      this.frameState.imgResX,
      this.frameState.imgResY,
    );
  }

  private packRayAngleOptics(
    target: Float32Array,
    offset: number,
    optics: ResolvedRayAngleOptics,
    innerThreshold: number,
  ): void {
    target[offset] = optics.tanHalfFovX;
    target[offset + 1] = optics.tanHalfFovY;
    target[offset + 2] = Math.min(0.8, Math.max(0, innerThreshold));
    target[offset + 3] = optics.source === "fallback65" ? 1 : 0;
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
    this.packRayAngleOptics(
      this.compositeScratch,
      16,
      this.resolveCurrentRayAngleOptics(),
      this.paramNumber(
        "depthRayAngleInnerThreshold",
        DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
      ),
    );
    this.compositeScratch[20] = this.paramNumber("rayAngleProbe", 0);
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
    return computeMipWeightsPass(radius, levels);
  }

  private ensurePyramidLevels(labelPrefix: string, levels: number): GPUTexture[] {
    return ensurePyramidLevelsPass(
      this.pool,
      labelPrefix,
      levels,
      this._width,
      this._height,
    );
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
    return renderPyramidChainPass(
      encoder,
      label,
      prefilterPipeline,
      prefilterParamsBuffer,
      sourceView,
      levels,
      pyramid,
      radius,
      {
        device: this.ctx.device,
        layout: this.layouts.pyramid,
        sampler: this.sampler,
        offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
        downsamplePipeline: this.pipelines.downsample,
        upsampleAddPipeline: this.pipelines.upsampleAdd,
      },
    );
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
    rayAngleGain: number,
    rayAngleGamma: number,
    rayAngleInnerThreshold: number,
    fieldPsfGain: number,
    fieldPsfRadiusPx: number,
    optics: ResolvedRayAngleOptics,
  ): GPUTextureView {
    return renderDiffusionDepthPrefilterPass(
      encoder,
      sourceView,
      depthMistGain,
      rayAngleGain,
      rayAngleGamma,
      rayAngleInnerThreshold,
      fieldPsfGain,
      fieldPsfRadiusPx,
      optics,
      {
        device: this.ctx.device,
        pool: this.pool,
        width: this._width,
        height: this._height,
        fitMode: this.frameState.fitMode,
        imgResX: this.frameState.imgResX,
        imgResY: this.frameState.imgResY,
        scratch: this.diffusionDepthPrefilterScratch,
        buffer: this.diffusionDepthPrefilterBuffer,
        layout: this.layouts.diffusionDepthPrefilter,
        pipeline: this.pipelines.diffusionDepthPrefilter,
        depthTexture: this.depthTexture,
        sampler: this.sampler,
        offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
        packRayAngleOptics: (target, offset, o, innerThreshold) =>
          this.packRayAngleOptics(target, offset, o, innerThreshold),
      },
    );
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
    rayAngleGain: number,
    rayAngleGamma: number,
    rayAngleInnerThreshold: number,
    fieldPsfGain: number,
    fieldPsfRadiusPx: number,
    optics: ResolvedRayAngleOptics,
  ): GPUTextureView {
    return renderBloomDepthPrefilterPass(
      encoder,
      sourceView,
      gain,
      rayAngleGain,
      rayAngleGamma,
      rayAngleInnerThreshold,
      fieldPsfGain,
      fieldPsfRadiusPx,
      optics,
      {
        device: this.ctx.device,
        pool: this.pool,
        width: this._width,
        height: this._height,
        fitMode: this.frameState.fitMode,
        imgResX: this.frameState.imgResX,
        imgResY: this.frameState.imgResY,
        scratch: this.bloomDepthPrefilterScratch,
        buffer: this.bloomDepthPrefilterBuffer,
        layout: this.layouts.diffusionDepthPrefilter,
        pipeline: this.pipelines.bloomDepthPrefilter,
        depthTexture: this.depthTexture,
        sampler: this.sampler,
        offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
        packRayAngleOptics: (target, offset, o, innerThreshold) =>
          this.packRayAngleOptics(target, offset, o, innerThreshold),
      },
    );
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
    rayAngleGain: number,
    rayAngleGamma: number,
    rayAngleInnerThreshold: number,
    fieldPsfGain: number,
    fieldPsfRadiusPx: number,
    optics: ResolvedRayAngleOptics,
  ): GPUTextureView {
    return renderHalationDepthPrefilterPass(
      encoder,
      sourceView,
      gain,
      rayAngleGain,
      rayAngleGamma,
      rayAngleInnerThreshold,
      fieldPsfGain,
      fieldPsfRadiusPx,
      optics,
      {
        device: this.ctx.device,
        pool: this.pool,
        width: this._width,
        height: this._height,
        fitMode: this.frameState.fitMode,
        imgResX: this.frameState.imgResX,
        imgResY: this.frameState.imgResY,
        scratch: this.halationDepthPrefilterScratch,
        buffer: this.halationDepthPrefilterBuffer,
        layout: this.layouts.diffusionDepthPrefilter,
        pipeline: this.pipelines.halationDepthPrefilter,
        depthTexture: this.depthTexture,
        sampler: this.sampler,
        offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
        packRayAngleOptics: (target, offset, o, innerThreshold) =>
          this.packRayAngleOptics(target, offset, o, innerThreshold),
      },
    );
  }

  private renderDiffusionPyramid(
    encoder: GPUCommandEncoder,
    sourceView: GPUTextureView,
    levels: GPUTexture[],
  ): GPUTexture {
    return renderDiffusionPyramidPass(encoder, sourceView, levels, this.diffusionPyramid, {
      device: this.ctx.device,
      layout: this.layouts.pyramid,
      sampler: this.sampler,
      offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
      downsamplePipeline: this.pipelines.downsample,
      upsampleAddPipeline: this.pipelines.upsampleAdd,
      width: this._width,
      height: this._height,
    });
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

  // `renderCentralBloom` moved to `./passes/crossFilter` (module-private
  // there too — its sole caller, `renderCrossFilter`, moved alongside it).

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
    return renderLightShaftsPass(encoder, sourceTexture, {
      device: this.ctx.device,
      pool: this.pool,
      width: this._width,
      height: this._height,
      lightShafts: this.lightShafts,
      lightshaftsLayout: this.layouts.lightshafts,
      lightshaftsBlendLayout: this.layouts.lightshaftsBlend,
      lightshaftsPipeline: this.pipelines.lightshafts,
      lightshaftsBlendPipeline: this.pipelines.lightshaftsBlend,
      sampler: this.sampler,
      crossFilterFlagsBindGroup: this.crossFilterFlagsBindGroup,
      paramNumber: (key, fallback) => this.paramNumber(key, fallback),
    });
  }

  private renderHaloPrism(
    encoder: GPUCommandEncoder,
    sceneTexture: GPUTexture,
    sourceSeedTexture: GPUTexture,
  ): GPUTexture {
    return renderHaloPrismPass(encoder, sceneTexture, sourceSeedTexture, {
      device: this.ctx.device,
      pool: this.pool,
      width: this._width,
      height: this._height,
      imgResX: this.frameState.imgResX,
      imgResY: this.frameState.imgResY,
      fitMode: this.frameState.fitMode,
      haloPrism: this.haloPrism,
      pyramidLayout: this.layouts.pyramid,
      haloPrismLayout: this.layouts.haloPrism,
      crossFilterSourcePipeline: this.pipelines.crossFilterSource,
      haloPrismPipeline: this.pipelines.haloPrism,
      depthTexture: this.depthTexture,
      sampler: this.sampler,
      offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
      crossFilterFlagsBindGroup: this.crossFilterFlagsBindGroup,
      paramNumber: (key, fallback) => this.paramNumber(key, fallback),
      resolveCurrentRayAngleOptics: () => this.resolveCurrentRayAngleOptics(),
      packRayAngleOptics: (target, offset, optics, innerThreshold) =>
        this.packRayAngleOptics(target, offset, optics, innerThreshold),
    });
  }

  private renderCrossFilter(
    encoder: GPUCommandEncoder,
    sourceTexture: GPUTexture,
  ): GPUTexture {
    const result = renderCrossFilterPass(encoder, sourceTexture, {
      device: this.ctx.device,
      pool: this.pool,
      width: this._width,
      height: this._height,
      fitMode: this.frameState.fitMode,
      imgResX: this.frameState.imgResX,
      imgResY: this.frameState.imgResY,
      time: this.frameState.time,
      maxStreaks: CROSS_FILTER_MAX_STREAKS,
      minSpacingMin: CROSS_FILTER_MIN_SPACING_MIN,
      minSpacingMax: CROSS_FILTER_MIN_SPACING_MAX,
      defaultDepthRayAngleGamma: DEFAULT_DEPTH_RAY_ANGLE_GAMMA,
      crossFilter: this.crossFilter,
      layouts: this.layouts,
      pipelines: this.pipelines,
      depthTexture: this.depthTexture,
      sampler: this.sampler,
      offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
      crossFilterFlagsBindGroup: this.crossFilterFlagsBindGroup,
      centralBloomPyramid: this.centralBloomPyramid,
      centralBloomLevels: CENTRAL_BLOOM_LEVELS,
      paramNumber: (key, fallback) => this.paramNumber(key, fallback),
      resolveCurrentRayAngleOptics: () => this.resolveCurrentRayAngleOptics(),
      packRayAngleOptics: (target, offset, optics, innerThreshold) =>
        this.packRayAngleOptics(target, offset, optics, innerThreshold),
      history: {
        peakHistoryWriteIndex: this.crossFilterPeakHistoryWriteIndex,
        peakHistoryFilledFrames: this.crossFilterPeakHistoryFilledFrames,
        lastHistoryTime: this.lastCrossFilterHistoryTime,
      },
    });
    this.crossFilterPeakHistoryWriteIndex = result.history.peakHistoryWriteIndex;
    this.crossFilterPeakHistoryFilledFrames = result.history.peakHistoryFilledFrames;
    this.lastCrossFilterHistoryTime = result.history.lastHistoryTime;
    return result.texture;
  }

  // `activeMotionBlurFrames` / `computeMotionBlurWeights` moved to
  // `./passes/motionBlur` (sole caller was the motion-blur-ON branch in
  // `renderFrame`, which moved alongside them).

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
    const detailSoftnessUniforms = deriveDetailSoftnessUniforms(
      this.paramNumber("detailSoftness", 0),
    );
    let opticalSourceView = colorGradedView;
    if (detailSoftnessUniforms.effectiveDetailSoftness > 0.0001) {
      const rtDetailSoftened = this.pool.get("rt.detailSoftened", {
        width: this._width,
        height: this._height,
        format: "rgba16float",
      });
      // Layout: 3 vec4f (see detail-softness.frag.wgsl.ts).
      // p0: effective, radius, chromaAttenScale, highlightBias
      // p1: rangeSigma, detailAmplitudeLo, detailAmplitudeHi, _pad
      // p2: invWidth, invHeight, _pad, _pad
      this.detailSoftnessScratch[0] = detailSoftnessUniforms.effectiveDetailSoftness;
      this.detailSoftnessScratch[1] = detailSoftnessUniforms.kernelRadiusPx;
      this.detailSoftnessScratch[2] = detailSoftnessUniforms.chromaAttenScale;
      this.detailSoftnessScratch[3] = detailSoftnessUniforms.highlightBias;
      this.detailSoftnessScratch[4] = detailSoftnessUniforms.rangeSigma;
      this.detailSoftnessScratch[5] = detailSoftnessUniforms.detailAmplitudeLo;
      this.detailSoftnessScratch[6] = detailSoftnessUniforms.detailAmplitudeHi;
      this.detailSoftnessScratch[7] = 0;
      this.detailSoftnessScratch[8] = 1 / Math.max(1, this._width);
      this.detailSoftnessScratch[9] = 1 / Math.max(1, this._height);
      this.detailSoftnessScratch[10] = 0;
      this.detailSoftnessScratch[11] = 0;
      device.queue.writeBuffer(
        this.detailSoftnessBuffer,
        0,
        this.detailSoftnessScratch.buffer,
        this.detailSoftnessScratch.byteOffset,
        this.detailSoftnessScratch.byteLength,
      );
      const detailSoftnessBg = device.createBindGroup({
        label: "detail-softness.bg",
        layout: this.layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: this.detailSoftnessBuffer } },
          { binding: 1, resource: colorGradedView },
          { binding: 2, resource: this.sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "detail-softness.pass",
        colorAttachments: [
          {
            view: rtDetailSoftened.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(this.pipelines.detailSoftness);
      pass.setBindGroup(0, this.offscreenFlagsBindGroup);
      pass.setBindGroup(1, detailSoftnessBg);
      pass.draw(3, 1, 0, 0);
      pass.end();
      opticalSourceView = rtDetailSoftened.createView();
    }

    // Shared depth-aware Mist / Glow controls.
    //   - `depthMistGain` drives the diffusion (Mist) pyramid prefilter and
    //     the composite `>= 1.5` debug view.
    //   - `depthGlowGain` drives the bloom + halation pyramid prefilters.
    // Both live in `(0, 1.5)` when active; values >= 1.5 on `depthMistGain`
    // switch composite into the raw-depth debug view and skip prefiltering.
    // Splitting the two gains lets the shared contract modulate Mist and
    // Glow independently. Cross uses its own compact-source depth/ray-angle
    // shaping inside `renderCrossFilter`; Lens remains out of scope here.
    const depthMistGain = this.paramNumber("depthMistGain", 0);
    const depthGlowGain = this.paramNumber("depthGlowGain", 0);
    const depthMistActive = depthMistGain > 0 && depthMistGain < 1.5;
    const depthGlowActive = depthGlowGain > 0 && depthGlowGain < 1.5;
    const depthRayAngleGamma = Math.max(
      0.001,
      this.paramNumber("depthRayAngleGamma", DEFAULT_DEPTH_RAY_ANGLE_GAMMA),
    );
    const depthRayAngleInnerThreshold = Math.min(
      0.8,
      Math.max(
        0,
        this.paramNumber(
          "depthRayAngleInnerThreshold",
          DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
        ),
      ),
    );
    const rayAngleOptics = this.resolveCurrentRayAngleOptics();
    const depthMistRayAngleGain = Math.max(
      0,
      this.paramNumber("depthMistRayAngleGain", DEFAULT_DEPTH_MIST_RAY_ANGLE_GAIN),
    );
    const depthBloomRayAngleGain = Math.max(
      0,
      this.paramNumber("depthBloomRayAngleGain", DEFAULT_DEPTH_BLOOM_RAY_ANGLE_GAIN),
    );
    const depthHalationRayAngleGain = Math.max(
      0,
      this.paramNumber("depthHalationRayAngleGain", DEFAULT_DEPTH_HALATION_RAY_ANGLE_GAIN),
    );
    const depthMistFieldPsfGain = Math.max(
      0,
      this.paramNumber("depthMistFieldPsfGain", DEFAULT_DEPTH_MIST_FIELD_PSF_GAIN),
    );
    const depthBloomFieldPsfGain = Math.max(
      0,
      this.paramNumber("depthBloomFieldPsfGain", DEFAULT_DEPTH_BLOOM_FIELD_PSF_GAIN),
    );
    const depthHalationFieldPsfGain = Math.max(
      0,
      this.paramNumber("depthHalationFieldPsfGain", DEFAULT_DEPTH_HALATION_FIELD_PSF_GAIN),
    );
    const depthMistFieldPsfRadiusPx = Math.max(
      0,
      this.paramNumber(
        "depthMistFieldPsfRadiusPx",
        DEFAULT_DEPTH_MIST_FIELD_PSF_RADIUS_PX,
      ),
    );
    const depthBloomFieldPsfRadiusPx = Math.max(
      0,
      this.paramNumber(
        "depthBloomFieldPsfRadiusPx",
        DEFAULT_DEPTH_BLOOM_FIELD_PSF_RADIUS_PX,
      ),
    );
    const depthHalationFieldPsfRadiusPx = Math.max(
      0,
      this.paramNumber(
        "depthHalationFieldPsfRadiusPx",
        DEFAULT_DEPTH_HALATION_FIELD_PSF_RADIUS_PX,
      ),
    );

    // Pass 2 — bloom pyramid (prefilter → downsample → additive upsample).
    const bloomRadius = this.paramNumber("bloomRadius", DEFAULT_BLOOM_RADIUS);
    const bloomSourceView = depthGlowActive
      ? this.renderBloomDepthPrefilter(
          encoder,
          opticalSourceView,
          depthGlowGain,
          depthBloomRayAngleGain,
          depthRayAngleGamma,
          depthRayAngleInnerThreshold,
          depthBloomFieldPsfGain,
          depthBloomFieldPsfRadiusPx,
          rayAngleOptics,
        )
      : opticalSourceView;
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
      ? this.renderHalationDepthPrefilter(
          encoder,
          opticalSourceView,
          depthGlowGain,
          depthHalationRayAngleGain,
          depthRayAngleGamma,
          depthRayAngleInnerThreshold,
          depthHalationFieldPsfGain,
          depthHalationFieldPsfRadiusPx,
          rayAngleOptics,
        )
      : opticalSourceView;
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
        ? this.renderDiffusionDepthPrefilter(
            encoder,
            opticalSourceView,
            depthMistGain,
            depthMistRayAngleGain,
            depthRayAngleGamma,
            depthRayAngleInnerThreshold,
            depthMistFieldPsfGain,
            depthMistFieldPsfRadiusPx,
            rayAngleOptics,
          )
        : opticalSourceView;
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
        { binding: 1, resource: opticalSourceView },
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
    postCompositeTexture = this.renderHaloPrism(encoder, postCompositeTexture, rtComposited);

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
    const motionBlurOn = isShutterMotionActive(shutterAngle);
    const haloPrismStrength = Math.min(
      1,
      Math.max(0, this.paramNumber("haloPrismStrength", 0)),
    );

    // Light shafts (WebGL parity): run after cross-filter, before motion
    // blur. Activation matches WebGL: the post chain must be active via
    // cross-filter or motion blur, and `shaftIntensity > 0`. Dust /
    // Scratches stays deferred on WebGPU in v1.
    const shaftIntensity = Math.min(
      1,
      Math.max(0, this.paramNumber("shaftIntensity", 0)),
    );
    const postChainActive = crossFilterStrength > 0 || haloPrismStrength > 0 || motionBlurOn;
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
      this.resetMotionBlurHistory();
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
      renderMotionBlurChainPass(
        encoder,
        postCompositeView,
        swapView,
        readbackView,
        shutterAngle,
        {
          device: this.ctx.device,
          ringBuffer: this.ringBuffer,
          motionblurFeedbackBuffer: this.motionblurFeedbackBuffer,
          motionblurFeedbackScratch: this.motionblurFeedbackScratch,
          motionblurBlendBuffer: this.motionblurBlendBuffer,
          motionblurBlendScratch: this.motionblurBlendScratch,
          motionblurFeedbackLayout: this.layouts.motionblurFeedback,
          motionblurBlendLayout: this.layouts.motionblurBlend,
          motionblurFeedbackPipeline: this.pipelines.motionblurFeedback,
          motionblurBlendPipeline: this.pipelines.motionblurBlend,
          sampler: this.sampler,
          offscreenFlagsBindGroup: this.offscreenFlagsBindGroup,
          displayFlagsBindGroup: this.displayFlagsBindGroup,
          paramNumber: (key, fallback) => this.paramNumber(key, fallback),
        },
      );
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

  resetMotionBlurHistory(): void {
    this.ringBuffer.reset();
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
    this.detailSoftnessBuffer.destroy();
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
    this.haloPrism.sourceParamsBuffer.destroy();
    this.haloPrism.paramsBuffer.destroy();
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
