import { V as ViewportCapabilities, a as ViewportContextLossInfo, e as ViewportContextLossListener, d as ViewportContextLossReason, R as RenderBackend, c as RenderBackendParams } from './RendererRuntime-DfZHjX7D.js';
export { b as RenderBackendParamValue } from './RendererRuntime-DfZHjX7D.js';
import { CameraOptics, CameraOpticsSource } from 'film-lab-core';

/**
 * GpuContext — adapter / device / canvas-surface bootstrap.
 *
 * Phase 1 T1-2. Backed by DIRECTION §2 canvas config:
 *   configure format=rgba8unorm (spec-compliant — sRGB variants are not
 *   valid canvas formats), viewFormats=[rgba8unorm-srgb] so views / pipeline
 *   colorAttachments can target the sRGB encoding and the hardware OETF
 *   performs the final linear → sRGB transform, colorSpace=srgb, alphaMode=opaque.
 */

interface GpuContextCreateOptions {
    /** Dev-mode validation scope is pushed around pipeline creation. */
    validation?: boolean;
}
type GpuContextLossReason = ViewportContextLossReason;
type GpuContextLossInfo = ViewportContextLossInfo;
declare class GpuContextCreationError extends Error {
    readonly cause?: unknown;
    constructor(message: string, cause?: unknown);
}
declare class GpuContext {
    readonly adapter: GPUAdapter;
    readonly device: GPUDevice;
    readonly canvas: HTMLCanvasElement;
    readonly context: GPUCanvasContext;
    readonly capabilities: ViewportCapabilities;
    /**
     * View / pipeline-attachment format.
     *
     * The swapchain is configured with the spec-legal `rgba8unorm`, but every
     * pass that writes to the canvas takes a view in `rgba8unorm-srgb` so the
     * hardware OETF performs the final linear → sRGB transform. Pipelines
     * declare `colorAttachments[].format = ctx.canvasFormat`.
     */
    readonly canvasFormat: GPUTextureFormat;
    readonly validation: boolean;
    private lost;
    private lossInfo;
    private readonly lossListeners;
    private constructor();
    static create(canvas: HTMLCanvasElement, opts?: GpuContextCreateOptions): Promise<GpuContext>;
    /** Wrap a pipeline-creating callback with validation error scope. */
    withValidationScope<T>(fn: () => T | Promise<T>): Promise<T>;
    isLost(): boolean;
    isContextLost(): boolean;
    getLossInfo(): GpuContextLossInfo | null;
    getContextLossInfo(): GpuContextLossInfo | null;
    onLost(listener: (info: GpuContextLossInfo) => void): () => void;
    onContextLost(listener: ViewportContextLossListener): () => void;
    reportFatalLoss(reason: Exclude<GpuContextLossReason, "device-lost">, error?: unknown): void;
    getCurrentTextureView(): GPUTextureView;
    destroy(): void;
    private markLost;
}

interface OffscreenTargetDescriptor {
    width: number;
    height: number;
    format?: GPUTextureFormat;
    mipLevelCount?: number;
    sampleCount?: number;
    usage?: GPUTextureUsageFlags;
}
declare class OffscreenTargetPool {
    private readonly device;
    private readonly entries;
    constructor(device: GPUDevice);
    get(label: string, desc: OffscreenTargetDescriptor): GPUTexture;
    /**
     * Build a mip-pyramid as N separately-labeled textures. `level=0` is the
     * `fullWidth`/`fullHeight` RT; each subsequent level halves until `minDim`.
     * Designed for bloom (5 levels) and halation (6 levels).
     */
    pyramid(labelPrefix: string, fullWidth: number, fullHeight: number, levels: number, desc?: Omit<OffscreenTargetDescriptor, "width" | "height">): GPUTexture[];
    destroy(): void;
}

/**
 * Lut3DTexture — 3D texture upload for LUT1 (Log→Linear) and LUT2 (Creative).
 *
 * Phase 1 T1-2. DIRECTION §2:
 *   - format = `rgba16float`
 *   - `writeTexture` requires `bytesPerRow` 256-byte aligned
 *   - `rowsPerImage = size` so depth slices line up
 *
 * `data` is interpreted as interleaved RGBA float16 or float32 depending on
 * `inputKind`. Internally we normalize to `Float16Array`-equivalent (Uint16
 * holding IEEE 754 binary16 bits). An identity LUT helper is provided for
 * pipeline smoke tests before real `.cube` data arrives.
 */
interface LutUploadOptions {
    /** Debug label passed to `createTexture` / `writeTexture`. */
    label?: string;
}
declare class Lut3DTexture {
    /**
     * Upload a 3D LUT. `data` must be `size³ × 4` floats (RGBA, row-major:
     * R at x=0, then x=1…, then y, then z). Identity inputs should hit the
     * `[0..1]` range; clamping is left to the caller — LUT1 accepts bounded
     * Log-encoded input, LUT2 is Reinhard-soft-shaped upstream (DIRECTION §3).
     */
    static upload(device: GPUDevice, data: Float32Array, size: number, opts?: LutUploadOptions): GPUTexture;
    /**
     * Identity LUT (linear ramp) — each texel holds its own normalized coord.
     * Used as a no-op placeholder to verify the pipeline end-to-end before
     * plugging in real `.cube` data.
     */
    static identity(size: number): Float32Array;
}

/**
 * MediaTexture — upload still and video sources as `rgba8unorm-srgb`.
 *
 * Phase 1 T1-2. Hardware EOTF converts the sampled sRGB value to linear on
 * read (DIRECTION §2), so the pipeline sees linear Rec.709 from the first
 * texture fetch.
 *
 * `fromVideoElement` re-uploads on every frame via
 * `copyExternalImageToTexture`; the caller owns RAF scheduling. When
 * `VideoFrame` is unavailable we fall back to the same `HTMLVideoElement`
 * path (DIRECTION §10 common default).
 *
 * **Y orientation**: upload with `flipY: true` so the WebGPU texture's row 0
 * corresponds to the image's bottom row. Combined with the procedural
 * fullscreen vertex shader (which derives UV.y from NDC y so that the top
 * of the screen maps to UV.y=1.0), this reproduces the WebGL/THREE.js
 * default orientation (top-of-screen = top-of-image). Without the flip the
 * preview renders upside-down. `setFlipY(true)` on the shader uniform is
 * an additional export-time knob (matching `setExportFlipY` on the WebGL
 * backend) and composes with the upload orientation.
 */
interface MediaTextureOptions {
    label?: string;
    /** Default: `TEXTURE_BINDING | COPY_DST | RENDER_ATTACHMENT` */
    usage?: GPUTextureUsageFlags;
}
declare class MediaTexture {
    static createPlaceholder(device: GPUDevice, opts?: MediaTextureOptions): GPUTexture;
    static fromImageBitmap(device: GPUDevice, bitmap: ImageBitmap, opts?: MediaTextureOptions): GPUTexture;
    /**
     * Upload the current frame of `video` into a reusable texture. If `target`
     * is null or its dimensions no longer match the video, a fresh texture is
     * allocated and returned; otherwise the existing one is updated in place.
     */
    static fromVideoElement(device: GPUDevice, video: HTMLVideoElement, target: GPUTexture | null, opts?: MediaTextureOptions): GPUTexture;
    static fromExternalImageSource(device: GPUDevice, source: ImageBitmapSource, width: number, height: number, target: GPUTexture | null, opts?: MediaTextureOptions): GPUTexture;
}

/**
 * RingBuffer — 8-slot motion-blur ring implemented as a single `GPUTexture`
 * with `depthOrArrayLayers: 8` (DIRECTION §4 — never 8 separate textures).
 *
 * Phase 1 T1-2. On resize, the texture is recreated and `validSlots` resets
 * to 0 so the composite pass can skip stale layers via a uniform.
 */
declare const MOTION_BLUR_RING_SLOTS = 8;
interface RingBufferOptions {
    width: number;
    height: number;
    format?: GPUTextureFormat;
    label?: string;
}
declare class RingBuffer {
    private readonly device;
    private texture;
    private writeIndex;
    private _validSlots;
    private _width;
    private _height;
    private readonly format;
    private readonly label;
    constructor(device: GPUDevice, opts: RingBufferOptions);
    private allocate;
    resize(width: number, height: number): void;
    reset(): void;
    /** Advance the write pointer. Returns the layer index to render into. */
    nextSlot(): number;
    /** Target view for the given layer — pass to a render pass color attachment. */
    viewForSlot(slot: number): GPUTextureView;
    /** 2D-array sampling view for the composite pass. */
    arrayView(): GPUTextureView;
    get validSlots(): number;
    get width(): number;
    get height(): number;
    destroy(): void;
}

/**
 * BlueNoiseTile — 256×256 `r8unorm` texture built from a pre-baked tile.
 *
 * The current composite grain is procedural again, but this tile is still kept
 * around for legacy bind-group compatibility and as a harmless fallback view
 * when the diffusion pyramid is inactive. The underlying bytes are void-and-
 * cluster-generated at build time (see `scripts/generate-blue-noise.mjs`).
 */
declare class BlueNoiseTile {
    /**
     * Upload the pre-baked tile as a single-channel `r8unorm` texture.
     * Cheaper than rgba8 since grain only needs one scalar value per texel;
     * the shader samples `.r` and reuses it for all channels (or dithered
     * chroma coefficients).
     */
    static load(device: GPUDevice): GPUTexture;
}

/**
 * WebGPUBackend — Phase 2 T2-1 + T2-2 + T2-0b + T2-3 + T2-4 + Phase 3
 * (Hard Mode temporal + central bloom + diffusion suppression + shafts).
 *
 * Full v1.0 render pipeline:
 *   1. filmlab → rt.colorGraded (`rgba16float`) — LUT1 → primary grade
 *      (DIRECTION §3 steps 1–12) → Reinhard soft-shaper → LUT2 → print
 *      CMY → print contrast.
 *   2. bloomPrefilter → bloom.L0; downsample chain → bloom.L[1..4];
 *      upsample chain with additive blend back to bloom.L0 (5 mips total,
 *      WebGL parity).
 *   3. halationPrefilter → halation.L0; downsample chain → halation.L[1..5];
 *      upsample chain with additive blend back to halation.L0 (6 mips).
 *   4. diffusion → diffusion.L0; 3-level full-image downsample/upsample
 *      chain from rt.colorGraded, reusing the composite's legacy grain
 *      texture slot for the top mip. Skipped entirely when Hard-mode
 *      cross-filter is active (WebGL parity).
 *   5. composite → rt.composited (`rgba16float`) — screen-blend glow
 *      shoulder, vignette, hybrid fine/coarse grain.
 *      Composite's diffusion uniform is forced to 0 when Hard-mode
 *      cross-filter is active, independently of user's `diffusion` field.
 *   6. Post-chain (active when `crossFilterStrength > 0`,
 *      `haloPrismStrength > 0`, or `shutterAngle > 180`):
 *      - Cross-filter: compact source gate → peak → optional spacing gate →
 *        (Hard-mode only) active WebGPU intentionally bypasses the
 *        legacy temporal hold so the 4-level central-bloom chain and
 *        directional streaks read current peaks directly, while the
 *        preserved temporal infrastructure remains available for future
 *        tuning → blend with center-protection.
 *      - Halo Prism (when `haloPrismStrength > 0`): compact source gate
 *        from the pre-Halo composite → chromatic annular arcs.
 *      - Light Shafts (when `shaftIntensity > 0` and post chain active):
 *        radial 64-tap occlusion at ¼ res → additive full-res blend.
 *      - Motion blur (`shutterAngle > 180`): feedback copy into the ring
 *        (`depthOrArrayLayers=8`, DIRECTION §4) → weighted blend of the
 *        last N slots → swap.
 *      - Motion blur OFF: blit the post-composite source → swap.
 *
 *   Active WebGPU post tail: `CrossFilter → HaloPrism → Shafts → MotionBlur`.
 *
 *   The swap pass output is always `rgba8unorm-srgb` so the hardware OETF
 *   handles the final linear → sRGB transform.
 *
 * Consumer API:
 *   - `setParams(record)` merges the full grade + post params blob; the
 *     uniforms it feeds are split between `GradeUniforms` (filmlab) and
 *     `CompositeUniforms` (bloom strength / halation intensity / grain /
 *     vignette). Bloom + halation shaping params (threshold, knee, radius,
 *     color), motion blur (`shutterAngle`, `trailIntensity`,
 *     `motionThreshold`), cross-filter (Hard Mode / temporal / spacing
 *     state), Halo Prism (`haloPrismStrength`, radius / width / chroma /
 *     source coupling), and light shafts (`shaftIntensity`, `shaftDecay`,
 *     `shaftOriginX`, `shaftOriginY`) are consumed directly by the
 *     post-chain bookkeeping via `paramNumber(...)`.
 *   - `setLUT1` / `setLUT2` upload 3D LUTs (identity pre-uploaded at
 *     construction so the filmlab bind group is always valid).
 *   - `setMediaFromBitmap` / `setImageResolution` / `setFitMode` /
 *     `setTime` feed the remaining frame state.
 *
 * Explicit defers (v1 migration scope):
 *   - Split / A-B compare (capability-gated off on WebGPU).
 *   - Dust / Scratches (intentionally deferred beyond v1).
 */

