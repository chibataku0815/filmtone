/**
 * Cross Filter pass — extracted verbatim from `WebGPUBackend.renderCrossFilter`
 * and its Hard-Mode-only helper `WebGPUBackend.renderCentralBloom`.
 *
 * `renderCentralBloom` is private to this module: nothing outside
 * `renderCrossFilter` ever called it on the original class, so it is not
 * re-exposed as a `WebGPUBackend` method.
 *
 * Behavior-preserving relocation only: no encode order, uniform packing, or
 * bind group contract changes relative to the original methods — including
 * the dormant (`WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED === false`)
 * temporal-hold branch, which is relocated as-is even though it never
 * executes in the current build.
 */

import type { OffscreenTargetPool } from "../OffscreenTargetPool";
import {
  CROSS_FILTER_TEMPORAL_REFERENCE_FPS,
  computeCrossFilterTemporalDecay,
} from "../crossFilterState";
import {
  DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
  type ResolvedRayAngleOptics,
} from "../rayAngleOptics";
import type { CrossFilterResources, Pipelines, PrefilterGroupLayouts, PyramidResources } from "./types";
import { computeMipWeights } from "./pyramid";

const CROSS_FILTER_SPACING_RADIUS_MAX_PX = 48.0;
const CROSS_FILTER_SPACING_RADIUS_STEP_PX = 24.0;
const CROSS_FILTER_THRESHOLD_HARD_BASELINE = 0.7;
const CROSS_FILTER_THRESHOLD_CONTROL_BASELINE = 0.92;
/** Number of cross-filter peak history ring slots (2 = ping-pong). */
const CROSS_FILTER_HISTORY_SLOTS = 2;
/**
 * Product divergence from WebGL parity: active WebGPU Hard Mode bypasses
 * the legacy temporal hold to remove the user-reported cross-filter trail.
 * The preserved history path stays compiled so its resources/state contract
 * and the elapsed-time normalization work remain intact for future tuning.
 */
const WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED = false;
/** Central bloom upsample radius (fixed, WebGL parity). */
const CENTRAL_BLOOM_RADIUS = 0.5;
const DEFAULT_CROSS_FILTER_DEPTH_GAIN = 0.25;
const DEFAULT_CROSS_FILTER_ANGLE_GAIN = 0.35;
const DEFAULT_CROSS_FILTER_EDGE_LENGTH_GAIN = 0.45;
const DEFAULT_CROSS_FILTER_EDGE_STRENGTH_GAIN = 0.25;

function smoothstep01(value: number): number {
  const clamped = Math.min(1, Math.max(0, value));
  return clamped * clamped * (3 - 2 * clamped);
}

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

function computeCrossFilterSpacingRadiusPx(
  minSpacing: number,
  minSpacingMin: number,
  minSpacingMax: number,
): number {
  const clamped = Math.min(
    minSpacingMax,
    Math.max(minSpacingMin, minSpacing),
  );
  let extraRadius = 0;
  for (
    let stepStart = minSpacingMin;
    stepStart < minSpacingMax;
    stepStart += 1
  ) {
    extraRadius +=
      CROSS_FILTER_SPACING_RADIUS_STEP_PX * smoothstep01(clamped - stepStart);
  }
  return Math.round(CROSS_FILTER_SPACING_RADIUS_MAX_PX + extraRadius);
}

