/**
 * @file Fullscreen preview overlay (Quick Mode).
 * @description
 * Full-viewport black overlay that enlarges a still image or shows the
 * ORIGINAL (raw) video with a minimal scrub seek bar. During video scrub the
 * content is the raw source video — this does NOT extend Filmtone's M1
 * grading-truth contract. On close, the caller's editor returns to its
 * graded poster still produced by `renderPreviewFrame`.
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type ChangeEvent,
  type PointerEvent as ReactPointerEvent,
  type ReactElement,
} from "react";
import { CloseIcon } from "@/components/FilmtoneIcons";

export interface FullscreenPreviewProps {
  isOpen: boolean;
  onClose: () => void;
  sourceKind: "image" | "video";
  imageUri?: string;
  videoUri?: string;
  filename?: string;
  closeLabel: string;
}

const DRAG_DISMISS_THRESHOLD_PX = 80;
const UNMOUNT_DELAY_MS = 220;
const FADE_MS = 150;

export function FullscreenPreview(props: FullscreenPreviewProps): ReactElement | null {
  const { isOpen, onClose, sourceKind, imageUri, videoUri, filename, closeLabel } = props;

  const [isMounted, setIsMounted] = useState(isOpen);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const videoRef = useRef<HTMLVideoElement | null>(null);
  const dragOriginRef = useRef<{ pointerId: number; y: number } | null>(null);

  // Mount / unmount transition (matches StrengthSheet pattern).
  useEffect(() => {
    if (isOpen) {
      setIsMounted(true);
      return undefined;
    }
    const timeoutId = window.setTimeout(() => setIsMounted(false), UNMOUNT_DELAY_MS);
    return () => window.clearTimeout(timeoutId);
  }, [isOpen]);

  // Scroll lock while visible.
  useEffect(() => {
    if (!isOpen) return undefined;
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, [isOpen]);

  // Reset transport state when closing.
  useEffect(() => {
    if (isOpen) return;
    const video = videoRef.current;
    if (video) {
      video.pause();
    }
    setCurrentTime(0);
  }, [isOpen]);

  const handleTimeUpdate = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    setCurrentTime(video.currentTime);
  }, []);

  const handleLoadedMetadata = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    setDuration(Number.isFinite(video.duration) ? video.duration : 0);
  }, []);

  const handleSeek = useCallback((event: ChangeEvent<HTMLInputElement>) => {
    const video = videoRef.current;
    const next = Number(event.target.value);
    if (!video || !Number.isFinite(next)) return;
    video.currentTime = next;
    setCurrentTime(next);
  }, []);

  const handleVideoTap = useCallback(() => {
    const video = videoRef.current;
    if (!video) return;
    if (video.paused) {
      void video.play().catch(() => {
        /* autoplay / gesture rejection — ignore. */
      });
    } else {
      video.pause();
    }
  }, []);

  const handleBackgroundPointerDown = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      if (dragOriginRef.current !== null) return;
      dragOriginRef.current = { pointerId: event.pointerId, y: event.clientY };
      try {
        event.currentTarget.setPointerCapture(event.pointerId);
      } catch {
        /* ignore */
      }
    },
    [],
  );

  const handleBackgroundPointerUp = useCallback(
    (event: ReactPointerEvent<HTMLDivElement>) => {
      const origin = dragOriginRef.current;
      if (!origin || origin.pointerId !== event.pointerId) return;
      const deltaY = event.clientY - origin.y;
      try {
        event.currentTarget.releasePointerCapture(event.pointerId);
      } catch {
        /* ignore */
      }
      dragOriginRef.current = null;
      if (deltaY > DRAG_DISMISS_THRESHOLD_PX) {
        onClose();
        return;
      }
      // Tap-on-black (no significant drag, didn't land on the media) → dismiss.
      if (event.target === event.currentTarget) {
        onClose();
      }
    },
    [onClose],
  );

  if (!isMounted) return null;

  const showVideo = sourceKind === "video" && Boolean(videoUri);
  const seekMax = duration > 0 ? duration : 0;
  const progress = seekMax > 0 ? Math.min(1, currentTime / seekMax) : 0;

  return (
    <div
      aria-hidden={!isOpen}
      role="dialog"
      aria-modal="true"
      aria-label={filename}
      className={[
        "fixed inset-0 z-50 isolate bg-black transition-opacity ease-out",
        isOpen ? "opacity-100 pointer-events-auto" : "opacity-0 pointer-events-none",
      ].join(" ")}
      style={{ transitionDuration: `${FADE_MS}ms`, touchAction: "none" }}
      onPointerDown={handleBackgroundPointerDown}
      onPointerUp={handleBackgroundPointerUp}
      onPointerCancel={handleBackgroundPointerUp}
    >
      <div
        className="absolute inset-0 flex items-center justify-center"
        style={{
          paddingTop: "env(safe-area-inset-top, 0px)",
          paddingBottom: "env(safe-area-inset-bottom, 0px)",
        }}
      >
        {showVideo ? (
          <video
            ref={videoRef}
            src={videoUri}
            poster={imageUri}
            playsInline
            muted
            preload="metadata"
            className="h-full w-full object-contain"
            onClick={handleVideoTap}
            onTimeUpdate={handleTimeUpdate}
            onLoadedMetadata={handleLoadedMetadata}
          />
        ) : imageUri ? (
          <img src={imageUri} alt={filename ?? ""} className="h-full w-full object-contain" />
        ) : null}
      </div>

      <button
        type="button"
        onClick={onClose}
        aria-label={closeLabel}
        className="squircle-md absolute flex h-12 w-12 items-center justify-center border border-white/12 bg-black/48 text-white/92 backdrop-blur-md active:bg-black/62"
        style={{
          top: "calc(env(safe-area-inset-top, 0px) + 12px)",
          right: "calc(env(safe-area-inset-right, 0px) + 12px)",
        }}
      >
        <CloseIcon className="h-5 w-5" aria-hidden="true" />
      </button>

      {showVideo && seekMax > 0 ? (
        <div
          className="absolute inset-x-0 px-6"
          style={{ bottom: "calc(env(safe-area-inset-bottom, 0px) + 20px)" }}
          onPointerDown={(event) => event.stopPropagation()}
          onPointerUp={(event) => event.stopPropagation()}
        >
          <div className="relative h-3 w-full">
            <div className="absolute inset-x-0 top-1/2 h-[2px] -translate-y-1/2 rounded-full bg-white/20" />
            <div
              className="pointer-events-none absolute left-0 top-1/2 h-[2px] -translate-y-1/2 rounded-full bg-[var(--accent-amber1)]"
              style={{ width: `${progress * 100}%` }}
            />
            <input
              type="range"
              min={0}
              max={seekMax}
              step={0.01}
              value={currentTime}
              onChange={handleSeek}
              aria-label={closeLabel}
              className="film-lab-slider absolute inset-0 h-full w-full cursor-pointer appearance-none bg-transparent"
              style={{ WebkitAppearance: "none" }}
            />
          </div>
        </div>
      ) : null}
    </div>
  );
}

export default FullscreenPreview;
