/**
 * WebGLBackend — Fullscreen quad with Film Lab color grading + Bloom/Halation multi-pass
 *
 * Architecture:
 *   Pass 1: Color grade (filmlab.frag) → RenderTarget A
 *   Pass 2-4: Bloom threshold → blur H → blur V (1/2 res)
 *   Pass 5-7: Halation threshold+tint → blur H → blur V (1/4 res)
 *   Pass 8: Composite (A + bloom + halation + vignette + grain + split) → screen
 *   Pass 9:  (reserved: #100 light shafts)
 *   Pass 10: #99 Dust & Scratches overlay (screen + additive blend)
 *   Pass 11: #97 Slow Shutter / N-frame ring buffer motion blur
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
import { motionblurFragmentShader, feedbackCopyFragmentShader } from "./shaders/motionblur.frag";
import { dustFragmentShader } from "./shaders/dust.frag";
import { createDustTexture, createScratchTexture } from "./textures/index";
import { lightshaftsFragmentShader } from "./shaders/lightshafts.frag";
import { lightshaftsBlendFragmentShader } from "./shaders/lightshafts-blend.frag";
import { crossFilterStreakFragmentShader } from "./shaders/cross-filter-streak.frag";
import { crossFilterBlendFragmentShader } from "./shaders/cross-filter-blend.frag";
import { crossFilterPeakFragmentShader } from "./shaders/cross-filter-peak.frag";
import { crossFilterPeakSpacingFragmentShader } from "./shaders/cross-filter-peak-spacing.frag";
import { crossFilterPeakSpacingMaxFragmentShader } from "./shaders/cross-filter-peak-spacing-max.frag";
import { crossFilterTemporalFragmentShader } from "./shaders/cross-filter-temporal.frag";
import type { RenderBackend, RenderBackendParams } from "../webgpu/Backend";

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

const CROSS_FILTER_SPACING_RADIUS_MAX_PX = 48.0;
const CROSS_FILTER_SPACING_RADIUS_STEP_PX = 24.0;
const CROSS_FILTER_THRESHOLD_HARD_BASELINE = 0.7;
const CROSS_FILTER_THRESHOLD_CONTROL_BASELINE = 0.92;
const CROSS_FILTER_MIN_SPACING_MIN = 1;
const CROSS_FILTER_MIN_SPACING_MAX = 10;

function computeCrossFilterEffectiveThreshold(threshold: number, hardModeActive: boolean): number {
  if (!hardModeActive) {
    return threshold;
  }
  return Math.min(
    1,
    Math.max(
      0,
      threshold -
        (CROSS_FILTER_THRESHOLD_CONTROL_BASELINE - CROSS_FILTER_THRESHOLD_HARD_BASELINE),
    ),
  );
}

function computeCrossFilterSpacingRadiusPx(minSpacing: number): number {
  const clamped = Math.min(
    CROSS_FILTER_MIN_SPACING_MAX,
    Math.max(CROSS_FILTER_MIN_SPACING_MIN, minSpacing),
  );
  let extraRadius = 0;
  for (
    let stepStart = CROSS_FILTER_MIN_SPACING_MIN;
    stepStart < CROSS_FILTER_MIN_SPACING_MAX;
    stepStart += 1
  ) {
    extraRadius +=
      CROSS_FILTER_SPACING_RADIUS_STEP_PX *
      THREE.MathUtils.smoothstep(clamped - stepStart, 0.0, 1.0);
  }
  return Math.round(CROSS_FILTER_SPACING_RADIUS_MAX_PX + extraRadius);
}

export type CrossFilterDebugView =
  | "off"
  | "threshold"
  | "peak"
  | "peakSpaced"
  | "peakHeld"
  | "streak0"
  | "streak1"
  | "streak2"
  | "streak3";

export interface CrossFilterDebugStageStats {
  width: number;
  height: number;
  totalPixels: number;
  activePixels: number;
  activeFraction: number;
  sumLuma: number;
  maxLuma: number;
}

export interface CrossFilterDebugMetrics {
  spacing: number;
  hardMode: boolean;
  temporalHoldActive: boolean;
  threshold: CrossFilterDebugStageStats | null;
  peak: CrossFilterDebugStageStats | null;
  peakSpaced: CrossFilterDebugStageStats | null;
  peakHeld: CrossFilterDebugStageStats | null;
  streaks: Array<CrossFilterDebugStageStats | null>;
}

const crossFilterDebugFragmentShader = /* glsl */ `
precision highp float;

uniform sampler2D uSource;
uniform float uGain;
uniform float uFalseColor;

in vec2 vUv;
out vec4 fragColor;

float luma709(vec3 c) {
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 heat(float t) {
  return clamp(
    vec3(
      smoothstep(0.00, 0.30, t),
      smoothstep(0.18, 0.72, t),
      smoothstep(0.55, 1.00, t)
    ),
    0.0,
    1.0
  );
}

void main() {
  vec3 src = texture(uSource, vUv).rgb;
  float lum = luma709(src);
  float boosted = clamp(lum * uGain, 0.0, 1.0);
  vec3 display = mix(clamp(src * uGain, 0.0, 1.0), heat(boosted), step(0.5, uFalseColor));
  fragColor = vec4(display, 1.0);
}
`;

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

export class WebGLBackend implements RenderBackend {
  mesh: THREE.Mesh;
  private material: THREE.ShaderMaterial;
  private geometry: THREE.PlaneGeometry;
  private boundRenderer: THREE.WebGLRenderer | null = null;
  private boundScene: THREE.Scene | null = null;
  private boundCamera: THREE.Camera | null = null;

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

  // --- Motion Blur: N-frame Ring Buffer (Post-composite #97) ---
  private static readonly MOTION_BLUR_RING_SIZE = 8;
  private shutterAngle = 0.0;
  private frameRepeat = 1; // renderer-internal, not in PARAM_KEYS
  private ringWriteIndex = 0;
  private ringFilledFrames = 0;
  private weightCurve: 'triangle' | 'box' | 'exponential' = 'triangle';
  private motionThreshold = 0.0;
  private trailIntensity = 0.0; // 0=no feedback, 0-0.95=longer trails
  private ringCopyMaterial: THREE.ShaderMaterial | null = null;
  private ringBlendMaterial: THREE.ShaderMaterial | null = null;
  private rtRingBuffer: THREE.WebGLRenderTarget[] = [];

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

