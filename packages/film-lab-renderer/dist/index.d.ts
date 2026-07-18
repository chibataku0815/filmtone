import * as THREE from 'three';
import { CameraOptics } from 'film-lab-core';
import { R as RenderBackend, V as ViewportCapabilities, a as ViewportContextLossInfo } from './RendererRuntime-DfZHjX7D.js';
export { b as RenderBackendParamValue, c as RenderBackendParams, d as ViewportContextLossReason } from './RendererRuntime-DfZHjX7D.js';

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

interface ViewportOptions {
    vertexShader: string;
    fragmentShader: string;
    width: number;
    height: number;
}
type CrossFilterDebugView = "off" | "threshold" | "peak" | "peakSpaced" | "peakHeld" | "streak0" | "streak1" | "streak2" | "streak3";
interface CrossFilterDebugStageStats {
    width: number;
    height: number;
    totalPixels: number;
    activePixels: number;
    activeFraction: number;
    sumLuma: number;
    maxLuma: number;
}
interface CrossFilterDebugMetrics {
    spacing: number;
    hardMode: boolean;
    temporalHoldActive: boolean;
    threshold: CrossFilterDebugStageStats | null;
    peak: CrossFilterDebugStageStats | null;
    peakSpaced: CrossFilterDebugStageStats | null;
    peakHeld: CrossFilterDebugStageStats | null;
    streaks: Array<CrossFilterDebugStageStats | null>;
}
declare class WebGLBackend implements RenderBackend {
    mesh: THREE.Mesh;
    private material;
    private geometry;
    private boundRenderer;
    private boundScene;
    private boundCamera;
    private postScene;
    private postCamera;
    private postGeometry;
    private postMesh;
    private bloomPrefilterMaterial;
    private halationPrefilterMaterial;
    private detailSoftnessMaterial;
    private downsampleMaterial;
    private upsampleMaterial;
    private compositeMaterial;
    private rtColorGraded;
    private rtDetailSoftened;
    private static readonly BLOOM_MIP_LEVELS;
    private static readonly HALATION_MIP_LEVELS;
    private static readonly DIFFUSION_MIP_LEVELS;
    private rtBloomMips;
    private rtHalationMips;
    /** A/B 比較: スロット A の最終合成（分割なし）を書き込む */
    private rtCompareComposite;
    /** #98 で確保する将来の post-composite 用フル解像度 RT（左側） */
    private rtPostComposite0;
    /** #98 で確保する将来の post-composite 用フル解像度 RT（右側） */
    private rtPostComposite1;
    /** true のとき render() でスロット A→RT、続けてスロット B を画面に分割表示 */
    private abCompareEnabled;
    private compareParamsA;
    private compareParamsB;
    private bloomThreshold;
    private bloomStrength;
    private bloomRadius;
    private halationIntensity;
    private halationSpread;
    private halationColor;
    private halationThreshold;
    private halationRadius;
    private bloomSoftKnee;
    private halationSoftKnee;
    private diffusion;
    private rtDiffusionMips;
    /**
     * composite の径方向グレイン混色（0=一様、1=周辺強め）。カラーパスには無く合成パスのみ。
     */
    private grainRadialMix;
    private detailSoftness;
    private static readonly MOTION_BLUR_RING_SIZE;
    private shutterAngle;
    private frameRepeat;
    private ringWriteIndex;
    private ringFilledFrames;
    private weightCurve;
    private motionThreshold;
    private trailIntensity;
    private ringCopyMaterial;
    private ringBlendMaterial;
    private rtRingBuffer;
    private dustAmount;
    private scratchAmount;
    private dustMaterial;
    private dustTexture;
    private scratchTexture;
    private shaftIntensity;
    private shaftDecay;
    private shaftOriginX;
    private shaftOriginY;
    private shaftMaterial;
    private shaftBlendMaterial;
    private rtShaft;
    private crossFilterStrength;
    private crossFilterSpikes;
    private crossFilterAngle;
    private crossFilterLength;
    private crossFilterThreshold;
    private crossFilterChromatic;
    private crossFilterSizeLimit;
    private crossFilterRandomness;
    /** Phase 6: Hard Mode toggle (0=Soft, 1=Hard). Render-time uniform overrides for stylized look. */
    private crossFilterHardMode;
    /** Peak-level spacing control — prefers separated highlight sources before streak generation. */
    private crossFilterMinSpacing;
    private crossFilterStreakMaterial;
    private crossFilterBlendMaterial;
    private rtCrossThreshold;
    private rtCrossPeak;
    private rtCrossPeakSpacingWork;
    private rtCrossPeakSpacingMax;
    private rtCrossPeakSpaced;
    private rtCrossStreak;
    private crossFilterPeakMaterial;
    private crossFilterPeakSpacingMaxMaterial;
    private crossFilterPeakSpacingMaterial;
    private crossFilterTemporalMaterial;
    private crossFilterDebugMaterial;
    private rtCrossPeakHistory;
    private crossFilterPeakHistoryWriteIndex;
    private crossFilterPeakHistoryFilledFrames;
    private crossFilterDebugView;
    private lastCrossPeakSpacedTarget;
    private lastCrossPeakHeldTarget;
    private lastCrossTemporalHoldActive;
    private lastCrossStreakCount;
    /** Phase 6: Hard Mode central bloom mip chain (lazy alloc, only when Hard Mode first becomes active). */
    private rtCentralBloomMips;
    private compareRenderActive;
    /**
     * composite のレンズ周辺ソフト（0〜1）。色収差周辺ソフトとは別（Params.lensSoftness）。
     */
    private lensSoftness;
    /**
     * シャドウ／ハイライトの色相は GPU から一意に逆算できないため、最後に `setParams` で適用した値を保持する。
     * `getParams` と「色相だけ更新」のときの強度維持に使う。
     */
    private splitShadowHueDeg;
    private splitHighlightHueDeg;
    private width;
    private height;
    private renderer;
    private histogramBuffer;
    /** HalfFloat RT 読み戻し用（readPixels は RGBA + HALF_FLOAT + Uint16 が正系） */
    private histogramHalfBuffer;
    constructor(options: ViewportOptions);
    /**
     * @description 0x0 の RenderTarget は WebGL warning の原因になります。
     * 画面の幅と高さが両方そろったときだけ GPU リソースを作ります。
     */
    private hasRenderableResolution;
    private ensureRenderTargets;
    private resizeRenderTargets;
    /**
     * Diffusion 用 mip chain を lazy 確保。diffusion=0 のときは GPU コストゼロ。
     */
    private ensureDiffusionResources;
    /**
     * #98 の post-composite seam が有効になったときだけ、中間 RT を作る。
     * 無効時は呼ばれないので、Pass 8 だけの現在挙動に余計なコストを足さない。
     */
    private ensurePostCompositeRenderTargets;
    /**
     * Motion blur 用の ShaderMaterial と N-frame ring buffer RT を遅延生成する。
     * shutterAngle > 180 になるまで GPU リソースを消費しない。
     */
    private ensureMotionBlurResources;
    /**
     * Dust & Scratches 用の ShaderMaterial とテクスチャを遅延生成する。
     * dustAmount > 0 || scratchAmount > 0 になるまで GPU リソースを消費しない。
     */
    private ensureDustResources;
    /**
     * Light shafts 用の ShaderMaterial と 1/4 解像度 RT を遅延生成する。
     * shaftIntensity > 0 になるまで GPU リソースを消費しない。
     */
    private ensureShaftResources;
    private ensureCrossFilterResources;
    /**
     * Phase 6: Hard Mode central bloom mip chain (lazy alloc, 4 levels at 1/4..1/32 of source).
     * Allocated only when Hard Mode first becomes active to keep VRAM cost off Soft-only sessions.
     */
    private ensureCentralBloomResources;
    /**
     * #98 の post-composite seam で使う RT を、画面サイズに合わせて広げ直す。
     *
     * @param w 幅
     * @param h 高さ
     */
    private resizePostCompositeRenderTargets;
    /**
     * 合成パス用ユニフォームをカラーグレード側（＋ Bloom/Halation 強度）に合わせる。
     */
    private syncCompositeUniformsFromMaterial;
    /**
     * post-composite chain が必要かどうか。A/B 比較中は R9 対策として Slot A はブラーをスキップ。
     * Slot B（abCompareEnabled=false）のみブラーを適用。
     */
    private hasPostCompositeChain;
    /**
     * Pass 1〜7 をまとめて実行する。
     * ここではまだ composite へは行かず、Pass 8 の入力を作るだけにする。
     *
     * @param renderer 描画先
     * @param scene 元シーン
     * @param camera 元カメラ
     */
    private renderBasePipeline;
    private opticalSourceTexture;
    private renderDetailSoftness;
    /**
     * Pass 8 の合成を 1 箇所へまとめる。
     *
     * @param renderer 描画先
     * @param target 出力先 RT。`null` なら画面に出す。
     * @param splitPosition 分割線の位置
     * @param abCompare A/B 比較かどうか
     * @param originalTexture 左側に見せる元画像
     */
    private renderCompositeFrame;
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
    private renderFinalFrame;
    /**
     * Split-only パス。グレーディングをスキップし、左=原画 / 右=ブラー済み出力 のスプリットのみ。
     * Before/After モード + post-composite chain 有効時に使用。
     */
    private renderSplitOnlyComposite;
    /**
     * Dust & Scratches パス。Screen blend で埃、Additive で傷をオーバーレイする。
     *
     * @param renderer 描画先
     * @param sourceTexture 直前の post-composite 出力
     * @param target 出力先（null = 画面）
     */
    private renderDust;
    /**
     * N-frame ring buffer motion blur.
     * Draw 1: Copy sourceTexture → rtRingBuffer[ringWriteIndex]
     * Draw 2: Weighted blend of ring slots (newest first) → target
     *
     * @param renderer 描画先
     * @param sourceTexture composite 出力テクスチャ
     * @param target 最終出力先（null = 画面）
     */
    private renderMotionBlur;
    /**
     * Light shafts two-sub-pass rendering.
     * 9a: Radial blur at 1/4 resolution (64 samples, luminance threshold).
     * 9b: Additive blend at full resolution.
     *
     * @param renderer 描画先
     * @param sourceTexture composite 出力テクスチャ
     * @param target 最終出力先（null = 画面）
     */
    private renderLightShafts;
    private renderCrossFilter;
    /**
     * Pass 9+ の受け皿。
     * Pass order: CrossFilter -> Shafts(9) -> Dust(10) -> MotionBlur(11)
     *
     * @param renderer 描画先
     * @param sourceTexture 直前の post-composite 出力
     * @param target 最終出力先
     */
    private renderPostCompositeChain;
    /**
     * A/B ルック比較のオンオフと両スロットのパラメータ（setParams と同形のレコード）。
     * オフ時は render が従来どおりアクティブ側のみ（setParams で渡した値）を使う。
     */
    setComparePair(enabled: boolean, paramsA: Record<string, number | string> | null, paramsB: Record<string, number | string> | null): void;
    /**
     * T2-0c: `RenderBackend.render()` is zero-arg. WebGL still needs the
     * Three.js renderer/scene/camera; callers that migrated to the backend
     * interface must first `bindThree(renderer, scene, camera)` once (typically
     * during setup), after which subsequent `render()` calls use the stored
     * bindings. Legacy 3-arg callers continue to pass them per-frame.
     */
    bindThree(renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.Camera): void;
    render(renderer?: THREE.WebGLRenderer, scene?: THREE.Scene, camera?: THREE.Camera): void;
    /**
     * スロット A を全パスで RT に書き、続けてスロット B を画面に分割合成する。
     */
    private renderComparePair;
    /**
     * Compute per-mip-level weights for the upsample accumulation.
     * radius=0 → tight bloom (only first mips). radius=1 → diffuse wide haze.
     */
    private static computeMipWeights;
    private renderBloom;
    private renderHalation;
    /**
     * Diffusion (Pro-Mist): Full-image mip pyramid blur (no threshold prefilter).
     * Reuses downsample/upsample materials shared with bloom/halation.
     */
    private renderDiffusion;
    setTexture(texture: THREE.Texture): void;
    setResolution(width: number, height: number): void;
    setImageResolution(width: number, height: number): void;
    setFitMode(mode: "cover" | "contain"): void;
    setTime(time: number): void;
    setExposure(value: number): void;
    setContrast(value: number): void;
    setSaturation(value: number): void;
    setTemperature(value: number): void;
    /**
     * グリーン／マゼンタ軸の色かぶり（シェーダー `uTint`）。
     * @param value -1〜1 程度（プリセットと `types.Params.tint` に対応）
     */
    setTint(value: number): void;
    setFade(value: number): void;
    setHighlights(value: number): void;
    setShadows(value: number): void;
    setRGBShift(value: number): void;
    setGrainIntensity(value: number): void;
    /**
     * @description Params.grainRadialMix を合成シェーダへ。0〜1 に丸める。
     */
    setGrainRadialMix(value: number): void;
    setGrainSize(value: number): void;
    /**
     * @description Params.lensSoftness を合成シェーダへ。0〜1 に丸める。
     */
    setLensSoftness(value: number): void;
    setVignette(value: number): void;
    setBloomThreshold(value: number): void;
    setBloomStrength(value: number): void;
    setBloomRadius(value: number): void;
    setDiffusion(value: number): void;
    setHalationIntensity(value: number): void;
    setHalationSpread(value: number): void;
    setHalationColor(hex: string): void;
    setHalationThreshold(value: number): void;
    setHalationRadius(value: number): void;
    setBloomSoftKnee(value: number): void;
    setHalationSoftKnee(value: number): void;
    setShutterAngle(degrees: number): void;
    setMotionBlurAmount(value: number): void;
    setTrailIntensity(value: number): void;
    setFrameRepeat(value: number): void;
    resetMotionBlurHistory(): void;
    setDustAmount(value: number): void;
    setScratchAmount(value: number): void;
    setShaftIntensity(value: number): void;
    setShaftDecay(value: number): void;
    setShaftOriginX(value: number): void;
    setShaftOriginY(value: number): void;
    setCrossFilterStrength(v: number): void;
    setCrossFilterSpikes(v: number): void;
    setCrossFilterAngle(v: number): void;
    setCrossFilterLength(v: number): void;
    setCrossFilterThreshold(v: number): void;
    setCrossFilterChromatic(v: number): void;
    setCrossFilterSizeLimit(v: number): void;
    setCrossFilterRandomness(v: number): void;
    setCrossFilterHardMode(v: number): void;
    setCrossFilterMinSpacing(v: number): void;
    private resetCrossFilterHistory;
    setCrossFilterDebugView(view: CrossFilterDebugView | null): void;
    getCrossFilterDebugView(): CrossFilterDebugView;
    private getRenderTargetLumaStats;
    getCrossFilterDebugMetrics(): CrossFilterDebugMetrics | null;
    /** Retained for sync (e.g. edit→batch transfer). Not used for rendering. */
    private lut1RawData;
    private lut1RawSize;
    private lut2RawData;
    private lut2RawSize;
    private createLUT3DTexture;
    setLUT1(data: Float32Array, size: number): void;
    clearLUT1(): void;
    setLUT1Intensity(value: number): void;
    setLUT2(data: Float32Array, size: number): void;
    clearLUT2(): void;
    setLUT2Intensity(value: number): void;
    /** @deprecated Use setLUT2() */
    setLUT(data: Float32Array, size: number): void;
    /** @deprecated Use clearLUT2() */
    clearLUT(): void;
    /** @deprecated Use setLUT2Intensity() */
    setLUTIntensity(value: number): void;
    getLUT1Snapshot(): {
        data: Float32Array;
        size: number;
        intensity: number;
    } | null;
    getLUT2Snapshot(): {
        data: Float32Array;
        size: number;
        intensity: number;
    } | null;
    /**
     * @description エクスポート時の Y 反転。composite パスのみ反転し、中間 RT は通常方向を維持。
     * readPixels 後の CPU flip を不要にする。
     */
    setExportFlipY(flip: boolean): void;
    setSplitPosition(value: number): void;
    /**
     * @description 合成パスが参照する分割位置（FilmLabCanvas の保存後復帰など）
     */
    getSplitPosition(): number;
    getParams(): Record<string, number | string>;
    setParams(params: Record<string, number | string | boolean>): void;
    /** カラーグレード済みRTからピクセルデータを取得（ヒストグラム用） */
    getHistogramPixels(): {
        pixels: Float32Array;
        width: number;
        height: number;
    } | null;
    /** `RenderBackend.destroy()` — alias for legacy `dispose()`. */
    destroy(): void;
    dispose(): void;
}

