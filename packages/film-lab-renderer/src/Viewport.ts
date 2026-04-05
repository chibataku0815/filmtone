/**
 * Viewport — Fullscreen quad with Film Lab color grading + Bloom/Halation multi-pass
 *
 * Architecture:
 *   Pass 1: Color grade (filmlab.frag) → RenderTarget A
 *   Pass 2-4: Bloom threshold → blur H → blur V (1/2 res)
 *   Pass 5-7: Halation threshold+tint → blur H → blur V (1/4 res)
 *   Pass 8: Composite (A + bloom + halation + vignette + grain + split) → screen
 *   Pass 9:  (reserved: #100 light shafts)
 *   Pass 10: #99 Dust & Scratches overlay (screen + additive blend)
 *   Pass 11: #97 Slow Shutter / EMA motion blur (ping-pong accumulation)
 */

import * as THREE from "three";
import {
  chromaUnitFromHueDegrees,
  FILM_LAB_DEFAULT_HIGHLIGHT_HUE,
  FILM_LAB_DEFAULT_SHADOW_HUE,
  LEGACY_HIGHLIGHT_TONE_MAGNITUDE,
  LEGACY_SHADOW_TONE_MAGNITUDE,
} from "film-lab-core";
import { filmlabVertexShader } from "./shaders/filmlab.vert";
import { bloomPrefilterFragmentShader } from "./shaders/bloom-prefilter.frag";
import { halationPrefilterFragmentShader } from "./shaders/halation-prefilter.frag";
import { downsampleFragmentShader } from "./shaders/downsample.frag";
import { upsampleFragmentShader } from "./shaders/upsample.frag";
import { compositeFragmentShader } from "./shaders/composite.frag";
import { motionblurFragmentShader } from "./shaders/motionblur.frag";
import { dustFragmentShader } from "./shaders/dust.frag";
import { createDustTexture, createScratchTexture } from "./textures/index";
import { lightshaftsFragmentShader } from "./shaders/lightshafts.frag";
import { lightshaftsBlendFragmentShader } from "./shaders/lightshafts-blend.frag";

export interface ViewportOptions {
  vertexShader: string;
  fragmentShader: string;
  width: number;
  height: number;
}

let _blackTexture: THREE.DataTexture | null = null;
function getBlackTexture(): THREE.DataTexture {
  if (!_blackTexture) {
    _blackTexture = new THREE.DataTexture(
      new Uint8Array([0, 0, 0, 255]),
      1, 1,
      THREE.RGBAFormat,
    );
    _blackTexture.needsUpdate = true;
  }
  return _blackTexture;
}

const RT_OPTIONS: THREE.RenderTargetOptions = {
  minFilter: THREE.LinearFilter,
  magFilter: THREE.LinearFilter,
  format: THREE.RGBAFormat,
  type: THREE.HalfFloatType,
};

/**
 * 色収差スライダに連動して composite で周辺ソフトを掛ける混色率のゲイン。
 * rgbShift が 0 のときはユニフォーム 0（ソフトなし）。
 * 新 UI 上限 0.01 でも、上げたときの周辺柔らかさが分かるよう少しだけ強める。
 */
const ABERRATION_EDGE_SOFTEN_SCALE = 32;

function hexToVec3(hex: string): THREE.Vector3 {
  const c = new THREE.Color(hex);
  return new THREE.Vector3(c.r, c.g, c.b);
}

export class Viewport {
  mesh: THREE.Mesh;
  private material: THREE.ShaderMaterial;
  private geometry: THREE.PlaneGeometry;

  // Post-processing scene (shared quad, swap material per pass)
  private postScene: THREE.Scene;
  private postCamera: THREE.OrthographicCamera;
  private postGeometry: THREE.PlaneGeometry;
  private postMesh: THREE.Mesh;

  // Post-processing materials
  private bloomPrefilterMaterial: THREE.ShaderMaterial;
  private halationPrefilterMaterial: THREE.ShaderMaterial;
  private downsampleMaterial: THREE.ShaderMaterial;
  private upsampleMaterial: THREE.ShaderMaterial;
  private compositeMaterial: THREE.ShaderMaterial;

  // RenderTargets (lazy)
  private rtColorGraded: THREE.WebGLRenderTarget | null = null;
  private static readonly BLOOM_MIP_LEVELS = 5;
  private static readonly HALATION_MIP_LEVELS = 6;
  private static readonly DIFFUSION_MIP_LEVELS = 3;
  private rtBloomMips: THREE.WebGLRenderTarget[] = [];
  private rtHalationMips: THREE.WebGLRenderTarget[] = [];
  /** A/B 比較: スロット A の最終合成（分割なし）を書き込む */
  private rtCompareComposite: THREE.WebGLRenderTarget | null = null;
  /** #98 で確保する将来の post-composite 用フル解像度 RT（左側） */
  private rtPostComposite0: THREE.WebGLRenderTarget | null = null;
  /** #98 で確保する将来の post-composite 用フル解像度 RT（右側） */
  private rtPostComposite1: THREE.WebGLRenderTarget | null = null;

  /** true のとき render() でスロット A→RT、続けてスロット B を画面に分割表示 */
  private abCompareEnabled = false;
  private compareParamsA: Record<string, number | string> = {};
  private compareParamsB: Record<string, number | string> = {};

  // Bloom/Halation params (stored here, not on color grade material)
  private bloomThreshold = 0.8;
  private bloomStrength = 0.0;
  private bloomRadius = 0.4;
  private halationIntensity = 0.0;
  private halationSpread = 15.0;
  private halationColor = new THREE.Vector3(0.91, 0.063, 0.125);
  private halationThreshold = 0.6;
  private halationRadius = 0.6;
  private bloomSoftKnee = 0.5;
  private halationSoftKnee = 0.3;

  // --- Diffusion (Pro-Mist / Cinebloom) ---
  private diffusion = 0.0;
  private rtDiffusionMips: THREE.WebGLRenderTarget[] = [];

  /**
   * composite の径方向グレイン混色（0=一様、1=周辺強め）。カラーパスには無く合成パスのみ。
   */
  private grainRadialMix = 1.0;

  // --- Motion Blur (Post-composite #97) ---
  private motionBlurAmount = 0.0;
  private frameRepeat = 1; // renderer-internal, not in PARAM_KEYS
  private motionBlurFrame = 0;
  private hasMotionBlurHistory = false;
  private motionBlurMaterial: THREE.ShaderMaterial | null = null;
  private rtMotionBlur0: THREE.WebGLRenderTarget | null = null;
  private rtMotionBlur1: THREE.WebGLRenderTarget | null = null;

  // --- Dust & Scratches (Post-composite #99) ---
  private dustAmount = 0.0;
  private scratchAmount = 0.0;
  private dustMaterial: THREE.ShaderMaterial | null = null;
  private dustTexture: THREE.CanvasTexture | null = null;
  private scratchTexture: THREE.CanvasTexture | null = null;

  // --- Light Shafts (Post-composite #100) ---
  private shaftIntensity = 0.0;
  private shaftDecay = 0.5;
  private shaftOriginX = 0.5;
  private shaftOriginY = 0.15;
  private shaftMaterial: THREE.ShaderMaterial | null = null;
  private shaftBlendMaterial: THREE.ShaderMaterial | null = null;
  private rtShaft: THREE.WebGLRenderTarget | null = null;

