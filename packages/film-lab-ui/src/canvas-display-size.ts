export type CanvasDisplaySizeInput = {
  containerWidth: number;
  containerHeight: number;
  contentWidth: number;
  contentHeight: number;
};

export type CanvasDisplaySize = {
  width: number;
  height: number;
};

function positiveFiniteOrFallback(value: number, fallback: number): number {
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

export function computeContainedCanvasDisplaySize(
  input: CanvasDisplaySizeInput,
): CanvasDisplaySize {
  const containerWidth = Math.max(
    1,
    positiveFiniteOrFallback(input.containerWidth, 1),
  );
  const containerHeight = Math.max(
    1,
    positiveFiniteOrFallback(input.containerHeight, 1),
  );
  const contentWidth = Math.max(
    1,
    positiveFiniteOrFallback(input.contentWidth, containerWidth),
  );
  const contentHeight = Math.max(
    1,
    positiveFiniteOrFallback(input.contentHeight, containerHeight),
  );

  const containerAspect = containerWidth / containerHeight;
  const contentAspect = contentWidth / contentHeight;

  if (containerAspect > contentAspect) {
    return {
      width: Math.min(containerWidth, containerHeight * contentAspect),
      height: containerHeight,
    };
  }

  return {
    width: containerWidth,
    height: Math.min(containerHeight, containerWidth / contentAspect),
  };
}
