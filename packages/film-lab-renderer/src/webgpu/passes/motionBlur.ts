/**
 * Motion blur post-chain — extracted verbatim from the "motion blur ON"
 * branch inline in `WebGPUBackend.renderFrame` (feedback copy into the
 * ring buffer + N-slot weighted blend → swap), plus the small
 * `activeMotionBlurFrames` / `computeMotionBlurWeights` private helpers
 * that branch was the sole caller of.
 *
 * This is the only pass module whose extraction touches `renderFrame`
 * itself: the surrounding `if (compareEnabled) {...} else if (!motionBlurOn)
 * {...} else {...}` decision tree in `renderFrame` is left fully intact —
 * only the contents of the final `else` branch are replaced with a call
 * into this module.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original inline code.
 */

import type { RingBuffer } from "../RingBuffer";
import { MOTION_BLUR_RING_SLOTS } from "../RingBuffer";
import {
  activeMotionBlurFramesForShutter,
  computeMotionBlurWeights as computeMotionBlurWeightsShared,
} from "../../motionBlurMath";

/**
 * `shutterAngle` (degrees, 0..720) → active slot count. Matches WebGL:
 * 180° is the no-added-blur baseline, 360° = 2 slots, 720° = 3 slots.
 */
function activeMotionBlurFrames(shutterAngle: number): number {
  return activeMotionBlurFramesForShutter(
    shutterAngle,
    MOTION_BLUR_RING_SLOTS,
  );
}

/**
 * Pre-normalized motion-blur weights (sum = 1 across active slots, 0
 * elsewhere). Triangle/box mix follows the WebGL path: shutterAngle ≤
 * 360° is pure triangle; > 360° smoothly flattens to box by 720°.
 */
function computeMotionBlurWeights(
  shutterAngle: number,
  activeFrames: number,
  validSlots: number,
): Float32Array {
  return computeMotionBlurWeightsShared(
    shutterAngle,
    activeFrames,
    validSlots,
    MOTION_BLUR_RING_SLOTS,
  );
}

export interface MotionBlurRenderDeps {
  device: GPUDevice;
  ringBuffer: RingBuffer;
  motionblurFeedbackBuffer: GPUBuffer;
  motionblurFeedbackScratch: Float32Array;
  motionblurBlendBuffer: GPUBuffer;
  motionblurBlendScratch: Float32Array;
  motionblurFeedbackLayout: GPUBindGroupLayout;
  motionblurBlendLayout: GPUBindGroupLayout;
  motionblurFeedbackPipeline: GPURenderPipeline;
  motionblurBlendPipeline: GPURenderPipeline;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  displayFlagsBindGroup: GPUBindGroup;
  paramNumber: (key: string, fallback: number) => number;
}

/**
 * Motion blur ON — feedback copy + weighted blend.
 *
 * Draw 1: copy `postCompositeView` (mixed with the previous ring slot when
 * `trailIntensity > 0`) into `ringBuffer`'s next slot.
 * Draw 2: weighted blend of the last N active slots → `swapView` (and the
 * optional readback target).
 */
