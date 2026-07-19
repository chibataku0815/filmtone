/**
 * Diffusion (Pro-Mist) pass — extracted verbatim from
 * `WebGPUBackend.renderDiffusionDepthPrefilter` and
 * `WebGPUBackend.renderDiffusionPyramid`.
 *
 * Unlike bloom/halation, diffusion doesn't share the generic
 * `renderPyramidChain` (no luma-gate prefilter step — it's a full-image
 * blur with a fixed wide radius), so its own downsample/upsample chain is
 * self-contained here. It reuses `computeMipWeights` from `./pyramid`.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original methods.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import type { ResolvedRayAngleOptics } from "../rayAngleOptics";
import type { PyramidResources } from "./types";
import { computeMipWeights } from "./pyramid";

export interface DiffusionDepthPrefilterDeps {
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
export function renderDiffusionDepthPrefilter(
  encoder: GPUCommandEncoder,
  sourceView: GPUTextureView,
  depthMistGain: number,
  rayAngleGain: number,
  rayAngleGamma: number,
  rayAngleInnerThreshold: number,
  fieldPsfGain: number,
  fieldPsfRadiusPx: number,
  optics: ResolvedRayAngleOptics,
  deps: DiffusionDepthPrefilterDeps,
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
  const scratchRT = pool.get("rt.diffusion.prefiltered", {
    width: width,
    height: height,
    format: "rgba16float",
  });
  const scratchView = scratchRT.createView();

  const s = scratch;
  s[0] = depthMistGain;
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
    label: "diffusion-depth-prefilter.bg",
    layout: layout,
    entries: [
      { binding: 0, resource: { buffer: buffer } },
      { binding: 1, resource: sourceView },
      { binding: 2, resource: depthTexture.createView() },
      { binding: 3, resource: sampler },
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
  pass.setPipeline(pipeline);
  pass.setBindGroup(0, offscreenFlagsBindGroup);
  pass.setBindGroup(1, bg);
  pass.draw(3, 1, 0, 0);
  pass.end();

  return scratchView;
}

export interface DiffusionPyramidDeps {
  device: GPUDevice;
  layout: GPUBindGroupLayout;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  downsamplePipeline: GPURenderPipeline;
  upsampleAddPipeline: GPURenderPipeline;
  width: number;
  height: number;
}

export function renderDiffusionPyramid(
  encoder: GPUCommandEncoder,
  sourceView: GPUTextureView,
  levels: GPUTexture[],
  diffusionPyramid: PyramidResources,
  deps: DiffusionPyramidDeps,
): GPUTexture {
  const {
    device,
    layout,
    sampler,
    offscreenFlagsBindGroup,
    downsamplePipeline,
    upsampleAddPipeline,
    width,
    height,
  } = deps;
  const weights = computeMipWeights(0.7, levels.length);

  // Step 1 — full-image first downsample: rt.colorGraded → levels[0].
  {
    const scratch = diffusionPyramid.downsampleScratch[0]!;
    scratch[0] = 1 / Math.max(width, 1);
    scratch[1] = 1 / Math.max(height, 1);
    scratch[2] = 0;
    scratch[3] = 0;
    device.queue.writeBuffer(
      diffusionPyramid.downsample[0]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: "diffusion.downsample.0.bg",
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: diffusionPyramid.downsample[0]! } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: sampler },
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
    pass.setPipeline(downsamplePipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  // Step 2 — progressive downsample.
  for (let i = 1; i < levels.length; i++) {
    const src = levels[i - 1]!;
    const dst = levels[i]!;
    const scratch = diffusionPyramid.downsampleScratch[i]!;
    scratch[0] = 1 / src.width;
    scratch[1] = 1 / src.height;
    scratch[2] = 0;
    scratch[3] = 0;
    device.queue.writeBuffer(
      diffusionPyramid.downsample[i]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: `diffusion.downsample.${i}.bg`,
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: diffusionPyramid.downsample[i]! } },
        { binding: 1, resource: src.createView() },
        { binding: 2, resource: sampler },
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
    pass.setPipeline(downsamplePipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  // Step 3 — additive upsample with the fixed wide diffusion radius.
  for (let i = levels.length - 2; i >= 0; i--) {
    const lowRes = levels[i + 1]!;
    const highRes = levels[i]!;
    const scratch = diffusionPyramid.upsampleScratch[i]!;
    scratch[0] = 1 / lowRes.width;
    scratch[1] = 1 / lowRes.height;
    scratch[2] = weights[i + 1]!;
    scratch[3] = 0;
    device.queue.writeBuffer(
      diffusionPyramid.upsample[i]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: `diffusion.upsample.${i}.bg`,
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: diffusionPyramid.upsample[i]! } },
        { binding: 1, resource: lowRes.createView() },
        { binding: 2, resource: sampler },
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
    pass.setPipeline(upsampleAddPipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return levels[0]!;
}
