/**
 * Halo Prism pass — extracted verbatim from `WebGPUBackend.renderHaloPrism`.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original method.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import { DEFAULT_RAY_ANGLE_INNER_THRESHOLD, type ResolvedRayAngleOptics } from "../rayAngleOptics";
import type { HaloPrismResources } from "./types";

export interface HaloPrismRenderDeps {
  device: GPUDevice;
  pool: OffscreenTargetPool;
  width: number;
  height: number;
  imgResX: number;
  imgResY: number;
  fitMode: number;
  haloPrism: HaloPrismResources;
  /** `layouts.pyramid` — reused for the halo prism's compact source gate (same shape as cross-filter's). */
  pyramidLayout: GPUBindGroupLayout;
  haloPrismLayout: GPUBindGroupLayout;
  /** `pipelines.crossFilterSource` — reused for the halo prism's compact source gate. */
  crossFilterSourcePipeline: GPURenderPipeline;
  haloPrismPipeline: GPURenderPipeline;
  depthTexture: GPUTexture;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  crossFilterFlagsBindGroup: GPUBindGroup;
  paramNumber: (key: string, fallback: number) => number;
  resolveCurrentRayAngleOptics: () => ResolvedRayAngleOptics;
  packRayAngleOptics: (
    target: Float32Array,
    offset: number,
    optics: ResolvedRayAngleOptics,
    innerThreshold: number,
  ) => void;
}

export function renderHaloPrism(
  encoder: GPUCommandEncoder,
  sceneTexture: GPUTexture,
  sourceSeedTexture: GPUTexture,
  deps: HaloPrismRenderDeps,
): GPUTexture {
  const {
    device,
    pool,
    width,
    height,
    imgResX,
    imgResY,
    fitMode,
    haloPrism,
    pyramidLayout,
    haloPrismLayout,
    crossFilterSourcePipeline,
    haloPrismPipeline,
    depthTexture,
    sampler,
    offscreenFlagsBindGroup,
    crossFilterFlagsBindGroup,
    paramNumber,
    resolveCurrentRayAngleOptics,
    packRayAngleOptics,
  } = deps;
  const strength = Math.min(1, Math.max(0, paramNumber("haloPrismStrength", 0)));
  if (strength <= 0) {
    return sceneTexture;
  }

  const halfWidth = Math.max(1, Math.floor(width / 2));
  const halfHeight = Math.max(1, Math.floor(height / 2));
  const sourceGateTexture = pool.get("rt.halo-prism.source-gate", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const outputTexture = pool.get("rt.halo-prism.output", {
    width: width,
    height: height,
    format: "rgba16float",
  });

  const threshold = Math.min(
    1,
    Math.max(0, paramNumber("haloPrismThreshold", 0.9)),
  );
  const sourceParamsScratch = haloPrism.sourceParamsScratch;
  sourceParamsScratch[0] = threshold;
  sourceParamsScratch[1] = 0.18;
  // Halo Prism needs a stable lens-space trigger, not a binary peak switch.
  // Keep the compact-source shape extraction, but use its softer threshold
  // curve so video highlights do not pop frame-to-frame at the gate.
  sourceParamsScratch[2] = 0;
  sourceParamsScratch[3] = 0;
  device.queue.writeBuffer(
    haloPrism.sourceParamsBuffer,
    0,
    sourceParamsScratch.buffer,
    sourceParamsScratch.byteOffset,
    sourceParamsScratch.byteLength,
  );

  {
    const bg = device.createBindGroup({
      label: "halo-prism.source.bg",
      layout: pyramidLayout,
      entries: [
        { binding: 0, resource: { buffer: haloPrism.sourceParamsBuffer } },
        { binding: 1, resource: sourceSeedTexture.createView() },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "halo-prism.source",
      colorAttachments: [
        {
          view: sourceGateTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(crossFilterSourcePipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  const paramsScratch = haloPrism.paramsScratch;
  paramsScratch[0] = strength;
  paramsScratch[1] = Math.min(1, Math.max(0, paramNumber("haloPrismRadius", 0.62)));
  paramsScratch[2] = Math.min(1, Math.max(0, paramNumber("haloPrismWidth", 0.22)));
  paramsScratch[3] = Math.min(1, Math.max(0, paramNumber("haloPrismChromatic", 0.65)));
  paramsScratch[4] = Math.min(
    1,
    Math.max(0, paramNumber("haloPrismSourceReactivity", 0.85)),
  );
  paramsScratch[5] = Math.min(1, Math.max(0, paramNumber("haloPrismSplit", 0.7)));
  paramsScratch[6] = (paramNumber("haloPrismAngle", 0) * Math.PI) / 180;
  paramsScratch[7] = 0;
  paramsScratch[8] = width;
  paramsScratch[9] = height;
  paramsScratch[10] = imgResX;
  paramsScratch[11] = imgResY;
  paramsScratch[12] = fitMode;
  paramsScratch[13] = threshold;
  paramsScratch[14] = 0;
  paramsScratch[15] = 0;
  packRayAngleOptics(
    paramsScratch,
    16,
    resolveCurrentRayAngleOptics(),
    DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
  );
  device.queue.writeBuffer(
    haloPrism.paramsBuffer,
    0,
    paramsScratch.buffer,
    paramsScratch.byteOffset,
    paramsScratch.byteLength,
  );

  {
    const bg = device.createBindGroup({
      label: "halo-prism.blend.bg",
      layout: haloPrismLayout,
      entries: [
        { binding: 0, resource: { buffer: haloPrism.paramsBuffer } },
        { binding: 1, resource: sceneTexture.createView() },
        { binding: 2, resource: sourceGateTexture.createView() },
        { binding: 3, resource: depthTexture.createView() },
        { binding: 4, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "halo-prism.blend",
      colorAttachments: [
        {
          view: outputTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(haloPrismPipeline);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return outputTexture;
}
