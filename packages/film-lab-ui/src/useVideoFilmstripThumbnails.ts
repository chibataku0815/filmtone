"use client";

/**
 * @fileoverview 動画プレビュー用 **フィルムストリップのサムネイル** を、非表示の `video` クローンから生成する React フックです（life#102）。
 *
 * @description
 * - キャンバス上の本番 `<video>` と同じ `src` / `srcObject` を、画面外に置いたクローンへコピーし、均等な時刻へ順にシークして `canvas.drawImage` します。
 * - 枚数は最大 12。長尺でも一度に増やさず、シーク回数で上限を切ります。
 * - `scrubbingRef` が true のあいだは **新しい生成を開始しない**／**生成ループを中断**し、タイムライン操作とぶつかりません。
 *
 * @limitations
 * - クローン方式がブラウザや CORS で失敗した場合は空配列になります（方式 B＝本番 video のミューテックスは未実装）。
 * - `toDataURL` はメインスレッドで走るため、極端に重い端末では短時間カクつく可能性があります。
 */

import { useEffect, useRef, useState, type RefObject } from "react";
import type { FilmLabCanvasRef } from "./FilmLabCanvas";

/** @description サムネイル 1 枚の最大幅（px）。縦はアスペクト比で自動。 */
export const FILMSTRIP_THUMB_MAX_COUNT = 12;

/** @description サムネイル横ピクセル。tray 幾何は維持しつつ生成画質だけを上げる。 */
export const FILMSTRIP_THUMB_WIDTH_PX = 80;

const REPRESENTATIVE_FRAME_CANDIDATE_TIMES = [0.25, 0.5, 0.75, 1, 1.5, 2] as const;
const REPRESENTATIVE_FRAME_BRIGHTNESS_THRESHOLD = 0.05;

/**
 * @description `video` のメタデータが揃うまで待ちます。
 * @param video 対象の動画要素
 */
function waitLoadedMetadata(video: HTMLVideoElement): Promise<void> {
  return new Promise((resolve, reject) => {
    if (video.readyState >= HTMLMediaElement.HAVE_METADATA) {
      resolve();
      return;
    }
    const onError = () => {
      video.removeEventListener("loadedmetadata", onLoaded);
      video.removeEventListener("error", onError);
      reject(
        new Error(
          `useVideoFilmstripThumbnails.waitLoadedMetadata: video error (networkState=${video.networkState}, error=${String(video.error?.message ?? "unknown")})`,
        ),
      );
    };
    const onLoaded = () => {
      video.removeEventListener("loadedmetadata", onLoaded);
      video.removeEventListener("error", onError);
      resolve();
    };
    video.addEventListener("loadedmetadata", onLoaded);
    video.addEventListener("error", onError);
  });
}

/**
 * @description `currentTime` を指定秒へ寄せ、`seeked` まで待ちます（すでに近いときはすぐ終了）。
 * @param video シーク対象
 * @param time 目標の秒
 * @param videoDuration `video.duration`（秒）
 */
function seekVideo(
  video: HTMLVideoElement,
  time: number,
  videoDuration: number,
): Promise<void> {
  const dur = Number.isFinite(videoDuration) && videoDuration > 0 ? videoDuration : 0;
  const target = dur > 0 ? Math.max(0, Math.min(dur, time)) : Math.max(0, time);
  return new Promise((resolve, reject) => {
    let settled = false;
    const finish = () => {
      if (settled) {
        return;
      }
      settled = true;
      window.clearTimeout(timerId);
      video.removeEventListener("seeked", onSeeked);
      resolve();
    };
    const onSeeked = () => finish();
    const timerId = window.setTimeout(() => finish(), 2500);
    video.addEventListener("seeked", onSeeked, { once: true });
    try {
      if (Math.abs(video.currentTime - target) < 0.02) {
        finish();
        return;
      }
      video.currentTime = target;
    } catch (err) {
      settled = true;
      window.clearTimeout(timerId);
      video.removeEventListener("seeked", onSeeked);
      reject(
        err instanceof Error
          ? err
          : new Error(
              `useVideoFilmstripThumbnails.seekVideo: failed to assign currentTime=${target} (${String(err)})`,
            ),
      );
    }
  });
}

/**
 * @description 画面外にクローン `video` を用意し、`src` / `srcObject` を本番と揃えます。
 * @param source キャンバス側のプレビュー動画
 * @returns 生成した要素（呼び出し側で DOM から外す）
 */