interface WebGPUBackendCreateOptions {
    validation?: boolean;
}
declare class WebGPUBackend implements RenderBackend {
    private readonly ctx;
    readonly capabilities: ViewportCapabilities;
    private readonly modules;
    private readonly pool;
    private readonly pipelines;
    private readonly layouts;
    private readonly displayFlagsBuffer;
    private readonly offscreenFlagsBuffer;
    private readonly crossFilterFlagsBuffer;
    private readonly displayFlagsBindGroup;
    private readonly offscreenFlagsBindGroup;
    private readonly crossFilterFlagsBindGroup;
    private readonly gradeBuffer;
    private readonly compositeBuffer;
    private readonly detailSoftnessBuffer;
    private readonly bloomParamsBuffer;
    private readonly halationParamsBuffer;
    private readonly diffusionDepthPrefilterBuffer;
    private readonly diffusionDepthPrefilterScratch;
    private readonly bloomDepthPrefilterBuffer;
    private readonly bloomDepthPrefilterScratch;
    private readonly halationDepthPrefilterBuffer;
    private readonly halationDepthPrefilterScratch;
    private readonly bloomPyramid;
    private readonly halationPyramid;
    private readonly diffusionPyramid;
    private readonly centralBloomPyramid;
    private readonly motionblurFeedbackBuffer;
    private readonly motionblurBlendBuffer;
    private readonly crossFilter;
    private readonly lightShafts;
    private readonly haloPrism;
    private readonly sampler;
    private readonly grainSampler;
    private readonly grainTexture;
    /**
     * Shared depth texture for depth-aware Mist / Glow / Cross.
     * Runtime depth tracks and the internal `?depthProbe=1|2` debug fallback
     * both upload into this surface.
     */
    private readonly depthTexture;
    private readonly gradeScratch;
    private readonly compositeScratch;
    private readonly detailSoftnessScratch;
    private readonly bloomParamsScratch;
    private readonly halationParamsScratch;
    private readonly motionblurFeedbackScratch;
    private readonly motionblurBlendScratch;
    /** Compare present uniform: 2 vec4 = 8 floats = 32 B. */
    private readonly compareSourceBuffer;
    private readonly compareSourceScratch;
    private mediaTexture;
    private placeholderTexture;
    private liveVideoElement;
    private lut1Texture;
    private lut2Texture;
    private ringBuffer;
    private _width;
    private _height;
    private destroyed;
    private gradeDirty;
    private readbackEnabled;
    private readbackBuffer;
    private readbackBufferSize;
    private hasReadableFrame;
    private frameState;
    private cameraOptics;
    /**
     * Preserved temporal-hold bookkeeping.
     *
     * WebGL and the dormant WebGPU temporal path use two half-resolution
     * history textures managed by `OffscreenTargetPool` under dedicated
     * labels (`rt.crossfilter.peak-history.{0,1}`). They persist as long as
     * the resolution is unchanged, so the ping-pong remains valid across
     * frames whenever the hold is re-enabled. The counters below get reset
     * whenever the history should be treated as empty — resolution changes,
     * `crossFilterStrength` transitions to 0, `crossFilterHardMode` flips,
     * or `crossFilterMinSpacing` crosses an epsilon. We also track the last
     * history timestamp so temporal decay can stay normalized to elapsed
     * time instead of render count.
     */
    private crossFilterPeakHistoryWriteIndex;
    private crossFilterPeakHistoryFilledFrames;
    private lastCrossFilterHistoryTime;
    private lastCrossFilterStrength;
    private lastCrossFilterHardMode;
    private lastCrossFilterMinSpacing;
    private constructor();
    static create(canvas: HTMLCanvasElement, opts?: WebGPUBackendCreateOptions): Promise<WebGPUBackend>;
    /**
     * Upload a 512x288 depth frame (red channel = depth, 0 = near, 255 = far)
     * for the shared depth-aware Mist / Glow path.
     */
    setDepthFromBitmap(bitmap: ImageBitmap): void;
    setMediaFromBitmap(bitmap: ImageBitmap): void;
    setMediaFromVideoElement(video: HTMLVideoElement): void;
    setMediaFromExternalImageSource(source: ImageBitmapSource, width: number, height: number): void;
    setVideoElement(video: HTMLVideoElement): void;
    setImageResolution(width: number, height: number): void;
    setCameraOptics(optics: CameraOptics | null): void;
    setFitMode(mode: "cover" | "contain"): void;
    setTime(time: number): void;
    setSplitPosition(position: number): void;
    getSplitPosition(): number;
    /**
     * Compare API. WebGPU backend still only honors the `enabled` flag —
     * when true, the present pass is replaced by the `compare-source`
     * pipeline that mixes raw `mediaTexture` and graded output by the
     * current `splitPosition`. Slot params (`paramsA` / `paramsB`) are
     * intentionally ignored on WebGPU v1; the WebGL dual-slot
     * simultaneous A/B render parity stays deferred. The active slot's
     * params still drive the normal grade pipeline (via `setParams` from
     * the control panel), so toggling Tab in compare mode updates the
     * graded side as expected.
     */
    setComparePair(enabled: boolean, _paramsA: Record<string, number | string> | null, _paramsB: Record<string, number | string> | null): void;
    setLUT1(data: Float32Array, size: number): void;
    setLUT1Intensity(value: number): void;
    clearLUT1(): void;
    setLUT2(data: Float32Array, size: number): void;
    setLUT2Intensity(value: number): void;
    clearLUT2(): void;
    setParams(params: RenderBackendParams): void;
    setFlipY(flip: boolean): void;
    getPendingParams(): Readonly<RenderBackendParams>;
    getMaxTextureDimension2D(): number;
    isContextLost(): boolean;
    getContextLossInfo(): GpuContextLossInfo | null;
    onContextLost(listener: (info: GpuContextLossInfo) => void): () => void;
    reportFatalContextLoss(reason: Exclude<GpuContextLossReason, "device-lost">, error?: unknown): void;
    prewarm(): void;
    setReadbackEnabled(enabled: boolean): void;
    readbackRgba8(): Promise<Uint8Array>;
    private refreshLiveVideoTexture;
    private getActiveMediaTexture;
    private paramNumber;
    private paramString;
    private resolveCurrentRayAngleOptics;
    private packRayAngleOptics;
    private uploadFrameUniforms;
    /**
     * Bloom / halation mip accumulation weights — WebGL parity formula.
     * Smaller `radius` biases energy toward the sharper mips; `radius=1`
     * spreads it outward to the low-freq tails.
     */
    private static computeMipWeights;
    private ensurePyramidLevels;
    private renderPyramidChain;
    /**
     * Shared depth-aware Mist path — produce a depth-weighted source mask feeding
     * the diffusion pyramid. Output goes to `rt.diffusion.prefiltered`
     * (full-res rgba16float), which the caller then passes to
     * `renderDiffusionPyramid` in place of the raw colorGraded view.
     *
     * Physical model: Pro-Mist scatters light at the source, so weighting the
     * source by depth *before* the pyramid is built is the physically correct
     * location. Post-composite modulation (the prior approach) re-cut an
     * already-bled halo with a sharp depth mask, which read as a ghost / double
     * image along silhouette edges.
     */
    private renderDiffusionDepthPrefilter;
    /**
     * Shared depth-aware Glow path — depth-weighted source mask feeding the
     * bloom pyramid. Output goes to `rt.bloom.depth-prefiltered` (full-res
     * rgba16float), which the caller passes to `renderPyramidChain` as the
     * `sourceView`; the existing bloom luma-gate prefilter then reads from
     * this intermediate. Near/far coefficients live in the WGSL constant
     * (`bloom-depth-prefilter.frag.wgsl.ts`).
     */
    private renderBloomDepthPrefilter;
    /**
     * Shared depth-aware Glow path — depth-weighted source mask feeding the
     * halation pyramid. Mirrors `renderBloomDepthPrefilter`; only the
     * scratch RT label and uniform buffer differ (separate buffers per
     * pyramid to avoid writeBuffer aliasing).
     */
    private renderHalationDepthPrefilter;
    private renderDiffusionPyramid;
    /**
     * WebGL and the preserved dormant WebGPU temporal path use a 2-slot
     * half-resolution history for temporal hold. That history is reset under
     * four conditions:
     *   1. resolution change (handled in `setResolution`)
     *   2. `crossFilterStrength` transitions to 0
     *   3. `crossFilterHardMode` flip (0 ↔ 1)
     *   4. `crossFilterMinSpacing` crosses a small epsilon
     *
     * The latter three are detected here by snapshotting last-frame values.
     */
    private maybeResetCrossFilterHistory;
    /**
     * Hard-mode central bloom, 4-level pyramid.
     *   1. seed mip 0 by downsampling the active peak mask (WebGL used held
     *      peaks; active WebGPU currently passes current peaks because the
     *      temporal hold is intentionally bypassed).
     *   2. progressive downsample mip 0 → mip 3.
     *   3. additive upsample back to mip 0 with fixed radius 0.5.
     *
     * Returns mip 0 so the caller can feed it to the cross-filter blend
     * shader's `uCentralBloom` binding. Mip 0 runs at quarter-resolution of
     * the full output (the peak texture is half-res, then we halve again on
     * seed).
     */
    private renderCentralBloom;
    /**
     * Light shafts two-sub-pass rendering (WebGL parity):
     *   9a: radial blur at 1/4 resolution (64 taps, luminance threshold).
     *   9b: additive blend at full resolution.
     *
     * Returns a full-resolution texture the caller can feed to the next post
     * stage (motion blur / blit). Preserves WebGL activation semantics — the
     * caller is responsible for the `shaftIntensity > 0 && (crossFilter ||
     * motionBlur) active` gate.
     */
    private renderLightShafts;
    private renderHaloPrism;
    private renderCrossFilter;
    /**
     * `shutterAngle` (degrees, 0..720) → active slot count. Matches WebGL:
     * 180° is the no-added-blur baseline, 360° = 2 slots, 720° = 3 slots.
     */
    private activeMotionBlurFrames;
    /**
     * Pre-normalized motion-blur weights (sum = 1 across active slots, 0
     * elsewhere). Triangle/box mix follows the WebGL path: shutterAngle ≤
     * 360° is pure triangle; > 360° smoothly flattens to box by 720°.
     */
    private computeMotionBlurWeights;
    render(): void;
    private renderInternal;
    private renderFrame;
    setResolution(width: number, height: number): void;
    resetMotionBlurHistory(): void;
    destroy(): void;
    get width(): number;
    get height(): number;
    private ensureReadbackBuffer;
}

