/**
 * Shared bloom/halation pyramid chain — extracted verbatim from
 * `WebGPUBackend`'s private `computeMipWeights` / `ensurePyramidLevels` /
 * `renderPyramidChain` methods. This generic prefilter → downsample →
 * additive-upsample chain is reused by both the bloom and halation passes
 * (see `bloom.ts` / `halation.ts` callers in `WebGPUBackend.renderFrame`).
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original methods.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import type { PyramidResources } from "./types";

/**
 * Bloom / halation mip accumulation weights — WebGL parity formula.
 * Smaller `radius` biases energy toward the sharper mips; `radius=1`
 * spreads it outward to the low-freq tails.
 */
export function computeMipWeights(radius: number, levels: number): number[] {
  const weights: number[] = [];
  for (let i = 0; i < levels; i++) {
    const t = i / Math.max(levels - 1, 1);
    const base = Math.exp(-3.0 * (1.0 - radius) * t);
    const wide = Math.exp(-0.5 * radius * (1.0 - t));
    weights.push(base * (1 - radius) + wide * radius);
  }
  return weights;
}

export function ensurePyramidLevels(
  pool: OffscreenTargetPool,
  labelPrefix: string,
  levels: number,
  width: number,
  height: number,
): GPUTexture[] {
  const out: GPUTexture[] = [];
  for (let i = 0; i < levels; i++) {
    const divisor = 2 ** (i + 1);
    const w = Math.max(1, Math.floor(width / divisor));
    const h = Math.max(1, Math.floor(height / divisor));
    out.push(
      pool.get(`${labelPrefix}.${i}`, {
        width: w,
        height: h,
        format: "rgba16float",
      }),
    );
  }
  return out;
}

export interface PyramidChainDeps {
  device: GPUDevice;
  /** `layouts.pyramid` bind group layout — shared across all pyramid-shaped passes. */
  layout: GPUBindGroupLayout;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  downsamplePipeline: GPURenderPipeline;
  upsampleAddPipeline: GPURenderPipeline;
}

export function renderPyramidChain(
  encoder: GPUCommandEncoder,
  label: string,
  prefilterPipeline: GPURenderPipeline,
  prefilterParamsBuffer: GPUBuffer,
  sourceView: GPUTextureView,
  levels: GPUTexture[],
  pyramid: PyramidResources,
  radius: number,
  deps: PyramidChainDeps,
): GPUTexture {
  const { device, layout, sampler, offscreenFlagsBindGroup, downsamplePipeline, upsampleAddPipeline } =
    deps;
  const weights = computeMipWeights(radius, levels.length);

  // Step 1 — prefilter: sourceView → levels[0] (clear load, no blend).
  {
    const bg = device.createBindGroup({
      label: `${label}.prefilter.bg`,
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: prefilterParamsBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: sampler },
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
    pass.setBindGroup(0, offscreenFlagsBindGroup);
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
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: pyramid.downsample[i - 1]! } },
        { binding: 1, resource: src.createView() },
        { binding: 2, resource: sampler },
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
    pass.setPipeline(downsamplePipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
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
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: pyramid.upsample[i]! } },
        { binding: 1, resource: lowRes.createView() },
        { binding: 2, resource: sampler },
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
    pass.setPipeline(upsampleAddPipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return levels[0]!;
}
