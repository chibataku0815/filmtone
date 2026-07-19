/**
 * Shared type declarations for `WebGPUBackend` and its extracted per-effect
 * pass modules under `src/webgpu/passes/`.
 *
 * Relocated verbatim from `WebGPUBackend.ts` (pure type declarations only —
 * zero runtime behavior). Living here (rather than in `WebGPUBackend.ts`)
 * lets pass modules import these types without an import cycle back into
 * the backend file.
 */

export interface ShaderModules {
  vert: GPUShaderModule;
  filmlab: GPUShaderModule;
  blit: GPUShaderModule;
  compareSource: GPUShaderModule;
  composite: GPUShaderModule;
  detailSoftness: GPUShaderModule;
  bloomPrefilter: GPUShaderModule;
  halationPrefilter: GPUShaderModule;
  diffusionDepthPrefilter: GPUShaderModule;
  bloomDepthPrefilter: GPUShaderModule;
  halationDepthPrefilter: GPUShaderModule;
  downsample: GPUShaderModule;
  upsample: GPUShaderModule;
  lightshafts: GPUShaderModule;
  lightshaftsBlend: GPUShaderModule;
  haloPrism: GPUShaderModule;
  dust: GPUShaderModule;
  motionblurFeedback: GPUShaderModule;
  motionblurBlend: GPUShaderModule;
  crossFilterSource: GPUShaderModule;
  crossFilterPeak: GPUShaderModule;
  crossFilterPeakSpacingMax: GPUShaderModule;
  crossFilterPeakSpacing: GPUShaderModule;
  crossFilterStreak: GPUShaderModule;
  crossFilterTemporal: GPUShaderModule;
  crossFilterBlend: GPUShaderModule;
}

export interface Pipelines {
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
  detailSoftness: GPURenderPipeline;
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
  crossFilterSource: GPURenderPipeline;
  crossFilterPeak: GPURenderPipeline;
  crossFilterPeakSpacingMax: GPURenderPipeline;
  crossFilterPeakSpacing: GPURenderPipeline;
  crossFilterStreak: GPURenderPipeline;
  crossFilterTemporal: GPURenderPipeline;
  crossFilterBlend: GPURenderPipeline;
  /** Hard-mode central bloom reuses the generic `downsample` / `upsampleAdd` pipelines. */
  lightshafts: GPURenderPipeline;
  lightshaftsBlend: GPURenderPipeline;
  haloPrism: GPURenderPipeline;
}

export interface PrefilterGroupLayouts {
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
  crossFilterStreak: GPUBindGroupLayout;
  crossFilterTemporal: GPUBindGroupLayout;
  crossFilterBlend: GPUBindGroupLayout;
  lightshafts: GPUBindGroupLayout;
  lightshaftsBlend: GPUBindGroupLayout;
  haloPrism: GPUBindGroupLayout;
}

/**
 * Pre-allocated pyramid resources. Uniform buffers are sized up-front so a
 * single submit() never collides multiple `writeBuffer` calls on the same
 * buffer. Textures live in `OffscreenTargetPool` and are keyed by label so
 * resize swaps transparently.
 */
export interface PyramidResources {
  readonly downsample: GPUBuffer[]; // length = levels
  readonly upsample: GPUBuffer[]; // length = levels - 1
  readonly downsampleScratch: Float32Array[];
  readonly upsampleScratch: Float32Array[];
}

export interface CrossFilterResources {
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

export interface LightShaftsResources {
  readonly paramsBuffer: GPUBuffer;
  readonly blendParamsBuffer: GPUBuffer;
  readonly paramsScratch: Float32Array;
  readonly blendParamsScratch: Float32Array;
}

export interface HaloPrismResources {
  readonly sourceParamsBuffer: GPUBuffer;
  readonly paramsBuffer: GPUBuffer;
  readonly sourceParamsScratch: Float32Array;
  readonly paramsScratch: Float32Array;
}