  /**
   * composite のレンズ周辺ソフト（0〜1）。色収差周辺ソフトとは別（Params.lensSoftness）。
   */
  private lensSoftness = 0.0;

  /**
   * シャドウ／ハイライトの色相は GPU から一意に逆算できないため、最後に `setParams` で適用した値を保持する。
   * `getParams` と「色相だけ更新」のときの強度維持に使う。
   */
  private splitShadowHueDeg = FILM_LAB_DEFAULT_SHADOW_HUE;
  private splitHighlightHueDeg = FILM_LAB_DEFAULT_HIGHLIGHT_HUE;

  private width: number;
  private height: number;

  private renderer: THREE.WebGLRenderer | null = null;
  private histogramBuffer: Float32Array | null = null;
  /** HalfFloat RT 読み戻し用（readPixels は RGBA + HALF_FLOAT + Uint16 が正系） */
  private histogramHalfBuffer: Uint16Array | null = null;

  constructor(options: ViewportOptions) {
    this.width = options.width;
    this.height = options.height;

    // Pass 1: Color grade material
    this.material = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: options.vertexShader,
      fragmentShader: options.fragmentShader,
      uniforms: {
        uTexture: { value: null },
        uResolution: {
          value: new THREE.Vector2(options.width, options.height),
        },
        uImageResolution: { value: new THREE.Vector2(1280, 720) },
        uTime: { value: 0.0 },
        uExposure: { value: 0.0 },
        uContrast: { value: 1.0 },
        uSaturation: { value: 1.0 },
        uTemperature: { value: 0.0 },
        uTint: { value: 0.0 },
        uShadowTint: { value: new THREE.Vector3(0, 0, 0) },
        uHighlightTint: { value: new THREE.Vector3(0, 0, 0) },
        uRGBShift: { value: 0.0 },
        uGrainIntensity: { value: 0.0 },
        uVignette: { value: 0.0 },
        uFade: { value: 0.0 },
        uHighlights: { value: 0.0 },
        uShadows: { value: 0.0 },
        /** -1 で分割オフ（全面がグレード後）。0〜1 で Before/After または A/B の境界 */
        uSplitPosition: { value: -1.0 },
        uLUT1: { value: null },
        uLUT1Intensity: { value: 1.0 },
        uLUT1Enabled: { value: 0.0 },
        uLUT2: { value: null },
        uLUT2Intensity: { value: 1.0 },
        uLUT2Enabled: { value: 0.0 },
        // 0.4.0 の現像段・プリント段で使う数値 uniform。
        uCompressionAmount: { value: 0.0 },
        uCompressionRange: { value: 0.5 },
        uPrintContrast: { value: 0.0 },
        uCyan: { value: 0.0 },
        uMagenta: { value: 0.0 },
        uYellow: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    this.geometry = new THREE.PlaneGeometry(2, 2);
    this.mesh = new THREE.Mesh(this.geometry, this.material);

    // Post-processing scene
    this.postScene = new THREE.Scene();
    this.postCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
    this.postGeometry = new THREE.PlaneGeometry(2, 2);
    this.postMesh = new THREE.Mesh(this.postGeometry);
    this.postScene.add(this.postMesh);

    // Bloom prefilter material
    this.bloomPrefilterMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: bloomPrefilterFragmentShader,
      uniforms: {
        uSource: { value: null },
        uThreshold: { value: 0.8 },
        uKnee: { value: 0.5 },
        uFlipY: { value: 0.0 },
      },
    });