/**
 * Viewport — single-entry renderer wrapper (Phase 3 T3-3).
 *
 * Master plan D3 calls for a single `Viewport` class that switches backends
 * internally via `RenderBackend`. T3-3 lands the composition refactor:
 *   - `Viewport` no longer extends `WebGLBackend`; it composes one of
 *     { `WebGLBackend`, `WebGPUBackend` } and forwards the public surface.
 *   - `backendKind` / `mesh?` are read-only introspection fields.
 *   - `Viewport.create(canvas, { prefer: 'webgpu' })` routes to the WebGPU
 *     backend when `isWebGPUSupported()` returns true AND the canvas does
 *     not already own a WebGL2 context (consumer-side responsibility). No
 *     silent fallback — if WebGPU is requested and unavailable, or the
 *     backend bootstrap throws, the exception propagates. Callers decide
 *     how to surface that to the user (e.g. explicit "WebGPU required" UI).
 *     Rationale: silent degradation multiplies code paths and masks
 *     premise-breaking bugs (e.g. a WebGPU-owned canvas that can no longer
 *     accept a WebGL2 context).
 *
 * Consumer surface preserved by delegation:
 *   render / setResolution / setTexture / setMediaFromBitmap /
 *   setImageResolution / setFitMode / setTime / setParams / getParams /
 *   setLUT1(+Intensity,+clear) / setLUT2(+Intensity,+clear) /
 *   setLUT/setLUTIntensity/clearLUT (deprecated aliases) /
 *   setSplitPosition / getSplitPosition / setExportFlipY /
 *   resetMotionBlurHistory / setReadbackEnabled / readbackRgba8 /
 *   bindThree / setComparePair /
 *   getHistogramPixels / dispose / destroy / prewarm.
 *
 * Granular WebGL setters (setExposure, setCrossFilterXxx, etc.) are no
 * longer on the Viewport public type. v1.0 consumers drive the renderer via
 * `setParams(record)` — verified by `grep viewport\.set…` across packages.
 */

type ViewportBackendPreference = "webgpu" | "webgl";

interface ViewportCreateOptions {
    /**
     * Desired backend. Defaults to `'webgpu'` so desktop paths flip
     * automatically. Web builds pass `'webgl'` explicitly (or rely on the
     * build flag). WebGPU requires a canvas without a prior WebGL2 context —
     * callers must pass a fresh canvas when `prefer === 'webgpu'`.
     */
    prefer?: ViewportBackendPreference;
    /** Override the derived render width. */
    width?: number;
    /** Override the derived render height. */
    height?: number;
}
declare class Viewport {
    private readonly webglBackend;
    private readonly webgpuBackend;
    readonly backendKind: ViewportBackendPreference;
    readonly capabilities: ViewportCapabilities;
    /**
     * WebGL-only handle to the fullscreen `THREE.Mesh`. `undefined` on the
     * WebGPU path — consumer code that does `scene.add(viewport.mesh)` MUST
     * gate on `viewport.backendKind === 'webgl'` first.
     */
    readonly mesh?: THREE.Mesh;
    private webgpuSetTextureGen;
    private constructor();
    static create(canvas: HTMLCanvasElement, opts?: ViewportCreateOptions): Promise<Viewport>;
    render(renderer?: THREE.WebGLRenderer, scene?: THREE.Scene, camera?: THREE.Camera): void;
    setResolution(width: number, height: number): void;
    /**
     * WebGL: sets the `THREE.Texture` uniform directly.
     * WebGPU: extracts the texture's source (`HTMLImageElement`,
     * `HTMLVideoElement`, `ImageBitmap`, etc.) and uploads via
     * `createImageBitmap` + `setMediaFromBitmap`. The conversion is async and
     * fire-and-forget; callers can continue rendering — the new image appears
     * on the next frame after the bitmap is ready. Generation counter drops
     * stale results if `setTexture` is called multiple times in flight.
     */
    setTexture(texture: THREE.Texture): void;
    /** WebGPU-native path; WebGL consumers should call `setTexture` instead. */
    setMediaFromBitmap(bitmap: ImageBitmap): void;
    /** WebGPU-native path for reusable Canvas / VideoFrame-style uploads. */
    setMediaFromExternalImageSource(source: ImageBitmapSource, width: number, height: number): void;
    /**
     * Upload a shared depth map for depth-aware Mist / Glow. No-op on WebGL.
     * `depthMistGain` / `depthGlowGain` stay in the shared grade contract; the
     * WebGPU renderer consumes the uploaded depth texture when those gains are > 0.
     */
    setDepthFromBitmap(bitmap: ImageBitmap): void;
    /**
     * Camera optics are consumed by the WebGPU ray-angle model. WebGL keeps
     * legacy behavior and ignores the value.
     */
    setCameraOptics(optics: CameraOptics | null): void;
    setImageResolution(width: number, height: number): void;
    setFitMode(mode: "cover" | "contain"): void;
    setTime(time: number): void;
    setParams(params: Record<string, number | string | boolean>): void;
    getParams(): Record<string, number | string>;
    getCapabilities(): ViewportCapabilities;
    isContextLost(): boolean;
    getContextLossInfo(): ViewportContextLossInfo | null;
    onContextLost(listener: (info: ViewportContextLossInfo) => void): () => void;
    setLUT1(data: Float32Array, size: number): void;
    setLUT1Intensity(value: number): void;
    clearLUT1(): void;
    setLUT2(data: Float32Array, size: number): void;
    setLUT2Intensity(value: number): void;
    clearLUT2(): void;
    /**
     * WebGL-only snapshot for edit→batch sync and video export. WebGPU path
     * returns `null` in v1.0 — consumers must gate on `backendKind === 'webgl'`
     * or accept the no-op fallback.
     */
    getLUT1Snapshot(): {
        data: Float32Array;
        size: number;
        intensity: number;
    } | null;
    getLUT2Snapshot(): {
        data: Float32Array;
        size: number;
        intensity: number;
    } | null;
    /** @deprecated Use setLUT2() — kept for legacy apps/webgl-study debug-gui. */
    setLUT(data: Float32Array, size: number): void;
    /** @deprecated Use clearLUT2() */
    clearLUT(): void;
    /** @deprecated Use setLUT2Intensity() */
    setLUTIntensity(value: number): void;
    setSplitPosition(value: number): void;
    getSplitPosition(): number;
    setExportFlipY(flip: boolean): void;
    resetMotionBlurHistory(): void;
    /**
     * v1 compare-bar: WebGPU honors `enabled` only and renders a full-screen
     * "ungraded source" present pass when active (slot params ignored —
     * dual-slot simultaneous A/B parity stays deferred). WebGL retains full
     * dual-grade behavior.
     */
    setComparePair(enabled: boolean, paramsA: Record<string, number | string> | null, paramsB: Record<string, number | string> | null): void;
    bindThree(renderer: THREE.WebGLRenderer, scene: THREE.Scene, camera: THREE.Camera): void;
    getHistogramPixels(): {
        pixels: Float32Array;
        width: number;
        height: number;
    } | null;
    /**
     * Phase 3 T3-3: prewarm WebGPU pipeline JIT.
     *
     * Issues a single render at current resolution so first real frame does
     * not stutter on pipeline compile. Caller should run inside
     * `requestIdleCallback` — DIRECTION §10 Phase 3 UX budget is 150 ms
     * silent / 300 ms overlay fadeout.
     *
     * No-op on WebGL (no JIT cost there).
     */
    prewarm(): Promise<void>;
    setReadbackEnabled(enabled: boolean): void;
    readbackRgba8(): Promise<Uint8Array>;
    dispose(): void;
    /** RenderBackend interface alias. */
    destroy(): void;
    private queueSetTextureWebGPU;
}