  // --- Cross Filter (Post-composite) ---
  private crossFilterStrength = 0;
  private crossFilterSpikes = 4;
  private crossFilterAngle = 0;
  private crossFilterLength = 0.5;
  private crossFilterThreshold = 0.8;
  private crossFilterChromatic = 0.3;
  private crossFilterSizeLimit = 0;
  private crossFilterRandomness = 1;
  /** Phase 6: Hard Mode toggle (0=Soft, 1=Hard). Render-time uniform overrides for stylized look. */
  private crossFilterHardMode = 0;
  /** Peak-level spacing control — prefers separated highlight sources before streak generation. */
  private crossFilterMinSpacing = 1;
  private crossFilterStreakMaterial: THREE.ShaderMaterial | null = null;
  private crossFilterBlendMaterial: THREE.ShaderMaterial | null = null;
  private rtCrossThreshold: THREE.WebGLRenderTarget | null = null;
  private rtCrossPeak: THREE.WebGLRenderTarget | null = null;
  private rtCrossPeakSpacingWork: THREE.WebGLRenderTarget | null = null;
  private rtCrossPeakSpacingMax: THREE.WebGLRenderTarget | null = null;
  private rtCrossPeakSpaced: THREE.WebGLRenderTarget | null = null;
  private rtCrossStreak: THREE.WebGLRenderTarget[] = [];
  private crossFilterPeakMaterial: THREE.ShaderMaterial | null = null;
  private crossFilterPeakSpacingMaxMaterial: THREE.ShaderMaterial | null = null;
  private crossFilterPeakSpacingMaterial: THREE.ShaderMaterial | null = null;
  private crossFilterTemporalMaterial: THREE.ShaderMaterial | null = null;
  private crossFilterDebugMaterial: THREE.ShaderMaterial | null = null;
  private rtCrossPeakHistory: THREE.WebGLRenderTarget[] = [];
  private crossFilterPeakHistoryWriteIndex = 0;
  private crossFilterPeakHistoryFilledFrames = 0;
  private crossFilterDebugView: CrossFilterDebugView = "off";
  private lastCrossPeakSpacedTarget: THREE.WebGLRenderTarget | null = null;
  private lastCrossPeakHeldTarget: THREE.WebGLRenderTarget | null = null;
  private lastCrossTemporalHoldActive = false;
  private lastCrossStreakCount = 0;
  /** Phase 6: Hard Mode central bloom mip chain (lazy alloc, only when Hard Mode first becomes active). */
  private rtCentralBloomMips: THREE.WebGLRenderTarget[] = [];
  private compareRenderActive = false;

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
        uFitMode: { value: 0.0 },
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
        uFitMode: { value: 0.0 },
        uSplitOnly: { value: 0.0 },
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
    for (let i = 0; i < WebGLBackend.BLOOM_MIP_LEVELS; i++) {
      const mw = Math.max(1, Math.floor(w / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(h / Math.pow(2, i + 1)));
      this.rtBloomMips.push(new THREE.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }

    // Halation mip chain (6 levels: W/2 .. W/64)
    this.rtHalationMips = [];
    for (let i = 0; i < WebGLBackend.HALATION_MIP_LEVELS; i++) {
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
    for (let i = 0; i < WebGLBackend.DIFFUSION_MIP_LEVELS; i++) {
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
   * Motion blur 用の ShaderMaterial と N-frame ring buffer RT を遅延生成する。
   * shutterAngle > 0 になるまで GPU リソースを消費しない。
   */
  private ensureMotionBlurResources(): void {
    if (this.ringCopyMaterial) return;

    // Feedback copy: sourceTexture + previous slot → ring slot
    this.ringCopyMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: feedbackCopyFragmentShader,
      uniforms: {
        uSource: { value: null },
        uPrevSlot: { value: null },
        uTrail: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    // N-frame weighted blend
    this.ringBlendMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: motionblurFragmentShader,
      uniforms: {
        uFrame0: { value: null },
        uFrame1: { value: null },
        uFrame2: { value: null },
        uFrame3: { value: null },
        uFrame4: { value: null },
        uFrame5: { value: null },
        uFrame6: { value: null },
        uFrame7: { value: null },
        uWeight0: { value: 1.0 },
        uWeight1: { value: 0.0 },
        uWeight2: { value: 0.0 },
        uWeight3: { value: 0.0 },
        uWeight4: { value: 0.0 },
        uWeight5: { value: 0.0 },
        uWeight6: { value: 0.0 },
        uWeight7: { value: 0.0 },
        uActiveFrames: { value: 1 },
        uMotionThreshold: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    // 8 ring buffer RenderTargets
    this.rtRingBuffer = [];
    for (let i = 0; i < WebGLBackend.MOTION_BLUR_RING_SIZE; i++) {
      this.rtRingBuffer.push(
        new THREE.WebGLRenderTarget(this.width, this.height, RT_OPTIONS),
      );
    }
  }

  /**
   * shutterAngle から有効フレーム数を算出する。
   * 0 のときは motion blur 無効を示す 0 を返す。
   */
  private getActiveFrameCount(): number {
    if (this.shutterAngle <= 0) return 0;
    // 720° → normalized=2.0 → all 8 frames active
    const normalized = Math.min(this.shutterAngle, 720) / 360;
    return Math.max(1, Math.min(WebGLBackend.MOTION_BLUR_RING_SIZE, Math.round(normalized * (WebGLBackend.MOTION_BLUR_RING_SIZE / 2))));
  }

  /**
   * weightCurve に応じた正規化済みブレンドウェイトを計算する。
   * index 0 = newest, index N-1 = oldest。
   * shutterAngle > 360° では triangle → box へ自動的にフラット化し、
   * より長いモーショントレイルを実現する。
   */
  private computeBlendWeights(activeFrames: number): Float32Array {
    const N = WebGLBackend.MOTION_BLUR_RING_SIZE;
    const weights = new Float32Array(N);
    const effective = Math.min(activeFrames, this.ringFilledFrames);
    if (effective <= 0 || effective === 1) { weights[0] = 1.0; return weights; }

    // 360° 超では triangle → box へ滑らかに遷移
    // flatness: 0.0 (pure triangle at ≤360°) → 1.0 (pure box at 720°)
    const flatness = Math.min(1, Math.max(0, (this.shutterAngle - 360) / 360));

    let sum = 0;
    for (let i = 0; i < effective; i++) {
      const triangleW = effective - i;
      const boxW = 1.0;
      switch (this.weightCurve) {
        case 'triangle': weights[i] = triangleW * (1 - flatness) + boxW * flatness; break;
        case 'box': weights[i] = 1.0; break;
        case 'exponential': weights[i] = Math.exp(-1.5 * i) * (1 - flatness) + boxW * flatness; break;
      }
      sum += weights[i]!;
    }
    if (sum > 0) for (let i = 0; i < effective; i++) weights[i]! /= sum;
    return weights;
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

  private ensureCrossFilterResources(): void {
    if (this.crossFilterStreakMaterial) return;

    this.crossFilterStreakMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterStreakFragmentShader,
      uniforms: {
        uSource: { value: null },
        uDirection: { value: new THREE.Vector2(1, 0) },
        uTexelSize: { value: new THREE.Vector2() },
        uLength: { value: 0.5 },
        uChromatic: { value: 0.0 },
        uBrightnessMul: { value: 1.0 },
        uRandomness: { value: 1 },
        // Phase 6: Hard Mode toggle. uHardMode=0 → Phase 5 byte-for-byte identical.
        // No length multiplier — Hard Mode uses the same maxSteps range as Soft Mode
        // to avoid UV wrap artifacts on smaller images.
        uHardMode: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    this.crossFilterBlendMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterBlendFragmentShader,
      uniforms: {
        uSource: { value: null },
        uStreak0: { value: null },
        uStreak1: { value: null },
        uStreak2: { value: null },
        uStreak3: { value: null },
        // Phase 6: Hard Mode central bloom texture (default black → no contribution when Soft).
        uCentralBloom: { value: getBlackTexture() },
        uStreakCount: { value: 2 },
        uIntensity: { value: 0.0 },
        uHardMode: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    this.crossFilterPeakSpacingMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakSpacingFragmentShader,
      uniforms: {
        uSource: { value: null },
        uLocalMax: { value: null },
        uTexelSize: { value: new THREE.Vector2() },
        uMinSpacing: { value: 0 },
        uFlipY: { value: 0.0 },
      },
    });

    this.crossFilterPeakSpacingMaxMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakSpacingMaxFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE.Vector2() },
        uAxis: { value: new THREE.Vector2(1, 0) },
        uRadiusPx: { value: 0 },
        uReadMetadata: { value: 0.0 },
        uFlipY: { value: 0.0 },
      },
    });

    const hw = Math.max(1, Math.floor(this.width / 2));
    const hh = Math.max(1, Math.floor(this.height / 2));
    this.rtCrossThreshold = new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeak = new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpacingWork = new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpacingMax = new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossPeakSpaced = new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS);
    this.rtCrossStreak = [];
    for (let i = 0; i < 4; i++) {
      this.rtCrossStreak.push(new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS));
    }

    this.crossFilterPeakMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterPeakFragmentShader,
      uniforms: {
        uSource: { value: null },
        uTexelSize: { value: new THREE.Vector2() },
        uSizeLimit: { value: 0 },
        uFlipY: { value: 0.0 },
      },
    });