function createOffscreenCloneVideo(source: HTMLVideoElement): HTMLVideoElement {
  const clone = document.createElement("video");
  clone.muted = true;
  clone.defaultMuted = true;
  clone.playsInline = true;
  clone.setAttribute("playsinline", "");
  clone.preload = "auto";
  if (source.crossOrigin) {
    clone.crossOrigin = source.crossOrigin;
  }
  if (source.srcObject) {
    try {
      clone.srcObject = source.srcObject;
    } catch (err) {
      console.warn("useVideoFilmstripThumbnails.createOffscreenCloneVideo: srcObject copy failed, falling back to src", {
        functionName: "createOffscreenCloneVideo",
        err,
      });
    }
  }
  if (!clone.srcObject) {
    const url = source.currentSrc || source.src;
    if (url) {
      clone.src = url;
    }
  }
  clone.style.cssText =
    "position:fixed;width:1px;height:1px;opacity:0;pointer-events:none;left:-9999px;top:0;z-index:-1;";
  document.body.appendChild(clone);
  return clone;
}

function computeCanvasAverageBrightness(
  ctx: CanvasRenderingContext2D,
  width: number,
  height: number,
): number {
  const { data } = ctx.getImageData(0, 0, width, height);
  if (data.length === 0) {
    return 0;
  }
  let luminanceSum = 0;
  let pixelCount = 0;
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i] / 255;
    const g = data[i + 1] / 255;
    const b = data[i + 2] / 255;
    luminanceSum += 0.2126 * r + 0.7152 * g + 0.0722 * b;
    pixelCount += 1;
  }
  return pixelCount > 0 ? luminanceSum / pixelCount : 0;
}

function clampSeekTime(time: number, duration: number): number {
  return Math.max(0, Math.min(duration, time));
}

export type UseVideoFilmstripThumbnailsArgs = {
  /** @description キャンバス API（`getActiveVideoElement` が使えること） */
  filmLabCanvasRef: RefObject<FilmLabCanvasRef | null>;
  /** @description タイムラインをスクラブ中なら true（親の ref と共有） */
  scrubbingRef: RefObject<boolean>;
  /**
   * @description 動画ソースの識別子。例: `currentSrc + "|" + duration`。
   * 空文字のときサムネはクリアされます。
   */
  mediaKey: string;
  /** @description サムネ枚数の上限（既定 12） */
  maxCount?: number;
  /** @description サムネの横幅（既定 `FILMSTRIP_THUMB_WIDTH_PX`） */
  thumbWidthPx?: number;
  /**
   * @description スクラブ終了のたびに親が増やすカウンタ。`mediaKey` が同じでも再生成したいときに使います。
   */
  regenTick?: number;
};

export type UseVideoFilmstripThumbnailsResult = {
  /** @description JPEG data URL の配列（失敗コマは空文字＝スケルトン表示用） */
  thumbnails: string[];
  /** @description 生成ジョブ実行中 */
  isGenerating: boolean;
};

/**
 * @description フィルムストリップ用サムネイルを非同期生成するフック。
 */