/**
 * Procedural fullscreen-triangle vertex shader.
 *
 * Phase 1 T1-3. Replaces the GLSL `filmlab.vert` buffer-based quad with a
 * WebGPU-idiomatic vertex-less triangle. Covers the entire clip-space
 * rectangle with exactly 3 vertices (no buffer binding needed).
 *
 * uFlipY is a `0 or 1` toggle (matching the GLSL version's semantics) and
 * lives on the per-frame uniform struct — see `WebGPUBackend` bind group 0.
 *
 * Entry: `vs_main` returns `VsOut { @builtin(position), @location(0) uv }`.
 */
declare const fullscreenVertexWgsl = "\nstruct VsOut {\n  @builtin(position) pos: vec4f,\n  @location(0) uv: vec2f,\n};\n\nstruct FrameFlags {\n  flipY: f32,\n  _pad0: f32,\n  _pad1: f32,\n  _pad2: f32,\n};\n\n@group(0) @binding(0) var<uniform> uFlags: FrameFlags;\n\n@vertex\nfn vs_main(@builtin(vertex_index) vi: u32) -> VsOut {\n  // Three-vertex fullscreen triangle: the triangle covers the full\n  // [-1..3] clip rectangle; the GPU rasterizer clips everything outside\n  // [-1..1], so the visible region is exactly the viewport.\n  let x = f32(((vi << 1u) & 2u)) * 2.0 - 1.0;\n  let y = f32((vi & 2u)) * 2.0 - 1.0;\n  let uvRaw = vec2f(x * 0.5 + 0.5, y * 0.5 + 0.5);\n  let uv = vec2f(uvRaw.x, mix(uvRaw.y, 1.0 - uvRaw.y, uFlags.flipY));\n\n  var out: VsOut;\n  out.pos = vec4f(x, y, 0.0, 1.0);\n  out.uv = uv;\n  return out;\n}\n";

/**
 * Bloom prefilter (WGSL) — quadratic soft-knee luma gate.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/bloom-prefilter.frag.ts.
 * Output writes into an `rgba16float` RT (DIRECTION §2), no clamp — HDR
 * overshoot is preserved for the downsample stage.
 *
 * Bind group layout (group 1, shared with halation/lightshafts/dust):
 *   @binding(0) uParams : vec4<f32>  // (threshold, knee, _, _)
 *   @binding(1) uSource : texture_2d<f32>
 *   @binding(2) uSampler: sampler
 */
declare const bloomPrefilterFragmentWgsl = "\nstruct Params {\n  threshold: f32,\n  knee: f32,\n  _pad0: f32,\n  _pad1: f32,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let color = textureSampleLevel(uSource, uSampler, uv, 0.0);\n  let luma = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));\n\n  let knee = max(uParams.knee * uParams.threshold, 1e-4);\n  let t = clamp((luma - uParams.threshold + knee) / (2.0 * knee), 0.0, 1.0);\n  var contribution = t * t * mix(knee, 1.0, t);\n\n  // Guard pow/log/sqrt inputs per DIRECTION \u00A73 (no negative luma).\n  let overshoot = max(0.0, luma - uParams.threshold);\n  contribution = max(contribution, overshoot);\n\n  return vec4f(color.rgb * contribution, 1.0);\n}\n";

/**
 * Halation prefilter (WGSL) — same soft-knee gate as bloom, tinted by the
 * halation color. Ported from src/webgl/shaders/halation-prefilter.frag.ts.
 *
 * Phase 1 T1-3. Packed uniforms as vec4 to avoid WGSL 16-byte silent
 * padding pitfalls (DIRECTION §4): halationColor stored as `.xyz` of a
 * vec4, threshold + knee on a second vec4.
 */
declare const halationPrefilterFragmentWgsl = "\nstruct Params {\n  // (halationColor.rgb, threshold)\n  colorThreshold: vec4f,\n  // (knee, _, _, _)\n  knee: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let color = textureSampleLevel(uSource, uSampler, uv, 0.0);\n  let luma = dot(color.rgb, vec3f(0.2126, 0.7152, 0.0722));\n\n  let threshold = uParams.colorThreshold.w;\n  let halationColor = uParams.colorThreshold.xyz;\n  let knee = max(uParams.knee.x * threshold, 1e-4);\n  let t = clamp((luma - threshold + knee) / (2.0 * knee), 0.0, 1.0);\n  var contribution = t * t * mix(knee, 1.0, t);\n  contribution = max(contribution, max(0.0, luma - threshold));\n\n  let halation = color.rgb * contribution * halationColor;\n  return vec4f(halation, 1.0);\n}\n";

/**
 * Downsample (WGSL) — 13-tap tent, Jimenez/COD-AW.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/downsample.frag.ts. Mirror
 * addressing is kept for parity with the WebGL path; the sampler-provided
 * `address-mode: mirror-repeat` would be cheaper but we retain the manual
 * `mirrorUv` to keep WebGL ↔ WebGPU pixel equivalence within PSNR range.
 */
declare const downsampleFragmentWgsl = "\nstruct Params {\n  // (texelSize.xy, _, _)\n  texelSize: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\nfn mirrorUv(uv: vec2f) -> vec2f {\n  let tiled = vec2f(uv.x - floor(uv.x * 0.5) * 2.0, uv.y - floor(uv.y * 0.5) * 2.0);\n  return vec2f(1.0, 1.0) - abs(tiled - vec2f(1.0, 1.0));\n}\n\nfn sampleMirror(uv: vec2f) -> vec4f {\n  return textureSampleLevel(uSource, uSampler, mirrorUv(uv), 0.0);\n}\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let d = uParams.texelSize.xy;\n\n  let a = sampleMirror(uv + vec2f(-2.0 * d.x,  2.0 * d.y));\n  let b = sampleMirror(uv + vec2f( 0.0,         2.0 * d.y));\n  let c = sampleMirror(uv + vec2f( 2.0 * d.x,  2.0 * d.y));\n\n  let dd = sampleMirror(uv + vec2f(-d.x,  d.y));\n  let e  = sampleMirror(uv + vec2f( d.x,  d.y));\n\n  let f = sampleMirror(uv + vec2f(-2.0 * d.x, 0.0));\n  let g = sampleMirror(uv);\n  let h = sampleMirror(uv + vec2f( 2.0 * d.x, 0.0));\n\n  let ii = sampleMirror(uv + vec2f(-d.x, -d.y));\n  let j  = sampleMirror(uv + vec2f( d.x, -d.y));\n\n  let k = sampleMirror(uv + vec2f(-2.0 * d.x, -2.0 * d.y));\n  let l = sampleMirror(uv + vec2f( 0.0,        -2.0 * d.y));\n  let m = sampleMirror(uv + vec2f( 2.0 * d.x, -2.0 * d.y));\n\n  return (dd + e + ii + j) * 0.125\n       + g * 0.125\n       + (a + c + k + m) * 0.03125\n       + (b + f + h + l) * 0.0625;\n}\n";

/**
 * Upsample (WGSL) — 9-tap tent.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/upsample.frag.ts. Output is
 * the weighted contribution alone; additive accumulation is performed by
 * the render pass blend state (`blend: { color: { operation: add, src: one,
 * dst: one } }`).
 */
declare const upsampleFragmentWgsl = "\nstruct Params {\n  // (texelSize.xy, weight, _)\n  texelAndWeight: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\nfn mirrorUv(uv: vec2f) -> vec2f {\n  let tiled = vec2f(uv.x - floor(uv.x * 0.5) * 2.0, uv.y - floor(uv.y * 0.5) * 2.0);\n  return vec2f(1.0, 1.0) - abs(tiled - vec2f(1.0, 1.0));\n}\n\nfn sampleMirror(uv: vec2f) -> vec4f {\n  return textureSampleLevel(uSource, uSampler, mirrorUv(uv), 0.0);\n}\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let d = uParams.texelAndWeight.xy;\n  let weight = uParams.texelAndWeight.z;\n\n  let s  = sampleMirror(uv);\n  let s0 = sampleMirror(uv + vec2f(-d.x,  d.y));\n  let s1 = sampleMirror(uv + vec2f( 0.0,  d.y));\n  let s2 = sampleMirror(uv + vec2f( d.x,  d.y));\n  let s3 = sampleMirror(uv + vec2f(-d.x,  0.0));\n  let s4 = sampleMirror(uv + vec2f( d.x,  0.0));\n  let s5 = sampleMirror(uv + vec2f(-d.x, -d.y));\n  let s6 = sampleMirror(uv + vec2f( 0.0, -d.y));\n  let s7 = sampleMirror(uv + vec2f( d.x, -d.y));\n\n  var upsampled = s * 4.0\n                + (s1 + s3 + s4 + s6) * 2.0\n                + (s0 + s2 + s5 + s7) * 1.0;\n  upsampled = upsampled / 16.0;\n  return upsampled * weight;\n}\n";

/**
 * Lightshafts (WGSL) — radial occlusion sampling, 64 taps.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/lightshafts.frag.ts. The
 * 64-tap loop is unrolled by the WGSL compiler; `textureSampleLevel` is
 * used unconditionally (no dynamic UV-dependent branches), satisfying
 * the DIRECTION §4 non-uniform-control-flow rule.
 */
declare const lightshaftsFragmentWgsl = "\nstruct Params {\n  // (lightOrigin.xy, decay, density)\n  originDecayDensity: vec4f,\n  // (exposure, _, _, _)\n  exposure: vec4f,\n};\n\nconst NUM_SAMPLES: u32 = 64u;\nconst LUMINANCE_THRESHOLD: f32 = 0.65;\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let lightOrigin = uParams.originDecayDensity.xy;\n  let decay = uParams.originDecayDensity.z;\n  let density = uParams.originDecayDensity.w;\n  let exposure = uParams.exposure.x;\n\n  var deltaUv = uv - lightOrigin;\n  deltaUv = deltaUv * (density / f32(NUM_SAMPLES));\n\n  var sampleUv = uv;\n  var accum = vec4f(0.0);\n  var illuminationDecay = 1.0;\n\n  for (var i: u32 = 0u; i < NUM_SAMPLES; i = i + 1u) {\n    sampleUv = sampleUv - deltaUv;\n    let clamped = clamp(sampleUv, vec2f(0.0), vec2f(1.0));\n    var s = textureSampleLevel(uSource, uSampler, clamped, 0.0);\n    let luma = dot(s.rgb, vec3f(0.2126, 0.7152, 0.0722));\n    let contribution = smoothstep(LUMINANCE_THRESHOLD - 0.05, LUMINANCE_THRESHOLD + 0.05, luma);\n    s = vec4f(s.rgb * contribution, s.a);\n    s = s * illuminationDecay;\n    accum = accum + s;\n    illuminationDecay = illuminationDecay * decay;\n  }\n\n  accum = accum / f32(NUM_SAMPLES);\n  return vec4f(accum.rgb * exposure, 1.0);\n}\n";

/**
 * Lightshafts blend (WGSL) — additive shaft overlay onto the scene.
 *
 * Phase 1 T1-3. Ported from src/webgl/shaders/lightshafts-blend.frag.ts.
 * The clamp to [0,1] is retained for exact WebGL parity even though
 * DIRECTION §1 removes `clamp(0,1)` from the PRIMARY grade; this is a
 * composite stage, so the clamp stays.
 */