/**
 * MediaLoader — File-to-Texture converter for Film Lab
 *
 * iPhone Safari 向け: HEIC の早期拒否、GPU maxTextureSize 超過時の Canvas 縮小、
 * 呼び出し側で表示できるよう MediaLoadError を投げる。
 *
 * デスクトップ Safari: 埋め込み ICC（ディスプレイプロファイル付きスクリーンショット等）で
 * `new Image()` + blob URL のデコードが失敗し、Chrome では通ることがある。
 * その場合は `createImageBitmap` → Canvas 経由のフォールバックを試す。
 *
 * デバッグ: URL に `?filmLabDebugMedia=1`（例: /film-lab?filmLabDebugMedia=1）を付けると
 * 各デコード段階を console に出す。
 */

interface LoadResult {
    texture: THREE.Texture;
    width: number;
    height: number;
    type: "image" | "video";
}
/** ブラウザがデコードできない形式・サイズなど（UI メッセージ用 code 付き） */
declare class MediaLoadError extends Error {
    readonly code: "HEIC_UNSUPPORTED" | "IMAGE_DECODE_FAILED" | "VIDEO_DECODE_FAILED" | "UNKNOWN";
    constructor(message: string, code: "HEIC_UNSUPPORTED" | "IMAGE_DECODE_FAILED" | "VIDEO_DECODE_FAILED" | "UNKNOWN");
}
interface LoadFileOptions {
    /** WebGL の gl.MAX_TEXTURE_SIZE。未指定時は縮小しない */
    maxTextureSize?: number;
}
/**
 * MIME が空・不正でも、拡張子が動画らしいときは `<video>` 経路へ回す（Finder ドロップの .mov 等）。
 * ブラウザが実際にデコードできない容器は loadVideo 内でエラーになる。
 */
declare const LIKELY_VIDEO_EXTENSION: RegExp;
/**
 * `?filmLabDebugMedia=1` のとき true。クライアント専用。
 */
declare function isFilmLabMediaDebugEnabled(): boolean;
/**
 * iPhone の写真（HEIC/HEIF）かどうか。MIME が空のときは拡張子で推定する。
 */
declare function isLikelyHeicFile(file: File): boolean;
declare class MediaLoader {
    loadFile(file: File, options?: LoadFileOptions): Promise<LoadResult>;
    /**
     * 画像をデコードしてテクスチャにする。
     * Safari 等で Image 経路が落ちた場合は createImageBitmap を順に試す。
     */
    private loadImage;
    private loadVideo;
    /**
     * @description URL から直接動画を読み込む。Desktop の mezzanine 変換後パス（`film-lab-video://…`）等、
     * blob URL を経由しない動画ソース向け。`loadVideo(file)` とほぼ同じだが `createObjectURL` / `revokeObjectURL` を使わない。
     * @param url 動画の URL（`film-lab-video://…` や `file://…` 等）
     * @param label エラーメッセージに表示する任意のラベル（元ファイル名等）
     */
    loadVideoFromURL(url: string, label?: string): Promise<LoadResult>;
    loadURL(url: string): Promise<LoadResult>;
}

/**
 * Renderer support detection & pixel ratio utilities.
 *
 * Hoisted from apps/web/src/shared/gl/ for shared renderer consumers.
 */
declare function isWebGL2Supported(): boolean;
/**
 * デバイスに応じたピクセル比を取得（モバイルや低電力デバイスでは制限をかける）
 */
declare function getOptimalPixelRatio(maxRatio?: number): number;
/**
 * WebGPU adapter availability probe. Memoized across calls — the first
 * `navigator.gpu.requestAdapter()` result determines support for this
 * page lifetime. Returns `false` when `navigator.gpu` is absent (e.g.
 * non-browser contexts, unsupported Electron builds, or `?__test=0`
 * bypasses that null the API).
 */
declare function isWebGPUSupported(): Promise<boolean>;

declare const filmlabVertexShader = "\nuniform float uFlipY;\nout vec2 vUv;\n\nvoid main() {\n  vUv = vec2(uv.x, mix(uv.y, 1.0 - uv.y, uFlipY));\n  gl_Position = vec4(position, 1.0);\n}\n";

/**
 * @fileOverview Film Lab メインカラーグレード用 GLSL3 フラグメントシェーダー文字列。
 * @description 露出・コントラスト・0.4.0 Process（圧縮／プリント）・LUT などを 1 パスで適用する。
 * @limitations 解像度や LUT は JS（Viewport）側の uniform で供給する。このファイル単体では描画しない。
 */
