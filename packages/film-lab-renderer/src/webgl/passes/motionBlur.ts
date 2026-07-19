/**
 * Motion blur pass — extracted verbatim from `WebGLBackend.renderMotionBlur`,
 * plus the small `getActiveFrameCount` / `computeBlendWeights` private
 * helpers that method was the sole caller of.
 *
 * `ensureMotionBlurResources()` (lazy material/ring-RT allocation) stays
 * inline on `WebGLBackend` — the wrapper method calls it before delegating
 * here, same as the original call order.
 *
 * `ringWriteIndex` / `ringFilledFrames` are instance-owned mutable counters
 * (not reference objects), so they can't be mutated through a plain
 * parameter. This function takes their current values and returns the
 * updated pair; the wrapper method assigns them back onto `this`.
 *
 * Behavior-preserving relocation only: no render-target / material /
 * autoClear sequencing changes relative to the original method.
 */

import * as THREE from "three";
import {
  activeMotionBlurFramesForShutter,
  computeMotionBlurWeights as computeMotionBlurWeightsShared,
  type MotionBlurWeightCurve,
} from "../../motionBlurMath";

/**
 * shutterAngle から有効フレーム数を算出する。
 * 180° 以下は通常素材の基準として temporal blend なし。
 */
function getActiveFrameCount(shutterAngle: number, ringSize: number): number {
  return activeMotionBlurFramesForShutter(
    shutterAngle,
    ringSize,
  );
}

/**
 * weightCurve に応じた正規化済みブレンドウェイトを計算する。
 * index 0 = newest, index N-1 = oldest。
 * shutterAngle は短い追加露光窓を決め、長い残像は trailIntensity が担当する。
 * shutterAngle > 360° では triangle → box へ自動的にフラット化する。
 */
function computeBlendWeights(
  shutterAngle: number,
  activeFrames: number,
  ringFilledFrames: number,
  ringSize: number,
  weightCurve: MotionBlurWeightCurve,
): Float32Array {
  return computeMotionBlurWeightsShared(
    shutterAngle,
    activeFrames,
    ringFilledFrames,
    ringSize,
    weightCurve,
  );
}

export interface MotionBlurRingState {
  ringWriteIndex: number;
  ringFilledFrames: number;
}

export interface MotionBlurRenderDeps {
  ringSize: number;
  ringCopyMaterial: THREE.ShaderMaterial | null;
  ringBlendMaterial: THREE.ShaderMaterial | null;
  rtRingBuffer: THREE.WebGLRenderTarget[];
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  shutterAngle: number;
  weightCurve: MotionBlurWeightCurve;
  trailIntensity: number;
  motionThreshold: number;
  ring: MotionBlurRingState;
  /** Shared 1x1 black-texture singleton owned by `WebGLBackend.ts` — passed
   * through (not duplicated) so both modules keep reusing the same GPU
   * resource instance. */
  getBlackTexture: () => THREE.DataTexture;
}

/**
 * N-frame ring buffer motion blur.
 * Draw 1: Copy sourceTexture → rtRingBuffer[ringWriteIndex]
 * Draw 2: Weighted blend of ring slots (newest first) → target
 *
 * @param renderer 描画先
 * @param sourceTexture composite 出力テクスチャ
 * @param target 最終出力先（null = 画面）
 */
export function renderMotionBlur(
  renderer: THREE.WebGLRenderer,
  sourceTexture: THREE.Texture,
  target: THREE.WebGLRenderTarget | null,
  deps: MotionBlurRenderDeps,
): MotionBlurRingState {
  const {
    ringSize,
    ringCopyMaterial,
    ringBlendMaterial,
    rtRingBuffer,
    postMesh,
    postScene,
    postCamera,
    shutterAngle,
    weightCurve,
    trailIntensity,
    motionThreshold,
    ring,
    getBlackTexture,
  } = deps;
  let ringWriteIndex = ring.ringWriteIndex;
  let ringFilledFrames = ring.ringFilledFrames;
  if (!ringCopyMaterial || !ringBlendMaterial || rtRingBuffer.length === 0) {
    return { ringWriteIndex, ringFilledFrames };
  }

  const N = ringSize;
  const prevAutoClear = renderer.autoClear;
  renderer.autoClear = false;

  // Draw 1: Feedback copy — mix(source, prevSlot, trail) → ring slot
  const cu = ringCopyMaterial.uniforms;
  cu.uSource!.value = sourceTexture;
  // Previous slot for feedback: the most recently written slot
  const prevSlotIdx = (ringWriteIndex - 1 + N) % N;
  cu.uPrevSlot!.value = ringFilledFrames > 0
    ? rtRingBuffer[prevSlotIdx]!.texture
    : getBlackTexture();
  cu.uTrail!.value = ringFilledFrames > 0 ? trailIntensity : 0.0;
  postMesh.material = ringCopyMaterial;
  renderer.setRenderTarget(rtRingBuffer[ringWriteIndex]!);
  renderer.render(postScene, postCamera);

  // Advance write head
  ringWriteIndex = (ringWriteIndex + 1) % N;
  ringFilledFrames = Math.min(ringFilledFrames + 1, N);

  // Draw 2: Weighted blend → target
  const activeFrames = getActiveFrameCount(shutterAngle, ringSize);
  const weights = computeBlendWeights(shutterAngle, activeFrames, ringFilledFrames, ringSize, weightCurve);

  const bu = ringBlendMaterial.uniforms;
  const black = getBlackTexture();

  // Bind ring slots in temporal order: newest first (index 0 = newest)
  for (let i = 0; i < N; i++) {
    // ringWriteIndex was just advanced, so newest = ringWriteIndex - 1
    const slotIndex = (ringWriteIndex - 1 - i + N * 2) % N;
    const filled = i < ringFilledFrames;
    bu[`uFrame${i}` as keyof typeof bu]!.value = filled
      ? rtRingBuffer[slotIndex]!.texture
      : black;
    bu[`uWeight${i}` as keyof typeof bu]!.value = weights[i]!;
  }
  bu.uActiveFrames!.value = Math.min(activeFrames, ringFilledFrames);
  bu.uMotionThreshold!.value = motionThreshold;

  postMesh.material = ringBlendMaterial;
  renderer.setRenderTarget(target);
  renderer.render(postScene, postCamera);

  renderer.autoClear = prevAutoClear;

  return { ringWriteIndex, ringFilledFrames };
}
