import { useEffect, useRef, useState } from "react";

export interface TopChromeProps {
  appName: string;
  sourceLabel?: string;
  onMenuOpen: () => void;
  menuLabel: string;
  /** Whether the chrome should auto-hide. Default true. Pass false to keep visible (e.g., empty state). */
  autoHide?: boolean;
}

const HIDE_AFTER_MS = 2000;

export function TopChrome({
  appName,
  sourceLabel,
  onMenuOpen,
  menuLabel,
  autoHide = true,
}: TopChromeProps) {
  const [visible, setVisible] = useState(true);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (!autoHide) {
      setVisible(true);
      if (timerRef.current !== null) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      return;
    }

    const clearTimer = () => {
      if (timerRef.current !== null) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };

    const scheduleHide = () => {
      clearTimer();
      timerRef.current = setTimeout(() => {
        setVisible(false);
      }, HIDE_AFTER_MS);
    };

    const handlePointer = () => {
      setVisible(true);
      scheduleHide();
    };

    document.addEventListener("pointerdown", handlePointer, { passive: true });
    document.addEventListener("pointermove", handlePointer, { passive: true });
    scheduleHide();

    return () => {
      document.removeEventListener("pointerdown", handlePointer);
      document.removeEventListener("pointermove", handlePointer);
      clearTimer();
    };
  }, [autoHide]);

  const transformClass = visible
    ? "translate-y-0 opacity-100"
    : "-translate-y-full opacity-0 pointer-events-none";

  return (
    <header
      className={`fixed top-0 left-0 right-0 z-30 px-4 pt-[calc(env(safe-area-inset-top,0px)+10px)] pb-3 glass-panel border-b border-white/12 flex items-center gap-3 transition-all duration-200 ease-out ${transformClass}`}
    >
      <span className="text-base font-medium tracking-[-0.01em] text-white shrink-0">
        {appName}
      </span>
      <span className="flex-1 text-center text-[11px] text-[var(--text-muted)] truncate max-w-[40%] mx-auto">
        {sourceLabel ?? ""}
      </span>
      <button
        type="button"
        onClick={onMenuOpen}
        aria-label={menuLabel}
        className="w-9 h-9 flex items-center justify-center rounded-full hover:bg-white/[0.06] text-white/80 shrink-0"
      >
        <svg
          width="18"
          height="18"
          viewBox="0 0 18 18"
          fill="none"
          xmlns="http://www.w3.org/2000/svg"
          aria-hidden="true"
        >
          <circle cx="3.5" cy="9" r="1.4" fill="currentColor" />
          <circle cx="9" cy="9" r="1.4" fill="currentColor" />
          <circle cx="14.5" cy="9" r="1.4" fill="currentColor" />
        </svg>
      </button>
    </header>
  );
}

export default TopChrome;
