export interface CompareViewportSyncInput {
  backendKind: "webgl" | "webgpu" | null;
  supportsABCompare: boolean;
  supportsBeforeAfter: boolean;
  compareMode: boolean;
  beforeAfterStashPresent: boolean;
  prevCompareMode: boolean;
  prevBeforeAfterActive: boolean;
}

export interface CompareViewportSyncPlan {
  compareOn: boolean;
  beforeAfterActive: boolean;
  comparePresentOn: boolean;
  nextSplitPosition: number | null;
}

export function resolveCompareViewportSyncPlan(
  input: CompareViewportSyncInput,
): CompareViewportSyncPlan {
  const compareOn = input.supportsABCompare && input.compareMode;
  const beforeAfterActive =
    input.supportsBeforeAfter && input.beforeAfterStashPresent;
  const comparePresentOn =
    compareOn || (input.backendKind === "webgpu" && beforeAfterActive);

  let nextSplitPosition: number | null = null;

  if (compareOn && !input.prevCompareMode) {
    nextSplitPosition = 0.5;
  } else if (beforeAfterActive && !input.prevBeforeAfterActive) {
    nextSplitPosition = 0.5;
  } else if (input.prevCompareMode && !compareOn && !beforeAfterActive) {
    nextSplitPosition = -1.0;
  } else if (!beforeAfterActive && input.prevBeforeAfterActive && !compareOn) {
    nextSplitPosition = -1.0;
  }

  return {
    compareOn,
    beforeAfterActive,
    comparePresentOn,
    nextSplitPosition,
  };
}
