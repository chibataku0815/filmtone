import {
  useCallback,
  useRef,
  type PointerEvent as ReactPointerEvent,
  type ReactElement,
} from "react";

export interface PreviewCanvasProps {
  source: { filename: string } | null;
  displayUri: string | undefined;
  emptyMessage: string;
  compareLabel: string;
  isComparing?: boolean;
  onPressHoldStart?: () => void;
  onPressHoldEnd?: () => void;
}

/**
 * Full-bleed still-frame preview canvas with press-and-hold compare gesture.
 */
export function PreviewCanvas(props: PreviewCanvasProps): ReactElement {
  const {
    source,
    displayUri,
    emptyMessage,
    compareLabel,
    isComparing = false,
    onPressHoldStart,
    onPressHoldEnd,
  } =
    props;

  const activePointerIdRef = useRef<number | null>(null);

  const endCompare = useCallback(() => {
    if (activePointerIdRef.current === null) return;
    activePointerIdRef.current = null;
    onPressHoldEnd?.();
  }, [onPressHoldEnd]);

  const handlePointerDown = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      if (!source) return;
      if (activePointerIdRef.current !== null) return;
      // Only respond to primary button / touch / pen.
      if (event.pointerType === "mouse" && event.button !== 0) return;
      activePointerIdRef.current = event.pointerId;
      try {
        event.currentTarget.setPointerCapture(event.pointerId);
      } catch {
        // setPointerCapture can throw in odd environments; ignore.
      }
      onPressHoldStart?.();
    },
    [source, onPressHoldStart],
  );

  const handlePointerEnd = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      if (activePointerIdRef.current !== event.pointerId) return;
      try {
        event.currentTarget.releasePointerCapture(event.pointerId);
      } catch {
        // ignore
      }
      endCompare();
    },
    [endCompare],
  );

  return (
    <div className="rounded-[28px] glass-panel border border-white/12 overflow-hidden">
      <div className="aspect-[9/16] bg-black relative">
        {source && displayUri ? (
          <>
            <img
              className="h-full w-full object-contain"
              src={displayUri}
              alt={source.filename}
            />
            <div
              className="absolute inset-0"
              style={{ touchAction: "none" }}
              onPointerDown={handlePointerDown}
              onPointerUp={handlePointerEnd}
              onPointerCancel={handlePointerEnd}
              onPointerLeave={handlePointerEnd}
            />

            {isComparing ? (
              <div className="absolute top-3 left-3 px-2.5 py-1 rounded-full glass-panel text-[10px] uppercase tracking-[0.12em] text-white pointer-events-none">
                {compareLabel}
              </div>
            ) : null}
          </>
        ) : (
          <div className="absolute inset-0 flex items-center justify-center bg-[#0a0a0a] px-6 text-center text-sm leading-6 text-[var(--text-base-70)]">
            {emptyMessage}
          </div>
        )}
      </div>
    </div>
  );
}

export default PreviewCanvas;