declare const lightshaftsBlendFragmentWgsl = "\nstruct Params {\n  // (intensity, _, _, _)\n  intensity: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uScene: texture_2d<f32>;\n@group(1) @binding(2) var uShafts: texture_2d<f32>;\n@group(1) @binding(3) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let scene = textureSampleLevel(uScene, uSampler, uv, 0.0).rgb;\n  let shafts = textureSampleLevel(uShafts, uSampler, uv, 0.0).rgb;\n  let result = scene + shafts * uParams.intensity.x;\n  return vec4f(clamp(result, vec3f(0.0), vec3f(1.0)), 1.0);\n}\n";

/**
 * Dust + scratch overlay (WGSL). Ported from src/webgl/shaders/dust.frag.ts.
 *
 * Phase 1 T1-3. Screen blend for dust, additive for scratches. Animated
 * offsets are driven by `uTime` (seconds). Dust/scratch textures are
 * sampled at `wrap-repeat` address mode so the scrolling tiles cleanly.
 */
declare const dustFragmentWgsl = "\nstruct Params {\n  // (dustAmount, scratchAmount, time, _)\n  amountsAndTime: vec4f,\n  // (resolution.x, resolution.y, _, _)\n  resolution: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uDust: texture_2d<f32>;\n@group(1) @binding(3) var uScratch: texture_2d<f32>;\n@group(1) @binding(4) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  var color = textureSampleLevel(uSource, uSampler, uv, 0.0);\n\n  let dustAmount = uParams.amountsAndTime.x;\n  let scratchAmount = uParams.amountsAndTime.y;\n  let time = uParams.amountsAndTime.z;\n\n  if (dustAmount > 0.0) {\n    let dustUv = uv * 3.0 + vec2f(time * 0.02, time * 0.015);\n    let dust = textureSampleLevel(uDust, uSampler, dustUv, 0.0).r;\n    let dustUv2 = uv * 1.7 + vec2f(-time * 0.013, time * 0.009);\n    let dust2 = textureSampleLevel(uDust, uSampler, dustUv2, 0.0).r;\n    let dustCombined = max(dust, dust2 * 0.7);\n    let dustColor = vec3f(dustCombined * dustAmount);\n    color = vec4f(1.0 - (1.0 - color.rgb) * (1.0 - dustColor), color.a);\n  }\n\n  if (scratchAmount > 0.0) {\n    let jitterPhase = floor(time * 4.0);\n    let scratchUv = vec2f(uv.x * 2.0, uv.y * 0.5 + jitterPhase * 0.37);\n    let scratch = textureSampleLevel(uScratch, uSampler, scratchUv, 0.0).r;\n    color = vec4f(color.rgb + vec3f(scratch * scratchAmount * 0.6), color.a);\n  }\n\n  return vec4f(clamp(color.rgb, vec3f(0.0), vec3f(1.0)), color.a);\n}\n";

/**
 * filmlab.frag (WGSL) — Phase 2 T2-1 + T2-2.
 *
 * Full v1.0 filmlab pipeline in Linear Rec.709 + rgba16float, following
 * DIRECTION §3 pipeline order: primary grade (exposure → film compression)
 * → Reinhard soft-shaper → LUT2 (Creative) → print CMY cast → print
 * contrast. No `clamp(0,1)` at any step; `max(x, 0.0)` guards sit in front
 * of pow/log/exp inputs per DIRECTION §10 Phase 2 default. LUT1
 * (Log→Linear input transform) is sampled before exposure; LUT2 sits after
 * the HDR primary-grade boundary with soft-shaper as the bounded input.
 *
 * Uniform layout (9 vec4 = 144 bytes, WGSL 16-byte aligned per DIRECTION
 * §4). See `packGradeUniforms` in `webgpu/gradeUniforms.ts` for the TS-side
 * packer.
 */
declare const filmlabFragmentWgsl = "\nstruct Grade {\n  // (exposure, contrast, saturation, _pad)\n  exposureContrastSaturation: vec4f,\n  // (temperature, tint, fade, rgbShift)\n  temperatureTintFadeRgbShift: vec4f,\n  // (highlights, shadows, compAmount, compRange)\n  highlightsShadowsComp: vec4f,\n  // (shadowTint.rgb, _pad)\n  shadowTint: vec4f,\n  // (highlightTint.rgb, _pad)\n  highlightTint: vec4f,\n  // (splitPosition, lut1Intensity, lut1Enabled, lut2Intensity)\n  splitLut: vec4f,\n  // (lut2Enabled, cyan, magenta, yellow)\n  lut2PrintCmY: vec4f,\n  // (printContrast, fitMode, imgResX, imgResY)\n  printContrastFit: vec4f,\n  // (resolutionX, resolutionY, time, _pad)\n  resolutionTime: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uGrade: Grade;\n@group(1) @binding(1) var uMedia: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n@group(1) @binding(3) var uLUT1: texture_3d<f32>;\n@group(1) @binding(4) var uLUT2: texture_3d<f32>;\n\nconst LUMA_R709 = vec3f(0.2126, 0.7152, 0.0722);\n\nfn fitUv(uv: vec2f, resolution: vec2f, imageResolution: vec2f, fitMode: f32) -> vec2f {\n  let screenAspect = resolution.x / max(resolution.y, 1.0);\n  let imageAspect = imageResolution.x / max(imageResolution.y, 1.0);\n  let coverScale = select(\n    vec2f(screenAspect / imageAspect, 1.0),\n    vec2f(1.0, imageAspect / screenAspect),\n    screenAspect > imageAspect,\n  );\n  let containScale = select(\n    vec2f(1.0, imageAspect / screenAspect),\n    vec2f(screenAspect / imageAspect, 1.0),\n    screenAspect > imageAspect,\n  );\n  let scale = mix(coverScale, containScale, fitMode);\n  var result = (uv - vec2f(0.5)) * scale + vec2f(0.5);\n  let narrowPortrait = step(2.0, scale.x) * fitMode;\n  result.x = result.x + 0.18 * scale.x * narrowPortrait;\n  return result;\n}\n\nfn insideUv(uv: vec2f) -> f32 {\n  let s = step(vec2f(0.0), uv) * step(uv, vec2f(1.0));\n  return s.x * s.y;\n}\n\nfn rgbShiftRadial(uv: vec2f, amount: f32, imageResolution: vec2f) -> vec4f {\n  var delta = uv - vec2f(0.5);\n  delta.x = delta.x * (imageResolution.x / max(imageResolution.y, 1.0));\n  let radial = clamp(length(delta) * 2.0, 0.0, 1.0);\n  let weight = pow(max(radial, 0.0), 1.65);\n  let amt = amount * weight;\n  let dir = normalize(delta + vec2f(1e-5));\n  let rCh = textureSampleLevel(uMedia, uSampler, uv + dir * amt, 0.0).r;\n  let center = textureSampleLevel(uMedia, uSampler, uv, 0.0);\n  let bCh = textureSampleLevel(uMedia, uSampler, uv - dir * amt, 0.0).b;\n  return vec4f(rCh, center.g, bCh, center.a);\n}\n\n// Reinhard soft-shaper \u2014 DIRECTION \u00A73 HDR-boundary entry. Smoothly\n// compresses (\u22650) HDR input toward [0, 1.5] before LUT2 sampling, so\n// highlight detail carried out of the primary grade survives the LUT2\n// lookup instead of hard-clipping at 1.0. k = 0.5 fixed (DIRECTION \u00A710\n// Phase 2; no UI knob in v1.0).\nfn softShape(x: vec3f) -> vec3f {\n  let safe = max(x, vec3f(0.0));\n  let k = 0.5;\n  return safe / (safe + vec3f(k)) * (1.0 + k);\n}\n\n// Print stage final S-curve contrast \u2014 WebGL parity, clamp removed so the\n// final swap/composite blit handles the display-range clamp per DIRECTION\n// \u00A72 \"no clamp in intermediate stages\".\nfn applyPrintContrast(rgb: vec3f, amount: f32) -> vec3f {\n  if (amount < 0.001) {\n    return rgb;\n  }\n  let k = mix(1.0, 5.0, amount);\n  let x = clamp(-k * (rgb - vec3f(0.5)), vec3f(-6.0), vec3f(6.0));\n  let s = vec3f(1.0) / (vec3f(1.0) + exp(x));\n  return mix(rgb, s, amount);\n}\n\n// Luma-preserving sigmoid compression \u2014 DIRECTION \u00A73 step 11/12. The\n// WebGL original clamps the output to [0,1]; we drop that here because a\n// wider range survives through T2-2 soft-shaper before LUT2.\nfn applyFilmCompression(rgb: vec3f, amount: f32, range: f32) -> vec3f {\n  if (amount < 0.001) {\n    return rgb;\n  }\n  let r = clamp(range, 0.0, 1.0);\n  let k = mix(5.15, 2.85, r);\n  let rangeSoft = smoothstep(0.82, 1.0, r);\n  let amt = amount * (1.0 - 0.18 * rangeSoft);\n  let luma = dot(rgb, LUMA_R709);\n  // Clamp only the sigmoid *input*, not the output, so ultra-bright\n  // pixels still pass through with gentle roll-off.\n  let x = clamp(k * (luma - 0.5), -5.5, 5.5);\n  let s = 1.0 / (1.0 + exp(-x));\n  let lumaSafe = max(luma, 0.001);\n  let lumaScale = select(1.0, mix(luma, s, amt) / lumaSafe, luma > 0.001);\n  return rgb * lumaScale;\n}\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let resolution = uGrade.resolutionTime.xy;\n  let imageResolution = uGrade.printContrastFit.zw;\n  let fitMode = uGrade.printContrastFit.y;\n  let fittedUv = fitUv(uv, resolution, imageResolution, fitMode);\n\n  // 1. media sample (sRGB \u2192 linear via hw EOTF on rgba8unorm-srgb).\n  // 2. optional radial RGB shift.\n  let rgbShift = uGrade.temperatureTintFadeRgbShift.w;\n  var color = select(\n    textureSampleLevel(uMedia, uSampler, fittedUv, 0.0),\n    rgbShiftRadial(fittedUv, rgbShift, imageResolution),\n    rgbShift > 0.0,\n  );\n\n  // 3. LUT1 \u2014 Log \u2192 Linear Rec.709. Clamp-to-edge is configured on the\n  // shared sampler (DIRECTION \u00A710 Phase 2) so the 0..1 domain is safe.\n  let lut1Intensity = uGrade.splitLut.y;\n  let lut1Enabled = uGrade.splitLut.z;\n  if (lut1Enabled > 0.5) {\n    let lut1Coord = clamp(color.rgb, vec3f(0.0), vec3f(1.0));\n    let lut1Sample = textureSampleLevel(uLUT1, uSampler, lut1Coord, 0.0).rgb;\n    color = vec4f(mix(color.rgb, lut1Sample, lut1Intensity), color.a);\n  }\n\n  // 4. Exposure \u2014 exp2 is safer than pow(2.0, x) under negative inputs.\n  let exposure = uGrade.exposureContrastSaturation.x;\n  color = vec4f(color.rgb * exp2(exposure), color.a);\n\n  // 5. Contrast.\n  let contrast = uGrade.exposureContrastSaturation.y;\n  color = vec4f((color.rgb - vec3f(0.5)) * contrast + vec3f(0.5), color.a);\n\n  // 6. Saturation.\n  let saturation = uGrade.exposureContrastSaturation.z;\n  let lumaSat = dot(color.rgb, LUMA_R709);\n  color = vec4f(mix(vec3f(lumaSat), color.rgb, saturation), color.a);\n\n  // 7. Temperature.\n  let temperature = uGrade.temperatureTintFadeRgbShift.x;\n  color = vec4f(\n    color.r + temperature * 0.1,\n    color.g,\n    color.b - temperature * 0.1,\n    color.a,\n  );\n\n  // 8. Tint (green / magenta).\n  let tint = uGrade.temperatureTintFadeRgbShift.y;\n  color = vec4f(\n    color.r + tint * 0.05,\n    color.g - tint * 0.08,\n    color.b + tint * 0.05,\n    color.a,\n  );\n\n  // 9. Split toning.\n  let lumST = dot(color.rgb, LUMA_R709);\n  let shadowTint = uGrade.shadowTint.rgb;\n  let highlightTint = uGrade.highlightTint.rgb;\n  color = vec4f(\n    color.rgb + shadowTint * (1.0 - lumST) * 0.18 + highlightTint * lumST * 0.18,\n    color.a,\n  );\n\n  // 10. Fade (Lift).\n  let fade = uGrade.temperatureTintFadeRgbShift.z;\n  color = vec4f(color.rgb + fade * (vec3f(1.0) - color.rgb), color.a);\n\n  // 11. Highlights / Shadows.\n  let highlights = uGrade.highlightsShadowsComp.x;\n  let shadows = uGrade.highlightsShadowsComp.y;\n  let lumHS = dot(color.rgb, LUMA_R709);\n  color = vec4f(\n    color.rgb + shadows * (1.0 - lumHS) * 0.5 + highlights * lumHS * 0.5,\n    color.a,\n  );\n\n  // 12. Film compression \u2014 lumaScale only, no output clamp.\n  let compAmount = uGrade.highlightsShadowsComp.z;\n  let compRange = uGrade.highlightsShadowsComp.w;\n  color = vec4f(applyFilmCompression(color.rgb, compAmount, compRange), color.a);\n\n  // --- HDR boundary ---\n  // 13. LUT2 (Creative) \u2014 the soft-shaper above prepares the bounded input\n  // so highlight >1 values fold gently into the lookup domain instead of\n  // hard-clipping. LUT2 output mixes back against the pre-shaped color so\n  // LUT intensity keeps its usual \"how creative\" meaning.\n  let lut2Intensity = uGrade.splitLut.w;\n  let lut2Enabled = uGrade.lut2PrintCmY.x;\n  if (lut2Enabled > 0.5) {\n    let shaped = softShape(color.rgb);\n    let lut2Coord = clamp(shaped, vec3f(0.0), vec3f(1.0));\n    let lut2Sample = textureSampleLevel(uLUT2, uSampler, lut2Coord, 0.0).rgb;\n    color = vec4f(mix(color.rgb, lut2Sample, lut2Intensity), color.a);\n  }\n\n  // 14. Print CMY cast \u2014 C = -R, M = -G, Y = -B darkroom analog.\n  let cyan = uGrade.lut2PrintCmY.y;\n  let magenta = uGrade.lut2PrintCmY.z;\n  let yellow = uGrade.lut2PrintCmY.w;\n  let cmyScale = 0.15;\n  color = vec4f(\n    color.r - cyan * cmyScale,\n    color.g - magenta * cmyScale,\n    color.b - yellow * cmyScale,\n    color.a,\n  );\n\n  // 15. Print contrast \u2014 final paper-hardness S-curve.\n  let printContrast = uGrade.printContrastFit.x;\n  color = vec4f(applyPrintContrast(color.rgb, printContrast), color.a);\n\n  let mask = insideUv(fittedUv);\n  // rgba16float output keeps values out-of-[0,1] alive; the final swap\n  // blit (rgba8unorm-srgb hardware OETF) does the clamped display transform.\n  return vec4f(color.rgb * mask, 1.0);\n}\n";

