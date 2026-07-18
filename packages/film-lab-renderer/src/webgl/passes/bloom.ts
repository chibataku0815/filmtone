/**
 * Bloom pass — extracted verbatim from `WebGLBackend.renderBloom`.
 *
 * Behavior-preserving relocation only: no render-target / material /
 * autoClear sequencing changes relative to the original method.
 */

import * as THREE from "three";
import { computeMipWeights } from "./pyramid";

export interface BloomRenderDeps {
  mips: THREE.WebGLRenderTarget[];
  bloomPrefilterMaterial: THREE.ShaderMaterial;
  downsampleMaterial: THREE.ShaderMaterial;
  upsampleMaterial: THREE.ShaderMaterial;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  opticalSourceTexture: THREE.Texture;
  bloomThreshold: number;
  bloomSoftKnee: number;
  bloomRadius: number;
}

export function renderBloom(renderer: THREE.WebGLRenderer, deps: BloomRenderDeps): void {
  const {
    mips,
    bloomPrefilterMaterial,
    downsampleMaterial,
    upsampleMaterial,
    postMesh,
    postScene,
    postCamera,
    opticalSourceTexture,
    bloomThreshold,
    bloomSoftKnee,
    bloomRadius,
  } = deps;

  // Step 1: Prefilter into mip[0]
  const bu = bloomPrefilterMaterial.uniforms;
  bu.uSource!.value = opticalSourceTexture;
  bu.uThreshold!.value = bloomThreshold;
  bu.uKnee!.value = bloomSoftKnee;
  postMesh.material = bloomPrefilterMaterial;
  renderer.setRenderTarget(mips[0]!);
  renderer.render(postScene, postCamera);

  // Step 2: Progressive downsample
  for (let i = 1; i < mips.length; i++) {
    const src = mips[i - 1]!;
    const dst = mips[i]!;
    const du = downsampleMaterial.uniforms;
    du.uSource!.value = src.texture;
    du.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
    postMesh.material = downsampleMaterial;
    renderer.setRenderTarget(dst);
    renderer.render(postScene, postCamera);
  }

  // Step 3: Progressive upsample with additive blending
  // Disable autoClear so the existing downsample data in each mip is preserved.
  // The upsample material uses AdditiveBlending to accumulate on top of it.
  const prevAutoClear = renderer.autoClear;
  renderer.autoClear = false;
  const weights = computeMipWeights(bloomRadius, mips.length);
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
