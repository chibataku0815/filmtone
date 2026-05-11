/**
 * WebGPU sub-entry — `film-lab-renderer/webgpu`.
 *
 * Desktop (`FILMTONE_BACKEND === "webgpu"`) imports WebGPU primitives and
 * the `WebGPUBackend` class from this module. The default
 * `film-lab-renderer` entry deliberately does NOT re-export these so that
 * `apps/web` (WebGL-only) builds tree-shake the WebGPU surface out.
 *
 * Verification target: `rg -l "WebGPUBackend|GpuContext" apps/web/.next` = 0.
 */

export {
  GpuContext,
  GpuContextCreationError,
  type GpuContextLossInfo,
  type GpuContextLossReason,
} from "./webgpu/GpuContext";
export type {
  ViewportCapabilities,
  ViewportContextLossInfo,
  ViewportContextLossReason,
} from "./RendererRuntime";
export { OffscreenTargetPool } from "./webgpu/OffscreenTargetPool";
export { Lut3DTexture } from "./webgpu/Lut3DTexture";
export { MediaTexture } from "./webgpu/MediaTexture";
export { RingBuffer, MOTION_BLUR_RING_SLOTS } from "./webgpu/RingBuffer";
export { BlueNoiseTile } from "./webgpu/BlueNoiseTile";
export {
  WebGPUBackend,
  type WebGPUBackendCreateOptions,
} from "./webgpu/WebGPUBackend";
export type {
  RenderBackend,
  RenderBackendParams,
  RenderBackendParamValue,
} from "./webgpu/Backend";
export {
  fullscreenVertexWgsl,
  filmlabFragmentWgsl,
  blitFragmentWgsl,
  compositeFragmentWgsl,
  detailSoftnessFragmentWgsl,
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  dustFragmentWgsl,
  motionblurFeedbackFragmentWgsl,
  motionblurBlendFragmentWgsl,
} from "./webgpu/shaders";
export {
  packGradeUniforms,
  GRADE_UNIFORM_BYTES,
  GRADE_UNIFORM_FLOATS,
  type GradeFrameState,
} from "./webgpu/gradeUniforms";
export {
  packCompositeUniforms,
  COMPOSITE_UNIFORM_BYTES,
  COMPOSITE_UNIFORM_FLOATS,
  hexToRgbTriple,
  type CompositeFrameState,
} from "./webgpu/compositeUniforms";
export {
  CROSS_FILTER_MIN_SPACING_EPSILON,
  CROSS_FILTER_TEMPORAL_REFERENCE_DECAY,
  CROSS_FILTER_TEMPORAL_REFERENCE_FPS,
  computeCrossFilterTemporalDecay,
  effectiveDiffusionAmount,
  isCrossFilterHardModeActive,
  shouldResetCrossFilterHistory,
  type CrossFilterHistorySnapshot,
} from "./webgpu/crossFilterState";
export {
  DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
  RAY_ANGLE_FALLBACK_HFOV_DEG,
  RAY_ANGLE_FOV_MAX_DEG,
  RAY_ANGLE_FOV_MIN_DEG,
  RAY_ANGLE_REFERENCE_TAN_HALF_HFOV,
  rayAngleMaskValue,
  resolveRayAngleOptics,
  type RayAngleOpticsSource,
  type ResolvedRayAngleOptics,
} from "./webgpu/rayAngleOptics";