/**
 * Passthrough blit (WGSL) — writes an `rgba16float` offscreen texture to
 * the swapchain (`rgba8unorm-srgb`). The hardware OETF does the final
 * linear → sRGB transform, so the shader itself stays linear.
 *
 * Phase 2 T2-1: used as the final present pass while composite.wgsl is
 * still being authored (T2-3). Once composite is live, this shader goes
 * away and composite writes directly to the swapchain.
 */
declare const blitFragmentWgsl = "\n@group(1) @binding(0) var uSource: texture_2d<f32>;\n@group(1) @binding(1) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  return textureSampleLevel(uSource, uSampler, uv, 0.0);\n}\n";

/**
 * composite.frag (WGSL) — Phase 2 T2-3 final display pass.
 *
 * Inputs: `uSource` (filmlab output, rgba16float), `uBloom` + `uHalation`
 * (accumulated pyramid outputs, rgba16float). Output goes straight to the
 * swap chain (`rgba8unorm-srgb`) so the hardware OETF handles the
 * linear→sRGB transform — no in-shader gamma math.
 *
 * v1.0 parity port (2026-04-19):
 *   - Bloom + halation screen-blend with soft shoulder (WebGL parity).
 *   - **Bloom/halation are sampled with flipped uv.y**. The procedural
 *     fullscreen vertex shader derives uv from NDC y (`y*0.5 + 0.5`), which
 *     inverts texture rows once per render pass. The base reaches the swap
 *     chain after an even number of passes (media upload + filmlab +
 *     composite + blit); bloom/halation reach the swap chain after an odd
 *     number of passes (media + filmlab + prefilter + …pyramid… + composite
 *     + blit) and therefore arrive mirrored along y relative to the base.
 *     Sampling them at `(uv.x, 1.0 - uv.y)` re-aligns the glow with the
 *     base image without touching the pyramid or any upstream orientation.
 *   - Image-space vignette.
 *   - **Hybrid grain** — WebGL parity: low-end uses calmer fine-grain
 *     structured noise with weak chroma, while mid/high keeps the existing
 *     silver-halide per-pixel hash + clump modulation. `grainSize` blends
 *     between the two so 0.01–0.10 remains perceptually useful.
 *   - **Lens softness + aberration edge soften** — WebGL parity: 8-tap
 *     cross+diagonal blur on `uSource`, mixed into the base via an edge
 *     mask whose weight follows `uLensSoftness` and `uAberrationEdgeSoften`.
 *     Reproduces the WebGL "film-lens soft periphery" behaviour.
 *
 * Deferred:
 *   - Split / A-B compare, motion blur feedback (handled upstream in the
 *     backend), dust overlay, cross-filter streaks / shafts.
 *
 * Bind group layout (DIRECTION §10 Phase 2 — 2 bind groups):
 *   - group(0) — frame flags (`vec4f`, currently unused here but kept
 *     for pipeline layout parity with filmlab/blit).
 *   - group(1) — per-frame uniforms + texture stack:
 *     binding(0) uComposite : Composite uniform struct (vec4-packed)
 *     binding(1) uSource    : texture_2d<f32>   (rt.colorGraded)
 *     binding(2) uBloom     : texture_2d<f32>   (rt.bloom full-res mip[0])
 *     binding(3) uHalation  : texture_2d<f32>   (rt.halation full-res mip[0])
 *     binding(4) uDiffusion : texture_2d<f32>   (diffusion top mip,
 *                                                reusing the legacy grain
 *                                                texture slot to avoid a
 *                                                layout change)
 *     binding(5) uSampler   : sampler           (linear, clamp-to-edge)
 *     binding(6) uGrainSamp : sampler           (linear, repeat — also
 *                                                kept for layout parity).
 *     binding(7) uDepth     : texture_2d<f32>   (shared depth texture for
 *                                                Mist / Glow, populated by
 *                                                either the runtime depth
 *                                                track or the internal
 *                                                debug probe; 0=near / 1=far.
 *                                                Gated by uComposite.lens.w =
 *                                                depthMistGain).
 */