export interface CentralBloomRenderDeps {
  device: GPUDevice;
  pool: OffscreenTargetPool;
  width: number;
  height: number;
  /** `CENTRAL_BLOOM_LEVELS` (also read by `WebGPUBackend`'s constructor). */
  levels: number;
  centralBloomPyramid: PyramidResources;
  /** `layouts.pyramid` bind group layout — shared across all pyramid-shaped passes. */
  layout: GPUBindGroupLayout;
  sampler: GPUSampler;
  downsamplePipeline: GPURenderPipeline;
  upsampleAddPipeline: GPURenderPipeline;
  crossFilterFlagsBindGroup: GPUBindGroup;
}

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
function renderCentralBloom(
  encoder: GPUCommandEncoder,
  heldPeakTexture: GPUTexture,
  deps: CentralBloomRenderDeps,
): GPUTexture {
  const {
    device,
    pool,
    width,
    height,
    levels: levelCount,
    centralBloomPyramid,
    layout,
    sampler,
    downsamplePipeline,
    upsampleAddPipeline,
    crossFilterFlagsBindGroup,
  } = deps;
  const halfWidth = Math.max(1, Math.floor(width / 2));
  const halfHeight = Math.max(1, Math.floor(height / 2));
  const levels: GPUTexture[] = [];
  for (let i = 0; i < levelCount; i++) {
    const divisor = 2 ** (i + 1);
    const w = Math.max(1, Math.floor(halfWidth / divisor));
    const h = Math.max(1, Math.floor(halfHeight / divisor));
    levels.push(
      pool.get(`rt.crossfilter.central-bloom.${i}`, {
        width: w,
        height: h,
        format: "rgba16float",
      }),
    );
  }
  const weights = computeMipWeights(
    CENTRAL_BLOOM_RADIUS,
    levels.length,
  );

  const sourceView = heldPeakTexture.createView();

  // Step 1 — seed mip 0 via `downsample` pipeline (not prefilter):
  // heldPeak (half-res) → mip 0 (half-res / 2).
  {
    const scratch = centralBloomPyramid.downsampleScratch[0]!;
    scratch[0] = 1 / heldPeakTexture.width;
    scratch[1] = 1 / heldPeakTexture.height;
    scratch[2] = 0;
    scratch[3] = 0;
    device.queue.writeBuffer(
      centralBloomPyramid.downsample[0]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: "centralBloom.seed.bg",
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: centralBloomPyramid.downsample[0]! } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "centralBloom.seed",
      colorAttachments: [
        {
          view: levels[0]!.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(downsamplePipeline);
    // Central bloom rides on the cross-filter (no-flip) contract for
    // every pass — mip 0 is sampled by `crossfilter.blend` alongside
    // the streak textures, which are themselves written under the
    // cross-filter contract. The generic bloom/halation pyramids use
    // the offscreen contract because they feed composite (which runs
    // under offscreen flags); this pyramid must NOT inherit that.
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  // Step 2 — progressive downsample mip[i-1] → mip[i].
  for (let i = 1; i < levels.length; i++) {
    const src = levels[i - 1]!;
    const dst = levels[i]!;
    const scratch = centralBloomPyramid.downsampleScratch[i]!;
    scratch[0] = 1 / src.width;
    scratch[1] = 1 / src.height;
    scratch[2] = 0;
    scratch[3] = 0;
    device.queue.writeBuffer(
      centralBloomPyramid.downsample[i]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: `centralBloom.downsample.${i}.bg`,
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: centralBloomPyramid.downsample[i]! } },
        { binding: 1, resource: src.createView() },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: `centralBloom.downsample.${i}`,
      colorAttachments: [
        {
          view: dst.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(downsamplePipeline);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  // Step 3 — additive upsample back to mip 0.
  for (let i = levels.length - 2; i >= 0; i--) {
    const lowRes = levels[i + 1]!;
    const highRes = levels[i]!;
    const scratch = centralBloomPyramid.upsampleScratch[i]!;
    scratch[0] = 1 / lowRes.width;
    scratch[1] = 1 / lowRes.height;
    scratch[2] = weights[i + 1]!;
    scratch[3] = 0;
    device.queue.writeBuffer(
      centralBloomPyramid.upsample[i]!,
      0,
      scratch.buffer,
      scratch.byteOffset,
      scratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: `centralBloom.upsample.${i}.bg`,
      layout: layout,
      entries: [
        { binding: 0, resource: { buffer: centralBloomPyramid.upsample[i]! } },
        { binding: 1, resource: lowRes.createView() },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: `centralBloom.upsample.${i}`,
      colorAttachments: [
        {
          view: highRes.createView(),
          loadOp: "load",
          storeOp: "store",
        },
      ],
    });
    pass.setPipeline(upsampleAddPipeline);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return levels[0]!;
}

export interface CrossFilterHistoryState {
  peakHistoryWriteIndex: number;
  peakHistoryFilledFrames: number;
  lastHistoryTime: number | null;
}

export interface CrossFilterRenderDeps {
  device: GPUDevice;
  pool: OffscreenTargetPool;
  width: number;
  height: number;
  fitMode: number;
  imgResX: number;
  imgResY: number;
  time: number;
  maxStreaks: number;
  minSpacingMin: number;
  minSpacingMax: number;
  /** `DEFAULT_DEPTH_RAY_ANGLE_GAMMA` — owned by `WebGPUBackend.ts` (also used by
   * `renderFrame`'s depth-prefilter defaults); passed through to avoid a
   * duplicate literal or a value-level import cycle back into that file. */
  defaultDepthRayAngleGamma: number;
  crossFilter: CrossFilterResources;
  layouts: Pick<
    PrefilterGroupLayouts,
    | "pyramid"
    | "crossFilterPeakSpacing"
    | "crossFilterStreak"
    | "crossFilterTemporal"
    | "crossFilterBlend"
  >;
  pipelines: Pick<
    Pipelines,
    | "crossFilterSource"
    | "crossFilterPeak"
    | "crossFilterPeakSpacingMax"
    | "crossFilterPeakSpacing"
    | "crossFilterStreak"
    | "crossFilterTemporal"
    | "crossFilterBlend"
    | "downsample"
    | "upsampleAdd"
  >;
  depthTexture: GPUTexture;
  sampler: GPUSampler;
  offscreenFlagsBindGroup: GPUBindGroup;
  crossFilterFlagsBindGroup: GPUBindGroup;
  centralBloomPyramid: PyramidResources;
  /** `CENTRAL_BLOOM_LEVELS` (also read by `WebGPUBackend`'s constructor). */
  centralBloomLevels: number;
  paramNumber: (key: string, fallback: number) => number;
  resolveCurrentRayAngleOptics: () => ResolvedRayAngleOptics;
  packRayAngleOptics: (
    target: Float32Array,
    offset: number,
    optics: ResolvedRayAngleOptics,
    innerThreshold: number,
  ) => void;
  history: CrossFilterHistoryState;
}

export interface CrossFilterRenderResult {
  texture: GPUTexture;
  history: CrossFilterHistoryState;
}

export function renderCrossFilter(
  encoder: GPUCommandEncoder,
  sourceTexture: GPUTexture,
  deps: CrossFilterRenderDeps,
): CrossFilterRenderResult {
  const {
    device,
    pool,
    width,
    height,
    fitMode,
    imgResX,
    imgResY,
    time,
    maxStreaks,
    minSpacingMin,
    minSpacingMax,
    defaultDepthRayAngleGamma,
    crossFilter,
    layouts,
    pipelines,
    depthTexture,
    sampler,
    offscreenFlagsBindGroup,
    crossFilterFlagsBindGroup,
    centralBloomPyramid,
    centralBloomLevels,
    paramNumber,
    resolveCurrentRayAngleOptics,
    packRayAngleOptics,
    history,
  } = deps;
  // Pass-through history snapshot — only mutated inside the dormant
  // temporal-hold branch below (`WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED`
  // is always `false` in the current build).
  let peakHistoryWriteIndex = history.peakHistoryWriteIndex;
  let peakHistoryFilledFrames = history.peakHistoryFilledFrames;
  let lastHistoryTime = history.lastHistoryTime;

  const strength = Math.min(1, Math.max(0, paramNumber("crossFilterStrength", 0)));
  if (strength <= 0) {
    return {
      texture: sourceTexture,
      history: { peakHistoryWriteIndex, peakHistoryFilledFrames, lastHistoryTime },
    };
  }

  const halfWidth = Math.max(1, Math.floor(width / 2));
  const halfHeight = Math.max(1, Math.floor(height / 2));
  const sourceGateTexture = pool.get("rt.crossfilter.source-gate", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const peakTexture = pool.get("rt.crossfilter.peak", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const spacingWorkTexture = pool.get("rt.crossfilter.spacing-work", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const spacingMaxTexture = pool.get("rt.crossfilter.spacing-max", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const spacingTexture = pool.get("rt.crossfilter.spacing", {
    width: halfWidth,
    height: halfHeight,
    format: "rgba16float",
  });
  const streakTextures = Array.from({ length: maxStreaks }, (_, index) =>
    pool.get(`rt.crossfilter.streak.${index}`, {
      width: halfWidth,
      height: halfHeight,
      format: "rgba16float",
    }),
  );
  const outputTexture = pool.get("rt.crossfilter.output", {
    width: width,
    height: height,
    format: "rgba16float",
  });

  const hardModeActive = paramNumber("crossFilterHardMode", 0) >= 0.5;
  const hardModeUniform = hardModeActive ? 1 : 0;
  const threshold = Math.min(1, Math.max(0, paramNumber("crossFilterThreshold", 0.8)));
  const sizeLimit = Math.min(1, Math.max(0, paramNumber("crossFilterSizeLimit", 0)));
  const randomness = Math.min(1, Math.max(0, paramNumber("crossFilterRandomness", 1)));
  const length = Math.min(1, Math.max(0, paramNumber("crossFilterLength", 0.5)));
  const chromatic = Math.min(1, Math.max(0, paramNumber("crossFilterChromatic", 0.3)));
  const crossFilterDepthGain = Math.min(
    1,
    Math.max(0, paramNumber("crossFilterDepthGain", DEFAULT_CROSS_FILTER_DEPTH_GAIN)),
  );
  const crossFilterAngleGain = Math.min(
    1,
    Math.max(0, paramNumber("crossFilterAngleGain", DEFAULT_CROSS_FILTER_ANGLE_GAIN)),
  );
  const crossFilterAngleGamma = Math.max(
    0.001,
    paramNumber("crossFilterAngleGamma", defaultDepthRayAngleGamma),
  );
  const crossFilterAngleInnerThreshold = Math.min(
    0.8,
    Math.max(
      0,
      paramNumber(
        "crossFilterAngleInnerThreshold",
        DEFAULT_RAY_ANGLE_INNER_THRESHOLD,
      ),
    ),
  );
  const crossFilterEdgeLengthGain = Math.min(
    1,
    Math.max(
      0,
      paramNumber("crossFilterEdgeLengthGain", DEFAULT_CROSS_FILTER_EDGE_LENGTH_GAIN),
    ),
  );
  const crossFilterEdgeStrengthGain = Math.min(
    1,
    Math.max(
      0,
      paramNumber(
        "crossFilterEdgeStrengthGain",
        DEFAULT_CROSS_FILTER_EDGE_STRENGTH_GAIN,
      ),
    ),
  );
  const minSpacing = Math.min(
    minSpacingMax,
    Math.max(minSpacingMin, paramNumber("crossFilterMinSpacing", 1)),
  );
  const rawSpikes = Math.max(2, Math.round(paramNumber("crossFilterSpikes", 4)));
  const spikeCount = rawSpikes % 2 === 0 ? rawSpikes : rawSpikes + 1;
  const dirCount = Math.max(
    1,
    Math.min(maxStreaks, Math.floor(spikeCount / 2)),
  );
  const angleRad = (paramNumber("crossFilterAngle", 0) * Math.PI) / 180;
  const effectiveThreshold = computeCrossFilterEffectiveThreshold(
    threshold,
    hardModeActive,
  );
  const effectiveSizeLimit = hardModeActive ? 1.0 : sizeLimit;
  const effectiveRandomness = hardModeActive ? 1.0 : randomness;
  const rayAngleOptics = resolveCurrentRayAngleOptics();

  const sourceView = sourceTexture.createView();
  const depthView = depthTexture.createView();
  const blackView = crossFilter.blackTexture.createView();

  crossFilter.thresholdScratch[0] = effectiveThreshold;
  crossFilter.thresholdScratch[1] = 0.12;
  crossFilter.thresholdScratch[2] = hardModeUniform;
  crossFilter.thresholdScratch[3] = 0;
  device.queue.writeBuffer(
    crossFilter.thresholdBuffer,
    0,
    crossFilter.thresholdScratch.buffer,
    crossFilter.thresholdScratch.byteOffset,
    crossFilter.thresholdScratch.byteLength,
  );
  {
    const bg = device.createBindGroup({
      label: "crossfilter.source.bg",
      layout: layouts.pyramid,
      entries: [
        { binding: 0, resource: { buffer: crossFilter.thresholdBuffer } },
        { binding: 1, resource: sourceView },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "crossfilter.source",
      colorAttachments: [
        {
          view: sourceGateTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(pipelines.crossFilterSource);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  crossFilter.peakScratch[0] = 1 / halfWidth;
  crossFilter.peakScratch[1] = 1 / halfHeight;
  crossFilter.peakScratch[2] = effectiveSizeLimit;
  crossFilter.peakScratch[3] = 0;
  device.queue.writeBuffer(
    crossFilter.peakBuffer,
    0,
    crossFilter.peakScratch.buffer,
    crossFilter.peakScratch.byteOffset,
    crossFilter.peakScratch.byteLength,
  );
  {
    const bg = device.createBindGroup({
      label: "crossfilter.peak.bg",
      layout: layouts.pyramid,
      entries: [
        { binding: 0, resource: { buffer: crossFilter.peakBuffer } },
        { binding: 1, resource: sourceGateTexture.createView() },
        { binding: 2, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "crossfilter.peak",
      colorAttachments: [
        {
          view: peakTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(pipelines.crossFilterPeak);
    pass.setBindGroup(0, offscreenFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  let currentPeakTexture = peakTexture;
  if (minSpacing >= 0.001) {
    const radiusPx = computeCrossFilterSpacingRadiusPx(minSpacing, minSpacingMin, minSpacingMax);

    const spacingMaxScratchX = crossFilter.spacingMaxScratch[0]!;
    spacingMaxScratchX[0] = 1 / halfWidth;
    spacingMaxScratchX[1] = 1 / halfHeight;
    spacingMaxScratchX[2] = 1;
    spacingMaxScratchX[3] = 0;
    spacingMaxScratchX[4] = radiusPx;
    spacingMaxScratchX[5] = 0;
    spacingMaxScratchX[6] = 0;
    spacingMaxScratchX[7] = 0;
    device.queue.writeBuffer(
      crossFilter.spacingMaxBuffers[0]!,
      0,
      spacingMaxScratchX.buffer,
      spacingMaxScratchX.byteOffset,
      spacingMaxScratchX.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "crossfilter.spacing-max-x.bg",
        layout: layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: crossFilter.spacingMaxBuffers[0]! } },
          { binding: 1, resource: peakTexture.createView() },
          { binding: 2, resource: sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.spacing-max-x",
        colorAttachments: [
          {
            view: spacingWorkTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(pipelines.crossFilterPeakSpacingMax);
      pass.setBindGroup(0, crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    const spacingMaxScratchY = crossFilter.spacingMaxScratch[1]!;
    spacingMaxScratchY[0] = 1 / halfWidth;
    spacingMaxScratchY[1] = 1 / halfHeight;
    spacingMaxScratchY[2] = 0;
    spacingMaxScratchY[3] = 1;
    spacingMaxScratchY[4] = radiusPx;
    spacingMaxScratchY[5] = 1;
    spacingMaxScratchY[6] = 0;
    spacingMaxScratchY[7] = 0;
    device.queue.writeBuffer(
      crossFilter.spacingMaxBuffers[1]!,
      0,
      spacingMaxScratchY.buffer,
      spacingMaxScratchY.byteOffset,
      spacingMaxScratchY.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "crossfilter.spacing-max-y.bg",
        layout: layouts.pyramid,
        entries: [
          { binding: 0, resource: { buffer: crossFilter.spacingMaxBuffers[1]! } },
          { binding: 1, resource: spacingWorkTexture.createView() },
          { binding: 2, resource: sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.spacing-max-y",
        colorAttachments: [
          {
            view: spacingMaxTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(pipelines.crossFilterPeakSpacingMax);
      pass.setBindGroup(0, crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    crossFilter.spacingScratch[0] = 1 / halfWidth;
    crossFilter.spacingScratch[1] = 1 / halfHeight;
    crossFilter.spacingScratch[2] = minSpacing;
    crossFilter.spacingScratch[3] = 0;
    device.queue.writeBuffer(
      crossFilter.spacingBuffer,
      0,
      crossFilter.spacingScratch.buffer,
      crossFilter.spacingScratch.byteOffset,
      crossFilter.spacingScratch.byteLength,
    );
    {
      const bg = device.createBindGroup({
        label: "crossfilter.spacing.bg",
        layout: layouts.crossFilterPeakSpacing,
        entries: [
          { binding: 0, resource: { buffer: crossFilter.spacingBuffer } },
          { binding: 1, resource: peakTexture.createView() },
          { binding: 2, resource: spacingMaxTexture.createView() },
          { binding: 3, resource: sampler },
        ],
      });
      const pass = encoder.beginRenderPass({
        label: "crossfilter.spacing",
        colorAttachments: [
          {
            view: spacingTexture.createView(),
            loadOp: "clear",
            storeOp: "store",
            clearValue: { r: 0, g: 0, b: 0, a: 1 },
          },
        ],
      });
      pass.setPipeline(pipelines.crossFilterPeakSpacing);
      pass.setBindGroup(0, crossFilterFlagsBindGroup);
      pass.setBindGroup(1, bg);
      pass.draw(3, 1, 0, 0);
      pass.end();
    }

    currentPeakTexture = spacingTexture;
  }

  // Active WebGPU Hard Mode intentionally bypasses the legacy temporal
  // hold so current peaks feed both central bloom and the streak march
  // directly. Keep the dormant temporal path behind a feature flag so
  // the preserved history resources/state and elapsed-time normalization
  // work remain intact without affecting the live product behavior.
  let heldPeakTexture = currentPeakTexture;
  if (hardModeActive && WEBGPU_CROSS_FILTER_TEMPORAL_HOLD_ENABLED) {
    const historyTextures = [
      pool.get("rt.crossfilter.peak-history.0", {
        width: halfWidth,
        height: halfHeight,
        format: "rgba16float",
      }),
      pool.get("rt.crossfilter.peak-history.1", {
        width: halfWidth,
        height: halfHeight,
        format: "rgba16float",
      }),
    ];
    const writeIndex =
      peakHistoryWriteIndex % CROSS_FILTER_HISTORY_SLOTS;
    const prevIndex =
      (writeIndex + CROSS_FILTER_HISTORY_SLOTS - 1) % CROSS_FILTER_HISTORY_SLOTS;
    const prevTexture =
      peakHistoryFilledFrames > 0
        ? historyTextures[prevIndex]!
        : crossFilter.blackTexture;
    const writeTexture = historyTextures[writeIndex]!;
    const temporalDeltaSeconds =
      lastHistoryTime === null
        ? 1 / CROSS_FILTER_TEMPORAL_REFERENCE_FPS
        : time - lastHistoryTime;
    const temporalDecay = computeCrossFilterTemporalDecay(temporalDeltaSeconds);

    crossFilter.temporalScratch[0] = temporalDecay;
    crossFilter.temporalScratch[1] = 0;
    crossFilter.temporalScratch[2] = 0;
    crossFilter.temporalScratch[3] = 0;
    device.queue.writeBuffer(
      crossFilter.temporalBuffer,
      0,
      crossFilter.temporalScratch.buffer,
      crossFilter.temporalScratch.byteOffset,
      crossFilter.temporalScratch.byteLength,
    );
    const temporalBg = device.createBindGroup({
      label: "crossfilter.temporal.bg",
      layout: layouts.crossFilterTemporal,
      entries: [
        { binding: 0, resource: { buffer: crossFilter.temporalBuffer } },
        { binding: 1, resource: currentPeakTexture.createView() },
        { binding: 2, resource: prevTexture.createView() },
        { binding: 3, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: "crossfilter.temporal",
      colorAttachments: [
        {
          view: writeTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(pipelines.crossFilterTemporal);
    // Stay on the cross-filter (no-flip) contract so heldPeakTexture
    // shares the upright row order with the rest of the post-peak
    // subchain (spacing → streak → blend). Using the offscreen contract
    // here would inject an asymmetric Y flip and mirror the held peak
    // mask relative to the source frame.
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, temporalBg);
    pass.draw(3, 1, 0, 0);
    pass.end();

    heldPeakTexture = writeTexture;
    peakHistoryWriteIndex =
      (writeIndex + 1) % CROSS_FILTER_HISTORY_SLOTS;
    peakHistoryFilledFrames = Math.min(
      peakHistoryFilledFrames + 1,
      CROSS_FILTER_HISTORY_SLOTS,
    );
    lastHistoryTime = time;
  }

  // Hard-mode central bloom (skipped entirely in Soft Mode; the blend
  // shader multiplies the bloom term by `uHardMode` so a black texture
  // would zero it out, but building the pyramid anyway wastes GPU time).
  let centralBloomTexture: GPUTexture | null = null;
  if (hardModeActive) {
    centralBloomTexture = renderCentralBloom(encoder, heldPeakTexture, {
      device,
      pool,
      width,
      height,
      levels: centralBloomLevels,
      centralBloomPyramid,
      layout: layouts.pyramid,
      sampler,
      downsamplePipeline: pipelines.downsample,
      upsampleAddPipeline: pipelines.upsampleAdd,
      crossFilterFlagsBindGroup,
    });
  }

  const hash = (seed: number): number => {
    const value = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
    return value - Math.floor(value);
  };

  for (let i = 0; i < dirCount; i++) {
    const seed = i * 17 + 7;
    const angleJitter = (hash(seed) - 0.5) * 2 * (5 * Math.PI / 180);
    const lengthMul = 1.0 + (hash(seed + 1) - 0.5) * 0.5;
    const brightMul = 1.0 + (hash(seed + 2) - 0.5) * 0.4;
    const dirAngle = angleRad + (i * Math.PI) / dirCount + angleJitter;
    const streakScratch = crossFilter.streakScratch[i]!;
    streakScratch[0] = Math.cos(dirAngle);
    streakScratch[1] = Math.sin(dirAngle);
    streakScratch[2] = 1 / heldPeakTexture.width;
    streakScratch[3] = 1 / heldPeakTexture.height;
    streakScratch[4] = length * lengthMul;
    streakScratch[5] = chromatic;
    streakScratch[6] = brightMul;
    streakScratch[7] = effectiveRandomness;
    streakScratch[8] = hardModeUniform;
    streakScratch[9] = crossFilterDepthGain;
    streakScratch[10] = crossFilterAngleGain;
    streakScratch[11] = crossFilterAngleGamma;
    streakScratch[12] = crossFilterEdgeLengthGain;
    streakScratch[13] = crossFilterEdgeStrengthGain;
    streakScratch[14] = fitMode;
    streakScratch[15] = 0;
    streakScratch[16] = width;
    streakScratch[17] = height;
    streakScratch[18] = imgResX;
    streakScratch[19] = imgResY;
    packRayAngleOptics(
      streakScratch,
      20,
      rayAngleOptics,
      crossFilterAngleInnerThreshold,
    );
    device.queue.writeBuffer(
      crossFilter.streakBuffers[i]!,
      0,
      streakScratch.buffer,
      streakScratch.byteOffset,
      streakScratch.byteLength,
    );
    const bg = device.createBindGroup({
      label: `crossfilter.streak.${i}.bg`,
      layout: layouts.crossFilterStreak,
      entries: [
        { binding: 0, resource: { buffer: crossFilter.streakBuffers[i]! } },
        { binding: 1, resource: heldPeakTexture.createView() },
        { binding: 2, resource: depthView },
        { binding: 3, resource: sampler },
      ],
    });
    const pass = encoder.beginRenderPass({
      label: `crossfilter.streak.${i}`,
      colorAttachments: [
        {
          view: streakTextures[i]!.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(pipelines.crossFilterStreak);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  crossFilter.blendScratch[0] = dirCount;
  crossFilter.blendScratch[1] = strength;
  crossFilter.blendScratch[2] = hardModeUniform;
  crossFilter.blendScratch[3] = 0;
  device.queue.writeBuffer(
    crossFilter.blendBuffer,
    0,
    crossFilter.blendScratch.buffer,
    crossFilter.blendScratch.byteOffset,
    crossFilter.blendScratch.byteLength,
  );
  {
    const centralBloomView = centralBloomTexture
      ? centralBloomTexture.createView()
      : blackView;
    const blendEntries: GPUBindGroupEntry[] = [
      { binding: 0, resource: { buffer: crossFilter.blendBuffer } },
      { binding: 1, resource: sourceView },
      { binding: 2, resource: dirCount >= 1 ? streakTextures[0]!.createView() : blackView },
      { binding: 3, resource: dirCount >= 2 ? streakTextures[1]!.createView() : blackView },
      { binding: 4, resource: dirCount >= 3 ? streakTextures[2]!.createView() : blackView },
      { binding: 5, resource: dirCount >= 4 ? streakTextures[3]!.createView() : blackView },
      { binding: 6, resource: centralBloomView },
      { binding: 7, resource: sampler },
    ];
    const bg = device.createBindGroup({
      label: "crossfilter.blend.bg",
      layout: layouts.crossFilterBlend,
      entries: blendEntries,
    });
    const pass = encoder.beginRenderPass({
      label: "crossfilter.blend",
      colorAttachments: [
        {
          view: outputTexture.createView(),
          loadOp: "clear",
          storeOp: "store",
          clearValue: { r: 0, g: 0, b: 0, a: 1 },
        },
      ],
    });
    pass.setPipeline(pipelines.crossFilterBlend);
    pass.setBindGroup(0, crossFilterFlagsBindGroup);
    pass.setBindGroup(1, bg);
    pass.draw(3, 1, 0, 0);
    pass.end();
  }

  return {
    texture: outputTexture,
    history: { peakHistoryWriteIndex, peakHistoryFilledFrames, lastHistoryTime },
  };
}