declare const filmlabFragmentShader = "\nprecision highp float;\nprecision highp sampler3D;\n\nuniform sampler2D uTexture;\nuniform vec2 uResolution;\nuniform vec2 uImageResolution;\nuniform float uTime;\n\nuniform float uExposure;\nuniform float uContrast;\nuniform float uSaturation;\nuniform float uTemperature;\nuniform float uTint;\n\nuniform float uRGBShift;\nuniform float uGrainIntensity;\nuniform float uVignette;\n\nuniform float uFade;\nuniform float uHighlights;\nuniform float uShadows;\n// \u30B7\u30E3\u30C9\u30A6\uFF0F\u30CF\u30A4\u30E9\u30A4\u30C8\u306E vec3 \u306F JS \u5074\u3067\u8272\u76F8\uFF08HSL \u5F69\u5EA6\u65B9\u5411\uFF09\u00D7 \u5F37\u5EA6 \u00D7 \u30EC\u30AC\u30B7\u30FC\u9577\u3055\u304B\u3089\u5408\u6210\uFF08\u8EF8 E \u8272\u76F8\u62E1\u5F35\uFF09\nuniform vec3 uShadowTint;\nuniform vec3 uHighlightTint;\n\nuniform float uSplitPosition;\n\n// Input Transform LUT (applied before color grading \u2014 Log\u2192Rec709)\nuniform highp sampler3D uLUT1;\nuniform float uLUT1Intensity;\nuniform float uLUT1Enabled;\n\n// Creative LUT (applied after color grading \u2014 film look)\nuniform highp sampler3D uLUT2;\nuniform float uLUT2Intensity;\nuniform float uLUT2Enabled;\n\n// 0.4.0 \u306E\u73FE\u50CF\u6BB5\u3067\u4F7F\u3046\u6570\u5024 uniform\u3002\nuniform float uCompressionAmount;  // 0\u301C1\u30010 \u3067\u7121\u52B9\nuniform float uCompressionRange;   // 0\u301C1\u30010.5 \u304C\u65E2\u5B9A\nuniform float uShadowLatitude;      // 0\u301C1\u3001toe separation\n\n// 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3067\u4F7F\u3046\u6570\u5024 uniform\u3002\nuniform float uCyan;               // -1\u301C1\u30010 \u3067\u7121\u52B9\nuniform float uMagenta;            // -1\u301C1\u30010 \u3067\u7121\u52B9\nuniform float uYellow;              // -1\u301C1\u30010 \u3067\u7121\u52B9\nuniform float uPrintContrast;      // 0\u301C1\u30010 \u3067\u7121\u52B9\n\nuniform float uFitMode; // 0.0 = cover (crop), 1.0 = contain (letterbox)\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvec2 fitUv(vec2 uv, vec2 resolution, vec2 imageResolution) {\n  float screenAspect = resolution.x / resolution.y;\n  float imageAspect = imageResolution.x / imageResolution.y;\n  vec2 coverScale = screenAspect > imageAspect\n    ? vec2(1.0, imageAspect / screenAspect)\n    : vec2(screenAspect / imageAspect, 1.0);\n  vec2 containScale = screenAspect > imageAspect\n    ? vec2(screenAspect / imageAspect, 1.0)\n    : vec2(1.0, imageAspect / screenAspect);\n  vec2 scale = mix(coverScale, containScale, uFitMode);\n  vec2 result = (uv - 0.5) * scale + 0.5;\n  // Contain: center narrow portraits in the left half (x=25%)\n  // Applies when image occupies < 50% of screen width (scale.x > 2.0)\n  float narrowPortrait = step(2.0, scale.x) * uFitMode;\n  result.x += 0.18 * scale.x * narrowPortrait;\n  return result;\n}\n\nfloat insideUv(vec2 uv) {\n  vec2 s = step(0.0, uv) * step(uv, vec2(1.0));\n  return s.x * s.y;\n}\n\n// Cover UV: zoom video to fill entire screen (for blurred background)\nvec2 bgCoverUv(vec2 uv, vec2 resolution, vec2 imageResolution) {\n  float screenAspect = resolution.x / resolution.y;\n  float imageAspect = imageResolution.x / imageResolution.y;\n  vec2 scale = screenAspect > imageAspect\n    ? vec2(1.0, imageAspect / screenAspect)\n    : vec2(screenAspect / imageAspect, 1.0);\n  return (uv - 0.5) * scale + 0.5;\n}\n\n// Feathered mask for soft edge between sharp image and blurred background\nfloat softMask(vec2 uv, float feather) {\n  vec2 d = smoothstep(vec2(0.0), vec2(feather), uv)\n         * smoothstep(vec2(0.0), vec2(feather), 1.0 - uv);\n  return d.x * d.y;\n}\n\n/**\n * \u30EC\u30F3\u30BA\u5468\u8FBA\u306E\u8272\u53CE\u5DEE\u306B\u8FD1\u3044\u898B\u3048\u65B9: \u753B\u50CF\u4E2D\u5FC3\u3067\u306F\u30BC\u30ED\u3001\u30D5\u30EC\u30FC\u30E0\u7AEF\u307B\u3069 R/B \u3092\u653E\u5C04\u65B9\u5411\u306B\u305A\u3089\u3059\u3002\n * amount \u306F\u30B9\u30E9\u30A4\u30C0\u4E0A\u9650\uFF08\u5468\u8FBA\u3067\u6700\u5927\u306B\u8FD1\u3044\u91CF\uFF09\u3002\u30A2\u30B9\u30DA\u30AF\u30C8\u88DC\u6B63\u3067\u8DDD\u96E2\u30DE\u30B9\u30AF\u3092\u5186\u5F62\u306B\u63C3\u3048\u308B\u3002\n */\nvec4 rgbShiftSampleRadial(sampler2D tex, vec2 uv, float amount, vec2 imageResolution) {\n  vec2 delta = uv - 0.5;\n  delta.x *= imageResolution.x / max(imageResolution.y, 1.0);\n  float radial = clamp(length(delta) * 2.0, 0.0, 1.0);\n  float weight = pow(radial, 1.65);\n  float amt = amount * weight;\n  vec2 dir = normalize(delta + vec2(1e-5));\n  float rCh = textureLod(tex, uv + dir * amt, 0.0).r;\n  float gCh = textureLod(tex, uv, 0.0).g;\n  float bCh = textureLod(tex, uv - dir * amt, 0.0).b;\n  float aCh = textureLod(tex, uv, 0.0).a;\n  return vec4(rCh, gCh, bCh, aCh);\n}\n\nfloat grain(vec2 uv, float time) {\n  return fract(sin(dot(uv * time, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;\n}\n\nfloat filmCompressionWarmProtect(vec3 chroma, float mag) {\n  if (mag <= 0.000001) return 0.0;\n  vec3 dir = chroma / mag;\n  float redWarm = smoothstep(0.32, 0.72, dir.r);\n  float blueOpposed = 1.0 - smoothstep(-0.58, -0.20, dir.b);\n  float greenModerate = 1.0 - smoothstep(0.18, 0.58, abs(dir.g));\n  return clamp(redWarm * blueOpposed * greenModerate, 0.0, 1.0);\n}\n\n// Film Compression V3: existing luma shoulder plus hue-preserving chroma\n// density rolloff around the post-shoulder neutral axis.\nvec3 applyFilmCompression(vec3 rgb, float amount, float range) {\n  if (amount < 0.001) return rgb;\n  float r = clamp(range, 0.0, 1.0);\n  float k = mix(5.15, 2.85, r);\n  float rangeSoft = smoothstep(0.82, 1.0, r);\n  float amt = amount * (1.0 - 0.18 * rangeSoft);\n  float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));\n  float x = clamp(k * (luma - 0.5), -5.5, 5.5);\n  float s = 1.0 / (1.0 + exp(-x));\n  // One-sided shoulder: only roll highlights down, never lift shadows.\n  // A symmetric sigmoid centered at 0.5 would push deep blacks upward\n  // and boost shadow chroma \u2014 the opposite of the filmic density target.\n  float shoulderY = min(luma, mix(luma, s, amt));\n  float lumaScale = luma > 0.001 ? shoulderY / luma : 1.0;\n  vec3 lumaCompressed = rgb * lumaScale;\n  vec3 chroma = lumaCompressed - vec3(shoulderY);\n  float chromaMag = length(chroma);\n\n  float shadowRelease = smoothstep(0.14, 0.30, shoulderY);\n  float kneeStart = mix(0.62, 0.42, r);\n  float kneeEnd = mix(0.96, 0.78, r);\n  float highlightMask = smoothstep(kneeStart, kneeEnd, shoulderY);\n  float chromaStress = smoothstep(0.16, 0.70, chromaMag);\n  float maxChannel = max(max(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);\n  float minChannel = min(min(lumaCompressed.r, lumaCompressed.g), lumaCompressed.b);\n  float highEdgeStress = smoothstep(0.82, 1.08, maxChannel);\n  float lowEdgeStress = smoothstep(0.82, 1.08, -minChannel);\n  float gamutStress = max(highEdgeStress, lowEdgeStress)\n    * chromaStress\n    * smoothstep(0.08, 0.24, shoulderY);\n  float warmProtect = filmCompressionWarmProtect(chroma, chromaMag);\n\n  float highlightCompression = 0.42 * highlightMask * shadowRelease * mix(0.55, 1.0, chromaStress);\n  float guardCompression = 0.22 * gamutStress * shadowRelease;\n  float protectedCompression = (highlightCompression + guardCompression) * (1.0 - 0.35 * warmProtect);\n  float chromaScale = clamp(1.0 - amt * protectedCompression, 0.0, 1.0);\n  vec3 landedChroma = chroma * chromaScale;\n  vec3 outColor = vec3(shoulderY) + landedChroma;\n  float outMax = max(max(outColor.r, outColor.g), outColor.b);\n  float landingChroma = smoothstep(0.18, 0.62, chromaMag);\n  float landingMask = smoothstep(0.78, 0.98, outMax)\n    * landingChroma\n    * shadowRelease\n    * (1.0 - 0.35 * warmProtect);\n  if (outMax > 0.78 && outMax > shoulderY + 0.000001) {\n    float over = outMax - 0.78;\n    float headroom = 0.22;\n    float softMax = 0.78 + (headroom * over) / (over + headroom);\n    float landingScale = clamp((softMax - shoulderY) / (outMax - shoulderY), 0.0, 1.0);\n    float landingBlend = clamp(amt * 0.88 * landingMask, 0.0, 1.0);\n    float finalScale = mix(1.0, landingScale, landingBlend);\n    outColor = vec3(shoulderY) + landedChroma * finalScale;\n  }\n  return clamp(outColor, 0.0, 1.0);\n}\n\nvec3 applyShadowLatitude(vec3 rgb, float amount) {\n  float amt = clamp(amount, 0.0, 1.0);\n  if (amt < 0.001) return rgb;\n  float y = dot(rgb, vec3(0.2126, 0.7152, 0.0722));\n  float blackProtect = smoothstep(0.025, 0.055, y);\n  float release = 1.0 - smoothstep(0.18, 0.30, y);\n  float band = blackProtect * release;\n  if (band <= 0.000001) return rgb;\n  float toeShape = max(0.0, 1.0 - y / 0.30);\n  float lumaLift = y * toeShape * 0.22 * amt * band;\n  float outY = y + lumaLift;\n  float chromaScale = 1.0 + 0.08 * amt * band;\n  vec3 outColor = vec3(outY) + (rgb - vec3(y)) * chromaScale;\n  return clamp(outColor, 0.0, 1.0);\n}\n\n// \u30D7\u30EA\u30F3\u30C8\u6BB5\u306E\u6700\u7D42\u30B3\u30F3\u30C8\u30E9\u30B9\u30C8\u3092 S \u30AB\u30FC\u30D6\u3067\u6301\u3061\u4E0A\u3052\u308B\u3002\n// amount=0 \u306A\u3089\u4F55\u3082\u3057\u306A\u3044\u3002\nvec3 applyPrintContrast(vec3 rgb, float amount) {\n  if (amount < 0.001) return rgb;\n  float k = mix(1.0, 5.0, amount);\n  vec3 s = 1.0 / (1.0 + exp(-k * (rgb - 0.5)));\n  return clamp(mix(rgb, s, amount), 0.0, 1.0);\n}\n\nvoid main() {\n  vec2 uv = fitUv(vUv, uResolution, uImageResolution);\n  float mask = insideUv(uv);\n\n  vec4 color = uRGBShift > 0.0\n    ? rgbShiftSampleRadial(uTexture, uv, uRGBShift, uImageResolution)\n    : textureLod(uTexture, uv, 0.0);\n\n  // === Input Transform LUT (LUT1) === before color grading\n  if (uLUT1Enabled > 0.5) {\n    vec3 lut1Coord = clamp(color.rgb, 0.0, 1.0);\n    color.rgb = mix(color.rgb, texture(uLUT1, lut1Coord).rgb, uLUT1Intensity);\n  }\n\n  // Exposure\n  color.rgb *= pow(2.0, uExposure);\n\n  // Contrast\n  color.rgb = (color.rgb - 0.5) * uContrast + 0.5;\n\n  // Saturation\n  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n  color.rgb = mix(vec3(luma), color.rgb, uSaturation);\n\n  // Temperature\n  color.r += uTemperature * 0.1;\n  color.b -= uTemperature * 0.1;\n\n  // Tint (green / magenta axis)\n  color.r += uTint * 0.05;\n  color.g -= uTint * 0.08;\n  color.b += uTint * 0.05;\n\n  // Split toning\n  float lumST = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n  color.rgb += uShadowTint * (1.0 - lumST) * 0.18;\n  color.rgb += uHighlightTint * lumST * 0.18;\n\n  // Fade (Lift \u2014 \u30D5\u30A3\u30EB\u30E0\u306E\u300C\u6D6E\u3044\u305F\u9ED2\u300D)\n  color.rgb = color.rgb + uFade * (1.0 - color.rgb);\n\n  // Highlights / Shadows\n  float lumHS = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n  color.rgb += uShadows * (1.0 - lumHS) * 0.5;\n  color.rgb += uHighlights * lumHS * 0.5;\n\n  // Film Compression V3. Apply before LUT2 and downstream optical stages.\n  color.rgb = applyFilmCompression(color.rgb, uCompressionAmount, uCompressionRange);\n\n  // Shadow Latitude / toe separation. Apply before LUT2.\n  color.rgb = applyShadowLatitude(color.rgb, uShadowLatitude);\n\n  // === Creative LUT (LUT2) === after color grading\n  if (uLUT2Enabled > 0.5) {\n    vec3 lut2Coord = clamp(color.rgb, 0.0, 1.0);\n    color.rgb = mix(color.rgb, texture(uLUT2, lut2Coord).rgb, uLUT2Intensity);\n  }\n\n  // 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3002CMY \u306E\u8272\u304B\u3076\u308A\u3092\u8DB3\u3059\u3002\n  // C = -R, M = -G, Y = -B \u306E\u6697\u5BA4\u306E\u8003\u3048\u65B9\u306B\u5408\u308F\u305B\u308B\u3002\n  float cmyScale = 0.15;  // 1.0 \u3067\u304A\u3088\u305D 0.15 \u306E RGB \u5909\u5316\u306B\u3059\u308B\n  color.r -= uCyan    * cmyScale;\n  color.g -= uMagenta * cmyScale;\n  color.b -= uYellow  * cmyScale;\n\n  // 0.4.0 \u306E\u30D7\u30EA\u30F3\u30C8\u6BB5\u3002\u6700\u5F8C\u306B\u7D19\u306E\u786C\u3055\u3092\u8DB3\u3059\u3002\n  color.rgb = applyPrintContrast(color.rgb, uPrintContrast);\n\n  color.rgb = clamp(color.rgb, 0.0, 1.0);\n\n  if (uFitMode > 0.5) {\n    // Frosted glass background for letterbox areas (contain mode)\n    vec2 bgUv = bgCoverUv(vUv, uResolution, uImageResolution);\n    vec3 bgSample = textureLod(uTexture, bgUv, 3.0).rgb * 0.6\n                  + textureLod(uTexture, bgUv, 4.0).rgb * 0.4;\n\n    // Desaturate\n    float bgLuma = dot(bgSample, vec3(0.2126, 0.7152, 0.0722));\n    vec3 bgColor = mix(vec3(bgLuma), bgSample, 0.60);\n\n    // Brightness\n    bgColor *= 0.45;\n\n    // Minimum luminance floor (prevent pure black in dark scenes)\n    bgColor = max(bgColor, vec3(0.02));\n\n    // Background vignette (darken corners ~15%)\n    float bgDist = length(vUv - 0.5);\n    float bgVig = 1.0 - smoothstep(0.3, 0.85, bgDist);\n    bgColor *= mix(0.55, 1.0, bgVig);\n\n    // Blend: sharp image inside bounds, blurred background outside\n    fragColor = vec4(mix(bgColor, color.rgb, mask), 1.0);\n  } else {\n    fragColor = vec4(color.rgb, 1.0);\n  }\n}\n";

declare const bloomPrefilterFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform float uThreshold;\nuniform float uKnee;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec4 color = texture(uSource, vUv);\n  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n\n  // Soft knee: quadratic ramp around threshold\n  float knee = max(uKnee * uThreshold, 1e-4);\n  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);\n  float contribution = t * t * mix(knee, 1.0, t);\n\n  // For pixels clearly above threshold, use full overshoot\n  contribution = max(contribution, max(0.0, luma - uThreshold));\n\n  fragColor = vec4(color.rgb * contribution, 1.0);\n}\n";

declare const halationPrefilterFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec3 uHalationColor;\nuniform float uThreshold;\nuniform float uKnee;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec4 color = texture(uSource, vUv);\n  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));\n\n  float knee = max(uKnee * uThreshold, 1e-4);\n  float t = clamp((luma - uThreshold + knee) / (2.0 * knee), 0.0, 1.0);\n  float contribution = t * t * mix(knee, 1.0, t);\n\n  contribution = max(contribution, max(0.0, luma - uThreshold));\n\n  vec3 halation = color.rgb * contribution * uHalationColor;\n  fragColor = vec4(halation, 1.0);\n}\n";