    // Halation prefilter material
    this.halationPrefilterMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: halationPrefilterFragmentShader,
      uniforms: {
        uSource: { value: null },
        uHalationColor: { value: new THREE.Vector3(0.91, 0.063, 0.125) },
        uThreshold: { value: 0.6 },
        uKnee: { value: 0.3 },
        uFlipY: { value: 0.0 },
      },
    });

    // Downsample material (shared for bloom + halation mip chain)
    this.downsampleMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: downsampleFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE.Vector2() },
        uFlipY: { value: 0.0 },
      },
    });

    // Upsample material (shared for bloom + halation mip chain)
    this.upsampleMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: upsampleFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE.Vector2() },
        uWeight: { value: 1.0 },
        uFlipY: { value: 0.0 },
      },
      blending: THREE.AdditiveBlending,
      depthTest: false,
      depthWrite: false,
    });

    // Composite material
    this.compositeMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: compositeFragmentShader,
      uniforms: {
        uSource: { value: null },
        uBloomTexture: { value: null },
        uHalationTexture: { value: null },
        uDiffusionTexture: { value: null },
        uOriginalTexture: { value: null },
        uBloomStrength: { value: 0.0 },
        uHalationIntensity: { value: 0.0 },
        uDiffusion: { value: 0.0 },
        uVignette: { value: 0.0 },
        uGrainIntensity: { value: 0.0 },
        uGrainRadialMix: { value: 1.0 },
        uGrainSize: { value: 0.3 },
        uTime: { value: 0.0 },
        uSplitPosition: { value: -1.0 },
        uAbCompare: { value: 0.0 },
        uResolution: {
          value: new THREE.Vector2(options.width, options.height),
        },
        uImageResolution: { value: new THREE.Vector2(1280, 720) },
        uAberrationEdgeSoften: { value: 0.0 },
        uLensSoftness: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });
  }

  // ===== RenderTarget management =====

  /**
   * @description 0x0 の RenderTarget は WebGL warning の原因になります。
   * 画面の幅と高さが両方そろったときだけ GPU リソースを作ります。
   */
  private hasRenderableResolution(): boolean {
    return this.width > 0 && this.height > 0;
  }

  private ensureRenderTargets(): void {
    if (this.rtColorGraded) return;
    if (!this.hasRenderableResolution()) return;

    const w = this.width;
    const h = this.height;

    this.rtColorGraded = new THREE.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtCompareComposite = new THREE.WebGLRenderTarget(w, h, RT_OPTIONS);

    // Bloom mip chain (5 levels: W/2 .. W/32)
    this.rtBloomMips = [];
    for (let i = 0; i < Viewport.BLOOM_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtBloomMips.push(new THREE.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }

    // Halation mip chain (6 levels: W/2 .. W/64)
    this.rtHalationMips = [];
    for (let i = 0; i < Viewport.HALATION_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtHalationMips.push(new THREE.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }

  private resizeRenderTargets(w: number, h: number): void {
    if (!this.rtColorGraded) return;
    if (w <= 0 || h <= 0) return;

    this.rtColorGraded.setSize(w, h);
    this.rtCompareComposite?.setSize(w, h);

    for (let i = 0; i < this.rtBloomMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtBloomMips[i]!.setSize(mw, mh);
    }
    for (let i = 0; i < this.rtHalationMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtHalationMips[i]!.setSize(mw, mh);
    }
    for (let i = 0; i < this.rtDiffusionMips.length; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtDiffusionMips[i]!.setSize(mw, mh);
    }
    this.resizePostCompositeRenderTargets(w, h);
  }

  /**
   * Diffusion 用 mip chain を lazy 確保。diffusion=0 のときは GPU コストゼロ。
   */
  private ensureDiffusionResources(): void {
    if (this.rtDiffusionMips.length > 0) return;
    if (!this.hasRenderableResolution()) return;

    const w = this.width;
    const h = this.height;
    for (let i = 0; i < Viewport.DIFFUSION_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtDiffusionMips.push(new THREE.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }

  /**
   * #98 の post-composite seam が有効になったときだけ、中間 RT を作る。
   * 無効時は呼ばれないので、Pass 8 だけの現在挙動に余計なコストを足さない。
   */
  private ensurePostCompositeRenderTargets(): void {
    if (this.rtPostComposite0) return;
    if (!this.hasRenderableResolution()) return;

    const w = this.width;
    const h = this.height;
    this.rtPostComposite0 = new THREE.WebGLRenderTarget(w, h, RT_OPTIONS);
    this.rtPostComposite1 = new THREE.WebGLRenderTarget(w, h, RT_OPTIONS);
  }

  /**
   * Motion blur 用の ShaderMaterial と ping-pong RT を遅延生成する。
   * motionBlurAmount > 0 になるまで GPU リソースを消費しない。
   */
  private ensureMotionBlurResources(): void {
    if (this.motionBlurMaterial) return;
    this.motionBlurMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: motionblurFragmentShader,
      uniforms: {
        uCurrentFrame: { value: null },
        uPrevAccum: { value: null },
        uAmount: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });
    this.rtMotionBlur0 = new THREE.WebGLRenderTarget(this.width, this.height, RT_OPTIONS);
    this.rtMotionBlur1 = new THREE.WebGLRenderTarget(this.width, this.height, RT_OPTIONS);
  }

  /**
   * Dust & Scratches 用の ShaderMaterial とテクスチャを遅延生成する。
   * dustAmount > 0 || scratchAmount > 0 になるまで GPU リソースを消費しない。
   */
  private ensureDustResources(): void {
    if (this.dustMaterial) return;
    this.dustTexture = createDustTexture();
    this.scratchTexture = createScratchTexture();
    this.dustMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: dustFragmentShader,
      uniforms: {
        uSource: { value: null },
        uDustTexture: { value: this.dustTexture },
        uScratchTexture: { value: this.scratchTexture },
        uDustAmount: { value: 0.0 },
        uScratchAmount: { value: 0.0 },
        uTime: { value: 0.0 },
        uResolution: { value: new THREE.Vector2() },
        uFlipY: { value: 0.0 },
      },
    });
  }

  /**
   * Light shafts 用の ShaderMaterial と 1/4 解像度 RT を遅延生成する。
   * shaftIntensity > 0 になるまで GPU リソースを消費しない。
   */
  private ensureShaftResources(): void {
    if (this.shaftMaterial) return;

    this.shaftMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: lightshaftsFragmentShader,
      uniforms: {
        uSource: { value: null },
        uLightOrigin: { value: new THREE.Vector2(0.5, 0.85) },
        uDecay: { value: 0.96 },
        uDensity: { value: 0.98 },
        uExposure: { value: 0.38 },
        uFlipY: { value: 0.0 },
      },
    });

    this.shaftBlendMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: lightshaftsBlendFragmentShader,
      uniforms: {
        uSource: { value: null },
        uShaftTexture: { value: null },
        uIntensity: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    // 1/4 resolution RT for performance
    const qw = Math.max(1, Math.floor(this.width / 4));
    const qh = Math.max(1, Math.floor(this.height / 4));
    this.rtShaft = new THREE.WebGLRenderTarget(qw, qh, RT_OPTIONS);
  }

  /**
   * #98 の post-composite seam で使う RT を、画面サイズに合わせて広げ直す。
   *
   * @param w 幅
   * @param h 高さ
   */
  private resizePostCompositeRenderTargets(w: number, h: number): void {
    if (!this.rtPostComposite0 || !this.rtPostComposite1) return;
    if (w <= 0 || h <= 0) return;

    this.rtPostComposite0.setSize(w, h);
    this.rtPostComposite1.setSize(w, h);
  }

  // ===== Multi-pass render =====

  /**
   * 合成パス用ユニフォームをカラーグレード側（＋ Bloom/Halation 強度）に合わせる。
   */
  private syncCompositeUniformsFromMaterial(): void {
    const cu = this.compositeMaterial.uniforms;
    const mu = this.material.uniforms;
    cu.uVignette!.value = mu.uVignette!.value;
    cu.uGrainIntensity!.value = mu.uGrainIntensity!.value;
    cu.uGrainRadialMix!.value = this.grainRadialMix;
    cu.uTime!.value = mu.uTime!.value;
    cu.uResolution!.value.copy(mu.uResolution!.value as THREE.Vector2);
    cu.uImageResolution!.value.copy(
      mu.uImageResolution!.value as THREE.Vector2,
    );
    cu.uBloomStrength!.value = this.bloomStrength;
    cu.uHalationIntensity!.value = this.halationIntensity;
    const rgbShift = mu.uRGBShift!.value as number;
    cu.uAberrationEdgeSoften!.value = Math.min(
      1,
      Math.max(0, rgbShift * ABERRATION_EDGE_SOFTEN_SCALE),
    );
    cu.uLensSoftness!.value = this.lensSoftness;
  }

  /**
   * post-composite chain が必要かどうか。A/B 比較中は無効化する（R9 対策）。
   */
  private hasPostCompositeChain(): boolean {
    if (this.abCompareEnabled) return false;
    // v0.5.0: Only motionBlur is user-facing. Shafts/Dust/Scratch deferred to v0.6
    return this.motionBlurAmount > 0;
  }

  /**
   * Pass 1〜7 をまとめて実行する。
   * ここではまだ composite へは行かず、Pass 8 の入力を作るだけにする。
   *
   * @param renderer 描画先
   * @param scene 元シーン
   * @param camera 元カメラ
   */
  private renderBasePipeline(
    renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    camera: THREE.Camera,
  ): void {
    renderer.setRenderTarget(this.rtColorGraded);
    renderer.render(scene, camera);

    const bloomOn = this.bloomStrength > 0;
    const halationOn = this.halationIntensity > 0;
    const diffusionOn = this.diffusion > 0;

    if (bloomOn) {
      this.renderBloom(renderer);
    }

    if (halationOn) {
      this.renderHalation(renderer);
    }

    if (diffusionOn) {
      this.renderDiffusion(renderer);
    }
  }

  /**
   * Pass 8 の合成を 1 箇所へまとめる。
   *
   * @param renderer 描画先
   * @param target 出力先 RT。`null` なら画面に出す。
   * @param splitPosition 分割線の位置
   * @param abCompare A/B 比較かどうか
   * @param originalTexture 左側に見せる元画像
   */
  private renderCompositeFrame(
    renderer: THREE.WebGLRenderer,
    target: THREE.WebGLRenderTarget | null,
    splitPosition: number,
    abCompare: number,
    originalTexture: THREE.Texture,
  ): void {
    const cu = this.compositeMaterial.uniforms;
    this.syncCompositeUniformsFromMaterial();
    cu.uSplitPosition!.value = splitPosition;
    cu.uAbCompare!.value = abCompare;
    cu.uOriginalTexture!.value = originalTexture;

    const black = getBlackTexture();
    const bloomOn = this.bloomStrength > 0;
    const halationOn = this.halationIntensity > 0;
    const diffusionOn = this.diffusion > 0;
    cu.uSource!.value = this.rtColorGraded!.texture;
    cu.uBloomTexture!.value = bloomOn ? this.rtBloomMips[0]!.texture : black;
    cu.uHalationTexture!.value = halationOn ? this.rtHalationMips[0]!.texture : black;
    cu.uDiffusionTexture!.value = diffusionOn && this.rtDiffusionMips.length > 0
      ? this.rtDiffusionMips[0]!.texture
      : black;
    cu.uDiffusion!.value = this.diffusion;
    this.postMesh.material = this.compositeMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }

  /**
   * 最終出力の入口。
   * #98 では post-composite chain が無い限り、Pass 8 をそのまま target に出す。
   * chain が有効になったときだけ、中間 RT を使って後段へ渡す。
   *
   * @param renderer 描画先
   * @param target 出力先 RT。`null` なら画面に出す。
   * @param originalTexture 左側に見せる元画像
   * @param splitPosition 分割線の位置
   * @param abCompare A/B 比較かどうか
   */
  private renderFinalFrame(
    renderer: THREE.WebGLRenderer,
    target: THREE.WebGLRenderTarget | null,
    originalTexture: THREE.Texture,
    splitPosition: number,
    abCompare: number,
  ): void {
    if (!this.hasPostCompositeChain()) {
      this.renderCompositeFrame(
        renderer,
        target,
        splitPosition,
        abCompare,
        originalTexture,
      );
      return;
    }

    this.ensurePostCompositeRenderTargets();
    if (!this.rtPostComposite0 || !this.rtPostComposite1) {
      this.renderCompositeFrame(
        renderer,
        target,
        splitPosition,
        abCompare,
        originalTexture,
      );
      return;
    }

    this.renderCompositeFrame(
      renderer,
      this.rtPostComposite0,
      splitPosition,
      abCompare,
      originalTexture,
    );
    this.renderPostCompositeChain(
      renderer,
      this.rtPostComposite0.texture,
      target,
    );
  }

  /**
   * Dust & Scratches パス。Screen blend で埃、Additive で傷をオーバーレイする。
   *
   * @param renderer 描画先
   * @param sourceTexture 直前の post-composite 出力
   * @param target 出力先（null = 画面）
   */
  private renderDust(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    target: THREE.WebGLRenderTarget | null,
  ): void {
    this.ensureDustResources();
    if (!this.dustMaterial) return;
    const du = this.dustMaterial.uniforms;
    du.uSource!.value = sourceTexture;
    du.uDustAmount!.value = this.dustAmount;
    du.uScratchAmount!.value = this.scratchAmount;
    du.uTime!.value = this.material.uniforms.uTime!.value;
    du.uResolution!.value.set(this.width, this.height);
    this.postMesh.material = this.dustMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }

  /**
   * EMA モーションブラー（ping-pong 蓄積）。
   * Step 1: current frame と前フレームの蓄積を EMA ブレンド → writeRT
   * Step 2: writeRT の結果を最終 target へコピー
   *
   * @param renderer 描画先
   * @param sourceTexture composite 出力テクスチャ
   * @param target 最終出力先（null = 画面）
   */
  private renderMotionBlur(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    target: THREE.WebGLRenderTarget | null,
  ): void {
    this.ensureMotionBlurResources();
    if (!this.motionBlurMaterial || !this.rtMotionBlur0 || !this.rtMotionBlur1) return;

    // R3: Frame 0 black flash prevention
    const effectiveAmount = this.hasMotionBlurHistory ? this.motionBlurAmount : 0.0;

    // Ping-pong: read from current accumulator, write to the other
    const readRT = this.motionBlurFrame % 2 === 0 ? this.rtMotionBlur0 : this.rtMotionBlur1;
    const writeRT = this.motionBlurFrame % 2 === 0 ? this.rtMotionBlur1 : this.rtMotionBlur0;

    const mu = this.motionBlurMaterial.uniforms;
    mu.uCurrentFrame!.value = sourceTexture;
    mu.uPrevAccum!.value = readRT.texture;
    mu.uAmount!.value = effectiveAmount;

    // Step 1: EMA blend -> writeRT
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    this.postMesh.material = this.motionBlurMaterial;
    renderer.setRenderTarget(writeRT);
    renderer.render(this.postScene, this.postCamera);

    // Step 2: Copy writeRT -> final target
    mu.uCurrentFrame!.value = writeRT.texture;
    mu.uAmount!.value = 0.0;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);

    renderer.autoClear = prevAutoClear;

    this.motionBlurFrame++;
    this.hasMotionBlurHistory = true;
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
  private renderLightShafts(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    target: THREE.WebGLRenderTarget | null,
  ): void {
    this.ensureShaftResources();
    if (!this.shaftMaterial || !this.shaftBlendMaterial || !this.rtShaft) return;

    // 9a: Radial blur at 1/4 res
    const su = this.shaftMaterial.uniforms;
    su.uSource!.value = sourceTexture;
    su.uLightOrigin!.value.set(this.shaftOriginX, 1.0 - this.shaftOriginY); // UV flip
    su.uDecay!.value = 0.92 + this.shaftDecay * 0.075; // Map 0-1 to 0.92-0.995
    this.postMesh.material = this.shaftMaterial;
    renderer.setRenderTarget(this.rtShaft);
    renderer.render(this.postScene, this.postCamera);

    // 9b: Additive blend at full res
    const bu = this.shaftBlendMaterial.uniforms;
    bu.uSource!.value = sourceTexture;
    bu.uShaftTexture!.value = this.rtShaft.texture;
    bu.uIntensity!.value = this.shaftIntensity;
    this.postMesh.material = this.shaftBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }

  /**
   * Pass 9+ の受け皿。
   * Pass order: Shafts(9) -> Dust(10) -> MotionBlur(11)
   *
   * @param renderer 描画先
   * @param sourceTexture 直前の post-composite 出力
   * @param target 最終出力先
   */
  private renderPostCompositeChain(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    target: THREE.WebGLRenderTarget | null,
  ): void {
    const shaftOn = this.shaftIntensity > 0;
    const dustOn = this.dustAmount > 0 || this.scratchAmount > 0;
    const motionBlurOn = this.motionBlurAmount > 0;

    type Pass = "shaft" | "dust" | "motionBlur";
    const passes: Pass[] = [];
    if (shaftOn) passes.push("shaft");
    if (dustOn) passes.push("dust");
    if (motionBlurOn) passes.push("motionBlur");

    if (passes.length === 0) return;

    let currentSource = sourceTexture;
    for (let i = 0; i < passes.length; i++) {
      const isLast = i === passes.length - 1;
      const passTarget = isLast ? target : this.rtPostComposite1!;

      switch (passes[i]) {
        case "shaft":
          this.renderLightShafts(renderer, currentSource, passTarget);
          break;
        case "dust":
          this.renderDust(renderer, currentSource, passTarget);
          break;
        case "motionBlur":
          this.renderMotionBlur(renderer, currentSource, passTarget);
          break;
      }

      if (!isLast) {
        currentSource = this.rtPostComposite1!.texture;
      }
    }
  }

  /**
   * A/B ルック比較のオンオフと両スロットのパラメータ（setParams と同形のレコード）。
   * オフ時は render が従来どおりアクティブ側のみ（setParams で渡した値）を使う。
   */
  setComparePair(
    enabled: boolean,
    paramsA: Record<string, number | string> | null,
    paramsB: Record<string, number | string> | null,
  ): void {
    this.abCompareEnabled = enabled;
    if (paramsA) this.compareParamsA = { ...paramsA };
    if (paramsB) this.compareParamsB = { ...paramsB };
  }

  render(
    renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    camera: THREE.Camera,
  ): void {
    if (!this.hasRenderableResolution()) return;

    this.ensureRenderTargets();
    if (!this.rtColorGraded) return;

    this.renderer = renderer;

    if (this.abCompareEnabled) {
      this.renderComparePair(renderer, scene, camera);
      return;
    }

    const mu = this.material.uniforms;
    this.renderBasePipeline(renderer, scene, camera);
    this.renderFinalFrame(
      renderer,
      null,
      mu.uTexture!.value as THREE.Texture,
      mu.uSplitPosition!.value as number,
      0.0,
    );
  }

  /**
   * スロット A を全パスで RT に書き、続けてスロット B を画面に分割合成する。
   */
  private renderComparePair(
    renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    camera: THREE.Camera,
  ): void {
    const mu = this.material.uniforms;
    const originalTexture = mu.uTexture!.value as THREE.Texture;

    // —— スロット A: 分割なしでフルフレームを比較用 RT に ——
    this.setParams(this.compareParamsA);
    this.renderBasePipeline(renderer, scene, camera);
    this.renderFinalFrame(
      renderer,
      this.rtCompareComposite,
      originalTexture,
      -1.0,
      0.0,
    );

    // —— スロット B: 左=A の合成結果、右=B ——
    this.setParams(this.compareParamsB);
    this.renderBasePipeline(renderer, scene, camera);
    this.renderFinalFrame(
      renderer,
      null,
      this.rtCompareComposite!.texture,
      mu.uSplitPosition!.value as number,
      1.0,
    );
  }

  /**
   * Compute per-mip-level weights for the upsample accumulation.
   * radius=0 → tight bloom (only first mips). radius=1 → diffuse wide haze.
   */
  private static computeMipWeights(radius: number, levels: number): number[] {
    const weights: number[] = [];
    for (let i = 0; i < levels; i++) {
      const t = i / Math.max(levels - 1, 1);
      const base = Math.exp(-3.0 * (1.0 - radius) * t);
      const wide = Math.exp(-0.5 * radius * (1.0 - t));
      weights.push(base * (1 - radius) + wide * radius);
    }
    return weights;
  }

  private renderBloom(renderer: THREE.WebGLRenderer): void {
    const mips = this.rtBloomMips;

    // Step 1: Prefilter into mip[0]
    const bu = this.bloomPrefilterMaterial.uniforms;
    bu.uSource!.value = this.rtColorGraded!.texture;
    bu.uThreshold!.value = this.bloomThreshold;
    bu.uKnee!.value = this.bloomSoftKnee;
    this.postMesh.material = this.bloomPrefilterMaterial;
    renderer.setRenderTarget(mips[0]!);
    renderer.render(this.postScene, this.postCamera);

    // Step 2: Progressive downsample
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1]!;
      const dst = mips[i]!;
      const du = this.downsampleMaterial.uniforms;
      du.uSource!.value = src.texture;
      du.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
      this.postMesh.material = this.downsampleMaterial;
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }

    // Step 3: Progressive upsample with additive blending
    // Disable autoClear so the existing downsample data in each mip is preserved.
    // The upsample material uses AdditiveBlending to accumulate on top of it.
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    const weights = Viewport.computeMipWeights(this.bloomRadius, mips.length);
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1]!;
      const highRes = mips[i]!;
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource!.value = lowRes.texture;
      uu.uTexelSize!.value.set(1.0 / lowRes.width, 1.0 / lowRes.height);
      uu.uWeight!.value = weights[i + 1]!;
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
  }

  private renderHalation(renderer: THREE.WebGLRenderer): void {
    const mips = this.rtHalationMips;

    // Step 1: Prefilter + tint into mip[0]
    const hu = this.halationPrefilterMaterial.uniforms;
    hu.uSource!.value = this.rtColorGraded!.texture;
    hu.uHalationColor!.value.copy(this.halationColor);
    hu.uThreshold!.value = this.halationThreshold;
    hu.uKnee!.value = this.halationSoftKnee;
    this.postMesh.material = this.halationPrefilterMaterial;
    renderer.setRenderTarget(mips[0]!);
    renderer.render(this.postScene, this.postCamera);

    // Step 2: Progressive downsample
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1]!;
      const dst = mips[i]!;
      const du = this.downsampleMaterial.uniforms;
      du.uSource!.value = src.texture;
      du.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
      this.postMesh.material = this.downsampleMaterial;
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }

    // Step 3: Progressive upsample with additive blending
    const prevAutoClear2 = renderer.autoClear;
    renderer.autoClear = false;
    const weights = Viewport.computeMipWeights(this.halationRadius, mips.length);
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1]!;
      const highRes = mips[i]!;
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource!.value = lowRes.texture;
      uu.uTexelSize!.value.set(1.0 / lowRes.width, 1.0 / lowRes.height);
      uu.uWeight!.value = weights[i + 1]!;
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear2;
  }

  /**
   * Diffusion (Pro-Mist): Full-image mip pyramid blur (no threshold prefilter).
   * Reuses downsample/upsample materials shared with bloom/halation.
   */
  private renderDiffusion(renderer: THREE.WebGLRenderer): void {
    this.ensureDiffusionResources();
    const mips = this.rtDiffusionMips;
    if (mips.length === 0) return;

    // Step 1: First downsample from rtColorGraded (NO prefilter — full image)
    const du = this.downsampleMaterial.uniforms;
    du.uSource!.value = this.rtColorGraded!.texture;
    du.uTexelSize!.value.set(
      1.0 / this.rtColorGraded!.width,
      1.0 / this.rtColorGraded!.height,
    );
    this.postMesh.material = this.downsampleMaterial;
    renderer.setRenderTarget(mips[0]!);
    renderer.render(this.postScene, this.postCamera);

    // Step 2: Progressive downsample
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1]!;
      const dst = mips[i]!;
      du.uSource!.value = src.texture;
      du.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
      renderer.setRenderTarget(dst);
      renderer.render(this.postScene, this.postCamera);
    }

    // Step 3: Progressive upsample with additive blending
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    const weights = Viewport.computeMipWeights(0.7, mips.length); // wide fixed radius
    for (let i = mips.length - 2; i >= 0; i--) {
      const lowRes = mips[i + 1]!;
      const highRes = mips[i]!;
      const uu = this.upsampleMaterial.uniforms;
      uu.uSource!.value = lowRes.texture;
      uu.uTexelSize!.value.set(1.0 / lowRes.width, 1.0 / lowRes.height);
      uu.uWeight!.value = weights[i + 1]!;
      this.postMesh.material = this.upsampleMaterial;
      renderer.setRenderTarget(highRes);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
  }

  // ===== Texture =====

  setTexture(texture: THREE.Texture): void {
    this.material.uniforms.uTexture!.value = texture;
  }

  // ===== Resolution =====

  setResolution(width: number, height: number): void {
    this.width = width;
    this.height = height;
    this.material.uniforms.uResolution!.value.set(width, height);
    this.compositeMaterial.uniforms.uResolution!.value.set(width, height);
    this.resizeRenderTargets(width, height);
    if (this.rtMotionBlur0) this.rtMotionBlur0.setSize(width, height);
    if (this.rtMotionBlur1) this.rtMotionBlur1.setSize(width, height);
    if (this.dustMaterial) {
      this.dustMaterial.uniforms.uResolution!.value.set(width, height);
    }
    if (this.rtShaft) {
      const qw = Math.max(1, Math.floor(width / 4));
      const qh = Math.max(1, Math.floor(height / 4));
      this.rtShaft.setSize(qw, qh);
    }
    this.resetMotionBlurHistory();
  }

  setImageResolution(width: number, height: number): void {
    this.material.uniforms.uImageResolution!.value.set(width, height);
  }

  // ===== Time =====

  setTime(time: number): void {
    this.material.uniforms.uTime!.value = time;
  }

  // ===== Color Grading Setters =====

  setExposure(value: number): void {
    this.material.uniforms.uExposure!.value = value;
  }

  setContrast(value: number): void {
    this.material.uniforms.uContrast!.value = value;
  }

  setSaturation(value: number): void {
    this.material.uniforms.uSaturation!.value = value;
  }

  setTemperature(value: number): void {
    this.material.uniforms.uTemperature!.value = value;
  }

  /**
   * グリーン／マゼンタ軸の色かぶり（シェーダー `uTint`）。
   * @param value -1〜1 程度（プリセットと `types.Params.tint` に対応）
   */
  setTint(value: number): void {
    this.material.uniforms.uTint!.value = value;
  }

  setFade(value: number): void {
    this.material.uniforms.uFade!.value = value;
  }

  setHighlights(value: number): void {
    this.material.uniforms.uHighlights!.value = value;
  }

  setShadows(value: number): void {
    this.material.uniforms.uShadows!.value = value;
  }

  // ===== Effects Setters =====

  setRGBShift(value: number): void {
    this.material.uniforms.uRGBShift!.value = value;
  }

  setGrainIntensity(value: number): void {
    this.material.uniforms.uGrainIntensity!.value = value;
  }

  /**
   * @description Params.grainRadialMix を合成シェーダへ。0〜1 に丸める。
   */
  setGrainRadialMix(value: number): void {
    const v = Math.min(1, Math.max(0, value));
    this.grainRadialMix = v;
    this.compositeMaterial.uniforms.uGrainRadialMix!.value = v;
  }

  setGrainSize(value: number): void {
    const v = Math.min(1, Math.max(0, value));
    this.compositeMaterial.uniforms.uGrainSize!.value = v;
  }

  /**
   * @description Params.lensSoftness を合成シェーダへ。0〜1 に丸める。
   */
  setLensSoftness(value: number): void {
    const v = Math.min(1, Math.max(0, value));
    this.lensSoftness = v;
    this.compositeMaterial.uniforms.uLensSoftness!.value = v;
  }

  setVignette(value: number): void {
    this.material.uniforms.uVignette!.value = value;
  }

  // ===== Bloom Setters =====

  setBloomThreshold(value: number): void {
    this.bloomThreshold = value;
  }

  setBloomStrength(value: number): void {
    this.bloomStrength = value;
  }

  setBloomRadius(value: number): void {
    this.bloomRadius = value;
  }

  // ===== Diffusion Setter =====

  setDiffusion(value: number): void {
    this.diffusion = Math.min(1, Math.max(0, value));
  }

  // ===== Halation Setters =====

  setHalationIntensity(value: number): void {
    this.halationIntensity = value;
  }

  setHalationSpread(value: number): void {
    this.halationSpread = value;
  }

  setHalationColor(hex: string): void {
    this.halationColor = hexToVec3(hex);
  }

  setHalationThreshold(value: number): void {
    this.halationThreshold = value;
  }

  setHalationRadius(value: number): void {
    this.halationRadius = value;
  }

  setBloomSoftKnee(value: number): void {
    this.bloomSoftKnee = value;
  }

  setHalationSoftKnee(value: number): void {
    this.halationSoftKnee = value;
  }

  // ===== Motion Blur =====

  setMotionBlurAmount(value: number): void {
    const prev = this.motionBlurAmount;
    this.motionBlurAmount = Math.min(1, Math.max(0, value));
    // Reset history on 0 -> >0 transition to avoid stale accumulation
    if (prev === 0 && this.motionBlurAmount > 0) {
      this.resetMotionBlurHistory();
    }
  }

  setFrameRepeat(value: number): void {
    this.frameRepeat = Math.min(8, Math.max(1, Math.round(value)));
  }

  resetMotionBlurHistory(): void {
    this.hasMotionBlurHistory = false;
    this.motionBlurFrame = 0;
  }

  // ===== Dust & Scratches =====

  setDustAmount(value: number): void {
    this.dustAmount = Math.min(1, Math.max(0, value));
  }

  setScratchAmount(value: number): void {
    this.scratchAmount = Math.min(1, Math.max(0, value));
  }

  // ===== Light Shafts =====

  setShaftIntensity(value: number): void {
    this.shaftIntensity = Math.min(1, Math.max(0, value));
  }

  setShaftDecay(value: number): void {
    this.shaftDecay = Math.min(1, Math.max(0, value));
  }

  setShaftOriginX(value: number): void {
    this.shaftOriginX = Math.min(1, Math.max(0, value));
  }

  setShaftOriginY(value: number): void {
    this.shaftOriginY = Math.min(1, Math.max(0, value));
  }

  // ===== LUT =====

  /** Retained for sync (e.g. edit→batch transfer). Not used for rendering. */
  private lut1RawData: Float32Array | null = null;
  private lut1RawSize = 0;
  private lut2RawData: Float32Array | null = null;
  private lut2RawSize = 0;

  private createLUT3DTexture(data: Float32Array, size: number): THREE.Data3DTexture {
    const texture = new THREE.Data3DTexture(data, size, size, size);
    texture.format = THREE.RGBAFormat;
    texture.type = THREE.FloatType;
    texture.minFilter = THREE.LinearFilter;
    texture.magFilter = THREE.LinearFilter;
    texture.wrapS = THREE.ClampToEdgeWrapping;
    texture.wrapT = THREE.ClampToEdgeWrapping;
    texture.wrapR = THREE.ClampToEdgeWrapping;
    texture.needsUpdate = true;
    return texture;
  }

  // --- LUT1: Input Transform (before color grading — Log→Rec709) ---

  setLUT1(data: Float32Array, size: number): void {
    const prev = this.material.uniforms.uLUT1?.value as THREE.Data3DTexture | null;
    if (prev) prev.dispose();
    this.material.uniforms.uLUT1!.value = this.createLUT3DTexture(data, size);
    this.material.uniforms.uLUT1Enabled!.value = 1.0;
    this.lut1RawData = data;
    this.lut1RawSize = size;
  }

  clearLUT1(): void {
    const tex = this.material.uniforms.uLUT1?.value as THREE.Data3DTexture | null;
    if (tex) tex.dispose();
    this.material.uniforms.uLUT1!.value = null;
    this.material.uniforms.uLUT1Enabled!.value = 0.0;
    this.lut1RawData = null;
    this.lut1RawSize = 0;
  }

  setLUT1Intensity(value: number): void {
    this.material.uniforms.uLUT1Intensity!.value = value;
  }

  // --- LUT2: Creative (after color grading — film look) ---

  setLUT2(data: Float32Array, size: number): void {
    const prev = this.material.uniforms.uLUT2?.value as THREE.Data3DTexture | null;
    if (prev) prev.dispose();
    this.material.uniforms.uLUT2!.value = this.createLUT3DTexture(data, size);
    this.material.uniforms.uLUT2Enabled!.value = 1.0;
    this.lut2RawData = data;
    this.lut2RawSize = size;
  }

  clearLUT2(): void {
    const tex = this.material.uniforms.uLUT2?.value as THREE.Data3DTexture | null;
    if (tex) tex.dispose();
    this.material.uniforms.uLUT2!.value = null;
    this.material.uniforms.uLUT2Enabled!.value = 0.0;
    this.lut2RawData = null;
    this.lut2RawSize = 0;
  }

  setLUT2Intensity(value: number): void {
    this.material.uniforms.uLUT2Intensity!.value = value;
  }

  // --- Backward-compatible aliases (delegate to LUT2 / Creative) ---

  /** @deprecated Use setLUT2() */
  setLUT(data: Float32Array, size: number): void {
    this.setLUT2(data, size);
  }

  /** @deprecated Use clearLUT2() */
  clearLUT(): void {
    this.clearLUT2();
  }

  /** @deprecated Use setLUT2Intensity() */
  setLUTIntensity(value: number): void {
    this.setLUT2Intensity(value);
  }

  // --- LUT data getters (for edit→batch sync) ---

  getLUT1Snapshot(): { data: Float32Array; size: number; intensity: number } | null {
    if (!this.lut1RawData) return null;
    return {
      data: this.lut1RawData,
      size: this.lut1RawSize,
      intensity: this.material.uniforms.uLUT1Intensity!.value as number,
    };
  }

  getLUT2Snapshot(): { data: Float32Array; size: number; intensity: number } | null {
    if (!this.lut2RawData) return null;
    return {
      data: this.lut2RawData,
      size: this.lut2RawSize,
      intensity: this.material.uniforms.uLUT2Intensity!.value as number,
    };
  }

  // ===== Export Y-flip =====

  /**
   * @description エクスポート時の Y 反転。composite パスのみ反転し、中間 RT は通常方向を維持。
   * readPixels 後の CPU flip を不要にする。
   */
  setExportFlipY(flip: boolean): void {
    // Only flip the final composite pass — intermediate RTs must stay normal
    // so bloom/halation UV sampling works correctly
    this.compositeMaterial.uniforms.uFlipY!.value = flip ? 1.0 : 0.0;
  }

  // ===== Before/After =====

  setSplitPosition(value: number): void {
    this.material.uniforms.uSplitPosition!.value = value;
  }

  /**
   * @description 合成パスが参照する分割位置（FilmLabCanvas の保存後復帰など）
   */
  getSplitPosition(): number {
    return this.material.uniforms.uSplitPosition!.value as number;
  }

  // ===== Bulk Params (for presets) =====

  getParams(): Record<string, number | string> {
    return {
      exposure: this.material.uniforms.uExposure!.value as number,
      contrast: this.material.uniforms.uContrast!.value as number,
      saturation: this.material.uniforms.uSaturation!.value as number,
      temperature: this.material.uniforms.uTemperature!.value as number,
      tint: this.material.uniforms.uTint!.value as number,
      shadowHue: this.splitShadowHueDeg,
      highlightHue: this.splitHighlightHueDeg,
      shadowTone: (() => {
        const u = this.material.uniforms.uShadowTint!.value as THREE.Vector3;
        const [ux, uy, uz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
        return (u.x * ux + u.y * uy + u.z * uz) / LEGACY_SHADOW_TONE_MAGNITUDE;
      })(),
      highlightTone: (() => {
        const u = this.material.uniforms.uHighlightTint!.value as THREE.Vector3;
        const [ux, uy, uz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
        return (u.x * ux + u.y * uy + u.z * uz) / LEGACY_HIGHLIGHT_TONE_MAGNITUDE;
      })(),
      rgbShift: this.material.uniforms.uRGBShift!.value as number,
      grainIntensity: this.material.uniforms.uGrainIntensity!.value as number,
      grainRadialMix: this.grainRadialMix,
      lensSoftness: this.lensSoftness,
      vignette: this.material.uniforms.uVignette!.value as number,
      fade: this.material.uniforms.uFade!.value as number,
      highlights: this.material.uniforms.uHighlights!.value as number,
      shadows: this.material.uniforms.uShadows!.value as number,
      bloomThreshold: this.bloomThreshold,
      bloomStrength: this.bloomStrength,
      bloomRadius: this.bloomRadius,
      diffusion: this.diffusion,
      halationIntensity: this.halationIntensity,
      halationSpread: this.halationSpread,
      halationThreshold: this.halationThreshold,
      halationRadius: this.halationRadius,
      bloomSoftKnee: this.bloomSoftKnee,
      halationSoftKnee: this.halationSoftKnee,
      halationColor: `#${new THREE.Color(this.halationColor.x, this.halationColor.y, this.halationColor.z).getHexString()}`,
      compressionAmount: this.material.uniforms.uCompressionAmount!.value as number,
      compressionRange: this.material.uniforms.uCompressionRange!.value as number,
      cyan: this.material.uniforms.uCyan!.value as number,
      magenta: this.material.uniforms.uMagenta!.value as number,
      yellow: this.material.uniforms.uYellow!.value as number,
      printContrast: this.material.uniforms.uPrintContrast!.value as number,
      motionBlurAmount: this.motionBlurAmount,
      dustAmount: this.dustAmount,
      scratchAmount: this.scratchAmount,
      shaftIntensity: this.shaftIntensity,
      shaftDecay: this.shaftDecay,
      shaftOriginX: this.shaftOriginX,
      shaftOriginY: this.shaftOriginY,
    };
  }

  setParams(params: Record<string, number | string>): void {
    if (params.exposure !== undefined)
      this.setExposure(params.exposure as number);
    if (params.contrast !== undefined)
      this.setContrast(params.contrast as number);
    if (params.saturation !== undefined)
      this.setSaturation(params.saturation as number);
    if (params.temperature !== undefined)
      this.setTemperature(params.temperature as number);
    if (params.tint !== undefined) this.setTint(params.tint as number);
    if (params.shadowHue !== undefined || params.shadowTone !== undefined) {
      let tone: number;
      if (params.shadowTone !== undefined) {
        tone = params.shadowTone as number;
        if (params.shadowHue !== undefined) {
          this.splitShadowHueDeg = params.shadowHue as number;
        }
      } else {
        const u = this.material.uniforms.uShadowTint!.value as THREE.Vector3;
        const [ox, oy, oz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
        tone =
          (u.x * ox + u.y * oy + u.z * oz) / LEGACY_SHADOW_TONE_MAGNITUDE;
        this.splitShadowHueDeg = params.shadowHue as number;
      }
      const [cx, cy, cz] = chromaUnitFromHueDegrees(this.splitShadowHueDeg);
      (this.material.uniforms.uShadowTint!.value as THREE.Vector3)
        .set(cx, cy, cz)
        .multiplyScalar(tone * LEGACY_SHADOW_TONE_MAGNITUDE);
    }

    if (params.highlightHue !== undefined || params.highlightTone !== undefined) {
      let tone: number;
      if (params.highlightTone !== undefined) {
        tone = params.highlightTone as number;
        if (params.highlightHue !== undefined) {
          this.splitHighlightHueDeg = params.highlightHue as number;
        }
      } else {
        const u = this.material.uniforms.uHighlightTint!.value as THREE.Vector3;
        const [ox, oy, oz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
        tone =
          (u.x * ox + u.y * oy + u.z * oz) / LEGACY_HIGHLIGHT_TONE_MAGNITUDE;
        this.splitHighlightHueDeg = params.highlightHue as number;
      }
      const [cx, cy, cz] = chromaUnitFromHueDegrees(this.splitHighlightHueDeg);
      (this.material.uniforms.uHighlightTint!.value as THREE.Vector3)
        .set(cx, cy, cz)
        .multiplyScalar(tone * LEGACY_HIGHLIGHT_TONE_MAGNITUDE);
    }
    if (params.rgbShift !== undefined)
      this.setRGBShift(params.rgbShift as number);
    if (params.grainIntensity !== undefined)
      this.setGrainIntensity(params.grainIntensity as number);
    if (params.grainRadialMix !== undefined)
      this.setGrainRadialMix(params.grainRadialMix as number);
    if (params.grainSize !== undefined)
      this.setGrainSize(params.grainSize as number);
    if (params.lensSoftness !== undefined)
      this.setLensSoftness(params.lensSoftness as number);
    if (params.vignette !== undefined)
      this.setVignette(params.vignette as number);
    if (params.fade !== undefined) this.setFade(params.fade as number);
    if (params.highlights !== undefined) this.setHighlights(params.highlights as number);
    if (params.shadows !== undefined) this.setShadows(params.shadows as number);
    if (params.bloomThreshold !== undefined)
      this.setBloomThreshold(params.bloomThreshold as number);
    if (params.bloomStrength !== undefined)
      this.setBloomStrength(params.bloomStrength as number);
    if (params.bloomRadius !== undefined)
      this.setBloomRadius(params.bloomRadius as number);
    if (params.diffusion !== undefined)
      this.setDiffusion(params.diffusion as number);
    if (params.halationIntensity !== undefined)
      this.setHalationIntensity(params.halationIntensity as number);
    if (params.halationSpread !== undefined)
      this.setHalationSpread(params.halationSpread as number);
    if (params.halationColor !== undefined)
      this.setHalationColor(params.halationColor as string);
    if (params.halationThreshold !== undefined)
      this.setHalationThreshold(params.halationThreshold as number);
    if (params.halationRadius !== undefined)
      this.setHalationRadius(params.halationRadius as number);
    else if (params.halationSpread !== undefined)
      this.setHalationRadius(Math.min(1, Math.max(0, (params.halationSpread as number) / 50.0)));
    if (params.bloomSoftKnee !== undefined)
      this.setBloomSoftKnee(params.bloomSoftKnee as number);
    if (params.halationSoftKnee !== undefined)
      this.setHalationSoftKnee(params.halationSoftKnee as number);
    if (params.compressionAmount !== undefined)
      this.material.uniforms.uCompressionAmount!.value = params.compressionAmount as number;
    if (params.compressionRange !== undefined)
      this.material.uniforms.uCompressionRange!.value = params.compressionRange as number;
    if (params.cyan !== undefined)
      this.material.uniforms.uCyan!.value = params.cyan as number;
    if (params.magenta !== undefined)
      this.material.uniforms.uMagenta!.value = params.magenta as number;
    if (params.yellow !== undefined)
      this.material.uniforms.uYellow!.value = params.yellow as number;
    if (params.printContrast !== undefined)
      this.material.uniforms.uPrintContrast!.value = params.printContrast as number;
    if (params.motionBlurAmount !== undefined)
      this.setMotionBlurAmount(params.motionBlurAmount as number);
    if (params.dustAmount !== undefined)
      this.setDustAmount(params.dustAmount as number);
    if (params.scratchAmount !== undefined)
      this.setScratchAmount(params.scratchAmount as number);
    if (params.shaftIntensity !== undefined)
      this.setShaftIntensity(params.shaftIntensity as number);
    if (params.shaftDecay !== undefined)
      this.setShaftDecay(params.shaftDecay as number);
    if (params.shaftOriginX !== undefined)
      this.setShaftOriginX(params.shaftOriginX as number);
    if (params.shaftOriginY !== undefined)
      this.setShaftOriginY(params.shaftOriginY as number);
  }

  // ===== Histogram readback =====

  /** カラーグレード済みRTからピクセルデータを取得（ヒストグラム用） */
  getHistogramPixels(): { pixels: Float32Array; width: number; height: number } | null {
    if (!this.rtColorGraded || !this.renderer) return null;
    const rt = this.rtColorGraded;
    const w = rt.width;
    const h = rt.height;
    if (w <= 0 || h <= 0) return null;
    const size = w * h * 4;
    if (!this.histogramHalfBuffer || this.histogramHalfBuffer.length !== size) {
      this.histogramHalfBuffer = new Uint16Array(size);
    }
    if (!this.histogramBuffer || this.histogramBuffer.length !== size) {
      this.histogramBuffer = new Float32Array(size);
    }
    // RGBA16F（HalfFloatType）に対し gl.RGBA + gl.FLOAT は環境によって無効（Electron / Metal で空振りしがち）。
    // WebGLRenderer.readRenderTargetPixels が型に合う readPixels を選び、Uint16 を FP32 に戻す。
    this.renderer.readRenderTargetPixels(rt, 0, 0, w, h, this.histogramHalfBuffer);
    const half = this.histogramHalfBuffer;
    const out = this.histogramBuffer;
    for (let i = 0; i < size; i++) {
      out[i] = THREE.DataUtils.fromHalfFloat(half[i]!);
    }
    return { pixels: out, width: w, height: h };
  }

  // ===== Dispose =====

  dispose(): void {
    this.geometry.dispose();
    this.material.dispose();
    this.postGeometry.dispose();
    this.bloomPrefilterMaterial.dispose();
    this.halationPrefilterMaterial.dispose();
    this.downsampleMaterial.dispose();
    this.upsampleMaterial.dispose();
    this.compositeMaterial.dispose();
    this.rtColorGraded?.dispose();
    for (const rt of this.rtBloomMips) rt.dispose();
    for (const rt of this.rtHalationMips) rt.dispose();
    for (const rt of this.rtDiffusionMips) rt.dispose();
    this.rtDiffusionMips = [];
    this.rtCompareComposite?.dispose();
    this.rtPostComposite0?.dispose();
    this.rtPostComposite1?.dispose();
    this.motionBlurMaterial?.dispose();
    this.rtMotionBlur0?.dispose();
    this.rtMotionBlur1?.dispose();
    this.dustMaterial?.dispose();
    this.dustTexture?.dispose();
    this.scratchTexture?.dispose();
    this.shaftMaterial?.dispose();
    this.shaftBlendMaterial?.dispose();
    this.rtShaft?.dispose();
    const lut1Texture = this.material.uniforms.uLUT1?.value as THREE.Data3DTexture | null;
    if (lut1Texture) lut1Texture.dispose();
    const lut2Texture = this.material.uniforms.uLUT2?.value as THREE.Data3DTexture | null;
    if (lut2Texture) lut2Texture.dispose();
    const mediaTexture = this.material.uniforms.uTexture?.value as THREE.Texture | null;
    if (mediaTexture) mediaTexture.dispose();
    this.histogramBuffer = null;
    this.histogramHalfBuffer = null;
    this.renderer = null;
  }
}
