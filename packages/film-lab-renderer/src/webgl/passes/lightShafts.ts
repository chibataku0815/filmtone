/**
 * Light shafts pass — extracted verbatim from `WebGLBackend.renderLightShafts`.
 *
 * `ensureShaftResources()` (lazy material/RT allocation) stays inline on
 * `WebGLBackend` — the wrapper method calls it before delegating here, same
 * as the original call order, and forwards the (possibly still-null, on a
 * non-renderable resolution) resources for this function's own null check.
 *
 * Behavior-preserving relocation only.
 */

import * as THREE from "three";

export interface LightShaftsRenderDeps {
  shaftMaterial: THREE.ShaderMaterial | null;
  shaftBlendMaterial: THREE.ShaderMaterial | null;
  rtShaft: THREE.WebGLRenderTarget | null;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  shaftOriginX: number;
  shaftOriginY: number;
  shaftDecay: number;
  shaftIntensity: number;
}

/**
 * Light shafts two-sub-pass rendering.
 * 9a: Radial blur at 1/4 resolution (64 samples, luminance threshold).
 * 9b: Additive blend at full resolution.
 *
 * @param renderer 描画先
 * @param sourceTexture composite 出力テクスチャ
 * @param target 最終出力先（null = 画面）
 */
export function renderLightShafts(
  renderer: THREE.WebGLRenderer,
  sourceTexture: THREE.Texture,
  target: THREE.WebGLRenderTarget | null,
  deps: LightShaftsRenderDeps,
): void {
  const {
    shaftMaterial,
    shaftBlendMaterial,
    rtShaft,
    postMesh,
    postScene,
    postCamera,
    shaftOriginX,
    shaftOriginY,
    shaftDecay,
    shaftIntensity,
  } = deps;
  if (!shaftMaterial || !shaftBlendMaterial || !rtShaft) return;

  // 9a: Radial blur at 1/4 res
  const su = shaftMaterial.uniforms;
  su.uSource!.value = sourceTexture;
  su.uLightOrigin!.value.set(shaftOriginX, 1.0 - shaftOriginY); // UV flip
  su.uDecay!.value = 0.92 + shaftDecay * 0.075; // Map 0-1 to 0.92-0.995
  postMesh.material = shaftMaterial;
  renderer.setRenderTarget(rtShaft);
  renderer.render(postScene, postCamera);

  // 9b: Additive blend at full res
  const bu = shaftBlendMaterial.uniforms;
  bu.uSource!.value = sourceTexture;
  bu.uShaftTexture!.value = rtShaft.texture;
  bu.uIntensity!.value = shaftIntensity;
  postMesh.material = shaftBlendMaterial;
  renderer.setRenderTarget(target);
  renderer.render(postScene, postCamera);
}
