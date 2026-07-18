/**
 * Light shafts pass — extracted verbatim from `WebGPUBackend.renderLightShafts`.
 *
 * Two-sub-pass rendering (WebGL parity):
 *   9a: radial blur at 1/4 resolution (64 taps, luminance threshold).
 *   9b: additive blend at full resolution.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original method.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import type { LightShaftsResources } from "./types";

/** Light shafts quarter-resolution divisor (WebGL parity). */
const LIGHTSHAFTS_RES_DIVISOR = 4;
/** Light shafts radial sampling defaults (WebGL parity). */
const LIGHTSHAFTS_DENSITY = 0.98;
const LIGHTSHAFTS_EXPOSURE = 0.38;

export interface LightShaftsRenderDeps {
  device: GPUDevice;
  pool: OffscreenTargetPool;
  width: number;
  height: number;
  lightShafts: LightShaftsResources;
  lightshaftsLayout: GPUBindGroupLayout;
  lightshaftsBlendLayout: GPUBindGroupLayout;
  lightshaftsPipeline: GPURenderPipeline;
  lightshaftsBlendPipeline: GPURenderPipeline;
  sampler: GPUSampler;
  crossFilterFlagsBindGroup: GPUBindGroup;
  paramNumber: (key: string, fallback: number) => number;
}

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
export function renderLightShafts(
  encoder: GPUCommandEncoder,
  sourceTexture: GPUTexture,
  deps: LightShaftsRenderDeps,
): GPUTexture {
  const {
    device,
    pool,
    width,
    height,
    lightShafts,
    lightshaftsLayout,
    lightshaftsBlendLayout,
    lightshaftsPipeline,
    lightshaftsBlendPipeline,
    sampler,
    crossFilterFlagsBindGroup,
    paramNumber,
  } = deps;
  const shaftWidth = Math.max(1, Math.floor(width / LIGHTSHAFTS_RES_DIVISOR));
  const shaftHeight = Math.max(1, Math.floor(height / LIGHTSHAFTS_RES_DIVISOR));
  const shaftTexture = pool.get("rt.lightshafts.quarter", {
    width: shaftWidth,
    height: shaftHeight,
    format: "rgba16float",
  });
  const blendOutput = pool.get("rt.lightshafts.output", {
    width: width,
    height: height,
    format: "rgba16float",
  });

  const originX = Math.min(1, Math.max(0, paramNumber("shaftOriginX", 0.5)));
  const originYParam = Math.min(1, Math.max(0, paramNumber("shaftOriginY", 0.85)));
  const shaftDecay = Math.min(1, Math.max(0, paramNumber("shaftDecay", 0)));
  const shaftIntensity = Math.min(
    1,
    Math.max(0, paramNumber("shaftIntensity", 0)),
  );
  const decay = 0.92 + shaftDecay * 0.075;

  // Pack shaft shader params: (originX, 1-originY, decay, density), (exposure, _, _, _).
  const paramsScratch = lightShafts.paramsScratch;
  paramsScratch[0] = originX;
  paramsScratch[1] = 1 - originYParam;
  paramsScratch[2] = decay;
  paramsScratch[3] = LIGHTSHAFTS_DENSITY;
  paramsScratch[4] = LIGHTSHAFTS_EXPOSURE;
  paramsScratch[5] = 0;
  paramsScratch[6] = 0;
  paramsScratch[7] = 0;
  device.queue.writeBuffer(
    lightShafts.paramsBuffer,
    0,
    paramsScratch.buffer,
    paramsScratch.byteOffset,
    paramsScratch.byteLength,
  );

  const sourceView = sourceTexture.createView();
  {
    const bg = device.createBindGroup({
      label: "lightshafts.radial.bg",
      layout: lightshaftsLayout,
      entries: [
        { binding: 0, resource: { buffer: lightShafts.paramsBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "lightshafts.radial",
      colorAttachments: [
        {
          view: shaftTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(lightshaftsPipeline);
    // Light shafts must stay on the no-flip (cross-filter) contract for
    // both subpasses. The blend pass samples uScene (post-composite,
    // upright) and uShafts at the same UV; inheriting the offscreen
    // (flipY=0 → flips) contract here would invert the shaft RT
    // relative to the scene input and desync origin / decay.
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  const blendParamsScratch = lightShafts.blendParamsScratch;
  blendParamsScratch[0] = shaftIntensity;
  blendParamsScratch[1] = 0;
  blendParamsScratch[2] = 0;
  blendParamsScratch[3] = 0;
  device.queue.writeBuffer(
    lightShafts.blendParamsBuffer,
    0,
    blendParamsScratch.buffer,
    blendParamsScratch.byteOffset,
    blendParamsScratch.byteLength,
  );
  {
    const bg = device.createBindGroup({
      label: "lightshafts.blend.bg",
      layout: lightshaftsBlendLayout,
      entries: [
        { binding: 0, resource: { buffer: lightShafts.blendParamsBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: shaftTexture.createView() },
        { binding: 3, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "lightshafts.blend",
      colorAttachments: [
        {
          view: blendOutput.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(lightshaftsBlendPipeline);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return blendOutput;
}