declare const detailSoftnessFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uTexelSize;\nuniform float uEffectiveDetailSoftness;\nuniform float uKernelRadiusPx;\nuniform float uRangeSigma;\nuniform float uDetailAmplitudeLo;\nuniform float uDetailAmplitudeHi;\nuniform float uChromaAttenScale;\nuniform float uHighlightBias;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec4 center = texture(uSource, vUv);\n  if (uEffectiveDetailSoftness < 0.0001) {\n    fragColor = center;\n    return;\n  }\n\n  float r = max(uKernelRadiusPx, 0.0001);\n  float rd = r * 0.70710678;\n  vec2 dx = vec2(uTexelSize.x * r, 0.0);\n  vec2 dy = vec2(0.0, uTexelSize.y * r);\n  vec2 dD1 = vec2(uTexelSize.x * rd,  uTexelSize.y * rd);\n  vec2 dD2 = vec2(uTexelSize.x * rd, -uTexelSize.y * rd);\n\n  vec3 srcRGB = center.rgb;\n  vec3 nE  = texture(uSource, vUv + dx).rgb;\n  vec3 nW  = texture(uSource, vUv - dx).rgb;\n  vec3 nN  = texture(uSource, vUv + dy).rgb;\n  vec3 nS  = texture(uSource, vUv - dy).rgb;\n  vec3 nNE = texture(uSource, vUv + dD1).rgb;\n  vec3 nNW = texture(uSource, vUv - dD2).rgb;\n  vec3 nSE = texture(uSource, vUv + dD2).rgb;\n  vec3 nSW = texture(uSource, vUv - dD1).rgb;\n\n  vec3 lumaWeights = vec3(0.2126, 0.7152, 0.0722);\n  float lumaC  = dot(srcRGB, lumaWeights);\n  float sigma2 = max(uRangeSigma * uRangeSigma, 1e-6);\n\n  float dE  = dot(nE,  lumaWeights) - lumaC;\n  float dW  = dot(nW,  lumaWeights) - lumaC;\n  float dN  = dot(nN,  lumaWeights) - lumaC;\n  float dS  = dot(nS,  lumaWeights) - lumaC;\n  float dNE = dot(nNE, lumaWeights) - lumaC;\n  float dNW = dot(nNW, lumaWeights) - lumaC;\n  float dSE = dot(nSE, lumaWeights) - lumaC;\n  float dSW = dot(nSW, lumaWeights) - lumaC;\n\n  float wE  = exp(-(dE  * dE)  / sigma2);\n  float wW  = exp(-(dW  * dW)  / sigma2);\n  float wN  = exp(-(dN  * dN)  / sigma2);\n  float wS  = exp(-(dS  * dS)  / sigma2);\n  float wNE = exp(-(dNE * dNE) / sigma2);\n  float wNW = exp(-(dNW * dNW) / sigma2);\n  float wSE = exp(-(dSE * dSE) / sigma2);\n  float wSW = exp(-(dSW * dSW) / sigma2);\n\n  vec3 sumRGB = srcRGB\n    + nE  * wE  + nW  * wW  + nN  * wN  + nS  * wS\n    + nNE * wNE + nNW * wNW + nSE * wSE + nSW * wSW;\n  float sumW = 1.0\n    + wE + wW + wN + wS\n    + wNE + wNW + wSE + wSW;\n\n  vec3 referenceRgb = sumRGB / sumW;\n  vec3 detail = srcRGB - referenceRgb;\n\n  float detailLuma = dot(detail, lumaWeights);\n  vec3 detailLumaVec = detailLuma * lumaWeights;\n  vec3 detailChroma = detail - detailLumaVec;\n\n  float detailMag = abs(detailLuma);\n  float gate = 1.0 - smoothstep(uDetailAmplitudeLo, uDetailAmplitudeHi, detailMag);\n  float highlightWeight = mix(1.0, uHighlightBias, smoothstep(0.6, 0.9, lumaC));\n\n  float lumaAtten   = uEffectiveDetailSoftness * gate * highlightWeight;\n  float chromaAtten = lumaAtten * uChromaAttenScale;\n\n  vec3 softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);\n  fragColor = vec4(softened, center.a);\n}\n";

