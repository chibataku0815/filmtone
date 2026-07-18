/**
 * Halation pass — extracted verbatim from `WebGLBackend.renderHalation`.
 *
 * Behavior-preserving relocation only: no render-target / material /
 * autoClear sequencing changes relative to the original method.
 */

import * as THREE from "three";
import { computeMipWeights } from "./pyramid";

export interface HalationRenderDeps {
  mips: THREE.WebGLRenderTarget[];
  halationPrefilterMaterial: THREE.ShaderMaterial;
  downsampleMaterial: THREE.ShaderMaterial;
  upsampleMaterial: THREE.ShaderMaterial;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  opticalSourceTexture: THREE.Texture;
  halationColor: THREE.Vector3;
  halationThreshold: number;
  halationSoftKnee: number;
  halationRadius: number;
}

export function renderHalation(renderer: THREE.WebGLRenderer, deps: HalationRenderDeps): void {
  const {
    mips,
    halationPrefilterMaterial,
    downsampleMaterial,
    upsampleMaterial,
    postMesh,
    postScene,
    postCamera,
    opticalSourceTexture,
    halationColor,
    halationThreshold,
    halationSoftKnee,
    halationRadius,
  } = deps;

  // Step 1: Prefilter + tint into mip[0]
  const hu = halationPrefilterMaterial.uniforms;
  hu.uSource!.value = opticalSourceTexture;
  hu.uHalationColor!.value.copy(halationColor);
  hu.uThreshold!.value = halationThreshold;
  hu.uKnee!.value = halationSoftKnee;
  postMesh.material = halationPrefilterMaterial;
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
  const prevAutoClear2 = renderer.autoClear;
  renderer.autoClear = false;
  const weights = computeMipWeights(halationRadius, mips.length);
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
  renderer.autoClear = prevAutoClear2;
}
