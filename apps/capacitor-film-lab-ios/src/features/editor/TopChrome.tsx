import { useEffect, useRef, useState } from "react";
import { LibraryIcon } from "@/components/FilmtoneIcons";

export interface TopChromeProps {
  appName: string;
  /** Unused at the UI layer — retained for prop compatibility with the editor. */
  modeLabel?: string;
  sourceLabel?: string;
  onMenuOpen: () => void;
  menuLabel: string;
  /** Whether the chrome should auto-hide. Default true. Pass false to keep visible (e.g., empty state). */
  autoHide?: boolean;
}

const HIDE_AFTER_MS = 2000;

export function TopChrome({
  appName,
  modeLabel: _modeLabel,
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
    : "-translate-y-6 opacity-0 pointer-events-none";

  return (
    <header className="fixed inset-x-0 top-0 z-30 px-4 pt-[calc(env(safe-area-inset-top,0px)+10px)]">
      <div
        className={`mx-auto flex max-w-3xl items-center gap-3 squircle-lg px-4 py-3 liquid-panel transition-all duration-200 ease-out ${transformClass}`}
      >
        <p className="min-w-0 flex-1 truncate text-[15px] font-medium tracking-[-0.02em] text-white">
          {sourceLabel ?? appName}
        </p>

        <button
          type="button"
          onClick={onMenuOpen}
          aria-label={menuLabel}
          className="shrink-0 p-2 -mr-1 text-white/64 active:text-white transition-colors"
        >
          <LibraryIcon className="h-5 w-5" />
        </button>
      </div>
    </header>
  );
}

export default TopChrome;