declare const downsampleFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uTexelSize;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvec2 mirrorUv(vec2 uv) {\n  vec2 tiled = mod(uv, 2.0);\n  return 1.0 - abs(tiled - 1.0);\n}\n\nvec4 sampleMirror(sampler2D tex, vec2 uv) {\n  return texture(tex, mirrorUv(uv));\n}\n\nvoid main() {\n  // 13-tap tent downsample (Jimenez, \"Next Generation Post Processing in CoD:AW\")\n  vec2 d = uTexelSize;\n\n  //  a . b . c\n  //  . d . e .\n  //  f . g . h\n  //  . i . j .\n  //  k . l . m\n\n  vec4 a = sampleMirror(uSource, vUv + vec2(-2.0 * d.x,  2.0 * d.y));\n  vec4 b = sampleMirror(uSource, vUv + vec2( 0.0,         2.0 * d.y));\n  vec4 c = sampleMirror(uSource, vUv + vec2( 2.0 * d.x,  2.0 * d.y));\n\n  vec4 dd = sampleMirror(uSource, vUv + vec2(-d.x,  d.y));\n  vec4 e  = sampleMirror(uSource, vUv + vec2( d.x,  d.y));\n\n  vec4 f = sampleMirror(uSource, vUv + vec2(-2.0 * d.x, 0.0));\n  vec4 g = sampleMirror(uSource, vUv);\n  vec4 h = sampleMirror(uSource, vUv + vec2( 2.0 * d.x, 0.0));\n\n  vec4 ii = sampleMirror(uSource, vUv + vec2(-d.x, -d.y));\n  vec4 j  = sampleMirror(uSource, vUv + vec2( d.x, -d.y));\n\n  vec4 k = sampleMirror(uSource, vUv + vec2(-2.0 * d.x, -2.0 * d.y));\n  vec4 l = sampleMirror(uSource, vUv + vec2( 0.0,        -2.0 * d.y));\n  vec4 m = sampleMirror(uSource, vUv + vec2( 2.0 * d.x, -2.0 * d.y));\n\n  // Weighted average: 5 quads of 4 bilinear taps\n  fragColor = (dd + e + ii + j) * 0.125\n            + g * 0.125\n            + (a + c + k + m) * 0.03125\n            + (b + f + h + l) * 0.0625;\n}\n";

declare const upsampleFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uTexelSize;\nuniform float uWeight;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvec2 mirrorUv(vec2 uv) {\n  vec2 tiled = mod(uv, 2.0);\n  return 1.0 - abs(tiled - 1.0);\n}\n\nvec4 sampleMirror(sampler2D tex, vec2 uv) {\n  return texture(tex, mirrorUv(uv));\n}\n\nvoid main() {\n  // 9-tap tent upsampling (3x3)\n  vec2 d = uTexelSize;\n\n  vec4 s  = sampleMirror(uSource, vUv);\n  vec4 s0 = sampleMirror(uSource, vUv + vec2(-d.x,  d.y));\n  vec4 s1 = sampleMirror(uSource, vUv + vec2( 0.0,  d.y));\n  vec4 s2 = sampleMirror(uSource, vUv + vec2( d.x,  d.y));\n  vec4 s3 = sampleMirror(uSource, vUv + vec2(-d.x,  0.0));\n  vec4 s4 = sampleMirror(uSource, vUv + vec2( d.x,  0.0));\n  vec4 s5 = sampleMirror(uSource, vUv + vec2(-d.x, -d.y));\n  vec4 s6 = sampleMirror(uSource, vUv + vec2( 0.0, -d.y));\n  vec4 s7 = sampleMirror(uSource, vUv + vec2( d.x, -d.y));\n\n  vec4 upsampled = s * 4.0\n                 + (s1 + s3 + s4 + s6) * 2.0\n                 + (s0 + s2 + s5 + s7) * 1.0;\n  upsampled /= 16.0;\n\n  // Output weighted contribution only \u2014 GL additive blending accumulates with existing RT data\n  fragColor = upsampled * uWeight;\n}\n";

/**
 * @fileoverview Film Lab Pass8 用フラグメントシェーダ（bloom / halation / vignette / grain / 分割）。
 * @description グレインは画像の cover 空間で径方向マスクを掛け、色収差 Pass1（rgbShiftSampleRadial）と同じ 1.65 べきで中心弱・周辺強にする。
 * uGrainRadialMix で一様（0）とフル径方向（1）をブレンドできる（Params.grainRadialMix、既定1）。
 * 色収差オン時の周辺ソフトは、混色量だけでなくブラー半径も少しだけ連動して増やす。
 * Params.lensSoftness（uLensSoftness）で rgbShift と独立に周辺の等方ブラーを足せる（Pro）。
 * 強度は控えめ（スライダー 100% でも周辺が潰れすぎないよう半径・混色を分離して足す）。
 * @limitations 分割表示時も vUv ベースでノイズを振る（従来どおり）。Remotion は本文字列を import 共有する。
 */
declare const compositeFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform sampler2D uBloomTexture;\nuniform sampler2D uHalationTexture;\nuniform sampler2D uDiffusionTexture;\nuniform sampler2D uOriginalTexture;\n\nuniform float uBloomStrength;\nuniform float uHalationIntensity;\nuniform float uDiffusion;\n\nuniform float uVignette;\nuniform float uGrainIntensity;\n/** 0=\u5F84\u65B9\u5411\u30DE\u30B9\u30AF\u7121\u3057\uFF08\u4E00\u69D8\uFF09\u30011=\u30D5\u30EB\u5468\u8FBA\u5F37\u3081\u3002mix(1.0, grainRadialWeight, clamp(\u5024,0,1)) \u306B\u7528\u3044\u308B */\nuniform float uGrainRadialMix;\n/** 0=\u6975\u7D30/\u5747\u4E00\u5BC4\u308A\u30011=\u6975\u7C97/\u30AF\u30E9\u30F3\u30D7\u5F37\u3081\u3002low-end fine grain \u3068 high-end coarse grain \u306E\u88DC\u9593\u306B\u4F7F\u3046 */\nuniform float uGrainSize;\nuniform float uTime;\n\nuniform float uSplitPosition;\n/** 0: Before/After\uFF08\u5DE6\u306F\u539F\u753B\u3092 coverUv \u3067\u30B5\u30F3\u30D7\u30EB\uFF09 / 1: A/B \u6BD4\u8F03\uFF08\u5DE6\u306F uOriginalTexture \u3092 vUv \u3067\u30B5\u30F3\u30D7\u30EB\uFF1D\u30B9\u30ED\u30C3\u30C8 A \u306E\u5168\u30D1\u30B9\u7D50\u679C\uFF09 */\nuniform float uAbCompare;\nuniform vec2 uResolution;\nuniform vec2 uImageResolution;\n/** \u8272\u53CE\u5DEE\u30AA\u30F3\u6642\u306E\u5468\u8FBA\u306E\u307F\u30B7\u30E3\u30FC\u30D7\u3068\u5FAE\u30D6\u30E9\u30FC\u3092\u6DF7\u305C\u308B\u91CF\uFF080\u301C1\u3001JS \u5074\u3067 rgbShift \u306B\u6BD4\u4F8B\u3002\u5927\u304D\u3044\u307B\u3069\u30D6\u30E9\u30FC\u534A\u5F84\u3082\u5C11\u3057\u5E83\u3052\u308B\uFF09 */\nuniform float uAberrationEdgeSoften;\n/** \u30EC\u30F3\u30BA\u306E\u5468\u8FBA\u30BD\u30D5\u30C8\uFF080\u301C1\u3001Params.lensSoftness\u3002\u8272\u53CE\u5DEE\u5468\u8FBA\u30BD\u30D5\u30C8\u3068\u306F\u5225\u5165\u529B\u3067\u5408\u6210\u3059\u308B\uFF09 */\nuniform float uLensSoftness;\nuniform float uFitMode;\n/** 1: \u30B0\u30EC\u30FC\u30C7\u30A3\u30F3\u30B0\u3092\u30B9\u30AD\u30C3\u30D7\u3057\u3001uSource(\u53F3) \u3068 uOriginalTexture(\u5DE6) \u306E\u30B9\u30D7\u30EA\u30C3\u30C8\u306E\u307F\u5B9F\u884C */\nuniform float uSplitOnly;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvec2 fitUv(vec2 uv, vec2 resolution, vec2 imageResolution) {\n  float screenAspect = resolution.x / resolution.y;\n  float imageAspect = imageResolution.x / imageResolution.y;\n  vec2 coverScale = screenAspect > imageAspect\n    ? vec2(1.0, imageAspect / screenAspect)\n    : vec2(screenAspect / imageAspect, 1.0);\n  vec2 containScale = screenAspect > imageAspect\n    ? vec2(screenAspect / imageAspect, 1.0)\n    : vec2(1.0, imageAspect / screenAspect);\n  vec2 scale = mix(coverScale, containScale, uFitMode);\n  vec2 result = (uv - 0.5) * scale + 0.5;\n  float narrowPortrait = step(2.0, scale.x) * uFitMode;\n  result.x += 0.18 * scale.x * narrowPortrait;\n  return result;\n}\n\nfloat insideUv(vec2 uv) {\n  vec2 s = step(0.0, uv) * step(uv, vec2(1.0));\n  return s.x * s.y;\n}\n\n// --- Film Grain: low-end fine grain + high-end clumped silver-halide hybrid ---\n\n// Per-pixel hash: sharp, random, no grid artifacts \u2014 like actual silver halide crystals.\nfloat grainPixelHash(vec2 p, float seed) {\n  return fract(sin(dot(p + seed, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;\n}\n\n// Low-frequency smooth noise for grain density modulation (clumping).\n// Value noise is fine here because the scale is large (20-80px per cell) \u2014\n// grid artifacts are invisible at this frequency.\nfloat grainClumpHash(vec2 p) {\n  vec3 p3 = fract(vec3(p.xyx) * 0.1031);\n  p3 += dot(p3, p3.yzx + 33.33);\n  return fract((p3.x + p3.y) * p3.z);\n}\n\nfloat grainClumpNoise(vec2 p) {\n  vec2 i = floor(p);\n  vec2 f = fract(p);\n  f = f * f * (3.0 - 2.0 * f);\n  float a = grainClumpHash(i);\n  float b = grainClumpHash(i + vec2(1.0, 0.0));\n  float c = grainClumpHash(i + vec2(0.0, 1.0));\n  float d = grainClumpHash(i + vec2(1.0, 1.0));\n  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);\n}\n\nvec2 grainRotate(vec2 p, float angle) {\n  float s = sin(angle);\n  float c = cos(angle);\n  return vec2(p.x * c - p.y * s, p.x * s + p.y * c);\n}\n\nfloat grainFineNoise(vec2 p, float fineScale, float seedA, float seedB) {\n  vec2 q0 = grainRotate(p * fineScale + vec2(seedA * 0.37, seedB * 0.19), 0.61);\n  vec2 q1 = grainRotate(\n    p * (fineScale * 1.41) + vec2(seedB * 0.23 + 17.0, seedA * 0.41 + 9.0),\n    -0.73\n  );\n  float n0 = grainClumpNoise(q0) - 0.5;\n  float n1 = grainClumpNoise(q1) - 0.5;\n  return mix(n0, n1, 0.42);\n}\n\n// Convert arbitrary glow energy into a bounded screen-blend opacity.\n// Low values stay close to linear, while hot highlight cores compress softly\n// so large radius / high strength can keep their spread without turning into\n// flat white plates.\nvec3 glowShoulder(vec3 energy) {\n  return 1.0 - exp(-max(energy, vec3(0.0)));\n}\n\nfloat glowHeadroom(vec3 baseRgb, float floorValue) {\n  float luma = dot(baseRgb, vec3(0.2126, 0.7152, 0.0722));\n  return mix(floorValue, 1.0, sqrt(clamp(1.0 - luma, 0.0, 1.0)));\n}\n\nvoid main() {\n  // Split-only \u30E2\u30FC\u30C9: post-composite chain\uFF08\u30E2\u30FC\u30B7\u30E7\u30F3\u30D6\u30E9\u30FC\u7B49\uFF09\u9069\u7528\u5F8C\u306B\u30B9\u30D7\u30EA\u30C3\u30C8\u3092\u884C\u3046\u3002\n  // uSource \u306B\u306F\u30D6\u30E9\u30FC\u6E08\u307F\u30B0\u30EC\u30FC\u30C7\u30A3\u30F3\u30B0\u51FA\u529B\u3001uOriginalTexture \u306B\u306F\u539F\u753B\u304C\u5165\u308B\u3002\n  if (uSplitOnly > 0.5) {\n    vec2 origUv = fitUv(vUv, uResolution, uImageResolution);\n    float splitMask = insideUv(origUv);\n    vec4 leftSample = texture(uOriginalTexture, origUv);\n    vec4 rightSample = texture(uSource, vUv);\n    float lineWidth = 2.0 / uResolution.x;\n\n    if (vUv.x < uSplitPosition - lineWidth) {\n      fragColor = mix(rightSample, leftSample, splitMask);\n    } else if (vUv.x < uSplitPosition + lineWidth) {\n      fragColor = vec4(vec3(1.0), rightSample.a) * splitMask + rightSample * (1.0 - splitMask);\n    } else {\n      fragColor = rightSample;\n    }\n    return;\n  }\n\n  // \u5468\u8FBA\u3060\u3051\u3054\u304F\u5F31\u3044\u30D6\u30E9\u30FC\uFF08\u8272\u53CE\u5DEE\u3068\u4F75\u305B\u305F\u30D5\u30A3\u30EB\u30E0\u7684\u5468\u8FBA\u67D4\u3089\u304B\u3055\uFF09\u3002\n  // \u8272\u53CE\u5DEE\u304C\u5F37\u3044\u307B\u3069\u3001\u6DF7\u8272\u91CF\u306B\u52A0\u3048\u3066\u30B5\u30F3\u30D7\u30EB\u534A\u5F84\u3082\u5C11\u3057\u3060\u3051\u5E83\u3052\u308B\u3002\n  vec2 edgeDelta = vUv - 0.5;\n  edgeDelta.x *= uResolution.x / max(uResolution.y, 1.0);\n  float edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);\n  float edgeMask = smoothstep(0.25, 1.0, edgeR);\n  vec3 sharpRgb = texture(uSource, vUv).rgb;\n  // \u30EC\u30F3\u30BA\u67D4\u3089\u304B\u3055: \u5468\u8FBA\u307B\u3069\u52B9\u304F\u3002\u3079\u304D\u3092\u4E0B\u3052\u308B\u3068\u5185\u5BC4\u308A\u306B\u3082\u52B9\u304D\u3001\u30B9\u30E9\u30A4\u30C0\u30FC\u304C\u300C\u5F31\u3044\u300D\u3068\u8A00\u308F\u308C\u305F\u3068\u304D\u306E\u8996\u8A8D\u6027\u304C\u4E0A\u304C\u308B\u3002\n  float lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);\n  float lensW = pow(lensR, 1.52);\n  // \u03B3 \u3092\u4E0B\u3052\u308B\u307B\u3069\u4E2D\u9593\u30B9\u30E9\u30A4\u30C0\u30FC\u3067\u3082\u5F37\u304F\u898B\u3048\u308B\uFF08\u6700\u5927 1.0 \u306F\u7DAD\u6301\uFF09\u3002\n  float lensDrive = pow(clamp(uLensSoftness, 0.0, 1.0), 0.78);\n  float lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);\n  float aberrAmt = clamp(uAberrationEdgeSoften, 0.0, 1.0);\n  // 8 \u30BF\u30C3\u30D7\u306E\u307E\u307E\u534A\u5F84\u30FB\u6DF7\u8272\u3092\u4E0A\u3052\u308B\uFF08\u521D\u7248\u306E 4px \u5F35\u308A\u4ED8\u304D\u3088\u308A\u306F cap \u3042\u308A\uFF09\u3002\n  float blurRadiusPx =\n    mix(1.5, 2.75, aberrAmt) + lensWeight * 1.35;\n  blurRadiusPx = min(blurRadiusPx, 4.2);\n  vec2 px =\n    vec2(1.0 / max(uResolution.x, 1.0), 1.0 / max(uResolution.y, 1.0)) *\n    blurRadiusPx;\n  // \u5341\u5B57 4 \u30BF\u30C3\u30D7\u3060\u3051\u3060\u3068 HV \u65B9\u5411\u306B\u632F\u308C\u3001\u7D30\u304B\u3044\u7E1E\u3084\u8449\u3067 X \u5B57\u3063\u307D\u3044\u30E2\u30A2\u30EC\u304C\u51FA\u3084\u3059\u3044\u3002\n  // \u659C\u3081 4 \u70B9\u3092\u8DB3\u3057\u3066 8 \u65B9\u5411\u5E73\u5747\u306B\u3057\u3001\u7B49\u65B9\u6027\u3092\u4E0A\u3052\u308B\uFF08\u534A\u5F84\u306F 1/\u221A2 \u30B9\u30B1\u30FC\u30EB\u3067\u30AB\u30FC\u30C9\u30CA\u30EB\u3068\u63C3\u3048\u308B\uFF09\u3002\n  vec2 d = px * 0.70710678;\n  vec3 blurRgb =\n    (texture(uSource, vUv + vec2(px.x, 0.0)).rgb +\n     texture(uSource, vUv - vec2(px.x, 0.0)).rgb +\n     texture(uSource, vUv + vec2(0.0, px.y)).rgb +\n     texture(uSource, vUv - vec2(0.0, px.y)).rgb +\n     texture(uSource, vUv + vec2(d.x, d.y)).rgb +\n     texture(uSource, vUv + vec2(d.x, -d.y)).rgb +\n     texture(uSource, vUv + vec2(-d.x, d.y)).rgb +\n     texture(uSource, vUv + vec2(-d.x, -d.y)).rgb) *\n    0.125;\n  // \u6DF7\u8272\u306F\u8272\u53CE\u5DEE\u3068\u540C\u3058\u304F edgeMask\u3002\n  float lensMix = lensWeight * 0.72;\n  float softenAmt = clamp(uAberrationEdgeSoften * edgeMask + lensMix * edgeMask, 0.0, 1.0);\n  vec4 color = vec4(mix(sharpRgb, blurRgb, softenAmt), texture(uSource, vUv).a);\n  vec3 baseRgb = color.rgb;\n\n  // Bloom + Halation screen blend with a soft shoulder.\n  // This preserves wide glow tails at high radius while compressing hot cores.\n  vec3 bloom = texture(uBloomTexture, vUv).rgb * uBloomStrength;\n  vec3 halation = texture(uHalationTexture, vUv).rgb * uHalationIntensity;\n  vec3 glow = glowShoulder(bloom + halation) * glowHeadroom(baseRgb, 0.82);\n  color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - glow);\n\n  // --- Diffusion: Pro-Mist / Cinebloom full-image light scattering ---\n  // Screen blend of blurred full image at controllable opacity.\n  // The 0.45 multiplier prevents over-brightening at diffusion=1.0.\n  // Unlike bloom (highlights only), diffusion scatters ALL light \u2014 creating\n  // a soft haze that reduces contrast while preserving sharpness.\n  if (uDiffusion > 0.0) {\n    vec3 diffused = texture(uDiffusionTexture, vUv).rgb;\n    vec3 diffOpacity = glowShoulder(diffused * uDiffusion * 0.29) * glowHeadroom(baseRgb, 0.88);\n    vec3 diffScreen = 1.0 - (1.0 - color.rgb) * (1.0 - diffOpacity);\n    color.rgb = diffScreen;\n  }\n\n  // Vignette in image space (follows image frame, not screen edges)\n  vec2 vigUv = fitUv(vUv, uResolution, uImageResolution);\n  float vigMask = insideUv(vigUv);\n  float dist = length((vigUv - 0.5)) * 1.414;\n  float vig = 1.0 - uVignette * dist * dist;\n  color.rgb *= mix(1.0, clamp(vig, 0.0, 1.0), vigMask);\n\n  // Radial weight (unchanged logic \u2014 center weak, edge strong)\n  vec2 grainCenterUv = fitUv(vUv, uResolution, uImageResolution);\n  float grainBoundaryMask = insideUv(grainCenterUv);\n  vec2 grainDelta = grainCenterUv - 0.5;\n  grainDelta.x *= uImageResolution.x / max(uImageResolution.y, 1.0);\n  float grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);\n  float grainRadialWeight = pow(grainRadial, 1.65);\n  float grainRadialEffective = mix(1.0, grainRadialWeight, clamp(uGrainRadialMix, 0.0, 1.0));\n\n  float grainSizeClamped = clamp(uGrainSize, 0.0, 1.0);\n  float coarseBlend = smoothstep(0.08, 0.28, grainSizeClamped);\n\n  // Temporal stepping stays deterministic for preview/export parity. Fine grain\n  // holds slightly longer than coarse grain so the low end reads calmer.\n  float grainFrame = floor(uTime * mix(2.0, 3.0, coarseBlend));\n\n  vec2 pixCoord = vUv * uResolution;\n  vec2 fineWarp = vec2(\n    grainClumpNoise(pixCoord / 96.0 + vec2(11.7, grainFrame * 0.07 + 3.1)),\n    grainClumpNoise(pixCoord / 96.0 + vec2(grainFrame * 0.09 + 5.3, 23.4))\n  ) - 0.5;\n  vec2 fineCoord = pixCoord + fineWarp * 1.45;\n  float fineScale = mix(1.75, 1.05, smoothstep(0.0, 0.25, grainSizeClamped));\n  float fineLuma = grainFineNoise(\n    fineCoord,\n    fineScale,\n    grainFrame * 1.13 + 7.0,\n    grainFrame * 1.71 + 19.0\n  );\n  float fineChromaStrength = mix(0.035, 0.16, smoothstep(0.02, 0.24, grainSizeClamped));\n  float fineChromaR = grainFineNoise(\n    fineCoord + vec2(17.0, 0.0),\n    fineScale * 1.07,\n    grainFrame * 1.37 + 41.0,\n    grainFrame * 1.91 + 67.0\n  ) * fineChromaStrength;\n  float fineChromaB = grainFineNoise(\n    fineCoord + vec2(0.0, 19.0),\n    fineScale * 1.11,\n    grainFrame * 1.53 + 83.0,\n    grainFrame * 2.07 + 109.0\n  ) * fineChromaStrength;\n\n  // Coarse path preserves the existing sharp per-pixel silver-halide character.\n  float coarseLuma = grainPixelHash(pixCoord, grainFrame * 1.7);\n  float coarseChromaR = grainPixelHash(pixCoord, grainFrame * 2.3 + 500.0) * 0.3;\n  float coarseChromaB = grainPixelHash(pixCoord, grainFrame * 3.1 + 1000.0) * 0.3;\n\n  // Low-end grain now changes actual frequency/distribution instead of only\n  // clump density. High-end stays on the existing cluster-driven path.\n  float fineDensity = mix(\n    0.92,\n    1.08,\n    grainClumpNoise(pixCoord / 180.0 + vec2(grainFrame * 0.11, 31.0))\n  );\n  float clumpScale = mix(80.0, 20.0, grainSizeClamped);\n  float coarseClump = grainClumpNoise(pixCoord / clumpScale + vec2(grainFrame * 0.5));\n  float coarseDensity = mix(1.0, 0.3 + coarseClump * 1.4, grainSizeClamped * 0.7);\n  float densityMod = mix(fineDensity, coarseDensity, coarseBlend);\n\n  float lumaGrain = mix(fineLuma, coarseLuma, coarseBlend);\n  float chromaR = mix(fineChromaR, coarseChromaR, coarseBlend);\n  float chromaB = mix(fineChromaB, coarseChromaB, coarseBlend);\n  float lowEndPresence = mix(1.06, 1.0, coarseBlend);\n\n  float w = uGrainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask * lowEndPresence;\n  color.r += (lumaGrain + chromaR) * w * densityMod;\n  color.g += lumaGrain * w * densityMod;\n  color.b += (lumaGrain + chromaB) * w * densityMod;\n  color.rgb = clamp(color.rgb, 0.0, 1.0);\n\n  // Before/After \u307E\u305F\u306F A/B \u6BD4\u8F03\u306E\u5206\u5272\n  vec2 origUv = fitUv(vUv, uResolution, uImageResolution);\n  float splitMask = insideUv(origUv);\n  vec4 leftSample = uAbCompare > 0.5\n    ? texture(uOriginalTexture, vUv)\n    : texture(uOriginalTexture, origUv);\n  float lineWidth = 2.0 / uResolution.x;\n\n  if (vUv.x < uSplitPosition - lineWidth) {\n    // Letterbox area: use graded output (which has blurred background)\n    fragColor = mix(color, leftSample, splitMask);\n  } else if (vUv.x < uSplitPosition + lineWidth) {\n    // Split line: only show inside image area\n    fragColor = vec4(vec3(1.0), color.a) * splitMask + color * (1.0 - splitMask);\n  } else {\n    fragColor = color;\n  }\n}\n";

/**
 * Motion blur shader — N-frame ring buffer weighted average
 * with inline motion detection (branchless oldest-frame selection).
 *
 * CPU supplies pre-normalized weights (sum=1.0 for active slots)
 * and uActiveFrames (1..8).
 */
declare const motionblurFragmentShader = "\nprecision highp float;\n\n// Ring buffer samplers: 0=newest, 7=oldest\nuniform sampler2D uFrame0;\nuniform sampler2D uFrame1;\nuniform sampler2D uFrame2;\nuniform sampler2D uFrame3;\nuniform sampler2D uFrame4;\nuniform sampler2D uFrame5;\nuniform sampler2D uFrame6;\nuniform sampler2D uFrame7;\n\n// Pre-normalized weights from CPU (sum=1.0 for active slots)\nuniform float uWeight0;\nuniform float uWeight1;\nuniform float uWeight2;\nuniform float uWeight3;\nuniform float uWeight4;\nuniform float uWeight5;\nuniform float uWeight6;\nuniform float uWeight7;\n\nuniform int uActiveFrames;      // 1..8\nuniform float uMotionThreshold; // 0.0=disabled, 0.02-0.05=recommended\n\nin vec2 vUv;\nout vec4 fragColor;\n\nfloat luma709(vec3 c) {\n  return dot(c, vec3(0.2126, 0.7152, 0.0722));\n}\n\nvoid main() {\n  vec4 f0 = texture(uFrame0, vUv);\n  vec4 f1 = texture(uFrame1, vUv);\n  vec4 f2 = texture(uFrame2, vUv);\n  vec4 f3 = texture(uFrame3, vUv);\n  vec4 f4 = texture(uFrame4, vUv);\n  vec4 f5 = texture(uFrame5, vUv);\n  vec4 f6 = texture(uFrame6, vUv);\n  vec4 f7 = texture(uFrame7, vUv);\n\n  // Weighted average\n  vec4 blurred =\n    f0 * uWeight0 + f1 * uWeight1 + f2 * uWeight2 + f3 * uWeight3 +\n    f4 * uWeight4 + f5 * uWeight5 + f6 * uWeight6 + f7 * uWeight7;\n\n  // Inline motion detection: branchless oldest frame selection\n  float af = float(uActiveFrames);\n  vec4 oldest = f0;\n  oldest = mix(oldest, f1, step(2.0, af));\n  oldest = mix(oldest, f2, step(3.0, af));\n  oldest = mix(oldest, f3, step(4.0, af));\n  oldest = mix(oldest, f4, step(5.0, af));\n  oldest = mix(oldest, f5, step(6.0, af));\n  oldest = mix(oldest, f6, step(7.0, af));\n  oldest = mix(oldest, f7, step(8.0, af));\n\n  float lumaDelta = abs(luma709(f0.rgb) - luma709(oldest.rgb));\n  float motionMask = (uMotionThreshold > 0.0)\n    ? smoothstep(uMotionThreshold * 0.5, uMotionThreshold * 2.0, lumaDelta)\n    : 1.0;\n\n  fragColor = mix(f0, blurred, motionMask);\n}\n";

declare const dustFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform sampler2D uDustTexture;\nuniform sampler2D uScratchTexture;\nuniform float uDustAmount;\nuniform float uScratchAmount;\nuniform float uTime;\nuniform vec2 uResolution;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec4 color = texture(uSource, vUv);\n\n  if (uDustAmount > 0.0) {\n    vec2 dustUv = vUv * 3.0 + vec2(uTime * 0.02, uTime * 0.015);\n    float dust = texture(uDustTexture, dustUv).r;\n    vec2 dustUv2 = vUv * 1.7 + vec2(-uTime * 0.013, uTime * 0.009);\n    float dust2 = texture(uDustTexture, dustUv2).r;\n    float dustCombined = max(dust, dust2 * 0.7);\n    vec3 dustColor = vec3(dustCombined * uDustAmount);\n    // Screen blend: 1 - (1 - base) * (1 - overlay)\n    color.rgb = 1.0 - (1.0 - color.rgb) * (1.0 - dustColor);\n  }\n\n  if (uScratchAmount > 0.0) {\n    float jitterPhase = floor(uTime * 4.0);\n    vec2 scratchUv = vec2(vUv.x * 2.0, vUv.y * 0.5 + jitterPhase * 0.37);\n    float scratch = texture(uScratchTexture, scratchUv).r;\n    // Additive blend\n    color.rgb += vec3(scratch * uScratchAmount * 0.6);\n  }\n\n  color.rgb = clamp(color.rgb, 0.0, 1.0);\n  fragColor = color;\n}\n";

declare const lightshaftsFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uLightOrigin;\nuniform float uDecay;\nuniform float uDensity;\nuniform float uExposure;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nconst int NUM_SAMPLES = 64;\nconst float LUMINANCE_THRESHOLD = 0.65;\n\nvoid main() {\n  vec2 deltaUv = vUv - uLightOrigin;\n  deltaUv *= 1.0 / float(NUM_SAMPLES) * uDensity;\n\n  vec2 sampleUv = vUv;\n  vec4 accum = vec4(0.0);\n  float illuminationDecay = 1.0;\n\n  for (int i = 0; i < NUM_SAMPLES; i++) {\n    sampleUv -= deltaUv;\n    vec4 s = texture(uSource, clamp(sampleUv, 0.0, 1.0));\n    float luma = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722));\n    float contribution = smoothstep(LUMINANCE_THRESHOLD - 0.05, LUMINANCE_THRESHOLD + 0.05, luma);\n    s.rgb *= contribution;\n    s *= illuminationDecay;\n    accum += s;\n    illuminationDecay *= uDecay;\n  }\n\n  accum /= float(NUM_SAMPLES);\n  fragColor = vec4(accum.rgb * uExposure, 1.0);\n}\n";

declare const lightshaftsBlendFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform sampler2D uShaftTexture;\nuniform float uIntensity;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec3 scene = texture(uSource, vUv).rgb;\n  vec3 shafts = texture(uShaftTexture, vUv).rgb;\n  vec3 result = scene + shafts * uIntensity;\n  fragColor = vec4(clamp(result, 0.0, 1.0), 1.0);\n}\n";