export function renderMotionBlurChain(
  encoder: GPUCommandEncoder,
  postCompositeView: GPUTextureView,
  swapView: GPUTextureView,
  readbackView: GPUTextureView | null,
  shutterAngle: number,
  deps: MotionBlurRenderDeps,
): void {
  const {
    device,
    ringBuffer,
    motionblurFeedbackBuffer,
    motionblurFeedbackScratch,
    motionblurBlendBuffer,
    motionblurBlendScratch,
    motionblurFeedbackLayout,
    motionblurBlendLayout,
    motionblurFeedbackPipeline,
    motionblurBlendPipeline,
    sampler,
    offscreenFlagsBindGroup,
    displayFlagsBindGroup,
    paramNumber,
  } = deps;
  const prevSlot =
    (ringBuffer.validSlots > 0
      ? // Most recently written slot is `(writeIndex - 1 + N) % N`;
        // when the ring is empty we fall through to the new slot and
        // let hasPrev=0 zero out the trail contribution.
        undefined
      : undefined);
  const nextSlot = ringBuffer.nextSlot();
  const validSlots = ringBuffer.validSlots; // already incremented
  const hasPrev = validSlots > 1 ? 1 : 0;
  const prevSlotIndex =
    (nextSlot - 1 + MOTION_BLUR_RING_SLOTS) % MOTION_BLUR_RING_SLOTS;
  void prevSlot; // explicitly unused; kept for future trail tuning

  const trailIntensity = paramNumber("trailIntensity", 0);
  motionblurFeedbackScratch[0] = trailIntensity;
  motionblurFeedbackScratch[1] = hasPrev;
  motionblurFeedbackScratch[2] = 0;
  motionblurFeedbackScratch[3] = 0;
  device.queue.writeBuffer(
    motionblurFeedbackBuffer,
    0,
    motionblurFeedbackScratch.buffer,
    motionblurFeedbackScratch.byteOffset,
    motionblurFeedbackScratch.byteLength,
  );

  // Previous-slot view: on the very first frame there is no real
  // previous slot; we reuse the same `nextSlot` layer (hasPrev=0 in
  // the uniform zeroes out its contribution).
  const prevView = ringBuffer.viewForSlot(hasPrev === 1 ? prevSlotIndex : nextSlot);
  const nextView = ringBuffer.viewForSlot(nextSlot);

  const feedbackBg = device.createBindGroup({
    label: "motionblur.feedback.bg",
    layout: motionblurFeedbackLayout,
    entries: [
      { binding: 0, resource: { buffer: motionblurFeedbackBuffer } },
      { binding: 1, resource: postCompositeView },
      { binding: 2, resource: prevView },
      { binding: 3, resource: sampler },
    ],
  });
  {
    const pass = encoder.beginRenderPass({
      label: "motionblur.feedback.pass",
      colorAttachments: [
        {
          view: nextView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(motionblurFeedbackPipeline);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, feedbackBg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  const activeFrames = Math.min(
    activeMotionBlurFrames(shutterAngle),
    validSlots,
  );
  const weights = computeMotionBlurWeights(
    shutterAngle,
    activeFrames,
    validSlots,
  );
  const oldestSlot =
    (nextSlot - (activeFrames - 1) + MOTION_BLUR_RING_SLOTS * 2) %
    MOTION_BLUR_RING_SLOTS;
  const motionThreshold = paramNumber("motionThreshold", 0);

  for (let i = 0; i < MOTION_BLUR_RING_SLOTS; i++) {
    motionblurBlendScratch[i] = weights[i] ?? 0;
  }
  motionblurBlendScratch[8] = nextSlot;
  motionblurBlendScratch[9] = oldestSlot;
  motionblurBlendScratch[10] = motionThreshold;
  motionblurBlendScratch[11] = 0;
  device.queue.writeBuffer(
    motionblurBlendBuffer,
    0,
    motionblurBlendScratch.buffer,
    motionblurBlendScratch.byteOffset,
    motionblurBlendScratch.byteLength,
  );

  const blendBg = device.createBindGroup({
    label: "motionblur.blend.bg",
    layout: motionblurBlendLayout,
    entries: [
      { binding: 0, resource: { buffer: motionblurBlendBuffer } },
      { binding: 1, resource: ringBuffer.arrayView() },
      { binding: 2, resource: sampler },
    ],
  });
  if (readbackView) {
    const readbackPass = encoder.beginRenderPass({
      label: "motionblur.blend.readback.pass",
      colorAttachments: [
        {
          view: readbackView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    readbackPass.setPipeline(motionblurBlendPipeline);
    readbackPass.setBindGroup(0, displayFlagsBindGroup);
    readbackPass.setBindGroup(1, blendBg);
    readbackPass.draw(3, 1, 0, 0);
    readbackPass.end();
  }
  {
    const pass = encoder.beginRenderPass({
      label: "motionblur.blend.present.pass",
      colorAttachments: [
        {
          view: swapView,
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(motionblurBlendPipeline);
    pass.setBindGroup(0, displayFlagsBindGroup);
    pass.setBindGroup(1, blendBg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }
}
