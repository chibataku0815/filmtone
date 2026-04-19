import { describe, expect, it } from "vitest";
// Direct src import — the `film-lab-renderer/webgpu` entry eagerly reads
// `GPUTextureUsage` at module init, which is not available in node-env
// unit tests. The crossFilterState module is pure TS and can be loaded
// without touching the WebGPU global.
import {
  CROSS_FILTER_MIN_SPACING_EPSILON,
  CROSS_FILTER_TEMPORAL_REFERENCE_DECAY,
  CROSS_FILTER_TEMPORAL_REFERENCE_FPS,
  computeCrossFilterTemporalDecay,
  effectiveDiffusionAmount,
  isCrossFilterHardModeActive,
  shouldResetCrossFilterHistory,
} from "../../../../packages/film-lab-renderer/src/webgpu/crossFilterState";

describe("isCrossFilterHardModeActive", () => {
  it("returns true only when strength is nonzero and hardMode ≥ 0.5", () => {
    expect(isCrossFilterHardModeActive(0.5, 1)).toBe(true);
    expect(isCrossFilterHardModeActive(0.01, 0.5)).toBe(true);
  });

  it("returns false when strength is zero regardless of hardMode", () => {
    expect(isCrossFilterHardModeActive(0, 1)).toBe(false);
    expect(isCrossFilterHardModeActive(0, 0.5)).toBe(false);
  });

  it("returns false when hardMode is below 0.5 (Soft Mode, or frozen)", () => {
    expect(isCrossFilterHardModeActive(0.5, 0)).toBe(false);
    expect(isCrossFilterHardModeActive(0.5, 0.49)).toBe(false);
  });
});

describe("effectiveDiffusionAmount", () => {
  it("forces 0 when Hard Mode is active, even at full user diffusion", () => {
    expect(effectiveDiffusionAmount(1, true)).toBe(0);
    expect(effectiveDiffusionAmount(0.4, true)).toBe(0);
  });

  it("clamps user diffusion to [0, 1] when Hard Mode is inactive", () => {
    expect(effectiveDiffusionAmount(0.3, false)).toBe(0.3);
    expect(effectiveDiffusionAmount(-0.5, false)).toBe(0);
    expect(effectiveDiffusionAmount(1.5, false)).toBe(1);
  });

  it("coerces non-finite input to 0 instead of NaN-leaking the uniform", () => {
    expect(effectiveDiffusionAmount(Number.NaN, false)).toBe(0);
    expect(effectiveDiffusionAmount(Number.POSITIVE_INFINITY, false)).toBe(0);
  });
});

describe("shouldResetCrossFilterHistory", () => {
  const neutral = { strength: 0.5, hardMode: 1 as const, minSpacing: 0.2 };

  it("does NOT reset when nothing meaningful changed", () => {
    expect(shouldResetCrossFilterHistory(neutral, { ...neutral })).toBe(false);
  });

  it("resets when Hard Mode flips Soft → Hard", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, hardMode: 0 },
        { ...neutral, hardMode: 1 },
      ),
    ).toBe(true);
  });

  it("resets when Hard Mode flips Hard → Soft", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, hardMode: 1 },
        { ...neutral, hardMode: 0 },
      ),
    ).toBe(true);
  });

  it("resets when strength transitions from nonzero to zero", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, strength: 0.5 },
        { ...neutral, strength: 0 },
      ),
    ).toBe(true);
  });

  it("does NOT reset when strength transitions from zero to nonzero (turning on)", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, strength: 0 },
        { ...neutral, strength: 0.5 },
      ),
    ).toBe(false);
  });

  it("resets when minSpacing crosses the epsilon", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, minSpacing: 0.2 },
        { ...neutral, minSpacing: 0.2 + CROSS_FILTER_MIN_SPACING_EPSILON * 2 },
      ),
    ).toBe(true);
  });

  it("does NOT reset when minSpacing changes are within the epsilon", () => {
    expect(
      shouldResetCrossFilterHistory(
        { ...neutral, minSpacing: 0.2 },
        { ...neutral, minSpacing: 0.2 + CROSS_FILTER_MIN_SPACING_EPSILON / 2 },
      ),
    ).toBe(false);
  });
});

describe("computeCrossFilterTemporalDecay", () => {
  it("matches the legacy decay at the 24 fps reference step", () => {
    expect(
      computeCrossFilterTemporalDecay(1 / CROSS_FILTER_TEMPORAL_REFERENCE_FPS),
    ).toBeCloseTo(CROSS_FILTER_TEMPORAL_REFERENCE_DECAY);
  });

  it("decays less over half a reference frame", () => {
    expect(
      computeCrossFilterTemporalDecay(1 / (CROSS_FILTER_TEMPORAL_REFERENCE_FPS * 2)),
    ).toBeCloseTo(Math.sqrt(CROSS_FILTER_TEMPORAL_REFERENCE_DECAY));
  });

  it("decays more over two reference frames", () => {
    expect(
      computeCrossFilterTemporalDecay(2 / CROSS_FILTER_TEMPORAL_REFERENCE_FPS),
    ).toBeCloseTo(CROSS_FILTER_TEMPORAL_REFERENCE_DECAY ** 2);
  });

  it("returns identity decay for repeated renders at the same timestamp", () => {
    expect(computeCrossFilterTemporalDecay(0)).toBe(1);
  });

  it("falls back to the reference decay for non-finite input", () => {
    expect(computeCrossFilterTemporalDecay(Number.NaN)).toBe(
      CROSS_FILTER_TEMPORAL_REFERENCE_DECAY,
    );
    expect(computeCrossFilterTemporalDecay(Number.POSITIVE_INFINITY)).toBe(
      CROSS_FILTER_TEMPORAL_REFERENCE_DECAY,
    );
  });
});