declare const crossFilterStreakFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uDirection;\nuniform vec2 uTexelSize;\nuniform float uLength;\nuniform float uChromatic;\nuniform float uBrightnessMul;\nuniform float uRandomness;\nuniform float uHardMode;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nconst int MAX_STREAK_PX = 64;\nconst float FALLOFF_K_SOFT  = 4.0;\nconst float FALLOFF_K_HARD  = 2.0;\nconst float STREAK_GAIN_SOFT = 2.5;\nconst float STREAK_GAIN_HARD = 6.0;\nconst float PEAK_THRESHOLD_SOFT = 0.01;\nconst float PEAK_THRESHOLD_HARD = 0.005;\nconst float CHROMA_HARD_FLOOR = 0.7;\n\n// Wavelength dispersion spectrum.\n// t = 0.0 -> near peak (warm: red/orange)  \u2014 matches reference \"\u8D64->\u6A59->\u9EC4->\u7DD1->\u9752\"\n// t = 0.5 -> mid streak (green/yellow)\n// t = 1.0 -> far tip (cool: blue/violet)\n// uChromatic = 0: white streak, uChromatic = 1: full rainbow\nvec3 wavelengthToRGB(float t) {\n  vec3 c;\n  c.r = clamp(1.0 - t * 2.0, 0.0, 1.0);\n  c.g = clamp(1.0 - abs(t - 0.45) * 3.2, 0.0, 1.0);\n  c.b = clamp((t - 0.45) * 3.0, 0.0, 1.0);\n  float maxC = max(c.r, max(c.g, c.b));\n  return c / max(maxC, 1e-4);\n}\n\nvoid main() {\n  // Phase 6: Hard Mode interpolated constants. uHardMode is always 0.0 (Soft) or 1.0 (Hard).\n  // mix(softVal, hardVal, 0.0) = softVal \u2192 byte-for-byte Phase 5 backward compat.\n  // MAX_STREAK_PX is restored to Phase 5 value (64) so Soft Mode behavior is bit-identical.\n  // Hard Mode's \"more dramatic\" character comes from gain/falloff/threshold/bloom/tone-mapping\n  // changes \u2014 NOT from longer streak marches (which would cause UV wrap on smaller images).\n  float falloffK    = mix(FALLOFF_K_SOFT, FALLOFF_K_HARD, uHardMode);\n  float streakGain  = mix(STREAK_GAIN_SOFT, STREAK_GAIN_HARD, uHardMode);\n  float peakThresh  = mix(PEAK_THRESHOLD_SOFT, PEAK_THRESHOLD_HARD, uHardMode);\n  float chromaEffective = mix(uChromatic, max(uChromatic, CHROMA_HARD_FLOOR), uHardMode);\n\n  int maxSteps = int(uLength * float(MAX_STREAK_PX));\n  maxSteps = clamp(maxSteps, 1, MAX_STREAK_PX);\n\n  // Forward: march in -uDirection to find peaks that cast a streak through this pixel\n  vec3 resultFwd = vec3(0.0);\n  for (int i = 1; i <= MAX_STREAK_PX; i++) {\n    if (i > maxSteps) break;\n    vec2 sampleUV = vUv - uDirection * uTexelSize * float(i);\n    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));\n    if (peakLuma > peakThresh) {\n      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);\n      if (peakHash > uRandomness) break;\n      float t = float(i) / float(maxSteps);\n      float falloff = exp(-float(i) * falloffK / float(maxSteps));\n      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);\n      resultFwd = peakLuma * tint * falloff;\n      break;\n    }\n  }\n\n  // Backward: march in +uDirection to find peaks that cast a streak through this pixel\n  vec3 resultBwd = vec3(0.0);\n  for (int i = 1; i <= MAX_STREAK_PX; i++) {\n    if (i > maxSteps) break;\n    vec2 sampleUV = vUv + uDirection * uTexelSize * float(i);\n    float peakLuma = dot(texture(uSource, sampleUV).rgb, vec3(0.2126, 0.7152, 0.0722));\n    if (peakLuma > peakThresh) {\n      float peakHash = fract(sin(dot(floor(sampleUV / uTexelSize), vec2(127.1, 311.7))) * 43758.5453);\n      if (peakHash > uRandomness) break;\n      float t = float(i) / float(maxSteps);\n      float falloff = exp(-float(i) * falloffK / float(maxSteps));\n      vec3 tint = mix(vec3(1.0), wavelengthToRGB(t), chromaEffective);\n      resultBwd = peakLuma * tint * falloff;\n      break;\n    }\n  }\n\n  vec3 result = resultFwd + resultBwd;\n  // Soft: Reinhard rolloff (= original Phase 5 behavior).\n  // Hard: linear amplification \u2192 blown-out centers.\n  vec3 toneSoft = 1.0 - exp(-result * streakGain * uBrightnessMul);\n  vec3 toneHard = result * streakGain * uBrightnessMul;\n  result = mix(toneSoft, toneHard, uHardMode);\n  fragColor = vec4(result, 1.0);\n}\n";

