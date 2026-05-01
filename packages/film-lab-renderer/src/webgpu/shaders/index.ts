/**
 * WebGPU shader module re-exports.
 *
 * Phase 1 T1-3. All WGSL sources exposed here so `WebGPUBackend` can build
 * `GPUShaderModule` instances and downstream apps can reuse them in
 * export / preview pipelines.
 */

export { fullscreenVertexWgsl } from "./fullscreen.vert.wgsl";
export { bloomPrefilterFragmentWgsl } from "./bloom-prefilter.frag.wgsl";
export { halationPrefilterFragmentWgsl } from "./halation-prefilter.frag.wgsl";
export { diffusionDepthPrefilterFragmentWgsl } from "./diffusion-depth-prefilter.frag.wgsl";
export { bloomDepthPrefilterFragmentWgsl } from "./bloom-depth-prefilter.frag.wgsl";
export { halationDepthPrefilterFragmentWgsl } from "./halation-depth-prefilter.frag.wgsl";
export { downsampleFragmentWgsl } from "./downsample.frag.wgsl";
export { upsampleFragmentWgsl } from "./upsample.frag.wgsl";
export { lightshaftsFragmentWgsl } from "./lightshafts.frag.wgsl";
export { lightshaftsBlendFragmentWgsl } from "./lightshafts-blend.frag.wgsl";
export { haloPrismFragmentWgsl } from "./halo-prism.frag.wgsl";
export { dustFragmentWgsl } from "./dust.frag.wgsl";
export { filmlabFragmentWgsl } from "./filmlab.frag.wgsl";
export { blitFragmentWgsl } from "./blit.frag.wgsl";
export { compareSourceFragmentWgsl } from "./compare-source.frag.wgsl";
export { compositeFragmentWgsl } from "./composite.frag.wgsl";
export { motionblurFeedbackFragmentWgsl } from "./motionblur-feedback.frag.wgsl";
export { motionblurBlendFragmentWgsl } from "./motionblur-blend.frag.wgsl";
export { crossFilterSourceFragmentWgsl } from "./cross-filter-source.frag.wgsl";
export { crossFilterPeakFragmentWgsl } from "./cross-filter-peak.frag.wgsl";
export { crossFilterPeakSpacingMaxFragmentWgsl } from "./cross-filter-peak-spacing-max.frag.wgsl";
export { crossFilterPeakSpacingFragmentWgsl } from "./cross-filter-peak-spacing.frag.wgsl";
export { crossFilterStreakFragmentWgsl } from "./cross-filter-streak.frag.wgsl";
export { crossFilterTemporalFragmentWgsl } from "./cross-filter-temporal.frag.wgsl";
export { crossFilterBlendFragmentWgsl } from "./cross-filter-blend.frag.wgsl";
