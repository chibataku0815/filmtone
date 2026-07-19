/**
 * Cross Filter pass — extracted verbatim from `WebGLBackend.renderCrossFilter`
 * and its Hard-Mode-only / debug-only helpers `renderCentralBloom`,
 * `resolveCrossFilterDebugSource`, and `renderCrossFilterDebug` (all
 * module-private here too — nothing outside `renderCrossFilter` ever called
 * them on the original class).
 *
 * Unlike the WebGPU cross-filter's temporal hold (permanently disabled by a
 * `false` feature flag), this WebGL temporal hold is LIVE whenever Hard Mode
 * is active and not currently doing an A/B compare render. `renderCrossFilter`
 * writes six instance-owned fields that can't be mutated through a plain
 * parameter (two ring counters, two `THREE.WebGLRenderTarget` reference
 * fields, a boolean, and a count) — this function takes their current
 * values bundled in `deps` and returns the updated bundle; the wrapper
 * method assigns them back onto `this`.
 *
 * Behavior-preserving relocation only: no render-target / material /
 * autoClear / bind sequencing changes relative to the original methods.
 */

import * as THREE from "three";
import type { CrossFilterDebugView } from "../WebGLBackend";
import { computeMipWeights } from "./pyramid";

const CROSS_FILTER_SPACING_RADIUS_MAX_PX = 48.0;
const CROSS_FILTER_SPACING_RADIUS_EXTRA_MAX_PX = 24.0;

export interface CentralBloomRenderDeps {
  mips: THREE.WebGLRenderTarget[];
  downsampleMaterial: THREE.ShaderMaterial;
  upsampleMaterial: THREE.ShaderMaterial;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
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
function renderCentralBloom(
  renderer: THREE.WebGLRenderer,
  sourceTexture: THREE.Texture,
  sourceWidth: number,
  sourceHeight: number,
  deps: CentralBloomRenderDeps,
): void {
  const { mips, downsampleMaterial, upsampleMaterial, postMesh, postScene, postCamera } = deps;
  if (mips.length === 0) return;

  // Step 1: Seed mip 0 from the current peak mask via the downsample shader.
  const ds = downsampleMaterial.uniforms;
  ds.uSource!.value = sourceTexture;
  ds.uTexelSize!.value.set(1.0 / sourceWidth, 1.0 / sourceHeight);
  postMesh.material = downsampleMaterial;
  renderer.setRenderTarget(mips[0]!);
  renderer.render(postScene, postCamera);

  // Step 2: Downsample chain (mip 1 → mip last).
  for (let i = 1; i < mips.length; i++) {
    const src = mips[i - 1]!;
    ds.uSource!.value = src.texture;
    ds.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
    renderer.setRenderTarget(mips[i]!);
    renderer.render(postScene, postCamera);
  }

  // Step 3: Upsample chain (mip last → mip 0) with additive blend.
  // CRITICAL: autoClear must be false so the previous downsample data persists in the destination mip
  // and the upsample shader's THREE.AdditiveBlending accumulates on top.
  const us = upsampleMaterial.uniforms;
  const weights = computeMipWeights(0.5, mips.length);
  postMesh.material = upsampleMaterial;
  const prevAutoClear = renderer.autoClear;
  renderer.autoClear = false;
  for (let i = mips.length - 2; i >= 0; i--) {
    const src = mips[i + 1]!;
    us.uSource!.value = src.texture;
    us.uTexelSize!.value.set(1.0 / src.width, 1.0 / src.height);
    us.uWeight!.value = weights[i + 1]!;
    renderer.setRenderTarget(mips[i]!);
    renderer.render(postScene, postCamera);
  }
  renderer.autoClear = prevAutoClear;
}

export interface DebugSourceDeps {
  rtCrossThreshold: THREE.WebGLRenderTarget | null;
  rtCrossPeak: THREE.WebGLRenderTarget | null;
  rtCrossStreak: THREE.WebGLRenderTarget[];
}

function resolveCrossFilterDebugSource(
  view: CrossFilterDebugView,
  currentPeakTarget: THREE.WebGLRenderTarget,
  peakTarget: THREE.WebGLRenderTarget,
  deps: DebugSourceDeps,
): { texture: THREE.Texture; gain: number; falseColor: boolean } | null {
  const { rtCrossThreshold, rtCrossPeak, rtCrossStreak } = deps;
  switch (view) {
    case "threshold":
      return rtCrossThreshold
        ? { texture: rtCrossThreshold.texture, gain: 8.0, falseColor: true }
        : null;
    case "peak":
      return rtCrossPeak
        ? { texture: rtCrossPeak.texture, gain: 16.0, falseColor: true }
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
      const rt = rtCrossStreak[index];
      return rt ? { texture: rt.texture, gain: 3.0, falseColor: false } : null;
    }
    default:
      return null;
  }
}

