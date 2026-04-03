"use client";

/**
 * @fileoverview Filmtone の **動画プレビュー用トランスポートバー**（life#75）。
 *
 * @description
 * - 再生・一時停止・タイムラインのドラッグ／クリックシーク・経過時間表示をまとめます。
 * - `FilmLabCanvasRef` だけを受け取り、内部で `requestAnimationFrame` により滑らかに時刻を追います。
 * - スクラブ中は動画を一時停止し、指／ポインタを離したあと「シーク前に再生中だった」なら再開します。
 *
 * @limitations
 * - フィルムストリップは **目安サムネ**（life#102）。現在位置の読み取り補助であり、正確なフレーム編集には使えません。
 * - `Space` は `document` のバブルフェーズで拾います。Compare モードでは Core が Capture で先に処理するため競合しません。
 */

import {
  useCallback,
  useEffect,
  useRef,
  useState,
  type RefObject,
} from "react";
import { useTranslations } from "next-intl";
import type { FilmLabCanvasRef } from "./FilmLabCanvas";
import { FILM_LAB_NEXT_INTL_NAMESPACE } from "./filmLabUiContract";
import { VideoFilmstripStrip } from "./VideoFilmstripStrip";
import {
  FILMSTRIP_THUMB_WIDTH_PX,
  useVideoFilmstripThumbnails,
} from "./useVideoFilmstripThumbnails";

/**
 * @description トランスポートに必要な ref。キャンバスと同じインスタンスを渡してください。
 */
export type VideoTransportControlsProps = {
  filmLabCanvasRef: RefObject<FilmLabCanvasRef | null>;
  /** @description ルート要素に追加する Tailwind クラス */
  className?: string;
};

/**
 * @description `秒` を `m:ss` 表示にします。子どもでも「分と秒」の関係が分かる表記です。
 * @param totalSeconds 負や NaN のときは 0 扱い
 */
function formatClock(totalSeconds: number): string {
  if (!Number.isFinite(totalSeconds) || totalSeconds < 0) {
    return "0:00";
  }
  const whole = Math.floor(totalSeconds);
  const s = whole % 60;
  const m = Math.floor(whole / 60);
  return `${m}:${String(s).padStart(2, "0")}`;
}

/**
 * @description 入力フォーカス中か。Space をページスクロールに渡さない判定にも使います。
 */
function isEditableTarget(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) {
    return false;
  }
  if (target.isContentEditable) {
    return true;
  }
  if (target instanceof HTMLInputElement || target instanceof HTMLTextAreaElement) {
    return true;
  }
  return false;
}

/**
 * @description 再生ボタン用の三角アイコン（Phosphor 依存を増やさない最小 SVG）。
 */
function PlayGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M8 5v14l11-7L8 5Z" />
    </svg>
  );
}

/**
 * @description 一時停止アイコン（二本線）。
 */
function PauseGlyph() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor" aria-hidden>
      <path d="M6 5h4v14H6V5Zm8 0h4v14h-4V5Z" />
    </svg>
  );
}

/**
 * @description トランスポートバー本体。
 */