    this.crossFilterTemporalMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterTemporalFragmentShader,
      uniforms: {
        uSource: { value: null },
        uPrev: { value: getBlackTexture() },
        uDecay: { value: 0.82 },
        uFlipY: { value: 0.0 },
      },
    });

    this.crossFilterDebugMaterial = new THREE.ShaderMaterial({
      glslVersion: THREE.GLSL3,
      vertexShader: filmlabVertexShader,
      fragmentShader: crossFilterDebugFragmentShader,
      uniforms: {
        uSource: { value: getBlackTexture() },
        uGain: { value: 1.0 },
        uFalseColor: { value: 1.0 },
      },
    });

    for (let i = 0; i < 2; i++) {
      this.rtCrossPeakHistory.push(new THREE.WebGLRenderTarget(hw, hh, RT_OPTIONS));
    }
  }

  /**
   * Phase 6: Hard Mode central bloom mip chain (lazy alloc, 4 levels at 1/4..1/32 of source).
   * Allocated only when Hard Mode first becomes active to keep VRAM cost off Soft-only sessions.
   */
  private ensureCentralBloomResources(): void {
    if (this.rtCentralBloomMips.length > 0) return;
    if (this.width <= 0 || this.height <= 0) return;
    const hw = Math.max(1, Math.floor(this.width / 2));
    const hh = Math.max(1, Math.floor(this.height / 2));
    for (let i = 0; i < 4; i++) {
      const mw = Math.max(1, Math.floor(hw / Math.pow(2, i + 1)));
      const mh = Math.max(1, Math.floor(hh / Math.pow(2, i + 1)));
      this.rtCentralBloomMips.push(new THREE.WebGLRenderTarget(mw, mh, RT_OPTIONS));
    }
  }

  /**
   * Phase 6: Renders the central halo around peak light sources for Hard Mode.
   * Reuses bloom downsample/upsample materials on the rtCrossPeak texture (the
   * point-source-only output from the cross filter peak detection pass).
   *
   * Pattern mirrors renderBloom():
   *   1. Seed mip 0 by downsampling rtCrossPeak.
   *   2. Downsample chain (mip 1 → 3).
   *   3. Upsample chain back to mip 0 with autoClear=false (additive blend) — CRITICAL.
   */
  private renderCentralBloom(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    sourceWidth: number,
    sourceHeight: number,
  ): void {
    const mips = this.rtCentralBloomMips;
    if (mips.length === 0) return;

    // Step 1: Seed mip 0 from the current peak mask via the downsample shader.
    const ds = this.downsampleMaterial.uniforms;
    ds.uSource!.value = sourceTexture;
    ds.uTexelSize!.value.set(1.0 / sourceWidth, 1.0 / sourceHeight);
    this.postMesh.material = this.downsampleMaterial;
    renderer.setRenderTarget(mips[0]!);
    renderer.render(this.postScene, this.postCamera);

    // Step 2: Downsample chain (mip 1 → mip last).
    for (let i = 1; i < mips.length; i++) {
      const src = mips[i - 1]!;
      ds.uSource!.value = src.texture;
      ds.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
      renderer.setRenderTarget(mips[i]!);
      renderer.render(this.postScene, this.postCamera);
    }

    // Step 3: Upsample chain (mip last → mip 0) with additive blend.
    // CRITICAL: autoClear must be false so the previous downsample data persists in the destination mip
    // and the upsample shader's THREE.AdditiveBlending accumulates on top.
    const us = this.upsampleMaterial.uniforms;
    const weights = WebGLBackend.computeMipWeights(0.5, mips.length);
    this.postMesh.material = this.upsampleMaterial;
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;
    for (let i = mips.length - 2; i >= 0; i--) {
      const src = mips[i + 1]!;
      us.uSource!.value = src.texture;
      us.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
      us.uWeight!.value = weights[i + 1]!;
      renderer.setRenderTarget(mips[i]!);
      renderer.render(this.postScene, this.postCamera);
    }
    renderer.autoClear = prevAutoClear;
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
    cu.uFitMode!.value = mu.uFitMode!.value;
  }

  /**
   * post-composite chain が必要かどうか。A/B 比較中は R9 対策として Slot A はブラーをスキップ。
   * Slot B（abCompareEnabled=false）のみブラーを適用。
   */
  private hasPostCompositeChain(): boolean {
    if (this.abCompareEnabled) return false;
    return this.shutterAngle > 0 || this.crossFilterStrength > 0;
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
    // Phase 6: Hard Mode のクロスフィルターは中心 bloom を持つため、global diffusion を抑制する。
    // user の diffusion 値はフィールドに保持されたまま (round-trip safe)、render path のみ skip。
    const hardModeActive = this.crossFilterStrength > 0 && this.crossFilterHardMode >= 0.5;
    const diffusionOn = this.diffusion > 0 && !hardModeActive;

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
    // Phase 6: Hard Mode は global diffusion を抑制。フィールド値は不変、composite uniform のみ 0 化。
    const hardModeActive = this.crossFilterStrength > 0 && this.crossFilterHardMode >= 0.5;
    const diffusionOn = this.diffusion > 0 && !hardModeActive;
    cu.uSource!.value = this.rtColorGraded!.texture;
    cu.uBloomTexture!.value = bloomOn ? this.rtBloomMips[0]!.texture : black;
    cu.uHalationTexture!.value = halationOn ? this.rtHalationMips[0]!.texture : black;
    cu.uDiffusionTexture!.value = diffusionOn && this.rtDiffusionMips.length > 0
      ? this.rtDiffusionMips[0]!.texture
      : black;
    cu.uDiffusion!.value = diffusionOn ? this.diffusion : 0;
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

    // Before/After スプリット + post-chain: スプリットをブラー後に移動して
    // 左=原画(ブラーなし)、右=グレーディング+ブラー済み を実現する。
    if (splitPosition > 0 && abCompare < 0.5) {
      // 1. Composite WITHOUT split → rtPostComposite0
      this.renderCompositeFrame(renderer, this.rtPostComposite0, -1.0, 0.0, originalTexture);
      // 2. PostChain (motionBlur etc.) → rtCompareComposite
      this.renderPostCompositeChain(renderer, this.rtPostComposite0.texture, this.rtCompareComposite!);
      // 3. Split-only pass: left=original, right=blurred graded → target
      this.renderSplitOnlyComposite(renderer, target, originalTexture, this.rtCompareComposite!.texture, splitPosition);
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
   * Split-only パス。グレーディングをスキップし、左=原画 / 右=ブラー済み出力 のスプリットのみ。
   * Before/After モード + post-composite chain 有効時に使用。
   */
  private renderSplitOnlyComposite(
    renderer: THREE.WebGLRenderer,
    target: THREE.WebGLRenderTarget | null,
    originalTexture: THREE.Texture,
    blurredTexture: THREE.Texture,
    splitPosition: number,
  ): void {
    const cu = this.compositeMaterial.uniforms;
    cu.uSplitOnly!.value = 1.0;
    cu.uSource!.value = blurredTexture;
    cu.uOriginalTexture!.value = originalTexture;
    cu.uSplitPosition!.value = splitPosition;
    this.syncCompositeUniformsFromMaterial();
    this.postMesh.material = this.compositeMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
    cu.uSplitOnly!.value = 0.0;
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
   * N-frame ring buffer motion blur.
   * Draw 1: Copy sourceTexture → rtRingBuffer[ringWriteIndex]
   * Draw 2: Weighted blend of ring slots (newest first) → target
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
    if (!this.ringCopyMaterial || !this.ringBlendMaterial || this.rtRingBuffer.length === 0) return;

    const N = WebGLBackend.MOTION_BLUR_RING_SIZE;
    const prevAutoClear = renderer.autoClear;
    renderer.autoClear = false;

    // Draw 1: Feedback copy — mix(source, prevSlot, trail) → ring slot
    const cu = this.ringCopyMaterial.uniforms;
    cu.uSource!.value = sourceTexture;
    // Previous slot for feedback: the most recently written slot
    const prevSlotIdx = (this.ringWriteIndex - 1 + N) % N;
    cu.uPrevSlot!.value = this.ringFilledFrames > 0
      ? this.rtRingBuffer[prevSlotIdx]!.texture
      : getBlackTexture();
    cu.uTrail!.value = this.ringFilledFrames > 0 ? this.trailIntensity : 0.0;
    this.postMesh.material = this.ringCopyMaterial;
    renderer.setRenderTarget(this.rtRingBuffer[this.ringWriteIndex]!);
    renderer.render(this.postScene, this.postCamera);

    // Advance write head
    this.ringWriteIndex = (this.ringWriteIndex + 1) % N;
    this.ringFilledFrames = Math.min(this.ringFilledFrames + 1, N);

    // Draw 2: Weighted blend → target
    const activeFrames = this.getActiveFrameCount();
    const weights = this.computeBlendWeights(activeFrames);

    const bu = this.ringBlendMaterial.uniforms;
    const black = getBlackTexture();

    // Bind ring slots in temporal order: newest first (index 0 = newest)
    for (let i = 0; i < N; i++) {
      // ringWriteIndex was just advanced, so newest = ringWriteIndex - 1
      const slotIndex = (this.ringWriteIndex - 1 - i + N * 2) % N;
      const filled = i < this.ringFilledFrames;
      bu[`uFrame${i}` as keyof typeof bu]!.value = filled
        ? this.rtRingBuffer[slotIndex]!.texture
        : black;
      bu[`uWeight${i}` as keyof typeof bu]!.value = weights[i]!;
    }
    bu.uActiveFrames!.value = Math.min(activeFrames, this.ringFilledFrames);
    bu.uMotionThreshold!.value = this.motionThreshold;

    this.postMesh.material = this.ringBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);

    renderer.autoClear = prevAutoClear;
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

  private resolveCrossFilterDebugSource(
    view: CrossFilterDebugView,
    currentPeakTarget: THREE.WebGLRenderTarget,
    peakTarget: THREE.WebGLRenderTarget,
  ): { texture: THREE.Texture; gain: number; falseColor: boolean } | null {
    switch (view) {
      case "threshold":
        return this.rtCrossThreshold
          ? { texture: this.rtCrossThreshold.texture, gain: 8.0, falseColor: true }
          : null;
      case "peak":
        return this.rtCrossPeak
          ? { texture: this.rtCrossPeak.texture, gain: 16.0, falseColor: true }
          : null;
      case "peakSpaced":
        return { texture: currentPeakTarget.texture, gain: 16.0, falseColor: true };
      case "peakHeld":
        return { texture: peakTarget.texture, gain: 16.0, falseColor: true };
      case "streak0":
      case "streak1":
      case "streak2":
      case "streak3": {
        const index = Number(view.slice(-1));
        const rt = this.rtCrossStreak[index];
        return rt ? { texture: rt.texture, gain: 3.0, falseColor: false } : null;
      }
      default:
        return null;
    }
  }

  private renderCrossFilterDebug(
    renderer: THREE.WebGLRenderer,
    target: THREE.WebGLRenderTarget | null,
    currentPeakTarget: THREE.WebGLRenderTarget,
    peakTarget: THREE.WebGLRenderTarget,
  ): boolean {
    if (!this.crossFilterDebugMaterial || this.crossFilterDebugView === "off") {
      return false;
    }

    const debugSource = this.resolveCrossFilterDebugSource(
      this.crossFilterDebugView,
      currentPeakTarget,
      peakTarget,
    );
    if (!debugSource) {
      return false;
    }

    const du = this.crossFilterDebugMaterial.uniforms;
    du.uSource!.value = debugSource.texture;
    du.uGain!.value = debugSource.gain;
    du.uFalseColor!.value = debugSource.falseColor ? 1.0 : 0.0;
    this.postMesh.material = this.crossFilterDebugMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
    return true;
  }

  private renderCrossFilter(
    renderer: THREE.WebGLRenderer,
    sourceTexture: THREE.Texture,
    target: THREE.WebGLRenderTarget | null,
  ): void {
    this.ensureCrossFilterResources();
    if (!this.crossFilterStreakMaterial || !this.crossFilterPeakSpacingMaterial || !this.crossFilterPeakSpacingMaxMaterial || !this.crossFilterBlendMaterial
        || !this.crossFilterPeakMaterial || !this.crossFilterTemporalMaterial
        || !this.rtCrossThreshold || !this.rtCrossPeak || !this.rtCrossPeakSpacingWork || !this.rtCrossPeakSpacingMax || !this.rtCrossPeakSpaced
        || this.rtCrossPeakHistory.length < 2 || this.rtCrossStreak.length === 0) return;

    const dirCount = Math.floor(this.crossFilterSpikes / 2);
    const angleRad = (this.crossFilterAngle * Math.PI) / 180;

    // Phase 6: Effective values pattern.
    // Hard Mode still snaps size/randomness, but threshold now follows the
    // user control through a legacy-compatible remap so the old 0.92 stored
    // baseline preserves the prior 0.70 onset behavior.
    // CRITICAL: Never mutate this.crossFilter* fields → user values stay round-trip safe.
    // NOTE: Length is NOT boosted in Hard Mode — the streak shader uses the same MAX_STREAK_PX (64)
    // as Phase 5 to prevent UV wrap artifacts on smaller images. Hard Mode's distinguishing
    // character comes from gain/falloff/threshold/bloom changes instead of longer marches.
    const isHard = this.crossFilterHardMode >= 0.5;
    const effectiveThreshold  = computeCrossFilterEffectiveThreshold(
      this.crossFilterThreshold,
      isHard,
    );
    const effectiveSizeLimit  = isHard ? 1.0  : this.crossFilterSizeLimit;
    const effectiveRandomness = isHard ? 1.0  : this.crossFilterRandomness;
    const hardModeUniform     = isHard ? 1.0  : 0.0;

    // Sub-pass 1: Threshold extraction (reuse bloom prefilter shader)
    const pu = this.bloomPrefilterMaterial.uniforms;
    const savedThreshold = pu.uThreshold!.value;
    const savedKnee = pu.uKnee!.value;
    pu.uSource!.value = sourceTexture;
    pu.uThreshold!.value = effectiveThreshold;
    pu.uKnee!.value = 0.1;
    this.postMesh.material = this.bloomPrefilterMaterial;
    renderer.setRenderTarget(this.rtCrossThreshold);
    renderer.render(this.postScene, this.postCamera);
    pu.uThreshold!.value = savedThreshold;
    pu.uKnee!.value = savedKnee;

    // Sub-pass 1.5: Peak detection (suppress uniform bright areas, preserve point sources)
    const pk = this.crossFilterPeakMaterial!.uniforms;
    pk.uSource!.value = this.rtCrossThreshold.texture;
    pk.uTexelSize!.value.set(1.0 / this.rtCrossThreshold.width, 1.0 / this.rtCrossThreshold.height);
    pk.uSizeLimit!.value = effectiveSizeLimit;
    this.postMesh.material = this.crossFilterPeakMaterial!;
    renderer.setRenderTarget(this.rtCrossPeak!);
    renderer.render(this.postScene, this.postCamera);

    let currentPeakTarget = this.rtCrossPeak!;
    if (this.crossFilterMinSpacing >= 0.001) {
      const radiusPx = computeCrossFilterSpacingRadiusPx(this.crossFilterMinSpacing);

      const smu = this.crossFilterPeakSpacingMaxMaterial.uniforms;
      smu.uSource!.value = this.rtCrossPeak.texture;
      smu.uTexelSize!.value.set(1.0 / this.rtCrossPeak.width, 1.0 / this.rtCrossPeak.height);
      smu.uAxis!.value.set(1, 0);
      smu.uRadiusPx!.value = radiusPx;
      smu.uReadMetadata!.value = 0.0;
      this.postMesh.material = this.crossFilterPeakSpacingMaxMaterial;
      renderer.setRenderTarget(this.rtCrossPeakSpacingWork);
      renderer.render(this.postScene, this.postCamera);

      smu.uSource!.value = this.rtCrossPeakSpacingWork.texture;
      smu.uAxis!.value.set(0, 1);
      smu.uReadMetadata!.value = 1.0;
      this.postMesh.material = this.crossFilterPeakSpacingMaxMaterial;
      renderer.setRenderTarget(this.rtCrossPeakSpacingMax);
      renderer.render(this.postScene, this.postCamera);

      const spu = this.crossFilterPeakSpacingMaterial.uniforms;
      spu.uSource!.value = this.rtCrossPeak.texture;
      spu.uLocalMax!.value = this.rtCrossPeakSpacingMax.texture;
      spu.uTexelSize!.value.set(1.0 / this.rtCrossPeak.width, 1.0 / this.rtCrossPeak.height);
      spu.uMinSpacing!.value = this.crossFilterMinSpacing;
      this.postMesh.material = this.crossFilterPeakSpacingMaterial;
      currentPeakTarget = this.rtCrossPeakSpaced!;
      renderer.setRenderTarget(currentPeakTarget);
      renderer.render(this.postScene, this.postCamera);
    }

    const temporalHoldActive = isHard && !this.compareRenderActive;
    let peakTarget = currentPeakTarget;
    if (temporalHoldActive) {
      const writeIndex = this.crossFilterPeakHistoryWriteIndex;
      const prevIndex = (writeIndex + this.rtCrossPeakHistory.length - 1) % this.rtCrossPeakHistory.length;
      const tu = this.crossFilterTemporalMaterial.uniforms;
      tu.uSource!.value = currentPeakTarget.texture;
      tu.uPrev!.value = this.crossFilterPeakHistoryFilledFrames > 0
        ? this.rtCrossPeakHistory[prevIndex]!.texture
        : getBlackTexture();
      this.postMesh.material = this.crossFilterTemporalMaterial;
      peakTarget = this.rtCrossPeakHistory[writeIndex]!;
      renderer.setRenderTarget(peakTarget);
      renderer.render(this.postScene, this.postCamera);
      this.crossFilterPeakHistoryWriteIndex = (writeIndex + 1) % this.rtCrossPeakHistory.length;
      this.crossFilterPeakHistoryFilledFrames = Math.min(
        this.crossFilterPeakHistoryFilledFrames + 1,
        this.rtCrossPeakHistory.length,
      );
    }
    this.lastCrossPeakSpacedTarget = currentPeakTarget;
    this.lastCrossPeakHeldTarget = peakTarget;
    this.lastCrossTemporalHoldActive = temporalHoldActive;

    // Phase 6 NEW: Sub-pass 1.75 — Hard Mode central bloom (skipped entirely in Soft Mode).
    if (isHard) {
      this.ensureCentralBloomResources();
      this.renderCentralBloom(renderer, peakTarget.texture, peakTarget.width, peakTarget.height);
    }

    // Sub-pass 2..N: Directional blur per spike direction
    const su = this.crossFilterStreakMaterial.uniforms;
    const qw = peakTarget.width;
    const qh = peakTarget.height;
    su.uSource!.value = peakTarget.texture;
    su.uTexelSize!.value.set(1.0 / qw, 1.0 / qh);
    su.uChromatic!.value = this.crossFilterChromatic;
    su.uRandomness!.value = effectiveRandomness;
    su.uHardMode!.value = hardModeUniform;

    // Deterministic hash for per-direction organic variation
    const hash = (n: number): number => {
      const s = Math.sin(n * 127.1 + 311.7) * 43758.5453;
      return s - Math.floor(s);
    };

    for (let i = 0; i < dirCount; i++) {
      const seed = i * 17 + 7;
      const angleJitter = (hash(seed) - 0.5) * 2 * (5 * Math.PI / 180);
      const lengthMul = 1.0 + (hash(seed + 1) - 0.5) * 0.5;
      const brightMul = 1.0 + (hash(seed + 2) - 0.5) * 0.4;

      const dirAngle = angleRad + (i * Math.PI) / dirCount + angleJitter;
      su.uDirection!.value.set(Math.cos(dirAngle), Math.sin(dirAngle));
      su.uLength!.value = this.crossFilterLength * lengthMul;
      su.uBrightnessMul!.value = brightMul;
      this.postMesh.material = this.crossFilterStreakMaterial;
      renderer.setRenderTarget(this.rtCrossStreak[i]!);
      renderer.render(this.postScene, this.postCamera);
    }
    this.lastCrossStreakCount = dirCount;
    su.uLength!.value = this.crossFilterLength;

    if (this.renderCrossFilterDebug(renderer, target, currentPeakTarget, peakTarget)) {
      return;
    }

    // Final sub-pass: Screen blend
    const black = getBlackTexture();
    const bu = this.crossFilterBlendMaterial.uniforms;
    bu.uSource!.value = sourceTexture;
    bu.uStreak0!.value = dirCount >= 1 ? this.rtCrossStreak[0]!.texture : black;
    bu.uStreak1!.value = dirCount >= 2 ? this.rtCrossStreak[1]!.texture : black;
    bu.uStreak2!.value = dirCount >= 3 ? this.rtCrossStreak[2]!.texture : black;
    bu.uStreak3!.value = dirCount >= 4 ? this.rtCrossStreak[3]!.texture : black;
    // Phase 6: bind central bloom mip 0 (full half-res result), or black in Soft Mode → bloom term = 0 in shader.
    bu.uCentralBloom!.value = isHard && this.rtCentralBloomMips[0]
      ? this.rtCentralBloomMips[0].texture
      : black;
    bu.uStreakCount!.value = dirCount;
    bu.uIntensity!.value = this.crossFilterStrength;
    bu.uHardMode!.value = hardModeUniform;
    this.postMesh.material = this.crossFilterBlendMaterial;
    renderer.setRenderTarget(target);
    renderer.render(this.postScene, this.postCamera);
  }

  /**
   * Pass 9+ の受け皿。
   * Pass order: CrossFilter -> Shafts(9) -> Dust(10) -> MotionBlur(11)
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
    const crossFilterOn = this.crossFilterStrength > 0;
    const shaftOn = this.shaftIntensity > 0;
    const dustOn = this.dustAmount > 0 || this.scratchAmount > 0;
    const motionBlurOn = this.shutterAngle > 0;

    type Pass = "crossFilter" | "shaft" | "dust" | "motionBlur";
    const passes: Pass[] = [];
    if (crossFilterOn) passes.push("crossFilter");
    if (shaftOn) passes.push("shaft");
    if (dustOn) passes.push("dust");
    if (motionBlurOn) passes.push("motionBlur");

    if (passes.length === 0) return;

    let currentSource = sourceTexture;
    for (let i = 0; i < passes.length; i++) {
      const isLast = i === passes.length - 1;
      const passTarget = isLast ? target : this.rtPostComposite1!;

      switch (passes[i]) {
        case "crossFilter":
          this.renderCrossFilter(renderer, currentSource, passTarget);
          if (this.crossFilterDebugView !== "off") return;
          break;
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
    const wasEnabled = this.abCompareEnabled;
    this.abCompareEnabled = enabled;
    if (paramsA) this.compareParamsA = { ...paramsA };
    if (paramsB) this.compareParamsB = { ...paramsB };
    if (enabled && !wasEnabled) {
      this.resetMotionBlurHistory();
    }
    if (enabled !== wasEnabled) {
      this.resetCrossFilterHistory();
    }
  }

  /**
   * T2-0c: `RenderBackend.render()` is zero-arg. WebGL still needs the
   * Three.js renderer/scene/camera; callers that migrated to the backend
   * interface must first `bindThree(renderer, scene, camera)` once (typically
   * during setup), after which subsequent `render()` calls use the stored
   * bindings. Legacy 3-arg callers continue to pass them per-frame.
   */
  bindThree(
    renderer: THREE.WebGLRenderer,
    scene: THREE.Scene,
    camera: THREE.Camera,
  ): void {
    this.boundRenderer = renderer;
    this.boundScene = scene;
    this.boundCamera = camera;
  }

  render(
    renderer?: THREE.WebGLRenderer,
    scene?: THREE.Scene,
    camera?: THREE.Camera,
  ): void {
    const r = renderer ?? this.boundRenderer;
    const s = scene ?? this.boundScene;
    const c = camera ?? this.boundCamera;
    if (!r || !s || !c) return;

    if (!this.hasRenderableResolution()) return;

    this.ensureRenderTargets();
    if (!this.rtColorGraded) return;

    this.renderer = r;

    if (this.abCompareEnabled) {
      this.renderComparePair(r, s, c);
      return;
    }

    const mu = this.material.uniforms;
    this.renderBasePipeline(r, s, c);
    this.renderFinalFrame(
      r,
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
    this.compareRenderActive = true;
    try {
      const mu = this.material.uniforms;
      const originalTexture = mu.uTexture!.value as THREE.Texture;

      // —— Slot A: abCompareEnabled=true → R9 ガード → ブラーなし ——
      this.setParams(this.compareParamsA);
      this.renderBasePipeline(renderer, scene, camera);
      this.renderFinalFrame(renderer, this.rtCompareComposite, originalTexture, -1.0, 0.0);

      // —— Slot B: 一時的に abCompareEnabled=false でブラーを有効化 ——
      const savedShutterAngle = this.shutterAngle;
      const savedCrossFilterStrength = this.crossFilterStrength;
      const savedCrossFilterHardMode = this.crossFilterHardMode;
      this.setParams(this.compareParamsB);
      this.renderBasePipeline(renderer, scene, camera);

      const savedAbCompareEnabled = this.abCompareEnabled;
      this.abCompareEnabled = false;
      this.renderFinalFrame(
        renderer,
        null,
        this.rtCompareComposite!.texture,
        mu.uSplitPosition!.value as number,
        1.0,
      );
      this.abCompareEnabled = savedAbCompareEnabled;
      this.shutterAngle = savedShutterAngle;
      this.crossFilterStrength = savedCrossFilterStrength;
      this.crossFilterHardMode = savedCrossFilterHardMode;
    } finally {
      this.compareRenderActive = false;
    }
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
    const weights = WebGLBackend.computeMipWeights(this.bloomRadius, mips.length);
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
    const weights = WebGLBackend.computeMipWeights(this.halationRadius, mips.length);
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
    const weights = WebGLBackend.computeMipWeights(0.7, mips.length); // wide fixed radius
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
    for (const rt of this.rtRingBuffer) rt.setSize(width, height);
    if (this.dustMaterial) {
      this.dustMaterial.uniforms.uResolution!.value.set(width, height);
    }
    if (this.rtShaft) {
      const qw = Math.max(1, Math.floor(width / 4));
      const qh = Math.max(1, Math.floor(height / 4));
      this.rtShaft.setSize(qw, qh);
    }
    if (this.rtCrossThreshold) {
      const hw = Math.max(1, Math.floor(width / 2));
      const hh = Math.max(1, Math.floor(height / 2));
      this.rtCrossThreshold.setSize(hw, hh);
      this.rtCrossPeak?.setSize(hw, hh);
      this.rtCrossPeakSpacingWork?.setSize(hw, hh);
      this.rtCrossPeakSpacingMax?.setSize(hw, hh);
      this.rtCrossPeakSpaced?.setSize(hw, hh);
      for (const rt of this.rtCrossPeakHistory) rt.setSize(hw, hh);
      for (const rt of this.rtCrossStreak) rt.setSize(hw, hh);
    }
    // Phase 6: Hard Mode central bloom mip chain (if allocated).
    if (this.rtCentralBloomMips.length > 0) {
      const hw2 = Math.max(1, Math.floor(width / 2));
      const hh2 = Math.max(1, Math.floor(height / 2));
      for (let i = 0; i < this.rtCentralBloomMips.length; i++) {
        const mw = Math.max(1, Math.floor(hw2 / Math.pow(2, i + 1)));
        const mh = Math.max(1, Math.floor(hh2 / Math.pow(2, i + 1)));
        this.rtCentralBloomMips[i]!.setSize(mw, mh);
      }
    }
    this.resetMotionBlurHistory();
    this.resetCrossFilterHistory();
  }

  setImageResolution(width: number, height: number): void {
    this.material.uniforms.uImageResolution!.value.set(width, height);
  }

  setFitMode(mode: "cover" | "contain"): void {
    const value = mode === "contain" ? 1.0 : 0.0;
    this.material.uniforms.uFitMode!.value = value;
    this.compositeMaterial.uniforms.uFitMode!.value = value;
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

  setShutterAngle(degrees: number): void {
    const prev = this.shutterAngle;
    this.shutterAngle = Math.min(720, Math.max(0, degrees));
    if (prev === 0 && this.shutterAngle > 0) this.resetMotionBlurHistory();
  }

  setMotionBlurAmount(value: number): void {
    this.setShutterAngle(Math.min(1, Math.max(0, value)) * 360);
  }

  setTrailIntensity(value: number): void {
    this.trailIntensity = Math.min(0.95, Math.max(0, value));
  }

  setFrameRepeat(value: number): void {
    this.frameRepeat = Math.min(8, Math.max(1, Math.round(value)));
  }

  resetMotionBlurHistory(): void {
    this.ringWriteIndex = 0;
    this.ringFilledFrames = 0;
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

  // ===== Cross Filter =====

  setCrossFilterStrength(v: number): void {
    this.crossFilterStrength = Math.min(1, Math.max(0, v));
    if (this.crossFilterStrength === 0) this.resetCrossFilterHistory();
  }
  setCrossFilterSpikes(v: number): void {
    const c = Math.min(8, Math.max(4, Math.round(v)));
    this.crossFilterSpikes = c % 2 === 0 ? c : c + 1;
  }
  setCrossFilterAngle(v: number): void { this.crossFilterAngle = ((v % 360) + 360) % 360; }
  setCrossFilterLength(v: number): void { this.crossFilterLength = Math.min(1, Math.max(0, v)); }
  setCrossFilterThreshold(v: number): void { this.crossFilterThreshold = Math.min(1, Math.max(0, v)); }
  setCrossFilterChromatic(v: number): void { this.crossFilterChromatic = Math.min(1, Math.max(0, v)); }
  setCrossFilterSizeLimit(v: number): void { this.crossFilterSizeLimit = Math.min(1, Math.max(0, v)); }
  setCrossFilterRandomness(v: number): void { this.crossFilterRandomness = Math.min(1, Math.max(0, v)); }
  setCrossFilterHardMode(v: number): void {
    const next = v >= 0.5 ? 1 : 0;
    if (next !== this.crossFilterHardMode) this.resetCrossFilterHistory();
    this.crossFilterHardMode = next;
  }
  setCrossFilterMinSpacing(v: number): void {
    const next = Math.min(CROSS_FILTER_MIN_SPACING_MAX, Math.max(CROSS_FILTER_MIN_SPACING_MIN, v));
    if (Math.abs(next - this.crossFilterMinSpacing) >= 1e-4) {
      this.resetCrossFilterHistory();
    }
    this.crossFilterMinSpacing = next;
  }

  private resetCrossFilterHistory(): void {
    this.crossFilterPeakHistoryWriteIndex = 0;
    this.crossFilterPeakHistoryFilledFrames = 0;
  }

  setCrossFilterDebugView(view: CrossFilterDebugView | null): void {
    this.crossFilterDebugView = view ?? "off";
  }

  getCrossFilterDebugView(): CrossFilterDebugView {
    return this.crossFilterDebugView;
  }

  private getRenderTargetLumaStats(
    rt: THREE.WebGLRenderTarget | null,
  ): CrossFilterDebugStageStats | null {
    if (!rt || !this.renderer) return null;
    const w = rt.width;
    const h = rt.height;
    if (w <= 0 || h <= 0) return null;

    const size = w * h * 4;
    if (!this.histogramHalfBuffer || this.histogramHalfBuffer.length !== size) {
      this.histogramHalfBuffer = new Uint16Array(size);
    }

    this.renderer.readRenderTargetPixels(rt, 0, 0, w, h, this.histogramHalfBuffer);

    let activePixels = 0;
    let sumLuma = 0;
    let maxLuma = 0;
    const ACTIVE_THRESHOLD = 0.001;
    for (let i = 0; i < size; i += 4) {
      const r = THREE.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i]!);
      const g = THREE.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i + 1]!);
      const b = THREE.DataUtils.fromHalfFloat(this.histogramHalfBuffer[i + 2]!);
      const luma = r * 0.2126 + g * 0.7152 + b * 0.0722;
      sumLuma += luma;
      if (luma > maxLuma) maxLuma = luma;
      if (luma > ACTIVE_THRESHOLD) activePixels += 1;
    }

    const totalPixels = w * h;
    return {
      width: w,
      height: h,
      totalPixels,
      activePixels,
      activeFraction: totalPixels > 0 ? activePixels / totalPixels : 0,
      sumLuma,
      maxLuma,
    };
  }

  getCrossFilterDebugMetrics(): CrossFilterDebugMetrics | null {
    if (!this.rtCrossThreshold || !this.rtCrossPeak) return null;

    const streaks: Array<CrossFilterDebugStageStats | null> = [];
    for (let i = 0; i < this.lastCrossStreakCount; i++) {
      streaks.push(this.getRenderTargetLumaStats(this.rtCrossStreak[i] ?? null));
    }

    return {
      spacing: this.crossFilterMinSpacing,
      hardMode: this.crossFilterHardMode >= 0.5,
      temporalHoldActive: this.lastCrossTemporalHoldActive,
      threshold: this.getRenderTargetLumaStats(this.rtCrossThreshold),
      peak: this.getRenderTargetLumaStats(this.rtCrossPeak),
      peakSpaced: this.getRenderTargetLumaStats(this.lastCrossPeakSpacedTarget),
      peakHeld: this.getRenderTargetLumaStats(this.lastCrossPeakHeldTarget),
      streaks,
    };
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
      shutterAngle: this.shutterAngle,
      trailIntensity: this.trailIntensity,
      motionBlurAmount: this.shutterAngle / 360,
      dustAmount: this.dustAmount,
      scratchAmount: this.scratchAmount,
      shaftIntensity: this.shaftIntensity,
      shaftDecay: this.shaftDecay,
      shaftOriginX: this.shaftOriginX,
      shaftOriginY: this.shaftOriginY,
      crossFilterStrength: this.crossFilterStrength,
      crossFilterSpikes: this.crossFilterSpikes,
      crossFilterAngle: this.crossFilterAngle,
      crossFilterLength: this.crossFilterLength,
      crossFilterThreshold: this.crossFilterThreshold,
      crossFilterChromatic: this.crossFilterChromatic,
      crossFilterSizeLimit: this.crossFilterSizeLimit,
      crossFilterRandomness: this.crossFilterRandomness,
      crossFilterHardMode: this.crossFilterHardMode,
      crossFilterMinSpacing: this.crossFilterMinSpacing,
    };
  }

  setParams(params: Record<string, number | string | boolean>): void {
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
    // shutterAngle takes precedence; motionBlurAmount is a Ghost Param (backward compat only).
    // If both are present, only shutterAngle is applied to prevent the ghost param from overwriting.
    if (params.shutterAngle !== undefined && (params.shutterAngle as number) > 0) {
      this.setShutterAngle(params.shutterAngle as number);
    } else if (params.motionBlurAmount !== undefined) {
      this.setMotionBlurAmount(params.motionBlurAmount as number);
    }
    if (params.trailIntensity !== undefined)
      this.setTrailIntensity(params.trailIntensity as number);
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
    if (params.crossFilterStrength !== undefined)
      this.setCrossFilterStrength(params.crossFilterStrength as number);
    if (params.crossFilterSpikes !== undefined)
      this.setCrossFilterSpikes(params.crossFilterSpikes as number);
    if (params.crossFilterAngle !== undefined)
      this.setCrossFilterAngle(params.crossFilterAngle as number);
    if (params.crossFilterLength !== undefined)
      this.setCrossFilterLength(params.crossFilterLength as number);
    if (params.crossFilterThreshold !== undefined)
      this.setCrossFilterThreshold(params.crossFilterThreshold as number);
    if (params.crossFilterChromatic !== undefined)
      this.setCrossFilterChromatic(params.crossFilterChromatic as number);
    if (params.crossFilterSizeLimit !== undefined)
      this.setCrossFilterSizeLimit(params.crossFilterSizeLimit as number);
    if (params.crossFilterRandomness !== undefined)
      this.setCrossFilterRandomness(params.crossFilterRandomness as number);
    if (params.crossFilterHardMode !== undefined)
      this.setCrossFilterHardMode(params.crossFilterHardMode as number);
    if (params.crossFilterMinSpacing !== undefined)
      this.setCrossFilterMinSpacing(params.crossFilterMinSpacing as number);
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

  /** `RenderBackend.destroy()` — alias for legacy `dispose()`. */
  destroy(): void {
    this.dispose();
  }

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
    this.ringCopyMaterial?.dispose();
    this.ringBlendMaterial?.dispose();
    for (const rt of this.rtRingBuffer) rt.dispose();
    this.rtRingBuffer = [];
    this.dustMaterial?.dispose();
    this.dustTexture?.dispose();
    this.scratchTexture?.dispose();
    this.shaftMaterial?.dispose();
    this.shaftBlendMaterial?.dispose();
    this.rtShaft?.dispose();
    this.crossFilterStreakMaterial?.dispose();
    this.crossFilterPeakSpacingMaxMaterial?.dispose();
    this.crossFilterPeakSpacingMaterial?.dispose();
    this.crossFilterBlendMaterial?.dispose();
    this.crossFilterPeakMaterial?.dispose();
    this.crossFilterTemporalMaterial?.dispose();
    this.crossFilterDebugMaterial?.dispose();
    this.rtCrossThreshold?.dispose();
    this.rtCrossPeak?.dispose();
    this.rtCrossPeakSpacingWork?.dispose();
    this.rtCrossPeakSpacingMax?.dispose();
    this.rtCrossPeakSpaced?.dispose();
    for (const rt of this.rtCrossPeakHistory) rt.dispose();
    this.rtCrossPeakHistory = [];
    for (const rt of this.rtCrossStreak) rt.dispose();
    this.rtCrossStreak = [];
    for (const rt of this.rtCentralBloomMips) rt.dispose();
    this.rtCentralBloomMips = [];
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