declare const crossFilterStreakDensityFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uTexelSize;\nuniform vec2 uDirection;\nuniform float uMinSpacing;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nconst int DENSITY_SAMPLES = 32;\nconst float DENSITY_RADIUS_MAX = 96.0;  // texels at half-res\nconst float SELF_GAP = 2.0;\nconst int TANGENT_HALF_WIDTH = 2;\nconst float CROWD_GAIN = 8.0;\n\nfloat sampleBandMax(sampler2D tex, vec2 uv, vec2 tangentStep) {\n  float bandMax = 0.0;\n  for (int j = -TANGENT_HALF_WIDTH; j <= TANGENT_HALF_WIDTH; j++) {\n    vec2 sampleUv = uv + tangentStep * float(j);\n    float lum = dot(texture(tex, sampleUv).rgb, vec3(0.2126, 0.7152, 0.0722));\n    bandMax = max(bandMax, lum);\n  }\n  return bandMax;\n}\n\nvoid main() {\n  vec3 center = texture(uSource, vUv).rgb;\n  float centerLuma = dot(center, vec3(0.2126, 0.7152, 0.0722));\n  if (centerLuma <= 1e-4) {\n    fragColor = vec4(center, 1.0);\n    return;\n  }\n\n  vec2 tangent = normalize(uDirection);\n  vec2 normal = normalize(vec2(-uDirection.y, uDirection.x));\n  vec2 tangentStep = tangent * uTexelSize;\n  float radius = max(SELF_GAP, uMinSpacing * DENSITY_RADIUS_MAX);\n\n  float neighborMax = 0.0;\n  for (int i = 0; i < DENSITY_SAMPLES; i++) {\n    float t = (float(i) + 0.5) / float(DENSITY_SAMPLES);\n    float d = mix(SELF_GAP, radius, t);\n    vec2 offset = normal * d * uTexelSize;\n    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv + offset, tangentStep));\n    neighborMax = max(neighborMax, sampleBandMax(uSource, vUv - offset, tangentStep));\n  }\n\n  float crowd = neighborMax / centerLuma;\n  float keep = 1.0 / (1.0 + crowd * CROWD_GAIN);\n  float factor = mix(1.0, keep, step(0.001, uMinSpacing));\n\n  fragColor = vec4(center * factor, 1.0);\n}\n";

declare const crossFilterBlendFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform sampler2D uStreak0;\nuniform sampler2D uStreak1;\nuniform sampler2D uStreak2;\nuniform sampler2D uStreak3;\nuniform sampler2D uCentralBloom;\nuniform int uStreakCount;\nuniform float uIntensity;\nuniform float uHardMode;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nvoid main() {\n  vec4 original = texture(uSource, vUv);\n  vec3 streaks = texture(uStreak0, vUv).rgb + texture(uStreak1, vUv).rgb;\n  if (uStreakCount > 2) streaks += texture(uStreak2, vUv).rgb;\n  if (uStreakCount > 3) streaks += texture(uStreak3, vUv).rgb;\n  streaks /= float(uStreakCount);\n\n  // Phase 6: Hard Mode central bloom contribution.\n  // uHardMode = 0.0 \u2192 bloom term is exactly vec3(0.0) \u2192 byte-for-byte Phase 5 backward compat.\n  // uHardMode = 1.0 \u2192 adds blurred peak halo for the \"thick base, soft glow\" reference look.\n  vec3 bloom = texture(uCentralBloom, vUv).rgb * uHardMode * 1.5;\n\n  // Phase 7: Highlight Protection Mask (Hard Mode only).\n  // Bright pixels in the original (light source centers) get the streak/bloom overlay attenuated\n  // to prevent double-bright blow-out. uHardMode=0 \u2192 centerProtect=1.0 \u2192 Phase 6 unchanged.\n  float origLuma = dot(original.rgb, vec3(0.2126, 0.7152, 0.0722));\n  float centerProtect = mix(1.0, 1.0 - smoothstep(0.65, 0.95, origLuma), uHardMode);\n\n  vec3 overlay = (streaks + bloom) * uIntensity * centerProtect;\n\n  // Additive blend: preserves dark areas exactly (no shadow lifting).\n  // Soft Reinhard rolloff on excess prevents harsh highlight clipping.\n  vec3 combined = original.rgb + overlay;\n  vec3 excess = max(combined - 1.0, vec3(0.0));\n  vec3 result = combined - excess + excess / (1.0 + excess * 2.0);\n\n  fragColor = vec4(result, original.a);\n}\n";

declare const crossFilterPeakFragmentShader = "\nprecision highp float;\n\nuniform sampler2D uSource;\nuniform vec2 uTexelSize;\nuniform float uSizeLimit;\n\nin vec2 vUv;\nout vec4 fragColor;\n\nconst int RING_SAMPLES = 16;\nconst float RING_RADIUS = 24.0;\nconst int NEIGHBOR_SAMPLES = 16;\nconst float NEIGHBOR_RADIUS = 8.0;\nconst float NEIGHBOR_THRESHOLD = 0.01;\n\nvoid main() {\n  vec4 center = texture(uSource, vUv);\n  float centerLuma = dot(center.rgb, vec3(0.2126, 0.7152, 0.0722));\n\n  float avgLuma = 0.0;\n  for (int i = 0; i < RING_SAMPLES; i++) {\n    float angle = float(i) * (6.28318 / float(RING_SAMPLES));\n    vec2 offset = vec2(cos(angle), sin(angle)) * RING_RADIUS * uTexelSize;\n    avgLuma += dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));\n  }\n  avgLuma /= float(RING_SAMPLES);\n\n  float peakness = centerLuma - avgLuma;\n\n  float neighborCount = 0.0;\n  for (int i = 0; i < NEIGHBOR_SAMPLES; i++) {\n    float angle = float(i) * (6.28318 / float(NEIGHBOR_SAMPLES));\n    vec2 offset = vec2(cos(angle), sin(angle)) * NEIGHBOR_RADIUS * uTexelSize;\n    float lum = dot(texture(uSource, vUv + offset).rgb, vec3(0.2126, 0.7152, 0.0722));\n    neighborCount += step(NEIGHBOR_THRESHOLD, lum);\n  }\n\n  float maxNeighbors = mix(float(NEIGHBOR_SAMPLES), 1.0, uSizeLimit);\n  float densityFactor = 1.0 - smoothstep(maxNeighbors, maxNeighbors + 2.0, neighborCount);\n\n  float factor = smoothstep(0.0, 0.2, peakness) * densityFactor;\n\n  fragColor = center * factor;\n}\n";

export { LIKELY_VIDEO_EXTENSION, type LoadFileOptions, type LoadResult, MediaLoadError, MediaLoader, RenderBackend, Viewport, type ViewportBackendPreference, ViewportCapabilities, ViewportContextLossInfo, type ViewportCreateOptions, type ViewportOptions, WebGLBackend, bloomPrefilterFragmentShader, compositeFragmentShader, crossFilterBlendFragmentShader, crossFilterPeakFragmentShader, crossFilterStreakDensityFragmentShader, crossFilterStreakFragmentShader, detailSoftnessFragmentShader, downsampleFragmentShader, dustFragmentShader, filmlabFragmentShader, filmlabVertexShader, getOptimalPixelRatio, halationPrefilterFragmentShader, isFilmLabMediaDebugEnabled, isLikelyHeicFile, isWebGL2Supported, isWebGPUSupported, lightshaftsBlendFragmentShader, lightshaftsFragmentShader, motionblurFragmentShader, upsampleFragmentShader };