export interface CrossFilterDebugRenderDeps extends DebugSourceDeps {
  crossFilterDebugMaterial: THREE.ShaderMaterial | null;
  crossFilterDebugView: CrossFilterDebugView;
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
}

function renderCrossFilterDebug(
  renderer: THREE.WebGLRenderer,
  target: THREE.WebGLRenderTarget | null,
  currentPeakTarget: THREE.WebGLRenderTarget,
  peakTarget: THREE.WebGLRenderTarget,
  deps: CrossFilterDebugRenderDeps,
): boolean {
  const { crossFilterDebugMaterial, crossFilterDebugView, postMesh, postScene, postCamera } = deps;
  if (!crossFilterDebugMaterial || crossFilterDebugView === "off") {
    return false;
  }

  const debugSource = resolveCrossFilterDebugSource(
    crossFilterDebugView,
    currentPeakTarget,
    peakTarget,
    deps,
  );
  if (!debugSource) {
    return false;
  }

  const du = crossFilterDebugMaterial.uniforms;
  du.uSource!.value = debugSource.texture;
  du.uGain!.value = debugSource.gain;
  du.uFalseColor!.value = debugSource.falseColor ? 1.0 : 0.0;
  postMesh.material = crossFilterDebugMaterial;
  renderer.setRenderTarget(target);
  renderer.render(postScene, postCamera);
  return true;
}

export interface CrossFilterHistoryState {
  crossFilterPeakHistoryWriteIndex: number;
  crossFilterPeakHistoryFilledFrames: number;
  lastCrossPeakSpacedTarget: THREE.WebGLRenderTarget | null;
  lastCrossPeakHeldTarget: THREE.WebGLRenderTarget | null;
  lastCrossTemporalHoldActive: boolean;
  lastCrossStreakCount: number;
}

export interface CrossFilterRenderDeps {
  crossFilterStreakMaterial: THREE.ShaderMaterial | null;
  crossFilterPeakSpacingMaterial: THREE.ShaderMaterial | null;
  crossFilterPeakSpacingMaxMaterial: THREE.ShaderMaterial | null;
  crossFilterBlendMaterial: THREE.ShaderMaterial | null;
  crossFilterPeakMaterial: THREE.ShaderMaterial | null;
  crossFilterTemporalMaterial: THREE.ShaderMaterial | null;
  crossFilterDebugMaterial: THREE.ShaderMaterial | null;
  bloomPrefilterMaterial: THREE.ShaderMaterial;
  downsampleMaterial: THREE.ShaderMaterial;
  upsampleMaterial: THREE.ShaderMaterial;
  rtCrossThreshold: THREE.WebGLRenderTarget | null;
  rtCrossPeak: THREE.WebGLRenderTarget | null;
  rtCrossPeakSpacingWork: THREE.WebGLRenderTarget | null;
  rtCrossPeakSpacingMax: THREE.WebGLRenderTarget | null;
  rtCrossPeakSpaced: THREE.WebGLRenderTarget | null;
  rtCrossPeakHistory: THREE.WebGLRenderTarget[];
  rtCrossStreak: THREE.WebGLRenderTarget[];
  rtCentralBloomMips: THREE.WebGLRenderTarget[];
  postMesh: THREE.Mesh;
  postScene: THREE.Scene;
  postCamera: THREE.OrthographicCamera;
  crossFilterSpikes: number;
  crossFilterAngle: number;
  crossFilterHardMode: number;
  crossFilterThreshold: number;
  crossFilterSizeLimit: number;
  crossFilterRandomness: number;
  crossFilterMinSpacing: number;
  crossFilterChromatic: number;
  crossFilterLength: number;
  crossFilterStrength: number;
  crossFilterDebugView: CrossFilterDebugView;
  /** External flag owned by `renderComparePair`; read-only here. */
  compareRenderActive: boolean;
  /** `getBlackTexture` singleton owned by `WebGLBackend.ts` — passed through
   * (not duplicated) so both modules keep reusing the same GPU resource. */
  getBlackTexture: () => THREE.DataTexture;
  /** Lazy central-bloom mip-chain allocation stays on `WebGLBackend` (it
   * reassigns `this.rtCentralBloomMips`'s backing array via push, but is
   * otherwise identical in shape to the other `ensureXxxResources`
   * methods left inline); called conditionally mid-function exactly like
   * the original, via this callback. */
  ensureCentralBloomResources: () => void;
  history: CrossFilterHistoryState;
}

