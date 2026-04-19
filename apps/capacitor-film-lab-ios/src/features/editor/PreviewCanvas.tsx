import {
  useCallback,
  useRef,
  type PointerEvent as ReactPointerEvent,
  type ReactElement,
} from "react";
import { AppMarkIcon, CompareIcon } from "@/components/FilmtoneIcons";

export interface PreviewCanvasProps {
  source: { filename: string } | null;
  displayUri: string | undefined;
  emptyMessage: string;
  compareLabel: string;
  isRendering?: boolean;
  metaLabel?: string;
  mediaAspectRatio?: number;
  isComparing?: boolean;
  onPressHoldStart?: () => void;
  onPressHoldEnd?: () => void;
  onExpand?: () => void;
}

const TAP_MAX_MS = 180;
const TAP_MAX_PX = 8;

function resolveFrameWidthClass(aspectRatio?: number): string {
  if (typeof aspectRatio !== "number" || !Number.isFinite(aspectRatio)) {
    return "max-w-full";
  }
  if (aspectRatio < 0.85) return "max-w-[20rem]";
  if (aspectRatio < 1.15) return "max-w-[28rem]";
  return "max-w-full";
}

/**
 * Full-bleed still-frame preview. Press-and-hold activates compare after 180ms;
 * a quick tap (<180ms, <8px) fires onExpand to open fullscreen.
 */
export function PreviewCanvas(props: PreviewCanvasProps): ReactElement {
  const {
    source,
    displayUri,
    emptyMessage,
    compareLabel,
    isRendering = false,
    metaLabel,
    mediaAspectRatio,
    isComparing = false,
    onPressHoldStart,
    onPressHoldEnd,
    onExpand,
  } = props;

  const pointerStateRef = useRef<{
    id: number;
    startX: number;
    startY: number;
    startedAt: number;
    holdTimer: number | null;
    holding: boolean;
  } | null>(null);

  const frameAspectRatio =
    typeof mediaAspectRatio === "number" && Number.isFinite(mediaAspectRatio)
      ? mediaAspectRatio
      : undefined;
  const frameWidthClass = resolveFrameWidthClass(frameAspectRatio);

  const clearHoldTimer = useCallback(() => {
    const state = pointerStateRef.current;
    if (state && state.holdTimer != null) {
      window.clearTimeout(state.holdTimer);
      state.holdTimer = null;
    }
  }, []);

  const handlePointerDown = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      if (!source) return;
      if (pointerStateRef.current !== null) return;
      if (event.pointerType === "mouse" && event.button !== 0) return;
      try {
        event.currentTarget.setPointerCapture(event.pointerId);
      } catch {
        // ignore
      }
      const state = {
        id: event.pointerId,
        startX: event.clientX,
        startY: event.clientY,
        startedAt: performance.now(),
        holdTimer: null as number | null,
        holding: false,
      };
      pointerStateRef.current = state;
      state.holdTimer = window.setTimeout(() => {
        if (pointerStateRef.current !== state) return;
        state.holding = true;
        onPressHoldStart?.();
      }, TAP_MAX_MS);
    },
    [source, onPressHoldStart],
  );

  const handlePointerMove = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      const state = pointerStateRef.current;
      if (!state || state.id !== event.pointerId) return;
      const dx = event.clientX - state.startX;
      const dy = event.clientY - state.startY;
      if (Math.hypot(dx, dy) > TAP_MAX_PX && !state.holding) {
        clearHoldTimer();
        state.holding = true;
        onPressHoldStart?.();
      }
    },
    [clearHoldTimer, onPressHoldStart],
  );

  const handlePointerEnd = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      const state = pointerStateRef.current;
      if (!state || state.id !== event.pointerId) return;
      try {
        event.currentTarget.releasePointerCapture(event.pointerId);
      } catch {
        // ignore
      }
      clearHoldTimer();
      const elapsed = performance.now() - state.startedAt;
      const dx = event.clientX - state.startX;
      const dy = event.clientY - state.startY;
      const wasTap =
        !state.holding && elapsed < TAP_MAX_MS && Math.hypot(dx, dy) < TAP_MAX_PX;
      pointerStateRef.current = null;
      if (state.holding) {
        onPressHoldEnd?.();
      } else if (wasTap) {
        onExpand?.();
      }
    },
    [clearHoldTimer, onPressHoldEnd, onExpand],
  );

  return (
    <div className="relative squircle-xl overflow-hidden bg-black">
      <div className="relative flex min-h-[18rem] items-center justify-center sm:min-h-[20rem]">
        {source && displayUri ? (
          <>
            <div
              className={[
                "relative w-full overflow-hidden squircle-xl bg-black",
                frameWidthClass,
              ].join(" ")}
              style={{
                aspectRatio: frameAspectRatio ? String(frameAspectRatio) : "4 / 3",
                maxHeight: "68svh",
              }}
            >
              <img
                className="h-full w-full object-contain"
                src={displayUri}
                alt={source.filename}
              />
            </div>
            <div
              className="absolute inset-0"
              style={{ touchAction: "none" }}
              onPointerDown={handlePointerDown}
              onPointerMove={handlePointerMove}
              onPointerUp={handlePointerEnd}
              onPointerCancel={handlePointerEnd}
            />

            {isComparing ? (
              <div className="pointer-events-none absolute inset-x-5 top-5 flex justify-start">
                <div className="inline-flex items-center gap-2 squircle-pill bg-[var(--accent-amber1)]/92 px-3 py-1.5 text-[11px] font-medium text-black">
                  <CompareIcon className="h-3.5 w-3.5" />
                  {compareLabel}
                </div>
              </div>
            ) : null}

            {metaLabel ? (
              <p className="pointer-events-none absolute bottom-3 right-4 font-mono text-[10px] text-white/50">
                {metaLabel}
              </p>
            ) : null}
          </>
        ) : (
          <div className="absolute inset-0 flex flex-col items-center justify-center gap-4 px-8 text-center">
            <span className="flex h-14 w-14 items-center justify-center rounded-full bg-white/[0.04] text-white/72">
              <AppMarkIcon className="h-6 w-6" />
            </span>
            <div className="max-w-xs text-sm leading-6 text-[var(--text-base-70)]">
              {emptyMessage}
            </div>
          </div>
        )}

        {isRendering ? (
          <div className="pointer-events-none absolute bottom-4 left-4 flex items-center gap-2 text-[11px] font-medium text-white/72">
            <span className="h-2 w-2 animate-pulse rounded-full bg-[var(--accent-amber1)]" />
            {emptyMessage}
          </div>
        ) : null}
      </div>
    </div>
  );
}

export default PreviewCanvas;