export function VideoTransportControls({
  filmLabCanvasRef,
  className,
}: VideoTransportControlsProps) {
  const tTransport = useTranslations(`${FILM_LAB_NEXT_INTL_NAMESPACE}.canvas.transport`);
  const tFilmstrip = useTranslations(`${FILM_LAB_NEXT_INTL_NAMESPACE}.canvas.filmstrip`);

  const scrubbingRef = useRef(false);
  const scrubTimeRef = useRef(0);
  const wasPlayingBeforeScrubRef = useRef(false);
  const trackRef = useRef<HTMLDivElement | null>(null);
  const filmstripMediaKeyRef = useRef("");
  const [filmstripMediaKey, setFilmstripMediaKey] = useState("");
  const [filmstripRegenTick, setFilmstripRegenTick] = useState(0);

  const [panel, setPanel] = useState<{
    open: boolean;
    isPlaying: boolean;
    currentTime: number;
    duration: number;
    suppressed: boolean;
  }>({
    open: false,
    isPlaying: false,
    currentTime: 0,
    duration: 0,
    suppressed: false,
  });

  const seekFromClientX = useCallback(
    (clientX: number) => {
      const canvasRef = filmLabCanvasRef.current;
      const track = trackRef.current;
      if (!canvasRef || !track) {
        return;
      }
      const rect = track.getBoundingClientRect();
      if (rect.width <= 0) {
        return;
      }
      const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
      const state = canvasRef.getVideoPlaybackState();
      const dur = state.duration;
      if (!(Number.isFinite(dur) && dur > 0)) {
        return;
      }
      const nextTime = ratio * dur;
      scrubTimeRef.current = nextTime;
      canvasRef.videoPlaybackSeek(nextTime);
      setPanel((prev) => ({
        ...prev,
        currentTime: nextTime,
        isPlaying: false,
      }));
    },
    [filmLabCanvasRef],
  );

  useEffect(() => {
    let raf = 0;
    const tick = () => {
      raf = window.requestAnimationFrame(tick);
      const api = filmLabCanvasRef.current;
      if (!api) {
        setPanel((p) =>
          p.open
            ? {
                open: false,
                isPlaying: false,
                currentTime: 0,
                duration: 0,
                suppressed: false,
              }
            : p,
        );
        if (filmstripMediaKeyRef.current !== "") {
          filmstripMediaKeyRef.current = "";
          setFilmstripMediaKey("");
        }
        return;
      }
      const suppressed = api.isVideoPlaybackSuppressed();
      const playback = api.getVideoPlaybackState();
      if (!playback.hasVideo) {
        setPanel((p) =>
          p.open
            ? {
                open: false,
                isPlaying: false,
                currentTime: 0,
                duration: 0,
                suppressed: false,
              }
            : p,
        );
        if (filmstripMediaKeyRef.current !== "") {
          filmstripMediaKeyRef.current = "";
          setFilmstripMediaKey("");
        }
        return;
      }
      const currentTime = scrubbingRef.current
        ? scrubTimeRef.current
        : playback.currentTime;
      const next = {
        open: true,
        isPlaying: scrubbingRef.current ? false : playback.isPlaying,
        currentTime,
        duration: playback.duration,
        suppressed,
      };
      setPanel((prev) => {
        if (
          prev.open === next.open &&
          prev.isPlaying === next.isPlaying &&
          prev.suppressed === next.suppressed &&
          Math.abs(prev.currentTime - next.currentTime) < 0.01 &&
          Math.abs(prev.duration - next.duration) < 0.0005
        ) {
          return prev;
        }
        return next;
      });

      const previewVideo = api.getActiveVideoElement();
      const nextFilmstripKey =
        next.open &&
        previewVideo &&
        playback.hasVideo &&
        Number.isFinite(playback.duration) &&
        playback.duration > 0
          ? `${previewVideo.currentSrc}|${playback.duration.toFixed(3)}`
          : "";
      if (nextFilmstripKey !== filmstripMediaKeyRef.current) {
        filmstripMediaKeyRef.current = nextFilmstripKey;
        setFilmstripMediaKey(nextFilmstripKey);
      }
    };
    raf = window.requestAnimationFrame(tick);
    return () => window.cancelAnimationFrame(raf);
  }, [filmLabCanvasRef]);

  const { thumbnails: filmstripThumbnails, isGenerating: filmstripGenerating } =
    useVideoFilmstripThumbnails({
      filmLabCanvasRef,
      scrubbingRef,
      mediaKey: filmstripMediaKey,
      thumbWidthPx: FILMSTRIP_THUMB_WIDTH_PX,
      regenTick: filmstripRegenTick,
    });

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key !== " " && e.code !== "Space") {
        return;
      }
      if (e.repeat) {
        return;
      }
      if (isEditableTarget(e.target)) {
        return;
      }
      const api = filmLabCanvasRef.current;
      if (!api?.getVideoPlaybackState().hasVideo) {
        return;
      }
      if (api.isVideoPlaybackSuppressed()) {
        return;
      }
      e.preventDefault();
      api.videoPlaybackTogglePlayPause();
    };
    document.addEventListener("keydown", onKeyDown);
    return () => document.removeEventListener("keydown", onKeyDown);
  }, [filmLabCanvasRef]);

  if (!panel.open) {
    return null;
  }

  const disabled = panel.suppressed;
  const dur = panel.duration;
  const progress =
    Number.isFinite(dur) && dur > 0
      ? Math.max(0, Math.min(1, panel.currentTime / dur))
      : 0;

  const onScrubPointerDown = (e: React.PointerEvent<HTMLDivElement>) => {
    const api = filmLabCanvasRef.current;
    if (!api || disabled) {
      return;
    }
    e.preventDefault();
    e.stopPropagation();
    scrubbingRef.current = true;
    wasPlayingBeforeScrubRef.current = api.getVideoPlaybackState().isPlaying;
    api.videoPlaybackPause();
    seekFromClientX(e.clientX);
    e.currentTarget.setPointerCapture(e.pointerId);
  };

  const onScrubPointerMove = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!scrubbingRef.current) {
      return;
    }
    seekFromClientX(e.clientX);
  };

  const endScrub = (e: React.PointerEvent<HTMLDivElement>) => {
    if (!scrubbingRef.current) {
      return;
    }
    scrubbingRef.current = false;
    try {
      e.currentTarget.releasePointerCapture(e.pointerId);
    } catch {
      // キャプチャが無い環境でも落ちないようにする
    }
    const api = filmLabCanvasRef.current;
    if (!api) {
      return;
    }
    if (!api.isVideoPlaybackSuppressed() && wasPlayingBeforeScrubRef.current) {
      api.videoPlaybackPlay();
    }
    setFilmstripRegenTick((n) => n + 1);
  };

  return (
    <div
      className={[
        "pointer-events-auto flex min-w-0 flex-col gap-1 bg-transparent py-4",
        className ?? "",
      ]
        .filter(Boolean)
        .join(" ")}
      role="group"
      aria-label={tTransport("regionAria")}
    >
      <VideoFilmstripStrip
        thumbnails={filmstripThumbnails}
        isGenerating={filmstripGenerating}
        currentTime={panel.currentTime}
        duration={panel.duration}
        disabled={disabled}
        thumbWidthPx={FILMSTRIP_THUMB_WIDTH_PX}
        stripAriaLabel={tFilmstrip("stripAria")}
      />

      <div className="mx-4 rounded-[1.2rem] border border-white/[0.09] bg-black/28 px-4 py-3 shadow-[0_12px_32px_rgba(0,0,0,0.24)] backdrop-blur-md">
        <div className="flex min-w-0 items-center gap-2">
          <button
            type="button"
            className="inline-flex h-9 w-9 shrink-0 items-center justify-center rounded-md border border-white/12 bg-white/5 text-white/90 transition-colors hover:border-white/20 hover:bg-white/10 disabled:cursor-not-allowed disabled:opacity-40"
            disabled={disabled}
            aria-label={panel.isPlaying ? tTransport("pauseAria") : tTransport("playAria")}
            title={disabled ? tTransport("disabledDuringBusy") : undefined}
            onClick={() => {
              const api = filmLabCanvasRef.current;
              if (!api || disabled) {
                return;
              }
              api.videoPlaybackTogglePlayPause();
            }}
          >
            {panel.isPlaying ? <PauseGlyph /> : <PlayGlyph />}
          </button>

          <div
            ref={trackRef}
            className="relative h-2 min-w-0 flex-1 cursor-pointer rounded-full bg-white/10"
            role="slider"
            tabIndex={0}
            aria-label={tTransport("timelineAria")}
            aria-valuemin={0}
            aria-valuemax={Math.max(0, dur)}
            aria-valuenow={panel.currentTime}
            aria-disabled={disabled}
            onKeyDown={(e) => {
              if (disabled || !(Number.isFinite(dur) && dur > 0)) {
                return;
              }
              const step = Math.max(0.05, dur / 200);
              const api = filmLabCanvasRef.current;
              if (!api) {
                return;
              }
              if (e.key === "ArrowLeft") {
                e.preventDefault();
                api.videoPlaybackSeek(panel.currentTime - step);
              } else if (e.key === "ArrowRight") {
                e.preventDefault();
                api.videoPlaybackSeek(panel.currentTime + step);
              }
            }}
            onPointerDown={onScrubPointerDown}
            onPointerMove={onScrubPointerMove}
            onPointerUp={endScrub}
            onPointerCancel={endScrub}
          >
            <div
              className="absolute inset-y-0 left-0 rounded-full bg-white/55"
              style={{ width: `${progress * 100}%` }}
            />
          </div>

          <span className="shrink-0 tabular-nums text-[11px] text-white/70">
            {formatClock(panel.currentTime)} / {formatClock(panel.duration)}
          </span>
        </div>
      </div>
    </div>
  );
}
