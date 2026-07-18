/**
 * Bloom pass — extracted verbatim from `WebGPUBackend.renderBloomDepthPrefilter`.
 *
 * The bloom prefilter → downsample → additive-upsample chain itself lives in
 * the shared `./pyramid.ts` (`renderPyramidChain`, called directly by
 * `WebGPUBackend.renderFrame` with the bloom prefilter pipeline/params
 * buffer). Only the dev-only depth-weighted source prefilter is
 * bloom-specific and lives here.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original method.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import type { ResolvedRayAngleOptics } from "../rayAngleOptics";

export interface BloomDepthPrefilterDeps {
  device: GPUDevice;
  pool: OffscreenTargetPool;
  width: number;
  height: number;
  fitMode: number;
  imgResX: number;
  imgResY: number;
  scratch: Float32Array;
  buffer: GPUBuffer;
  /** `layouts.diffusionDepthPrefilter` — shared bind group layout across all three depth prefilters. */
  layout: GPUBindGroupLayout;
  pipeline: GPURenderPipeline;
  depthTexture: GPUTexture;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  packRayAngleOptics: (
    target: Float32Array,
    offset: number,
    optics: ResolvedRayAngleOptics,
    innerThreshold: number,
  ) => void;
}

/**
 * Shared depth-aware Glow path — depth-weighted source mask feeding the
 * bloom pyramid. Output goes to `rt.bloom.depth-prefiltered` (full-res
 * rgba16float), which the caller passes to `renderPyramidChain` as the
 * `sourceView`; the existing bloom luma-gate prefilter then reads from
 * this intermediate. Near/far coefficients live in the WGSL constant
 * (`bloom-depth-prefilter.frag.wgsl.ts`).
 */
export function renderBloomDepthPrefilter(
  encoder: GPUCommandEncoder,
  sourceView: GPUTextureView,
  gain: number,
  rayAngleGain: number,
  rayAngleGamma: number,
  rayAngleInnerThreshold: number,
  fieldPsfGain: number,
  fieldPsfRadiusPx: number,
  optics: ResolvedRayAngleOptics,
  deps: BloomDepthPrefilterDeps,
): GPUTextureView {
  const {
    device,
    pool,
    width,
    height,
    fitMode,
    imgResX,
    imgResY,
    scratch,
    buffer,
    layout,
    pipeline,
    depthTexture,
    sampler,
    offscreenFlagsBindGroup,
    packRayAngleOptics,
  } = deps;
  const scratchRT = pool.get("rt.bloom.depth-prefiltered", {
    width: width,
    height: height,
    format: "rgba16float",
  });
  const scratchView = scratchRT.createView();

  const s = scratch;
  s[0] = gain;
  s[1] = fitMode;
  s[2] = rayAngleGain;
  s[3] = rayAngleGamma;
  s[4] = width;
  s[5] = height;
  s[6] = imgResX;
  s[7] = imgResY;
  s[8] = fieldPsfGain;
  s[9] = fieldPsfRadiusPx;
  s[10] = 0;
  s[11] = 0;
  packRayAngleOptics(s, 12, optics, rayAngleInnerThreshold);
  device.queue.writeBuffer(
    buffer,
    0,
    s.buffer,
    s.byteOffset,
    s.byteLength,
  );

  const bg = device.createBindGroup({
    label: "bloom-depth-prefilter.bg",
    layout: layout,
    entries: [
      { binding: 0, resource: { buffer: buffer } },
      { binding: 1, resource: sourceView },
      { binding: 2, resource: depthTexture.createView() },
      { binding: 3, resource: sampler },
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
  pass.setPipeline(pipeline);
  pass.setBindGroup(0, offscreenFlagsBindGroup);
  pass.setBindGroup(1, bg);
  pass.draw(3, 1, 0, 0);
  pass.end();

  return scratchView;
}
