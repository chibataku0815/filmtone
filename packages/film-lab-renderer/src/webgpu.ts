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

export { GpuContext, GpuContextCreationError } from "./webgpu/GpuContext";
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
  bloomPrefilterFragmentWgsl,
  halationPrefilterFragmentWgsl,
  downsampleFragmentWgsl,
  upsampleFragmentWgsl,
  lightshaftsFragmentWgsl,
  lightshaftsBlendFragmentWgsl,
  dustFragmentWgsl,
} from "./webgpu/shaders";