export function useVideoFilmstripThumbnails({
  filmLabCanvasRef,
  scrubbingRef,
  mediaKey,
  maxCount = FILMSTRIP_THUMB_MAX_COUNT,
  thumbWidthPx = FILMSTRIP_THUMB_WIDTH_PX,
  regenTick = 0,
}: UseVideoFilmstripThumbnailsArgs): UseVideoFilmstripThumbnailsResult {
  const [thumbnails, setThumbnails] = useState<string[]>([]);
  const [isGenerating, setIsGenerating] = useState(false);

  useEffect(() => {
    if (!mediaKey) {
      setThumbnails([]);
      setIsGenerating(false);
      return;
    }

    let cancelled = false;

    const run = async () => {
      if (scrubbingRef.current) {
        return;
      }
      setIsGenerating(true);
      setThumbnails([]);

      const api = filmLabCanvasRef.current;
      const source = api?.getActiveVideoElement() ?? null;
      if (!source || cancelled || scrubbingRef.current) {
        setIsGenerating(false);
        return;
      }

      let clone: HTMLVideoElement | null = null;
      try {
        clone = createOffscreenCloneVideo(source);
        await waitLoadedMetadata(clone);
        if (cancelled || scrubbingRef.current) {
          return;
        }

        const dur = clone.duration;
        if (!Number.isFinite(dur) || dur <= 0) {
          console.warn("useVideoFilmstripThumbnails: invalid clone.duration", {
            functionName: "useVideoFilmstripThumbnails",
            duration: dur,
            mediaKey,
          });
          return;
        }

        const count = Math.min(FILMSTRIP_THUMB_MAX_COUNT, Math.max(1, maxCount));
        const stamps =
          count === 1 ? [0] : Array.from({ length: count }, (_, i) => (i / (count - 1)) * dur);

        const vw = clone.videoWidth;
        const vh = clone.videoHeight;
        if (vw <= 0 || vh <= 0) {
          console.warn("useVideoFilmstripThumbnails: videoWidth/videoHeight not ready", {
            functionName: "useVideoFilmstripThumbnails",
            videoWidth: vw,
            videoHeight: vh,
            mediaKey,
          });
          return;
        }

        const thumbH = Math.max(1, Math.round((vh / vw) * thumbWidthPx));
        const canvas = document.createElement("canvas");
        canvas.width = thumbWidthPx;
        canvas.height = thumbH;
        const ctx = canvas.getContext("2d");
        if (!ctx) {
          console.error("useVideoFilmstripThumbnails: 2d context is null", {
            functionName: "useVideoFilmstripThumbnails",
            mediaKey,
          });
          return;
        }

        const frames: string[] = [];
        clone.pause();

        let bestRepresentativeFrame:
          | { brightness: number; dataUrl: string; time: number }
          | null = null;
        for (const candidateTime of REPRESENTATIVE_FRAME_CANDIDATE_TIMES) {
          if (cancelled || scrubbingRef.current) {
            break;
          }
          const clampedCandidateTime = clampSeekTime(candidateTime, dur);
          await seekVideo(clone, clampedCandidateTime, dur);
          if (cancelled || scrubbingRef.current) {
            break;
          }
          ctx.fillStyle = "#141414";
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          try {
            ctx.drawImage(clone, 0, 0, vw, vh, 0, 0, thumbWidthPx, thumbH);
            const brightness = computeCanvasAverageBrightness(ctx, canvas.width, canvas.height);
            const dataUrl = canvas.toDataURL("image/jpeg", 0.72);
            if (
              bestRepresentativeFrame == null ||
              brightness > bestRepresentativeFrame.brightness
            ) {
              bestRepresentativeFrame = {
                brightness,
                dataUrl,
                time: clampedCandidateTime,
              };
            }
            if (brightness >= REPRESENTATIVE_FRAME_BRIGHTNESS_THRESHOLD) {
              frames.push(dataUrl);
              break;
            }
          } catch (err) {
            console.warn("useVideoFilmstripThumbnails: representative frame probe failed", {
              functionName: "useVideoFilmstripThumbnails",
              time: clampedCandidateTime,
              mediaKey,
              err,
            });
          }
        }
        if (!cancelled && !scrubbingRef.current && frames.length === 0) {
          frames.push(bestRepresentativeFrame?.dataUrl ?? "");
        }

        for (const t of stamps.slice(1)) {
          if (cancelled || scrubbingRef.current) {
            break;
          }
          await seekVideo(clone, t, dur);
          if (cancelled || scrubbingRef.current) {
            break;
          }
          ctx.fillStyle = "#141414";
          ctx.fillRect(0, 0, canvas.width, canvas.height);
          try {
            ctx.drawImage(clone, 0, 0, vw, vh, 0, 0, thumbWidthPx, thumbH);
            frames.push(canvas.toDataURL("image/jpeg", 0.72));
          } catch (err) {
            console.warn("useVideoFilmstripThumbnails: drawImage / toDataURL failed", {
              functionName: "useVideoFilmstripThumbnails",
              time: t,
              mediaKey,
              err,
            });
            frames.push("");
          }
        }

        if (!cancelled && !scrubbingRef.current && frames.length === stamps.length) {
          setThumbnails(frames);
        }
      } catch (err) {
        console.error("useVideoFilmstripThumbnails: generation failed", {
          functionName: "useVideoFilmstripThumbnails",
          mediaKey,
          err,
        });
      } finally {
        if (clone && clone.parentNode) {
          clone.parentNode.removeChild(clone);
        }
        clone = null;
        setIsGenerating(false);
      }
    };

    void run();

    return () => {
      cancelled = true;
    };
  }, [filmLabCanvasRef, scrubbingRef, mediaKey, maxCount, thumbWidthPx, regenTick]);

  return { thumbnails, isGenerating };
}