export interface CrossFilterRenderResult {
  history: CrossFilterHistoryState;
}

export function renderCrossFilter(
  renderer: THREE.WebGLRenderer,
  sourceTexture: THREE.Texture,
  target: THREE.WebGLRenderTarget | null,
  deps: CrossFilterRenderDeps,
): CrossFilterRenderResult {
  const {
    crossFilterStreakMaterial,
    crossFilterPeakSpacingMaterial,
    crossFilterPeakSpacingMaxMaterial,
    crossFilterBlendMaterial,
    crossFilterPeakMaterial,
    crossFilterTemporalMaterial,
    crossFilterDebugMaterial,
    bloomPrefilterMaterial,
    downsampleMaterial,
    upsampleMaterial,
    rtCrossThreshold,
    rtCrossPeak,
    rtCrossPeakSpacingWork,
    rtCrossPeakSpacingMax,
    rtCrossPeakSpaced,
    rtCrossPeakHistory,
    rtCrossStreak,
    rtCentralBloomMips,
    postMesh,
    postScene,
    postCamera,
    crossFilterSpikes,
    crossFilterAngle,
    crossFilterHardMode,
    crossFilterThreshold,
    crossFilterSizeLimit,
    crossFilterRandomness,
    crossFilterMinSpacing,
    crossFilterChromatic,
    crossFilterLength,
    crossFilterStrength,
    crossFilterDebugView,
    compareRenderActive,
    getBlackTexture,
    ensureCentralBloomResources,
    history,
  } = deps;
  let crossFilterPeakHistoryWriteIndex = history.crossFilterPeakHistoryWriteIndex;
  let crossFilterPeakHistoryFilledFrames = history.crossFilterPeakHistoryFilledFrames;
  let lastCrossPeakSpacedTarget = history.lastCrossPeakSpacedTarget;
  let lastCrossPeakHeldTarget = history.lastCrossPeakHeldTarget;
  let lastCrossTemporalHoldActive = history.lastCrossTemporalHoldActive;
  let lastCrossStreakCount = history.lastCrossStreakCount;
  const passThroughHistory = (): CrossFilterRenderResult => ({
    history: {
      crossFilterPeakHistoryWriteIndex,
      crossFilterPeakHistoryFilledFrames,
      lastCrossPeakSpacedTarget,
      lastCrossPeakHeldTarget,
      lastCrossTemporalHoldActive,
      lastCrossStreakCount,
    },
  });

  if (!crossFilterStreakMaterial || !crossFilterPeakSpacingMaterial || !crossFilterPeakSpacingMaxMaterial || !crossFilterBlendMaterial
      || !crossFilterPeakMaterial || !crossFilterTemporalMaterial
      || !rtCrossThreshold || !rtCrossPeak || !rtCrossPeakSpacingWork || !rtCrossPeakSpacingMax || !rtCrossPeakSpaced
      || rtCrossPeakHistory.length < 2 || rtCrossStreak.length === 0) return passThroughHistory();

  const dirCount = Math.floor(crossFilterSpikes / 2);
  const angleRad = (crossFilterAngle * Math.PI) / 180;

  // Phase 6: Effective values pattern.
  // Hard Mode overrides 3 user-controlled values at uniform-set time.
  // CRITICAL: Never mutate this.crossFilter* fields → user values stay round-trip safe.
  // NOTE: Length is NOT boosted in Hard Mode — the streak shader uses the same MAX_STREAK_PX (64)
  // as Phase 5 to prevent UV wrap artifacts on smaller images. Hard Mode's distinguishing
  // character comes from gain/falloff/threshold/bloom changes instead of longer marches.
  const isHard = crossFilterHardMode >= 0.5;
  const effectiveThreshold  = isHard ? 0.70 : crossFilterThreshold;
  const effectiveSizeLimit  = isHard ? 1.0  : crossFilterSizeLimit;
  const effectiveRandomness = isHard ? 1.0  : crossFilterRandomness;
  const hardModeUniform     = isHard ? 1.0  : 0.0;

  // Sub-pass 1: Threshold extraction (reuse bloom prefilter shader)
  const pu = bloomPrefilterMaterial.uniforms;
  const savedThreshold = pu.uThreshold!.value;
  const savedKnee = pu.uKnee!.value;
  pu.uSource!.value = sourceTexture;
  pu.uThreshold!.value = effectiveThreshold;
  pu.uKnee!.value = 0.1;
  postMesh.material = bloomPrefilterMaterial;
  renderer.setRenderTarget(rtCrossThreshold);
  renderer.render(postScene, postCamera);
  pu.uThreshold!.value = savedThreshold;
  pu.uKnee!.value = savedKnee;

  // Sub-pass 1.5: Peak detection (suppress uniform bright areas, preserve point sources)
  const pk = crossFilterPeakMaterial!.uniforms;
  pk.uSource!.value = rtCrossThreshold.texture;
  pk.uTexelSize!.value.set(1.0 / rtCrossThreshold.width, 1.0 / rtCrossThreshold.height);
  pk.uSizeLimit!.value = effectiveSizeLimit;
  postMesh.material = crossFilterPeakMaterial!;
  renderer.setRenderTarget(rtCrossPeak!);
  renderer.render(postScene, postCamera);

  let currentPeakTarget = rtCrossPeak!;
  if (crossFilterMinSpacing >= 0.001) {
    const spacingBoost = Math.min(1, Math.max(0, crossFilterMinSpacing - 1.0));
    const radiusPx = Math.round(
      CROSS_FILTER_SPACING_RADIUS_MAX_PX +
        CROSS_FILTER_SPACING_RADIUS_EXTRA_MAX_PX *
          THREE.MathUtils.smoothstep(spacingBoost, 0.0, 1.0),
    );

    const smu = crossFilterPeakSpacingMaxMaterial.uniforms;
    smu.uSource!.value = rtCrossPeak.texture;
    smu.uTexelSize!.value.set(1.0 / rtCrossPeak.width, 1.0 / rtCrossPeak.height);
    smu.uAxis!.value.set(1, 0);
    smu.uRadiusPx!.value = radiusPx;
    smu.uReadMetadata!.value = 0.0;
    postMesh.material = crossFilterPeakSpacingMaxMaterial;
    renderer.setRenderTarget(rtCrossPeakSpacingWork);
    renderer.render(postScene, postCamera);

    smu.uSource!.value = rtCrossPeakSpacingWork.texture;
    smu.uAxis!.value.set(0, 1);
    smu.uReadMetadata!.value = 1.0;
    postMesh.material = crossFilterPeakSpacingMaxMaterial;
    renderer.setRenderTarget(rtCrossPeakSpacingMax);
    renderer.render(postScene, postCamera);

    const spu = crossFilterPeakSpacingMaterial.uniforms;
    spu.uSource!.value = rtCrossPeak.texture;
    spu.uLocalMax!.value = rtCrossPeakSpacingMax.texture;
    spu.uTexelSize!.value.set(1.0 / rtCrossPeak.width, 1.0 / rtCrossPeak.height);
    spu.uMinSpacing!.value = crossFilterMinSpacing;
    postMesh.material = crossFilterPeakSpacingMaterial;
    currentPeakTarget = rtCrossPeakSpaced!;
    renderer.setRenderTarget(currentPeakTarget);
    renderer.render(postScene, postCamera);
  }

  const temporalHoldActive = isHard && !compareRenderActive;
  let peakTarget = currentPeakTarget;
  if (temporalHoldActive) {
    const writeIndex = crossFilterPeakHistoryWriteIndex;
    const prevIndex = (writeIndex + rtCrossPeakHistory.length - 1) % rtCrossPeakHistory.length;
    const tu = crossFilterTemporalMaterial.uniforms;
    tu.uSource!.value = currentPeakTarget.texture;
    tu.uPrev!.value = crossFilterPeakHistoryFilledFrames > 0
      ? rtCrossPeakHistory[prevIndex]!.texture
      : getBlackTexture();
    postMesh.material = crossFilterTemporalMaterial;
    peakTarget = rtCrossPeakHistory[writeIndex]!;
    renderer.setRenderTarget(peakTarget);
    renderer.render(postScene, postCamera);
    crossFilterPeakHistoryWriteIndex = (writeIndex + 1) % rtCrossPeakHistory.length;
    crossFilterPeakHistoryFilledFrames = Math.min(
      crossFilterPeakHistoryFilledFrames + 1,
      rtCrossPeakHistory.length,
    );
  }
  lastCrossPeakSpacedTarget = currentPeakTarget;
  lastCrossPeakHeldTarget = peakTarget;
  lastCrossTemporalHoldActive = temporalHoldActive;

  // Phase 6 NEW: Sub-pass 1.75 — Hard Mode central bloom (skipped entirely in Soft Mode).
  if (isHard) {
    ensureCentralBloomResources();
    renderCentralBloom(renderer, peakTarget.texture, peakTarget.width, peakTarget.height, {
      mips: rtCentralBloomMips,
      downsampleMaterial,
      upsampleMaterial,
      postMesh,
      postScene,
      postCamera,
    });
  }

  // Sub-pass 2..N: Directional blur per spike direction
  const su = crossFilterStreakMaterial.uniforms;
  const qw = peakTarget.width;
  const qh = peakTarget.height;
  su.uSource!.value = peakTarget.texture;
  su.uTexelSize!.value.set(1.0 / qw, 1.0 / qh);
  su.uChromatic!.value = crossFilterChromatic;
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
    su.uLength!.value = crossFilterLength * lengthMul;
    su.uBrightnessMul!.value = brightMul;
    postMesh.material = crossFilterStreakMaterial;
    renderer.setRenderTarget(rtCrossStreak[i]!);
    renderer.render(postScene, postCamera);
  }
  lastCrossStreakCount = dirCount;
  su.uLength!.value = crossFilterLength;

  if (
    renderCrossFilterDebug(renderer, target, currentPeakTarget, peakTarget, {
      crossFilterDebugMaterial,
      crossFilterDebugView,
      postMesh,
      postScene,
      postCamera,
      rtCrossThreshold,
      rtCrossPeak,
      rtCrossStreak,
    })
  ) {
    return passThroughHistory();
  }

  // Final sub-pass: Screen blend
  const black = getBlackTexture();
  const bu = crossFilterBlendMaterial.uniforms;
  bu.uSource!.value = sourceTexture;
  bu.uStreak0!.value = dirCount >= 1 ? rtCrossStreak[0]!.texture : black;
  bu.uStreak1!.value = dirCount >= 2 ? rtCrossStreak[1]!.texture : black;
  bu.uStreak2!.value = dirCount >= 3 ? rtCrossStreak[2]!.texture : black;
  bu.uStreak3!.value = dirCount >= 4 ? rtCrossStreak[3]!.texture : black;
  // Phase 6: bind central bloom mip 0 (full half-res result), or black in Soft Mode → bloom term = 0 in shader.
  bu.uCentralBloom!.value = isHard && rtCentralBloomMips[0]
    ? rtCentralBloomMips[0].texture
    : black;
  bu.uStreakCount!.value = dirCount;
  bu.uIntensity!.value = crossFilterStrength;
  bu.uHardMode!.value = hardModeUniform;
  postMesh.material = crossFilterBlendMaterial;
  renderer.setRenderTarget(target);
  renderer.render(postScene, postCamera);

  return passThroughHistory();
}
