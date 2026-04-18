export { Viewport, type ViewportOptions } from "./webgl/WebGLBackend";
export {
  MediaLoader,
  MediaLoadError,
  isLikelyHeicFile,
  isFilmLabMediaDebugEnabled,
  LIKELY_VIDEO_EXTENSION,
  type LoadResult,
  type LoadFileOptions,
} from "./MediaLoader";
export {
  isWebGL2Supported,
  isWebGPUSupported,
  getOptimalPixelRatio,
} from "./support";
export type { RenderBackend } from "./webgpu/Backend";

// Shaders
export { filmlabVertexShader } from "./webgl/shaders/filmlab.vert";
export { filmlabFragmentShader } from "./webgl/shaders/filmlab.frag";
export { bloomPrefilterFragmentShader } from "./webgl/shaders/bloom-prefilter.frag";
export { halationPrefilterFragmentShader } from "./webgl/shaders/halation-prefilter.frag";
export { downsampleFragmentShader } from "./webgl/shaders/downsample.frag";
export { upsampleFragmentShader } from "./webgl/shaders/upsample.frag";
export { compositeFragmentShader } from "./webgl/shaders/composite.frag";
export { motionblurFragmentShader } from "./webgl/shaders/motionblur.frag";
export { dustFragmentShader } from "./webgl/shaders/dust.frag";
export { lightshaftsFragmentShader } from "./webgl/shaders/lightshafts.frag";
export { lightshaftsBlendFragmentShader } from "./webgl/shaders/lightshafts-blend.frag";
export { crossFilterStreakFragmentShader } from "./webgl/shaders/cross-filter-streak.frag";
export { crossFilterStreakDensityFragmentShader } from "./webgl/shaders/cross-filter-streak-density.frag";
export { crossFilterBlendFragmentShader } from "./webgl/shaders/cross-filter-blend.frag";
export { crossFilterPeakFragmentShader } from "./webgl/shaders/cross-filter-peak.frag";