declare const compositeFragmentWgsl = "\nstruct Composite {\n  // (resolution.xy, imageResolution.xy)\n  resolution: vec4f,\n  // (bloomStrength, halationIntensity, vignette, grainIntensity)\n  effects: vec4f,\n  // (grainSize, grainRadialMix, fitMode, time)\n  grainFit: vec4f,\n  // (lensSoftness, aberrationEdgeSoften, diffusion, _)\n  lens: vec4f,\n  // (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)\n  optics: vec4f,\n  // (rayAngleProbe, _, _, _)\n  debug: vec4f,\n  // (directTransmission, blackRetention, scatterStrength, highlightReactivity)\n  optical: vec4f,\n  // (warmScatter, spectralTail, _, _)\n  opticalColor: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uComposite: Composite;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uBloom: texture_2d<f32>;\n@group(1) @binding(3) var uHalation: texture_2d<f32>;\n@group(1) @binding(4) var uDiffusion: texture_2d<f32>;\n@group(1) @binding(5) var uSampler: sampler;\n@group(1) @binding(6) var uGrainSampler: sampler;\n@group(1) @binding(7) var uDepth: texture_2d<f32>;\n\nconst LUMA_R709 = vec3f(0.2126, 0.7152, 0.0722);\nconst RAY_ANGLE_REFERENCE_TAN_HALF_HFOV: f32 = 0.6370702608; // tan(65deg / 2)\n\nfn fitUv(uv: vec2f, resolution: vec2f, imageResolution: vec2f, fitMode: f32) -> vec2f {\n  let screenAspect = resolution.x / max(resolution.y, 1.0);\n  let imageAspect = imageResolution.x / max(imageResolution.y, 1.0);\n  let coverScale = select(\n    vec2f(screenAspect / imageAspect, 1.0),\n    vec2f(1.0, imageAspect / screenAspect),\n    screenAspect > imageAspect,\n  );\n  let containScale = select(\n    vec2f(1.0, imageAspect / screenAspect),\n    vec2f(screenAspect / imageAspect, 1.0),\n    screenAspect > imageAspect,\n  );\n  let scale = mix(coverScale, containScale, fitMode);\n  var result = (uv - vec2f(0.5)) * scale + vec2f(0.5);\n  let narrowPortrait = step(2.0, scale.x) * fitMode;\n  result.x = result.x + 0.18 * scale.x * narrowPortrait;\n  return result;\n}\n\nfn insideUv(uv: vec2f) -> f32 {\n  let s = step(vec2f(0.0), uv) * step(uv, vec2f(1.0));\n  return s.x * s.y;\n}\n\nfn rayAngleMask(\n  imageUv: vec2f,\n  imageResolution: vec2f,\n  tanHalfFov: vec2f,\n  innerThreshold: f32,\n) -> f32 {\n  let sensor = (imageUv - vec2f(0.5)) * 2.0;\n  let ray = sensor * max(tanHalfFov, vec2f(1e-4));\n  let viewZ = 1.0 / sqrt(dot(ray, ray) + 1.0);\n  let incidence = 1.0 - viewZ;\n  let aspectY = imageResolution.y / max(imageResolution.x, 1.0);\n  let cornerRay = vec2f(\n    RAY_ANGLE_REFERENCE_TAN_HALF_HFOV,\n    RAY_ANGLE_REFERENCE_TAN_HALF_HFOV * aspectY,\n  );\n  let maxIncidence = 1.0 - (1.0 / sqrt(dot(cornerRay, cornerRay) + 1.0));\n  let normalized = clamp(incidence / max(maxIncidence, 1e-5), 0.0, 1.0);\n  return smoothstep(clamp(innerThreshold, 0.0, 0.8), 1.0, pow(normalized, 1.4));\n}\n\n// Soft shoulder: map HDR glow energy into a [0,1] screen-blend opacity so\n// bloom + halation don't clip into flat white plates.\nfn glowShoulder(energy: vec3f) -> vec3f {\n  return vec3f(1.0) - exp(-max(energy, vec3f(0.0)));\n}\n\nfn glowHeadroom(baseRgb: vec3f, floorValue: f32) -> f32 {\n  let luma = dot(baseRgb, LUMA_R709);\n  let k = sqrt(clamp(1.0 - luma, 0.0, 1.0));\n  return mix(floorValue, 1.0, k);\n}\n\n// --- Film grain (WebGL parity) ---\n//\n// Coarse path uses the current per-pixel hash silver-halide look; low-end uses\n// a calmer structured fine-grain basis and smoothly crossfades into coarse.\nfn grainPixelHash(p: vec2f, seed: f32) -> f32 {\n  let s = sin(dot(p + vec2f(seed), vec2f(12.9898, 78.233))) * 43758.5453;\n  return fract(s) - 0.5;\n}\n\n// Low-frequency smooth noise for grain density modulation (clumping).\nfn grainClumpHash(p: vec2f) -> f32 {\n  var p3 = fract(vec3f(p.x, p.y, p.x) * 0.1031);\n  p3 = p3 + vec3f(dot(p3, p3.yzx + vec3f(33.33)));\n  return fract((p3.x + p3.y) * p3.z);\n}\n\nfn grainClumpNoise(p: vec2f) -> f32 {\n  let i = floor(p);\n  var f = fract(p);\n  f = f * f * (vec2f(3.0) - 2.0 * f);\n  let a = grainClumpHash(i);\n  let b = grainClumpHash(i + vec2f(1.0, 0.0));\n  let c = grainClumpHash(i + vec2f(0.0, 1.0));\n  let d = grainClumpHash(i + vec2f(1.0, 1.0));\n  return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);\n}\n\nfn grainRotate(p: vec2f, angle: f32) -> vec2f {\n  let s = sin(angle);\n  let c = cos(angle);\n  return vec2f(p.x * c - p.y * s, p.x * s + p.y * c);\n}\n\nfn grainFineNoise(p: vec2f, fineScale: f32, seedA: f32, seedB: f32) -> f32 {\n  let q0 = grainRotate(p * fineScale + vec2f(seedA * 0.37, seedB * 0.19), 0.61);\n  let q1 = grainRotate(\n    p * (fineScale * 1.41) + vec2f(seedB * 0.23 + 17.0, seedA * 0.41 + 9.0),\n    -0.73,\n  );\n  let n0 = grainClumpNoise(q0) - 0.5;\n  let n1 = grainClumpNoise(q1) - 0.5;\n  return mix(n0, n1, 0.42);\n}\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let resolution = uComposite.resolution.xy;\n  let imageResolution = uComposite.resolution.zw;\n  let bloomStrength = uComposite.effects.x;\n  let halationIntensity = uComposite.effects.y;\n  let vignette = uComposite.effects.z;\n  let grainIntensity = uComposite.effects.w;\n  let grainSize = uComposite.grainFit.x;\n  let grainRadialMix = uComposite.grainFit.y;\n  let fitMode = uComposite.grainFit.z;\n  let time = uComposite.grainFit.w;\n  let lensSoftness = clamp(uComposite.lens.x, 0.0, 1.0);\n  let aberrationEdgeSoften = clamp(uComposite.lens.y, 0.0, 1.0);\n  let diffusion = clamp(uComposite.lens.z, 0.0, 1.0);\n  let opticalDirectTransmission = clamp(uComposite.optical.x, 0.0, 1.0);\n  let opticalBlackRetention = clamp(uComposite.optical.y, 0.0, 1.0);\n  let opticalScatterStrength = clamp(uComposite.optical.z, 0.0, 1.0);\n  let opticalHighlightReactivity = clamp(uComposite.optical.w, 0.0, 1.0);\n  let opticalWarmScatter = clamp(uComposite.opticalColor.x, 0.0, 1.0);\n  let opticalSpectralTail = clamp(uComposite.opticalColor.y, 0.0, 1.0);\n  // Shared depth-aware Mist control:\n  //   0.0      = no depth modulation (uniform mist, WebGL parity)\n  //   0.0..1.0 = depth-modulated mist (near = 0x, far = (1 + 4*gain)x)\n  //   >= 1.5   = internal debug view: render raw depth texture as grayscale\n  //              (bypasses all subsequent stages \u2014 for alignment check only).\n  let depthMistGain = clamp(uComposite.lens.w, 0.0, 2.0);\n\n  if (uComposite.debug.x >= 0.5) {\n    let imageUv = fitUv(uv, resolution, imageResolution, fitMode);\n    let m = rayAngleMask(\n      imageUv,\n      imageResolution,\n      uComposite.optics.xy,\n      uComposite.optics.z,\n    ) * insideUv(imageUv);\n    return vec4f(m, m, m, 1.0);\n  }\n\n  // Debug view: show the depth texture directly over the image-space UV\n  // so we can confirm the AI depth map is uploaded and aligned before\n  // judging its effect on mist. The depth PNG is in IMAGE aspect, while\n  // the canvas may be a different aspect \u2014 so sample in image-fit UV\n  // (same transform vignette uses).\n  if (depthMistGain >= 1.5) {\n    let depthUv = fitUv(uv, uComposite.resolution.xy, uComposite.resolution.zw, uComposite.grainFit.z);\n    let d = textureSampleLevel(uDepth, uSampler, depthUv, 0.0).r;\n    return vec4f(d, d, d, 1.0);\n  }\n\n  // --- Lens softness + aberration edge soften (WebGL parity) ---\n  // Edge mask weighting: periphery gets more of the 8-tap blur. Cardinal\n  // vs diagonal directions are both used (8 taps total) to keep the soft\n  // periphery isotropic instead of X-shaped.\n  var edgeDelta = uv - vec2f(0.5);\n  edgeDelta.x = edgeDelta.x * (resolution.x / max(resolution.y, 1.0));\n  let edgeR = clamp(length(edgeDelta) * 1.414, 0.0, 1.0);\n  let edgeMask = smoothstep(0.25, 1.0, edgeR);\n  let sharpRgb = textureSampleLevel(uSource, uSampler, uv, 0.0).rgb;\n  let lensR = clamp(length(edgeDelta) * 2.0, 0.0, 1.0);\n  let lensW = pow(lensR, 1.52);\n  // \u03B3 < 1 so mid-slider positions stay visible (matches WebGL).\n  let lensDrive = pow(lensSoftness, 0.78);\n  let lensWeight = clamp(lensDrive * lensW, 0.0, 1.0);\n  // Blur radius grows with aberration + lens softness. Capped to 4.2 px so\n  // we don't smear fine detail even at slider 1.0.\n  var blurRadiusPx = mix(1.5, 2.75, aberrationEdgeSoften) + lensWeight * 1.35;\n  blurRadiusPx = min(blurRadiusPx, 4.2);\n  let px = vec2f(1.0 / max(resolution.x, 1.0), 1.0 / max(resolution.y, 1.0)) * blurRadiusPx;\n  let diag = px * 0.70710678;\n  let blurRgb = (\n      textureSampleLevel(uSource, uSampler, uv + vec2f(px.x, 0.0), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv - vec2f(px.x, 0.0), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv + vec2f(0.0, px.y), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv - vec2f(0.0, px.y), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv + vec2f(diag.x,  diag.y), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv + vec2f(diag.x, -diag.y), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv + vec2f(-diag.x,  diag.y), 0.0).rgb\n    + textureSampleLevel(uSource, uSampler, uv + vec2f(-diag.x, -diag.y), 0.0).rgb\n  ) * 0.125;\n  let lensMix = lensWeight * 0.72;\n  let softenAmt = clamp(aberrationEdgeSoften * edgeMask + lensMix * edgeMask, 0.0, 1.0);\n  var color = vec4f(mix(sharpRgb, blurRgb, softenAmt), 1.0);\n  let baseRgb = color.rgb;\n\n  // Bloom + halation screen-blend with soft shoulder (WebGL parity).\n  // Sample with flipped uv.y: bloom/halation accumulate an odd number of\n  // fullscreen render passes relative to uSource, so their texture rows\n  // arrive inverted along y. This single y-flip at sample time re-aligns\n  // them with the base without touching the pyramid or the vertex shader.\n  let glowUv = vec2f(uv.x, 1.0 - uv.y);\n  let bloom = textureSampleLevel(uBloom, uSampler, glowUv, 0.0).rgb * bloomStrength;\n  let halation = textureSampleLevel(uHalation, uSampler, glowUv, 0.0).rgb * halationIntensity;\n  var diffused = vec3f(0.0);\n  if (diffusion > 0.0) {\n    diffused = textureSampleLevel(uDiffusion, uSampler, glowUv, 0.0).rgb;\n  }\n\n  if (opticalScatterStrength > 0.0) {\n    let baseLuma = dot(baseRgb, LUMA_R709);\n    let shadowHold = 1.0 - smoothstep(0.02, 0.34, baseLuma);\n    let directLoss =\n      (1.0 - opticalDirectTransmission)\n      * opticalScatterStrength\n      * (1.0 - shadowHold * opticalBlackRetention * 0.75);\n    let direct = color.rgb * (1.0 - directLoss);\n\n    let highlightMask = smoothstep(0.42, 1.28, dot(max(baseRgb, vec3f(0.0)), LUMA_R709));\n    let highlightDrive = mix(1.0, 1.0 + highlightMask * 1.65, opticalHighlightReactivity);\n    let blackProtect = mix(1.0, smoothstep(0.04, 0.48, baseLuma), opticalBlackRetention);\n    let warmBias = vec3f(\n      1.0 + opticalWarmScatter * 0.18 + opticalSpectralTail * 0.12,\n      1.0 + opticalWarmScatter * 0.05,\n      1.0 - opticalWarmScatter * 0.10 - opticalSpectralTail * 0.08,\n    );\n    let scatterEnergy =\n      bloom * 0.82\n      + halation * 1.08\n      + diffused * diffusion * 0.24;\n    let scatter = glowShoulder(\n      scatterEnergy\n      * warmBias\n      * opticalScatterStrength\n      * highlightDrive\n      * blackProtect,\n    );\n    color = vec4f(direct + scatter, color.a);\n  } else {\n    let glow = glowShoulder(bloom + halation) * glowHeadroom(baseRgb, 0.82);\n    color = vec4f(vec3f(1.0) - (vec3f(1.0) - color.rgb) * (vec3f(1.0) - glow), color.a);\n\n    if (diffusion > 0.0) {\n    // Shared depth-aware Mist path: depth shaping is now applied UPSTREAM, in\n    // diffusion-depth-prefilter.frag, so the diffusion pyramid input is\n    // already depth-weighted at the source before any blur. Composite\n    // therefore just samples the pre-baked halo without a per-pixel depth\n    // mask, which removes the ghost / double-image that appeared when a\n    // sharp depth cut was applied after the pyramid had bled across\n    // silhouettes. WebGL parity is preserved: when depthMistGain = 0 the\n    // prefilter is skipped and the pyramid receives raw colorGraded.\n      let diffOpacity = glowShoulder(diffused * diffusion * 0.29) * glowHeadroom(baseRgb, 0.88);\n      color = vec4f(\n        vec3f(1.0) - (vec3f(1.0) - color.rgb) * (vec3f(1.0) - diffOpacity),\n        color.a,\n      );\n    }\n  }\n\n  // Vignette in image space (follows image frame).\n  let vigUv = fitUv(uv, resolution, imageResolution, fitMode);\n  let vigMask = insideUv(vigUv);\n  let dist = length(vigUv - vec2f(0.5)) * 1.414;\n  let vig = 1.0 - vignette * dist * dist;\n  color = vec4f(color.rgb * mix(1.0, clamp(vig, 0.0, 1.0), vigMask), color.a);\n\n  // --- Grain: low-end fine grain + high-end clumped silver-halide hybrid ---\n  let grainCenterUv = fitUv(uv, resolution, imageResolution, fitMode);\n  let grainBoundaryMask = insideUv(grainCenterUv);\n  var grainDelta = grainCenterUv - vec2f(0.5);\n  grainDelta.x = grainDelta.x * (imageResolution.x / max(imageResolution.y, 1.0));\n  let grainRadial = clamp(length(grainDelta) * 2.0, 0.0, 1.0);\n  let grainRadialWeight = pow(grainRadial, 1.65);\n  let grainRadialEffective = mix(1.0, grainRadialWeight, clamp(grainRadialMix, 0.0, 1.0));\n\n  let grainSizeClamped = clamp(grainSize, 0.0, 1.0);\n  let coarseBlend = smoothstep(0.08, 0.28, grainSizeClamped);\n\n  // Deterministic temporal stepping for preview/export parity. Fine grain\n  // updates a little more slowly than coarse grain to keep the low end calm.\n  let grainFrame = floor(time * mix(2.0, 3.0, coarseBlend));\n\n  let pixCoord = uv * resolution;\n  let fineWarp = vec2f(\n    grainClumpNoise(pixCoord / 96.0 + vec2f(11.7, grainFrame * 0.07 + 3.1)),\n    grainClumpNoise(pixCoord / 96.0 + vec2f(grainFrame * 0.09 + 5.3, 23.4)),\n  ) - vec2f(0.5);\n  let fineCoord = pixCoord + fineWarp * 1.45;\n  let fineScale = mix(1.75, 1.05, smoothstep(0.0, 0.25, grainSizeClamped));\n  let fineLuma = grainFineNoise(\n    fineCoord,\n    fineScale,\n    grainFrame * 1.13 + 7.0,\n    grainFrame * 1.71 + 19.0,\n  );\n  let fineChromaStrength = mix(0.035, 0.16, smoothstep(0.02, 0.24, grainSizeClamped));\n  let fineChromaR = grainFineNoise(\n    fineCoord + vec2f(17.0, 0.0),\n    fineScale * 1.07,\n    grainFrame * 1.37 + 41.0,\n    grainFrame * 1.91 + 67.0,\n  ) * fineChromaStrength;\n  let fineChromaB = grainFineNoise(\n    fineCoord + vec2f(0.0, 19.0),\n    fineScale * 1.11,\n    grainFrame * 1.53 + 83.0,\n    grainFrame * 2.07 + 109.0,\n  ) * fineChromaStrength;\n\n  // Coarse path preserves the current sharp per-pixel character.\n  let coarseLuma = grainPixelHash(pixCoord, grainFrame * 1.7);\n  let coarseChromaR = grainPixelHash(pixCoord, grainFrame * 2.3 + 500.0) * 0.3;\n  let coarseChromaB = grainPixelHash(pixCoord, grainFrame * 3.1 + 1000.0) * 0.3;\n\n  let fineDensity = mix(\n    0.92,\n    1.08,\n    grainClumpNoise(pixCoord / 180.0 + vec2f(grainFrame * 0.11, 31.0)),\n  );\n  let clumpScale = mix(80.0, 20.0, grainSizeClamped);\n  let coarseClump = grainClumpNoise(pixCoord / clumpScale + vec2f(grainFrame * 0.5));\n  let coarseDensity = mix(1.0, 0.3 + coarseClump * 1.4, grainSizeClamped * 0.7);\n  let densityMod = mix(fineDensity, coarseDensity, coarseBlend);\n\n  let lumaGrain = mix(fineLuma, coarseLuma, coarseBlend);\n  let chromaR = mix(fineChromaR, coarseChromaR, coarseBlend);\n  let chromaB = mix(fineChromaB, coarseChromaB, coarseBlend);\n  let lowEndPresence = mix(1.06, 1.0, coarseBlend);\n\n  let grainWeight =\n    grainIntensity * 0.5 * grainRadialEffective * grainBoundaryMask * lowEndPresence;\n  var rgb = color.rgb;\n  rgb.r = rgb.r + (lumaGrain + chromaR) * grainWeight * densityMod;\n  rgb.g = rgb.g + lumaGrain * grainWeight * densityMod;\n  rgb.b = rgb.b + (lumaGrain + chromaB) * grainWeight * densityMod;\n  color = vec4f(clamp(rgb, vec3f(0.0), vec3f(1.0)), color.a);\n\n  // Keep the legacy repeat sampler live so the bind-group layout does not\n  // need to change even though grain is now procedural.\n  let legacySamplerKeepalive = textureSampleLevel(uDiffusion, uGrainSampler, glowUv, 0.0).r;\n  color = vec4f(color.rgb + vec3f(legacySamplerKeepalive) * 0.0, color.a);\n\n  // rgba8unorm-srgb handles the final clamp + OETF automatically.\n  return vec4f(color.rgb, 1.0);\n}\n";

