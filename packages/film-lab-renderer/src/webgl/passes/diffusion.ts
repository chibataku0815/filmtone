/**
 * Diffusion (Pro-Mist) pass — extracted verbatim from
 * `WebGLBackend.renderDiffusion`.
 *
 * `ensureDiffusionResources()` (lazy mip-chain allocation) stays inline on
 * `WebGLBackend` — the wrapper method calls it before delegating here, same
 * as the original call order. Only the render/encode logic moves.
 *
 * Behavior-preserving relocation only: no render-target / material /
 * autoClear sequencing changes relative to the original method.
 */

import * as THREE from "three";
import { computeMipWeights } from "./pyramid";

export interface DiffusionRenderDeps {
  mips: THREE.WebGLRenderTarget[];
  downsampleMaterial: THREE.ShaderMaterial;
  upsampleMaterial: THREE.ShaderMaterial;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  opticalSourceTexture: THREE.Texture;
  rtColorGraded: THREE.WebGLRenderTarget;
}

/**
 * Diffusion (Pro-Mist): Full-image mip pyramid blur (no threshold prefilter).
 * Reuses downsample/upsample materials shared with bloom/halation.
 */
export function renderDiffusion(renderer: THREE.WebGLRenderer, deps: DiffusionRenderDeps): void {
  const {
    mips,
    downsampleMaterial,
    upsampleMaterial,
    postMesh,
    postScene,
    postCamera,
    opticalSourceTexture,
    rtColorGraded,
  } = deps;
  if (mips.length === 0) return;

  // Step 1: First downsample from optical source (NO prefilter — full image)
  const du = downsampleMaterial.uniforms;
  du.uSource!.value = opticalSourceTexture;
  du.uTexelSize!.value.set(
    1.0 / rtColorGraded.width,
    1.0 / rtColorGraded.height,
  );
  postMesh.material = downsampleMaterial;
  renderer.setRenderTarget(mips[0]!);
  renderer.render(postScene, postCamera);

  // Step 2: Progressive downsample
  for (let i = 1; i < mips.length; i++) {
    const src = mips[i - 1]!;
    const dst = mips[i]!;
    du.uSource!.value = src.texture;
    du.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
    renderer.setRenderTarget(dst);
    renderer.render(postScene, postCamera);
  }

  // Step 3: Progressive upsample with additive blending
  const prevAutoClear = renderer.autoClear;
  renderer.autoClear = false;
  const weights = computeMipWeights(0.7, mips.length); // wide fixed radius
  for (let i = mips.length - 2; i >= 0; i--) {
    const lowRes = mips[i + 1]!;
    const highRes = mips[i]!;
    const uu = upsampleMaterial.uniforms;
    uu.uSource!.value = lowRes.texture;
    uu.uTexelSize!.value.set(1.0 / lowRes.width, 1.0 / lowRes.height);
    uu.uWeight!.value = weights[i + 1]!;
    postMesh.material = upsampleMaterial;
    renderer.setRenderTarget(highRes);
    renderer.render(postScene, postCamera);
  }
  renderer.autoClear = prevAutoClear;
}
