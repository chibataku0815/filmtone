import { describe, expect, it } from "vitest";
import { resolveCompareViewportSyncPlan } from "../../../../packages/film-lab-ui/src/compareViewportSync";

const BASE_INPUT = {
  supportsABCompare: true,
  supportsBeforeAfter: true,
  compareMode: false,
  beforeAfterStashPresent: false,
  prevCompareMode: false,
  prevBeforeAfterActive: false,
} as const;

describe("resolveCompareViewportSyncPlan", () => {
  it("activates compare present for WebGPU before/after and centers the split", () => {
    const plan = resolveCompareViewportSyncPlan({
      ...BASE_INPUT,
      backendKind: "webgpu",
      beforeAfterStashPresent: true,
    });

    expect(plan).toEqual({
      compareOn: false,
      beforeAfterActive: true,
      comparePresentOn: true,
      nextSplitPosition: 0.5,
    });
  });

  it("keeps WebGL before/after on the legacy split path", () => {
    const plan = resolveCompareViewportSyncPlan({
      ...BASE_INPUT,
      backendKind: "webgl",
      beforeAfterStashPresent: true,
    });

    expect(plan).toEqual({
      compareOn: false,
      beforeAfterActive: true,
      comparePresentOn: false,
      nextSplitPosition: 0.5,
    });
  });

  it("clears the split path when WebGL before/after exits", () => {
    const plan = resolveCompareViewportSyncPlan({
      ...BASE_INPUT,
      backendKind: "webgl",
      prevBeforeAfterActive: true,
    });

    expect(plan).toEqual({
      compareOn: false,
      beforeAfterActive: false,
      comparePresentOn: false,
      nextSplitPosition: -1,
    });
  });

  it("preserves compare-mode activation for WebGPU A/B compare", () => {
    const plan = resolveCompareViewportSyncPlan({
      ...BASE_INPUT,
      backendKind: "webgpu",
      compareMode: true,
    });

    expect(plan).toEqual({
      compareOn: true,
      beforeAfterActive: false,
      comparePresentOn: true,
      nextSplitPosition: 0.5,
    });
  });

  it("clears the split path when WebGPU before/after exits", () => {
    const plan = resolveCompareViewportSyncPlan({
      ...BASE_INPUT,
      backendKind: "webgpu",
      prevBeforeAfterActive: true,
    });

    expect(plan).toEqual({
      compareOn: false,
      beforeAfterActive: false,
      comparePresentOn: false,
      nextSplitPosition: -1,
    });
  });
});