declare const detailSoftnessFragmentWgsl = "\nstruct DetailSoftnessUniforms {\n  // x: effectiveDetailSoftness, y: kernelRadiusPx,\n  // z: chromaAttenScale, w: edgeGuardLo\n  p0: vec4f,\n  // x: edgeGuardHi, y: highlightBias,\n  // z: inverse width, w: inverse height\n  p1: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: DetailSoftnessUniforms;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\nfn luma709(rgb: vec3f) -> f32 {\n  return dot(rgb, vec3f(0.2126, 0.7152, 0.0722));\n}\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let center = textureSampleLevel(uSource, uSampler, uv, 0.0);\n  let effective = uParams.p0.x;\n  if (effective < 0.0001) {\n    return center;\n  }\n\n  let r = max(uParams.p0.y, 0.0001);\n  let chromaAttenScale = uParams.p0.z;\n  let edgeGuardLo = uParams.p0.w;\n  let edgeGuardHi = uParams.p1.x;\n  let highlightBias = uParams.p1.y;\n  let texel = vec2f(uParams.p1.z, uParams.p1.w) * r;\n  let lumaWeights = vec3f(0.2126, 0.7152, 0.0722);\n\n  let srcRGB = center.rgb;\n  let nR = textureSampleLevel(uSource, uSampler, uv + vec2f(texel.x, 0.0), 0.0).rgb;\n  let nL = textureSampleLevel(uSource, uSampler, uv - vec2f(texel.x, 0.0), 0.0).rgb;\n  let nU = textureSampleLevel(uSource, uSampler, uv + vec2f(0.0, texel.y), 0.0).rgb;\n  let nD = textureSampleLevel(uSource, uSampler, uv - vec2f(0.0, texel.y), 0.0).rgb;\n\n  let localRef = (srcRGB + nR + nL + nU + nD) * 0.2;\n  let detail = srcRGB - localRef;\n\n  let lumaCenter = luma709(srcRGB);\n  let lumaGrad =\n    abs(luma709(nR) - luma709(nL)) * 0.5 +\n    abs(luma709(nU) - luma709(nD)) * 0.5;\n  let edgeGuard = 1.0 - smoothstep(edgeGuardLo, edgeGuardHi, lumaGrad);\n  let highlightWeight = mix(1.0, highlightBias, smoothstep(0.6, 0.9, lumaCenter));\n\n  let lumaAtten = effective * edgeGuard * highlightWeight;\n  let chromaAtten = lumaAtten * chromaAttenScale;\n  let detailLuma = dot(detail, lumaWeights);\n  let detailLumaVec = detailLuma * lumaWeights;\n  let detailChroma = detail - detailLumaVec;\n  let softened = srcRGB - (detailLumaVec * lumaAtten) - (detailChroma * chromaAtten);\n  return vec4f(softened, center.a);\n}\n";

/**
 * motionblur-feedback (WGSL) — Phase 2 T2-4.
 *
 * Writes the current graded/composited frame into the next ring slot,
 * optionally mixing in the most recently written slot for extended trail.
 * Ported from `src/webgl/shaders/motionblur.frag.ts` `feedbackCopy` shader.
 *
 * Bind group layout (group 1):
 *   binding(0) uParams : Params  (trail, hasPrev, _, _)
 *   binding(1) uSource : texture_2d<f32>  (composited current frame)
 *   binding(2) uPrev   : texture_2d<f32>  (previous ring slot; black when hasPrev=0)
 *   binding(3) uSampler: sampler
 */
declare const motionblurFeedbackFragmentWgsl = "\nstruct Params {\n  // (trail, hasPrev, _, _) \u2014 trail is scaled by hasPrev so a fresh ring\n  // (no valid previous slot) falls back to a clean copy without requiring\n  // a separate pipeline.\n  trail: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uSource: texture_2d<f32>;\n@group(1) @binding(2) var uPrev: texture_2d<f32>;\n@group(1) @binding(3) var uSampler: sampler;\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let src = textureSampleLevel(uSource, uSampler, uv, 0.0);\n  let prev = textureSampleLevel(uPrev, uSampler, uv, 0.0);\n  let t = clamp(uParams.trail.x * uParams.trail.y, 0.0, 0.95);\n  return mix(src, prev, t);\n}\n";

/**
 * motionblur-blend (WGSL) — Phase 2 T2-4.
 *
 * N-slot weighted average over the 8-layer ring buffer
 * (`texture_2d_array<f32>`, DIRECTION §4). CPU pre-normalizes weights so
 * `weights[i] = 0` for `i >= activeFrames` — removes the branch the WebGL
 * path used, keeps the loop tight + gradient-free.
 *
 * Motion detection compares newest vs oldest slot luminance and fades
 * toward the newest frame for stationary pixels (`motionThreshold > 0`).
 * `motionThreshold = 0` disables detection — always use the blurred
 * average. CPU passes `oldestSlot` directly so the shader doesn't need
 * to know `activeFrames`.
 *
 * Bind group layout (group 1):
 *   binding(0) uParams : Params (weights[0..7] packed into 2 vec4 +
 *                        (currentSlot, oldestSlot, motionThreshold, _))
 *   binding(1) uRing   : texture_2d_array<f32>  (8 layers)
 *   binding(2) uSampler: sampler
 */
declare const motionblurBlendFragmentWgsl = "\nstruct Params {\n  // weights[0..3] \u2014 index 0 = newest, 7 = oldest.\n  weights0: vec4f,\n  weights1: vec4f,\n  // (currentSlot, oldestSlot, motionThreshold, _)\n  ring: vec4f,\n};\n\n@group(1) @binding(0) var<uniform> uParams: Params;\n@group(1) @binding(1) var uRing: texture_2d_array<f32>;\n@group(1) @binding(2) var uSampler: sampler;\n\nconst LUMA_R709 = vec3f(0.2126, 0.7152, 0.0722);\n\n@fragment\nfn fs_main(@location(0) uv: vec2f) -> @location(0) vec4f {\n  let currentSlot = i32(uParams.ring.x);\n  let oldestSlot = i32(uParams.ring.y);\n  let motionThreshold = uParams.ring.z;\n\n  var weights: array<f32, 8>;\n  weights[0] = uParams.weights0.x;\n  weights[1] = uParams.weights0.y;\n  weights[2] = uParams.weights0.z;\n  weights[3] = uParams.weights0.w;\n  weights[4] = uParams.weights1.x;\n  weights[5] = uParams.weights1.y;\n  weights[6] = uParams.weights1.z;\n  weights[7] = uParams.weights1.w;\n\n  var sum = vec4f(0.0);\n  for (var i: i32 = 0; i < 8; i = i + 1) {\n    // +16 keeps the intermediate non-negative for every (currentSlot, i)\n    // pair in [0..7] \u00D7 [0..7]; the % 8 then wraps cleanly.\n    let layer = (currentSlot - i + 16) % 8;\n    let sample = textureSampleLevel(uRing, uSampler, uv, layer, 0.0);\n    sum = sum + sample * weights[i];\n  }\n\n  let newest = textureSampleLevel(uRing, uSampler, uv, currentSlot, 0.0);\n  let oldest = textureSampleLevel(uRing, uSampler, uv, oldestSlot, 0.0);\n  let lumaDelta = abs(dot(newest.rgb - oldest.rgb, LUMA_R709));\n  let motionMask = select(\n    1.0,\n    smoothstep(motionThreshold * 0.5, motionThreshold * 2.0, lumaDelta),\n    motionThreshold > 0.0,\n  );\n\n  return mix(newest, sum, motionMask);\n}\n";

/**
 * gradeUniforms — TS packer for the 9-vec4 WGSL `Grade` struct.
 *
 * Mirrors `filmlab.frag.wgsl` layout exactly. Missing fields fall back to
 * neutral defaults so a partial params record (e.g. preset resolution
 * only) still yields a valid upload. Consumers should feed the full
 * `BuiltViewportParams` blob from `viewport-to-params` / `batch-pipeline`.
 *
 * Layout (vec4 index × 4 floats = 36 floats = 144 bytes):
 *   0: (exposure, contrast, saturation, _pad)
 *   1: (temperature, tint, fade, rgbShift)
 *   2: (highlights, shadows, compAmount, compRange)
 *   3: (shadowTint.r, shadowTint.g, shadowTint.b, _pad)
 *   4: (highlightTint.r, highlightTint.g, highlightTint.b, _pad)
 *   5: (splitPosition, lut1Intensity, lut1Enabled, lut2Intensity)
 *   6: (lut2Enabled, cyan, magenta, yellow)
 *   7: (printContrast, fitMode, imgResX, imgResY)
 *   8: (resolutionX, resolutionY, time, _pad)
 */
declare const GRADE_UNIFORM_FLOATS = 36;
declare const GRADE_UNIFORM_BYTES: number;
interface GradeFrameState {
    /** Canvas render resolution. */
    resolutionX: number;
    resolutionY: number;
    /** Source image / video resolution, used by the cover/contain fit math. */
    imgResX: number;
    imgResY: number;
    /** 0.0 = cover, 1.0 = contain. */
    fitMode: number;
    /** Seconds since start — feeds time-based effects (grain etc.). */
    time: number;
    /** Before/after split slider in [-1, 1]; -1 disables the split UI. */
    splitPosition: number;
    /**
     * v1 compare-bar toggle: when true, the present pass is replaced by a
     * full-screen "ungraded source" pipeline. Slot params are not honored
     * on WebGPU v1 (dual-slot simultaneous A/B is deferred); see
     * `compare-source.frag.wgsl.ts`.
     */
    compareEnabled: boolean;
    /** Raw grade parameters (keys in film-lab-core `Params`). */
    params: Record<string, number | string | boolean>;
    /** LUT1 intensity (multiplied against lut1Enabled at pack time). */
    lut1Intensity: number;
    lut1Enabled: boolean;
    lut2Intensity: number;
    lut2Enabled: boolean;
}
declare function packGradeUniforms(state: GradeFrameState, out?: Float32Array): Float32Array;

/**
 * compositeUniforms — TS packer for the composite.wgsl `Composite` struct.
 *
 * Phase 2 T2-3 + v1.0 parity (2026-04-19). Mirrors the 8-vec4 layout defined
 * in `shaders/composite.frag.wgsl.ts`. Numeric params fall back to neutral
 * defaults so a partial params record still yields a valid upload.
 *
 * Layout (8 vec4 × 4 floats = 32 floats = 128 bytes):
 *   0: (resolutionX, resolutionY, imageResX, imageResY)
 *   1: (bloomStrength, halationIntensity, vignette, grainIntensity)
 *   2: (grainSize, grainRadialMix, fitMode, time)
 *   3: (lensSoftness, aberrationEdgeSoften, diffusion, depthMistGain)
 *   4: (tanHalfFovX, tanHalfFovY, innerThreshold, fallbackFlag)
 *   5: (rayAngleProbe, _, _, _)
 *   6: (opticalDirectTransmission, opticalBlackRetention,
 *       opticalScatterStrength, opticalHighlightReactivity)
 *   7: (opticalWarmScatter, opticalSpectralTail, _, _)
 *
 * `depthMistGain` is the shared depth-aware Mist gain (0 = uniform mist,
 * 1 = full depth modulation). Values >= 1.5 stay reserved for the internal
 * raw-depth debug view. See `composite.frag.wgsl.ts` binding(7) uDepth.
 */
declare const COMPOSITE_UNIFORM_FLOATS = 32;
declare const COMPOSITE_UNIFORM_BYTES: number;
interface CompositeFrameState {
    resolutionX: number;
    resolutionY: number;
    imgResX: number;
    imgResY: number;
    fitMode: number;
    time: number;
    params: Record<string, number | string | boolean>;
}
declare function packCompositeUniforms(state: CompositeFrameState, out?: Float32Array): Float32Array;
/**
 * Parse a `#rrggbb` / `#rgb` hex string into linear-ish 0..1 components.
 * Matches the WebGL backend's `hexToVec3` so halation color upload produces
 * the same tint for a given preset string. Inputs are treated as sRGB
 * encoded, but the WebGL path also feeds them into the shader without an
 * sRGB→linear step, so parity is the safe choice here.
 */
declare function hexToRgbTriple(hex: string): [number, number, number];

/**
 * Pure helpers for cross-filter runtime state transitions.
 *
 * Extracted so Hard-mode gating and temporal-history reset semantics can
 * be verified in a non-GPU test environment. Do not depend on any WebGPU
 * types here — this module stays side-effect free so unit tests under the
 * desktop-app's vitest setup can import it directly.
 */
/**
 * Minimum |Δ| on `crossFilterMinSpacing` that counts as a "material"
 * change. The current product floor fixes spacing at 1.0, but keep the
 * legacy epsilon contract so older snapshots remain well-defined if this
 * parameter becomes variable again.
 */
declare const CROSS_FILTER_MIN_SPACING_EPSILON = 0.0001;
/**
 * Hard-mode temporal hold was authored as "0.82 per frame" in WebGL.
 * Preview, however, renders on RAF cadence while export renders at the
 * fixed video-export cadence. Treat 24 fps as the reference contract so
 * both paths can derive the same real-time decay.
 */
declare const CROSS_FILTER_TEMPORAL_REFERENCE_FPS = 24;
declare const CROSS_FILTER_TEMPORAL_REFERENCE_DECAY = 0.82;
/**
 * Hard Mode is "active" only when the user has both:
 *   - engaged the cross filter (`crossFilterStrength > 0`), and
 *   - selected Hard Mode (`crossFilterHardMode >= 0.5`).
 *
 * This predicate drives both diffusion suppression (composite input is
 * zeroed) and the post-chain's temporal + central-bloom stages.
 */
declare function isCrossFilterHardModeActive(crossFilterStrength: number, crossFilterHardMode: number): boolean;
/**
 * Effective diffusion contribution fed to the composite uniform and used
 * to gate the diffusion pyramid build. Hard Mode forces 0; otherwise the
 * user's value passes through clamped to [0, 1].
 *
 * The user's `diffusion` field is NEVER mutated — this function only
 * computes the frame-local effective value.
 */
declare function effectiveDiffusionAmount(userDiffusion: number, hardModeActive: boolean): number;
/**
 * Convert the legacy "0.82 per 24 fps frame" temporal hold into an
 * elapsed-time-based decay factor. This keeps preview (RAF cadence) and
 * fixed-fps export aligned in real time instead of render-count space.
 */
declare function computeCrossFilterTemporalDecay(deltaSeconds: number, referenceFps?: number, referenceDecay?: number): number;
interface CrossFilterHistorySnapshot {
    /** Clamped `crossFilterStrength` ∈ [0, 1]. */
    readonly strength: number;
    /** Quantized Hard Mode — 0 or 1. */
    readonly hardMode: 0 | 1;
    /** Current public `crossFilterMinSpacing` snapshot (1–2 in current UI). */
    readonly minSpacing: number;
}
/**
 * Decide whether the cross-filter temporal history ring should be reset
 * given the prior-frame and current-frame snapshots.
 *
 * WebGL parity — the history is reset when:
 *   1. Hard Mode flips between Soft (0) and Hard (1).
 *   2. `crossFilterStrength` transitions from nonzero to 0.
 *   3. `crossFilterMinSpacing` crosses the epsilon.
 *
 * Resolution changes are handled separately in `setResolution`.
 */
declare function shouldResetCrossFilterHistory(prev: CrossFilterHistorySnapshot, next: CrossFilterHistorySnapshot): boolean;

type RayAngleOpticsSource = CameraOpticsSource | "fallback65";
interface ResolvedRayAngleOptics {
    tanHalfFovX: number;
    tanHalfFovY: number;
    source: RayAngleOpticsSource;
}
declare const RAY_ANGLE_FALLBACK_HFOV_DEG = 65;
declare const RAY_ANGLE_FOV_MIN_DEG = 1;
declare const RAY_ANGLE_FOV_MAX_DEG = 178;
declare const RAY_ANGLE_REFERENCE_TAN_HALF_HFOV: number;
declare const DEFAULT_RAY_ANGLE_INNER_THRESHOLD = 0.1;
declare function resolveRayAngleOptics(optics: CameraOptics | null | undefined, imageWidth: number, imageHeight: number): ResolvedRayAngleOptics;
declare function rayAngleMaskValue(options: {
    imageUvX: number;
    imageUvY: number;
    imageWidth: number;
    imageHeight: number;
    optics?: CameraOptics | ResolvedRayAngleOptics | null;
    gamma?: number;
    innerThreshold?: number;
}): number;

export { BlueNoiseTile, COMPOSITE_UNIFORM_BYTES, COMPOSITE_UNIFORM_FLOATS, CROSS_FILTER_MIN_SPACING_EPSILON, CROSS_FILTER_TEMPORAL_REFERENCE_DECAY, CROSS_FILTER_TEMPORAL_REFERENCE_FPS, type CompositeFrameState, type CrossFilterHistorySnapshot, DEFAULT_RAY_ANGLE_INNER_THRESHOLD, GRADE_UNIFORM_BYTES, GRADE_UNIFORM_FLOATS, GpuContext, GpuContextCreationError, type GpuContextLossInfo, type GpuContextLossReason, type GradeFrameState, Lut3DTexture, MOTION_BLUR_RING_SLOTS, MediaTexture, OffscreenTargetPool, RAY_ANGLE_FALLBACK_HFOV_DEG, RAY_ANGLE_FOV_MAX_DEG, RAY_ANGLE_FOV_MIN_DEG, RAY_ANGLE_REFERENCE_TAN_HALF_HFOV, type RayAngleOpticsSource, RenderBackend, RenderBackendParams, type ResolvedRayAngleOptics, RingBuffer, ViewportCapabilities, ViewportContextLossInfo, ViewportContextLossReason, WebGPUBackend, type WebGPUBackendCreateOptions, blitFragmentWgsl, bloomPrefilterFragmentWgsl, compositeFragmentWgsl, computeCrossFilterTemporalDecay, detailSoftnessFragmentWgsl, downsampleFragmentWgsl, dustFragmentWgsl, effectiveDiffusionAmount, filmlabFragmentWgsl, fullscreenVertexWgsl, halationPrefilterFragmentWgsl, hexToRgbTriple, isCrossFilterHardModeActive, lightshaftsBlendFragmentWgsl, lightshaftsFragmentWgsl, motionblurBlendFragmentWgsl, motionblurFeedbackFragmentWgsl, packCompositeUniforms, packGradeUniforms, rayAngleMaskValue, resolveRayAngleOptics, shouldResetCrossFilterHistory, upsampleFragmentWgsl };
